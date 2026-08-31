#if defined(UNIT_TESTS) || defined(SPACEMAN_DMM)

#define DOGMOS_WORLD_GENERATION_WORD_MAX 65535
#define DOGMOS_TEST_STAGE_EXCITED_GROUPS 1
#define DOGMOS_TEST_STAGE_EQUALIZE 2
#define DOGMOS_TEST_STAGE_TURF_HEAT 3
#define DOGMOS_TEST_STAGE_REACTIONS 5
#define DOGMOS_TEST_STAGE_RESPONSE_FIELDS 13
#define DOGMOS_PIPELINE_TEST_EPSILON 0.001

/** Verifies startup identity mismatches report exact expected and actual values. */
/datum/unit_test/dogmos_service_contract_identity

/datum/unit_test/dogmos_service_contract_identity/Run()
	var/abi_error = dogmos_contract_identity_error(DOGMOS_CONTRACT_ABI_VERSION + 1, DOGMOS_CONTRACT_PROTOCOL_VERSION, DOGMOS_CONTRACT_SOURCE_REVISION, DOGMOS_CONTRACT_FEATURE_FINGERPRINT)
	if(abi_error != "Dogmos ABI mismatch: expected [DOGMOS_CONTRACT_ABI_VERSION], actual [DOGMOS_CONTRACT_ABI_VERSION + 1].")
		return Fail("Dogmos startup did not report the exact ABI mismatch: [abi_error]", __FILE__, __LINE__)
	var/protocol_error = dogmos_contract_identity_error(DOGMOS_CONTRACT_ABI_VERSION, DOGMOS_CONTRACT_PROTOCOL_VERSION + 1, DOGMOS_CONTRACT_SOURCE_REVISION, DOGMOS_CONTRACT_FEATURE_FINGERPRINT)
	if(protocol_error != "Dogmos protocol mismatch: expected [DOGMOS_CONTRACT_PROTOCOL_VERSION], actual [DOGMOS_CONTRACT_PROTOCOL_VERSION + 1].")
		return Fail("Dogmos startup did not report the exact protocol mismatch: [protocol_error]", __FILE__, __LINE__)
	var/mismatched_revision = "[DOGMOS_CONTRACT_SOURCE_REVISION]-mismatch"
	var/revision_error = dogmos_contract_identity_error(DOGMOS_CONTRACT_ABI_VERSION, DOGMOS_CONTRACT_PROTOCOL_VERSION, mismatched_revision, DOGMOS_CONTRACT_FEATURE_FINGERPRINT)
	if(revision_error != "Dogmos source revision mismatch: expected [DOGMOS_CONTRACT_SOURCE_REVISION], actual [mismatched_revision].")
		return Fail("Dogmos startup did not report the exact source-revision mismatch: [revision_error]", __FILE__, __LINE__)
	var/mismatched_fingerprint = "[DOGMOS_CONTRACT_FEATURE_FINGERPRINT]-mismatch"
	var/fingerprint_error = dogmos_contract_identity_error(DOGMOS_CONTRACT_ABI_VERSION, DOGMOS_CONTRACT_PROTOCOL_VERSION, DOGMOS_CONTRACT_SOURCE_REVISION, mismatched_fingerprint)
	if(fingerprint_error != "Dogmos feature fingerprint mismatch: expected [DOGMOS_CONTRACT_FEATURE_FINGERPRINT], actual [mismatched_fingerprint].")
		return Fail("Dogmos startup did not report the exact feature-fingerprint mismatch: [fingerprint_error]", __FILE__, __LINE__)
	var/matching_error = dogmos_contract_identity_error(DOGMOS_CONTRACT_ABI_VERSION, DOGMOS_CONTRACT_PROTOCOL_VERSION, DOGMOS_CONTRACT_SOURCE_REVISION, DOGMOS_CONTRACT_FEATURE_FINGERPRINT)
	if(!isnull(matching_error))
		return Fail("Dogmos startup reported an identity mismatch for the synchronized contract: [matching_error]", __FILE__, __LINE__)

/** Verifies the production service reports its identity and preserves a sentinel mixture. */
/datum/unit_test/dogmos_service_lifecycle
	/// Sentinel mixture released during test teardown.
	var/datum/gas_mixture/sentinel

/datum/unit_test/dogmos_service_lifecycle/Run()
	if(!SSdogmos.service_ready || !dogmos_service_health())
		return Fail("dogmosd did not pass startup identity and health checks.", __FILE__, __LINE__)

	var/service_pid = dogmos_service_pid()
	if(!isnum(service_pid) || service_pid <= 0 || round(service_pid) != service_pid)
		return Fail("dogmosd reported invalid service PID [service_pid].", __FILE__, __LINE__)

	var/list/world_generation_words = dogmos_service_world_generation()
	if(!islist(world_generation_words) || length(world_generation_words) != 2)
		return Fail("dogmosd reported malformed world-generation words.", __FILE__, __LINE__)
	for(var/world_generation_word in world_generation_words)
		if(!isnum(world_generation_word) || world_generation_word < 0 || world_generation_word > DOGMOS_WORLD_GENERATION_WORD_MAX || round(world_generation_word) != world_generation_word)
			return Fail("dogmosd reported invalid world-generation word [world_generation_word].", __FILE__, __LINE__)
	if(!world_generation_words[1] && !world_generation_words[2])
		return Fail("dogmosd reported a zero world generation.", __FILE__, __LINE__)

	var/expected_temperature = 321.5
	var/expected_oxygen_moles = 7.25
	sentinel = new(CELL_VOLUME)
	sentinel.set_temperature(expected_temperature)
	sentinel.set_moles(/datum/gas/oxygen, expected_oxygen_moles)
	var/sentinel_temperature = sentinel.return_temperature()
	var/sentinel_oxygen_moles = sentinel.get_moles(/datum/gas/oxygen)
	if(sentinel.dogmos_slot <= 0 || sentinel.dogmos_generation <= 0)
		return Fail("Dogmos assigned an invalid identity to the lifecycle sentinel mixture.", __FILE__, __LINE__)
	if(sentinel_temperature != expected_temperature || sentinel_oxygen_moles != expected_oxygen_moles)
		return Fail("dogmosd did not preserve the lifecycle sentinel mixture state.", __FILE__, __LINE__)

	log_world("DOGMOS SERVICE LIFECYCLE: pid=[service_pid] world_generation_words=[world_generation_words[1]]:[world_generation_words[2]] sentinel=[sentinel.dogmos_slot]:[sentinel.dogmos_generation] temperature=[sentinel_temperature] oxygen_moles=[sentinel_oxygen_moles]")

/datum/unit_test/dogmos_service_lifecycle/Destroy()
	QDEL_NULL(sentinel)
	return ..()

