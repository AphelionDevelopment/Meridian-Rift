/// What the lobby menu's `whitelistGate` field can hold.
#define SYMPHONY_GATE_OPEN "open"
#define SYMPHONY_GATE_BLOCKED "blocked"
#define SYMPHONY_GATE_CHECKING "checking"
#define SYMPHONY_GATE_UNAVAILABLE "unavailable"

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

/**
 * Returns how the whitelist gate currently stands for this new_player, and why.
 *
 * symphony_blocks_play() only answers "in" or "out", and it fails closed, so a database outage
 * comes back from it looking exactly like a refusal. This says which of the two it was, so the
 * lobby can tell someone the database is down instead of telling them they aren't whitelisted
 * and sending them off to re-link an account that was never the problem.
 *
 * Shares symphony_whitelist_lookup()'s cache, so the display path asking costs nothing extra.
 * Sleeps on a cache miss - call it from refresh_whitelist_gate(), never from process().
 *
 * Returns:
 * - SYMPHONY_GATE_OPEN: They may play, or nothing is gating them.
 * - SYMPHONY_GATE_BLOCKED: We asked, and they aren't whitelisted.
 * - SYMPHONY_GATE_UNAVAILABLE: We couldn't ask. Still barred, but it isn't their doing.
 */
/mob/dead/new_player/proc/symphony_gate_state()
	if(!CONFIG_GET(flag/symphony_enabled))
		return SYMPHONY_GATE_OPEN
	if(!client)
		return SYMPHONY_GATE_BLOCKED
	if(client.holder)
		return SYMPHONY_GATE_OPEN
	var/answer = symphony_whitelist_lookup(ckey)
	// Fail-closed still applies, we just don't accuse them of not being whitelisted when we couldn't check.
	if(isnull(answer))
		return SYMPHONY_GATE_UNAVAILABLE
	return answer ? SYMPHONY_GATE_OPEN : SYMPHONY_GATE_BLOCKED

/**
 * Returns whether the gate is blocking this new_player, without ever touching the database.
 *
 * The non-sleeping counterpart to symphony_blocks_play(), for callers that can't wear a query.
 *
 * A cache miss comes back null rather than TRUE. "We haven't asked yet" is not the same as "no",
 * and rendering it as one is what had the lobby flash a whitelist rejection at everybody every
 * time the cache lapsed.
 *
 * Returns:
 * - TRUE: They're barred, or they have no client.
 * - FALSE: They're clear, they're staff, or the module is off.
 * - null: Nothing cached. Ask symphony_blocks_play() if you need a real answer.
 */
/mob/dead/new_player/proc/symphony_blocks_play_cached()
	if(!CONFIG_GET(flag/symphony_enabled))
		return FALSE
	if(!client)
		return TRUE
	if(client.holder)
		return FALSE
	var/cached = symphony_whitelist_cache_peek(ckey)
	return isnull(cached) ? null : !cached

/datum/lobby_menu
	/// Whether a symphony_whitelist_cache_peek() miss already has a refresh_whitelist_gate() going off
	var/whitelist_gate_refreshing = FALSE
	/// The last state we actually resolved. Held across cache expiry, so a routine TTL lapse doesn't flash the gate at a whitelisted player. Null until the first lookup lands.
	var/whitelist_gate_state = null

/**
 * Returns the gate state to hand the lobby menu this tick.
 *
 * Display only, and it runs inside process(), so it reads the cache rather than the database and
 * never sleeps. On a cache miss it kicks off a background refresh_whitelist_gate(), which pushes
 * the real answer the moment it lands.
 *
 * The last resolved state is held on the datum and only moves when a lookup actually resolves.
 * Without that, the ten second cache TTL would drop this back to "unknown" every ten seconds and
 * the menu would blink a whitelist rejection at players who are perfectly whitelisted. It also
 * means the unavailable state survives a database outage, during which nothing caches at all.
 *
 * Returns:
 * - A SYMPHONY_GATE_* value. SYMPHONY_GATE_CHECKING until the first lookup ever lands.
 */
