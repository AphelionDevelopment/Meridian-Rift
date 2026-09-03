/**
 * # Salvage hand-cart
 *
 * A rideable single-tile flatbed for hauling shipbreaking salvage.
 * Carries loose items in a storage bed and one large ship structure
 * (hull plating, tanks, engines, scanners) loaded by drag-drop.
 */
/datum/armor/vehicle_salvage_cart
	melee = 20
	bullet = 10
	laser = 10
	bomb = 10
	fire = 60
	acid = 60

/**
 * # Salvage hand-cart vehicle
 *
 * Rideable flatbed with a storage bed for loose items and a single
 * structure slot for large ship parts. Structures load by drag-drop
 * when adjacent and unanchored, unload by hand or alt-click.
 */
/obj/vehicle/ridden/salvage_cart
	name = "salvage hand-cart"
	desc = "A sturdy teal flatbed for hauling ship salvage. Drag a loose ship structure onto it to load the bed."
	icon = 'modular_aphelion/modules/shipbreaking/icons/salvage_cart.dmi'
	icon_state = "salvage_cart"
	max_buckled_mobs = 1
	max_occupants = 1
	max_integrity = 250
	armor_type = /datum/armor/vehicle_salvage_cart
	movedelay = 1.6
	custom_materials = list(/datum/material/aluminum = SHEET_MATERIAL_AMOUNT * 8)
	/// Large ship structure currently hauled on the bed, if any
	var/obj/loaded_structure
	/// Structures and machines the bed accepts. Machinery included: engines, scanners, recycler.
	var/static/list/loadable_structures = typecacheof(list(
		/obj/structure/hull_plating,
		/obj/structure/shuttle_decoration/liquid_tank,
		/obj/machinery/power/shuttle_engine,
		/obj/machinery/exoscanner,
		/obj/structure/titanium_structure,
		/obj/structure/door_assembly,
		/obj/machinery/recycler,
	))

/obj/vehicle/ridden/salvage_cart/Initialize(mapload)
	. = ..()
	create_storage(max_slots = 7, max_specific_storage = WEIGHT_CLASS_BULKY, max_total_storage = WEIGHT_CLASS_BULKY * 7)
	register_context()
	AddElement(/datum/element/ridable, /datum/component/riding/vehicle/salvage_cart)

/obj/vehicle/ridden/salvage_cart/Destroy()
	if(loaded_structure)
		UnregisterSignal(loaded_structure, COMSIG_QDELETING)
		loaded_structure.forceMove(drop_location())
		loaded_structure = null
	return ..()

/**
 * Checks whether a target can be loaded onto the bed.
 *
 * Arguments:
 * * target - The obj to check
 */
/obj/vehicle/ridden/salvage_cart/proc/can_load_structure(obj/target)
	if(loaded_structure)
		return FALSE
	if(QDELETED(target))
		return FALSE
	if(!is_type_in_typecache(target, loadable_structures))
		return FALSE
	if(target.anchored)
		return FALSE
	if(target.has_buckled_mobs())
		return FALSE
	return TRUE

/**
 * Loads a structure onto the bed, closing closets first.
 *
 * Arguments:
 * * target - The obj to load
 * * user - The mob loading it
 */
/obj/vehicle/ridden/salvage_cart/proc/load_structure(obj/target, mob/user)
	if(!can_load_structure(target))
		if(user)
			if(loaded_structure)
				balloon_alert(user, "bed occupied!")
			else if(target.anchored)
				balloon_alert(user, "anchored!")
			else
				balloon_alert(user, "cannot load that!")
		return FALSE
	if(!Adjacent(target))
		if(user)
			balloon_alert(user, "too far!")
		return FALSE
	if(istype(target, /obj/structure/closet))
		var/obj/structure/closet/closet_target = target
		closet_target.close()
	target.forceMove(src)
	loaded_structure = target
	RegisterSignal(loaded_structure, COMSIG_QDELETING, PROC_REF(on_loaded_qdeleting))
	update_appearance()
	if(user)
		balloon_alert(user, "loaded [target.name]")
		playsound(src, 'sound/items/tools/ratchet.ogg', 50, TRUE)
	return TRUE

/**
 * Unloads the hauled structure onto a nearby turf.
 *
 * Arguments:
 * * user - The mob unloading it
 */
/obj/vehicle/ridden/salvage_cart/proc/unload_structure(mob/user)
	if(!loaded_structure)
		return FALSE
	var/obj/unloaded = loaded_structure
	UnregisterSignal(unloaded, COMSIG_QDELETING)
	loaded_structure = null
	var/turf/dropoff = get_turf(src)
	if(!dropoff.Enter(unloaded, src))
		dropoff = drop_location()
	unloaded.forceMove(dropoff)
	update_appearance()
	if(user)
		balloon_alert(user, "unloaded [unloaded.name]")
		playsound(src, 'sound/items/deconstruct.ogg', 50, TRUE)
	return TRUE

/**
 * Clears the bed reference when the loaded structure is deleted.
 */
/obj/vehicle/ridden/salvage_cart/proc/on_loaded_qdeleting(datum/source)
	SIGNAL_HANDLER
	if(source == loaded_structure)
		loaded_structure = null
		update_appearance()

/obj/vehicle/ridden/salvage_cart/mouse_drop_receive(atom/dropped, mob/user, params)
	if(isobj(dropped) && can_load_structure(dropped))
		load_structure(dropped, user)
		return
	return ..()

/obj/vehicle/ridden/salvage_cart/attack_hand(mob/user, list/modifiers)
	if(loaded_structure)
		unload_structure(user)
		return TRUE
	return ..()

/obj/vehicle/ridden/salvage_cart/click_alt(mob/user)
	if(loaded_structure)
		unload_structure(user)
		return CLICK_ACTION_SUCCESS
	return NONE

/obj/vehicle/ridden/salvage_cart/update_overlays()
	. = ..()
	if(!loaded_structure)
		return
	if(!loaded_structure.icon)
		return
	. += mutable_appearance(loaded_structure.icon, loaded_structure.icon_state, layer + 0.1)

/obj/vehicle/ridden/salvage_cart/handle_deconstruct(disassembled = TRUE)
	if(loaded_structure)
		UnregisterSignal(loaded_structure, COMSIG_QDELETING)
		loaded_structure.forceMove(drop_location())
		loaded_structure = null
	return ..()

/obj/vehicle/ridden/salvage_cart/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change = TRUE)
	. = ..()
	if(loaded_structure && prob(15))
		playsound(src, 'sound/vehicles/skateboard_roll.ogg', 20, TRUE)

/obj/vehicle/ridden/salvage_cart/add_context(atom/source, list/context, obj/item/held_item, mob/user)
	. = ..()
	if(!held_item && loaded_structure)
		context[SCREENTIP_CONTEXT_LMB] = "Unload structure"
		context[SCREENTIP_CONTEXT_ALT_LMB] = "Unload structure"
		return CONTEXTUAL_SCREENTIP_SET

/**
 * # Salvage hand-cart riding datum
 *
 * Keyless slow flatbed. Rider sits centered on the bed.
 */
/datum/component/riding/vehicle/salvage_cart
	keytype = null
	ride_check_flags = RIDER_NEEDS_LEGS | UNBUCKLE_DISABLED_RIDER
	vehicle_move_delay = 2

/datum/component/riding/vehicle/salvage_cart/get_rider_offsets_and_layers(pass_index, mob/offsetter)
	return list(
		TEXT_NORTH = list(0, 6),
		TEXT_SOUTH = list(0, 6),
		TEXT_EAST = list(0, 6),
		TEXT_WEST = list(0, 6),
	)
