/**
 * Returns whether this ckey holds a Discord role that grants the given in-game role.
 *
 * Joins the Discord link table against the role grants, so an account nobody has linked is
 * simply a no.
 *
 * A failed query is NOT a no. It comes back null, so the caller can tell "we asked, and the
 * answer is no" from "we never got to ask". Anything gating entry should still treat null as
 * a refusal; anything writing the player a message about it should not.
 *
 * Arguments:
 * - target_ckey: The ckey to look up.
 * - role_key: The grant key to test for, e.g. "whitelist".
 *
 * Returns:
 * - TRUE/FALSE: Whether they hold a role granting it.
 * - null: The database was unreachable, or the query failed.
 */
/proc/symphony_has_ingame_role(target_ckey, role_key)
	target_ckey = ckey(target_ckey)
	if(!target_ckey || !role_key)
		return FALSE
	if(!SSdbcore.Connect())
		return null

	var/datum/db_query/query = SSdbcore.NewQuery(
		"SELECT 1 FROM [format_table_name("discord_links")] AS dl \
		JOIN [format_table_name("discord_member_roles")] AS mr ON mr.discord_id = dl.discord_id \
		JOIN [format_table_name("symphony_role_grants")] AS g ON g.discord_role_id = mr.role_id \
		WHERE dl.ckey = :ckey AND dl.valid = 1 AND g.grant_type = 'ingame' AND g.grant_key = :role_key LIMIT 1",
		list("ckey" = target_ckey, "role_key" = role_key),
	)
	if(!query.warn_execute())
		qdel(query)
		return null
	. = query.NextRow()
	qdel(query)

/// Everyone holding an in-game role key, ckey -> TRUE. Null if we couldn't check, empty if nobody has it.
/proc/symphony_ingame_role_ckeys(role_key)
	if(!role_key || !SSdbcore.Connect())
		return null

	var/datum/db_query/query = SSdbcore.NewQuery(
		"SELECT DISTINCT dl.ckey FROM [format_table_name("discord_links")] AS dl \
		JOIN [format_table_name("discord_member_roles")] AS mr ON mr.discord_id = dl.discord_id \
		JOIN [format_table_name("symphony_role_grants")] AS g ON g.discord_role_id = mr.role_id \
		WHERE dl.valid = 1 AND g.grant_type = 'ingame' AND g.grant_key = :role_key",
		list("role_key" = role_key),
	)
	if(!query.warn_execute())
		qdel(query)
		return null
	var/list/holders = list()
	while(query.NextRow())
		holders[ckey(query.item[1])] = TRUE
	qdel(query)
	return holders

/// Cached whitelist answers, keyed by ckey. Only here to eat bursts, anything that changes a grant drops it.
GLOBAL_LIST_EMPTY(symphony_whitelist_cache)
GLOBAL_LIST_EMPTY(symphony_whitelist_cache_expiry)
/// Bumped on invalidation, so a slept lookup knows it was overtaken.
GLOBAL_VAR_INIT(symphony_whitelist_epoch, 0)

#define SYMPHONY_WHITELIST_CACHE_TIME (10 SECONDS)

/// Forget a ckey, so a grant or revoke lands now instead of after the TTL.
/proc/symphony_invalidate_whitelist_cache(target_ckey)
	target_ckey = ckey(target_ckey)
	if(!target_ckey)
		return
	GLOB.symphony_whitelist_cache -= target_ckey
	GLOB.symphony_whitelist_cache_expiry -= target_ckey
	GLOB.symphony_whitelist_epoch++

/**
 * Writes an answer we already know to be good straight into the whitelist cache.
 *
 * Used for panel notifications and the subsystem's checked bulk snapshot. Blanking these
 * entries instead would make each client query for an answer we already have.
 *
 * The epoch bump is what stops a lookup still asleep on the database from landing its staler
 * single-row result on top of this one.
 *
 * Arguments:
 * - target_ckey: The ckey to write.
 * - whitelisted: TRUE or FALSE. Never pass null - the cache uses that to mean "don't know".
 */
/proc/symphony_seed_whitelist_cache(target_ckey, whitelisted)
	target_ckey = ckey(target_ckey)
	if(!target_ckey)
		return
	GLOB.symphony_whitelist_cache[target_ckey] = whitelisted
	GLOB.symphony_whitelist_cache_expiry[target_ckey] = world.time + SYMPHONY_WHITELIST_CACHE_TIME
	GLOB.symphony_whitelist_epoch++

