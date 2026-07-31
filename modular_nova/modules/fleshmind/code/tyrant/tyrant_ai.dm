/datum/ai_controller/basic_controller/fleshmind/tyrant
	behavior_tree_json = "modular_nova/modules/fleshmind/code/tyrant/tyrant.bt.json"
	blackboard = list(
		BB_TARGETING_STRATEGY = /datum/targeting_strategy/basic,
		BB_BASIC_MOB_SPEAK_LINES = null,
		BB_AGGRO_RANGE = 14,
		BB_RANGED_SKIRMISH_MIN_DISTANCE = 3,
		BB_RANGED_SKIRMISH_MAX_DISTANCE = 4,
	)

/datum/action/cooldown/mob_cooldown/projectile_attack/tyrant_laser
	name = "Main Laser"
	desc = "Shoot a laser towards a target"
	button_icon = 'icons/obj/weapons/guns/projectiles.dmi'
	button_icon_state = "green_laser"
	cooldown_time = 3 SECONDS
	projectile_type = /obj/projectile/beam/emitter/hitscan/tyrant
	var/list/laser_projectile_sounds = list(
		'modular_nova/modules/fleshmind/sound/tyrant/laser_1.ogg',
		'modular_nova/modules/fleshmind/sound/tyrant/laser_2.ogg',
		'modular_nova/modules/fleshmind/sound/tyrant/laser_3.ogg',
		'modular_nova/modules/fleshmind/sound/tyrant/laser_4.ogg',
		'modular_nova/modules/fleshmind/sound/tyrant/laser_5.ogg',
		'modular_nova/modules/fleshmind/sound/tyrant/laser_6.ogg',
	)

/datum/action/cooldown/mob_cooldown/projectile_attack/tyrant_laser/attack_sequence(mob/living/firer, atom/target)
	playsound(firer, pick(laser_projectile_sounds), 100, TRUE) // shoot_projectile() never plays projectile_sound in this codebase
	return ..()

/obj/projectile/beam/emitter/hitscan/tyrant
	faction = list(FACTION_FLESHMIND)

/datum/action/cooldown/mob_cooldown/projectile_attack/tyrant_rocket
	name = "Shoot Rocket"
	desc = "Shoot a rocket towards a target"
	button_icon = 'icons/obj/weapons/guns/projectiles.dmi'
	button_icon_state = "low_yield_rocket"
	cooldown_time = 3 SECONDS
	projectile_type = /obj/projectile/bullet/rocket/weak/tyrant
	var/launch_sound = 'sound/items/weapons/gun/general/rocket_launch.ogg'
	can_move = FALSE

/datum/action/cooldown/mob_cooldown/projectile_attack/tyrant_rocket/attack_sequence(mob/living/firer, atom/target)
	firer.balloon_alert_to_viewers("begins whirring violently!")
	playsound(firer, 'modular_nova/modules/fleshmind/sound/tyrant/charge_up.ogg', 100, TRUE)
	if(!do_after(firer, 2 SECONDS))
		return
	playsound(firer, launch_sound, 100, TRUE)
	return ..()

/obj/projectile/bullet/rocket/weak/tyrant
	faction = list(FACTION_FLESHMIND)
