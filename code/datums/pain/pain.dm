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
	/// Set when organ damage moves. Organs tick constantly, so their floor is rebuilt on the next process instead of per hit.
	var/floor_needs_recalculation = FALSE
	/// Set when pain moved while the mob was in no state to take a health refresh. Retried next process.
	var/health_update_deferred = FALSE
	/// Permanent pain that is not an injury, as an assoc list of (source key -> list(zone, amount)).
	/// Surgery without anaesthetic, phantom limbs, anything else that hurts without being a wound.
	var/list/other_sources
	/// How badly the heart is failing to keep up, 0 to 1. Hits hurt more and drain slower the higher it is.
	var/heart_strain = 0
	/// Whether a spike is currently holding the mob blacked out. Cached because the crit ladder reads
	/// it on every updatehealth(), and scanning the status effect list that often is not free.
	var/in_shock = FALSE
	/// Whether the floor alone is currently pinning the mob down. Cached for the same reason.
	var/crawling = FALSE
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

	RegisterSignal(parent, COMSIG_CARBON_GAIN_WOUND, PROC_REF(on_wound_gained))
	// Deliberately the post signal. COMSIG_CARBON_LOSE_WOUND fires while the wound is still on the
	// limb, so a floor rebuilt from it would count the injury that was just treated.
	RegisterSignal(parent, COMSIG_CARBON_POST_LOSE_WOUND, PROC_REF(on_wound_lost))
	RegisterSignal(parent, COMSIG_CARBON_ORGAN_DAMAGED, PROC_REF(on_organs_changed))
	RegisterSignal(parent, COMSIG_CARBON_GAIN_ORGAN, PROC_REF(on_organs_changed))
	RegisterSignal(parent, COMSIG_CARBON_LOSE_ORGAN, PROC_REF(on_organs_changed))
	RegisterSignal(parent, COMSIG_MOB_STATCHANGE, PROC_REF(on_stat_changed))
	RegisterSignal(parent, COMSIG_LIVING_POST_FULLY_HEAL, PROC_REF(on_fully_healed))
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
		COMSIG_CARBON_POST_LOSE_WOUND,
		COMSIG_CARBON_ORGAN_DAMAGED,
		COMSIG_CARBON_GAIN_ORGAN,
		COMSIG_CARBON_LOSE_ORGAN,
		COMSIG_MOB_STATCHANGE,
		COMSIG_LIVING_POST_FULLY_HEAL,
		COMSIG_QDELETING,
	))
	parent = null

/datum/pain/process(seconds_per_tick)
	if(QDELETED(parent))
		return

	update_dampening()
	// Checked every tick rather than off organ damage, because a heart can stop without being hurt.
	update_heart_strain()

	if(expire_pain_sources() || floor_needs_recalculation)
		recalculate_floor()

	if(temporary_pain > 0)
		// Fast while high and slower as it falls, so a maxed pool drains to the shock recovery
		// threshold in under five seconds but the last of it lingers.
		var/decay = (PAIN_TEMPORARY_DECAY_FLAT + (temporary_pain * PAIN_TEMPORARY_DECAY_COEFFICIENT)) * seconds_per_tick
		// A heart that cannot circulate cannot clear it either.
		decay *= (1 - (heart_strain * PAIN_HEART_DECAY_BRAKE))
		adjust_temporary_pain(-decay)

	// Adrenaline is once per fight, and a mob with nothing left to feel is out of the fight.
	if(adrenaline_spent && !total_pain && !parent.has_status_effect(/datum/status_effect/adrenaline))
		adrenaline_spent = FALSE

	// Pain that moved while the body was coming apart never got its refresh. Take it now.
	if(health_update_deferred && parent.get_bodypart(BODY_ZONE_CHEST))
		health_update_deferred = FALSE
		parent.updatehealth()

	roll_bracket_effects()

/// A new injury raises the floor, and waiting a tick to feel a broken arm is the delay this system exists to remove.
/datum/pain/proc/on_wound_gained(datum/source, datum/wound/new_wound, obj/item/bodypart/limb)
	SIGNAL_HANDLER

	recalculate_floor()
	// Massive trauma is what triggers fight or flight. Being rid of an injury is not trauma.
	if(new_wound?.pain_factor >= PAIN_ADRENALINE_INJURY_TRIGGER)
		try_trigger_adrenaline()

/// Treating an injury has to take its pain with it. See New() for why this listens to the post signal.
/datum/pain/proc/on_wound_lost(datum/source, datum/wound/lost_wound, obj/item/bodypart/limb)
	SIGNAL_HANDLER

	recalculate_floor()

