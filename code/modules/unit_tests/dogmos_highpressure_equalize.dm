/**
 * Correctness check for the SSAIR_HIGHPRESSURE cutover to Rust's katmos pressure equalizer
 * (process_turf_equalize_auxtools, aphelion-dogmos src/turfs/katmos.rs, called from
 * SSair.process_high_pressure_delta(), code/controllers/subsystem/air.dm). Confirms the FFI plumbing
 * genuinely does real work (num_equalize_processed becomes positive) rather than just returning a
 * number, the same false-passable-assertion class Phase 2's remediation flagged.
 *
 * Seeds a MUCH larger asymmetry than dogmos_gas_fdm_golden.dm's 3x - that test deliberately stays
 * under the FDM's 5.0 kPa low/high-pressure split so the pair lands in low_pressure_turfs (feeding
 * SSAIR_EXCITEDGROUPS instead). This test needs the opposite: a delta big enough to clear that
 * threshold after one share step, so the pair lands in high_pressure_turfs and actually reaches the
 * katmos equalize channel this proc is meant to exercise.
 */
/datum/unit_test/dogmos_highpressure_equalize

/datum/unit_test/dogmos_highpressure_equalize/Run()
	var/turf/open/turf_a = run_loc_floor_bottom_left
	var/turf/open/turf_b = get_step(turf_a, EAST)
	TEST_ASSERT(istype(turf_a), "run_loc_floor_bottom_left is not an open turf - this test needs one.")
	TEST_ASSERT(istype(turf_b), "The turf east of run_loc_floor_bottom_left is not an open turf - this test needs two real, adjacent turfs.")

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

	var/before = SSair.num_equalize_processed
	SSair.process_turf_equalize_auxtools(100)
	var/after = SSair.num_equalize_processed

	air_a.set_moles(/datum/gas/oxygen, original_a_o2)
	air_a.set_moles(/datum/gas/nitrogen, original_a_n2)

	TEST_ASSERT(after > 0, \
		"num_equalize_processed ([before] -> [after]) is not positive after seeding a high-pressure turf pair and running the equalizer - the FFI call did not process anything real.")
