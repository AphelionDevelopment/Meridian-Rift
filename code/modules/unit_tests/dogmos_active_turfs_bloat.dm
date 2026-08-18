/// Upper bound for the bounded active-turf maintenance walk.
#define ACTIVE_TURFS_BLOAT_TEST_MAX_MS 15

/** Bounds the legacy active-turf walk independently of gas movement. */
/datum/unit_test/dogmos_active_turfs_bloat

/datum/unit_test/dogmos_active_turfs_bloat/Run()
	var/list/pair = allocate_turf_pair()
	var/turf/open/turf_a = pair[1]
	var/turf/open/turf_b = pair[2]

	// The regression is driven by list length, so repeated turfs are sufficient.
	var/list/original_active_turfs = SSair.active_turfs
	var/list/bloated = list(turf_a, turf_b)
	for(var/i in 1 to 1900)
		bloated += turf_a
		bloated += turf_b
	SSair.active_turfs = bloated
	var/original_cursor = SSair.active_turfs_walk_cursor
	SSair.active_turfs_walk_cursor = 0

	var/start_tick_usage = TICK_USAGE_REAL
	SSair.process_active_turfs()
	var/cost_ms = TICK_USAGE_TO_MS(start_tick_usage)

	SSair.active_turfs = original_active_turfs
	SSair.active_turfs_walk_cursor = original_cursor

	TEST_ASSERT(cost_ms < ACTIVE_TURFS_BLOAT_TEST_MAX_MS, \
		"process_active_turfs() took [cost_ms]ms against a ~3800-entry list (bound: [ACTIVE_TURFS_BLOAT_TEST_MAX_MS]ms); work should stay within ACTIVE_TURFS_WALK_BATCH_SIZE.")

#undef ACTIVE_TURFS_BLOAT_TEST_MAX_MS
