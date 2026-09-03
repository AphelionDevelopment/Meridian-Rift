/// Boot log lines shown in the lobby's startup terminal, capped to MAX_STARTUP_MESSAGES.
GLOBAL_LIST_EMPTY(startup_messages)

SUBSYSTEM_DEF(title)
	name = "Title Screen"
	ss_flags = SS_NO_FIRE
	init_stage = INITSTAGE_FIRST

	var/file_path
	var/icon/startup_splash

	/// The current title screen being displayed, as a file path text.
	/// Set only through set_showing(), never on its own.
	var/current_title_screen
	/// The current notice text, or null.
	var/current_notice
	/// The preamble html that includes all styling and layout.
	var/title_html
	/// The list of possible title screens to rotate through, as file path texts.
	var/title_screens = list()
	/// Config-directory file names, index-aligned with title_screens. The icons
	/// themselves carry no name, so this is what the admin dropdown selects by.
	var/list/title_screen_names = list()

	/// Admin-pinned title screen file name, or null to rotate/fall back.
	var/selected_title_name
	/// Config file name of the screen actually showing, or null for the neutral master
	/// and admin uploads. Distinct from selected_title_name: a rotation changes what is
	/// displayed without touching the admin pin, and the overlay flag is keyed by the screen actually showing rather than the pinned one.
	var/current_title_name
	/// Whether change_title_screen() is allowed to pick a new screen each round.
	var/rotate_title_screens = TRUE
	/// File name => TRUE when that screen should carry the themed wordmark overlay.
	var/list/title_overlays = list()
	/// Server-wide presentation applied on top of whichever screen is showing.
	var/title_variant = "convex"
	var/title_texture = "original"
	var/title_classic_alt = FALSE
	/// Cached asset URL for the neutral wordmark used by overlay mode.
	var/title_mark_asset_registered = FALSE

	/// average realtime seconds it takes to load the map we're currently running
	var/average_completion_time = DEFAULT_TITLE_MAP_LOADTIME
	/// a given startup message => average timestamp in realtime seconds
	var/list/startup_message_timings = list()
	/// Raw data to update later
	var/list/progress_json = list()
	/// The reference realtime that we're treating as 0 for this run
	var/progress_reference_time = 0
	/// Name the current title image is registered under in the asset cache. Incremented each
	/// time the image changes, since re-registering the same name with different content logs
	/// an asset cache error (see /datum/asset_transport/proc/register_asset).
	var/current_title_asset_name
	/// Counter used to build a fresh, unique asset name each time the title image changes.
	var/title_asset_generation = 0

/datum/controller/subsystem/title/Initialize()
	var/list/provisional_title_screens = flist("[global.config.directory]/title_screens/images/")
	var/list/local_title_screens = list()

	for(var/screen in provisional_title_screens)
		var/list/formatted_list = splittext(screen, "+")
		if((LAZYLEN(formatted_list) == 1 && (formatted_list[1] != "exclude" && formatted_list[1] != "blank.png" && formatted_list[1] != "startup_splash")))
			local_title_screens += screen

		if(LAZYLEN(formatted_list) > 1 && LOWER_TEXT(formatted_list[1]) == "startup_splash")
			var/file_path = "[global.config.directory]/title_screens/images/[screen]"
			ASSERT(fexists(file_path))
			startup_splash = new(fcopy_rsc(file_path))

	// Progress stuff
	check_progress_reference_time()
	load_progress_json()
	load_title_settings()

	if(startup_splash)
		change_title_screen(startup_splash)
	else
		change_title_screen(DEFAULT_TITLE_LOADING_SCREEN)

	if(length(local_title_screens))
		for(var/i in local_title_screens)
			var/file_path = "[global.config.directory]/title_screens/images/[i]"
			ASSERT(fexists(file_path))
			var/icon/title2use = new(fcopy_rsc(file_path))
			title_screens += title2use
			// Keep the config file name index-aligned with its icon so the admin
			// dropdown has a stable key to select and persist by.
			title_screen_names += i

	// A screen pinned in a previous round may have been removed from the config
	// directory since; drop the selection rather than pinning to nothing.
	if(selected_title_name && !(selected_title_name in title_screen_names))
		selected_title_name = null

	return SS_INIT_SUCCESS

