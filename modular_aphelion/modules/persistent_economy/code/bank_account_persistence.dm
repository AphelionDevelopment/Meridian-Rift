/datum/bank_account
	/// Namespaced key this account's state is stored under. Null on a round-scoped account, the default.
	var/persistence_key
	/// Ledger this account loads from and writes back to. Null on a round-scoped account, the default.
	var/datum/economy_ledger/ledger
	/// Whether this account has stopped drawing passive income. See [/datum/bank_account/proc/suspend_income].
	var/income_suspended = FALSE
	/// Whether this account adopted a stored record when it was bound, meaning the character behind it
	/// has played before. Anything paid out once per character, rather than once per shift, checks this.
	var/restored_from_ledger = FALSE

/**
 * Binds this account to a ledger and adopts whatever state was stored under the key.
 *
 * This is the only thing that makes an account persistent. Until it is called the account behaves as
 * it always has, and [/datum/bank_account/proc/flush_to_ledger] does nothing.
 *
 * A key carries at most one live account. An account already holding the key is detached and has its
 * income suspended first, because two accounts writing one key lets money be spent twice: each writes
 * its own balance over the other's, so a withdrawal from one is undone by the next write from the
 * other.
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

	var/datum/bank_account/previous_holder = attached_ledger.live_accounts[key]
	if(previous_holder && previous_holder != src)
		previous_holder.suspend_income()
		previous_holder.detach_ledger()

	ledger = attached_ledger
	persistence_key = key
	ledger.live_accounts[key] = src

	var/stored_balance = ledger.read_balance(key)
	if(isnull(stored_balance))
		flush_to_ledger()
		return FALSE

	account_balance = stored_balance
	account_debt = ledger.read_debt(key)
	transaction_history = ledger.read_history(key)
	restored_from_ledger = TRUE
	return TRUE

/**
 * Unbinds this account from its ledger, leaving the stored record as it stands.
 *
 * The account keeps its balance and goes back to being round-scoped, so nothing it does from here
 * reaches the file. Used when a key changes hands and when a ledger is torn down.
 */
/datum/bank_account/proc/detach_ledger()
	if(isnull(ledger))
		return FALSE

	if(ledger.live_accounts[persistence_key] == src)
		ledger.live_accounts -= persistence_key
	ledger = null
	persistence_key = null
	return TRUE

/**
 * Stops this account drawing passive income for the rest of the round.
 *
 * A player who switches characters mid-round leaves the old account behind in
 * `SSeconomy.bank_accounts_by_id`, where it keeps collecting payday. That was harmless while balances
 * died with the round. Persisted, it is a second income stream per character a player cycles through,
 * so an abandoned account is cut off. It can still be spent from and transferred to, since the
 * character's money is still theirs.
 */
/datum/bank_account/proc/suspend_income()
	if(income_suspended)
		return FALSE

	income_suspended = TRUE
	flush_to_ledger()
	return TRUE

/**
 * Writes this account's balance, debt and recent transactions back to its ledger.
 *
 * Called from [/datum/bank_account/proc/adjust_money], the single point every balance change passes
 * through. Does nothing on a round-scoped account.
 */
/datum/bank_account/proc/flush_to_ledger()
	if(isnull(ledger))
		return FALSE

	ledger.write_record(
		key = persistence_key,
		balance = account_balance,
		debt = account_debt,
		holder = account_holder,
		history = transaction_history,
	)
	return TRUE
