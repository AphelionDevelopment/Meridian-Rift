/datum/controller/subsystem/economy
	/// Average account balance observed on the first payday of the round, used as the baseline
	/// [/datum/controller/subsystem/economy/var/station_target] is built from. Null until captured.
	var/opening_average_balance

/**
 * Returns the crew's targeted allowance, which held wealth is measured against to set inflation.
 *
 * Upstream builds this from what the crew should be holding: every account's paycheck times
 * [STARTING_PAYCHECKS]. That only works while balances start near that figure each round. Once they
 * carry over, held wealth is unbounded and the target is not, so vendor prices would open at whatever
 * multiple of a stock paycheck the richest shift banked and never recover.
 *
 * So the baseline is the wealth observed at the round's first payday, not the wealth expected.
 * Inflation then measures what the crew earns during the shift rather than what it walked in with, and
 * a rich crew and a poor one open at the same multiplier. Hoarding between rounds no longer drives
 * prices up; only in-shift earnings do.
 *
 * With persistence off there is nothing to carry over, so this hands back the stock expression
 * untouched.
 */
/datum/controller/subsystem/economy/proc/get_station_target()
	if(!PERSISTENT_ECONOMY_ENABLED)
		return max(round(temporary_total / max(length(bank_accounts_by_id) * 2, 1)) + station_target_buffer, 1)

	var/account_count = length(bank_accounts_by_id)
	if(!account_count)
		return max(station_target_buffer, 1)

	if(isnull(opening_average_balance))
		opening_average_balance = station_total / account_count

	return max(round(opening_average_balance / 2) + station_target_buffer, 1)
