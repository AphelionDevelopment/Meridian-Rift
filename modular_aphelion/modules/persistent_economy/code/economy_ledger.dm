/// Every ledger currently open, keyed by the path of the file it backs onto. See [/proc/get_economy_ledger].
GLOBAL_LIST_EMPTY(economy_ledgers)

/**
 * # Economy ledger
 *
 * A keyed store of bank account state that outlives the round.
 *
 * Wraps a [/datum/json_database], so writes get its backup and recovery path. One ledger owns one
 * file. Accounts sharing a file are separated by their persistence key, namespaced by whichever
 * system owns the account: `dept:<department_id>`, `char:<slot_index>`, and so on.
 *
 * Attaching a ledger to a [/datum/bank_account] is what makes that account persistent. Accounts with
 * no ledger stay round-scoped. A database rewrites its whole file on save, so only share a file
 * between accounts whose number is bounded. Per-player state belongs in a per-player file.
 *
 * Ledgers live for the whole round. Accounts hold a hard ref to theirs, so destroying one while an
 * account still points at it would hard delete the ledger.
 */
/datum/economy_ledger
	/// Path of the file this ledger backs onto. Kept for logging; the database holds its own private copy.
	var/store_path
	/// The database that every read and write on this ledger passes through.
	var/datum/json_database/store
	/// Accounts currently bound to this ledger, keyed by their persistence key. At most one per key.
	var/list/datum/bank_account/live_accounts = list()

/datum/economy_ledger/New(store_path)
	src.store_path = store_path
	store = new(store_path)
	GLOB.economy_ledgers[store_path] = src

/datum/economy_ledger/Destroy(force)
	GLOB.economy_ledgers -= store_path
	// Detaching removes the account's own entry, so walk a copy rather than the list being emptied.
	for(var/record_key in live_accounts.Copy())
		var/datum/bank_account/bound_account = live_accounts[record_key]
		bound_account.detach_ledger()
	live_accounts = null
	QDEL_NULL(store)
	return ..()

/**
 * Returns the ledger backing the given file, opening one if it is not already live.
 *
 * Always get ledgers through this proc. [/datum/json_database] refuses to open a second database on
 * a file that already has one, so constructing a ledger directly runtimes as soon as two systems
 * name the same path.
 * Arguments:
 * * store_path - path of the JSON file, under data/, that the ledger reads and writes.
 */
/proc/get_economy_ledger(store_path)
	var/datum/economy_ledger/existing_ledger = GLOB.economy_ledgers[store_path]
	if(existing_ledger)
		return existing_ledger

	return new /datum/economy_ledger(store_path)

/**
 * Writes every account bound to every open ledger back to its file.
 *
 * Called at round end from [/datum/controller/subsystem/persistence/proc/collect_data]. Ordinary
 * writes ride on [/datum/bank_account/proc/adjust_money], so this only matters for state that changed
 * without a transaction behind it, and as a backstop against the last transaction of the round having
 * missed its deferred save.
 *
 * Takes the round's economy snapshot once everything is written, so the figures logged are the ones
 * the next round starts from.
 */
/proc/flush_economy_ledgers()
	for(var/ledger_path in GLOB.economy_ledgers)
		var/datum/economy_ledger/ledger = GLOB.economy_ledgers[ledger_path]
		for(var/record_key in ledger.live_accounts)
			var/datum/bank_account/bound_account = ledger.live_accounts[record_key]
			bound_account.flush_to_ledger()

	log_economy_snapshot()

/**
 * Reads the whole record stored under a key.
 *
 * Returns a copy of the record, or null when the key has never been written or holds something this
 * build cannot read. Null means the account has no usable history, which is how a first-time character
 * is told apart from one that spent down to zero.
 *
 * A record stamped with a newer schema than this build understands is refused rather than guessed at,
 * so rolling a server back does not rewrite newer records into an older shape. A record with no
 * version predates versioning and is the same shape as version 1.
 * Arguments:
 * * key - the namespaced persistence key to read.
 */
/datum/economy_ledger/proc/read_record(key)
	var/list/record = store.get_key(key)
	if(!islist(record))
		return null

	var/record_version = record[LEDGER_FIELD_VERSION]
	if(isnum(record_version) && record_version > LEDGER_SCHEMA_VERSION)
		stack_trace("Ledger [store_path] holds record [key] at schema version [record_version], but this build only reads [LEDGER_SCHEMA_VERSION]. Refusing to read it.")
		return null

	return record.Copy()

/**
 * Reads the stored balance for a key.
 *
 * Returns the balance, or null when the key has no record or holds a malformed one. A hand-edited or
 * partially written file should leave an account alone rather than zero it. A balance beyond
 * [LEDGER_BALANCE_LIMIT] is clamped, so a corrupted or tampered figure cannot enter the economy whole.
 * Arguments:
 * * key - the namespaced persistence key to read.
 */
