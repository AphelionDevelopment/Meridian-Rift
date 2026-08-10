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

/// Temporary pain shed per second no matter how much is left.
#define PAIN_TEMPORARY_DECAY_FLAT 2
/// Portion of the remaining temporary pain shed per second. Drains fast while high, lingers once low.
#define PAIN_TEMPORARY_DECAY_COEFFICIENT 0.1

/// Felt pain at which the body checks out entirely.
#define PAIN_SHOCK_THRESHOLD 100
/// Felt pain a mob must fall back to before it leaves shock. Below the threshold so nobody yo-yos on the line.
#define PAIN_SHOCK_RECOVERY_THRESHOLD 70

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
