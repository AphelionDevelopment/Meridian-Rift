/** Verifies gas conservation and directional flow across one real FDM step. */
/datum/unit_test/dogmos_gas_fdm_golden

/datum/unit_test/dogmos_gas_fdm_golden/Run()
	var/list/pair = allocate_turf_pair()
	var/turf/open/turf_a = pair[1]
	var/turf/open/turf_b = pair[2]

	var/datum/gas_mixture/air_a = turf_a.air
	var/datum/gas_mixture/air_b = turf_b.air
	var/original_a_o2 = air_a.get_moles(/datum/gas/oxygen)

	// Deliberately asymmetric: triple turf_a's oxygen relative to its actual starting value.
	air_a.set_moles(/datum/gas/oxygen, original_a_o2 * 3)

	var/a_before = air_a.get_moles(/datum/gas/oxygen)
	var/b_before = air_b.get_moles(/datum/gas/oxygen)
	TEST_ASSERT(a_before > b_before, \
		"Seeding turf_a with 3x turf_b's oxygen did not actually produce an asymmetric pair ([a_before] vs [b_before]) - test setup is broken, not the thing under test.")

	SSair.active_turfs |= turf_a
	SSair.active_turfs |= turf_b
	SSair.process_turfs_auxtools(100)
	SSair.finish_turf_processing_auxtools(100)

	var/a_after = air_a.get_moles(/datum/gas/oxygen)
	var/b_after = air_b.get_moles(/datum/gas/oxygen)

	TEST_ASSERT(a_after < a_before, \
		"turf_a's oxygen ([a_before] -> [a_after]) did not decrease after sharing with lower-oxygen turf_b - gas is not flowing out of the fuller turf.")
	TEST_ASSERT(b_after > b_before, \
		"turf_b's oxygen ([b_before] -> [b_after]) did not increase after sharing with higher-oxygen turf_a - gas is not flowing into the emptier turf.")
	TEST_ASSERT(a_after > b_after, \
		"turf_a's oxygen ([a_after]) dropped to or below turf_b's ([b_after]) after a single share step - a single GAS_DIFFUSION_CONSTANT-weighted step should not overshoot past equilibrium.")
