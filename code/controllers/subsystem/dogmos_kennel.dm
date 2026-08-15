/**
 * Dogmos Kennel - the master control panel for the Dogmos subsystem/integration, intended to supersede
 * (not replace outright - see the atmos_control admin verb, kept alongside this one until parity is
 * confirmed) the Atmos Control Panel. "Dogmos Kennel" is the permanent name, not a placeholder to be
 * dropped later.
 *
 * Backed by its own persistent singleton datum rather than a second ui_interact() entry point on SSair:
 * SStgui.get_open_ui(user, src_object) matches an open UI by (user, src_object) ONLY, ignoring the
 * interface string - src_object.open_uis is one flat list per object, not partitioned by interface. A
 * second SSair interface would let a user with the OLD "AtmosControlPanel" already open have this
 * panel's try_update_ui() silently find and reuse that same UI instance (and vice versa), breaking
 * "supersede but not replace" during the transition where both must be independently openable. This
 * datum is a thin facade over that problem, not a second source of truth: all real state still lives on
 * SSair (cost_*, realistic_space_radiation, equalize_enabled, and everything this file adds), matching
 * how every existing piece of Dogmos telemetry/toggle already lives there.
 *
 * Persistent (created once via GLOBAL_DATUM_INIT, never new()'d per-open like /datum/dynamic_panel) so
 * one open_uis list serves every simultaneous viewer, and so kennel_slow_mode is one shared value
 * everyone observes together - a real shared cost control, not N independent per-viewer flags.
 */
GLOBAL_DATUM_INIT(dogmos_kennel, /datum/dogmos_kennel, new())

/datum/dogmos_kennel

/datum/dogmos_kennel/ui_state(mob/user)
	return ADMIN_STATE(R_DEBUG)

/datum/dogmos_kennel/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "DogmosKennel")
		ui.set_autoupdate(FALSE)
		ui.open()

/**
 * Everything the Overview tab needs, read straight off SSair.
 *
 * Deliberately does NOT expose SSair.excited_groups (unlike AtmosControlPanel.jsx, which still shows
 * it for its own users): per that datum's own doc comment, Rust's per-cycle equalization
 * (SSAIR_EXCITEDGROUPS/SSAIR_HIGHPRESSURE) never creates or updates /datum/excited_group objects, so
 * both the per-zone table AND the group count are frozen at whatever setup_allturfs() produced at
 * roundstart - not "rarely updated," genuinely inert for the rest of the round. A "live master control
 * panel" showing a headline number that never moves is actively misleading, not merely stale, so this
 * was removed here rather than "integrated" - there's real live substitutes for the same underlying
 * question (is equalization doing anything) already below: low_pressure_turfs/high_pressure_turfs/
 * group_turfs_processed/equalize_processed, all genuine per-cycle Rust telemetry. Re-adding a per-zone
 * breakdown for real would need Rust to report zone membership back to DM, which doesn't exist today -
 * see dogmos_excited_groups.dm's own doc comment for why that isn't a small addition.
 */
