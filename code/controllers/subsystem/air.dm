/// How many active_turfs entries process_active_turfs()'s legacy per-cycle walk (archive/current_cycle/
/// temperature_expose/stability check) processes per fire() cycle, round-robin. Bounds the walk's own
/// cost so it can never grow unboundedly with active_turfs size and starve the actual gas FDM call of
/// its tick budget - the 2026-08-14 playtest regression (turfs extremely resistant to gas/heat
/// exchange, non-functional breaches) traced to exactly this: the walk was unconditionally full-list
/// and MC_TICK_CHECK-un-gated by design, active_turfs grew from ~1700 to ~3800 turfs over one session
/// (it is never shrunk on its own; see the stability check this same fix adds), and the walk's own
/// growing cost pushed TICK_USAGE past Master.current_ticklimit before the FDM call's remaining_ms was
/// (re-)computed, so process_turfs_auxtools() received a near-zero or negative budget on most cycles
/// despite measuring real cost. 400 keeps the worst-case walk cost well under what was observed for
/// the full ~3800-turf list (~24ms), leaving the bulk of the tick for the FDM call regardless of how
/// large active_turfs grows.
#define ACTIVE_TURFS_WALK_BATCH_SIZE 400

SUBSYSTEM_DEF(air)
	name = "Atmospherics"
	dependencies = list(
		/datum/controller/subsystem/dogmos,
		/datum/controller/subsystem/mapping,
		/datum/controller/subsystem/atoms,
	)
	priority = FIRE_PRIORITY_AIR
	wait = 0.5 SECONDS
	ss_flags = SS_BACKGROUND
	runlevels = RUNLEVEL_GAME | RUNLEVEL_POSTGAME

	var/cached_cost = 0

	var/cost_atoms = 0
	var/cost_turfs = 0
	var/cost_hotspots = 0
	var/cost_groups = 0
	var/cost_highpressure = 0
	var/cost_superconductivity = 0
	var/cost_pipenets = 0
	var/cost_atmos_machinery = 0
	var/cost_rebuilds = 0
	var/cost_adjacent = 0
	/// Cost of Dogmos' post_process() pass (reactions + visuals dispatch after a gas FDM cycle).
	/// Read/written by process_turfs_auxtools (aphelion-dogmos src/turfs/processing.rs) - unused
	/// until SSAIR_ACTIVETURFS cuts over to Rust.
	var/cost_post_process = 0
	/// Cost of Dogmos' katmos pressure-equalization pass. Read/written by
	/// process_turf_equalize_auxtools (src/turfs/katmos.rs) - unused until SSAIR_HIGHPRESSURE cuts over.
	var/cost_equalize = 0

	/// Max FDM (finite-difference gas diffusion) iterations per process_turfs_auxtools call. Read by
	/// Rust (src/turfs/processing.rs); unused until SSAIR_ACTIVETURFS cuts over.
	var/share_max_steps = 1
	/// Whether Dogmos' katmos pressure equalizer runs as part of the gas FDM pass. Turned on as of the
	/// SSAIR_HIGHPRESSURE cutover - see process_high_pressure_delta() for the consumer.
	var/equalize_enabled = TRUE
	/// Ratio of a turf's gas shared with its planetary atmosphere per FDM cycle. Mirrors Rust's own
	/// internal GAS_DIFFUSION_CONSTANT (1/8) so DM's declared default matches what Rust would fall
	/// back to if this var didn't exist at all. Read by Rust; unused until SSAIR_ACTIVETURFS cuts over.
	var/planet_share_ratio = 0.125
	/// How many turfs Dogmos' last gas FDM pass flagged as low pressure (stable, camera-eligible for
	/// excited-group processing). Write-only telemetry from Rust; unused until SSAIR_ACTIVETURFS
	/// cuts over.
	var/low_pressure_turfs = 0
	/// As low_pressure_turfs, for turfs flagged high pressure (feeds katmos equalization once
	/// equalize_enabled is on). Write-only telemetry from Rust.
	var/high_pressure_turfs = 0
	/// Pressure delta threshold Dogmos' excited-group processor treats as "converged enough to stop".
	/// Read by Rust (src/turfs/groups.rs); unused until SSAIR_EXCITEDGROUPS cuts over.
	var/excited_group_pressure_goal = 0.5
	/// How many turfs Dogmos' last excited-group pass processed. Write-only telemetry from Rust.
	var/num_group_turfs_processed = 0
	/// Ceiling on how many turfs a single katmos equalize pass will touch before bailing, to bound
	/// worst-case cost on a large pressure event. Read by Rust (src/turfs/katmos.rs); unused until
	/// SSAIR_HIGHPRESSURE cuts over.
	var/equalize_hard_turf_limit = 2000
	/// How many turfs Dogmos' last katmos equalize pass processed. Write-only telemetry from Rust.
	var/num_equalize_processed = 0

	var/list/excited_groups = list()
	var/list/active_turfs = list()
	/// Round-robin cursor into active_turfs for the legacy per-cycle walk (archive/current_cycle/
	/// temperature_expose/stability check, process_active_turfs()) - see ACTIVE_TURFS_WALK_BATCH_SIZE.
	var/active_turfs_walk_cursor = 0
	var/list/hotspots = list()
	var/list/networks = list()
	var/list/rebuild_queue = list()
	//Subservient to rebuild queue
	var/list/expansion_queue = list()
	/// List of turfs to recalculate adjacent turfs on before processing
	var/list/adjacent_rebuild = list()
	/// A list of machines that will be processed when currentpart == SSAIR_ATMOSMACHINERY. Use SSair.begin_processing_machine and SSair.stop_processing_machine to add and remove machines.
	var/list/obj/machinery/atmos_machinery = list()

	var/list/pipe_init_dirs_cache = list()
	//atmos singletons
	var/list/gas_reactions = list()
	/// Flat, uniquely-prioritised view of gas_reactions. Read by Dogmos; see init_dogmos_reactions().
	var/list/dogmos_reactions = list()
	var/list/atmos_gen
	var/list/planetary = list() //Lets cache static planetary mixes
	/// List of gas string -> canonical gas mixture
	var/list/strings_to_mix = list()


	//Special functions lists
	var/list/turf/open/high_pressure_delta = list()
	var/list/atom_process = list()
	/// Reactions which will contribute to a hotspot's size.
	var/list/hotspot_reactions

	/// A cache of objects that perisists between processing runs when resumed == TRUE. Dangerous, qdel'd objects not cleared from this may cause runtimes on processing.
	var/list/currentrun = list()
	var/currentpart = SSAIR_PIPENETS

	var/map_loading = TRUE
	var/list/queued_for_activation
	var/display_all_groups = FALSE

	var/list/reaction_handbook
	var/list/gas_handbook


