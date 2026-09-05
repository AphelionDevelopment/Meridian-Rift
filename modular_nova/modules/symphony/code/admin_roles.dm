/// Prefix on an in-game role key, everything after it is the rank name.
#define SYMPHONY_ADMIN_ROLE_PREFIX "admin:"

/// Both, so the master switch really does turn it off.
/proc/symphony_discord_admin_sync_enabled()
	return CONFIG_GET(flag/symphony_enabled) && CONFIG_GET(flag/symphony_discord_admin_sync)

/// Has to run at the end of load_admins() - it Cut()s GLOB.admin_datums and would eat ours.
/proc/symphony_apply_discord_admins()
	if(!symphony_discord_admin_sync_enabled())
		return 0

	var/list/ranks_by_ckey = list()
	for(var/datum/admin_rank/rank as anything in GLOB.admin_ranks)
		if(!rank?.name)
			continue
		var/role_key = "[SYMPHONY_ADMIN_ROLE_PREFIX][rank.name]"
		var/list/holders = symphony_ingame_role_ckeys(role_key)
		// Fail closed, null is a failed query and not "nobody holds it".
		if(isnull(holders))
			continue
		for(var/holder_ckey in holders)
			if(GLOB.admin_datums[holder_ckey] || GLOB.deadmins[holder_ckey])
				continue
			var/list/ranks = ranks_by_ckey[holder_ckey]
			if(isnull(ranks))
				ranks_by_ckey[holder_ckey] = list(rank)
			else
				ranks |= rank

	// Gather every mapping before creating holders, or the first rank hides later grants.
	// The queries can sleep: preserve any local/SQL grants made while they were running.
	if(!symphony_discord_admin_sync_enabled())
		return 0
	var/granted = 0
	for(var/holder_ckey in ranks_by_ckey)
		if(GLOB.admin_datums[holder_ckey] || GLOB.deadmins[holder_ckey])
			continue
		new /datum/admins(ranks_by_ckey[holder_ckey], holder_ckey)
		granted++

	if(granted)
		log_admin("Symphony: granted [granted] admin\s from Discord roles.")
	return granted

/// Has to run after the ranks load, GLOB.admin_ranks is empty until then.
/proc/symphony_refresh_admin_role_keys()
	// Collected first, removed after - deleting while we iterate skips every other match.
	var/list/stale = list()
	for(var/key in GLOB.symphony_ingame_roles)
		if(findtext(key, SYMPHONY_ADMIN_ROLE_PREFIX) == 1)
			stale += key
	for(var/key in stale)
		GLOB.symphony_ingame_roles -= key

	if(!symphony_discord_admin_sync_enabled())
		return

	for(var/datum/admin_rank/rank as anything in GLOB.admin_ranks)
		if(!rank?.name)
			continue
		GLOB.symphony_ingame_roles["[SYMPHONY_ADMIN_ROLE_PREFIX][rank.name]"] = "Grants the in-game admin rank \"[rank.name]\"."

/// Kept apart from symphony_ingame_roles, this one has to work with Discord sync off.
/datum/world_topic/symphony/admin_ranks
	keyword = "symphony_admin_ranks"

/datum/world_topic/symphony/admin_ranks/Run(list/input)
	. = list()
	var/list/ranks = list()
	for(var/datum/admin_rank/rank as anything in GLOB.admin_ranks)
		if(!rank?.name)
			continue
		ranks += list(list(
			"name" = rank.name,
			// protected_ranks holds the rank datums, not their names - testing the name was always FALSE.
			"protected" = (rank in GLOB.protected_ranks) ? TRUE : FALSE,
		))
	.["ranks"] = ranks
	.["discord_sync"] = symphony_discord_admin_sync_enabled() ? TRUE : FALSE
	// With the legacy system on nothing reads the SQL admin tables, so a panel grant goes nowhere.
	.["legacy_admin_system"] = CONFIG_GET(flag/admin_legacy_system) ? TRUE : FALSE

/datum/world_topic/symphony/reload_admins
	keyword = "symphony_reload_admins"

/datum/world_topic/symphony/reload_admins/Run(list/input)
	. = list()
	load_admins()
	.["success"] = TRUE
	.["admins"] = length(GLOB.admin_datums)
	log_admin("Symphony: admins reloaded from the panel.")

#undef SYMPHONY_ADMIN_ROLE_PREFIX
