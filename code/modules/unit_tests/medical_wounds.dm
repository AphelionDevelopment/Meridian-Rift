/// The worst severity among every wound this mob is carrying, or -1 if it has none.
/datum/unit_test/proc/get_worst_wound_severity(mob/living/carbon/victim)
	var/worst = -1
	for(var/datum/wound/carried as anything in victim.all_wounds)
		worst = max(worst, carried.severity)
	return worst

/// Wound series are exclusive: a limb may carry a fracture and a bruise, but never two fractures.
/datum/unit_test/proc/assert_one_wound_per_series(mob/living/carbon/victim)
	var/list/seen_series = list()
	for(var/datum/wound/carried as anything in victim.all_wounds)
		var/datum/wound_pregen_data/pregen_data = GLOB.all_wound_pregen_data[carried.type]
		if(pregen_data.wound_series in seen_series)
			TEST_FAIL("Patient carries two wounds of the same series ([pregen_data.wound_series]) at once")
		seen_series += pregen_data.wound_series

/**
 * Checks that a flesh-and-bone human suffers every type of wound, that injuries escalate a tier at a
 * time as damage accumulates, and that fully_heal clears them.
 *
 * Injuries are deterministic: damage piles up on the bodypart and crossing a threshold causes an
 * injury of that tier, every time. Which wound datum lands at that tier is still random, so this
 * asserts the tier rather than the typepath.
 */
/datum/unit_test/test_human_base/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)

	/// the limbs have no wound resistance like the chest and head do, so let's go with the r_arm
	var/obj/item/bodypart/tested_part = victim.get_bodypart(BODY_ZONE_R_ARM)
	/// One series per attack type, used as the yardstick for where each tier's threshold sits
	var/list/reference_series = list(
		list(/datum/wound/blunt/bone/moderate, /datum/wound/blunt/bone/severe, /datum/wound/blunt/bone/critical),
		list(/datum/wound/slash/flesh/moderate, /datum/wound/slash/flesh/severe, /datum/wound/slash/flesh/critical),
		list(/datum/wound/pierce/bleed/moderate, /datum/wound/pierce/bleed/severe, /datum/wound/pierce/bleed/critical),
		list(/datum/wound/burn/flesh/moderate, /datum/wound/burn/flesh/severe, /datum/wound/burn/flesh/critical),
	)
	/// In order of the wound types we're trying to inflict, what sharpness do we need to deal them?
	var/list/sharps = list(NONE, SHARP_EDGED, SHARP_POINTY, NONE)
	/// Since burn wounds need burn damage, duh
	var/list/dam_types = list(BRUTE, BRUTE, BRUTE, BURN)

	for(var/i in 1 to length(reference_series))
		TEST_ASSERT_EQUAL(length(victim.all_wounds), 0, "Patient is somehow wounded before test")

		for(var/datum/wound/reference as anything in reference_series[i])
			var/datum/wound_pregen_data/pregen_data = GLOB.all_wound_pregen_data[reference]
			// Damage stays at the minimum so the limb survives all three tiers; the bonus puts the
			// injury score on this tier's threshold.
			if(dam_types[i] == BRUTE)
				tested_part.receive_damage(WOUND_MINIMUM_DAMAGE, 0, wound_bonus = pregen_data.threshold_minimum, sharpness = sharps[i])
			else
				tested_part.receive_damage(0, WOUND_MINIMUM_DAMAGE, wound_bonus = pregen_data.threshold_minimum, sharpness = sharps[i])

			TEST_ASSERT(length(victim.all_wounds), "Patient has no wounds when one is expected. Severity: [initial(reference.severity)]")
			TEST_ASSERT_EQUAL(get_worst_wound_severity(victim), initial(reference.severity), \
				"Patient's worst injury is not the tier the attack crossed. Expected the tier of [initial(reference.name)]")
			assert_one_wound_per_series(victim)

		victim.fully_heal(ADMIN_HEAL_ALL) // should clear all wounds between types
		TEST_ASSERT_EQUAL(length(victim.all_wounds), 0, "fully_heal left wounds behind")

/// Identical damage to an identical part has to produce an identical injury tier.
/datum/unit_test/wound_determinism/Run()
	var/list/severities = list()

	for(var/attempt in 1 to 3)
		var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
		var/obj/item/bodypart/tested_part = victim.get_bodypart(BODY_ZONE_R_ARM)

		// Three solid cuts. Enough damage to walk the arm up to a critical injury with no bonuses of any kind.
		for(var/hit in 1 to 3)
			tested_part.receive_damage(WOUND_MAX_CONSIDERED_DAMAGE, 0, sharpness = SHARP_EDGED)

		severities += get_worst_wound_severity(victim)

	for(var/severity in severities)
		TEST_ASSERT_EQUAL(severity, severities[1], "The same three cuts produced different injury tiers across runs: [json_encode(severities)]")

/// A hit a plate stopped bruises and cracks bone. It never opens anyone up and never reaches the
/// worst tier, however many land. This is the helmeted head worked example.
/datum/unit_test/wound_nonpenetrating/Run()
	var/mob/living/carbon/human/armoured = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/tested_part = armoured.get_bodypart(BODY_ZONE_R_ARM)

	// Enough edged damage to have opened a bare arm several times over, all of it flagged as stopped.
	// Driven through the injury track directly rather than through a plate, so this stays a test of
	// what a stopped hit is allowed to cause rather than of any plate's tolerance.
	for(var/hit in 1 to 8)
		tested_part.painless_wound_roll(WOUND_SLASH, WOUND_MAX_CONSIDERED_DAMAGE, 0, 0, SHARP_EDGED, nonpenetrating = TRUE)

	TEST_ASSERT(length(armoured.all_wounds), "A stopped hit should still bruise and break bone, but eight of them left no injury at all")
	for(var/datum/wound/carried as anything in armoured.all_wounds)
		var/datum/wound_pregen_data/pregen_data = GLOB.all_wound_pregen_data[carried.type]
		TEST_ASSERT(!pregen_data.bleeds, "A hit a plate stopped opened the patient up: [carried]")
		TEST_ASSERT(carried.severity <= WOUND_NONPENETRATING_MAX_SEVERITY, "A hit a plate stopped caused [carried], past the non-penetrating severity cap")

	TEST_ASSERT(armoured.get_bodypart(BODY_ZONE_R_ARM), "A hit a plate stopped took the limb off")