/datum/dogmos_kennel/ui_data(mob/user)
	var/list/data = list()
	data["active_size"] = SSair.active_turfs.len
	data["hotspots_size"] = SSair.hotspots.len
	data["conducting_size"] = dogmos_heat_graph_count()
	data["low_pressure_turfs"] = SSair.low_pressure_turfs
	data["high_pressure_turfs"] = SSair.high_pressure_turfs
	data["group_turfs_processed"] = SSair.num_group_turfs_processed
	data["equalize_processed"] = SSair.num_equalize_processed
	data["space_boundary_size"] = dogmos_space_boundary_count()
	data["dogmos_costs"] = list(
		"turfs" = SSair.cost_turfs,
		"groups" = SSair.cost_groups,
		"highpressure" = SSair.cost_highpressure,
		"equalize" = SSair.cost_equalize,
		"superconductivity" = SSair.cost_superconductivity,
		"post_process" = SSair.cost_post_process,
	)
	data["frozen"] = SSair.can_fire
	data["realistic_space_radiation"] = SSair.realistic_space_radiation
	data["equalize_enabled"] = SSair.equalize_enabled
	data["fire_count"] = SSair.times_fired
	data["showing_user"] = user.hud_used.atmos_debug_overlays
	data["kennel_slow_mode"] = SSair.kennel_slow_mode

	// Slow mode (default ON) gates payload as well as push cadence (see the cadence half in
	// SSair.fire()): the five recent_* tables, structures_of_interest, and the machinery browse list
	// are the only genuinely variable-cost part of this panel's data - everything above is exactly what
	// the old Atmos Control Panel already computed every cycle. Sent as real empty lists rather than
	// omitted keys when slow mode is on, so the frontend never has to guard against an absent key.
	SSair.kennel_prune_expired_pins()
	if(SSair.kennel_slow_mode)
		data["recent_fire_groups"] = list()
		data["recent_high_cost_zones"] = list()
		data["recent_explosions"] = list()
		data["recent_reactions_of_interest"] = list()
		data["recent_breaches"] = list()
		data["structures_of_interest"] = list()
	else
		data["recent_fire_groups"] = SSair.recent_fire_groups
		data["recent_high_cost_zones"] = SSair.recent_high_cost_zones
		data["recent_explosions"] = SSair.recent_explosions
		data["recent_reactions_of_interest"] = SSair.recent_reactions_of_interest
		data["recent_breaches"] = SSair.recent_breaches
		data["structures_of_interest"] = SSair.structures_of_interest

		// Every registered atmos machine/canister, for manually pinning one not already auto-flagged -
		// this list can be large (thousands of pipe segments on a full map), so it only exists at all
		// alongside the rest of the expensive payload, never while slow mode is on.
		var/list/browse = list()
		for(var/obj/machinery/candidate as anything in SSair.atmos_machinery)
			if(!candidate)
				continue
			var/area/candidate_area = get_area(candidate)
			browse += list(list(
				"ref" = REF(candidate),
				"name" = candidate.name,
				"area" = candidate_area ? candidate_area.name : null,
			))
		data["atmos_machinery_browse"] = browse

	data["kennel_fire_group_notable_size"] = SSair.kennel_fire_group_notable_size
	data["kennel_reaction_magnitude_threshold"] = SSair.kennel_reaction_magnitude_threshold
	data["kennel_machine_cost_ms_threshold"] = SSair.kennel_machine_cost_ms_threshold
	data["kennel_profile_reactions"] = SSair.kennel_profile_reactions
	data["kennel_high_cost_ms_threshold"] = SSair.kennel_high_cost_ms_threshold
	return data

/datum/dogmos_kennel/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
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
			SSair.can_fire = !SSair.can_fire
			return TRUE
		if("toggle_realistic_space_radiation")
			SSair.realistic_space_radiation = !SSair.realistic_space_radiation
			return TRUE
		if("toggle_equalize_enabled")
			SSair.equalize_enabled = !SSair.equalize_enabled
			return TRUE
		if("toggle_kennel_slow_mode")
			SSair.kennel_slow_mode = !SSair.kennel_slow_mode
			return TRUE
		if("toggle_kennel_profile_reactions")
			SSair.kennel_profile_reactions = !SSair.kennel_profile_reactions
			return TRUE
		if("toggle_user_display")
			var/mob/user = ui.user
			user.hud_used.atmos_debug_overlays = !user.hud_used.atmos_debug_overlays
			if(user.hud_used.atmos_debug_overlays)
				user.client.images += GLOB.colored_images
				user.client.images += GLOB.kennel_overlay_images
			else
				user.client.images -= GLOB.colored_images
				user.client.images -= GLOB.kennel_overlay_images
			return TRUE
		if("kennel_pin")
			var/obj/machinery/target = locate(params["ref"]) in SSair.atmos_machinery
			if(!target)
				return
			SSair.kennel_pin_structure(target, "manually leashed", null)
			return TRUE
		if("kennel_unpin")
			SSair.kennel_unpin_structure(params["ref"])
			return TRUE
		if("kennel_set_threshold")
			var/value = text2num(params["value"])
			if(isnull(value))
				return
			switch(params["threshold"])
				if("fire_group_notable_size")
					SSair.kennel_fire_group_notable_size = max(1, value)
				if("reaction_magnitude_threshold")
					SSair.kennel_reaction_magnitude_threshold = max(0, value)
				if("machine_cost_ms_threshold")
					SSair.kennel_machine_cost_ms_threshold = max(0, value)
				if("high_cost_ms_threshold")
					SSair.kennel_high_cost_ms_threshold = max(0, value)
				else
					return
			return TRUE
