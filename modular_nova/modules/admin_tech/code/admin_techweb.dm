/// Heres where the Administrative Fabricator and the Admin Techweb live

// techweb: modular_nova\master_files\code\modules\research\techweb\techweb_types.dm
// machine.dm define w/ nova edit code\__DEFINES\machines.dm
// TODO: sprites, flatpacks of common admin machines like the debug chem spawner, etc
/// Admin lathe, waow so cool, wow, wow so cool
/obj/machinery/rnd/production/colony_lathe/admin
	name = "administrative fabricator"
	desc = "A rapid construction fabricator with the feedstock stage removed entirely, which thermodynamics does not \
		ordinarily allow for. Everything it knows, it prints instantly and for free, and it knows every piece of \
		subspace equipment CentCom has ever quietly signed off on. Repacks into a flatpack."
	icon = 'modular_nova/modules/colony_fabricator/icons/machines.dmi'
	icon_state = "colony_lathe"
	base_icon_state = "colony_lathe"
	circuit = null
	production_animation = "colony_lathe_n"
	light_color = LIGHT_COLOR_BRIGHT_YELLOW
	light_power = 5
	allowed_buildtypes = ADMIN_TECHWEB | COLONY_FABRICATOR
	speedup_disabled = TRUE
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | ACID_PROOF
	techweb_path = /datum/techweb/autounlocking/admin
	repacked_type = /obj/item/flatpacked_machine/admin

/obj/machinery/rnd/production/colony_lathe/admin/give_manufacturer_examine()
	AddElement(/datum/element/manufacturer_examine, COMPANY_ADMIN)

// Zero coefficient means has_materials() and use_materials() both ask for nothing, so everything prints free.
/obj/machinery/rnd/production/colony_lathe/admin/build_efficiency(datum/design/design)
	return 0

/obj/machinery/rnd/production/colony_lathe/admin/examine(mob/user)
	. = ..()
	. += span_notice("It needs no material feedstock - every design prints instantly, at no cost, in any quantity.")
	. += span_notice("Alongside the administrative catalogue it carries everything a rapid construction fabricator knows.")

/// Flat-packed version of the administrative fabricator
/obj/item/flatpacked_machine/admin
	name = "flat-packed administrative fabricator"
	/// For all flatpacked machines, set the desc to the type_to_deploy followed by ::desc to reuse the type_to_deploy's description
	desc = /obj/machinery/rnd/production/colony_lathe/admin::desc
	icon = 'modular_nova/modules/colony_fabricator/icons/packed_machines.dmi'
	icon_state = "colony_lathe_packed"
	/// What structure is created by this item.
	type_to_deploy = /obj/machinery/rnd/production/colony_lathe/admin
	/// How long it takes to create the structure in question.
	deploy_time = 4 SECONDS
	w_class = WEIGHT_CLASS_TINY
	slot_flags = ITEM_SLOT_ADMIN
	resistance_flags = INDESTRUCTIBLE
	obj_flags = parent_type::obj_flags | ADMIN_OBJ_FLAGS
	obj_flags_nova = parent_type::obj_flags_nova | ADMIN_OBJ_FLAGS_NOVA

/obj/item/flatpacked_machine/admin/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/manufacturer_examine, COMPANY_ADMIN)

/**
 * Base design for everything the administrative fabricator prints
 *
 * New printables in this module subtype this and declare only name, id, build_path, and a category if the default
 * does not fit. Two constraints the CI unit tests enforce: RND_CATEGORY_INITIAL must stay in the category list or an
 * autounlocking techweb will not pick the design up, and the material cost must not be empty, because a design with a
 * build_path and no cost at all fails the design test. Nothing is charged in practice - the fabricator overrides
 * build_efficiency() to zero.
 */
/datum/design/admin
	build_type = ADMIN_TECHWEB
	materials = list(/datum/material/iron = SMALL_MATERIAL_AMOUNT)
	// The token cost must not be stamped onto what comes out, or a printed multitool ends up made of ten iron instead
	// of what it is normally made of. This also exempts these designs from the design_mats unit test, which otherwise
	// requires the design cost and the item's custom_materials to agree.
	inherit_materials = DESIGN_DONT_INHERIT_MATS
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_EQUIPMENT)

// Tools

