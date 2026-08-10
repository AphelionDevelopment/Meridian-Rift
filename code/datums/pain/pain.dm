/**
 * Pain controller.
 *
 * Holds the two values every pain gate in the game reads. Injuries and damaged organs set a
 * permanent floor that only treatment lowers; impacts, stuns and exertion stack a temporary pool on
 * top of it. Painkillers reduce what the mob feels, never what it is carrying, so bloodloss and
 * overflow read the floor while brackets and shock read [felt_pain].
 */
/datum/pain
	/// The mob this controller belongs to.
	var/mob/living/carbon/parent
	/// Permanent pain per bodypart zone, before that zone's cap is applied.
	var/list/floor_by_zone = list()
	/// Sum of every capped zone floor. Never exceeds PAIN_FLOOR_MAXIMUM.
	var/pain_floor = 0
	/// Pain from impacts and stuns. Decays on its own, fast while high.
	var/temporary_pain = 0
	/// pain_floor plus temporary_pain. The real total, which painkillers do not touch.
	var/total_pain = 0
	/// total_pain minus dampening. Brackets, shock and recovery all read this.
	var/felt_pain = 0
	/// Felt pain the strongest active painkiller is hiding. Painkillers do not stack.
	var/dampening = 0
	/// The bracket felt_pain currently falls into.
	var/datum/pain_bracket/current_bracket
	/// Whether this mob has already spent its one shot at fight or flight.
	var/adrenaline_spent = FALSE
	/// Movement penalty from the current bracket. Held so its slowdown can be retuned in place.
	var/datum/movespeed_modifier/pain/movespeed_mod
	/// Task time penalty from the current bracket. Held for the same reason.
	var/datum/actionspeed_modifier/pain/actionspeed_mod
	/// When the current bracket may next roll its intermittent effects.
	COOLDOWN_DECLARE(effect_roll_cooldown)

/datum/pain/New(mob/living/carbon/new_parent)
	if(!istype(new_parent))
		stack_trace("Tried to attach a pain controller to a non-carbon!")
		qdel(src)
		return

	parent = new_parent
	START_PROCESSING(SSpain, src)

	RegisterSignal(parent, COMSIG_CARBON_GAIN_WOUND, PROC_REF(on_wounds_changed))
	RegisterSignal(parent, COMSIG_CARBON_LOSE_WOUND, PROC_REF(on_wounds_changed))
	RegisterSignal(parent, COMSIG_CARBON_ORGAN_DAMAGED, PROC_REF(on_organs_changed))
	RegisterSignal(parent, COMSIG_ORGAN_IMPLANTED, PROC_REF(on_organs_changed))
	RegisterSignal(parent, COMSIG_ORGAN_REMOVED, PROC_REF(on_organs_changed))
	RegisterSignal(parent, COMSIG_MOB_STATCHANGE, PROC_REF(on_stat_changed))
	RegisterSignal(parent, COMSIG_QDELETING, PROC_REF(clear_parent_ref))

	recalculate_floor()

/datum/pain/Destroy(force)
	STOP_PROCESSING(SSpain, src)
	if(parent)
		clear_effects()
		clear_parent_ref()
	current_bracket = null
	return ..()

/// Drops our reference to the mob when it is being deleted, so we never hold it past its life.
/datum/pain/proc/clear_parent_ref()
	SIGNAL_HANDLER

	UnregisterSignal(parent, list(
		COMSIG_CARBON_GAIN_WOUND,
		COMSIG_CARBON_LOSE_WOUND,
		COMSIG_CARBON_ORGAN_DAMAGED,
		COMSIG_ORGAN_IMPLANTED,
		COMSIG_ORGAN_REMOVED,
		COMSIG_MOB_STATCHANGE,
		COMSIG_QDELETING,
	))
	parent = null

/datum/pain/process(seconds_per_tick)
	if(QDELETED(parent))
		return

	update_dampening()

	if(temporary_pain > 0)
		// Fast while high and slower as it falls, so a maxed pool drains to the shock recovery
		// threshold in under five seconds but the last of it lingers.
		var/decay = (PAIN_TEMPORARY_DECAY_FLAT + (temporary_pain * PAIN_TEMPORARY_DECAY_COEFFICIENT)) * seconds_per_tick
		adjust_temporary_pain(-decay)

	roll_bracket_effects()

