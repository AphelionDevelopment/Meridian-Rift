/** Registers a touched space turf as an immutable Dogmos graph boundary. */
/turf/open/space/register_dogmos_air()
	if(!DOGMOS)
		return
	if(isnull(dogmos_registration_generation))
		mark_dogmos_turf_replacement()
	if(!air)
		// Map loading can reach this before the shared space mixture exists.
		return
	// Space shares one immutable mixture, so Rust registers it as a boundary only.
	update_air_ref(DOGMOS_SIMULATION_SPACE_BOUNDARY)

/** Ensures a touched space turf has a gas-graph boundary before adjacency updates. */
/turf/open/space/sync_dogmos_adjacency()
	if(!DOGMOS)
		return
	register_dogmos_air()
	__update_auxtools_turf_adjacency_info(world.maxx, world.maxy)
