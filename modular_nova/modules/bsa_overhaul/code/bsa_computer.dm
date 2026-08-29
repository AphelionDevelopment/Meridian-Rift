/**
 * The control computer
 *
 * Responsible for cannon firing protocols.
 */

/obj/machinery/computer/bsa_control
	name = "bluespace artillery control"
	use_power = NO_POWER_USE
	circuit = /obj/item/circuitboard/computer/bsa_control
	icon = 'icons/obj/machines/particle_accelerator.dmi'
	icon_state = "control_boxp"
	icon_keyboard = null
	icon_screen = null
	/// A weakref to our cannon
	var/datum/weakref/connected_cannon
	/// The current system status of the gun
	var/notice
	/// Our target... WHY NOT WEEKREFF
	var/atom/target
	/// Are we allowing the gun to target areas?
	var/area_aim = FALSE //should also show areas for targeting
	/// If we're showing roughly where the BSA will appear.
	var/visualizing_position = FALSE
	/// The centerpiece's turf when visualization started, so it can't be moved mid-deployment.
	var/turf/visualization_center
	/// The front piece's turf when visualization started, so it can't be rotated mid-deployment.
	var/turf/visualization_front
	/// Typepath of the effect used for position visualization.
	var/visualization_type = /obj/effect/clear_color/green
	/// List of effects being used to show where the BSA will appear.
	var/list/visualization_effects

	connectable = FALSE //connecting_computer change: since icon_state is not a typical console, it cannot be connectable.


/obj/machinery/computer/bsa_control/Initialize(mapload, obj/item/circuitboard/circuit)
	. = ..()
	visualization_effects = list()

/obj/machinery/computer/bsa_control/Destroy(force)
	stop_visualizing()
	return ..()

/obj/machinery/computer/bsa_control/on_set_machine_stat(old_value)
	. = ..()
	if(machine_stat)
		stop_visualizing()

/obj/machinery/computer/bsa_control/ui_state(mob/user)
	return GLOB.physical_state

/obj/machinery/computer/bsa_control/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "BluespaceArtilleryNova", name)
		ui.open()

/obj/machinery/computer/bsa_control/ui_data()
	var/list/data = list()
	var/obj/machinery/bsa/full/cannon = connected_cannon?.resolve()

	data["connected"] = cannon
	data["notice"] = notice
	data["unlocked"] = GLOB.bsa_unlock
	data["powernet_power"] = cannon?.get_available_powercap()
	data["power_suck_cap"] = cannon?.power_suck_cap
	data["status"] = cannon?.system_state
	data["capacitor_charge"] = cannon?.capacitor_power
	data["target_capacitor_charge"] = cannon?.target_power
	data["max_capacitor_charge"] = cannon?.max_charge
	data["visualizing"] = visualizing_position
	if(target)
		data["target"] = get_target_name()
	return data

/obj/machinery/computer/bsa_control/ui_act(action, params)
	. = ..()
	if(.)
		return

	switch(action)
		if("build")
			deploy()
			. = TRUE
		if("visualize")
			start_visualizing()
			. = TRUE
		if("unvisualize")
			stop_visualizing()
			. = TRUE
		if("fire")
			fire(usr)
			. = TRUE
		if("recalibrate")
			calibrate(usr)
			. = TRUE
		if("charge")
			charge()
		if("capacitor_target_change")
			change_capacitor_target(params["capacitor_target"])
	update_appearance()

/obj/machinery/computer/bsa_control/emag_act(mob/user, obj/item/card/emag/emag_card)
	if(obj_flags & EMAGGED)
		return FALSE
	obj_flags |= EMAGGED
	balloon_alert(user, "rigged to explode")
	to_chat(user, span_warning("You emag [src] and hear the focusing crystal short out. You get the feeling it wouldn't be wise to stand near [src] when the BSA fires..."))
	return TRUE

/**
 * Changes the target charge for the internal capacitors
 */
/obj/machinery/computer/bsa_control/proc/change_capacitor_target(new_target)
	var/obj/machinery/bsa/full/cannon = connected_cannon?.resolve()
	if(!cannon)
		return
	cannon.target_power = new_target

/**
 * Takes power from the powernet and inserts it into the gun.
 */
/obj/machinery/computer/bsa_control/proc/charge()
	var/obj/machinery/bsa/full/cannon = connected_cannon?.resolve()
	if(!cannon)
		return
	if(cannon.system_state != BSA_SYSTEM_READY && cannon.system_state != BSA_SYSTEM_LOW_POWER)
		return
	cannon.system_state = BSA_SYSTEM_CHARGE_CAPACITORS

/**
 * Sets a target for the gun to use.
 */
