// Armour plates, and the non-penetrating / penetrating split they decide.
//
// A plate is a tolerance rather than a percentage. It stops everything up to its level outright and
// lets the rest through as though nothing were worn, so damage is the only penetration stat there is.
// What the plate stops is non-penetrating: it hurts, it bruises or burns the body underneath, it
// wears the plate out, and it can never reach anything inside. What gets past is penetrating and
// behaves exactly like an unarmoured hit. See phase 6 of the combat overhaul plan.

/// Damage a plate stops outright, per level. Level 1 stops 10, level 2 stops 20, and so on.
#define PLATE_TOLERANCE_PER_LEVEL 10
/// Punishment a plate absorbs before it stops working, per level. Every plate is worth roughly ten
/// hits at its own tolerance - a plate that only ever meets grazes lasts a great deal longer.
#define PLATE_DURABILITY_PER_LEVEL 100

/// Portion of a stopped hit that lands as temporary pain. Under [PAIN_IMPACT_RATIO], because the
/// point of a plate is that being hit through one is survivable, not that it is comfortable.
#define PLATE_PAIN_RATIO 0.4
/// How much of that pain a stopped hit is worth for landing at all, before the rest is scaled by how
/// close to tolerance it came. A round that fills the plate's headroom spikes twice what a graze does.
#define PLATE_PAIN_PROXIMITY_FLOOR 0.5
/// Portion of a stopped hit that counts towards bruising or burning the part underneath.
#define PLATE_WOUND_RATIO 0.5

/// How long fitting a plate into a carrier, or prying one back out, takes. Long enough that swapping
/// one mid-fight is a decision rather than a reflex.
#define PLATE_FITTING_TIME (4 SECONDS)

// How worn a plate is, as a portion of its durability. Only used for examine text and for the noises
// it makes on the way down - the plate works identically at every one of them until it is spent.
/// Marked, but nothing a wearer would think twice about.
#define PLATE_WEAR_SCUFFED 0.75
/// Visibly damaged. Worth swapping out before the next fight.
#define PLATE_WEAR_CRACKED 0.5
/// About to give out.
#define PLATE_WEAR_FAILING 0.25