/**
 * Returns the number of remaining latejoin antagonist slots if we are past roundstart,
 * otherwise returns "PRE-ROUND".
 */
/datum/controller/subsystem/title/proc/get_latejoin_queue_count()
	if (SSticker.current_state < GAME_STATE_PLAYING)
		return "PRE-ROUND"

	return max(SSdynamic.rulesets_to_spawn[LATEJOIN], 0)

/**
 * Make sure reference time is set up. If not, this is now time 0.
 */
/datum/controller/subsystem/title/proc/check_progress_reference_time()
	if(!progress_reference_time)
		progress_reference_time = world.timeofday

/**
 * Handle and clean up leaving startup
 */
/datum/controller/subsystem/title/proc/check_finish_progress()
	//It's the first time we're firing out of startup -> pregame
	if(progress_json && SSticker.current_state == GAME_STATE_PREGAME)
		save_progress_json()

/**
 * Load the progress info json and setup that part of the SS.
*/
/datum/controller/subsystem/title/proc/load_progress_json()
	var/json_file = file(TITLE_PROGRESS_CACHE_FILE)
	if(!fexists(json_file))
		return

	// Load map progress cache info
	progress_json = json_decode(file2text(json_file))

	// Different format. Purge everything.
	if(progress_json["_version"] != TITLE_PROGRESS_CACHE_VERSION)
		progress_json.Cut()
		return

	// If there's no info about the current map, use the defaults.
	var/list/map_info = progress_json[SSmapping.current_map.map_name]
	if(!islist(map_info))
		return

	// Get expected total time and subpart time
	average_completion_time = map_info["total"] || DEFAULT_TITLE_MAP_LOADTIME
	startup_message_timings = map_info["messages"] || list()

/datum/controller/subsystem/title/proc/save_progress_json()
	var/json_file = file(TITLE_PROGRESS_CACHE_FILE)
	var/list/map_info = list()

	progress_json["_version"] = TITLE_PROGRESS_CACHE_VERSION

	if(progress_json[SSmapping.current_map.map_name])
		// Save total time and updated message timings. Latest time is worth 1/4 the "average"
		map_info["total"] = 0.75 * average_completion_time + 0.25 * (world.timeofday - progress_reference_time)
	else
		// New. Just save the time it took.
		map_info["total"] = world.timeofday - progress_reference_time
	map_info["messages"] = startup_message_timings
	progress_json[SSmapping.current_map.map_name] = map_info

	fdel(json_file)
	WRITE_FILE(json_file, json_encode(progress_json))

	// We're done, don't touch it again this round.
	progress_json = null

/**
 * Load the server-wide title screen presentation chosen by an admin.
 *
 * Mirrors load_progress_json(): a missing or version-mismatched file simply
 * leaves the compiled defaults in place rather than failing initialization.
 */
/datum/controller/subsystem/title/proc/load_title_settings()
	var/json_file = file(TITLE_SETTINGS_FILE)
	if(!fexists(json_file))
		return

	var/list/settings = json_decode(file2text(json_file))
	if(!islist(settings) || settings["_version"] != TITLE_SETTINGS_VERSION)
		return

	selected_title_name = istext(settings["selected"]) ? settings["selected"] : null
	rotate_title_screens = !!settings["rotate"]
	title_variant = istext(settings["variant"]) ? settings["variant"] : title_variant
	title_texture = istext(settings["texture"]) ? settings["texture"] : title_texture
	title_classic_alt = !!settings["classicAlt"]

	// Overlay flags are keyed by config file name. Unknown keys are kept rather
	// than pruned, so temporarily removing an image does not lose its setting.
	var/list/stored_overlays = settings["overlays"]
	title_overlays = islist(stored_overlays) ? stored_overlays.Copy() : list()

