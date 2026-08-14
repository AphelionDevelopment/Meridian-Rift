/// Generous upper bound for process_active_turfs()'s own wall-clock cost against a ~3800-entry
/// active_turfs list. ACTIVE_TURFS_WALK_BATCH_SIZE (400) should keep the walk itself to a small
/// fraction of this regardless of list size - calibrated against a measured ~10x gap between the
/// bounded and unbounded walk on this same padded list (see the doc comment below), with slack for
/// CI noise the way dogmos_del_cost.dm's own ratio-based bound does.
#define ACTIVE_TURFS_BLOAT_TEST_MAX_MS 15

/**
 * Regression test for the 2026-08-14 playtest finding: turfs became extremely resistant to gas
 * exchange over a long real round (confirmed via tools/dogmos/analyze_round_log.ps1 against the actual
 * round log - SSair.active_turfs grew monotonically from ~1700 to ~3800 turfs over one session, never
 * shrinking, while process_active_turfs()'s own measured MC cost grew from ~15ms to ~22-26ms in lockstep).
 *
 * Root cause: the legacy per-turf walk (archive/current_cycle/temperature_expose) was unconditional
 * over the WHOLE active_turfs list and deliberately un-gated (reasoning at the time: gating it risked
 * starving the FDM call below it - backwards in hindsight), so its own cost scaled directly with list
 * size with no cap. On a real, busy server this repeatedly overran SSair's allotted MC tick share every
 * cycle; the Master Controller responds to a chronically-overrunning subsystem by adaptively shrinking
 * its future ticklimit allocation, compounding the problem over the session - which is why "MC costs"
 * grew rather than merely being briefly high. `remaining_ms` being computed once at proc entry, before
 * the walk ran, is a related but secondary correctness gap (the value can go stale relative to what the
 * walk itself just spent) - not fixed independently here from the primary bound.
 *
 * Asserts a wall-clock cost BOUND, not a gas-movement outcome. An earlier version of this test asserted
 * "did turf_a's oxygen change after a bloated-list call" and passed against BOTH the fixed code and the
 * exact pre-fix code (confirmed via a deliberate revert-and-rerun) - the isolated unit test environment
 * has no other subsystems competing for tick budget, so TICK_USAGE stays low enough all game that even
 * the old unbounded walk never actually starved Rust's FDM call there. The bug is a live-server MC
 * scheduling pathology that a single idle unit test call cannot reproduce by observing outcome alone;
 * what a unit test CAN reliably measure is whether the walk's own cost is actually bounded regardless of
 * list size, which is the real, verifiable content of the fix - see dogmos_del_cost.dm for the existing
 * precedent of a timing-based (not outcome-based) assertion in this suite.
 */
/datum/unit_test/dogmos_active_turfs_bloat

/datum/unit_test/dogmos_active_turfs_bloat/Run()
	var/list/pair = allocate_turf_pair()
	var/turf/open/turf_a = pair[1]
	var/turf/open/turf_b = pair[2]

	// Simulate a bloated active_turfs list without needing thousands of distinct real turfs - the bug
	// is driven by list LENGTH (the walk iterates whatever's there, real or duplicate), not by turf
	// identity, so padding with repeats of the same two turfs reproduces the cost characteristic that
	// actually broke this.
	var/list/original_active_turfs = SSair.active_turfs
	var/list/bloated = list(turf_a, turf_b)
	for(var/i in 1 to 1900)
		bloated += turf_a
		bloated += turf_b
	SSair.active_turfs = bloated
	var/original_cursor = SSair.active_turfs_walk_cursor
	SSair.active_turfs_walk_cursor = 0

	var/start_tick_usage = TICK_USAGE_REAL
	SSair.process_active_turfs()
	var/cost_ms = TICK_USAGE_TO_MS(start_tick_usage)

	SSair.active_turfs = original_active_turfs
	SSair.active_turfs_walk_cursor = original_cursor

	TEST_ASSERT(cost_ms < ACTIVE_TURFS_BLOAT_TEST_MAX_MS, \
		"process_active_turfs() took [cost_ms]ms against a ~3800-entry active_turfs list (bound: [ACTIVE_TURFS_BLOAT_TEST_MAX_MS]ms) - the legacy walk should be bounded to ACTIVE_TURFS_WALK_BATCH_SIZE entries per call, not scale with list length. This is the exact regression from the 2026-08-14 playtest.")

#undef ACTIVE_TURFS_BLOAT_TEST_MAX_MS
