/**
 * General regression guard for a real Tier-3-reported bug (2026-08-15): "rooms exposed to a breach
 * don't get colder." Checks that a hot interior turf's heat-graph temperature (return_temperature())
 * actually drops after a real process_turf_heat() cycle once its neighbor becomes space, via whichever
 * combination of Rust's cooling mechanisms end up responsible - NOT a precise test of any one of them.
 *
 * Investigated 2026-08-15: `ThermalInfo.adjacent_to_space` (aphelion-dogmos src/turfs/superconduct.rs) -
 * the flag that gates blackbody radiation specifically - is only ever populated by
 * supercond_update_ref(), reached exclusively through register_dogmos_air()/update_air_ref().
 * sync_dogmos_adjacency()'s own refresh (supercond_update_adjacencies) only touches heat-graph EDGES, a
 * separate Rust structure - so without register_dogmos_air() also running from sync_dogmos_adjacency()
 * (see LINDA_system.dm, fixed alongside this test), a breach's interior turf never gets
 * adjacent_to_space refreshed from its roundstart FALSE. That's a real, fixed gap - but a
 * deliberate-break run proved this test does NOT discriminate it: superconduct.rs's "share w/ air" step
 * (~line 392) unconditionally equilibrates a turf's heat-graph temperature toward its OWN gas mixture's
 * temperature whenever that gas mixture is registered and enabled, regardless of adjacent_to_space -
 * and since the interior turf's gas is already cooling via ordinary FDM mixing with the vacuum neighbor
 * (space registration, fixed earlier in this integration), that alone was enough to pass this test with
 * the adjacent_to_space fix disabled. Kept as a real regression guard for "does cooling happen at all,"
 * not as proof of the specific fix - a precise blackbody-only test would need to isolate a turf with no
 * gas registered at all, which isn't representative of a real breach anyway.
 *
 * Sets up an interior turf that is never itself touched by ChangeTurf, converts its neighbor into space
 * via ChangeTurf (the same mechanism a real breach uses), and confirms the interior turf's temperature
 * actually drops after a real process_turf_heat() cycle - not just that some registration counter moved.
 */
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
