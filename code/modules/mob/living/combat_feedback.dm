/**
 * The feedback budget: one arbiter deciding what a fight is allowed to tell you.
 *
 * Combat produces more announceable events than anybody can read - a burst of fire is five impacts,
 * three injuries, a plate cracking and an organ giving out inside half a second. Left alone each
 * phase adds its own message and the one that mattered scrolls away with the rest. So every combat
 * event asks here first, and within [COMBAT_FEEDBACK_WINDOW] only the biggest one speaks.
 *
 * The window is per mob, so a room full of people being shot still reads normally; it is one
 * person's feedback that is rationed, not the fight's.
 */

/mob/living
	/// Priority of whatever last won a feedback moment. Reset by the window expiring, not by time passing.
	var/last_feedback_priority = 0
	/// How long the current winner holds the floor.
	COOLDOWN_DECLARE(feedback_window)

/**
 * Announces one combat event, if it is the biggest thing to have happened to this mob just now.
 *
 * Everything an event wants to do is passed in one call - message, sound and shake together - so
 * that losing the moment means the whole event goes quiet rather than half of it leaking through.
 *
 * Arguments:
 * * priority - One of the COMBAT_FEEDBACK_* defines, optionally plus a severity. Higher wins.
 * * message - What onlookers see. Null for events that only shake.
 * * self_message - What the mob sees. Null falls back to [message].
 * * sound - Sound to play at the mob.
 * * sound_volume - How loud.
 * * shake_strength - Screen shake for the mob itself, in tiles. Zero for none.
 * * vision_distance - How far [message] carries.
 *
 * Returns TRUE if this event won the moment and was announced.
 */
/mob/living/proc/combat_feedback(
	priority = COMBAT_FEEDBACK_IMPACT,
	message = null,
	self_message = null,
	sound,
	sound_volume = 60,
	shake_strength = 0,
	vision_distance = COMBAT_MESSAGE_RANGE,
)
	// A tie loses. Two hits of the same size in one moment are one moment's worth of noise.
	if(priority <= last_feedback_priority && !COOLDOWN_FINISHED(src, feedback_window))
		return FALSE

	last_feedback_priority = priority
	COOLDOWN_START(src, feedback_window, COMBAT_FEEDBACK_WINDOW)

	if(message)
		visible_message(message, self_message || message, vision_distance = vision_distance)
	else if(self_message)
		to_chat(src, self_message)

	if(sound)
		playsound(src, sound, sound_volume, TRUE)

	if(shake_strength > 0)
		shake_camera(src, COMBAT_SHAKE_DURATION, shake_strength)

	return TRUE

/**
 * Shakes the screen of whoever just took a hit, harder the further inside them it got.
 *
 * The design's "small shakes for NP hits, big for P hits". Routed through the arbiter so continuous
 * damage - burning, pressure, a shotgun's worth of pellets - shakes once rather than once per tick,
 * and so a hit that also broke something announces the break instead of juddering over it.
 *
 * Arguments:
 * * damage - How much got through. Ignored entirely for a hit a plate stopped.
 * * penetrated - Whether anything reached the body at all.
 */
/mob/living/proc/shake_from_impact(damage, penetrated = TRUE)
	if(!penetrated)
		return combat_feedback(COMBAT_FEEDBACK_IMPACT, shake_strength = COMBAT_SHAKE_NONPENETRATING)

	var/strength = LERP(
		COMBAT_SHAKE_PENETRATING_MIN,
		COMBAT_SHAKE_PENETRATING_MAX,
		min(damage / COMBAT_SHAKE_FULL_STRENGTH_DAMAGE, 1),
	)
	return combat_feedback(COMBAT_FEEDBACK_IMPACT, shake_strength = strength)
