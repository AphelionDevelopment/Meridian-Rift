#if defined(UNIT_TESTS) || defined(SPACEMAN_DMM)

#define DOGMOS_WORLD_GENERATION_WORD_MAX 65535

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
	first.__gasmixture_unregister()
	qdel(first)

	var/datum/gas_mixture/second = new(CELL_VOLUME)
	if(second.dogmos_slot != first_slot)
		return Fail("Dogmos did not reuse the released bounded mixture slot.", __FILE__, __LINE__)
	if(second.dogmos_generation <= first_generation)
		return Fail("Dogmos reused a mixture slot without advancing its generation.", __FILE__, __LINE__)
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

/datum/unit_test/dogmos_service_mixture_snapshot_cache/Destroy()
	QDEL_NULL(first)
	QDEL_NULL(second)
	SSdogmos.reset_mixture_snapshot_cache()
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

#undef DOGMOS_WORLD_GENERATION_WORD_MAX

#endif
