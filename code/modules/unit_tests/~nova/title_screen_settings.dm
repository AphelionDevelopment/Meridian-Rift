/**
 * Covers the server-wide title screen presentation.
 *
 * The setters are reachable from a client through the manager window, so the
 * validation in front of them is what stops a forged payload from pinning the
 * lobby to something that does not exist. These tests drive SStitle directly;
 * the rights check that guards them lives in title_screen_manager.dm.
 */
/datum/unit_test/title_screen_settings

/datum/unit_test/title_screen_settings/Run()
	// Snapshot, because SStitle is a live subsystem shared with the running round.
	var/saved_names = SStitle.title_screen_names
	var/saved_screens = SStitle.title_screens
	var/saved_selection = SStitle.selected_title_name
	var/saved_rotate = SStitle.rotate_title_screens
	var/saved_settings = SStitle.title_screen_settings
	var/saved_current = SStitle.current_title_screen
	var/saved_current_name = SStitle.current_title_name
	var/saved_progress = SStitle.progress_json
	// change_title_screen() runs check_finish_progress(), which would write the real cache file.
	SStitle.progress_json = null

	SStitle.title_screen_names = list("alpha.png", "beta.png")
	// Deliberately NOT DEFAULT_TITLE_SCREEN_IMAGE: get_title_treatment() short-circuits to
	// the mask treatment for that resource, so stubbing the fakes with it would make every
	// treatment assertion below pass or fail for the wrong reason.
	SStitle.title_screens = list(DEFAULT_TITLE_LOADING_SCREEN, DEFAULT_TITLE_LOADING_SCREEN)
	SStitle.title_screen_settings = list()
	SStitle.selected_title_name = null
	SStitle.rotate_title_screens = TRUE

	// Both built-in masters survive the same availability check used while the
	// subsystem restores its persisted selection during initialization.
	TEST_ASSERT(SStitle.is_title_screen_available(null), "The default title master was not considered available.")
	TEST_ASSERT(SStitle.is_title_screen_available(TITLE_DEFAULT_ALT_SCREEN_KEY), "The alternate title master would be discarded during initialization.")

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

	// A screen with no record of its own reads as the defaults rather than null.
	var/list/fresh = SStitle.get_screen_settings("alpha.png")
	TEST_ASSERT_EQUAL(fresh["variant"], TITLE_DEFAULT_VARIANT, "An unconfigured screen did not fall back to the default variant.")
	TEST_ASSERT_EQUAL(fresh["texture"], TITLE_DEFAULT_TEXTURE, "An unconfigured screen did not fall back to the default texture.")
	TEST_ASSERT_EQUAL(fresh["variant"], "convex", "The virgin screen default is not convex.")
	TEST_ASSERT_EQUAL(fresh["texture"], "navarobl", "The virgin screen default does not use Version 2 scanlines.")
	TEST_ASSERT(fresh["bezel"], "The virgin screen default does not show the monitor bezel.")
	TEST_ASSERT(!("framed" in fresh), "The retired per-screen frame option is still exposed.")
	TEST_ASSERT(!fresh["wordmark"], "An unconfigured screen should start without the wordmark.")

	// Settings are per screen, and only for screens that exist.
	TEST_ASSERT(!SStitle.set_screen_settings("nope.png", list("wordmark" = TRUE)), "Settings were stored for an unknown screen.")
	TEST_ASSERT(!SStitle.set_screen_settings("alpha.png", list()), "An empty change was accepted.")
	TEST_ASSERT(SStitle.set_screen_settings("beta.png", list("wordmark" = TRUE)), "A valid wordmark toggle was rejected.")
	TEST_ASSERT(SStitle.get_screen_settings("beta.png")["wordmark"], "The wordmark flag was not stored.")
	// The neutral master has no file name and is always addressable.
	TEST_ASSERT(SStitle.set_screen_settings(null, list("variant" = "edge")), "The default screen rejected a valid change.")
	TEST_ASSERT_EQUAL(SStitle.get_screen_settings(null)["variant"], "edge", "The default screen did not store its variant.")

	// A partial change leaves every field it did not mention alone.
	SStitle.set_screen_settings("beta.png", list("texture" = "navarobl"))
	var/list/partial = SStitle.get_screen_settings("beta.png")
	TEST_ASSERT_EQUAL(partial["texture"], "navarobl", "A partial change did not apply the texture.")
	TEST_ASSERT(partial["wordmark"], "A partial change cleared an unrelated field.")

	// Presentation is validated against the values TGUI can actually render.
	TEST_ASSERT(!SStitle.set_screen_settings("alpha.png", list("variant" = "nope")), "An unknown screen effect was accepted.")
	// The rim used to be welded onto the effect as convex-bezel; it is its own
	// switch now, so the combined value is no longer a valid effect.
	TEST_ASSERT(!SStitle.set_screen_settings("alpha.png", list("variant" = "convex-bezel")), "The retired convex-bezel effect was accepted.")
	TEST_ASSERT(!SStitle.set_screen_settings("alpha.png", list("texture" = "nope")), "An unknown texture was accepted.")
	TEST_ASSERT(!SStitle.set_screen_settings("alpha.png", list("framed" = FALSE)), "The retired frame option was accepted.")
	TEST_ASSERT_EQUAL(SStitle.get_screen_settings("alpha.png")["variant"], TITLE_DEFAULT_VARIANT, "A rejected effect was still stored.")

	// Scanlines can be turned off, and the rim moves without touching the effect.
	TEST_ASSERT(SStitle.set_screen_settings("alpha.png", list("texture" = "none")), "Turning scanlines off was rejected.")
	TEST_ASSERT(SStitle.set_screen_settings("alpha.png", list("bezel" = TRUE)), "A valid rim toggle was rejected.")
	TEST_ASSERT(SStitle.get_screen_settings("alpha.png")["bezel"], "The rim flag was not stored.")
	TEST_ASSERT_EQUAL(SStitle.get_screen_settings("alpha.png")["variant"], TITLE_DEFAULT_VARIANT, "Toggling the rim changed the screen effect.")
	SStitle.set_screen_settings("alpha.png", list("bezel" = FALSE, "texture" = TITLE_DEFAULT_TEXTURE))

	// Treatment: the neutral master tints; every picture uses the selected
	// screen treatment, with the wordmark as its only optional overlay. A stale
	// v2 frame flag is deliberately ignored.
	SStitle.set_title_selection(null)
	TEST_ASSERT_EQUAL(SStitle.get_title_treatment(), TITLE_TREATMENT_MASK, "The default image should use the mask treatment.")
	SStitle.title_screen_settings["alpha.png"] = list("framed" = FALSE)
	SStitle.set_title_selection("alpha.png")
	TEST_ASSERT_EQUAL(SStitle.get_title_treatment(), TITLE_TREATMENT_SCREEN, "A legacy frame flag bypassed the required screen treatment.")
	SStitle.set_screen_settings("alpha.png", list("wordmark" = TRUE))
	TEST_ASSERT_EQUAL(SStitle.get_title_treatment(), TITLE_TREATMENT_OVERLAY, "A screen with a wordmark should use the overlay treatment.")
	SStitle.set_screen_settings("alpha.png", list("wordmark" = FALSE))

	// Rotation off pins the selection; on, it picks from the configured list.
	SStitle.set_title_selection("beta.png")
	SStitle.set_title_rotation(FALSE)
	TEST_ASSERT_EQUAL(SStitle.resolve_unattended_screen(), SStitle.get_title_screen_icon("beta.png"), "Rotation was off but an unattended change did not keep the pinned screen.")
	SStitle.set_title_rotation(TRUE)
	TEST_ASSERT(SStitle.resolve_unattended_screen() in SStitle.title_screens, "Rotation was on but produced a screen outside the configured list.")

	// The manager follows the screen actually showing, not the stale admin pin.
	// Its global rotation checkbox is immediate and never dirties one screen's
	// presentation draft.
	SStitle.selected_title_name = "alpha.png"
	SStitle.set_showing(SStitle.get_title_screen_icon("beta.png"), "beta.png")
	var/datum/title_screen_manager/manager = new(null)
	TEST_ASSERT_EQUAL(manager.draft_screen, "beta.png", "The title manager initialized from the stale pinned screen instead of the live screen.")
	TEST_ASSERT(!manager.draft_selection_changed, "The title manager treated its live initial selection as an admin change.")
	TEST_ASSERT(!manager.has_pending_changes(), "A newly opened title manager started with a dirty screen draft.")
	var/list/manager_data = manager.ui_data(null)
	TEST_ASSERT_EQUAL(manager_data["liveScreen"], "beta.png", "The title manager reported the pinned screen instead of the screen actually showing.")
	TEST_ASSERT("rotateTitleScreens" in manager_data, "The title manager omitted the independent live rotation preference.")
	TEST_ASSERT(!("draftRotate" in manager_data), "Rotation is still represented as part of the screen draft.")
	var/manager_baseline_variant = manager.draft_settings["variant"]
	var/external_variant = manager_baseline_variant == "flat" ? "edge" : "flat"
	SStitle.set_screen_settings("beta.png", list("variant" = external_variant))
	TEST_ASSERT(!manager.has_pending_changes(), "Another admin's appearance change dirtied this manager's untouched draft.")
	TEST_ASSERT(manager.sync_clean_draft_to_live(), "A clean manager did not reload an external appearance change.")
	TEST_ASSERT_EQUAL(manager.draft_settings["variant"], external_variant, "A clean manager kept stale appearance controls.")
	SStitle.set_screen_settings("beta.png", list("variant" = manager_baseline_variant))
	manager.sync_clean_draft_to_live()
	SStitle.set_title_rotation(FALSE)
	TEST_ASSERT_EQUAL(SStitle.selected_title_name, "beta.png", "Disabling rotation kept a stale hidden pin instead of the live screen.")
	TEST_ASSERT(!manager.has_pending_changes(), "Changing rotation dirtied the current screen's presentation draft.")
	SStitle.set_title_rotation(TRUE)
	SStitle.set_showing(SStitle.get_title_screen_icon("alpha.png"), "alpha.png")
	TEST_ASSERT(manager.sync_clean_draft_to_live(), "A clean manager did not follow the rotated live screen.")
	TEST_ASSERT_EQUAL(manager.draft_screen, "alpha.png", "A clean manager kept showing the previous screen's controls after rotation.")
	TEST_ASSERT(!manager.has_pending_changes(), "Following a rotation dirtied the current screen's presentation draft.")
	manager.draft_settings["wordmark"] = !manager.draft_settings["wordmark"]
	SStitle.set_showing(SStitle.get_title_screen_icon("beta.png"), "beta.png")
	TEST_ASSERT(!manager.sync_clean_draft_to_live(), "A rotation discarded a locally modified title-screen draft.")
	TEST_ASSERT_EQUAL(manager.draft_screen, "alpha.png", "A dirty draft switched screens during rotation.")
	TEST_ASSERT(manager.has_pending_changes(), "Changing a per-screen presentation field did not dirty the draft.")
	TEST_ASSERT(manager.draft_requires_selection(), "Applying a preserved draft would not restore its screen after rotation.")
	qdel(manager)

	// Rotation has to carry the complete record belonging to the image it lands
	// on. Restrict the pool to one screen at a time so every field is exercised
	// deterministically rather than hoping random rolls cover both records.
	SStitle.set_screen_settings("alpha.png", list("variant" = "flat", "bezel" = FALSE, "texture" = "original", "wordmark" = FALSE))
	SStitle.set_screen_settings("beta.png", list("variant" = "convex", "bezel" = TRUE, "texture" = "navarobl", "wordmark" = TRUE))
	var/list/all_test_names = SStitle.title_screen_names
	var/list/all_test_screens = SStitle.title_screens
	var/list/rotation_expectations = list(
		"alpha.png" = list("variant" = "flat", "bezel" = FALSE, "texture" = "original", "treatment" = TITLE_TREATMENT_SCREEN),
		"beta.png" = list("variant" = "convex", "bezel" = TRUE, "texture" = "navarobl", "treatment" = TITLE_TREATMENT_OVERLAY),
	)
	for(var/screen_name in rotation_expectations)
		var/screen_index = all_test_names.Find(screen_name)
		SStitle.title_screen_names = list(screen_name)
		SStitle.title_screens = list(all_test_screens[screen_index])
		SStitle.resolve_unattended_screen()
		var/list/expected = rotation_expectations[screen_name]
		var/list/rotated_payload = SStitle.get_title_payload()
		// Restore shared globals before asserting: a failed assertion must not
		// leave the singleton pool in place for later unit tests.
		SStitle.title_screen_names = all_test_names
		SStitle.title_screens = all_test_screens
		TEST_ASSERT_EQUAL(SStitle.current_title_name, screen_name, "Rotation lost the selected screen's name.")
		TEST_ASSERT_EQUAL(rotated_payload["titleVariant"], expected["variant"], "Rotation loaded the wrong variant for [screen_name].")
		TEST_ASSERT_EQUAL(rotated_payload["titleBezel"], expected["bezel"], "Rotation loaded the wrong bezel state for [screen_name].")
		TEST_ASSERT_EQUAL(rotated_payload["titleTexture"], expected["texture"], "Rotation loaded the wrong scanlines for [screen_name].")
		TEST_ASSERT_EQUAL(rotated_payload["titleImageTreatment"], expected["treatment"], "Rotation loaded the wrong wordmark treatment for [screen_name].")

	// An upload isn't a config screen, so it can't inherit a record from the last pin.
	SStitle.set_title_selection("beta.png")
	SStitle.change_title_screen(DEFAULT_TITLE_LOADING_SCREEN)
	TEST_ASSERT_EQUAL(SStitle.current_title_name, null, "An uploaded screen kept the previous screen's name.")
	TEST_ASSERT(!SStitle.is_current_title_screen_managed(), "An unmanaged upload was mistaken for the neutral master.")
	TEST_ASSERT_EQUAL(SStitle.get_title_treatment(), TITLE_TREATMENT_NONE, "An unmanaged upload borrowed the neutral master's presentation.")
	var/uploaded_selection = SStitle.selected_title_name
	SStitle.set_title_rotation(FALSE)
	TEST_ASSERT_EQUAL(SStitle.selected_title_name, uploaded_selection, "Disabling rotation turned an unmanaged upload into the neutral master.")
	var/datum/title_screen_manager/upload_manager = new(null)
	var/list/upload_manager_data = upload_manager.ui_data(null)
	TEST_ASSERT(!upload_manager.draft_screen_chosen, "The title manager created an editable draft for an unmanaged upload.")
	TEST_ASSERT(!upload_manager_data["liveScreenManaged"], "The title manager reported an unmanaged upload as a configured screen.")
	TEST_ASSERT(!upload_manager_data["draftScreenChosen"], "The title manager falsely selected the neutral master for an unmanaged upload.")
	TEST_ASSERT(!upload_manager_data["pending"], "An unmanaged upload opened the title manager with pending changes.")
	qdel(upload_manager)
	SStitle.set_title_rotation(TRUE)

	// The payload TGUI consumes must carry every control it renders.
	var/list/payload = SStitle.get_title_payload()
	for(var/key in list("titleImageUrl", "titleMarkUrl", "titleImageTreatment", "titleVariant", "titleBezel", "titleTexture", "titleClassicAlt"))
		TEST_ASSERT(key in payload, "The lobby payload is missing [key].")
	for(var/unused_key in list("titleScreens", "titleSelected", "titleRotate"))
		TEST_ASSERT(!(unused_key in payload), "The lobby payload still sends unused [unused_key] state.")

	// The manager lists the neutral master first, then every config screen,
	// each with the full record the window's controls bind to.
	var/list/options = SStitle.get_title_screen_options()
	TEST_ASSERT_EQUAL(length(options), 4, "The screen list should be both masters plus both config screens.")
	var/list/first = options[1]
	TEST_ASSERT(first["isDefault"], "The neutral master should lead the screen list.")
	TEST_ASSERT_EQUAL(first["name"], null, "The neutral master should have no config file name.")
	// The alternate ramp is its own entry rather than a checkbox on the first.
	var/list/second = options[2]
	TEST_ASSERT(second["isAlt"], "The alternate master should follow the default one.")
	TEST_ASSERT(second["isDefault"], "The alternate master is still a master.")
	for(var/key in list("name", "isDefault", "isAlt", "url", "variant", "bezel", "texture", "wordmark"))
		TEST_ASSERT(key in options[3], "A screen option is missing [key].")
	TEST_ASSERT(!("framed" in options[3]), "A screen option still exposes the retired frame field.")

	// Both masters are selectable and both render the tinted wordmark.
	TEST_ASSERT(SStitle.set_title_selection(TITLE_DEFAULT_ALT_SCREEN_KEY), "The alternate master was rejected as a selection.")
	TEST_ASSERT_EQUAL(SStitle.current_title_screen, DEFAULT_TITLE_SCREEN_IMAGE, "The alternate master did not show the master image.")
	TEST_ASSERT_EQUAL(SStitle.get_title_treatment(), TITLE_TREATMENT_MASK, "The alternate master should use the mask treatment.")
	TEST_ASSERT(SStitle.get_title_payload()["titleClassicAlt"], "The alternate master did not report its ramp.")
	SStitle.set_title_rotation(FALSE)
	SStitle.resolve_unattended_screen()
	TEST_ASSERT_EQUAL(SStitle.current_title_name, TITLE_DEFAULT_ALT_SCREEN_KEY, "An unattended update forgot the pinned alternate master.")
	TEST_ASSERT(SStitle.get_title_payload()["titleClassicAlt"], "An unattended update lost the alternate master's ramp.")
	SStitle.set_title_selection(null)
	TEST_ASSERT(!SStitle.get_title_payload()["titleClassicAlt"], "The default master reported the alternate ramp.")

	SStitle.title_screen_names = saved_names
	SStitle.title_screens = saved_screens
	SStitle.selected_title_name = saved_selection
	SStitle.rotate_title_screens = saved_rotate
	SStitle.title_screen_settings = saved_settings
	SStitle.current_title_screen = saved_current
	SStitle.current_title_name = saved_current_name
	SStitle.progress_json = saved_progress
	// The setters above wrote the test's own values to the real settings file.
	// Put the server's back rather than leaving it holding alpha.png.
	SStitle.save_title_settings()

