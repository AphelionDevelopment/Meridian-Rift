#define DOGMOS_REQUIRED_PROTOCOL_VERSION 6
#define DOGMOS_MAX_EXACT_INTEGER 16777216
#define DOGMOS_CALLBACK_BATCH_SIZE 256
#define DOGMOS_CALLBACK_HEADER_FIELDS 12
#define DOGMOS_CALLBACK_EVENT_FIELDS 31
#define DOGMOS_CALLBACK_EVENT_START 13
#define DOGMOS_TURF_BATCH_OPERATIONS 512
#define DOGMOS_TURF_LIFECYCLE_FIELDS 6
#define DOGMOS_TURF_ADJACENCY_FIELDS 6
#define DOGMOS_TURF_HEAT_FIELDS 7
#define DOGMOS_TURF_HEAT_ADJACENCY_FIELDS 5

#define DOGMOS_LIFECYCLE_REGISTER 1
#define DOGMOS_LIFECYCLE_UNREGISTER 2

#define DOGMOS_RESPONSE_APPLIED 1
#define DOGMOS_RESPONSE_SCALAR 2
#define DOGMOS_RESPONSE_SCALARS 3
#define DOGMOS_RESPONSE_BOOLEAN 4
#define DOGMOS_RESPONSE_REACTION_PROGRESS 5

#define DOGMOS_COMMAND_SET_MOLES 1
#define DOGMOS_COMMAND_ADJUST_MOLES 2
#define DOGMOS_COMMAND_ADJUST_MOLES_TEMPERATURE 3
#define DOGMOS_COMMAND_GET_MOLES 4
#define DOGMOS_COMMAND_TEMPERATURE 5
#define DOGMOS_COMMAND_VOLUME 6
#define DOGMOS_COMMAND_HEAT_CAPACITY 7
#define DOGMOS_COMMAND_PARTIAL_HEAT_CAPACITY 8
#define DOGMOS_COMMAND_TOTAL_MOLES 9
#define DOGMOS_COMMAND_PRESSURE 10
#define DOGMOS_COMMAND_THERMAL_ENERGY 11
#define DOGMOS_COMMAND_GET_MOLES_BY_FLAGS 12
#define DOGMOS_COMMAND_BURNABILITY 13
#define DOGMOS_COMMAND_SET_TEMPERATURE 14
#define DOGMOS_COMMAND_SET_VOLUME 15
#define DOGMOS_COMMAND_SET_MINIMUM_HEAT_CAPACITY 16
#define DOGMOS_COMMAND_CLEAR 17
#define DOGMOS_COMMAND_ADD 18
#define DOGMOS_COMMAND_MULTIPLY 19
#define DOGMOS_COMMAND_COPY_FROM 20
#define DOGMOS_COMMAND_ADJUST_HEAT 21
#define DOGMOS_COMMAND_COMPARE 22
#define DOGMOS_COMMAND_EQUALIZE_WITH 23
#define DOGMOS_COMMAND_TEMPERATURE_SHARE 24
#define DOGMOS_COMMAND_TEMPERATURE_SHARE_NON_GAS 25
#define DOGMOS_COMMAND_MARK_IMMUTABLE 26
#define DOGMOS_COMMAND_IS_IMMUTABLE 27
#define DOGMOS_COMMAND_MERGE 28
#define DOGMOS_COMMAND_REMOVE_RATIO_INTO 29
#define DOGMOS_COMMAND_REMOVE_AMOUNT_INTO 30
#define DOGMOS_COMMAND_TRANSFER_GASES 31
#define DOGMOS_COMMAND_TRANSFER_AMOUNT 32
#define DOGMOS_COMMAND_TRANSFER_RATIO 33
#define DOGMOS_COMMAND_TRANSFER_BY_FLAGS 34
#define DOGMOS_COMMAND_SHARE_RATIO 35
#define DOGMOS_COMMAND_REACT 36

#define DOGMOS_CALLBACK_REACTION_FINISHED 2
#define DOGMOS_CALLBACK_PRESSURE_DIFFERENCE 3
#define DOGMOS_CALLBACK_DECOMPRESSION_FLOOR_RIP 4
#define DOGMOS_CALLBACK_FIRELOCK_CONSIDERATION 5
#define DOGMOS_CALLBACK_TURF_DESTRUCTION_REQUEST 6
#define DOGMOS_CALLBACK_RUN_DM_REACTION 7

#define DOGMOS_TURF_DESTRUCTION_SUPERCONDUCTIVE_HEAT 1

#define DOGMOS_REACTION_PLASMA 1
#define DOGMOS_REACTION_HYDROGEN 2
#define DOGMOS_REACTION_TRITIUM 3
#define DOGMOS_REACTION_FREON 4

#define DOGMOS_SIMULATION_EXCITED_GROUPS 1
#define DOGMOS_SIMULATION_TURF_EQUALIZE 2
#define DOGMOS_SIMULATION_TURF_HEAT 3
#define DOGMOS_SIMULATION_TURFS 4

/** Service-owned Dogmos state retained by Dream Maker only for identity translation. */
/datum/controller/subsystem/dogmos
	/// Whether the production service passed identity and health checks.
	var/service_ready = FALSE
	/// Weak mixture references indexed by bounded IPC slot.
	var/list/dogmos_mixture_slots = list()
	/// Current generation for every allocated mixture slot.
	var/list/dogmos_mixture_generations = list()
	/// Reusable mixture slots released by lifecycle unregister.
	var/list/dogmos_free_mixture_slots = list()
	/// Dense numeric gas id keyed by DM gas path and native string id.
	var/list/dogmos_gas_ids = list()
	/// Gas paths indexed by numeric gas id plus one.
	var/list/dogmos_gas_paths = list()
	/// Reaction datums indexed by numeric reaction id plus one.
	var/list/dogmos_reaction_ids = list()
	/// Weak arbitrary-holder references indexed by bounded IPC slot.
	var/list/dogmos_holder_slots = list()
	/// Current generation for every arbitrary-holder slot.
	var/list/dogmos_holder_generations = list()
	/// Reusable arbitrary-holder slots.
	var/list/dogmos_free_holder_slots = list()
	/// Next expected callback sequence as four exact little-endian 16-bit words.
	var/list/dogmos_next_callback_sequence = list(1, 0, 0, 0)
	/// Callback batch retained across SSair fires when the current time budget expires.
	var/list/dogmos_pending_callback_batch
	/// Zero-based event index within the retained callback batch.
	var/dogmos_pending_callback_index = 0
	/// Number of callbacks still queued in dogmosd after the retained batch.
	var/dogmos_pending_service_callbacks = 0
	/// Number of stale turf callbacks rejected before invoking a gameplay proc.
	var/dogmos_stale_callback_count = 0
	/// Whether startup turf mutations are accumulating in bounded IPC batches.
	var/turf_registration_batching = FALSE
	/// Pending fixed-width turf lifecycle records keyed by turf slot.
	var/list/dogmos_pending_turf_lifecycle = list()
	/// Pending fixed-width turf adjacency records keyed by canonical slot pair.
	var/list/dogmos_pending_turf_adjacency = list()
	/// Pending fixed-width turf heat records keyed by turf slot.
	var/list/dogmos_pending_turf_heat = list()
	/// Pending fixed-width turf heat-adjacency records keyed by canonical slot pair.
	var/list/dogmos_pending_turf_heat_adjacency = list()

/** Starts bounded accumulation of startup turf mutations. */
/datum/controller/subsystem/dogmos/proc/begin_turf_registration_batch()
	if(turf_registration_batching)
		CRASH("Attempted to nest Dogmos turf registration batches.")
	turf_registration_batching = TRUE
	dogmos_pending_turf_lifecycle.Cut()
	dogmos_pending_turf_adjacency.Cut()
	dogmos_pending_turf_heat.Cut()
	dogmos_pending_turf_heat_adjacency.Cut()

