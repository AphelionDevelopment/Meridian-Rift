/// Dogmos Kennel: how many entries each recent_* ring buffer keeps in memory. Search/filter happens
/// client-side in the TGUI table, so this stays cheap to keep generous - durability beyond this cap is
/// the round-scoped log file (kennel_append_log()), not a bigger in-memory list.
#define KENNEL_EVENT_HISTORY_CAP 200

/// Dogmos Kennel overlay categories - fixed, dedicated colors (deliberately NOT the wrapping/shared
/// GLOB.colored_turfs pool excited groups rotate through) so an admin can learn "this color means this
/// category" and have it keep meaning that, cycle to cycle.
#define KENNEL_OVERLAY_BREACH "breach"
#define KENNEL_OVERLAY_HIGH_COST "high_cost"
#define KENNEL_OVERLAY_REACTION "reaction"
#define KENNEL_OVERLAY_STRUCTURE "structure"
/// How many turfs each EVENT-based overlay category (breach/high-cost/reaction) keeps lit at once,
/// oldest evicted first. Not used for the structure category, which mirrors structures_of_interest's
/// own pin lifecycle directly instead of a separate bounded set.
#define KENNEL_OVERLAY_RECENT_CAP 15

/// category -> list (index = GET_Z_PLANE_OFFSET()+1) of the dedicated overlay object for that
/// category/plane. category -> flat list of every image instance lives in kennel_overlay_images, for
/// the client.images += pattern toggle_user_display already uses.
GLOBAL_LIST_EMPTY(kennel_overlay_turfs)
GLOBAL_LIST_EMPTY(kennel_overlay_images)

/**
 * Builds the four dedicated overlay categories, one real /obj/effect/overlay/atmos_excited + /image
 * pair per (category, z-plane-offset) - same construction as SSair.setup_turf_visuals()'s
 * GLOB.colored_turfs/colored_images, just with fixed per-category colors instead of a shared rotating
 * palette. Called once from SSair/Initialize().
 */
/datum/controller/subsystem/air/proc/setup_kennel_overlays()
	var/static/list/category_colors = list(
		"[KENNEL_OVERLAY_BREACH]" = COLOR_RED,
		"[KENNEL_OVERLAY_HIGH_COST]" = COLOR_ORANGE,
		"[KENNEL_OVERLAY_REACTION]" = COLOR_PURPLE,
		"[KENNEL_OVERLAY_STRUCTURE]" = COLOR_CYAN,
	)
	for(var/category in category_colors)
		var/list/add_to = list()
		GLOB.kennel_overlay_turfs[category] = add_to
		for(var/offset in 0 to SSmapping.max_plane_offset)
			var/obj/effect/overlay/atmos_excited/marker = new()
			SET_PLANE_W_SCALAR(marker, HIGH_GAME_PLANE, offset)
			add_to += marker
			var/image/shiny = new('icons/effects/effects.dmi', marker, "atmos_top")
			SET_PLANE_W_SCALAR(shiny, HIGH_GAME_PLANE, offset)
			shiny.color = category_colors[category]
			GLOB.kennel_overlay_images += shiny

/datum/controller/subsystem/air/proc/kennel_show_overlay(turf/target, category)
	if(!istype(target))
		return
	var/list/slots = GLOB.kennel_overlay_turfs[category]
	if(!slots)
		return
	var/offset = GET_Z_PLANE_OFFSET(target.z) + 1
	target.vis_contents |= slots[offset]

/datum/controller/subsystem/air/proc/kennel_hide_overlay(turf/target, category)
	if(!istype(target))
		return
	var/list/slots = GLOB.kennel_overlay_turfs[category]
	if(!slots)
		return
	var/offset = GET_Z_PLANE_OFFSET(target.z) + 1
	target.vis_contents -= slots[offset]

/**
 * Shared by the three event-based overlay categories (breach/high-cost/reaction - NOT structures, see
 * kennel_pin_structure()): shows category's overlay on target and keeps tracker as a FIFO of the most
 * recent KENNEL_OVERLAY_RECENT_CAP distinct turfs shown, hiding the overlay on whichever turf falls off
 * the back. A turf already in tracker is moved to the front rather than duplicated, so a location that
 * keeps triggering the same category doesn't burn through the cap on itself alone.
 */
/datum/controller/subsystem/air/proc/kennel_mark_overlay_recent(list/tracker, category, turf/target)
	if(!istype(target))
		return
	if(target in tracker)
		tracker -= target
	tracker += target
	kennel_show_overlay(target, category)
	if(length(tracker) > KENNEL_OVERLAY_RECENT_CAP)
		var/turf/evicted = tracker[1]
		tracker.Cut(1, 2)
		kennel_hide_overlay(evicted, category)

