/**
 * What happens to a bodypart that has run out of ways to get worse.
 *
 * Injuries are how a part absorbs punishment. Once it is carrying the worst injury there is, more
 * damage has nowhere to go inside the part, so it goes to whatever the part was protecting instead -
 * the brain behind a ruined head, the heart behind a ruined chest, the limb itself for a limb. See
 * phase 5 of the combat overhaul plan.
 */

/obj/item/bodypart
	/// Keeps overflow feedback from firing on every tick of something continuous, like being on fire.
	COOLDOWN_DECLARE(overflow_feedback_cooldown)

/**
 * Tells the owner their body is being ruined from the inside, at most once every few seconds.
 *
 * Overflow happens per hit, and a hit can be a bullet or one tick of standing in a fire, so this is
 * rate limited rather than trusting the source to be reasonable about it.
 *
 * Arguments:
 * * message - What the owner feels.
 */
/obj/item/bodypart/proc/announce_overflow(message)
	if(!COOLDOWN_FINISHED(src, overflow_feedback_cooldown))
		return

	COOLDOWN_START(src, overflow_feedback_cooldown, OVERFLOW_FEEDBACK_COOLDOWN)
	to_chat(owner, span_userdanger(message))
	playsound(owner, 'sound/effects/wounds/crackandbleed.ogg', 60, TRUE)

/**
 * Whether this bodypart has nothing left to give.
 *
 * Deliberately reads the injury track rather than the damage total. Heads and chests cap at 250
 * damage, which is several magazines, while the injury that ruins one is two or three solid hits -
 * so damage totals would put overflow far out of reach of the pacing the design asks for. A Critical
 * injury is the worst state a part can be in, and that is what "maxed" means.
 */
/obj/item/bodypart/proc/is_injury_capacity_maxed()
	for(var/datum/wound/injury as anything in wounds)
		if(injury.severity >= WOUND_SEVERITY_CRITICAL)
			return TRUE
	return FALSE

/**
 * Converts a hit onto whatever this bodypart was protecting.
 *
 * Only ever called for a penetrating hit on a part that was already maxed *before* this hit landed,
 * which is what stops one monster shot from both ruining a part and killing through it. The part
 * still takes its damage as normal; this is what the hit does on top, now that there is nothing left
 * in the part to absorb it.
 *
 * Limbs have nothing inside worth targeting, so a limb's overflow is the limb itself coming off.
 *
 * Assumes the part has an owner - receive_damage()'s owner branch is the only caller.
 *
 * Arguments:
 * * damage - Wounding damage of the hit that overflowed.
 * * wounding_type - One of the WOUND_* types, for dismemberment flavour.
 * * attack_direction - Which way the hit came from, so the blood goes the other way.
 * * damage_source - What did it, for the logs.
 *
 * Returns TRUE if the bodypart is gone, in which case the caller has nothing left to damage.
 */
/obj/item/bodypart/proc/apply_overflow(damage, wounding_type, attack_direction, damage_source)
	// A limb comes off to a solid hit and not to a graze, which is the difference between finishing
	// someone's arm and worrying at it.
	if(damage < OVERFLOW_DISMEMBER_MINIMUM_DAMAGE || !can_dismember())
		return FALSE

	// Held onto because taking the limb off is what clears it, and the log is about whoever lost it.
	var/mob/living/carbon/losing_the_limb = owner

	var/datum/wound/loss/dismembering = new
	if(!dismembering.apply_dismember(src, wounding_type, outright = TRUE, attack_direction = attack_direction))
		return FALSE

	log_overflow(losing_the_limb, damage_source, plaintext_zone, "dismemberment", damage)
	return TRUE

/obj/item/bodypart/head/apply_overflow(damage, wounding_type, attack_direction, damage_source)
	var/obj/item/organ/inner_brain = owner.get_organ_slot(ORGAN_SLOT_BRAIN)
	if(isnull(inner_brain))
		return FALSE

	// Uncapped, unlike ordinary violence: overflow is one of the two things allowed past the brain's
	// death threshold, and it is the slow one. A finisher is the fast one.
	var/overflow = damage * OVERFLOW_DAMAGE_RATIO
	owner.adjust_organ_loss(ORGAN_SLOT_BRAIN, overflow)
	log_overflow(owner, damage_source, plaintext_zone, "brain", overflow)

	announce_overflow("Something gives way inside your skull!")
	return FALSE

/obj/item/bodypart/chest/apply_overflow(damage, wounding_type, attack_direction, damage_source)
	var/obj/item/organ/heart/inner_heart = owner.get_organ_slot(ORGAN_SLOT_HEART)
	if(isnull(inner_heart))
		return FALSE

	var/overflow = damage * OVERFLOW_DAMAGE_RATIO
	owner.adjust_organ_loss(ORGAN_SLOT_HEART, overflow)
	log_overflow(owner, damage_source, plaintext_zone, "heart", overflow)

	// A ruined heart does not stop on its own here - failing and beating are separate states - and a
	// heart that keeps beating is not a chest kill. Arrest is what makes this lethal, slowly, through
	// the oxygen the brain stops getting.
	if((inner_heart.organ_flags & ORGAN_FAILING) && !owner.undergoing_cardiac_arrest())
		owner.set_heartattack(TRUE)

	announce_overflow("Something tears deep in your chest!")
	return FALSE
