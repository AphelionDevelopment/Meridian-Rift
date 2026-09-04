/**
 * Covers the server-wide title screen presentation.
 *
 * The setters are reachable from a client through the lobby menu, so the
 * validation in front of them is what stops a forged payload from pinning the
 * lobby to something that does not exist. These tests drive SStitle directly;
 * the rights check that guards them lives in lobby_menu_title_controls.dm.
 */
/datum/unit_test/title_screen_settings

/datum/unit_test/title_screen_settings/Run()
	// Snapshot, because SStitle is a live subsystem shared with the running round.
	var/saved_names = SStitle.title_screen_names
	var/saved_screens = SStitle.title_screens
	var/saved_selection = SStitle.selected_title_name
	var/saved_rotate = SStitle.rotate_title_screens
	var/saved_overlays = SStitle.title_overlays
	var/saved_current = SStitle.current_title_screen
	var/saved_current_name = SStitle.current_title_name
	var/saved_progress = SStitle.progress_json
	// change_title_screen() runs check_finish_progress(), which would write the real cache file.
	SStitle.progress_json = null
	var/saved_variant = SStitle.title_variant
	var/saved_texture = SStitle.title_texture
	var/saved_classic_alt = SStitle.title_classic_alt

	SStitle.title_screen_names = list("alpha.png", "beta.png")
	// Deliberately NOT DEFAULT_TITLE_SCREEN_IMAGE: get_title_treatment() short-circuits to
	// the mask treatment for that resource, so stubbing the fakes with it would make every
	// treatment assertion below pass or fail for the wrong reason.
	SStitle.title_screens = list(DEFAULT_TITLE_LOADING_SCREEN, DEFAULT_TITLE_LOADING_SCREEN)
	SStitle.title_overlays = list()
	SStitle.selected_title_name = null
	SStitle.rotate_title_screens = TRUE

	// Selection only accepts names the config directory actually produced.
	TEST_ASSERT(!SStitle.set_title_selection("nope.png"), "An unknown screen name was accepted.")
	TEST_ASSERT(!SStitle.set_title_selection(list("alpha.png")), "A non-text screen name was accepted.")
	TEST_ASSERT_EQUAL(SStitle.selected_title_name, null, "A rejected selection still changed the pinned screen.")

	TEST_ASSERT(SStitle.set_title_selection("alpha.png"), "A valid screen name was rejected.")
	TEST_ASSERT_EQUAL(SStitle.selected_title_name, "alpha.png", "A valid selection was not applied.")

	// The empty selection is the documented way back to the neutral master.
	TEST_ASSERT(SStitle.set_title_selection(null), "Clearing the selection was rejected.")
	TEST_ASSERT_EQUAL(SStitle.selected_title_name, null, "Clearing the selection did not reset it.")
	TEST_ASSERT_EQUAL(SStitle.current_title_screen, DEFAULT_TITLE_SCREEN_IMAGE, "Clearing the selection did not fall back to the default image.")

	// Overlay flags are per screen, and only for screens that exist.
	TEST_ASSERT(!SStitle.set_title_overlay("nope.png", TRUE), "An overlay was set for an unknown screen.")
	TEST_ASSERT(SStitle.set_title_overlay("beta.png", TRUE), "A valid overlay toggle was rejected.")
	TEST_ASSERT(SStitle.title_overlays["beta.png"], "The overlay flag was not stored.")

	// Treatment: the neutral master tints, a plain picture does not, and a
	// picture only gains the wordmark once its own overlay flag is set.
	SStitle.set_title_selection(null)
	TEST_ASSERT_EQUAL(SStitle.get_title_treatment(), TITLE_TREATMENT_MASK, "The default image should use the mask treatment.")
	SStitle.set_title_selection("alpha.png")
	TEST_ASSERT_EQUAL(SStitle.get_title_treatment(), TITLE_TREATMENT_NONE, "A screen without an overlay flag should be untreated.")
	SStitle.set_title_selection("beta.png")
	TEST_ASSERT_EQUAL(SStitle.get_title_treatment(), TITLE_TREATMENT_OVERLAY, "A screen with an overlay flag should use the overlay treatment.")

	// Rotation off pins the selection; on, it picks from the configured list.
	SStitle.set_title_rotation(FALSE)
	TEST_ASSERT_EQUAL(SStitle.resolve_unattended_screen(), SStitle.get_title_screen_icon("beta.png"), "Rotation was off but an unattended change did not keep the pinned screen.")
	SStitle.set_title_rotation(TRUE)
	TEST_ASSERT(SStitle.resolve_unattended_screen() in SStitle.title_screens, "Rotation was on but produced a screen outside the configured list.")

	// A rotation has to carry the overlay flag of the screen it landed on. Reading the
	// flag off the pinned name instead meant a rotated screen showed the wrong treatment.
	// Only beta.png is flagged, so whichever way each roll lands the two must agree.
	for(var/attempt in 1 to 20)
		// resolve_unattended_screen() applies the pick itself. Calling it directly
		// rather than change_title_screen() skips show_title_screen(), so this does
		// not churn 20 generations through the asset cache.
		SStitle.resolve_unattended_screen()
		var/expected = SStitle.title_overlays[SStitle.current_title_name] ? TITLE_TREATMENT_OVERLAY : TITLE_TREATMENT_NONE
		TEST_ASSERT_EQUAL(SStitle.get_title_treatment(), expected, "A rotated screen ([SStitle.current_title_name]) did not use its own overlay flag.")

	// An upload isn't a config screen, so it can't inherit a flag from the last pin.
	SStitle.set_title_selection("beta.png")
	SStitle.change_title_screen(DEFAULT_TITLE_LOADING_SCREEN)
	TEST_ASSERT_EQUAL(SStitle.current_title_name, null, "An uploaded screen kept the previous screen's name.")
	TEST_ASSERT_EQUAL(SStitle.get_title_treatment(), TITLE_TREATMENT_NONE, "An uploaded screen inherited an overlay flag.")

	// Presentation is validated against the values TGUI can actually render.
	TEST_ASSERT(!SStitle.set_title_presentation("nope", "original", FALSE), "An unknown bezel variant was accepted.")
	TEST_ASSERT(!SStitle.set_title_presentation("convex", "nope", FALSE), "An unknown texture was accepted.")
	TEST_ASSERT(SStitle.set_title_presentation("edge", "navarobl", TRUE), "A valid presentation was rejected.")
	TEST_ASSERT_EQUAL(SStitle.title_variant, "edge", "A valid presentation did not apply the variant.")
	TEST_ASSERT_EQUAL(SStitle.title_texture, "navarobl", "A valid presentation did not apply the texture.")

	// The payload TGUI consumes must carry every control it renders.
	var/list/payload = SStitle.get_title_payload()
	for(var/key in list("titleImageUrl", "titleMarkUrl", "titleImageTreatment", "titleScreens", "titleSelected", "titleRotate", "titleVariant", "titleTexture", "titleClassicAlt"))
		TEST_ASSERT(key in payload, "The lobby payload is missing [key].")

	SStitle.title_screen_names = saved_names
	SStitle.title_screens = saved_screens
	SStitle.selected_title_name = saved_selection
	SStitle.rotate_title_screens = saved_rotate
	SStitle.title_overlays = saved_overlays
	SStitle.current_title_screen = saved_current
	SStitle.current_title_name = saved_current_name
	SStitle.progress_json = saved_progress
	SStitle.title_variant = saved_variant
	SStitle.title_texture = saved_texture
	SStitle.title_classic_alt = saved_classic_alt
