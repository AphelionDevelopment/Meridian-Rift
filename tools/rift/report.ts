import fs from 'node:fs/promises';
import path from 'node:path';
import type { ProcessResult } from './process';

export const RIFT_SCHEMA_VERSION = 1 as const;

export type RiftStatus =
  | 'passed'
  | 'failed'
  | 'timed_out'
  | 'cancelled'
  | 'ready_then_stopped';

export type EvidenceClass =
  | 'inspection'
  | 'compiler'
  | 'full_build'
  | 'boot'
  | 'focused_test'
  | 'full_test'
  | 'soak';

export type RiftFailure = {
  code: string;
  stage: string;
  message: string;
};

export type RiftEvent = {
  schema_version: typeof RIFT_SCHEMA_VERSION;
  run_id: string;
  sequence: number;
  timestamp: string;
  kind:
    | 'run_started'
    | 'stage_started'
    | 'process_started'
    | 'process_output'
    | 'observation'
    | 'artifact'
    | 'stage_finished'
    | 'failure'
    | 'run_finished';
  stage: string;
  status?: RiftStatus;
  data: Record<string, unknown>;
};

export type RiftSummary = {
  schema_version: typeof RIFT_SCHEMA_VERSION;
  run_id: string;
  command: string;
  profile: string;
  status: RiftStatus;
  evidence: EvidenceClass;
  exit_code: number;
  started_at: string;
  finished_at: string;
  duration_ms: number;
  repository: { revision: string; dirty: boolean };
  tool_versions: Record<string, string>;
  network_mode: 'offline' | 'allow';
  phases: Array<Record<string, unknown>>;
  processes: Array<Record<string, unknown>>;
  tests: {
    recorded: number;
    passed: number;
    failed: number;
    skipped: number;
  } | null;
  runtime_signatures: Array<{
    signature: string;
    count: number;
    first_seen: string;
  }>;
  resource_maxima: Array<Record<string, unknown>>;
  artifacts: Array<Record<string, unknown>>;
  cleanup: { passed: boolean; leftovers: string[] };
  failures: RiftFailure[];
};

export type RunRecorderOptions = {
  runDir: string;
  runId: string;
  command: string;
  profile: string;
  evidence: EvidenceClass;
  networkMode: 'offline' | 'allow';
};

export type ArtifactRecord = {
  path: string;
  size: number;
  sha256: string;
  stage: string;
  freshness: 'new' | 'rebuilt' | 'reused' | 'collected';
  modified_at?: string;
};

const pathEscapes = (relativePath: string) =>
  relativePath === '..' ||
  relativePath.startsWith(`..${path.sep}`) ||
  path.isAbsolute(relativePath);

const redactUserPaths = (value: string) =>
  value
    .replaceAll(/([A-Za-z]:\\Users\\)[^\\\r\n]+/g, '$1<profile>')
    .replaceAll(/(\/Users\/)[^/\r\n]+/g, '$1<profile>');

export class RunRecorder {
  readonly stdoutPath: string;
  readonly stderrPath: string;
  readonly #eventsPath: string;
  readonly #summaryPath: string;
  readonly #startedAtMs: number;
  #sequence = 0;
  #writes: Promise<void> = Promise.resolve();
  #summary: RiftSummary;
  #finished: RiftSummary | null = null;

  private constructor(
    readonly runDir: string,
    options: RunRecorderOptions,
  ) {
    this.stdoutPath = path.join(runDir, 'stdout.log');
    this.stderrPath = path.join(runDir, 'stderr.log');
    this.#eventsPath = path.join(runDir, 'events.ndjson');
    this.#summaryPath = path.join(runDir, 'summary.json');
    this.#startedAtMs = Date.now();
    const startedAt = new Date(this.#startedAtMs).toISOString();
    this.#summary = {
      schema_version: RIFT_SCHEMA_VERSION,
      run_id: options.runId,
      command: options.command,
      profile: options.profile,
      status: 'failed',
      evidence: options.evidence,
      exit_code: 3,
      started_at: startedAt,
      finished_at: startedAt,
      duration_ms: 0,
      repository: { revision: 'unknown', dirty: false },
      tool_versions: {},
      network_mode: options.networkMode,
      phases: [],
      processes: [],
      tests: null,
      runtime_signatures: [],
      resource_maxima: [],
      artifacts: [],
      cleanup: { passed: true, leftovers: [] },
      failures: [],
    };
  }

