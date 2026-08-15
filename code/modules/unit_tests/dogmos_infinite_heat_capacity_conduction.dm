/**
 * Verifies the fix for a real, latent bug investigated (but deliberately not fixed) during the
 * SSAIR_SUPERCONDUCTIVITY cutover and fixed 2026-08-15 per Zoe's "clean up deferred issues" direction:
 * aphelion-dogmos's get_share_energy(delta, cap_1, cap_2) computed `cap_1*cap_2/(cap_1+cap_2)`, which
 * hits IEEE-754's indeterminate inf/inf form (not the correct calculus limit) whenever either capacity
 * is infinite - confirmed reachable by real station turfs (two /turf/open/floor/engine tiles, finite
 * conductivity + infinite heat_capacity, separated by an ordinary window that doesn't override
 * block_superconductivity()). The observed symptom was both turfs snapping to TCMB (2.7K) via the
 * downstream sanity clamp on the resulting NaN.
 *
 * Deliberately does NOT override heat_capacity on either turf - the test room's stock turfs already
 * default to INFINITY (neither /turf/open/indestructible nor /turf/closed/indestructible overrides it),
 * which is exactly the condition that triggers the bug, unlike dogmos_superconduction_golden.dm's
 * SUPERCONDUCTION_TEST_HEAT_CAPACITY override (needed there specifically to AVOID this same NaN so it
 * could test ordinary finite-capacity conduction instead).
 */
/datum/unit_test/dogmos_infinite_heat_capacity_conduction

/datum/unit_test/dogmos_infinite_heat_capacity_conduction/Run()
	var/list/pair = allocate_turf_pair()
	var/turf/open/turf_a = pair[1]
	var/turf/open/turf_b = pair[2]

	// isinf() is BYOND's true-IEEE-infinity check, and does not consider BYOND's own INFINITY constant
	// infinite by that definition - it's a finite sentinel (1e31), not f32::INFINITY. Compare against
	// the constant directly instead; see the matching BYOND_INFINITY_THRESHOLD comment on the Rust side
	// (aphelion-dogmos src/turfs/superconduct.rs) for why this distinction is exactly the bug.
	TEST_ASSERT(turf_a.heat_capacity == INFINITY && turf_b.heat_capacity == INFINITY, \
		"The test room's turfs no longer default to infinite heat_capacity ([turf_a.heat_capacity], [turf_b.heat_capacity]) - test setup is broken, not the thing under test (this test specifically needs the infinite-capacity condition to reproduce the bug).")

	// blocks_air on turf_b breaks gas-adjacency, which is what creates a real heat edge - see
	// dogmos_superconduction_golden.dm's doc comment for the full explanation of why a plain
	// gas-adjacent pair (what allocate_turf_pair() guarantees) never conducts heat at all.
	turf_b.blocks_air = TRUE
	resync_turf_for_dogmos(turf_a)
	resync_turf_for_dogmos(turf_b)

	TEST_ASSERT(!(turf_b in turf_a.atmos_adjacent_turfs), \
		"turf_b is still gas-adjacent to turf_a after being marked blocks_air - the heat edge this test depends on only exists for NON-gas-adjacent neighbors, so the setup did not take.")

	turf_a.set_temperature(1500)
	turf_b.set_temperature(1000)

	var/a_before = turf_a.return_temperature()
	var/b_before = turf_b.return_temperature()
	TEST_ASSERT(a_before > b_before, \
		"Seeding turf_a at 1500K and turf_b at 1000K did not produce an asymmetric pair ([a_before] vs [b_before]) - test setup is broken, not the thing under test.")

	// Deliberately does NOT break early on the first detected change (an earlier version of this test
	// did, and that was wrong): the bug's actual failure signature has TWO distinct stages, one cycle
	// apart. The "share w/ adjacents" turf-to-turf loop (no clamp of its own) can push a turf's STORED
	// temperature to real IEEE infinity/NaN within a single process_turf_heat() call; reading it back
	// immediately (hook_turf_temperature, superconduct.rs) returns a read-time fallback of exactly
	// 300.0 for a non-normal stored value - which happens to be a boring, plausible-looking number that
	// trivially satisfied a weaker version of the assertion below. Only on the NEXT full cycle does that
	// same turf's own write-time sanity clamp (`if !temp_write.is_normal() { *temp_write = TCMB }`,
	// which runs once per turf per cycle in the FIRST processing stage) catch the leftover bad value
	// and overwrite storage with TCMB - which is what a too-short retry window would miss entirely.
	// Both 700K and 1000K/1500K test seeds were deliberately chosen away from both fallback sentinels
	// (300.0, 102.0) so neither can be mistaken for a plausible equilibrium temperature.
	for(var/attempt in 1 to 10)
		SSair.process_turf_heat()
		sleep(2)

	var/a_after = turf_a.return_temperature()
	var/b_after = turf_b.return_temperature()

	TEST_ASSERT(a_after != 300.0 && b_after != 300.0, \
		"turf_a/turf_b temperature ([a_after], [b_after]) hit the read-time non-normal fallback (hook_turf_temperature returns exactly 300.0 for a stored NaN/infinity) - get_share_energy() is still overflowing for this infinite-heat-capacity pair.")
	TEST_ASSERT(!isnan(a_after) && a_after > TCMB + 1, \
		"turf_a's temperature after conducting with an infinite-heat-capacity neighbor is [a_after]K - NaN or snapped to near TCMB is exactly the get_share_energy() inf/inf bug this test guards against.")
	TEST_ASSERT(!isnan(b_after) && b_after > TCMB + 1, \
		"turf_b's temperature after conducting with an infinite-heat-capacity neighbor is [b_after]K - NaN or snapped to near TCMB is exactly the get_share_energy() inf/inf bug this test guards against.")

/datum/unit_test/dogmos_infinite_heat_capacity_conduction/Destroy()
	// Unconditional, matching dogmos_superconduction_golden.dm's convention: a TEST_ASSERT abort in
	// Run() skips its own restore, and blocks_air/temperature are persistent turf state every later
	// test would inherit.
	var/turf/open/turf_a = run_loc_floor_bottom_left
	if(istype(turf_a))
		var/turf/open/turf_b = get_step(turf_a, EAST)
		turf_a.set_temperature(T20C)
		resync_turf_for_dogmos(turf_a)
		if(istype(turf_b))
			turf_b.blocks_air = initial(turf_b.blocks_air)
			turf_b.set_temperature(T20C)
			resync_turf_for_dogmos(turf_b)
	return ..()
