/turf
	/// Dogmos seeds its heat-conduction graph from this at first registration (set to `temperature`
	/// at that point, not maintained afterward - Rust owns the live value from there on). A second,
	/// independently-drifting "initial" var would just be a second source of truth; this is written
	/// once by whatever calls update_air_ref() first, never assigned to directly elsewhere.
	var/initial_temperature
	/// Directions Dogmos should NOT conduct heat through - the inverse of conductivity_directions().
	/// Kept in sync with atmos_adjacent_turfs by the same adjacency-rebuild pass, and read by Rust's
	/// superconduction adjacency graph (supercond_update_adjacencies), which computes its neighbor set
	/// from this bitmask rather than from atmos_adjacent_turfs (that list drives the separate gas graph).
	var/conductivity_blocked_directions = NONE

/turf/Initalize_Atmos(time)
	register_dogmos_air()
	return ..()

/**
 * Registers (or re-registers) this turf with Dogmos' gas/heat graphs. Called at every point a turf's
 * air-relevant state might have changed for the first time or after a type swap: the roundstart
 * Initalize_Atmos() pass, ChangeTurf's AfterChange() hook, and StopLoadingMap()'s late-map-load
 * catch-up. blocks_air turfs still register (Rust auto-detects blocks_air and routes them to the heat
 * graph only, regardless of the flag passed here - see hook_register_turf in aphelion-dogmos
 * src/turfs.rs), so this doesn't need its own blocks_air branch beyond picking which flag to pass.
 */
/turf/proc/register_dogmos_air()
	if(!init_air || !DOGMOS)
		return
	if(isnull(initial_temperature))
		initial_temperature = temperature
	// Closed turfs, blocks_air turfs, and open turfs whose air hasn't been created yet (some map-load
	// paths call AfterChange() before /turf/open/Initialize()'s create_gas_mixture() has run) all fall
	// back to a heat-only registration - hook_register_turf's gas branch reads air's
	// _extools_pointer_gasmixture directly and crashes on a null air, but it unconditionally calls
	// supercond_update_ref() regardless of this flag, so heat-graph registration is always safe here.
	// A turf that fell back for a missing air gets a real gas registration later from
	// StopLoadingMap()'s catch-up or the next air_update_turf() call.
	var/turf/open/as_open = isopenturf(src) ? src : null
	update_air_ref((as_open?.air && !blocks_air) ? DOGMOS_SIMULATION_ALL : DOGMOS_SIMULATION_NONE)

/**
 * Writes a turf's temperature through to Dogmos' heat-conduction graph. The single entry point for
 * every call site that used to write /turf/var/temperature directly (fix_air.dm, effects_foam.dm,
 * recipes.dm, other_reagents.dm, holo_effect.dm, supply.dm) - centralizes the space-turf guard
 * instead of needing one at each of the six sites, and gives one place to enforce validation instead
 * of six. Named distinctly from the raw __set_temperature() FFI bind so this can own the clean name.
 *
 * The DM-side var is always updated, including when Dogmos is unavailable or a turf has not yet
 * registered into TurfHeat. The Rust setter is a safe no-op for an unregistered turf, so map-load
 * ordering cannot turn a compatibility write into a runtime.
 */
/turf/proc/set_temperature(new_temp)
	temperature = new_temp
	if(DOGMOS && init_air)
		__set_temperature(new_temp)

/**
 * Returns the registered Dogmos TurfHeat temperature, or null when this turf has no heat-graph node
 * or the registered value is not finite. Unlike return_temperature(), this proc never fabricates a
 * numeric value for an unregistered turf, so callers can safely fall back to the DM turf var.
 */
/turf/proc/dogmos_heat_temperature()
	return __dogmos_heat_temperature()

/**
 * Returns the temperature authority selected for blocked turfs. Open turfs that admit gas continue
 * using their gas-mixture GetTemperature() path; blocked turfs use this selector instead. The Rust
 * authority is intentionally conditional because registration is not guaranteed during every map-load
 * hook.
 */
/turf/proc/get_dogmos_blocked_temperature()
	if(DOGMOS && SSair.dogmos_blocked_turf_temperature_authority == DOGMOS_TEMPERATURE_AUTHORITY_RUST)
		var/rust_temperature = dogmos_heat_temperature()
		if(!isnull(rust_temperature))
			return rust_temperature
	return temperature
