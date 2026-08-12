/// Field treatment counts: a wrapped or splinted injury is a tier quieter than an untreated one.
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

/// The floor is a cached sum, so everything that changes what an injury costs has to invalidate it.
/// Treating one especially: a floor still counting a healed wound is a crawl nobody can lift.
/datum/unit_test/pain_floor_tracks_treatment/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/datum/pain/pain = patient.pain_controller
	TEST_ASSERT(pain, "The test subject has no pain controller")

	var/obj/item/bodypart/arm = patient.get_bodypart(BODY_ZONE_R_ARM)
	arm.force_wound_upwards(/datum/wound/blunt/bone/severe)
	TEST_ASSERT_EQUAL(pain.pain_floor, PAIN_FACTOR_SEVERE, "A fresh fracture should put its pain factor onto the floor")

	// Wrapping a limb changes what its injuries cost without adding or removing one, so it only marks
	// the floor stale rather than rebuilding on the spot.
	var/obj/item/stack/medical/wrap/gauze/wrap = allocate(/obj/item/stack/medical/wrap/gauze)
	arm.apply_item(wrap, LIMB_ITEM_GAUZE)
	TEST_ASSERT(pain.floor_needs_recalculation, "Wrapping a limb should mark the floor for a rebuild")
	pain.recalculate_floor()
	TEST_ASSERT_EQUAL(pain.pain_floor, PAIN_FACTOR_MODERATE, "A wrapped fracture should cost a tier less floor than a bare one")

	var/datum/wound/fracture = arm.get_wound_type(/datum/wound/blunt/bone/severe)
	fracture.remove_wound()
	TEST_ASSERT_EQUAL(pain.pain_floor, 0, "Treating the injury did not take its pain off the floor with it")

/// A fresh hit blacks a crawler out again without clearing the floor holding them down.
/datum/unit_test/pain_crawler_blackout/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	var/datum/pain/pain = victim.pain_controller
	TEST_ASSERT(pain, "The test subject has no pain controller")

	// A floor at the cap needs more than one bodypart, since no single one can reach it alone.
	victim.add_pain_source("test_chest", PAIN_CAP_CHEST, BODY_ZONE_CHEST)
	victim.add_pain_source("test_arm", PAIN_CAP_LIMB, BODY_ZONE_R_ARM)

	TEST_ASSERT(victim.has_status_effect(/datum/status_effect/pain_crawl), "A floor at the cap should leave the mob crawling")
	TEST_ASSERT(!victim.has_status_effect(/datum/status_effect/incapacitating/pain_shock), "A floor at the cap should not black the mob out, as there is nothing to drain")

	victim.add_temporary_pain(DAMAGE_PRECISION)
	TEST_ASSERT(victim.has_status_effect(/datum/status_effect/incapacitating/pain_shock), "A fresh hit on a crawler should black them out again")
	TEST_ASSERT(victim.has_status_effect(/datum/status_effect/pain_crawl), "Blacking out should not clear the floor that was holding them down")

	// The hard ceiling drains whatever is needed for normal recovery, even against a ruined heart.
	var/obj/item/organ/heart/heart = victim.get_organ_slot(ORGAN_SLOT_HEART)
	heart.set_organ_damage(heart.maxHealth)
	pain.update_heart_strain()
	pain.blackout_ends_at = world.time
	pain.process(1)
	TEST_ASSERT(!victim.has_status_effect(/datum/status_effect/incapacitating/pain_shock), "The blackout should lift once the fresh pain has drained")
	TEST_ASSERT(victim.has_status_effect(/datum/status_effect/pain_crawl), "Draining the pool should not stand a mob up whose floor is still at the cap")

	// Lowering the floor is the only way out of the crawl.
	victim.remove_pain_source("test_chest")
	TEST_ASSERT(!victim.has_status_effect(/datum/status_effect/pain_crawl), "Lowering the floor should let the mob off the ground")

