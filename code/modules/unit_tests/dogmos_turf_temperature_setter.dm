/**
 * FFI round-trip for /turf/proc/set_temperature() (modular_aphelion/master_files/code/game/turfs/turf.dm),
 * the wrapper added in Phase 3 so every DM call site that used to write /turf/var/temperature directly
 * can push the value through to Dogmos' heat-conduction graph instead of silently going stale there.
 *
 * Does not attempt to exercise the raw __set_temperature() bind's NaN/infinite-rejection or
 * not-registered-in-TurfHeat error paths directly - both return Err from Rust, which propagates as an
 * uncaught DM exception rather than something a TEST_ASSERT can cleanly observe, and forcing either
 * deliberately risks aborting the rest of the suite rather than just this test. Both are covered by
 * construction instead: register_dogmos_air() (see dogmos_turf_registration.dm) already establishes
 * that any turf with nonzero thermal_conductivity/heat_capacity registers into TurfHeat, and the
 * wrapper never passes anything but a plain DM number through.
 */
/datum/unit_test/dogmos_turf_temperature_setter

/datum/unit_test/dogmos_turf_temperature_setter/Run()
	var/turf/open/floor = run_loc_floor_bottom_left
	TEST_ASSERT(istype(floor), "The unit test run location is not an open turf - this test needs one.")

	var/original_temperature = floor.temperature
	var/original_initial_temperature = floor.initial_temperature

	// Make sure it's actually registered before testing the setter against it.
	floor.register_dogmos_air()

	floor.set_temperature(400)
	TEST_ASSERT_EQUAL(floor.temperature, 400, \
		"set_temperature() did not update the turf's own temperature var.")
	TEST_ASSERT_EQUAL(round(floor.return_temperature()), 400, \
		"return_temperature() is [floor.return_temperature()]K after set_temperature(400) - the write did not reach Rust's TurfHeat arena.")

	floor.set_temperature(150)
	TEST_ASSERT_EQUAL(floor.temperature, 150, \
		"set_temperature() did not update the turf's own temperature var on a second write.")
	TEST_ASSERT_EQUAL(round(floor.return_temperature()), 150, \
		"return_temperature() is [floor.return_temperature()]K after set_temperature(150) - a second write did not reach Rust.")

	floor.set_temperature(original_temperature)
	floor.initial_temperature = original_initial_temperature

/datum/unit_test/dogmos_turf_temperature_setter/Destroy()
	// Unconditional, matching dogmos_turf_registration.dm's convention: a TEST_ASSERT abort above
	// skips Run()'s own restore, and this is a shared test-room turf every later test depends on.
	var/turf/open/floor = run_loc_floor_bottom_left
	if(istype(floor))
		floor.set_temperature(T20C)
		floor.initial_temperature = null
	return ..()
