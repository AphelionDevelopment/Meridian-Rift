/** Verifies that the excited-group path consumes a low-pressure FDM result. */
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
