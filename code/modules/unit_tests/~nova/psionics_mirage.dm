/** Illusionism uses real hallucination cores, and Mirage fits a Gamma's normal imprint budget. */
/datum/unit_test/psionic_mirage_catalog

/datum/unit_test/psionic_mirage_catalog/Run()
	var/mob/living/carbon/human/psion = allocate(/mob/living/carbon/human/consistent)
	var/datum/component/psionic_profile/profile = psion.awaken_psionics()
	var/datum/tgui/ui = allocate(/datum/tgui, psion, profile, "PsionicImprinting")
	var/mirage_type = /datum/action/cooldown/psionic/pointed/mirage
	TEST_ASSERT(profile.ui_act("imprint", list("action_type" = "[mirage_type]"), ui), "Gamma cannot imprint Mirage through TGUI.")
	TEST_ASSERT_EQUAL(profile.available_points, 1, "Mirage should cost two of Gamma's three points.")
	var/telepathy_type = /datum/action/cooldown/psionic/pointed/telepathy
	TEST_ASSERT(profile.ui_act("imprint", list("action_type" = "[telepathy_type]"), ui), "Mirage + Telepathy should fit Gamma's budget.")
	var/datum/psionic_school/school = get_psionic_school_for_anomaly(/obj/effect/anomaly/hallucination)
	TEST_ASSERT_EQUAL(school.type, PSIONIC_SCHOOL_HALLUCINATION, "Hallucination anomaly maps to the wrong school.")
	TEST_ASSERT_EQUAL(get_psionic_school_for_anomaly_core(/obj/item/assembly/signaler/anomaly/hallucination), school, "Hallucination core maps to a different school.")
	var/obj/item/assembly/signaler/anomaly/hallucination/core = allocate(/obj/item/assembly/signaler/anomaly/hallucination)
	TEST_ASSERT_EQUAL(core.click_alt(psion), CLICK_ACTION_SUCCESS, "Hallucination core cannot attune Illusionism.")
	TEST_ASSERT(QDELETED(core), "Attunement must consume the actual core.")
	var/datum/action/cooldown/psionic/pointed/mirage/action = profile.granted_actions[mirage_type]
	TEST_ASSERT_EQUAL(profile.get_action_strain_gain(20, action), 16, "Illusionism attunement should discount Mirage's strain by 20%.")
	profile.apply_rank(PSIONIC_RANK_EPSILON)
	TEST_ASSERT(!action.Activate(get_step(psion, EAST)), "Epsilon must not cast Mirage.")

/** Commands affect the current double without another cast, and movement preserves collision boundaries. */
/datum/unit_test/psionic_mirage_commands

/datum/unit_test/psionic_mirage_commands/Run()
	var/mob/living/carbon/human/psion = allocate(/mob/living/carbon/human/consistent)
	var/datum/component/psionic_profile/profile = psion.awaken_psionics(starting_powers = list(/datum/action/cooldown/psionic/pointed/mirage))
	var/datum/action/cooldown/psionic/pointed/mirage/action = profile.granted_actions[/datum/action/cooldown/psionic/pointed/mirage]
	var/turf/start = get_step(psion, EAST)
	TEST_ASSERT(action.InterceptClickOn(psion, null, start), "Initial Mirage cast failed.")
	var/mob/living/basic/illusion/psionic_mirage/double = action.active_mirage
	TEST_ASSERT(double, "Casting Mirage did not create a double.")
	TEST_ASSERT(!profile.is_strain_recovery_blocked(), "Mirage should allow passive strain recovery.")
	TEST_ASSERT(!action.Activate(start), "Commands must not bypass the recast cooldown.")
	var/strain_before_command = profile.strain
	TEST_ASSERT(action.InterceptClickOn(psion, "right=1", start), "Mode cycling failed during cooldown.")
	TEST_ASSERT_EQUAL(double.current_mode, "Flee", "Cycling should immediately update the live double.")
	var/turf/destination = get_step(start, NORTH)
	TEST_ASSERT(action.InterceptClickOn(psion, "shift=1", destination), "Destination command failed during cooldown.")
	TEST_ASSERT_EQUAL(profile.strain, strain_before_command, "Commands must not add strain.")
	var/datum/move_loop/movement = double.move_packet?.running_loop
	TEST_ASSERT(movement, "Flee command did not start normal movement.")
	movement.move()
	TEST_ASSERT_EQUAL(get_turf(double), destination, "Double did not move toward its destination.")
	TEST_ASSERT(psion.Move(destination, get_dir(psion, destination)), "A double must not block a person walking through it.")
	var/turf/blocked_destination = get_step(destination, NORTH)
	allocate(/obj/structure/window/reinforced/fulltile, blocked_destination)
	double.set_mode("Flee", blocked_destination)
	movement = double.move_packet.running_loop
	movement.move()
	TEST_ASSERT_EQUAL(get_turf(double), destination, "Double must not move through a full-tile window.")
	double.set_mode("Stationary")
	TEST_ASSERT(!double.move_packet, "Stationary mode left a movement loop running.")
	action.next_use_time = 0
	TEST_ASSERT(action.Activate(start), "Recasting failed after cooldown.")
	TEST_ASSERT(QDELETED(double), "Recasting must replace the previous double.")
	TEST_ASSERT(action.active_mirage != double, "Recasting did not create a new double.")
	TEST_ASSERT(action.InterceptClickOn(psion, "alt=1", start), "Explicit dismissal failed.")
	TEST_ASSERT(!action.active_mirage, "Dismissal left an active double reference.")