/// Write the current presentation back out. Called by every setter.
/datum/controller/subsystem/title/proc/save_title_settings()
	var/json_file = file(TITLE_SETTINGS_FILE)
	var/list/settings = list(
		"_version" = TITLE_SETTINGS_VERSION,
		"selected" = selected_title_name,
		"rotate" = rotate_title_screens,
		"variant" = title_variant,
		"texture" = title_texture,
		"classicAlt" = title_classic_alt,
		"overlays" = title_overlays,
	)

	fdel(json_file)
	WRITE_FILE(json_file, json_encode(settings))

/datum/controller/subsystem/title/Recover()
	startup_splash = SStitle.startup_splash
	file_path = SStitle.file_path

	set_showing(SStitle.current_title_screen, SStitle.current_title_name)
	current_notice = SStitle.current_notice
	title_screens = SStitle.title_screens
	title_screen_names = SStitle.title_screen_names

	selected_title_name = SStitle.selected_title_name
	rotate_title_screens = SStitle.rotate_title_screens
	title_overlays = SStitle.title_overlays
	title_variant = SStitle.title_variant
	title_texture = SStitle.title_texture
	title_classic_alt = SStitle.title_classic_alt
	title_mark_asset_registered = SStitle.title_mark_asset_registered

	average_completion_time = SStitle.average_completion_time
	startup_message_timings = SStitle.startup_message_timings
	progress_json = SStitle.progress_json
	progress_reference_time = SStitle.progress_reference_time
	current_title_asset_name = SStitle.current_title_asset_name
	title_asset_generation = SStitle.title_asset_generation

/**
 * Registers the current title screen as the lobby menu's background asset,
 * and pushes the fresh URL to every currently-open lobby menu.
 *
 * The title image changes over time (loading gif -> picked title screen -> admin swaps), and
 * /datum/asset_transport/proc/register_asset logs an error if you re-register the same name
 * with different content, so each call here registers under a fresh, unique name instead of
 * reusing one fixed name.
 */
/datum/controller/subsystem/title/proc/show_title_screen()
	set waitfor = FALSE
	title_asset_generation++
	current_title_asset_name = "[LOBBY_TITLE_ASSET_PREFIX]_[title_asset_generation].png"
	SSassets.transport.register_asset(current_title_asset_name, current_title_screen)
	ensure_title_mark_asset()
	var/list/payload = get_title_payload()
	for(var/datum/lobby_menu/menu as anything in GLOB.lobby_menus)
		if(!menu.client)
			continue
		SSassets.transport.send_assets(menu.client, current_title_asset_name)
		SSassets.transport.send_assets(menu.client, LOBBY_TITLE_MARK_ASSET_NAME)
		menu.send_update(payload)

/**
 * Registers the neutral wordmark used by overlay mode.
 *
 * Unlike the title screen this content never changes, so it keeps one fixed
 * name instead of the generation counter that show_title_screen() needs.
 */
/datum/controller/subsystem/title/proc/ensure_title_mark_asset()
	if(title_mark_asset_registered)
		return
	SSassets.transport.register_asset(LOBBY_TITLE_MARK_ASSET_NAME, DEFAULT_TITLE_SCREEN_IMAGE)
	title_mark_asset_registered = TRUE

/**
 * How the lobby should render whatever screen is currently showing.
 *
 * The default image is a neutral alpha master, so it is tinted directly. A
 * config screen is a finished picture, so it only gains the themed wordmark
 * when an admin has opted that specific file in.
 *
 * Keyed on the screen actually showing rather than the pinned one, so a rotation
 * carries whatever overlay flag the screen it landed on was given.
 */
/datum/controller/subsystem/title/proc/get_title_treatment()
	if(current_title_screen == DEFAULT_TITLE_SCREEN_IMAGE)
		return TITLE_TREATMENT_MASK
	if(current_title_name && title_overlays[current_title_name])
		return TITLE_TREATMENT_OVERLAY
	return TITLE_TREATMENT_NONE


