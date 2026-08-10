/// Movement penalty from the mob's current pain bracket. Slowdown is set by the pain controller.
/datum/movespeed_modifier/pain
	id = "pain"
	variable = TRUE

/// Task time penalty from the mob's current pain bracket. Slowdown is set by the pain controller.
/datum/actionspeed_modifier/pain
	id = "pain"
	variable = TRUE

/**
 * Pain shock, the spike variant.
 *
 * Applied when a mob is pinned at the pain cap. Blacks the mob out entirely, and is removed the
 * moment felt pain drops back under PAIN_SHOCK_RECOVERY_THRESHOLD, so nobody yo-yos on the line.
 * Phase 1 keeps this trait-only - it deliberately does not touch stat, which is Phase 4's job.
 */
/datum/status_effect/incapacitating/pain_shock
	id = "pain_shock"
	status_type = STATUS_EFFECT_UNIQUE
	// Removal is driven by the pain controller, not a timer.
	duration = STATUS_EFFECT_PERMANENT
	tick_interval = STATUS_EFFECT_NO_TICK

/datum/status_effect/incapacitating/pain_shock/on_apply()
	if(owner.stat == DEAD)
		return FALSE

	. = ..()
	if(!.)
		return .

	owner.add_traits(list(TRAIT_INCAPACITATED, TRAIT_IMMOBILIZED, TRAIT_FLOORED, TRAIT_HANDS_BLOCKED), PAIN_TRAIT)
	owner.visible_message(
		span_warning("[owner] collapses, overwhelmed!"),
		span_userdanger("The pain is too much. Everything goes black."),
	)
	return .

/datum/status_effect/incapacitating/pain_shock/on_remove()
	owner.remove_traits(list(TRAIT_INCAPACITATED, TRAIT_IMMOBILIZED, TRAIT_FLOORED, TRAIT_HANDS_BLOCKED), PAIN_TRAIT)
	to_chat(owner, span_warning("You come to, wrecked."))
	return ..()

/**
 * Pain shock, the floor variant.
 *
 * Applied when the mob's permanent floor alone pins it at the cap. Unlike a spike blackout there is
 * nothing to drain, so this lasts until treatment or a painkiller lowers felt pain. The mob can
 * crawl, drag itself and reach its own pockets - crawling is the whole point of the state - but it
 * cannot stand or fight.
 */
/datum/status_effect/pain_crawl
	id = "pain_crawl"
	status_type = STATUS_EFFECT_UNIQUE
	duration = STATUS_EFFECT_PERMANENT
	tick_interval = STATUS_EFFECT_NO_TICK
	alert_type = null

/datum/status_effect/pain_crawl/on_apply()
	if(owner.stat == DEAD)
		return FALSE

	// Floored but not hands-blocked: reaching your own pockets for an injector is the way out.
	owner.add_traits(list(TRAIT_FLOORED, TRAIT_PACIFISM), PAIN_TRAIT)
	owner.visible_message(
		span_warning("[owner] goes down, barely conscious!"),
		span_userdanger("You can't stand. All you can do is drag yourself."),
	)
	return TRUE

/datum/status_effect/pain_crawl/on_remove()
	owner.remove_traits(list(TRAIT_FLOORED, TRAIT_PACIFISM), PAIN_TRAIT)
	to_chat(owner, span_notice("You can get up again."))
	return ..()

/**
 * Adrenaline.
 *
 * Massive trauma triggers fight or flight once per fight. Halves felt pain long enough to shoot back
 * or run, then hands all of it back at once. It delays pain shock, it never cancels it.
 */
/datum/status_effect/adrenaline
	id = "adrenaline"
	status_type = STATUS_EFFECT_UNIQUE
	duration = PAIN_ADRENALINE_DURATION
	tick_interval = STATUS_EFFECT_NO_TICK
	alert_type = null

/datum/status_effect/adrenaline/on_apply()
	if(!iscarbon(owner))
		return FALSE

	var/mob/living/carbon/carbon_owner = owner
	if(isnull(carbon_owner.pain_controller))
		return FALSE

	to_chat(owner, span_userdanger("Your heart slams and the pain washes out of you!"))
	carbon_owner.pain_controller.update_dampening()
	return TRUE

/datum/status_effect/adrenaline/on_remove()
	var/mob/living/carbon/carbon_owner = owner
	// The crash: everything it was holding back lands at once, plus a moment of being unable to cope.
	carbon_owner.pain_controller?.update_dampening()
	carbon_owner.adjust_stutter(PAIN_ADRENALINE_CRASH_STUTTER)
	to_chat(owner, span_userdanger("The adrenaline drains away, and everything hurts at once."))
	return ..()
