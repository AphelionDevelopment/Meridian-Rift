/**
 * What it takes to kill a person, and what it takes to knock one down.
 *
 * Damage totals decide neither any more. A person is alive while their brain is alive, their heart is
 * beating and there is blood in them to circulate, so everything that used to kill through the health
 * bar now kills by ruining one of those three. Humans only: xenos carry no heart and keep the health
 * ladder on /mob/living/carbon.
 */

/mob/living/carbon/human/update_stat_from_condition()
	// Death is handled by the brain, the blood and the heart, each where it lives, so this decides
	// consciousness only. It runs on every updatehealth(), so the pain rungs come off the controller's
	// cached state rather than a scan of the status effect list.
	var/datum/pain/pain = pain_controller
	if((pain?.in_shock || circulation_stopped()) && !HAS_TRAIT(src, TRAIT_NOHARDCRIT))
		set_stat(HARD_CRIT)
		return FALSE

	if((pain?.crawling || is_bled_out()) && !HAS_TRAIT(src, TRAIT_NOSOFTCRIT))
		set_stat(SOFT_CRIT)
		return FALSE

	set_stat(STABLE)
	return FALSE

/**
 * Whether this mob has lost enough blood to be going under from it.
 *
 * get_blood_volume() walks the reagent list when asked for modifiers, which is too much work for
 * something the crit ladder asks on every updatehealth(). Modifiers only ever multiply and saline
 * only ever adds, so a mob above the threshold with neither cannot be under it.
 */
/mob/living/carbon/proc/is_bled_out()
	if(!CAN_HAVE_BLOOD(src))
		return FALSE
	if(blood_volume >= BLOOD_VOLUME_BAD && !length(blood_volume_modifiers))
		return FALSE
	return get_blood_volume(apply_modifiers = TRUE) < BLOOD_VOLUME_BAD

/**
 * Whether this body has anything moving oxygen around it any more.
 *
 * Not [/mob/living/carbon/proc/undergoing_cardiac_arrest], which only answers whether the organic
 * heart attack mechanic is running. That proc is FALSE for a robotic heart and for anything carrying
 * TRAIT_STABLEHEART, so reading arrest alone leaves an augmented chest unkillable: the cybernetic
 * heart sits at ORGAN_FAILING and reports itself beating forever.
 */
/mob/living/carbon/human/proc/circulation_stopped()
	if(undergoing_cardiac_arrest())
		return TRUE

	var/obj/item/organ/heart/our_heart = get_organ_slot(ORGAN_SLOT_HEART)
	// Nothing in the chest to have stopped; a body that needs a heart and has none is already in arrest.
	if(isnull(our_heart))
		return FALSE

	return !our_heart.is_beating() || (our_heart.organ_flags & ORGAN_FAILING)

/mob/living/carbon/human/can_recover_breath()
	// Circulation only. Not the crit rung, since a batoned target is unconscious with working lungs,
	// and not the oxyloss threshold is_dying() reads, or one lungful of vacuum would put a mob past
	// the point of breathing it back off.
	return !circulation_stopped() && !is_bled_out()

/mob/living/carbon/human/is_damaged_beyond_revival()
	// Not on damage alone. Brute and burn no longer kill and nothing caps their totals short of the
	// bodyparts' own limits, so an ordinary combat corpse sits far under the old revival floor and that
	// check would make most kills permanent.
	//
	// A dead brain does stand in the way, since it is the thing that killed them: reviving through one
	// hands back a body the next Life() kills again, and for anything immune to the slower routes -
	// synthetics take no oxygen or toxin damage - the loop never resolves. The brain has to be repaired
	// first, which is the same answer can_defib() gives.
	var/obj/item/organ/our_brain = get_organ_slot(ORGAN_SLOT_BRAIN)
	return !isnull(our_brain) && (our_brain.organ_flags & ORGAN_FAILING)

/mob/living/carbon/human/is_dying()
	// Pain is excluded: succumb reads this, and a stun must not be the same as a kill.
	if(circulation_stopped())
		return TRUE
	if(get_oxy_loss() >= OXYLOSS_BRAIN_DAMAGE_THRESHOLD)
		return TRUE
	if(get_tox_loss() >= TOXLOSS_BRAIN_DAMAGE_THRESHOLD)
		return TRUE
	return is_bled_out()