/datum/controller/subsystem/air/stat_entry(msg)
	msg += "\n  Cost:{"
	msg += "AT:[round(cost_turfs,1)]|"
	msg += "HS:[round(cost_hotspots,1)]|"
	msg += "EG:[round(cost_groups,1)]|"
	msg += "HP:[round(cost_highpressure,1)]|"
	msg += "SC:[round(cost_superconductivity,1)]|"
	msg += "PN:[round(cost_pipenets,1)]|"
	msg += "AM:[round(cost_atmos_machinery,1)]|"
	msg += "AO:[round(cost_atoms, 1)]|"
	msg += "RB:[round(cost_rebuilds,1)]|"
	msg += "AJ:[round(cost_adjacent,1)]|"
	msg += "} "
	msg += "\n  Count:{AT:[active_turfs.len]|"
	msg += "HS:[hotspots.len]|"
	msg += "EG:[excited_groups.len]|"
	msg += "HP:[high_pressure_delta.len]|"
	msg += "SC:[dogmos_heat_graph_count()]|"
	msg += "PN:[networks.len]|"
	msg += "AM:[atmos_machinery.len]|"
	msg += "AO:[atom_process.len]|"
	msg += "RB:[rebuild_queue.len]|"
	msg += "EP:[expansion_queue.len]|"
	msg += "AJ:[adjacent_rebuild.len]|"
	msg += "AT/MS:[round((cost ? active_turfs.len/cost : 0),0.1)]"
	msg += "}"
	return ..()


/datum/controller/subsystem/air/Initialize()
	map_loading = FALSE
	// gas_reactions, dogmos_reactions and the Dogmos gas registry are built by SSdogmos at
	// INITSTAGE_EARLY - they have to exist before the first turf builds its air. See dogmos.dm.
	hotspot_reactions = init_hotspot_reactions()

	setup_allturfs()
	setup_atmos_machinery()
	setup_pipenets()
	setup_turf_visuals()
	process_adjacent_rebuild()
	atmos_handbooks_init()
	return SS_INIT_SUCCESS


/datum/controller/subsystem/air/fire(resumed = FALSE)
	var/timer = TICK_USAGE_REAL

	//Rebuilds can happen at any time, so this needs to be done outside of the normal system
	cost_rebuilds = 0
	cost_adjacent = 0

	// We need to have a solid setup for turfs before fire, otherwise we'll get massive runtimes and strange behavior
	if(length(adjacent_rebuild))
		timer = TICK_USAGE_REAL
		process_adjacent_rebuild()
		//This does mean that the apperent rebuild costs fluctuate very quickly, this is just the cost of having them always process, no matter what
		cost_adjacent = TICK_USAGE_REAL - timer
		if(state != SS_RUNNING)
			return

	// Every time we fire, we want to make sure pipenets are rebuilt. The game state could have changed between each fire() proc call
	// and anything missing a pipenet can lead to unintended behaviour at worse and various runtimes at best.
	if(length(rebuild_queue) || length(expansion_queue))
		timer = TICK_USAGE_REAL
		process_rebuilds()
		//This does mean that the apperent rebuild costs fluctuate very quickly, this is just the cost of having them always process, no matter what
		cost_rebuilds = TICK_USAGE_REAL - timer
		if(state != SS_RUNNING)
			return

	if(currentpart == SSAIR_PIPENETS || !resumed)
		timer = TICK_USAGE_REAL
		if(!resumed)
			cached_cost = 0
		process_pipenets(resumed)
		cached_cost += TICK_USAGE_REAL - timer
		if(state != SS_RUNNING)
			return
		cost_pipenets = MC_AVERAGE(cost_pipenets, TICK_DELTA_TO_MS(cached_cost))
		resumed = FALSE
		currentpart = SSAIR_ATMOSMACHINERY

	if(currentpart == SSAIR_ATMOSMACHINERY)
		timer = TICK_USAGE_REAL
		if(!resumed)
			cached_cost = 0
		process_atmos_machinery(resumed)
		cached_cost += TICK_USAGE_REAL - timer
		if(state != SS_RUNNING)
			return
		cost_atmos_machinery = MC_AVERAGE(cost_atmos_machinery, TICK_DELTA_TO_MS(cached_cost))
		resumed = FALSE
		currentpart = SSAIR_ACTIVETURFS

	if(currentpart == SSAIR_ACTIVETURFS)
		timer = TICK_USAGE_REAL
		if(!resumed)
			cached_cost = 0
		process_active_turfs(resumed)
		cached_cost += TICK_USAGE_REAL - timer
		if(state != SS_RUNNING)
			return
		cost_turfs = MC_AVERAGE(cost_turfs, TICK_DELTA_TO_MS(cached_cost))
		resumed = FALSE
		currentpart = SSAIR_HOTSPOTS

	if(currentpart == SSAIR_HOTSPOTS) //We do this before excited groups to allow breakdowns to be independent of adding turfs while still *mostly preventing mass fires
		timer = TICK_USAGE_REAL
		if(!resumed)
			cached_cost = 0
		process_hotspots(resumed)
		cached_cost += TICK_USAGE_REAL - timer
		if(state != SS_RUNNING)
			return
		cost_hotspots = MC_AVERAGE(cost_hotspots, TICK_DELTA_TO_MS(cached_cost))
		resumed = FALSE
		currentpart = SSAIR_EXCITEDGROUPS

	if(currentpart == SSAIR_EXCITEDGROUPS)
		timer = TICK_USAGE_REAL
		if(!resumed)
			cached_cost = 0
		process_excited_groups(resumed)
		cached_cost += TICK_USAGE_REAL - timer
		if(state != SS_RUNNING)
			return
		cost_groups = MC_AVERAGE(cost_groups, TICK_DELTA_TO_MS(cached_cost))
		resumed = FALSE
		currentpart = SSAIR_HIGHPRESSURE

	if(currentpart == SSAIR_HIGHPRESSURE)
		timer = TICK_USAGE_REAL
		if(!resumed)
			cached_cost = 0
		process_high_pressure_delta(resumed)
		cached_cost += TICK_USAGE_REAL - timer
		if(state != SS_RUNNING)
			return
		cost_highpressure = MC_AVERAGE(cost_highpressure, TICK_DELTA_TO_MS(cached_cost))
		resumed = FALSE
		currentpart = SSAIR_SUPERCONDUCTIVITY

	if(currentpart == SSAIR_SUPERCONDUCTIVITY)
		// cost_superconductivity is NOT re-averaged from TICK_USAGE_REAL here, unlike every other
		// stage: process_super_conductivity()/process_turf_heat() is fire-and-forget (see its doc
		// comment) and returns near-instantly, so a DM-side wall-clock measurement of this call would
		// be near-zero every cycle and would drown out Rust's own deferred EWMA write to that var
		// (superconduct.rs, written whenever the background thread's callback actually drains) rather
		// than reflecting real cost the way the blocking stages' measurements do.
		process_super_conductivity(resumed)
		if(state != SS_RUNNING)
			return
		resumed = FALSE
		currentpart = SSAIR_PROCESS_ATOMS

	if(currentpart == SSAIR_PROCESS_ATOMS)
		timer = TICK_USAGE_REAL
		if(!resumed)
			cached_cost = 0
		process_atoms(resumed)
		cached_cost += TICK_USAGE_REAL - timer
		if(state != SS_RUNNING)
			return
		cost_atoms = MC_AVERAGE(cost_atoms, TICK_DELTA_TO_MS(cached_cost))
		resumed = FALSE


	currentpart = SSAIR_PIPENETS
	SStgui.update_uis(SSair) //Lightning fast debugging motherfucker