/** Verifies service-backed mixture identities are live, bounded, and generational. */
/datum/unit_test/dogmos_service_mixture_identity

/datum/unit_test/dogmos_service_mixture_identity/Run()
	if(!SSdogmos.service_ready)
		return Fail("dogmosd did not pass startup identity and health checks.", __FILE__, __LINE__)
	var/datum/gas_mixture/first = new(CELL_VOLUME)
	var/first_slot = first.dogmos_slot
	var/first_generation = first.dogmos_generation
	if(first_slot <= 0 || first_slot > 16777216)
		return Fail("Dogmos assigned an invalid mixture slot [first_slot].", __FILE__, __LINE__)
	if(first_generation <= 0 || first_generation > 16777216)
		return Fail("Dogmos assigned an invalid mixture generation [first_generation].", __FILE__, __LINE__)
	var/list/retired_snapshot = new/list(42)
	SSdogmos.store_mixture_snapshot_cache(first_slot, first_generation, retired_snapshot)
	first.__gasmixture_unregister()
	if(SSdogmos.lookup_mixture_snapshot_cache(first_slot, first_generation))
		return Fail("Unregistering a mixture retained its cached snapshot.", __FILE__, __LINE__)
	qdel(first)

	var/datum/gas_mixture/second = new(CELL_VOLUME)
	if(second.dogmos_slot != first_slot)
		return Fail("Dogmos did not reuse the released bounded mixture slot.", __FILE__, __LINE__)
	if(second.dogmos_generation <= first_generation)
		return Fail("Dogmos reused a mixture slot without advancing its generation.", __FILE__, __LINE__)
	if(SSdogmos.lookup_mixture_snapshot_cache(first_slot, first_generation))
		return Fail("A reused mixture slot resolved the retired generation's cached snapshot.", __FILE__, __LINE__)
	qdel(second)

/** Verifies the bounded direct-mapped mixture snapshot cache and mutation invalidation. */
/datum/unit_test/dogmos_service_mixture_snapshot_cache
	/// First service-backed mixture released during teardown.
	var/datum/gas_mixture/first
	/// Second service-backed mixture released during teardown.
	var/datum/gas_mixture/second

/datum/unit_test/dogmos_service_mixture_snapshot_cache/Run()
	if(!SSdogmos.service_ready)
		return Fail("dogmosd did not pass startup identity and health checks.", __FILE__, __LINE__)

	SSdogmos.reset_mixture_snapshot_cache()
	first = new(CELL_VOLUME)
	second = new(CELL_VOLUME)
	first.set_temperature(312.5)
	first.set_moles(/datum/gas/oxygen, 4)
	second.set_temperature(290)

	var/misses_before = SSdogmos.dogmos_mixture_cache_misses
	var/hits_before = SSdogmos.dogmos_mixture_cache_hits
	if(first.return_temperature() != 312.5)
		return Fail("The mixture snapshot cache changed the returned temperature.", __FILE__, __LINE__)
	if(first.total_moles() != 4)
		return Fail("The mixture snapshot cache changed the returned total moles.", __FILE__, __LINE__)
	if(SSdogmos.dogmos_mixture_cache_misses != misses_before + 1 || SSdogmos.dogmos_mixture_cache_hits != hits_before + 1)
		return Fail("Repeated same-revision getters did not produce one cache miss followed by one hit.", __FILE__, __LINE__)

	first.set_temperature(315)
	first.return_temperature()
	if(SSdogmos.dogmos_mixture_cache_misses != misses_before + 2)
		return Fail("A primary mixture mutation did not evict its cached snapshot.", __FILE__, __LINE__)

	var/misses_before_multi = SSdogmos.dogmos_mixture_cache_misses
	first.adjust_multi(/datum/gas/oxygen, 1, /datum/gas/nitrogen, 2)
	first.return_temperature()
	if(SSdogmos.dogmos_mixture_cache_misses != misses_before_multi + 1)
		return Fail("A multi-gas mutation did not evict its cached snapshot.", __FILE__, __LINE__)

	second.return_temperature()
	var/misses_after_warm = SSdogmos.dogmos_mixture_cache_misses
	first.copy_from(second)
	first.return_temperature()
	second.return_temperature()
	if(SSdogmos.dogmos_mixture_cache_misses != misses_after_warm + 2)
		return Fail("A two-mixture mutation did not evict both cached handles.", __FILE__, __LINE__)

	var/list/fake_snapshot = new/list(42)
	SSdogmos.store_mixture_snapshot_cache(1, 7, fake_snapshot)
	var/collisions_before = SSdogmos.dogmos_mixture_cache_collisions
	SSdogmos.store_mixture_snapshot_cache(513, 9, fake_snapshot)
	if(SSdogmos.dogmos_mixture_cache_collisions != collisions_before + 1)
		return Fail("Direct-mapped cache collisions were not counted.", __FILE__, __LINE__)
	if(!isnull(SSdogmos.lookup_mixture_snapshot_cache(1, 7)))
		return Fail("A colliding slot retained the displaced cache entry.", __FILE__, __LINE__)
	if(SSdogmos.lookup_mixture_snapshot_cache(513, 8))
		return Fail("The mixture snapshot cache accepted a mismatched generation.", __FILE__, __LINE__)

	var/invalidations_before = SSdogmos.dogmos_mixture_cache_epoch_invalidations
	SSdogmos.invalidate_mixture_snapshot_epoch()
	if(SSdogmos.dogmos_mixture_cache_epoch_invalidations != invalidations_before + 1 || SSdogmos.lookup_mixture_snapshot_cache(513, 9))
		return Fail("Stage-wide epoch invalidation retained an old snapshot.", __FILE__, __LINE__)
	SSdogmos.dogmos_mixture_cache_epoch = 16777216
	SSdogmos.store_mixture_snapshot_cache(1, 1, fake_snapshot)
	SSdogmos.invalidate_mixture_snapshot_epoch()
	if(SSdogmos.dogmos_mixture_cache_epoch != 1 || SSdogmos.lookup_mixture_snapshot_cache(1, 1))
		return Fail("Exact-integer cache epoch rollover did not clear and reset the bounded cache.", __FILE__, __LINE__)

	first.return_temperature()
	var/misses_before_immutable = SSdogmos.dogmos_mixture_cache_misses
	first.mark_immutable()
	first.return_temperature()
	if(SSdogmos.dogmos_mixture_cache_misses != misses_before_immutable + 1)
		return Fail("Marking a mixture immutable did not evict its cached snapshot.", __FILE__, __LINE__)
	if(!first.is_immutable())
		return Fail("Dogmos did not retain the mixture's immutable state.", __FILE__, __LINE__)

