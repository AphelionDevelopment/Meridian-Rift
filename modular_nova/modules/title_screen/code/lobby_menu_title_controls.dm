/**
 * Server-wide title screen controls for the lobby menu.
 *
 * These live here rather than in code/modules/lobby_menu/lobby_menu.dm so the
 * feature stays modular: both procs are declared with proc/ upstream, so this
 * file overrides them and falls through with ..() for everything it does not
 * handle.
 */

/// Rank that may change the title screen, matching ADMIN_VERB(admin_change_title_screen).
#define TITLE_SCREEN_ADMIN_RIGHTS R_FUN

/**
 * The lobby browser never received the Font Awesome asset that TGUI windows
 * send, so every <Icon> in the lobby rendered as an empty element: the theme
 * picker's tick marks and the title screen overlay checkboxes were invisible.
 * Sending it here keeps the fix out of core lobby_menu.dm.
 */
/datum/lobby_menu/initialize_browser()
	. = ..()
	window.send_asset(get_asset_datum(/datum/asset/simple/namespaced/fontawesome))

/datum/lobby_menu/send_init()
	. = ..()
	// serverUpdate merges a Partial<ServerState> over the state serverInit just
	// installed, so appending here avoids editing the core payload.
	send_update(get_title_control_payload())

/// The shared title state plus whether this particular client may change it.
/datum/lobby_menu/proc/get_title_control_payload()
	var/list/payload = SStitle.get_title_payload()
	payload["canSetTitleScreen"] = can_set_title_screen()
	return payload

/**
 * Whether this client holds the rank that owns the title screen.
 *
 * The client-side flag only decides whether the menu renders. Every handler
 * below re-checks this, because a payload can be forged.
 */
/datum/lobby_menu/proc/can_set_title_screen()
	return !isnull(client?.holder) && check_rights_for(client, TITLE_SCREEN_ADMIN_RIGHTS)

/datum/lobby_menu/on_message(type, payload, href_list)
	switch(type)
		if("setTitleScreen", "setTitleRotation", "setTitleOverlay", "setTitlePresentation")
			handle_title_message(type, payload)
			return TRUE

	return ..()

/**
 * Applies one title screen control message.
 *
 * A rejected or unauthorised change re-sends the authoritative state so the
 * menu snaps back instead of silently keeping an optimistic value.
 */
/datum/lobby_menu/proc/handle_title_message(type, list/payload)
	if(!can_set_title_screen())
		message_admins("[key_name(client)] tried to change the title screen without the required rights.")
		send_update(get_title_control_payload())
		return

	// Picking a screen replaces the lobby for everyone who is connected and
	// keeps it that way across restarts, so make the admin say it out loud
	// first. The prompt sleeps, so it runs off the message pump.
	if(type == "setTitleScreen")
		INVOKE_ASYNC(src, PROC_REF(confirm_and_set_title_screen), payload?["screen"])
		return

	var/applied = FALSE
	switch(type)
		if("setTitleRotation")
			applied = SStitle.set_title_rotation(payload?["rotate"])
		if("setTitleOverlay")
			applied = SStitle.set_title_overlay(payload?["screen"], payload?["overlay"])
		if("setTitlePresentation")
			applied = SStitle.set_title_presentation(
				payload?["variant"],
				payload?["texture"],
				payload?["classicAlt"],
			)

	if(!applied)
		// Bad input. Nothing changed, so only this client needs correcting.
		send_update(get_title_control_payload())
		return

	log_admin("[key_name(client)] changed the title screen presentation ([type]).")

/**
 * Confirms a server-wide title screen change, then applies it.
 *
 * Always re-checks rights after the prompt: it sleeps for as long as the admin
 * takes to answer, and their holder can be gone by the time it returns. On any
 * refusal the authoritative state is sent back so the menu snaps out of its
 * optimistic selection.
 */
/datum/lobby_menu/proc/confirm_and_set_title_screen(screen_name)
	var/label = "the default Meridian Rift screen"
	if(!isnull(screen_name) && screen_name != "")
		label = "\"[screen_name]\""

	var/answer = tgui_alert(
		client,
		"Switch the lobby title screen to [label]? This changes what every connected player sees right now, and it stays that way across rounds until someone changes it again.",
		"Change the title screen for everyone?",
		list("Change it for everyone", "Cancel"),
		timeout = 30 SECONDS,
	)

	if(answer != "Change it for everyone" || !can_set_title_screen())
		send_update(get_title_control_payload())
		return

	if(!SStitle.set_title_selection(screen_name))
		send_update(get_title_control_payload())
		return

	log_admin("[key_name(client)] changed the title screen to [label] for everyone.")
	message_admins("[key_name_admin(client)] changed the lobby title screen to [label] for everyone.")

#undef TITLE_SCREEN_ADMIN_RIGHTS
