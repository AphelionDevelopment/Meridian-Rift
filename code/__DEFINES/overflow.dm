// Overflow: how combat damage is allowed to kill.
//
// A bodypart absorbs punishment by carrying injuries. Once its injuries are maxed, further
// penetrating damage lands on whatever the part was protecting, which is overflow.

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
