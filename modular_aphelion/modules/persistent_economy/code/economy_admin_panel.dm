/// Largest balance the panel will let an admin type in, in either direction.
#define ADMIN_BALANCE_LIMIT 100000000

ADMIN_VERB(economy_panel, R_ADMIN, "Economy Panel", "View and manage bank accounts.", ADMIN_CATEGORY_GAME)
	var/static/datum/economy_admin_panel/panel = new
	panel.ui_interact(user.mob)

/**
 * # Economy admin panel
 *
 * Admin-side view of every bank account, live or stored.
 *
 * Splits the accounts that exist this round, crew and station budgets, from the records sitting in a
 * ledger on disk. The stored view reads the station ledger by default and can be pointed at any
 * player's ledger by ckey. That is the only way to see the balance of a character who is not playing.
 *
 * The two are not the same. Editing a live account changes the account and writes through to its
 * ledger. Editing a stored record changes only the file, so doing it to a character who is in the
 * round gets overwritten the moment they next earn or spend. The panel marks those records live.
 */
/datum/economy_admin_panel
	/// Ckey whose ledger the stored view shows, or null for the shared station ledger.
	var/inspected_ckey

/datum/economy_admin_panel/ui_state(mob/user)
	return ADMIN_STATE(R_ADMIN)

/datum/economy_admin_panel/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "EconomyAdminPanel")
		ui.open()

/// Every account that exists this round, crew and departmental. All panel lookups are scoped to this.
/datum/economy_admin_panel/proc/get_live_accounts()
	return assoc_to_values(SSeconomy.bank_accounts_by_id) + SSeconomy.departmental_accounts

/// The ledger the stored view is currently showing.
/datum/economy_admin_panel/proc/get_inspected_ledger()
	if(!inspected_ckey)
		return get_station_ledger()

	return get_economy_ledger("data/player_saves/[inspected_ckey[1]]/[inspected_ckey]/persistent_economy.json")

/// Serialises one live account into the shape the UI expects.
/datum/economy_admin_panel/proc/account_to_list(datum/bank_account/account)
	return list(
		"ref" = REF(account),
		"holder" = account.account_holder,
		"account_id" = account.account_id,
		"balance" = account.account_balance,
		"debt" = account.account_debt,
		"job" = account.account_job?.title,
		"persistent" = !isnull(account.ledger),
		"key" = account.persistence_key,
	)

/datum/economy_admin_panel/ui_data(mob/user)
	var/list/data = list()

	var/list/crew_accounts = list()
	for(var/datum/bank_account/account as anything in assoc_to_values(SSeconomy.bank_accounts_by_id))
		crew_accounts += list(account_to_list(account))
	data["crew_accounts"] = crew_accounts

	var/list/station_accounts = list()
	for(var/datum/bank_account/department/account as anything in SSeconomy.departmental_accounts)
		station_accounts += list(account_to_list(account))
	data["station_accounts"] = station_accounts

	var/list/live_keys = list()
	for(var/datum/bank_account/account as anything in get_live_accounts())
		if(account.persistence_key)
			live_keys[account.persistence_key] = TRUE

	var/datum/economy_ledger/inspected_ledger = get_inspected_ledger()
	var/list/stored_records = list()
	for(var/record_key in inspected_ledger.read_all())
		stored_records += list(list(
			"key" = record_key,
			"holder" = inspected_ledger.read_holder(record_key),
			"balance" = inspected_ledger.read_balance(record_key),
			"debt" = inspected_ledger.read_debt(record_key),
			"live" = !isnull(live_keys[record_key]),
		))
	data["stored_records"] = stored_records
	data["inspected_ckey"] = inspected_ckey
	data["inflation_value"] = SSeconomy.inflation_value
	data["station_total"] = SSeconomy.station_total
	data["station_target"] = SSeconomy.station_target

	return data

/datum/economy_admin_panel/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return

	if(!check_rights(R_ADMIN))
		return

	var/mob/user = usr

	switch(action)
		if("adjust_balance")
			return adjust_account_balance(user, params["ref"])

		if("set_balance")
			return set_account_balance(user, params["ref"])

		if("set_debt")
			return set_account_debt(user, params["ref"])

		if("inspect_ckey")
			var/target_ckey = ckey(tgui_input_text(user, "Whose ledger?", "Inspect Player Ledger"))
			if(!target_ckey)
				return
			inspected_ckey = target_ckey
			return TRUE

		if("inspect_station")
			inspected_ckey = null
			return TRUE

		if("set_stored_balance")
			return set_stored_record_balance(user, params["key"])

		if("delete_stored")
			return delete_stored_record(user, params["key"])

/**
 * Moves credits into or out of a live account through the same path any other transaction takes.
 *
 * Uses [/datum/bank_account/proc/adjust_money], so the account's own rules apply: debt collection
 * takes its cut, the change lands in transaction history, and a withdrawal larger than the balance is
 * refused instead of driving it negative. Use set_balance to override that.
 * Arguments:
 * * user - the admin acting.
 * * account_ref - reference to the target account, re-resolved after the prompt.
 */
