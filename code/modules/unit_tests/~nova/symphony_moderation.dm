/// Database fixtures never open a connection or execute SQL.
/datum/controller/subsystem/dbcore/symphony_moderation_test
	name = "Symphony moderation test fixture"
	ss_flags = SS_NO_INIT | SS_NO_FIRE
	var/list/role_holders = list()
	var/list/ban_row
	var/list/note_arguments
	var/callback_role
	var/datum/callback/during_query

/datum/controller/subsystem/dbcore/symphony_moderation_test/New()
	// The subsystem constructor would replace the real SSdbcore.
	return

/datum/controller/subsystem/dbcore/symphony_moderation_test/OnConfigLoad()
	return

/datum/controller/subsystem/dbcore/symphony_moderation_test/Shutdown()
	return

/datum/controller/subsystem/dbcore/symphony_moderation_test/Connect()
	return TRUE

/datum/controller/subsystem/dbcore/symphony_moderation_test/NewQuery(sql_query, list/arguments, allow_during_shutdown = FALSE)
	var/datum/db_query/symphony_moderation_test/query = new
	query.rows = list()
	if(arguments["role_key"])
		for(var/holder_ckey in role_holders[arguments["role_key"]])
			query.rows += list(list(holder_ckey))
		if(arguments["role_key"] == callback_role)
			query.during_query = during_query
			during_query = null
	else if(arguments["text"])
		note_arguments = arguments.Copy()
	return query

/datum/controller/subsystem/dbcore/symphony_moderation_test/MassInsert(table, list/rows, duplicate_key = FALSE, ignore_errors = FALSE, warn = FALSE, async = TRUE, special_columns = null)
	var/list/row = rows[1]
	ban_row = row.Copy()
	return TRUE

/datum/db_query/symphony_moderation_test
	var/datum/callback/during_query

/datum/db_query/symphony_moderation_test/New()
	return

/datum/db_query/symphony_moderation_test/Destroy()
	during_query = null
	return ..()

/datum/db_query/symphony_moderation_test/warn_execute(async = TRUE)
	// Reproduce a change at the yielding query boundary without yielding the global fixture.
	during_query?.Invoke()
	return TRUE

/datum/db_query/symphony_moderation_test/NextRow(async = TRUE)
	if(next_row_to_take > length(rows))
		return FALSE
	item = rows[next_row_to_take++]
	return TRUE

/// Keep real clients, admin holders, configuration, and the database out of these tests.
/datum/unit_test/symphony_moderation
	abstract_type = /datum/unit_test/symphony_moderation
	var/datum/controller/subsystem/dbcore/previous_db
	var/datum/controller/subsystem/dbcore/symphony_moderation_test/test_db
	var/list/previous_admins
	var/list/previous_deadmins
	var/list/previous_ranks
	var/list/previous_clients
	var/list/previous_directory
	var/previous_enabled
	var/previous_admin_sync

/datum/unit_test/symphony_moderation/New()
	..()
	previous_db = SSdbcore
	previous_admins = GLOB.admin_datums
	previous_deadmins = GLOB.deadmins
	previous_ranks = GLOB.admin_ranks
	previous_clients = GLOB.clients
	previous_directory = GLOB.directory
	previous_enabled = CONFIG_GET(flag/symphony_enabled)
	previous_admin_sync = CONFIG_GET(flag/symphony_discord_admin_sync)
	test_db = allocate(/datum/controller/subsystem/dbcore/symphony_moderation_test)
	SSdbcore = test_db
	GLOB.admin_datums = list()
	GLOB.deadmins = list()
	GLOB.admin_ranks = list()
	GLOB.clients = list()
	GLOB.directory = list()
	CONFIG_SET(flag/symphony_enabled, TRUE)
	CONFIG_SET(flag/symphony_discord_admin_sync, TRUE)

/datum/unit_test/symphony_moderation/Destroy()
	SSdbcore = previous_db
	GLOB.admin_datums = previous_admins
	GLOB.deadmins = previous_deadmins
	GLOB.admin_ranks = previous_ranks
	GLOB.clients = previous_clients
	GLOB.directory = previous_directory
	CONFIG_SET(flag/symphony_enabled, previous_enabled)
	CONFIG_SET(flag/symphony_discord_admin_sync, previous_admin_sync)
	return ..()

