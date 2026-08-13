/// Tracks permanent, temporary, and felt pain for a carbon mob.
/datum/pain
	/// The mob this controller belongs to.
	var/mob/living/carbon/parent
	/// Permanent pain per bodypart zone, before that zone's cap is applied.
	var/list/floor_by_zone = list()
	/// Sum of every capped zone floor. Never exceeds PAIN_FLOOR_MAXIMUM.
	var/pain_floor = 0
	/// Pain from impacts and stuns. Decays on its own, fast while high.
	var/temporary_pain = 0
	/// pain_floor plus temporary_pain, clamped to the pain meter. Painkillers do not touch it.
	var/total_pain = 0
	/// total_pain minus dampening. Brackets, shock and recovery all read this.
	var/felt_pain = 0
	/// Felt pain the strongest active painkiller is hiding. Painkillers do not stack.
	var/dampening = 0
	/// Fixed dampening from the strongest painkiller or analgesia trait, before adrenaline halves felt pain.
	var/base_dampening = 0
	/// Set when organ damage changes. Organs tick constantly, so their floor is rebuilt on the next process rather than per hit.
	var/floor_needs_recalculation = FALSE
	/// Set when pain moved while the mob was in no state to take a health refresh. Retried next process.
	var/health_update_deferred = FALSE
	/// Permanent pain that is not an injury, as an assoc list of (source key -> list(zone, amount)).
	/// Surgery without anaesthetic, phantom limbs, anything else that hurts without being a wound.
	var/list/other_sources
	/// How badly the heart is failing to keep up, 0 to 1. Hits hurt more and drain slower the higher it is.
	var/heart_strain = 0
	/// Whether a spike is currently holding the mob blacked out. Cached, as the crit ladder reads it on every updatehealth().
	var/in_shock = FALSE
	/// When the current uninterrupted blackout must end.
	var/blackout_ends_at = 0
	/// Whether the floor alone is currently pinning the mob down. Cached for the same reason.
	var/crawling = FALSE
	/// The bracket felt_pain currently falls into.
	var/datum/pain_bracket/current_bracket
	/// Whether this mob has already spent its adrenaline for this fight.
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
	// The post signal, not COMSIG_CARBON_LOSE_WOUND: that one fires while the wound is still on the
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

/// Drops the reference to the parent mob when it is deleted.
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
		// Shock is an arrest window, never a long-term stun. At the ceiling, drain enough of the pool
		// to satisfy the normal recovery rule; a high floor drains it entirely and leaves a crawler.
		if(in_shock && blackout_ends_at && world.time >= blackout_ends_at)
			adjust_temporary_pain(get_shock_recovery_pool() - temporary_pain)

		// Fast while high, slower as it falls, so a maxed pool drains to the shock recovery threshold
		// in under five seconds.
		var/decay = (PAIN_TEMPORARY_DECAY_FLAT + (temporary_pain * PAIN_TEMPORARY_DECAY_COEFFICIENT)) * seconds_per_tick
		// Heart strain slows lingering pain, but never extends the hard five-second arrest window.
		if(!in_shock)
			decay *= (1 - (heart_strain * PAIN_HEART_DECAY_BRAKE))
		adjust_temporary_pain(-decay)

	// Adrenaline re-arms once the mob has no pain left at all.
	if(adrenaline_spent && !total_pain && !parent.has_status_effect(/datum/status_effect/adrenaline))
		adrenaline_spent = FALSE

	// Deferred refresh from a pain change made while the chest was missing.
	if(health_update_deferred && parent.get_bodypart(BODY_ZONE_CHEST))
		health_update_deferred = FALSE
		parent.updatehealth()

	roll_bracket_effects()

/**
 * The largest temporary pool that still lets the mob come out of a blackout, ending one on time.
 *
 * A blackout ends by draining the pool to wherever felt pain would sit at the recovery threshold,
 * rather than by waiting: the five second ceiling is a hard promise, and the decay curve alone
 * cannot make it against an arbitrary floor. Comes out at zero when the floor alone is high enough
 * to hold the mob under, which is exactly the case that leaves a crawler instead.
 */
