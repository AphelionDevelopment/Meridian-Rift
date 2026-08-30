/** Verifies SSair recovery preserves DM state without replacing service-owned atmosphere state. */
/datum/unit_test/dogmos_ssair_recovery

/datum/unit_test/dogmos_ssair_recovery/Run()
	if(!SSdogmos.service_ready || !dogmos_service_health())
		return Fail("dogmosd was not healthy before the SSair recovery test.", __FILE__, __LINE__)

	var/datum/controller/subsystem/dogmos/original_dogmos = SSdogmos
	var/original_service_pid = dogmos_service_pid()
	var/list/original_world_generation = dogmos_service_world_generation()
	var/original_equalize_enabled = SSair.equalize_enabled
	var/original_kennel_slow_mode = SSair.kennel_slow_mode
	var/original_threshold = SSair.kennel_high_cost_ms_threshold
	var/original_stage_work_limit = SSair.dogmos_stage_work_limit
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
	SSair.dogmos_frontier_epoch = list(1, 2, 3, 4)
	SSair.dogmos_stage_epoch = list(5, 6, 7, 8)
	SSair.dogmos_pending_stage = 4
	SSair.dogmos_pending_frontier_epoch = list(1, 2, 3, 4)
	SSair.dogmos_stage_remaining_estimate = 17
	SSair.dogmos_stage_work_limit = 128
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
	var/list/recovered_world_generation = dogmos_service_world_generation()
	TEST_ASSERT_EQUAL(recovered_world_generation[1], original_world_generation[1], \
		"SSair recovery changed the low word of the dogmosd world generation.")
	TEST_ASSERT_EQUAL(recovered_world_generation[2], original_world_generation[2], \
		"SSair recovery changed the high word of the dogmosd world generation.")
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
	for(var/word_index in 1 to 4)
		TEST_ASSERT_EQUAL(SSair.dogmos_frontier_epoch[word_index], word_index, \
			"SSair recovery changed frontier epoch word [word_index].")
		TEST_ASSERT_EQUAL(SSair.dogmos_stage_epoch[word_index], word_index + 4, \
			"SSair recovery changed stage epoch word [word_index].")
		TEST_ASSERT_EQUAL(SSair.dogmos_pending_frontier_epoch[word_index], word_index, \
			"SSair recovery changed pending frontier epoch word [word_index].")
	TEST_ASSERT_EQUAL(SSair.dogmos_pending_stage, 4, \
		"SSair recovery restarted instead of retaining the pending Dogmos stage.")
	TEST_ASSERT_EQUAL(SSair.dogmos_stage_remaining_estimate, 17, \
		"SSair recovery did not retain the pending Dogmos work estimate.")
	TEST_ASSERT_EQUAL(SSair.dogmos_stage_work_limit, 128, \
		"SSair recovery did not retain the Dogmos stage work limit.")
	TEST_ASSERT_EQUAL(SSair.resolve_kennel_jump_target(jump_key), jump_target, \
		"SSair recovery did not rebuild the bounded Kennel jump-target index.")

	var/list/dogmos_recovery_fields = list(
		"gases_registered",
		"service_ready",
		"dogmos_mixture_slots",
		"dogmos_mixture_generations",
		"dogmos_free_mixture_slots",
		"dogmos_gas_ids",
		"dogmos_gas_paths",
		"dogmos_reaction_ids",
		"dogmos_holder_slots",
		"dogmos_holder_generations",
		"dogmos_free_holder_slots",
		"dogmos_next_callback_sequence",
		"dogmos_pending_callback_batch",
		"dogmos_pending_callback_index",
		"dogmos_pending_callback_count",
		"dogmos_pending_service_callbacks",
		"dogmos_stale_callback_count",
		"dogmos_health_preflight_count",
		"turf_registration_batching",
		"dogmos_pending_turf_lifecycle",
		"dogmos_pending_turf_adjacency",
		"dogmos_pending_turf_adjacency_index",
		"dogmos_pending_turf_heat",
		"dogmos_pending_turf_heat_adjacency",
		"dogmos_pending_turf_heat_adjacency_index",
		"dogmos_pending_adjacency_retry",
		"runtime_topology_batching",
		"dogmos_runtime_topology_records",
		"dogmos_runtime_topology_calls",
		"dogmos_runtime_topology_max_queued",
		"dogmos_runtime_topology_deferrals",
		"dogmos_mixture_cache",
		"dogmos_mixture_cache_epoch",
		"dogmos_mixture_cache_hits",
		"dogmos_mixture_cache_misses",
		"dogmos_mixture_cache_collisions",
		"dogmos_mixture_cache_epoch_invalidations",
	)
	var/list/original_dogmos_state = list()
	for(var/field_name in dogmos_recovery_fields)
		original_dogmos_state[field_name] = SSdogmos.vars[field_name]

	SSdogmos.dogmos_pending_callback_batch = list("recovery callback")
	SSdogmos.dogmos_pending_callback_index = 1
	SSdogmos.dogmos_pending_callback_count = 1
	SSdogmos.dogmos_pending_service_callbacks = 2
	SSdogmos.dogmos_stale_callback_count += 11
	SSdogmos.dogmos_health_preflight_count += 12
	SSdogmos.dogmos_pending_turf_lifecycle = list("recovery lifecycle")
	SSdogmos.dogmos_pending_turf_adjacency = list("recovery adjacency")
	SSdogmos.dogmos_pending_turf_adjacency_index = list("recovery adjacency index")
	SSdogmos.dogmos_pending_turf_heat = list("recovery heat")
	SSdogmos.dogmos_pending_turf_heat_adjacency = list("recovery heat adjacency")
	SSdogmos.dogmos_pending_turf_heat_adjacency_index = list("recovery heat adjacency index")
	SSdogmos.dogmos_pending_adjacency_retry = list("recovery retry")
	SSdogmos.dogmos_runtime_topology_records += 13
	SSdogmos.dogmos_runtime_topology_calls += 14
	SSdogmos.dogmos_runtime_topology_max_queued += 15
	SSdogmos.dogmos_runtime_topology_deferrals += 16
	SSdogmos.dogmos_mixture_cache = list("recovery cache")
	SSdogmos.dogmos_mixture_cache_epoch += 17
	SSdogmos.dogmos_mixture_cache_hits += 18
	SSdogmos.dogmos_mixture_cache_misses += 19
	SSdogmos.dogmos_mixture_cache_collisions += 20
	SSdogmos.dogmos_mixture_cache_epoch_invalidations += 21
	var/list/expected_dogmos_state = list()
	for(var/field_name in dogmos_recovery_fields)
		expected_dogmos_state[field_name] = SSdogmos.vars[field_name]

	Master.subsystems += new /datum/controller/subsystem/dogmos

	TEST_ASSERT_NOTEQUAL(SSdogmos, original_dogmos, \
		"Dogmos recovery did not install the replacement subsystem datum.")
	TEST_ASSERT(SSdogmos.ss_flags & SS_NO_INIT, \
		"Dogmos recovery did not suppress cold service initialization.")
	TEST_ASSERT(SSdogmos.initialized, \
		"Dogmos recovery did not retain initialized state.")
	for(var/field_name in dogmos_recovery_fields)
		TEST_ASSERT_EQUAL(SSdogmos.vars[field_name], expected_dogmos_state[field_name], \
			"Dogmos recovery did not retain [field_name].")
	TEST_ASSERT_EQUAL(dogmos_service_pid(), original_service_pid, \
		"Dogmos recovery replaced the healthy dogmosd process.")
	var/list/dogmos_recovered_world_generation = dogmos_service_world_generation()
	TEST_ASSERT_EQUAL(dogmos_recovered_world_generation[1], original_world_generation[1], \
		"Dogmos recovery changed the low word of the dogmosd world generation.")
	TEST_ASSERT_EQUAL(dogmos_recovered_world_generation[2], original_world_generation[2], \
		"Dogmos recovery changed the high word of the dogmosd world generation.")
	TEST_ASSERT(dogmos_service_health(), \
		"dogmosd was unhealthy after Dogmos recovery.")
	for(var/field_name in dogmos_recovery_fields)
		SSdogmos.vars[field_name] = original_dogmos_state[field_name]
	TEST_ASSERT_EQUAL(sentinel.return_temperature(), 321.5, \
		"Dogmos recovery invalidated the sentinel mixture temperature.")
	TEST_ASSERT_EQUAL(sentinel.get_moles(/datum/gas/oxygen), 7.25, \
		"Dogmos recovery invalidated the sentinel mixture oxygen amount.")

	SSair.equalize_enabled = original_equalize_enabled
	SSair.kennel_slow_mode = original_kennel_slow_mode
	SSair.kennel_high_cost_ms_threshold = original_threshold
	SSair.recent_breaches = original_breaches
	SSair.kennel_jump_targets = original_jump_targets
	SSair.kennel_jump_target_counts = original_jump_target_counts
	SSair.dogmos_pending_stage = null
	SSair.dogmos_pending_frontier_epoch = null
	SSair.dogmos_stage_work_limit = original_stage_work_limit
