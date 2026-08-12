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
	var/list/holders = symphony_ingame_role_ckeys("whitelist")
	if(isnull(holders))
		return
	// A copy, because revoking can qdel a client out from under the loop.
	for(var/client/checked as anything in GLOB.clients.Copy())
		if(!checked || !checked.ckey)
			continue
		// We've got the real answer in bulk, so the stale per-ckey cache can go.
		symphony_invalidate_whitelist_cache(checked.ckey)
		if(holders[checked.ckey])
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
