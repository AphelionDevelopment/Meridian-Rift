/obj/machinery/nuclearbomb/selfdestruct
	// Pinned to the announcement track. The sequence is timed against the audio, so there is no
	// correct behaviour at any other length.
	timer_set = SELF_DESTRUCT_DURATION_SECONDS
	minimum_timer_set = SELF_DESTRUCT_DURATION_SECONDS
	maximum_timer_set = SELF_DESTRUCT_DURATION_SECONDS
	// The announcement has already spent 11:45 counting down; a further alarm is just a second countdown.
	detonation_lead_in = 0

/obj/machinery/nuclearbomb/selfdestruct/arm_nuke(mob/armer)
	// The keypad clamps to the values above, but the admin "Toggle Nuke" verb writes timer_set directly.
	if(timer_set != SELF_DESTRUCT_DURATION_SECONDS)
		message_admins("\The [src] was armed on a [timer_set] second timer. Reset to [SELF_DESTRUCT_DURATION_SECONDS] \
			seconds to keep the self-destruct sequence in sync with its announcement.")
		timer_set = SELF_DESTRUCT_DURATION_SECONDS

	. = ..()
	if(!isnull(GLOB.self_destruct_sequence))
		return
	GLOB.self_destruct_sequence = new /datum/self_destruct_sequence(src)

/**
 * Drops the "input time" step out of the keypad flow entirely.
 *
 * The countdown is fixed to the announcement, so there is nothing to enter - the stock flow would
 * just take a number and clamp it back to [SELF_DESTRUCT_DURATION_SECONDS]. Accepting the code takes
 * the safety off itself and goes straight to the arming prompt.
 */
/obj/machinery/nuclearbomb/selfdestruct/update_ui_mode()
	. = ..()
	if(ui_mode != NUKEUI_AWAIT_TIMER)
		return
	toggle_nuke_safety() // only reachable with the safety on, so this always takes it off
	ui_mode = NUKEUI_AWAIT_ARM

/obj/machinery/nuclearbomb/selfdestruct/get_cinematic_type(detonation_status)
	if(isnull(detonation_status)) // the miss cinematic gibs nobody, so it has no bodies to lose
		return ..()
	return /datum/cinematic/nuke/self_destruct/persistent

/obj/machinery/nuclearbomb/selfdestruct/disarm_nuke(mob/disarmer)
	. = ..()
	if(GLOB.self_destruct_sequence?.terminal == src)
		qdel(GLOB.self_destruct_sequence)

/// Cutting the terminal open is the other way to call off a self-destruct, so it closes with the abort
/// interlock. Returns TRUE if the interaction should be dropped.
/obj/machinery/nuclearbomb/selfdestruct/proc/refuse_tampering(mob/user)
	if(!GLOB.self_destruct_sequence?.past_no_return)
		return FALSE

	balloon_alert(user, "casing sealed!")
	to_chat(user, span_bolddanger("[src]'s casing has locked itself down. There is no getting at the core now."))
	return TRUE

/obj/machinery/nuclearbomb/selfdestruct/screwdriver_act(mob/living/user, obj/item/tool)
	if(refuse_tampering(user))
		return ITEM_INTERACT_BLOCKING
	return ..()

/obj/machinery/nuclearbomb/selfdestruct/crowbar_act(mob/user, obj/item/tool)
	if(refuse_tampering(user))
		return ITEM_INTERACT_BLOCKING
	return ..()

/obj/machinery/nuclearbomb/selfdestruct/welder_act(mob/living/user, obj/item/tool)
	if(refuse_tampering(user))
		return ITEM_INTERACT_BLOCKING
	return ..()

/obj/machinery/nuclearbomb/selfdestruct/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	// Only the core paths are off limits; no harm in letting someone shove the disk back in.
	if(istype(tool, /obj/item/nuke_core_container) || istype(tool, /obj/item/nuke_core))
		if(refuse_tampering(user))
			return ITEM_INTERACT_BLOCKING
	return ..()
