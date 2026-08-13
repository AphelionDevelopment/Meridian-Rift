/// Plate body first, webbing second, so a plate's material and its straps colour separately.
/datum/greyscale_config/armor_plate
	name = "Armour Plate"
	icon_file = 'icons/obj/clothing/armor_plate.dmi'
	json_config = 'code/datums/greyscale/json_configs/armor_plate.json'

/// Stops matching hits up to its tolerance and loses durability when it does.
/obj/item/armor_plate
	name = "armour plate"
	desc = "A plate of composite armour, shaped to drop into a carrier. Every hit it stops wears it down."
	// What a plate is made to stop is what makes it one, so the base has nothing to stop and is never spawned.
	abstract_type = /obj/item/armor_plate
	// A greyscale item carries its map preview here and switches to the real state on init, so the
	// map editor has something to draw before anything is generated.
	icon = 'icons/map_icons/items/_item.dmi'
	icon_state = "/obj/item/armor_plate/ballistic"
	post_init_icon_state = "armor_plate"
	greyscale_config = /datum/greyscale_config/armor_plate
	inhand_icon_state = "armor"
	lefthand_file = 'icons/mob/inhands/clothing/suits_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/clothing/suits_righthand.dmi'
	w_class = WEIGHT_CLASS_BULKY
	force = 6
	throwforce = 8
	throw_range = 3
	attack_verb_continuous = list("bashes", "slams", "whacks")
	attack_verb_simple = list("bash", "slam", "whack")
	custom_materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 4)
	/// Sets both this plate's per-hit tolerance and its total durability.
	var/level = 1
	/// Durability left before the plate stops working. Drained by what it stops, never by what it lets past.
	var/durability
	/// Armour flags this plate answers. It does nothing about anything not listed here.
	var/list/stops_flags
	/// Wounding type a stopped hit leaves on the body underneath.
	var/nonpenetrating_wound_type = WOUND_BLUNT

/obj/item/armor_plate/Initialize(mapload)
	. = ..()
	stops_flags = string_list(stops_flags)
	durability = get_maximum_durability()

/obj/item/armor_plate/Destroy()
	// Plates live inside their carrier, so the carrier has to drop its reference.
	var/obj/item/clothing/carrier = loc
	if(istype(carrier) && carrier.fitted_plate == src)
		carrier.fitted_plate = null
	return ..()

/// Damage this plate stops outright on any one hit.
/obj/item/armor_plate/proc/get_tolerance()
	return level * PLATE_TOLERANCE_PER_LEVEL

/// Total damage this plate absorbs over its lifetime.
/obj/item/armor_plate/proc/get_maximum_durability()
	return level * PLATE_DURABILITY_PER_LEVEL

/// Whether this plate still stops anything.
/obj/item/armor_plate/proc/is_working()
	return durability > 0

/**
 * Whether this plate has any opinion about an attack.
 *
 * A plate is ballistic or ablative and never both, so the wrong sort of attack does not meet it at
 * all and the hit lands as though the carrier were unarmoured.
 *
 * Arguments:
 * * armour_flag - One of the armour flags, e.g. [BULLET] or [LASER].
 */
/obj/item/armor_plate/proc/stops_attack(armour_flag)
	return armour_flag in stops_flags

/**
 * Takes a hit on behalf of whoever is wearing this plate, and reports how much of it never landed.
 *
 * Everything up to the plate's tolerance is stopped: that damage never reaches the bodypart, cannot
 * wound past Major severity and cannot overflow onto an organ. It spikes pain, marks the body
 * underneath, and wears the plate down by as much as it stopped.
 *
 * Arguments:
 * * victim - Who is wearing this plate.
 * * damage - The whole hit, before anything is taken off it.
 * * def_zone - Bodypart or zone the hit landed on.
 * * wound_bonus - The attack's wound bonus, so [CANT_WOUND] still means what it says.
 * * attack_direction - Which way the hit came from.
 * * damage_source - What did it.
 * * wound_clothing - If this should wear the carrier down as well as the plate.
 *
 * Returns how much of the hit the plate stopped, which the caller subtracts from what it applies.
 */
