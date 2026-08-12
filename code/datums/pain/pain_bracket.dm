/// Every pain bracket, ordered most severe first so a lookup can take the first threshold it clears.
GLOBAL_LIST_INIT(pain_brackets, list(
	new /datum/pain_bracket/agony,
	new /datum/pain_bracket/severe,
	new /datum/pain_bracket/moderate,
	new /datum/pain_bracket/mild,
	new /datum/pain_bracket/minor,
))

/// Defines the effects for one band of felt pain.
/datum/pain_bracket
	/// Shown on examine and in logs.
	var/name = "minor pain"
	/// Lowest felt pain that puts a mob in this bracket.
	var/threshold = PAIN_BRACKET_MINOR_THRESHOLD
	/// Colour the pain meter takes while here.
	var/meter_colour = COLOR_WHITE
	/// Moodlet applied while here. Null for brackets with no moodlet.
	var/datum/mood_event/mood_event
	/// Multiplier on how long tasks take. 1 is unimpaired.
	var/interaction_penalty = 1
	/// Flat movement slowdown applied while here.
	var/slowdown = 0
	/// Chance per roll to fumble a held item.
	var/drop_chance = 0
	/// Chance per roll to fall over.
	var/fall_chance = 0
	/// Chance per roll to make an involuntary noise.
	var/vocalise_chance = 0
	/// Chance per roll for pain to make the mob visibly shake.
	var/shake_chance = 0
	/// Chance per roll for pain to impair speech until the next roll.
	var/stutter_chance = 0
	/// Chance per roll to briefly pass out.
	var/passout_chance = 0
	/// Whether the pain meter pulses while here, as the last rung past red.
	var/meter_flashes = FALSE

/// A reading only, with no effect.
/datum/pain_bracket/minor
	name = "minor pain"
	threshold = PAIN_BRACKET_MINOR_THRESHOLD

/// Task times stretch slightly, with the occasional visible sign of discomfort.
/datum/pain_bracket/mild
	name = "mild pain"
	threshold = PAIN_BRACKET_MILD_THRESHOLD
	meter_colour = COLOR_YELLOW
	mood_event = /datum/mood_event/pain/mild
	interaction_penalty = 1.1
	vocalise_chance = 5

/// Fumbled items and the first visible shaking.
/datum/pain_bracket/moderate
	name = "moderate pain"
	threshold = PAIN_BRACKET_MODERATE_THRESHOLD
	meter_colour = COLOR_ORANGE
	mood_event = /datum/mood_event/pain/moderate
	interaction_penalty = 1.3
	drop_chance = 5
	vocalise_chance = 10
	shake_chance = 10
	stutter_chance = 10

/// Movement slows, speech breaks up and items start dropping.
/datum/pain_bracket/severe
	name = "severe pain"
	threshold = PAIN_BRACKET_SEVERE_THRESHOLD
	meter_colour = COLOR_SOFT_RED
	mood_event = /datum/mood_event/pain/severe
	interaction_penalty = 1.6
	slowdown = 1
	drop_chance = 15
	fall_chance = 5
	vocalise_chance = 20
	shake_chance = 25
	stutter_chance = 100

/// Barely standing, one spike short of shock.
/datum/pain_bracket/agony
	name = "agony"
	threshold = PAIN_BRACKET_AGONY_THRESHOLD
	meter_colour = COLOR_RED
	mood_event = /datum/mood_event/pain/agony
	interaction_penalty = 2
	slowdown = 2.5
	drop_chance = 30
	fall_chance = 15
	vocalise_chance = 35
	shake_chance = 100
	stutter_chance = 100
	passout_chance = 10
	meter_flashes = TRUE

// One moodlet per bracket, all flagged MOOD_EVENT_PAIN so painkillers hide them alongside the meter
// and the doll.
/datum/mood_event/pain
	event_flags = MOOD_EVENT_PAIN

/datum/mood_event/pain/mild
	description = "I can't ignore the pain."
	mood_change = -2

/datum/mood_event/pain/moderate
	description = "The pain makes it hard to think."
	mood_change = -5

/datum/mood_event/pain/severe
	description = "I can barely think through the pain."
	mood_change = -8

/datum/mood_event/pain/agony
	description = "The pain is unbearable."
	mood_change = -12