/// Wounds change the floor, and waiting a tick to feel a broken arm is the delay this system exists to remove.
/datum/pain/proc/on_wounds_changed(datum/source, datum/wound/changed_wound, obj/item/bodypart/limb)
	SIGNAL_HANDLER

	recalculate_floor()
	if(changed_wound?.pain_factor >= PAIN_ADRENALINE_INJURY_TRIGGER)
		try_trigger_adrenaline()

/// Organ damage, insertion and removal all move the floor.
/datum/pain/proc/on_organs_changed(datum/source, obj/item/organ/changed_organ, damage_amount, maximum)
	SIGNAL_HANDLER

	recalculate_floor()

/// Corpses feel nothing, so stop burning cycles on them until they are back up.
/datum/pain/proc/on_stat_changed(datum/source, new_stat, old_stat)
	SIGNAL_HANDLER

	if(old_stat == DEAD && new_stat != DEAD)
		START_PROCESSING(SSpain, src)
		return

	if(old_stat != DEAD && new_stat == DEAD)
		STOP_PROCESSING(SSpain, src)
		clear_effects()

/**
 * Rebuilds the permanent floor from every wound and damaged organ the mob is carrying.
 *
 * Each zone is capped on its own before the total is summed, so no single bodypart can put someone
 * into shock. Combinations still can.
 */
/datum/pain/proc/recalculate_floor()
	if(QDELETED(parent))
		return

	floor_by_zone.Cut()

	for(var/obj/item/bodypart/part as anything in parent.bodyparts)
		for(var/datum/wound/injury as anything in part.wounds)
			floor_by_zone[part.body_zone] += injury.pain_factor

	for(var/obj/item/organ/inner_organ as anything in parent.organs)
		if(!inner_organ.pain_factor || !inner_organ.damage || !inner_organ.maxHealth)
			continue
		// A lightly bruised organ should not hurt as much as a failing one.
		var/damage_ratio = min(inner_organ.damage / inner_organ.maxHealth, 1)
		floor_by_zone[inner_organ.zone] += inner_organ.pain_factor * damage_ratio

	var/new_floor = 0
	for(var/zone in floor_by_zone)
		new_floor += min(floor_by_zone[zone], get_zone_cap(zone))

	pain_floor = min(round(new_floor, DAMAGE_PRECISION), PAIN_FLOOR_MAXIMUM)
	update_pain()

/**
 * Returns how close a bodypart zone is to its own pain cap, from 0 to 1, as the mob would feel it.
 *
 * Reads felt rather than total pain, so painkillers blind the mob's own readouts - you know how bad
 * it feels, not what you are actually carrying.
 *
 * Arguments:
 * * zone - One of the BODY_ZONE_* defines.
 */
/datum/pain/proc/get_zone_pain_ratio(zone)
	var/zone_cap = get_zone_cap(zone)
	if(!zone_cap)
		return 0

	var/zone_pain = min(floor_by_zone[zone] || 0, zone_cap)
	if(total_pain > 0)
		zone_pain *= (felt_pain / total_pain)

	return clamp(zone_pain / zone_cap, 0, 1)

/**
 * Returns the most permanent pain a bodypart zone may contribute to the floor.
 *
 * Arguments:
 * * zone - One of the BODY_ZONE_* defines.
 */
/datum/pain/proc/get_zone_cap(zone)
	switch(zone)
		if(BODY_ZONE_HEAD)
			return PAIN_CAP_HEAD
		if(BODY_ZONE_CHEST)
			return PAIN_CAP_CHEST
	return PAIN_CAP_LIMB

/**
 * Adds to or drains the temporary pool.
 *
 * Arguments:
 * * amount - Pain to add. Negative drains.
 */
/datum/pain/proc/adjust_temporary_pain(amount)
	if(!amount)
		return

	var/new_temporary = clamp(temporary_pain + amount, 0, PAIN_TEMPORARY_MAXIMUM)
	if(new_temporary == temporary_pain)
		return

	temporary_pain = new_temporary
	update_pain()

	if(amount >= PAIN_ADRENALINE_SPIKE_TRIGGER)
		try_trigger_adrenaline()