/// Organ damage, insertion and removal all move the floor.
/datum/pain/proc/on_organs_changed(datum/source, obj/item/organ/changed_organ)
	SIGNAL_HANDLER

	// Deferred rather than immediate for two reasons. Every organ damages and heals itself on its own
	// tick, so this fires constantly and organ pain climbs slowly enough that once per second is soon
	// enough; and organs are pulled in bulk during a species change, where rebuilding the floor from a
	// half-assembled body is how you get a runtime.
	floor_needs_recalculation = TRUE

/// A full heal takes the injuries with it, so the floor is rebuilt on the spot rather than a tick later.
/datum/pain/proc/on_fully_healed(datum/source, heal_flags)
	SIGNAL_HANDLER

	adrenaline_spent = FALSE
	recalculate_floor()

/// Corpses feel nothing, so stop burning cycles on them until they are back up.
/datum/pain/proc/on_stat_changed(datum/source, new_stat, old_stat)
	SIGNAL_HANDLER

	if(old_stat == DEAD && new_stat != DEAD)
		START_PROCESSING(SSpain, src)
		// Death stripped everything this controller had applied and nothing else puts it back, so a
		// mob that comes back still carrying its injuries has to be returned to the state it left in.
		// Clearing the bracket is what forces its effects to reapply even if the band has not changed.
		current_bracket = null
		update_pain()
	else if(old_stat != DEAD && new_stat == DEAD)
		STOP_PROCESSING(SSpain, src)
		clear_effects()
	else
		return

	parent.update_pain_hud()

/**
 * Rebuilds the permanent floor from every wound and damaged organ the mob is carrying.
 *
 * Each zone is capped on its own before the total is summed, so no single bodypart can put someone
 * into shock. Combinations still can.
 */
/datum/pain/proc/recalculate_floor()
	if(QDELETED(parent))
		return

	floor_needs_recalculation = FALSE
	floor_by_zone.Cut()

	for(var/obj/item/bodypart/part as anything in parent.bodyparts)
		for(var/datum/wound/injury as anything in part.wounds)
			// Not the injury's raw factor: a wrapped or splinted one hurts a tier less than it should.
			floor_by_zone[part.body_zone] += injury.get_pain_factor()

	for(var/obj/item/organ/inner_organ as anything in parent.organs)
		if(!inner_organ.pain_factor || !inner_organ.damage || !inner_organ.maxHealth)
			continue
		// A lightly bruised organ should not hurt as much as a failing one.
		var/damage_ratio = min(inner_organ.damage / inner_organ.maxHealth, 1)
		// Eyes and tongues live in precise zones. They hurt the head they sit in, not a zone of
		// their own, or the head's cap would not be the head's cap.
		floor_by_zone[deprecise_zone(inner_organ.zone)] += inner_organ.pain_factor * damage_ratio

	// Everything that hurts without being an injury: an unnumbed surgery, a limb that is not there.
	for(var/source_key in other_sources)
		var/list/source = other_sources[source_key]
		floor_by_zone[source[PAIN_SOURCE_ZONE]] += source[PAIN_SOURCE_AMOUNT]

	var/new_floor = 0
	for(var/zone in floor_by_zone)
		new_floor += min(floor_by_zone[zone], get_zone_cap(zone))

	pain_floor = min(round(new_floor, DAMAGE_PRECISION), PAIN_FLOOR_MAXIMUM)
	update_pain()

/// Works out how far behind the heart is. A failing one makes every hit land harder and hold longer.
/datum/pain/proc/update_heart_strain()
	var/obj/item/organ/heart/our_heart = parent.get_organ_slot(ORGAN_SLOT_HEART)
	if(isnull(our_heart) || !our_heart.maxHealth)
		heart_strain = 0
		return

	heart_strain = clamp(our_heart.damage / our_heart.maxHealth, 0, 1)
	// A heart that has stopped is not partly behind, it is entirely behind.
	if(!our_heart.is_beating())
		heart_strain = 1

/**
 * Registers permanent pain that is not an injury.
 *
 * The floor is mostly wounds and ruined organs, but not everything that hurts is either: being cut
 * open while awake, or a limb that is not there and aches anyway. Sources are keyed so a caller can
 * take its own back off again without knowing about the others.
 *
 * Arguments:
 * * source_key - Unique string for the source, used to remove it again.
 * * amount - Permanent pain to add.
 * * zone - Which bodypart zone it is felt in. Capped with everything else in that zone.
 * * duration - How long it lasts. Zero means until someone takes it off again.
 */