/datum/design/admin/multitool
	name = "Subspace Multitool"
	id = "admin_multitool"
	build_path = /obj/item/multitool/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_TOOLS)

/datum/design/admin/welding_tool
	name = "Subspace Welding Tool"
	id = "admin_welding_tool"
	build_path = /obj/item/weldingtool/advanced/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_TOOLS)

/datum/design/admin/jaws_of_life
	name = "Subspace Jaws of Life"
	id = "admin_jaws_of_life"
	build_path = /obj/item/crowbar/power/alien/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_TOOLS)

/datum/design/admin/hand_drill
	name = "Subspace Hand Drill"
	id = "admin_hand_drill"
	build_path = /obj/item/screwdriver/power/alien/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_TOOLS)

/datum/design/admin/matter_manipulator
	name = "Subspace Matter Manipulator"
	id = "admin_matter_manipulator"
	build_path = /obj/item/construction/rcd/arcd/mattermanipulator/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_TOOLS)

/datum/design/admin/rld
	name = "Subspace Lighting Device"
	id = "admin_rld"
	build_path = /obj/item/construction/rld/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_TOOLS)

/datum/design/admin/plumbing_constructor
	name = "Subspace Plumbing Constructor"
	id = "admin_plumbing_constructor"
	build_path = /obj/item/construction/plumbing/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_TOOLS)

/datum/design/admin/part_replacer
	name = "Subspace Rapid Part Exchange Device"
	id = "admin_part_replacer"
	build_path = /obj/item/storage/part_replacer/bluespace/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_TOOLS)

/datum/design/admin/light_replacer
	name = "Subspace Light Replacer"
	id = "admin_light_replacer"
	build_path = /obj/item/lightreplacer/blue/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_TOOLS)

/datum/design/admin/forcefield_projector
	name = "Subspace Forcefield Projector"
	id = "admin_forcefield_projector"
	build_path = /obj/item/forcefield_projector/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_TOOLS)

/datum/design/admin/holosign_creator
	name = "Subspace Atmospheric Holofan Projector"
	id = "admin_holosign_creator"
	build_path = /obj/item/holosign_creator/atmos/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_TOOLS)

/datum/design/admin/extinguisher
	name = "Subspace Fire Extinguisher"
	id = "admin_extinguisher"
	build_path = /obj/item/extinguisher/subspace
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_TOOLS)

/datum/design/admin/mop
	name = "Subspace Advanced Mop"
	id = "admin_mop"
	build_path = /obj/item/mop/advanced/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_TOOLS)

/datum/design/admin/soap
	name = "Subspace Soap"
	id = "admin_soap"
	build_path = /obj/item/soap/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_TOOLS)

/datum/design/admin/shears
	name = "Subspace Botanical Shears"
	id = "admin_shears"
	build_path = /obj/item/shears/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_TOOLS)

/datum/design/admin/watering_can
	name = "Subspace Watering Can"
	id = "admin_watering_can"
	build_path = /obj/item/reagent_containers/cup/watering_can/advanced/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_TOOLS)

// Weaponry

/datum/design/admin/carbine
	name = "Subspace Carbine"
	id = "admin_carbine"
	build_path = /obj/item/gun/energy/modular_laser_rifle/carbine/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_WEAPONS)

/datum/design/admin/pneumatic_cannon
	name = "Subspace Ballmatter Mass Projector"
	id = "admin_pneumatic_cannon"
	build_path = /obj/item/pneumatic_cannon/subspace
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_WEAPONS)

/datum/design/admin/baseball_bat
	name = "Subspace Baseball Bat"
	id = "admin_baseball_bat"
	build_path = /obj/item/melee/baseball_bat/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_WEAPONS)

/datum/design/admin/dagenblicky
	name = "Subspace Mass Projector Pen"
	id = "admin_dagenblicky"
	build_path = /obj/item/gun/magic/subspace/dagenblicky
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_WEAPONS)

/datum/design/admin/fisher
	name = "Subspace Disruptor"
	id = "admin_fisher"
	build_path = /obj/item/gun/energy/recharge/fisher/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_WEAPONS)

/datum/design/admin/medigun
	name = "Subspace Medigun"
	id = "admin_medigun"
	build_path = /obj/item/gun/energy/cell_loaded/medigun/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_WEAPONS)