/datum/unit_test/dogmos_service_mixture_snapshot_cache/Destroy()
	QDEL_NULL(first)
	QDEL_NULL(second)
	SSdogmos.reset_mixture_snapshot_cache()
	return ..()

/** Verifies pipenet reconciliation uses one atomic state batch while conserving mixture state. */
/datum/unit_test/dogmos_service_pipeline_batch_reconcile
	/// Pipeline released during teardown.
	var/datum/pipeline/test_pipeline
	/// First service-backed mixture released during teardown.
	var/datum/gas_mixture/first
	/// Second service-backed mixture released during teardown.
	var/datum/gas_mixture/second

/datum/unit_test/dogmos_service_pipeline_batch_reconcile/Run()
	if(!SSdogmos.service_ready)
		return Fail("dogmosd did not pass startup identity and health checks.", __FILE__, __LINE__)

	first = new(100)
	second = new(300)
	first.set_volume(100)
	second.set_volume(300)
	first.set_temperature(300)
	second.set_temperature(600)
	first.set_moles(/datum/gas/oxygen, 4)
	second.set_moles(/datum/gas/nitrogen, 12)
	var/expected_temperature = (first.return_temperature() * first.heat_capacity() + second.return_temperature() * second.heat_capacity()) / (first.heat_capacity() + second.heat_capacity())

	test_pipeline = new
	test_pipeline.set_air(first)
	test_pipeline.other_airs = list(second)
	var/invalidations_before = SSdogmos.dogmos_mixture_cache_epoch_invalidations
	test_pipeline.reconcile_air()

	if(SSdogmos.dogmos_mixture_cache_epoch_invalidations != invalidations_before + 1)
		return Fail("Pipenet reconciliation did not invalidate the mixture snapshot cache exactly once.", __FILE__, __LINE__)
	var/first_oxygen = first.get_moles(/datum/gas/oxygen)
	var/second_oxygen = second.get_moles(/datum/gas/oxygen)
	if(abs(first_oxygen - 1) > DOGMOS_PIPELINE_TEST_EPSILON || abs(second_oxygen - 3) > DOGMOS_PIPELINE_TEST_EPSILON)
		return Fail("Pipenet reconciliation did not distribute oxygen by volume ratio: [first_oxygen] / [second_oxygen].", __FILE__, __LINE__)
	var/first_nitrogen = first.get_moles(/datum/gas/nitrogen)
	var/second_nitrogen = second.get_moles(/datum/gas/nitrogen)
	if(abs(first_nitrogen - 3) > DOGMOS_PIPELINE_TEST_EPSILON || abs(second_nitrogen - 9) > DOGMOS_PIPELINE_TEST_EPSILON)
		return Fail("Pipenet reconciliation did not distribute nitrogen by volume ratio: [first_nitrogen] / [second_nitrogen].", __FILE__, __LINE__)
	if(abs(first.return_temperature() - expected_temperature) > DOGMOS_PIPELINE_TEST_EPSILON || abs(second.return_temperature() - expected_temperature) > DOGMOS_PIPELINE_TEST_EPSILON)
		return Fail("Pipenet reconciliation did not conserve thermal energy.", __FILE__, __LINE__)

/datum/unit_test/dogmos_service_pipeline_batch_reconcile/Destroy()
	QDEL_NULL(test_pipeline)
	QDEL_NULL(first)
	QDEL_NULL(second)
	return ..()

/** Verifies non-conducting turfs remain absent from the service heat graph. */
/datum/unit_test/dogmos_service_turf_heat_absence
	/// Turf restored after the assertion run.
	var/turf/target
	/// Original thermal conductivity restored during teardown.
	var/original_thermal_conductivity
	/// Original heat capacity restored during teardown.
	var/original_heat_capacity

/datum/unit_test/dogmos_service_turf_heat_absence/Run()
	if(!SSdogmos.service_ready)
		return Fail("dogmosd did not pass startup identity and health checks.", __FILE__, __LINE__)
	target = run_loc_floor_bottom_left
	original_thermal_conductivity = target.thermal_conductivity
	original_heat_capacity = target.heat_capacity
	target.thermal_conductivity = 0
	target.heat_capacity = 0
	target.register_dogmos_air()
	target.sync_dogmos_adjacency()

	var/list/heat_snapshot = dogmos_turf_heat_snapshot(list(target.dogmos_service_slot(), target.dogmos_service_generation()))
	if(length(heat_snapshot) != 5)
		return Fail("Dogmos returned a malformed turf heat snapshot with [length(heat_snapshot)] fields.", __FILE__, __LINE__)
	if(heat_snapshot[1] != FALSE)
		return Fail("Dogmos retained a heat-graph node for a turf with zero conductivity and heat capacity.", __FILE__, __LINE__)

/datum/unit_test/dogmos_service_turf_heat_absence/Destroy()
	if(target)
		target.thermal_conductivity = original_thermal_conductivity
		target.heat_capacity = original_heat_capacity
		target.register_dogmos_air()
	return ..()

/** Verifies startup turf mutations remain deferred until the bounded batch flush. */
/datum/unit_test/dogmos_service_turf_batching
	/// Turf restored after the assertion run.
	var/turf/target
	/// Adjacent turf restored after the assertion run.
	var/turf/neighbor
	/// Original thermal conductivity restored during teardown.
	var/original_thermal_conductivity
	/// Original heat capacity restored during teardown.
	var/original_heat_capacity
	/// Original adjacent-turf atmosphere initialization state restored during teardown.
	var/original_neighbor_init_air

/datum/unit_test/dogmos_service_turf_batching/Run()
	if(!SSdogmos.service_ready)
		return Fail("dogmosd did not pass startup identity and health checks.", __FILE__, __LINE__)
	target = run_loc_floor_bottom_left
	original_thermal_conductivity = target.thermal_conductivity
	original_heat_capacity = target.heat_capacity
	target.thermal_conductivity = 0
	target.heat_capacity = 0
	target.register_dogmos_air()

	SSdogmos.begin_turf_registration_batch()
	target.thermal_conductivity = original_thermal_conductivity
	target.heat_capacity = original_heat_capacity
	target.register_dogmos_air()
	var/list/deferred_snapshot = dogmos_turf_heat_snapshot(list(target.dogmos_service_slot(), target.dogmos_service_generation()))
	if(deferred_snapshot[1] != FALSE)
		return Fail("Dogmos applied a startup turf mutation before its explicit batch flush.", __FILE__, __LINE__)
	SSdogmos.finish_turf_registration_batch()
	var/list/flushed_snapshot = dogmos_turf_heat_snapshot(list(target.dogmos_service_slot(), target.dogmos_service_generation()))
	if(flushed_snapshot[1] != TRUE)
		return Fail("Dogmos did not apply a startup turf mutation during its explicit batch flush.", __FILE__, __LINE__)

	neighbor = get_step(target, EAST)
	if(!isopenturf(neighbor) || !neighbor.init_air)
		return Fail("The Dogmos batching test requires an atmosphere-enabled open turf to the east.", __FILE__, __LINE__)
	original_neighbor_init_air = neighbor.init_air
	neighbor.init_air = FALSE
	neighbor.register_dogmos_air(remove_uninitialized = TRUE)
	neighbor.init_air = original_neighbor_init_air
	target.sync_dogmos_adjacency()
	var/list/neighbor_snapshot = dogmos_turf_heat_snapshot(list(neighbor.dogmos_service_slot(), neighbor.dogmos_service_generation()))
	if(neighbor_snapshot[1] != TRUE)
		return Fail("Dogmos adjacency synchronization did not re-register an atmosphere-enabled endpoint.", __FILE__, __LINE__)

