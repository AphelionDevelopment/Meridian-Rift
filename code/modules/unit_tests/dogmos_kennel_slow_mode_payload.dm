/**
 * Dogmos Kennel Phase 4: the payload half of kennel_slow_mode (/datum/dogmos_kennel/ui_data()) - the
 * five recent_* tables, structures_of_interest, and atmos_machinery_browse are the only genuinely
 * variable-cost part of this panel's data. With slow mode on, those keys must still be present (real
 * empty lists, not omitted) so the frontend never needs an undefined-guard, but must not carry real
 * data even when SSair actually has some recorded; with slow mode off, the real data comes through.
 */
/datum/unit_test/dogmos_kennel_slow_mode_payload
	var/original_slow_mode
	var/list/original_bucket

/datum/unit_test/dogmos_kennel_slow_mode_payload/Run()
	var/mob/living/carbon/human/observer = allocate(/mob/living/carbon/human/consistent)
	// create_mob_hud() no-ops without a real client (this test mob has none) - build the HUD directly,
	// the same way create_mob_hud() does internally, since ui_data() unconditionally reads
	// user.hud_used.atmos_debug_overlays regardless of what this test is actually checking.
	observer.set_hud_used(new observer.hud_type(observer))

	original_slow_mode = SSair.kennel_slow_mode
	original_bucket = SSair.recent_fire_groups
	SSair.recent_fire_groups = list(list("time" = "00:00:00", "jump_to" = null, "area" = "Test", "peak_size" = 99))

	SSair.kennel_slow_mode = TRUE
	var/list/data_slow = GLOB.dogmos_kennel.ui_data(observer)
	TEST_ASSERT(islist(data_slow["recent_fire_groups"]), \
		"ui_data()'s recent_fire_groups is not a list at all while slow mode is on - the frontend has nothing safe to render.")
	TEST_ASSERT_EQUAL(length(data_slow["recent_fire_groups"]), 0, \
		"ui_data() sent [length(data_slow["recent_fire_groups"])] real recent_fire_groups entries while kennel_slow_mode is TRUE - the payload gate is not suppressing the expensive tables.")
	TEST_ASSERT_NULL(data_slow["atmos_machinery_browse"], \
		"ui_data() sent atmos_machinery_browse while kennel_slow_mode is TRUE - that key should be entirely absent, not just empty, matching its optional frontend type.")

	SSair.kennel_slow_mode = FALSE
	var/list/data_live = GLOB.dogmos_kennel.ui_data(observer)
	TEST_ASSERT_EQUAL(length(data_live["recent_fire_groups"]), 1, \
		"ui_data() did not send the real recent_fire_groups entry while kennel_slow_mode is FALSE - got [length(data_live["recent_fire_groups"])] entries.")
	TEST_ASSERT_EQUAL(data_live["recent_fire_groups"][1]["peak_size"], 99, \
		"ui_data()'s recent_fire_groups entry does not match SSair's real data while slow mode is off.")

	SSair.kennel_slow_mode = original_slow_mode
	SSair.recent_fire_groups = original_bucket

/datum/unit_test/dogmos_kennel_slow_mode_payload/Destroy()
	// Unconditional, not just on success: a TEST_ASSERT abort in Run() skips its own restore above and
	// would otherwise leave SSair's real slow-mode toggle/bucket dirty for the rest of the suite.
	if(!isnull(original_slow_mode))
		SSair.kennel_slow_mode = original_slow_mode
	if(!isnull(original_bucket))
		SSair.recent_fire_groups = original_bucket
	return ..()
