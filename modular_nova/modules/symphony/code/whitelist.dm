/// Does this ckey hold a Discord role that grants the in-game role? Fail-closed, a DB error is a no.
/proc/symphony_has_ingame_role(target_ckey, role_key)
	target_ckey = ckey(target_ckey)
	if(!target_ckey || !role_key)
		return FALSE
	if(!SSdbcore.Connect())
		return FALSE

	var/datum/db_query/query = SSdbcore.NewQuery(
		"SELECT 1 FROM [format_table_name("discord_links")] AS dl \
		JOIN [format_table_name("discord_member_roles")] AS mr ON mr.discord_id = dl.discord_id \
		JOIN [format_table_name("symphony_role_grants")] AS g ON g.discord_role_id = mr.role_id \
		WHERE dl.ckey = :ckey AND dl.valid = 1 AND g.grant_type = 'ingame' AND g.grant_key = :role_key LIMIT 1",
		list("ckey" = target_ckey, "role_key" = role_key),
	)
	if(!query.warn_execute())
		qdel(query)
		return FALSE
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

#define SYMPHONY_WHITELIST_CACHE_TIME (10 SECONDS)

/// Forget a ckey, so a grant or revoke lands now instead of after the TTL.
/proc/symphony_invalidate_whitelist_cache(target_ckey)
	target_ckey = ckey(target_ckey)
	if(!target_ckey)
		return
	GLOB.symphony_whitelist_cache -= target_ckey
	GLOB.symphony_whitelist_cache_expiry -= target_ckey

/// TRUE if the gate is off, or we hold the whitelist role. Fail-OPEN when disabled - it's a gate, not an entitlement.
/proc/is_symphony_whitelisted(target_ckey)
	if(!CONFIG_GET(flag/symphony_enabled))
		return TRUE
	target_ckey = ckey(target_ckey)
	if(!target_ckey)
		return FALSE
	var/expiry = GLOB.symphony_whitelist_cache_expiry[target_ckey]
	if(expiry && world.time < expiry)
		return GLOB.symphony_whitelist_cache[target_ckey]
	. = symphony_has_ingame_role(target_ckey, "whitelist")
	GLOB.symphony_whitelist_cache[target_ckey] = .
	GLOB.symphony_whitelist_cache_expiry[target_ckey] = world.time + SYMPHONY_WHITELIST_CACHE_TIME

/// The entitlement version, fail-CLOSED - if the module is off then nothing granted it, so nobody has it.
/proc/symphony_holds_whitelist_role(target_ckey)
	if(!CONFIG_GET(flag/symphony_enabled))
		return FALSE
	return symphony_has_ingame_role(target_ckey, "whitelist")

#undef SYMPHONY_WHITELIST_CACHE_TIME
