/// Drives a bodypart to a Critical injury, which is what "maxed" means to overflow.
/datum/unit_test/proc/max_out_injuries(mob/living/carbon/human/victim, obj/item/bodypart/part)
	part.force_wound_upwards(/datum/wound/slash/flesh/critical)
	return part.is_injury_capacity_maxed()

/**
 * A single hit can ruin a part. The kill starts on the hit after it, never inside the same one.
 *
 * This is the rule that stops overflow being an instakill, so it is asserted on its own.
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

/**
 * A body with no heart in it still has to be killable through the torso.
 *
 * Skeletons and jellypeople carry no heart at all, so the chest's usual overflow target is not there.
 * With nothing to fall back on, their torsos absorbed penetrating hits forever and only the head was
 * worth aiming at.
 */
/datum/unit_test/overflow_reaches_a_heartless_body/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	victim.set_species(/datum/species/jelly)
	TEST_ASSERT(isnull(victim.get_organ_slot(ORGAN_SLOT_HEART)), "Failed to allocate the heartless patient this test is about")

	var/obj/item/bodypart/chest = victim.get_bodypart(BODY_ZONE_CHEST)
	TEST_ASSERT(max_out_injuries(victim, chest), "Failed to give the patient the critical chest injury this test is about")

	victim.apply_damage(30, BRUTE, chest, sharpness = SHARP_EDGED)
	TEST_ASSERT(victim.get_organ_loss(ORGAN_SLOT_BRAIN) > 0, \
		"A hit on the ruined chest of a heartless body went nowhere")

/**
 * Once a part's injuries stack up, what is inside it starts taking hits, not only that part's own
 * overflow target. Which organ is random for now, so this asserts that something other than the
 * head's overflow target eventually gets hurt.
 */
/datum/unit_test/overflow_reaches_other_organs/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/head = victim.get_bodypart(BODY_ZONE_HEAD)
	TEST_ASSERT(max_out_injuries(victim, head), "Failed to give the patient the critical head injury this test is about")

	// Enough hits that a random pick across the head's organs is not going to miss all of them.
	for(var/hit in 1 to 20)
		victim.apply_damage(10, BRUTE, head, sharpness = SHARP_EDGED)

	var/collateral = victim.get_organ_loss(ORGAN_SLOT_EYES) \
		+ victim.get_organ_loss(ORGAN_SLOT_EARS) \
		+ victim.get_organ_loss(ORGAN_SLOT_TONGUE)
	TEST_ASSERT(collateral > 0, \
		"Twenty hits on a ruined head never touched an eye, an ear or a tongue - organs in a stacked part should take hits")

/**
 * A bruise is never lethal, however bad it gets.
 *
 * Capacity is read off the injury track, so any Critical injury would open a part up to being killed
 * through it. Appendix A excludes bruises, via allows_overflow on the datum.
 */
/datum/unit_test/overflow_ignores_bruises/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/head = victim.get_bodypart(BODY_ZONE_HEAD)

	head.force_wound_upwards(/datum/wound/bruise/critical)
	TEST_ASSERT(head.get_wound_type(/datum/wound/bruise/critical), "Failed to give the patient the contusion this test is about")
	TEST_ASSERT(!head.is_injury_capacity_maxed(), "A contusion is still only a bruise, and should not max a bodypart's injury capacity")

	// Anything not excluded still counts, or the flag would be a way of turning overflow off.
	head.force_wound_upwards(/datum/wound/slash/flesh/critical)
	TEST_ASSERT(head.is_injury_capacity_maxed(), "A critical laceration should still max a bodypart's injury capacity")

/// Nobody can be killed through a working plate; the armour has to be broken first.
/datum/unit_test/overflow_needs_penetration/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/armor_plate/plate = plate_up(victim)
	var/obj/item/bodypart/chest = victim.get_bodypart(BODY_ZONE_CHEST)
	TEST_ASSERT(max_out_injuries(victim, chest), "Failed to give the patient the critical chest injury this test is about")

	// Inside the plate's tolerance, so every one of these is stopped outright.
	for(var/hit in 1 to 5)
		victim.apply_damage(plate.get_tolerance(), BRUTE, chest, sharpness = SHARP_EDGED, armour_flag = MELEE)

	TEST_ASSERT(plate.is_working(), "The plate this test is about broke partway through")
	TEST_ASSERT_EQUAL(victim.get_organ_loss(ORGAN_SLOT_HEART), 0, \
		"Hits a plate stopped overflowed into the heart - a working plate cannot be killed through")

/**
 * Worn percentage armour slows overflow down; it does not switch it off.
 *
 * NP/P was stubbed off `blocked` before plates existed, so any rating at or above 50% made a zone
 * permanently unkillable: the captain's carapace sat exactly on that line and lasers to the chest
 * piled up burn forever without ever reaching the heart. Only a plate is non-penetrating now.
 */