/**
 * Records one Dogmos Kennel event into bucket (one of SSair's recent_* lists), newest first, capped at
 * KENNEL_EVENT_HISTORY_CAP, and appends it to the round-scoped Kennel log file for durability beyond
 * that in-memory cap. entry is a plain list of string/number fields - the same shape the TGUI table for
 * that category expects, and what kennel_append_log() serializes to JSON.
 */
/datum/controller/subsystem/air/proc/record_kennel_event(list/bucket, list/entry)
	bucket.Insert(1, list(entry))
	if(length(bucket) > KENNEL_EVENT_HISTORY_CAP)
		bucket.Cut(KENNEL_EVENT_HISTORY_CAP + 1, length(bucket) + 1)
	kennel_append_log(entry)

/// Appends one JSON-encoded line to the round's Kennel log file (GLOB.dogmos_kennel_log, declared in
/// code/_globalvars/logging.dm) - durable, post-round-reviewable history beyond the in-memory cap.
/datum/controller/subsystem/air/proc/kennel_append_log(list/entry)
	WRITE_LOG(GLOB.dogmos_kennel_log, json_encode(entry))

/**
 * Phase 3: called directly (not queued through auxcallback - see the doc comment on react_hook,
 * aphelion-dogmos src/lib.rs, for why react_hook already only ever runs on the main DM thread) whenever
 * kennel_profile_reactions is on and a single react_by_id() call meets or exceeds
 * kennel_high_cost_ms_threshold. holder is whatever the reacting gas_mixture's real holder was - usually
 * a turf (the SSAIR_ACTIVETURFS post-process path always passes one), but react() can be called with any
 * atom or null as holder, so this resolves an area only when holder actually is a turf rather than
 * assuming one.
 */
/datum/controller/subsystem/air/proc/kennel_record_reaction_cost(reaction_name, atom/holder, cost_ms)
	var/turf/holder_turf = isturf(holder) ? holder : null
	var/area/holder_area = holder_turf ? get_area(holder_turf) : null
	record_kennel_event(recent_high_cost_zones, list(
		"time" = round_timestamp(),
		"jump_to" = holder_turf ? REF(holder_turf) : null,
		"area" = holder_area ? holder_area.name : (holder ? "[holder]" : "unknown"),
		"reaction" = reaction_name,
		"cost_ms" = round(cost_ms, 0.01),
	))
	if(holder_turf)
		kennel_mark_overlay_recent(kennel_overlay_high_cost_turfs, KENNEL_OVERLAY_HIGH_COST, holder_turf)

/**
 * COMSIG_GLOB_EXPLOSION handler (registered on SSdcs in Initialize()) - same pattern
 * /obj/machinery/doppler_array/proc/sense_explosion() already uses for the same signal. Records every
 * explosion, and auto-pins explosion_cause into structures_of_interest if it's an atmos machine/canister
 * (e.g. a canister that blew) so it's easy to find afterward.
 */
/datum/controller/subsystem/air/proc/on_kennel_explosion(datum/source, turf/epicenter, devastation_range, heavy_impact_range, light_impact_range, took, orig_dev_range, orig_heavy_range, orig_light_range, explosion_cause, explosion_index)
	SIGNAL_HANDLER
	var/area/epicenter_area = epicenter ? get_area(epicenter) : null
	record_kennel_event(recent_explosions, list(
		"time" = round_timestamp(),
		"jump_to" = epicenter ? REF(epicenter) : null,
		"area" = epicenter_area ? epicenter_area.name : null,
		"devastation_range" = devastation_range,
		"heavy_impact_range" = heavy_impact_range,
		"light_impact_range" = light_impact_range,
		"cause" = explosion_cause ? "[explosion_cause]" : "unknown",
		"index" = explosion_index,
	))
	if(istype(explosion_cause, /obj/machinery))
		kennel_pin_structure(explosion_cause, "explosion cause", kennel_auto_pin_duration)

/**
 * Checked once per turf, per cycle, from walk_active_turfs_batch()'s existing per-turf loop (no new
 * batch/timer needed - reuses the same round-robin walk that already visits every active turf
 * periodically). air.reaction_results is populated uniformly by both DM-side SET_REACTION_RESULTS and
 * the native aphelion_reactions finish procs, but per turf_settled()'s own doc comment it's a
 * cumulative, never-cleared record - an entry's KEY never disappears once a reaction has fired there
 * once, so a naive "value >= threshold" check would re-record the same old reaction forever. T's own
 * kennel_last_reaction_results cache (turf.dm) makes this a real "did this change since I last looked"
 * check instead: only a reaction whose recorded amount actually differs from the cached value - i.e.
 * fired again, or fired for the first time - and clears the threshold gets recorded.
 */
