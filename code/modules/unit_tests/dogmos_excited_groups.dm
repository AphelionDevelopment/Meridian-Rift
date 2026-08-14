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
 *
 * Asserts a processed COUNT rather than "gas actually moved on these specific turfs", which is weaker
 * than dogmos_gas_fdm_golden.dm's real physics assertions and is a deliberate, informed limit rather
 * than an oversight. Strengthening it was attempted during the SSAIR_SUPERCONDUCTIVITY stage and
 * withdrawn: excited_group_processing() (groups.rs) inserts a turf into found_turfs the moment the
 * flood-fill DISCOVERS it - before evaluating the `(max - min) >= pressure_goal` band check that then
 * `continue`s past it - so a deliberately-seeded pressure outlier is exactly what the algorithm is
 * designed to visit-and-exclude from the zone average. Which turfs end up merged into which zone is
 * decided entirely inside Rust and is neither observable nor controllable from DM, so "turf_a moved"
 * is not a property this test can assert; a version asserting it (and a looser "turf_a or turf_b
 * moved") both failed against a working equalizer. Do not "fix" this by re-adding such an assertion
 * without first giving Rust a way to report zone membership back.
 */
/datum/unit_test/dogmos_excited_groups

/datum/unit_test/dogmos_excited_groups/Run()
	var/list/pair = allocate_turf_pair()
	var/turf/open/turf_a = pair[1]
	var/turf/open/turf_b = pair[2]

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

	TEST_ASSERT(after > 0, \
		"num_group_turfs_processed ([before] -> [after]) is not positive after seeding a low-pressure turf pair and running the equalizer - the FFI call did not process anything real.")
