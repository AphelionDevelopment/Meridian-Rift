/// Finite stand-in for the test room's heat_capacity, which is INFINITY (inherited from base /turf -
/// neither /turf/open/indestructible nor /turf/closed/indestructible overrides it). Rust's
/// get_share_energy() computes (c1*c2)/(c1+c2), which is INF/INF = NaN for two infinite capacities, so
/// a test using the room's stock values would measure the NaN path rather than real conduction. Value
/// mirrors /turf/open/floor's real 20000.
#define SUPERCONDUCTION_TEST_HEAT_CAPACITY 20000

/**
 * The real correctness check for the SSAIR_SUPERCONDUCTIVITY cutover to Rust's turf-to-turf heat
 * conduction (process_turf_heat, aphelion-dogmos src/turfs/superconduct.rs, driven from
 * SSair.process_super_conductivity(), code/controllers/subsystem/air.dm). Checks the same class of
 * physical invariant dogmos_gas_fdm_golden.dm checks for gas diffusion: heat flows hot -> cold, and
 * conduction doesn't overshoot into reversing which turf is hotter.
 *
 * Setting blocks_air on turf_b is the whole point of the setup, not incidental. Superconduction moves
 * heat where gas CANNOT flow, so two gas-adjacent turfs deliberately get no heat edge at all:
 * /turf/open/conductivity_directions() returns only directions whose neighbor is absent from
 * atmos_adjacent_turfs, and sync_dogmos_adjacency() (LINDA_system.dm) then stores the INVERSE of that
 * as conductivity_blocked_directions, which is what Rust builds its heat graph from
 * (ALL_CARDINALS_MULTIZ - blocked_dirs). A plain adjacent pair - which is exactly what
 * allocate_turf_pair() guarantees, since it asserts gas-adjacency - therefore can never conduct, and an
 * earlier version of this test that used one failed for precisely that reason. Marking turf_b
 * blocks_air breaks gas adjacency, which is what CREATES the heat edge:
 * * immediate_calculate_adjacent_turfs() drops turf_b from turf_a's atmos_adjacent_turfs (its
 *   `!(blocks_air || current_turf.blocks_air)` branch), so that direction becomes non-gas-adjacent and
 *   is left out of turf_a's conductivity_blocked_directions.
 * * turf_b, being blocks_air, takes /turf/open/conductivity_directions()'s `return ..()` branch to the
 *   base /turf version (ALL_CARDINALS), so nothing is blocked for it and the reverse edge exists too.
 * * Both keep init_air = TRUE and so both still register - closed turfs would NOT, since /turf/closed
 *   sets init_air = FALSE and register_dogmos_air() early-returns on that, which is why this can't
 *   simply test against a real wall.
 * This mirrors dogmos_turf_registration.dm's own blocks_air case, which exists to prove heat-only
 * registration works.
 *
 * process_turf_heat() is fire-and-forget: a non-blocking try_send over a flume::bounded(1) channel to a
 * persistent worker, silently dropped if the slot is occupied, and the live SSair is also calling it
 * every ~0.5s throughout the suite. Hence the bounded retry rather than one call - a single notify has
 * no guarantee of being the one that lands.
 */
/datum/unit_test/dogmos_superconduction_golden

/datum/unit_test/dogmos_superconduction_golden/Run()
	var/list/pair = allocate_turf_pair()
	var/turf/open/turf_a = pair[1]
	var/turf/open/turf_b = pair[2]

	turf_a.heat_capacity = SUPERCONDUCTION_TEST_HEAT_CAPACITY
	turf_b.heat_capacity = SUPERCONDUCTION_TEST_HEAT_CAPACITY
	turf_b.blocks_air = TRUE
	resync_turf_for_dogmos(turf_a)
	resync_turf_for_dogmos(turf_b)

	TEST_ASSERT(!(turf_b in turf_a.atmos_adjacent_turfs), \
		"turf_b is still gas-adjacent to turf_a after being marked blocks_air - the heat edge this test depends on only exists for NON-gas-adjacent neighbors, so the setup did not take.")

	turf_a.set_temperature(700)
	turf_b.set_temperature(T20C)

	var/a_before = turf_a.return_temperature()
	var/b_before = turf_b.return_temperature()
	TEST_ASSERT(a_before > b_before, \
		"Seeding turf_a at 700K and turf_b at T20C did not produce an asymmetric pair ([a_before] vs [b_before]) - test setup is broken, not the thing under test.")

	var/a_after = a_before
	for(var/attempt in 1 to 10)
		SSair.process_turf_heat()
		sleep(2)
		a_after = turf_a.return_temperature()
		if(a_after != a_before)
			break

	var/b_after = turf_b.return_temperature()

	TEST_ASSERT(a_after < a_before, \
		"turf_a's temperature ([a_before] -> [a_after]) did not decrease after conducting with cooler turf_b (cost_superconductivity [SSair.cost_superconductivity]) - heat is not flowing out of the hotter turf.")
	TEST_ASSERT(b_after > b_before, \
		"turf_b's temperature ([b_before] -> [b_after]) did not increase after conducting with hotter turf_a - heat is not flowing into the cooler turf.")
	TEST_ASSERT(a_after > b_after, \
		"turf_a's temperature ([a_after]) dropped to or below turf_b's ([b_after]) after conduction - this should not overshoot past equilibrium.")

/datum/unit_test/dogmos_superconduction_golden/Destroy()
	// Unconditional, matching dogmos_turf_registration.dm's convention: a TEST_ASSERT abort in Run()
	// skips any cleanup there, and blocks_air/heat_capacity are persistent turf state every later test
	// would inherit. restore_atmos() does not cover either of them.
	var/turf/open/turf_a = run_loc_floor_bottom_left
	if(istype(turf_a))
		var/turf/open/turf_b = get_step(turf_a, EAST)
		turf_a.heat_capacity = initial(turf_a.heat_capacity)
		turf_a.set_temperature(T20C)
		resync_turf_for_dogmos(turf_a)
		if(istype(turf_b))
			turf_b.blocks_air = initial(turf_b.blocks_air)
			turf_b.heat_capacity = initial(turf_b.heat_capacity)
			turf_b.set_temperature(T20C)
			resync_turf_for_dogmos(turf_b)
	return ..()

#undef SUPERCONDUCTION_TEST_HEAT_CAPACITY
