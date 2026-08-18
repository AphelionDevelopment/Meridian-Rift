/** Verifies that the high-pressure path reaches Katmos and redistributes gas. */
/datum/unit_test/dogmos_highpressure_equalize

/datum/unit_test/dogmos_highpressure_equalize/Run()
	var/list/pair = allocate_turf_pair()
	var/turf/open/turf_a = pair[1]
	var/turf/open/turf_b = pair[2]

	var/datum/gas_mixture/air_a = turf_a.air
	var/original_a_o2 = air_a.get_moles(/datum/gas/oxygen)
	var/original_a_n2 = air_a.get_moles(/datum/gas/nitrogen)
	air_a.set_moles(/datum/gas/oxygen, original_a_o2 * 10)
	air_a.set_moles(/datum/gas/nitrogen, original_a_n2 * 10)

	SSair.active_turfs |= turf_a
	SSair.active_turfs |= turf_b
	SSair.process_turfs_auxtools(100)
	SSair.finish_turf_processing_auxtools(100)

	TEST_ASSERT(SSair.high_pressure_turfs > 0, \
		"high_pressure_turfs (SSair var, write-only telemetry from Rust's gas FDM pass) is not positive after seeding a 10x pressure asymmetry - test setup did not actually produce a high-pressure turf, so the equalize channel below would be empty regardless of whether equalize itself works.")

	// Captured right before/after the equalizer call specifically (not the FDM cycle above) - a real
	// physics assertion, not just a processed-count check. Katmos' monstermos redistribution
	// (equalize()/process_zone(), katmos.rs) directly moves moles between zone members toward the
	// zone average, so a turf seeded 10x asymmetric should measurably lose gas.
	var/a_before_eq = air_a.get_moles(/datum/gas/oxygen)
	var/before = SSair.num_equalize_processed
	SSair.process_turf_equalize_auxtools(100)
	var/after = SSair.num_equalize_processed
	var/a_after_eq = air_a.get_moles(/datum/gas/oxygen)

	TEST_ASSERT(after > before, \
		"num_equalize_processed ([before] -> [after]) did not increase after seeding a high-pressure turf pair and running the equalizer - the FFI call did not process anything real.")
	TEST_ASSERT(a_after_eq < a_before_eq, \
		"turf_a's oxygen ([a_before_eq] -> [a_after_eq]) did not decrease after the equalizer ran - num_equalize_processed increased but the seeded high-pressure turf itself was not actually redistributed.")
