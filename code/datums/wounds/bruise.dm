/**
 * Bruising.
 *
 * The injury blunt trauma leaves, and the only injury a hit that armour stopped may leave. Bruises
 * are never lethal and never bleed. They hurt, they make a limb worse at its job, and they fade on
 * their own given rest.
 *
 * Unlike the rest of the tree this applies to the chest and head as well as limbs.
 */
/datum/wound/bruise
	name = "Bruise"
	a_or_from = "a"
	sound_effect = 'sound/effects/wounds/crack1.ogg'
	wound_flags = ACCEPTS_GAUZE
	processes = TRUE
	can_scar = FALSE
	// Never lethal, so a bruise must never be the injury that opens a part up to overflow.
	allows_overflow = FALSE

	/// How many process ticks of rest this bruise needs before it fades.
	var/regen_ticks_needed
	/// How far along it currently is.
	var/regen_ticks_current = 0
	/// Temporary pain spiked each time the limb is used.
	var/use_pain

/datum/wound/bruise/set_victim(new_victim)
	if(victim)
		UnregisterSignal(victim, COMSIG_LIVING_EARLY_UNARMED_ATTACK)

	if(new_victim && use_pain)
		RegisterSignal(new_victim, COMSIG_LIVING_EARLY_UNARMED_ATTACK, PROC_REF(on_hurt_hand_used))

	return ..()

/datum/wound/bruise/handle_process(seconds_per_tick, times_fired)
	. = ..()

	// Bruises fade on their own, faster while lying down or splinted.
	regen_ticks_current += 1
	if(victim.body_position == LYING_DOWN)
		regen_ticks_current += 1
	regen_ticks_current += 1 - limb.get_splint_factor()

	if(regen_ticks_current < regen_ticks_needed)
		return

	to_chat(victim, span_green("The bruising on your [limb.plaintext_zone] has faded."))
	remove_wound()

/// Spikes pain when the bruised limb is used to punch something.
/datum/wound/bruise/proc/on_hurt_hand_used(mob/living/user, atom/target, proximity)
	SIGNAL_HANDLER

	// Fires ahead of every unarmed click, so the swing has to be confirmed as an attack first.
	if(!proximity || !victim.combat_mode || victim.get_active_hand() != limb || !ismob(target))
		return

	victim.add_temporary_pain(use_pain)
	to_chat(victim, span_warning("Your bruised [limb.plaintext_zone] throbs as you strike [target]."))

/datum/wound/bruise/get_limb_examine_description()
	return span_warning("The flesh here is swollen and discoloured.")

/datum/wound_pregen_data/bruise
	abstract = TRUE

	// Includes bullets and blades that failed to get through.
	required_wounding_type = WOUND_BRUTE
	required_limb_biostate = BIO_FLESH

	wound_series = WOUND_SERIES_FLESH_BRUISE

	// Thresholds sit at or above the tier they compete with, so a bruise is an alternative at that
	// tier rather than a replacement for a more specific injury.
	weight = 30

/// Minor: fades on its own.
/datum/wound/bruise/moderate
	name = "Minor Bruise"
	desc = "Patient's flesh is bruised, with minor swelling and discolouration."
	treat_text = "Rest, with a cold pack if available."
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

/// Major: deep bruising that hurts to use.
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

/// Critical: contused to the point of a weakened grip and a limp. Slow to heal, never lethal.
/datum/wound/bruise/critical
	name = "Severe Contusion"
	desc = "Patient's flesh is contused throughout, with heavy swelling, weakened grip and pain on any use."
	treat_text = "Immobilisation and prolonged rest. There is nothing to operate on."
	treat_text_short = "Immobilise and wait."
	simple_treat_text = "<b>Splint</b> it and <b>rest</b>. It heals slowly."
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
