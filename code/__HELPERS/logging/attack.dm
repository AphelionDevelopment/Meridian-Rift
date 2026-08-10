/// Generic attack logging
/proc/log_attack(text, list/data)
	logger.Log(LOG_CATEGORY_ATTACK, text, data)

/**
 * Log a combat message in the attack log
 *
 * Arguments:
 * * atom/user - argument is the actor performing the action
 * * atom/target - argument is the target of the action
 * * what_done - is a verb describing the action (e.g. punched, throwed, kicked, etc.)
 * * atom/object - is a tool with which the action was made (usually an item)
 * * addition - is any additional text, which will be appended to the rest of the log line
 */
/proc/log_combat(atom/user, atom/target, what_done, atom/object=null, addition=null)
	var/ssource = key_name(user)
	var/starget = key_name(target)

	var/mob/living/living_target = target
	var/hp = istype(living_target) ? " (NEWHP: [living_target.health]) " : ""

	var/sobject = ""
	if(object)
		sobject = " with [object]"
	var/saddition = ""
	if(addition)
		saddition = " [addition]"

	var/postfix = "[sobject][saddition][hp]"

	var/message = "[what_done] [starget][postfix]"
	user.log_message(message, LOG_ATTACK, color="red")

	if(user != target)
		var/reverse_message = "was [what_done] by [ssource][postfix]"
		target.log_message(reverse_message, LOG_VICTIM, color="orange", log_globally=FALSE)

/**
 * log_wound() is for when someone is *attacked* and suffers a wound. Note that this only captures wounds from damage, so smites/forced wounds aren't logged, as well as demotions like cuts scabbing over
 *
 * Note that this has no info on the attack that dealt the wound: information about where damage came from isn't passed to the bodypart's damaged proc. When in doubt, check the attack log for attacks at that same time
 * TODO later: Add logging for healed wounds, though that will require some rewriting of healing code to prevent admin heals from spamming the logs. Not high priority
 *
 * Arguments:
 * * victim- The guy who got wounded
 * * suffered_wound- The wound, already applied, that we're logging. It has to already be attached so we can get the limb from it
 * * dealt_damage- How much damage is associated with the attack that dealt with this wound.
 * * dealt_wound_bonus- The wound_bonus, if one was specified, of the wounding attack
 * * dealt_exposed_wound_bonus- The exposed_wound_bonus, if one was specified *and applied*, of the wounding attack. Not shown if armor was present
 * * base_roll- The injury score the wound was decided on: the part's accumulated damage of this wounding type, after mods
 */
/proc/log_wound(atom/victim, datum/wound/suffered_wound, dealt_damage, dealt_wound_bonus, dealt_exposed_wound_bonus, base_roll)
	if(QDELETED(victim) || !suffered_wound)
		return
	var/message = "suffered: [suffered_wound][suffered_wound.limb ? " to [suffered_wound.limb.plaintext_zone]" : null]"// maybe indicate if it's a promote/demote?

	if(dealt_damage)
		message += " | Damage: [dealt_damage]"
		// The score is what the injury was decided on: this part's accumulated damage of this type,
		// after armour and every other modifier. It says how close the next tier is.
		if(base_roll)
			message += " (injury score [round(base_roll, 0.1)])"

	if(dealt_wound_bonus)
		message += " | WB: [dealt_wound_bonus]"

	if(dealt_exposed_wound_bonus)
		message += " | BWB: [dealt_exposed_wound_bonus]"

	victim.log_message(message, LOG_ATTACK, color="blue")

/**
 * log_overflow() is for damage that ran out of bodypart to go into and landed on what the part was
 * protecting instead. It is one of exactly two ways combat is allowed to kill, so it gets a category
 * of its own alongside the attack log it also writes to.
 *
 * Arguments:
 * * victim - Whoever it happened to
 * * weapon - What did it, if the damage carried a source
 * * zone - Plaintext name of the bodypart that had nothing left to give
 * * target_description - What the damage landed on instead: an organ, or dismemberment
 * * amount - How much landed there
 */
/proc/log_overflow(atom/victim, atom/weapon, zone, target_description, amount)
	if(QDELETED(victim))
		return

	var/message = "OVERFLOW: [zone] -> [target_description] ([round(amount, 0.1)])[weapon ? " from [weapon]" : ""]"
	logger.Log(LOG_CATEGORY_EXECUTION, "[key_name(victim)]: [message]")
	victim.log_message(message, LOG_ATTACK, color = "red")

/**
 * log_finisher() is for an execution: a deliberate killing blow on someone who had already stopped
 * being able to stop it. The other of the two ways combat kills, and the one worth reading first.
 *
 * Arguments:
 * * victim - Whoever was finished off
 * * user - Whoever did it
 * * weapon - What they did it with
 */
/proc/log_finisher(atom/victim, atom/user, atom/weapon)
	if(QDELETED(victim))
		return

	logger.Log(LOG_CATEGORY_EXECUTION, "[key_name(user)] -> [key_name(victim)]: FINISHER[weapon ? " with [weapon]" : ""]")
	log_combat(user, victim, "executed", weapon)

/// Logging for bombs detonating
/proc/log_bomber(atom/user, details, atom/bomb, additional_details, message_admins = TRUE)
	var/bomb_message = "[details][bomb ? " [bomb.name] at [AREACOORD(bomb)]": ""][additional_details ? " [additional_details]" : ""]."

	if(user)
		user.log_message(bomb_message, LOG_ATTACK) //let it go to individual logs as well as the game log
		bomb_message = "[key_name(user)] at [AREACOORD(user)] [bomb_message]."
	log_game(bomb_message)

	GLOB.bombers += bomb_message
	var/area/bomb_area = get_area(bomb)
	if(message_admins && !(bomb_area?.area_flags & QUIET_LOGS)) // Don't spam the logs with deathmatch bombs
		message_admins("[user ? "[ADMIN_LOOKUPFLW(user)] at [ADMIN_VERBOSEJMP(user)] " : ""][details][bomb ? " [bomb.name] at [ADMIN_VERBOSEJMP(bomb)]": ""][additional_details ? " [additional_details]" : ""].")