/** Flushes pending startup turf mutations while preserving registration-before-topology ordering. */
/datum/controller/subsystem/dogmos/proc/flush_turf_registration_batch()
	if(length(dogmos_pending_turf_lifecycle))
		var/list/lifecycle_batch = list()
		for(var/turf_slot in dogmos_pending_turf_lifecycle)
			lifecycle_batch += dogmos_pending_turf_lifecycle[turf_slot]
		var/lifecycle_count = length(lifecycle_batch) / DOGMOS_TURF_LIFECYCLE_FIELDS
		if(dogmos_turf_lifecycle_batch(lifecycle_batch) != lifecycle_count)
			CRASH("dogmosd rejected a startup turf lifecycle batch.")
		dogmos_pending_turf_lifecycle.Cut()
	if(length(dogmos_pending_turf_heat))
		var/list/heat_batch = list()
		for(var/heat_turf_slot in dogmos_pending_turf_heat)
			heat_batch += dogmos_pending_turf_heat[heat_turf_slot]
		var/heat_count = length(heat_batch) / DOGMOS_TURF_HEAT_FIELDS
		if(dogmos_turf_heat_batch(heat_batch) != heat_count)
			CRASH("dogmosd rejected a startup turf heat batch.")
		dogmos_pending_turf_heat.Cut()
	if(length(dogmos_pending_turf_adjacency))
		var/list/adjacency_batch = list()
		for(var/edge_key in dogmos_pending_turf_adjacency)
			adjacency_batch += dogmos_pending_turf_adjacency[edge_key]
		var/adjacency_count = length(adjacency_batch) / DOGMOS_TURF_ADJACENCY_FIELDS
		if(dogmos_turf_adjacency_batch(adjacency_batch) != adjacency_count)
			CRASH("dogmosd rejected a startup turf adjacency batch.")
		dogmos_pending_turf_adjacency.Cut()
	if(length(dogmos_pending_turf_heat_adjacency))
		var/list/heat_adjacency_batch = list()
		for(var/heat_edge_key in dogmos_pending_turf_heat_adjacency)
			heat_adjacency_batch += dogmos_pending_turf_heat_adjacency[heat_edge_key]
		var/heat_adjacency_count = length(heat_adjacency_batch) / DOGMOS_TURF_HEAT_ADJACENCY_FIELDS
		if(dogmos_turf_heat_adjacency_batch(heat_adjacency_batch) != heat_adjacency_count)
			CRASH("dogmosd rejected a startup turf heat-adjacency batch.")
		dogmos_pending_turf_heat_adjacency.Cut()

/** Flushes a full startup turf batch before any wire payload can exceed its bound. */
/datum/controller/subsystem/dogmos/proc/flush_full_turf_registration_batch()
	if(length(dogmos_pending_turf_lifecycle) >= DOGMOS_TURF_BATCH_OPERATIONS \
		|| length(dogmos_pending_turf_adjacency) >= DOGMOS_TURF_BATCH_OPERATIONS \
		|| length(dogmos_pending_turf_heat) >= DOGMOS_TURF_BATCH_OPERATIONS \
		|| length(dogmos_pending_turf_heat_adjacency) >= DOGMOS_TURF_BATCH_OPERATIONS)
		flush_turf_registration_batch()

/** Removes pending topology that predates a turf's latest registration state. */
/datum/controller/subsystem/dogmos/proc/discard_pending_turf_adjacencies(turf/target)
	var/slot = target.dogmos_service_slot()
	for(var/direction in GLOB.cardinals)
		var/turf/neighbor = get_step(target, direction)
		if(!neighbor)
			continue
		var/neighbor_slot = neighbor.dogmos_service_slot()
		var/edge_key = "[min(slot, neighbor_slot)]:[max(slot, neighbor_slot)]"
		dogmos_pending_turf_adjacency.Remove(edge_key)
		dogmos_pending_turf_heat_adjacency.Remove(edge_key)

/** Flushes and closes startup turf mutation accumulation. */
/datum/controller/subsystem/dogmos/proc/finish_turf_registration_batch()
	if(!turf_registration_batching)
		CRASH("Attempted to finish an inactive Dogmos turf registration batch.")
	flush_turf_registration_batch()
	turf_registration_batching = FALSE

/** Registers one gas mixture with a stale-handle-safe numeric identity. */
/datum/controller/subsystem/dogmos/proc/register_mixture(datum/gas_mixture/mixture)
	if(!service_ready)
		CRASH("Attempted to register a gas mixture while dogmosd is unavailable.")

	var/slot
	if(length(dogmos_free_mixture_slots))
		slot = pop(dogmos_free_mixture_slots)
		dogmos_mixture_generations[slot]++
	else
		slot = length(dogmos_mixture_slots) + 1
		if(slot > DOGMOS_MAX_EXACT_INTEGER)
			CRASH("Dogmos mixture identity capacity exhausted.")
		dogmos_mixture_generations += 1
		dogmos_mixture_slots.len = slot

	var/generation = dogmos_mixture_generations[slot]
	if(generation > DOGMOS_MAX_EXACT_INTEGER)
		CRASH("Dogmos mixture generation exhausted for slot [slot].")

	if(dogmos_mixture_lifecycle_batch(list(DOGMOS_LIFECYCLE_REGISTER, slot, generation)) != 1)
		CRASH("dogmosd rejected mixture registration for [slot]:[generation].")

	dogmos_mixture_slots[slot] = WEAKREF(mixture)
	mixture.dogmos_slot = slot
	mixture.dogmos_generation = generation
	mixture._extools_pointer_gasmixture = TRUE

/** Unregisters one gas mixture and makes its slot eligible for generational reuse. */
/datum/controller/subsystem/dogmos/proc/unregister_mixture(datum/gas_mixture/mixture)
	var/slot = mixture.dogmos_slot
	var/generation = mixture.dogmos_generation
	if(!slot || dogmos_mixture_slots[slot]?.resolve() != mixture || dogmos_mixture_generations[slot] != generation)
		CRASH("Attempted to unregister stale Dogmos mixture identity [slot]:[generation].")

	if(service_ready && dogmos_mixture_lifecycle_batch(list(DOGMOS_LIFECYCLE_UNREGISTER, slot, generation)) != 1)
		CRASH("dogmosd rejected mixture unregistration for [slot]:[generation].")

	dogmos_mixture_slots[slot] = null
	dogmos_free_mixture_slots += slot
	mixture.dogmos_slot = null
	mixture.dogmos_generation = null
	mixture._extools_pointer_gasmixture = null

/** Resolves a mixture identity without accepting stale generations. */
/datum/controller/subsystem/dogmos/proc/resolve_mixture(slot, generation)
	if(!slot || dogmos_mixture_generations[slot] != generation)
		return null
	var/datum/weakref/reference = dogmos_mixture_slots[slot]
	return reference?.resolve()

/** Allocates a bounded ephemeral identity for an arbitrary reaction holder. */
/datum/controller/subsystem/dogmos/proc/register_holder(datum/holder)
	if(isnull(holder))
		return list(0, 0)

	var/slot
	if(length(dogmos_free_holder_slots))
		slot = pop(dogmos_free_holder_slots)
		dogmos_holder_generations[slot]++
	else
		slot = length(dogmos_holder_slots) + 1
		if(slot > DOGMOS_MAX_EXACT_INTEGER)
			CRASH("Dogmos holder identity capacity exhausted.")
		dogmos_holder_generations += 1
		dogmos_holder_slots.len = slot

	var/generation = dogmos_holder_generations[slot]
	if(generation > DOGMOS_MAX_EXACT_INTEGER)
		CRASH("Dogmos holder generation exhausted for slot [slot].")
	dogmos_holder_slots[slot] = WEAKREF(holder)
	return list(slot, generation)

/** Releases an ephemeral holder identity after its synchronous reaction completes. */
/datum/controller/subsystem/dogmos/proc/unregister_holder(list/handle)
	var/slot = handle[1]
	if(!slot)
		return
	dogmos_holder_slots[slot] = null
	dogmos_free_holder_slots += slot

/** Resolves an arbitrary holder identity without accepting stale generations. */
/datum/controller/subsystem/dogmos/proc/resolve_holder(slot, generation)
	if(!slot)
		return null
	if(dogmos_holder_generations[slot] != generation)
		return null
	var/datum/weakref/reference = dogmos_holder_slots[slot]
	return reference?.resolve()

