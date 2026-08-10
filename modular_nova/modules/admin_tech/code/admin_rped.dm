// Originally from: NOVA MODULE ICSPAWNING https://github.com/Skyrat-SS13/Skyrat-tg/pull/104

/// Ceiling on how many of one type a single manufacture selection may produce.
#define RPED_MAX_BATCH_SIZE 100

/obj/item/storage/part_replacer/bluespace/admin
	name = "subspace rped"
	desc = "A specialized bluespace RPED for technicians that can manufacture stock parts on the fly. Fills in whatever \
		a machine or an unbuilt frame is missing before it gets to work, so nothing is ever short a part."
	storage_type = /datum/storage/rped/bluespace/admin
	w_class = WEIGHT_CLASS_TINY
	slot_flags = ITEM_SLOT_ADMIN
	resistance_flags = INDESTRUCTIBLE
	obj_flags = parent_type::obj_flags | ADMIN_OBJ_FLAGS
	obj_flags_nova = parent_type::obj_flags_nova | ADMIN_OBJ_FLAGS_NOVA
	/// Whether or not auto-clear is enabled
	var/auto_clear = TRUE
	/// How many of a given type the manufacture menu produces per selection.
	var/batch_size = 30
	/// List of valid types for pick_stock_part().
	var/static/list/valid_stock_part_types = list(
		/obj/item/circuitboard/machine,
		/obj/item/circuitboard/computer,
		/obj/item/stock_parts,
		/obj/item/stack/sheet,
		/obj/item/reagent_containers/cup/beaker,
	)
	/// Manufacture menu entries that batch out a fixed set of types. Add an entry here rather than another else-if.
	var/static/list/bulk_manufacture_options = list(
		"Tier 4 Parts" = list(
			/obj/item/stock_parts/capacitor/quadratic,
			/obj/item/stock_parts/scanning_module/triphasic,
			/obj/item/stock_parts/servo/femto,
			/obj/item/stock_parts/micro_laser/quadultra,
			/obj/item/stock_parts/matter_bin/bluespace,
			/obj/item/stock_parts/power_store/cell/bluespace,
			/obj/item/stock_parts/power_store/battery/bluespace,
		),
		"Cable Coils" = list(/obj/item/stack/cable_coil),
		"Glass Sheets" = list(/obj/item/stack/sheet/glass),
		"Plasteel Sheets" = list(/obj/item/stack/sheet/plasteel),
		"Bluespace Crystals" = list(/obj/item/stack/sheet/bluespace_crystal),
		"Infinite Megacell" = list(/obj/item/stock_parts/power_store/battery/infinite),
		"Infinite Power Cell" = list(/obj/item/stock_parts/power_store/cell/infinite),
	)
	/// Manufacture menu entries that open the subtype browser at the given root. Roots must pass valid_stock_part_types.
	var/static/list/browse_manufacture_options = list(
		"Machine Boards" = /obj/item/circuitboard/machine,
		"Computer Boards" = /obj/item/circuitboard/computer,
		"Stock Parts" = /obj/item/stock_parts,
		"Material Sheets" = /obj/item/stack/sheet,
		"Beakers" = /obj/item/reagent_containers/cup/beaker,
	)

/obj/item/storage/part_replacer/bluespace/admin/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/manufacturer_examine, COMPANY_ADMIN)
	// A frame's own item_interaction runs ahead of interact_with_atom on the held item, so this signal is the only
	// hook early enough to stock the RPED before the frame empties it.
	RegisterSignal(src, COMSIG_ITEM_INTERACTING_WITH_ATOM, PROC_REF(on_interacting_with_atom))

/obj/item/storage/part_replacer/bluespace/admin/examine(mob/user)
	. = ..()
	. += span_notice("Alt-Right-Click to manufacture parts, set the batch size, or clear its internal storage.")
	. += span_notice("Leftovers pulled out of an upgraded machine are [auto_clear ? "destroyed" : "kept"].")