/datum/design/admin/reagent_gun
	name = "Subspace Reagent Gun"
	id = "admin_reagent_gun"
	build_path = /obj/item/gun/chem/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_WEAPONS)

/datum/design/admin/syringe_gun
	name = "Subspace Syringe Gun"
	id = "admin_syringe_gun"
	build_path = /obj/item/gun/syringe/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_WEAPONS)

// Equipment

/datum/design/admin/pda
	name = "Subspace PDA"
	id = "admin_pda"
	build_path = /obj/item/modular_computer/pda/admin

/datum/design/admin/headset
	name = "Bluespace Headset"
	id = "admin_headset"
	build_path = /obj/item/radio/headset/admin

/datum/design/admin/encryptionkey
	name = "Subspace Encryption Key"
	id = "admin_encryptionkey"
	build_path = /obj/item/encryptionkey/admin

/datum/design/admin/contacts
	name = "Subspace Contacts"
	id = "admin_contacts"
	build_path = /obj/item/clothing/glasses/meson/engine/admin/debug

/datum/design/admin/laser_pointer
	name = "Subspace Laser Pointer"
	id = "admin_laser_pointer"
	build_path = /obj/item/laser_pointer/admin

/datum/design/admin/door_remote
	name = "Subspace Door Remote"
	id = "admin_door_remote"
	build_path = /obj/item/door_remote/admin

/datum/design/admin/emag
	name = "Subspace Cryptographic Sequencer"
	id = "admin_emag"
	build_path = /obj/item/card/emag/admin

/datum/design/admin/target_locator
	name = "Subspace Target Locator"
	id = "admin_target_locator"
	build_path = /obj/item/pinpointer/crew/admin

/datum/design/admin/vendor_beacon
	name = "Debug Vendor Beacon"
	id = "admin_vendor_beacon"
	build_path = /obj/item/summon_beacon/vendors/debug

/datum/design/admin/job_locker_beacon
	name = "Debug Job Locker Beacon"
	id = "admin_job_locker_beacon"
	build_path = /obj/item/choice_beacon/job_locker/debug

/datum/design/admin/fan_capsule
	name = "Debug Tiny Fan Capsule"
	id = "admin_fan_capsule"
	build_path = /obj/item/survivalcapsule/admin/fan

/datum/design/admin/fabricator
	name = "Flat-packed Administrative Fabricator"
	id = "admin_fabricator"
	build_path = /obj/item/flatpacked_machine/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_CONSTRUCTION)

// Storage

/datum/design/admin/pocket
	name = "Bluespace Pocket"
	id = "admin_pocket"
	build_path = /obj/item/storage/bag/admin

/datum/design/admin/construction_bag
	name = "Bluespace Construction Bag"
	id = "admin_construction_bag"
	build_path = /obj/item/storage/bag/construction/admin

/datum/design/admin/pouch
	name = "Subspace Pouch"
	id = "admin_pouch"
	build_path = /obj/item/storage/subspace_pouch

/datum/design/admin/utility_belt
	name = "Bluespace Utility Belt"
	id = "admin_utility_belt"
	build_path = /obj/item/storage/belt/utility/admin/full

// Medical

/datum/design/admin/health_analyzer
	name = "Subspace Health Analyzer"
	id = "admin_health_analyzer"
	build_path = /obj/item/healthanalyzer/advanced/admin

/datum/design/admin/surgery_tray
	name = "Subspace Surgical Tray"
	id = "admin_surgery_tray"
	build_path = /obj/item/surgery_tray/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_TOOLS)

/datum/design/admin/hypospray
	name = "Subspace Hypospray"
	id = "admin_hypospray"
	build_path = /obj/item/reagent_containers/hypospray/combat/subspace

/datum/design/admin/chem_synth
	name = "Handheld Debug Chemical Synthesiser"
	id = "admin_chem_synth"
	build_path = /obj/item/handheld_debug_chem_synth

/datum/design/admin/beaker
	name = "Subspace Beaker"
	id = "admin_beaker"
	build_path = /obj/item/reagent_containers/cup/beaker/admin

/datum/design/admin/syringe
	name = "Subspace Syringe"
	id = "admin_syringe"
	build_path = /obj/item/reagent_containers/syringe/admin

/datum/design/admin/scalpel
	name = "Subspace Laser Scalpel"
	id = "admin_scalpel"
	build_path = /obj/item/scalpel/advanced/alien/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_TOOLS)