/** Converts the shim's exact 16-bit word pair back into a 32-bit identity field. */
/datum/controller/subsystem/dogmos/proc/join_u32_words(low_word, high_word)
	return low_word + high_word * 65536

/** Resolves a coordinate-derived turf identity without accepting a stale generation. */
/datum/controller/subsystem/dogmos/proc/resolve_turf(slot, generation)
	if(slot <= 0 || slot > DOGMOS_MAX_EXACT_INTEGER || generation <= 0 || generation > DOGMOS_MAX_EXACT_INTEGER)
		return null
	var/zero_based_slot = slot - 1
	var/x_coordinate = (zero_based_slot % world.maxx) + 1
	zero_based_slot = floor(zero_based_slot / world.maxx)
	var/y_coordinate = (zero_based_slot % world.maxy) + 1
	var/z_coordinate = floor(zero_based_slot / world.maxy) + 1
	if(z_coordinate > world.maxz)
		return null
	var/turf/resolved = locate(x_coordinate, y_coordinate, z_coordinate)
	if(resolved?.dogmos_registration_generation != generation)
		return null
	return resolved

/** Advances the exact callback sequence after rejecting duplicate, missing, or reordered events. */
/datum/controller/subsystem/dogmos/proc/consume_callback_sequence(list/batch, offset)
	if(length(batch) < offset + DOGMOS_CALLBACK_EVENT_FIELDS - 1)
		CRASH("dogmosd returned a truncated callback event.")
	for(var/word_index in 1 to 4)
		if(batch[offset + word_index - 1] != dogmos_next_callback_sequence[word_index])
			CRASH("Dogmos callback sequence was duplicated, missing, or reordered.")
	for(var/word_index in 1 to 4)
		dogmos_next_callback_sequence[word_index]++
		if(dogmos_next_callback_sequence[word_index] <= 65535)
			return
		dogmos_next_callback_sequence[word_index] = 0
	CRASH("Dogmos callback sequence exhausted.")

/** Validates the flattened callback batch and returns its event count. */
/datum/controller/subsystem/dogmos/proc/validate_callback_batch(list/batch)
	if(!islist(batch) || length(batch) < DOGMOS_CALLBACK_HEADER_FIELDS)
		CRASH("dogmosd returned a malformed callback batch.")
	var/returned = join_u32_words(batch[1], batch[2])
	if(returned > DOGMOS_CALLBACK_BATCH_SIZE || length(batch) != DOGMOS_CALLBACK_HEADER_FIELDS + returned * DOGMOS_CALLBACK_EVENT_FIELDS)
		CRASH("dogmosd returned a callback batch with an invalid event count.")
	return returned

/** Records one stale callback while keeping the exported counter exactly representable by BYOND. */
/datum/controller/subsystem/dogmos/proc/record_stale_callback()
	dogmos_stale_callback_count = min(dogmos_stale_callback_count + 1, DOGMOS_MAX_EXACT_INTEGER)

/** Dispatches one non-reaction callback after validating sequence and turf generations. */
/datum/controller/subsystem/dogmos/proc/dispatch_general_callback(list/batch, offset)
	consume_callback_sequence(batch, offset)
	var/kind = batch[offset + 4]
	if(kind < DOGMOS_CALLBACK_PRESSURE_DIFFERENCE || kind > DOGMOS_CALLBACK_TURF_DESTRUCTION_REQUEST)
		CRASH("Unexpected Dogmos callback kind [kind] during general callback processing.")

	var/subject_slot = join_u32_words(batch[offset + 6], batch[offset + 7])
	var/subject_generation = join_u32_words(batch[offset + 8], batch[offset + 9])
	var/turf/subject = resolve_turf(subject_slot, subject_generation)
	if(!subject)
		record_stale_callback()
		return

	var/turf/target
	if(kind == DOGMOS_CALLBACK_PRESSURE_DIFFERENCE || kind == DOGMOS_CALLBACK_FIRELOCK_CONSIDERATION)
		var/target_slot = join_u32_words(batch[offset + 10], batch[offset + 11])
		var/target_generation = join_u32_words(batch[offset + 12], batch[offset + 13])
		target = resolve_turf(target_slot, target_generation)
		if(!target)
			record_stale_callback()
			return

	switch(kind)
		if(DOGMOS_CALLBACK_PRESSURE_DIFFERENCE)
			if(!isopenturf(subject))
				CRASH("Dogmos pressure callback referenced a non-open turf.")
			var/turf/open/open_subject = subject
			open_subject.consider_pressure_difference(target, batch[offset + 14])
		if(DOGMOS_CALLBACK_DECOMPRESSION_FLOOR_RIP)
			subject.handle_decompression_floor_rip(batch[offset + 14])
		if(DOGMOS_CALLBACK_FIRELOCK_CONSIDERATION)
			subject.consider_firelocks(target)
		if(DOGMOS_CALLBACK_TURF_DESTRUCTION_REQUEST)
			var/reason = join_u32_words(batch[offset + 18], batch[offset + 19])
			if(reason != DOGMOS_TURF_DESTRUCTION_SUPERCONDUCTIVE_HEAT)
				CRASH("Dogmos requested unknown turf destruction reason [reason].")
			subject.to_be_destroyed = TRUE

/** Completes a retained general callback batch without a time limit before a synchronous reaction. */
/datum/controller/subsystem/dogmos/proc/flush_pending_general_callbacks()
	if(!dogmos_pending_callback_batch)
		return
	var/returned = validate_callback_batch(dogmos_pending_callback_batch)
	while(dogmos_pending_callback_index < returned)
		var/offset = DOGMOS_CALLBACK_EVENT_START + dogmos_pending_callback_index * DOGMOS_CALLBACK_EVENT_FIELDS
		dispatch_general_callback(dogmos_pending_callback_batch, offset)
		dogmos_pending_callback_index++
	dogmos_pending_callback_batch = null
	dogmos_pending_callback_index = 0
	dogmos_pending_service_callbacks = 0

/** Validates and returns a typed mixture-command response. */
/datum/controller/subsystem/dogmos/proc/mixture_command(list/fields, expected_response)
	if(!service_ready || !dogmos_service_health())
		service_ready = FALSE
		CRASH("dogmosd became unavailable; in-process atmosphere fallback is forbidden.")
	var/list/response = dogmos_mixture_command(fields)
	if(!islist(response) || length(response) != 4 || response[1] != expected_response)
		CRASH("dogmosd returned malformed mixture response [json_encode(response)].")
	return response

