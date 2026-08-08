/**
 * The cut destroyed when credits move between two crew accounts.
 *
 * The economy's main continuous sink, and the counterweight that replaces the roundstart charge on
 * held credits. A charge on a balance is a hard ceiling: balances settle where a shift's earnings meet
 * the charge and stop, which puts a wall in front of exactly the saving this economy is built around.
 * A charge on movement has no such ceiling. It sinks money in proportion to how much trade is
 * happening rather than how much has been saved, so a busy shift drains more than a quiet one and a
 * player who banks their credits is not punished for it.
 *
 * Taken from the recipient's side, so the sender pays the figure they agreed to and the seller carries
 * the fee, as a broker's cut works. The sender's funds were already checked against the full amount,
 * so the levy cannot make a transfer fail.
 *
 * Exempt when either side is a departmental account. That covers payday, which is a transfer out of a
 * department budget and would otherwise be docked twice over, and covers paying a machine or a
 * department for a service, which is priced already. What is left is crew paying crew, which is the
 * player-to-player trade this is meant to tax.
 *
 * Returns the number of credits to destroy, which may be zero.
 * Arguments:
 * * from - the account the credits are leaving.
 * * amount - the full sum being transferred, before the levy.
 */
/datum/bank_account/proc/get_transaction_levy(datum/bank_account/from, amount)
	if(!PERSISTENT_ECONOMY_ENABLED || amount <= 0)
		return 0

	if(IS_DEPARTMENTAL_ACCOUNT(src) || IS_DEPARTMENTAL_ACCOUNT(from))
		return 0

	return round(amount * TRANSACTION_LEVY_FRACTION)