/datum/controller/subsystem/air/proc/check_kennel_reaction_of_interest(turf/open/T)
	var/list/results = T.air.reaction_results
	if(!length(results))
		return
	for(var/reaction_type in results)
		var/amount = results[reaction_type]
		var/cached = LAZYACCESS(T.kennel_last_reaction_results, reaction_type)
		if(cached == amount)
			continue
		LAZYSET(T.kennel_last_reaction_results, reaction_type, amount)
		if(abs(amount) < kennel_reaction_magnitude_threshold)
			continue
		var/area/reaction_area = get_area(T)
		record_kennel_event(recent_reactions_of_interest, list(
			"time" = round_timestamp(),
			"jump_to" = REF(T),
			"area" = reaction_area ? reaction_area.name : null,
			"reaction" = "[reaction_type]",
			"amount" = round(amount, 0.1),
		))
		kennel_mark_overlay_recent(kennel_overlay_reaction_turfs, KENNEL_OVERLAY_REACTION, T)

/**
 * Checked once per machine, per cycle, from process_atmos_machinery()'s existing per-machine loop -
 * same TICK_USAGE/TICK_USAGE_TO_MS pattern dogmos_del_cost.dm already established for measuring a real
 * call's cost. Keeps a per-machine EWMA (MC_AVERAGE, matching every other cost_* var in this file) and
 * auto-pins a machine whose EWMA crosses kennel_machine_cost_ms_threshold.
 */
/datum/controller/subsystem/air/proc/check_kennel_machine_cost(obj/machinery/M, cost_ms)
	if(!M)
		return // process_atmos_machinery() falls through to a null M when its own list holds a stale null slot - not this proc's problem to fix, just don't crash on it.
	var/key = REF(M)
	var/previous = kennel_machine_cost_ewma[key]
	var/ewma = isnull(previous) ? cost_ms : MC_AVERAGE(previous, cost_ms)
	kennel_machine_cost_ewma[key] = ewma
	if(ewma >= kennel_machine_cost_ms_threshold)
		kennel_pin_structure(M, "high cost ([round(ewma, 0.01)]ms EWMA)", kennel_auto_pin_duration)

/**
 * Pins target into structures_of_interest - either a manual admin pin (expires = null, never pruned
 * automatically) or an auto-pin (expires = a world.time deadline, removed by
 * kennel_prune_expired_pins()). Re-pinning an already-pinned target refreshes its reason/expiry rather
 * than creating a duplicate entry.
 */
/datum/controller/subsystem/air/proc/kennel_pin_structure(obj/machinery/target, reason, expires_in)
	if(QDELETED(target))
		return
	var/key = REF(target)
	for(var/list/entry in structures_of_interest)
		if(entry["ref"] == key)
			entry["reason"] = reason
			entry["expires"] = expires_in ? world.time + expires_in : null
			return
	var/area/target_area = get_area(target)
	structures_of_interest.Insert(1, list(list(
		"ref" = key,
		"name" = target.name,
		"area" = target_area ? target_area.name : null,
		"reason" = reason,
		"pinned_at" = round_timestamp(),
		"expires" = expires_in ? world.time + expires_in : null,
	)))
	// kennel_pinned_turfs is DM-internal bookkeeping only (never sent to ui_data()) so unpin/expiry can
	// hide the structure overlay without re-locate()-ing an admin-suppliable ref - see
	// kennel_unpin_structure()/kennel_prune_expired_pins().
	var/turf/target_turf = get_turf(target)
	if(target_turf)
		kennel_pinned_turfs[key] = target_turf
		kennel_show_overlay(target_turf, KENNEL_OVERLAY_STRUCTURE)

/// Admin-triggered unpin (Dogmos Kennel's Structures/Machines tab) - removes by ref regardless of
/// whether the pin was manual or auto, and regardless of whether target still exists.
/datum/controller/subsystem/air/proc/kennel_unpin_structure(ref)
	for(var/list/entry in structures_of_interest)
		if(entry["ref"] == ref)
			structures_of_interest -= list(entry)
			kennel_hide_overlay(kennel_pinned_turfs[ref], KENNEL_OVERLAY_STRUCTURE)
			kennel_pinned_turfs -= ref
			return

/// Lazily removes expired auto-pins - called from the Kennel UI's ui_data() on every read rather than
/// on its own timer, which is adequate for a debug panel's data and avoids a dedicated process() just
/// for this.
/datum/controller/subsystem/air/proc/kennel_prune_expired_pins()
	for(var/list/entry in structures_of_interest)
		var/expires = entry["expires"]
		if(expires && world.time >= expires)
			var/ref = entry["ref"]
			structures_of_interest -= list(entry)
			kennel_hide_overlay(kennel_pinned_turfs[ref], KENNEL_OVERLAY_STRUCTURE)
			kennel_pinned_turfs -= ref
