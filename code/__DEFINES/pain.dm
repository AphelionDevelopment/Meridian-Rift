// Combat pain system.
// Injuries set a permanent floor, impacts stack a temporary pool on top of it, and painkillers
// reduce only how much of the total the mob feels.

/// Pain contributed by a Light injury.
#define PAIN_FACTOR_LIGHT 5
/// Pain contributed by a Moderate injury.
#define PAIN_FACTOR_MODERATE 15
/// Pain contributed by a Severe injury.
#define PAIN_FACTOR_SEVERE 30
/// Pain contributed by an Extreme injury.
#define PAIN_FACTOR_EXTREME 50

/// Steps an injury's pain factor down one tier. Field treatment does not remove an injury, but a
/// splinted fracture counts a tier lower.
#define PAIN_FACTOR_TIER_BELOW(factor) ( \
	(factor) > PAIN_FACTOR_SEVERE ? PAIN_FACTOR_SEVERE : \
	(factor) > PAIN_FACTOR_MODERATE ? PAIN_FACTOR_MODERATE : \
	(factor) > PAIN_FACTOR_LIGHT ? PAIN_FACTOR_LIGHT : (factor) \
)

/// Most permanent pain the head is allowed to contribute to the floor.
#define PAIN_CAP_HEAD 70
/// Most permanent pain the chest is allowed to contribute to the floor.
#define PAIN_CAP_CHEST 70
/// Most permanent pain a single limb is allowed to contribute to the floor.
#define PAIN_CAP_LIMB 30

/// Ceiling on the permanent floor once every capped bodypart is summed.
#define PAIN_FLOOR_MAXIMUM 100
/// Ceiling on the temporary pool. With the decay curve below, this bounds a stun to five seconds.
#define PAIN_TEMPORARY_MAXIMUM 120
/// Ceiling on felt pain.
#define PAIN_MAXIMUM 100

/// Portion of an injury's pain factor spent as temporary pain each time the limb is used.
#define PAIN_INJURY_USE_RATIO 0.5
/// The same, for a use that fails outright.
#define PAIN_INJURY_USE_SPIKE_RATIO 1

/// Portion of an attack's damage that lands as temporary pain, on top of whatever it wounds.
/// Brute and burn only; oxygen and toxin damage go to the organs instead.
#define PAIN_IMPACT_RATIO 0.5

/// Temporary pain shed per second no matter how much is left.
#define PAIN_TEMPORARY_DECAY_FLAT 2
/// Portion of the remaining temporary pain shed per second.
#define PAIN_TEMPORARY_DECAY_COEFFICIENT 0.1

/// Felt pain at which a mob goes into shock.
#define PAIN_SHOCK_THRESHOLD 100
/// Felt pain a mob must fall back to before it leaves shock. Below the shock threshold, so it does not oscillate on the line.
#define PAIN_SHOCK_RECOVERY_THRESHOLD 70
/// Absolute longest one uninterrupted pain blackout may last.
#define PAIN_SHOCK_MAXIMUM_DURATION (5 SECONDS)

/// How much more a hit hurts with a completely ruined heart. Scales with how ruined it is.
#define PAIN_HEART_STRAIN_MULTIPLIER 0.5
/// How much slower pain drains with a completely ruined heart. Scales the same way.
#define PAIN_HEART_DECAY_BRAKE 0.5

/// Permanent pain of being operated on while awake and unnumbed. Cleared when the surgery ends.
#define PAIN_SURGERY_UNANAESTHETISED 20
/// Temporary pain per unnumbed surgical step.
#define PAIN_SURGERY_STEP_SPIKE 15
/// Permanent pain of a missing limb. Extreme, but capped by the limb's own zone cap of 30.
#define PAIN_MISSING_LIMB PAIN_FACTOR_EXTREME

