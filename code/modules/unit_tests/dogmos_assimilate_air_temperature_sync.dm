/**
 * Verifies the fix for a real, reported bug (2026-08-15): "on reset, either some turfs or something
 * was retaining and releasing heat, even after [a holodeck arena] reset" - fixed by the Fix Air admin
 * verb, which explicitly calls turf-level set_temperature(), but not by the reset itself.
 *
 * Root cause: /turf/open/proc/Assimilate_Air() (change_turf.dm), called from AfterChange() whenever a
 * turf is placed via ChangeTurf() without CHANGETURF_INHERIT_AIR/IGNORE_AIR (exactly what the standard
 * map-template loader used by holodeck resets does, and what ordinary construction/deconstruction does
 * too - this isn't holodeck-specific), blends the new turf's gas with its real neighbors' gas and
 * temperature, then calls `total.set_temperature(...)` and `turf.air.copy_from(total)`. Both of those
 * only ever touch Dogmos' GAS-MIXTURE-level temperature (a real, working FFI round trip) - never the
 * turf's own separate HEAT-GRAPH copy (TurfHeat/ThermalInfo, what return_temperature(), blackbody
 * radiation, and superconduction all actually read). A freshly-placed turf's gas would correctly show
 * the assimilated (possibly neighbor-contaminated) temperature while its heat-graph copy silently kept
 * whatever register_dogmos_air() seeded it with at first registration (that type's own default
 * `temperature`, typically T20C) - two different "temperatures" for the same turf, invisible to a
 * plain gas-content check, and reconciled only by an explicit fix like the Fix Air verb's
 * turf.set_temperature() call. Fixed by having Assimilate_Air() call turf.set_temperature() too.
 *
 * Seeds the hot neighbor via turf_a.air.set_temperature() (gas-mixture level), not turf_a.set_temperature()
 * (heat-graph level) - a first version of this test used the latter and failed for the wrong reason
 * (the neighbor read back at T20C inside Assimilate_Air(), never actually hot), because
 * Assimilate_Air() reads mix.return_temperature() where mix = turf.air - the exact same two-different-
 * temperatures distinction this bug is about, just tripping up the test instead of production code
 * that time. Matches how a real heat source (e.g. a fire reaction) actually raises a turf's
 * temperature: via air.set_temperature() on the reacting gas mixture, not the turf-level setter.
 *
 * Reuses allocate_turf_pair() and re-ChangeTurfs turf_b to its own type with CHANGETURF_RECALC_ADJACENT
 * (so atmos_adjacent_turfs - what Assimilate_Air() reads to find turf_a as a real hot neighbor - is
 * populated synchronously before AfterChange() runs Assimilate_Air(), matching what the map loader's
 * own CHANGETURF_DEFER_CHANGE + later bulk adjacency pass achieves asynchronously in real play).
 */
/datum/unit_test/dogmos_assimilate_air_temperature_sync

/datum/unit_test/dogmos_assimilate_air_temperature_sync/Run()
	var/list/pair = allocate_turf_pair()
	var/turf/open/turf_a = pair[1]
	var/turf/open/turf_b = pair[2]

	turf_a.heat_capacity = 20000
	turf_a.air.set_temperature(1000)

	var/turf_a_temp_immediately_after_seeding = turf_a.air.return_temperature()

	var/turf_b_type = turf_b.type
	var/turf/open/new_turf_b = turf_b.ChangeTurf(turf_b_type, null, CHANGETURF_RECALC_ADJACENT)
	TEST_ASSERT(istype(new_turf_b), \
		"ChangeTurf to [turf_b_type] did not produce an open turf - test setup is broken, not the thing under test.")
	TEST_ASSERT(turf_a_temp_immediately_after_seeding > 999, \
		"turf_a's gas mixture temperature right after air.set_temperature(1000) and BEFORE any ChangeTurf call was already [turf_a_temp_immediately_after_seeding]K, not ~1000K - test setup is broken before the thing under test even starts.")

	var/gas_temp = new_turf_b.air.return_temperature()
	var/heat_graph_temp = new_turf_b.return_temperature()

	TEST_ASSERT(gas_temp > T20C + 1, \
		"The reset turf's gas mixture temperature ([gas_temp]K) never picked up any heat from its 1000K neighbor (adjacent_count=[LAZYLEN(new_turf_b.atmos_adjacent_turfs)], turf_a_in_list=[(turf_a in new_turf_b.atmos_adjacent_turfs)], turf_a_air_temp=[turf_a.air.return_temperature()]) - test setup is broken (Assimilate_Air() isn't running or isn't finding turf_a as a neighbor), not the thing under test.")
	TEST_ASSERT(abs(gas_temp - heat_graph_temp) < 1, \
		"The reset turf's gas mixture temperature ([gas_temp]K) and its own heat-graph temperature ([heat_graph_temp]K) disagree by more than 1K after Assimilate_Air() - the turf-level heat-graph copy isn't being synced to match the assimilated gas temperature.")

/datum/unit_test/dogmos_assimilate_air_temperature_sync/Destroy()
	var/turf/open/turf_a = run_loc_floor_bottom_left
	if(istype(turf_a))
		turf_a.heat_capacity = initial(turf_a.heat_capacity)
		turf_a.air.set_temperature(T20C)
		turf_a.set_temperature(T20C)
	restore_atmos()
	return ..()