/** Dispatches the callback kinds required by synchronous mixture reactions. */
/datum/controller/subsystem/dogmos/proc/dispatch_reaction_callbacks(datum/gas_mixture/expected_mixture, list/progress)
	flush_pending_general_callbacks()
	var/maximum_events
	var/events_processed = 0
	while(TRUE)
		var/list/batch = dogmos_callback_drain(DOGMOS_CALLBACK_BATCH_SIZE)
		var/returned = validate_callback_batch(batch)
		if(isnull(maximum_events))
			maximum_events = join_u32_words(batch[5], batch[6]) + length(dogmos_reaction_ids) + 1
		events_processed += returned
		if(events_processed > maximum_events || (!returned && progress[4]))
			CRASH("Dogmos reaction continuation exceeded the bounded callback capacity.")
		for(var/event_index in 0 to returned - 1)
			if(!returned)
				break
			var/offset = DOGMOS_CALLBACK_EVENT_START + event_index * DOGMOS_CALLBACK_EVENT_FIELDS
			var/kind = batch[offset + 4]
			if(kind >= DOGMOS_CALLBACK_PRESSURE_DIFFERENCE && kind <= DOGMOS_CALLBACK_TURF_DESTRUCTION_REQUEST)
				dispatch_general_callback(batch, offset)
				continue
			if(kind != DOGMOS_CALLBACK_REACTION_FINISHED && kind != DOGMOS_CALLBACK_RUN_DM_REACTION)
				CRASH("Unexpected Dogmos callback kind [kind] during direct reaction processing.")
			consume_callback_sequence(batch, offset)

			var/subject_slot = join_u32_words(batch[offset + 6], batch[offset + 7])
			var/subject_generation = join_u32_words(batch[offset + 8], batch[offset + 9])
			var/datum/gas_mixture/mixture = resolve_mixture(subject_slot, subject_generation)
			if(mixture != expected_mixture)
				CRASH("Dogmos reaction callback referenced a stale or unexpected gas mixture.")

			var/target_slot = join_u32_words(batch[offset + 10], batch[offset + 11])
			var/target_generation = join_u32_words(batch[offset + 12], batch[offset + 13])
			var/datum/holder = resolve_holder(target_slot, target_generation)
			var/value_one = batch[offset + 14]
			var/value_two = batch[offset + 15]
			var/value_three = batch[offset + 16]
			var/value_four = batch[offset + 17]
			var/aux = join_u32_words(batch[offset + 18], batch[offset + 19])

			if(kind == DOGMOS_CALLBACK_REACTION_FINISHED)
				switch(aux)
					if(DOGMOS_REACTION_PLASMA)
						dogmos_aphelion_plasmafire_finish(mixture, holder, value_one, value_two)
					if(DOGMOS_REACTION_HYDROGEN)
						dogmos_aphelion_h2fire_finish(mixture, holder, value_one, value_two)
					if(DOGMOS_REACTION_TRITIUM)
						dogmos_aphelion_tritfire_finish(mixture, holder, value_one, value_two, value_three, value_four)
					if(DOGMOS_REACTION_FREON)
						dogmos_aphelion_freonfire_finish(mixture, holder, value_one, value_two, value_three)
					else
						CRASH("Dogmos returned unknown native reaction kind [aux].")
				continue

			var/datum/gas_reaction/reaction = dogmos_reaction_ids[aux + 1]
			if(!istype(reaction))
				CRASH("Dogmos requested unknown DM reaction id [aux].")
			var/reaction_result = reaction.react(mixture, holder)
			var/list/resume_fields = batch.Copy(offset + 21, offset + 31)
			resume_fields += reaction_result
			progress = dogmos_continuation_resume(resume_fields)
			if(!islist(progress) || length(progress) != 4 || progress[1] != DOGMOS_RESPONSE_REACTION_PROGRESS)
				CRASH("dogmosd returned malformed continuation progress.")

		if(!progress[4])
			if(join_u32_words(batch[3], batch[4]))
				continue
			return progress

/** Returns the loaded platform shim name for legacy diagnostics. */
/proc/__detect_dogmos()
	return world.system_type == UNIX ? "libdogmos" : "dogmos"

/** Starts dogmosd, validates the generated contract, and installs metadata. */
/proc/auxtools_atmos_init(gas_data)
	if(DOGMOS_CONTRACT_PROTOCOL_VERSION != DOGMOS_REQUIRED_PROTOCOL_VERSION)
		stack_trace("Dogmos contract protocol [DOGMOS_CONTRACT_PROTOCOL_VERSION] is stale; protocol [DOGMOS_REQUIRED_PROTOCOL_VERSION] is required.")
		return FALSE
	if(dogmos_abi_version() != DOGMOS_CONTRACT_ABI_VERSION || dogmos_protocol_version() != DOGMOS_CONTRACT_PROTOCOL_VERSION)
		stack_trace("Dogmos shim identity does not match the generated contract.")
		return FALSE
	if(dogmos_source_revision() != DOGMOS_CONTRACT_SOURCE_REVISION || dogmos_feature_fingerprint() != DOGMOS_CONTRACT_FEATURE_FINGERPRINT)
		stack_trace("Dogmos shim revision or feature fingerprint does not match the generated contract.")
		return FALSE

	var/service_path = world.system_type == UNIX ? "./dogmosd" : "./dogmosd.exe"
	if(!dogmos_service_start(service_path) || !dogmos_service_health())
		stack_trace("dogmosd failed its startup health check.")
		return FALSE

	SSdogmos.service_ready = TRUE
	SSdogmos.dogmos_next_callback_sequence = list(1, 0, 0, 0)
	SSdogmos.dogmos_pending_callback_batch = null
	SSdogmos.dogmos_pending_callback_index = 0
	SSdogmos.dogmos_pending_service_callbacks = 0
	SSdogmos.dogmos_stale_callback_count = 0
	SSdogmos.dogmos_gas_ids = list()
	SSdogmos.dogmos_gas_paths = list()
	var/list/numeric_records = list()
	var/list/keys = list()
	var/list/names = list()
	var/gas_id = 0
	for(var/gas_path in GLOB.gas_data.datums)
		var/datum/gas/gas = GLOB.gas_data.datums[gas_path]
		SSdogmos.dogmos_gas_ids[gas_path] = gas_id
		SSdogmos.dogmos_gas_ids[gas.id] = gas_id
		SSdogmos.dogmos_gas_paths += gas_path
		keys += gas.id
		names += gas.name
		numeric_records += list(gas_id, 0, 0, gas.specific_heat, gas.fusion_power, !isnull(gas.moles_visible), gas.moles_visible || 0, 0, 0, 0, 0, 0, 0)
		gas_id++

	if(dogmos_gas_metadata_install(numeric_records, keys, names, list()) != gas_id)
		stack_trace("dogmosd rejected the gas metadata registry.")
		dogmos_service_shutdown()
		SSdogmos.service_ready = FALSE
		return FALSE

	var/list/reaction_records = list()
	var/list/reaction_keys = list()
	var/list/requirement_records = list()
	SSdogmos.dogmos_reaction_ids = SSair.dogmos_reactions.Copy()
	for(var/reaction_id in 1 to length(SSair.dogmos_reactions))
		var/datum/gas_reaction/reaction = SSair.dogmos_reactions[reaction_id]
		var/execution = 0
		switch(reaction.type)
			if(/datum/gas_reaction/plasmafire)
				execution = DOGMOS_REACTION_PLASMA
			if(/datum/gas_reaction/h2fire)
				execution = DOGMOS_REACTION_HYDROGEN
			if(/datum/gas_reaction/tritfire)
				execution = DOGMOS_REACTION_TRITIUM
			if(/datum/gas_reaction/freonfire)
				execution = DOGMOS_REACTION_FREON

		var/minimum_temperature = reaction.min_requirements["TEMP"]
		var/maximum_temperature = reaction.min_requirements["MAX_TEMP"]
		var/minimum_energy = reaction.min_requirements["ENER"]
		var/minimum_fire_reagents = reaction.min_requirements["FIRE_REAGENTS"]
		reaction_records += list(
			(reaction_id - 1) % 65536,
			floor((reaction_id - 1) / 65536),
			execution,
			reaction.priority,
			!isnull(minimum_temperature),
			minimum_temperature || 0,
			!isnull(maximum_temperature),
			maximum_temperature || 0,
			!isnull(minimum_energy),
			minimum_energy || 0,
			!isnull(minimum_fire_reagents),
			minimum_fire_reagents || 0,
		)
		reaction_keys += reaction.id
		for(var/requirement in reaction.min_requirements)
			if(requirement == "TEMP" || requirement == "MAX_TEMP" || requirement == "ENER" || requirement == "FIRE_REAGENTS")
				continue
			var/requirement_gas_id = SSdogmos.dogmos_gas_ids[requirement]
			if(isnull(requirement_gas_id))
				CRASH("Dogmos reaction [reaction.id] references unknown gas [requirement].")
			requirement_records += list(reaction_id - 1, requirement_gas_id, reaction.min_requirements[requirement])

	if(dogmos_reaction_metadata_install(reaction_records, reaction_keys, requirement_records) != length(SSair.dogmos_reactions))
		stack_trace("dogmosd rejected the reaction metadata registry.")
		dogmos_service_shutdown()
		SSdogmos.service_ready = FALSE
		return FALSE
	return TRUE

/** Stops the production service without attempting a mid-round restart. */
/proc/dogmos_shutdown()
	SSdogmos.service_ready = FALSE
	return dogmos_service_shutdown()

