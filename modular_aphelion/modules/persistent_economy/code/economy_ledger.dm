/// Key of the credit balance inside a ledger record.
#define LEDGER_FIELD_BALANCE "balance"
/// Key of the outstanding debt inside a ledger record.
#define LEDGER_FIELD_DEBT "debt"
/// Key of the account holder's name inside a ledger record. For admin readability, never read back.
#define LEDGER_FIELD_HOLDER "holder"
/// Key of the `world.realtime` stamp of the last write inside a ledger record.
#define LEDGER_FIELD_UPDATED "updated"

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

/datum/economy_ledger/New(store_path)
	src.store_path = store_path
	store = new(store_path)
	GLOB.economy_ledgers[store_path] = src

/datum/economy_ledger/Destroy(force)
	GLOB.economy_ledgers -= store_path
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
 * Reads the whole record stored under a key.
 *
 * Returns a copy of the record, or null when the key has never been written. Null means the account
 * has no history, which is how a first-time character is told apart from one that spent down to zero.
 * Arguments:
 * * key - the namespaced persistence key to read.
 */
/datum/economy_ledger/proc/read_record(key)
	var/list/record = store.get_key(key)
	if(!islist(record))
		return null

	return record.Copy()

/**
 * Reads the stored balance for a key.
 *
 * Returns the balance, or null when the key has no record or holds a malformed one. A hand-edited or
 * partially written file should leave an account alone rather than zero it.
 * Arguments:
 * * key - the namespaced persistence key to read.
 */
/datum/economy_ledger/proc/read_balance(key)
	var/list/record = read_record(key)
	if(isnull(record))
		return null

	var/stored_balance = record[LEDGER_FIELD_BALANCE]
	return isnum(stored_balance) ? stored_balance : null

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
	return isnum(stored_debt) ? stored_debt : 0

/**
 * Writes an account's state to the ledger under the given key, replacing whatever was there.
 *
 * The database defers and coalesces writes to the end of the tick, so calling this on every
 * transaction costs one file rewrite per tick in which money moved, not one per transaction.
 * Arguments:
 * * key - the namespaced persistence key to write under.
 * * balance - the account's current credit balance.
 * * debt - the account's current outstanding debt.
 * * holder - the account holder's name, stored to keep the raw file readable.
 */
/datum/economy_ledger/proc/write_record(key, balance, debt, holder)
	store.set_key(key, list(
		LEDGER_FIELD_BALANCE = balance,
		LEDGER_FIELD_DEBT = debt,
		LEDGER_FIELD_HOLDER = holder,
		LEDGER_FIELD_UPDATED = world.realtime,
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

#undef LEDGER_FIELD_BALANCE
#undef LEDGER_FIELD_DEBT
#undef LEDGER_FIELD_HOLDER
#undef LEDGER_FIELD_UPDATED