/// The crawl is a soft crit that leaves the hands usable. Reaching your own pockets is the only way
/// out of a floor at the cap, so taking the crawler's hands is a soft lock.
/datum/unit_test/pain_crawl_keeps_hands/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)

	victim.add_pain_source("test_chest", PAIN_CAP_CHEST, BODY_ZONE_CHEST)
	victim.add_pain_source("test_arm", PAIN_CAP_LIMB, BODY_ZONE_R_ARM)

	TEST_ASSERT(victim.has_status_effect(/datum/status_effect/pain_crawl), "A floor at the cap should leave the mob crawling")
	TEST_ASSERT_EQUAL(victim.stat, SOFT_CRIT, "The crawl should put the mob in soft crit")
	TEST_ASSERT(HAS_TRAIT(victim, TRAIT_FLOORED), "A crawler should not be able to stand")
	TEST_ASSERT(!HAS_TRAIT(victim, TRAIT_HANDS_BLOCKED), "A crawler cannot reach their own injector with their hands blocked")
	TEST_ASSERT(!HAS_TRAIT(victim, TRAIT_INCAPACITATED), "A crawler cannot treat themselves while incapacitated")

	var/obj/item/held_injector = allocate(/obj/item/reagent_containers/hypospray/medipen)
	victim.put_in_hands(held_injector)
	TEST_ASSERT(!(SEND_SIGNAL(victim, COMSIG_MOB_CLICKON, victim, list()) & COMSIG_MOB_CANCEL_CLICKON), \
		"A crawler was prevented from treating their own body")
	TEST_ASSERT(!(SEND_SIGNAL(victim, COMSIG_MOB_CLICKON, held_injector, list()) & COMSIG_MOB_CANCEL_CLICKON), \
		"A crawler was prevented from using an item in their own hands")
	var/obj/item/external_item = allocate(/obj/item/crowbar)
	TEST_ASSERT(SEND_SIGNAL(victim, COMSIG_MOB_CLICKON, external_item, list()) & COMSIG_MOB_CANCEL_CLICKON, \
		"A crawler could interact with something outside their own body and equipment")

	// The exception belongs to the crawl alone; every other soft crit is as helpless as before.
	victim.remove_pain_source("test_chest")
	victim.remove_pain_source("test_arm")
	victim.set_blood_volume(BLOOD_VOLUME_BAD - 1)
	victim.updatehealth()
	TEST_ASSERT_EQUAL(victim.stat, SOFT_CRIT, "Bleeding out past BLOOD_VOLUME_BAD should still soft crit")
	TEST_ASSERT(HAS_TRAIT(victim, TRAIT_HANDS_BLOCKED), "Soft crit from bloodloss should still take the patient's hands")

/**
 * Being put down by pain must not cost you air.
 *
 * The breath loop reads the crit ladder, and pain owns two rungs of it now. If the rung alone stopped
 * a mob breathing then every stun would feed oxyloss, which phase 4 routes into brain damage, making
 * stunlocking a way of killing someone.
 */
/datum/unit_test/pain_does_not_suffocate/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)

	victim.add_temporary_pain(PAIN_SHOCK_THRESHOLD)
	TEST_ASSERT_EQUAL(victim.stat, HARD_CRIT, "A pain spike at the cap should hard crit the mob")
	TEST_ASSERT(victim.can_recover_breath(), "A mob put down by pain has working lungs and must keep breathing")

	// A heavy beating is not a breathing problem either, now that damage totals decide nothing.
	victim.apply_damage(60, BRUTE, BODY_ZONE_CHEST, wound_bonus = CANT_WOUND)
	TEST_ASSERT(victim.can_recover_breath(), "Brute damage should not stop a patient clearing an oxygen debt")

	// The states that genuinely are a breathing emergency still are.
	victim.set_heartattack(TRUE)
	TEST_ASSERT(!victim.can_recover_breath(), "Cardiac arrest should still stop a patient clearing an oxygen debt")
	victim.set_heartattack(FALSE)

	victim.set_blood_volume(BLOOD_VOLUME_BAD - 1)
	TEST_ASSERT(!victim.can_recover_breath(), "Bleeding out should still stop a patient clearing an oxygen debt")