/datum/controller/subsystem/air/Recover()
	excited_groups = SSair.excited_groups
	active_turfs = SSair.active_turfs
	hotspots = SSair.hotspots
	networks = SSair.networks
	rebuild_queue = SSair.rebuild_queue
	expansion_queue = SSair.expansion_queue
	adjacent_rebuild = SSair.adjacent_rebuild
	atmos_machinery = SSair.atmos_machinery
	pipe_init_dirs_cache = SSair.pipe_init_dirs_cache
	gas_reactions = SSair.gas_reactions
	atmos_gen = SSair.atmos_gen
	planetary = SSair.planetary
	high_pressure_delta = SSair.high_pressure_delta
	atom_process = SSair.atom_process
	currentrun = SSair.currentrun
	queued_for_activation = SSair.queued_for_activation

/datum/controller/subsystem/air/proc/process_adjacent_rebuild(init = FALSE)
	var/list/queue = adjacent_rebuild

	while (length(queue))
		var/turf/currT = queue[1]
		var/goal = queue[currT]
		queue.Cut(1,2)

		currT.immediate_calculate_adjacent_turfs()
		if(goal == MAKE_ACTIVE)
			add_to_active(currT)
		else if(goal == KILL_EXCITED)
			add_to_active(currT, TRUE)

		if(init)
			CHECK_TICK
		else
			if(MC_TICK_CHECK)
				break

/datum/controller/subsystem/air/proc/process_pipenets(resumed = FALSE)
	if (!resumed)
		src.currentrun = networks.Copy()
	//cache for sanic speed (lists are references anyways)
	var/list/currentrun = src.currentrun
	while(currentrun.len)
		var/datum/thing = currentrun[currentrun.len]
		currentrun.len--
		if(thing)
			thing.process()
		else
			networks.Remove(thing)
		if(MC_TICK_CHECK)
			return

/datum/controller/subsystem/air/proc/add_to_rebuild_queue(obj/machinery/atmospherics/atmos_machine)
	if(istype(atmos_machine, /obj/machinery/atmospherics) && !atmos_machine.rebuilding)
		rebuild_queue += atmos_machine
		atmos_machine.rebuilding = TRUE

/datum/controller/subsystem/air/proc/add_to_expansion(datum/pipeline/line, starting_point)
	var/list/new_packet = new(SSAIR_REBUILD_QUEUE)
	new_packet[SSAIR_REBUILD_PIPELINE] = line
	new_packet[SSAIR_REBUILD_QUEUE] = list(starting_point)
	expansion_queue += list(new_packet)

/datum/controller/subsystem/air/proc/remove_from_expansion(datum/pipeline/line)
	for(var/list/packet in expansion_queue)
		if(packet[SSAIR_REBUILD_PIPELINE] == line)
			expansion_queue -= packet
			return

/datum/controller/subsystem/air/proc/process_atoms(resumed = FALSE)
	if(!resumed)
		src.currentrun = atom_process.Copy()
	//cache for sanic speed (lists are references anyways)
	var/list/currentrun = src.currentrun
	while(currentrun.len)
		var/atom/talk_to = currentrun[currentrun.len]
		currentrun.len--
		if(!talk_to)
			return
		talk_to.process_exposure()
		if(MC_TICK_CHECK)
			return

/datum/controller/subsystem/air/proc/process_atmos_machinery(resumed = FALSE)
	if (!resumed)
		src.currentrun = atmos_machinery.Copy()
	//cache for sanic speed (lists are references anyways)
	var/list/currentrun = src.currentrun
	while(currentrun.len)
		var/obj/machinery/M = currentrun[currentrun.len]
		currentrun.len--
		if(!M)
			atmos_machinery -= M
		if(M.process_atmos(wait * 0.1) == PROCESS_KILL)
			stop_processing_machine(M)
		if(MC_TICK_CHECK)
			return


/**
 * Turf-to-turf heat conduction is now Rust's job (process_turf_heat, aphelion-dogmos
 * src/turfs/superconduct.rs) - a full graph sweep on a persistent background thread, not a per-turf
 * DM walk. Unlike every other Dogmos stage in this file, this is fire-and-forget, not a
 * budget/pause()/resume cycle:
 * * process_turf_heat() reads SSair.wait, notifies the worker thread over a bounded(1) channel via a
 *   non-blocking try_send, and always returns immediately - there is no "did it finish" signal to wait
 *   on, and no remaining-budget argument to pass.
 * * If the worker is still busy processing the previous cycle's notify, this send is silently
 *   dropped - the next cycle's notify (0.5s later) picks it back up. This is an accepted, self-correcting
 *   skip, not an error condition worth detecting.
 * * SSair.cost_superconductivity is written directly by the Rust worker as its own EWMA (matching
 *   cost_post_process/cost_equalize's existing pattern) - do not average TICK_DELTA_TO_MS(cached_cost)
 *   into it here, that would double-account a cost this proc doesn't actually spend.
 * * Rust's deferred to_be_destroyed = TRUE write (the melt-trigger side effect, LINDA_turf_tile.dm's
 *   atmos_expose()/burn_turf()) rides the SAME auxcallback queue finish_turf_processing_auxtools()
 *   already drains every cycle in process_active_turfs() (SSAIR_ACTIVETURFS) - no separate drain call
 *   is needed here.
 */
/datum/controller/subsystem/air/proc/process_super_conductivity(resumed = FALSE)
	process_turf_heat()

/datum/controller/subsystem/air/proc/process_hotspots(resumed = FALSE)
	if (!resumed)
		src.currentrun = hotspots.Copy()
	//cache for sanic speed (lists are references anyways)
	var/list/currentrun = src.currentrun
	while(currentrun.len)
		var/obj/effect/hotspot/H = currentrun[currentrun.len]
		currentrun.len--
		if (H)
			H.process()
		else
			hotspots -= H
		if(MC_TICK_CHECK)
			return

