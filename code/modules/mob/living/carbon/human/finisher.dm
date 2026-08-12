/// Executes helpless targets after an interruptible wind-up.

/**
 * Whether this mob can no longer do anything about what happens to it.
 *
 * Pain shock and the pain crawl are rungs on the crit ladder, so the stat check covers them along
 * with arrest and bloodloss. The rest covers being helpless while stat still reads STABLE: knocked
 * out, stunned, cuffed, or with no legs left to stand on.
 */
/mob/living/carbon/proc/is_at_mercy()
	return pain_controller?.in_shock \
		|| pain_controller?.crawling \
		|| stat != STABLE \
		|| incapacitated \
		|| HAS_TRAIT(src, TRAIT_KNOCKEDOUT) \
		|| usable_legs <= 0

/**
 * Whether this item is capable of finishing someone off.
 *
 * A single killing blow, so the weapon has to be able to deliver one. Anything that only deals
 * stamina is a restraint tool.
 */
/obj/item/proc/is_lethal_enough_to_finish()
	if(damtype == STAMINA || damtype == OXY)
		return FALSE
	return (sharpness & (SHARP_EDGED|SHARP_POINTY)) || force >= FINISHER_MINIMUM_FORCE

/// Stun weapons take people alive, whatever their force. The security baton is force 10 and would
/// otherwise qualify.
/obj/item/melee/baton/is_lethal_enough_to_finish()
	return FALSE

/obj/item/gun/is_lethal_enough_to_finish()
	// The chambered round decides this, not the gun: a disabler and a lethal laser are the same frame.
	var/obj/projectile/round = chambered?.loaded_projectile
	if(isnull(round) || !can_shoot())
		return FALSE
	if(!(round.damage_type == BRUTE || round.damage_type == BURN))
		return FALSE
	return round.damage >= FINISHER_MINIMUM_PROJECTILE_DAMAGE

/// Attempts a finisher. Returns TRUE when it consumes the click.
/mob/living/carbon/human/proc/try_finisher(mob/living/user, obj/item/weapon)
	if(user == src || !user.combat_mode || stat == DEAD)
		return FALSE
	if(user.zone_selected != BODY_ZONE_HEAD)
		return FALSE
	if(isnull(weapon) || !weapon.is_lethal_enough_to_finish())
		return FALSE
	if(!is_at_mercy())
		return FALSE
	if(isnull(get_bodypart(BODY_ZONE_HEAD)) || isnull(get_organ_slot(ORGAN_SLOT_BRAIN)))
		return FALSE

	visible_message(
		span_userdanger("[user] lines [weapon] up with [src]'s head!"),
		span_userdanger("[user] lines [weapon] up with your head!"),
		span_hear("You hear something being readied."),
	)
	playsound(src, 'sound/effects/wounds/crack2.ogg', 100, TRUE, extrarange = FINISHER_WINDUP_HEARING_RANGE)

	if(!do_after(user, FINISHER_WINDUP_TIME, src))
		user.visible_message(
			span_notice("[user] is interrupted."),
			span_notice("You are interrupted."),
		)
		return TRUE

	// The wind-up is long enough for any of this to have stopped being true, so ask again.
	if(QDELETED(src) || stat == DEAD || !user.Adjacent(src) || user.incapacitated)
		return TRUE
	if(!is_at_mercy() || user.zone_selected != BODY_ZONE_HEAD)
		return TRUE
	if(user.get_active_held_item() != weapon || !weapon.is_lethal_enough_to_finish())
		return TRUE

	finish_off(user, weapon)
	return TRUE

/mob/living/carbon/human/attackby_secondary(obj/item/weapon, mob/living/user, list/modifiers, list/attack_modifiers)
	// Right click separates finishing someone from hitting them, since every other condition is also
	// true of an ordinary swing at a downed target's head. Guns have their own point blank route.
	if(!isgun(weapon) && try_finisher(user, weapon))
		return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN

	return ..()

/// Kills through brain damage, leaving the target recoverable after organ repair.
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

	apply_damage(FINISHER_HEAD_TRAUMA, BRUTE, BODY_ZONE_HEAD, wound_bonus = CANT_WOUND, attacking_item = weapon)
	adjust_organ_loss(ORGAN_SLOT_BRAIN, inner_brain.maxHealth)
	spray_blood(get_dir(user, src), WOUND_SEVERITY_CRITICAL)

	log_finisher(src, user, weapon)
	investigate_log("was executed by [key_name(user)] with [weapon].", INVESTIGATE_DEATHS)

	// death() does not consult TRAIT_NODEATH itself, so this does. The brain is filled either way.
	if(!HAS_TRAIT(src, TRAIT_NODEATH))
		death()
