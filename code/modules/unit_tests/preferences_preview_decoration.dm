/datum/unit_test/preferences_preview_decoration

/datum/unit_test/preferences_preview_decoration/Run()
	var/static/list/body_regions = list(
		BODY_ZONE_HEAD,
		BODY_ZONE_CHEST,
		BODY_ZONE_L_ARM,
		BODY_ZONE_PRECISE_L_HAND,
		BODY_ZONE_L_LEG,
		BODY_ZONE_R_ARM,
		BODY_ZONE_PRECISE_R_HAND,
		BODY_ZONE_R_LEG,
	)
	var/static/list/implant_regions = list(
		"brain",
		"eyes",
		"tongue",
		"heart",
		"stomach",
		"ears",
		"mouth",
		"lungs",
		"liver",
	)
	var/static/list/mode_regions = list(
		MERIDIAN_PREVIEW_DECORATION_AUGMENTATION_MARKINGS = body_regions,
		MERIDIAN_PREVIEW_DECORATION_AUGMENTATION_BODY_PARTS = body_regions,
		MERIDIAN_PREVIEW_DECORATION_AUGMENTATION_IMPLANTS = implant_regions,
	)
	var/static/list/icon_contracts = list(
		list("path" = 'modular_nova/modules/character_preview_background/icons/preview_decoration_32x32.dmi', "size" = 32),
		list("path" = 'modular_nova/modules/character_preview_background/icons/preview_decoration_64x64.dmi', "size" = 64),
		list("path" = 'modular_nova/modules/character_preview_background/icons/preview_decoration_96x96.dmi', "size" = 96),
	)
	var/list/expected_states = list()
	for(var/mode in mode_regions)
		expected_states += mode
		for(var/region in mode_regions[mode])
			expected_states += "[mode]--[region]"

	for(var/list/icon_contract as anything in icon_contracts)
		var/icon_path = icon_contract["path"]
		var/expected_size = icon_contract["size"]
		var/list/states = icon_states(icon_path, TRUE)
		TEST_ASSERT_EQUAL(length(states), length(expected_states), "Preview decoration [icon_path] must expose only the finite base and selected-region states.")
		for(var/expected_state in expected_states)
			TEST_ASSERT(expected_state in states, "Preview decoration [icon_path] is missing [expected_state].")

		for(var/icon_state in states)
			for(var/direction in list(SOUTH, NORTH, EAST, WEST))
				var/icon/state_icon = icon(icon_path, icon_state, direction)
				TEST_ASSERT_EQUAL(state_icon.Width(), expected_size, "Preview decoration [icon_path]/[icon_state]/[direction] changed width.")
				TEST_ASSERT_EQUAL(state_icon.Height(), expected_size, "Preview decoration [icon_path]/[icon_state]/[direction] changed height.")

	var/atom/movable/screen/map_view/char_preview/preview = new(null, null, null)
	preview.canvas = image('modular_nova/modules/character_preview_background/icons/background_32x32.dmi', icon_state = "Black")
	preview.last_canvas_size = 0

	TEST_ASSERT_EQUAL(preview.meridian_decoration_mode, MERIDIAN_PREVIEW_DECORATION_NONE, "Preview decoration should begin disabled until TGUI resolves its visible page.")
	TEST_ASSERT_NULL(preview.meridian_decoration_region, "Preview decoration should not begin with a selected region.")
	for(var/mode in mode_regions)
		TEST_ASSERT(preview.set_meridian_decoration(mode, null), "Preview rejected base mode [mode].")
		TEST_ASSERT_EQUAL(preview.get_meridian_decoration_state(), mode, "Base mode [mode] did not select its corner-only state.")
		TEST_ASSERT_EQUAL(length(preview.canvas.overlays), 1, "Changing Augments tabs should replace, not stack, the native overlay.")

		for(var/region in mode_regions[mode])
			TEST_ASSERT(preview.set_meridian_decoration(mode, region), "Preview rejected [mode] region [region].")
			TEST_ASSERT_EQUAL(preview.meridian_decoration_mode, mode, "Preview did not retain [mode].")
			TEST_ASSERT_EQUAL(preview.meridian_decoration_region, region, "Preview did not retain [mode] region [region].")
			TEST_ASSERT_EQUAL(preview.get_meridian_decoration_state(), "[mode]--[region]", "Preview selected the wrong state for [mode] region [region].")
			TEST_ASSERT_EQUAL(length(preview.canvas.overlays), 1, "Changing regions should replace, not stack, the native overlay.")

	var/retained_mode = preview.meridian_decoration_mode
	var/retained_region = preview.meridian_decoration_region
	TEST_ASSERT(!preview.set_meridian_decoration(MERIDIAN_PREVIEW_DECORATION_AUGMENTATION_IMPLANTS, BODY_ZONE_HEAD), "Implants mode accepted a body-part region.")
	TEST_ASSERT(!preview.set_meridian_decoration(MERIDIAN_PREVIEW_DECORATION_AUGMENTATION_MARKINGS, "brain"), "Markings mode accepted an implant region.")
	TEST_ASSERT(!preview.set_meridian_decoration("body_zone_head", BODY_ZONE_HEAD), "Preview accepted an out-of-contract decoration mode.")
	TEST_ASSERT(!preview.set_meridian_decoration(MERIDIAN_PREVIEW_DECORATION_NONE, BODY_ZONE_HEAD), "None mode accepted a selected region.")
	TEST_ASSERT_EQUAL(preview.meridian_decoration_mode, retained_mode, "Invalid input changed the current decoration mode.")
	TEST_ASSERT_EQUAL(preview.meridian_decoration_region, retained_region, "Invalid input changed the current decoration region.")

	TEST_ASSERT(preview.set_meridian_decoration(MERIDIAN_PREVIEW_DECORATION_AUGMENTATION_BODY_PARTS, BODY_ZONE_L_ARM), "Preview rejected the direction test region.")
	for(var/direction in list(SOUTH, NORTH, EAST, WEST))
		preview.setDir(direction)
		TEST_ASSERT_EQUAL(preview.dir, direction, "Rebuilding the canvas reset preview direction [direction].")
		TEST_ASSERT_EQUAL(preview.meridian_decoration_overlay.dir, direction, "Preview decoration did not follow direction [direction].")
		TEST_ASSERT_EQUAL(preview.meridian_decoration_overlay.icon_state, "[MERIDIAN_PREVIEW_DECORATION_AUGMENTATION_BODY_PARTS]--[BODY_ZONE_L_ARM]", "Rotation changed the selected region state.")
		TEST_ASSERT_EQUAL(length(preview.canvas.overlays), 1, "Rotation stacked native decoration overlays.")

	TEST_ASSERT(preview.set_meridian_decoration(MERIDIAN_PREVIEW_DECORATION_NONE, null), "Preview rejected the none decoration mode.")
	TEST_ASSERT_NULL(preview.meridian_decoration_region, "Disabling decoration retained a selected region.")
	TEST_ASSERT_NULL(preview.meridian_decoration_overlay, "Disabling decoration retained its image reference.")
	TEST_ASSERT_EQUAL(length(preview.canvas.overlays), 0, "Disabling decoration should remove the native overlay.")

	qdel(preview)
	TEST_ASSERT(QDELETED(preview), "Destroying the preview left its map-view object alive.")
