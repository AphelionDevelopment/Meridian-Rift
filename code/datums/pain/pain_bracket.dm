/// Every pain bracket, ordered most severe first so a lookup can take the first threshold it clears.
GLOBAL_LIST_INIT(pain_brackets, list(
	new /datum/pain_bracket/agony,
	new /datum/pain_bracket/severe,
	new /datum/pain_bracket/moderate,
	new /datum/pain_bracket/mild,
	new /datum/pain_bracket/minor,
))

/**
 * A band of felt pain, and what the body does while it sits in that band.
 *
 * Tuning the pain system means editing the numbers on these datums, not the controller. Permanent
 * effects last as long as the mob stays in the bracket; intermittent ones roll against their chance.
 */
/datum/pain_bracket
	/// Shown on examine and in logs.
	var/name = "minor pain"
	/// Lowest felt pain that puts a mob in this bracket.
	var/threshold = PAIN_BRACKET_MINOR_THRESHOLD
	/// Colour the pain meter takes while here.
	var/meter_colour = COLOR_WHITE
	/// What being in this much pain does to a mob's mood. Null for brackets that are not worth complaining about.
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
	/// Whether speech is impaired while here.
	var/stutters = FALSE

/// No effect, just a reading. A minor bruise lives here.
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

/// Where pain becomes a problem: fumbling, shaking, the first stutter.
/datum/pain_bracket/moderate
	name = "moderate pain"
	threshold = PAIN_BRACKET_MODERATE_THRESHOLD
	meter_colour = COLOR_ORANGE
	mood_event = /datum/mood_event/pain/moderate
	interaction_penalty = 1.3
	drop_chance = 5
	vocalise_chance = 10

/// Begging for it to stop. Movement suffers and items start leaving your hands.
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
	stutters = TRUE

/// Barely standing. One more hit ends it.
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
	stutters = TRUE

// One moodlet per bracket. All of them carry MOOD_EVENT_PAIN, so anything that stops a mob feeling
// pain stops it souring their mood too - the same trait that blinds the meter and the doll.
/datum/mood_event/pain
	event_flags = MOOD_EVENT_PAIN

/datum/mood_event/pain/mild
	description = "Something hurts, and it is not letting me forget it."
	mood_change = -2

/datum/mood_event/pain/moderate
	description = "It hurts. I can think around it, but it takes work."
	mood_change = -5

/datum/mood_event/pain/severe
	description = "I can barely think through the pain!"
	mood_change = -8

/datum/mood_event/pain/agony
	description = "MAKE IT STOP!"
	mood_change = -12
