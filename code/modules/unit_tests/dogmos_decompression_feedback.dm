/** Verifies per-area rate limiting for decompression feedback. */
/datum/unit_test/dogmos_decompression_feedback
	/// Original per-area feedback timestamps restored during teardown.
	var/list/original_feedback_times

/datum/unit_test/dogmos_decompression_feedback/Run()
	var/turf/open/breach_turf = run_loc_floor_bottom_left
	TEST_ASSERT(istype(breach_turf), "run_loc_floor_bottom_left is not an open turf - this test needs one.")

	original_feedback_times = SSair.kennel_breach_feedback_times
	SSair.kennel_breach_feedback_times = list()

	TEST_ASSERT(SSair.kennel_decompression_feedback_available(breach_turf), \
		"The first decompression feedback event in an area was suppressed.")
	TEST_ASSERT(!SSair.kennel_decompression_feedback_available(breach_turf), \
		"Repeated decompression feedback in the same area was not rate-limited.")

	SSair.kennel_breach_feedback_times = original_feedback_times

/datum/unit_test/dogmos_decompression_feedback/Destroy()
	if(!isnull(original_feedback_times))
		SSair.kennel_breach_feedback_times = original_feedback_times
	return ..()
