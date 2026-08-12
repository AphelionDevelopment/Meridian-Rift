/**
 * Finding the plate that stands between an attack and a bodypart.
 *
 * [/mob/living/proc/apply_damage] asks for a plate once per attack that carries an armour flag. If it
 * gets one, that plate decides the hit instead of the percentage model: everything up to its
 * tolerance is stopped outright and the rest lands unarmoured.
 *
 * Only carbons with clothing have plates. Fire, pressure, explosions and poison carry no armour flag
 * and never ask, so environmental damage skips the plate model.
 */

/**
 * The working plate covering a bodypart against this sort of attack, if there is one.
 *
 * Arguments:
 * * damagetype - One of the damage types. Only [BRUTE] and [BURN] meet a plate.
 * * armour_flag - The attack's armour flag, e.g. [BULLET] or [LASER].
 * * def_zone - Bodypart or zone the attack landed on.
 */
/mob/living/proc/get_covering_plate(damagetype, armour_flag, def_zone)
	return null

/// Whether a fitted plate occupies the carrier covering this zone, even if it is spent or the wrong type.
/mob/living/proc/has_fitted_plate_covering(def_zone)
	return FALSE

/mob/living/carbon/human/get_covering_plate(damagetype, armour_flag, def_zone)
	if(damagetype != BRUTE && damagetype != BURN)
		return null
	if(isnull(def_zone))
		return null

	var/obj/item/bodypart/hit_part = isbodypart(def_zone) ? def_zone : get_bodypart(check_zone(def_zone))
	if(isnull(hit_part))
		return null

	// Helmet before suit, since the only zone both could claim is a head the suit has a hood over.
	return get_plate_from(head, hit_part, armour_flag) || get_plate_from(wear_suit, hit_part, armour_flag)

/mob/living/carbon/human/has_fitted_plate_covering(def_zone)
	if(isnull(def_zone))
		return FALSE

	var/obj/item/bodypart/hit_part = isbodypart(def_zone) ? def_zone : get_bodypart(check_zone(def_zone))
	if(isnull(hit_part))
		return FALSE

	return plate_covers_part(head, hit_part) || plate_covers_part(wear_suit, hit_part)

/// Whether this carrier has a fitted plate over the bodypart. Its condition and type do not matter.
/mob/living/carbon/human/proc/plate_covers_part(obj/item/clothing/carrier, obj/item/bodypart/hit_part)
	return !isnull(carrier?.fitted_plate) && (carrier.body_parts_covered & hit_part.body_part)

/**
 * The plate in one worn item, if it has one that covers this part and cares about this attack.
 *
 * A spent plate, or one of the wrong sort for the attack, does not stop the hit. The fitted plate
 * still occupies the carrier, so the hit lands unarmoured rather than falling back to percentages.
 *
 * Arguments:
 * * carrier - The worn item that might hold a plate.
 * * hit_part - The bodypart the attack landed on.
 * * armour_flag - The attack's armour flag.
 */
/mob/living/carbon/human/proc/get_plate_from(obj/item/clothing/carrier, obj/item/bodypart/hit_part, armour_flag)
	RETURN_TYPE(/obj/item/armor_plate)

	var/obj/item/armor_plate/fitted = carrier?.fitted_plate
	if(isnull(fitted) || !fitted.is_working() || !fitted.stops_attack(armour_flag))
		return null
	if(!(carrier.body_parts_covered & hit_part.body_part))
		return null
	return fitted
