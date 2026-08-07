/**
 * The stock cinematic hangs its backdrop on the mob and only re-shows on that mob logging back in,
 * so anyone the nuke gibs loses the screen the moment they land in an observer. Which, at the end of
 * a self-destruct, is everybody. This one follows the client into whatever body it ends up in.
 */
/datum/cinematic/nuke/self_destruct/persistent

/**
 * Mirrors the parent, except for the wait.
 *
 * intro_nuke is three one second frames, and the parent waits 3.5 for it, so its last frame sits on
 * screen for half a second after the countdown has already finished. That half second puts the blast
 * out of step with the announcement, which the whole sequence is timed against.
 */
/datum/cinematic/nuke/self_destruct/persistent/play_cinematic()
	flick("intro_nuke", screen)
	stoplag(SELF_DESTRUCT_CINEMATIC_INTRO)
	play_nuke_effect()
	if(special_callback)
		special_callback.Invoke()
	if(after_nuke_summary_state)
		screen.icon_state = after_nuke_summary_state

/datum/cinematic/nuke/self_destruct/persistent/start_cinematic(list/watchers)
	. = ..()
	// The parent bails before showing anything if another cinematic blocked us. Nothing to follow.
	if(!length(watching))
		return
	RegisterSignal(SSdcs, COMSIG_GLOB_PLAYER_LOGIN, PROC_REF(on_new_body))

/**
 * Catches a client landing in a new mob.
 *
 * This fires from add_to_player_list(), which is early enough in Login() that client.clear_screen()
 * has not run yet and would throw the cinematic straight back out - leaving only the backdrop, which
 * is solid black. So we wait for COMSIG_MOB_CLIENT_LOGIN at the end of that same Login() instead.
 */
/datum/cinematic/nuke/self_destruct/persistent/proc/on_new_body(datum/source, mob/player)
	SIGNAL_HANDLER
	// Override, because the parent may already have this mob registered to its own show_to.
	RegisterSignal(player, COMSIG_MOB_CLIENT_LOGIN, PROC_REF(show_to_new_body), override = TRUE)

/// Re-shows the cinematic, once the new mob's hud has finished building.
/datum/cinematic/nuke/self_destruct/persistent/proc/show_to_new_body(mob/player, client/player_client)
	SIGNAL_HANDLER

	if(isnull(player_client))
		return
	// show_to no-ops on a client it already has, and the backdrop went with the old body.
	if(player_client in watching)
		remove_watcher(player_client)
	show_to(player, player_client)
