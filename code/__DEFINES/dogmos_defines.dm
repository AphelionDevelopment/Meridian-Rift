// Hand-maintained Dogmos constants that have no generated binding of their own - they're plain
// numeric bit values the Rust fork expects on specific FFI calls, not proc/var bindings that
// `cargo test generate_binds` would emit. Do not move these into dogmos_bindings.dm (generated,
// see build_dogmos.ps1's drift gate).

/// SimulationFlags bit for /turf/proc/update_air_ref(flag): fully active, normally-simulated turf
/// (a plain open floor). Matches Rust's SimulationFlags::SIMULATION_ALL (aphelion-dogmos src/turfs.rs).
#define DOGMOS_SIMULATION_ALL (1<<1)
/// SimulationFlags bit for update_air_ref(flag): a semi-permeable turf that diffuses air without
/// being a fully active simulation node (e.g. a grille/window). Matches SimulationFlags::SIMULATION_DIFFUSE.
#define DOGMOS_SIMULATION_DIFFUSE (1<<0)
/// Pass to update_air_ref() to remove/unregister a turf from Dogmos' gas graph entirely (any negative
/// value works per hook_register_turf's `flag >= 0` check, but this name documents intent at call sites).
#define DOGMOS_SIMULATION_NONE -1
/// Sentinel (not a real SimulationFlags bit) for /turf/open/space/register_dogmos_air() to pass to
/// update_air_ref(). Registers the turf as a present-but-never-processed, immutable gas-graph node
/// instead of a normal SIMULATION_ALL turf - see hook_register_turf's SPACE_BOUNDARY_FLAG handling
/// (aphelion-dogmos src/turfs.rs) for why space needs this rather than the ordinary path. Must stay
/// numerically distinct from every real SimulationFlags value and from DOGMOS_SIMULATION_NONE.
#define DOGMOS_SIMULATION_SPACE_BOUNDARY -2

/// AdjacentFlags bit written into atmos_adjacent_turfs list values, consumed by
/// __update_auxtools_turf_adjacency_info(). Matches Rust's AdjacentFlags::ATMOS_ADJACENT_FIRELOCK.
#define DOGMOS_ADJACENT_FIRELOCK (1<<1)

/// Selects the legacy DM turf temperature for blocked-turf consumers.
#define DOGMOS_TEMPERATURE_AUTHORITY_DM 0
/// Selects the registered Dogmos TurfHeat temperature for blocked-turf consumers, falling back to DM
/// when a turf has no heat-graph node.
#define DOGMOS_TEMPERATURE_AUTHORITY_RUST 1

/// Runs FDM pressure diffusion without Katmos whole-zone equalization.
#define DOGMOS_EQUALIZE_PROFILE_FDM_ONLY 0
/// Runs the current Katmos whole-zone equalizer after FDM pressure diffusion.
#define DOGMOS_EQUALIZE_PROFILE_FAST_ZONE 1
