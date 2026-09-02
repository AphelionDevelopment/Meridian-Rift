// Determines if input boxes are in tgui or old fashioned
/datum/preference/toggle/tgui_input
	category = PREFERENCE_CATEGORY_GAME_PREFERENCES
	savefile_key = "tgui_input"
	savefile_identifier = PREFERENCE_PLAYER

/// Large button preference. Error text is in tooltip.
/datum/preference/toggle/tgui_input_large
	category = PREFERENCE_CATEGORY_GAME_PREFERENCES
	savefile_key = "tgui_input_large"
	savefile_identifier = PREFERENCE_PLAYER
	default_value = FALSE

/datum/preference/toggle/tgui_input_large/apply_to_client(client/client, value)
	for (var/datum/tgui/tgui as anything in client.mob?.tgui_open_uis)
		// Force it to reload either way
		tgui.send_full_update(client.mob)

/// Swapped button state - sets buttons to SS13 traditional SUBMIT/CANCEL
/datum/preference/toggle/tgui_input_swapped
	category = PREFERENCE_CATEGORY_GAME_PREFERENCES
	savefile_key = "tgui_input_swapped"
	savefile_identifier = PREFERENCE_PLAYER

/datum/preference/toggle/tgui_input_swapped/apply_to_client(client/client, value)
	for (var/datum/tgui/tgui as anything in client.mob?.tgui_open_uis)
		// Force it to reload either way
		tgui.send_full_update(client.mob)

/// Changes layout in some UI's, like Vending, Smartfridge etc. Making it list or grid
/datum/preference/choiced/tgui_layout
	savefile_key = "tgui_layout"
	savefile_identifier = PREFERENCE_PLAYER

/datum/preference/choiced/tgui_layout/init_possible_values()
	return list(
		TGUI_LAYOUT_GRID,
		TGUI_LAYOUT_LIST,
	)

/datum/preference/choiced/tgui_layout/create_default_value()
	return TGUI_LAYOUT_LIST

/datum/preference/choiced/tgui_layout/apply_to_client(client/client, value)
	for (var/datum/tgui/tgui as anything in client.mob?.tgui_open_uis)
		// Force it to reload either way
		tgui.update_static_data(client.mob)

/datum/preference/choiced/tgui_layout/smartfridge
	savefile_key = "tgui_layout_smartfridge"

/datum/preference/choiced/tgui_layout/create_default_value()
	return TGUI_LAYOUT_GRID

/datum/preference/toggle/tgui_lock
	category = PREFERENCE_CATEGORY_GAME_PREFERENCES
	savefile_key = "tgui_lock"
	savefile_identifier = PREFERENCE_PLAYER
	default_value = FALSE

/datum/preference/toggle/tgui_lock/apply_to_client(client/client, value)
	for (var/datum/tgui/tgui as anything in client.mob?.tgui_open_uis)
		// Force it to reload either way
		tgui.update_static_data(client.mob)

// But no games.
/datum/preference/toggle/tgui_unlimited_windows
	category = PREFERENCE_CATEGORY_GAME_PREFERENCES
	savefile_key = "tgui_unlimited_windows"
	savefile_identifier = PREFERENCE_PLAYER
	default_value = FALSE

/// Light mode for tgui say
/datum/preference/toggle/tgui_say_light_mode
	category = PREFERENCE_CATEGORY_GAME_PREFERENCES
	savefile_key = "tgui_say_light_mode"
	savefile_identifier = PREFERENCE_PLAYER
	default_value = FALSE

/datum/preference/toggle/tgui_say_light_mode/apply_to_client(client/client)
	client.tgui_say?.load()

/datum/preference/toggle/ui_scale
	category = PREFERENCE_CATEGORY_GAME_PREFERENCES
	savefile_key = "ui_scale"
	savefile_identifier = PREFERENCE_PLAYER
	default_value = TRUE

/datum/preference/toggle/ui_scale/apply_to_client(client/client, value)
	if(!istype(client))
		return

	INVOKE_ASYNC(client, TYPE_VERB_REF(/client, refresh_tgui))
	client.tgui_say?.load()

/// Account-wide MeridianOS presentation selected from the in-window gear menu.
/datum/preference/choiced/meridian_theme
	category = PREFERENCE_CATEGORY_MANUALLY_RENDERED
	savefile_key = "meridian_theme"
	savefile_identifier = PREFERENCE_PLAYER

/datum/preference/choiced/meridian_theme/init_possible_values()
	return list(
		"meridian",
		"meridian_classic",
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
	)

/datum/preference/choiced/meridian_theme/create_default_value()
	return "meridian"

/datum/preference/choiced/meridian_theme/apply_to_client_updated(client, value)
	if(isnull(client))
		return
	var/mob/client_mob = client:mob
	for(var/datum/tgui/open_ui as anything in client_mob?.tgui_open_uis)
		open_ui.send_config_update()
	client:lobby_menu?.send_update(list("meridianTheme" = value))

/**
 * Validate, persist, and distribute a MeridianOS theme selection.
 *
 * The explicit membership check must remain before update_preference(); the
 * generic choiced deserializer converts unknown input to its default, which
 * would otherwise let an invalid wire value silently change the selection.
 */
/datum/preferences/proc/set_meridian_theme(raw_theme)
	if(!istext(raw_theme))
		return FALSE

	var/datum/preference/choiced/meridian_theme/theme_preference = GLOB.preference_entries[/datum/preference/choiced/meridian_theme]
	if(!(raw_theme in theme_preference.get_choices()))
		return FALSE

	if(read_preference(theme_preference.type) == raw_theme)
		return TRUE

	if(!update_preference(theme_preference, raw_theme))
		return FALSE

	return save_preferences()

/// Self-bound transport entrypoint; browser payloads can never choose an owner.
/client/proc/set_meridian_theme(raw_theme)
	return prefs?.set_meridian_theme(raw_theme)

/// Test/client-interface parity for preference behavior without a live BYOND client.
/datum/client_interface/proc/set_meridian_theme(raw_theme)
	return prefs?.set_meridian_theme(raw_theme)
