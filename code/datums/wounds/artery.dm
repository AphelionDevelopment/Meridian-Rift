/// A low-pain arterial bleed that requires a tourniquet and cautery.
/datum/wound/slash/flesh/artery
	name = "Severed Artery"
	// Without a scanner this reads as bleeding from whatever cut is next to it.
	undiagnosed_name = "Heavy Bleeding"
	desc = "The patient has a severed artery with heavy internal bleeding."
	treat_text = "Apply a tourniquet immediately to buy time, then cauterise the vessel closed. \
		Bandaging will not reach it."
	treat_text_short = "Tourniquet, then cauterise."
	simple_treat_text = "A <b>tourniquet</b>, right now. Then <b>cautery</b>. Gauze will not stop this."
	homemade_treat_text = "Nothing homemade stops an artery. Tie it off above the wound and find a surgeon."
	examine_desc = "is slick with dark blood welling from somewhere deep"
	occur_text = "wells up with dark blood, running far heavier than the wound looks"
	sound_effect = 'sound/effects/wounds/blood3.ogg'

	severity = WOUND_SEVERITY_CRITICAL
	// Light despite the severity, which is why pain_factor is set per datum rather than derived.
	pain_factor = PAIN_FACTOR_LIGHT
	// The limb is structurally intact, so an artery is not the Critical injury dismemberment wants.
	// Counting it would replace bleeding out with amputation.
	allows_overflow = FALSE

	// Heavier than a critical cut, and unlike one it neither clots nor worsens.
	initial_flow = 4.5
	minimum_flow = 0.5
	clot_rate = 0
	demotes_to = null

	// Nothing to tick: no clotting to apply and no gauze benefit to grant.
	processes = FALSE
	// No ACCEPTS_GAUZE, but pressure by hand still helps.
	wound_flags = CAN_BE_GRASPED
	base_treat_time = 5 SECONDS
	threshold_penalty = 20

	status_effect_type = /datum/status_effect/wound/artery

/datum/wound/slash/flesh/artery/get_self_check_description(self_aware)
	return span_boldwarning("It doesn't hurt much, but it is soaked in blood.")

/datum/wound/slash/flesh/artery/get_bleed_rate_of_change()
	// It neither clots nor worsens, so gauze applied for another wound must not report this one as
	// improving.
	return BLOOD_FLOW_STEADY

/datum/wound/slash/flesh/artery/get_limb_examine_description()
	return span_warning("The flesh here is soaked through with blood.")

/datum/wound_pregen_data/artery
	abstract = FALSE

	wound_path_to_generate = /datum/wound/slash/flesh/artery
	wound_series = WOUND_SERIES_FLESH_ARTERY
	bleeds = TRUE

	// Needs something to bleed, so bloodless limbs are exempt.
	required_limb_biostate = (BIO_FLESH|BIO_BLOODED)
	ignore_cannot_bleed = FALSE

	// Limbs only, as a tourniquet has no answer for a torso artery.
	viable_zones = list(BODY_ZONE_L_ARM, BODY_ZONE_R_ARM, BODY_ZONE_L_LEG, BODY_ZONE_R_LEG)

	// At or above the critical tier of both series it competes with, so it is an alternative at the
	// top tier, picked by weight, rather than a replacement for them.
	threshold_minimum = 100
	weight = 15

	required_wounding_type = WOUND_SLASH

/datum/wound_pregen_data/artery/wounding_types_valid(suggested_wounding_type)
	// Cutting and piercing only; blunt trauma bruises around an artery.
	return (suggested_wounding_type == WOUND_SLASH || suggested_wounding_type == WOUND_PIERCE)

/datum/status_effect/wound/artery
	id = "artery"
