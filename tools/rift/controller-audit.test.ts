import { expect, setDefaultTimeout, spyOn, test } from 'bun:test';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import type { OwnedProcess, ProcessResult, ProcessSpec } from './process';
import { RunRecorder } from './report';
import {
  acquireRunLock,
  allocateRun,
  type CompileRequest,
  compileFull,
  loadProfiles,
  parseProfileDocument,
  qualifyRepository,
  resolveByond,
  waitForReadiness,
  waitForTestCompletion,
  watchGameLogs,
} from './rift';

setDefaultTimeout(30_000);

const temporary = async (action: (root: string) => Promise<void>) => {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'rift-audit-'));
  try {
    await action(root);
  } finally {
    await fs.rm(root, { recursive: true, force: true });
  }
};

test('full build uses the qualified compiler and forwards profile defines', async () => {
  await temporary(async (root) => {
    await fs.mkdir(path.join(root, 'tools/build'), { recursive: true });
    for (const [file, content] of Object.entries({
      'tgstation.dme': '',
      'dependencies.sh': '',
      'BUILD.cmd':
        '@echo off\ncall "%~dp0\\tools\\build\\build.bat" --wait-on-error build %*\n',
      'tools/build/build.bat': '',
      'tools/build/build.ts': '',
    }))
      await Bun.write(path.join(root, file), content);
    const repository = await qualifyRepository(root);
    const { runId, runDir } = await allocateRun(repository.runsRoot);
    const recorder = await RunRecorder.create({
      runId,
      runDir,
      command: 'compile',
      profile: 'default',
      evidence: 'full_build',
      networkMode: 'offline',
    });
    const source = path.join(root, 'modular_aphelion/module.dm');
    await Bun.write(source, 'first revision');
    let actual: ProcessSpec | undefined;
    const request: CompileRequest & { force: boolean } = {
      runId,
      repository,
      recorder,
      force: false,
      byond: {
        dm: 'qualified-dm.exe',
        dreamDaemon: 'dreamdaemon.exe',
        version: '516.1687',
        source: 'DM_EXE',
      },
      environment: { DM_EXE: 'outdated-dm.exe,qualified-dm.exe' },
      defines: ['ALL_MAPS'],
      wallTimeoutMs: 1000,
      idleTimeoutMs: 1000,
      buildProcessRunner: (spec) => {
        actual = spec;
        const result = (async (): Promise<ProcessResult> => {
          if (!(await Bun.file(path.join(root, 'tgstation.dmb')).exists())) {
            await Bun.write(
              path.join(root, 'tgstation.dmb'),
              await Bun.file(source).text(),
            );
            await Bun.write(path.join(root, 'tgstation.rsc'), 'new rsc');
          }
          return {
            role: spec.role,
            rootPid: 1,
            ownedPids: [1],
            exitCode: 0,
            signal: null,
            termination: 'natural',
            startedAt: new Date().toISOString(),
            finishedAt: new Date().toISOString(),
            durationMs: 0,
          };
        })();
        return {
          rootPid: 1,
          result,
          stop: async () => result,
          snapshot: async () => [],
          ownedPids: () => [1],
        };
      },
    };
    await compileFull(request);
    expect(actual?.env.DM_EXE).toBe('qualified-dm.exe');
    expect(actual?.args.slice(-2)).toEqual(['build', '-DALL_MAPS']);
    expect((await compileFull(request)).reused).toBe(true);
    await Bun.write(source, 'second revision');
    const changed = await compileFull(request);
    expect(changed.reused).toBe(false);
    expect(await Bun.file(changed.dmb).text()).toBe('second revision');
  });
});

test('log monitoring reads fatal rules in files other than the readiness log', async () => {
  await temporary(async (root) => {
    const profile = (await loadProfiles('tools/rift/profiles.json')).get(
      'default',
    )!;
    profile.fatal_log_rules.push({
      ...profile.fatal_log_rules[0],
      id: 'service_failed',
      file: 'data/service.log.json',
      message_pattern: 'service failed',
    });
    await Bun.write(
      path.join(root, profile.readiness_rule.file),
      '{"cat":"runtime","msg":"Initializations complete within 1 second"}\n',
    );
    await Bun.write(
      path.join(root, 'data/service.log.json'),
      '{"cat":"runtime","msg":"service failed"}\n',
    );
    const abort = new AbortController();
    const timer = setTimeout(() => abort.abort(), 150);
    const records = [];
    try {
      for await (const item of watchGameLogs({
        deployment: {
          root,
          data: path.join(root, 'data'),
          gameLogDir: path.join(root, 'data/logs/rift'),
          dmb: '',
          rsc: '',
        },
        profile,
        signal: abort.signal,
      }))
        records.push(item);
    } finally {
      clearTimeout(timer);
    }
    expect(records.map((item) => item.record.msg)).toContain('service failed');
    expect(records[0].batchComplete).toBe(false);
  });
});

test('profile paths reject drive-relative paths and terminal traversal', async () => {
  for (const unsafe of ['C:outside.json', 'data/..']) {
    const document = await Bun.file('tools/rift/profiles.json').json();
    document.profiles.default.readiness_rule.file = unsafe;
    expect(() => parseProfileDocument(JSON.stringify(document))).toThrow(
      'unsafe profile path',
    );
  }
});

test('profile rules reject duplicate counter identities', async () => {
  const document = await Bun.file('tools/rift/profiles.json').json();
  document.profiles.default.fatal_log_rules.push({
    ...document.profiles.default.fatal_log_rules[0],
  });
  expect(() => parseProfileDocument(JSON.stringify(document))).toThrow(
    'duplicate',
  );
});