/datum/design/admin/retractor
	name = "Subspace Mechanical Pinches"
	id = "admin_retractor"
	build_path = /obj/item/retractor/advanced/alien/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_TOOLS)

/datum/design/admin/cautery
	name = "Subspace Searing Tool"
	id = "admin_cautery"
	build_path = /obj/item/cautery/advanced/alien/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_TOOLS)

/datum/design/admin/blood_filter
	name = "Subspace Medical Combitool"
	id = "admin_blood_filter"
	build_path = /obj/item/blood_filter/advanced/alien/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_TOOLS)

/datum/design/admin/ph_meter
	name = "Subspace pH Meter"
	id = "admin_ph_meter"
	build_path = /obj/item/ph_meter/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_TOOLS)

/datum/design/admin/patch_applicator
	name = "Subspace Patch Applicator"
	id = "admin_patch_applicator"
	build_path = /obj/item/reagent_containers/applicator/patch/admin

/datum/design/admin/pill_applicator
	name = "Subspace Pill Applicator"
	id = "admin_pill_applicator"
	build_path = /obj/item/reagent_containers/applicator/pill/admin

/datum/design/admin/beaker_noreact
	name = "Subspace Cryostasis Beaker"
	id = "admin_beaker_noreact"
	build_path = /obj/item/reagent_containers/cup/beaker/admin/noreact

/datum/design/admin/beaker_small
	name = "Small Subspace Beaker"
	id = "admin_beaker_small"
	build_path = /obj/item/reagent_containers/cup/beaker/admin/small

// Internals

/datum/design/admin/tank_oxygen
	name = "Oxygen Subspace Tank"
	id = "admin_tank_oxygen"
	build_path = /obj/item/tank/internals/admin/oxygen

/datum/design/admin/tank_pluoxium
	name = "Pluoxium Subspace Tank"
	id = "admin_tank_pluoxium"
	build_path = /obj/item/tank/internals/admin/pluoxium

/datum/design/admin/tank_plasma
	name = "Plasma Subspace Tank"
	id = "admin_tank_plasma"
	build_path = /obj/item/tank/internals/admin/plasma

/datum/design/admin/tank_nitrogen
	name = "Nitrogen Subspace Tank"
	id = "admin_tank_nitrogen"
	build_path = /obj/item/tank/internals/admin/nitrogen

/datum/design/admin/gas_filter
	name = "Subspace Gas Filter"
	id = "admin_gas_filter"
	build_path = /obj/item/gas_filter/admin

/datum/design/admin/tank_empty
	name = "Empty Subspace Tank"
	id = "admin_tank_empty"
	build_path = /obj/item/tank/internals/admin

/datum/design/admin/tank_tritium
	name = "Tritium Subspace Tank"
	id = "admin_tank_tritium"
	build_path = /obj/item/tank/internals/admin/tritium

/datum/design/admin/tank_freon
	name = "Freon Subspace Tank"
	id = "admin_tank_freon"
	build_path = /obj/item/tank/internals/admin/freon

/datum/design/admin/tank_juggermol
	name = "'JUGGERMOL' Subspace Tank"
	id = "admin_tank_juggermol"
	build_path = /obj/item/tank/internals/admin/mix/juggermol

/datum/design/admin/tank_fusionfur
	name = "'Fusion-Fur' Subspace Tank"
	id = "admin_tank_fusionfur"
	build_path = /obj/item/tank/internals/admin/mix/fusionfur

/datum/design/admin/tank_beeshead
	name = "'Bee's Head' Subspace Tank"
	id = "admin_tank_beeshead"
	build_path = /obj/item/tank/internals/admin/mix/beeshead

// Worn kit - the bluespace technician loadout

/datum/design/admin/techsuit
	name = "Bluespace Techsuit"
	id = "admin_techsuit"
	build_path = /obj/item/clothing/under/admin

/datum/design/admin/letterman
	name = "Bluespace Letterman"
	id = "admin_letterman"
	build_path = /obj/item/clothing/suit/admin

/datum/design/admin/gauntlets
	name = "Bluespace Gauntlets"
	id = "admin_gauntlets"
	build_path = /obj/item/clothing/gloves/tackler/admin

/datum/design/admin/magboots
	name = "Bluespace Magboots"
	id = "admin_magboots"
	build_path = /obj/item/clothing/shoes/magboots/advance/admin