/**
 * Tops the RPED up with whatever an unbuilt machine frame is still asking for.
 *
 * Returns NONE unconditionally so the frame's own interaction still runs and installs the parts.
 * Arguments:
 * * source - the RPED itself
 * * user - the mob holding the RPED
 * * target - what is being clicked; only machine frames are handled
 * * modifiers - click modifiers, unused
 */
/obj/item/storage/part_replacer/bluespace/admin/proc/on_interacting_with_atom(datum/source, mob/living/user, atom/target, list/modifiers)
	SIGNAL_HANDLER
	if(!istype(target, /obj/structure/frame/machine))
		return NONE
	var/obj/structure/frame/machine/machine_frame = target
	// Prioritize using the circuit's components list first, if present, to maintain consistency.
	var/obj/item/circuitboard/machine/circuit = machine_frame.circuit
	var/list/required = istype(circuit) ? circuit.req_components : machine_frame.req_components
	if(length(required))
		spawn_parts_for_components(user, required)
	return NONE

/datum/storage/rped/bluespace/admin
	max_slots = 1000
	max_total_storage = 20000

/obj/item/storage/part_replacer/bluespace/admin/PopulateContents()
	for(var/i in 1 to 30)
		new /obj/item/stock_parts/capacitor/quadratic(src)
		new /obj/item/stock_parts/scanning_module/triphasic(src)
		new /obj/item/stock_parts/servo/femto(src)
		new /obj/item/stock_parts/micro_laser/quadultra(src)
		new /obj/item/stock_parts/matter_bin/bluespace(src)
		new /obj/item/stock_parts/power_store/cell/bluespace(src)
		new /obj/item/stock_parts/power_store/battery/bluespace(src)
		new /obj/item/reagent_containers/cup/beaker/bluespace(src)
		new /obj/item/stack/cable_coil/(src)
		new /obj/item/stack/sheet/glass(src)
		new /obj/item/stack/sheet/plasteel(src)
		new /obj/item/stack/sheet/bluespace_crystal(src)

/// An extension to the default RPED part replacement action - if you don't have the requisite parts in the RPED already, it will spawn T4 versions to use.
/obj/item/storage/part_replacer/bluespace/admin/interact_with_atom(obj/attacked_object, mob/living/user, list/modifiers)
	//duplicate checks from parent since we need to stock up before the parent actually swaps anything
	if(user.combat_mode)
		return ITEM_INTERACT_SKIP_TO_ATTACK
	if(!ismachinery(attacked_object) || istype(attacked_object, /obj/machinery/computer))
		return NONE
	var/obj/machinery/attacked_machinery = attacked_object
	if(!LAZYLEN(attacked_machinery.component_parts))
		return ITEM_INTERACT_FAILURE

	// Auto-clear tells the machine's old parts from ours by comparing against this.
	var/list/old_contents = auto_clear ? atom_storage.return_inv(FALSE) : null

	// There's no good way to get required components off of an already-built machine, so we go through its circuit.
	var/obj/item/circuitboard/machine/circuit = attacked_machinery.circuit
	if(istype(circuit))
		spawn_parts_for_components(user, circuit.req_components)

	. = ..()

	if(!auto_clear)
		return .
	for(var/obj/item/stored_item in atom_storage.return_inv(FALSE))
		if(!(stored_item in old_contents))
			qdel(stored_item)
	return .