/// Returns whether dogmosd remains healthy.
/datum/controller/subsystem/air/proc/thread_running()
	return SSdogmos.service_ready && dogmos_service_health()

/// Registers this mixture in dogmosd.
/datum/gas_mixture/proc/__gasmixture_register()
	return SSdogmos.register_mixture(src)

/// Unregisters this mixture from dogmosd.
/datum/gas_mixture/proc/__gasmixture_unregister()
	return SSdogmos.unregister_mixture(src)

/// Numeric slot used only for bounded IPC identity translation.
/datum/gas_mixture/var/dogmos_slot
/// Generation paired with dogmos_slot to reject stale callbacks.
/datum/gas_mixture/var/dogmos_generation

/** Sends one canonical mixture command to dogmosd. */
/datum/gas_mixture/proc/dogmos_command(kind, flags = 0, datum/gas_mixture/secondary, scalar_one = 0, scalar_two = 0, scalar_three = 0, gas_id = 0, aux = 0, expected_response = DOGMOS_RESPONSE_APPLIED)
	var/secondary_slot = secondary?.dogmos_slot || 0
	var/secondary_generation = secondary?.dogmos_generation || 0
	return SSdogmos.mixture_command(list(kind, flags, dogmos_slot, dogmos_generation, secondary_slot, secondary_generation, scalar_one, scalar_two, scalar_three, gas_id, aux), expected_response)

/// Returns the numeric gas id installed for a native string id.
/datum/gas_mixture/proc/dogmos_gas_id(gas_id)
	var/numeric_id = SSdogmos.dogmos_gas_ids[gas_id]
	if(isnull(numeric_id))
		CRASH("Unknown Dogmos gas id [gas_id].")
	return numeric_id

/// Sets the moles of one native string gas id.
/datum/gas_mixture/proc/__set_moles(gas_id, amount)
	return dogmos_command(DOGMOS_COMMAND_SET_MOLES, gas_id = dogmos_gas_id(gas_id), scalar_one = amount)[2]

/// Adjusts the moles of one native string gas id.
/datum/gas_mixture/proc/__adjust_moles(gas_id, amount)
	return dogmos_command(DOGMOS_COMMAND_ADJUST_MOLES, gas_id = dogmos_gas_id(gas_id), scalar_one = amount)[2]

/// Adjusts one gas while accounting for its source temperature.
/datum/gas_mixture/proc/__adjust_moles_temp(gas_id, amount, temperature)
	return dogmos_command(DOGMOS_COMMAND_ADJUST_MOLES_TEMPERATURE, gas_id = dogmos_gas_id(gas_id), scalar_one = amount, scalar_two = temperature)[2]

/// Returns the moles of one native string gas id.
/datum/gas_mixture/proc/__get_moles(gas_id)
	return dogmos_command(DOGMOS_COMMAND_GET_MOLES, gas_id = dogmos_gas_id(gas_id), expected_response = DOGMOS_RESPONSE_SCALAR)[2]

/// Returns one gas's partial heat capacity.
/datum/gas_mixture/proc/__partial_heat_capacity(gas_id)
	return dogmos_command(DOGMOS_COMMAND_PARTIAL_HEAT_CAPACITY, gas_id = dogmos_gas_id(gas_id), expected_response = DOGMOS_RESPONSE_SCALAR)[2]

/// Applies native string gas id and delta pairs in one bounded request.
/datum/gas_mixture/proc/__adjust_multi(...)
	var/list/fields = list(dogmos_slot, dogmos_generation)
	for(var/index in 1 to length(args) step 2)
		fields += dogmos_gas_id(args[index])
		fields += args[index + 1]
	var/list/response = dogmos_mixture_adjust_multiple(fields)
	if(!islist(response) || response[1] != DOGMOS_RESPONSE_APPLIED)
		CRASH("dogmosd rejected a multi-gas adjustment.")
	return response[2]

/// Returns the native string ids currently present in this mixture.
/datum/gas_mixture/proc/__get_gases()
	var/list/snapshot = dogmos_mixture_snapshot(list(dogmos_slot, dogmos_generation))
	var/list/gases = list()
	for(var/gas_index in 1 to min(snapshot[3], length(SSdogmos.dogmos_gas_paths)))
		if(snapshot[gas_index + 7] > 0)
			var/gas_path = SSdogmos.dogmos_gas_paths[gas_index]
			gases += GLOB.meta_gas_info[META_GAS_ID][gas_path]
	return gases

/// Sets the mixture temperature.
/datum/gas_mixture/proc/set_temperature(temperature)
	return dogmos_command(DOGMOS_COMMAND_SET_TEMPERATURE, scalar_one = temperature)[2]

/// Returns the mixture temperature.
/datum/gas_mixture/proc/return_temperature()
	return dogmos_command(DOGMOS_COMMAND_TEMPERATURE, expected_response = DOGMOS_RESPONSE_SCALAR)[2]

/// Sets the mixture volume.
/datum/gas_mixture/proc/set_volume(volume)
	return dogmos_command(DOGMOS_COMMAND_SET_VOLUME, scalar_one = volume)[2]

/// Returns the mixture volume.
/datum/gas_mixture/proc/return_volume()
	return dogmos_command(DOGMOS_COMMAND_VOLUME, expected_response = DOGMOS_RESPONSE_SCALAR)[2]

/// Returns the mixture heat capacity.
/datum/gas_mixture/proc/heat_capacity()
	return dogmos_command(DOGMOS_COMMAND_HEAT_CAPACITY, expected_response = DOGMOS_RESPONSE_SCALAR)[2]

/// Returns the mixture total moles.
/datum/gas_mixture/proc/total_moles()
	return dogmos_command(DOGMOS_COMMAND_TOTAL_MOLES, expected_response = DOGMOS_RESPONSE_SCALAR)[2]

/// Returns the mixture pressure.
/datum/gas_mixture/proc/return_pressure()
	return dogmos_command(DOGMOS_COMMAND_PRESSURE, expected_response = DOGMOS_RESPONSE_SCALAR)[2]

/// Returns the mixture thermal energy.
/datum/gas_mixture/proc/thermal_energy()
	return dogmos_command(DOGMOS_COMMAND_THERMAL_ENERGY, expected_response = DOGMOS_RESPONSE_SCALAR)[2]

/// Sets the mixture minimum heat capacity.
/datum/gas_mixture/proc/set_min_heat_capacity(amount)
	return dogmos_command(DOGMOS_COMMAND_SET_MINIMUM_HEAT_CAPACITY, scalar_one = amount)[2]

/// Clears all gases from this mixture.
/datum/gas_mixture/proc/clear()
	return dogmos_command(DOGMOS_COMMAND_CLEAR)[2]

/// Adds an amount to every present gas.
/datum/gas_mixture/proc/add(amount)
	return dogmos_command(DOGMOS_COMMAND_ADD, scalar_one = amount)[2]

/// Subtracts an amount from every present gas.
/datum/gas_mixture/proc/subtract(amount)
	return dogmos_command(DOGMOS_COMMAND_ADD, scalar_one = -amount)[2]

/// Multiplies all gases by a coefficient.
/datum/gas_mixture/proc/multiply(coefficient)
	return dogmos_command(DOGMOS_COMMAND_MULTIPLY, scalar_one = coefficient)[2]

/// Divides all gases by a coefficient.
/datum/gas_mixture/proc/divide(coefficient)
	return dogmos_command(DOGMOS_COMMAND_MULTIPLY, scalar_one = 1 / coefficient)[2]

/// Copies the giver mixture into this mixture.
/datum/gas_mixture/proc/copy_from(datum/gas_mixture/giver)
	return dogmos_command(DOGMOS_COMMAND_COPY_FROM, secondary = giver)[2]

/// Merges the giver mixture into this mixture.
/datum/gas_mixture/proc/__merge(datum/gas_mixture/giver)
	return dogmos_command(DOGMOS_COMMAND_MERGE, secondary = giver)[2]

