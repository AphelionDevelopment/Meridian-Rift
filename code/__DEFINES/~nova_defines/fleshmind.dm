// Fleshmind defines, signals and blackboard keys


/// Fleshmind
#define BB_MECHIVER_DEAD_TARGET "mechiver_dead_target"
#define BB_MECHIVER_CONTAINED_MOB "mechiver_contained_mob"
#define BB_TREADER_DISPENSE_NANITES "treader_dispense_nanites"
#define BB_TYRANT_LASER "tyrant_shoot_laser"
#define BB_TYRANT_ROCKET "tyrant_shoot_rocket"

// CORRUPTION SIGNALS

/// From /obj/structure/fleshmind/structure/proc/activate_ability() (src)
#define COMSIG_CORRUPTION_STRUCTURE_ABILITY_TRIGGERED "corruption_structure_ability_triggered"

/// From /mob/living/basic/fleshmind/phaser/proc/phase_move_to(atom/target, nearby = FALSE)
#define COMSIG_PHASER_PHASE_MOVE "phaser_phase_move"
/// from /mob/living/basic/fleshmind/phaser/proc/enter_nearby_closet()
#define COMSIG_PHASER_ENTER_CLOSET "phaser_enter_closet"

/// from /obj/structure/fleshmind/structure/core/proc/rally_troops()
#define COMSIG_FLESHMIND_CORE_RALLY "fleshmind_core_rally"

#define COMSIG_MECHIVER_CONVERT "mechiver_convert"

//#define COMSIG_CORE_DEATH "fleshmind_core_death"

#define ROLE_WIRE_PRIEST "Wire Priest"
