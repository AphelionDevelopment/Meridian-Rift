/**
 * Bruising.
 *
 * The injury that everything blunt leaves behind, and the only thing a hit that armour stopped is
 * allowed to leave. Bruises are never lethal and never bleed: they hurt, they make a limb worse at
 * its job, and they fade on their own given time and rest. Anything that needs a surgeon is a
 * fracture or a laceration, not this.
 *
 * Unlike the rest of the tree this applies to the chest and head as well as limbs, because there is
 * no part of a person that cannot be bruised.
 */
/datum/wound/bruise
	name = "Bruise"
	a_or_from = "a"
	sound_effect = 'sound/effects/wounds/crack1.ogg'
	wound_flags = ACCEPTS_GAUZE
	processes = TRUE
	can_scar = FALSE
	// Never lethal, per Appendix A. A contusion is the worst a bruise gets, and it is still a bruise -
	// it must not be the injury that opens a head up to being killed through.
	allows_overflow = FALSE
	// Nothing in a medkit treats a bruise. Rest does, and a splint makes rest work faster.

	/// How many process ticks of rest this bruise needs before it fades.
	var/regen_ticks_needed
	/// How far along it currently is.
	var/regen_ticks_current = 0
	/// Temporary pain for putting weight on this the moment it is used for something.
	var/use_pain

/datum/wound/bruise/set_victim(new_victim)
	if(victim)
		UnregisterSignal(victim, COMSIG_LIVING_EARLY_UNARMED_ATTACK)

	if(new_victim && use_pain)
		RegisterSignal(new_victim, COMSIG_LIVING_EARLY_UNARMED_ATTACK, PROC_REF(on_hurt_hand_used))

	return ..()

/datum/wound/bruise/handle_process(seconds_per_tick, times_fired)
	. = ..()

	// Bruises fade on their own. Staying off the limb, or off your feet entirely, is the whole cure.
	regen_ticks_current += 1
	if(victim.body_position == LYING_DOWN)
		regen_ticks_current += 1
	regen_ticks_current += 1 - limb.get_splint_factor()

	if(regen_ticks_current < regen_ticks_needed)
		return

	to_chat(victim, span_green("The bruising on your [limb.plaintext_zone] has faded."))
	remove_wound()

/// Working through a bruise costs you something. Punching with a bruised arm is a spike of pain, not a penalty on paper.
/datum/wound/bruise/proc/on_hurt_hand_used(mob/living/user, atom/target, proximity)
	SIGNAL_HANDLER

	// This signal fires ahead of every unarmed click, throwing a punch or not, so the swing has to be
	// confirmed as one before it costs anything - hugging someone is not working through an injury.
	if(!proximity || !victim.combat_mode || victim.get_active_hand() != limb || !ismob(target))
		return

	victim.add_temporary_pain(use_pain)
	to_chat(victim, span_warning("Your bruised [limb.plaintext_zone] throbs as you strike [target]."))

/datum/wound/bruise/get_limb_examine_description()
	return span_warning("The flesh here is swollen and discoloured.")

/datum/wound_pregen_data/bruise
	abstract = TRUE

	// Anything blunt enough to leave one, which includes bullets and blades that failed to get through.
	required_wounding_type = WOUND_BRUTE
	required_limb_biostate = BIO_FLESH

	wound_series = WOUND_SERIES_FLESH_BRUISE

	// Bruises never beat a more specific injury to the punch - their thresholds sit at or above the
	// tier they compete with, so they are an alternative at that tier rather than a replacement for it.
	weight = 30

/// Minor: fades on its own, and that is the whole of it.
/datum/wound/bruise/moderate
	name = "Minor Bruise"
	desc = "Patient's flesh is bruised, with minor swelling and discolouration."
	treat_text = "Rest. Ice, if the patient insists."
	treat_text_short = "Rest."
	simple_treat_text = "<b>Rest</b>. It will fade on its own."
	homemade_treat_text = "A cold pack and staying off it."
	examine_desc = "is bruised and slightly swollen"
	occur_text = "darkens with a spreading bruise"
	severity = WOUND_SEVERITY_MODERATE
	pain_factor = PAIN_FACTOR_LIGHT
	threshold_penalty = 10
	status_effect_type = /datum/status_effect/wound/bruise/moderate
	regen_ticks_needed = 60

/datum/wound_pregen_data/bruise/minor
	abstract = FALSE

	wound_path_to_generate = /datum/wound/bruise/moderate
	threshold_minimum = 20

/// Major: deep bruising. It hurts to use and it hurts more the more you use it.
/datum/wound/bruise/severe
	name = "Deep Bruise"
	desc = "Patient's flesh is deeply bruised, with significant swelling and pain on use."
	treat_text = "A cold pack and rest. Splinting the limb will speed recovery."
	treat_text_short = "Cold pack and rest."
	simple_treat_text = "<b>Rest</b> and a <b>cold pack</b>. A <b>splint</b> speeds it up."
	homemade_treat_text = "A cold pack, a splint if you have one, and staying off it."
	examine_desc = "is badly bruised and swollen"
	occur_text = "swells and darkens with deep bruising"
	severity = WOUND_SEVERITY_SEVERE
	pain_factor = PAIN_FACTOR_MODERATE
	interaction_efficiency_penalty = 1.3
	limp_slowdown = 2
	limp_chance = 30
	threshold_penalty = 20
	status_effect_type = /datum/status_effect/wound/bruise/severe
	regen_ticks_needed = 150
	use_pain = 5

/datum/wound_pregen_data/bruise/deep
	abstract = FALSE

	wound_path_to_generate = /datum/wound/bruise/severe
	threshold_minimum = 60

/// Critical: contused to the point of being half useless. Slow to heal, and never the thing that kills you.
/datum/wound/bruise/critical
	name = "Severe Contusion"
	desc = "Patient's flesh is contused throughout, with heavy swelling, weakened grip and pain on any use."
	treat_text = "Immobilisation and prolonged rest. There is nothing to operate on; it simply takes time."
	treat_text_short = "Immobilise and wait."
	simple_treat_text = "<b>Splint</b> it and <b>rest</b>. There is no quick fix - it heals slowly."
	homemade_treat_text = "Keep it still, keep it cold, and do not use it."
	examine_desc = "is swollen, purpled and hangs oddly"
	occur_text = "swells violently, purpling as it goes"
	severity = WOUND_SEVERITY_CRITICAL
	pain_factor = PAIN_FACTOR_SEVERE
	interaction_efficiency_penalty = 1.6
	limp_slowdown = 4
	limp_chance = 50
	threshold_penalty = 30
	status_effect_type = /datum/status_effect/wound/bruise/critical
	regen_ticks_needed = 320
	use_pain = 10

/datum/wound_pregen_data/bruise/contusion
	abstract = FALSE

	wound_path_to_generate = /datum/wound/bruise/critical
	threshold_minimum = 120

/datum/status_effect/wound/bruise/moderate
	id = "bruise"
/datum/status_effect/wound/bruise/severe
	id = "deepbruise"
/datum/status_effect/wound/bruise/critical
	id = "contusion"