/** Alternate appearances follow mental protection without spending charges and release every viewer on deletion. */
/datum/unit_test/psionic_mirage_observers

/datum/unit_test/psionic_mirage_observers/Run()
	var/mob/living/carbon/human/psion = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/viewer = allocate(/mob/living/carbon/human/consistent)
	var/datum/component/psionic_profile/profile = psion.awaken_psionics(starting_powers = list(/datum/action/cooldown/psionic/pointed/mirage))
	var/datum/action/cooldown/psionic/pointed/mirage/action = profile.granted_actions[/datum/action/cooldown/psionic/pointed/mirage]
	TEST_ASSERT(action.Activate(get_step(psion, EAST)), "Initial Mirage cast failed.")
	var/mob/living/basic/illusion/psionic_mirage/double = action.active_mirage
	var/datum/atom_hud/alternate_appearance/basic/psionic_mirage/revealed = double.revealed_appearance
	TEST_ASSERT(revealed.mobShouldSee(psion), "The creator must recognize their own illusion.")
	TEST_ASSERT(!revealed.mobShouldSee(viewer), "An unprotected observer should see the apparent double.")
	ADD_TRAIT(viewer, TRAIT_PSIONIC_DAMPENER, QUIRK_TRAIT)
	revealed.check_hud(viewer)
	TEST_ASSERT(revealed.hud_users_all_z_levels[viewer], "Mental shielding should reveal the false image.")
	SEND_SIGNAL(viewer, COMSIG_MOB_LOGOUT)
	TEST_ASSERT(!revealed.hud_users_all_z_levels[viewer], "Logout must detach the false image.")
	revealed.check_hud(viewer)
	TEST_ASSERT(revealed.hud_users_all_z_levels[viewer], "Reloading alternate appearances must restore the protected view.")
	var/turf/camera_turf = locate(1, 1, 1)
	revealed.on_look_z_level_changed(viewer, get_turf(viewer), camera_turf)
	revealed.hide_from(viewer, absolute = TRUE)
	TEST_ASSERT(!revealed.hud_users[camera_turf.z][viewer], "Hiding a camera view must clear its remote HUD bucket.")
	revealed.check_hud(viewer)
	TEST_ASSERT_EQUAL(revealed.image.color, "#ff4b55", "The revealed image must use Illusionism's red.")
	double.setDir(NORTH)
	TEST_ASSERT_EQUAL(revealed.image.dir, NORTH, "The false image must turn with the double.")
	REMOVE_TRAIT(viewer, TRAIT_PSIONIC_DAMPENER, QUIRK_TRAIT)
	revealed.check_hud(viewer)
	TEST_ASSERT(!revealed.hud_users_all_z_levels[viewer], "Removing protection must remove the false image.")
	var/datum/component/psionic_protection/protection = viewer.AddComponent(/datum/component/psionic_protection, charges = 2)
	revealed.check_hud(viewer)
	TEST_ASSERT(revealed.hud_users_all_z_levels[viewer], "Charged mental protection should reveal the double.")
	TEST_ASSERT_EQUAL(protection.charges, 2, "Looking at Mirage must not drain protection charges.")
	protection.charges = 0
	revealed.check_hud(viewer)
	TEST_ASSERT(!revealed.hud_users_all_z_levels[viewer], "Spent protection must not reveal the double.")
	ADD_TRAIT(viewer, TRAIT_RESIST_PSYCHIC, REF(src))
	revealed.check_hud(viewer)
	TEST_ASSERT(double.psionic_dispel(psion), "Manifestation dispel failed.")
	TEST_ASSERT(QDELETED(double) && QDELETED(revealed), "Dispel left the double or alternate appearance alive.")
	TEST_ASSERT(!(revealed in GLOB.active_alternate_appearances), "Dispel left a global appearance entry.")
	TEST_ASSERT(!length(revealed.hud_users_all_z_levels), "Dispel left viewer references behind.")
	TEST_ASSERT(!action.active_mirage, "Dispel left the action's double reference behind.")

/** NPC distraction retains targeting and mental defenses, and the double cannot inflict damage or operate machinery. */
/datum/unit_test/psionic_mirage_npcs

