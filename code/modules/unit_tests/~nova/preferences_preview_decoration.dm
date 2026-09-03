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

		var/list/expected_left_hand_target
		switch(expected_size)
			if(32)
				expected_left_hand_target = list("x" = 9, "y_top" = 17)
			if(64)
				expected_left_hand_target = list("x" = 25, "y_top" = 49)
			if(96)
				expected_left_hand_target = list("x" = 41, "y_top" = 81)
		var/icon/left_hand_icon = icon(icon_path, "[MERIDIAN_PREVIEW_DECORATION_AUGMENTATION_BODY_PARTS]--[BODY_ZONE_PRECISE_L_HAND]", SOUTH)
		TEST_ASSERT_EQUAL(
			left_hand_icon.GetPixel(expected_left_hand_target["x"] + 1, expected_size - expected_left_hand_target["y_top"]),
			rgb(0, 229, 212, 255),
			"Preview decoration [icon_path] did not keep its left-hand target inside the south-aligned canonical body.",
		)

	var/atom/movable/screen/map_view/char_preview/preview = new(null, null, null)
	preview.canvas = image('modular_nova/modules/character_preview_background/icons/background_32x32.dmi', icon_state = "Black")
	preview.last_canvas_size = 0

	TEST_ASSERT_EQUAL(preview.meridian_decoration_mode, MERIDIAN_PREVIEW_DECORATION_NONE, "Preview decoration should begin disabled until TGUI resolves its visible page.")
	TEST_ASSERT_NULL(preview.meridian_decoration_region, "Preview decoration should not begin with a selected region.")
	for(var/mode in mode_regions)
		TEST_ASSERT(preview.set_meridian_decoration(mode, null), "Preview rejected base mode [mode].")
		TEST_ASSERT_EQUAL(preview.get_meridian_decoration_state(), mode, "Base mode [mode] did not select its corner-only state.")
		TEST_ASSERT_EQUAL(length(preview.canvas.overlays), 1, "Changing Augments tabs should replace, not stack, the native overlay.")
		TEST_ASSERT_EQUAL(preview.meridian_decoration_overlay.plane, HIGH_GAME_PLANE, "Preview frame [mode] is not above the rendered body planes.")
		TEST_ASSERT_EQUAL(preview.meridian_decoration_overlay.layer, FLY_LAYER, "Preview frame [mode] lost its deterministic foreground layer.")

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
		TEST_ASSERT_EQUAL(preview.meridian_decoration_overlay.icon_state, MERIDIAN_PREVIEW_DECORATION_AUGMENTATION_BODY_PARTS, "Rotation changed the fixed frame state.")
		TEST_ASSERT_EQUAL(length(preview.canvas.overlays), 1, "Rotation stacked native decoration overlays.")

	var/matrix/identity_transform = matrix()
	var/list/target_32 = preview.get_meridian_decoration_target(32, SOUTH, 29, 54, identity_transform, 0, 0)
	var/list/target_64 = preview.get_meridian_decoration_target(64, SOUTH, 29, 54, identity_transform, 16, 0)
	var/list/target_96 = preview.get_meridian_decoration_target(96, SOUTH, 29, 54, identity_transform, 32, 0)
	TEST_ASSERT_EQUAL(target_32["x"], 10, "32px left-hand target changed canonical X.")
	TEST_ASSERT_EQUAL(target_32["y"], 15, "32px left-hand target changed canonical Y.")
	TEST_ASSERT_EQUAL(target_64["x"], 26, "64px left-hand target was not centered with the body.")
	TEST_ASSERT_EQUAL(target_64["y"], 15, "64px left-hand target was not south-aligned with the body.")
	TEST_ASSERT_EQUAL(target_96["x"], 42, "96px left-hand target was not centered with the body.")
	TEST_ASSERT_EQUAL(target_96["y"], 15, "96px left-hand target was not south-aligned with the body.")

	var/list/north_target = preview.get_meridian_decoration_target(64, NORTH, 29, 54, identity_transform, 16, 0)
	var/list/east_target = preview.get_meridian_decoration_target(64, EAST, 29, 54, identity_transform, 16, 0)
	var/list/west_target = preview.get_meridian_decoration_target(64, WEST, 29, 54, identity_transform, 16, 0)
	TEST_ASSERT_EQUAL(north_target["x"], 39, "North-facing target did not mirror across the body.")
	TEST_ASSERT_EQUAL(east_target["x"], 31, "East-facing target lost the reviewed depth compression.")
	TEST_ASSERT_EQUAL(west_target["x"], 34, "West-facing target lost the reviewed depth compression.")

	var/matrix/scaled_transform = matrix()
	scaled_transform.Scale(1.5)
	scaled_transform.Translate(0, 8)
	var/list/scaled_target = preview.get_meridian_decoration_target(64, SOUTH, 29, 54, scaled_transform, 16, 0)
	TEST_ASSERT_EQUAL(scaled_target["x"], 23, "Scaled preview target ignored the body's actual X transform.")
	TEST_ASSERT_EQUAL(scaled_target["y"], 22, "Scaled preview target ignored the body's actual Y transform.")
	var/list/pixel_w_target = preview.get_meridian_decoration_target(64, SOUTH, 29, 54, identity_transform, 20, 0)
	TEST_ASSERT_EQUAL(pixel_w_target["x"], 30, "Preview target ignored the body's combined pixel_x and pixel_w offset.")
	var/matrix/double_transform = matrix()
	double_transform.Scale(2)
	double_transform.Translate(0, 16)
	var/list/double_target = preview.get_meridian_decoration_target(96, SOUTH, 29, 54, double_transform, 32, 0)
	TEST_ASSERT_EQUAL(double_target["x"], 36, "96px preview target ignored a doubled body transform.")
	TEST_ASSERT_EQUAL(double_target["y"], 30, "96px preview target lost the doubled body's south alignment.")

	var/atom/movable/screen/map_view/char_preview/rendered_preview = new(null, null, null)
	rendered_preview.body = new
	rendered_preview.body.pixel_x = 16
	rendered_preview.body.transform = identity_transform
	rendered_preview.canvas = image('modular_nova/modules/character_preview_background/icons/background_64x64.dmi', icon_state = "Black")
	rendered_preview.last_canvas_size = 1
	TEST_ASSERT(rendered_preview.set_meridian_decoration(MERIDIAN_PREVIEW_DECORATION_AUGMENTATION_BODY_PARTS, BODY_ZONE_PRECISE_L_HAND), "Rendered preview rejected its left-hand callout.")
	TEST_ASSERT_EQUAL(length(rendered_preview.canvas.overlays), 3, "Rendered preview did not keep body, frame, and leader as one bounded stack.")
	TEST_ASSERT_NOTNULL(rendered_preview.meridian_decoration_leader_overlay, "Rendered preview did not create its body-aware leader.")
	TEST_ASSERT_EQUAL(rendered_preview.meridian_decoration_leader_overlay.plane, HIGH_GAME_PLANE, "Runtime leader can still render behind a body child plane.")
	TEST_ASSERT_EQUAL(rendered_preview.meridian_decoration_leader_overlay.layer, FLY_LAYER, "Runtime leader lost its deterministic foreground layer.")
	TEST_ASSERT_EQUAL(rendered_preview.meridian_decoration_leader_overlay.mouse_opacity, MOUSE_OPACITY_TRANSPARENT, "Runtime leader can capture preview input.")
	TEST_ASSERT_EQUAL(rendered_preview.meridian_decoration_leader_overlay.dir, SOUTH, "Runtime leader did not keep its baked directional frame stable.")
	var/icon/runtime_leader_icon = icon(rendered_preview.meridian_decoration_leader_overlay.icon)
	TEST_ASSERT("" in icon_states(runtime_leader_icon, TRUE), "Runtime leader did not normalize to a renderable default state.")
	TEST_ASSERT_EQUAL(runtime_leader_icon.Width(), 64, "Runtime leader changed the 64px native-map bounds.")
	TEST_ASSERT_EQUAL(runtime_leader_icon.Height(), 64, "Runtime leader changed the 64px native-map bounds.")
	TEST_ASSERT_EQUAL(runtime_leader_icon.GetPixel(26, 15), rgb(0, 229, 212, 255), "Runtime leader did not terminate over the transformed left hand.")
	rendered_preview.setDir(NORTH)
	var/icon/north_leader_icon = icon(rendered_preview.meridian_decoration_leader_overlay.icon)
	TEST_ASSERT("" in icon_states(north_leader_icon, TRUE), "Rotated runtime leader lost its default render state.")
	TEST_ASSERT_EQUAL(north_leader_icon.GetPixel(39, 15), rgb(0, 229, 212, 255), "North-facing runtime leader did not terminate over the mirrored left hand.")
	rendered_preview.setDir(SOUTH)
	rendered_preview.body.pixel_x = 32
	rendered_preview.body.transform = double_transform
	rendered_preview.canvas = image('modular_nova/modules/character_preview_background/icons/background_96x96.dmi', icon_state = "Black")
	rendered_preview.last_canvas_size = 2
	rendered_preview.rebuild_meridian_canvas_overlays()
	var/icon/double_leader_icon = icon(rendered_preview.meridian_decoration_leader_overlay.icon)
	TEST_ASSERT_EQUAL(double_leader_icon.Width(), 96, "Doubled runtime leader changed the 96px native-map bounds.")
	TEST_ASSERT_EQUAL(double_leader_icon.Height(), 96, "Doubled runtime leader changed the 96px native-map bounds.")
	TEST_ASSERT_EQUAL(double_leader_icon.GetPixel(36, 30), rgb(0, 229, 212, 255), "Doubled runtime leader missed its transformed left hand.")
	TEST_ASSERT(rendered_preview.set_meridian_decoration(MERIDIAN_PREVIEW_DECORATION_NONE, null), "Rendered preview rejected decoration cleanup.")
	TEST_ASSERT_NULL(rendered_preview.meridian_decoration_leader_overlay, "Disabling decoration retained the runtime leader.")
	TEST_ASSERT_EQUAL(length(rendered_preview.canvas.overlays), 1, "Disabling decoration left native frame or leader overlays behind.")
	qdel(rendered_preview)
	TEST_ASSERT(QDELETED(rendered_preview), "Destroying a rendered preview left its runtime icon stack alive.")

	TEST_ASSERT(preview.set_meridian_decoration(MERIDIAN_PREVIEW_DECORATION_NONE, null), "Preview rejected the none decoration mode.")
	TEST_ASSERT_NULL(preview.meridian_decoration_region, "Disabling decoration retained a selected region.")
	TEST_ASSERT_NULL(preview.meridian_decoration_overlay, "Disabling decoration retained its image reference.")
	TEST_ASSERT_EQUAL(length(preview.canvas.overlays), 0, "Disabling decoration should remove the native overlay.")

	qdel(preview)
	TEST_ASSERT(QDELETED(preview), "Destroying the preview left its map-view object alive.")
