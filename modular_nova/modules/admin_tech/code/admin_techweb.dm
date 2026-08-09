/// Heres where the Administrative Fabricator and the Admin Techweb live

// techweb: modular_nova\master_files\code\modules\research\techweb\techweb_types.dm
// machine.dm define w/ nova edit code\__DEFINES\machines.dm
// TODO: sprites, flatpacks of common admin machines like the debug chem spawner, etc
/// Admin lathe, waow so cool, wow, wow so cool
/obj/machinery/rnd/production/colony_lathe/admin
	name = "administrative fabricator"
	desc = "A rapid construction fabricator with the material feedstock stage removed entirely, which is not something \
		the laws of thermodynamics ordinarily permit. Everything it knows how to make, it makes instantly and for free, \
		and it knows how to make every piece of subspace equipment Central Command has ever quietly signed off on. \
		It repacks into a flatpack for transport."
	icon = 'modular_nova/modules/colony_fabricator/icons/machines.dmi'
	icon_state = "colony_lathe"
	base_icon_state = "colony_lathe"
	circuit = null
	production_animation = "colony_lathe_n"
	light_color = LIGHT_COLOR_BRIGHT_YELLOW
	light_power = 5
	// The admin designs are ADMIN_TECHWEB; this used to be COLONY_FABRICATOR against /datum/techweb/colony_fabricator,
	// which meant the administrative fabricator could print everything except the administrative gear.
	allowed_buildtypes = ADMIN_TECHWEB | COLONY_FABRICATOR
	speedup_disabled = TRUE
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | ACID_PROOF
	techweb_path = /datum/techweb/autounlocking/admin
	repacked_type = /obj/item/flatpacked_machine/admin

// The parent exposes this hook precisely so subtypes don't have to re-add a second manufacturer element in Initialize.
/obj/machinery/rnd/production/colony_lathe/admin/give_manufacturer_examine()
	AddElement(/datum/element/manufacturer_examine, COMPANY_ADMIN)

// Zero coefficient means has_materials() and use_materials() both ask for nothing, so everything prints free.
// The designs still carry a token cost because the design unit test rejects a design with a build_path and no cost.
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
//ADMIN_ITEM_VARS(/obj/item/flatpacked_machine/admin)

/obj/item/flatpacked_machine/admin/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/manufacturer_examine, COMPANY_ADMIN)


/// Printables list of admin items
/// When adding new items to the module, you should really add them here
// This also adds some printables of other various debug items
//
// Everything here hangs off /datum/design/admin so a new entry only has to declare what makes it different.
// RND_CATEGORY_INITIAL is what makes an autounlocking techweb pick a design up, so don't drop it from the category list.
/datum/design/admin
	build_type = ADMIN_TECHWEB
	// Token cost only. The administrative fabricator zeroes its build efficiency, so nothing is actually consumed -
	// but the design unit test fails any design that has a build_path and no material cost whatsoever.
	materials = list(/datum/material/iron = SMALL_MATERIAL_AMOUNT)
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_EQUIPMENT)

//
// Tools
//
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

//
// Weaponry
//
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

//
// Equipment
//
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

//
// Storage
//
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

//
// Medical
//
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

//
// Internals
//
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

//
// MODsuits
//
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

//
// Cyborg
//
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
