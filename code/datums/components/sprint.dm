/// Stamina spent per running tile, as a percent of max running stamina.
#define RUN_STAMINA_COST_PERCENT 2
/// Cost multiplier for mobs with [TRAIT_FREERUNNING].
#define RUN_FREERUNNING_MODIFIER 0.7
/// Ground a diagonal step covers. Fills the dust counter faster, but costs no extra stamina.
#define RUN_DIAGONAL_STEP 1.4
/// Tiles held in one direction before a run counts as sustained.
#define RUN_SUSTAINED_THRESHOLD 8
/// Minimum time between dust puffs.
#define RUN_DUST_GRACE (0.5 SECONDS)
/// Running stamina regained per second once regen has kicked in.
#define RUN_REGEN_PER_SECOND 8
/// How long after the last spent tile before regen kicks in.
#define RUN_REGEN_DELAY (1 SECONDS)
/// Percent of running stamina lost that forces a mob down to a walk.
#define RUN_EXHAUSTION_PERCENT 100
/// Percent it must recover past before it can run again.
#define RUN_RECOVERY_PERCENT 30
/// Trait source for the winded lockout.
#define RUN_TRAIT "sprint"

/**
 * # Sprint
 *
 * Makes running fast and tiring, so walking is the free default and running is the deliberate choice.
 *
 * Running spends a dedicated running-stamina pool - separate from the pain pool tasers, batons and
 * shoves draw from - and kicks up dust. Running out of breath applies [TRAIT_NORUNNING] and drops the
 * mob to a walk until it recovers. There is no separate sprint state: the run intent is the sprint.
 */
/datum/component/sprint
	dupe_mode = COMPONENT_DUPE_UNIQUE
	/// Typed copy of parent.
	var/mob/living/carbon/human/runner
	/// Running stamina spent so far. 0 is fresh, max_stamina is winded.
	var/stamina_loss = 0
	/// Running stamina pool size.
	var/max_stamina = 100
	/// world.time of the last tile spent. Regen only starts once this has been quiet for RUN_REGEN_DELAY.
	var/last_spend = 0
	/// Tiles run in the current direction.
	var/sustained_moves = 0
	/// world.time of the last dust puff. Zero means this run has not kicked up its first cloud yet.
	var/last_dust = 0

/datum/component/sprint/Initialize()
	. = ..()
	if(!ishuman(parent))
		return COMPONENT_INCOMPATIBLE
	runner = parent

/datum/component/sprint/Destroy(force)
	STOP_PROCESSING(SSfastprocess, src)
	// The parent unhooks us from the mob, which UnregisterFromParent() still needs runner for
	. = ..()
	runner = null

/datum/component/sprint/RegisterWithParent()
	RegisterSignal(parent, COMSIG_MOB_CLIENT_PRE_MOVE, PROC_REF(on_mob_move))
	RegisterSignal(parent, COMSIG_MOVE_INTENT_TOGGLED, PROC_REF(on_intent_toggled))
	RegisterSignal(parent, COMSIG_LIVING_ADJUST_SPRINT_STAMINA, PROC_REF(on_adjust_sprint_stamina))
	RegisterSignal(parent, COMSIG_LIVING_GET_SPRINT_STAMINA_LOSS, PROC_REF(on_get_sprint_stamina_loss)) // APHELION EDIT ADDITION - SPRINT-STAMINA
	RegisterSignal(parent, COMSIG_LIVING_IS_SPRINT_STAMINA_EXHAUSTED, PROC_REF(on_is_sprint_stamina_exhausted))
	update_stamina_hud()

/datum/component/sprint/UnregisterFromParent()
	STOP_PROCESSING(SSfastprocess, src)
	reset_dust()
	UnregisterSignal(parent, list(COMSIG_MOB_CLIENT_PRE_MOVE, COMSIG_MOVE_INTENT_TOGGLED, COMSIG_LIVING_ADJUST_SPRINT_STAMINA, COMSIG_LIVING_GET_SPRINT_STAMINA_LOSS, COMSIG_LIVING_IS_SPRINT_STAMINA_EXHAUSTED)) // APHELION EDIT CHANGE - SPRINT-STAMINA - ORIGINAL: UnregisterSignal(parent, list(COMSIG_MOB_CLIENT_PRE_MOVE, COMSIG_MOVE_INTENT_TOGGLED, COMSIG_LIVING_ADJUST_SPRINT_STAMINA, COMSIG_LIVING_IS_SPRINT_STAMINA_EXHAUSTED))

