import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {
  type OwnedProcess,
  type ProcessHooks,
  type ProcessResult,
  type ProcessSnapshot,
  type ProcessSpec,
  ProcessSupervisionError,
} from './process';
import { RunRecorder } from './report';
import {
  allocateRun,
  loadProfiles,
  parseCli,
  qualifyRepository,
  type RiftProfile,
  runServerWorkflow,
  runSoakWorkflow,
  runTestWorkflow,
  type WorkflowContext,
} from './rift';

const resultDocument = (entries: Array<[string, number]>) =>
  Object.fromEntries(
    entries.map(([name, status]) => [name, { name, status, message: '' }]),
  );

export const runEvidenceFixture = async (options: {
  results: Array<[string, number]>;
  focus?: string[];
  minimum?: number;
  runtimeAfterReadiness?: boolean;
  supervisionFailureRole?: 'dreammaker' | 'dreamdaemon';
  workflow?: 'run' | 'soak';
  configureProfile?: (profile: RiftProfile) => void;
  childSnapshots?: () => ProcessSnapshot[];
  requiredArtifactContent?: string;
}) => {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'rift-unit-evidence-'));
  try {
    for (const directory of ['tools/build', 'tools/ci', '_maps']) {
      await fs.mkdir(path.join(root, directory), { recursive: true });
    }
    await Promise.all([
      Bun.write(path.join(root, 'tgstation.dme'), '// fixture\n'),
      Bun.write(
        path.join(root, 'dependencies.sh'),
        [
          'export BYOND_MAJOR=516',
          'export BYOND_MINOR=1687',
          'export BUN_VERSION=1.3.5',
          'export PYTHON_VERSION=3.11.0',
          'export CUTTER_VERSION=v5.0.1',
        ].join('\n'),
      ),
      Bun.write(
        path.join(root, 'BUILD.cmd'),
        '@echo off\r\ncall "%~dp0\\tools\\build\\build.bat" --wait-on-error build %*\r\n',
      ),
      Bun.write(path.join(root, 'tools/build/build.bat'), '@echo off\r\n'),
      Bun.write(path.join(root, 'tools/build/build.ts'), 'export {};\n'),
      Bun.write(path.join(root, 'tools/ci/ci_config.txt'), 'CI config'),
      Bun.write(path.join(root, '_maps/metastation.json'), '{}\n'),
    ]);
    const repository = await qualifyRepository(root);
    const { runId, runDir } = await allocateRun(repository.runsRoot);
    const recorder = await RunRecorder.create({
      runDir,
      runId,
      command: options.workflow ?? 'test',
      profile: 'ci',
      evidence:
        options.workflow === 'soak'
          ? 'soak'
          : options.workflow === 'run'
            ? 'boot'
            : 'focused_test',
      networkMode: 'offline',
    });
    const profiles = await loadProfiles(
      path.join(import.meta.dir, 'profiles.json'),
    );
    const profile = structuredClone(profiles.get('ci')!);
    if (options.workflow) profile.artifact_rules = [];
    profile.fatal_log_rules[0].max_occurrences = 99;
    options.configureProfile?.(profile);
    const runner = (spec: ProcessSpec, hooks: ProcessHooks): OwnedProcess => {
      let requestStop!: () => void;
      const stopped = new Promise<void>((resolve) => {
        requestStop = resolve;
      });
      const result = (async (): Promise<ProcessResult> => {
        const startedAt = new Date().toISOString();
        await hooks.onStart(12345);
        if (spec.role === options.supervisionFailureRole) {
          throw new ProcessSupervisionError(
            new Error('snapshot unavailable'),
            new Error('cleanup unverified'),
          );
        }
        if (spec.role === 'build_contract') {
          await hooks.onOutput('stdout', 'icon-cutter');
        } else if (spec.role === 'dreammaker') {
          const base = spec.args.at(-1)!.slice(0, -4);
          await Bun.write(`${base}.dmb`, 'fixture dmb');
          await Bun.write(`${base}.rsc`, 'fixture rsc');
          await hooks.onOutput('stdout', '0 errors, 0 warnings');
        } else if (spec.role === 'dreamdaemon') {
          const logs = path.join(spec.cwd, 'data/logs/rift');
          await fs.mkdir(logs, { recursive: true });
          await Bun.write(
            path.join(logs, 'runtime.log.json'),
            '{"cat":"runtime","msg":"Initializations complete within 1 second!"}\n',
          );
          if (options.workflow) {
            await stopped;
          } else {
            await Bun.sleep(150);
          }
          if (options.runtimeAfterReadiness) {
            await fs.appendFile(
              path.join(logs, 'runtime.log.json'),
              '{"cat":"runtime","msg":"runtime error: after readiness"}\n',
            );
          }
          await Bun.write(
            path.join(spec.cwd, 'data/unit_tests.json'),
            JSON.stringify(resultDocument(options.results)),
          );
          await Bun.write(path.join(logs, 'clean_run.lk'), 'clean');
          if (options.requiredArtifactContent !== undefined) {
            await Bun.write(
              path.join(spec.cwd, 'data/profile-required.txt'),
              options.requiredArtifactContent,
            );
          }
          if (!options.workflow) await Bun.sleep(150);
        }
        const completed: ProcessResult = {
          role: spec.role,
          rootPid: 12345,
          ownedPids: [12345],
          exitCode: 0,
          signal: null,
          termination: 'natural',
          startedAt,
          finishedAt: new Date().toISOString(),
          durationMs: 1,
        };
        await hooks.onFinish?.(completed);
        return completed;
      })();
      return {
        rootPid: 12345,
        result,
        stop: async () => {
          requestStop();
          return result;
        },
        snapshot: async () => options.childSnapshots?.() ?? [],
        ownedPids: () => [12345],
      };
    };
    const command = parseCli(
      options.workflow
        ? [
            options.workflow,
            '--compile-mode',
            'fast',
            '--run-seconds',
            options.workflow === 'run' ? '1' : '30',
          ]
        : [
            'test',
            '--profile',
            'ci',
            ...(options.focus ?? []).flatMap((name) => ['--focus', name]),
            ...(options.minimum === undefined
              ? []
              : ['--minimum-tests', String(options.minimum)]),
          ],
    );
    if (!['run', 'soak', 'test'].includes(command.command)) {
      throw new Error('fixture command is not test');
    }
    let virtualTime = 0;
    const context: WorkflowContext = {
      repository,
      pins: {
        BYOND_MAJOR: '516',
        BYOND_MINOR: '1687',
        BUN_VERSION: '1.3.5',
        PYTHON_VERSION: '3.11.0',
        CUTTER_VERSION: 'v5.0.1',
      },
      byond: {
        dm: 'fixture-dm.exe',
        dreamDaemon: 'fixture-dd.exe',
        version: '516.1687',
        source: 'DM_EXE',
      },
      pinnedPython: 'fixture-python.exe',
      profileName: 'ci',
      profile,
      profiles,
      recorder,
      runId,
      runDir,
      environment: {},
      networkMode: 'offline',
      processRunner: runner,
      buildProcessRunner: runner,
      serverPort: 1444,
      now: () => virtualTime,
      sleep: async (milliseconds) => {
        virtualTime += milliseconds;
      },
      lock: {
        path: '',
        record: {
          schema_version: 1,
          token: 'fixture',
          pid: process.pid,
          command: options.workflow ?? 'test',
          run_id: runId,
          started_at: new Date().toISOString(),
        },
        release: async () => {},
      },
    };
    if (command.command === 'run') {
      return await runServerWorkflow(context, command);
    }
    if (command.command === 'soak') {
      return await runSoakWorkflow(context, command);
    }
    if (command.command === 'test') {
      return await runTestWorkflow(context, command);
    }
    throw new Error('unsupported fixture workflow');
  } finally {
    await fs.rm(root, { recursive: true, force: true });
  }
};
