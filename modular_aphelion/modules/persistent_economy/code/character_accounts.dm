/// Namespace prefix for character account keys within a player's ledger.
#define CHARACTER_KEY_PREFIX "char:"

/**
 * Binds a new player account to its character's ledger, and pays the roundstart grant if owed.
 *
 * Called from [/mob/living/carbon/human/proc/on_job_equipping] in place of the unconditional
 * [STARTING_PAYCHECKS] grant. With balances carrying over, paying it every shift would be a faucet
 * with nothing on the other side, so only a character new to the ledger gets it. A returning one lives
 * on payday and on what it earns.
 *
 * Nothing is taken from a returning character at spawn. A proportional charge on held credits is a
 * hard wealth ceiling, and this economy is meant to be saved into. The sink is on transfers instead,
 * in [/proc/get_transaction_levy].
 *
 * Identity is ckey plus character slot, matching the rest of the codebase's per-character persistence.
 * Overwriting a slot inherits that slot's money, which comes with slot-keyed storage and is not
 * handled here.
 *
 * A character with no ckey or slot index, mostly admin-spawned bodies, gets the stock grant and no
 * ledger.
 * Arguments:
 * * account - the newly built account to bind.
 * * player_client - the spawning player's client, used for their ckey. May be null.
 */
/mob/living/carbon/human/proc/attach_character_account(datum/bank_account/account, client/player_client)
	var/player_ckey = player_client?.ckey || ckey
	var/slot_index = mind?.original_character_slot_index

	if(!PERSISTENT_ECONOMY_ENABLED || !player_ckey || isnull(slot_index))
		account.payday(STARTING_PAYCHECKS, free = TRUE)
		return FALSE

	var/datum/economy_ledger/character_ledger = get_economy_ledger("data/player_saves/[player_ckey[1]]/[player_ckey]/persistent_economy.json")
	suspend_previous_character_income(character_ledger, account)

	if(!account.attach_ledger(attached_ledger = character_ledger, key = "[CHARACTER_KEY_PREFIX][slot_index]"))
		account.payday(STARTING_PAYCHECKS, free = TRUE)
		return FALSE

	return TRUE

/**
 * Cuts off passive income to every account this player already has open in the round.
 *
 * One player's characters share a ledger, so the accounts still bound to it are the characters they
 * played earlier this shift. Those stay in `SSeconomy.bank_accounts_by_id` and keep collecting payday
 * after the body is gone, which persisted means one banked income stream per character a player cycles
 * through.
 *
 * Only income stops. The money stays theirs, spendable and transferable.
 * Arguments:
 * * character_ledger - the player's ledger, whose live accounts are their characters this round.
 * * incoming_account - the account being bound now, which is the one that should still earn.
 */
/mob/living/carbon/human/proc/suspend_previous_character_income(datum/economy_ledger/character_ledger, datum/bank_account/incoming_account)
	for(var/record_key in character_ledger.live_accounts)
		var/datum/bank_account/previous_account = character_ledger.live_accounts[record_key]
		if(previous_account == incoming_account || previous_account.income_suspended)
			continue

		previous_account.suspend_income()
		log_econ("[previous_account.account_holder]'s account stopped earning, as [key_name(src)] took over a different character.")

#undef CHARACTER_KEY_PREFIX
