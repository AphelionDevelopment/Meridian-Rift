/**
 * Stamina, for anything with a pain controller, is temporary pain.
 *
 * Every stamina source in the game - batons, disablers, exhaustion, tackles, sprinting - spends
 * itself on the pain pool instead of a bar of its own. The ~550 existing stamina call sites keep
 * working through these three procs, so there is exactly one way to be put down and one number that
 * decides it. The pool carries its own decay curve and its own shock, so neither the stamina
 * regeneration timer nor the stamina crit ladder survive the conversion - both hang off
 * received_stamina_damage(), which these overrides never reach and which bails on a controller anyway.
 *
 * Mobs without a controller - simple and basic mobs - keep plain stamina.
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
 * Reads felt pain, so a painkiller blinds this readout exactly like it blinds the health doll. The
 * meter shows how bad it feels through the bracket colour and how full the bar is - never a number.
 */
/mob/living/carbon/proc/update_pain_hud()
	if(!client || !hud_used)
		return

	var/atom/movable/screen/stamina/meter = hud_used.screen_objects[HUD_MOB_STAMINA]
	if(isnull(meter))
		return

	// The bar measures pain now, and its tooltip should say so.
	meter.name = "pain"

	if(stat == DEAD)
		meter.icon_state = "stamina_dead"
		meter.color = null
		return

	var/felt = get_felt_pain()
	var/datum/pain_bracket/bracket = pain_controller?.current_bracket
	meter.color = bracket?.meter_colour

	if(felt >= PAIN_SHOCK_THRESHOLD)
		meter.icon_state = "stamina_crit"
		return

	if(felt <= 0)
		meter.icon_state = "stamina_full"
		return

	meter.icon_state = "stamina_[clamp(ceil(felt / (PAIN_MAXIMUM * 0.2)), 1, 5)]"