/obj/machinery/computer/bsa_control/proc/calibrate(mob/user)
	if(!GLOB.bsa_unlock)
		return
	var/list/gps_locators = list()
	for(var/datum/component/gps/iterating_gps in GLOB.GPS_list) //nulls on the list somehow
		if(iterating_gps.tracking)
			gps_locators[iterating_gps.gpstag] = iterating_gps

	var/list/options = gps_locators
	if(area_aim)
		options += GLOB.teleportlocs
	var/victim = tgui_input_list(user, "Select target", "Artillery Targeting", options)
	if(isnull(victim))
		return
	if(isnull(options[victim]))
		return
	target = options[victim]

/**
 * Returns the targets name, simple.
 */
/obj/machinery/computer/bsa_control/proc/get_target_name()
	if(istype(target, /area))
		return get_area_name(target, TRUE)
	else if(istype(target, /datum/component/gps))
		var/datum/component/gps/gps = target
		return gps.gpstag

/**
 * Locates the impact turf based off of if it's an area or a GPS.
 */
/obj/machinery/computer/bsa_control/proc/get_impact_turf()
	if(obj_flags & EMAGGED)
		return get_turf(src)
	else if(istype(target, /area))
		return pick(get_area_turfs(target))
	else if(istype(target, /datum/component/gps))
		var/datum/component/gps/gps = target
		return get_turf(gps.parent)

/**
 * Initiates the cannon fire protocol
 */
/obj/machinery/computer/bsa_control/proc/fire(mob/user)
	var/obj/machinery/bsa/full/cannon = connected_cannon?.resolve()
	if(!cannon)
		notice = "System error"
		return
	if((cannon.machine_stat & BROKEN))
		notice = "Cannon integrity failure!"
		return
	if((cannon.machine_stat & NOPOWER))
		notice = "Cannon unpowered!"
		return
	var/turf/target_turf = get_impact_turf()
	notice = cannon.pre_fire(user, target_turf)

/**
 * Deploy
 *
 * Deploys the cannon and deletes the old parts.
 */
/// Prior to deployment, indicates the space the cannon will occupy using effects.
/obj/machinery/computer/bsa_control/proc/start_visualizing()
	if(visualizing_position)
		return
	var/obj/machinery/bsa/full/prebuilt = locate() in range(7) //In case of adminspawn
	if(prebuilt)
		prebuilt.control_computer = src
		connected_cannon = WEAKREF(prebuilt)
		return

	var/obj/machinery/bsa/middle/centerpiece = locate() in range(7)
	if(!centerpiece)
		notice = "No BSA parts detected nearby."
		return
	notice = centerpiece.check_completion()
	if(notice)
		return

	var/list/deployment_turfs = centerpiece.get_deployment_turfs()
	if(isnull(deployment_turfs))
		notice = "Parts misaligned!"
		return

	visualization_center = get_turf(centerpiece)
	visualization_front = get_turf(centerpiece.front_piece?.resolve())
	visualizing_position = TRUE
	for(var/turf/deployment_turf as anything in deployment_turfs)
		visualization_effects += new visualization_type(deployment_turf)

/// Clears the effects indicating where the cannon will deploy.
/obj/machinery/computer/bsa_control/proc/stop_visualizing()
	visualizing_position = FALSE
	visualization_center = null
	visualization_front = null
	for(var/obj/effect/deployment_visualizer as anything in visualization_effects)
		qdel(deployment_visualizer)
	visualization_effects?.Cut()

/obj/machinery/computer/bsa_control/proc/deploy(force=FALSE)
	var/obj/machinery/bsa/full/prebuilt = locate() in range(7) //In case of adminspawn
	if(prebuilt)
		prebuilt.control_computer = src
		connected_cannon = WEAKREF(prebuilt)
		return

	var/obj/machinery/bsa/middle/centerpiece = locate() in range(7)
	if(!centerpiece)
		notice = "No BSA parts detected nearby."
		return null
	notice = centerpiece.check_completion()
	if(notice)
		return null
	// These only apply when deployment was staged through the hologram, and must run after check_completion().
	if(visualizing_position)
		if(visualization_center != get_turf(centerpiece))
			notice = "The BSA has been moved mid-deployment."
			stop_visualizing()
			return null
		if(visualization_front != get_turf(centerpiece.front_piece?.resolve()))
			notice = "The BSA has been rotated mid-deployment."
			stop_visualizing()
			return null
		stop_visualizing()
	//Totally nanite construction system not an immersion breaking spawning
	do_smoke(4, centerpiece, get_turf(centerpiece))
	var/obj/machinery/bsa/full/cannon = new(get_turf(centerpiece), centerpiece.get_cannon_direction())
	cannon.control_computer = src
	if(centerpiece.front_piece)
		qdel(centerpiece.front_piece.resolve())
	if(centerpiece.back_piece)
		qdel(centerpiece.back_piece.resolve())
	qdel(centerpiece)
	connected_cannon = WEAKREF(cannon)

