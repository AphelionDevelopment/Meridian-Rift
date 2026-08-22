/// Lobby menu actions a gated player can still send.
GLOBAL_LIST_INIT(symphony_gate_free_actions, list("server_swap"))

/// TRUE if this lobby menu action is allowed through the whitelist gate.
/proc/symphony_action_is_gate_free(action)
	return action in GLOB.symphony_gate_free_actions

/// TRUE means this new_player isn't getting into the round.
/mob/dead/new_player/proc/symphony_blocks_play()
	if(!CONFIG_GET(flag/symphony_enabled))
		return FALSE
	if(!client)
		return TRUE
	// We're fail-closed, so without this a DB blip locks the admins out of their own round.
	if(client.holder)
		return FALSE
	return !is_symphony_whitelisted(ckey)

/// Non-blocking version of symphony_blocks_play()
/mob/dead/new_player/proc/symphony_blocks_play_cached()
	if(!CONFIG_GET(flag/symphony_enabled))
		return FALSE
	if(!client)
		return TRUE
	if(client.holder)
		return FALSE
	var/cached = symphony_whitelist_cache_peek(ckey)
	return isnull(cached) ? TRUE : !cached

/datum/lobby_menu
	/// Whether a symphony_whitelist_cache_peek() miss already has a refresh_whitelist_gate() going off
	var/whitelist_gate_refreshing = FALSE

/// Whether the current player is currently blocked from playing by the Discord whitelist gate.
/// Display-only: reads the whitelist cache rather than the DB, so it never sleeps. Kicks off a background
/// refresh_whitelist_gate() on a cache miss, which pushes the real answer once it lands.
/datum/lobby_menu/proc/symphony_blocks_this_player()
	var/mob/dead/new_player/player = client?.mob
	if(!istype(player))
		return FALSE
	// Neither of these needs the DB, so skip the cache dance and avoid spawning refreshes every tick for nothing.
	if(!CONFIG_GET(flag/symphony_enabled) || client.holder)
		return FALSE
	if(!whitelist_gate_refreshing && isnull(symphony_whitelist_cache_peek(player.ckey)))
		whitelist_gate_refreshing = TRUE
		refresh_whitelist_gate()
	return player.symphony_blocks_play_cached()

/// Does the real (DB-hitting, sleep-capable) whitelist check off the should-not-sleep callstack, then pushes the answer to the client.
/datum/lobby_menu/proc/refresh_whitelist_gate()
	set waitfor = FALSE
	var/mob/dead/new_player/player = client?.mob
	if(!istype(player))
		whitelist_gate_refreshing = FALSE
		return
	var/blocks = player.symphony_blocks_play()
	whitelist_gate_refreshing = FALSE
	if(!client)
		return
	send_update(list("whitelistGate" = blocks))

/mob/dead/new_player/proc/symphony_gate_notice()
	// `key`, not `ckey` - ckey() strips the hyphen that is_guest_key matches on
	if(is_guest_key(key))
		to_chat(src, span_userdanger("You are logged in as a BYOND guest."))
		to_chat(src, span_warning("Guest accounts cannot be whitelisted. Sign in with a real BYOND account and reconnect to play."))
		return
	to_chat(src, span_userdanger("You are not whitelisted."))
	to_chat(src, span_warning("Use the <b>GET WHITELISTED</b> button on the lobby menu to link your Discord account. You must stay in the Discord with the whitelist role to play."))
