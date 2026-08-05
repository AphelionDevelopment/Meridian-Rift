/// Reusable dust puff kicked up by a running mob. Parks in nullspace between appearances.
/obj/effect/sprint_dust
	icon = 'modular_nova/modules/sprint/icons/sprint_dust.dmi'
	icon_state = null
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT

/**
 * Plays one puff, then returns to nullspace.
 *
 * Arguments:
 * * state - icon state to flick.
 * * puff_dir - direction the mob was moving.
 * * location - turf to appear on.
 * * duration - how long to stay before leaving.
 */
/obj/effect/sprint_dust/proc/appear(state, puff_dir, turf/location, duration)
	if(!location)
		return
	// The full cloud is only drawn facing south, the smaller puffs trail the way you went.
	dir = (state == "sprint_cloud") ? SOUTH : puff_dir
	abstract_move(location)
	flick(state, src)
	addtimer(CALLBACK(src, TYPE_PROC_REF(/atom/movable, moveToNullspace)), duration, TIMER_UNIQUE|TIMER_OVERRIDE)
