import { describe, expect, setDefaultTimeout, test } from 'bun:test';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';

setDefaultTimeout(30_000);

const withLauncher = async (
  action: (root: string, parent: string) => Promise<void>,
  suffix = '',
) => {
  const parent = await fs.mkdtemp(path.join(os.tmpdir(), 'rift-launcher-'));
  const root = path.join(parent, `checkout with & spaces${suffix}`);
  try {
    await fs.mkdir(path.join(root, 'tools', 'rift'), { recursive: true });
    const bunRoot = path.join(root, 'cache', 'bun-v1.3.5-x64');
    await fs.mkdir(bunRoot, { recursive: true });
    await fs.mkdir(path.join(root, 'tools', 'bootstrap'), { recursive: true });
    await fs.copyFile(process.execPath, path.join(bunRoot, 'bun.exe'));
    for (const launcher of ['RIFT.cmd', 'RIFT_BUILD.cmd']) {
      await fs.copyFile(
        path.join(import.meta.dir, '..', '..', launcher),
        path.join(root, launcher),
      );
    }
    await Bun.write(
      path.join(root, 'dependencies.sh'),
      'export BUN_VERSION=1.3.5\n',
    );
    await Bun.write(
      path.join(root, 'tools', 'rift', 'rift.ts'),
      'console.log(JSON.stringify(Bun.argv.slice(2))); process.exit(Number(process.env.FIXTURE_EXIT ?? 0));\n',
    );
    await Bun.write(
      path.join(root, 'tools', 'bootstrap', 'javascript.bat'),
      '@echo off\r\necho bootstrap-invoked\r\nexit /b 7\r\n',
    );
    await action(root, parent);
  } finally {
    await fs.rm(parent, { recursive: true, force: true });
  }
};

const runLauncher = async (
  root: string,
  cwd: string,
  args: string[],
  environment: Record<string, string> = {},
  launcher = 'RIFT.cmd',
  delayedExpansion = false,
) => {
  const command = `""${delayedExpansion ? launcher : path.join(root, launcher)}" ${args.map((arg) => `"${arg}"`).join(' ')}"`;
  const child = Bun.spawn(
    [
      'cmd.exe',
      '/d',
      ...(delayedExpansion ? ['/v:on'] : []),
      '/s',
      '/c',
      command,
    ],
    {
      cwd,
      env: {
        ...process.env,
        MERIDIAN_RIFT_BUILD_NETWORK: 'offline',
        TG_BOOTSTRAP_CACHE: path.join(root, 'cache'),
        ...environment,
      },
      windowsVerbatimArguments: true,
      stdout: 'pipe',
      stderr: 'pipe',
    },
  );
  const [exitCode, stdout, stderr] = await Promise.all([
    child.exited,
    new Response(child.stdout).text(),
    new Response(child.stderr).text(),
  ]);
  return { exitCode, stdout, stderr };
};

describe.skipIf(process.platform !== 'win32')('Windows launcher audit', () => {
  test('propagates bootstrap failure through both entry points', async () => {
    await withLauncher(async (root, parent) => {
      for (const launcher of ['RIFT.cmd', 'RIFT_BUILD.cmd']) {
        const result = await runLauncher(
          root,
          parent,
          [],
          { MERIDIAN_RIFT_BUILD_NETWORK: 'allow' },
          launcher,
        );
        expect(result.stdout).toContain('bootstrap-invoked');
        expect(result.exitCode).toBe(7);
      }
    });
  });

  test('resolves a relative bootstrap cache from the checkout when invoked elsewhere', async () => {
    await withLauncher(async (root, parent) => {
      const result = await runLauncher(root, parent, ['doctor'], {
        TG_BOOTSTRAP_CACHE: 'cache',
        FIXTURE_EXIT: '9',
      });
      expect(result.stdout.trim()).toBe('["doctor"]');
      expect(result.exitCode).toBe(9);
    });
  });

  test('rejects an invalid equals network option before invoking bootstrap', async () => {
    await withLauncher(async (root, parent) => {
      const result = await runLauncher(
        root,
        parent,
        ['doctor', '--network=invalid'],
        { MERIDIAN_RIFT_BUILD_NETWORK: 'allow' },
      );
      expect(result.stdout).not.toContain('bootstrap-invoked');
      expect(result.exitCode).toBe(2);
    });
  });

  test('preserves percent literals and quoted metacharacters while inspecting options', async () => {
    await withLauncher(async (root, parent) => {
      const args = [
        'run',
        '--map',
        '_maps/100%RIFT_UNDEFINED% & (Station)!.json',
      ];
      const result = await runLauncher(root, parent, args);
      expect(result.exitCode).toBe(0);
      expect(JSON.parse(result.stdout.trim())).toEqual(args);
    });
  });

  test('compatibility launcher preserves exclamation marks with caller delayed expansion enabled', async () => {
    await withLauncher(async (root) => {
      const result = await runLauncher(
        root,
        root,
        [],
        {},
        'RIFT_BUILD.cmd',
        true,
      );
      expect(result.exitCode).toBe(0);
      expect(JSON.parse(result.stdout.trim())).toEqual([
        'compile',
        '--mode',
        'full',
        '--format',
        'result',
      ]);
    }, '!');
  });
});
