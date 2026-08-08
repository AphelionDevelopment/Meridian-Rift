/// Namespace prefix for character account keys within a player's ledger.
#define CHARACTER_KEY_PREFIX "char:"
/// Fraction of a returning character's carried balance taken at spawn as cost of living.
#define CHARACTER_UPKEEP_FRACTION 0.05

/**
 * Binds a new player account to its character's ledger, and pays the roundstart grant if owed.
 *
 * Called from [/mob/living/carbon/human/proc/on_job_equipping] in place of the unconditional
 * [STARTING_PAYCHECKS] grant. With balances carrying over, paying it every shift would be a faucet
 * with nothing on the other side. A character new to the ledger still gets it; a returning one lives
 * on passive payday.
 *
 * Returning characters are charged a fraction of what they carried as cost of living. A proportional
 * charge never bankrupts a poor character and bounds a rich one: balances settle where a shift's
 * earnings meet the charge instead of climbing without limit.
 *
 * Identity is ckey plus character slot, matching the rest of the codebase's per-character
 * persistence. Overwriting a slot inherits that slot's money, which is a property of slot-keyed
 * storage and not handled here.
 *
 * A character with no ckey or slot index, mostly admin-spawned bodies, gets the stock grant and no
 * ledger, behaving as it did before this module.
 * Arguments:
 * * account - the newly built account to bind.
 * * player_client - the spawning player's client, used for their ckey. May be null.
 */
/mob/living/carbon/human/proc/attach_character_account(datum/bank_account/account, client/player_client)
	var/player_ckey = player_client?.ckey || ckey
	var/slot_index = mind?.original_character_slot_index

	if(!player_ckey || isnull(slot_index))
		account.payday(STARTING_PAYCHECKS, free = TRUE)
		return FALSE

	var/datum/economy_ledger/character_ledger = get_economy_ledger("data/player_saves/[player_ckey[1]]/[player_ckey]/persistent_economy.json")
	if(!account.attach_ledger(attached_ledger = character_ledger, key = "[CHARACTER_KEY_PREFIX][slot_index]"))
		account.payday(STARTING_PAYCHECKS, free = TRUE)
		return FALSE

	var/upkeep = round(account.account_balance * CHARACTER_UPKEEP_FRACTION)
	if(upkeep > 0)
		account.adjust_money(-upkeep, "Nanotrasen: Cost of Living")
		log_econ("[upkeep] [MONEY_NAME] were taken from [account.account_holder]'s account as cost of living.")

	return TRUE

#undef CHARACTER_KEY_PREFIX
#undef CHARACTER_UPKEEP_FRACTION