/datum/unit_test/dogmos_service_turf_batching/Destroy()
	if(SSdogmos.turf_registration_batching)
		SSdogmos.finish_turf_registration_batch()
	if(target)
		target.thermal_conductivity = original_thermal_conductivity
		target.heat_capacity = original_heat_capacity
		target.register_dogmos_air()
	if(neighbor)
		neighbor.init_air = original_neighbor_init_air
		neighbor.register_dogmos_air()
	return ..()

/** Verifies startup adjacency rebuilds do not re-register current turfs. */
/datum/unit_test/dogmos_service_startup_registration_deduplication

/datum/unit_test/dogmos_service_startup_registration_deduplication/Run()
	var/turf/target = run_loc_floor_bottom_left
	var/turf/neighbor = get_step(target, EAST)
	if(!target.init_air || isnull(target.dogmos_registration_generation) || !neighbor?.init_air || isnull(neighbor.dogmos_registration_generation))
		return Fail("The Dogmos startup registration test requires two registered atmosphere turfs.", __FILE__, __LINE__)

	var/original_batching = SSdogmos.turf_registration_batching
	var/list/original_lifecycle = SSdogmos.dogmos_pending_turf_lifecycle
	var/list/original_adjacency = SSdogmos.dogmos_pending_turf_adjacency
	var/list/original_adjacency_index = SSdogmos.dogmos_pending_turf_adjacency_index
	var/list/original_heat = SSdogmos.dogmos_pending_turf_heat
	var/list/original_heat_adjacency = SSdogmos.dogmos_pending_turf_heat_adjacency
	var/list/original_heat_adjacency_index = SSdogmos.dogmos_pending_turf_heat_adjacency_index
	var/list/original_retry = SSdogmos.dogmos_pending_adjacency_retry
	SSdogmos.turf_registration_batching = TRUE
	SSdogmos.dogmos_pending_turf_lifecycle = list()
	SSdogmos.dogmos_pending_turf_adjacency = list()
	SSdogmos.dogmos_pending_turf_adjacency_index = list()
	SSdogmos.dogmos_pending_turf_heat = list()
	SSdogmos.dogmos_pending_turf_heat_adjacency = list()
	SSdogmos.dogmos_pending_turf_heat_adjacency_index = list()
	SSdogmos.dogmos_pending_adjacency_retry = list()
	var/target_key = "[target.dogmos_service_slot()]"
	var/neighbor_key = "[neighbor.dogmos_service_slot()]"
	SSdogmos.dogmos_pending_turf_lifecycle[target_key] = list("target sentinel")
	SSdogmos.dogmos_pending_turf_lifecycle[neighbor_key] = list("neighbor sentinel")

	target.sync_dogmos_adjacency()

	var/list/target_lifecycle = SSdogmos.dogmos_pending_turf_lifecycle[target_key]
	var/list/neighbor_lifecycle = SSdogmos.dogmos_pending_turf_lifecycle[neighbor_key]
	var/failure_message
	if(target_lifecycle?[1] != "target sentinel")
		failure_message = "Dogmos re-registered the current turf during startup adjacency synchronization."
	else if(neighbor_lifecycle?[1] != "neighbor sentinel")
		failure_message = "Dogmos re-registered a current neighbor during startup adjacency synchronization."
	var/original_registered_mixture_slot = target.dogmos_registered_mixture_slot
	var/original_registered_mixture_generation = target.dogmos_registered_mixture_generation
	if(!failure_message)
		target.dogmos_registered_mixture_slot = null
		target.dogmos_registered_mixture_generation = null
		SSdogmos.dogmos_pending_turf_lifecycle[target_key] = list("stale target sentinel")
		target.sync_dogmos_adjacency()
		target_lifecycle = SSdogmos.dogmos_pending_turf_lifecycle[target_key]
		if(target_lifecycle?[1] == "stale target sentinel")
			failure_message = "Dogmos did not refresh a startup turf whose gas mixture became available."
	target.dogmos_registered_mixture_slot = original_registered_mixture_slot
	target.dogmos_registered_mixture_generation = original_registered_mixture_generation

	SSdogmos.turf_registration_batching = original_batching
	SSdogmos.dogmos_pending_turf_lifecycle = original_lifecycle
	SSdogmos.dogmos_pending_turf_adjacency = original_adjacency
	SSdogmos.dogmos_pending_turf_adjacency_index = original_adjacency_index
	SSdogmos.dogmos_pending_turf_heat = original_heat
	SSdogmos.dogmos_pending_turf_heat_adjacency = original_heat_adjacency
	SSdogmos.dogmos_pending_turf_heat_adjacency_index = original_heat_adjacency_index
	SSdogmos.dogmos_pending_adjacency_retry = original_retry
	if(failure_message)
		return Fail(failure_message, __FILE__, __LINE__)

/** Verifies callback turf resolution rejects stale generations without invoking gameplay handlers. */
/datum/unit_test/dogmos_service_callback_identity