/datum/unit_test/symphony_moderation/plain_text_ban/Run()
	var/admin_name = "<img src=x> & Admin"
	var/reason = "<b>Reason</b> & &lt;literal&gt;"
	var/datum/world_topic/symphony/ban/topic = allocate(/datum/world_topic/symphony/ban)
	var/list/result = topic.Run(list(
		"target_ckey" = "symphonytestban",
		"admin_name" = admin_name,
		"reason" = reason,
		"role" = "Server",
		"match_ip_cid" = "0",
	))
	TEST_ASSERT(result["success"], "The fixture ban should succeed")
	TEST_ASSERT_EQUAL(test_db.ban_row["reason"], html_encode(reason), "The ban browser must display the external reason as literal text")
	TEST_ASSERT_EQUAL(test_db.note_arguments["text"], html_encode("Banned via Symphony by [admin_name] (Server): [reason]"), "The notes browser must display the whole external note as literal text")

/datum/unit_test/symphony_moderation/multiple_admin_ranks/Run()
	var/datum/admin_rank/first_rank = allocate(/datum/admin_rank, "SymphonyFirst", RANK_SOURCE_DB, R_BAN)
	var/datum/admin_rank/second_rank = allocate(/datum/admin_rank, "SymphonySecond", RANK_SOURCE_DB, R_DEBUG)
	GLOB.admin_ranks = list(first_rank, second_rank)
	var/list/holders = list("symphonytestnew", "symphonytestlocal", "symphonytestdeadmin")
	test_db.role_holders["admin:SymphonyFirst"] = holders
	test_db.role_holders["admin:SymphonySecond"] = holders
	// Existing local/SQL grants take precedence, including deadmined accounts.
	GLOB.admin_datums["symphonytestlocal"] = TRUE
	GLOB.deadmins["symphonytestdeadmin"] = TRUE
	var/granted = symphony_apply_discord_admins()
	var/datum/admins/new_holder = GLOB.admin_datums["symphonytestnew"] || GLOB.deadmins["symphonytestnew"]
	if(new_holder)
		allocated += new_holder
	TEST_ASSERT_EQUAL(granted, 1, "An account with two mappings should receive exactly one holder")
	TEST_ASSERT_NOTNULL(new_holder, "The new Discord admin should receive a holder")
	TEST_ASSERT_EQUAL(length(new_holder.ranks), 2, "Every mapped rank must be retained")
	TEST_ASSERT_EQUAL(new_holder.rank_flags(), R_BAN | R_DEBUG, "Both mapped ranks must contribute their existing rights")
	TEST_ASSERT_EQUAL(GLOB.admin_datums["symphonytestlocal"], TRUE, "Local/SQL admin holders must retain precedence")
	TEST_ASSERT_EQUAL(GLOB.deadmins["symphonytestdeadmin"], TRUE, "Local/SQL deadmined holders must retain precedence")

/datum/unit_test/symphony_moderation/admin_grant_during_query/Run()
	var/datum/admin_rank/first_rank = allocate(/datum/admin_rank, "SymphonyFirst", RANK_SOURCE_DB, R_BAN)
	var/datum/admin_rank/second_rank = allocate(/datum/admin_rank, "SymphonySecond", RANK_SOURCE_DB, R_DEBUG)
	GLOB.admin_ranks = list(first_rank, second_rank)
	test_db.role_holders["admin:SymphonyFirst"] = list("symphonytestlate")
	test_db.role_holders["admin:SymphonySecond"] = list("symphonytestlate")
	test_db.callback_role = "admin:SymphonySecond"
	test_db.during_query = CALLBACK(src, PROC_REF(grant_local_admin))
	TEST_ASSERT_EQUAL(symphony_apply_discord_admins(), 0, "A local/SQL grant made during queries must keep precedence")
	TEST_ASSERT_EQUAL(GLOB.admin_datums["symphonytestlate"], TRUE, "The new local/SQL holder must not be replaced")

/datum/unit_test/symphony_moderation/admin_grant_during_query/proc/grant_local_admin()
	GLOB.admin_datums["symphonytestlate"] = TRUE

/datum/unit_test/symphony_moderation/admin_sync_disabled_during_query/Run()
	var/datum/admin_rank/rank = allocate(/datum/admin_rank, "SymphonyFirst", RANK_SOURCE_DB, R_BAN)
	GLOB.admin_ranks = list(rank)
	test_db.role_holders["admin:SymphonyFirst"] = list("symphonytestdisabled")
	test_db.callback_role = "admin:SymphonyFirst"
	test_db.during_query = CALLBACK(src, PROC_REF(disable_sync))
	TEST_ASSERT_EQUAL(symphony_apply_discord_admins(), 0, "Disabling sync during the query must prevent new admin grants")
	TEST_ASSERT_NULL(GLOB.admin_datums["symphonytestdisabled"] || GLOB.deadmins["symphonytestdisabled"], "Disabled sync must not create a holder")

/datum/unit_test/symphony_moderation/admin_sync_disabled_during_query/proc/disable_sync()
	CONFIG_SET(flag/symphony_discord_admin_sync, FALSE)