/**
 * Covers the version 1 -> 2 settings migration.
 *
 * Version 1 stored one variant/texture/classicAlt for the whole server plus a
 * map of overlay flags. Every screen it knew about therefore looked the same,
 * so the migration has to reproduce that by copying the globals onto each one.
 */
/datum/unit_test/title_screen_settings_migration

/datum/unit_test/title_screen_settings_migration/Run()
	var/saved_names = SStitle.title_screen_names
	var/saved_settings = SStitle.title_screen_settings
	var/saved_selection = SStitle.selected_title_name

	SStitle.title_screen_names = list("alpha.png", "beta.png")
	SStitle.title_screen_settings = list()

	SStitle.migrate_legacy_title_settings(list(
		"_version" = TITLE_SETTINGS_VERSION_LEGACY,
		"variant" = "edge",
		"texture" = "navarobl",
		"classicAlt" = TRUE,
		"overlays" = list("beta.png" = TRUE, "gone.png" = TRUE),
	))

	// Both screens inherit the old server-wide presentation...
	for(var/screen_name in list("alpha.png", "beta.png"))
		var/list/record = SStitle.get_screen_settings(screen_name)
		TEST_ASSERT_EQUAL(record["variant"], "edge", "[screen_name] did not inherit the legacy variant.")
		TEST_ASSERT_EQUAL(record["texture"], "navarobl", "[screen_name] did not inherit the legacy texture.")

	// ...and only the one that had an overlay flag keeps the wordmark.
	TEST_ASSERT(SStitle.get_screen_settings("beta.png")["wordmark"], "A legacy overlay flag was lost.")
	TEST_ASSERT(!SStitle.get_screen_settings("alpha.png")["wordmark"], "A wordmark was invented for a screen that had no overlay flag.")

	// Version 1 deliberately kept flags for images that were temporarily gone.
	TEST_ASSERT(SStitle.title_screen_settings["gone.png"], "A record for a missing image was pruned.")

	// The neutral master is its own screen and was never in the overlay map.
	var/list/master = SStitle.get_screen_settings(null)
	TEST_ASSERT_EQUAL(master["variant"], "edge", "The neutral master did not inherit the legacy variant.")
	TEST_ASSERT(!master["wordmark"], "The neutral master was given a wordmark it never had.")

	// v1's global classicAlt selected a ramp, so it becomes the alt master.
	TEST_ASSERT_EQUAL(SStitle.selected_title_name, TITLE_DEFAULT_ALT_SCREEN_KEY, "A legacy classicAlt did not select the alternate master.")
	TEST_ASSERT(SStitle.title_screen_settings[TITLE_DEFAULT_ALT_SCREEN_KEY], "The alternate master got no record from the migration.")

	// v1's convex-bezel welded the rim onto the effect; the migration splits it.
	SStitle.title_screen_settings = list()
	SStitle.migrate_legacy_title_settings(list(
		"_version" = TITLE_SETTINGS_VERSION_LEGACY,
		"variant" = "convex-bezel",
		"texture" = "original",
	))
	var/list/split = SStitle.get_screen_settings("alpha.png")
	TEST_ASSERT_EQUAL(split["variant"], "convex", "convex-bezel did not migrate to the convex effect.")
	TEST_ASSERT(split["bezel"], "convex-bezel did not migrate to a separate rim.")

	// A sparse v1 file keeps the historical no-rim/Original defaults rather
	// than inheriting the fuller defaults introduced for new v2 records.
	SStitle.title_screen_settings = list()
	SStitle.migrate_legacy_title_settings(list("_version" = TITLE_SETTINGS_VERSION_LEGACY))
	var/list/historical_defaults = SStitle.get_screen_settings("alpha.png")
	TEST_ASSERT(!historical_defaults["bezel"], "A legacy title unexpectedly gained the new default bezel.")
	TEST_ASSERT_EQUAL(historical_defaults["texture"], "original", "A legacy title unexpectedly gained Version 2 scanlines.")

	SStitle.title_screen_names = saved_names
	SStitle.title_screen_settings = saved_settings
	SStitle.selected_title_name = saved_selection
	SStitle.save_title_settings()
