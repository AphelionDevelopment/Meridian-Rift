/// Warn them, wait out the grace period, then bin them to the lobby if the role hasn't come back.
/proc/symphony_revoke(target_ckey)
	// The panel pushes revokes whether we're enforcing or not.
	if(!CONFIG_GET(flag/symphony_enabled))
		return
	target_ckey = ckey(target_ckey)
	symphony_invalidate_whitelist_cache(target_ckey)
	var/client/found = GLOB.directory[target_ckey]
	if(!found)
		return
	// Staff exemption, same as gate.dm
	if(found.holder)
		return
	if(isnewplayer(found.mob))
		var/mob/dead/new_player/lobby = found.mob
		to_chat(found, span_userdanger("Your Discord whitelist role was removed."))
		// Round start never asks the gate, so unready them or they spawn as crew anyway.
		lobby.ready = PLAYER_NOT_READY
		// Before show_title_screen(), which re-inits the menu off this.
		found.lobby_menu?.set_whitelist_gate(TRUE)
		lobby.show_title_screen()
		return
	var/grace = CONFIG_GET(number/symphony_grace_seconds)
	to_chat(found, span_userdanger("Your Discord whitelist role was removed. You will be returned to the lobby in [grace] seconds unless it is restored."))
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(symphony_enforce_kick), target_ckey), grace SECONDS, TIMER_UNIQUE | TIMER_OVERRIDE)

/**
 * Bins a player back to the lobby once their grace period runs out, if the role hasn't come back.
 *
 * Fires off the timer symphony_revoke() sets. Re-checks everything on the way through, because a
 * grace period is long enough for them to have been adminned, re-granted, or to have left.
 *
 * Never ejects on a lookup that failed. Booting someone out of a round they were legitimately
 * playing because the database blinked is a far worse outcome than leaving a genuinely revoked
 * player in for a few more minutes, and SSsymphony's sweep picks the real ones back up as soon
 * as it can query again.
 *
 * Arguments:
 * - target_ckey: The ckey whose grace period just expired.
 */
/proc/symphony_enforce_kick(target_ckey)
	var/client/found = GLOB.directory[target_ckey]
	if(!found || isnewplayer(found.mob))
		return
	// Checked again, they might have been adminned during the grace.
	if(found.holder)
		return
	var/whitelisted = symphony_whitelist_lookup(target_ckey)
	// Couldn't ask. Never eject someone on a blind check - SSsymphony's sweep re-detects a real revoke once the DB is back, and the join gate is still refusing them in the meantime.
	if(isnull(whitelisted))
		log_game("Symphony: skipped returning [key_name(found)] to the lobby, the whitelist database was unreachable.")
		return
	if(whitelisted)
		to_chat(found, span_notice("Whitelist role restored - you may continue playing."))
		return
	to_chat(found, span_userdanger("Whitelist lost. Returning you to the lobby."))
	symphony_return_to_lobby(found)

/proc/symphony_return_to_lobby(client/target)
	var/mob/old_mob = target.mob
	if(old_mob && !isnewplayer(old_mob))
		old_mob.log_message("returned to lobby by discord whitelist enforcement", LOG_GAME)
		// The lobby mob's Login() makes a new mind, so retire this one or the key owns two.
		if(old_mob.mind)
			old_mob.mind.active = FALSE
	var/mob/dead/new_player/lobby = new()
	lobby.key = target.key
	// Before show_title_screen(), which re-inits the menu off this - the gate was never evaluated while they were in a body, so it still holds whatever it said back in the lobby.
	target.lobby_menu?.set_whitelist_gate(TRUE)
	lobby.show_title_screen()
	// We leave the body behind on purpose, so say so - it could be a live antag.
	message_admins("Symphony: [key_name_admin(target)] was returned to the lobby by whitelist enforcement. Their body was left in place[old_mob ? " at [AREACOORD(old_mob)]" : ""].")

/// Re-check on connect, the grace timer is one shot so a relog would otherwise dodge it.
/client/New()
	. = ..()
	if(!.)
		return
	if(!CONFIG_GET(flag/symphony_enabled))
		return
	if(!ckey || !mob || isnewplayer(mob)) // the lobby has its own gate
		return
	if(holder) // staff exemption, as in gate.dm
		return
	// Only revoke if it's an explicit no (FALSE). A DB outage (null) isn't a revoke, and symphony_revoke() would tell them their role was removed when we have no idea whether it was.
	var/whitelisted = symphony_whitelist_lookup(ckey)
	if(isnull(whitelisted) || whitelisted)
		return
	symphony_revoke(ckey)

/proc/symphony_notify_grant(target_ckey)
	// Same - no announcing a whitelist nothing was enforcing.
	if(!CONFIG_GET(flag/symphony_enabled))
		return
	symphony_invalidate_whitelist_cache(target_ckey)
	var/client/found = GLOB.directory[ckey(target_ckey)]
	if(!found)
		return
	to_chat(found, span_greentext("You are now whitelisted - you can join the round."))
	var/mob/dead/new_player/lobby_mob = found.mob
	if(istype(lobby_mob))
		found.lobby_menu?.set_whitelist_gate(FALSE)
		lobby_mob.show_title_screen()
