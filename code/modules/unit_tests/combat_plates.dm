/// Fits a working plate into a suit and puts it on the test subject, returning the plate.
/datum/unit_test/proc/plate_up(mob/living/carbon/human/victim, plate_type = /obj/item/armor_plate/ballistic)
	var/obj/item/clothing/suit/armor/vest/carrier = allocate(/obj/item/clothing/suit/armor/vest)
	var/obj/item/armor_plate/plate = allocate(plate_type)
	carrier.fitted_plate = plate
	plate.forceMove(carrier)
	victim.equip_to_slot(carrier, ITEM_SLOT_OCLOTHING)
	return plate

/**
 * A plate that answers an attack replaces the percentage model for that hit. D6.
 *
 * Everything up to its tolerance is stopped outright, and what gets past arrives as though nothing
 * were worn: the carrier's percentage does not get a second say. Worn armour still decides every
 * attack no plate answered.
 */
/datum/unit_test/plate_replaces_worn_armour/Run()
	var/mob/living/carbon/human/plated = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/armor_plate/plate = plate_up(plated)
	var/obj/item/bodypart/chest = plated.get_bodypart(BODY_ZONE_CHEST)

	TEST_ASSERT_EQUAL(plated.get_covering_plate(BRUTE, MELEE, chest), plate, \
		"A ballistic plate in a worn vest should answer a melee hit on the chest")

	// Half the hit nominally stopped by armour, which the plate should make irrelevant.
	var/plated_damage = plated.apply_damage(30, BRUTE, chest, blocked = 50, wound_bonus = CANT_WOUND, armour_flag = MELEE)
	TEST_ASSERT_EQUAL(plated_damage, 30 - plate.get_tolerance(), \
		"A hit through a plate should lose exactly the plate's tolerance; worn armour does not apply on top")

	var/mob/living/carbon/human/unplated = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/bare_chest = unplated.get_bodypart(BODY_ZONE_CHEST)
	TEST_ASSERT(isnull(unplated.get_covering_plate(BRUTE, MELEE, bare_chest)), "An unplated human should have no covering plate")

	var/unplated_damage = unplated.apply_damage(30, BRUTE, bare_chest, blocked = 50, wound_bonus = CANT_WOUND, armour_flag = MELEE)
	TEST_ASSERT_EQUAL(unplated_damage, 15, \
		"With no plate to answer the hit, worn armour should still reduce it by its percentage")

/// A plate is ballistic or ablative and never both, so the wrong sort of attack does not meet it at all.
/datum/unit_test/plate_answers_one_kind_of_attack/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	plate_up(victim)
	var/obj/item/bodypart/chest = victim.get_bodypart(BODY_ZONE_CHEST)

	TEST_ASSERT(victim.get_covering_plate(BRUTE, BULLET, chest), "A ballistic plate should answer a bullet")
	TEST_ASSERT(isnull(victim.get_covering_plate(BURN, LASER, chest)), "A ballistic plate should have no answer for a laser")

	// The wrong sort stops nothing, and the ballistic carrier cannot become ablative by fallback.
	var/burned = victim.apply_damage(30, BURN, chest, blocked = 50, wound_bonus = CANT_WOUND, armour_flag = LASER)
	TEST_ASSERT_EQUAL(burned, 30, "A laser on a ballistic plate should land as an unarmoured hit")

	var/obj/item/armor_plate/spent = victim.get_covering_plate(BRUTE, BULLET, chest)
	spent.durability = 0
	var/shot = victim.apply_damage(30, BRUTE, chest, blocked = 50, wound_bonus = CANT_WOUND, armour_flag = BULLET)
	TEST_ASSERT_EQUAL(shot, 30, "A spent plate should let the entire hit penetrate")

/**
 * There is no penetration stat. C6.
 *
 * Damage is penetration: a hit is either inside a plate's tolerance or it is not, and only how hard
 * it lands decides which. armour_penetration keeps every one of its references and still applies to
 * atoms; it stops applying to mobs.
 */
/datum/unit_test/armour_penetration_does_nothing_to_people/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	victim.equip_to_slot(allocate(/obj/item/clothing/suit/armor/vest), ITEM_SLOT_OCLOTHING)

	var/unpenetrated = victim.run_armor_check(BODY_ZONE_CHEST, MELEE, silent = TRUE)
	TEST_ASSERT(unpenetrated > 0, "The armour vest this test is about is not providing any melee armour")

	var/penetrated = victim.run_armor_check(BODY_ZONE_CHEST, MELEE, armour_penetration = 100, silent = TRUE)
	TEST_ASSERT_EQUAL(penetrated, unpenetrated, \
		"Armour penetration still cut a mob's armour")
