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
		lobby.show_title_screen()
		return
	var/grace = CONFIG_GET(number/symphony_grace_seconds)
	to_chat(found, span_userdanger("Your Discord whitelist role was removed. You will be returned to the lobby in [grace] seconds unless it is restored."))
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(symphony_enforce_kick), target_ckey), grace SECONDS, TIMER_UNIQUE | TIMER_OVERRIDE)

/proc/symphony_enforce_kick(target_ckey)
	var/client/found = GLOB.directory[target_ckey]
	if(!found || isnewplayer(found.mob))
		return
	// Checked again, they might have been adminned during the grace.
	if(found.holder)
		return
	if(is_symphony_whitelisted(target_ckey))
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
	if(is_symphony_whitelisted(ckey))
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
		lobby_mob.show_title_screen()
