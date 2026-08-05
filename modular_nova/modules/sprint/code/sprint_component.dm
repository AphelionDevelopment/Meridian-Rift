/// Stamina spent per running tile, as a percent of max stamina.
#define RUN_STAMINA_COST_PERCENT 0.4
/// Cost multiplier for mobs with [TRAIT_FREERUNNING].
#define RUN_FREERUNNING_MODIFIER 0.7
/// Ground a diagonal step covers. Fills the dust counter faster, but costs no extra stamina.
#define RUN_DIAGONAL_STEP 1.4
/// Tiles held in one direction before a run counts as sustained.
#define RUN_SUSTAINED_THRESHOLD 8
/// Minimum time between dust puffs.
#define RUN_DUST_GRACE (0.5 SECONDS)
/// Percent of max stamina lost that forces a mob down to a walk.
#define RUN_EXHAUSTION_PERCENT 40
/// Percent it must recover past before it can run again.
#define RUN_RECOVERY_PERCENT 30
/// Trait source for the winded lockout.
#define RUN_TRAIT "sprint"

/**
 * # Sprint
 *
 * Makes running fast and tiring, so walking is the free default and running is the deliberate choice.
 *
 * Running spends the mob's ordinary stamina - the same pool tasers and shoves draw from - and kicks up
 * dust. Running out of breath applies [TRAIT_NORUNNING] and drops the mob to a walk until it recovers.
 * There is no separate sprint state: the run intent is the sprint.
 */
/datum/component/sprint
	/// Typed copy of parent.
	var/mob/living/carbon/runner
	/// Tiles run in the current direction.
	var/sustained_moves = 0
	/// world.time of the last dust puff. Zero means this run has not kicked up its first cloud yet.
	var/last_dust = 0

/datum/component/sprint/Initialize()
	. = ..()
	if(!iscarbon(parent))
		return COMPONENT_INCOMPATIBLE
	runner = parent

/datum/component/sprint/Destroy(force)
	STOP_PROCESSING(SSfastprocess, src)
	runner = null
	return ..()

/datum/component/sprint/RegisterWithParent()
	RegisterSignal(parent, COMSIG_MOB_CLIENT_PRE_MOVE, PROC_REF(on_mob_move))
	RegisterSignal(parent, COMSIG_MOVE_INTENT_TOGGLED, PROC_REF(update_pace))
	update_pace()

/datum/component/sprint/UnregisterFromParent()
	reset_dust()
	runner.remove_movespeed_modifier(/datum/movespeed_modifier/run_pace)
	runner.remove_movespeed_modifier(/datum/movespeed_modifier/walk_pace)
	UnregisterSignal(parent, list(COMSIG_MOB_CLIENT_PRE_MOVE, COMSIG_MOVE_INTENT_TOGGLED))

/// Swaps in the speedup for whichever pace the mob is now on.
/datum/component/sprint/proc/update_pace(mob/living/source)
	SIGNAL_HANDLER
	if(runner.move_intent == MOVE_INTENT_RUN)
		runner.remove_movespeed_modifier(/datum/movespeed_modifier/walk_pace)
		runner.add_movespeed_modifier(/datum/movespeed_modifier/run_pace)
		return
	runner.remove_movespeed_modifier(/datum/movespeed_modifier/run_pace)
	runner.add_movespeed_modifier(/datum/movespeed_modifier/walk_pace)
	reset_dust()

/// Charges a running tile and kicks up dust. Walking costs nothing.
/datum/component/sprint/proc/on_mob_move(mob/living/source, list/move_args)
	SIGNAL_HANDLER
	if(runner.move_intent != MOVE_INTENT_RUN)
		return

	var/direction = move_args[MOVE_ARG_DIRECTION]
	var/step_size = ISDIAGONALDIR(direction) ? RUN_DIAGONAL_STEP : 1
	if(!last_dust)
		// The full cloud is only drawn facing south.
		puff(/obj/effect/temp_visual/dir_setting/sprint_dust/cloud, SOUTH)
		sustained_moves += step_size
	else if(world.time > last_dust + RUN_DUST_GRACE)
		handle_sustained_dust(direction, step_size)

	spend_stamina()