/datum/lobby_menu/proc/symphony_blocks_this_player()
	var/mob/dead/new_player/player = client?.mob
	if(!istype(player))
		return SYMPHONY_GATE_OPEN
	// Neither of these needs the DB, so skip the cache dance and avoid spawning refreshes every tick for nothing.
	if(!CONFIG_GET(flag/symphony_enabled) || client.holder)
		return SYMPHONY_GATE_OPEN
	if(!whitelist_gate_refreshing && isnull(symphony_whitelist_cache_peek(player.ckey)))
		whitelist_gate_refreshing = TRUE
		refresh_whitelist_gate()
	// Only a real cached answer moves the gate. Nothing caches while the DB is down, so the unavailable state refresh_whitelist_gate() left behind stays put instead of decaying to "blocked".
	var/cached = player.symphony_blocks_play_cached()
	if(!isnull(cached))
		whitelist_gate_state = cached ? SYMPHONY_GATE_BLOCKED : SYMPHONY_GATE_OPEN
	return whitelist_gate_state || SYMPHONY_GATE_CHECKING

/**
 * Does the real, database-hitting whitelist check off the back of a callstack that mustn't sleep.
 *
 * symphony_blocks_this_player() runs inside the lobby menu's process(), which can't block on a
 * query, so it fires this instead and serves the cache in the meantime. Once the answer lands,
 * this records it and pushes it to the client on its own.
 */
/datum/lobby_menu/proc/refresh_whitelist_gate()
	set waitfor = FALSE
	var/mob/dead/new_player/player = client?.mob
	if(!istype(player))
		whitelist_gate_refreshing = FALSE
		return
	var/state = player.symphony_gate_state()
	whitelist_gate_refreshing = FALSE
	if(!client)
		return
	whitelist_gate_state = state
	send_update(list("whitelistGate" = state))

/**
 * Pushes a gate state we already know to be right straight to the client.
 *
 * A panel grant or revoke hands us the answer outright, so there is nothing to go and look up.
 * Without this the menu would sit on its last known state until the next refresh resolved, which
 * for a revoke means briefly showing someone a menu they are no longer entitled to.
 *
 * Call it before show_title_screen(), which re-inits the menu off whatever this leaves behind.
 *
 * Arguments:
 * - blocked: TRUE to raise the gate, FALSE to drop it.
 */
/datum/lobby_menu/proc/set_whitelist_gate(blocked)
	whitelist_gate_state = blocked ? SYMPHONY_GATE_BLOCKED : SYMPHONY_GATE_OPEN
	send_update(list("whitelistGate" = whitelist_gate_state))

/mob/dead/new_player/proc/symphony_gate_notice()
	// `key`, not `ckey` - ckey() strips the hyphen that is_guest_key matches on
	if(is_guest_key(key))
		to_chat(src, span_userdanger("You are logged in as a BYOND guest."))
		to_chat(src, span_warning("Guest accounts cannot be whitelisted. Sign in with a real BYOND account and reconnect to play."))
		return
	// The gate fails closed, so an outage reaches here looking exactly like a refusal. Say which it is.
	if(!SSdbcore.Connect())
		to_chat(src, span_userdanger("The whitelist database is unreachable."))
		to_chat(src, span_warning("This is a problem on our end, not with your account. Try again shortly."))
		return
	to_chat(src, span_userdanger("You are not whitelisted."))
	to_chat(src, span_warning("Use the <b>GET WHITELISTED</b> button on the lobby menu to link your Discord account. You must stay in the Discord with the whitelist role to play."))

#undef SYMPHONY_GATE_OPEN
#undef SYMPHONY_GATE_BLOCKED
#undef SYMPHONY_GATE_CHECKING
#undef SYMPHONY_GATE_UNAVAILABLE