/datum/unit_test/overflow_ignores_percentage_armour/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/chest = victim.get_bodypart(BODY_ZONE_CHEST)
	TEST_ASSERT(max_out_injuries(victim, chest), "Failed to give the patient the critical chest injury this test is about")

	victim.apply_damage(30, BRUTE, chest, blocked = 50, sharpness = SHARP_EDGED)

	TEST_ASSERT(victim.get_organ_loss(ORGAN_SLOT_HEART) > 0, \
		"A hit through half armour left the heart untouched - percentage armour is damage reduction, not a plate")

/// Enough overflow into a head kills, and the corpse is as recoverable as any other brain death.
/datum/unit_test/overflow_eventually_kills/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/head = victim.get_bodypart(BODY_ZONE_HEAD)
	var/obj/item/organ/brain = victim.get_organ_slot(ORGAN_SLOT_BRAIN)
	TEST_ASSERT(max_out_injuries(victim, head), "Failed to give the patient the critical head injury this test is about")

	// A count rather than one huge hit, since confirming a kill is meant to cost most of a magazine.
	// Kept small enough per hit that the total brute stays under the separate tissue-damage limit on
	// defibrillation, so the assertion below is about the brain alone.
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
 * The gap phase 4 left open: nothing died of accumulated burn any more.
 *
 * Overflow is the route back, and burning arrives as many small ticks rather than as hits, so it has
 * to work at that size or a body can burn indefinitely with a working heart in it.
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

/**
 * The artery is defined by its pain factor rather than its severity: Light, where everything else
 * this lethal is Severe or Extreme. That gap is what gets asserted.
 */
/datum/unit_test/artery_is_the_killer_you_dont_feel/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	var/datum/pain/pain = victim.pain_controller
	var/obj/item/bodypart/leg = victim.get_bodypart(BODY_ZONE_L_LEG)

	leg.force_wound_upwards(/datum/wound/slash/flesh/artery)
	var/datum/wound/severed = leg.get_wound_type(/datum/wound/slash/flesh/artery)
	TEST_ASSERT(severed, "Failed to give the patient the severed artery this test is about")

	TEST_ASSERT_EQUAL(severed.severity, WOUND_SEVERITY_CRITICAL, "A severed artery should be a critical injury")
	TEST_ASSERT_EQUAL(severed.pain_factor, PAIN_FACTOR_LIGHT, \
		"A severed artery should carry Light pain despite being a critical injury")
	TEST_ASSERT_EQUAL(pain.pain_floor, PAIN_FACTOR_LIGHT, "The pain floor should carry only what the artery costs")
	TEST_ASSERT(severed.blood_flow > 0, "A severed artery should be bleeding")

	// A tourniquet buys time. Closing the vessel is a surgeon's job.
	var/bleed_rate_before = leg.cached_bleed_rate
	TEST_ASSERT(bleed_rate_before > 0, "The limb should be bleeding with a severed artery in it")

	var/obj/item/tourniquet/clamp = allocate(/obj/item/tourniquet)
	leg.apply_item(clamp, LIMB_ITEM_TOURNIQUET)
	TEST_ASSERT(leg.cached_bleed_rate < bleed_rate_before, "A tourniquet should slow the bleeding from an artery")
	TEST_ASSERT(leg.get_wound_type(/datum/wound/slash/flesh/artery), \
		"A tourniquet should only slow the artery, never close it")

/// A finisher needs a target that can no longer prevent it. Anyone still upright can.
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

/// Restraint tools cannot finish anyone off, whatever their force.
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

/**
 * An artery is not what takes a limb off.
 *
 * Appendix B's dismemberment rule is a Critical fracture or laceration plus a high-damage penetrating
 * hit. An artery is Critical too, but the limb around it is structurally intact, so counting it would
 * amputate the patient instead of letting them bleed.
 */
/datum/unit_test/artery_does_not_take_the_limb/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/leg = victim.get_bodypart(BODY_ZONE_L_LEG)

	leg.force_wound_upwards(/datum/wound/slash/flesh/artery)
	TEST_ASSERT(leg.get_wound_type(/datum/wound/slash/flesh/artery), "Failed to give the patient the severed artery this test is about")
	TEST_ASSERT(!leg.is_injury_capacity_maxed(), "A severed artery should not count as a limb having nothing left to give")

	victim.apply_damage(60, BRUTE, leg, sharpness = SHARP_EDGED)
	TEST_ASSERT(victim.get_bodypart(BODY_ZONE_L_LEG), "A solid hit on a leg with a severed artery took the leg off")