/**
 * Real pressure equalization for "high pressure" turfs (the FDM pass's other output set, alongside
 * SSAIR_EXCITEDGROUPS's low_pressure_turfs) is now Rust's job too - process_turf_equalize_auxtools
 * (aphelion-dogmos src/turfs/katmos.rs) runs a monstermos-style flood-fill/redistribution pass instead
 * of the naive single-cell diffusion step the gas FDM pass would otherwise have done for these turfs
 * (equalize_enabled gates that off - see process_turf_hook in processing.rs). This also activates
 * katmos's hull-breach handling (explosively_depressurize()): the DM-side of that -
 * consider_firelocks() and handle_decompression_floor_rip(), LINDA_turf_tile.dm - plus firelock-edge
 * detection (atmos_adjacency_flags_with(), LINDA_system.dm) were added alongside this cutover, real
 * feature work rather than a stub, per Zoe's call.
 *
 * high_pressure_movements() (the "spacewind" push-movables-around mechanic) is UNCHANGED and needs no
 * porting: both the FDM's own non-equalize branch and katmos's finalize step ultimately call the same
 * existing /turf/open/proc/consider_pressure_difference(), which is what populates high_pressure_delta
 * below. Note the one-cycle latency this introduces: consider_pressure_difference calls made by katmos
 * are queued auxcallbacks (auxcallback::byond_callback_sender), drained by
 * finish_turf_processing_auxtools() - which only runs once per fire() cycle, in the earlier
 * SSAIR_ACTIVETURFS stage. So a pressure-difference callback queued by THIS cycle's equalize pass
 * (which runs after ACTIVETURFS) isn't drained until next cycle's ACTIVETURFS call, and the movables
 * push it produces lags by one fire() cycle (0.5s). Accepted, not fixed - the whole port is already
 * eventually-consistent across fire() stages, and this is a bounded, self-correcting one-cycle delay,
 * not a starvation risk.
 */
/datum/controller/subsystem/air/proc/process_high_pressure_delta(resumed = FALSE)
	if(!resumed)
		var/remaining_ms = TICK_DELTA_TO_MS(Master.current_ticklimit - TICK_USAGE)
		if(process_turf_equalize_auxtools(remaining_ms))
			pause() // ran out of budget mid-equalize - resume next fire()
			return

	while (high_pressure_delta.len)
		var/turf/open/T = high_pressure_delta[high_pressure_delta.len]
		high_pressure_delta.len--
		T.high_pressure_movements()
		T.pressure_difference = 0
		if(MC_TICK_CHECK)
			return

/**
 * Gas sharing/reactions/visuals for active_turfs are now Rust's job (process_turfs_auxtools /
 * finish_turf_processing_auxtools, aphelion-dogmos src/turfs/processing.rs) - Rust scans its own
 * TurfGases graph in full every cycle rather than working off active_turfs at all, so none of the
 * old per-turf iteration here is gas-processing anymore.
 *
 * What's left is every non-gas-math side effect process_cell() (LINDA_turf_tile.dm, now deleted) used
 * to produce for every active turf, none of which Rust's FDM pass knows to do on DM's behalf:
 * * archive() (via LINDA_CYCLE_ARCHIVE) - archives turf.air; archived_cycle is read by this same walk's
 *   own gate below, and by finish_turf_processing_auxtools()'s reaction pass.
 * * current_cycle - read by /obj/effect/hotspot/Initialize() (LINDA_fire.dm) to decide whether a
 *   just-spawned hotspot is still within its parent turf's current processing cycle.
 * * temperature_expose(air, temperature) - the general atom-exposure hook (COMSIG_TURF_EXPOSE,
 *   check_atmos_process()) that lets mobs/items ignite or take damage from standing in hot air, wholly
 *   separate from hotspot objects (SSAIR_HOTSPOTS) and never called by Rust's FDM/post_process().
 *
 * consider_superconductivity() - the old per-turf trigger that added a turf to active_super_conductivity -
 * is gone along with DM's own superconduction walk (SSAIR_SUPERCONDUCTIVITY cutover). Rust's heat
 * worker (process_turf_heat, aphelion-dogmos src/turfs/superconduct.rs) scans its whole TurfHeat graph
 * on its own schedule every cycle; it was never driven by this walk in the first place, so nothing
 * needs to replace the trigger.
 *
 * 2026-08-14 playtest regression, fixed here: this walk used to be unconditional (every entry, every
 * cycle) and deliberately NOT MC_TICK_CHECK-gated, reasoning that gating it risked starving the FDM
 * call below it of tick budget. That reasoning was backwards, and it took a real ~2.5 hour session to
 * show why: active_turfs is never shrunk (still true - see turf_settled() below, which now actually
 * fixes that rather than just noting it), so it grew from ~1700 to ~3800 turfs over one round, and the
 * walk's own un-gated, un-bounded cost grew right along with it - directly inflating TICK_USAGE before
 * `remaining_ms` was (originally) computed ONCE at the top of this proc, ahead of the walk. By the time
 * the actual FDM call ran, TICK_USAGE had already climbed past Master.current_ticklimit most cycles,
 * so process_turfs_auxtools() received a near-zero or negative budget - Rust's Duration::from_millis()
 * saturates a negative float to 0, so the FDM loop's very first budget check broke it before any real
 * diffusion happened, even though the walk itself measured real, growing cost every cycle. Symptom:
 * turfs extremely resistant to both gas and heat exchange (heat mostly rides on gas-carried thermal
 * energy for ordinary open-room spread, so a starved FDM breaks both), and non-functional breaches
 * (space-adjacent sharing is also the FDM's job). Fixed two ways together:
 * 1. The walk now processes a bounded batch per cycle (ACTIVE_TURFS_WALK_BATCH_SIZE, round-robin via
 *    active_turfs_walk_cursor) instead of the whole list, so its cost can no longer grow unboundedly.
 * 2. `remaining_ms` is now computed fresh immediately before EACH Rust call (not once, before the
 *    walk), so neither call ever sees a budget that's gone stale relative to what the walk (now bounded
 *    anyway) or the previous Rust call actually spent.
 */
/datum/controller/subsystem/air/proc/process_active_turfs(resumed = FALSE)
	if(!resumed)
		walk_active_turfs_batch()
		process_turfs_auxtools(TICK_DELTA_TO_MS(Master.current_ticklimit - TICK_USAGE))

	if(finish_turf_processing_auxtools(TICK_DELTA_TO_MS(Master.current_ticklimit - TICK_USAGE)))
		pause() // still draining queued reactions/visuals/pressure-difference callbacks - resume next fire()

/**
 * Processes up to ACTIVE_TURFS_WALK_BATCH_SIZE entries of active_turfs, round-robin via
 * active_turfs_walk_cursor so every turf gets visited periodically without ever walking the whole
 * (potentially thousands-long) list in one cycle. Snapshots the slice before mutating active_turfs
 * (turf_settled() removals below shift list indices, which would corrupt an in-progress index-based
 * walk over the live list).
 */
