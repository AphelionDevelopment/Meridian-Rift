/// Movement penalty from the mob's current pain bracket. Slowdown is set by the pain controller.
/datum/movespeed_modifier/pain
	id = "pain"
	variable = TRUE

/// Task time penalty from the mob's current pain bracket. Slowdown is set by the pain controller.
/datum/actionspeed_modifier/pain
	id = "pain"
	variable = TRUE

/// Brief movement penalty after fight-or-flight wears off.
/datum/movespeed_modifier/status_effect/adrenaline_crash
	multiplicative_slowdown = PAIN_ADRENALINE_CRASH_SLOWDOWN

/// Brief unconsciousness caused by a temporary pain spike.
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

	// STAMINA as the source, since that is what stamcrit used and what IsParalyzed(), tackles and
	// less-lethal embeds still read. The crawl keeps a source of its own, as the two can be applied at
	// once and each has to be removable without the other.
	owner.add_traits(list(TRAIT_INCAPACITATED, TRAIT_IMMOBILIZED, TRAIT_FLOORED, TRAIT_HANDS_BLOCKED), STAMINA)
	owner.visible_message(
		span_warning("[owner] collapses, overwhelmed!"),
		span_userdanger("The pain is too much. Everything goes black."),
	)
	return .

/datum/status_effect/incapacitating/pain_shock/on_remove()
	owner.remove_traits(list(TRAIT_INCAPACITATED, TRAIT_IMMOBILIZED, TRAIT_FLOORED, TRAIT_HANDS_BLOCKED), STAMINA)
	to_chat(owner, span_warning("You come to, wrecked."))
	return ..()

/// A pain-induced crawl that lasts until treatment or analgesia lowers the pain floor.
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
	owner.add_traits(list(TRAIT_FLOORED, TRAIT_PACIFISM), TRAIT_STATUS_EFFECT(id))
	RegisterSignal(owner, COMSIG_MOB_CLICKON, PROC_REF(restrict_interaction))
	owner.visible_message(
		span_warning("[owner] goes down, barely conscious!"),
		span_userdanger("You can't stand. All you can do is drag yourself."),
	)
	return TRUE

/datum/status_effect/pain_crawl/on_remove()
	UnregisterSignal(owner, COMSIG_MOB_CLICKON)
	owner.remove_traits(list(TRAIT_FLOORED, TRAIT_PACIFISM), TRAIT_STATUS_EFFECT(id))
	to_chat(owner, span_notice("You can get up again."))
	return ..()

/// Keeps a crawler's usable hands to self-help: their own body, clothing, pockets and held items.
/datum/status_effect/pain_crawl/proc/restrict_interaction(datum/source, atom/target, list/modifiers)
	SIGNAL_HANDLER

	// Looking is not an action, and must remain available for situational awareness.
	if(LAZYACCESS(modifiers, SHIFT_CLICK))
		return NONE
	if(target == owner || (target in owner.get_all_contents()))
		return NONE

	to_chat(owner, span_warning("You can only manage your own gear and injuries through the pain."))
	return COMSIG_MOB_CANCEL_CLICKON

/// Temporarily halves felt pain after major trauma.
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
	carbon_owner.pain_controller.update_pain(adrenaline_override = TRUE)
	return TRUE

/datum/status_effect/adrenaline/on_remove()
	var/mob/living/carbon/carbon_owner = owner
	// The crash: everything it held back lands at once, with a brief slowdown on top.
	carbon_owner.pain_controller?.update_pain(adrenaline_override = FALSE)
	carbon_owner.apply_status_effect(/datum/status_effect/adrenaline_crash)
	to_chat(owner, span_userdanger("The adrenaline drains away, and everything hurts at once."))
	return ..()

/// The brief slowdown after an adrenaline rush ends.
/datum/status_effect/adrenaline_crash
	id = "adrenaline_crash"
	status_type = STATUS_EFFECT_REFRESH
	duration = PAIN_ADRENALINE_CRASH_DURATION
	tick_interval = STATUS_EFFECT_NO_TICK
	alert_type = null

/datum/status_effect/adrenaline_crash/on_apply()
	owner.add_movespeed_modifier(/datum/movespeed_modifier/status_effect/adrenaline_crash)
	return TRUE

/datum/status_effect/adrenaline_crash/on_remove()
	owner.remove_movespeed_modifier(/datum/movespeed_modifier/status_effect/adrenaline_crash)
	return ..()