/**
 * How much margin this body has left, read off the three things that keep it alive.
 *
 * Damage totals no longer answer this: a maxed chest with a working heart is in no danger, and full
 * health with a stopped heart is dying. Returns the worst of the three, since triage wants the thing
 * about to kill the patient rather than an average.
 *
 * Ignores pain, so a painkilled patient still reads as critical, and brute and burn, which the
 * analyser lists in full underneath.
 */
/mob/living/carbon/human/get_vitals_ratio()
	var/obj/item/organ/our_brain = get_organ_slot(ORGAN_SLOT_BRAIN)
	if(isnull(our_brain) || circulation_stopped())
		return 0

	var/margin = 1
	if(our_brain.maxHealth)
		margin = min(margin, 1 - (our_brain.damage / our_brain.maxHealth))

	var/obj/item/organ/heart/our_heart = get_organ_slot(ORGAN_SLOT_HEART)
	if(our_heart?.maxHealth)
		margin = min(margin, 1 - (our_heart.damage / our_heart.maxHealth))

	// Raw volume rather than the modified figure: this runs on every updatehealth() and the modifiers
	// walk the whole reagent list.
	if(CAN_HAVE_BLOOD(src))
		margin = min(margin, (blood_volume - BLOOD_VOLUME_SURVIVE) / (BLOOD_VOLUME_NORMAL - BLOOD_VOLUME_SURVIVE))

	return clamp(margin, 0, 1)

/mob/living/carbon/human/get_health_hud_percent()
	var/margin = get_vitals_ratio()
	// The negative half of the ladder is reserved for a body with something actually giving out.
	if(is_dying())
		return -100 * (1 - margin)
	return 100 * margin

/mob/living/carbon/human/get_crit_overlay_reading()
	// The same ladder the HUD reads. Pain is excluded from it deliberately, so a stun greys nobody
	// out: the overlays are for a body on its way out, and pain shock has its own status effect.
	return get_health_hud_percent()

/**
 * The most brain damage ordinary violence is allowed to leave.
 *
 * Ordinary violence leaves cognitive damage, not death; overflow, finishers and suffocation are the
 * routes past it. Read off the brain rather than assumed, since not every brain gives out at the
 * standard threshold: a surplus one goes at half of it.
 */
/mob/living/proc/get_brain_damage_combat_cap()
	return BRAIN_DAMAGE_COMBAT_MAXIMUM

/mob/living/carbon/get_brain_damage_combat_cap()
	var/obj/item/organ/our_brain = get_organ_slot(ORGAN_SLOT_BRAIN)
	return isnull(our_brain) ? BRAIN_DAMAGE_COMBAT_MAXIMUM : (our_brain.maxHealth - 1)

/**
 * Turns suffocation and poisoning into the organ damage that actually kills.
 *
 * Keeps space, drowning, strangling, a stopped heart and every poison lethal now that no amount of
 * oxyloss or toxloss is death by itself. Past the point the body copes with, each starts destroying
 * an organ.
 *
 * Arguments:
 * * seconds_per_tick - Standard Life() timing.
 */
/mob/living/carbon/human/proc/handle_organ_lethality(seconds_per_tick)
	if(get_oxy_loss() >= OXYLOSS_BRAIN_DAMAGE_THRESHOLD)
		adjust_organ_loss(ORGAN_SLOT_BRAIN, OXYLOSS_BRAIN_DAMAGE_RATE * seconds_per_tick)

	var/poisoning = get_tox_loss()
	// The liver is clearing the poison, so it is what the poison ruins first.
	if(poisoning >= TOXLOSS_LIVER_DAMAGE_THRESHOLD)
		adjust_organ_loss(ORGAN_SLOT_LIVER, TOXLOSS_LIVER_DAMAGE_RATE * seconds_per_tick)
	// Past this the poison reaches the brain as well.
	if(poisoning >= TOXLOSS_BRAIN_DAMAGE_THRESHOLD)
		adjust_organ_loss(ORGAN_SLOT_BRAIN, TOXLOSS_BRAIN_DAMAGE_RATE * seconds_per_tick)
