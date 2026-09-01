/// Enables the choice of background in the character preview menu
/datum/preference/choiced/background_state
	savefile_key = "background_state"
	savefile_identifier = PREFERENCE_CHARACTER

GLOBAL_LIST_INIT(background_state_options, list(
	"Black",
	"Grey",
	"White",
	"White Tiles",
	"Plasteel",
	"Dark Tiles" ,
	"Plating",
	"Reinforced Floor",
))

/datum/preference/choiced/background_state/create_default_value()
	return GLOB.background_state_options[1]

/datum/preference/choiced/background_state/init_possible_values()
	return GLOB.background_state_options

/datum/preference/choiced/background_state/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	return

#define MERIDIAN_PREVIEW_FRAME_COLOR rgb(240, 68, 89, 255)
#define MERIDIAN_PREVIEW_READOUT_COLOR rgb(0, 229, 212, 255)
#define MERIDIAN_PREVIEW_LEADER_COLOR rgb(0, 176, 165, 235)

/// Returns the reviewed callout geometry shared with the Augments workbench.
/atom/movable/screen/map_view/char_preview/proc/get_meridian_decoration_callout()
	// Keep these finite values synchronized with augmentation-preview-callouts.json.
	var/static/list/body_callouts = list(
		BODY_ZONE_HEAD = list("side" = "top", "edge" = 50, "target_x" = 50, "target_y" = 21),
		BODY_ZONE_CHEST = list("side" = "bottom", "edge" = 50, "target_x" = 50, "target_y" = 44),
		BODY_ZONE_L_ARM = list("side" = "left", "edge" = 30, "target_x" = 36, "target_y" = 40),
		BODY_ZONE_PRECISE_L_HAND = list("side" = "left", "edge" = 52, "target_x" = 29, "target_y" = 54),
		BODY_ZONE_L_LEG = list("side" = "left", "edge" = 78, "target_x" = 42, "target_y" = 76),
		BODY_ZONE_R_ARM = list("side" = "right", "edge" = 30, "target_x" = 64, "target_y" = 40),
		BODY_ZONE_PRECISE_R_HAND = list("side" = "right", "edge" = 52, "target_x" = 71, "target_y" = 54),
		BODY_ZONE_R_LEG = list("side" = "right", "edge" = 78, "target_x" = 58, "target_y" = 76),
	)
	var/static/list/implant_callouts = list(
		"brain" = list("side" = "top", "edge" = 50, "target_x" = 50, "target_y" = 18),
		"eyes" = list("side" = "left", "edge" = 15, "target_x" = 48, "target_y" = 23),
		"tongue" = list("side" = "left", "edge" = 36, "target_x" = 49, "target_y" = 30),
		"heart" = list("side" = "left", "edge" = 57, "target_x" = 46, "target_y" = 43),
		"stomach" = list("side" = "left", "edge" = 78, "target_x" = 47, "target_y" = 56),
		"ears" = list("side" = "right", "edge" = 15, "target_x" = 52, "target_y" = 24),
		"mouth" = list("side" = "right", "edge" = 36, "target_x" = 51, "target_y" = 30),
		"lungs" = list("side" = "right", "edge" = 57, "target_x" = 53, "target_y" = 43),
		"liver" = list("side" = "right", "edge" = 78, "target_x" = 55, "target_y" = 54),
	)

	var/list/profile
	switch(meridian_decoration_mode)
		if(
			MERIDIAN_PREVIEW_DECORATION_AUGMENTATION_MARKINGS,
			MERIDIAN_PREVIEW_DECORATION_AUGMENTATION_BODY_PARTS,
		)
			profile = body_callouts
		if(MERIDIAN_PREVIEW_DECORATION_AUGMENTATION_IMPLANTS)
			profile = implant_callouts

	if(isnull(profile))
		return null
	return profile[meridian_decoration_region]