/// Recomputes how much pain the brain is currently allowed to ignore.
/datum/pain/proc/update_dampening()
	if(QDELETED(parent))
		return

	var/strongest = 0
	// Nothing numbs like not being able to feel at all.
	if(HAS_TRAIT(parent, TRAIT_ANALGESIA))
		strongest = PAIN_DAMPEN_TOTAL
	else
		for(var/datum/reagent/held_reagent as anything in parent.reagents?.reagent_list)
			strongest = max(strongest, held_reagent.pain_dampening)

		// Being extremely drunk numbs you too, with all the drawbacks of being extremely drunk.
		var/datum/status_effect/inebriated/inebriation = parent.has_status_effect(/datum/status_effect/inebriated)
		if(inebriation?.drunk_value >= PAIN_DAMPEN_DRUNK_REQUIREMENT)
			strongest = max(strongest, PAIN_DAMPEN_ALCOHOL)

	// Adrenaline is not a painkiller, it just hides half of whatever is left on top of one.
	if(parent.has_status_effect(/datum/status_effect/adrenaline))
		strongest = max(strongest, total_pain * PAIN_ADRENALINE_DAMPEN_RATIO)

	if(dampening == strongest)
		return

	dampening = strongest
	update_pain()

/// Recomputes the totals and the bracket. Everything that changes pain ends up here.
/datum/pain/proc/update_pain()
	var/old_felt_pain = felt_pain

	total_pain = min(pain_floor + temporary_pain, PAIN_MAXIMUM)
	felt_pain = clamp(total_pain - dampening, 0, PAIN_MAXIMUM)
	update_bracket()
	update_shock()

	// The health doll reads pain now, so it has to be refreshed when pain moves rather than only
	// when health does.
	if(felt_pain != old_felt_pain)
		parent.update_health_hud()

/// Moves the mob into whichever bracket its felt pain now falls in, and applies that bracket's permanent effects.
/datum/pain/proc/update_bracket()
	var/datum/pain_bracket/new_bracket
	for(var/datum/pain_bracket/bracket as anything in GLOB.pain_brackets)
		if(felt_pain >= bracket.threshold)
			new_bracket = bracket
			break

	if(new_bracket == current_bracket)
		return

	current_bracket = new_bracket
	apply_bracket_effects()

/// Syncs the movement and task speed penalties to the current bracket.
/datum/pain/proc/apply_bracket_effects()
	if(QDELETED(parent) || isnull(current_bracket))
		return

	if(current_bracket.slowdown)
		if(isnull(movespeed_mod))
			movespeed_mod = new
			movespeed_mod.multiplicative_slowdown = current_bracket.slowdown
			parent.add_movespeed_modifier(movespeed_mod)
		else
			movespeed_mod.multiplicative_slowdown = current_bracket.slowdown
			parent.update_movespeed()
	else if(movespeed_mod)
		parent.remove_movespeed_modifier(movespeed_mod)
		QDEL_NULL(movespeed_mod)

	// interaction_penalty is a multiplier on task length, actionspeed wants the delta.
	var/action_slowdown = current_bracket.interaction_penalty - 1
	if(action_slowdown > 0)
		if(isnull(actionspeed_mod))
			actionspeed_mod = new
			actionspeed_mod.multiplicative_slowdown = action_slowdown
			parent.add_actionspeed_modifier(actionspeed_mod)
		else
			actionspeed_mod.multiplicative_slowdown = action_slowdown
			parent.update_actionspeed()
	else if(actionspeed_mod)
		parent.remove_actionspeed_modifier(actionspeed_mod)
		QDEL_NULL(actionspeed_mod)

/// Rolls the current bracket's intermittent effects. Nothing here is guaranteed; that is the point.
/datum/pain/proc/roll_bracket_effects()
	if(isnull(current_bracket) || QDELETED(parent) || parent.stat == DEAD)
		return
	if(!COOLDOWN_FINISHED(src, effect_roll_cooldown))
		return

	COOLDOWN_START(src, effect_roll_cooldown, PAIN_EFFECT_ROLL_INTERVAL)

	if(current_bracket.stutters)
		parent.adjust_stutter_up_to(PAIN_EFFECT_ROLL_INTERVAL, PAIN_EFFECT_ROLL_INTERVAL * 2)

	if(current_bracket.vocalise_chance && prob(current_bracket.vocalise_chance))
		parent.emote(felt_pain >= PAIN_BRACKET_SEVERE_THRESHOLD ? "scream" : "whimper")

	if(current_bracket.drop_chance && prob(current_bracket.drop_chance))
		var/obj/item/dropped = parent.get_active_held_item()
		if(dropped && parent.dropItemToGround(dropped))
			parent.visible_message(
				span_warning("[parent] fumbles [dropped] out of [parent.p_their()] hand!"),
				span_warning("Your hand spasms and you drop [dropped]!"),
			)

	if(current_bracket.fall_chance && prob(current_bracket.fall_chance))
		parent.Knockdown(PAIN_EFFECT_ROLL_INTERVAL)
		parent.visible_message(
			span_warning("[parent] buckles!"),
			span_userdanger("Your legs give out."),
		)

