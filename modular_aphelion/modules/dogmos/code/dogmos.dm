/// GLOB.total_runtimes as it stood the moment initialisation finished. Snapshotted by the MC
/// (code\controllers\master.dm) so a unit test can ask "was the boot clean?" without being
/// polluted by runtimes the tests themselves cause. See /datum/unit_test/no_runtimes_during_init.
GLOBAL_VAR_INIT(runtimes_at_init_complete, 0)

/**
 * Hands Dogmos the gas registry and the reaction table before anything can build a gas mixture.
 *
 * This cannot live in SSair. SSair depends on SSmapping and SSatoms (see air.dm), so it initialises
 * *after* every turf has already run /turf/open/Initialize -> create_gas_mixture ->
 * SSair.parse_gas_string -> set_moles. With no gases registered, Rust rejects every id, and - worse -
 * parse_gas_string caches the half-built canonical mixture in SSair.strings_to_mix *before*
 * populating it, so the empty mix is served to every turf for the rest of the round even once
 * registration succeeds. Registration therefore has to happen in its own subsystem, at
 * INITSTAGE_EARLY, which the MC guarantees runs before all of INITSTAGE_MAIN.
 *
 * Nothing here touches mapload or atoms: init_gas_reactions() and init_dogmos_reactions() only read
 * GLOB.meta_gas_info and subtypesof(), and auxtools_atmos_init() reads GLOB.gas_data plus
 * SSair.dogmos_reactions off the global. All three exist before any subsystem Initialize() runs -
 * do NOT try to move this into PreInit() instead, GLOB does not exist yet at that point
 * (see master.dm, GLOB is created after every subsystem's PreInit() has already run).
 */
SUBSYSTEM_DEF(dogmos)
	name = "Dogmos"
	init_stage = INITSTAGE_EARLY
	ss_flags = SS_NO_FIRE
	/// SSair also names us in its own dependencies (self-documentation at the read site); this pair
	/// is what actually forces us ahead of mapload and atom init.
	dependents = list(
		/datum/controller/subsystem/mapping,
		/datum/controller/subsystem/atoms,
	)

	/// TRUE once auxtools_atmos_init() has returned successfully. Read by gas_string_id() as a
	/// one-shot tripwire: any gas id crossing into Dogmos while this is FALSE means something
	/// initialised too early and will be silently rejected by Rust.
	var/gases_registered = FALSE

/datum/controller/subsystem/dogmos/Initialize()
	// Owned by SSair at runtime; built here because Dogmos reads dogmos_reactions off the global
	// during auxtools_atmos_init() and there is no second chance to hand it over.
	SSair.gas_reactions = init_gas_reactions()
	SSair.dogmos_reactions = init_dogmos_reactions(SSair.gas_reactions)

	if(!length(SSair.dogmos_reactions))
		stack_trace("init_dogmos_reactions() produced an empty list - Dogmos will run with no reactions at all.")

	populate_gas_data_overlays()

	if(!auxtools_atmos_init(GLOB.gas_data))
		stack_trace("auxtools_atmos_init() did not report success - Dogmos may hold an incomplete gas registry.")
		return SS_INIT_FAILURE

	gases_registered = TRUE
	return SS_INIT_SUCCESS

/**
 * Fills in GLOB.gas_data.overlays (left empty by /datum/gas_data/New(), see gas_types.dm), which
 * Rust's update_visuals() reads to resolve which pre-baked overlay object to show for a given gas at
 * a given plane offset and visibility state - the set_visuals() FFI callback this feeds is what turf
 * gas rendering runs through once SSAIR_ACTIVETURFS moves to Rust.
 *
 * Deliberately a reference into GLOB.meta_gas_info[META_GAS_OVERLAY]'s existing per-gas overlay lists,
 * not a second, duplicate set of /obj/effect/overlay/gas instances - meta_gas_list() (gas_mixture.dm)
 * already built exactly the objects needed, keyed by plane offset the same way
 * gas_mixture.dm's return_visuals() already reads them (see code/__HELPERS/_planes.dm's
 * GET_TURF_PLANE_OFFSET for the offset+1 convention both sides agree on). Since this stores the SAME
 * list objects rather than copies, SSmapping growing z_level_to_plane_offset for a new z-level after
 * roundstart (code/controllers/subsystem/mapping.dm) - which appends new offset sublists onto those
 * same META_GAS_OVERLAY lists - is automatically visible here too, with nothing further to keep in sync.
 *
 * Must run after GLOB.meta_gas_info exists. It does: that's a GLOBAL_LIST_INIT (gas_mixture.dm),
 * evaluated at world load like GLOB.gas_data's own GLOBAL_DATUM_INIT - both complete before any
 * subsystem's Initialize() runs, this subsystem's included, so there is no ordering hazard here
 * despite the two globals initializing independently of each other.
 */
/datum/controller/subsystem/dogmos/proc/populate_gas_data_overlays()
	var/list/meta_overlays = GLOB.meta_gas_info[META_GAS_OVERLAY]
	for(var/gas_path in GLOB.gas_data.datums)
		var/datum/gas/gas_instance = GLOB.gas_data.datums[gas_path]
		var/list/overlay_table = meta_overlays[gas_path]
		if(length(overlay_table))
			GLOB.gas_data.overlays[gas_instance.id] = overlay_table