/datum/design/admin/visor
	name = "Bluespace Visor"
	id = "admin_visor"
	build_path = /obj/item/clothing/head/helmet/perceptomatrix/admin

/datum/design/admin/gas_mask
	name = "Bluespace Mask"
	id = "admin_gas_mask"
	build_path = /obj/item/clothing/mask/gas/atmos/admin

/datum/design/admin/energy_shield
	name = "CentCom Tactical Shield Projector"
	id = "admin_energy_shield"
	build_path = /obj/item/clothing/accessory/energy_shield/admin

/datum/design/admin/cytotheca
	name = "Bluespace Cytotheca"
	id = "admin_cytotheca"
	build_path = /obj/item/storage/neck/admin/cytotheca

/datum/design/admin/armor_vest
	name = "Technician's Vest"
	id = "admin_armor_vest"
	build_path = /obj/item/clothing/suit/armor/vest/debug

// Identification

/datum/design/admin/id_admin
	name = "Admin ID"
	id = "admin_id_admin"
	build_path = /obj/item/card/id/advanced/debug/admin

/datum/design/admin/id_bluespace
	name = "Bluespace ID"
	id = "admin_id_bluespace"
	build_path = /obj/item/card/id/advanced/debug/admin/bluespace

/datum/design/admin/id_subspace
	name = "Subspace ID"
	id = "admin_id_subspace"
	build_path = /obj/item/card/id/advanced/debug/admin/subspace

/datum/design/admin/id_centcom
	name = "CentCom Master ID"
	id = "admin_id_centcom"
	build_path = /obj/item/card/id/advanced/debug/admin/centcom

// Kits - prepacked boxes, for when you would rather not print things one at a time

/datum/design/admin/debug_box
	name = "Subspace Box"
	id = "admin_debug_box"
	build_path = /obj/item/storage/box/debug

/datum/design/admin/taser
	name = "Debug Taser"
	id = "admin_taser"
	build_path = /obj/item/gun/energy/taser/debug
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_WEAPONS)

// MODsuits

/datum/design/admin/modsuit_bluespace
	name = "Bluespace MODsuit"
	id = "admin_modsuit_bluespace"
	build_path = /obj/item/mod/control/pre_equipped/bluespace
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_MODSUITS)

/datum/design/admin/modsuit_subspace
	name = "Subspace MODsuit"
	id = "admin_modsuit_subspace"
	build_path = /obj/item/mod/control/pre_equipped/subspace
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_MODSUITS)

/datum/design/admin/module_storage
	name = "MOD Subspace Storage Module"
	id = "admin_module_storage"
	build_path = /obj/item/mod/module/storage/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_MODSUIT_MODULES)

/datum/design/admin/module_dispenser
	name = "MOD Subspace Box Dispenser Module"
	id = "admin_module_dispenser"
	build_path = /obj/item/mod/module/dispenser/subspacebox
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_MODSUIT_MODULES)

/datum/design/admin/module_infiltrator
	name = "MOD Subspace Infiltrator Module"
	id = "admin_module_infiltrator"
	build_path = /obj/item/mod/module/infiltrator/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_MODSUIT_MODULES)

/datum/design/admin/module_carbine
	name = "MOD Subspace Carbine Module"
	id = "admin_module_carbine"
	build_path = /obj/item/mod/module/admin/carbine
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_MODSUIT_MODULES)

// Cyborg

/datum/design/admin/borg_frontline
	name = "Cyborg Upgrade: Frontline Walker"
	id = "admin_borg_frontline"
	build_path = /obj/item/borg/upgrade/transform/admin/frontline
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_MECHFAB_CYBORG_MODULES)

/datum/design/admin/borg_backline
	name = "Cyborg Upgrade: Backline Walker"
	id = "admin_borg_backline"
	build_path = /obj/item/borg/upgrade/transform/admin/backline
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_MECHFAB_CYBORG_MODULES)

/datum/design/admin/borg_engineer
	name = "Cyborg Upgrade: Engineering Walker"
	id = "admin_borg_engineer"
	build_path = /obj/item/borg/upgrade/transform/admin/engineer
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_MECHFAB_CYBORG_MODULES)

// Subspace tier - the badmin variants of the above. Same slots, fewer manners.