/datum/unit_test/dogmos_service_callback_identity/Run()
	var/turf/target = run_loc_floor_bottom_left
	var/original_generation = target.dogmos_registration_generation
	var/list/original_sequence = SSdogmos.dogmos_next_callback_sequence.Copy()
	var/original_stale_callbacks = SSdogmos.dogmos_stale_callback_count
	target.dogmos_registration_generation = 41
	var/slot = target.dogmos_service_slot()
	if(SSdogmos.resolve_turf(slot, 41) != target)
		target.dogmos_registration_generation = original_generation
		return Fail("Dogmos did not resolve a current turf identity.", __FILE__, __LINE__)
	if(!isnull(SSdogmos.resolve_turf(slot, 42)))
		target.dogmos_registration_generation = original_generation
		return Fail("Dogmos accepted a stale turf generation.", __FILE__, __LINE__)

	SSdogmos.dogmos_next_callback_sequence = list(1, 0, 0, 0)
	var/list/stale_callback = new/list(48)
	stale_callback[13] = 1
	stale_callback[14] = 0
	stale_callback[15] = 0
	stale_callback[16] = 0
	stale_callback[21] = 1
	stale_callback[22] = 4
	stale_callback[24] = slot % 65536
	stale_callback[25] = floor(slot / 65536)
	stale_callback[26] = 42
	SSdogmos.dispatch_general_callback(stale_callback, 13)
	if(SSdogmos.dogmos_stale_callback_count != original_stale_callbacks + 1)
		target.dogmos_registration_generation = original_generation
		SSdogmos.dogmos_next_callback_sequence = original_sequence
		return Fail("Dogmos did not count a rejected stale callback.", __FILE__, __LINE__)

	target.dogmos_registration_generation = original_generation
	SSdogmos.dogmos_next_callback_sequence = original_sequence
	SSdogmos.dogmos_stale_callback_count = original_stale_callbacks

#define DOGMOS_TEST_CALLBACK_HEADER_FIELDS 12
#define DOGMOS_TEST_CALLBACK_EVENT_FIELDS 36
#define DOGMOS_TEST_CALLBACK_EVENT_START 13
#define DOGMOS_TEST_CALLBACK_SCOPE_GENERAL 1
#define DOGMOS_TEST_CALLBACK_SCOPE_FIELD 8
#define DOGMOS_TEST_CALLBACK_KIND_FIELD 9
#define DOGMOS_TEST_CALLBACK_SUBJECT_SLOT_FIELD 11
#define DOGMOS_TEST_CALLBACK_SUBJECT_GENERATION_FIELD 13
#define DOGMOS_TEST_CALLBACK_TURF_DESTRUCTION_REQUEST 4

/** Verifies exhausted SSair budget prevents the first retained callback from dispatching. */
/datum/unit_test/dogmos_service_callback_budget

/datum/unit_test/dogmos_service_callback_budget/Run()
	var/list/original_sequence = SSdogmos.dogmos_next_callback_sequence
	var/list/original_pending_batch = SSdogmos.dogmos_pending_callback_batch
	var/original_pending_index = SSdogmos.dogmos_pending_callback_index
	var/original_pending_count = SSdogmos.dogmos_pending_callback_count
	var/original_pending_service_callbacks = SSdogmos.dogmos_pending_service_callbacks
	var/original_stale_callbacks = SSdogmos.dogmos_stale_callback_count
	var/list/test_sequence = list(1, 0, 0, 0)
	var/list/callback_batch = new/list(DOGMOS_TEST_CALLBACK_HEADER_FIELDS + DOGMOS_TEST_CALLBACK_EVENT_FIELDS)
	var/offset = DOGMOS_TEST_CALLBACK_EVENT_START
	for(var/word_index in 1 to 4)
		callback_batch[offset + word_index - 1] = test_sequence[word_index]
	callback_batch[offset + DOGMOS_TEST_CALLBACK_SCOPE_FIELD] = DOGMOS_TEST_CALLBACK_SCOPE_GENERAL
	callback_batch[offset + DOGMOS_TEST_CALLBACK_KIND_FIELD] = DOGMOS_TEST_CALLBACK_TURF_DESTRUCTION_REQUEST
	callback_batch[offset + DOGMOS_TEST_CALLBACK_SUBJECT_SLOT_FIELD] = 0
	callback_batch[offset + DOGMOS_TEST_CALLBACK_SUBJECT_SLOT_FIELD + 1] = 0
	callback_batch[offset + DOGMOS_TEST_CALLBACK_SUBJECT_GENERATION_FIELD] = 0
	callback_batch[offset + DOGMOS_TEST_CALLBACK_SUBJECT_GENERATION_FIELD + 1] = 0

	SSdogmos.dogmos_next_callback_sequence = test_sequence
	SSdogmos.dogmos_pending_callback_batch = callback_batch
	SSdogmos.dogmos_pending_callback_index = 0
	SSdogmos.dogmos_pending_callback_count = 1
	SSdogmos.dogmos_pending_service_callbacks = 0
	process_atmos_callbacks(0)

	var/failure_message
	if(SSdogmos.dogmos_pending_callback_batch != callback_batch)
		failure_message = "Dogmos discarded a retained callback batch without callback budget."
	else if(SSdogmos.dogmos_pending_callback_index != 0)
		failure_message = "Dogmos advanced the retained callback cursor without callback budget."
	else if(SSdogmos.dogmos_next_callback_sequence[1] != 1)
		failure_message = "Dogmos consumed a callback sequence without callback budget."
	else if(SSdogmos.dogmos_stale_callback_count != original_stale_callbacks)
		failure_message = "Dogmos dispatched a stale callback without callback budget."
	else
		process_atmos_callbacks(100)
		if(SSdogmos.dogmos_pending_callback_batch)
			failure_message = "Dogmos did not clear a retained callback batch after dispatch."
		else if(SSdogmos.dogmos_next_callback_sequence[1] != 2)
			failure_message = "Dogmos did not consume the retained callback in sequence."
		else if(SSdogmos.dogmos_stale_callback_count != original_stale_callbacks + 1)
			failure_message = "Dogmos did not dispatch the retained stale callback with positive budget."

	SSdogmos.dogmos_next_callback_sequence = original_sequence
	SSdogmos.dogmos_pending_callback_batch = original_pending_batch
	SSdogmos.dogmos_pending_callback_index = original_pending_index
	SSdogmos.dogmos_pending_callback_count = original_pending_count
	SSdogmos.dogmos_pending_service_callbacks = original_pending_service_callbacks
	SSdogmos.dogmos_stale_callback_count = original_stale_callbacks
	if(failure_message)
		return Fail(failure_message, __FILE__, __LINE__)

#undef DOGMOS_TEST_CALLBACK_HEADER_FIELDS
#undef DOGMOS_TEST_CALLBACK_EVENT_FIELDS
#undef DOGMOS_TEST_CALLBACK_EVENT_START
#undef DOGMOS_TEST_CALLBACK_SCOPE_GENERAL
#undef DOGMOS_TEST_CALLBACK_SCOPE_FIELD
#undef DOGMOS_TEST_CALLBACK_KIND_FIELD
#undef DOGMOS_TEST_CALLBACK_SUBJECT_SLOT_FIELD
#undef DOGMOS_TEST_CALLBACK_SUBJECT_GENERATION_FIELD
#undef DOGMOS_TEST_CALLBACK_TURF_DESTRUCTION_REQUEST