/// A bespoke proc for spawning in parts
/obj/item/storage/part_replacer/bluespace/admin/proc/spawn_parts_for_components(mob/living/user, list/required_components)
	for(var/req_component, amount_required in required_components)
		if(!amount_required)
			continue

		// Stacks first: they're a special kind of item, matched and spawned by amount.
		if(ispath(req_component, /obj/item/stack))
			restock_stack(user, req_component, amount_required)
			continue

		// Any other physical item: matched and spawned one-for-one.
		if(ispath(req_component, /obj/item))
			restock_items(user, req_component, amount_required)
			continue

		// Stock part datums, which stand in for a physical object (and a tier of it).
		if(ispath(req_component, /datum/stock_part))
			restock_stock_part(user, req_component, amount_required)
			continue

		// Anything else means a malformed recipe - let someone know.
		to_chat(user, span_notice("Something went wrong manufacturing [req_component]. Alert the devs, and let them know what machine it was!"))


/// Top a stack up to the required amount.
/// Stacks auto-split on Initialize, so a single spawn covers whatever's short.
/obj/item/storage/part_replacer/bluespace/admin/proc/restock_stack(mob/living/user, stack_type, amount_required)
	var/list/valid_types = typesof(stack_type)
	var/found = 0
	for(var/obj/item/stack/stored_stack in contents)
		if(!(stored_stack.type in valid_types))
			continue
		found += stored_stack.amount
		if(found >= amount_required)
			return // Already have enough - nothing to spawn.

	atom_storage.attempt_insert(new stack_type(src, amount_required - found), user, TRUE)

/// Spawn one item per unit still missing after counting what we already hold.
/obj/item/storage/part_replacer/bluespace/admin/proc/restock_items(mob/living/user, item_type, amount_required)
	var/found = count_stored(typesof(item_type), amount_required)
	spawn_shortfall(user, item_type, amount_required - found)

/// Stock parts are datums mapped onto physical objects, sometimes at a specific tier.
/obj/item/storage/part_replacer/bluespace/admin/proc/restock_stock_part(mob/living/user, datum/stock_part/part_type, amount_required)
	// A specific tier above the basic one was asked for: match and spawn exactly that item.
	if(initial(part_type.tier) > 1)
		var/exact_type = initial(part_type.physical_object_type)
		var/found = count_stored(list(exact_type), amount_required)
		spawn_shortfall(user, exact_type, amount_required - found)
		return

	// Otherwise any physical object in the base type's family counts.
	var/base_type = initial(part_type.physical_object_base_type)
	var/found = count_stored(typesof(base_type), amount_required)
	if(found >= amount_required)
		return

	// We're short, so spawn the highest tier variant this part has available.
	var/spawn_type = base_type
	var/highest_tier = 0
	for(var/datum/stock_part/variant as anything in typesof(part_type))
		if(initial(variant.tier) <= highest_tier)
			continue
		highest_tier = initial(variant.tier)
		spawn_type = initial(variant.physical_object_type)

	spawn_shortfall(user, spawn_type, amount_required - found)

/// Count stored items whose type is in valid_types, stopping once we've seen enough.
/obj/item/storage/part_replacer/bluespace/admin/proc/count_stored(list/valid_types, threshold)
	var/found = 0
	for(var/obj/stored_item in contents)
		if(!(stored_item.type in valid_types))
			continue
		found += 1
		if(found >= threshold)
			break
	return found

/// Insert `amount` freshly-spawned copies of atom_type. A non-positive amount inserts nothing.
/obj/item/storage/part_replacer/bluespace/admin/proc/spawn_shortfall(mob/living/user, atom_type, amount)
	for(var/i in 1 to amount)
		atom_storage.attempt_insert(new atom_type(src), user, TRUE)

