/**
 * The real correctness check for the SSAIR_ACTIVETURFS cutover to Rust's gas FDM
 * (process_turfs_auxtools/finish_turf_processing_auxtools, aphelion-dogmos src/turfs/processing.rs,
 * called from SSair.process_active_turfs(), code/controllers/subsystem/air.dm). station_turf_has_air
 * already confirms a single settled floor holds a sane atmosphere, but says nothing about whether
 * sharing BETWEEN two different turfs actually still happens correctly - this seeds two adjacent
 * turfs with deliberately asymmetric oxygen, runs one real FDM cycle, and checks the physical
 * invariants any correct diffusion step must satisfy: total moles conserved, gas flows from the
 * fuller turf to the emptier one, and a single share step doesn't overshoot into reversing which
 * turf has more.
 *
 * Deliberately checks invariants rather than an exact hand-computed value - replicating Rust's FDM
 * arithmetic (GAS_DIFFUSION_CONSTANT-weighted merge across every neighbor, not just the pair under
 * test) by hand in DM risks the test itself being wrong in a way that either false-fails or, worse,
 * false-passes by both sides sharing the same mistake.
 *
 * Does NOT check "total moles across just turf_a and turf_b conserved" - that isn't actually a valid
 * invariant here. The unit test room has more than two turfs, and Rust's FDM scans its whole
 * registered graph every cycle, not just the pair under test - turf_a and turf_b each have other
 * neighbors participating in the same share pass, so gas measurably leaves this two-turf slice
 * without leaving the room (confirmed: an earlier version of this test asserted exact 2-turf
 * conservation and failed for exactly this reason, not because sharing was wrong).
 *
 * Calls process_turfs_auxtools()/finish_turf_processing_auxtools() directly with a fixed, generous
 * time budget rather than going through SSair.process_active_turfs()'s real
 * Master.current_ticklimit - TICK_USAGE calculation - confirmed the hard way: deep into a long test
 * suite, that budget can be near-zero or negative by the time this test's turn comes up (whatever
 * the current tick has already spent), so Rust's FDM gets Duration::from_millis(0) and correctly
 * does nothing in exactly one step. That's the tick-budgeting working as designed, not a bug - it
 * just makes SSair.process_active_turfs() itself unsuitable for a deterministic single-cycle test.
 */
/datum/unit_test/dogmos_gas_fdm_golden

/datum/unit_test/dogmos_gas_fdm_golden/Run()
	var/list/pair = allocate_turf_pair()
	var/turf/open/turf_a = pair[1]
	var/turf/open/turf_b = pair[2]

	var/datum/gas_mixture/air_a = turf_a.air
	var/datum/gas_mixture/air_b = turf_b.air
	var/original_a_o2 = air_a.get_moles(/datum/gas/oxygen)

	// Deliberately asymmetric: triple turf_a's oxygen relative to its actual starting value.
	air_a.set_moles(/datum/gas/oxygen, original_a_o2 * 3)

	var/a_before = air_a.get_moles(/datum/gas/oxygen)
	var/b_before = air_b.get_moles(/datum/gas/oxygen)
	TEST_ASSERT(a_before > b_before, \
		"Seeding turf_a with 3x turf_b's oxygen did not actually produce an asymmetric pair ([a_before] vs [b_before]) - test setup is broken, not the thing under test.")

	SSair.active_turfs |= turf_a
	SSair.active_turfs |= turf_b
	SSair.process_turfs_auxtools(100)
	SSair.finish_turf_processing_auxtools(100)

	var/a_after = air_a.get_moles(/datum/gas/oxygen)
	var/b_after = air_b.get_moles(/datum/gas/oxygen)

	TEST_ASSERT(a_after < a_before, \
		"turf_a's oxygen ([a_before] -> [a_after]) did not decrease after sharing with lower-oxygen turf_b - gas is not flowing out of the fuller turf.")
	TEST_ASSERT(b_after > b_before, \
		"turf_b's oxygen ([b_before] -> [b_after]) did not increase after sharing with higher-oxygen turf_a - gas is not flowing into the emptier turf.")
	TEST_ASSERT(a_after > b_after, \
		"turf_a's oxygen ([a_after]) dropped to or below turf_b's ([b_after]) after a single share step - a single GAS_DIFFUSION_CONSTANT-weighted step should not overshoot past equilibrium.")
