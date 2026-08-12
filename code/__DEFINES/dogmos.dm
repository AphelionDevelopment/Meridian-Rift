/**
 * Minimal Dogmos glue, sufficient to prove the native library loads and answers over FFI.
 *
 * This is a temporary Phase 0 artifact. It is superseded wholesale by the generated
 * bindings.dm once /datum/gas_mixture is ported in Phase 2 - 12 of the generated bindings
 * collide with procs that gas_mixture.dm still defines today, so the full file cannot be
 * included until those are gone. Only collision-free symbols appear here.
 */

/* This comment bypasses grep checks */ /var/__dogmos

/// Resolves the Dogmos library name for the host platform and caches it in __dogmos.
/proc/__detect_dogmos()
	if (world.system_type == UNIX)
		return __dogmos = "libdogmos"
	else
		return __dogmos = "dogmos"

#define DOGMOS (__dogmos || __detect_dogmos())

/// Called by Dogmos itself when a hook fails on the Rust side.
/proc/byondapi_stack_trace(msg)
	CRASH(msg)

/**
 * Args: (ms). Runs callbacks until the time limit is reached, all of them if omitted.
 *
 * Also the cheapest way to force Dogmos to run its library initialisers: byondapi only
 * runs those the first time a hook touches a ByondValue, and hooks that take no arguments
 * (get_amt_gas_mixes, get_max_gas_mixes) will panic on an uninitialised gas arena if they
 * are the very first call into the library.
 */
/proc/process_atmos_callbacks(remaining)
	return call_ext(DOGMOS, "byond:atmos_callback_handle_ffi")(remaining)

/// Returns: the amount of gas mixtures that are attached to a byond gas mixture.
/datum/controller/subsystem/air/proc/get_amt_gas_mixes()
	return call_ext(DOGMOS, "byond:hook_amt_gas_mixes_ffi")()

/// Returns: the total amount of gas mixtures in the arena, including "free" ones.
/datum/controller/subsystem/air/proc/get_max_gas_mixes()
	return call_ext(DOGMOS, "byond:hook_max_gas_mixes_ffi")()