/**
 * Puts the mob into, or takes it out of, pain shock.
 *
 * Which shock applies depends on what is holding the mob at the cap. A temporary spike blacks them
 * out briefly; a floor that high leaves nothing to drain, so they crawl until they are treated.
 */
/datum/pain/proc/update_shock()
	if(QDELETED(parent) || parent.stat == DEAD)
		return

	var/in_shock = parent.has_status_effect(/datum/status_effect/incapacitating/pain_shock) || parent.has_status_effect(/datum/status_effect/pain_crawl)

	if(felt_pain < PAIN_SHOCK_THRESHOLD)
		// Down at the cap, up at the recovery threshold. A mob part way between stays down.
		if(in_shock && felt_pain < PAIN_SHOCK_RECOVERY_THRESHOLD)
			parent.remove_status_effect(/datum/status_effect/incapacitating/pain_shock)
			parent.remove_status_effect(/datum/status_effect/pain_crawl)
		// A floor of 70-99 can never drop under the recovery threshold on its own, so the mob rises
		// the moment the temporary pool is gone - straight into the worst bracket, standing barely.
		else if(in_shock && !temporary_pain)
			parent.remove_status_effect(/datum/status_effect/incapacitating/pain_shock)
			parent.remove_status_effect(/datum/status_effect/pain_crawl)
		return

	if(in_shock)
		return

	// A floor at the cap has nothing to drain, so it crawls rather than blacks out.
	if(pain_floor - dampening >= PAIN_SHOCK_THRESHOLD)
		parent.apply_status_effect(/datum/status_effect/pain_crawl)
	else
		parent.apply_status_effect(/datum/status_effect/incapacitating/pain_shock)

/// Fight or flight, once per mob. Massive trauma only.
/datum/pain/proc/try_trigger_adrenaline()
	if(adrenaline_spent || QDELETED(parent) || parent.stat == DEAD)
		return
	// Machines feel everything else, but they do not do fight or flight.
	if(parent.mob_biotypes & MOB_ROBOTIC)
		return

	adrenaline_spent = TRUE
	parent.apply_status_effect(/datum/status_effect/adrenaline)

/// Strips every effect this controller applied. Used on death and teardown.
/datum/pain/proc/clear_effects()
	if(QDELETED(parent))
		return

	if(movespeed_mod)
		parent.remove_movespeed_modifier(movespeed_mod)
		QDEL_NULL(movespeed_mod)
	if(actionspeed_mod)
		parent.remove_actionspeed_modifier(actionspeed_mod)
		QDEL_NULL(actionspeed_mod)
	parent.remove_status_effect(/datum/status_effect/incapacitating/pain_shock)
	parent.remove_status_effect(/datum/status_effect/pain_crawl)

/// Convenience accessor so callers do not have to null-check the controller themselves.
/mob/living/proc/get_felt_pain()
	return 0

/mob/living/carbon/get_felt_pain()
	return pain_controller?.felt_pain || 0

/// How close a bodypart zone is to its own pain cap, 0 to 1, as this mob feels it.
/mob/living/proc/get_zone_pain_ratio(zone)
	return 0

/mob/living/carbon/get_zone_pain_ratio(zone)
	return pain_controller?.get_zone_pain_ratio(zone) || 0

/**
 * Adds temporary pain to a mob, if it can feel any.
 *
 * Arguments:
 * * amount - Temporary pain to add.
 */
/mob/living/proc/add_temporary_pain(amount)
	return

/mob/living/carbon/add_temporary_pain(amount)
	pain_controller?.adjust_temporary_pain(amount)
