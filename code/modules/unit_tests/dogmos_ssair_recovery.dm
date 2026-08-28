/** Verifies SSair recovery preserves DM state without replacing service-owned atmosphere state. */
/datum/unit_test/dogmos_ssair_recovery

/datum/unit_test/dogmos_ssair_recovery/Run()
	if(!SSdogmos.service_ready || !dogmos_service_health())
		return Fail("dogmosd was not healthy before the SSair recovery test.", __FILE__, __LINE__)

	var/datum/controller/subsystem/dogmos/original_dogmos = SSdogmos
	var/original_service_pid = dogmos_service_pid()
	var/original_equalize_enabled = SSair.equalize_enabled
	var/original_kennel_slow_mode = SSair.kennel_slow_mode
	var/original_threshold = SSair.kennel_high_cost_ms_threshold
	var/list/original_breaches = SSair.recent_breaches
	var/list/original_active_turfs = SSair.active_turfs
	var/list/original_jump_targets = SSair.kennel_jump_targets
	var/list/original_jump_target_counts = SSair.kennel_jump_target_counts
	var/turf/jump_target = run_loc_floor_bottom_left
	var/jump_key = REF(jump_target)

	SSair.equalize_enabled = FALSE
	SSair.kennel_slow_mode = FALSE
	SSair.kennel_high_cost_ms_threshold = 7.5
	SSair.kennel_push_cursor = 3
	SSair.active_turfs_walk_cursor = 17
	var/list/recovery_breaches = list(list(
		"time" = "00:00:00",
		"jump_to" = jump_key,
		"area" = "Recovery Test",
		"moles_lost" = 1,
	))
	SSair.recent_breaches = recovery_breaches
	SSair.kennel_jump_targets = list()
	SSair.kennel_jump_targets[jump_key] = WEAKREF(jump_target)
	SSair.kennel_jump_target_counts = list()
	SSair.kennel_jump_target_counts[jump_key] = 1

	var/datum/gas_mixture/sentinel = allocate(/datum/gas_mixture, CELL_VOLUME)
	sentinel.set_temperature(321.5)
	sentinel.set_moles(/datum/gas/oxygen, 7.25)
	var/sentinel_slot = sentinel.dogmos_slot
	var/sentinel_generation = sentinel.dogmos_generation

	Master.subsystems += new /datum/controller/subsystem/air

	TEST_ASSERT_EQUAL(SSdogmos, original_dogmos, \
		"SSair recovery replaced the authoritative Dogmos subsystem datum.")
	TEST_ASSERT_EQUAL(dogmos_service_pid(), original_service_pid, \
		"SSair recovery replaced the healthy dogmosd process.")
	TEST_ASSERT(dogmos_service_health(), \
		"dogmosd was unhealthy after SSair recovery.")
	TEST_ASSERT_EQUAL(sentinel.dogmos_slot, sentinel_slot, \
		"SSair recovery changed the sentinel mixture slot.")
	TEST_ASSERT_EQUAL(sentinel.dogmos_generation, sentinel_generation, \
		"SSair recovery changed the sentinel mixture generation.")
	TEST_ASSERT_EQUAL(sentinel.return_temperature(), 321.5, \
		"SSair recovery changed the service-owned sentinel temperature.")
	TEST_ASSERT_EQUAL(sentinel.get_moles(/datum/gas/oxygen), 7.25, \
		"SSair recovery changed the service-owned sentinel oxygen amount.")

	TEST_ASSERT_EQUAL(SSair.equalize_enabled, FALSE, \
		"SSair recovery did not retain the equalization setting.")
	TEST_ASSERT_EQUAL(SSair.kennel_slow_mode, FALSE, \
		"SSair recovery did not retain the Kennel slow-mode setting.")
	TEST_ASSERT_EQUAL(SSair.kennel_high_cost_ms_threshold, 7.5, \
		"SSair recovery did not retain the Kennel threshold.")
	TEST_ASSERT_EQUAL(SSair.recent_breaches, recovery_breaches, \
		"SSair recovery did not retain the bounded breach history.")
	TEST_ASSERT_EQUAL(SSair.active_turfs, original_active_turfs, \
		"SSair recovery did not retain the active-turf runtime queue.")
	TEST_ASSERT_EQUAL(SSair.kennel_push_cursor, 0, \
		"SSair recovery retained the old Kennel update cursor.")
	TEST_ASSERT_EQUAL(SSair.active_turfs_walk_cursor, 0, \
		"SSair recovery retained the old active-turf walk cursor.")
	TEST_ASSERT_EQUAL(SSair.resolve_kennel_jump_target(jump_key), jump_target, \
		"SSair recovery did not rebuild the bounded Kennel jump-target index.")

	SSair.equalize_enabled = original_equalize_enabled
	SSair.kennel_slow_mode = original_kennel_slow_mode
	SSair.kennel_high_cost_ms_threshold = original_threshold
	SSair.recent_breaches = original_breaches
	SSair.kennel_jump_targets = original_jump_targets
	SSair.kennel_jump_target_counts = original_jump_target_counts
