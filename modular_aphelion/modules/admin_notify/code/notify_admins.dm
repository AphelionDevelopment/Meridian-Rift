/// How long a player has to wait between uses of the Notify Admins verb.
#define ADMIN_NOTIFY_COOLDOWN (2 MINUTES)
/// How long the Notify Admins hotkey has to be held down before it fires.
#define ADMIN_NOTIFY_HOLD_TIME (2 SECONDS)

/// Timer id for the hotkey's hold delay. Hung off the client so it dies with them on disconnect.
/client/var/notify_admins_hold_timer
/// World time at which this client may use Notify Admins again. Driven by the COOLDOWN_* macros.
/client/var/notify_admins_cooldown = 0

GAME_VERB_DESC(/client, notify_admins, "Notify Admins", "Ask staff to come and observe what is happening to you.", "OOC")
	if(is_banned_from(ckey, list(BAN_ADMIN_NOTIFY)))
		to_chat(src, span_danger("You are not able to use this."))
		return

	if(!COOLDOWN_FINISHED(src, notify_admins_cooldown))
		to_chat(src, span_warning("You can notify the admins again in [DisplayTimeText(COOLDOWN_TIMELEFT(src, notify_admins_cooldown))]."))
		return

	if(isnull(mob))
		return

	COOLDOWN_START(src, notify_admins_cooldown, ADMIN_NOTIFY_COOLDOWN)

	log_admin("[key_name(src)] notified admins to observe them.")
	message_admins("[key_name_admin(src)] has requested admin attention/observation. [ADMIN_FLW(mob)]")

	for(var/client/admin_client as anything in GLOB.admins)
		if(!admin_client.prefs?.read_preference(/datum/preference/toggle/admin_notify_alert))
			continue
		SEND_SOUND(admin_client, sound('modular_aphelion/modules/admin_notify/sound/admin_notify.ogg', volume = 50))
		window_flash(admin_client)

	if(!length(GLOB.admins))
		to_chat(src, span_warning("No staff are online at the moment. Your request has been logged, but use Adminhelp if you need it seen."))
		return

	to_chat(src, span_notice("You've notified the admins to take a look at you."))

/// Hotkey pairing for the verb above. Held rather than tapped so nobody fat-fingers the whole staff team.
/datum/keybinding/client/notify_admins
	hotkey_keys = list(UNBOUND_KEY)
	name = "notify_admins"
	full_name = "Notify Admins (Hold)"
	description = "Hold for 2 seconds to notify admins to come observe you."
	keybind_signal = COMSIG_KB_NOTIFYADMINS_DOWN

/datum/keybinding/client/notify_admins/down(client/user, turf/target, mousepos_x, mousepos_y)
	. = ..()
	if(.)
		return
	if(user.notify_admins_hold_timer)
		return TRUE
	// Checked here as well as in the verb so a player on cooldown finds out now, not two seconds from now.
	// Deliberately not the ban check, which can block on the ban cache and has no business doing that in a keypress.
	if(!COOLDOWN_FINISHED(user, notify_admins_cooldown))
		to_chat(user, span_warning("You can notify the admins again in [DisplayTimeText(COOLDOWN_TIMELEFT(user, notify_admins_cooldown))]."))
		return TRUE
	to_chat(user, span_notice("Keep holding to notify admins..."))
	user.notify_admins_hold_timer = addtimer(CALLBACK(user, TYPE_PROC_REF(/client, finish_notify_admins)), ADMIN_NOTIFY_HOLD_TIME, TIMER_STOPPABLE)
	return TRUE

/datum/keybinding/client/notify_admins/up(client/user, turf/target)
	. = ..()
	if(user.notify_admins_hold_timer)
		deltimer(user.notify_admins_hold_timer)
		user.notify_admins_hold_timer = null

/// Called by the hold timer once the key has been down long enough.
/client/proc/finish_notify_admins()
	notify_admins_hold_timer = null
	notify_admins()

#undef ADMIN_NOTIFY_COOLDOWN
#undef ADMIN_NOTIFY_HOLD_TIME