/// The server-wide title state every lobby menu needs, shared by init and updates.
/datum/controller/subsystem/title/proc/get_title_payload()
	ensure_title_mark_asset()
	return list(
		"titleImageUrl" = SSassets.transport.get_asset_url(current_title_asset_name),
		"titleMarkUrl" = SSassets.transport.get_asset_url(LOBBY_TITLE_MARK_ASSET_NAME),
		"titleImageTreatment" = get_title_treatment(),
		"titleScreens" = get_title_screen_options(),
		"titleSelected" = selected_title_name,
		"titleRotate" = rotate_title_screens,
		"titleVariant" = title_variant,
		"titleTexture" = title_texture,
		"titleClassicAlt" = title_classic_alt,
	)

/// The admin dropdown's options: every config screen plus its overlay flag.
/datum/controller/subsystem/title/proc/get_title_screen_options()
	var/list/options = list()
	for(var/screen_name in title_screen_names)
		options += list(list(
			"name" = screen_name,
			"overlay" = !!title_overlays[screen_name],
		))
	return options

/**
 * Sets which screen is showing, together with the config file name it came from.
 *
 * The overlay flag is looked up by name, so a screen and its name drifting apart
 * means the lobby renders one picture's treatment on top of another's. Assigning
 * the two only ever as a pair is what makes that unrepresentable.
 *
 * Arguments:
 * * screen - the icon or file resource to display.
 * * screen_name - its config file name, or null when it has none: the neutral
 * master, the boot splash, and admin uploads are not config screens.
 */
/datum/controller/subsystem/title/proc/set_showing(screen, screen_name)
	current_title_screen = screen
	current_title_name = screen_name

/**
 * Adds a notice to the main title screen in the form of big red text!
 */
/datum/controller/subsystem/title/proc/set_notice(new_title)
	current_notice = new_title ? sanitize_text(new_title) : null
	for(var/datum/lobby_menu/menu as anything in GLOB.lobby_menus)
		menu.send_update(list("notice" = current_notice))

/**
 * Changes the title screen to a new image.
 */
/datum/controller/subsystem/title/proc/change_title_screen(new_screen)
	if(new_screen)
		// An upload or the boot splash, neither of which is a config screen with a flag.
		set_showing(new_screen, null)
	else
		resolve_unattended_screen()

	check_finish_progress()
	show_title_screen()

/**
 * Picks the screen for an unattended change, i.e. the round-end rotation.
 *
 * Rotation is the historical behaviour and stays the default. When an admin has
 * turned it off, the pinned selection wins instead. Gating here rather than at
 * the ticker call site is what lets a chosen screen persist across rounds
 * without editing core code.
 *
 * Applies the pick through set_showing() rather than only returning it, so
 * get_title_treatment() can tell which screen's overlay flag applies to whatever
 * the rotation just landed on. The chosen screen is returned as well, for callers
 * that want to inspect the result.
 */
/datum/controller/subsystem/title/proc/resolve_unattended_screen()
	if(!rotate_title_screens)
		var/icon/pinned = get_title_screen_icon(selected_title_name)
		set_showing(pinned || DEFAULT_TITLE_SCREEN_IMAGE, pinned ? selected_title_name : null)
		return current_title_screen

	if(LAZYLEN(title_screens))
		// By index rather than pick(), so the name stays with the icon we landed on.
		var/rolled = rand(1, length(title_screens))
		set_showing(title_screens[rolled], title_screen_names[rolled])
		return current_title_screen

	set_showing(DEFAULT_TITLE_SCREEN_IMAGE, null)
	return current_title_screen

/// Resolve a config file name to its preloaded icon, or null when unknown.
/datum/controller/subsystem/title/proc/get_title_screen_icon(screen_name)
	if(!istext(screen_name))
		return null
	var/index = title_screen_names.Find(screen_name)
	if(!index)
		return null
	return title_screens[index]

/**
 * Push the current settings to every open lobby.
 *
 * Unlike show_title_screen() this does not touch the asset cache, so the
 * toggles that only change presentation cannot churn through generations of
 * identical registered images.
 */