/// BSTs' special Bluespace RPED can manufacture parts on Alt-RMB, either cables, glass, machine boards, or stock parts.
/obj/item/storage/part_replacer/bluespace/admin/click_alt_secondary(mob/user)
	// Every other tool in this module gates its admin-only half the same way, and this one hands out infinite tier 4 parts.
	if(!user.client?.holder)
		return

	// Ask the user what they want to make, or if they want to clear the storage.
	var/list/menu = list("Clear All Items", "Toggle Auto-Clear", "Set Batch Size")
	menu += bulk_manufacture_options
	menu += browse_manufacture_options
	var/spawn_selection = tgui_input_list(user, "Pick a part, or clear storage", "RPED Manufacture", menu)
	// If they didn't cancel out of the list selection, we do things.  Clear-all removes all items, auto-clear destroys left-overs after upgrades, and everything else is pretty self-explanatory.
	// Machine boards and stock parts use a recursive subtype selector.
	if(isnull(spawn_selection))
		return

	switch(spawn_selection)
		if("Clear All Items")
			for(var/obj/item/stored_item in atom_storage.return_inv(FALSE))
				qdel(stored_item)
		if("Toggle Auto-Clear")
			auto_clear = !auto_clear
			to_chat(user, span_notice("The RPED will now [(auto_clear ? "destroy" : "keep")] items left over after upgrades."))
		if("Set Batch Size")
			var/new_size = tgui_input_number(user, "How many of each type should a selection produce?", "RPED Batch Size", batch_size, RPED_MAX_BATCH_SIZE, 1)
			if(isnull(new_size))
				return
			batch_size = new_size
			to_chat(user, span_notice("The RPED will now produce [batch_size] of each type per selection."))
		else
			var/list/bulk_types = bulk_manufacture_options[spawn_selection]
			if(bulk_types)
				for(var/obj/item/part_type as anything in bulk_types)
					for(var/i in 1 to batch_size)
						atom_storage.attempt_insert(new part_type(src), user, TRUE)
			else
				pick_stock_part(user, FALSE, browse_manufacture_options[spawn_selection])

/// A bespoke proc for picking a subtype to spawn in a relatively user-friendly way.
/obj/item/storage/part_replacer/bluespace/admin/proc/pick_stock_part(mob/user, recurse, subtype)
	// Sanity check: make sure it's actually an item, and not an atom, machine, or whatever else someone might try to feed it down the line.
	if(!is_path_in_list(subtype, valid_stock_part_types))//This line is what eats new stock parts in the subtype check, update in var at top
		return
	// Stores a list of pretty type names : actual paths.
	var/list/items_temp = list()
	// Grab the initial list of paths, NOT INCLUDING this specific path.
	var/list/paths = subtypesof(subtype)

	// Simplistic check to only list top-level subtypes.
	var/list/top_level_subtypes_only = list()
	for(var/datum/subtype_path as anything in paths)
		if(initial(subtype_path.parent_type) != subtype)
			continue
		top_level_subtypes_only += subtype_path
	paths = top_level_subtypes_only

	// With all sub-subtypes removed, initialize the list of valid, spawnable items & their pretty names - and if this is a recursion, include the original subtype.
	if(recurse)
		paths += subtype
	for(var/path in paths)
		var/obj/path_as_obj = path
		// Generates a pretty list of item names & paths, including notes for those with subtypes.  When browsing subtypes, the parent won't have the (# more) note added.
		if(length(subtypesof(path)))
			if(path == subtype)
				items_temp["[initial(path_as_obj.name)]: [path]"] = path
			else
				items_temp["[initial(path_as_obj.name)] (+[length(subtypesof(path))] more): [path]"] = path
		else
			items_temp["[initial(path_as_obj.name)]: [path]"] = path

	// Finally, once the listed is generated, ask the user what they want to spawn.
	var/target_item = tgui_input_list(user, "Select Subtype", "RPED Manufacture", sort_list(items_temp))
	if(!target_item)
		return
	// If they select something, and the name:path binding is valid, then either spawn it, OR, if it has subtypes, and isn't the parent type, recurse to let them pick a subtype.
	var/the_item = items_temp[target_item]
	if(!the_item)
		return
	if(length(subtypesof(the_item)) && the_item != subtype)
		pick_stock_part(user, TRUE, the_item)
		return
	for(var/i in 1 to batch_size)
		atom_storage.attempt_insert(new the_item(src), user, TRUE)

#undef RPED_MAX_BATCH_SIZE