/datum/pain/proc/add_pain_source(source_key, amount, zone = BODY_ZONE_CHEST, duration = 0)
	LAZYINITLIST(other_sources)
	other_sources[source_key] = list(deprecise_zone(zone), amount, duration ? world.time + duration : 0)
	recalculate_floor()

/**
 * Removes a registered non-injury pain source.
 *
 * Arguments:
 * * source_key - The key the source was added under.
 */
/datum/pain/proc/remove_pain_source(source_key)
	if(!LAZYACCESS(other_sources, source_key))
		return

	LAZYREMOVE(other_sources, source_key)
	recalculate_floor()

/// Drops any non-injury pain the mob has had long enough to stop feeling. Returns TRUE if anything went.
/datum/pain/proc/expire_pain_sources()
	var/list/expired
	for(var/source_key in other_sources)
		var/list/source = other_sources[source_key]
		if(source[PAIN_SOURCE_EXPIRY] && source[PAIN_SOURCE_EXPIRY] <= world.time)
			LAZYADD(expired, source_key)

	if(!length(expired))
		return FALSE

	other_sources -= expired
	return TRUE

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

	// A struggling heart makes everything land harder. Draining is slowed separately, in process().
	if(amount > 0 && heart_strain)
		amount *= (1 + (heart_strain * PAIN_HEART_STRAIN_MULTIPLIER))

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
	for(var/datum/reagent/held_reagent as anything in parent.reagents?.reagent_list)
		strongest = max(strongest, held_reagent.pain_dampening)

	// Not everything that numbs you is a chemical. Cocktails, augmented hearts and gene mods all hand
	// out TRAIT_ANALGESIA, and anything holding it without a value here is read as complete numbness.
	for(var/datum/status_effect/effect as anything in parent.status_effects)
		strongest = max(strongest, effect.pain_dampening)

	for(var/datum/mutation/mutation as anything in parent.dna?.mutations)
		strongest = max(strongest, mutation.pain_dampening)

	// Being extremely drunk numbs you too, with all the drawbacks of being extremely drunk.
	var/datum/status_effect/inebriated/inebriation = parent.has_status_effect(/datum/status_effect/inebriated)
	if(inebriation?.drunk_value >= PAIN_DAMPEN_DRUNK_REQUIREMENT)
		strongest = max(strongest, PAIN_DAMPEN_ALCOHOL)

	// Nothing numbs like not being able to feel at all.
	if(has_total_analgesia())
		strongest = PAIN_DAMPEN_TOTAL

	// Adrenaline is not a painkiller, it just hides half of whatever is left on top of one.
	if(parent.has_status_effect(/datum/status_effect/adrenaline))
		strongest = max(strongest, total_pain * PAIN_ADRENALINE_DAMPEN_RATIO)

	if(dampening == strongest)
		return

	dampening = strongest
	update_pain()

/**
 * Whether something with no dampening value of its own has numbed this mob completely.
 *
 * Painkillers grant TRAIT_ANALGESIA as well, but they carry their own value and are never total -
 * morphine is forty points, not immunity. So do the handful of cocktails, implants and gene mods that
 * grant it. Anything else holding the trait (the numb quirk, stasis, a trauma, admin chems) means the
 * mob genuinely cannot feel anything, which is the deliberate half of D3.
 */
/datum/pain/proc/has_total_analgesia()
	if(!HAS_TRAIT(parent, TRAIT_ANALGESIA))
		return FALSE

	var/list/graded_sources = list()
	for(var/datum/reagent/held_reagent as anything in parent.reagents?.reagent_list)
		if(held_reagent.pain_dampening)
			graded_sources += METABOLIZATION_TRAIT(held_reagent.type)

	for(var/datum/status_effect/effect as anything in parent.status_effects)
		if(effect.pain_dampening)
			graded_sources += TRAIT_STATUS_EFFECT(effect.id)

	// Every mutation shares one trait source, so one graded mutation vouches for the lot. Nothing in
	// the game hands out a graded one and hulk at the same time.
	for(var/datum/mutation/mutation as anything in parent.dna?.mutations)
		if(mutation.pain_dampening)
			graded_sources += GENETIC_MUTATION
			break

	for(var/source in GET_TRAIT_SOURCES(parent, TRAIT_ANALGESIA))
		if(!(source in graded_sources))
			return TRUE

	return FALSE

