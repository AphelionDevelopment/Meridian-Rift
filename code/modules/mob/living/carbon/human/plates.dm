/**
 * Finding the plate that stands between an attack and a bodypart.
 *
 * [/mob/living/proc/apply_damage] asks for a plate once per attack that carries an armour flag. If it
 * gets one, that plate decides the hit instead of the percentage model: everything up to its
 * tolerance is stopped outright and the rest lands unarmoured. A covered carrier with no working,
 * matching plate also suppresses its legacy percentage armour, so the whole hit penetrates.
 *
 * Only carbons with clothing have plates. Fire, pressure, explosions and poison carry no armour flag
 * and never ask, so environmental damage skips the plate model.
 */

/**
 * The plate carrier standing between an attack and a bodypart, if there is one.
 *
 * The single traversal every other question here is asked through. A carrier owns its covered hit
 * whether or not it has anything to stop it with, which is what suppresses the percentage model;
 * whether the hit is actually stopped is [/obj/item/clothing/proc/get_answering_plate]'s business.
 *
 * Arguments:
 * * damagetype - One of the damage types. Only [BRUTE] and [BURN] meet a plate.
 * * armour_flag - The attack's armour flag, e.g. [BULLET] or [LASER].
 * * def_zone - Bodypart or zone the attack landed on.
 */
/mob/living/proc/get_plate_carrier(damagetype, armour_flag, def_zone)
	return null

/**
 * The working plate covering a bodypart against this sort of attack, if there is one.
 *
 * Arguments:
 * * damagetype - One of the damage types. Only [BRUTE] and [BURN] meet a plate.
 * * armour_flag - The attack's armour flag, e.g. [BULLET] or [LASER].
 * * def_zone - Bodypart or zone the attack landed on.
 */
/mob/living/proc/get_covering_plate(damagetype, armour_flag, def_zone)
	RETURN_TYPE(/obj/item/armor_plate)

	var/obj/item/clothing/carrier = get_plate_carrier(damagetype, armour_flag, def_zone)
	return carrier?.get_answering_plate(armour_flag)

/**
 * Whether a plate stops a hit outright, so that none of it reaches the body.
 *
 * Asked by everything an attack does to a body besides its damage — embedding, most of all. A plate
 * answers a hit in place of the percentage model, so `blocked` stays at zero however much the plate
 * caught, and anything reading `blocked` to decide whether the attack got inside needs this instead.
 *
 * Arguments:
 * * damage - The whole hit, before anything is taken off it.
 * * damagetype - One of the damage types.
 * * armour_flag - The attack's armour flag, e.g. [BULLET] or [LASER].
 * * def_zone - Bodypart or zone the attack landed on.
 */
/mob/living/proc/plate_stops_hit(damage, damagetype, armour_flag, def_zone)
	// Nothing to stop, so nothing stopped it. Keeps harmless sticky things sticking to armour.
	if(damage <= 0)
		return FALSE

	var/obj/item/armor_plate/covering = get_covering_plate(damagetype, armour_flag, def_zone)
	return !isnull(covering) && damage <= covering.get_tolerance()

/mob/living/carbon/human/get_plate_carrier(damagetype, armour_flag, def_zone)
	RETURN_TYPE(/obj/item/clothing)

	if(damagetype != BRUTE && damagetype != BURN)
		return null
	if(isnull(def_zone))
		return null

	var/obj/item/bodypart/hit_part = isbodypart(def_zone) ? def_zone : get_bodypart(check_zone(def_zone))
	if(isnull(hit_part))
		return null

	var/obj/item/clothing/helmet = plate_carrier_covers_part(head, hit_part) ? head : null
	var/obj/item/clothing/suit = plate_carrier_covers_part(wear_suit, hit_part) ? wear_suit : null

	// Helmet before suit, since the only zone both could claim is a head the suit has a hood over.
	// A carrier holding a plate that answers this attack wins outright; failing that either will do,
	// as neither is going to stop anything.
	if(helmet?.get_answering_plate(armour_flag))
		return helmet
	if(suit?.get_answering_plate(armour_flag))
		return suit
	return helmet || suit

/// Whether this item is a plate carrier worn over the bodypart. A carrier needs a working plate to protect it.
/mob/living/carbon/human/proc/plate_carrier_covers_part(obj/item/clothing/carrier, obj/item/bodypart/hit_part)
	return carrier?.accepts_armor_plates && (carrier.body_parts_covered & hit_part.body_part)