/datum/controller/subsystem/air/proc/walk_active_turfs_batch()
	var/list/turfs = active_turfs
	var/turf_count = length(turfs)
	if(!turf_count)
		active_turfs_walk_cursor = 0
		return

	if(active_turfs_walk_cursor >= turf_count)
		active_turfs_walk_cursor = 0

	var/batch_end = min(active_turfs_walk_cursor + ACTIVE_TURFS_WALK_BATCH_SIZE, turf_count)
	var/list/batch = turfs.Copy(active_turfs_walk_cursor + 1, batch_end + 1)

	for(var/turf/open/T as anything in batch)
		if(!T)
			continue
		if(T.archived_cycle < times_fired)
			LINDA_CYCLE_ARCHIVE(T)
		T.current_cycle = times_fired
		T.temperature_expose(T.air, T.air.return_temperature())
		if(turf_settled(T))
			remove_from_active(T)

	// active_turfs may have shrunk (turf_settled() removals above) since batch_end was computed against
	// the pre-walk length - clamp instead of leaving the cursor past the new end, which would just
	// wrap on the NEXT call anyway but would skip that check here.
	active_turfs_walk_cursor = (batch_end >= length(active_turfs)) ? 0 : batch_end

/**
 * Whether T has actually settled: its gas no longer differs meaningfully from any gas-adjacent
 * neighbor's (reusing gas_mixture/compare() - "true if the two mixtures are different enough for
 * processing" per its own doc comment, the same check setup_allturfs() already uses for its roundstart
 * stability pass), and no active hotspot is burning on it. Does NOT check air.reaction_results - that
 * list is a cumulative, never-cleared historical record (explosion/doppler-array post-mortem data via
 * SET_REACTION_RESULTS), not a "still reacting this cycle" flag; a turf that reacted once, ever, would
 * never be considered settled again. An actively-reacting mixture's composition keeps diverging from
 * its neighbors' anyway, so the compare() check below already catches it without needing a separate
 * reaction signal. A settled turf gains nothing from continuing to occupy a slot in
 * active_turfs - Rust's own FDM pass doesn't consume that list at all (it scans its whole registered
 * graph independently, gated by its own per-turf should_process() check), so removing a settled turf
 * here only stops the DM-side legacy walk's bookkeeping for it, not any actual physics. Turfs that
 * become active again later are correctly re-added by the existing SSair.add_to_active() call sites
 * (LINDA_system.dm, LINDA_fire.dm, canister/valve release paths) the moment something disturbs them.
 */
/datum/controller/subsystem/air/proc/turf_settled(turf/open/T)
	if(T.active_hotspot)
		return FALSE
	for(var/turf/neighbor as anything in T.atmos_adjacent_turfs)
		if(!isopenturf(neighbor))
			continue
		var/turf/open/open_neighbor = neighbor
		if(T.air.compare(open_neighbor.air))
			return FALSE
	return TRUE

/**
 * Pressure-equalization for stable ("low pressure") turfs is now Rust's job too
 * (process_excited_groups_auxtools, aphelion-dogmos src/turfs/groups.rs) - it consumes the
 * low_pressure_turfs set Rust's own gas FDM pass (process_turfs_auxtools, SSAIR_ACTIVETURFS) already
 * produced this cycle via an internal channel, flood-fills outward from each seed turf while pressure
 * stays within excited_group_pressure_goal, and snaps every turf in the resulting group directly to
 * the merged average - the same "converged region, stop diffusing incrementally, snap to average" idea
 * /datum/excited_group/proc/self_breakdown() used to implement in DM, just run every cycle instead of
 * after a stability cooldown.
 *
 * /datum/excited_group's breakdown/dismantle mechanism is intentionally NOT ported here (see the Phase
 * 3 plan's "Excited groups" section) - it was a pure perf optimization for DM's naive per-tick pairwise
 * diffusion, which no longer runs. The datum itself stays alive only for setup_allturfs()'s roundstart
 * active-turf discovery pass, unrelated to this per-tick stage.
 *
 * Rust's low_pressure_turfs channel is taken (consumed) whole on each call - if a pass is interrupted
 * by overtiming partway through a batch, whatever it hasn't reached yet is simply dropped rather than
 * resumed, since the channel is already empty for any later call this cycle. Accepted, katmos-native
 * "best effort within budget" behavior, not a bug: a skipped equalization self-corrects on the very
 * next gas FDM cycle, which produces a fresh low_pressure_turfs set.
 */
/datum/controller/subsystem/air/proc/process_excited_groups(resumed = FALSE)
	var/remaining_ms = TICK_DELTA_TO_MS(Master.current_ticklimit - TICK_USAGE)
	if(process_excited_groups_auxtools(remaining_ms))
		pause() // ran out of budget mid-batch - resume next fire(), see doc comment above

/datum/controller/subsystem/air/proc/process_rebuilds()
	//Yes this does mean rebuilding pipenets can freeze up the subsystem forever, but if we're in that situation something else is very wrong
	var/list/currentrun = rebuild_queue
	while(currentrun.len || length(expansion_queue))
		while(currentrun.len && !length(expansion_queue)) //If we found anything, process that first
			var/obj/machinery/atmospherics/remake = currentrun[currentrun.len]
			currentrun.len--
			if (!remake)
				continue
			remake.rebuild_pipes()
			if (MC_TICK_CHECK)
				return

		var/list/queue = expansion_queue
		while(queue.len)
			var/list/pack = queue[queue.len]
			//We operate directly with the pipeline like this because we can trust any rebuilds to remake it properly
			var/datum/pipeline/linepipe = pack[SSAIR_REBUILD_PIPELINE]
			var/list/border = pack[SSAIR_REBUILD_QUEUE]
			expand_pipeline(linepipe, border)
			if(state != SS_RUNNING) //expand_pipeline can fail a tick check, we shouldn't let things get too fucky here
				return

			linepipe.building = FALSE
			queue.len--
			if (MC_TICK_CHECK)
				return

///Rebuilds a pipeline by expanding outwards, while yielding when sane
/datum/controller/subsystem/air/proc/expand_pipeline(datum/pipeline/net, list/border)
	while(border.len)
		var/obj/machinery/atmospherics/borderline = border[border.len]
		border.len--

		var/list/result = borderline.pipeline_expansion(net)
		if(!length(result))
			continue
		for(var/obj/machinery/atmospherics/considered_device in result)
			if(!istype(considered_device, /obj/machinery/atmospherics/pipe))
				considered_device.set_pipenet(net, borderline)
				net.add_machinery_member(considered_device)
				continue
			var/obj/machinery/atmospherics/pipe/item = considered_device
			if(net.members.Find(item))
				continue
			if(item.parent)
				var/static/pipenetwarnings = 10
				if(pipenetwarnings > 0)
					log_mapping("build_pipeline(): [item.type] added to a pipenet while still having one. (pipes leading to the same spot stacking in one turf) around [AREACOORD(item)].")
					pipenetwarnings--
					if(pipenetwarnings == 0)
						log_mapping("build_pipeline(): further messages about pipenets will be suppressed")

			net.members += item
			border += item

			net.air.set_volume(net.air.return_volume() + item.volume)
			item.replace_pipenet(item.parent, net)

			if(item.air_temporary)
				net.air.merge(item.air_temporary)
				item.air_temporary = null

		if (MC_TICK_CHECK)
			return