/// Maps a canonical 32px, top-origin anatomy target through the actual body transform.
/atom/movable/screen/map_view/char_preview/proc/get_meridian_decoration_target(
	canvas_dimension,
	preview_direction,
	target_x_percent,
	target_y_percent,
	matrix/body_transform,
	body_pixel_x = 0,
	body_pixel_y = 0,
)
	if(isnull(body_transform))
		body_transform = matrix()

	switch(preview_direction)
		if(NORTH)
			target_x_percent = 100 - target_x_percent
		if(EAST)
			target_x_percent = 50 + (target_x_percent - 50) * 0.3
		if(WEST)
			target_x_percent = 50 - (target_x_percent - 50) * 0.3

	// One-argument round() floors in DM; add 0.5 for explicit nearest-pixel
	// behavior matching the generated DMI artwork.
	var/source_x = round(31 * target_x_percent / 100 + 0.5)
	var/source_y = round(31 * target_y_percent / 100 + 0.5)
	var/source_delta_x = source_x + 0.5 - 16
	var/source_delta_y = 31.5 - source_y - 16
	var/transformed_x = body_pixel_x + 16 + body_transform.a * source_delta_x + body_transform.b * source_delta_y + body_transform.c
	var/transformed_y = body_pixel_y + 16 + body_transform.d * source_delta_x + body_transform.e * source_delta_y + body_transform.f

	return list(
		// transformed_* are zero-based pixel-center coordinates. floor + 1
		// converts them to DrawBox's one-based pixel cells.
		"x" = clamp(round(transformed_x + 1), 1, canvas_dimension),
		"y" = clamp(round(transformed_y + 1), 1, canvas_dimension),
	)

/// Draws one bounded pixel into a runtime preview-decoration icon.
/atom/movable/screen/map_view/char_preview/proc/draw_meridian_decoration_pixel(icon/canvas_icon, color, x, y)
	x = round(x + 0.5)
	y = round(y + 0.5)
	if(x < 1 || x > canvas_icon.Width() || y < 1 || y > canvas_icon.Height())
		return
	canvas_icon.DrawBox(color, x, y)

/// Draws a one-pixel Bresenham leader with no recurring rendering work.
/atom/movable/screen/map_view/char_preview/proc/draw_meridian_decoration_line(icon/canvas_icon, color, x0, y0, x1, y1)
	var/current_x = round(x0 + 0.5)
	var/current_y = round(y0 + 0.5)
	var/target_x = round(x1 + 0.5)
	var/target_y = round(y1 + 0.5)
	var/x_distance = abs(target_x - current_x)
	var/y_distance = abs(target_y - current_y)
	var/x_step = current_x < target_x ? 1 : -1
	var/y_step = current_y < target_y ? 1 : -1
	var/error = x_distance - y_distance

	while(TRUE)
		draw_meridian_decoration_pixel(canvas_icon, color, current_x, current_y)
		if(current_x == target_x && current_y == target_y)
			break
		var/doubled_error = 2 * error
		if(doubled_error > -y_distance)
			error -= y_distance
			current_x += x_step
		if(doubled_error < x_distance)
			error += x_distance
			current_y += y_step

/// Draws the mode-specific target node over the selected body region.
/atom/movable/screen/map_view/char_preview/proc/draw_meridian_decoration_target(icon/canvas_icon, x, y)
	switch(meridian_decoration_mode)
		if(MERIDIAN_PREVIEW_DECORATION_AUGMENTATION_MARKINGS)
			draw_meridian_decoration_pixel(canvas_icon, MERIDIAN_PREVIEW_READOUT_COLOR, x, y)
			draw_meridian_decoration_pixel(canvas_icon, MERIDIAN_PREVIEW_FRAME_COLOR, x - 1, y)
			draw_meridian_decoration_pixel(canvas_icon, MERIDIAN_PREVIEW_FRAME_COLOR, x + 1, y)
		if(MERIDIAN_PREVIEW_DECORATION_AUGMENTATION_BODY_PARTS)
			draw_meridian_decoration_line(canvas_icon, MERIDIAN_PREVIEW_FRAME_COLOR, x - 1, y - 1, x + 1, y - 1)
			draw_meridian_decoration_line(canvas_icon, MERIDIAN_PREVIEW_FRAME_COLOR, x - 1, y + 1, x + 1, y + 1)
			draw_meridian_decoration_line(canvas_icon, MERIDIAN_PREVIEW_FRAME_COLOR, x - 1, y - 1, x - 1, y + 1)
			draw_meridian_decoration_line(canvas_icon, MERIDIAN_PREVIEW_FRAME_COLOR, x + 1, y - 1, x + 1, y + 1)
			draw_meridian_decoration_pixel(canvas_icon, MERIDIAN_PREVIEW_READOUT_COLOR, x, y)
		if(MERIDIAN_PREVIEW_DECORATION_AUGMENTATION_IMPLANTS)
			draw_meridian_decoration_pixel(canvas_icon, MERIDIAN_PREVIEW_READOUT_COLOR, x, y)
			draw_meridian_decoration_pixel(canvas_icon, MERIDIAN_PREVIEW_FRAME_COLOR, x - 1, y)
			draw_meridian_decoration_pixel(canvas_icon, MERIDIAN_PREVIEW_FRAME_COLOR, x + 1, y)
			draw_meridian_decoration_pixel(canvas_icon, MERIDIAN_PREVIEW_FRAME_COLOR, x, y - 1)
			draw_meridian_decoration_pixel(canvas_icon, MERIDIAN_PREVIEW_FRAME_COLOR, x, y + 1)

