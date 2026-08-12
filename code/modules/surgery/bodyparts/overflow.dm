/**
 * What happens to a bodypart that has run out of ways to get worse.
 *
 * Injuries are how a part absorbs punishment. Once it carries the worst injury there is, further
 * damage goes to whatever the part was protecting: the brain behind a ruined head, the heart behind
 * a ruined chest, and for a limb, the limb itself.
 */

/obj/item/bodypart
	/// Keeps overflow feedback from firing on every tick of something continuous, like being on fire.
	COOLDOWN_DECLARE(overflow_feedback_cooldown)

/**
 * Tells the owner their body is being ruined from the inside, at most once every few seconds.
 *
 * Overflow happens per hit, and a hit can be a bullet or one tick of standing in a fire, so this
 * carries a cooldown on top of the feedback budget.
 *
 * Arguments:
 * * message - What the owner feels.
 * * onlooker_message - What everyone else sees.
 */
/obj/item/bodypart/proc/announce_overflow(message, onlooker_message)
	if(!COOLDOWN_FINISHED(src, overflow_feedback_cooldown))
		return

	COOLDOWN_START(src, overflow_feedback_cooldown, OVERFLOW_FEEDBACK_COOLDOWN)
	owner.combat_feedback(
		COMBAT_FEEDBACK_OVERFLOW,
		message = span_bolddanger(onlooker_message),
		self_message = span_userdanger(message),
		sound = 'sound/effects/wounds/crackandbleed.ogg',
		shake_strength = COMBAT_SHAKE_PENETRATING_MAX,
	)

/**
 * Whether this bodypart has nothing left to give.
 *
 * Reads the injury track rather than the damage total. Heads and chests cap at 250 damage, several
 * magazines, while the injury that ruins one is two or three solid hits, so a damage total would put
 * overflow out of reach of the intended pacing. A Critical injury is the worst state a part can be
 * in, barring the injuries flagged never lethal.
 */
/obj/item/bodypart/proc/is_injury_capacity_maxed()
	for(var/datum/wound/injury as anything in wounds)
		if(injury.severity >= WOUND_SEVERITY_CRITICAL && injury.allows_overflow)
			return TRUE
	return FALSE

/**
 * Damages one organ inside this bodypart, chosen at random.
 *
 * Once a part's injuries have stacked up, what is inside it starts taking hits too and can be
 * destroyed outright, so eyes, ears, tongues, lungs, livers and stomachs are on the receiving end of
 * a fight as well as the part's own overflow target.
 *
 * Which organ a hit finds is random, as neither design document gives a rule for it. The zone's own
 * overflow target is in the pool with the rest.
 *
 * Assumes the part has an owner; receive_damage()'s owner branch is the only caller.
 *
 * Arguments:
 * * damage - Wounding damage of the hit that overflowed.
 * * damage_source - What did it, for the logs.
 */
/obj/item/bodypart/proc/damage_random_organ(damage, damage_source)
	var/list/obj/item/organ/candidates = list()
	for(var/obj/item/organ/inner_organ as anything in owner.organs)
		// Eyes and tongues live in precise zones, but are inside this part all the same.
		if(inner_organ.slot && deprecise_zone(inner_organ.zone) == body_zone)
			candidates += inner_organ

	if(!length(candidates))
		return

	var/obj/item/organ/unlucky = pick(candidates)
	var/was_failing = (unlucky.organ_flags & ORGAN_FAILING)
	owner.adjust_organ_loss(unlucky.slot, damage * OVERFLOW_ORGAN_DAMAGE_RATIO)

	// Only an organ giving out is logged; the hits on the way there are in the attack log already.
	if(!was_failing && (unlucky.organ_flags & ORGAN_FAILING))
		log_overflow(owner, damage_source, plaintext_zone, "[unlucky.name] destroyed", damage)

/**
 * Converts a hit onto whatever this bodypart was protecting.
 *
 * Only called for a penetrating hit on a part that was already maxed before this hit landed, so one
 * shot can never both ruin a part and kill through it. The part still takes its damage as normal;
 * this is on top of that.
 *
 * Limbs have nothing inside worth targeting, so a limb's overflow is the limb coming off.
 *
 * Assumes the part has an owner; receive_damage()'s owner branch is the only caller.
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
	// A limb comes off to a solid hit, not to a graze.
	if(damage < OVERFLOW_DISMEMBER_MINIMUM_DAMAGE || !can_dismember())
		return FALSE

	// Held onto because taking the limb off clears owner, and the log needs the mob.
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

	// Uncapped, unlike ordinary damage: overflow and finishers are the two routes past the brain's
	// death threshold.
	var/overflow = damage * OVERFLOW_DAMAGE_RATIO
	owner.adjust_organ_loss(ORGAN_SLOT_BRAIN, overflow)
	log_overflow(owner, damage_source, plaintext_zone, "brain", overflow)

	announce_overflow("Something gives way inside your skull!", "Something gives way inside [owner]'s skull!")
	return FALSE

/obj/item/bodypart/chest/apply_overflow(damage, wounding_type, attack_direction, damage_source)
	var/obj/item/organ/heart/inner_heart = owner.get_organ_slot(ORGAN_SLOT_HEART)
	if(isnull(inner_heart))
		return overflow_without_a_heart(damage, damage_source)

	var/overflow = damage * OVERFLOW_DAMAGE_RATIO
	owner.adjust_organ_loss(ORGAN_SLOT_HEART, overflow)
	log_overflow(owner, damage_source, plaintext_zone, "heart", overflow)

	// Failing and beating are separate states here, so a ruined heart does not stop on its own.
	// Arrest is what makes chest overflow lethal, via the oxygen the brain stops getting.
	if((inner_heart.organ_flags & ORGAN_FAILING) && !owner.undergoing_cardiac_arrest())
		owner.set_heartattack(TRUE)

	announce_overflow("Something tears deep in your chest!", "Something tears deep in [owner]'s chest!")
	return FALSE

/**
 * Chest overflow for a body with no heart in it at all.
 *
 * Some species have no heart, which left their torsos with nothing to overflow into: a
 * maxed chest absorbed penetrating hits forever and body shots on them could never kill. There is no
 * circulation to stop, so what a ruined torso costs such a body is the brain, at the rate a ruined
 * skull costs anyone else.
 *
 * Arguments:
 * * damage - Wounding damage of the hit that overflowed.
 * * damage_source - What did it, for the logs.
 */
/obj/item/bodypart/chest/proc/overflow_without_a_heart(damage, damage_source)
	if(isnull(owner.get_organ_slot(ORGAN_SLOT_BRAIN)))
		return FALSE

	var/overflow = damage * OVERFLOW_DAMAGE_RATIO
	owner.adjust_organ_loss(ORGAN_SLOT_BRAIN, overflow)
	log_overflow(owner, damage_source, plaintext_zone, "brain", overflow)

	announce_overflow("Something deep in your chest gives out!", "Something deep in [owner]'s chest gives out!")
	return FALSE