///Removes a turf from processing, and causes its excited group to clean up so things properly adapt to the change
/datum/controller/subsystem/air/proc/remove_from_active(turf/open/T)
	active_turfs -= T
	if(currentpart == SSAIR_ACTIVETURFS)
		currentrun -= T
	#ifdef VISUALIZE_ACTIVE_TURFS //Use this when you want details about how the turfs are moving, display_all_groups should work for normal operation
	T.remove_atom_colour(TEMPORARY_COLOUR_PRIORITY, COLOR_VIBRANT_LIME)
	#endif
	if(istype(T))
		T.excited = FALSE
		if(T.excited_group)
			//If this fires during active turfs it'll cause a slight removal of active turfs, as they breakdown if they have no excited group
			//The group also expands by a tile per rebuild on each edge, suffering
			T.excited_group.garbage_collect() //Kill the excited group, it'll reform on its own later

///Puts an active turf to sleep so it doesn't process. Do this without cleaning up its excited group.
/datum/controller/subsystem/air/proc/sleep_active_turf(turf/open/T)
	active_turfs -= T
	if(currentpart == SSAIR_ACTIVETURFS)
		currentrun -= T
	#ifdef VISUALIZE_ACTIVE_TURFS
	T.remove_atom_colour(TEMPORARY_COLOUR_PRIORITY, COLOR_VIBRANT_LIME)
	#endif
	if(istype(T))
		T.excited = FALSE

///Adds a turf to active processing, handles duplicates. Call this with blockchanges == TRUE if you want to nuke the assoc excited group
/datum/controller/subsystem/air/proc/add_to_active(turf/open/activate, blockchanges = FALSE)
	if(istype(activate) && activate.air)
		activate.significant_share_ticker = 0
		if(blockchanges && activate.excited_group) //This is used almost exclusivly for shuttles, so the excited group doesn't stay behind
			activate.excited_group.garbage_collect() //Nuke it
		if(activate.excited) //Don't keep doing it if there's no point
			return
		#ifdef VISUALIZE_ACTIVE_TURFS
		activate.add_atom_colour(COLOR_VIBRANT_LIME, TEMPORARY_COLOUR_PRIORITY)
		#endif
		activate.excited = TRUE
		active_turfs += activate
	else if(activate.flags_1 & INITIALIZED_1)
		for(var/turf/neighbor as anything in activate.atmos_adjacent_turfs)
			add_to_active(neighbor, TRUE)
	else if(map_loading)
		if(queued_for_activation)
			queued_for_activation[activate] = activate
	else
		activate.requires_activation = TRUE

/datum/controller/subsystem/air/StartLoadingMap()
	LAZYINITLIST(queued_for_activation)
	map_loading = TRUE

/datum/controller/subsystem/air/StopLoadingMap()
	map_loading = FALSE
	for(var/turf/T in queued_for_activation)
		// Late-map-loaded turfs (ruins, away missions) never went through setup_allturfs()'s bulk
		// Initalize_Atmos() pass, so they've never registered with Dogmos - do it now, alongside the
		// existing add_to_active() catch-up this loop already does for the same reason.
		T.register_dogmos_air()
		add_to_active(T, TRUE)
	queued_for_activation.Cut()

/datum/controller/subsystem/air/proc/setup_allturfs()
	var/list/active_turfs = src.active_turfs
	times_fired++

	// Clear active turfs - faster than removing every single turf in the world
	// one-by-one, and Initalize_Atmos only ever adds `src` back in.
	#ifdef VISUALIZE_ACTIVE_TURFS
	for(var/jumpy in active_turfs)
		var/turf/active = jumpy
		active.remove_atom_colour(TEMPORARY_COLOUR_PRIORITY, COLOR_VIBRANT_LIME)
	#endif
	active_turfs.Cut()
	// We compare this against turf.current cycle using <= to ensure O(n)
	// It defaults to 0, so we start at -1
	var/time = -1

	var/list/turf/open/difference_check = list()
	for(var/turf/setup as anything in ALL_TURFS())
		if (!setup.init_air)
			continue
		// We pass the tick as the current step so if we sleep the step changes
		// This way we can make setting up adjacent turfs O(n) rather then O(n^2)
		setup.Initalize_Atmos(time)
		// We assert that we'll only get open turfs here
		difference_check += setup
		if(CHECK_TICK)
			time--

	// Now we're gonna compare for differences
	// Taking advantage of current cycle being set to negative before this run to do A->B B->A prevention
	for(var/turf/open/potential_diff as anything in difference_check)
		// I can't use 0 here, so we're gonna do this instead. If it ever breaks I'll eat my shoe
		potential_diff.current_cycle = -INFINITY
		for(var/turf/open/enemy_tile as anything in potential_diff.atmos_adjacent_turfs)
			// If it's already been processed, then it's already talked to us
			if(enemy_tile.current_cycle == -INFINITY)
				continue
			// .air instead of .return_air() because we can guarantee that the proc won't do anything
			if(potential_diff.air.compare(enemy_tile.air, FALSE))
				if(!potential_diff.excited)
					potential_diff.excited = TRUE
					SSair.active_turfs += potential_diff
				if(!enemy_tile.excited)
					enemy_tile.excited = TRUE
					SSair.active_turfs += enemy_tile
				// No sense continuing to iterate
				break
		CHECK_TICK

	if(active_turfs.len)
		var/starting_ats = active_turfs.len
		sleep(world.tick_lag)
		var/timer = world.timeofday

		log_mapping("There are [starting_ats] active turfs at roundstart caused by a difference of the air between the adjacent turfs. \
		To locate these active turfs, go into the \"Debug\" tab of your stat-panel. Then hit the verb that says \"Mapping Verbs - Enable\". \
		Now, you can see all of the associated coordinates using \"Mapping -> Show roundstart AT list\" verb.")

		for(var/turf/T in active_turfs)
			GLOB.active_turfs_startlist += T

		//now lets clear out these active turfs
		var/list/turfs_to_check = active_turfs.Copy()
		do
			var/list/new_turfs_to_check = list()
			for(var/turf/open/T in turfs_to_check)
				new_turfs_to_check += T.resolve_active_graph()
			CHECK_TICK

			active_turfs += new_turfs_to_check
			turfs_to_check = new_turfs_to_check
		while (turfs_to_check.len)

		var/ending_ats = active_turfs.len
		for(var/thing in excited_groups)
			var/datum/excited_group/EG = thing
			EG.self_breakdown(roundstart = TRUE)
			EG.dismantle()
			CHECK_TICK

		log_active_turfs() // invoke this here so we can count the time it takes to run this proc as "wasted time", quite simple honestly.

		var/msg = "HEY! LISTEN! [DisplayTimeText(world.timeofday - timer, 0.00001)] were wasted processing [starting_ats] turf(s) (connected to [ending_ats - starting_ats] other turfs) with atmos differences at round start."
		to_chat(world, span_boldannounce("[msg]"))
		warning(msg)

