/**
 * Finishers.
 *
 * Overflow is how a fight kills someone by accident, over several hits, while they are still trying.
 * A finisher is the other route: a deliberate execution of someone who has already stopped being a
 * threat. Every condition has to hold at once - they are at your mercy, you are on top of them, you
 * are aimed at the head, you are holding something lethal - and then it takes a wind-up long enough
 * that everyone watching knows exactly what you did. See phase 5 of the combat overhaul plan.
 */

/**
 * Whether this mob has stopped being able to do anything about what happens to it.
 *
 * Pain shock and the pain crawl are both rungs on the crit ladder since phase 4, so the two states
 * the pain system produces are covered by the stat check, alongside arrest and bloodloss. The rest is
 * for the ways a mob can be helpless while its stat still reads fine: knocked out by oxygen, held
 * down by a stun, cuffed, or simply with nothing left to stand on.
 */
/mob/living/carbon/proc/is_at_mercy()
	if(stat != STABLE)
		return TRUE
	// One bitfield already covers being stunned, cuffed, held in an aggressive grab, and in stasis.
	if(incapacitated)
		return TRUE
	if(HAS_TRAIT(src, TRAIT_KNOCKEDOUT))
		return TRUE
	// Mangled beyond standing: nothing left to get up with.
	if(usable_legs <= 0)
		return TRUE
	return FALSE

/**
 * Whether this item is capable of finishing someone off.
 *
 * A finisher is not a beating - it is one deliberate killing blow, so the thing in your hands has to
 * be able to deliver one. Anything that only ever deals stamina is a restraint tool by definition.
 */
/obj/item/proc/is_lethal_enough_to_finish()
	if(damtype == STAMINA || damtype == OXY)
		return FALSE
	// Sharp enough to open a skull, or heavy enough to stave one in.
	return (sharpness & (SHARP_EDGED|SHARP_POINTY)) || force >= FINISHER_MINIMUM_FORCE

/// Stun weapons take people alive. That distinction is the whole reason restraint is cheaper than
/// killing, so no amount of blunt force on the end of a baton makes it an execution tool.
/obj/item/melee/baton/is_lethal_enough_to_finish()
	return FALSE

/obj/item/gun/is_lethal_enough_to_finish()
	// The round in the chamber decides this, not the gun: a disabler and a lethal laser are the same
	// frame, and an empty gun is a club that has not been swung.
	var/obj/projectile/round = chambered?.loaded_projectile
	if(isnull(round) || !can_shoot())
		return FALSE
	if(!(round.damage_type == BRUTE || round.damage_type == BURN))
		return FALSE
	return round.damage >= FINISHER_MINIMUM_PROJECTILE_DAMAGE

/**
 * Runs the conditions for a finisher and, if they all hold, performs one.
 *
 * Called from a point blank gun, and from a right-clicked melee weapon. Deliberately not from the
 * ordinary swing: hooked there it took over every combat-mode blow aimed at the head of anyone
 * cuffed, grabbed or on the floor, so you could no longer simply hit someone. Returns TRUE if the
 * finisher took the click, whether or not it ran to completion - an interrupted execution still
 * spent the attempt.
 *
 * Arguments:
 * * user - Whoever is doing this.
 * * weapon - What they are doing it with.
 */
/mob/living/carbon/human/proc/try_finisher(mob/living/user, obj/item/weapon)
	if(user == src || !user.combat_mode || stat == DEAD)
		return FALSE
	if(user.zone_selected != BODY_ZONE_HEAD)
		return FALSE
	if(isnull(weapon) || !weapon.is_lethal_enough_to_finish())
		return FALSE
	if(!is_at_mercy())
		return FALSE
	// Nothing to aim at, and nothing in there to end.
	if(isnull(get_bodypart(BODY_ZONE_HEAD)) || isnull(get_organ_slot(ORGAN_SLOT_BRAIN)))
		return FALSE

	visible_message(
		span_userdanger("[user] lines [weapon] up with [src]'s head!"),
		span_userdanger("[user] lines [weapon] up with your head!"),
		span_hear("You hear something being readied, deliberately."),
	)
	playsound(src, 'sound/effects/wounds/crack2.ogg', 100, TRUE, extrarange = FINISHER_WINDUP_HEARING_RANGE)

	if(!do_after(user, FINISHER_WINDUP_TIME, src))
		user.visible_message(
			span_notice("[user] is interrupted."),
			span_notice("You are interrupted."),
		)
		return TRUE

	// The wind-up is long enough for all of this to have stopped being true, and the whole point of it
	// is that it can be stopped. Everything gets asked again.
	if(QDELETED(src) || stat == DEAD || !user.Adjacent(src) || user.incapacitated)
		return TRUE
	if(!is_at_mercy() || user.zone_selected != BODY_ZONE_HEAD)
		return TRUE
	if(user.get_active_held_item() != weapon || !weapon.is_lethal_enough_to_finish())
		return TRUE

	finish_off(user, weapon)
	return TRUE

/mob/living/carbon/human/attackby_secondary(obj/item/weapon, mob/living/user, list/modifiers, list/attack_modifiers)
	// Right click is what separates finishing someone from hitting them, since every other condition
	// a finisher wants is also true of an ordinary swing at a downed target's head. A gun already has
	// its point blank route and does not need a second one.
	if(!isgun(weapon) && try_finisher(user, weapon))
		return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN

	return ..()

/**
 * The killing blow itself.
 *
 * The fast way across the brain's death threshold, where overflow is the slow one. It leaves a corpse
 * exactly as recoverable as any other brain death - repair the brain, then defibrillate - because no
 * combat death is permanent.
 *
 * Arguments:
 * * user - Whoever is doing this.
 * * weapon - What they are doing it with.
 */
/mob/living/carbon/human/proc/finish_off(mob/living/user, obj/item/weapon)
	var/obj/item/organ/inner_brain = get_organ_slot(ORGAN_SLOT_BRAIN)

	combat_feedback(
		COMBAT_FEEDBACK_EXECUTION,
		message = span_bolddanger("[user] finishes [src] off with [weapon]!"),
		self_message = span_userdanger("[user] finishes you off with [weapon]!"),
		shake_strength = COMBAT_SHAKE_PENETRATING_MAX,
		vision_distance = DEFAULT_MESSAGE_RANGE,
	)
	playsound(src, 'sound/effects/wounds/crackandbleed.ogg', 100, TRUE, extrarange = FINISHER_WINDUP_HEARING_RANGE)

	// Damage first for the gore, then the brain, so the corpse looks like what happened to it.
	apply_damage(FINISHER_HEAD_TRAUMA, BRUTE, BODY_ZONE_HEAD, wound_bonus = CANT_WOUND, attacking_item = weapon)
	adjust_organ_loss(ORGAN_SLOT_BRAIN, inner_brain.maxHealth)
	spray_blood(get_dir(user, src), WOUND_SEVERITY_CRITICAL)

	log_finisher(src, user, weapon)
	investigate_log("was executed by [key_name(user)] with [weapon].", INVESTIGATE_DEATHS)

	// death() does not consult TRAIT_NODEATH itself, so this does. The brain is filled either way, so
	// whoever is holding the trait dies the moment they stop.
	if(!HAS_TRAIT(src, TRAIT_NODEATH))
		death()
