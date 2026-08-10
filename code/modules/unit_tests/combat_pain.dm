/// Field treatment counts. A wrapped or splinted injury is a tier quieter than an untreated one,
/// which is what lets a medic put someone back on their feet without a surgeon.
/datum/unit_test/pain_treatment/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/arm = patient.get_bodypart(BODY_ZONE_R_ARM)

	arm.force_wound_upwards(/datum/wound/blunt/bone/severe)
	var/datum/wound/fracture = arm.get_wound_type(/datum/wound/blunt/bone/severe)
	TEST_ASSERT(fracture, "Failed to give the patient the fracture this test is about")
	TEST_ASSERT_EQUAL(fracture.get_pain_factor(), PAIN_FACTOR_SEVERE, "An untreated fracture should hurt its full amount")

	var/obj/item/stack/medical/wrap/gauze/wrap = allocate(/obj/item/stack/medical/wrap/gauze)
	arm.apply_item(wrap, LIMB_ITEM_GAUZE)
	TEST_ASSERT_EQUAL(fracture.get_pain_factor(), PAIN_FACTOR_MODERATE, "A splinted fracture should drop a tier of pain")

	// Criticals are the exception: a splint stops a compound fracture getting worse, nothing more.
	arm.force_wound_upwards(/datum/wound/blunt/bone/critical)
	var/datum/wound/compound = arm.get_wound_type(/datum/wound/blunt/bone/critical)
	TEST_ASSERT(compound, "Failed to escalate the fracture to a compound one")
	TEST_ASSERT_EQUAL(compound.get_pain_factor(), PAIN_FACTOR_EXTREME, "A splint should not quiet a compound fracture")

/// Fresh hits always black you out again: shoot a crawler and they go limp, stir, then drag on.
/datum/unit_test/pain_crawler_blackout/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	var/datum/pain/pain = victim.pain_controller
	TEST_ASSERT(pain, "The test subject has no pain controller")

	// A floor at the cap needs more than one bodypart, since no single one can reach it alone.
	victim.add_pain_source("test_chest", PAIN_CAP_CHEST, BODY_ZONE_CHEST)
	victim.add_pain_source("test_arm", PAIN_CAP_LIMB, BODY_ZONE_R_ARM)

	TEST_ASSERT(victim.has_status_effect(/datum/status_effect/pain_crawl), "A floor at the cap should leave the mob crawling")
	TEST_ASSERT(!victim.has_status_effect(/datum/status_effect/incapacitating/pain_shock), "A floor at the cap should not black the mob out - there is nothing to drain")

	victim.add_temporary_pain(PAIN_SHOCK_BLACKOUT_MINIMUM)
	TEST_ASSERT(victim.has_status_effect(/datum/status_effect/incapacitating/pain_shock), "A fresh hit on a crawler should black them out again")
	TEST_ASSERT(victim.has_status_effect(/datum/status_effect/pain_crawl), "Blacking out should not clear the floor that was holding them down")

	pain.adjust_temporary_pain(-PAIN_TEMPORARY_MAXIMUM)
	TEST_ASSERT(!victim.has_status_effect(/datum/status_effect/incapacitating/pain_shock), "The blackout should lift once the fresh pain has drained")
	TEST_ASSERT(victim.has_status_effect(/datum/status_effect/pain_crawl), "Draining the pool should not stand a mob up whose floor is still at the cap")

	// Treating the source is the only way out of the crawl.
	victim.remove_pain_source("test_chest")
	TEST_ASSERT(!victim.has_status_effect(/datum/status_effect/pain_crawl), "Lowering the floor should let the mob off the ground")

/// The crawl is a soft crit you can still use your hands in. Dragging yourself to your own pockets is
/// the only way out of a floor at the cap, so anything that takes the crawler's hands is a soft lock.
/datum/unit_test/pain_crawl_keeps_hands/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)

	victim.add_pain_source("test_chest", PAIN_CAP_CHEST, BODY_ZONE_CHEST)
	victim.add_pain_source("test_arm", PAIN_CAP_LIMB, BODY_ZONE_R_ARM)

	TEST_ASSERT(victim.has_status_effect(/datum/status_effect/pain_crawl), "A floor at the cap should leave the mob crawling")
	TEST_ASSERT_EQUAL(victim.stat, SOFT_CRIT, "The crawl should put the mob in soft crit")
	TEST_ASSERT(HAS_TRAIT(victim, TRAIT_FLOORED), "A crawler should not be able to stand")
	TEST_ASSERT(!HAS_TRAIT(victim, TRAIT_HANDS_BLOCKED), "A crawler cannot reach their own injector with their hands blocked")
	TEST_ASSERT(!HAS_TRAIT(victim, TRAIT_INCAPACITATED), "A crawler cannot treat themselves while incapacitated")

	// The exception is only the crawl's: every other soft crit is as helpless as it ever was.
	victim.remove_pain_source("test_chest")
	victim.remove_pain_source("test_arm")
	victim.set_blood_volume(BLOOD_VOLUME_BAD - 1)
	victim.updatehealth()
	TEST_ASSERT_EQUAL(victim.stat, SOFT_CRIT, "Bleeding out past BLOOD_VOLUME_BAD should still soft crit")
	TEST_ASSERT(HAS_TRAIT(victim, TRAIT_HANDS_BLOCKED), "Soft crit from bloodloss should still take the patient's hands")
