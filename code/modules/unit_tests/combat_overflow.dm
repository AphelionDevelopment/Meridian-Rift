/// Drives a bodypart to a Critical injury, which is what "maxed" means for overflow.
/datum/unit_test/proc/max_out_injuries(mob/living/carbon/human/victim, obj/item/bodypart/part)
	part.force_wound_upwards(/datum/wound/slash/flesh/critical)
	return part.is_injury_capacity_maxed()

/**
 * A monster hit can ruin a part. The kill starts on the hit after it, never inside the same one.
 *
 * This is the rule that stops overflow being an instakill, so it gets asserted on its own before
 * anything else about overflow is worth testing.
 */
/datum/unit_test/overflow_never_within_a_hit/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/head = victim.get_bodypart(BODY_ZONE_HEAD)

	// One tier short of maxed, so this hit is the one that could ruin the head.
	head.force_wound_upwards(/datum/wound/slash/flesh/severe)
	TEST_ASSERT(!head.is_injury_capacity_maxed(), "A severe injury is not a maxed one - only Critical is")

	victim.apply_damage(60, BRUTE, head, sharpness = SHARP_EDGED)
	TEST_ASSERT_EQUAL(victim.get_organ_loss(ORGAN_SLOT_BRAIN), 0, \
		"The hit that ruined the head also reached the brain - overflow has to start on the next hit")

/// Once a part is maxed, penetrating hits go to what it was protecting. Head to brain, chest to heart.
/datum/unit_test/overflow_reaches_the_organs/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/head = victim.get_bodypart(BODY_ZONE_HEAD)
	TEST_ASSERT(max_out_injuries(victim, head), "Failed to give the patient the critical head injury this test is about")

	victim.apply_damage(30, BRUTE, head, sharpness = SHARP_EDGED)
	TEST_ASSERT(victim.get_organ_loss(ORGAN_SLOT_BRAIN) > 0, "A hit on a ruined head left the brain untouched")

	var/mob/living/carbon/human/second_victim = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/chest = second_victim.get_bodypart(BODY_ZONE_CHEST)
	TEST_ASSERT(max_out_injuries(second_victim, chest), "Failed to give the patient the critical chest injury this test is about")

	second_victim.apply_damage(30, BRUTE, chest, sharpness = SHARP_EDGED)
	TEST_ASSERT(second_victim.get_organ_loss(ORGAN_SLOT_HEART) > 0, "A hit on a ruined chest left the heart untouched")

/// Nobody is executed through a working plate. Break the armour or strip the helmet first.
/datum/unit_test/overflow_needs_penetration/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/head = victim.get_bodypart(BODY_ZONE_HEAD)
	TEST_ASSERT(max_out_injuries(victim, head), "Failed to give the patient the critical head injury this test is about")

	for(var/hit in 1 to 5)
		victim.apply_damage(30, BRUTE, head, blocked = WOUND_NONPENETRATING_BLOCK, sharpness = SHARP_EDGED)

	TEST_ASSERT_EQUAL(victim.get_organ_loss(ORGAN_SLOT_BRAIN), 0, \
		"Hits that armour stopped overflowed into the brain - a working plate cannot be killed through")

/// Enough overflow into a head kills, and the corpse is as recoverable as any other brain death.
/datum/unit_test/overflow_eventually_kills/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/head = victim.get_bodypart(BODY_ZONE_HEAD)
	var/obj/item/organ/brain = victim.get_organ_slot(ORGAN_SLOT_BRAIN)
	TEST_ASSERT(max_out_injuries(victim, head), "Failed to give the patient the critical head injury this test is about")

	// Deliberately a count rather than one huge hit: the doc's whole point is that confirming a kill
	// costs most of a magazine. Kept small enough per hit that the total brute stays under the
	// separate tissue-damage limit on defibrillation, so the assertion below is about the brain alone.
	var/hits = 0
	while(victim.get_organ_loss(ORGAN_SLOT_BRAIN) < brain.maxHealth && hits < 20)
		victim.apply_damage(20, BRUTE, head, sharpness = SHARP_EDGED)
		hits++

	TEST_ASSERT(hits > 1, "A ruined head took a single hit to reach brain death - no hit should kill on its own")
	TEST_ASSERT(hits < 20, "Twenty overflowing hits to a ruined head still did not fill the brain")
	TEST_ASSERT(victim.get_brute_loss() < MAX_REVIVE_BRUTE_DAMAGE, \
		"This test landed enough brute to block defibrillation on its own, which would make the check below meaningless")
	brain.on_life(seconds_per_tick = 2)
	TEST_ASSERT_EQUAL(victim.stat, DEAD, "A brain filled by overflow did not kill its owner")
	TEST_ASSERT_EQUAL(victim.can_defib(), DEFIB_FAIL_FAILING_BRAIN, \
		"An overflow kill should need the brain repaired before a defibrillator means anything")

/**
 * The hole phase 4 left open on purpose: nothing died of accumulated burn any more.
 *
 * Overflow is the way back, and burning arrives as a great many small ticks rather than as hits, so
 * it has to work at that size or a body can burn indefinitely with a working heart in it.
 */
/datum/unit_test/overflow_closes_the_burn_hole/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/chest = victim.get_bodypart(BODY_ZONE_CHEST)

	chest.force_wound_upwards(/datum/wound/burn/flesh/critical)
	TEST_ASSERT(chest.is_injury_capacity_maxed(), "Failed to give the patient the critical burn this test is about")

	// Roughly a tick of standing in a fire, ten times over.
	for(var/tick in 1 to 10)
		victim.apply_damage(4, BURN, chest)

	TEST_ASSERT(victim.get_organ_loss(ORGAN_SLOT_HEART) > 0, \
		"Burning never reached the heart of a patient whose chest was already ruined - nothing would burn to death")

/// A finisher is for someone who has already stopped being able to stop it. Anyone still upright is not that.
/datum/unit_test/finisher_needs_a_helpless_target/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/killer = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/knife = allocate(/obj/item/knife/combat)

	killer.put_in_active_hand(knife)
	killer.set_combat_mode(TRUE)
	killer.zone_selected = BODY_ZONE_HEAD

	TEST_ASSERT(!victim.is_at_mercy(), "A healthy standing human should not be at anyone's mercy")
	TEST_ASSERT(!victim.try_finisher(killer, knife), "A finisher was allowed on a target who was still standing")

	victim.Paralyze(10 SECONDS)
	TEST_ASSERT(victim.is_at_mercy(), "A paralysed human should be at the attacker's mercy")

/// Restraint tools cannot execute. That is the whole difference between arresting someone and killing them.
/datum/unit_test/finisher_needs_a_lethal_weapon/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/killer = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/baton = allocate(/obj/item/melee/baton/security)

	killer.put_in_active_hand(baton)
	killer.set_combat_mode(TRUE)
	killer.zone_selected = BODY_ZONE_HEAD
	victim.Paralyze(10 SECONDS)

	TEST_ASSERT(!baton.is_lethal_enough_to_finish(), "A stun baton should not count as a lethal weapon")
	TEST_ASSERT(!victim.try_finisher(killer, baton), "A finisher was allowed with a stun baton")
