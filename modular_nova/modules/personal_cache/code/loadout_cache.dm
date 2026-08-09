// THIS IS A MODULAR NOVA SECTOR FILE - PERSONAL_CACHE
// The "Cache" tab and everything that lives in it
/datum/loadout_category/cache
	category_name = "Cache"
	category_ui_icon = FA_ICON_BOX_ARCHIVE
	type_to_generate = /datum/loadout_item/cache
	tab_order = /datum/loadout_category/pocket::tab_order + 1
	/// cache_slot -> max simultaneous selections of that slot.
	VAR_PRIVATE/list/slot_limits = list(
		CACHE_SLOT_TANK = 1,
		CACHE_SLOT_MASK = 1,
		CACHE_SLOT_RATION = 2,
		CACHE_SLOT_GENERAL = 2,
	)
	/// cache_slot -> what the tab blurb calls it. New slot? One line here, one in slot_limits, and the blurb writes itself.
	VAR_PRIVATE/list/slot_labels = list(
		CACHE_SLOT_TANK = "Tanks",
		CACHE_SLOT_MASK = "Masks",
		CACHE_SLOT_RATION = "Rations",
		CACHE_SLOT_GENERAL = "General",
	)

// Slaps the slot counts into the tab's blurb text
/datum/loadout_category/cache/New()
	. = ..()
	var/list/blurb = list()
	for(var/slot in slot_limits)
		blurb += "[slot_labels[slot] || slot]: [slot_limits[slot]]"
	category_info = jointext(blurb, " | ")

/// One max-selected limit per cache_slot, oldest pick evicted first once you're over. Same trick as /datum/loadout_category/pocket.
/datum/loadout_category/cache/handle_duplicate_entires(
	datum/preference_middleware/loadout/manager,
	datum/loadout_item/conflicting_item,
	datum/loadout_item/added_item,
	list/datum/loadout_item/all_loadout_items,
)
	var/datum/loadout_item/cache/incoming = added_item
	var/max_allowed = slot_limits[incoming.cache_slot]
	if(isnull(max_allowed))
		return TRUE

	var/list/datum/loadout_item/cache/same_slot = list()
	for(var/datum/loadout_item/cache/existing in all_loadout_items)
		if(existing.cache_slot != incoming.cache_slot)
			continue
		same_slot += existing

	if(length(same_slot) >= max_allowed)
		manager.deselect_item(same_slot[1])
	return TRUE

/datum/loadout_item/cache
	abstract_type = /datum/loadout_item/cache
	/// Which Cache slot we belong to - CACHE_SLOT_* defines live in code\__DEFINES\~nova_defines\customization\personal_cache.dm
	var/cache_slot
	/// cache_slot -> the basetype a fresh pick of that slot bumps out of its pouch (new tank evicts the old tank, etc). Not listed = purely additive. See place_in_cache().
	var/static/list/slot_to_replaced_type = list(
		CACHE_SLOT_TANK = /obj/item/tank/internals,
		CACHE_SLOT_MASK = /obj/item/clothing/mask,
	)

// Cache items skip the whole "getting worn" song and dance and go straight into the Bluespace Cache.
/datum/loadout_item/cache/insert_path_into_outfit(datum/outfit/outfit, mob/living/carbon/human/equipper, visuals_only = FALSE, override_items = LOADOUT_OVERRIDE_BACKPACK)
	if(!visuals_only)
		LAZYADD(outfit.backpack_contents, item_path)

/datum/loadout_item/cache/on_equip_item(obj/item/equipped_item, list/item_details, mob/living/carbon/human/equipper, datum/outfit/outfit, visuals_only = FALSE)
	..() // custom name, description, reskin and objective-blocking - a Cache pick is still a loadout pick, and the UI offers those buttons either way
	if(visuals_only || isnull(equipper) || isnull(equipped_item))
		return NONE

	var/obj/item/storage/box/survival/cache_box = locate(/obj/item/storage/box/survival) in equipper.get_all_gear()
	place_in_cache(cache_box, equipped_item)
	return NONE // nothing here is ever worn, so there's no slot to redraw