/datum/pain/proc/get_shock_recovery_pool()
	// Felt pain is what recovery reads, so the threshold is converted back through everything sitting
	// between the pool and it. A hair under the threshold, so the mob wakes rather than landing on it.
	var/adrenaline_factor = parent.has_status_effect(/datum/status_effect/adrenaline) ? (1 - PAIN_ADRENALINE_DAMPEN_RATIO) : 1
	var/felt_headroom = (PAIN_SHOCK_RECOVERY_THRESHOLD - DAMAGE_PRECISION) / adrenaline_factor

	return clamp(felt_headroom - pain_floor + base_dampening, 0, temporary_pain)

/// Raises the floor as soon as an injury lands, rather than on the next process.
/datum/pain/proc/on_wound_gained(datum/source, datum/wound/new_wound, obj/item/bodypart/limb)
	SIGNAL_HANDLER

	recalculate_floor()
	try_trigger_adrenaline_from_injury(new_wound?.pain_factor)

/// Drops an injury's pain when it is treated. See New() for why this listens to the post signal.
/datum/pain/proc/on_wound_lost(datum/source, datum/wound/lost_wound, obj/item/bodypart/limb)
	SIGNAL_HANDLER

	recalculate_floor()

/// Organ damage, insertion and removal all move the floor.
/datum/pain/proc/on_organs_changed(datum/source, obj/item/organ/changed_organ)
	SIGNAL_HANDLER

	// Deferred for two reasons: every organ damages and heals on its own tick, so this fires constantly
	// and once per second is frequent enough; and organs are pulled in bulk during a species change,
	// where rebuilding the floor from a half-assembled body runtimes.
	mark_dirty()

/// Rebuilds the floor immediately on a full heal, since it takes every injury with it.
/datum/pain/proc/on_fully_healed(datum/source, heal_flags)
	SIGNAL_HANDLER

	adrenaline_spent = FALSE
	recalculate_floor()

/// Stops processing on death, and reapplies everything the controller had applied on revival.
/datum/pain/proc/on_stat_changed(datum/source, new_stat, old_stat)
	SIGNAL_HANDLER

	if(old_stat == DEAD && new_stat != DEAD)
		START_PROCESSING(SSpain, src)
		// Death stripped every effect this controller applied and nothing else puts them back.
		// Clearing the bracket forces them to reapply even if the band has not changed.
		current_bracket = null
		update_pain()
	else if(old_stat != DEAD && new_stat == DEAD)
		STOP_PROCESSING(SSpain, src)
		clear_effects()
	else
		return

	parent.update_pain_hud()

/// Rebuilds permanent pain from wounds, organs, and other registered sources.
/datum/pain/proc/recalculate_floor()
	if(QDELETED(parent))
		return

	floor_needs_recalculation = FALSE
	floor_by_zone.Cut()

	for(var/obj/item/bodypart/part as anything in parent.bodyparts)
		for(var/datum/wound/injury as anything in part.wounds)
			// Not the raw factor: a wrapped or splinted injury counts a tier lower.
			floor_by_zone[part.body_zone] += injury.get_pain_factor()

	for(var/obj/item/organ/inner_organ as anything in parent.organs)
		if(!inner_organ.pain_factor || !inner_organ.damage || !inner_organ.maxHealth)
			continue
		var/damage_ratio = min(inner_organ.damage / inner_organ.maxHealth, 1)
		// Eyes and tongues sit in precise zones. They count against the head's cap rather than one of their own.
		floor_by_zone[deprecise_zone(inner_organ.zone)] += inner_organ.pain_factor * damage_ratio

	// Non-injury sources: unanaesthetised surgery, phantom limbs.
	for(var/source_key in other_sources)
		var/list/source = other_sources[source_key]
		floor_by_zone[source[PAIN_SOURCE_ZONE]] += source[PAIN_SOURCE_AMOUNT]

	var/new_floor = 0
	for(var/zone in floor_by_zone)
		new_floor += min(floor_by_zone[zone], get_zone_cap(zone))

	pain_floor = min(round(new_floor, DAMAGE_PRECISION), PAIN_FLOOR_MAXIMUM)
	update_pain()

/// Flags the floor for a rebuild on the next process, for changes too frequent to answer one by one.
/datum/pain/proc/mark_dirty()
	floor_needs_recalculation = TRUE

/// Recomputes heart strain. A failing heart makes hits land harder and decay slower.
/datum/pain/proc/update_heart_strain()
	var/obj/item/organ/heart/our_heart = parent.get_organ_slot(ORGAN_SLOT_HEART)
	if(isnull(our_heart) || !our_heart.maxHealth)
		heart_strain = 0
		return

	heart_strain = clamp(our_heart.damage / our_heart.maxHealth, 0, 1)
	// A stopped heart is full strain regardless of its damage.
	if(!our_heart.is_beating())
		heart_strain = 1

