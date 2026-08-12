/datum/wound/muscle/robotic
	sound_effect = 'modular_nova/modules/medical/sound/robotic_slash_T1.ogg' // NOVA EDIT CHANGE - ORIGINAL: sound_effect = 'sound/effects/wounds/blood1.ogg'
	treat_text_short = "Wrap the affected limb with gauze and tell them to rest."

/datum/wound_pregen_data/muscle/robotic
	required_limb_biostate = (BIO_METAL)

/datum/wound/muscle/robotic/moderate
	name = "Overworked Servo"
	desc = "A servo has been overworked, and will operate with reduced efficiency until rested."
	treat_text = "A tight splint on the affected limb, as well as plenty of rest and sleep."
	examine_desc = "appears to be moving sluggishly"
	occur_text = "jitters for a moment before moving sluggishly"
	severity = WOUND_SEVERITY_MODERATE
	pain_factor = PAIN_FACTOR_MODERATE // NOVA EDIT ADDITION - COMBAT_PAIN
	interaction_efficiency_penalty = 1.5
	limp_slowdown = 2
	limp_chance = 30
	threshold_penalty = 15
	status_effect_type = /datum/status_effect/wound/muscle/robotic/moderate
	regen_ticks_needed = 90

/datum/wound_pregen_data/muscle/robotic/servo
	abstract = FALSE
	wound_path_to_generate = /datum/wound/muscle/robotic/moderate
	threshold_minimum = 35

/datum/wound/muscle/robotic/severe
	name = "Exhausted Piston"
	sound_effect = 'modular_nova/modules/medical/sound/robotic_slash_T2.ogg' // NOVA EDIT CHANGE - ORIGINAL: sound_effect = 'sound/effects/wounds/blood2.ogg'
	desc = "An important hydraulic piston has been critically overused, resulting in total dysfunction until it recovers."
	treat_text = "A tight splint on the affected limb, as well as plenty of rest and sleep."
	examine_desc = "is stiffly limp, the extremities splayed out widely"
	occur_text = "goes completely stiff, seeming to lock into position"
	severity = WOUND_SEVERITY_SEVERE
	pain_factor = PAIN_FACTOR_SEVERE // NOVA EDIT ADDITION - COMBAT_PAIN
	interaction_efficiency_penalty = 2
	limp_slowdown = 5
	limp_chance = 40
	threshold_penalty = 35
	disabling = TRUE
	status_effect_type = /datum/status_effect/wound/muscle/robotic/severe
	regen_ticks_needed = 150

/datum/wound_pregen_data/muscle/robotic/hydraulic
	abstract = FALSE

	wound_path_to_generate = /datum/wound/muscle/robotic/severe
	threshold_minimum = 80