/// Builds the sparse native leader against the body's real transform and offsets.
/atom/movable/screen/map_view/char_preview/proc/build_meridian_decoration_leader(decoration_icon, canvas_dimension, preview_direction)
	if(isnull(body) || isnull(meridian_decoration_region))
		return null

	var/list/callout = get_meridian_decoration_callout()
	if(isnull(callout))
		return null

	// Normalize the selected directional frame to one default SOUTH frame. The
	// leader geometry is already baked for preview_direction, so the wrapping
	// image must not attempt another directional-state lookup.
	var/icon/leader_icon = icon(
		icon(decoration_icon, meridian_decoration_mode, preview_direction, 1),
		"",
		SOUTH,
		1,
	)
	leader_icon.DrawBox(null, 1, 1, canvas_dimension, canvas_dimension)

	var/edge_offset = round((canvas_dimension - 1) * callout["edge"] / 100 + 0.5)
	var/inset = max(3, round(canvas_dimension * 0.12 + 0.5))
	var/list/edge_point
	var/list/elbow_point
	switch(callout["side"])
		if("top")
			edge_point = list("x" = edge_offset + 1, "y" = canvas_dimension)
			elbow_point = list("x" = edge_offset + 1, "y" = canvas_dimension - inset)
		if("right")
			edge_point = list("x" = canvas_dimension, "y" = canvas_dimension - edge_offset)
			elbow_point = list("x" = canvas_dimension - inset, "y" = canvas_dimension - edge_offset)
		if("bottom")
			edge_point = list("x" = edge_offset + 1, "y" = 1)
			elbow_point = list("x" = edge_offset + 1, "y" = 1 + inset)
		if("left")
			edge_point = list("x" = 1, "y" = canvas_dimension - edge_offset)
			elbow_point = list("x" = 1 + inset, "y" = canvas_dimension - edge_offset)

	if(isnull(edge_point) || isnull(elbow_point))
		return null

	var/list/target_point = get_meridian_decoration_target(
		canvas_dimension,
		preview_direction,
		callout["target_x"],
		callout["target_y"],
		body.transform,
		body.pixel_x + body.pixel_w,
		body.pixel_y + body.pixel_z,
	)
	draw_meridian_decoration_line(leader_icon, MERIDIAN_PREVIEW_READOUT_COLOR, edge_point["x"], edge_point["y"], elbow_point["x"], elbow_point["y"])
	draw_meridian_decoration_line(leader_icon, MERIDIAN_PREVIEW_LEADER_COLOR, elbow_point["x"], elbow_point["y"], target_point["x"], target_point["y"])
	draw_meridian_decoration_pixel(leader_icon, MERIDIAN_PREVIEW_READOUT_COLOR, edge_point["x"], edge_point["y"])
	draw_meridian_decoration_target(leader_icon, target_point["x"], target_point["y"])
	return leader_icon

#undef MERIDIAN_PREVIEW_FRAME_COLOR
#undef MERIDIAN_PREVIEW_READOUT_COLOR
#undef MERIDIAN_PREVIEW_LEADER_COLOR
