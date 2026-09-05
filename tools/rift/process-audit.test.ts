import { describe, expect, spyOn, test } from 'bun:test';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {
  runProbeProcess,
  snapshotDescendants,
  startOwnedProcess,
  stopOwnedProcessTree,
} from './process';
import { RunRecorder } from './report';

const identity = {
  pid: process.pid,
  parentPid: null,
  name: 'fixture.exe',
  creationTime: '2026-09-05T00:00:00.0000000Z',
};
const row = {
  ProcessId: identity.pid,
  ParentProcessId: 0,
  Name: identity.name,
  CreationTime: identity.creationTime,
};

const response = (stdout = '', exitCode = 0, stderr = '') => ({
  stdout: new Blob([stdout]).stream(),
  stderr: new Blob([stderr]).stream(),
  exited: Promise.resolve(exitCode),
  kill: () => {},
});

const spec = {
  role: 'fixture',
  executable: 'fixture.exe',
  args: [],
  cwd: process.cwd(),
  env: {},
  wallTimeoutMs: 1_000,
  idleTimeoutMs: 1_000,
};
const hooks = {
  onStart: async () => {},
  onOwnedPids: async () => {},
  onSample: async () => {},
  onOutput: async () => {},
};

describe('process audit regressions', () => {
  test('cleanup succeeds when every verified process already exited', async () => {
    const nativeSpawn = Bun.spawn;
    const spawn = spyOn(Bun, 'spawn').mockImplementation(
      (options: any): any => {
        const program = Buffer.from(options.cmd.at(-1), 'base64').toString(
          'utf16le',
        );
        return program.includes('$expected =')
          ? nativeSpawn(options)
          : response('[]');
      },
    );
    const exitedIdentity = { ...identity, pid: 2_147_483_000 };
    try {
      await expect(
        stopOwnedProcessTree(
          exitedIdentity.pid,
          [exitedIdentity.pid],
          undefined,
          new Map([[exitedIdentity.pid, exitedIdentity]]),
        ),
      ).resolves.toBeUndefined();
    } finally {
      spawn.mockRestore();
    }
  });

  test('records descendants discovered only during final cleanup', async () => {
    let rootExit!: (code: number) => void;
    let rootAlive = true;
    let stopped = false;
    const exited = new Promise<number>((resolve) => {
      rootExit = resolve;
    });
    const spawn = spyOn(Bun, 'spawn').mockImplementation(
      (options: any): any => {
        if (options.cmd[0] === 'fixture.exe') {
          return { ...response(), pid: identity.pid, exited };
        }
        const program = Buffer.from(options.cmd.at(-1), 'base64').toString(
          'utf16le',
        );
        if (program.includes('$expected =')) {
          stopped = true;
          return response();
        }
        if (program.includes('RIFT_PROCESS_IDS')) return response('[]');
        return response(
          JSON.stringify(
            stopped
              ? []
              : [
                  ...(rootAlive ? [row] : []),
                  { ...row, ProcessId: 900_002, ParentProcessId: identity.pid },
                  ...(!rootAlive
                    ? [{ ...row, ProcessId: 900_004, ParentProcessId: 900_002 }]
                    : []),
                ],
          ),
        );
      },
    );
    try {
      const result = await startOwnedProcess(spec, {
        ...hooks,
        onSample: async () => {
          rootAlive = false;
          rootExit(0);
        },
      }).result;
      expect(result.ownedPids).toContain(900_004);
    } finally {
      spawn.mockRestore();
    }
  });

  test('cleanup kills the verified process object instead of a reused PID', async () => {
    const runDir = await fs.mkdtemp(path.join(os.tmpdir(), 'rift-stop-audit-'));
    const resultPath = path.join(runDir, 'target.txt');
    const nativeSpawn = Bun.spawn;
    let stopped = false;
    const spawn = spyOn(Bun, 'spawn').mockImplementation(
      (options: any): any => {
        const program = Buffer.from(options.cmd.at(-1), 'base64').toString(
          'utf16le',
        );
        if (program.includes('$expected =')) {
          const fixture = `
function Get-CimInstance {
  [pscustomobject]@{ ProcessId = ${identity.pid}; Name = 'fixture.exe'; CreationDate = [datetime]'2026-09-05T00:00:00Z' }
}
function Get-Process {
  [CmdletBinding()] param([int]$Id)
  [pscustomobject]@{ ProcessName = 'fixture'; StartTime = [datetime]'2026-09-05T00:00:00Z'; SafeHandle = 1 }
}
function Stop-Process {
  [CmdletBinding()] param([int]$Id, [object]$InputObject, [switch]$Force)
  $targetLabel = if ($null -ne $InputObject) { 'original' } else { 'reused' }
  Set-Content -LiteralPath $env:RIFT_AUDIT_RESULT -Value $targetLabel
}
`;
          stopped = true;
          return nativeSpawn({
            ...options,
            cmd: [
              ...options.cmd.slice(0, -1),
              Buffer.from(fixture + program, 'utf16le').toString('base64'),
            ],
            env: { ...options.env, RIFT_AUDIT_RESULT: resultPath },
          });
        }
        return response(
          program.includes('RIFT_PROCESS_IDS')
            ? '[]'
            : JSON.stringify(stopped ? [] : [row]),
        );
      },
    );
    try {
      await stopOwnedProcessTree(
        identity.pid,
        [identity.pid],
        undefined,
        new Map([[identity.pid, identity]]),
      );
      expect((await Bun.file(resultPath).text()).trim()).toBe('original');
    } finally {
      spawn.mockRestore();
      await fs.rm(runDir, { recursive: true, force: true });
    }
  });

  test('probe output limits apply before an unterminated line is buffered', async () => {
    let rootExit!: (code: number) => void;
    let killed = false;
    const exited = new Promise<number>((resolve) => {
      rootExit = resolve;
    });
    let outputController!: ReadableStreamDefaultController<Uint8Array>;
    const output = new ReadableStream<Uint8Array>({
      start(controller) {
        outputController = controller;
        controller.enqueue(new Uint8Array(1024 * 1024 + 1).fill(65));
      },
    });
    const spawn = spyOn(Bun, 'spawn').mockImplementation(
      (options: any): any => {
        if (options.cmd[0] === 'fixture.exe') {
          return {
            ...response(),
            stdout: output,
            pid: identity.pid,
            exited,
            kill: () => {
              killed = true;
              outputController.close();
              rootExit(1);
            },
          };
        }
        const program = Buffer.from(options.cmd.at(-1), 'base64').toString(
          'utf16le',
        );
        return response(
          program.includes('RIFT_PROCESS_IDS') ||
            program.includes('$expected =')
            ? '[]'
            : JSON.stringify(killed ? [] : [row]),
        );
      },
    );
    let timer: ReturnType<typeof setTimeout> | undefined;
    try {
      const probe = runProbeProcess('fixture.exe', [], process.cwd(), {});
      const outcome = await Promise.race([
        probe.then(
          () => 'resolved',
          (error) => String(error),
        ),
        new Promise<string>((resolve) => {
          timer = setTimeout(() => resolve('unbounded'), 200);
        }),
      ]);
      if (outcome === 'unbounded') {
        outputController.close();
        rootExit(0);
        await probe.catch(() => undefined);
      }
      expect(outcome).toContain('exceeded');
    } finally {
      clearTimeout(timer);
      spawn.mockRestore();
    }
  });

  test('terminates promptly when an output consumer fails', async () => {
    let rootExit!: (code: number) => void;
    let killed = false;
    const exited = new Promise<number>((resolve) => {
      rootExit = resolve;
    });
    const spawn = spyOn(Bun, 'spawn').mockImplementation(
      (options: any): any => {
        if (options.cmd[0] === 'fixture.exe') {
          return {
            ...response('fail\n'),
            pid: identity.pid,
            exited,
            kill: () => {
              killed = true;
              rootExit(1);
            },
          };
        }
        const program = Buffer.from(options.cmd.at(-1), 'base64').toString(
          'utf16le',
        );
        return response(
          program.includes('RIFT_PROCESS_IDS') ||
            program.includes('$expected =')
            ? '[]'
            : JSON.stringify(killed ? [] : [row]),
        );
      },
    );
    try {
      const startedAt = Date.now();
      await expect(
        startOwnedProcess(spec, {
          ...hooks,
          onOutput: async () => {
            throw new Error('output sink failed');
          },
        }).result,
      ).rejects.toThrow('output sink failed');
      expect(Date.now() - startedAt).toBeLessThan(500);
    } finally {
      spawn.mockRestore();
    }
  });

  test('allows a slow successful ownership query under compile load', async () => {
    const spawn = spyOn(Bun, 'spawn').mockImplementation((): any => ({
      ...response('[]'),
      exited: Bun.sleep(6_000).then(() => 0),
    }));
    try {
      await expect(snapshotDescendants(identity.pid)).resolves.toEqual([]);
    } finally {
      spawn.mockRestore();
    }
  }, 20_000);

  test('bounds a hung PowerShell ownership query', async () => {
    let killed = false;
    const spawn = spyOn(Bun, 'spawn').mockImplementation((): any => ({
      ...response(),
      exited: new Promise(() => {}),
      kill: () => {
        killed = true;
      },
    }));
    let timer: ReturnType<typeof setTimeout> | undefined;
    try {
      const outcome = await Promise.race([
        snapshotDescendants(identity.pid).then(
          () => 'resolved',
          (error) => String(error),
        ),
        new Promise<string>((resolve) => {
          timer = setTimeout(() => resolve('unbounded'), 16_000);
        }),
      ]);
      expect(outcome).toContain('timed out');
      expect(killed).toBe(true);
    } finally {
      clearTimeout(timer);
      spawn.mockRestore();
    }
  }, 20_000);

  test('does not adopt descendants of a reused root PID', async () => {
    const spawn = spyOn(Bun, 'spawn').mockImplementation(
      (options: any): any => {
        const program = Buffer.from(options.cmd.at(-1), 'base64').toString(
          'utf16le',
        );
        return response(
          program.includes('RIFT_PROCESS_IDS')
            ? '[]'
            : JSON.stringify([
                { ...row, CreationTime: '2026-09-05T01:00:00.0000000Z' },
                { ...row, ProcessId: 900_002, ParentProcessId: identity.pid },
              ]),
        );
      },
    );
    try {
      const samples = await snapshotDescendants(
        identity.pid,
        'fixture',
        new Map([[identity.pid, identity]]),
      );
      expect(samples).toEqual([]);
    } finally {
      spawn.mockRestore();
    }
  });

  test('keeps tracking owned descendants whose intermediate parent exited', async () => {
    const childIdentity = { ...identity, pid: 900_002, parentPid: 900_003 };
    const spawn = spyOn(Bun, 'spawn').mockImplementation(
      (options: any): any => {
        const program = Buffer.from(options.cmd.at(-1), 'base64').toString(
          'utf16le',
        );
        return response(
          program.includes('RIFT_PROCESS_IDS')
            ? '[]'
            : JSON.stringify([
                { ...row, ProcessId: 900_002, ParentProcessId: 900_003 },
                { ...row, ProcessId: 900_004, ParentProcessId: 900_002 },
              ]),
        );
      },
    );
    try {
      const samples = await snapshotDescendants(
        identity.pid,
        'fixture',
        new Map([
          [identity.pid, identity],
          [childIdentity.pid, childIdentity],
        ]),
      );
      expect(samples.map(({ pid }) => pid)).toEqual([900_002, 900_004]);
    } finally {
      spawn.mockRestore();
    }
  });

  test('rejects a run when ownership snapshots are unavailable', async () => {
    const spawn = spyOn(Bun, 'spawn').mockImplementation(
      (options: any): any => {
        if (options.cmd[0] === 'fixture.exe') {
          return { ...response(), pid: identity.pid };
        }
        return response('', 1, 'CIM unavailable');
      },
    );
    try {
      await expect(startOwnedProcess(spec, hooks).result).rejects.toThrow(
        'process snapshot failed',
      );
    } finally {
      spawn.mockRestore();
    }
  });

  test('does not certify cleanup when its final process query fails', async () => {
    let tableReads = 0;
    const spawn = spyOn(Bun, 'spawn').mockImplementation(
      (options: any): any => {
        const program = Buffer.from(options.cmd.at(-1), 'base64').toString(
          'utf16le',
        );
        if (program.includes('$expected =')) {
          return response();
        }
        if (program.includes('RIFT_PROCESS_IDS')) {
          return response('[]');
        }
        tableReads += 1;
        return tableReads === 1
          ? response(JSON.stringify([row]))
          : response('', 1, 'CIM unavailable');
      },
    );
    try {
      await expect(
        stopOwnedProcessTree(
          identity.pid,
          [identity.pid],
          undefined,
          new Map([[identity.pid, identity]]),
        ),
      ).rejects.toThrow('process snapshot failed');
    } finally {
      spawn.mockRestore();
    }
  });

  test('cleans descendants before draining pipes after natural root exit', async () => {
    let closeOutput!: () => void;
    let rootExit!: (code: number) => void;
    let stopped = false;
    let rootAlive = true;
    const output = new ReadableStream<Uint8Array>({
      start(controller) {
        closeOutput = () => controller.close();
      },
    });
    const exited = new Promise<number>((resolve) => {
      rootExit = resolve;
    });
    const spawn = spyOn(Bun, 'spawn').mockImplementation(
      (options: any): any => {
        if (options.cmd[0] === 'fixture.exe') {
          return { ...response(), pid: identity.pid, stdout: output, exited };
        }
        const program = Buffer.from(options.cmd.at(-1), 'base64').toString(
          'utf16le',
        );
        if (program.includes('$expected =')) {
          stopped = true;
          closeOutput();
          return response();
        }
        if (program.includes('RIFT_PROCESS_IDS')) {
          return response('[]');
        }
        return response(
          JSON.stringify(
            stopped
              ? []
              : [
                  ...(rootAlive ? [row] : []),
                  { ...row, ProcessId: 900_002, ParentProcessId: identity.pid },
                ],
          ),
        );
      },
    );
    let timer: ReturnType<typeof setTimeout> | undefined;
    try {
      const owned = startOwnedProcess(spec, {
        ...hooks,
        onSample: async () => {
          rootAlive = false;
          rootExit(0);
        },
      });
      const completed = await Promise.race([
        owned.result.then(() => true),
        new Promise<boolean>((resolve) => {
          timer = setTimeout(() => resolve(false), 200);
        }),
      ]);
      if (!completed) {
        closeOutput();
        await owned.result;
      }
      expect(completed).toBe(true);
    } finally {
      clearTimeout(timer);
      spawn.mockRestore();
    }
  });
});

test('redacts every summary field and case-insensitive profile path', async () => {
  const runDir = await fs.mkdtemp(path.join(os.tmpdir(), 'rift-report-audit-'));
  try {
    const recorder = await RunRecorder.create({
      runDir,
      runId: 'audit',
      command: 'soak',
      profile: 'default',
      evidence: 'soak',
      networkMode: 'offline',
    });
    await recorder.setToolVersions({
      fixture: 'C:\\Users\\PrivateProfile\\tool',
    });
    await recorder.setRuntimeSignatures([
      { signature: 'C:/users/PrivateProfile/log', count: 1, first_seen: 'now' },
    ]);
    await recorder.setCleanup({
      passed: false,
      leftovers: ['/home/PrivateProfile/file'],
      retained: [],
    });
    const summary = await recorder.finish('failed', 5);
    expect(JSON.stringify(summary)).not.toContain('PrivateProfile');
    expect(
      await Bun.file(path.join(runDir, 'summary.json')).text(),
    ).not.toContain('PrivateProfile');
  } finally {
    await fs.rm(runDir, { recursive: true, force: true });
  }
});
