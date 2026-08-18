/** Verifies finite results when two heat capacities use BYOND's infinite sentinel. */
/datum/unit_test/dogmos_infinite_heat_capacity_conduction

/datum/unit_test/dogmos_infinite_heat_capacity_conduction/Run()
	var/list/pair = allocate_turf_pair()
	var/turf/open/turf_a = pair[1]
	var/turf/open/turf_b = pair[2]

	// BYOND's INFINITY is a finite sentinel, so compare it directly rather than with isinf().
	TEST_ASSERT(turf_a.heat_capacity == INFINITY && turf_b.heat_capacity == INFINITY, \
		"The test room's turfs no longer default to infinite heat_capacity ([turf_a.heat_capacity], [turf_b.heat_capacity]) - test setup is broken, not the thing under test (this test specifically needs the infinite-capacity condition to reproduce the bug).")

	// A non-gas-adjacent neighbor creates the heat edge.
	turf_b.blocks_air = TRUE
	resync_turf_for_dogmos(turf_a)
	resync_turf_for_dogmos(turf_b)

	TEST_ASSERT(!(turf_b in turf_a.atmos_adjacent_turfs), \
		"turf_b is still gas-adjacent to turf_a after being marked blocks_air - the heat edge this test depends on only exists for NON-gas-adjacent neighbors, so the setup did not take.")

	turf_a.set_temperature(1500)
	turf_b.set_temperature(1000)

	var/a_before = turf_a.return_temperature()
	var/b_before = turf_b.return_temperature()
	TEST_ASSERT(a_before > b_before, \
		"Seeding turf_a at 1500K and turf_b at 1000K did not produce an asymmetric pair ([a_before] vs [b_before]) - test setup is broken, not the thing under test.")

	// Allow multiple cycles so a write-time sanity clamp cannot hide an intermediate invalid value.
	for(var/attempt in 1 to 10)
		SSair.process_turf_heat()
		sleep(2)

	var/a_after = turf_a.return_temperature()
	var/b_after = turf_b.return_temperature()

	TEST_ASSERT(a_after != 300.0 && b_after != 300.0, \
		"turf_a/turf_b temperature ([a_after], [b_after]) hit the read-time non-normal fallback (hook_turf_temperature returns exactly 300.0 for a stored NaN/infinity) - get_share_energy() is still overflowing for this infinite-heat-capacity pair.")
	TEST_ASSERT(!isnan(a_after) && a_after > TCMB + 1, \
		"turf_a's temperature after conducting with an infinite-heat-capacity neighbor is [a_after]K - NaN or snapped to near TCMB is exactly the get_share_energy() inf/inf bug this test guards against.")
	TEST_ASSERT(!isnan(b_after) && b_after > TCMB + 1, \
		"turf_b's temperature after conducting with an infinite-heat-capacity neighbor is [b_after]K - NaN or snapped to near TCMB is exactly the get_share_energy() inf/inf bug this test guards against.")

/datum/unit_test/dogmos_infinite_heat_capacity_conduction/Destroy()
	// Unconditional, matching dogmos_superconduction_golden.dm's convention: a TEST_ASSERT abort in
	// Run() skips its own restore, and blocks_air/temperature are persistent turf state every later
	// test would inherit.
	var/turf/open/turf_a = run_loc_floor_bottom_left
	if(istype(turf_a))
		var/turf/open/turf_b = get_step(turf_a, EAST)
		turf_a.set_temperature(T20C)
		resync_turf_for_dogmos(turf_a)
		if(istype(turf_b))
			turf_b.blocks_air = initial(turf_b.blocks_air)
			turf_b.set_temperature(T20C)
			resync_turf_for_dogmos(turf_b)
	return ..()