/**
 * Registers permanent pain that is not an injury.
 *
 * Covers what hurts without being a wound or a damaged organ: unanaesthetised surgery, phantom
 * limbs. Sources are keyed so a caller can remove its own without knowing about the others.
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

/// Drops expired non-injury pain sources. Returns TRUE if any were removed.
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
 * Reads felt rather than total pain, so painkillers blind the mob's own readouts.
 *
 * Arguments:
 * * zone - One of the BODY_ZONE_* defines.
 */
/datum/pain/proc/get_zone_pain_ratio(zone)
	var/zone_cap = get_zone_cap(zone)
	if(!zone_cap)
		return 0

	var/zone_pain = min(floor_by_zone[zone] || 0, zone_cap)
	// The doll draws the floor, so it is blinded by how much of the floor a painkiller hides. Scaling
	// against the total instead would let the temporary pool darken every zone at once.
	if(pain_floor > 0)
		zone_pain *= get_felt_floor() / pain_floor

	return clamp(zone_pain / zone_cap, 0, 1)

/// The permanent floor as the mob feels it after medication and fight-or-flight.
/datum/pain/proc/get_felt_floor(adrenaline_override)
	var/felt_floor = base_dampening >= PAIN_DAMPEN_TOTAL ? 0 : max(pain_floor - base_dampening, 0)
	var/adrenaline_active = isnull(adrenaline_override) ? !!parent.has_status_effect(/datum/status_effect/adrenaline) : adrenaline_override
	if(adrenaline_active)
		felt_floor *= (1 - PAIN_ADRENALINE_DAMPEN_RATIO)
	return felt_floor

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

	// A struggling heart makes hits land harder. Draining is slowed separately, in process().
	if(amount > 0 && heart_strain)
		amount *= (1 + (heart_strain * PAIN_HEART_STRAIN_MULTIPLIER))

	// Asked of the whole hit, before the pool clamps it. A spike big enough for fight or flight is
	// still that big when it lands on a mob that was already at the ceiling.
	if(amount >= PAIN_ADRENALINE_SPIKE_TRIGGER)
		try_trigger_adrenaline()

	var/new_temporary = clamp(temporary_pain + amount, 0, PAIN_TEMPORARY_MAXIMUM)
	if(new_temporary == temporary_pain)
		return

	temporary_pain = new_temporary
	update_pain()
	// Repeated hits can juggle a target, but each one demands fresh commitment and buys at most the
	// same five-second window.
	if(amount > 0 && in_shock)
		blackout_ends_at = world.time + PAIN_SHOCK_MAXIMUM_DURATION

/**
 * Recomputes how much pain the brain is currently allowed to ignore.
 *
 * Runs every tick for every carbon, so it walks the reagents, status effects and mutations exactly
 * once. That single pass collects both the strongest graded dampener and the trait source each
 * graded thing would be holding TRAIT_ANALGESIA under, which is what tells an ungraded analgesic
 * apart from one already counted. Only a mob actually carrying the trait pays for that second part.
 */
/datum/pain/proc/update_dampening()
	if(QDELETED(parent))
		return

	// Cocktails, augmented hearts and gene mods grant TRAIT_ANALGESIA too. Anything holding it without
	// a value here reads as total numbness.
	var/tracking_analgesia = HAS_TRAIT(parent, TRAIT_ANALGESIA)
	var/list/graded_sources = tracking_analgesia ? list() : null

	var/strongest = 0
	for(var/datum/reagent/held_reagent as anything in parent.reagents?.reagent_list)
		if(!held_reagent.pain_dampening)
			continue
		if(tracking_analgesia)
			graded_sources += METABOLIZATION_TRAIT(held_reagent.type)
		// A surgical anaesthetic does nothing below a full dose. Zero for a normal painkiller, which
		// works from the first unit.
		if(held_reagent.volume < held_reagent.pain_dampening_minimum_volume)
			continue
		// A drug only numbs a biotype it works on: morphine does nothing for a synthetic.
		if(!(parent.mob_biotypes & held_reagent.affected_biotype))
			continue
		strongest = max(strongest, held_reagent.pain_dampening)

	for(var/datum/status_effect/effect as anything in parent.status_effects)
		if(!effect.pain_dampening)
			continue
		if(tracking_analgesia)
			graded_sources += TRAIT_STATUS_EFFECT(effect.id)
		strongest = max(strongest, effect.pain_dampening)

	for(var/datum/mutation/mutation as anything in parent.dna?.mutations)
		if(!mutation.pain_dampening)
			continue
		// Every mutation shares one trait source, so one graded mutation covers all of them.
		if(tracking_analgesia)
			graded_sources |= GENETIC_MUTATION
		strongest = max(strongest, mutation.pain_dampening)

	var/datum/status_effect/inebriated/inebriation = parent.has_status_effect(/datum/status_effect/inebriated)
	if(inebriation?.drunk_value >= PAIN_DAMPEN_DRUNK_REQUIREMENT)
		strongest = max(strongest, PAIN_DAMPEN_ALCOHOL)

	if(tracking_analgesia && has_ungraded_analgesia(graded_sources))
		strongest = max(strongest, PAIN_DAMPEN_STRONG)

	if(base_dampening == strongest)
		return

	base_dampening = strongest
	update_pain()

