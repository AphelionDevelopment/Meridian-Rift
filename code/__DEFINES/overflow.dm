// Overflow and finishers: the two ways combat damage is allowed to kill.
//
// A bodypart absorbs punishment by carrying injuries. Once its injuries are maxed, further
// penetrating damage lands on whatever the part was protecting, which is overflow. A finisher is a
// telegraphed execution on a helpless target, with every condition checked.

/// Portion of an overflowing hit that lands on what the bodypart was protecting. The pacing knob for
/// how many hits a kill takes.
#define OVERFLOW_DAMAGE_RATIO 1.5
/// Portion of an overflowing hit that lands on some other organ inside the same part, on top of what
/// the part's own overflow target takes.
#define OVERFLOW_ORGAN_DAMAGE_RATIO 0.5

/// Least damage a penetrating hit needs before it takes a limb off. Heads and chests have no
/// equivalent floor: what reaches the organ is a proportion of the hit, so a graze stays a graze and
/// sustained burning can still reach a heart.
#define OVERFLOW_DISMEMBER_MINIMUM_DAMAGE 20

/// How often an overflowing part announces itself. Continuous damage, mostly burning, arrives every
/// tick and would otherwise announce every tick.
#define OVERFLOW_FEEDBACK_COOLDOWN (3 SECONDS)

/// How long a finisher's wind-up takes, during which anyone watching can stop it.
#define FINISHER_WINDUP_TIME (3 SECONDS)
/// Least force a blunt melee weapon needs before it can finish anyone off. Anything sharp qualifies
/// regardless. Set above the security baton's force.
#define FINISHER_MINIMUM_FORCE 15
/// Least damage a chambered round needs before a gun can.
#define FINISHER_MINIMUM_PROJECTILE_DAMAGE 10
/// Brute the killing blow leaves on the head, on top of taking the brain past its threshold.
#define FINISHER_HEAD_TRAUMA 25
/// How far the wind-up can be heard.
#define FINISHER_WINDUP_HEARING_RANGE 7
