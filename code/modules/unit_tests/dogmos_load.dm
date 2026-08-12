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
