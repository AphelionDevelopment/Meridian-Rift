/**
 * Verifies the fix for the 2026-08-14 playtest regression (breaches pulled nothing, gas never
 * diffused into space): space turfs never registered into Dogmos at all, because
 * /turf/open/space/Initialize() skips Initalize_Atmos() entirely and the base register_dogmos_air()
 * early-returns on !init_air - so a station turf's edge to a real space neighbor was silently dropped
 * by Rust's adjacency sync (TurfGases::update_adjacencies() skips any neighbor id it never registered).
 * See modular_aphelion/master_files/code/game/turfs/open/space/space.dm for the fix's two overrides.
 *
 * Converts a real test-room neighbor into /turf/open/space via ChangeTurf - the same machinery a real
 * hull breach uses (place_on_top/ChangeTurf always calls the new turf's Initialize() and
 * AfterChange(), matching how this actually gets exercised in play, not a synthetic shortcut) - then
 * asserts both that the space turf actually registered (dogmos_space_boundary_count() increases) and
 * that gas measurably left the interior turf after a real FDM cycle. Checking only the counter would
 * repeat the exact mistake C4 already fixed once in this codebase (dogmos_turf_adjacency_sync.dm): a
 * registered-but-inert node would still move the counter without proving diffusion actually works.
 */
/datum/unit_test/dogmos_space_boundary_registration
	/// The EAST neighbor's original type, so Destroy() can restore it even if Run() aborts partway
	/// through via a TEST_ASSERT failure.
	var/original_neighbor_type

/datum/unit_test/dogmos_space_boundary_registration/Run()
	var/turf/open/interior = run_loc_floor_bottom_left
	TEST_ASSERT(istype(interior), "run_loc_floor_bottom_left is not an open turf - this test needs one.")

	var/datum/gas_mixture/air_interior = interior.air
	var/before_moles = air_interior.total_moles()
	TEST_ASSERT(before_moles > 0, \
		"The interior test turf has no gas to begin with - test setup is broken, not the thing under test.")

	var/before_boundary_count = dogmos_space_boundary_count()

	var/list/conversion = convert_neighbor_to_space(interior)
	original_neighbor_type = conversion[2]

	TEST_ASSERT(dogmos_space_boundary_count() > before_boundary_count, \
		"dogmos_space_boundary_count() did not increase after a real space neighbor was discovered as an adjacent turf - the space turf did not register into Dogmos' gas graph (see the register_dogmos_air() override on /turf/open/space).")

	// Fixed, generous budgets rather than SSair.process_active_turfs()'s real tick-budget calculation -
	// same reasoning as dogmos_gas_fdm_golden.dm: that budget can be near-zero deep into a long suite
	// run, which would make this test flaky for a reason unrelated to what it's actually checking.
	SSair.process_turfs_auxtools(100)
	SSair.finish_turf_processing_auxtools(100)

	var/after_moles = air_interior.total_moles()
	TEST_ASSERT(after_moles < before_moles, \
		"The interior turf's total moles ([before_moles] -> [after_moles]) did not decrease after a real FDM cycle with a registered space neighbor - gas is not actually diffusing into space.")

	restore_neighbor_from_space(interior, original_neighbor_type)
	original_neighbor_type = null

/datum/unit_test/dogmos_space_boundary_registration/Destroy()
	// Unconditional, not just on success: a TEST_ASSERT abort in Run() skips its own restore and would
	// otherwise leave a real space turf sitting in the test room for every test that runs after this
	// one.
	restore_neighbor_from_space(run_loc_floor_bottom_left, original_neighbor_type)
	restore_atmos()
	return ..()
