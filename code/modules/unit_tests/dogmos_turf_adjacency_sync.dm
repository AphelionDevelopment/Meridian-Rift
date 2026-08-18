/** Verifies adjacency flags and heat-graph refresh on a real multi-turf layout. */
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