/datum/economy_ledger/proc/read_balance(key)
	var/list/record = read_record(key)
	if(isnull(record))
		return null

	var/stored_balance = record[LEDGER_FIELD_BALANCE]
	if(!isnum(stored_balance))
		return null

	if(abs(stored_balance) > LEDGER_BALANCE_LIMIT)
		stack_trace("Ledger [store_path] holds an out of range balance of [stored_balance] for [key]. Clamping it.")
	return clamp(stored_balance, -LEDGER_BALANCE_LIMIT, LEDGER_BALANCE_LIMIT)

/**
 * Reads the stored debt for a key, treating a missing or malformed entry as no debt.
 * Arguments:
 * * key - the namespaced persistence key to read.
 */
/datum/economy_ledger/proc/read_debt(key)
	var/list/record = read_record(key)
	if(isnull(record))
		return 0

	var/stored_debt = record[LEDGER_FIELD_DEBT]
	if(!isnum(stored_debt))
		return 0

	return clamp(stored_debt, 0, LEDGER_BALANCE_LIMIT)

/**
 * Reads the stored transaction history for a key, newest last.
 *
 * Returns a list of `adjusted_money`/`reason` pairs in the shape
 * [/datum/bank_account/var/transaction_history] holds, or an empty list when there is none. Entries
 * that are not that shape are dropped rather than loaded, since the panel renders them directly.
 * Arguments:
 * * key - the namespaced persistence key to read.
 */
/datum/economy_ledger/proc/read_history(key)
	var/list/record = read_record(key)
	if(isnull(record))
		return list()

	var/list/stored_history = record[LEDGER_FIELD_HISTORY]
	if(!islist(stored_history))
		return list()

	var/list/clean_history = list()
	for(var/list/entry as anything in stored_history)
		if(!islist(entry) || !isnum(entry["adjusted_money"]) || !istext(entry["reason"]))
			continue
		clean_history += list(entry.Copy())

	if(length(clean_history) > LEDGER_HISTORY_LENGTH)
		clean_history.Cut(1, length(clean_history) - LEDGER_HISTORY_LENGTH + 1)
	return clean_history

/**
 * Writes an account's state to the ledger under the given key, replacing whatever was there.
 *
 * The database defers and coalesces writes to the end of the tick, so calling this on every
 * transaction costs one file rewrite per tick in which money moved, not one per transaction. That is
 * also why history is capped: the whole file is rewritten each save, so an unbounded log here would
 * grow the cost of every future transaction.
 * Arguments:
 * * key - the namespaced persistence key to write under.
 * * balance - the account's current credit balance.
 * * debt - the account's current outstanding debt.
 * * holder - the account holder's name, stored to keep the raw file readable.
 * * history - the account's recent transactions, trimmed to [LEDGER_HISTORY_LENGTH].
 */
/datum/economy_ledger/proc/write_record(key, balance, debt, holder, list/history)
	var/list/trimmed_history = history ? history.Copy() : list()
	if(length(trimmed_history) > LEDGER_HISTORY_LENGTH)
		trimmed_history.Cut(1, length(trimmed_history) - LEDGER_HISTORY_LENGTH + 1)

	store.set_key(key, list(
		LEDGER_FIELD_VERSION = LEDGER_SCHEMA_VERSION,
		LEDGER_FIELD_BALANCE = clamp(balance, -LEDGER_BALANCE_LIMIT, LEDGER_BALANCE_LIMIT),
		LEDGER_FIELD_DEBT = clamp(debt, 0, LEDGER_BALANCE_LIMIT),
		LEDGER_FIELD_HOLDER = holder,
		LEDGER_FIELD_UPDATED = world.realtime,
		LEDGER_FIELD_HISTORY = trimmed_history,
	))

/**
 * Reads the stored holder name for a key, or null when there is none.
 *
 * Display only. Nothing keys off it, and a renamed account keeps the old name until its next write.
 * Arguments:
 * * key - the namespaced persistence key to read.
 */
/datum/economy_ledger/proc/read_holder(key)
	var/list/record = read_record(key)
	if(isnull(record))
		return null

	var/stored_holder = record[LEDGER_FIELD_HOLDER]
	return istext(stored_holder) ? stored_holder : null

/**
 * Returns a copy of every record in this ledger, keyed as stored.
 *
 * For tooling that shows a ledger whole, such as the admin panel. Gameplay code knows the key it
 * wants and should read that key instead of walking the file.
 */
/datum/economy_ledger/proc/read_all()
	var/list/all_records = store.get()
	if(!islist(all_records))
		return list()

	return all_records.Copy()

/**
 * Erases the record stored under a key, if there is one.
 *
 * An account still bound to this key writes itself back on its next transaction, so this only sticks
 * on a key with no live account behind it.
 * Arguments:
 * * key - the namespaced persistence key to erase.
 */
/datum/economy_ledger/proc/delete_record(key)
	if(isnull(store.get_key(key)))
		return FALSE

	store.remove(key)
	return TRUE
