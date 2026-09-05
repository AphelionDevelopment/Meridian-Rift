import { expect, test } from 'bun:test';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import type { OwnedProcess, ProcessResult } from './process';
import { RunRecorder } from './report';
import {
  acquireRunLock,
  allocateRun,
  loadProfiles,
  parseCli,
  qualifyRepository,
  runServerWorkflow,
  runSoakWorkflow,
  type WorkflowContext,
} from './rift';

const withWorkflow = async (
  action: (context: WorkflowContext) => Promise<void>,
) => {
  const root = await fs.mkdtemp(
    path.join(os.tmpdir(), 'rift-deployment-audit-'),
  );
  try {
    for (const [file, content] of Object.entries({
      'tgstation.dme': '',
      'dependencies.sh': '',
      'BUILD.cmd':
        '@echo off\ncall "%~dp0\\tools\\build\\build.bat" --wait-on-error build %*\n',
      'tools/build/build.bat': '',
      'tools/build/build.ts': '',
      '_maps/metastation.json': '{}',
    }))
      await Bun.write(path.join(root, file), content);
    const repository = await qualifyRepository(root);
    const { runId, runDir } = await allocateRun(repository.runsRoot);
    const profiles = await loadProfiles('tools/rift/profiles.json');
    const profile = profiles.get('default')!;
    const recorder = await RunRecorder.create({
      runId,
      runDir,
      command: 'run',
      profile: 'default',
      evidence: 'boot',
      networkMode: 'offline',
    });
    const lock = await acquireRunLock(repository.runsRoot, 'run', runId, 0);
    const finished = (role: string): ProcessResult => ({
      role,
      rootPid: 1,
      ownedPids: [1],
      exitCode: 0,
      signal: null,
      termination: 'natural',
      startedAt: new Date().toISOString(),
      finishedAt: new Date().toISOString(),
      durationMs: 0,
    });
    await action({
      repository,
      runId,
      runDir,
      recorder,
      lock,
      profile,
      profiles,
      profileName: 'default',
      environment: {},
      networkMode: 'offline',
      pins: {
        BYOND_MAJOR: '516',
        BYOND_MINOR: '1687',
        BUN_VERSION: '1.3.5',
        PYTHON_VERSION: '3.11.0',
        CUTTER_VERSION: 'v5.0.1',
      },
      byond: {
        dm: 'fixture-dm.exe',
        dreamDaemon: 'fixture-dreamdaemon.exe',
        version: '516.1687',
        source: 'DM_EXE',
      },
      pinnedPython: 'fixture-python.exe',
      serverPort: 1339,
      buildProcessRunner: (spec) => {
        const result = (async () => {
          await Bun.write(path.join(root, 'tgstation.dmb'), 'compiled dmb');
          await Bun.write(path.join(root, 'tgstation.rsc'), 'compiled rsc');
          return finished(spec.role);
        })();
        return {
          rootPid: 1,
          result,
          stop: async () => result,
          snapshot: async () => [],
          ownedPids: () => [1],
        };
      },
      processRunner: (spec) => {
        let resolve!: (result: ProcessResult) => void;
        const result = new Promise<ProcessResult>((settle) => {
          resolve = settle;
        });
        const ready = Bun.write(
          path.join(spec.cwd, 'data/logs/rift/runtime.log.json'),
          '{"cat":"runtime","msg":"Initializations complete within 1 second"}\n',
        );
        return {
          rootPid: 1,
          result,
          ownedPids: () => [1],
          snapshot: async () => [],
          stop: async (termination) => {
            await ready;
            const value = { ...finished(spec.role), termination };
            resolve(value);
            return value;
          },
        } satisfies OwnedProcess;
      },
    });
  } finally {
    await fs.rm(root, { recursive: true, force: true });
  }
};

for (const workflow of ['run', 'soak'] as const) {
  test(`${workflow} rejects a runtime emitted at the requested stop`, async () => {
    await withWorkflow(async (context) => {
      let virtualNow = 0;
      context.now = () => virtualNow;
      context.sleep = async (milliseconds) => {
        virtualNow += milliseconds;
      };
      const delegate = context.processRunner!;
      context.processRunner = (spec, hooks) => {
        const owned = delegate(spec, hooks);
        return {
          ...owned,
          stop: async (reason) => {
            const result = await owned.stop(reason);
            await fs.appendFile(
              path.join(spec.cwd, 'data/logs/rift/runtime.log.json'),
              '{"cat":"runtime","msg":"runtime error: stopping"}',
            );
            return result;
          },
        };
      };
      const command = parseCli([
        workflow,
        '--compile-mode',
        'full',
        '--map',
        '_maps/metastation.json',
        ...(workflow === 'soak' ? ['--run-seconds', '30'] : []),
      ]);
      const summary =
        command.command === 'run'
          ? await runServerWorkflow(context, command)
          : command.command === 'soak'
            ? await runSoakWorkflow(context, command)
            : null;
      expect(summary?.status).toBe('failed');
      expect(summary?.runtime_signatures.length).toBe(1);
    });
  });
  for (const keep of [false, true]) {
    test(`${workflow} reports ownership of partial CI deployment with keep=${keep}`, async () => {
      await withWorkflow(async (context) => {
        context.profile.config_source = 'ci';
        const command = parseCli([
          workflow,
          '--compile-mode',
          'full',
          '--map',
          '_maps/metastation.json',
          ...(workflow === 'soak' ? ['--run-seconds', '30'] : []),
          ...(keep ? ['--keep-workspace'] : []),
        ]);
        const summary =
          command.command === 'run'
            ? await runServerWorkflow(context, command)
            : command.command === 'soak'
              ? await runSoakWorkflow(context, command)
              : null;
        expect(summary?.status).toBe('failed');
        expect(summary?.cleanup.retained).toEqual(keep ? ['workspace'] : []);
        expect(
          await fs.stat(path.join(context.runDir, 'workspace')).then(
            () => true,
            () => false,
          ),
        ).toBe(keep);
      });
    });
  }
}

test('soak aborts its log monitor when resource sampling rejects', async () => {
  const controllers: AbortController[] = [];
  const OriginalAbortController = globalThis.AbortController;
  globalThis.AbortController = class extends OriginalAbortController {
    constructor() {
      super();
      controllers.push(this);
    }
  };
  try {
    await withWorkflow(async (context) => {
      const delegate = context.processRunner!;
      context.processRunner = (spec, hooks) => ({
        ...delegate(spec, hooks),
        snapshot: async () => {
          throw new Error('snapshot fixture failure');
        },
      });
      const command = parseCli([
        'soak',
        '--compile-mode',
        'full',
        '--map',
        '_maps/metastation.json',
        '--run-seconds',
        '30',
      ]);
      if (command.command !== 'soak')
        throw new Error('unexpected fixture command');
      const summary = await runSoakWorkflow(context, command);
      expect(summary.status).toBe('failed');
      expect(
        summary.failures.some((failure) =>
          failure.message.includes('snapshot fixture failure'),
        ),
      ).toBe(true);
      expect(controllers.length).toBeGreaterThanOrEqual(2);
      expect(controllers.every((controller) => controller.signal.aborted)).toBe(
        true,
      );
    });
  } finally {
    for (const controller of controllers) controller.abort();
    globalThis.AbortController = OriginalAbortController;
  }
});
