/** Verifies that a hot interior turf cools after its neighbor becomes space. */
/datum/unit_test/dogmos_breach_radiative_cooling
	/// The EAST neighbor's original type, so Destroy() can restore it even if Run() aborts partway
	/// through via a TEST_ASSERT failure.
	var/original_neighbor_type

/datum/unit_test/dogmos_breach_radiative_cooling/Run()
	var/turf/open/interior = run_loc_floor_bottom_left
	TEST_ASSERT(istype(interior), "run_loc_floor_bottom_left is not an open turf - this test needs one.")

	// Finite heat_capacity (the stock test room's is INFINITY, same NaN hazard
	// dogmos_superconduction_golden.dm documents) and a hot seed temperature so a real blackbody delta
	// is easily distinguishable from float noise within a couple of cycles.
	interior.heat_capacity = 20000
	interior.set_temperature(2000)
	interior.register_dogmos_air()

	var/before_temp = interior.return_temperature()
	TEST_ASSERT(before_temp > T0C, \
		"Seeding the interior turf at 2000K did not take ([before_temp]) - test setup is broken, not the thing under test.")

	// CHANGETURF_RECALC_ADJACENT (inside convert_neighbor_to_space()): without it, AfterChange() queues
	// the adjacency recompute for a later SSair.fire() instead of running it immediately - this test
	// needs the edge (and, critically, the interior turf's sync_dogmos_adjacency() call) to happen
	// synchronously.
	var/list/conversion = convert_neighbor_to_space(interior)
	original_neighbor_type = conversion[2]

	// process_turf_heat() is fire-and-forget (bounded(1) channel to a persistent worker, silently
	// dropped if busy) and the live SSair is also calling it every ~0.5s throughout the suite - same
	// bounded-retry pattern as dogmos_superconduction_golden.dm, a single notify has no guarantee of
	// being the one that lands.
	var/after_temp = before_temp
	for(var/attempt in 1 to 10)
		SSair.process_turf_heat()
		sleep(2)
		after_temp = interior.return_temperature()
		if(after_temp != before_temp)
			break

	TEST_ASSERT(after_temp < before_temp, \
		"The interior turf's temperature ([before_temp] -> [after_temp]) did not decrease after a real heat cycle with a newly-breached space neighbor - should_conduct_to_space() is not being refreshed when a breach changes adjacency.")

	restore_neighbor_from_space(interior, original_neighbor_type)
	original_neighbor_type = null

/datum/unit_test/dogmos_breach_radiative_cooling/Destroy()
	// Unconditional, not just on success: a TEST_ASSERT abort in Run() skips its own restore.
	var/turf/open/interior = run_loc_floor_bottom_left
	if(istype(interior))
		restore_neighbor_from_space(interior, original_neighbor_type)
		interior.heat_capacity = initial(interior.heat_capacity)
		interior.set_temperature(T20C)
		interior.register_dogmos_air()
	return ..()
