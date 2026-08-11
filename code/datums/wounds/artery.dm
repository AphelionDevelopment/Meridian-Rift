/**
 * Severed artery.
 *
 * The killer you don't feel. Appendix B of the combat overhaul plan calls this the only genuinely new
 * limb target, and the thing that makes it new is the pain column: Light, where everything else this
 * lethal is Severe or Extreme. A limb with a cut artery still works and barely aches, and the patient
 * bleeds out while treating whatever hurts more.
 *
 * Built on the flesh cut so it inherits the bleeding, grasping and cauterising machinery, but it sits
 * in a series of its own - an artery is something you have *as well as* the wound that opened it, not
 * instead of it. It never clots and gauze does nothing for it. A tourniquet buys time, which is what
 * the design asks for, and the limb bleed multiplier for one already exists.
 */
/datum/wound/slash/flesh/artery
	name = "Severed Artery"
	// Little visible wounding is the point: without a scanner this reads as bleeding from the cut
	// next to it, which is exactly how someone bleeds out while being treated for something else.
	undiagnosed_name = "Heavy Bleeding"
	desc = "Patient's limb has a severed artery, bleeding heavily with little outward sign of it."
	treat_text = "Apply a tourniquet immediately to buy time, then cauterise the vessel closed. \
		Bandaging will not reach it."
	treat_text_short = "Tourniquet, then cauterise."
	simple_treat_text = "A <b>tourniquet</b>, right now. Then <b>cautery</b> - gauze will not stop this."
	homemade_treat_text = "Nothing homemade stops an artery. Tie it off above the wound and find a surgeon."
	examine_desc = "is slick with dark blood welling from somewhere deep"
	occur_text = "wells up with dark blood, running far heavier than the wound looks"
	sound_effect = 'sound/effects/wounds/blood3.ogg'

	severity = WOUND_SEVERITY_CRITICAL
	// Light, and that is the whole design of this injury. Set here rather than derived from severity,
	// which is exactly why pain_factor is per datum.
	pain_factor = PAIN_FACTOR_LIGHT
	// A limb comes off to "a Critical fracture or laceration plus a high-damage P hit", per Appendix B.
	// An artery is neither: the limb is structurally intact and the vessel inside it is not, which is
	// the entire point of the injury. Counting it would take limbs off far sooner than the design's
	// rule does and would replace bleeding out - the thing this wound exists to do - with amputation.
	allows_overflow = FALSE

	// Heavier than a critical cut, and unlike one it neither clots nor worsens - it simply does not stop.
	initial_flow = 4.5
	minimum_flow = 0.5
	clot_rate = 0
	demotes_to = null

	// Nothing to tick: no clotting to apply and no gauze benefit to grant.
	processes = FALSE
	// Gauze is deliberately absent. Pressure by hand still helps a little, as it would.
	wound_flags = CAN_BE_GRASPED
	base_treat_time = 5 SECONDS
	threshold_penalty = 20

	status_effect_type = /datum/status_effect/wound/artery

/datum/wound/slash/flesh/artery/get_self_check_description(self_aware)
	// The one thing that will not warn you about this is how it feels.
	return span_boldwarning("It doesn't hurt much, but it is soaked in blood.")

/datum/wound/slash/flesh/artery/get_bleed_rate_of_change()
	// It does not clot and it does not worsen. Gauze on the limb for some other wound must not be
	// allowed to report this one as improving.
	return BLOOD_FLOW_STEADY

/datum/wound/slash/flesh/artery/get_limb_examine_description()
	return span_warning("The flesh here is soaked through with blood.")

/datum/wound_pregen_data/artery
	abstract = FALSE

	wound_path_to_generate = /datum/wound/slash/flesh/artery
	wound_series = WOUND_SERIES_FLESH_ARTERY
	bleeds = TRUE

	// Needs something to bleed, so bloodless limbs are exempt rather than silently carrying a wound
	// that can never do anything.
	required_limb_biostate = (BIO_FLESH|BIO_BLOODED)
	ignore_cannot_bleed = FALSE

	// A limb target, per Appendix B. A torso artery is not something a tourniquet has an answer for.
	viable_zones = list(BODY_ZONE_L_ARM, BODY_ZONE_R_ARM, BODY_ZONE_L_LEG, BODY_ZONE_R_LEG)

	// At or above the critical tier of both series it competes with, so it never monopolises a window
	// the way a lower threshold would - it is an alternative at the top tier, picked by weight.
	threshold_minimum = 100
	weight = 15

	required_wounding_type = WOUND_SLASH

/datum/wound_pregen_data/artery/wounding_types_valid(suggested_wounding_type)
	// Things that cut and things that punch through. Blunt trauma bruises around an artery.
	return (suggested_wounding_type == WOUND_SLASH || suggested_wounding_type == WOUND_PIERCE)

/datum/status_effect/wound/artery
	id = "artery"