#define DOGMOS_TEST_REACTION_EVENT_OFFSET 13
#define DOGMOS_TEST_REACTION_SUBJECT_SLOT_FIELD 11
#define DOGMOS_TEST_REACTION_SUBJECT_GENERATION_FIELD 13
#define DOGMOS_TEST_CALLBACK_REACTION_FINISHED 2

/** Verifies general reaction callbacks reject stale mixture generations at the identity boundary. */
/datum/unit_test/dogmos_service_general_reaction_subject

/datum/unit_test/dogmos_service_general_reaction_subject/Run()
	var/datum/gas_mixture/mixture = new(CELL_VOLUME)
	var/list/callback = new/list(48)
	callback[DOGMOS_TEST_REACTION_EVENT_OFFSET + DOGMOS_TEST_REACTION_SUBJECT_SLOT_FIELD] = mixture.dogmos_slot % 65536
	callback[DOGMOS_TEST_REACTION_EVENT_OFFSET + DOGMOS_TEST_REACTION_SUBJECT_SLOT_FIELD + 1] = floor(mixture.dogmos_slot / 65536)
	callback[DOGMOS_TEST_REACTION_EVENT_OFFSET + DOGMOS_TEST_REACTION_SUBJECT_GENERATION_FIELD] = mixture.dogmos_generation % 65536
	callback[DOGMOS_TEST_REACTION_EVENT_OFFSET + DOGMOS_TEST_REACTION_SUBJECT_GENERATION_FIELD + 1] = floor(mixture.dogmos_generation / 65536)
	var/list/live_subject = SSdogmos.decode_general_reaction_subject(callback, DOGMOS_TEST_REACTION_EVENT_OFFSET)
	var/failure_message
	if(live_subject[1] != mixture)
		failure_message = "Dogmos rejected a live general-reaction mixture identity."
	callback[DOGMOS_TEST_REACTION_EVENT_OFFSET + DOGMOS_TEST_REACTION_SUBJECT_GENERATION_FIELD]++
	var/list/stale_subject = SSdogmos.decode_general_reaction_subject(callback, DOGMOS_TEST_REACTION_EVENT_OFFSET)
	if(!failure_message && stale_subject[1])
		failure_message = "Dogmos accepted a stale general-reaction mixture generation."
	var/original_stale_callbacks = SSdogmos.dogmos_stale_callback_count
	var/stale_dispatch_result = SSdogmos.dispatch_general_reaction_callback(callback, DOGMOS_TEST_REACTION_EVENT_OFFSET, DOGMOS_TEST_CALLBACK_REACTION_FINISHED)
	if(!failure_message && (!isnum(stale_dispatch_result) || stale_dispatch_result != FALSE))
		failure_message = "Dogmos did not explicitly discard a stale finished-reaction callback."
	if(!failure_message && SSdogmos.dogmos_stale_callback_count != original_stale_callbacks + 1)
		failure_message = "Dogmos did not count a discarded stale finished-reaction callback."
	SSdogmos.dogmos_stale_callback_count = original_stale_callbacks
	qdel(mixture)
	if(failure_message)
		return Fail(failure_message, __FILE__, __LINE__)

#undef DOGMOS_TEST_REACTION_EVENT_OFFSET
#undef DOGMOS_TEST_REACTION_SUBJECT_SLOT_FIELD
#undef DOGMOS_TEST_REACTION_SUBJECT_GENERATION_FIELD
#undef DOGMOS_TEST_CALLBACK_REACTION_FINISHED

/** Verifies runtime topology remains deferred for the full committed-frontier cycle. */
/datum/unit_test/dogmos_service_topology_stage_barrier

/datum/unit_test/dogmos_service_topology_stage_barrier/Run()
	var/list/original_pending_frontier = SSair.dogmos_pending_frontier_epoch
	var/deferrals_before = SSdogmos.dogmos_runtime_topology_deferrals
	SSair.dogmos_pending_frontier_epoch = list(1, 0, 0, 0)
	var/flushed = SSdogmos.flush_turf_registration_batch()
	var/deferrals_after = SSdogmos.dogmos_runtime_topology_deferrals
	SSair.dogmos_pending_frontier_epoch = original_pending_frontier
	SSdogmos.dogmos_runtime_topology_deferrals = deferrals_before
	if(flushed)
		return Fail("Dogmos flushed runtime topology while a committed frontier remained pending.", __FILE__, __LINE__)
	if(deferrals_after != deferrals_before + 1)
		return Fail("Dogmos did not count a committed-frontier topology deferral.", __FILE__, __LINE__)

/** Verifies an exhausted MC budget returns control without sleeping inside SSair. */
/datum/unit_test/dogmos_service_stage_budget_progress

/datum/unit_test/dogmos_service_stage_budget_progress/Run()
	var/original_work_limit = SSair.dogmos_stage_work_limit
	SSair.dogmos_stage_work_limit = 128
	var/zero_budget_limit = SSair.dogmos_work_limit_for_budget(0)
	var/overrun_budget_limit = SSair.dogmos_work_limit_for_budget(-1)
	SSair.dogmos_stage_work_limit = original_work_limit
	var/defer_start = world.time
	var/deferred = SSair.dogmos_defer_stage_for_budget()

	if(zero_budget_limit)
		return Fail("Dogmos scheduled service work despite an exhausted MC budget.", __FILE__, __LINE__)
	if(overrun_budget_limit)
		return Fail("Dogmos scheduled service work after an MC overrun.", __FILE__, __LINE__)
	if(!deferred)
		return Fail("Dogmos did not report an exhausted stage as deferred.", __FILE__, __LINE__)
	if(world.time != defer_start)
		return Fail("Dogmos slept inside SSair while deferring an exhausted stage.", __FILE__, __LINE__)

/** Verifies one Dogmos turf-processing call performs the configured bounded FDM passes. */
/datum/unit_test/dogmos_service_fdm_multi_pass