/// Temporary pain must only slow a human through the FELT-pain bracket modifier. The legacy health
/// slowdown reads stamina, which is raw temporary pain for these mobs, and would bypass dampeners.
/datum/unit_test/pain_slowdown_uses_felt_pain/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)

	victim.add_temporary_pain(40)
	victim.updatehealth()

	TEST_ASSERT_EQUAL(victim.get_stamina_loss(), 40, "The test did not create enough temporary pain to trigger the old slowdown path")
	TEST_ASSERT(!victim.has_movespeed_modifier(/datum/movespeed_modifier/damage_slowdown), \
		"Raw temporary pain applied the legacy health slowdown instead of relying on the FELT-pain bracket")

/**
 * Everything that hands out TRAIT_ANALGESIA is a numeric dampener, never pain immunity.
 *
 * Painkillers are graded, as are the cocktails, implants and gene mods that grant the same trait.
 * An otherwise ungraded source falls back to a strong finite value.
 */
/datum/unit_test/pain_graded_analgesia/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/datum/pain/pain = patient.pain_controller
	TEST_ASSERT(pain, "The test subject has no pain controller")

	patient.add_pain_source("test_chest", PAIN_CAP_CHEST, BODY_ZONE_CHEST)
	patient.add_pain_source("test_arm", PAIN_CAP_LIMB, BODY_ZONE_R_ARM)
	TEST_ASSERT_EQUAL(pain.felt_pain, PAIN_SHOCK_THRESHOLD, "A floor at the cap should be felt in full before anything numbs it")

	patient.apply_status_effect(/datum/status_effect/rev_resilience)
	pain.update_dampening()
	TEST_ASSERT(HAS_TRAIT(patient, TRAIT_ANALGESIA), "The cocktail this test is about did not grant analgesia")
	TEST_ASSERT_EQUAL(pain.dampening, PAIN_DAMPEN_ALCOHOL, "A cocktail should dampen pain by its own value rather than numbing entirely")
	TEST_ASSERT_EQUAL(pain.felt_pain, PAIN_SHOCK_THRESHOLD - PAIN_DAMPEN_ALCOHOL, "A graded painkiller hid more pain than it is worth")

	patient.remove_status_effect(/datum/status_effect/rev_resilience)
	ADD_TRAIT(patient, TRAIT_ANALGESIA, TRAIT_GENERIC)
	pain.update_dampening()
	TEST_ASSERT_EQUAL(pain.base_dampening, PAIN_DAMPEN_STRONG, "An ungraded analgesia trait granted total pain immunity")
	TEST_ASSERT(pain.felt_pain > 0, "An ungraded analgesia trait made the patient unable to feel pain")

/// Appendix B puts Extreme pain on a missing limb. The loss wound cannot carry it, since the limb it
/// was applied to is gone by the time the floor is rebuilt, so the empty socket does.
/datum/unit_test/pain_missing_limb/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	var/datum/pain/pain = victim.pain_controller
	TEST_ASSERT(pain, "The test subject has no pain controller")

	victim.get_bodypart(BODY_ZONE_R_ARM).dismember()
	TEST_ASSERT(isnull(victim.get_bodypart(BODY_ZONE_R_ARM)), "Failed to take the arm this test is about")
	TEST_ASSERT_EQUAL(pain.pain_floor, PAIN_CAP_LIMB, "Losing an arm should cost that limb's entire share of the pain floor")

/**
 * Adrenaline delays pain shock. It never cancels it.
 *
 * Fight or flight continuously halves felt pain for its duration. It delays shock, but enough raw
 * pain can still fill the felt meter because the floor and temporary pool have independent caps.
 */