/// Drops the dust trail when the mob leaves a run, so the next one starts on a fresh cloud. The pace itself comes from the mob's move intent modifier.
/datum/component/sprint/proc/on_intent_toggled(mob/living/source)
	SIGNAL_HANDLER
	if(runner.move_intent != MOVE_INTENT_RUN)
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

/// Spends sprint stamina requested by another system.
/datum/component/sprint/proc/on_adjust_sprint_stamina(mob/living/source, amount)
	SIGNAL_HANDLER
	if(amount > 0)
		last_spend = world.time
		START_PROCESSING(SSfastprocess, src)
	adjust_stamina_loss(amount)

/// Stores the current sprint stamina loss in the query list.
/datum/component/sprint/proc/on_get_sprint_stamina_loss(mob/living/source, list/stamina_loss)
	SIGNAL_HANDLER
	stamina_loss[1] = src.stamina_loss

/// Reports whether the sprint stamina pool is exhausted.
/datum/component/sprint/proc/on_is_sprint_stamina_exhausted(mob/living/source)
	SIGNAL_HANDLER
	return stamina_loss >= max_stamina ? COMPONENT_SPRINT_EXHAUSTED : NONE

/// Clears dust tracking, so the next run starts with a fresh cloud.
/datum/component/sprint/proc/reset_dust()
	sustained_moves = 0
	last_dust = 0

/**
 * Charges one tile against running stamina, then re-checks exhaustion.
 *
 * Flat per tile - diagonals cover more ground but cost the same.
 */
/datum/component/sprint/proc/spend_stamina()
	var/cost = max_stamina * (RUN_STAMINA_COST_PERCENT / 100)
	if(HAS_TRAIT(runner, TRAIT_FREERUNNING))
		cost *= RUN_FREERUNNING_MODIFIER
	last_spend = world.time
	adjust_stamina_loss(cost)
	START_PROCESSING(SSfastprocess, src)

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

/// Adjusts stamina loss, clamped to the pool, redraws the HUD, and rechecks the winded lockout.
/datum/component/sprint/proc/adjust_stamina_loss(amount)
	stamina_loss = clamp(stamina_loss + amount, 0, max_stamina)
	update_stamina_hud()
	update_winded_state()

/**
 * Applies and clears the winded lockout as running stamina drains and recovers.
 */
/datum/component/sprint/proc/update_winded_state()
	var/loss_percent = stamina_loss / max_stamina * 100
	var/winded = HAS_TRAIT_FROM(runner, TRAIT_NORUNNING, RUN_TRAIT)
	if(!winded && loss_percent >= RUN_EXHAUSTION_PERCENT)
		ADD_TRAIT(runner, TRAIT_NORUNNING, RUN_TRAIT)
		to_chat(runner, span_warning("You are too winded to keep running..."))
		if(runner.move_intent == MOVE_INTENT_RUN)
			runner.toggle_move_intent()
		return
	if(winded && loss_percent <= RUN_RECOVERY_PERCENT)
		REMOVE_TRAIT(runner, TRAIT_NORUNNING, RUN_TRAIT)
		to_chat(runner, span_notice("You have caught your breath."))

/// Redraws the running-stamina meter. Full and empty share the stamina bar's icon states.
/datum/component/sprint/proc/update_stamina_hud()
	if(!runner.client || !runner.hud_used)
		return

	var/atom/movable/screen/run_stamina/meter = runner.hud_used.screen_objects[HUD_MOB_RUN_STAMINA]
	if(isnull(meter))
		return

	if(runner.stat == DEAD)
		meter.icon_state = "stamina_dead"
	else if(stamina_loss <= 0)
		meter.icon_state = "stamina_full"
	else if(stamina_loss >= max_stamina)
		meter.icon_state = "stamina_crit"
	else
		meter.icon_state = "stamina_[ceil(stamina_loss / (max_stamina * 0.2))]"

/// Regenerates running stamina once it has gone quiet for RUN_REGEN_DELAY.
/datum/component/sprint/process(seconds_per_tick)
	if(world.time < last_spend + RUN_REGEN_DELAY)
		return
	adjust_stamina_loss(-RUN_REGEN_PER_SECOND * seconds_per_tick)
	if(stamina_loss <= 0)
		return PROCESS_KILL

#undef RUN_STAMINA_COST_PERCENT
#undef RUN_FREERUNNING_MODIFIER
#undef RUN_DIAGONAL_STEP
#undef RUN_SUSTAINED_THRESHOLD
#undef RUN_DUST_GRACE
#undef RUN_REGEN_PER_SECOND
#undef RUN_REGEN_DELAY
#undef RUN_EXHAUSTION_PERCENT
#undef RUN_RECOVERY_PERCENT
#undef RUN_TRAIT