/datum/unit_test/psionic_mirage_npcs/Run()
	var/mob/living/carbon/human/psion = allocate(/mob/living/carbon/human/consistent)
	var/datum/component/psionic_profile/profile = psion.awaken_psionics(starting_powers = list(/datum/action/cooldown/psionic/pointed/mirage))
	var/datum/action/cooldown/psionic/pointed/mirage/action = profile.granted_actions[/datum/action/cooldown/psionic/pointed/mirage]
	TEST_ASSERT(action.Activate(get_step(psion, EAST)), "Initial Mirage cast failed.")
	var/mob/living/basic/illusion/psionic_mirage/double = action.active_mirage
	var/mob/living/basic/zombie/pursuer = allocate(/mob/living/basic/zombie, get_step(double, EAST))
	pursuer.ai_controller.set_blackboard_key(BB_CURRENT_TARGET, psion)
	ADD_TRAIT(pursuer, TRAIT_RESIST_PSYCHIC, REF(src))
	double.set_mode("Distract")
	TEST_ASSERT_EQUAL(pursuer.ai_controller.blackboard[BB_CURRENT_TARGET], psion, "A mentally protected NPC must not be redirected.")
	REMOVE_TRAIT(pursuer, TRAIT_RESIST_PSYCHIC, REF(src))
	double.distract_pursuers()
	TEST_ASSERT_EQUAL(pursuer.ai_controller.blackboard[BB_CURRENT_TARGET], double, "An eligible pursuing NPC was not distracted.")
	pursuer.ai_controller.set_blackboard_key(BB_CURRENT_TARGET, psion)
	pursuer.sentience_type = SENTIENCE_BOSS
	double.distract_pursuers()
	TEST_ASSERT_EQUAL(pursuer.ai_controller.blackboard[BB_CURRENT_TARGET], psion, "Bosses must retain their targets.")
	var/health_before = pursuer.health
	TEST_ASSERT(!double.melee_attack(pursuer), "The double must not use the melee attack chain.")
	TEST_ASSERT_EQUAL(pursuer.health, health_before, "The double inflicted damage.")
	var/obj/machinery/door/airlock/door = allocate(/obj/machinery/door/airlock, get_step(double, NORTH))
	TEST_ASSERT(!double.UnarmedAttack(door, TRUE), "The double must not operate machinery.")
	TEST_ASSERT(door.density, "The double opened an airlock.")
	pursuer.melee_attack(double, ignore_cooldown = TRUE)
	TEST_ASSERT(QDELETED(double), "One successful NPC hit must destroy the fragile double.")
	TEST_ASSERT(!action.active_mirage, "Destruction left the action's double reference behind.")

/** Suppression, caster logout/death, reset, and actual expiry end the manifestation. */
/datum/unit_test/psionic_mirage_cleanup

/datum/unit_test/psionic_mirage_cleanup/Run()
	var/mob/living/carbon/human/psion = allocate(/mob/living/carbon/human/consistent)
	var/datum/component/psionic_profile/profile = psion.awaken_psionics(starting_powers = list(/datum/action/cooldown/psionic/pointed/mirage))
	var/datum/action/cooldown/psionic/pointed/mirage/action = profile.granted_actions[/datum/action/cooldown/psionic/pointed/mirage]
	var/turf/destination = get_step(psion, EAST)
	TEST_ASSERT(action.Activate(destination), "Initial Mirage cast failed.")
	ADD_TRAIT(psion, TRAIT_PSIONIC_DAMPENER, REF(src))
	TEST_ASSERT(!action.active_mirage, "Suppression must immediately end the double.")
	REMOVE_TRAIT(psion, TRAIT_PSIONIC_DAMPENER, REF(src))
	action.next_use_time = 0
	TEST_ASSERT(action.Activate(destination), "Cast after suppression failed.")
	SEND_SIGNAL(psion, COMSIG_MOB_LOGOUT)
	TEST_ASSERT(!action.active_mirage, "Logout must end the double.")
	profile.strain = 0
	action.next_use_time = 0
	TEST_ASSERT(action.Activate(destination), "Cast after logout failed.")
	TEST_ASSERT(psion.psionic_dispel(psion), "Caster dispel failed.")
	TEST_ASSERT(!action.active_mirage, "Caster dispel must end the double.")
	profile.strain = 0
	action.next_use_time = 0
	TEST_ASSERT(action.Activate(destination), "Cast before expiry failed.")
	var/mob/living/basic/illusion/psionic_mirage/double = action.active_mirage
	var/datum/atom_hud/alternate_appearance/basic/psionic_mirage/revealed = double.revealed_appearance
	sleep(21 SECONDS)
	TEST_ASSERT(QDELETED(double) && QDELETED(revealed) && !action.active_mirage, "Expired Mirage left a double, appearance, or action reference.")
	TEST_ASSERT(action.Activate(destination), "Cast before reset failed.")
	double = action.active_mirage
	profile.reset_imprints(3, silent = TRUE)
	TEST_ASSERT(QDELETED(double) && QDELETED(action), "Imprint reset must remove the action and its double.")
	TEST_ASSERT(profile.learn_power(/datum/action/cooldown/psionic/pointed/mirage), "Relearning Mirage failed.")
	action = profile.granted_actions[/datum/action/cooldown/psionic/pointed/mirage]
	TEST_ASSERT(action.Activate(destination), "Cast before caster death failed.")
	double = action.active_mirage
	psion.death()
	TEST_ASSERT(QDELETED(double) && !action.active_mirage, "Caster death must remove the double.")