/obj/item/armor_plate/proc/take_impact(mob/living/victim, damage, def_zone, wound_bonus = 0, attack_direction, damage_source, wound_clothing = TRUE)
	var/stopped = min(damage, get_tolerance())
	if(stopped <= 0)
		return 0

	// A round that fills the plate's headroom hurts far more than one well under it.
	var/proximity = PLATE_PAIN_PROXIMITY_FLOOR + ((1 - PLATE_PAIN_PROXIMITY_FLOOR) * (stopped / get_tolerance()))
	victim.add_temporary_pain(stopped * PLATE_PAIN_RATIO * proximity)
	// Small shake for a hit that never got inside. wear_down() outranks it when the plate gives.
	victim.shake_from_impact(stopped, penetrated = FALSE)

	var/obj/item/bodypart/hit_part = isbodypart(def_zone) ? def_zone : victim.get_bodypart(check_zone(def_zone))
	// The plate is what met the body, so a caught knife leaves a bruise rather than a cut. Flagged as
	// stopped, which keeps the injury tree under the bleeding tiers.
	hit_part?.painless_wound_roll(
		wounding_type = nonpenetrating_wound_type,
		wounding_dmg = stopped * PLATE_WOUND_RATIO,
		wound_bonus = wound_bonus,
		exposed_wound_bonus = 0,
		wound_clothing = wound_clothing,
		nonpenetrating = TRUE,
	)

	wear_down(stopped, victim)
	return stopped

/**
 * Spends this plate's durability on what it just stopped, and says so when that changes something.
 *
 * Feedback fires on state changes rather than on hits, so a plate catching rounds does not drown out
 * the round that gets through.
 *
 * Arguments:
 * * amount - Damage absorbed.
 * * wearer - Who to tell, if anyone.
 */
/obj/item/armor_plate/proc/wear_down(amount, mob/living/wearer)
	var/static/list/wear_bands = list(PLATE_WEAR_SCUFFED, PLATE_WEAR_CRACKED, PLATE_WEAR_FAILING)

	var/was_at = durability / get_maximum_durability()
	durability = max(durability - amount, 0)

	if(isnull(wearer))
		return

	if(!durability)
		wearer.combat_feedback(
			COMBAT_FEEDBACK_STATE,
			message = span_danger("The [name] [wearer] is wearing shatters!"),
			self_message = span_userdanger("The [name] you are wearing shatters!"),
			sound = 'sound/effects/glass/glassbr3.ogg',
			sound_volume = 70,
			shake_strength = COMBAT_SHAKE_PENETRATING_MIN,
		)
		return

	var/now_at = durability / get_maximum_durability()
	for(var/band in wear_bands)
		if(was_at > band && now_at <= band)
			wearer.combat_feedback(
				COMBAT_FEEDBACK_STATE,
				message = span_warning("Something gives in the [name] [wearer] is wearing."),
				self_message = span_warning("Something gives in the [name] you are wearing."),
				sound = 'sound/effects/wounds/crack1.ogg',
				sound_volume = 50,
				shake_strength = COMBAT_SHAKE_NONPENETRATING,
			)
			return

/obj/item/armor_plate/examine(mob/user)
	. = ..()
	. += span_notice("It stops up to <b>[get_tolerance()]</b> damage from any one hit. Anything heavier goes straight through.")
	. += span_notice("It only stops [english_list(stops_flags, and_text = " and ")] damage.")
	. += describe_plate_wear()

/// One line of wear description, for this plate's examine and its carrier's.
/obj/item/armor_plate/proc/describe_plate_wear()
	if(!is_working())
		return span_boldwarning("It is shattered through, and will not stop anything.")

	switch(durability / get_maximum_durability())
		if(PLATE_WEAR_SCUFFED to INFINITY)
			return span_notice("It is scuffed at worst.")
		if(PLATE_WEAR_CRACKED to PLATE_WEAR_SCUFFED)
			return span_warning("It is dented and scored.")
		if(PLATE_WEAR_FAILING to PLATE_WEAR_CRACKED)
			return span_warning("It is cracked most of the way through.")
		else
			return span_boldwarning("It is barely holding together.")

