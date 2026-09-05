import { describe, expect, test } from 'bun:test';
import { runEvidenceFixture } from './workflow-evidence.fixture';

const focus = '/datum/unit_test/requested';
const unrelated = '/datum/unit_test/unrelated';

describe('unit test evidence acceptance', () => {
  for (const role of ['dreammaker', 'dreamdaemon'] as const) {
    test(`records unverified ${role} cleanup as a failed gate`, async () => {
      const summary = await runEvidenceFixture({
        results: [[focus, 0]],
        supervisionFailureRole: role,
      });
      expect(summary.status).toBe('failed');
      expect(summary.exit_code).toBe(5);
      expect(summary.cleanup.passed).toBe(false);
    });
  }

  test('rejects skipped-only results while preserving skip counts', async () => {
    const summary = await runEvidenceFixture({ results: [[unrelated, 2]] });
    expect(summary.status).toBe('failed');
    expect(summary.tests).toEqual({
      recorded: 1,
      passed: 0,
      failed: 0,
      skipped: 1,
    });
    expect(summary.failures[0].message).toContain(
      'unit_test_count_below_minimum',
    );
  });

  test('requires every requested focus even when unrelated passes satisfy the count', async () => {
    const summary = await runEvidenceFixture({
      results: [[unrelated, 0]],
      focus: [focus],
    });
    expect(summary.status).toBe('failed');
    expect(summary.failures[0].message).toContain('unit_test_focus_missing');
  });

  test('rejects skipped focus even when another test passes', async () => {
    const summary = await runEvidenceFixture({
      results: [
        [focus, 2],
        [unrelated, 0],
      ],
      focus: [focus],
    });
    expect(summary.status).toBe('failed');
    expect(summary.failures[0].message).toContain('unit_test_focus_skipped');
  });

  test('minimum count includes passes but excludes skips', async () => {
    const summary = await runEvidenceFixture({
      results: [
        [focus, 0],
        [unrelated, 2],
      ],
      minimum: 2,
    });
    expect(summary.status).toBe('failed');
    expect(summary.failures[0].message).toContain(
      'unit_test_count_below_minimum',
    );
  });

  test('rejects a post-readiness runtime below the configured fatal threshold', async () => {
    const summary = await runEvidenceFixture({
      results: [[focus, 0]],
      focus: [focus],
      runtimeAfterReadiness: true,
    });
    expect(summary.status).toBe('failed');
    expect(summary.failures[0].message).toContain('runtime_error');
    expect(summary.runtime_signatures).toHaveLength(1);
  });

  test('accepts completed requested focus and retains unrelated skip counts', async () => {
    const summary = await runEvidenceFixture({
      results: [
        [focus, 0],
        [unrelated, 2],
      ],
      focus: [focus],
    });
    expect(summary.status).toBe('passed');
    expect(summary.tests).toEqual({
      recorded: 2,
      passed: 1,
      failed: 0,
      skipped: 1,
    });
  });
});