/// Key for the pain of being operated on while awake.
#define PAIN_SOURCE_SURGERY "surgery"
/// How long the memory of an unnumbed surgical step keeps hurting, refreshed by each new one.
#define PAIN_SURGERY_MEMORY_DURATION (2 MINUTES)
/// Key for the pain of a limb that is not there, one per zone.
#define PAIN_SOURCE_MISSING_LIMB(zone) "missing_[zone]"

// Layout of an entry in /datum/pain/var/other_sources.
/// The bodypart zone a non-injury pain source is felt in.
#define PAIN_SOURCE_ZONE 1
/// How much that source hurts.
#define PAIN_SOURCE_AMOUNT 2
/// When the source expires, or zero if it lasts until something removes it.
#define PAIN_SOURCE_EXPIRY 3

/// Mood category the current pain bracket's moodlet occupies.
#define PAIN_MOOD_CATEGORY "pain"

/// How often the current bracket rolls its intermittent effects.
#define PAIN_EFFECT_ROLL_INTERVAL (4 SECONDS)

// The top bracket pulses the meter's alpha, as there is no colour past red.
/// How faint the pain meter goes at the bottom of a flash.
#define PAIN_METER_FLASH_ALPHA 90
/// How long each half of a flash takes.
#define PAIN_METER_FLASH_INTERVAL (0.4 SECONDS)

/// Permanent pain from one injury that is enough to trigger fight or flight.
#define PAIN_ADRENALINE_INJURY_TRIGGER PAIN_FACTOR_SEVERE
/// Temporary pain from a single hit that is enough to trigger fight or flight.
#define PAIN_ADRENALINE_SPIKE_TRIGGER 40
/// How long adrenaline lasts.
#define PAIN_ADRENALINE_DURATION (30 SECONDS)
/// Portion of total pain adrenaline hides while it lasts.
#define PAIN_ADRENALINE_DAMPEN_RATIO 0.5
/// How long the mob stutters once the adrenaline crashes.
#define PAIN_ADRENALINE_CRASH_STUTTER (10 SECONDS)

/// Felt pain hidden by each painkiller. Only the strongest active one counts; they never stack.
#define PAIN_DAMPEN_IBUPROFEN 10
/// Weak, easy to overdose on.
#define PAIN_DAMPEN_PARACETAMOL 15
/// Heavy drunkenness.
#define PAIN_DAMPEN_ALCOHOL 20
/// Drunkenness required before alcohol dampens anything.
#define PAIN_DAMPEN_DRUNK_REQUIREMENT 60
/// Injectable and addictive.
#define PAIN_DAMPEN_MORPHINE 40
/// Surgical grade. An overdose causes respiratory depression.
#define PAIN_DAMPEN_FENTANYL 70
/// Anaesthetic gas: complete numbness, then sleep.
#define PAIN_DAMPEN_TOTAL 100
/// How much of a surgical anaesthetic is needed before it dampens anything. Below this it does
/// nothing at all.
#define PAIN_DAMPEN_ANAESTHETIC_DOSE 15

// Grades for analgesic chems the design does not name individually. An ungraded analgesia trait uses
// the strong value too: traits may damp pain, but the combat contract grants none total immunity.
/// A mild additive, or a painkiller that is mostly something else.
#define PAIN_DAMPEN_WEAK 10
/// A field painkiller.
#define PAIN_DAMPEN_MODERATE 25
/// Opioid grade.
#define PAIN_DAMPEN_STRONG 40

/// Lowest felt pain for each bracket. Effects for each live on the matching /datum/pain_bracket.
#define PAIN_BRACKET_MINOR_THRESHOLD 0
/// Task times start to stretch here.
#define PAIN_BRACKET_MILD_THRESHOLD 10
/// Fumbling, shaking and stuttering start here.
#define PAIN_BRACKET_MODERATE_THRESHOLD 30
/// Screaming, frequent drops, falling over.
#define PAIN_BRACKET_SEVERE_THRESHOLD 50
/// Barely functional, one spike short of shock.
#define PAIN_BRACKET_AGONY_THRESHOLD 70
