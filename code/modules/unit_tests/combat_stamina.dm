/// Tests that stamina damage, which is temporary pain now, ends in pain shock at the cap
/datum/unit_test/stamcrit
	priority = TEST_LONGER

/datum/unit_test/stamcrit/Run()
	var/mob/living/carbon/human/consistent/tider = allocate(__IMPLIED_TYPE__)
	// Applied in baton sized helpings: a single hit big enough to trigger adrenaline would halve
	// what the mob feels and hold shock off, which is its whole job.
	var/stamina_per_hit = PAIN_ADRENALINE_SPIKE_TRIGGER - 10
	var/hits_to_shock = ceil(PAIN_SHOCK_THRESHOLD / stamina_per_hit)

	for(var/hit in 1 to hits_to_shock - 1)
		tider.adjust_stamina_loss(stamina_per_hit)
	TEST_ASSERT(!tider.has_status_effect(/datum/status_effect/incapacitating/pain_shock), "Pain shock should not be applied at [tider.get_felt_pain()] felt pain")

	tider.adjust_stamina_loss(stamina_per_hit)
	TEST_ASSERT(tider.has_status_effect(/datum/status_effect/incapacitating/pain_shock), "Pain shock should be applied at [tider.get_felt_pain()] felt pain")

	// Down at the cap, up at the recovery threshold, and nothing in between.
	tider.set_stamina_loss(PAIN_SHOCK_RECOVERY_THRESHOLD)
	TEST_ASSERT(tider.has_status_effect(/datum/status_effect/incapacitating/pain_shock), "Pain shock should hold at [tider.get_felt_pain()] felt pain, above the recovery threshold")

	tider.set_stamina_loss(PAIN_SHOCK_RECOVERY_THRESHOLD - 1)
	TEST_ASSERT(!tider.has_status_effect(/datum/status_effect/incapacitating/pain_shock), "Pain shock should be removed at [tider.get_felt_pain()] felt pain, under the recovery threshold")

/// Tests that the temporary pain pool drains on its own, with no regeneration timer behind it
/datum/unit_test/stam_regen
	priority = TEST_LONGER

/datum/unit_test/stam_regen/Run()
	var/mob/living/carbon/human/consistent/tider = allocate(__IMPLIED_TYPE__)
	tider.adjust_stamina_loss(50)
	var/pain_before_decay = tider.get_stamina_loss()
	TEST_ASSERT_EQUAL(pain_before_decay, 50, "Stamina damage should land as temporary pain, but the mob is carrying [pain_before_decay]")

	sleep(3 SECONDS)
	TEST_ASSERT(tider.get_stamina_loss() < pain_before_decay, "Temporary pain should decay on its own, but sat at [tider.get_stamina_loss()]")
