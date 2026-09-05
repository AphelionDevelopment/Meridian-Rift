import { describe, expect, test } from 'bun:test';
import { runEvidenceFixture } from './workflow-evidence.fixture';

describe('profile enforcement across workflows', () => {
  for (const workflow of ['run', 'test'] as const) {
    test(`${workflow} fails when a continuously required child disappears after readiness`, async () => {
      let snapshots = 0;
      const summary = await runEvidenceFixture({
        results: [['/datum/unit_test/requested', 0]],
        workflow: workflow === 'test' ? undefined : workflow,
        configureProfile: (profile) => {
          profile.required_children = [
            {
              role: 'fixture-helper',
              process_name: 'fixture-helper.exe',
              min_count: 1,
              max_count: 1,
              continuous_after_readiness: true,
            },
          ];
        },
        childSnapshots: () =>
          ++snapshots === 1
            ? [
                {
                  pid: 12346,
                  parentPid: 12345,
                  name: 'fixture-helper.exe',
                  role: 'fixture-helper',
                  privateBytes: 0,
                  workingSetBytes: 0,
                },
              ]
            : [],
      });
      expect(summary.status).toBe('failed');
      expect(summary.failures[0].code).toBe('required_child_missing');
      const snapshotsAtReturn = snapshots;
      await Bun.sleep(75);
      expect(snapshots).toBe(snapshotsAtReturn);
      expect(summary.cleanup.passed).toBe(true);
    });
  }

  for (const workflow of ['run', 'soak'] as const) {
    for (const content of [undefined, ''] as const) {
      test(`${workflow} rejects a ${content === undefined ? 'missing' : 'empty'} required artifact`, async () => {
        const summary = await runEvidenceFixture({
          results: [],
          workflow,
          requiredArtifactContent: content,
          configureProfile: (profile) => {
            profile.artifact_rules = [
              {
                id: 'required_fixture',
                path: 'data/profile-required.txt',
                required: true,
                nonempty: true,
              },
            ];
          },
        });
        expect(summary.exit_code).toBe(5);
        expect(summary.failures[0].message).toContain('artifact_missing');
      });
    }

    test(`${workflow} accepts a nonempty required artifact written during shutdown`, async () => {
      const summary = await runEvidenceFixture({
        results: [],
        workflow,
        requiredArtifactContent: 'shutdown completed',
        configureProfile: (profile) => {
          profile.artifact_rules = [
            {
              id: 'required_fixture',
              path: 'data/profile-required.txt',
              required: true,
              nonempty: true,
            },
          ];
        },
      });
      expect(summary.exit_code).toBe(0);
      expect(summary.cleanup.passed).toBe(true);
    });
  }
});