/**
 * Whether something is granting analgesia that carries no dampening value of its own.
 *
 * Arguments:
 * * graded_sources - Trait sources already accounted for by a graded dampener, gathered by the
 * caller's single pass over the mob.
 */
/datum/pain/proc/has_ungraded_analgesia(list/graded_sources)
	for(var/source in GET_TRAIT_SOURCES(parent, TRAIT_ANALGESIA))
		if(!(source in graded_sources))
			return TRUE

	return FALSE

/// Recomputes the totals, the bracket and the shock state. Everything that changes pain ends up here.
/datum/pain/proc/update_pain(adrenaline_override)
	var/old_felt_pain = felt_pain

	// The temporary reservoir may exceed the meter so a blackout can drain without erasing the whole
	// spike, but PAIN and FELT are both 0-100 values as presented to every gameplay gate.
	total_pain = min(pain_floor + temporary_pain, PAIN_MAXIMUM)
	var/unclamped_felt = base_dampening >= PAIN_DAMPEN_TOTAL ? 0 : max(total_pain - base_dampening, 0)
	// Fight or flight halves whatever the mob would otherwise feel, including pain gained after the
	// trigger and pain left visible through medication.
	var/adrenaline_active = isnull(adrenaline_override) ? !!parent.has_status_effect(/datum/status_effect/adrenaline) : adrenaline_override
	if(adrenaline_active)
		unclamped_felt *= (1 - PAIN_ADRENALINE_DAMPEN_RATIO)
	dampening = total_pain - unclamped_felt
	felt_pain = clamp(unclamped_felt, 0, PAIN_MAXIMUM)
	update_bracket()
	update_shock(adrenaline_override)

	// The doll, the meter and the damage slowdown all read pain, so a change needs the same refresh
	// taking damage does. Not while the chest is off: updatehealth() reads it without a null check,
	// and losing a limb moves pain.
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

/// Rolls the current bracket's intermittent effects.
/datum/pain/proc/roll_bracket_effects()
	if(isnull(current_bracket) || QDELETED(parent) || parent.stat == DEAD)
		return
	if(!COOLDOWN_FINISHED(src, effect_roll_cooldown))
		return

	COOLDOWN_START(src, effect_roll_cooldown, PAIN_EFFECT_ROLL_INTERVAL)

	// Synthetics run the same brackets and chances with different flavour: speaker distortion and
	// servo tremors in place of stuttering and shaking.
	var/is_synthetic = (parent.mob_biotypes & MOB_ROBOTIC)

	if(current_bracket.stutter_chance && prob(current_bracket.stutter_chance))
		parent.adjust_stutter_up_to(PAIN_EFFECT_ROLL_INTERVAL, PAIN_EFFECT_ROLL_INTERVAL * 2)
		if(is_synthetic)
			parent.adjust_slurring_up_to(PAIN_EFFECT_ROLL_INTERVAL, PAIN_EFFECT_ROLL_INTERVAL * 2)

	if(current_bracket.shake_chance && prob(current_bracket.shake_chance))
		parent.adjust_jitter_up_to(PAIN_EFFECT_ROLL_INTERVAL, PAIN_EFFECT_ROLL_INTERVAL * 2)

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

	if(current_bracket.passout_chance && prob(current_bracket.passout_chance))
		parent.Unconscious(PAIN_EFFECT_ROLL_INTERVAL, ignore_canstun = TRUE)
		parent.visible_message(
			span_warning("[parent] passes out from the pain!"),
			span_userdanger("The pain swallows everything for a moment."),
		)

