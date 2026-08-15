/**
 * Dogmos Kennel: kennel_pin_structure()/kennel_unpin_structure()/kennel_prune_expired_pins(). Covers
 * three properties directly: re-pinning an already-pinned target updates it in place rather than
 * duplicating the entry, an expiring auto-pin is actually removed once its deadline passes, and a
 * manual pin (expires = null) survives pruning regardless of how much time passes.
 */
/datum/unit_test/dogmos_kennel_structures
	var/list/original_list

/datum/unit_test/dogmos_kennel_structures/Run()
	original_list = SSair.structures_of_interest
	SSair.structures_of_interest = list()

	var/obj/machinery/fake_machine = allocate(/obj/machinery)

	SSair.kennel_pin_structure(fake_machine, "first reason", 10 SECONDS)
	TEST_ASSERT_EQUAL(length(SSair.structures_of_interest), 1, \
		"Pinning a fresh target did not add exactly one entry - got [length(SSair.structures_of_interest)].")

	// Re-pin with a different reason: should update the SAME entry in place, not add a second one.
	SSair.kennel_pin_structure(fake_machine, "second reason", 20 SECONDS)
	TEST_ASSERT_EQUAL(length(SSair.structures_of_interest), 1, \
		"Re-pinning an already-pinned target added a duplicate entry instead of updating in place - got [length(SSair.structures_of_interest)].")
	var/list/entry = SSair.structures_of_interest[1]
	TEST_ASSERT_EQUAL(entry["reason"], "second reason", \
		"Re-pinning did not update the reason field - still [entry["reason"]].")

	// Force the (updated) pin's expiry into the past and confirm pruning actually removes it.
	entry["expires"] = world.time - 1
	SSair.kennel_prune_expired_pins()
	TEST_ASSERT_EQUAL(length(SSair.structures_of_interest), 0, \
		"kennel_prune_expired_pins() did not remove an entry whose expires deadline has already passed - [length(SSair.structures_of_interest)] entries remain.")

	// A manual pin (expires = null) must never be pruned, no matter how far world.time has moved.
	SSair.kennel_pin_structure(fake_machine, "manual pin", null)
	SSair.kennel_prune_expired_pins()
	TEST_ASSERT_EQUAL(length(SSair.structures_of_interest), 1, \
		"kennel_prune_expired_pins() removed a manual pin (expires = null) - manual pins must never expire.")

	SSair.kennel_unpin_structure(SSair.structures_of_interest[1]["ref"])
	TEST_ASSERT_EQUAL(length(SSair.structures_of_interest), 0, \
		"kennel_unpin_structure() did not remove the pinned entry by ref.")

	qdel(fake_machine)
	SSair.structures_of_interest = original_list

/datum/unit_test/dogmos_kennel_structures/Destroy()
	// Unconditional, not just on success: a TEST_ASSERT abort in Run() skips its own restore above and
	// would otherwise leave a fake pin sitting in SSair's real structures_of_interest for the rest of
	// the suite.
	if(!isnull(original_list))
		SSair.structures_of_interest = original_list
	return ..()
