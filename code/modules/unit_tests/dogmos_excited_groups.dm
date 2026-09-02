/// Maximum service chunks a stage may consume before this test reports stalled progress.
#define DOGMOS_EXCITED_GROUPS_STAGE_CHUNK_LIMIT 4096
/// Maximum subsystem fires this test waits for an existing service cycle to finish.
#define DOGMOS_EXCITED_GROUPS_BOUNDARY_ATTEMPTS 20

/** Verifies that the excited-group path consumes a low-pressure FDM result. */
/datum/unit_test/dogmos_excited_groups

/datum/unit_test/dogmos_excited_groups/Run()
	// NOVA EDIT ADDITION START - DOGMOS
	var/reached_stage_boundary = FALSE
	for(var/attempt in 1 to DOGMOS_EXCITED_GROUPS_BOUNDARY_ATTEMPTS)
		if(isnull(SSair.dogmos_pending_stage) && !SSair.dogmos_pending_frontier_epoch && SSdogmos.flush_turf_registration_batch())
			reached_stage_boundary = TRUE
			break
		sleep(SSair.wait)
	TEST_ASSERT(reached_stage_boundary, "Dogmos did not reach a safe stage boundary before the excited-groups test.")
	// NOVA EDIT ADDITION END

	var/list/pair = allocate_turf_pair()
	var/turf/open/turf_a = pair[1]
	var/turf/open/turf_b = pair[2]

	var/datum/gas_mixture/air_a = turf_a.air
	var/original_a_o2 = air_a.get_moles(/datum/gas/oxygen)
	air_a.set_moles(/datum/gas/oxygen, original_a_o2 * 1.05)

	SSair.active_turfs |= turf_a
	SSair.active_turfs |= turf_b
	// NOVA EDIT ADDITION START - DOGMOS
	var/turf_stage_pending = TRUE
	var/turf_stage_chunks = 0
	while(turf_stage_pending && turf_stage_chunks < DOGMOS_EXCITED_GROUPS_STAGE_CHUNK_LIMIT)
		turf_stage_pending = SSair.process_turfs_auxtools(100)
		turf_stage_chunks++
	TEST_ASSERT(!turf_stage_pending, "Dogmos turf processing did not complete within [DOGMOS_EXCITED_GROUPS_STAGE_CHUNK_LIMIT] chunks.")
	// NOVA EDIT ADDITION END
	SSair.finish_turf_processing_auxtools(100)

	var/before = SSair.num_group_turfs_processed
	/* // NOVA EDIT REMOVAL START - DOGMOS
	SSair.process_excited_groups_auxtools(100)
	*/ // NOVA EDIT REMOVAL END
	// NOVA EDIT ADDITION START - DOGMOS
	var/stage_pending = TRUE
	var/stage_chunks = 0
	while(stage_pending && stage_chunks < DOGMOS_EXCITED_GROUPS_STAGE_CHUNK_LIMIT)
		stage_pending = SSair.process_excited_groups_auxtools(100)
		stage_chunks++
	TEST_ASSERT(!stage_pending, "Dogmos excited-groups processing did not complete within [DOGMOS_EXCITED_GROUPS_STAGE_CHUNK_LIMIT] chunks.")
	// NOVA EDIT ADDITION END
	var/after = SSair.num_group_turfs_processed

	TEST_ASSERT(after > 0, \
		"num_group_turfs_processed ([before] -> [after]) is not positive after seeding a low-pressure turf pair and running the equalizer - the FFI call did not process anything real.")

#undef DOGMOS_EXCITED_GROUPS_STAGE_CHUNK_LIMIT
#undef DOGMOS_EXCITED_GROUPS_BOUNDARY_ATTEMPTS
