/**
 * Phase 3.0's adjacency-rebuild wiring fixed two things at once, both regression-tested here:
 *
 * 1. atmos_adjacent_turfs[neighbor] used to be written as a bare boolean TRUE (1). Dogmos'
 *    AdjacentFlags::from_bits_truncate only recognizes bit 0b10 (ATMOS_ADJACENT_FIRELOCK) - truncating
 *    1 silently drops it, so hook_infos would never see a real flags value. Every entry should now be a
 *    real (currently always NONE, since nothing computes firelock-adjacency yet) flags value instead.
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
		TEST_ASSERT_EQUAL(flag_value, NONE, \
			"atmos_adjacent_turfs entry for [neighbor] = [flag_value], expected NONE (0) - no firelock-adjacency detection exists yet, so every entry should currently be flagless. A bare TRUE (1) here is the exact regression this test guards: Dogmos' AdjacentFlags::from_bits_truncate only recognizes bit 0b10 and would silently drop a boolean 1.")

	var/expected_blocked = ALL_CARDINALS & ~floor.conductivity_directions()
	TEST_ASSERT_EQUAL(floor.conductivity_blocked_directions, expected_blocked, \
		"conductivity_blocked_directions ([floor.conductivity_blocked_directions]) does not match ALL_CARDINALS & ~conductivity_directions() ([expected_blocked]) - it fell out of sync with the adjacency rebuild that just ran, which is exactly what sync_dogmos_adjacency() exists to prevent.")
