/**
 * What it takes to kill a person, and what it takes to knock one down.
 *
 * Damage totals decide neither any more. A person is alive while their brain is alive, their heart is
 * beating and there is blood in them to circulate; everything that used to kill through the health
 * bar now kills by ruining one of those three. See the combat overhaul plan, phase 0, for the full
 * contract - including why this lives on humans rather than every carbon.
 */

/mob/living/carbon/human/update_stat_from_condition()
	// Death is the brain's, the blood's and the heart's business, and each of those kills where it
	// lives. Nothing is left here but how conscious the mob is.
	// This runs on every updatehealth(), so the pain rungs are read off the controller's cached state
	// rather than by scanning the status effect list twice.
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
 * Deliberately not [/mob/living/carbon/proc/undergoing_cardiac_arrest], which answers the narrower
 * question of whether tg's organic heart attack mechanic is running. That proc is FALSE for a robotic
 * heart, because a robotic heart cannot have a heart attack, and FALSE for anything carrying
 * TRAIT_STABLEHEART. Both of those used to die of the damage totals phase 4 stopped consulting, so
 * reading arrest alone leaves an augmented chest immortal: the cybernetic heart sits at ORGAN_FAILING,
 * reports itself as beating forever, and nothing else in the contract can kill through a chest.
 *
 * A pump that has been ruined has stopped, whatever it is made of.
 */
/mob/living/carbon/human/proc/circulation_stopped()
	if(undergoing_cardiac_arrest())
		return TRUE

	var/obj/item/organ/heart/our_heart = get_organ_slot(ORGAN_SLOT_HEART)
	// Nothing in the chest to have stopped. A body that needs one and has none is arrest already.
	if(isnull(our_heart))
		return FALSE

	return !our_heart.is_beating() || (our_heart.organ_flags & ORGAN_FAILING)

/mob/living/carbon/human/can_recover_breath()
	// Circulation, and only circulation. Not health, which stopped deciding anything; not the crit rung,
	// because a batoned target is unconscious with working lungs and a crawler's problem is their leg;
	// and deliberately not the oxyloss threshold [is_dying] reads, or one bad lungful of vacuum would
	// put a mob permanently past the point of breathing it back off.
	return !circulation_stopped() && !is_bled_out()

/mob/living/carbon/human/is_damaged_beyond_revival()
	// Never, on damage alone. Brute and burn stopped killing in phase 4 and nothing caps their totals
	// short of the bodyparts' own limits, so an ordinary combat corpse now sits hundreds of points
	// under the old floor - a maxed head and chest are more than all of it by themselves. Leaving the
	// check in place would have made most kills permanent, which is exactly what the design forbids.
	// What can and cannot come back is the organs' business, in [/mob/living/carbon/proc/can_defib].
	return FALSE

/mob/living/carbon/human/is_dying()
	// Being in agony is not the same as bleeding out. Someone put down by pain has everything to play
	// for, and letting them give up would make a stun the same thing as a kill.
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
 * The damage totals stopped answering this in phase 4 - a man with a maxed chest and a working heart
 * is in no danger at all, and a man at full health with a stopped one is dying - so every instrument
 * that used to read them reads this instead. The worst of the three, because triage is about the thing
 * about to kill the patient rather than an average of their problems.
 *
 * Deliberately says nothing about pain: a triage instrument must not inherit the patient's painkillers,
 * and Appendix D's doped fighter with a severed artery is exactly the case a medic has to be able to
 * see. Brute and burn are just as deliberately absent - the analyser lists those in full underneath,
 * and a ruined limb is not an emergency any more.
 */
/mob/living/carbon/human/get_vitals_ratio()
	// Nothing in the skull, or a pump that has given out, and there is no margin left to report.
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
	// walk the whole reagent list. Saline buying someone a few percent is not what triage is looking at.
	if(CAN_HAVE_BLOOD(src))
		margin = min(margin, (blood_volume - BLOOD_VOLUME_SURVIVE) / (BLOOD_VOLUME_NORMAL - BLOOD_VOLUME_SURVIVE))

	return clamp(margin, 0, 1)

/mob/living/carbon/human/get_health_hud_percent()
	var/margin = get_vitals_ratio()
	// The ladder's bottom half is where a doctor is meant to drop what they are doing, so it is reserved
	// for a body with something actually giving out rather than for a full damage bar.
	if(is_dying())
		return -100 * (1 - margin)
	return 100 * margin

/**
 * The most brain damage ordinary violence is allowed to leave.
 *
 * Beating someone's head in makes them stupid, not dead. Crossing the line is what overflow and
 * finishers are for, and suffocation gets there on its own. Read off the brain rather than assumed,
 * because not every brain gives out at the standard threshold - a surplus one goes at half of it, and
 * a flat cap would leave that brain uncapped and its owner unkillable at the same time.
 */
/mob/living/proc/get_brain_damage_combat_cap()
	return BRAIN_DAMAGE_COMBAT_MAXIMUM

/mob/living/carbon/get_brain_damage_combat_cap()
	var/obj/item/organ/our_brain = get_organ_slot(ORGAN_SLOT_BRAIN)
	return isnull(our_brain) ? BRAIN_DAMAGE_COMBAT_MAXIMUM : (our_brain.maxHealth - 1)

/**
 * Turns suffocation and poisoning into the organ damage that actually kills.
 *
 * This is the bridge that keeps space, drowning, strangling, a stopped heart and every poison in the
 * game lethal now that no amount of oxyloss or toxloss is death by itself. Both work the same way:
 * past the point the body can cope with, they start destroying something that cannot be walked off.
 *
 * Arguments:
 * * seconds_per_tick - Standard Life() timing.
 */
/mob/living/carbon/human/proc/handle_organ_lethality(seconds_per_tick)
	// A brain with no oxygen dies, whether the oxygen stopped at the lungs, the heart or the airway.
	if(get_oxy_loss() >= OXYLOSS_BRAIN_DAMAGE_THRESHOLD)
		adjust_organ_loss(ORGAN_SLOT_BRAIN, OXYLOSS_BRAIN_DAMAGE_RATE * seconds_per_tick)

	var/poisoning = get_tox_loss()
	// The liver is what is trying to clear the poison, so it is what the poison ruins first.
	if(poisoning >= TOXLOSS_LIVER_DAMAGE_THRESHOLD)
		adjust_organ_loss(ORGAN_SLOT_LIVER, TOXLOSS_LIVER_DAMAGE_RATE * seconds_per_tick)
	// Past this there is more poison in the patient than the liver could ever have been blamed for.
	if(poisoning >= TOXLOSS_BRAIN_DAMAGE_THRESHOLD)
		adjust_organ_loss(ORGAN_SLOT_BRAIN, TOXLOSS_BRAIN_DAMAGE_RATE * seconds_per_tick)