/// Logs all active turfs at roundstart to the mapping log so it can be readily accessed.
/datum/controller/subsystem/air/proc/log_active_turfs()
// sadly this has to be here because we can't realistically expect that all active turfs will be resolved in every possible situation when running through CI.
// In an ideal world, we would have absolutely zero active turfs 99.99% of the time, but that's not the case. `log_mapping()` during world initialize triggers a CI fail.
#ifdef UNIT_TESTS
	return
#else
	// Associated lists, left-hand-side is the z-level or z-trait, right-hand-side is the number of active turfs associated with that.
	var/list/tally_by_level = list()
	// Discriminate for certain z-traits, stuff like "Linkage" is not helpful.
	var/list/tally_by_level_trait = list(
		ZTRAIT_AWAY = 0,
		ZTRAIT_CENTCOM = 0,
		ZTRAIT_ICE_RUINS = 0,
		ZTRAIT_ICE_RUINS_UNDERGROUND  = 0,
		ZTRAIT_ISOLATED_RUINS = 0,
		ZTRAIT_LAVA_RUINS = 0,
		ZTRAIT_MINING = 0,
		ZTRAIT_RESERVED = 0,
		ZTRAIT_SPACE_RUINS = 0,
		ZTRAIT_STATION = 0,
	)

	var/list/message_to_log = list()

	message_to_log += "\nAll that follows is a turf with an active air difference at roundstart. To clear this, make sure that all of the turfs listed below are connected to a turf with the same air contents.\n\
		In an ideal world, this list should have enough information to help you locate the active turf(s) in question. Unfortunately, this might not be an ideal world.\n\
		If the round is still ongoing, you can use the \"Mapping -> Show roundstart AT list\" verb to see exactly what active turfs were detected. Otherwise, good luck."

	for(var/turf/active_turf as anything in GLOB.active_turfs_startlist)
		var/turf_z = active_turf.z
		var/datum/space_level/level = SSmapping.z_list[turf_z]
		var/list/level_traits = list()
		for(var/trait in level.traits)
			if(!isnull(tally_by_level_trait[trait]))
				level_traits += trait
				tally_by_level_trait[trait]++

		// so we can pass along the area type for the log, making it much easier to locate the active turf for a mapper assuming all area types are unique. This is only really a problem for stuff like ruin areas.
		var/area/turf_area = get_area(active_turf)
		message_to_log += "Active turf: [AREACOORD(active_turf)] ([turf_area.type]). Turf type: [active_turf.type]. Relevant Z-Trait(s): [english_list(level_traits)]."

		tally_by_level["[turf_z]"]++

	// Following is so we can detect which rounds were "problematic" as far as active turfs go.
	SSblackbox.record_feedback("amount", "overall_roundstart_active_turfs", length(GLOB.active_turfs_startlist))

	for(var/z_level in tally_by_level)
		var/level_turf_count = tally_by_level[z_level]
		if(level_turf_count == 0) // no point logging it
			continue
		message_to_log += "Z-Level [z_level] has [level_turf_count] active turf(s)."
		SSblackbox.record_feedback("tally", "roundstart_active_turfs_per_z", level_turf_count, z_level)

	for(var/z_trait in tally_by_level_trait)
		var/trait_turf_count = tally_by_level_trait[z_trait]
		if(trait_turf_count == 0)
			continue
		message_to_log += "Z-Level trait [z_trait] has [trait_turf_count] active turf(s)."
		SSblackbox.record_feedback("amount", "roundstart_active_turfs_for_trait_[z_trait]", trait_turf_count)

	message_to_log += "End of active turf list."
	log_mapping(message_to_log.Join("\n"))
#endif

/turf/open/proc/resolve_active_graph()
	. = list()
	var/datum/excited_group/EG = excited_group
	if (blocks_air || !air)
		return
	if (!EG)
		EG = new
		EG.add_turf(src)

	for (var/turf/open/ET in atmos_adjacent_turfs)
		if (ET.blocks_air || !ET.air)
			continue

		var/ET_EG = ET.excited_group
		if (ET_EG)
			if (ET_EG != EG)
				EG.merge_groups(ET_EG)
				EG = excited_group //merge_groups() may decide to replace our current EG
		else
			EG.add_turf(ET)
		if (!ET.excited)
			ET.excited = TRUE
			. += ET

/turf/open/space/resolve_active_graph()
	return list()

/datum/controller/subsystem/air/proc/setup_atmos_machinery()
	for (var/obj/machinery/atmospherics/AM in atmos_machinery)
		AM.atmos_init()
		CHECK_TICK

//this can't be done with setup_atmos_machinery() because
// all atmos machinery has to initialize before the first
// pipenet can be built.
/datum/controller/subsystem/air/proc/setup_pipenets()
	for (var/obj/machinery/atmospherics/AM in atmos_machinery)
		var/list/targets = AM.get_rebuild_targets()
		for(var/datum/pipeline/build_off as anything in targets)
			build_off.build_pipeline_blocking(AM)
		CHECK_TICK

GLOBAL_LIST_EMPTY(colored_turfs)
GLOBAL_LIST_EMPTY(colored_images)
/datum/controller/subsystem/air/proc/setup_turf_visuals()
	for(var/sharp_color in GLOB.contrast_colors)
		var/list/add_to = list()
		GLOB.colored_turfs += list(add_to)
		for(var/offset in 0 to SSmapping.max_plane_offset)
			var/obj/effect/overlay/atmos_excited/suger_high = new()
			SET_PLANE_W_SCALAR(suger_high, HIGH_GAME_PLANE, offset)
			add_to += suger_high
			var/image/shiny = new('icons/effects/effects.dmi', suger_high, "atmos_top")
			SET_PLANE_W_SCALAR(shiny, HIGH_GAME_PLANE, offset)
			shiny.color = sharp_color
			GLOB.colored_images += shiny

/datum/controller/subsystem/air/proc/setup_template_machinery(list/atmos_machines)
	var/obj/machinery/atmospherics/AM
	for(var/A in 1 to atmos_machines.len)
		AM = atmos_machines[A]
		AM.atmos_init()
		CHECK_TICK

	for(var/A in 1 to atmos_machines.len)
		AM = atmos_machines[A]
		var/list/targets = AM.get_rebuild_targets()
		for(var/datum/pipeline/build_off as anything in targets)
			build_off.build_pipeline_blocking(AM)
		CHECK_TICK


