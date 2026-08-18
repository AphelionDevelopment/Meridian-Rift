/** Shared admin panel for Dogmos telemetry and controls. State remains on SSair so all viewers see the
 * same values while this facade stays independent from AtmosControlPanel. */
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

/** Returns live Dogmos telemetry and bounded Kennel histories for the Overview tab. */
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
	data["heat_telemetry"] = list(
		"graph_nodes" = SSair.dogmos_heat_graph_nodes,
		"edge_attempts" = SSair.dogmos_heat_edge_attempts,
		"edges_applied" = SSair.dogmos_heat_edges_applied,
		"lock_contention" = SSair.dogmos_heat_lock_contention,
		"registration_changes" = SSair.dogmos_heat_registration_changes,
		"callback_enqueue_failures" = dogmos_callback_enqueue_failures(),
	)
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
	// APHELION EDIT ADDITION START - DOGMOS
	data["flamethrower_directional_spread"] = SSair.flamethrower_directional_spread
	data["event_counts"] = list(
		"fire_groups" = length(SSair.recent_fire_groups),
		"high_cost_zones" = length(SSair.recent_high_cost_zones),
		"explosions" = length(SSair.recent_explosions),
		"reactions_of_interest" = length(SSair.recent_reactions_of_interest),
		"breaches" = length(SSair.recent_breaches),
	)
	// APHELION EDIT ADDITION END

	// Slow mode gates only the potentially large machinery browse.
	SSair.kennel_prune_expired_pins()
	data["recent_fire_groups"] = SSair.recent_fire_groups
	data["recent_explosions"] = SSair.recent_explosions
	data["recent_high_cost_zones"] = SSair.recent_high_cost_zones
	data["recent_reactions_of_interest"] = SSair.recent_reactions_of_interest
	data["recent_breaches"] = SSair.recent_breaches
	data["structures_of_interest"] = SSair.structures_of_interest

	if(!SSair.kennel_slow_mode)
		// Every registered atmos machine/canister, for manually pinning one not already auto-flagged -
		// this list can be large (thousands of pipe segments on a full map), so it only exists while
		// slow mode is off.
		var/list/browse = list()
		for(var/candidate as anything in SSair.atmos_machinery)
			if(!istype(candidate, /obj/machinery))
				continue
			var/obj/machinery/machine = candidate
			var/area/candidate_area = get_area(machine)
			browse += list(list(
				"ref" = REF(machine),
				"name" = machine.name,
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
	var/mob/user = usr
	if(. || !user?.client || !check_rights_for(user.client, R_DEBUG))
		return
	switch(action)
		if("move-to-target")
			var/turf/target = SSair.resolve_kennel_jump_target(params["spot"])
			if(!target || !user)
				return
			user.forceMove(target)
		if("toggle-freeze")
			SSair.can_fire = !SSair.can_fire
			return TRUE
		if("toggle_realistic_space_radiation")
			SSair.realistic_space_radiation = !SSair.realistic_space_radiation
			return TRUE
		if("toggle_equalize_enabled")
			SSair.equalize_enabled = !SSair.equalize_enabled
			return TRUE
		// APHELION EDIT ADDITION START - DOGMOS
		if("toggle_flamethrower_directional_spread")
			SSair.flamethrower_directional_spread = !SSair.flamethrower_directional_spread
			return TRUE
		// APHELION EDIT ADDITION END
		if("toggle_kennel_slow_mode")
			SSair.kennel_slow_mode = !SSair.kennel_slow_mode
			return TRUE
		if("toggle_kennel_profile_reactions")
			SSair.kennel_profile_reactions = !SSair.kennel_profile_reactions
			return TRUE
		if("toggle_user_display")
			user = ui.user
			user.hud_used.atmos_debug_overlays = !user.hud_used.atmos_debug_overlays
			if(user.hud_used.atmos_debug_overlays)
				user.client.images += GLOB.colored_images
				user.client.images += GLOB.kennel_overlay_images
			else
				user.client.images -= GLOB.colored_images
				user.client.images -= GLOB.kennel_overlay_images
				// APHELION EDIT ADDITION START - DOGMOS
				if(ishuman(user))
					var/mob/living/carbon/human/human_user = user
					var/obj/item/clothing/glasses/meson/engine/dogmos/dogmos_goggles = human_user.glasses
					if(istype(dogmos_goggles))
						user.client.images |= dogmos_goggles.dogmos_overlay_images()
				// APHELION EDIT ADDITION END
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