/// Ballistic plates stop physical impacts and do nothing about beam weapons.
/obj/item/armor_plate/ballistic
	name = "ballistic plate"
	desc = "A ceramic carrier plate that stops physical impacts but not lasers."
	icon_state = "/obj/item/armor_plate/ballistic"
	greyscale_colors = "#8a8577#3f3d36"
	stops_flags = list(MELEE, BULLET, BOMB)
	nonpenetrating_wound_type = WOUND_BLUNT

/obj/item/armor_plate/ballistic/reinforced
	name = "reinforced ballistic plate"
	desc = "A reinforced ceramic carrier plate that stops physical impacts but not lasers."
	icon_state = "/obj/item/armor_plate/ballistic/reinforced"
	greyscale_colors = "#6f7a5f#3a3f33"
	level = 2
	custom_materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 6, /datum/material/alloy/plasteel = SHEET_MATERIAL_AMOUNT * 2)

/obj/item/armor_plate/ballistic/composite
	name = "composite ballistic plate"
	desc = "A heavy composite carrier plate that stops physical impacts but not lasers."
	icon_state = "/obj/item/armor_plate/ballistic/composite"
	greyscale_colors = "#4f5a63#2f353a"
	level = 3
	custom_materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 8, /datum/material/alloy/plasteel = SHEET_MATERIAL_AMOUNT * 4, /datum/material/titanium = SHEET_MATERIAL_AMOUNT * 2)

/// Ablative plates stop beam weapons, and what they stop burns the plate rather than the wearer.
/obj/item/armor_plate/ablative
	name = "ablative plate"
	desc = "A reflective carrier plate that stops energy impacts but not bullets."
	icon_state = "/obj/item/armor_plate/ablative"
	greyscale_colors = "#b9c2c9#4a4f52"
	custom_materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 2, /datum/material/silver = SHEET_MATERIAL_AMOUNT)
	stops_flags = list(LASER, ENERGY)
	nonpenetrating_wound_type = WOUND_BURN

/obj/item/armor_plate/ablative/reinforced
	name = "reinforced ablative plate"
	desc = "A reinforced carrier plate that stops energy impacts but not bullets."
	icon_state = "/obj/item/armor_plate/ablative/reinforced"
	greyscale_colors = "#9fb6c4#3f4a52"
	level = 2
	custom_materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 4, /datum/material/silver = SHEET_MATERIAL_AMOUNT * 2)

/obj/item/armor_plate/ablative/composite
	name = "composite ablative plate"
	desc = "A heavy composite carrier plate that stops energy impacts but not physical attacks."
	icon_state = "/obj/item/armor_plate/ablative/composite"
	greyscale_colors = "#7fc3c8#33484a"
	level = 3
	custom_materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 6, /datum/material/silver = SHEET_MATERIAL_AMOUNT * 4, /datum/material/titanium = SHEET_MATERIAL_AMOUNT * 2)

/obj/item/clothing
	/// The plate fitted into this carrier, if it takes one. See [/obj/item/armor_plate].
	var/obj/item/armor_plate/fitted_plate
	/// Whether a plate can be fitted into this. Armour and helmets take one, a jumpsuit does not.
	var/accepts_armor_plates = FALSE
	/// The plate this carrier starts with. Set to null for carriers that should spawn empty.
	var/initial_armor_plate = /obj/item/armor_plate/ballistic

/obj/item/clothing/suit/armor
	accepts_armor_plates = TRUE

/obj/item/clothing/suit/space
	accepts_armor_plates = TRUE

/obj/item/clothing/suit/mod
	accepts_armor_plates = TRUE

/obj/item/clothing/head/helmet
	accepts_armor_plates = TRUE

/obj/item/clothing/head/mod
	accepts_armor_plates = TRUE

