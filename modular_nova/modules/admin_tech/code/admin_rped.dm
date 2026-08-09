// Originally from: NOVA MODULE ICSPAWNING https://github.com/Skyrat-SS13/Skyrat-tg/pull/104
/obj/item/storage/part_replacer/bluespace/admin
	name = "subspace rped"
	desc = "A specialized bluespace RPED for technicians that can manufacture stock parts on the fly. It fills in \
		whatever a machine or an unbuilt frame is missing before it works, so nothing is ever short a part."
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
	// A machine frame is a structure rather than machinery, and a frame's own item_interaction runs before any
	// interact_with_atom on the thing held - so the frame handling that used to sit in interact_with_atom below could
	// never fire. This signal goes out ahead of both, which lets us stock up and then let the frame install as normal.
	RegisterSignal(src, COMSIG_ITEM_INTERACTING_WITH_ATOM, PROC_REF(on_interacting_with_atom))

/obj/item/storage/part_replacer/bluespace/admin/examine(mob/user)
	. = ..()
	. += span_notice("Alt-Right-Click to manufacture parts, set the batch size, or clear its internal storage.")
	. += span_notice("Leftovers pulled out of an upgraded machine are [auto_clear ? "destroyed" : "kept"].")

/// Tops the RPED up with whatever an unbuilt machine frame is still asking for, then stands aside so the frame installs them.
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

	// Snapshot taken before the swap so auto-clear can tell what came out of the machine from what we walked in with.
	var/list/old_contents = auto_clear ? atom_storage.return_inv(FALSE) : null

	// There's no good way to get required components off of an already-built machine, so we go through its circuit.
	var/obj/item/circuitboard/machine/circuit = attacked_machinery.circuit
	if(istype(circuit))
		spawn_parts_for_components(user, circuit.req_components)

	. = ..()

	if(!auto_clear)
		return
	for(var/obj/item/stored_item in atom_storage.return_inv(FALSE))
		if(!(stored_item in old_contents))
			qdel(stored_item)

/// A bespoke proc for spawning in parts
/obj/item/storage/part_replacer/bluespace/admin/proc/spawn_parts_for_components(mob/living/user, list/required_components)
	// Since req_components in machineboards can list item types *OR* /datum/stock_part subtypes this gets a little complicated.
	for(var/req_component in required_components)
		// Start off noting how many the recipe calls for, a counter for how many matching parts have been found, and generating a list of subtypes for use in later checks.
		var/parts_amount_required = required_components[req_component]
		var/found_matching = 0
		var/list/subtypes = typesof(req_component)

		if(!parts_amount_required)
			continue

		/// Then, check if the requested component is an object subtype - this means it's probably either materials (e.g, cables) or non-stock_part subtypes like beakers.
		if(ispath(req_component, /obj/item))
			// If it's a stack, it needs special treatment.
			if(ispath(req_component, /obj/item/stack))
				// Stacks generate the matching count based on how many matching stacks are in the RPED's inventory with sufficient count.
				// To find stacks inside the RPED, we search its contents for anything that's a subtype of /obj/item/stack.
				for(var/obj/item/stack/stored_stack in contents)
					// If a stack item is found, we check if it's in the typesof list for the current requested component, and if so, mark its count.
					if(stored_stack.type in subtypes)
						found_matching += stored_stack.amount
						// If there's enough, we can return early.
						if(found_matching >= parts_amount_required)
							break
				// If there's not enough left, spawn enough of the appropriate type that there will be.  Stacks' Initialialize accepts an amount for the newly-spawned stack to have, and will auto-split as needed.
				if(found_matching < parts_amount_required)
					atom_storage.attempt_insert(new req_component(src, parts_amount_required - found_matching), user, TRUE)
				continue

			// It's not a stack, which means now we have to count how many matching items are present.
			for(var/obj/stored_item in contents)
				if(stored_item.type in subtypes)
					found_matching += 1
					// If there's enough, we can break - no need to spawn extras.
					if(found_matching >= parts_amount_required)
						break
			// If there's still not enough, we're going to have to spawn enough in manually.
			for(var/i in 1 to parts_amount_required - found_matching)
				atom_storage.attempt_insert(new req_component(src), user, TRUE)
			continue

		/// If it's not an obj, then it's a subtype of /datum/stock_part - or *should be*, anyway.
		if(ispath(req_component, /datum/stock_part))
			var/datum/stock_part/part_type = req_component
			// initial() rather than instantiating the datum - we only ever want to read the tier and the paths off it.
			var/base_type = initial(part_type.physical_object_base_type)

			// Specific machines sometimes call for specific tiers of part; give them precisely what they ask for, just in case.
			if(initial(part_type.tier) > 1)
				base_type = initial(part_type.physical_object_type)
				// Search to see if we have enough of that exact item, and if not, we'll spawn more.
				for(var/obj/stored_item in contents)
					if(stored_item.type == base_type)
						found_matching += 1
						// If there's enough, we can return early.
						if(found_matching >= parts_amount_required)
							break
			else
				// For everything else, just make sure we have enough valid items of the stock part's subtypes.
				subtypes = typesof(base_type)
				for(var/obj/stored_item in contents)
					if(stored_item.type in subtypes)
						found_matching += 1
						// If there's enough, we can return early.
						if(found_matching >= parts_amount_required)
							break

				if(found_matching < parts_amount_required)
					// Pick the highest tier the requested part has available, so machines get the best we can give them.
					var/highest_tier = 0
					for(var/datum/stock_part/sub_part as anything in typesof(req_component))
						if(initial(sub_part.tier) > highest_tier)
							highest_tier = initial(sub_part.tier)
							base_type = initial(sub_part.physical_object_type)

			// Once the best component has been found, fill in enough remaining.
			for(var/i in 1 to parts_amount_required - found_matching)
				atom_storage.attempt_insert(new base_type(src), user, TRUE)
			continue

		// If it's not a /datum/stock_part subtype either, something has gone wrong and devs should probably be alerted.
		to_chat(user, span_notice("Something went wrong manufacturing [req_component]. Alert the devs, and let them know what machine it was!"))

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
			var/new_size = tgui_input_number(user, "How many of each type should a selection produce?", "RPED Batch Size", batch_size, 100, 1)
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
