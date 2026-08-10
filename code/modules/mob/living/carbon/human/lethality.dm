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
	if((pain?.in_shock || undergoing_cardiac_arrest()) && !HAS_TRAIT(src, TRAIT_NOHARDCRIT))
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

/mob/living/carbon/human/is_dying()
	// Being in agony is not the same as bleeding out. Someone put down by pain has everything to play
	// for, and letting them give up would make a stun the same thing as a kill.
	if(undergoing_cardiac_arrest())
		return TRUE
	if(get_oxy_loss() >= OXYLOSS_BRAIN_DAMAGE_THRESHOLD)
		return TRUE
	if(get_tox_loss() >= TOXLOSS_BRAIN_DAMAGE_THRESHOLD)
		return TRUE
	return is_bled_out()

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
