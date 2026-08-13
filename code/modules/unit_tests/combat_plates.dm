/// Fits a working plate into a suit and puts it on the test subject, returning the plate.
/datum/unit_test/proc/plate_up(mob/living/carbon/human/victim, plate_type = /obj/item/armor_plate/ballistic)
	var/obj/item/clothing/suit/armor/vest/carrier = allocate(/obj/item/clothing/suit/armor/vest)
	var/obj/item/armor_plate/plate = carrier.fitted_plate
	if(!istype(plate, plate_type))
		QDEL_NULL(carrier.fitted_plate)
		plate = new plate_type(carrier)
		carrier.fitted_plate = plate
	victim.equip_to_slot(carrier, ITEM_SLOT_OCLOTHING)
	return plate

/// Plate carriers start ready to protect their wearer.
/datum/unit_test/plate_carrier_starts_with_plate/Run()
	var/obj/item/clothing/suit/armor/vest/carrier = allocate(/obj/item/clothing/suit/armor/vest)
	TEST_ASSERT(istype(carrier.fitted_plate, /obj/item/armor_plate/ballistic), \
		"A plate carrier should spawn with a ballistic plate fitted")
	TEST_ASSERT_EQUAL(carrier.fitted_plate.loc, carrier, \
		"A plate carrier's starting plate should be contained inside it")

	var/obj/item/clothing/suit/armor/vest/capcarapace/captain_armor = allocate(/obj/item/clothing/suit/armor/vest/capcarapace)
	TEST_ASSERT(istype(captain_armor.fitted_plate, /obj/item/armor_plate/ballistic/composite), \
		"The captain's armor should spawn with a composite ballistic plate fitted")

/// Plate carriers expose only protections that are independent of their fitted plate.
/datum/unit_test/plate_carrier_has_no_legacy_combat_armour/Run()
	var/obj/item/clothing/suit/armor/vest/carrier = allocate(/obj/item/clothing/suit/armor/vest)
	for(var/combat_rating in list(MELEE, BULLET, LASER, ENERGY, BOMB, WOUND))
		TEST_ASSERT_EQUAL(carrier.get_armor_rating(combat_rating), 0, \
			"A plate carrier retained a legacy [combat_rating] armour rating")

	TEST_ASSERT(carrier.get_armor_rating(FIRE) > 0, \
		"Removing a carrier's combat armour also removed its independent fire durability")

/**
 * A matching plate replaces percentage armour for that hit.
 *
 * Everything up to its tolerance is stopped outright, and what gets past arrives as though nothing
 * were worn: the carrier's percentage does not get a second say. Worn armour still decides attacks
 * outside a plate carrier's coverage.
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

	var/mob/living/carbon/human/empty_carrier = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/clothing/suit/armor/vest/empty_vest = allocate(/obj/item/clothing/suit/armor/vest)
	QDEL_NULL(empty_vest.fitted_plate)
	empty_carrier.equip_to_slot(empty_vest, ITEM_SLOT_OCLOTHING)
	var/obj/item/bodypart/unplated_chest = empty_carrier.get_bodypart(BODY_ZONE_CHEST)
	TEST_ASSERT(isnull(empty_carrier.get_covering_plate(BRUTE, MELEE, unplated_chest)), "An empty carrier should have no covering plate")
	TEST_ASSERT(empty_carrier.has_plate_carrier_covering(unplated_chest), "An empty carrier should still own hits on the zones it covers")

	var/unplated_damage = empty_carrier.apply_damage(30, BRUTE, unplated_chest, blocked = 50, wound_bonus = CANT_WOUND, armour_flag = MELEE)
	TEST_ASSERT_EQUAL(unplated_damage, 30, \
		"An empty plate carrier should not reduce damage with its percentage armour")

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
 * A round a plate stops outright never gets far enough into the body to embed.
 *
 * A plate answers a hit in place of percentage armour, so the `blocked` an embed roll used to read is
 * zero however much the plate caught.
 */
/datum/unit_test/plate_stops_embedding/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/armor_plate/plate = plate_up(victim)
	var/obj/projectile/bullet/c38/bullet = allocate(/obj/projectile/bullet/c38)
	bullet.get_embed().embed_chance = 100

	bullet.damage = plate.get_tolerance()
	bullet.get_embed().try_embed_projectile(bullet, victim, BODY_ZONE_CHEST, blocked = 0)
	TEST_ASSERT(isnull(locate(/obj/item/shrapnel) in victim), \
		"A round the plate stopped outright still embedded")

	bullet.damage = plate.get_tolerance() + 1
	bullet.get_embed().try_embed_projectile(bullet, victim, BODY_ZONE_CHEST, blocked = 0)
	TEST_ASSERT(locate(/obj/item/shrapnel) in victim, \
		"A round heavier than the plate's tolerance failed to embed")

/**
 * Damage alone determines whether a hit exceeds plate tolerance.
 *
 * Damage is penetration: a hit is either inside a plate's tolerance or it is not, and only how hard
 * it lands decides which. armour_penetration keeps every one of its references and still applies to
 * atoms; it stops applying to mobs.
 */
/datum/unit_test/armour_penetration_does_nothing_to_people/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	victim.equip_to_slot(allocate(/obj/item/clothing/under/misc/durathread), ITEM_SLOT_ICLOTHING)

	var/unpenetrated = victim.run_armor_check(BODY_ZONE_CHEST, MELEE, silent = TRUE)
	TEST_ASSERT(unpenetrated > 0, "The armoured jumpsuit this test is about is not providing any melee armour")

	var/penetrated = victim.run_armor_check(BODY_ZONE_CHEST, MELEE, armour_penetration = 100, silent = TRUE)
	TEST_ASSERT_EQUAL(penetrated, unpenetrated, \
		"Armour penetration still cut a mob's armour")