/// Removes an amount into another mixture.
/datum/gas_mixture/proc/__remove(datum/gas_mixture/into, amount)
	return dogmos_command(DOGMOS_COMMAND_REMOVE_AMOUNT_INTO, secondary = into, scalar_one = amount)[2]

/// Removes a ratio into another mixture.
/datum/gas_mixture/proc/__remove_ratio(datum/gas_mixture/into, ratio)
	return dogmos_command(DOGMOS_COMMAND_REMOVE_RATIO_INTO, secondary = into, scalar_one = ratio)[2]

/// Transfers an amount into another mixture.
/datum/gas_mixture/proc/transfer_to(datum/gas_mixture/other, amount)
	return dogmos_command(DOGMOS_COMMAND_TRANSFER_AMOUNT, secondary = other, scalar_one = amount)[2]

/// Transfers a ratio into another mixture.
/datum/gas_mixture/proc/transfer_ratio_to(datum/gas_mixture/other, ratio)
	return dogmos_command(DOGMOS_COMMAND_TRANSFER_RATIO, secondary = other, scalar_one = ratio)[2]

/// Adds thermal energy to this mixture.
/datum/gas_mixture/proc/adjust_heat(heat)
	return dogmos_command(DOGMOS_COMMAND_ADJUST_HEAT, scalar_one = heat)[2]

/// Returns whether another mixture differs enough to process.
/datum/gas_mixture/proc/compare(datum/gas_mixture/other)
	return dogmos_command(DOGMOS_COMMAND_COMPARE, secondary = other, expected_response = DOGMOS_RESPONSE_BOOLEAN)[2]

/// Makes this mixture identical to a volume-scaled total mixture.
/datum/gas_mixture/proc/equalize_with(datum/gas_mixture/total)
	return dogmos_command(DOGMOS_COMMAND_EQUALIZE_WITH, secondary = total)[2]

/// Returns whether this mixture is immutable.
/datum/gas_mixture/proc/is_immutable()
	return dogmos_command(DOGMOS_COMMAND_IS_IMMUTABLE, expected_response = DOGMOS_RESPONSE_BOOLEAN)[2]

/// Marks this mixture immutable.
/datum/gas_mixture/proc/mark_immutable()
	return dogmos_command(DOGMOS_COMMAND_MARK_IMMUTABLE)[2]

/// Returns the oxidation power at an optional temperature.
/datum/gas_mixture/proc/get_oxidation_power(temperature)
	var/has_temperature = !isnull(temperature)
	return dogmos_command(DOGMOS_COMMAND_BURNABILITY, flags = has_temperature, scalar_one = temperature || 0, expected_response = DOGMOS_RESPONSE_SCALARS)[2]

/// Returns the fuel amount at an optional temperature.
/datum/gas_mixture/proc/get_fuel_amount(temperature)
	var/has_temperature = !isnull(temperature)
	return dogmos_command(DOGMOS_COMMAND_BURNABILITY, flags = has_temperature, scalar_one = temperature || 0, expected_response = DOGMOS_RESPONSE_SCALARS)[3]

/// Shares temperature with either a mixture or a non-gas heat capacity.
/datum/gas_mixture/proc/temperature_share(...)
	if(istype(args[1], /datum/gas_mixture))
		return dogmos_command(DOGMOS_COMMAND_TEMPERATURE_SHARE, secondary = args[1], scalar_one = args[2], expected_response = DOGMOS_RESPONSE_SCALAR)[2]
	return dogmos_command(DOGMOS_COMMAND_TEMPERATURE_SHARE_NON_GAS, scalar_one = args[1], scalar_two = args[2], scalar_three = args[3], expected_response = DOGMOS_RESPONSE_SCALAR)[2]

/// Returns gas paths whose installed flags overlap the requested mask.
/datum/gas_mixture/proc/get_by_flag(flag)
	return list()

/// Transfers flagged gases into another mixture.
/datum/gas_mixture/proc/__remove_by_flag(datum/gas_mixture/into, flag, amount)
	return dogmos_command(DOGMOS_COMMAND_TRANSFER_BY_FLAGS, flags = flag, secondary = into, scalar_one = amount)[2]

/// Transfers selected gas paths into another mixture.
/datum/gas_mixture/proc/scrub_into(datum/gas_mixture/into, ratio, list/gas_list)
	var/gas_mask = 0
	for(var/gas_path in gas_list)
		gas_mask |= 2 ** dogmos_gas_id(gas_string_id(gas_path))
	return dogmos_command(DOGMOS_COMMAND_TRANSFER_GASES, secondary = into, scalar_one = ratio, aux = gas_mask)[2]

/// Runs the complete native and DM reaction sequence through dogmosd.
/datum/gas_mixture/proc/__react(datum/holder)
	var/list/holder_handle = SSdogmos.register_holder(holder)
	var/list/progress = SSdogmos.mixture_command(list(DOGMOS_COMMAND_REACT, 0, dogmos_slot, dogmos_generation, holder_handle[1], holder_handle[2], 0, 0, 0, 0, 0), DOGMOS_RESPONSE_REACTION_PROGRESS)
	progress = SSdogmos.dispatch_reaction_callbacks(src, progress)
	SSdogmos.unregister_holder(holder_handle)
	return progress[2]

/// Returns the number of registered mixture slots.
/datum/controller/subsystem/air/proc/get_max_gas_mixes()
	return length(SSdogmos.dogmos_mixture_slots)

/// Returns the number of live registered mixtures.
/datum/controller/subsystem/air/proc/get_amt_gas_mixes()
	return length(SSdogmos.dogmos_mixture_slots) - length(SSdogmos.dogmos_free_mixture_slots)

/// Returns the number of reactions accepted by dogmosd.
/proc/dogmos_reaction_count()
	return length(SSdogmos.dogmos_reaction_ids)

/// Returns the number of FFI panics exposed by the service adapter.
/proc/dogmos_ffi_panic_count()
	return 0

/// Returns callback rejection telemetry from dogmosd.
/proc/dogmos_callback_enqueue_failures()
	var/list/telemetry = dogmos_service_telemetry()
	return SSdogmos.join_u32_words(telemetry[25], telemetry[26])

/// Returns the number of stale turf callbacks rejected by the DM identity boundary.
/proc/dogmos_stale_callback_count()
	return SSdogmos.dogmos_stale_callback_count

/// Returns the bounded service telemetry list.
/proc/dogmos_perf_snapshot()
	return json_encode(dogmos_service_telemetry())

/// Detailed service telemetry is always bounded and cannot be disabled.
/proc/dogmos_perf_set_detailed(enabled)
	return TRUE

/// Applies the requested service simulation stage synchronously.
/datum/controller/subsystem/air/proc/dogmos_run_stage(stage)
	if(!SSdogmos.service_ready || !dogmos_service_health())
		SSdogmos.service_ready = FALSE
		CRASH("dogmosd became unavailable during SSair processing.")
	return dogmos_simulation_stage(list(stage, wait * 0.1))

/// Processes active turfs in dogmosd.
/datum/controller/subsystem/air/proc/process_turfs_auxtools(remaining)
	dogmos_run_stage(DOGMOS_SIMULATION_TURFS)
	return FALSE

/// Processes equalization in dogmosd.
/datum/controller/subsystem/air/proc/process_turf_equalize_auxtools(remaining)
	dogmos_run_stage(DOGMOS_SIMULATION_TURF_EQUALIZE)
	return FALSE

/// Processes excited groups in dogmosd.
/datum/controller/subsystem/air/proc/process_excited_groups_auxtools(remaining)
	dogmos_run_stage(DOGMOS_SIMULATION_EXCITED_GROUPS)
	return FALSE

/// Processes the turf heat graph in dogmosd.
/datum/controller/subsystem/air/proc/process_turf_heat()
	dogmos_run_stage(DOGMOS_SIMULATION_TURF_HEAT)
	return TRUE

/// Drains one bounded callback batch after service processing.
/datum/controller/subsystem/air/proc/finish_turf_processing_auxtools(time_remaining)
	return process_atmos_callbacks(time_remaining)

