#define MECHIVER_CORPSE_RANGE 10

/datum/ai_controller/basic_controller/fleshmind
	behavior_tree_json = "modular_nova/modules/fleshmind/code/fleshmind_base.bt.json"
	ai_movement = /datum/ai_movement/jps

	blackboard = list(
		BB_TARGETING_STRATEGY = /datum/targeting_strategy/basic,
		BB_BASIC_MOB_SPEAK_LINES = null,
		BB_AGGRO_RANGE = 14
	)

/datum/ai_controller/basic_controller/fleshmind/globber
	behavior_tree_json = "modular_nova/modules/fleshmind/code/fleshmind_globber.bt.json"
	blackboard = list(
		BB_TARGETING_STRATEGY = /datum/targeting_strategy/basic,
		BB_BASIC_MOB_SPEAK_LINES = null,
		BB_AGGRO_RANGE = 14,
		BB_RANGED_SKIRMISH_MIN_DISTANCE = 3,
		BB_RANGED_SKIRMISH_MAX_DISTANCE = 4,
	)

/datum/ai_controller/basic_controller/fleshmind/floater

/datum/ai_controller/basic_controller/fleshmind/stunner

/datum/ai_controller/basic_controller/fleshmind/treader
	behavior_tree_json = "modular_nova/modules/fleshmind/code/fleshmind_treader.bt.json"
	blackboard = list(
		BB_TARGETING_STRATEGY = /datum/targeting_strategy/basic,
		BB_BASIC_MOB_SPEAK_LINES = null,
		BB_AGGRO_RANGE = 14,
		BB_RANGED_SKIRMISH_MIN_DISTANCE = 3,
		BB_RANGED_SKIRMISH_MAX_DISTANCE = 4,
	)

/datum/ai_controller/basic_controller/fleshmind/mechiver
	behavior_tree_json = "modular_nova/modules/fleshmind/code/fleshmind_mechiver.bt.json"
	blackboard = list(
		BB_TARGETING_STRATEGY = /datum/targeting_strategy/basic,
		BB_BASIC_MOB_STOP_FLEEING = TRUE,
		BB_TARGET_MINIMUM_STAT = HARD_CRIT,
		BB_AGGRO_RANGE = 14,
	)

/datum/ai_controller/basic_controller/fleshmind/phaser
	behavior_tree_json = "modular_nova/modules/fleshmind/code/fleshmind_phaser.bt.json"

/// Clears path blockages without eating our own wireweed.
/datum/bt_node/ai_behavior/attack_obstructions/fleshmind
	can_ignore_step = TRUE

/datum/bt_node/ai_behavior/attack_obstructions/fleshmind/can_smash_object(mob/living/basic/basic_mob, obj/object)
	if(istype(object, /obj/structure/fleshmind))
		return FALSE
	return ..()

/datum/bt_node/ai_behavior/use_mob_ability/dispense_nanites
	ability_key = BB_TREADER_DISPENSE_NANITES

/datum/bt_node/ai_behavior/use_mob_ability/dispense_nanites/get_valid_ability(datum/ai_controller/controller)
	. = ..()
	if(!.)
		return null
	var/mob/living/pawn = controller.pawn
	for(var/mob/living/iterating_mob in view(DEFAULT_VIEW_RANGE, pawn))
		if(iterating_mob.faction_check_atom(pawn) && iterating_mob.health < iterating_mob.maxHealth * 0.5)
			return .
	return null

/**
 * MECHIVER AI
 */

/// Accepts living non-allies weak enough for the mechiver to convert.
/datum/targeting_strategy/fleshmind_incapacitated

/datum/targeting_strategy/fleshmind_incapacitated/is_valid_target(mob/living/living_mob, atom/target, vision_range, datum/ai_controller/controller = null)
	. = ..()
	if(!.)
		return FALSE
	if(!isliving(target) || target == living_mob)
		return FALSE
	var/mob/living/candidate = target
	if(living_mob.faction_check_atom(candidate))
		return FALSE
	return candidate.health < (candidate.maxHealth * MECHIVER_CONSUME_HEALTH_THRESHOLD)

/// Scans for the closest convertable mob, does nothing while we are digesting one.
/datum/bt_node/ai_behavior/acquire_target/update_interaction_target/fleshmind_corpse
	target_key = BB_MECHIVER_DEAD_TARGET
	targeting_strategy = /datum/targeting_strategy/fleshmind_incapacitated
	target_source = /datum/target_source/oview_living
	vision_range = MECHIVER_CORPSE_RANGE
	time_between_perform = 2 SECONDS

/datum/bt_node/ai_behavior/acquire_target/update_interaction_target/fleshmind_corpse/can_search(datum/ai_controller/controller)
	return !controller.blackboard[BB_MECHIVER_CONTAINED_MOB]

/datum/bt_node/ai_behavior/acquire_target/update_interaction_target/fleshmind_corpse/pick_final_target(datum/ai_controller/controller, list/filtered_targets)
	return get_closest_atom(/mob/living, filtered_targets, get_turf(controller.pawn))

/datum/bt_node/ai_behavior/convert_easy_pickings
	var/target_key = BB_MECHIVER_DEAD_TARGET

/datum/bt_node/ai_behavior/convert_easy_pickings/setup(datum/ai_controller/controller)
	. = ..()
	var/mob/living/target = controller.blackboard[target_key]
	if(QDELETED(target))
		return FALSE
	var/mob/living/pawn = controller.pawn
	if(pawn.faction_check_atom(target))
		return FALSE
	if(target.health > (target.maxHealth * MECHIVER_CONSUME_HEALTH_THRESHOLD)) // Don't do this
		return FALSE

/datum/bt_node/ai_behavior/convert_easy_pickings/perform(seconds_per_tick, datum/ai_controller/controller)
	var/mob/living/target = controller.blackboard[target_key]
	var/mob/living/pawn = controller.pawn
	if(QDELETED(target))
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED
	if(!isturf(target.loc)) // Check to make sure the target is reachable.
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED
	if(!pawn.Adjacent(target))
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED

	SEND_SIGNAL(pawn, COMSIG_MECHIVER_CONVERT, target)
	return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

/datum/bt_node/ai_behavior/convert_easy_pickings/finish_action(datum/ai_controller/controller, succeeded)
	. = ..()
	if(succeeded)
		controller.clear_blackboard_key(target_key)

#undef MECHIVER_CORPSE_RANGE
