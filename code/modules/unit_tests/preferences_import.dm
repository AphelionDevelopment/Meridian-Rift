/// Missing and empty preset collections must be safe before character migrations run.
/datum/unit_test/preferences_import_loadout_defaults/Run()
	var/list/legacy = list("/obj/item/cane" = list("name" = "Walking stick"))
	var/list/fixtures = list(
		list("version" = 52, "loadout_list" = legacy),
		list("version" = 52, "loadout_lists" = list()),
		list("version" = 52),
	)
	for(var/list/slot as anything in fixtures)
		prefs_import_pass1(list("version" = 52, "character1" = slot))
		var/list/presets = slot["loadout_lists"]
		TEST_ASSERT(length(presets), "Import left no preset for the loadout-index default before migration.")
		TEST_ASSERT(istext(presets[1]), "The first preset must be a usable loadout-index default.")
		if(slot["loadout_list"])
			TEST_ASSERT_EQUAL(json_encode(presets["Default"]), json_encode(legacy), "The legacy loadout was lost while supplying a modern default.")

/// JSON arrays inside item details must not become numeric list indexes.
/datum/unit_test/preferences_import_loadout_details/Run()
	var/list/clean
	try
		clean = prefs_import_clean_loadout(list("/obj/item/cane" = list(999, null, list(999))))
	catch
		TEST_FAIL("Malformed loadout detail keys caused a runtime instead of being discarded.")
		return
	TEST_ASSERT_EQUAL(length(clean["/obj/item/cane"]), 0, "Malformed loadout details were retained.")

	clean = prefs_import_clean_loadout(list("/obj/item/cane" = list("name" = "<b>Stick</b>", "description" = "A stick.")))
	var/list/details = clean["/obj/item/cane"]
	TEST_ASSERT_EQUAL(details["name"], html_encode("<b>Stick</b>"), "Imported names need the same HTML encoding as UI input.")
	TEST_ASSERT_EQUAL(details["description"], "A stick.", "A valid description was changed.")
	clean = prefs_import_clean_loadout(list("/obj/item/cane" = list("name" = list("invalid"), "description" = 999)))
	TEST_ASSERT_EQUAL(length(clean["/obj/item/cane"]), 0, "Structured or numeric values cannot be used as item names or descriptions.")

/datum/unit_test/preferences_import_registry_values/Run()
	var/list/slot = list("version" = 52, "augments" = list("head" = 999), "augment_limb_styles" = list("head" = list(999)), "languages" = list("/datum/language/common" = 3))
	prefs_import_pass1(list("version" = 52, "character1" = slot))
	TEST_ASSERT_EQUAL(length(slot["augments"]), 0, "A numeric augment would index its owner's registry out of bounds.")
	TEST_ASSERT_EQUAL(length(slot["augment_limb_styles"]), 0, "A structured augment style must not reach the owner's registry.")
	TEST_ASSERT_EQUAL(length(slot["languages"]), 1, "Valid numeric language flags were removed.")

/// These raw fields are consumed before native loaders reach their normal sanitizers.
/datum/unit_test/preferences_import_raw_player_fields/Run()
	var/list/upload = list("version" = 52, "preferred_spawn_outfits" = list(999), "key_bindings" = list(999), "favorite_outfits" = list(999))
	var/list/clean = prefs_import_pass1(upload)
	TEST_ASSERT_EQUAL(length(clean["preferred_spawn_outfits"]), 0, "A numeric spawn-outfit key will index its list out of bounds during load_preferences.")
	TEST_ASSERT_EQUAL(length(clean["key_bindings"]), 0, "A numeric keybinding key will reach the keybinding migration before sanitization.")
	TEST_ASSERT_EQUAL(length(clean["favorite_outfits"]), 0, "A numeric outfit type will reach text2path before sanitization.")

	upload = list("version" = 35, "key_bindings" = list("ShiftQ" = "quick_equip_belt", "X" = list("swap_hands", 999)), "preferred_spawn_outfits" = list("Normal" = "Naked"))
	clean = prefs_import_pass1(upload)
	var/list/bindings = clean["key_bindings"]
	TEST_ASSERT_EQUAL(json_encode(bindings["ShiftQ"]), json_encode(list("quick_equip_belt")), "Supported legacy scalar keybindings were lost.")
	TEST_ASSERT_EQUAL(json_encode(bindings["X"]), json_encode(list("swap_hands")), "Valid keybinding entries were lost while rejecting a hostile entry.")
	var/list/outfits = clean["preferred_spawn_outfits"]
	TEST_ASSERT_EQUAL(outfits["Normal"], "Naked", "The native special-case Naked outfit was lost.")

/// Exported names already contain HTML entities and must survive a round trip unchanged.
/datum/unit_test/preferences_import_encoded_loadouts/Run()
	var/name = "A &amp; B"
	var/list/input_presets = list()
	input_presets[name] = list("/obj/item/cane" = list("name" = name))
	var/list/slot = list("version" = 52, "loadout_lists" = input_presets, "loadout_index" = name)
	prefs_import_pass1(list("version" = 52, "character1" = slot))
	var/list/presets = slot["loadout_lists"]
	TEST_ASSERT(name in presets, "Import double-encoded an exported preset name.")
	TEST_ASSERT_EQUAL(slot["loadout_index"], name, "Import changed the selected exported preset.")
	var/list/loadout = presets[name]
	var/list/details = loadout?["/obj/item/cane"]
	TEST_ASSERT_EQUAL(details?["name"], name, "Import double-encoded an exported custom item name.")

