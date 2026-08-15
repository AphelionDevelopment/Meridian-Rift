/**
 * Regression test for a real bug reported via live playtest (2026-08-15): Thunderdome/holodeck resets
 * occasionally leave hot-spots inside the reset arena, invisible to a plain gas-content check and only
 * fixable by the Fix Air admin verb (which happens to call turf-level set_temperature() directly).
 *
 * This is a DIFFERENT bug from - and survives - the earlier Assimilate_Air() temperature-sync fix
 * (dogmos_assimilate_air_temperature_sync.dm): that fix only applies to ChangeTurf() calls that actually
 * run Assimilate_Air(), i.e. ones without CHANGETURF_IGNORE_AIR/CHANGETURF_INHERIT_AIR. But the real
 * map-template loader used by holodeck/Thunderdome resets (parsed_map/build_coordinate,
 * code/modules/mapping/reader.dm:958) places turfs with CHANGETURF_DEFER_CHANGE, then finalizes them in
 * a later batch pass with `T.AfterChange(CHANGETURF_IGNORE_AIR)` (reader.dm:358) - deliberately skipping
 * Assimilate_Air() so a real map load uses each turf's own fresh air instead of blending with whatever
 * was next to it before. register_dogmos_air() still runs unconditionally in the base AfterChange()
 * though, and BYOND turf refs are stable across ChangeTurf() (the same coordinate slot is reused, not a
 * fresh allocation - verified directly via REF(src) before/after during this investigation). So if this
 * exact ref was already registered in Dogmos' heat graph before the reset (e.g. an old, still-hot
 * Thunderdome arena tile), register_dogmos_air() hits Rust's "already present" branch
 * (TurfHeat::insert_turf, aphelion-dogmos src/turfs/superconduct.rs) - which deliberately leaves
 * temperature untouched on that branch, by design, for ordinary live re-registration. Left alone, a
 * reset turf's heat-graph copy silently keeps whatever temperature the arena had before resetting,
 * forever. Fixed by having AfterChange()'s CHANGETURF_IGNORE_AIR branch call set_temperature() (a direct
 * FFI write, bypassing insert_turf's preserve-on-update path entirely) to resync the heat graph to the
 * fresh turf's own temperature.
 *
 * Replicates the real map-loader sequence exactly (ChangeTurf with CHANGETURF_DEFER_CHANGE, then a
 * separate, later AfterChange(CHANGETURF_IGNORE_AIR) call) rather than a single ChangeTurf call, since
 * that split is what makes this bug distinct from the already-fixed Assimilate_Air case.
 */
/datum/unit_test/dogmos_ignore_air_temperature_reset
	var/original_type

/datum/unit_test/dogmos_ignore_air_temperature_reset/Run()
	var/turf/open/turf_a = run_loc_floor_bottom_left
	TEST_ASSERT(istype(turf_a), "run_loc_floor_bottom_left is not an open turf - this test needs one.")

	original_type = turf_a.type
	turf_a.set_temperature(1000)
	TEST_ASSERT(abs(turf_a.return_temperature() - 1000) < 1, \
		"turf_a's heat-graph temperature right after set_temperature(1000) was [turf_a.return_temperature()]K, not ~1000K - test setup is broken before the thing under test even starts.")

	// CHANGETURF_DEFER_CHANGE: matches build_coordinate()'s own ChangeTurf call exactly - AfterChange()
	// is NOT invoked yet after this line (change_turf.dm's own early-return on this flag). Swaps to a
	// different real type (matching the other alternating-type tests in this suite) since path == type
	// is a ChangeTurf() no-op.
	var/turf/open/floor/plating/new_turf = turf_a.ChangeTurf(/turf/open/floor/plating, flags = CHANGETURF_DEFER_CHANGE)
	TEST_ASSERT(istype(new_turf), "ChangeTurf to /turf/open/floor/plating did not produce a plating turf - test setup is broken, not the thing under test.")

	// Matches reader.dm:358's later finalization call exactly - this is the real code path under test.
	new_turf.AfterChange(CHANGETURF_IGNORE_AIR, original_type)

	var/heat_graph_temp = new_turf.return_temperature()
	TEST_ASSERT(heat_graph_temp < 900, \
		"The reset turf's heat-graph temperature is still [heat_graph_temp]K after AfterChange(CHANGETURF_IGNORE_AIR) - it retained the pre-reset 1000K instead of resetting, reproducing the Thunderdome hot-spot-after-reset bug.")
	TEST_ASSERT(abs(heat_graph_temp - new_turf.temperature) < 1, \
		"The reset turf's heat-graph temperature ([heat_graph_temp]K) and its own DM-side temperature var ([new_turf.temperature]K) disagree by more than 1K - the heat graph isn't synced to this fresh turf's real temperature.")

/datum/unit_test/dogmos_ignore_air_temperature_reset/Destroy()
	var/turf/open/turf_a = run_loc_floor_bottom_left
	if(original_type && istype(turf_a) && turf_a.type != original_type)
		turf_a.ChangeTurf(original_type, flags = CHANGETURF_INHERIT_AIR | CHANGETURF_RECALC_ADJACENT)
	restore_atmos()
	return ..()
