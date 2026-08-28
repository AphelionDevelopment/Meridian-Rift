#if defined(UNIT_TESTS) || defined(SPACEMAN_DMM)

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
	qdel(first)

	var/datum/gas_mixture/second = new(CELL_VOLUME)
	if(second.dogmos_slot != first_slot)
		return Fail("Dogmos did not reuse the released bounded mixture slot.", __FILE__, __LINE__)
	if(second.dogmos_generation <= first_generation)
		return Fail("Dogmos reused a mixture slot without advancing its generation.", __FILE__, __LINE__)
	qdel(second)

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
	var/list/stale_callback = new/list(43)
	stale_callback[13] = 1
	stale_callback[17] = 4
	stale_callback[19] = slot % 65536
	stale_callback[20] = floor(slot / 65536)
	stale_callback[21] = 42
	SSdogmos.dispatch_general_callback(stale_callback, 13)
	if(SSdogmos.dogmos_stale_callback_count != original_stale_callbacks + 1)
		target.dogmos_registration_generation = original_generation
		SSdogmos.dogmos_next_callback_sequence = original_sequence
		return Fail("Dogmos did not count a rejected stale callback.", __FILE__, __LINE__)

	target.dogmos_registration_generation = original_generation
	SSdogmos.dogmos_next_callback_sequence = original_sequence
	SSdogmos.dogmos_stale_callback_count = original_stale_callbacks

#endif
