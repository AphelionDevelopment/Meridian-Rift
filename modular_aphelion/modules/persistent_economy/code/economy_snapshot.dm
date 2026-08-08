/// Directory every player's ledger lives under, as `<saves>/<first letter>/<ckey>/`.
#define PLAYER_SAVES_PATH "data/player_saves/"
/// Filename each player's ledger is written to inside their save directory.
#define PLAYER_LEDGER_FILENAME "persistent_economy.json"

/**
 * Every player ledger file on disk, as an assoc of file path to the ckey that owns it.
 *
 * Walks the save tree rather than asking who is playing, so it finds the characters of players who are
 * not in the round. Most of the money in a persistent economy sits in accounts nobody is holding.
 */
/proc/list_player_ledger_files()
	var/list/ledger_files = list()
	for(var/letter_directory in flist(PLAYER_SAVES_PATH))
		for(var/ckey_directory in flist("[PLAYER_SAVES_PATH][letter_directory]"))
			var/file_path = "[PLAYER_SAVES_PATH][letter_directory][ckey_directory][PLAYER_LEDGER_FILENAME]"
			if(fexists(file_path))
				// flist returns directories with a trailing slash, which is not part of the ckey.
				ledger_files[file_path] = copytext(ckey_directory, 1, -1)
			CHECK_TICK

	return ledger_files

/**
 * Reduces a raw ledger record to the figures a cross-ledger view needs, or null if it is unreadable.
 *
 * Forgiving in one direction only. A record missing a holder or a debt is summarised without them,
 * since neither changes what the account is worth, but one whose balance is not a number is dropped. A
 * corrupt record should be missing from a total rather than counted as zero, which would read as a
 * player who spent everything.
 * Arguments:
 * * record - a decoded ledger record, from an open ledger or straight off disk.
 */
/proc/summarise_ledger_record(list/record)
	if(!islist(record))
		return null

	var/record_version = record[LEDGER_FIELD_VERSION]
	if(isnum(record_version) && record_version > LEDGER_SCHEMA_VERSION)
		return null

	var/stored_balance = record[LEDGER_FIELD_BALANCE]
	if(!isnum(stored_balance))
		return null

	var/stored_debt = record[LEDGER_FIELD_DEBT]
	var/stored_holder = record[LEDGER_FIELD_HOLDER]
	return list(
		"balance" = clamp(stored_balance, -LEDGER_BALANCE_LIMIT, LEDGER_BALANCE_LIMIT),
		"debt" = isnum(stored_debt) ? clamp(stored_debt, 0, LEDGER_BALANCE_LIMIT) : 0,
		"holder" = istext(stored_holder) ? stored_holder : null,
	)

/**
 * Every record in every ledger, open or not, newest state first.
 *
 * An open ledger is read from memory and a closed one off disk, because those disagree. A
 * [/datum/json_database] defers its writes to the end of the tick, so the file behind an open ledger
 * is at least one save stale, and straight after [/proc/flush_economy_ledgers] it is missing the whole
 * round's last flush.
 *
 * Each entry carries `source` (the ckey for a player ledger, "station" for the shared one), `key`,
 * `holder`, `balance`, `debt` and `live` (whether an account is bound to that key this round).
 */
/proc/collect_all_ledger_records()
	var/list/all_records = list()
	var/datum/economy_ledger/station_ledger = get_station_ledger()

	for(var/ledger_path in GLOB.economy_ledgers)
		var/datum/economy_ledger/ledger = GLOB.economy_ledgers[ledger_path]
		var/list/open_records = ledger.read_all()
		for(var/record_key in open_records)
			var/list/summary = summarise_ledger_record(open_records[record_key])
			if(isnull(summary))
				continue
			summary["source"] = (ledger == station_ledger) ? "station" : ledger_owner_ckey(ledger_path)
			summary["key"] = record_key
			summary["live"] = !isnull(ledger.live_accounts[record_key])
			all_records += list(summary)
			CHECK_TICK

	var/list/ledger_files = list_player_ledger_files()
	for(var/file_path in ledger_files)
		if(GLOB.economy_ledgers[file_path])
			continue

		var/list/stored_records = safe_json_decode(file2text(file_path))
		if(!islist(stored_records))
			continue

		for(var/record_key in stored_records)
			var/list/summary = summarise_ledger_record(stored_records[record_key])
			if(isnull(summary))
				continue
			summary["source"] = ledger_files[file_path]
			summary["key"] = record_key
			summary["live"] = FALSE
			all_records += list(summary)
			CHECK_TICK

	return all_records

/**
 * The ckey whose save directory a ledger path sits in, or the path itself if it is not one.
 * Arguments:
 * * ledger_path - path of the file a ledger backs onto.
 */
/proc/ledger_owner_ckey(ledger_path)
	var/list/path_segments = splittext(ledger_path, "/")
	if(length(path_segments) < 2)
		return ledger_path

	return path_segments[length(path_segments) - 1]

/// Orders ledger record summaries richest first, for a view whose job is to surface the outliers.
/proc/cmp_ledger_record_balance_dsc(list/first_record, list/second_record)
	return second_record["balance"] - first_record["balance"]

/**
 * Logs the size of the whole economy, once, at round end.
 *
 * Every figure this module turns on is a guess without it. The two levies, the department grant
 * ceiling and the operating charge are all calibrated against how fast the supply is growing, and
 * nothing else measures that: blackbox tracks flows like credits levied, which says how hard the sinks
 * are working but not whether they are keeping up. Prices for whatever persistent money eventually
 * buys come from this number too.
 *
 * Called from [/proc/flush_economy_ledgers], after every account has written itself back and while the
 * ledgers are still open, so the total covers the round that just ended.
 */
/proc/log_economy_snapshot()
	var/list/all_records = collect_all_ledger_records()

	var/station_credits = 0
	var/station_records = 0
	var/player_credits = 0
	var/player_records = 0
	var/outstanding_debt = 0

	for(var/list/record as anything in all_records)
		outstanding_debt += record["debt"]
		if(record["source"] == "station")
			station_credits += record["balance"]
			station_records++
			continue
		player_credits += record["balance"]
		player_records++

	log_econ("ECONOMY SNAPSHOT: [station_credits + player_credits] [MONEY_NAME] held across [station_records + player_records] records. \
		Departments [station_credits] over [station_records]. Players [player_credits] over [player_records]. \
		Outstanding debt [outstanding_debt]. Vendor prices [round(SSeconomy.inflation_value * 100)]%.")

	SSblackbox.record_feedback("amount", "economy_credits_held", station_credits + player_credits)
	SSblackbox.record_feedback("amount", "economy_credits_departmental", station_credits)
	SSblackbox.record_feedback("amount", "economy_records_held", station_records + player_records)

#undef PLAYER_SAVES_PATH
#undef PLAYER_LEDGER_FILENAME