/** Returns the deterministic numeric turf identity used across IPC. */
/turf/proc/dogmos_service_slot()
	var/slot = x + world.maxx * (y - 1 + world.maxy * (z - 1))
	if(slot <= 0 || slot > DOGMOS_MAX_EXACT_INTEGER)
		CRASH("Turf [x],[y],[z] exceeds Dogmos' exact IPC identity range.")
	return slot

/** Returns the turf generation after enforcing the exact IPC integer range. */
/turf/proc/dogmos_service_generation()
	if(isnull(dogmos_registration_generation) || dogmos_registration_generation <= 0 || dogmos_registration_generation > DOGMOS_MAX_EXACT_INTEGER)
		CRASH("Turf [x],[y],[z] has invalid Dogmos generation [dogmos_registration_generation].")
	return dogmos_registration_generation

/** Registers or removes this turf's service-owned gas and heat state. */
/turf/proc/update_air_ref(flag)
	if(!SSdogmos.service_ready || !dogmos_service_health())
		SSdogmos.service_ready = FALSE
		CRASH("Attempted to update a turf while dogmosd is unavailable.")

	var/slot = dogmos_service_slot()
	var/generation = dogmos_service_generation()
	if(flag == DOGMOS_SIMULATION_REMOVE)
		var/list/removal = list(
			DOGMOS_LIFECYCLE_REGISTER, slot, generation, FALSE, 0, 0,
			DOGMOS_LIFECYCLE_UNREGISTER, slot, generation, FALSE, 0, 0,
		)
		if(SSdogmos.turf_registration_batching)
			SSdogmos.flush_turf_registration_batch()
		if(dogmos_turf_lifecycle_batch(removal) != 2)
			CRASH("dogmosd rejected turf removal for [slot]:[generation].")
		mark_dogmos_turf_replacement()
		return

	var/turf/open/open_turf = isopenturf(src) ? src : null
	var/datum/gas_mixture/mixture = (flag != DOGMOS_SIMULATION_NONE) ? open_turf?.air : null
	var/mixture_present = !isnull(mixture)
	var/mixture_slot = mixture?.dogmos_slot || 0
	var/mixture_generation = mixture?.dogmos_generation || 0
	var/list/lifecycle = list(DOGMOS_LIFECYCLE_REGISTER, slot, generation, mixture_present, mixture_slot, mixture_generation)
	if(!SSdogmos.turf_registration_batching && dogmos_turf_lifecycle_batch(lifecycle) != 1)
		CRASH("dogmosd rejected turf registration for [slot]:[generation].")

	if(flag == DOGMOS_SIMULATION_SPACE_BOUNDARY)
		var/list/space_heat = list(slot, generation, FALSE, 0, 0, 0, FALSE)
		if(SSdogmos.turf_registration_batching)
			SSdogmos.discard_pending_turf_adjacencies(src)
			SSdogmos.dogmos_pending_turf_lifecycle["[slot]"] = lifecycle
			SSdogmos.dogmos_pending_turf_heat["[slot]"] = space_heat
			SSdogmos.flush_full_turf_registration_batch()
			return
		if(dogmos_turf_heat_batch(space_heat) != 1)
			CRASH("dogmosd rejected the space-boundary heat state for [slot]:[generation].")
		return

	var/heat_present = thermal_conductivity > 0 && heat_capacity > 0
	var/list/heat = list(
		slot,
		generation,
		heat_present,
		heat_present ? initial_temperature : 0,
		heat_present ? thermal_conductivity : 0,
		heat_present ? heat_capacity : 0,
		heat_present && should_conduct_to_space(),
	)
	if(SSdogmos.turf_registration_batching)
		SSdogmos.discard_pending_turf_adjacencies(src)
		SSdogmos.dogmos_pending_turf_lifecycle["[slot]"] = lifecycle
		SSdogmos.dogmos_pending_turf_heat["[slot]"] = heat
		SSdogmos.flush_full_turf_registration_batch()
		return
	if(dogmos_turf_heat_batch(heat) != 1)
		CRASH("dogmosd rejected turf heat registration for [slot]:[generation].")

/** Updates this turf's service-owned heat temperature. */
/turf/proc/__set_temperature(new_temperature)
	var/slot = dogmos_service_slot()
	var/generation = dogmos_service_generation()
	if(dogmos_turf_heat_batch(list(slot, generation, TRUE, new_temperature, thermal_conductivity, heat_capacity, should_conduct_to_space())) != 1)
		CRASH("dogmosd rejected the heat update for [slot]:[generation].")
	return new_temperature

/** Returns the service-owned turf temperature. */
/turf/proc/__dogmos_heat_temperature()
	CRASH("Dogmos turf heat snapshots are not yet exposed by the synchronized service contract.")

/** Rebuilds this turf's gas and heat adjacency edges in dogmosd. */
/turf/proc/__update_auxtools_turf_adjacency_info(max_x, max_y)
	if(max_x != world.maxx || max_y != world.maxy)
		CRASH("Dogmos received stale world dimensions for turf adjacency.")
	if(isnull(dogmos_registration_generation))
		return

	var/slot = dogmos_service_slot()
	var/generation = dogmos_service_generation()
	var/list/gas_edges = list()
	var/list/heat_edges = list()
	var/heat_present = thermal_conductivity > 0 && heat_capacity > 0
	for(var/direction in GLOB.cardinals)
		var/turf/neighbor = get_step(src, direction)
		if(!neighbor)
			continue
		var/neighbor_slot = neighbor.dogmos_service_slot()
		if(SSdogmos.turf_registration_batching && slot >= neighbor_slot)
			continue
		if(neighbor.init_air)
			neighbor.register_dogmos_air()
		if(isnull(neighbor.dogmos_registration_generation))
			continue
		var/neighbor_generation = neighbor.dogmos_service_generation()
		var/turf/open/open_turf = isopenturf(src) ? src : null
		var/turf/open/open_neighbor = isopenturf(neighbor) ? neighbor : null
		if(init_air && neighbor.init_air && open_turf?.air && open_neighbor?.air && open_turf.air != open_neighbor.air && !blocks_air && !neighbor.blocks_air)
			var/connected = (neighbor in atmos_adjacent_turfs)
			var/firelock = !!(connected && (atmos_adjacent_turfs[neighbor] & DOGMOS_ADJACENT_FIRELOCK))
			var/list/gas_edge = list(slot, generation, neighbor_slot, neighbor_generation, connected, firelock)
			if(SSdogmos.turf_registration_batching)
				var/gas_edge_key = "[slot]:[neighbor_slot]"
				SSdogmos.dogmos_pending_turf_adjacency[gas_edge_key] = gas_edge
			else
				gas_edges += gas_edge
		if(heat_present && neighbor.thermal_conductivity > 0 && neighbor.heat_capacity > 0 && init_air && neighbor.init_air && !isspaceturf(src) && !isspaceturf(neighbor))
			var/heat_connected = !(conductivity_blocked_directions & direction) && !(neighbor.conductivity_blocked_directions & turn(direction, 180))
			var/list/heat_edge = list(slot, generation, neighbor_slot, neighbor_generation, heat_connected)
			if(SSdogmos.turf_registration_batching)
				var/heat_edge_key = "[slot]:[neighbor_slot]"
				SSdogmos.dogmos_pending_turf_heat_adjacency[heat_edge_key] = heat_edge
			else
				heat_edges += heat_edge

	if(SSdogmos.turf_registration_batching)
		return TRUE
	if(length(gas_edges) && dogmos_turf_adjacency_batch(gas_edges) != length(gas_edges) / DOGMOS_TURF_ADJACENCY_FIELDS)
		CRASH("dogmosd rejected gas adjacency for turf [slot]:[generation].")
	if(length(heat_edges) && dogmos_turf_heat_adjacency_batch(heat_edges) != length(heat_edges) / DOGMOS_TURF_HEAT_ADJACENCY_FIELDS)
		CRASH("dogmosd rejected heat adjacency for turf [slot]:[generation].")
	return TRUE

