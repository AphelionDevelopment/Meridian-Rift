// Unit tests are included before this module in tgstation.dme.
#include "..\..\..\..\modular_nova\modules\title_screen\code\_title_screen_defines.dm"

/// Isolates title tests from the server's persistence, assets, and recipients.
/// Allocated by each test so /datum/unit_test/Destroy restores state even when
/// TEST_ASSERT returns from Run early. No test resource enters SSassets.cache.
/datum/title_screen_test_state
	var/datum/controller/subsystem/title/title
	var/list/saved_title_vars = list()
	var/datum/asset_transport/saved_transport
	var/datum/asset_transport/title_screen_test/test_transport
	var/list/saved_lobby_menus
	var/list/saved_clients
	var/settings_file

/datum/title_screen_test_state/New()
	title = SStitle
	for(var/field in list(
		"title_screen_names", "title_screens", "selected_title_name", "rotate_title_screens",
		"title_screen_settings", "title_settings_file", "current_title_screen", "current_title_name",
		"progress_json", "current_title_asset_name", "published_title_screen", "published_title_name",
		"published_title_payload", "title_asset_generation", "title_mark_asset_registered", "preview_assets_registered",
	))
		saved_title_vars[field] = title.vars[field]
	saved_transport = SSassets.transport
	test_transport = new
	SSassets.transport = test_transport
	saved_lobby_menus = GLOB.lobby_menus
	saved_clients = GLOB.clients
	GLOB.lobby_menus = list()
	GLOB.clients = list()

	settings_file = "tmp/title_screen_settings_[REF(src)].json"
	title.title_settings_file = settings_file
	title.progress_json = null
	title.title_screen_names = list("alpha.png", "beta.png")
	title.title_screens = list(DEFAULT_TITLE_LOADING_SCREEN, DEFAULT_TITLE_LOADING_SCREEN)
	title.title_screen_settings = list()
	title.selected_title_name = null
	title.rotate_title_screens = TRUE
	title.set_showing(DEFAULT_TITLE_SCREEN_IMAGE, null)
	title.current_title_asset_name = "title_test_initial.png"
	title.published_title_screen = null
	title.published_title_name = null
	title.published_title_payload = null
	title.title_asset_generation = 0
	title.title_mark_asset_registered = FALSE
	title.preview_assets_registered = list()

/datum/title_screen_test_state/Destroy()
	for(var/field in saved_title_vars)
		title.vars[field] = saved_title_vars[field]
	SSassets.transport = saved_transport
	GLOB.lobby_menus = saved_lobby_menus
	GLOB.clients = saved_clients
	fdel(settings_file)
	QDEL_NULL(test_transport)
	return ..()

/// Models registration and transport-specific URLs without writing the asset cache.
/datum/asset_transport/title_screen_test
	var/url_prefix = "test-original/"
	var/list/registered_assets = list()

/datum/asset_transport/title_screen_test/register_asset(asset_name, asset, file_hash, dmi_file_path)
	registered_assets[asset_name] = asset

/datum/asset_transport/title_screen_test/get_asset_url(asset_name, datum/asset_cache_item/asset_cache_item)
	return "[url_prefix][asset_name]"

/datum/asset_transport/title_screen_test/send_assets(client/client, list/asset_list)
	return FALSE

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
	allocate(/datum/title_screen_test_state)
	// The fixture uses a non-master image for both configured screens so their
	// treatment assertions cannot accidentally take the built-in mask shortcut.

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
	var/datum/title_screen_manager/manager = allocate(/datum/title_screen_manager)
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
	var/datum/title_screen_manager/upload_manager = allocate(/datum/title_screen_manager)
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

/**
 * Covers the version 1 -> 2 settings migration.
 *
 * Version 1 stored one variant/texture/classicAlt for the whole server plus a
 * map of overlay flags. Every screen it knew about therefore looked the same,
 * so the migration has to reproduce that by copying the globals onto each one.
 */
/datum/unit_test/title_screen_settings_migration

/datum/unit_test/title_screen_settings_migration/Run()
	allocate(/datum/title_screen_test_state)

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

	// A ramp flag must not replace a separately pinned configured picture.
	fdel(SStitle.title_settings_file)
	WRITE_FILE(file(SStitle.title_settings_file), json_encode(list(
		"_version" = TITLE_SETTINGS_VERSION_LEGACY,
		"selected" = "alpha.png",
		"rotate" = FALSE,
		"classicAlt" = TRUE,
	)))
	SStitle.load_title_settings()
	TEST_ASSERT_EQUAL(SStitle.selected_title_name, "alpha.png", "A legacy ramp flag replaced the configured screen selection.")
	TEST_ASSERT(!SStitle.rotate_title_screens, "Migration changed the legacy rotation setting.")
	SStitle.resolve_unattended_screen()
	TEST_ASSERT_EQUAL(SStitle.current_title_name, "alpha.png", "The migrated pin no longer resolves to its configured picture.")
	var/list/persisted = json_decode(file2text(SStitle.title_settings_file))
	TEST_ASSERT_EQUAL(persisted["selected"], "alpha.png", "Migration persisted a replacement for the configured pin.")

/// A transport change must update URLs without exposing an unpublished screen.
/datum/unit_test/title_screen_published_transport