/// Recomputes the totals and the bracket. Everything that changes pain ends up here.
/datum/pain/proc/update_pain()
	var/old_felt_pain = felt_pain

	total_pain = min(pain_floor + temporary_pain, PAIN_MAXIMUM)
	felt_pain = clamp(total_pain - dampening, 0, PAIN_MAXIMUM)
	update_bracket()
	update_shock()

	// The doll, the meter and the damage slowdown all read pain now, so pain moving has to run the
	// same refresh that taking damage does rather than only redrawing. Not mid-limb-surgery though:
	// updatehealth() reads the chest without checking for one, and losing a limb moves pain.
	if(felt_pain != old_felt_pain)
		if(parent.get_bodypart(BODY_ZONE_CHEST))
			parent.updatehealth()
		else
			health_update_deferred = TRUE

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

/// Syncs the movement penalty, task speed penalty and moodlet to the current bracket.
/datum/pain/proc/apply_bracket_effects()
	if(QDELETED(parent) || isnull(current_bracket))
		return

	if(current_bracket.mood_event)
		parent.add_mood_event(PAIN_MOOD_CATEGORY, current_bracket.mood_event)
	else
		parent.clear_mood_event(PAIN_MOOD_CATEGORY)

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

	var/was_blacked_out = in_shock
	var/was_crawling = crawling

	// A floor at the cap has nothing left to drain, so it crawls. Only treatment or a painkiller
	// lifts that; waiting it out is not on the table.
	var/should_crawl = (pain_floor - dampening) >= PAIN_SHOCK_THRESHOLD

	var/should_black_out = FALSE
	if(felt_pain >= PAIN_SHOCK_THRESHOLD)
		// Anything at the cap that is not purely the floor is a blackout - including a fresh hit on
		// someone already crawling, which is what puts a crawler back down mid-drag.
		should_black_out = !should_crawl || (temporary_pain >= PAIN_SHOCK_BLACKOUT_MINIMUM)
	else if(was_blacked_out)
		// Down at the cap, up at the recovery threshold, so nobody yo-yos on the line. A floor of
		// 70-99 can never reach that threshold, so it rises the moment its pool is gone instead.
		should_black_out = (felt_pain >= PAIN_SHOCK_RECOVERY_THRESHOLD) && temporary_pain > 0

	// Written before the early return, so anything that strips a shock behind our back - a full heal,
	// an admin - is reconciled on the next pain change rather than leaving the ladder lying.
	in_shock = should_black_out
	crawling = should_crawl

	if(should_black_out == was_blacked_out && should_crawl == was_crawling)
		return

	if(should_black_out != was_blacked_out)
		if(should_black_out)
			parent.apply_status_effect(/datum/status_effect/incapacitating/pain_shock)
		else
			parent.remove_status_effect(/datum/status_effect/incapacitating/pain_shock)

	if(should_crawl != was_crawling)
		if(should_crawl)
			parent.apply_status_effect(/datum/status_effect/pain_crawl)
		else
			parent.remove_status_effect(/datum/status_effect/pain_crawl)

	// Shock is a rung on the crit ladder now, so moving between these is a change of consciousness.
	parent.update_stat()
	// The crawl keeps its hands where every other soft crit does not, and set_stat only recomputes
	// that on a change of rung - so a mob already soft critting for another reason needs a resync.
	if(should_crawl != was_crawling)
		parent.update_stat_traits()

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
	parent.clear_mood_event(PAIN_MOOD_CATEGORY)
	in_shock = FALSE
	crawling = FALSE
	parent.remove_status_effect(/datum/status_effect/incapacitating/pain_shock)
	parent.remove_status_effect(/datum/status_effect/pain_crawl)

/// Registers permanent pain from something that is not an injury. See [/datum/pain/proc/add_pain_source].
/mob/living/proc/add_pain_source(source_key, amount, zone = BODY_ZONE_CHEST, duration = 0)
	return

/mob/living/carbon/add_pain_source(source_key, amount, zone = BODY_ZONE_CHEST, duration = 0)
	pain_controller?.add_pain_source(source_key, amount, zone, duration)

/// Takes a registered non-injury pain source back off. See [/datum/pain/proc/remove_pain_source].
/mob/living/proc/remove_pain_source(source_key)
	return

/mob/living/carbon/remove_pain_source(source_key)
	pain_controller?.remove_pain_source(source_key)

/**
 * Marks this mob's permanent floor as out of date, to be rebuilt on the next process.
 *
 * For the things that change how much an injury hurts without adding or removing one - a wrap going
 * on or coming off. Deferred rather than immediate because those arrive one per wound on the limb,
 * and a treated limb is worth exactly one rebuild.
 */
/mob/living/carbon/proc/mark_pain_dirty()
	if(pain_controller)
		pain_controller.floor_needs_recalculation = TRUE

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
