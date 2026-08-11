// Combat pain system.
// Damage causes injuries, pain causes incapacitation. Injuries set a permanent floor, impacts stack
// a temporary pool on top of it, and painkillers only change how much of the total the brain notices.

/// Pain contributed by a Light injury.
#define PAIN_FACTOR_LIGHT 5
/// Pain contributed by a Moderate injury.
#define PAIN_FACTOR_MODERATE 15
/// Pain contributed by a Severe injury.
#define PAIN_FACTOR_SEVERE 30
/// Pain contributed by an Extreme injury.
#define PAIN_FACTOR_EXTREME 50

/// Steps down the injury pain ladder, for injuries that have had something done about them.
/// Field treatment does not fix an injury, but it takes the edge off - a splinted fracture is a tier quieter.
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

/// Ceiling on the permanent floor once every capped bodypart is summed. No single part can reach it alone.
#define PAIN_FLOOR_MAXIMUM 100
/// Ceiling on the temporary pool. With the decay curve below, this is what bounds a stun to five seconds.
#define PAIN_TEMPORARY_MAXIMUM 120
/// Ceiling on total and felt pain. Both mob-facing values run 0 to this.
#define PAIN_MAXIMUM 100

// Working through an injury feeds the meter, so pushing on has a price even when it works.
/// Portion of an injury's pain factor spent as temporary pain each time it is used.
#define PAIN_INJURY_USE_RATIO 0.5
/// The same, for a use that goes badly enough to stop you mid-swing.
#define PAIN_INJURY_USE_SPIKE_RATIO 1

/// Portion of an attack's damage that lands as temporary pain, on top of whatever it wounds.
/// Brute and burn only - suffocating and poisoning are the organs' business.
#define PAIN_IMPACT_RATIO 0.5

/// Temporary pain shed per second no matter how much is left.
#define PAIN_TEMPORARY_DECAY_FLAT 2
/// Portion of the remaining temporary pain shed per second. Drains fast while high, lingers once low.
#define PAIN_TEMPORARY_DECAY_COEFFICIENT 0.1

/// Felt pain at which the body checks out entirely.
#define PAIN_SHOCK_THRESHOLD 100
/// Felt pain a mob must fall back to before it leaves shock. Below the threshold so nobody yo-yos on the line.
#define PAIN_SHOCK_RECOVERY_THRESHOLD 70
/// Temporary pain on a mob already crawling that counts as a fresh hit, and puts them out again.
#define PAIN_SHOCK_BLACKOUT_MINIMUM 10

// A failing heart cannot keep up with what is being done to the body it belongs to.
/// How much more a hit hurts with a completely ruined heart. Scales with how ruined it is.
#define PAIN_HEART_STRAIN_MULTIPLIER 0.5
/// How much slower pain drains with a completely ruined heart. Scales the same way.
#define PAIN_HEART_DECAY_BRAKE 0.5

/// Permanent pain of being operated on while awake and unnumbed. Cleared when the surgery ends.
#define PAIN_SURGERY_UNANAESTHETISED 20
/// Temporary pain per unnumbed surgical step.
#define PAIN_SURGERY_STEP_SPIKE 15
/// Permanent pain of a limb that is no longer there. Extreme, per Appendix B - the limb's own cap of 30
/// is what keeps losing one arm from being the whole of it, and losing all four from being survivable.
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
/// When it stops hurting, or zero for sources that last until something removes them.
#define PAIN_SOURCE_EXPIRY 3

/// Mood category the current pain bracket's moodlet occupies. One at a time, like the brackets themselves.
#define PAIN_MOOD_CATEGORY "pain"

/// How often the current bracket rolls its intermittent effects.
#define PAIN_EFFECT_ROLL_INTERVAL (4 SECONDS)

/// Permanent pain from one injury that is enough to trigger fight or flight.
#define PAIN_ADRENALINE_INJURY_TRIGGER PAIN_FACTOR_SEVERE
/// Temporary pain from a single hit that is enough to trigger fight or flight.
#define PAIN_ADRENALINE_SPIKE_TRIGGER 40
/// How long fight or flight lasts. Long enough to shoot back or run, not to win a war.
#define PAIN_ADRENALINE_DURATION (30 SECONDS)
/// Portion of total pain adrenaline hides while it lasts.
#define PAIN_ADRENALINE_DAMPEN_RATIO 0.5
/// How long the mob stumbles over its words once the adrenaline crashes.
#define PAIN_ADRENALINE_CRASH_STUTTER (10 SECONDS)

/// Felt pain hidden by each painkiller. Only the strongest active one counts; they never stack.
#define PAIN_DAMPEN_IBUPROFEN 10
/// Weak, easy to overdose on.
#define PAIN_DAMPEN_PARACETAMOL 15
/// Being extremely drunk, with all the drawbacks of being extremely drunk.
#define PAIN_DAMPEN_ALCOHOL 20
/// How drunk "extremely drunk" actually is, before alcohol dulls anything.
#define PAIN_DAMPEN_DRUNK_REQUIREMENT 60
/// The workhorse. Fast, injectable, addictive.
#define PAIN_DAMPEN_MORPHINE 40
/// Surgical grade. An overdose stops your breathing.
#define PAIN_DAMPEN_FENTANYL 70
/// Anaesthetic gas. You feel nothing at all, then you are asleep.
#define PAIN_DAMPEN_TOTAL 100
/// How much of a surgical anaesthetic has to be in someone before it numbs them at all. Below this
/// it does nothing for pain - an anaesthetic is a dose, not a sip, and total numbness is total.
#define PAIN_DAMPEN_ANAESTHETIC_DOSE 15

// Grades for the analgesic chems the design does not name individually. Anything that numbs without
// a value here is read as total numbness, so a painkiller missing one is a painkiller that makes you
// invincible.
/// A mild additive, or a painkiller that is mostly something else.
#define PAIN_DAMPEN_WEAK 10
/// A field painkiller: takes the edge off a bad injury without hiding it.
#define PAIN_DAMPEN_MODERATE 25
/// Opioid grade. Enough to keep someone upright who should not be.
#define PAIN_DAMPEN_STRONG 40

/// Lowest felt pain for each bracket. Effects for each live on the matching /datum/pain_bracket.
#define PAIN_BRACKET_MINOR_THRESHOLD 0
/// Task times start to stretch here.
#define PAIN_BRACKET_MILD_THRESHOLD 10
/// Where pain becomes a problem: fumbling, shaking, stuttering.
#define PAIN_BRACKET_MODERATE_THRESHOLD 30
/// Screaming, frequent drops, falling over.
#define PAIN_BRACKET_SEVERE_THRESHOLD 50
/// Barely functional. One more hit ends it.
#define PAIN_BRACKET_AGONY_THRESHOLD 70
