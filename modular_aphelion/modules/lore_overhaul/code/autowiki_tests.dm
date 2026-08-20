#ifdef UNIT_TESTS
/datum/lore_overhaul_entry/autowiki_test
	entry_id = "unit_test.autowiki"
	target_type = /obj/item/radio
	wiki_enabled = TRUE
	wiki_slug = "unit-test-autowiki"
	wiki_summary = "Pipe | summary"
	display_name = "Unit test radio"
	display_description = "Unit test description"
	type_label = "Radio"

/datum/autowiki/lore_overhaul/autowiki_test
	page = "Template:Autowiki/AphelionLore/unit-test-autowiki"
	entry_type = /datum/lore_overhaul_entry/autowiki_test

/datum/unit_test/lore_overhaul_autowiki

/datum/unit_test/lore_overhaul_autowiki/Run()
	var/datum/autowiki/lore_overhaul/autowiki = new
	var/output = autowiki.generate()
	TEST_ASSERT_EQUAL(
		output,
		"{{Autowiki/AphelionLoreEntry|id=unit_test.autowiki|name=Unit test radio|description=Unit test description|summary=Pipe {{!}} summary|type=Radio}}",
		"Lore-overhaul AutoWiki adapter did not escape or render its fixture entry correctly."
	)
#endif
