/// Damage totals do not kill any more. The brain, the heart and the blood do, and everything else
/// kills by ruining one of them. This walks each rung of that contract.
/datum/unit_test/death_contract
	priority = TEST_LONGER

/datum/unit_test/death_contract/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)

	// Enough brute to have killed them twice over under the old rules.
	victim.adjust_brute_loss(victim.maxHealth * 2, forced = TRUE)
	victim.updatehealth()
	TEST_ASSERT_NOTEQUAL(victim.stat, DEAD, "A human died of brute damage alone, at [victim.health] health. Nothing should die that way now")

	// Suffocation has to reach the brain to kill, so check that it gets there.
	victim.adjust_oxy_loss(OXYLOSS_BRAIN_DAMAGE_THRESHOLD, forced = TRUE)
	var/brain_damage_before = victim.get_organ_loss(ORGAN_SLOT_BRAIN)
	victim.handle_organ_lethality(seconds_per_tick = 2)
	TEST_ASSERT(victim.get_organ_loss(ORGAN_SLOT_BRAIN) > brain_damage_before, "Suffocating past the threshold did not cost the patient any brain")

	// And a dead brain is death, wherever the damage came from.
	var/obj/item/organ/brain/dying_brain = victim.get_organ_slot(ORGAN_SLOT_BRAIN)
	victim.adjust_organ_loss(ORGAN_SLOT_BRAIN, BRAIN_DAMAGE_DEATH)
	dying_brain.on_life(seconds_per_tick = 2)
	TEST_ASSERT_EQUAL(victim.stat, DEAD, "A brain past its death threshold did not kill its owner")

/// A defibrillator needs something to circulate, so an exsanguinated patient has to be transfused first.
/datum/unit_test/defib_needs_blood/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	patient.death()

	TEST_ASSERT_EQUAL(patient.can_defib(), DEFIB_POSSIBLE, "A fresh corpse should be defibrillatable")

	patient.blood_volume = DEFIB_MINIMUM_BLOOD - 1
	TEST_ASSERT_EQUAL(patient.can_defib(), DEFIB_FAIL_NO_BLOOD, "A corpse with no blood left in it was cleared for defibrillation")

	patient.blood_volume = BLOOD_VOLUME_NORMAL
	TEST_ASSERT_EQUAL(patient.can_defib(), DEFIB_POSSIBLE, "Transfusing the patient did not make them defibrillatable again")
