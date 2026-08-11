// Combat feedback budget.
//
// A fight produces far more things worth saying than a player can read. Every one of them announced
// on its own turns a firefight into a wall of text, and the line that mattered - the plate giving
// out, the skull opening - scrolls past with the rest. So feedback is arbitrated: within a short
// window only the biggest thing that has happened to a mob gets to speak, and a bigger event
// arriving mid-window takes the moment off a smaller one. See [/mob/living/proc/combat_feedback].

/// How long one announced event holds the floor. Anything smaller inside this window is swallowed.
#define COMBAT_FEEDBACK_WINDOW (1 SECONDS)

// Priorities. Higher wins. Spaced so a tier can carry a severity on top without reaching the next one.
/// A hit landing. Shake and nothing else - this is the "not every bullet" the design asks for.
#define COMBAT_FEEDBACK_IMPACT 10
/// An injury being taken. Severity is added on top, so a shattered femur outranks a graze.
#define COMBAT_FEEDBACK_INJURY 20
/// Equipment or a body changing state: a plate cracking, a plate giving out entirely.
#define COMBAT_FEEDBACK_STATE 30
/// Damage reaching something the body cannot do without.
#define COMBAT_FEEDBACK_OVERFLOW 40
/// Someone being finished off. Always speaks.
#define COMBAT_FEEDBACK_EXECUTION 50

// Screen shake, scaled by whether the hit got inside. Both are soft caps; see [/proc/shake_camera].
/// How hard a hit an armour plate stopped shakes the wearer. Enough to know it happened.
#define COMBAT_SHAKE_NONPENETRATING 0.4
/// Least a hit that got through shakes its victim.
#define COMBAT_SHAKE_PENETRATING_MIN 0.6
/// Most a hit that got through shakes its victim, however big it was.
#define COMBAT_SHAKE_PENETRATING_MAX 2.5
/// Damage a penetrating hit needs to carry to shake as hard as it possibly can.
#define COMBAT_SHAKE_FULL_STRENGTH_DAMAGE 40
/// How long any combat shake lasts.
#define COMBAT_SHAKE_DURATION (0.3 SECONDS)
