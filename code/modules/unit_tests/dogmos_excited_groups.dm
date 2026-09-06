#define DOGMOS_EXCITED_TEST_STAGE 1

/** Verifies one native excited-group stage redistributes a low-pressure fixture. */
/datum/unit_test/dogmos_excited_groups

/datum/unit_test/dogmos_excited_groups/Run()
	TEST_ASSERT(dogmos_wait_for_stage_boundary(), "Dogmos did not reach a safe boundary before excited-group processing.")
	var/list/pair = allocate_turf_pair()
	TEST_ASSERT_EQUAL(length(pair), 2, "The excited-group fixture needs two gas-adjacent turfs.")
	var/turf/open/turf_a = pair[1]
	var/datum/gas_mixture/air_a = turf_a.air
	var/original_o2 = air_a.get_moles(/datum/gas/oxygen)
	TEST_ASSERT(original_o2 > 0, "The excited-group fixture requires nonzero oxygen.")
	air_a.set_moles(/datum/gas/oxygen, original_o2 * 1.05)
	var/a_before = air_a.get_moles(/datum/gas/oxygen)
	var/processed_before = SSair.num_group_turfs_processed
	TEST_ASSERT(dogmos_run_fixture_stage(DOGMOS_EXCITED_TEST_STAGE, pair), "Native excited-group processing did not complete and restore its frontier within the fixture bound.")
	var/a_after = air_a.get_moles(/datum/gas/oxygen)
	TEST_ASSERT(SSair.num_group_turfs_processed > processed_before, "Native excited-group processing did not report a processed component.")
	TEST_ASSERT(a_after < a_before, "Excited-group processing did not redistribute the seeded oxygen ([a_before] -> [a_after]).")

/datum/unit_test/dogmos_excited_groups/Destroy()
	restore_atmos()
	return ..()

#undef DOGMOS_EXCITED_TEST_STAGE
