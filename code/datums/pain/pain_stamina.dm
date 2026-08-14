/**
 * Stamina, for anything with a pain controller, is temporary pain.
 *
 * Every stamina source (batons, disablers, exhaustion, tackles, sprinting) spends itself on the pain
 * pool instead of a bar of its own, so the existing stamina call sites keep working through these
 * three procs. The pool carries its own decay curve and its own shock, so neither the stamina
 * regeneration timer nor stamcrit survive the conversion: both hang off received_stamina_damage(),
 * which these overrides never reach and which bails on a controller anyway.
 *
 * Simple and basic mobs have no controller and keep plain stamina.
 */

/mob/living/carbon/get_stamina_loss()
	if(isnull(pain_controller))
		return ..()
	return pain_controller.temporary_pain

/mob/living/carbon/adjust_stamina_loss(amount, updating_stamina = TRUE, forced = FALSE, required_biotype = ALL)
	if(isnull(pain_controller))
		return ..()
	if(!can_adjust_stamina_loss(amount, forced, required_biotype))
		return 0

	var/old_pain = pain_controller.temporary_pain
	pain_controller.adjust_temporary_pain(amount * CONFIG_GET(number/damage_multiplier))
	// Stamina procs report the change as old minus new, so damage comes back negative.
	return old_pain - pain_controller.temporary_pain

/mob/living/carbon/set_stamina_loss(amount, updating_stamina = TRUE, forced = FALSE, required_biotype = ALL)
	if(isnull(pain_controller))
		return ..()
	if(!forced && (HAS_TRAIT(src, TRAIT_GODMODE) || !(mob_biotypes & required_biotype)))
		return 0

	var/old_pain = pain_controller.temporary_pain
	pain_controller.adjust_temporary_pain(amount - old_pain)
	return old_pain - pain_controller.temporary_pain

/mob/living/carbon/update_stamina_hud(shown_stamina_loss)
	update_pain_hud()

/**
 * Redraws the pain meter in the slot the stamina bar used to hold.
 *
 * Reads felt pain, so a painkiller blinds this readout as it does the health doll. Bracket colour
 * is the only reading; there is no number.
 */
/mob/living/carbon/proc/update_pain_hud()
	if(!client || !hud_used)
		return

	var/atom/movable/screen/stamina/meter = hud_used.screen_objects[HUD_MOB_STAMINA]
	if(isnull(meter))
		return

	meter.name = "pain"

	if(stat == DEAD)
		meter.icon_state = "pain_dead"
		meter.color = null
		meter.set_flashing(FALSE)
		return

	meter.icon_state = "pain"
	var/datum/pain_bracket/bracket = pain_controller?.current_bracket
	meter.color = bracket?.meter_colour
	meter.set_flashing(!!bracket?.meter_flashes)

/atom/movable/screen/stamina
	/// Whether the meter is currently pulsing. Held so a redraw does not restart the animation.
	var/flashing = FALSE

/**
 * Starts or stops the pain meter pulsing.
 *
 * Pulses alpha rather than colour: the bracket owns the colour and repaints it on every redraw, so
 * an animation on the same variable would fight with it.
 *
 * Arguments:
 * * new_flashing - Whether the meter should be pulsing.
 */
/atom/movable/screen/stamina/proc/set_flashing(new_flashing)
	if(flashing == new_flashing)
		return

	flashing = new_flashing
	if(!flashing)
		animate(src, alpha = 255, time = 0, flags = ANIMATION_END_NOW)
		return

	animate(src, alpha = PAIN_METER_FLASH_ALPHA, time = PAIN_METER_FLASH_INTERVAL, loop = -1)
	animate(alpha = 255, time = PAIN_METER_FLASH_INTERVAL)
