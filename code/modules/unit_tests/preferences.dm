/// Requires all preferences to implement required methods.
/datum/unit_test/preferences_implement_everything

/datum/unit_test/preferences_implement_everything/Run()
	var/datum/preferences/preferences = new(new /datum/client_interface)
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)

	for (var/preference_type in GLOB.preference_entries)
		var/datum/preference/preference = GLOB.preference_entries[preference_type]
		if (preference.savefile_identifier == PREFERENCE_CHARACTER)
			preference.apply_to_human(human, preference.create_informed_default_value(preferences), preferences)

		if (istype(preference, /datum/preference/choiced))
			var/datum/preference/choiced/choiced_preference = preference
			choiced_preference.init_possible_values()

		// Smoke-test is_valid
		preference.is_valid(TRUE)
		preference.is_valid("string")
		preference.is_valid(100)
		preference.is_valid(list(1, 2, 3))

/// Requires all preferences to have a valid, unique savefile_identifier.
/datum/unit_test/preferences_valid_savefile_key

/datum/unit_test/preferences_valid_savefile_key/Run()
	var/list/known_savefile_keys = list()

	for (var/preference_type in GLOB.preference_entries)
		var/datum/preference/preference = GLOB.preference_entries[preference_type]
		if (!istext(preference.savefile_key))
			TEST_FAIL("[preference_type] has an invalid savefile_key.")

		if (preference.savefile_key in known_savefile_keys)
			TEST_FAIL("[preference_type] has a non-unique savefile_key `[preference.savefile_key]`!")

		known_savefile_keys += preference.savefile_key

/// Requires all main features have a main_feature_name
/datum/unit_test/preferences_valid_main_feature_name

/datum/unit_test/preferences_valid_main_feature_name/Run()
	for (var/preference_type in GLOB.preference_entries)
		var/datum/preference/choiced/preference = GLOB.preference_entries[preference_type]
		if (!istype(preference))
			continue

		if (preference.category != PREFERENCE_CATEGORY_FEATURES && preference.category != PREFERENCE_CATEGORY_CLOTHING)
			continue

		TEST_ASSERT(!isnull(preference.main_feature_name), "Preference [preference_type] does not have a main_feature_name set!")

/// Validates that every choiced preference with should_generate_icons implements icon_for,
/// and that every one that doesn't, doesn't.
/datum/unit_test/preferences_should_generate_icons_sanity

/datum/unit_test/preferences_should_generate_icons_sanity/Run()
	for (var/preference_type in GLOB.preference_entries)
		var/datum/preference/choiced/choiced_preference = GLOB.preference_entries[preference_type]
		if (!istype(choiced_preference) || choiced_preference.abstract_type == preference_type)
			continue

		var/list/values = choiced_preference.get_choices()

		if (choiced_preference.should_generate_icons)
			for (var/value in values)
				var/icon = choiced_preference.icon_for(value)
				TEST_ASSERT(istype(icon, /datum/universal_icon) || ispath(icon), "[preference_type] gave [icon] as an icon for [value], which is not a valid value")
		else
			var/errored = FALSE

			try
				choiced_preference.icon_for(values[1])
			catch
				errored = TRUE

			TEST_ASSERT(errored, "[preference_type] implemented icon_for, but does not have should_generate_icons = TRUE")
// APHELION EDIT ADDITION START - MERIDIAN_UI

/datum/unit_test/preferences_pda_theme_migration

/datum/unit_test/preferences_pda_theme_migration/Run()
	var/datum/preference/choiced/pda_theme/preference = GLOB.preference_entries[/datum/preference/choiced/pda_theme]
	var/list/legacy_names = list(
		PDA_THEME_NTOS_LEGACY_NAME = PDA_THEME_MERIDIAN_NAME,
		PDA_THEME_DARK_MODE_LEGACY_NAME = PDA_THEME_DARK_MODE_NAME,
		PDA_THEME_LIGHT_MODE_LEGACY_NAME = PDA_THEME_LIGHT_MODE_NAME,
	)
	for(var/legacy_name in legacy_names)
		var/canonical_name = legacy_names[legacy_name]
		var/loaded_name = preference.deserialize(legacy_name, null)
		TEST_ASSERT_EQUAL(loaded_name, canonical_name, "A saved legacy PDA theme lost its selection.")
		TEST_ASSERT_EQUAL(preference.serialize(loaded_name), canonical_name, "A migrated theme saved its obsolete name again.")
		TEST_ASSERT_EQUAL(GLOB.pda_name_to_theme[loaded_name], GLOB.default_pda_themes[canonical_name], "The migrated preference resolved to the wrong device theme.")
		TEST_ASSERT(!(legacy_name in GLOB.default_pda_themes), "A legacy name leaked into PDA preference choices.")
		TEST_ASSERT(!(legacy_name in GLOB.pda_name_to_theme), "A legacy name leaked into the clear PDA theme catalog.")

	for(var/theme_name in GLOB.default_pda_themes)
		TEST_ASSERT_EQUAL(preference.deserialize(theme_name, null), theme_name, "An existing PDA theme failed to round-trip.")
	TEST_ASSERT_EQUAL(preference.deserialize("unknown theme", null), preference.create_default_value(), "An invalid PDA theme did not fall back to the default.")
	TEST_ASSERT_EQUAL(preference.deserialize(null, null), preference.create_default_value(), "A missing PDA theme did not fall back to the default.")
	TEST_ASSERT_EQUAL(preference.deserialize(list(PDA_THEME_LIGHT_MODE_LEGACY_NAME), null), preference.create_default_value(), "A non-text PDA theme did not fall back to the default.")

	var/obj/item/modular_computer/pda/clear/pda = allocate(/obj/item/modular_computer/pda/clear)
	var/datum/computer_file/program/themeify/theme_app = locate() in pda.stored_files
	TEST_ASSERT(theme_app, "The clear PDA did not initialize its theme selector.")
	var/list/theme_data = theme_app.ui_data(null)
	var/list/seen_themes = list()
	for(var/list/theme in theme_data["themes"])
		var/theme_ref = theme["theme_ref"]
		TEST_ASSERT(theme_ref, "The clear PDA exposed a theme without a valid identifier.")
		TEST_ASSERT(!(theme_ref in seen_themes), "The clear PDA exposed duplicate theme choices.")
		seen_themes += theme_ref
	TEST_ASSERT_EQUAL(length(seen_themes), length(GLOB.pda_name_to_theme), "The clear PDA lost a supported theme.")

