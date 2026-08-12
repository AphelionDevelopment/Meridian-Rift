/**
 * Verifies that the Dogmos native library loads and answers across the FFI boundary.
 *
 * This is the Phase 0 gate for the atmospherics port: it proves the library is present,
 * that BYOND can resolve it, and that a call_ext round-trip returns a usable value.
 */
/datum/unit_test/dogmos_load

/datum/unit_test/dogmos_load/Run()
	var/library = __detect_dogmos()
	TEST_ASSERT(istext(library), "__detect_dogmos() returned no library name, got: [isnull(library) ? "null" : library]")

	// Runs the library initialisers as a side effect - see the comment on this proc.
	var/callbacks_finished = process_atmos_callbacks(0)
	TEST_ASSERT(isnum(callbacks_finished), "process_atmos_callbacks() did not return a number across the FFI boundary, got: [isnull(callbacks_finished) ? "null" : callbacks_finished]")

	var/mix_count = SSair.get_amt_gas_mixes()
	TEST_ASSERT(isnum(mix_count), "SSair.get_amt_gas_mixes() did not return a number across the FFI boundary, got: [isnull(mix_count) ? "null" : mix_count]")

	var/max_mixes = SSair.get_max_gas_mixes()
	TEST_ASSERT(isnum(max_mixes), "SSair.get_max_gas_mixes() did not return a number across the FFI boundary, got: [isnull(max_mixes) ? "null" : max_mixes]")
	TEST_ASSERT(max_mixes >= mix_count, "Dogmos reports fewer total gas mixtures ([max_mixes]) than attached ones ([mix_count])")

/// Verifies that every gas and reaction was handed to Dogmos during SSair init.
/datum/unit_test/dogmos_registration

/datum/unit_test/dogmos_registration/Run()
	TEST_ASSERT(length(GLOB.gas_data.datums) == GAS_TYPE_COUNT, "GLOB.gas_data holds [length(GLOB.gas_data.datums)] gas datums, expected [GAS_TYPE_COUNT]")

	for(var/gas_path in GLOB.gas_data.datums)
		var/datum/gas/gas = GLOB.gas_data.datums[gas_path]
		TEST_ASSERT(istype(gas), "GLOB.gas_data.datums\[[gas_path]\] is not a gas datum instance - Dogmos reads vars off instances, not type paths")
		TEST_ASSERT(gas.id, "[gas_path] registered with no id")
		TEST_ASSERT(isnum(gas.specific_heat), "[gas_path] registered with a non-numeric specific_heat")

	TEST_ASSERT(length(SSair.dogmos_reactions), "SSair.dogmos_reactions is empty - Dogmos would have no reactions at all")

	// Dogmos keys reactions by priority and silently drops duplicates, so a collision here means
	// reactions vanish at runtime with no error.
	var/list/seen_priorities = list()
	for(var/datum/gas_reaction/reaction as anything in SSair.dogmos_reactions)
		TEST_ASSERT(isnum(reaction.priority), "[reaction.type] has a non-numeric Dogmos priority")
		TEST_ASSERT(!seen_priorities["[reaction.priority]"], "[reaction.type] shares Dogmos priority [reaction.priority] with another reaction - one of them would be silently discarded")
		seen_priorities["[reaction.priority]"] = TRUE

	// Every requirement key must be a gas id string or a recognised sentinel, or Dogmos ignores it.
	var/list/meta_gas_id = GLOB.meta_gas_info[META_GAS_ID]
	var/list/known_gas_ids = list()
	for(var/gas_path in meta_gas_id)
		known_gas_ids[meta_gas_id[gas_path]] = TRUE

	for(var/datum/gas_reaction/reaction as anything in SSair.dogmos_reactions)
		for(var/requirement in reaction.min_requirements)
			if(requirement == "TEMP" || requirement == "MAX_TEMP" || requirement == "ENER" || requirement == "FIRE_REAGENTS")
				continue
			TEST_ASSERT(known_gas_ids[requirement], "[reaction.type] has requirement key \"[requirement]\", which is neither a gas id nor a sentinel Dogmos understands")
