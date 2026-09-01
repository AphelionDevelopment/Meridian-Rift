/datum/unit_test/preferences_preview_decoration

/datum/unit_test/preferences_preview_decoration/Run()
	var/static/list/augmentation_states = list(
		MERIDIAN_PREVIEW_DECORATION_AUGMENTATION_MARKINGS,
		MERIDIAN_PREVIEW_DECORATION_AUGMENTATION_BODY_PARTS,
		MERIDIAN_PREVIEW_DECORATION_AUGMENTATION_IMPLANTS,
	)
	var/static/list/icon_contracts = list(
		list("path" = 'modular_nova/modules/character_preview_background/icons/preview_decoration_32x32.dmi', "size" = 32),
		list("path" = 'modular_nova/modules/character_preview_background/icons/preview_decoration_64x64.dmi', "size" = 64),
		list("path" = 'modular_nova/modules/character_preview_background/icons/preview_decoration_96x96.dmi', "size" = 96),
	)

	for(var/list/icon_contract as anything in icon_contracts)
		var/icon_path = icon_contract["path"]
		var/expected_size = icon_contract["size"]
		var/list/states = icon_states(icon_path, TRUE)
		TEST_ASSERT_EQUAL(length(states), length(augmentation_states), "Preview decoration [icon_path] must expose exactly three finite Augments states.")
		for(var/expected_state in augmentation_states)
			TEST_ASSERT(expected_state in states, "Preview decoration [icon_path] is missing [expected_state].")

		for(var/icon_state in states)
			var/icon/state_icon = icon(icon_path, icon_state)
			TEST_ASSERT_EQUAL(state_icon.Width(), expected_size, "Preview decoration [icon_path]/[icon_state] changed width.")
			TEST_ASSERT_EQUAL(state_icon.Height(), expected_size, "Preview decoration [icon_path]/[icon_state] changed height.")

	var/atom/movable/screen/map_view/char_preview/preview = new(null, null, null)
	preview.canvas = image('modular_nova/modules/character_preview_background/icons/background_32x32.dmi', icon_state = "Black")
	preview.last_canvas_size = 0

	TEST_ASSERT_EQUAL(preview.meridian_decoration_mode, MERIDIAN_PREVIEW_DECORATION_NONE, "Preview decoration should begin disabled until TGUI resolves its visible page.")
	for(var/active_state in augmentation_states)
		TEST_ASSERT(preview.set_meridian_decoration(active_state), "Preview rejected [active_state].")
		TEST_ASSERT_EQUAL(preview.meridian_decoration_mode, active_state, "Preview did not retain [active_state].")
		TEST_ASSERT_EQUAL(length(preview.canvas.overlays), 1, "Changing Augments tabs should replace, not stack, the native overlay.")

	TEST_ASSERT(!preview.set_meridian_decoration("body_zone_head"), "Preview accepted an out-of-contract anatomical decoration mode.")
	TEST_ASSERT_EQUAL(preview.meridian_decoration_mode, MERIDIAN_PREVIEW_DECORATION_AUGMENTATION_IMPLANTS, "Invalid input changed the current decoration mode.")
	TEST_ASSERT(preview.set_meridian_decoration(MERIDIAN_PREVIEW_DECORATION_NONE), "Preview rejected the none decoration mode.")
	TEST_ASSERT_EQUAL(length(preview.canvas.overlays), 0, "Disabling decoration should remove the native overlay.")

	qdel(preview)
	TEST_ASSERT(QDELETED(preview), "Destroying the preview left its map-view object alive.")
