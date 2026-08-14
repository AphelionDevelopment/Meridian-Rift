/**
 * Phase 3.0's adjacency-rebuild wiring fixed two things at once, both regression-tested here:
 *
 * 1. atmos_adjacent_turfs[neighbor] used to be written as a bare boolean TRUE (1). Dogmos'
 *    AdjacentFlags::from_bits_truncate only recognizes bit 0b10 (ATMOS_ADJACENT_FIRELOCK) - truncating
 *    1 silently drops it, so hook_infos would never see a real flags value. Every entry should now be a
 *    real flags value (NONE, or DOGMOS_ADJACENT_FIRELOCK once the SSAIR_HIGHPRESSURE cutover's
 *    atmos_adjacency_flags_with() detects a firelock on the edge) instead.
 *
 *    Checked as "not the bare value 1", not "always NONE": the latter was true only because firelock
 *    detection didn't exist yet at Phase 3.0, and would have started failing for a CORRECT reason the
 *    moment it landed - which is exactly the failure mode of a test that asserts an implementation
 *    accident instead of the actual invariant it's meant to guard.
 * 2. conductivity_blocked_directions (read by Rust's supercond_update_adjacencies for the separate heat
 *    graph) must be recomputed by the same rebuild pass that touches atmos_adjacent_turfs (the gas
 *    graph), via the new sync_dogmos_adjacency() hook - not two independent, driftable refreshes.
 *
 * Real multi-turf layout (the unit test room and its neighbors), not a synthetic one - this is
 * specifically about whether a genuine adjacency rebuild produces correct data, not about the
 * bookkeeping in isolation.
 */
/datum/unit_test/dogmos_turf_adjacency_sync

/datum/unit_test/dogmos_turf_adjacency_sync/Run()
	var/turf/open/floor = run_loc_floor_bottom_left
	TEST_ASSERT(istype(floor), "The unit test run location is not an open turf - this test needs one.")

	floor.immediate_calculate_adjacent_turfs()

	TEST_ASSERT(islist(floor.atmos_adjacent_turfs) && length(floor.atmos_adjacent_turfs), \
		"A station floor has no atmos_adjacent_turfs after a rebuild - this test needs at least one real open neighbor to check anything.")

	for(var/turf/neighbor as anything in floor.atmos_adjacent_turfs)
		var/flag_value = floor.atmos_adjacent_turfs[neighbor]
		TEST_ASSERT_NOTEQUAL(flag_value, 1, \
			"atmos_adjacent_turfs entry for [neighbor] = 1 (bare TRUE) - Dogmos' AdjacentFlags::from_bits_truncate only recognizes bit 0b10 (DOGMOS_ADJACENT_FIRELOCK) and would silently drop this. Every entry must be a real flags value (NONE or DOGMOS_ADJACENT_FIRELOCK), never a bare boolean.")
		TEST_ASSERT(flag_value == NONE || flag_value == DOGMOS_ADJACENT_FIRELOCK, \
			"atmos_adjacent_turfs entry for [neighbor] = [flag_value], not a recognised AdjacentFlags value (NONE or DOGMOS_ADJACENT_FIRELOCK).")

	var/expected_blocked = ALL_CARDINALS & ~floor.conductivity_directions()
	TEST_ASSERT_EQUAL(floor.conductivity_blocked_directions, expected_blocked, \
		"conductivity_blocked_directions ([floor.conductivity_blocked_directions]) does not match ALL_CARDINALS & ~conductivity_directions() ([expected_blocked]) - it fell out of sync with the adjacency rebuild that just ran, which is exactly what sync_dogmos_adjacency() exists to prevent.")
