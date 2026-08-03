/obj/item/organ/genital/testicles
	name = "testicles"
	desc = "A male reproductive organ."
	icon_state = "testicles"
	icon = 'modular_nova/master_files/icons/obj/genitals/testicles.dmi'
	mutantpart_key = ORGAN_SLOT_TESTICLES
	zone = BODY_ZONE_PRECISE_GROIN
	slot = ORGAN_SLOT_TESTICLES
	aroused = AROUSAL_CANT
	genital_location = GROIN
	drop_when_organ_spilling = FALSE
	bodypart_overlay = /datum/bodypart_overlay/mutant/genital/testicles
	internal_fluid_datum = /datum/reagent/consumable/cum

/datum/bodypart_overlay/mutant/genital/testicles
	feature_key = ORGAN_SLOT_TESTICLES
	layers = list(
		EXTERNAL_FRONT_UNDER_CLOTHES = TESTICLES_LAYER,
		EXTERNAL_BEHIND = BODY_BEHIND_LAYER,
	)
	offset_location = LOWER_BODY
	genital_stack_rank = 3

// taur_testicles_onmob.dmi only has art for the ADJACENT layer
/datum/bodypart_overlay/mutant/genital/testicles/get_all_overlays(obj/item/bodypart/limb)
	var/datum/sprite_accessory/genital/genital_datum = sprite_datum
	if(genital_datum?.uses_taur_sprite(limb?.owner))
		set_layers(list(EXTERNAL_ADJACENT = BODY_ADJ_LAYER - (genital_stack_rank * GENITAL_STACK_STEP)))
	else
		set_layers(list(
			EXTERNAL_FRONT_UNDER_CLOTHES = TESTICLES_LAYER,
			EXTERNAL_BEHIND = BODY_BEHIND_LAYER,
		))
	return ..()

/// Whether these testicles should currently render using the taur version
/obj/item/organ/genital/testicles/proc/uses_taur_mode()
	var/datum/bodypart_overlay/mutant/genital/testicles/our_overlay = bodypart_overlay
	var/datum/sprite_accessory/genital/genital_datum = our_overlay?.sprite_datum
	return !!genital_datum?.uses_taur_sprite(owner)

/// Re-syncs taur mode (e.g. after the "penis_taur_mode" DNA feature was toggled) and refreshes the sprite.
/obj/item/organ/genital/testicles/proc/refresh_taur_mode()
	update_sprite_suffix()
	owner?.update_body()

/obj/item/organ/genital/testicles/on_mob_insert(mob/living/carbon/organ_owner, special, movement_flags)
	. = ..()
	update_sprite_suffix()

/obj/item/organ/genital/testicles/update_genital_icon_state()
	var/measured_size = clamp(genital_size, 1, TESTICLES_MAX_SIZE)
	var/passed_string = "testicles_[genital_type]_[measured_size]"
	if(uses_skintones)
		passed_string += "_s"
	icon_state = passed_string

/obj/item/organ/genital/testicles/get_description_string(datum/sprite_accessory/genital/testicles/testicles)
	if(istype(testicles, /datum/sprite_accessory/genital/testicles/internal))
		visibility_preference = GENITAL_SKIP_VISIBILITY //Removes visibility if yes.
	else
		return "You see a pair of testicles, they look [LOWER_TEXT(balls_size_to_description(genital_size))]."

/obj/item/organ/genital/testicles/build_from_dna(datum/dna/DNA, associated_key)
	uses_skin_color = DNA.features["testicles_uses_skincolor"]
	genital_size = DNA.features["balls_size"]
	var/size = 0.5
	if(DNA.features["balls_size"] > 0)
		size = DNA.features["balls_size"]

	internal_fluid_maximum = size * 20

	return ..()

/obj/item/organ/genital/testicles/build_from_accessory(datum/sprite_accessory/genital/accessory, datum/dna/DNA)
	uses_skintones = DNA.features["testicles_uses_skintones"] ? accessory.has_skintone_shading : FALSE
	return ..()

/obj/item/organ/genital/testicles/get_sprite_size_string()
	var/datum/bodypart_overlay/mutant/genital/testicles/our_overlay = bodypart_overlay
	var/datum/sprite_accessory/genital/genital_datum = our_overlay?.sprite_datum
	var/taured = uses_taur_mode()
	// taur_testicles_onmob.dmi only goes up to size 6, and has no skintoned "_s" variants.
	var/affix_cap = taured ? genital_datum.taur_max_sprite_size_affix : max_sprite_size_affix
	var/measured_size = floor(genital_size)
	measured_size = clamp(measured_size, 0, affix_cap)
	var/passed_string = "[genital_type]_[measured_size]"
	if(uses_skintones && !taured)
		passed_string += "_s"
	return passed_string

/datum/bodypart_overlay/mutant/genital/testicles/get_global_feature_list()
	return SSaccessories.sprite_accessories[ORGAN_SLOT_TESTICLES]

/obj/item/organ/genital/testicles/proc/balls_size_to_description(number)
	if(number < 0)
		number = 0
	var/returned = GLOB.balls_size_translation["[number]"]
	if(!returned)
		returned = BREAST_SIZE_BEYOND_MEASUREMENT
	return returned

/obj/item/organ/genital/testicles/proc/balls_description_to_size(cup)
	for(var/key in GLOB.balls_size_translation)
		if(GLOB.balls_size_translation[key] == cup)
			return text2num(key)
	return 0