/// Cache-only lookup, never touches the DB and so never sleeps. TRUE/FALSE if cached, null if we don't know yet.
/proc/symphony_whitelist_cache_peek(target_ckey)
	target_ckey = ckey(target_ckey)
	if(!target_ckey)
		return null
	var/expiry = GLOB.symphony_whitelist_cache_expiry[target_ckey]
	if(!expiry || world.time >= expiry)
		return null
	return GLOB.symphony_whitelist_cache[target_ckey]

/**
 * Returns whether this ckey holds the whitelist role, and whether we could even find out.
 *
 * The cached, sleep-capable path everything else here is built on. A hit answers out of the
 * cache, a miss goes to the database and caches whatever comes back.
 *
 * Only ever caches a real answer. Banking a database outage as "not whitelisted" would keep
 * refusing them for the rest of the TTL after the database came back, and would have the lobby
 * draw a rejection at someone whose whitelist was never in question.
 *
 * Can sleep on a cache miss - use symphony_whitelist_cache_peek() where you can't afford that.
 *
 * Arguments:
 * - target_ckey: The ckey to look up.
 *
 * Returns:
 * - TRUE/FALSE: Whether they hold the whitelist role.
 * - null: The database was unreachable, so nothing was cached and nothing is known.
 */
/proc/symphony_whitelist_lookup(target_ckey)
	target_ckey = ckey(target_ckey)
	if(!target_ckey)
		return FALSE
	while(TRUE)
		var/cached = symphony_whitelist_cache_peek(target_ckey)
		if(!isnull(cached))
			return cached
		var/epoch = GLOB.symphony_whitelist_epoch
		var/answer = symphony_has_ingame_role(target_ckey, "whitelist")
		// A notification can overtake even a failed query. Use its answer, or retry if it only invalidated the cache.
		if(epoch != GLOB.symphony_whitelist_epoch)
			continue
		if(isnull(answer))
			return null
		GLOB.symphony_whitelist_cache[target_ckey] = answer
		GLOB.symphony_whitelist_cache_expiry[target_ckey] = world.time + SYMPHONY_WHITELIST_CACHE_TIME
		return answer

/**
 * Returns whether this ckey is allowed into the round.
 *
 * The blunt version of symphony_whitelist_lookup(), for the paths that only want a yes or a no.
 *
 * Fails OPEN when the module is disabled - it's a gate, not an entitlement, so nothing being
 * enforced means everyone walks through. Fails CLOSED on a database error.
 *
 * Reach for symphony_whitelist_lookup() instead anywhere you need to tell "no" apart from
 * "couldn't ask", which is anything that ejects a player or writes them a reason why.
 *
 * Arguments:
 * - target_ckey: The ckey to check.
 *
 * Returns:
 * - TRUE/FALSE: Whether they may play.
 */
/proc/is_symphony_whitelisted(target_ckey)
	if(!CONFIG_GET(flag/symphony_enabled))
		return TRUE
	return symphony_whitelist_lookup(target_ckey) ? TRUE : FALSE

/**
 * Returns whether this ckey actually holds the whitelist role as an entitlement.
 *
 * The mirror image of is_symphony_whitelisted(). That one asks "may they play", this one asks
 * "did Discord genuinely grant them this", which is what you want when hanging a perk off the
 * role rather than gating entry on it.
 *
 * So it fails CLOSED when the module is disabled - if nothing is handing the role out then
 * nobody holds it - and it skips the cache, because the handful of things asking can afford
 * the query.
 *
 * Arguments:
 * - target_ckey: The ckey to check.
 *
 * Returns:
 * - TRUE/FALSE: Whether they hold the role. A database error is a FALSE.
 */
/proc/symphony_holds_whitelist_role(target_ckey)
	while(CONFIG_GET(flag/symphony_enabled))
		var/epoch = GLOB.symphony_whitelist_epoch
		var/answer = symphony_has_ingame_role(target_ckey, "whitelist")
		if(!CONFIG_GET(flag/symphony_enabled))
			return FALSE
		// Imports and perks need a current entitlement too, while retaining their uncached lookup.
		if(epoch != GLOB.symphony_whitelist_epoch)
			continue
		return answer ? TRUE : FALSE
	return FALSE

#undef SYMPHONY_WHITELIST_CACHE_TIME
