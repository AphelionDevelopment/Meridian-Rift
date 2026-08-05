/mob/living/carbon
	// SPRINT - walking is the free default, running is faster but costs stamina.
	move_intent = MOVE_INTENT_WALK

/// Cooldown for the next smell
	var/next_smell = 0
