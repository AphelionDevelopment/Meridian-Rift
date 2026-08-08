/datum/bank_account
	/// Namespaced key this account's state is stored under. Null on a round-scoped account, the default.
	var/persistence_key
	/// Ledger this account loads from and writes back to. Null on a round-scoped account, the default.
	var/datum/economy_ledger/ledger

/**
 * Binds this account to a ledger and adopts whatever state was stored under the key.
 *
 * This is the only thing that makes an account persistent. Until it is called the account behaves as
 * it always has, and [/datum/bank_account/proc/flush_to_ledger] does nothing.
 *
 * Returns TRUE when a stored record was found and applied, FALSE when the key is new to the ledger.
 * Branch on that to tell a returning account from a first-time one, which decides whether roundstart
 * grants are paid.
 * Arguments:
 * * attached_ledger - the ledger to bind to, from [/proc/get_economy_ledger].
 * * key - key to store this account under, namespaced by the system that owns it.
 */
/datum/bank_account/proc/attach_ledger(datum/economy_ledger/attached_ledger, key)
	if(isnull(attached_ledger) || !key)
		CRASH("attach_ledger called on [account_holder]'s account with no [isnull(attached_ledger) ? "ledger" : "key"].")

	ledger = attached_ledger
	persistence_key = key

	var/stored_balance = ledger.read_balance(key)
	if(isnull(stored_balance))
		flush_to_ledger()
		return FALSE

	account_balance = stored_balance
	account_debt = ledger.read_debt(key)
	return TRUE

/**
 * Writes this account's balance and debt back to its ledger.
 *
 * Called from [/datum/bank_account/proc/adjust_money], the single point every balance change passes
 * through. Does nothing on a round-scoped account.
 */
/datum/bank_account/proc/flush_to_ledger()
	if(isnull(ledger))
		return FALSE

	ledger.write_record(persistence_key, account_balance, account_debt, account_holder)
	return TRUE