/datum/design/admin/headset_subspace
	name = "Subspace Headset"
	id = "admin_headset_subspace"
	build_path = /obj/item/radio/headset/admin/subspace

/datum/design/admin/techsuit_subspace
	name = "Subspace Techsuit"
	id = "admin_techsuit_subspace"
	build_path = /obj/item/clothing/under/admin/subspace

/datum/design/admin/letterman_subspace
	name = "Subspace Letterman"
	id = "admin_letterman_subspace"
	build_path = /obj/item/clothing/suit/admin/subspace

/datum/design/admin/gauntlets_subspace
	name = "Subspace Gauntlets"
	id = "admin_gauntlets_subspace"
	build_path = /obj/item/clothing/gloves/tackler/admin/subspace

/datum/design/admin/magboots_subspace
	name = "Subspace Magboots"
	id = "admin_magboots_subspace"
	build_path = /obj/item/clothing/shoes/magboots/advance/admin/subspace

/datum/design/admin/visor_subspace
	name = "Subspace Visor"
	id = "admin_visor_subspace"
	build_path = /obj/item/clothing/head/helmet/perceptomatrix/admin/subspace

/datum/design/admin/gas_mask_subspace
	name = "Subspace Mask"
	id = "admin_gas_mask_subspace"
	build_path = /obj/item/clothing/mask/gas/atmos/admin/subspace

/datum/design/admin/energy_shield_bluespace
	name = "Bluespace Shield Projector"
	id = "admin_energy_shield_bluespace"
	build_path = /obj/item/clothing/accessory/energy_shield/admin/bluespace

/datum/design/admin/energy_shield_subspace
	name = "Subspace Shield Projector"
	id = "admin_energy_shield_subspace"
	build_path = /obj/item/clothing/accessory/energy_shield/admin/subspace

/datum/design/admin/cytotheca_subspace
	name = "Subspace Cytotheca"
	id = "admin_cytotheca_subspace"
	build_path = /obj/item/storage/neck/admin/cytotheca/subspace

/datum/design/admin/pocket_subspace
	name = "Subspace Pocket"
	id = "admin_pocket_subspace"
	build_path = /obj/item/storage/bag/admin/subspace

/datum/design/admin/construction_bag_subspace
	name = "Subspace Construction Bag"
	id = "admin_construction_bag_subspace"
	build_path = /obj/item/storage/bag/construction/admin/subspace

/datum/design/admin/utility_belt_empty
	name = "Technician's Satchel"
	id = "admin_utility_belt_empty"
	build_path = /obj/item/storage/belt/utility/admin

/datum/design/admin/utility_belt_bluespace
	name = "Bluespace Technician's Satchel"
	id = "admin_utility_belt_bluespace"
	build_path = /obj/item/storage/belt/utility/admin/full/bluespace

/datum/design/admin/utility_belt_subspace
	name = "Subspace Technician's Satchel"
	id = "admin_utility_belt_subspace"
	build_path = /obj/item/storage/belt/utility/admin/full/subspace

/datum/design/admin/pouch_cytotheca
	name = "Slimy Subspace Pouch"
	id = "admin_pouch_cytotheca"
	build_path = /obj/item/storage/subspace_pouch/cytotheca

/datum/design/admin/debug_box_schrodinger
	name = "Schrodinger's Subspace Box"
	id = "admin_debug_box_schrodinger"
	build_path = /obj/item/storage/box/debug/schrodinger

/datum/design/admin/patch_applicator_instant
	name = "Instant Subspace Patch Applicator"
	id = "admin_patch_applicator_instant"
	build_path = /obj/item/reagent_containers/applicator/patch/admin/instant

/datum/design/admin/pill_applicator_xr
	name = "Extended Release Subspace Pill Applicator"
	id = "admin_pill_applicator_xr"
	build_path = /obj/item/reagent_containers/applicator/pill/admin/xr

/datum/design/admin/annihilator
	name = "Annihilator"
	id = "admin_annihilator"
	build_path = /obj/item/gun/energy/pulse/destroyer/annihilator
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_WEAPONS)

/datum/design/admin/modsuit_danger
	name = "Bluespace MODsuit (Danger Modules)"
	id = "admin_modsuit_danger"
	build_path = /obj/item/mod/control/pre_equipped/bluespace/danger_module_debug
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_MODSUITS)
