/**
 * Phase 3.0: turf registration was never actually wired up before this - update_air_ref() and
 * __update_auxtools_turf_adjacency_info() existed as working generated bindings, but nothing in DM
 * called either of them, so Rust's TurfGases/TurfHeat graphs were empty at runtime. This is the first
 * real FFI round-trip proving register_dogmos_air() (turf.dm) actually reaches Rust: seed a known
 * temperature, force a genuinely fresh registration, and read it back through return_temperature() -
 * a value that matches what was just seeded (rather than the 102/300 no-arena fallbacks in
 * aphelion-dogmos src/turfs/superconduct.rs's hook_turf_temperature, or a stale prior value) proves
 * the turf actually reached Rust's TurfHeat arena, not just that the DM-side call didn't error.
 *
 * The test turf (run_loc_floor_bottom_left) is already registered from roundstart boot, so a naive
 * re-registration wouldn't prove anything: TurfHeat::insert_turf only refreshes
 * thermal_conductivity/heat_capacity/adjacent_to_space on an already-present node - it deliberately
 * does NOT reset temperature (so a live turf's evolving temperature survives routine re-registration,
 * e.g. on ChangeTurf). To actually observe a fresh insert, thermal_conductivity/heat_capacity are
 * zeroed first, forcing supercond_update_ref's insert-vs-remove branch to remove the turf from
 * TurfHeat, before registering again with real values.
 */
/datum/unit_test/dogmos_turf_registration

/datum/unit_test/dogmos_turf_registration/proc/force_fresh_registration(turf/target, test_temperature)
	var/original_thermal_conductivity = target.thermal_conductivity
	var/original_heat_capacity = target.heat_capacity

	target.thermal_conductivity = 0
	target.heat_capacity = 0
	target.register_dogmos_air() // supercond_update_ref sees therm_cond/heat_cap <= 0 and removes the turf.

	target.thermal_conductivity = original_thermal_conductivity
	target.heat_capacity = original_heat_capacity
	target.temperature = test_temperature
	target.initial_temperature = null
	target.register_dogmos_air() // Now a genuine fresh insert, seeded from the temperature just set.

/datum/unit_test/dogmos_turf_registration/Run()
	var/turf/open/floor = run_loc_floor_bottom_left
	TEST_ASSERT(istype(floor), "The unit test run location is not an open turf - this test needs one.")

	var/original_temperature = floor.temperature
	var/original_initial_temperature = floor.initial_temperature
	var/original_blocks_air = floor.blocks_air

	// Open-turf case.
	force_fresh_registration(floor, 350)

	TEST_ASSERT_EQUAL(floor.initial_temperature, 350, \
		"register_dogmos_air() did not seed initial_temperature from temperature on first registration.")
	TEST_ASSERT_EQUAL(round(floor.return_temperature()), 350, \
		"return_temperature() is [floor.return_temperature()]K, not the 350K just registered - the turf did not actually reach Rust's TurfHeat arena (hook_register_turf/supercond_update_ref).")

	// Closed/blocks_air case: hook_register_turf calls supercond_update_ref() unconditionally
	// regardless of blocks_air, so a solid turf should still land in TurfHeat (needed for solid/solid
	// superconduction to eventually work through Rust rather than DM's share_temperature_mutual_solid).
	floor.blocks_air = TRUE
	force_fresh_registration(floor, 500)

	TEST_ASSERT_EQUAL(floor.initial_temperature, 500, \
		"register_dogmos_air() did not seed initial_temperature on a blocks_air turf's first registration.")
	TEST_ASSERT_EQUAL(round(floor.return_temperature()), 500, \
		"return_temperature() is [floor.return_temperature()]K, not the 500K just registered - a blocks_air turf did not register into TurfHeat. Solid/solid superconduction depends on this.")

	floor.blocks_air = original_blocks_air
	force_fresh_registration(floor, original_temperature)
	floor.initial_temperature = original_initial_temperature

/datum/unit_test/dogmos_turf_registration/Destroy()
	// Unconditional, not just on assertion failure: Run() only restores the shared test turf at its
	// very end, so any TEST_ASSERT abort above skips that restore and leaves temperature/blocks_air
	// dirty for every test that runs after this one.
	var/turf/open/floor = run_loc_floor_bottom_left
	if(istype(floor))
		floor.blocks_air = FALSE
		force_fresh_registration(floor, T20C)
		floor.initial_temperature = null
	return ..()
