/turf
	/// Monotonic identity for queued Dogmos callbacks; changes when ChangeTurf() replaces this turf ref.
	var/dogmos_registration_generation
	/// Shared counter used to distinguish a turf replacement from routine re-registration.
	var/static/next_dogmos_registration_generation = 0
	/// Initial temperature used when Dogmos first registers the turf's heat node.
	var/initial_temperature
	/// Directions blocked for Dogmos heat conduction.
	var/conductivity_blocked_directions = NONE
	/// Whether decompression may strip this turf's floor surface.
	var/decompression_floor_rip_resistant = FALSE

/// Advances the callback generation used to fence ChangeTurf() replacements.
/turf/proc/mark_dogmos_turf_replacement()
	dogmos_registration_generation = ++next_dogmos_registration_generation

/turf/Initalize_Atmos(time)
	register_dogmos_air()
	return ..()

/** Registers or re-registers this turf in Dogmos' gas and heat graphs. */
/turf/proc/register_dogmos_air()
	if(!DOGMOS)
		return
	if(!init_air)
		update_air_ref(DOGMOS_SIMULATION_REMOVE)
		return
	if(isnull(dogmos_registration_generation))
		mark_dogmos_turf_replacement()
	if(isnull(initial_temperature))
		initial_temperature = temperature
	// Map-load turfs without air use heat-only registration until their gas datum exists.
	var/turf/open/as_open = isopenturf(src) ? src : null
	update_air_ref((as_open?.air && !blocks_air) ? DOGMOS_SIMULATION_ALL : DOGMOS_SIMULATION_NONE)

/** Writes the DM and Dogmos temperatures. */
/turf/proc/set_temperature(new_temp)
	temperature = new_temp
	if(DOGMOS && init_air)
		__set_temperature(new_temp)

/** Returns the registered Dogmos heat temperature, if available. */
/turf/proc/dogmos_heat_temperature()
	return __dogmos_heat_temperature()

/** Returns the configured temperature authority for blocked turfs. */
/turf/proc/get_dogmos_blocked_temperature()
	if(DOGMOS && SSair.dogmos_blocked_turf_temperature_authority == DOGMOS_TEMPERATURE_AUTHORITY_RUST)
		var/rust_temperature = dogmos_heat_temperature()
		if(!isnull(rust_temperature))
			return rust_temperature
	return temperature
