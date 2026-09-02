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

	var/applied = FALSE
	switch(type)
		if("setTitleScreen")
			applied = SStitle.set_title_selection(payload?["screen"])
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

#undef TITLE_SCREEN_ADMIN_RIGHTS
