// Combat feedback budget.
//
// A fight produces more announceable events than a player can read. Feedback is arbitrated: within
// a short window only the highest priority event announces, and a bigger event arriving mid-window
// takes the window off a smaller one. See [/mob/living/proc/combat_feedback].

/// How long one announced event suppresses smaller ones.
#define COMBAT_FEEDBACK_WINDOW (1 SECONDS)

// Priorities. Higher wins. Spaced so a tier can carry a severity on top without reaching the next one.
/// A hit landing. Shake only, with no message.
#define COMBAT_FEEDBACK_IMPACT 10
/// An injury being taken. Severity is added on top, so a worse injury outranks a lesser one.
#define COMBAT_FEEDBACK_INJURY 20
/// Equipment or a body changing state: a plate cracking, a plate giving out entirely.
#define COMBAT_FEEDBACK_STATE 30
/// Damage reaching an organ through a maxed bodypart.
#define COMBAT_FEEDBACK_OVERFLOW 40

// Screen shake, scaled by whether the hit got inside. Both are soft caps; see [/proc/shake_camera].
/// How hard a hit an armour plate stopped shakes the wearer.
#define COMBAT_SHAKE_NONPENETRATING 0.4
/// Least a hit that got through shakes its victim.
#define COMBAT_SHAKE_PENETRATING_MIN 0.6
/// Most a hit that got through shakes its victim.
#define COMBAT_SHAKE_PENETRATING_MAX 2.5
/// Damage a penetrating hit needs to carry to shake as hard as it possibly can.
#define COMBAT_SHAKE_FULL_STRENGTH_DAMAGE 40
/// How long any combat shake lasts.
#define COMBAT_SHAKE_DURATION (0.3 SECONDS)
