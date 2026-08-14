/**
 * Correctness check for the SSAIR_EXCITEDGROUPS cutover to Rust's katmos-style pressure equalizer
 * (process_excited_groups_auxtools, aphelion-dogmos src/turfs/groups.rs, called from
 * SSair.process_excited_groups(), code/controllers/subsystem/air.dm). Confirms the FFI plumbing
 * genuinely crosses the boundary and does real work - not just "returns a number", which Phase 2's own
 * remediation found is a false-passable assertion (dogmos_load's original weak check).
 *
 * Runs one real gas FDM cycle first (process_turfs_auxtools/finish_turf_processing_auxtools) so Rust's
 * internal low_pressure_turfs channel actually has something in it for process_excited_groups_auxtools
 * to consume - the equalizer does nothing if fed an empty/absent channel (see the doc comment on
 * SSair.process_excited_groups()).
 *
 * Deliberately seeds a small asymmetry rather than using two already-identical turfs: Rust's FDM
 * (should_process(), src/turfs/processing.rs) skips a turf ENTIRELY - never adding it to either the
 * low- or high-pressure set - unless it actually differs from a neighbor enough to be worth a share
 * step. Two turfs already in perfect equilibrium are therefore never fed into the groups channel at
 * all, which would make this test pass or fail for the wrong reason. A modest, single-share-step
 * asymmetry (much smaller than the golden test's 3x seed) both guarantees the pair gets processed and
 * keeps the post-share pressure delta under the 5.0 kPa low/high-pressure split, so the pair lands in
 * low_pressure_turfs rather than being routed to the (unrelated, HIGHPRESSURE-stage) equalize channel.
 */
/datum/unit_test/dogmos_excited_groups

/datum/unit_test/dogmos_excited_groups/Run()
	var/turf/open/turf_a = run_loc_floor_bottom_left
	var/turf/open/turf_b = get_step(turf_a, EAST)
	TEST_ASSERT(istype(turf_a), "run_loc_floor_bottom_left is not an open turf - this test needs one.")
	TEST_ASSERT(istype(turf_b), "The turf east of run_loc_floor_bottom_left is not an open turf - this test needs two real, adjacent turfs.")

	var/datum/gas_mixture/air_a = turf_a.air
	var/original_a_o2 = air_a.get_moles(/datum/gas/oxygen)
	air_a.set_moles(/datum/gas/oxygen, original_a_o2 * 1.05)

	SSair.active_turfs |= turf_a
	SSair.active_turfs |= turf_b
	SSair.process_turfs_auxtools(100)
	SSair.finish_turf_processing_auxtools(100)

	var/before = SSair.num_group_turfs_processed
	SSair.process_excited_groups_auxtools(100)
	var/after = SSair.num_group_turfs_processed

	air_a.set_moles(/datum/gas/oxygen, original_a_o2)

	TEST_ASSERT(after > 0, \
		"num_group_turfs_processed ([before] -> [after]) is not positive after seeding a low-pressure turf pair and running the equalizer - the FFI call did not process anything real.")