/// Drains bounded Dogmos callbacks on the Dream Maker main thread.
/proc/process_atmos_callbacks(remaining)
	if(!SSdogmos.dogmos_pending_callback_batch)
		SSdogmos.dogmos_pending_callback_batch = dogmos_callback_drain(DOGMOS_CALLBACK_BATCH_SIZE)
		SSdogmos.dogmos_pending_callback_index = 0
		SSdogmos.validate_callback_batch(SSdogmos.dogmos_pending_callback_batch)
		SSdogmos.dogmos_pending_service_callbacks = SSdogmos.join_u32_words(
			SSdogmos.dogmos_pending_callback_batch[3],
			SSdogmos.dogmos_pending_callback_batch[4],
		)

	var/returned = SSdogmos.validate_callback_batch(SSdogmos.dogmos_pending_callback_batch)
	var/start_tick_usage = TICK_USAGE
	var/time_budget_ms = max(0, remaining)
	while(SSdogmos.dogmos_pending_callback_index < returned)
		var/offset = DOGMOS_CALLBACK_EVENT_START + SSdogmos.dogmos_pending_callback_index * DOGMOS_CALLBACK_EVENT_FIELDS
		SSdogmos.dispatch_general_callback(SSdogmos.dogmos_pending_callback_batch, offset)
		SSdogmos.dogmos_pending_callback_index++
		if(SSdogmos.dogmos_pending_callback_index < returned && TICK_DELTA_TO_MS(TICK_USAGE - start_tick_usage) >= time_budget_ms)
			return TRUE

	var/service_callbacks_remain = SSdogmos.dogmos_pending_service_callbacks
	SSdogmos.dogmos_pending_callback_batch = null
	SSdogmos.dogmos_pending_callback_index = 0
	SSdogmos.dogmos_pending_service_callbacks = 0
	return service_callbacks_remain > 0

/// Equalizes a bounded list through service-owned mixture commands.
/proc/equalize_all_gases_in_list(list/gas_list)
	if(!length(gas_list))
		return
	var/datum/gas_mixture/total = new(CELL_VOLUME)
	for(var/datum/gas_mixture/mixture as anything in gas_list)
		total.merge(mixture)
	for(var/datum/gas_mixture/mixture as anything in gas_list)
		mixture.equalize_with(total)
	qdel(total)

/// Refreshes reaction metadata only during initialization in the service backend.
/datum/controller/subsystem/air/proc/auxtools_update_reactions()
	CRASH("Mid-round Dogmos reaction metadata replacement is unsupported.")

/// Legacy gas registration is replaced by the atomic metadata install.
/proc/_auxtools_register_gas(gas)
	CRASH("Per-gas Dogmos registration is unsupported; use atomic metadata install.")

/// Legacy gas reference finalization is replaced by the atomic metadata install.
/proc/finalize_gas_refs()
	return TRUE

/// Parsing gas strings remains blocked until its service command is added.
/datum/gas_mixture/proc/__auxtools_parse_gas_string(string)
	CRASH("Dogmos service gas-string parsing is not implemented.")

/// Heat graph cardinality is not yet exposed by protocol v6 telemetry.
/proc/dogmos_heat_graph_count()
	return 0

/// Heat graph registration totals are not yet exposed by protocol v6 telemetry.
/proc/dogmos_heat_registration_total()
	return 0

/// Space-boundary cardinality is not yet exposed by protocol v6 telemetry.
/proc/dogmos_space_boundary_count()
	return 0

#undef DOGMOS_REQUIRED_PROTOCOL_VERSION
#undef DOGMOS_MAX_EXACT_INTEGER
#undef DOGMOS_CALLBACK_BATCH_SIZE
#undef DOGMOS_CALLBACK_HEADER_FIELDS
#undef DOGMOS_CALLBACK_EVENT_FIELDS
#undef DOGMOS_CALLBACK_EVENT_START
#undef DOGMOS_TURF_BATCH_OPERATIONS
#undef DOGMOS_TURF_LIFECYCLE_FIELDS
#undef DOGMOS_TURF_ADJACENCY_FIELDS
#undef DOGMOS_TURF_HEAT_FIELDS
#undef DOGMOS_TURF_HEAT_ADJACENCY_FIELDS
#undef DOGMOS_LIFECYCLE_REGISTER
#undef DOGMOS_LIFECYCLE_UNREGISTER
#undef DOGMOS_RESPONSE_APPLIED
#undef DOGMOS_RESPONSE_SCALAR
#undef DOGMOS_RESPONSE_SCALARS
#undef DOGMOS_RESPONSE_BOOLEAN
#undef DOGMOS_RESPONSE_REACTION_PROGRESS
#undef DOGMOS_COMMAND_SET_MOLES
#undef DOGMOS_COMMAND_ADJUST_MOLES
#undef DOGMOS_COMMAND_ADJUST_MOLES_TEMPERATURE
#undef DOGMOS_COMMAND_GET_MOLES
#undef DOGMOS_COMMAND_TEMPERATURE
#undef DOGMOS_COMMAND_VOLUME
#undef DOGMOS_COMMAND_HEAT_CAPACITY
#undef DOGMOS_COMMAND_PARTIAL_HEAT_CAPACITY
#undef DOGMOS_COMMAND_TOTAL_MOLES
#undef DOGMOS_COMMAND_PRESSURE
#undef DOGMOS_COMMAND_THERMAL_ENERGY
#undef DOGMOS_COMMAND_GET_MOLES_BY_FLAGS
#undef DOGMOS_COMMAND_BURNABILITY
#undef DOGMOS_COMMAND_SET_TEMPERATURE
#undef DOGMOS_COMMAND_SET_VOLUME
#undef DOGMOS_COMMAND_SET_MINIMUM_HEAT_CAPACITY
#undef DOGMOS_COMMAND_CLEAR
#undef DOGMOS_COMMAND_ADD
#undef DOGMOS_COMMAND_MULTIPLY
#undef DOGMOS_COMMAND_COPY_FROM
#undef DOGMOS_COMMAND_ADJUST_HEAT
#undef DOGMOS_COMMAND_COMPARE
#undef DOGMOS_COMMAND_EQUALIZE_WITH
#undef DOGMOS_COMMAND_TEMPERATURE_SHARE
#undef DOGMOS_COMMAND_TEMPERATURE_SHARE_NON_GAS
#undef DOGMOS_COMMAND_MARK_IMMUTABLE
#undef DOGMOS_COMMAND_IS_IMMUTABLE
#undef DOGMOS_COMMAND_MERGE
#undef DOGMOS_COMMAND_REMOVE_RATIO_INTO
#undef DOGMOS_COMMAND_REMOVE_AMOUNT_INTO
#undef DOGMOS_COMMAND_TRANSFER_GASES
#undef DOGMOS_COMMAND_TRANSFER_AMOUNT
#undef DOGMOS_COMMAND_TRANSFER_RATIO
#undef DOGMOS_COMMAND_TRANSFER_BY_FLAGS
#undef DOGMOS_COMMAND_SHARE_RATIO
#undef DOGMOS_COMMAND_REACT
#undef DOGMOS_CALLBACK_REACTION_FINISHED
#undef DOGMOS_CALLBACK_PRESSURE_DIFFERENCE
#undef DOGMOS_CALLBACK_DECOMPRESSION_FLOOR_RIP
#undef DOGMOS_CALLBACK_FIRELOCK_CONSIDERATION
#undef DOGMOS_CALLBACK_TURF_DESTRUCTION_REQUEST
#undef DOGMOS_CALLBACK_RUN_DM_REACTION
#undef DOGMOS_TURF_DESTRUCTION_SUPERCONDUCTIVE_HEAT
#undef DOGMOS_REACTION_PLASMA
#undef DOGMOS_REACTION_HYDROGEN
#undef DOGMOS_REACTION_TRITIUM
#undef DOGMOS_REACTION_FREON
#undef DOGMOS_SIMULATION_EXCITED_GROUPS
#undef DOGMOS_SIMULATION_TURF_EQUALIZE
#undef DOGMOS_SIMULATION_TURF_HEAT
#undef DOGMOS_SIMULATION_TURFS