/**
 * Puts the mob into, or takes it out of, pain shock.
 *
 * Which shock applies depends on what is holding the mob at the cap. A temporary spike blacks them
 * out briefly; a floor that high has nothing to drain, so they crawl until they are treated.
 */
/datum/pain/proc/update_shock(adrenaline_override)
	if(QDELETED(parent) || parent.stat == DEAD)
		return

	var/was_blacked_out = in_shock
	var/was_crawling = crawling

	// A floor at the cap has nothing to drain, so only treatment or a painkiller lifts it.
	var/should_crawl = get_felt_floor(adrenaline_override) >= PAIN_SHOCK_THRESHOLD

	var/should_black_out = FALSE
	if(felt_pain >= PAIN_SHOCK_THRESHOLD)
		// Anything at the cap that is not purely the floor blacks out, including a fresh hit on
		// someone already crawling.
		should_black_out = !should_crawl || temporary_pain > 0
	else if(was_blacked_out)
		// Down at the cap, up at the recovery threshold. A floor of 70-99 never reaches that
		// threshold, so it rises once its pool is gone instead.
		should_black_out = (felt_pain >= PAIN_SHOCK_RECOVERY_THRESHOLD) && temporary_pain > 0

	// Written before the early return, so a shock stripped elsewhere (a full heal, an admin) is
	// reconciled on the next pain change.
	in_shock = should_black_out
	crawling = should_crawl

	if(should_black_out == was_blacked_out && should_crawl == was_crawling)
		return

	if(should_black_out != was_blacked_out)
		if(should_black_out)
			blackout_ends_at = world.time + PAIN_SHOCK_MAXIMUM_DURATION
			parent.apply_status_effect(/datum/status_effect/incapacitating/pain_shock)
		else
			blackout_ends_at = 0
			parent.remove_status_effect(/datum/status_effect/incapacitating/pain_shock)

	if(should_crawl != was_crawling)
		if(should_crawl)
			parent.apply_status_effect(/datum/status_effect/pain_crawl)
		else
			parent.remove_status_effect(/datum/status_effect/pain_crawl)

	// Shock is a rung on the crit ladder.
	parent.update_stat()
	// The crawl keeps its hands where other soft crits do not, and set_stat only recomputes that on a
	// change of rung, so a mob already soft critting for another reason needs a resync.
	if(should_crawl != was_crawling)
		parent.update_stat_traits()

/**
 * Triggers adrenaline if an injury this painful is enough to cause it.
 *
 * The single place an injury's worth is judged. How much a wound hurts and which severity tier it
 * reads as are separate numbers that routinely disagree - an Open Laceration is Severe and worth a
 * Moderate factor - so the pain factor decides and the tier never does.
 *
 * Arguments:
 * * injury_pain_factor - The permanent pain the injury is worth.
 */
/datum/pain/proc/try_trigger_adrenaline_from_injury(injury_pain_factor)
	if(injury_pain_factor < PAIN_ADRENALINE_INJURY_TRIGGER)
		return

	try_trigger_adrenaline()

/// Triggers adrenaline, once per fight, on massive trauma only.
/datum/pain/proc/try_trigger_adrenaline()
	if(adrenaline_spent || QDELETED(parent) || parent.stat == DEAD)
		return
	// Synthetics get no adrenaline.
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
	blackout_ends_at = 0
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
 * For anything that changes how much an injury hurts without adding or removing one, such as a wrap
 * going on or coming off. Deferred because those arrive one per wound on the limb, and a treated
 * limb is worth one rebuild.
 */
/mob/living/carbon/proc/mark_pain_dirty()
	pain_controller?.mark_dirty()

/// Triggers fight-or-flight from an injury too painful to shrug off. See [/datum/pain/proc/try_trigger_adrenaline_from_injury].
/mob/living/proc/try_pain_adrenaline(injury_pain_factor)
	return

/mob/living/carbon/try_pain_adrenaline(injury_pain_factor)
	pain_controller?.try_trigger_adrenaline_from_injury(injury_pain_factor)

/// Felt pain, or zero for a mob with no pain controller.
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