/datum/controller/subsystem/title/proc/broadcast_title_settings()
	var/list/payload = get_title_payload()
	for(var/datum/lobby_menu/menu as anything in GLOB.lobby_menus)
		if(!menu.client)
			continue
		menu.send_update(payload)

/**
 * Admin-facing setters.
 *
 * Each validates its input, persists, and reuses the existing broadcast path.
 * None of them check rights: callers are responsible for that, so the checks
 * stay next to the transport that can be reached from a client.
 */
/datum/controller/subsystem/title/proc/set_title_selection(screen_name)
	if(isnull(screen_name) || screen_name == "")
		// The empty selection means the neutral Meridian Rift master.
		selected_title_name = null
		set_showing(DEFAULT_TITLE_SCREEN_IMAGE, null)
	else
		var/icon/chosen = get_title_screen_icon(screen_name)
		if(!chosen)
			return FALSE
		selected_title_name = screen_name
		set_showing(chosen, screen_name)

	save_title_settings()
	show_title_screen()
	return TRUE

/datum/controller/subsystem/title/proc/set_title_rotation(rotate)
	rotate_title_screens = !!rotate
	save_title_settings()
	broadcast_title_settings()
	return TRUE

/datum/controller/subsystem/title/proc/set_title_overlay(screen_name, enabled)
	if(!get_title_screen_icon(screen_name))
		return FALSE
	title_overlays[screen_name] = !!enabled
	save_title_settings()
	broadcast_title_settings()
	return TRUE

/datum/controller/subsystem/title/proc/set_title_presentation(variant, texture, classic_alt)
	var/static/list/valid_variants = list("flat", "edge", "convex", "convex-bezel")
	var/static/list/valid_textures = list("original", "navarobl")
	if(!(variant in valid_variants) || !(texture in valid_textures))
		return FALSE

	title_variant = variant
	title_texture = texture
	title_classic_alt = !!classic_alt
	save_title_settings()
	broadcast_title_settings()
	return TRUE

/**
 * Update a user's character setup name.
 * Arguments:
 * * user - The user being updated
 * * name - the real name of the current slot.
 */
/datum/controller/subsystem/title/proc/update_character_name(mob/dead/new_player/user, name)
	user.client?.lobby_menu?.send_update(list("characterName" = uppertext(name)))

/**
 * Adds a startup message to the splashscreen.
 *
 * Arguments:
 * * msg - the message to show users.
 * * warning - optional: TRUE to indicate this is an error/warning
 */
/proc/add_startup_message(msg, warning)
	// Remove the # second(s) / #s part of the message.
	var/static/regex/msg_key_regex = new(@"[0-9.]+( second)?s?!", "ig")
	// Key used to cache the timing info
	var/msg_key = msg_key_regex.Replace(msg, "#")

	GLOB.startup_messages += list(list("text" = msg, "warning" = !!warning))
	if(length(GLOB.startup_messages) > MAX_STARTUP_MESSAGES)
		GLOB.startup_messages.Cut(1, length(GLOB.startup_messages) - MAX_STARTUP_MESSAGES + 1)

	// If we ran before SStitle initialized, set the ref time now.
	SStitle.check_progress_reference_time()

	// Add or update message history info.
	var/old_timing = SStitle.startup_message_timings[msg_key]
	var/new_timing
	if(!old_timing)
		// new message
		new_timing = world.timeofday - SStitle.progress_reference_time
	else
		// old message. Latest time is worth 1/4 the "average"
		new_timing = 0.75 * old_timing + 0.25 * (world.timeofday - SStitle.progress_reference_time)
	SStitle.startup_message_timings[msg_key] = new_timing

	for(var/datum/lobby_menu/menu as anything in GLOB.lobby_menus)
		menu.send_update(list(
			"startupMessages" = GLOB.startup_messages,
			"progressCurrent" = new_timing,
			"progressTotal" = SStitle.average_completion_time,
		))