/// Drops spawned_item into cache_box's pouch for our slot (or the root if there's no pouch for it), booting whatever it replaces. No valid home for it? Deletes it - callers never babysit orphans. TRUE if it landed somewhere, FALSE if it got binned.
/datum/loadout_item/cache/proc/place_in_cache(obj/item/storage/box/survival/cache_box, obj/item/spawned_item)
	if(isnull(spawned_item))
		return FALSE

	var/replaced_type = slot_to_replaced_type[cache_slot]
	if(isnull(cache_box) || (replaced_type && cache_box.cache_locked))
		qdel(spawned_item)
		return FALSE

	var/atom/destination = cache_box.get_pouch_for_slot(cache_slot) || cache_box
	if(replaced_type)
		for(var/obj/item/existing in destination.contents.Copy())
			if(existing != spawned_item && istype(existing, replaced_type))
				qdel(existing)

	spawned_item.forceMove(destination)
	return TRUE

// --- Air Tanks ---
/datum/loadout_item/cache/tank
	abstract_type = /datum/loadout_item/cache/tank
	cache_slot = CACHE_SLOT_TANK
	group = "Air Tanks"

/datum/loadout_item/cache/tank/emergency
	name = "Emergency Oxygen Tank"
	item_path = /obj/item/tank/internals/emergency_oxygen

/datum/loadout_item/cache/tank/extended
	name = "Extended-Capacity Oxygen Tank"
	item_path = /obj/item/tank/internals/emergency_oxygen/engi

/datum/loadout_item/cache/tank/double
	name = "Double Emergency Oxygen Tank"
	item_path = /obj/item/tank/internals/emergency_oxygen/double

// The belt-sized one, not the full brick - that one's NORMAL and couldn't be put back into the survival matrix once taken out.
/datum/loadout_item/cache/tank/plasmaman
	name = "Plasmaman Gas Tank"
	item_path = /obj/item/tank/internals/plasmaman/belt

// --- Breathing Masks ---
/datum/loadout_item/cache/mask
	abstract_type = /datum/loadout_item/cache/mask
	cache_slot = CACHE_SLOT_MASK
	group = "Breathing Masks"

/datum/loadout_item/cache/mask/standard
	name = "Standard Breath Mask"
	item_path = /obj/item/clothing/mask/breath

/datum/loadout_item/cache/mask/medical
	name = "Medical Breath Mask"
	item_path = /obj/item/clothing/mask/breath/medical

// A subtype, not the base gas mask - the loadout list can't have the same typepath twice without runtiming. Explorer over sechailer so we're not handing the whole crew a Compli-o-nator 3000.
/datum/loadout_item/cache/mask/gas
	name = "Explorer Gas Mask"
	item_path = /obj/item/clothing/mask/gas/explorer/folded

// --- Ration Packs ---
/datum/loadout_item/cache/ration
	abstract_type = /datum/loadout_item/cache/ration
	cache_slot = CACHE_SLOT_RATION
	group = "Ration Packs"

/datum/loadout_item/cache/ration/plain
	name = "Donk-Pocket (Plain)"
	item_path = /obj/item/food/donkpocket

/datum/loadout_item/cache/ration/spicy
	name = "Donk-Pocket (Spicy)"
	item_path = /obj/item/food/donkpocket/spicy

/datum/loadout_item/cache/ration/teriyaki
	name = "Donk-Pocket (Teriyaki)"
	item_path = /obj/item/food/donkpocket/teriyaki

/datum/loadout_item/cache/ration/deluxe
	name = "Donk-Pocket (Deluxe)"
	item_path = /obj/item/food/donkpocket/deluxe

// --- Company-Issued Odds and Ends ---
/datum/loadout_item/cache/general
	abstract_type = /datum/loadout_item/cache/general
	cache_slot = CACHE_SLOT_GENERAL
	group = "Company Accessories"

/datum/loadout_item/cache/general/dogtag
	name = "NanoTrasen Dogtag"
	item_path = /obj/item/clothing/accessory/dogtag

/datum/loadout_item/cache/general/conduct_medal
	name = "Medal of Conduct"
	item_path = /obj/item/clothing/accessory/medal/conduct

/datum/loadout_item/cache/general/service_ribbon
	name = "Service Ribbon"
	item_path = /obj/item/clothing/accessory/medal/ribbon

// Not an accessory by any stretch, so it gets its own shelf - and somewhere obvious to file future non-accessory general picks.
/datum/loadout_item/cache/general/tool
	abstract_type = /datum/loadout_item/cache/general/tool
	group = "Company Equipment"

/datum/loadout_item/cache/general/tool/multitool
	name = "Company-Issued Multitool"
	item_path = /obj/item/multitool