/**
 * Worn percentage armour is damage reduction, not a wall.
 *
 * NP/P was stubbed off `blocked` before plates existed, which made any rating at or above 50% total
 * immunity to the worst injuries: a laser on a captain's carapace piled up burn damage forever and
 * never reached a Catastrophic Burn. Percentage armour now only reduces the damage that feeds the
 * injury track.
 */
/datum/unit_test/wound_percentage_armour_is_not_a_plate/Run()
	var/mob/living/carbon/human/armoured = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/tested_part = armoured.get_bodypart(BODY_ZONE_CHEST)

	for(var/hit in 1 to 20)
		armoured.apply_damage(WOUND_MAX_CONSIDERED_DAMAGE, BURN, tested_part, blocked = 50)

	TEST_ASSERT(get_worst_wound_severity(armoured) >= WOUND_SEVERITY_CRITICAL, \
		"Twenty lasers through half armour never reached the worst injury tier - percentage armour should slow injuries down, not cap them")

/// A weapon armour brings under the minimum hit size still has to injure eventually. While the injury
/// track was gated on how big a hit was rather than on the part's running total, a light weapon against
/// a vest did nothing indefinitely: no injuries, so no injury capacity, so no overflow.
/datum/unit_test/wound_light_hits_accumulate/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/tested_part = victim.get_bodypart(BODY_ZONE_CHEST)

	for(var/hit in 1 to 30)
		victim.apply_damage(WOUND_MINIMUM_DAMAGE / 2, BRUTE, tested_part)

	TEST_ASSERT(tested_part.get_wounding_damage(WOUND_BLUNT) > 0, \
		"Hits under the minimum damage never reached the part's running injury total")
	TEST_ASSERT(length(victim.all_wounds), \
		"Thirty light hits to the chest left no injury at all")

/// This test is used for making sure species with bones but no flesh (skeletons, plasmamen) can only suffer BONE_WOUNDS, and nothing tagged with FLESH_WOUND (it's possible to require both)
/datum/unit_test/test_human_bone/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)

	/// the limbs have no wound resistance like the chest and head do, so let's go with the r_arm
	var/obj/item/bodypart/tested_part = victim.get_bodypart(BODY_ZONE_R_ARM)
	var/list/reference_series = list(
		list(/datum/wound/blunt/bone/moderate, /datum/wound/blunt/bone/severe, /datum/wound/blunt/bone/critical),
		list(/datum/wound/slash/flesh/moderate, /datum/wound/slash/flesh/severe, /datum/wound/slash/flesh/critical),
		list(/datum/wound/pierce/bleed/moderate, /datum/wound/pierce/bleed/severe, /datum/wound/pierce/bleed/critical),
		list(/datum/wound/burn/flesh/moderate, /datum/wound/burn/flesh/severe, /datum/wound/burn/flesh/critical),
	)
	/// In order of the wound types we're trying to inflict, what sharpness do we need to deal them?
	var/list/sharps = list(NONE, SHARP_EDGED, SHARP_POINTY, NONE)
	/// Since burn wounds need burn damage, duh
	var/list/dam_types = list(BRUTE, BRUTE, BRUTE, BURN)

	tested_part.biological_state &= ~BIO_FLESH // take away the base limb's flesh (ouchie!) ((not actually ouchie, this just affects their wounds and dismemberment handling))

	for(var/i in 1 to length(reference_series))
		TEST_ASSERT_EQUAL(length(victim.all_wounds), 0, "Patient is somehow wounded before test")

		for(var/datum/wound/reference as anything in reference_series[i])
			var/datum/wound_pregen_data/pregen_data = GLOB.all_wound_pregen_data[reference]
			if(dam_types[i] == BRUTE)
				tested_part.receive_damage(WOUND_MINIMUM_DAMAGE, 0, wound_bonus = pregen_data.threshold_minimum, sharpness = sharps[i])
			else
				tested_part.receive_damage(0, WOUND_MINIMUM_DAMAGE, wound_bonus = pregen_data.threshold_minimum, sharpness = sharps[i])

			// A limb with no flesh can only take the wounds that do not need any. Bone wounds should still
			// land on their tier; everything else should simply not happen.
			for(var/datum/wound/suffered as anything in victim.all_wounds)
				var/datum/wound_pregen_data/suffered_pregen_data = GLOB.all_wound_pregen_data[suffered.type]
				TEST_ASSERT((suffered_pregen_data.required_limb_biostate & ~BIO_FLESH), \
					"Limb has flesh wound despite no BIO_FLESH biological_state. Offending wound: [suffered]")

			if(!(pregen_data.required_limb_biostate & BIO_FLESH))
				TEST_ASSERT_EQUAL(get_worst_wound_severity(victim), initial(reference.severity), \
					"Patient's worst injury is not the tier the attack crossed. Expected the tier of [initial(reference.name)]")

			assert_one_wound_per_series(victim)

		victim.fully_heal(ADMIN_HEAL_ALL) // should clear all wounds between types