/datum/unit_test/pain_adrenaline_delays_shock/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	var/datum/pain/pain = victim.pain_controller
	TEST_ASSERT(pain, "The test subject has no pain controller")

	// One huge hit: enough to trigger fight or flight, not enough to reach the cap on its own.
	victim.add_temporary_pain(PAIN_ADRENALINE_SPIKE_TRIGGER)
	TEST_ASSERT(victim.has_status_effect(/datum/status_effect/adrenaline), "A massive spike should trigger adrenaline")
	pain.update_dampening()
	TEST_ASSERT(pain.dampening > 0, "Adrenaline should be hiding some of what the mob is already carrying")
	TEST_ASSERT(pain.felt_pain < PAIN_SHOCK_THRESHOLD, "Adrenaline should keep a survivable spike survivable")

	// New pain is halved too. Enough injuries plus a full pool must still be able to reach shock.
	victim.add_pain_source("test_chest", PAIN_CAP_CHEST, BODY_ZONE_CHEST)
	victim.add_pain_source("test_arm", PAIN_CAP_LIMB, BODY_ZONE_R_ARM)
	victim.add_temporary_pain(PAIN_TEMPORARY_MAXIMUM)
	TEST_ASSERT_EQUAL(pain.felt_pain, PAIN_SHOCK_THRESHOLD, "Adrenaline cancelled pain shock instead of delaying it")
	TEST_ASSERT(pain.in_shock, "A mob past the cap on adrenaline should still black out")

	pain.adjust_temporary_pain(-40)
	var/felt_before_hit = pain.felt_pain
	victim.add_temporary_pain(20)
	TEST_ASSERT_EQUAL(pain.felt_pain - felt_before_hit, 10, "Pain gained during adrenaline was not halved")

/**
 * A surgical anaesthetic needs a full dose, not a sip.
 *
 * Total numbness means no shock, no crawl and no finisher, so anything carrying it has to be gated on
 * enough being present to put someone under, or it is the cheapest stun immunity in the game.
 */
/datum/unit_test/pain_anaesthetic_needs_a_dose/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/datum/pain/pain = patient.pain_controller
	TEST_ASSERT(pain, "The test subject has no pain controller")

	patient.add_pain_source("test_chest", PAIN_CAP_CHEST, BODY_ZONE_CHEST)

	patient.reagents.add_reagent(/datum/reagent/nitrous_oxide, PAIN_DAMPEN_ANAESTHETIC_DOSE - 1)
	pain.update_dampening()
	TEST_ASSERT_EQUAL(pain.dampening, 0, "A sip of anaesthetic numbed the patient")

	patient.reagents.add_reagent(/datum/reagent/nitrous_oxide, 1)
	pain.update_dampening()
	TEST_ASSERT_EQUAL(pain.base_dampening, PAIN_DAMPEN_TOTAL, "A full dose of anaesthetic should provide full-strength dampening")
	TEST_ASSERT_EQUAL(pain.felt_pain, 0, "A full dose of anaesthetic should numb the patient's current pain completely")

/**
 * A body that comes apart easily takes more damage, not more stun.
 *
 * Impact pain reads the lesser of what an attack delivered and what the body made of it. A species on
 * a damage multiplier still pays for it in injuries, but its stun is the blow that was struck: a
 * holosynth is on five times burn and would otherwise be in pain shock from the first thing to touch
 * it. Resistance still quiets a hit, since there the lesser figure is what the body took.
 */
/datum/unit_test/pain_ignores_fragility/Run()
	var/mob/living/carbon/human/baseline = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/fragile = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/resistant = allocate(/mob/living/carbon/human/consistent)
	fragile.physiology.burn_mod *= 5
	resistant.physiology.burn_mod *= 0.5

	baseline.apply_damage(20, BURN, baseline.get_bodypart(BODY_ZONE_CHEST))
	fragile.apply_damage(20, BURN, fragile.get_bodypart(BODY_ZONE_CHEST))
	resistant.apply_damage(20, BURN, resistant.get_bodypart(BODY_ZONE_CHEST))

	TEST_ASSERT(fragile.get_fire_loss() > baseline.get_fire_loss(), "The fragile patient should still have taken more burn damage")
	TEST_ASSERT_EQUAL(fragile.pain_controller.temporary_pain, baseline.pain_controller.temporary_pain, \
		"A damage multiplier multiplied the stun along with the damage")

	TEST_ASSERT(resistant.get_fire_loss() < baseline.get_fire_loss(), "The resistant patient should have taken less burn damage")
	TEST_ASSERT(resistant.pain_controller.temporary_pain < baseline.pain_controller.temporary_pain, \
		"A hit that a body shrugged off should hurt it less")
