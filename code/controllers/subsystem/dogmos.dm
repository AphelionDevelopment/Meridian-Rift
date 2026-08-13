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

	if(!auxtools_atmos_init(GLOB.gas_data))
		stack_trace("auxtools_atmos_init() did not report success - Dogmos may hold an incomplete gas registry.")
		return SS_INIT_FAILURE

	gases_registered = TRUE
	return SS_INIT_SUCCESS