test('readiness paths can contain plain text logs', async () => {
  await temporary(async (root) => {
    const profile = (await loadProfiles('tools/rift/profiles.json')).get(
      'default',
    )!;
    profile.readiness_rule.file = 'data/ready.log';
    await Bun.write(
      path.join(root, 'data/ready.log'),
      'Initializations complete within 1 second\n',
    );
    const records = await Array.fromAsync(
      watchGameLogs({
        deployment: {
          root,
          data: path.join(root, 'data'),
          gameLogDir: path.join(root, 'data/logs/rift'),
          dmb: '',
          rsc: '',
        },
        profile,
        once: true,
      }),
    );
    expect(records[0]?.record.msg).toBe(
      'Initializations complete within 1 second',
    );
  });
});

test('BYOND registry resolution reads the named installpath value', async () => {
  await temporary(async (root) => {
    await Bun.write(path.join(root, 'bin/dm.exe'), 'fixture');
    await Bun.write(path.join(root, 'bin/dreamdaemon.exe'), 'fixture');
    const result = await resolveByond(
      { root } as Awaited<ReturnType<typeof qualifyRepository>>,
      {
        BYOND_MAJOR: '516',
        BYOND_MINOR: '1687',
        BUN_VERSION: '1.3.5',
        PYTHON_VERSION: '3.11.0',
        CUTTER_VERSION: 'v5.0.1',
      },
      async (executable, args) => {
        if (
          executable === 'reg.exe' &&
          args.slice(-2).join(' ') === '/v installpath'
        )
          return {
            exitCode: 0,
            stdout: `installpath REG_SZ ${root}`,
            stderr: '',
          };
        if (executable === path.join(root, 'bin/dm.exe'))
          return {
            exitCode: 0,
            stdout: 'DM compiler version 516.1687',
            stderr: '',
          };
        return { exitCode: 1, stdout: '', stderr: '' };
      },
      {},
    );
    expect(result.source).toBe('registry');
  });
});

test('a contender cannot reap a lock while its owner is publishing it', async () => {
  await temporary(async (root) => {
    const originalOpen = fs.open.bind(fs);
    let signalWriting!: () => void;
    const writing = new Promise<void>((resolve) => {
      signalWriting = resolve;
    });
    let delayed = false;
    const open = spyOn(fs, 'open').mockImplementation(async (...args) => {
      const handle = await originalOpen(...args);
      if (
        !delayed &&
        String(args[0]).includes('.active.lock') &&
        args[1] === 'wx'
      ) {
        delayed = true;
        const writeFile = handle.writeFile.bind(handle);
        handle.writeFile = async (...writeArgs) => {
          signalWriting();
          await Bun.sleep(100);
          return writeFile(...writeArgs);
        };
      }
      return handle;
    });
    const outcomes: Awaited<ReturnType<typeof acquireRunLock>>[] = [];
    try {
      const first = acquireRunLock(root, 'compile', 'first', 0);
      await writing;
      const results = await Promise.allSettled([
        first,
        acquireRunLock(root, 'compile', 'second', 0),
      ]);
      for (const result of results)
        if (result.status === 'fulfilled') outcomes.push(result.value);
      expect(outcomes).toHaveLength(1);
    } finally {
      open.mockRestore();
      for (const lock of outcomes) await lock.release();
    }
  });
});

test('cancellation interrupts lock waiting before the lock deadline', async () => {
  await temporary(async (root) => {
    const lock = await acquireRunLock(root, 'compile', 'owner', 0);
    let cancelled = false;
    const timer = setTimeout(() => {
      cancelled = true;
    }, 20);
    try {
      await expect(
        acquireRunLock(
          root,
          'test',
          'waiting',
          1,
          () => true,
          () => cancelled,
        ),
      ).rejects.toMatchObject({ exitCode: 130 });
    } finally {
      clearTimeout(timer);
      await lock.release();
    }
  });
});

test('completion drains the final runtime record without requiring a newline', async () => {
  await temporary(async (root) => {
    const profile = (await loadProfiles('tools/rift/profiles.json')).get('ci')!;
    const deployment = {
      root,
      data: path.join(root, 'data'),
      gameLogDir: path.join(root, 'data/logs/rift'),
      dmb: '',
      rsc: '',
    };
    const log = path.join(root, profile.readiness_rule.file);
    await Bun.write(
      log,
      '{"cat":"runtime","msg":"Initializations complete within 1 second"}\n',
    );
    const recorder = await RunRecorder.create({
      runId: '20260905T000000Z-1234abcd',
      runDir: root,
      command: 'test',
      profile: 'ci',
      evidence: 'focused_test',
      networkMode: 'offline',
    });
    let finish!: (result: ProcessResult) => void;
    const result = new Promise<ProcessResult>((resolve) => {
      finish = resolve;
    });
    const process: OwnedProcess = {
      rootPid: 1,
      result,
      stop: async () => result,
      snapshot: async () => [],
      ownedPids: () => [1],
    };
    const readiness = await waitForReadiness({
      deployment,
      profile,
      process,
      recorder,
      timeoutMs: 1000,
    });
    await fs.appendFile(
      log,
      '{"cat":"runtime","msg":"runtime error: last record"}',
    );
    finish({
      role: 'dreamdaemon',
      rootPid: 1,
      ownedPids: [1],
      exitCode: 0,
      signal: null,
      termination: 'natural',
      startedAt: new Date().toISOString(),
      finishedAt: new Date().toISOString(),
      durationMs: 1,
    });
    await expect(
      waitForTestCompletion({
        deployment,
        profile,
        process,
        recorder,
        readiness,
      }),
    ).rejects.toThrow('runtime_error');
  });
});
