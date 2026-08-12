/// Limits each mob to the highest-priority combat feedback in a short window.

/mob/living
	/// Priority of whatever last won a feedback moment. Only meaningful while the window is open.
	var/last_feedback_priority = 0
	/// How long the current winner suppresses lesser events.
	COOLDOWN_DECLARE(feedback_window)

/**
 * Announces one combat event, if it is the biggest thing to have happened to this mob just now.
 *
 * Message, sound and shake are passed together, so losing the moment silences the whole event
 * rather than half of it.
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
	// A tie loses, so two hits of the same size in one window announce once.
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
 * Shakes the screen of whoever took a hit, scaled by how much damage got through.
 *
 * Small shakes for stopped hits, larger ones the more damage got through. Routed through the
 * arbiter so continuous damage shakes once rather than once per tick.
 *
 * Arguments:
 * * damage - How much got through. Ignored for a hit a plate stopped.
 * * penetrated - Whether anything reached the body.
 */
/mob/living/proc/shake_from_impact(damage, penetrated = TRUE)
	if(!penetrated)
		return combat_feedback(COMBAT_FEEDBACK_IMPACT, shake_strength = COMBAT_SHAKE_NONPENETRATING)

	var/severity = min(damage / COMBAT_SHAKE_FULL_STRENGTH_DAMAGE, 1)
	return combat_feedback(COMBAT_FEEDBACK_IMPACT, shake_strength = LERP(COMBAT_SHAKE_PENETRATING_MIN, COMBAT_SHAKE_PENETRATING_MAX, severity))
