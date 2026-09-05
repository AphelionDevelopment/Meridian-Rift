/// Safety net for revokes we never heard about.
SUBSYSTEM_DEF(symphony)
	name = "Discord Whitelist"
	wait = 5 MINUTES
	ss_flags = SS_BACKGROUND | SS_NO_INIT
	runlevels = RUNLEVEL_LOBBY | RUNLEVEL_SETUP | RUNLEVEL_GAME

/datum/controller/subsystem/symphony/fire()
	if(!CONFIG_GET(flag/symphony_enabled))
		return
	// One query for the lot. null means we couldn't check, an empty list means nobody holds it.
	var/epoch = GLOB.symphony_whitelist_epoch
	var/list/holders = symphony_ingame_role_ckeys("whitelist")
	// A panel notification or config change during the query makes the whole snapshot obsolete.
	if(isnull(holders) || !CONFIG_GET(flag/symphony_enabled) || epoch != GLOB.symphony_whitelist_epoch)
		return
	// A copy, because revoking can qdel a client out from under the loop.
	for(var/client/checked as anything in GLOB.clients.Copy())
		if(!checked || !checked.ckey)
			continue
		// We've got the real answer in bulk, so write it over whatever the per-ckey cache held. Blanking it instead just forces everyone to re-query for something we already know.
		var/whitelisted = holders[checked.ckey] ? TRUE : FALSE
		symphony_seed_whitelist_cache(checked.ckey, whitelisted)
		if(whitelisted)
			continue
		if(checked.holder)
			continue
		// Lobby players need unreadying too, or a missed revoke still spawns them.
		if(isnewplayer(checked.mob))
			var/mob/dead/new_player/lobby = checked.mob
			if(lobby.ready != PLAYER_NOT_READY)
				lobby.ready = PLAYER_NOT_READY
				lobby.show_title_screen()
			continue
		if(!checked.mob)
			continue
		symphony_revoke(checked.ckey)