  static async create(options: RunRecorderOptions): Promise<RunRecorder> {
    await fs.mkdir(options.runDir, { recursive: true });
    const recorder = new RunRecorder(options.runDir, options);
    await Promise.all([
      fs.writeFile(recorder.#eventsPath, ''),
      fs.writeFile(recorder.stdoutPath, ''),
      fs.writeFile(recorder.stderrPath, ''),
    ]);
    await recorder.emit('run_started', 'run', {
      command: options.command,
      profile: options.profile,
      evidence: options.evidence,
      network_mode: options.networkMode,
    });
    return recorder;
  }

  #queue(action: () => Promise<void>): Promise<void> {
    const queued = this.#writes.then(action);
    this.#writes = queued.catch(() => undefined);
    return queued;
  }

  #appendEvent(
    kind: RiftEvent['kind'],
    stage: string,
    data: Record<string, unknown>,
    status?: RiftStatus,
  ) {
    this.#sequence += 1;
    const event: RiftEvent = {
      schema_version: RIFT_SCHEMA_VERSION,
      run_id: this.#summary.run_id,
      sequence: this.#sequence,
      timestamp: new Date().toISOString(),
      kind,
      stage,
      data,
      ...(status ? { status } : {}),
    };
    return fs.appendFile(
      this.#eventsPath,
      `${JSON.stringify(event)}\n`,
      'utf8',
    );
  }

  emit(
    kind: RiftEvent['kind'],
    stage: string,
    data: Record<string, unknown>,
    status?: RiftStatus,
  ): Promise<void> {
    return this.#queue(async () => {
      const now = Date.now();
      if (kind === 'stage_started') {
        this.#summary.phases.push({
          ...structuredClone(data),
          stage,
          status: 'running',
          started_at: new Date(now).toISOString(),
          started_at_ms: now,
        });
      } else if (kind === 'stage_finished') {
        const phase = this.#summary.phases.findLast(
          (entry) => entry.stage === stage && entry.finished_at === undefined,
        );
        if (phase) {
          Object.assign(phase, structuredClone(data));
          phase.stage = stage;
          phase.status = status ?? 'passed';
          phase.finished_at = new Date(now).toISOString();
          phase.duration_ms =
            typeof phase.started_at_ms === 'number'
              ? now - phase.started_at_ms
              : 0;
          delete phase.started_at_ms;
        }
      }
      await this.#appendEvent(kind, stage, data, status);
    });
  }

  appendOutput(
    stage: string,
    role: string,
    stream: 'stdout' | 'stderr',
    line: string,
  ): Promise<void> {
    return this.#queue(async () => {
      const outputPath =
        stream === 'stdout' ? this.stdoutPath : this.stderrPath;
      await fs.appendFile(outputPath, `${line}\n`, 'utf8');
      await this.#appendEvent('process_output', stage, { role, stream, line });
    });
  }

  async addFailure(failure: RiftFailure): Promise<void> {
    this.#summary.failures.push({ ...failure });
    await this.emit('failure', failure.stage, { ...failure }, 'failed');
  }

  async addArtifact(record: ArtifactRecord): Promise<void> {
    this.#summary.artifacts.push({ ...record });
    await this.emit('artifact', record.stage, { ...record });
  }

  async setTests(tests: NonNullable<RiftSummary['tests']>): Promise<void> {
    await this.#queue(async () => {
      this.#summary.tests = { ...tests };
    });
  }

  async setRepository(revision: string, dirty: boolean): Promise<void> {
    await this.#queue(async () => {
      this.#summary.repository = { revision, dirty };
    });
  }

  async setToolVersions(versions: Record<string, string>): Promise<void> {
    await this.#queue(async () => {
      this.#summary.tool_versions = { ...versions };
    });
  }

  async addPhase(phase: Record<string, unknown>): Promise<void> {
    await this.#queue(async () => {
      this.#summary.phases.push(structuredClone(phase));
    });
  }

  async addProcess(result: ProcessResult): Promise<void> {
    await this.#queue(async () => {
      this.#summary.processes.push({
        role: result.role,
        root_pid: result.rootPid,
        owned_pids: [...result.ownedPids],
        exit_code: result.exitCode,
        signal: result.signal,
        termination: result.termination,
        started_at: result.startedAt,
        finished_at: result.finishedAt,
        duration_ms: result.durationMs,
      });
    });
  }

  async setRuntimeSignatures(
    signatures: RiftSummary['runtime_signatures'],
  ): Promise<void> {
    await this.#queue(async () => {
      this.#summary.runtime_signatures = structuredClone(signatures);
    });
  }

  async setResourceMaxima(
    maxima: Array<Record<string, unknown>>,
  ): Promise<void> {
    await this.#queue(async () => {
      this.#summary.resource_maxima = structuredClone(maxima);
    });
  }

  async setCleanup(cleanup: RiftSummary['cleanup']): Promise<void> {
    await this.#queue(async () => {
      this.#summary.cleanup = {
        passed: cleanup.passed,
        leftovers: [...cleanup.leftovers],
      };
    });
  }

  async finish(status: RiftStatus, exitCode: number): Promise<RiftSummary> {
    if (this.#finished) {
      return structuredClone(this.#finished);
    }
    await this.emit('run_finished', 'run', { exit_code: exitCode }, status);
    await this.#writes;

    const finishedAtMs = Date.now();
    for (const phase of this.#summary.phases) {
      if (phase.finished_at !== undefined) {
        continue;
      }
      phase.status = status;
      phase.finished_at = new Date(finishedAtMs).toISOString();
      phase.duration_ms =
        typeof phase.started_at_ms === 'number'
          ? finishedAtMs - phase.started_at_ms
          : 0;
      delete phase.started_at_ms;
    }
    this.#summary.status = status;
    this.#summary.exit_code = exitCode;
    this.#summary.finished_at = new Date(finishedAtMs).toISOString();
    this.#summary.duration_ms = finishedAtMs - this.#startedAtMs;
    const temporaryPath = `${this.#summaryPath}.${crypto.randomUUID()}.tmp`;
    await fs.writeFile(
      temporaryPath,
      `${JSON.stringify(this.#summary, null, 2)}\n`,
      'utf8',
    );
    await fs.rename(temporaryPath, this.#summaryPath);
    this.#finished = structuredClone(this.#summary);
    return structuredClone(this.#summary);
  }
}

export const hashArtifact = async (
  absolutePath: string,
  runDir: string,
  stage: string,
  freshness: ArtifactRecord['freshness'],
): Promise<ArtifactRecord> => {
  const resolvedRunDir = path.resolve(runDir);
  const resolvedArtifact = path.resolve(absolutePath);
  const relativePath = path.relative(resolvedRunDir, resolvedArtifact);
  if (pathEscapes(relativePath)) {
    throw new Error('artifact path escapes run directory');
  }

  const file = Bun.file(resolvedArtifact);
  const bytes = new Uint8Array(await file.arrayBuffer());
  const sha256 = new Bun.CryptoHasher('sha256').update(bytes).digest('hex');
  return {
    path: relativePath.replaceAll('\\', '/'),
    size: bytes.byteLength,
    sha256,
    stage,
    freshness,
  };
};

export const normalizeRuntimeSignature = (message: string): string =>
  message
    .replaceAll(/\[0x[0-9a-f]+\]/gi, '[ref]')
    .replaceAll(/\d+/g, 'N')
    .trim();

export const readStoredRun = async (
  runDir: string,
): Promise<{ summary: RiftSummary; events: RiftEvent[] }> => {
  const summary = (await Bun.file(
    path.join(runDir, 'summary.json'),
  ).json()) as RiftSummary;
  if (summary.schema_version !== RIFT_SCHEMA_VERSION) {
    throw new Error(
      `unsupported report schema: ${String(summary.schema_version)}`,
    );
  }

  const eventText = await Bun.file(path.join(runDir, 'events.ndjson')).text();
  const events = eventText.trim()
    ? eventText
        .trim()
        .split('\n')
        .map((line) => JSON.parse(line) as RiftEvent)
    : [];
  for (const event of events) {
    if (event.schema_version !== RIFT_SCHEMA_VERSION) {
      throw new Error(
        `unsupported event schema: ${String(event.schema_version)}`,
      );
    }
  }
  return { summary, events };
};

export const renderHumanSummary = (summary: RiftSummary): string => {
  const lines = [
    `RIFT ${summary.command} ${summary.status}`,
    `run: ${summary.run_id}`,
    `evidence: ${summary.evidence}`,
    `exit: ${summary.exit_code}`,
    `duration_ms: ${summary.duration_ms}`,
    `repository: ${summary.repository.revision} dirty=${String(summary.repository.dirty)}`,
  ];
  for (const [tool, version] of Object.entries(summary.tool_versions).sort(
    ([left], [right]) => left.localeCompare(right),
  )) {
    lines.push(`tool: ${tool}=${version}`);
  }
  if (summary.tests) {
    lines.push(
      `tests: recorded=${summary.tests.recorded} passed=${summary.tests.passed} failed=${summary.tests.failed} skipped=${summary.tests.skipped}`,
    );
  }
  for (const phase of summary.phases) {
    if (phase.stage === 'doctor') {
      lines.push(
        `doctor: offline_ready=${String(phase.offline_ready)} lock=${String(phase.lock)} platform=${String(phase.platform)}`,
      );
      if (Array.isArray(phase.stale_scratch)) {
        for (const scratch of phase.stale_scratch) {
          lines.push(`stale_scratch: ${String(scratch)}`);
        }
      }
      continue;
    }
    const details = [
      typeof phase.status === 'string' ? `status=${phase.status}` : null,
      typeof phase.duration_ms === 'number'
        ? `duration_ms=${phase.duration_ms}`
        : null,
    ].filter((entry): entry is string => entry !== null);
    lines.push(
      `phase: ${String(phase.stage ?? 'unknown')}${details.length > 0 ? ` ${details.join(' ')}` : ''}`,
    );
  }
  for (const processResult of summary.processes) {
    const details = [
      `role=${String(processResult.role ?? 'unknown')}`,
      `termination=${String(processResult.termination ?? 'unknown')}`,
      `exit=${String(processResult.exit_code ?? 'null')}`,
      typeof processResult.duration_ms === 'number'
        ? `duration_ms=${processResult.duration_ms}`
        : null,
    ].filter((entry): entry is string => entry !== null);
    lines.push(`process: ${details.join(' ')}`);
  }
  for (const signature of summary.runtime_signatures) {
    lines.push(
      `runtime: count=${signature.count} signature=${signature.signature}`,
    );
  }
  for (const maximum of summary.resource_maxima) {
    lines.push(`resource: ${JSON.stringify(maximum)}`);
  }
  const visibleArtifacts = summary.artifacts.slice(0, 8);
  for (const artifact of visibleArtifacts) {
    lines.push(`artifact: ${String(artifact.path)}`);
  }
  if (summary.artifacts.length > visibleArtifacts.length) {
    lines.push(
      `artifacts: ${summary.artifacts.length} total, ${summary.artifacts.length - visibleArtifacts.length} omitted`,
    );
  }
  for (const failure of summary.failures.slice(0, 1)) {
    lines.push(
      `failure [${failure.code}] ${failure.stage}: ${failure.message}`,
    );
  }
  return redactUserPaths(lines.join('\n'));
};