/datum/unit_test/preferences_meridian_theme

/datum/unit_test/preferences_meridian_theme/Run()
	var/datum/preference/choiced/meridian_theme/preference = GLOB.preference_entries[/datum/preference/choiced/meridian_theme]
	var/list/expected_ids = list(
		"meridian",
		"meridian_classic",
		"meridian_pipboy",
		"meridian_vector",
		"meridian_foundry",
		"meridian_diagnostic",
		"meridian_highline",
		"meridian_synapse",
		"meridian_cyberpunk",
		"meridian_augmentation",
		"meridian_afterlight",
		"meridian_relay",
		"meridian_bastion",
		"meridian_aphelion",
	)
	var/list/actual_ids = preference.get_choices()

	TEST_ASSERT_EQUAL(preference.savefile_key, "meridian_theme", "MeridianOS theme changed its persistent save key.")
	TEST_ASSERT_EQUAL(preference.savefile_identifier, PREFERENCE_PLAYER, "MeridianOS theme must remain account-wide.")
	TEST_ASSERT_EQUAL(preference.create_default_value(), "meridian", "MeridianOS Standard must remain the default.")
	TEST_ASSERT_EQUAL(length(actual_ids), length(expected_ids), "MeridianOS theme choices changed size.")
	for(var/index in 1 to length(expected_ids))
		TEST_ASSERT_EQUAL(actual_ids[index], expected_ids[index], "MeridianOS theme choice [index] changed order or ID.")

	TEST_ASSERT_EQUAL(preference.category, PREFERENCE_CATEGORY_MANUALLY_RENDERED, "MeridianOS theme must remain exclusive to the gear menu.")
	TEST_ASSERT(!preference.is_valid("meridian_unknown", null), "MeridianOS theme accepted an unknown raw ID.")
	TEST_ASSERT(!preference.is_valid(list("meridian"), null), "MeridianOS theme accepted a non-text raw value.")

	var/datum/client_interface/meridian_theme_unit_test/test_client = allocate(/datum/client_interface/meridian_theme_unit_test)
	var/datum/preferences/meridian_theme_unit_test/test_preferences = allocate(/datum/preferences/meridian_theme_unit_test, test_client)
	test_client.prefs = test_preferences
	var/datum/lobby_menu/meridian_theme_unit_test/test_lobby = allocate(/datum/lobby_menu/meridian_theme_unit_test)
	test_client.lobby_menu = test_lobby
	test_preferences.value_cache[preference.type] = "meridian"
	test_preferences.recently_updated_keys = list()
	test_preferences.save_call_count = 0

	var/mob/test_mob = allocate(/mob)
	test_client.mob = test_mob
	var/datum/tgui/meridian_theme_unit_test/first_ui = allocate(/datum/tgui/meridian_theme_unit_test)
	var/datum/tgui/meridian_theme_unit_test/second_ui = allocate(/datum/tgui/meridian_theme_unit_test)
	test_mob.tgui_open_uis = list(first_ui, second_ui)
	var/datum/client_interface/meridian_theme_unit_test/other_client = allocate(/datum/client_interface/meridian_theme_unit_test)
	var/datum/preferences/meridian_theme_unit_test/other_preferences = allocate(/datum/preferences/meridian_theme_unit_test, other_client)
	other_client.prefs = other_preferences
	var/datum/lobby_menu/meridian_theme_unit_test/other_lobby = allocate(/datum/lobby_menu/meridian_theme_unit_test)
	other_client.lobby_menu = other_lobby
	other_preferences.value_cache[preference.type] = "meridian"
	other_preferences.recently_updated_keys = list()
	other_preferences.save_call_count = 0

	TEST_ASSERT(!test_client.set_meridian_theme("meridian_unknown"), "Unknown wire IDs must be rejected before preference deserialization.")
	TEST_ASSERT(!test_client.set_meridian_theme(list("meridian_vector")), "Non-text wire values must be rejected.")
	TEST_ASSERT_EQUAL(test_preferences.read_preference(preference.type), "meridian", "Rejected input changed the saved theme.")
	TEST_ASSERT_EQUAL(test_preferences.save_call_count, 0, "Rejected input attempted to persist preferences.")
	TEST_ASSERT_EQUAL(first_ui.config_update_count, 0, "Rejected input broadcast a config update.")
	TEST_ASSERT_EQUAL(test_lobby.update_count, 0, "Rejected input broadcast a lobby update.")

	TEST_ASSERT(test_client.set_meridian_theme("meridian_pipboy"), "A valid theme selection was rejected.")
	TEST_ASSERT_EQUAL(test_preferences.read_preference(preference.type), "meridian_pipboy", "A valid theme selection was not applied.")
	TEST_ASSERT_EQUAL(test_preferences.save_call_count, 1, "A valid selection was not persisted immediately and exactly once.")
	TEST_ASSERT_EQUAL(first_ui.config_update_count, 1, "The first open TGUI did not receive the preference update.")
	TEST_ASSERT_EQUAL(second_ui.config_update_count, 1, "The second open TGUI did not receive the preference update.")
	TEST_ASSERT_EQUAL(test_lobby.update_count, 1, "The open lobby did not receive the preference update.")
	TEST_ASSERT_EQUAL(test_lobby.captured_theme, "meridian_pipboy", "The lobby received a non-canonical preference value.")

	TEST_ASSERT(test_client.set_meridian_theme("meridian_pipboy"), "Reselecting the canonical value should be a successful no-op.")
	TEST_ASSERT_EQUAL(test_preferences.save_call_count, 1, "Reselecting the canonical value persisted redundantly.")
	TEST_ASSERT_EQUAL(first_ui.config_update_count, 1, "Reselecting the canonical value broadcast redundantly.")
	TEST_ASSERT_EQUAL(test_lobby.update_count, 1, "Reselecting the canonical value broadcast to the lobby redundantly.")

	TEST_ASSERT(test_client.set_meridian_theme("meridian_aphelion"), "The Aphelion theme selection was rejected.")
	TEST_ASSERT_EQUAL(test_preferences.read_preference(preference.type), "meridian_aphelion", "The Aphelion selection was not applied.")
	TEST_ASSERT_EQUAL(preference.deserialize(preference.serialize("meridian_aphelion"), null), "meridian_aphelion", "The saved Aphelion selection did not round-trip.")
	TEST_ASSERT_EQUAL(test_preferences.save_call_count, 2, "The Aphelion selection was not persisted exactly once.")
	TEST_ASSERT_EQUAL(first_ui.config_update_count, 2, "The first open TGUI did not receive the Aphelion update.")
	TEST_ASSERT_EQUAL(second_ui.config_update_count, 2, "The second open TGUI did not receive the Aphelion update.")
	TEST_ASSERT_EQUAL(test_lobby.update_count, 2, "The open lobby did not receive the Aphelion update.")
	TEST_ASSERT_EQUAL(test_lobby.captured_theme, "meridian_aphelion", "The lobby received the wrong Aphelion preference ID.")

	TEST_ASSERT_EQUAL(other_preferences.read_preference(preference.type), "meridian", "One client's selection mutated another preference owner.")
	TEST_ASSERT_EQUAL(other_preferences.save_call_count, 0, "One client's selection persisted another preference owner.")
	TEST_ASSERT_EQUAL(other_lobby.update_count, 0, "One client's selection broadcast to another client's lobby.")