/**
 * Plate carriers do not provide percentage combat armour of their own.
 *
 * Their coverage determines where a fitted plate can answer a hit, while the plate determines what
 * it stops. Environmental and material protections remain on the clothing: bio protection and fire
 * or acid durability are independent of the fitted plate.
 */
/obj/item/clothing/get_armor_rating(damage_type)
	if(accepts_armor_plates)
		switch(damage_type)
			if(MELEE, BULLET, LASER, ENERGY, BOMB, WOUND)
				return 0
	return ..()

/**
 * Fits a plate into this carrier, or pries the fitted one back out with a crowbar.
 *
 * Called from [/obj/item/clothing/item_interaction] before anything else it does.
 *
 * Arguments:
 * * user - Who is doing the fitting.
 * * tool - What they are doing it with.
 */
/obj/item/clothing/proc/fit_armor_plate(mob/living/user, obj/item/tool)
	if(istype(tool, /obj/item/armor_plate))
		if(!accepts_armor_plates)
			balloon_alert(user, "no plate carrier!")
			return ITEM_INTERACT_BLOCKING
		if(fitted_plate)
			balloon_alert(user, "already plated!")
			return ITEM_INTERACT_BLOCKING
		balloon_alert(user, "fitting plate...")
		if(!do_after(user, PLATE_FITTING_TIME, src) || fitted_plate || !user.transferItemToLoc(tool, src))
			return ITEM_INTERACT_BLOCKING
		fitted_plate = tool
		balloon_alert(user, "plate fitted")
		return ITEM_INTERACT_SUCCESS

	if(tool.tool_behaviour != TOOL_CROWBAR || !fitted_plate)
		return NONE

	balloon_alert(user, "prying plate out...")
	if(!tool.use_tool(src, user, PLATE_FITTING_TIME, volume = 50) || !fitted_plate)
		return ITEM_INTERACT_BLOCKING
	var/obj/item/armor_plate/removed = fitted_plate
	fitted_plate = null
	user.put_in_hands(removed)
	balloon_alert(user, "plate removed")
	return ITEM_INTERACT_SUCCESS

/// What this carrier's plate, if it has one, adds to its examine text.
/obj/item/clothing/proc/describe_fitted_plate()
	if(!accepts_armor_plates)
		return null
	if(isnull(fitted_plate))
		return span_notice("Its plate carrier is empty.")

	return list(
		span_notice("A [fitted_plate.name] is fitted, stopping up to <b>[fitted_plate.get_tolerance()]</b> damage from any one hit."),
		fitted_plate.describe_plate_wear(),
	)

/// A case for spare plates, which are too bulky for a backpack. Carrying one costs a hand.
/obj/item/storage/plate_case
	name = "plate case"
	desc = "A hard case for spare armour plates. Nothing else will fit, and it will not fit in a bag."
	icon = 'icons/obj/storage/case.dmi'
	icon_state = "secbox"
	inhand_icon_state = "lockbox"
	lefthand_file = 'icons/mob/inhands/equipment/briefcase_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/equipment/briefcase_righthand.dmi'
	w_class = WEIGHT_CLASS_BULKY
	throw_speed = 2
	throw_range = 4
	custom_materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 2)

/obj/item/storage/plate_case/Initialize(mapload)
	. = ..()
	atom_storage.max_slots = 3
	atom_storage.max_specific_storage = WEIGHT_CLASS_BULKY
	atom_storage.set_holdable(list(/obj/item/armor_plate))

/// A case that arrives filled, for cargo and lockers.
/obj/item/storage/plate_case/ballistic
	name = "ballistic plate case"

/obj/item/storage/plate_case/ballistic/PopulateContents()
	for(var/spare in 1 to 3)
		new /obj/item/armor_plate/ballistic/reinforced(src)

/obj/item/storage/plate_case/ablative
	name = "ablative plate case"

/obj/item/storage/plate_case/ablative/PopulateContents()
	for(var/spare in 1 to 3)
		new /obj/item/armor_plate/ablative/reinforced(src)
