#define DOGMOS_EQUALIZE_TEST_STAGE 2

/** Verifies that one native equalization stage redistributes a high-pressure fixture. */
/datum/unit_test/dogmos_highpressure_equalize

/datum/unit_test/dogmos_highpressure_equalize/Run()
	TEST_ASSERT(dogmos_wait_for_stage_boundary(), "Dogmos did not reach a safe boundary before equalization.")
	var/list/pair = allocate_turf_pair()
	TEST_ASSERT_EQUAL(length(pair), 2, "The equalization fixture needs two gas-adjacent turfs.")
	var/turf/open/turf_a = pair[1]
	var/datum/gas_mixture/air_a = turf_a.air
	var/original_o2 = air_a.get_moles(/datum/gas/oxygen)
	var/original_n2 = air_a.get_moles(/datum/gas/nitrogen)
	TEST_ASSERT(original_o2 > 0, "The equalization fixture requires nonzero oxygen.")
	air_a.set_moles(/datum/gas/oxygen, original_o2 * 10)
	air_a.set_moles(/datum/gas/nitrogen, original_n2 * 10)

	var/a_before = air_a.get_moles(/datum/gas/oxygen)
	var/processed_before = SSair.num_equalize_processed
	TEST_ASSERT(dogmos_run_fixture_stage(DOGMOS_EQUALIZE_TEST_STAGE, pair), "Native equalization did not complete and restore its frontier within the fixture bound.")
	var/a_after = air_a.get_moles(/datum/gas/oxygen)
	TEST_ASSERT(SSair.num_equalize_processed > processed_before, "Native equalization did not report a processed component.")
	TEST_ASSERT(a_after < a_before, "Equalization left the high-pressure turf unchanged ([a_before] -> [a_after]); no diffusion stage ran in this interval.")

/datum/unit_test/dogmos_highpressure_equalize/Destroy()
	restore_atmos()
	return ..()

#undef DOGMOS_EQUALIZE_TEST_STAGE