/datum/controller/subsystem/air/proc/get_init_dirs(type, dir, init_dir)

	if(!pipe_init_dirs_cache[type])
		pipe_init_dirs_cache[type] = list()

	if(!pipe_init_dirs_cache[type]["[init_dir]"])
		pipe_init_dirs_cache[type]["[init_dir]"] = list()

	if(!pipe_init_dirs_cache[type]["[init_dir]"]["[dir]"])
		var/obj/machinery/atmospherics/temp = new type(null, FALSE, dir, init_dir)
		pipe_init_dirs_cache[type]["[init_dir]"]["[dir]"] = temp.get_init_directions()
		qdel(temp)

	return pipe_init_dirs_cache[type]["[init_dir]"]["[dir]"]

/datum/controller/subsystem/air/proc/generate_atmos()
	atmos_gen = list()
	for(var/T in subtypesof(/datum/atmosphere))
		var/datum/atmosphere/atmostype = T
		atmos_gen[initial(atmostype.id)] = new atmostype

/// Takes a gas string, returns the matching mutable gas_mixture
/datum/controller/subsystem/air/proc/parse_gas_string(gas_string, gastype = /datum/gas_mixture)
	var/datum/gas_mixture/cached = strings_to_mix["[gas_string]-[gastype]"]

	if(cached)
		if(istype(cached, /datum/gas_mixture/immutable))
			return cached
		return cached.copy()

	var/datum/gas_mixture/canonical_mix = new gastype()
	// We set here so any future key changes don't fuck us
	strings_to_mix["[gas_string]-[gastype]"] = canonical_mix
	gas_string = preprocess_gas_string(gas_string)

	var/list/gas = params2list(gas_string)
	if(gas["TEMP"])
		canonical_mix.set_temperature(text2num(gas["TEMP"]))
		gas -= "TEMP"
	else // if we do not have a temp in the new gas mix lets assume room temp.
		canonical_mix.set_temperature(T20C)
	for(var/id in gas)
		canonical_mix.set_moles(id, text2num(gas[id]))

	if(istype(canonical_mix, /datum/gas_mixture/immutable))
		canonical_mix.mark_immutable() //content is final now; New() deliberately did not do this
		return canonical_mix
	return canonical_mix.copy()

/datum/controller/subsystem/air/proc/preprocess_gas_string(gas_string)
	if(!atmos_gen)
		generate_atmos()
	if(!atmos_gen[gas_string])
		return gas_string
	var/datum/atmosphere/mix = atmos_gen[gas_string]
	return mix.gas_string

#undef ACTIVE_TURFS_WALK_BATCH_SIZE

/**
 * Adds a given machine to the processing system for SSAIR_ATMOSMACHINERY processing.
 *
 * Arguments:
 * * machine - The machine to start processing. Can be any /obj/machinery.
 */
/datum/controller/subsystem/air/proc/start_processing_machine(obj/machinery/machine)
	if(machine.atmos_processing)
		return
	if(QDELETED(machine))
		stack_trace("We tried to add a garbage collecting machine to SSair. Don't")
		return
	machine.atmos_processing = TRUE
	atmos_machinery += machine

/**
 * Removes a given machine to the processing system for SSAIR_ATMOSMACHINERY processing.
 *
 * Arguments:
 * * machine - The machine to stop processing.
 */
/datum/controller/subsystem/air/proc/stop_processing_machine(obj/machinery/machine)
	if(!machine.atmos_processing)
		return
	machine.atmos_processing = FALSE
	atmos_machinery -= machine

	// If we're currently processing atmos machines, there's a chance this machine is in
	// the currentrun list, which is a cache of atmos_machinery. Remove it from that list
	// as well to prevent processing qdeleted objects in the cache.
	if(currentpart == SSAIR_ATMOSMACHINERY)
		currentrun -= machine

/datum/controller/subsystem/air/ui_state(mob/user)
	return ADMIN_STATE(R_DEBUG)

/datum/controller/subsystem/air/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "AtmosControlPanel")
		ui.set_autoupdate(FALSE)
		ui.open()

/datum/controller/subsystem/air/ui_data(mob/user)
	var/list/data = list()
	data["excited_groups"] = list()
	for(var/datum/excited_group/group in excited_groups)
		var/turf/T = group.turf_list[1]
		var/area/target = get_area(T)
		var/max = 0
		#ifdef TRACK_MAX_SHARE
		for(var/who in group.turf_list)
			var/turf/open/lad = who
			max = max(lad.max_share, max)
		#endif
		data["excited_groups"] += list(list(
			"jump_to" = REF(T), //Just go to the first turf
			"group" = REF(group),
			"area" = target.name,
			"breakdown" = group.breakdown_cooldown,
			"dismantle" = group.dismantle_cooldown,
			"size" = group.turf_list.len,
			"should_show" = group.should_display,
			"max_share" = max
		))
	data["active_size"] = active_turfs.len
	data["hotspots_size"] = hotspots.len
	data["excited_size"] = excited_groups.len
	data["conducting_size"] = dogmos_heat_graph_count()
	data["frozen"] = can_fire
	data["show_all"] = display_all_groups
	data["fire_count"] = times_fired
	#ifdef TRACK_MAX_SHARE
	data["display_max"] = TRUE
	#else
	data["display_max"] = FALSE
	#endif
	data["showing_user"] = user.hud_used.atmos_debug_overlays
	return data

/datum/controller/subsystem/air/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(. || !check_rights_for(usr.client, R_DEBUG))
		return
	switch(action)
		if("move-to-target")
			var/turf/target = locate(params["spot"])
			if(!target)
				return
			usr.forceMove(target)
		if("toggle-freeze")
			can_fire = !can_fire
			return TRUE
		if("toggle_show_group")
			var/datum/excited_group/group = locate(params["group"])
			if(!group)
				return
			group.should_display = !group.should_display
			if(display_all_groups)
				return TRUE
			if(group.should_display)
				group.display_turfs()
			else
				group.hide_turfs()
			return TRUE
		if("toggle_show_all")
			display_all_groups = !display_all_groups
			for(var/datum/excited_group/group in excited_groups)
				if(display_all_groups)
					group.display_turfs()
				else if(!group.should_display) //Don't flicker yeah?
					group.hide_turfs()
			return TRUE
		if("toggle_user_display")
			var/mob/user = ui.user
			user.hud_used.atmos_debug_overlays = !user.hud_used.atmos_debug_overlays
			if(user.hud_used.atmos_debug_overlays)
				user.client.images += GLOB.colored_images
			else
				user.client.images -= GLOB.colored_images
			return TRUE