/datum/unit_test/dogmos_service_fdm_multi_pass/Run()
	if(!isnull(SSair.dogmos_pending_stage))
		return Fail("Dogmos began the FDM multi-pass test with a service stage already pending.", __FILE__, __LINE__)
	var/original_share_max_steps = SSair.share_max_steps
	var/original_fdm_steps_completed = SSair.dogmos_fdm_steps_completed
	SSair.share_max_steps = 4
	SSair.dogmos_fdm_steps_completed = 0
	var/pending = TRUE
	var/chunks = 0
	while(pending && chunks < 20)
		pending = SSair.process_turfs_auxtools(100)
		chunks++
	var/completed_steps = SSair.dogmos_fdm_steps_completed

	for(var/stage in list(DOGMOS_TEST_STAGE_REACTIONS, DOGMOS_TEST_STAGE_EXCITED_GROUPS, DOGMOS_TEST_STAGE_EQUALIZE, DOGMOS_TEST_STAGE_TURF_HEAT))
		var/stage_pending = TRUE
		var/stage_chunks = 0
		while(stage_pending && stage_chunks < 20)
			stage_pending = SSair.dogmos_run_stage(stage, 100)
			stage_chunks++
		if(stage_pending)
			pending = TRUE
	SSair.dogmos_pending_frontier_epoch = null

	SSair.share_max_steps = original_share_max_steps
	SSair.dogmos_fdm_steps_completed = original_fdm_steps_completed

	if(pending)
		return Fail("Dogmos did not complete the bounded FDM test cycle within its chunk limit.", __FILE__, __LINE__)
	if(completed_steps != 4)
		return Fail("Dogmos completed [completed_steps] FDM passes instead of the configured four.", __FILE__, __LINE__)

/** Verifies malformed stage responses are rejected before SSair reads their fields. */
/datum/unit_test/dogmos_service_stage_response_failure

/datum/unit_test/dogmos_service_stage_response_failure/Run()
	var/list/valid_response = new/list(DOGMOS_TEST_STAGE_RESPONSE_FIELDS)
	for(var/field_index in 1 to DOGMOS_TEST_STAGE_RESPONSE_FIELDS)
		valid_response[field_index] = 0
	var/list/short_response = valid_response.Copy()
	short_response.Cut(length(short_response), length(short_response) + 1)
	var/list/non_numeric_response = valid_response.Copy()
	non_numeric_response[1] = "invalid"

	if(SSair.dogmos_stage_response_is_valid(DOGMOS_TEST_STAGE_EQUALIZE, null))
		return Fail("Dogmos accepted a null stage response.", __FILE__, __LINE__)
	if(SSair.dogmos_stage_response_is_valid(DOGMOS_TEST_STAGE_EQUALIZE, 1))
		return Fail("Dogmos accepted a scalar stage response.", __FILE__, __LINE__)
	if(SSair.dogmos_stage_response_is_valid(DOGMOS_TEST_STAGE_EQUALIZE, short_response))
		return Fail("Dogmos accepted a short stage response.", __FILE__, __LINE__)
	if(SSair.dogmos_stage_response_is_valid(DOGMOS_TEST_STAGE_EQUALIZE, non_numeric_response))
		return Fail("Dogmos accepted a non-numeric stage response.", __FILE__, __LINE__)
	if(!SSair.dogmos_stage_response_is_valid(DOGMOS_TEST_STAGE_EQUALIZE, valid_response))
		return Fail("Dogmos rejected a fixed-width numeric stage response.", __FILE__, __LINE__)

	var/original_pending_stage = SSair.dogmos_pending_stage
	var/list/original_pending_frontier = SSair.dogmos_pending_frontier_epoch
	var/original_remaining_estimate = SSair.dogmos_stage_remaining_estimate
	var/original_active_stages_complete = SSair.dogmos_active_turf_stages_complete
	var/original_fdm_steps_completed = SSair.dogmos_fdm_steps_completed
	var/original_can_fire = SSair.can_fire
	var/original_service_ready = SSdogmos.service_ready
	SSair.dogmos_pending_stage = DOGMOS_TEST_STAGE_REACTIONS
	SSair.dogmos_pending_frontier_epoch = list(1, 0, 0, 0)
	SSair.dogmos_stage_remaining_estimate = 77
	SSair.dogmos_active_turf_stages_complete = TRUE
	SSair.dogmos_fdm_steps_completed = 3
	var/failure_pending = SSair.dogmos_fail_closed_stage(DOGMOS_TEST_STAGE_REACTIONS, FALSE)
	var/failure_message
	if(!failure_pending)
		failure_message = "Dogmos did not pause SSair after an irrecoverable stage response."
	else if(!isnull(SSair.dogmos_pending_stage) || !isnull(SSair.dogmos_pending_frontier_epoch))
		failure_message = "Dogmos retained failed stage state for another retry."
	else if(SSair.dogmos_stage_remaining_estimate || SSair.dogmos_active_turf_stages_complete || SSair.dogmos_fdm_steps_completed)
		failure_message = "Dogmos retained failed-cycle progress after the stage failure."
	else if(SSair.can_fire || SSdogmos.service_ready)
		failure_message = "Dogmos did not fail closed after the stage failure."

	SSair.dogmos_pending_stage = original_pending_stage
	SSair.dogmos_pending_frontier_epoch = original_pending_frontier
	SSair.dogmos_stage_remaining_estimate = original_remaining_estimate
	SSair.dogmos_active_turf_stages_complete = original_active_stages_complete
	SSair.dogmos_fdm_steps_completed = original_fdm_steps_completed
	SSair.can_fire = original_can_fire
	SSdogmos.service_ready = original_service_ready
	if(failure_message)
		return Fail(failure_message, __FILE__, __LINE__)

/** Verifies a resumed SSair stage does not repeat the cycle health preflight. */
/datum/unit_test/dogmos_service_resumed_health_preflight

/datum/unit_test/dogmos_service_resumed_health_preflight/Run()
	if(SSair.dogmos_health_preflight_required(TRUE))
		return Fail("A resumed SSair stage repeated the Dogmos cycle health preflight.", __FILE__, __LINE__)
	if(!SSair.dogmos_health_preflight_required(FALSE))
		return Fail("A new SSair cycle skipped the Dogmos health preflight.", __FILE__, __LINE__)

/** Verifies SSair completes a real Runtime Station or MetaStation cycle after startup. */
/datum/unit_test/dogmos_service_idle_cycle_progress

/datum/unit_test/dogmos_service_idle_cycle_progress/Run()
	var/initial_fire_count = SSair.times_fired
	var/deadline = world.time + 30 SECONDS
	while(SSair.times_fired <= initial_fire_count && world.time < deadline)
		sleep(1 SECONDS)
	if(SSair.times_fired <= initial_fire_count)
		return Fail("Dogmos did not allow SSair to complete an idle cycle within 30 seconds.", __FILE__, __LINE__)

/** Verifies repeated deferred adjacency updates coalesce and drain completely. */
/datum/unit_test/dogmos_service_topology_pressure