/datum/client_interface/meridian_theme_unit_test
	var/datum/lobby_menu/meridian_theme_unit_test/lobby_menu

/datum/client_interface/meridian_theme_unit_test/Destroy()
	// Mock clients are datums, so sever the preference ownership cycle.
	prefs = null
	lobby_menu = null
	mob = null
	return ..()

/datum/preferences/meridian_theme_unit_test
	var/save_call_count = 0

/datum/preferences/meridian_theme_unit_test/Destroy()
	parent = null
	return ..()

/datum/preferences/meridian_theme_unit_test/save_preferences()
	save_call_count++
	return TRUE

/datum/tgui/meridian_theme_unit_test
	var/config_update_count = 0

/datum/tgui/meridian_theme_unit_test/New()
	// This test sink only records updates; it has no live UI owner.
	return

/datum/tgui/meridian_theme_unit_test/send_config_update()
	config_update_count++
	return TRUE

/datum/lobby_menu/meridian_theme_unit_test
	var/update_count = 0
	var/captured_theme

/datum/lobby_menu/meridian_theme_unit_test/New()
	// Skip browser creation and subscriptions for this update-only test sink.
	return

/datum/lobby_menu/meridian_theme_unit_test/send_update(list/data)
	update_count++
	captured_theme = data["meridianTheme"]
// APHELION EDIT ADDITION END