/// Clears dust tracking, so the next run starts with a fresh cloud.
/datum/component/sprint/proc/reset_dust()
	sustained_moves = 0
	last_dust = 0

/**
 * Charges one tile against stamina, then re-checks exhaustion.
 *
 * Flat per tile - diagonals cover more ground but cost the same. Forced, so immunity to stamina damage
 * does not also grant endless running.
 */
/datum/component/sprint/proc/spend_stamina()
	var/cost = runner.max_stamina * (RUN_STAMINA_COST_PERCENT / 100)
	if(HAS_TRAIT(runner, TRAIT_FREERUNNING))
		cost *= RUN_FREERUNNING_MODIFIER
	runner.adjust_stamina_loss(cost, forced = TRUE)
	update_winded_state()

/**
 * Puffs dust for a run already underway.
 *
 * Holding a direction puffs once on crossing [RUN_SUSTAINED_THRESHOLD]; turning puffs if the run was
 * already sustained, and doubling back always puffs.
 *
 * Arguments:
 * * direction - direction being moved this tile.
 * * step_size - ground this tile covers.
 */
/datum/component/sprint/proc/handle_sustained_dust(direction, step_size)
	if(direction & runner.last_move)
		if(sustained_moves < RUN_SUSTAINED_THRESHOLD && (sustained_moves + step_size) >= RUN_SUSTAINED_THRESHOLD)
			puff(/obj/effect/temp_visual/dir_setting/sprint_dust/small, direction)
		sustained_moves += step_size
		return

	if(sustained_moves >= RUN_SUSTAINED_THRESHOLD)
		puff(/obj/effect/temp_visual/dir_setting/sprint_dust/small, direction)
	if(direction & turn(runner.last_move, 180))
		puff(/obj/effect/temp_visual/dir_setting/sprint_dust/tiny, direction)
	sustained_moves = 0

/**
 * Kicks up one dust puff and records when, since sustained tracking is gated on it.
 *
 * Arguments:
 * * puff_type - which dust effect to throw out. Carries its own duration.
 * * direction - which way the puff faces.
 */
/datum/component/sprint/proc/puff(puff_type, direction)
	new puff_type(get_turf(runner), direction)
	last_dust = world.time

/**
 * Applies and clears the winded lockout as stamina drains and recovers.
 *
 * Stamina returns in one jump once the mob has gone [/mob/living/var/stamina_regen_time] without taking
 * any, so we process only to notice that jump and lift the lockout.
 */
/datum/component/sprint/proc/update_winded_state()
	var/loss_percent = runner.get_stamina_loss() / runner.max_stamina * 100
	var/winded = HAS_TRAIT_FROM(runner, TRAIT_NORUNNING, RUN_TRAIT)
	if(!winded && loss_percent >= RUN_EXHAUSTION_PERCENT)
		ADD_TRAIT(runner, TRAIT_NORUNNING, RUN_TRAIT)
		to_chat(runner, span_warning("You are too winded to keep running..."))
		if(runner.move_intent == MOVE_INTENT_RUN)
			runner.toggle_move_intent()
		START_PROCESSING(SSfastprocess, src)
		return
	if(winded && loss_percent <= RUN_RECOVERY_PERCENT)
		REMOVE_TRAIT(runner, TRAIT_NORUNNING, RUN_TRAIT)
		to_chat(runner, span_notice("You have caught your breath."))

/datum/component/sprint/process(seconds_per_tick)
	update_winded_state()
	if(!HAS_TRAIT_FROM(runner, TRAIT_NORUNNING, RUN_TRAIT))
		return PROCESS_KILL

#undef RUN_STAMINA_COST_PERCENT
#undef RUN_FREERUNNING_MODIFIER
#undef RUN_DIAGONAL_STEP
#undef RUN_SUSTAINED_THRESHOLD
#undef RUN_DUST_GRACE
#undef RUN_EXHAUSTION_PERCENT
#undef RUN_RECOVERY_PERCENT
#undef RUN_TRAIT
