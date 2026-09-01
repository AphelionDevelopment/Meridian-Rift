/datum/unit_test/preferences_preview_decoration

/datum/unit_test/preferences_preview_decoration/Run()
	var/static/list/icon_contracts = list(
		list("path" = 'modular_nova/modules/character_preview_background/icons/preview_decoration_32x32.dmi', "size" = 32),
		list("path" = 'modular_nova/modules/character_preview_background/icons/preview_decoration_64x64.dmi', "size" = 64),
		list("path" = 'modular_nova/modules/character_preview_background/icons/preview_decoration_96x96.dmi', "size" = 96),
	)

	for(var/list/icon_contract as anything in icon_contracts)
		var/icon_path = icon_contract["path"]
		var/expected_size = icon_contract["size"]
		var/list/states = icon_states(icon_path, TRUE)
		TEST_ASSERT_EQUAL(length(states), 2, "Preview decoration [icon_path] must expose exactly two finite states.")
		TEST_ASSERT(MERIDIAN_PREVIEW_DECORATION_STANDARD in states, "Preview decoration [icon_path] is missing its Standard state.")
		TEST_ASSERT(MERIDIAN_PREVIEW_DECORATION_AUGMENTATION in states, "Preview decoration [icon_path] is missing its Augmentation state.")

		for(var/icon_state in states)
			var/icon/state_icon = icon(icon_path, icon_state)
			TEST_ASSERT_EQUAL(state_icon.Width(), expected_size, "Preview decoration [icon_path]/[icon_state] changed width.")
			TEST_ASSERT_EQUAL(state_icon.Height(), expected_size, "Preview decoration [icon_path]/[icon_state] changed height.")

	var/atom/movable/screen/map_view/char_preview/preview = new(null, null, null)
	preview.canvas = image('modular_nova/modules/character_preview_background/icons/background_32x32.dmi', icon_state = "Black")
	preview.last_canvas_size = 0

	TEST_ASSERT_EQUAL(preview.meridian_decoration_mode, MERIDIAN_PREVIEW_DECORATION_NONE, "Preview decoration should begin disabled until TGUI resolves its visible page.")
	TEST_ASSERT(preview.set_meridian_decoration(MERIDIAN_PREVIEW_DECORATION_STANDARD), "Preview rejected the Standard decoration mode.")
	TEST_ASSERT_EQUAL(length(preview.canvas.overlays), 1, "Standard decoration should add exactly one equal-size overlay.")
	TEST_ASSERT(!preview.set_meridian_decoration("body_zone_head"), "Preview accepted an out-of-contract anatomical decoration mode.")
	TEST_ASSERT_EQUAL(preview.meridian_decoration_mode, MERIDIAN_PREVIEW_DECORATION_STANDARD, "Invalid input changed the current decoration mode.")
	TEST_ASSERT(preview.set_meridian_decoration(MERIDIAN_PREVIEW_DECORATION_AUGMENTATION), "Preview rejected the Augmentation decoration mode.")
	TEST_ASSERT_EQUAL(length(preview.canvas.overlays), 1, "Changing decoration should replace, not stack, the native overlay.")
	TEST_ASSERT(preview.set_meridian_decoration(MERIDIAN_PREVIEW_DECORATION_NONE), "Preview rejected the none decoration mode.")
	TEST_ASSERT_EQUAL(length(preview.canvas.overlays), 0, "Disabling decoration should remove the native overlay.")

	qdel(preview)
	TEST_ASSERT(QDELETED(preview), "Destroying the preview left its map-view object alive.")
