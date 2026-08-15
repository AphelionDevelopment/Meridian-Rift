/**
 * Space turfs skip Initalize_Atmos() entirely (/turf/open/space/Initialize() doesn't call ..(), see
 * space_EXPENSIVE.dm), so the base /turf/proc/register_dogmos_air()'s init_air gate means no space
 * turf was ever registered into Dogmos at all - which meant a station turf bordering space never got
 * a gas-graph edge to it (Rust silently drops adjacency to an unregistered neighbor id), so gas never
 * diffused into space and katmos's explosively_depressurize() (which detects a breach by finding an
 * immutable neighbor) never had one to find. Confirmed via the 2026-08-14 playtest: breaches pulled
 * nothing, and the perf log showed katmos's high-pressure/equalize counters sitting at exactly zero
 * for an entire ~2000s round.
 *
 * These two overrides register one specific space turf on demand, the moment either side's adjacency
 * plumbing actually touches it - not eagerly for every space turf on the map, which would add real
 * roundstart cost for tiles nothing ever borders (see space_EXPENSIVE.dm's own comments about
 * deliberately skipping normal Initialize() overhead here). Both are idempotent and cheap to call
 * repeatedly: Rust's insert_turf() overwrites the existing node in place rather than duplicating it,
 * and mark_immutable() is a plain bool set, so multiple interior neighbors independently discovering
 * and re-registering the same space turf is harmless.
 */
/turf/open/space/register_dogmos_air()
	if(!DOGMOS)
		return
	if(!air)
		// The optimized map-loader path (/turf/open/space/basic/New()) calls AfterChange() - and so
		// this - before Initialize() has constructed `air` (space_gas). Mirrors the same not-ready
		// guard the base register_dogmos_air() applies for ordinary open turfs (see
		// modular_aphelion/master_files/code/game/turfs/turf.dm's doc comment): skip silently, since
		// the next real adjacency touch after Initialize() runs calls this again with air set.
		return
	// DOGMOS_SIMULATION_SPACE_BOUNDARY is a sentinel, not a real SimulationFlags bit - Rust's
	// hook_register_turf inserts the node with empty flags (present, never selected as a turf to
	// process) and marks the underlying mix immutable. That matters because every space turf shares
	// one static `air` datum (space_gas): if Rust ever treated a space turf as a normal enabled node
	// and wrote diffusion results into it, that write would corrupt "vacuum" for every other space
	// tile referencing the same slot. See hook_register_turf in aphelion-dogmos/src/turfs.rs.
	update_air_ref(DOGMOS_SIMULATION_SPACE_BOUNDARY)

/**
 * The base version early-returns on !init_air, which is exactly why this needed fixing - but it's
 * still correct to gate on !DOGMOS. Calling register_dogmos_air() first (idempotent) guarantees a
 * graph node exists no matter which order this and the register call happen to run in from whatever
 * triggered them - Rust's own update_adjacencies() calls already no-op gracefully against an
 * unregistered id, so this is a belt-and-suspenders ordering guarantee, not a correctness requirement
 * on its own.
 *
 * conductivity_blocked_directions is deliberately left at its initial() default (NONE) here - space
 * never registers into Dogmos' heat graph (see register_dogmos_air() above; supercond_update_ref is
 * skipped for the space-boundary registration path on the Rust side), so the var has no consumer for
 * a space turf and computing it via conductivity_directions() would be dead work.
 */
/turf/open/space/sync_dogmos_adjacency()
	if(!DOGMOS)
		return
	register_dogmos_air()
	__update_auxtools_turf_adjacency_info(world.maxx, world.maxy)