/// Player-owned fields import; the destination server retains its commendation state.
/datum/unit_test/preferences_import_server_metadata/Run()
	var/list/upload = list("version" = 52, "hearted_until" = 999999999, "unrecognised_server_state" = TRUE, "sound_tts_blips" = TRUE)
	var/list/local_metadata = list("hearted_until" = 1234, "aphelion_import_notice_seen" = TRUE)
	var/list/clean = prefs_import_pass1(upload, local_metadata)
	TEST_ASSERT_EQUAL(clean["hearted_until"], 1234, "A player import replaced the server's commendation state.")
	TEST_ASSERT_EQUAL(clean["aphelion_import_notice_seen"], TRUE, "A player import lost the destination server's notice state.")
	TEST_ASSERT(!("unrecognised_server_state" in clean), "An unknown root field bypassed the player import allowlist.")
	TEST_ASSERT_EQUAL(clean["sound_tts_blips"], TRUE, "An input required by the legacy sound migration was removed.")

	clean = prefs_import_pass1(list("version" = 52, "hearted_until" = 999999999), list())
	TEST_ASSERT_NULL(clean["hearted_until"], "An upload granted a commendation to an account with none locally.")

	clean = prefs_import_pass1(list("version" = 52, "hearted_until" = 1234))
	TEST_ASSERT_EQUAL(clean["hearted_until"], 1234, "Staff imports must retain their existing ability to restore a complete backup.")

/// Use the native loadout preference and Nova migration with a supported pre-preset character.
/datum/unit_test/preferences_import_legacy_character/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/list/slot = list(
		"version" = 52,
		"modular_version" = 11,
		"tgui_prefs_migration" = TRUE,
		"real_name" = "Legacy Import",
		"loadout_list" = list("/obj/item/cane" = list("name" = "Walking stick")),
	)
	prefs_import_pass1(list("version" = 52, "character1" = slot))
	preferences.savefile.set_entry("character1", slot)
	preferences.value_cache = list()
	TEST_ASSERT_EQUAL(preferences.read_preference(/datum/preference/loadout_index), "Default", "A legacy character cannot obtain a valid loadout index before migration.")
	TEST_ASSERT(preferences.load_character(), "A supported legacy character failed the native loader.")
	var/list/presets = preferences.read_preference(/datum/preference/loadout)
	var/list/loadout = presets["Default"]
	TEST_ASSERT(/obj/item/cane in loadout, "The native migration lost the imported cane.")
	var/list/details = loadout[/obj/item/cane]
	TEST_ASSERT_EQUAL(details["name"], "Walking stick", "The native migration lost custom item details.")
	TEST_ASSERT_EQUAL(preferences.read_preference(/datum/preference/name/real_name), "Legacy Import", "The native migration changed a valid character name.")

	// A current root version must not prevent migration of a secondary legacy slot.
	var/list/second_slot = deep_copy_list(slot)
	second_slot["real_name"] = "Second Import"
	second_slot["modular_version"] = 11
	preferences.savefile.set_entry("character2", second_slot)
	preferences.savefile.set_entry("aphelion_import_pending", TRUE)
	TEST_ASSERT(preferences.prefs_import_finalise(), "The pending import was not finalized.")
	TEST_ASSERT(second_slot["modular_version"] > 11, "The secondary slot was rebuilt without running its native migration.")
	TEST_ASSERT_EQUAL(preferences.default_slot, 1, "Finalizing secondary slots changed the selected character.")
	TEST_ASSERT_EQUAL(preferences.read_preference(/datum/preference/name/real_name), "Legacy Import", "Finalizing secondary slots left the wrong character loaded.")

/// A memory-only savefile: all normal migrations run, with no real player's path available.
/datum/preferences/preferences_import_test/load_path(ckey, filename)
	load_and_save = FALSE
	path = "preferences_import_memory_only"

/// Failed candidate verification or pending recovery must leave the original file intact.
/datum/unit_test/preferences_import_replacement
	var/test_path = "data/preferences_import_unit_test.json"

/datum/unit_test/preferences_import_replacement/Destroy()
	for(var/suffix in list("", ".importtmp", ".importrestore", ".updatebac"))
		fdel("[test_path][suffix]")
	return ..()

/datum/unit_test/preferences_import_replacement/Run()
	fdel(test_path)
	TEST_ASSERT(text2file("{\"version\":52,\"original\":true}", test_path), "Could not create the disposable import fixture.")
	var/original = file2text(test_path)
	TEST_ASSERT(prefs_import_replace(test_path, "invalid JSON"), "A malformed candidate was reported as successfully installed.")
	TEST_ASSERT_EQUAL(file2text(test_path), original, "Failed candidate verification changed the live file.")

	TEST_ASSERT(text2file(original, "[test_path].importrestore"), "Could not create the disposable recovery fixture.")
	TEST_ASSERT(prefs_import_replace(test_path, "{\"version\":52}"), "A pending recovery backup was overwritten by another import.")
	TEST_ASSERT_EQUAL(file2text(test_path), original, "A pending recovery changed the live file.")
	fdel("[test_path].importrestore")

	var/list/replacement = list("version" = 52, "character1" = list("real_name" = "Imported Character"))
	TEST_ASSERT_NULL(prefs_import_replace(test_path, json_encode(replacement)), "A valid candidate failed to replace the disposable fixture.")
	TEST_ASSERT_EQUAL(json_encode(json_decode(file2text(test_path))), json_encode(replacement), "The replacement was not written completely or was appended to the old JSON.")
	TEST_ASSERT(!fexists("[test_path].importrestore"), "A successful import left a recovery lock behind.")