/datum/economy_admin_panel/proc/adjust_account_balance(mob/user, account_ref)
	var/datum/bank_account/account = locate(account_ref) in get_live_accounts()
	if(!account)
		return

	var/amount = tgui_input_number(
		user = user,
		message = "Credits to add? Negative to remove.",
		title = "Adjust [account.account_holder]",
		default = 0,
		max_value = ADMIN_BALANCE_LIMIT,
		min_value = -ADMIN_BALANCE_LIMIT,
	)
	if(isnull(amount) || !amount)
		return

	account = locate(account_ref) in get_live_accounts()
	if(!account)
		return

	if(!account.adjust_money(amount, "Administrative Adjustment"))
		to_chat(user, span_warning("[account.account_holder] lacks the [-amount] credits to remove. Use Set to override."))
		return

	log_admin("[key_name(user)] adjusted [account.account_holder]'s account by [amount] credits, to [account.account_balance].")
	message_admins("[key_name_admin(user)] adjusted [account.account_holder]'s account by [amount] credits, to [account.account_balance].")
	return TRUE

/**
 * Overwrites a live account's balance outright, bypassing the rules adjust_account_balance respects.
 *
 * Writes to the ledger afterwards so the new figure survives the round even if the account never
 * transacts again.
 * Arguments:
 * * user - the admin acting.
 * * account_ref - reference to the target account, re-resolved after the prompt.
 */
/datum/economy_admin_panel/proc/set_account_balance(mob/user, account_ref)
	var/datum/bank_account/account = locate(account_ref) in get_live_accounts()
	if(!account)
		return

	var/new_balance = tgui_input_number(
		user = user,
		message = "New balance?",
		title = "Set [account.account_holder]",
		default = account.account_balance,
		max_value = ADMIN_BALANCE_LIMIT,
	)
	if(isnull(new_balance))
		return

	account = locate(account_ref) in get_live_accounts()
	if(!account)
		return

	var/old_balance = account.account_balance
	account.account_balance = new_balance
	account.flush_to_ledger()

	log_admin("[key_name(user)] set [account.account_holder]'s balance from [old_balance] to [new_balance].")
	message_admins("[key_name_admin(user)] set [account.account_holder]'s balance from [old_balance] to [new_balance].")
	return TRUE

/**
 * Overwrites a live account's outstanding debt.
 * Arguments:
 * * user - the admin acting.
 * * account_ref - reference to the target account, re-resolved after the prompt.
 */
/datum/economy_admin_panel/proc/set_account_debt(mob/user, account_ref)
	var/datum/bank_account/account = locate(account_ref) in get_live_accounts()
	if(!account)
		return

	var/new_debt = tgui_input_number(
		user = user,
		message = "New debt?",
		title = "Set [account.account_holder]'s Debt",
		default = account.account_debt,
		max_value = ADMIN_BALANCE_LIMIT,
	)
	if(isnull(new_debt))
		return

	account = locate(account_ref) in get_live_accounts()
	if(!account)
		return

	var/old_debt = account.account_debt
	account.account_debt = new_debt
	account.flush_to_ledger()

	log_admin("[key_name(user)] set [account.account_holder]'s debt from [old_debt] to [new_debt].")
	message_admins("[key_name_admin(user)] set [account.account_holder]'s debt from [old_debt] to [new_debt].")
	return TRUE

/**
 * Rewrites a stored record's balance directly in the ledger file.
 *
 * Only sticks on a record with no live account behind it. One that is in play overwrites this on its
 * next transaction. The panel marks those records live.
 * Arguments:
 * * user - the admin acting.
 * * record_key - the ledger key being edited, re-checked after the prompt.
 */
/datum/economy_admin_panel/proc/set_stored_record_balance(mob/user, record_key)
	var/datum/economy_ledger/inspected_ledger = get_inspected_ledger()
	if(isnull(inspected_ledger.read_balance(record_key)))
		return

	var/new_balance = tgui_input_number(
		user = user,
		message = "New stored balance for [record_key]?",
		title = "Set Stored Balance",
		default = inspected_ledger.read_balance(record_key),
		max_value = ADMIN_BALANCE_LIMIT,
	)
	if(isnull(new_balance))
		return

	inspected_ledger = get_inspected_ledger()
	var/old_balance = inspected_ledger.read_balance(record_key)
	if(isnull(old_balance))
		return

	inspected_ledger.write_record(
		key = record_key,
		balance = new_balance,
		debt = inspected_ledger.read_debt(record_key),
		holder = inspected_ledger.read_holder(record_key),
	)

	log_admin("[key_name(user)] set stored balance of [record_key] in [inspected_ledger.store_path] from [old_balance] to [new_balance].")
	message_admins("[key_name_admin(user)] set stored balance of [record_key] from [old_balance] to [new_balance].")
	return TRUE

/**
 * Erases a stored record from the ledger file, after confirmation.
 * Arguments:
 * * user - the admin acting.
 * * record_key - the ledger key being erased, re-checked after the prompt.
 */
/datum/economy_admin_panel/proc/delete_stored_record(mob/user, record_key)
	var/datum/economy_ledger/inspected_ledger = get_inspected_ledger()
	if(isnull(inspected_ledger.read_balance(record_key)))
		return

	if(tgui_alert(user, "Erase the stored record for [record_key]?", "Delete Record", list("Delete", "Cancel")) != "Delete")
		return

	inspected_ledger = get_inspected_ledger()
	if(!inspected_ledger.delete_record(record_key))
		return

	log_admin("[key_name(user)] deleted the stored record for [record_key] from [inspected_ledger.store_path].")
	message_admins("[key_name_admin(user)] deleted the stored record for [record_key].")
	return TRUE

#undef ADMIN_BALANCE_LIMIT