/datum/unit_test/title_screen_published_transport/Run()
	allocate(/datum/title_screen_test_state)
	SStitle.set_screen_settings("alpha.png", list("variant" = "flat", "bezel" = FALSE, "texture" = "none"))
	SStitle.set_title_selection("alpha.png")
	var/published_asset_name = SStitle.current_title_asset_name
	var/list/original_payload = SStitle.get_published_title_payload()

	// Stage another picture and appearance without publishing its asset yet.
	SStitle.set_showing(DEFAULT_TITLE_SCREEN_IMAGE, TITLE_DEFAULT_ALT_SCREEN_KEY)
	SStitle.broadcast_title_settings()
	var/datum/asset_transport/title_screen_test/replacement = allocate(/datum/asset_transport/title_screen_test)
	replacement.url_prefix = "test-fallback/"
	SSassets.transport = replacement
	var/list/payload = SStitle.get_published_title_payload()
	TEST_ASSERT_NOTEQUAL(payload["titleImageUrl"], original_payload["titleImageUrl"], "A transport change retained the old image URL.")
	TEST_ASSERT_EQUAL(payload["titleImageUrl"], replacement.get_asset_url(published_asset_name), "The new URL does not identify the published image.")
	TEST_ASSERT_EQUAL(payload["titleMarkUrl"], replacement.get_asset_url(LOBBY_TITLE_MARK_ASSET_NAME), "The wordmark retained its old transport URL.")
	TEST_ASSERT_EQUAL(payload["titleImageTreatment"], TITLE_TREATMENT_SCREEN, "Initialization exposed the staged master's treatment.")
	TEST_ASSERT_EQUAL(payload["titleVariant"], "flat", "Initialization mixed staged appearance with the published picture.")
	TEST_ASSERT(!payload["titleClassicAlt"], "Initialization exposed the staged alternate master.")
	payload["titleVariant"] = "convex"
	TEST_ASSERT_EQUAL(SStitle.get_published_title_payload()["titleVariant"], "flat", "Mutating an init payload changed the published snapshot.")

/// Unchanged appearance is valid, but must not rewrite settings or republish.
/datum/unit_test/title_screen_unchanged_settings

/datum/unit_test/title_screen_unchanged_settings/Run()
	allocate(/datum/title_screen_test_state)
	SStitle.set_title_selection("alpha.png")
	var/list/published = SStitle.published_title_payload
	var/generation = SStitle.title_asset_generation
	// Remove only the fixture's temporary file to detect any subsequent write.
	fdel(SStitle.title_settings_file)
	TEST_ASSERT(SStitle.set_screen_settings("alpha.png", SStitle.get_screen_settings("alpha.png")), "An unchanged appearance was rejected.")
	TEST_ASSERT(!fexists(SStitle.title_settings_file), "An unchanged appearance rewrote settings.")
	TEST_ASSERT_EQUAL(SStitle.published_title_payload, published, "An unchanged appearance was republished.")
	TEST_ASSERT_EQUAL(SStitle.title_asset_generation, generation, "An unchanged appearance registered another title image.")
	TEST_ASSERT(!SStitle.title_screen_settings["alpha.png"], "An unchanged default appearance created a redundant persisted record.")
	TEST_ASSERT(!SStitle.set_screen_settings("alpha.png", list("variant" = "invalid")), "The no-change path accepted an invalid appearance.")

/// Teardown must restore every published-state/cache reference and leave real
/// persistence unchanged, including when Run exits before its normal end.
/datum/unit_test/title_screen_test_isolation

/datum/unit_test/title_screen_test_isolation/Run()
	var/datum/title_screen_test_state/fixture = allocate(/datum/title_screen_test_state)
	var/list/saved_title_vars = fixture.saved_title_vars.Copy()
	var/datum/asset_transport/saved_transport = fixture.saved_transport
	var/list/saved_lobby_menus = fixture.saved_lobby_menus
	var/list/saved_clients = fixture.saved_clients
	var/list/saved_cache = SSassets.cache
	var/list/saved_cache_entries = saved_cache.Copy()
	var/real_settings_file = saved_title_vars["title_settings_file"]
	var/real_settings_existed = fexists(real_settings_file)
	var/real_settings_contents = file2text(real_settings_file)
	var/test_settings_file = fixture.settings_file

	SStitle.set_screen_settings("alpha.png", list("wordmark" = TRUE))
	SStitle.set_title_selection("alpha.png")
	SStitle.set_title_rotation(FALSE)
	SStitle.get_title_screen_options()
	TEST_ASSERT(fexists(test_settings_file), "The fixture did not exercise its isolated settings file.")
	TEST_ASSERT(length(SStitle.preview_assets_registered), "The fixture did not exercise preview registration.")
	// This is the same Destroy path used by the runner after an early assertion
	// return; invoking it here lets the remaining assertions inspect restoration.
	qdel(fixture)

	for(var/field in saved_title_vars)
		TEST_ASSERT_EQUAL(SStitle.vars[field], saved_title_vars[field], "Title teardown failed to restore [field].")
	TEST_ASSERT_EQUAL(SSassets.transport, saved_transport, "Title teardown retained its fake asset transport.")
	TEST_ASSERT_EQUAL(GLOB.lobby_menus, saved_lobby_menus, "Title teardown lost the lobby recipients.")
	TEST_ASSERT_EQUAL(GLOB.clients, saved_clients, "Title teardown lost the client list.")
	TEST_ASSERT_EQUAL(SSassets.cache, saved_cache, "Title tests replaced the server asset cache.")
	TEST_ASSERT_EQUAL(length(SSassets.cache), length(saved_cache_entries), "Title tests added or removed server asset entries.")
	for(var/asset_name in saved_cache_entries)
		TEST_ASSERT_EQUAL(SSassets.cache[asset_name], saved_cache_entries[asset_name], "Title tests replaced server asset [asset_name].")
	TEST_ASSERT(!fexists(test_settings_file), "Title teardown left its temporary settings file behind.")
	TEST_ASSERT_EQUAL(fexists(real_settings_file), real_settings_existed, "Title tests created or removed the real settings file.")
	TEST_ASSERT_EQUAL(file2text(real_settings_file), real_settings_contents, "Title tests changed the real settings file.")
