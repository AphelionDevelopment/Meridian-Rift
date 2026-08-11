// Overflow and finishers: the two ways combat damage is allowed to kill.
//
// A bodypart absorbs punishment by carrying injuries, and once its injuries are maxed it has nothing
// left to absorb with - further penetrating damage lands on whatever the part was protecting. That is
// overflow, and it is the slow way. A finisher is the deliberate version of the same thing: a
// telegraphed execution on a helpless target with every condition checked, because death is meant to
// be a decision rather than an accident.

/// Portion of an overflowing hit that lands on what the bodypart was protecting.
/// The pacing knob for the whole phase - see Appendix E of the combat overhaul plan.
#define OVERFLOW_DAMAGE_RATIO 1.5
/// Portion of an overflowing hit that lands on some other organ inside the same part, on top of
/// whatever the part's own overflow target takes. Appendix B's "organs are targeted once a part's
/// injuries stack up" - lighter than the kill route, because ruining an eye is not the same as a kill.
#define OVERFLOW_ORGAN_DAMAGE_RATIO 0.5

/// A limb only comes off to a hit of at least this size - the design's "high-damage P hit".
/// There is deliberately no equivalent floor for heads and chests: what reaches the organ is a
/// proportion of the hit, so a graze is a graze, and sustained burning has to be able to cook a heart.
#define OVERFLOW_DISMEMBER_MINIMUM_DAMAGE 20

/// How often a part that is overflowing will say so. Continuous damage - burning, mostly - arrives
/// every tick, and the design's feedback budget says the biggest event wins the moment, not every one.
#define OVERFLOW_FEEDBACK_COOLDOWN (3 SECONDS)

/// How long a finisher's wind-up takes. Long enough that anyone watching has time to stop it.
#define FINISHER_WINDUP_TIME (3 SECONDS)
/// Least force a blunt melee weapon needs before it can finish anyone off. Anything sharp qualifies
/// regardless - a scalpel does not need to be heavy. Sits above the security baton on purpose.
#define FINISHER_MINIMUM_FORCE 15
/// Least damage a chambered round needs before a gun can.
#define FINISHER_MINIMUM_PROJECTILE_DAMAGE 10
/// Brute the killing blow leaves on the head, on top of taking the brain past its threshold.
#define FINISHER_HEAD_TRAUMA 25
/// How far the wind-up can be heard. Witnesses are the point.
#define FINISHER_WINDUP_HEARING_RANGE 7