/datum/unit_test/dogmos_service_topology_pressure/Run()
	var/list/original_pending_frontier = SSair.dogmos_pending_frontier_epoch
	var/original_runtime_batching = SSdogmos.runtime_topology_batching
	var/list/original_gas_edges = SSdogmos.dogmos_pending_turf_adjacency
	var/list/original_gas_index = SSdogmos.dogmos_pending_turf_adjacency_index
	var/list/original_heat_edges = SSdogmos.dogmos_pending_turf_heat_adjacency
	var/list/original_heat_index = SSdogmos.dogmos_pending_turf_heat_adjacency_index
	var/original_max_queued = SSdogmos.dogmos_runtime_topology_max_queued
	var/turf/target = run_loc_floor_bottom_left

	SSdogmos.runtime_topology_batching = TRUE
	SSdogmos.dogmos_pending_turf_adjacency = list()
	SSdogmos.dogmos_pending_turf_adjacency_index = list()
	SSdogmos.dogmos_pending_turf_heat_adjacency = list()
	SSdogmos.dogmos_pending_turf_heat_adjacency_index = list()
	SSdogmos.dogmos_runtime_topology_max_queued = 0
	SSair.dogmos_pending_frontier_epoch = list(1, 0, 0, 0)
	target.__update_auxtools_turf_adjacency_info(world.maxx, world.maxy)
	var/first_gas_count = length(SSdogmos.dogmos_pending_turf_adjacency)
	var/first_heat_count = length(SSdogmos.dogmos_pending_turf_heat_adjacency)
	for(var/repetition in 1 to 20)
		target.__update_auxtools_turf_adjacency_info(world.maxx, world.maxy)

	var/failure_message
	if(length(SSdogmos.dogmos_pending_turf_adjacency) != first_gas_count)
		failure_message = "Deferred gas adjacency work grew with repeated updates instead of coalescing."
	else if(length(SSdogmos.dogmos_pending_turf_heat_adjacency) != first_heat_count)
		failure_message = "Deferred heat adjacency work grew with repeated updates instead of coalescing."
	else if(SSdogmos.dogmos_runtime_topology_max_queued != first_gas_count + first_heat_count)
		failure_message = "Dogmos topology pressure telemetry did not retain the unique queued edge count."

	SSair.dogmos_pending_frontier_epoch = null
	if(!SSdogmos.flush_turf_registration_batch() && !failure_message)
		failure_message = "Dogmos did not flush deferred topology after the committed frontier cleared."
	if((length(SSdogmos.dogmos_pending_turf_adjacency) || length(SSdogmos.dogmos_pending_turf_heat_adjacency) \
			|| length(SSdogmos.dogmos_pending_turf_adjacency_index) || length(SSdogmos.dogmos_pending_turf_heat_adjacency_index)) && !failure_message)
		failure_message = "Dogmos retained topology queue or reverse-index entries after a successful flush."

	SSair.dogmos_pending_frontier_epoch = original_pending_frontier
	SSdogmos.runtime_topology_batching = original_runtime_batching
	SSdogmos.dogmos_pending_turf_adjacency = original_gas_edges
	SSdogmos.dogmos_pending_turf_adjacency_index = original_gas_index
	SSdogmos.dogmos_pending_turf_heat_adjacency = original_heat_edges
	SSdogmos.dogmos_pending_turf_heat_adjacency_index = original_heat_index
	SSdogmos.dogmos_runtime_topology_max_queued = original_max_queued
	if(failure_message)
		return Fail(failure_message, __FILE__, __LINE__)

/** Verifies turf replacement discards queued topology from an older generation. */
/datum/unit_test/dogmos_service_stale_topology_discard

/datum/unit_test/dogmos_service_stale_topology_discard/Run()
	var/list/original_gas_edges = SSdogmos.dogmos_pending_turf_adjacency
	var/list/original_gas_index = SSdogmos.dogmos_pending_turf_adjacency_index
	var/list/original_heat_edges = SSdogmos.dogmos_pending_turf_heat_adjacency
	var/list/original_heat_index = SSdogmos.dogmos_pending_turf_heat_adjacency_index
	var/turf/target = run_loc_floor_bottom_left
	var/target_slot = target.dogmos_service_slot()
	var/stale_generation = target.dogmos_service_generation() + 1
	var/neighbor_slot = target_slot + 1
	var/edge_key = "[target_slot]:[stale_generation]:[neighbor_slot]:1"

	SSdogmos.dogmos_pending_turf_adjacency = list()
	SSdogmos.dogmos_pending_turf_adjacency[edge_key] = list(target_slot, stale_generation, neighbor_slot, 1, TRUE, FALSE)
	SSdogmos.dogmos_pending_turf_adjacency_index = list()
	SSdogmos.index_pending_edge(SSdogmos.dogmos_pending_turf_adjacency_index, "[target_slot]", edge_key)
	SSdogmos.index_pending_edge(SSdogmos.dogmos_pending_turf_adjacency_index, "[neighbor_slot]", edge_key)
	SSdogmos.dogmos_pending_turf_heat_adjacency = list()
	SSdogmos.dogmos_pending_turf_heat_adjacency[edge_key] = list(target_slot, stale_generation, neighbor_slot, 1, TRUE)
	SSdogmos.dogmos_pending_turf_heat_adjacency_index = list()
	SSdogmos.index_pending_edge(SSdogmos.dogmos_pending_turf_heat_adjacency_index, "[target_slot]", edge_key)
	SSdogmos.index_pending_edge(SSdogmos.dogmos_pending_turf_heat_adjacency_index, "[neighbor_slot]", edge_key)

	SSdogmos.discard_pending_turf_adjacencies(target)
	var/failure_message
	if(length(SSdogmos.dogmos_pending_turf_adjacency) || length(SSdogmos.dogmos_pending_turf_adjacency_index))
		failure_message = "Dogmos retained stale gas topology after a turf generation changed."
	else if(length(SSdogmos.dogmos_pending_turf_heat_adjacency) || length(SSdogmos.dogmos_pending_turf_heat_adjacency_index))
		failure_message = "Dogmos retained stale heat topology after a turf generation changed."

	SSdogmos.dogmos_pending_turf_adjacency = original_gas_edges
	SSdogmos.dogmos_pending_turf_adjacency_index = original_gas_index
	SSdogmos.dogmos_pending_turf_heat_adjacency = original_heat_edges
	SSdogmos.dogmos_pending_turf_heat_adjacency_index = original_heat_index
	if(failure_message)
		return Fail(failure_message, __FILE__, __LINE__)

#undef DOGMOS_WORLD_GENERATION_WORD_MAX
#undef DOGMOS_TEST_STAGE_EXCITED_GROUPS
#undef DOGMOS_TEST_STAGE_EQUALIZE
#undef DOGMOS_TEST_STAGE_TURF_HEAT
#undef DOGMOS_TEST_STAGE_REACTIONS
#undef DOGMOS_TEST_STAGE_RESPONSE_FIELDS
#undef DOGMOS_PIPELINE_TEST_EPSILON

#endif
