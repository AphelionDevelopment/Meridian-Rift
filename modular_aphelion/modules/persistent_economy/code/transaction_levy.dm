/**
 * The cut destroyed when credits enter an account from outside it.
 *
 * The economy's main continuous sink, and the counterweight that replaces the roundstart charge on
 * held credits. A charge on a balance is a hard ceiling: balances settle where a shift's earnings meet
 * the charge and stop, which puts a wall in front of exactly the saving this economy is built around.
 * A charge on movement has no such ceiling. It sinks money in proportion to how much trade is
 * happening rather than how much has been saved, so a busy shift drains more than a quiet one and a
 * player who banks their credits is not punished for it.
 *
 * Taken from the recipient's side, so the sender pays the figure they agreed to and the seller carries
 * the fee, as a broker's cut works. The sender's funds are checked against the full amount before this
 * is worked out, so the levy cannot make a transfer fail.
 *
 * Exempt when either side is a departmental account. That covers payday, which is a transfer out of a
 * department budget and would otherwise be docked twice over, and covers paying a machine or a
 * department for a service, which is priced already. What is left is crew paying crew, which is the
 * player-to-player trade this is meant to tax.
 *
 * Returns the number of credits to destroy, which may be zero.
 * Arguments:
 * * sender - the account the credits are leaving, or null when they are being banked from physical
 * currency, which has no account behind it.
 * * recipient - the account the credits are arriving in.
 * * amount - the full sum being moved, before the levy.
 * * fraction - the cut to take. [DEPOSIT_LEVY_FRACTION] when banking cash, otherwise the default.
 */
/proc/get_transaction_levy(datum/bank_account/sender, datum/bank_account/recipient, amount, fraction = TRANSACTION_LEVY_FRACTION)
	if(!PERSISTENT_ECONOMY_ENABLED || amount <= 0)
		return 0

	if(IS_DEPARTMENTAL_ACCOUNT(recipient) || IS_DEPARTMENTAL_ACCOUNT(sender))
		return 0

	return round(amount * fraction)

/**
 * Works out the levy on a sum and records that it was taken.
 *
 * Call this from every path that moves credits into an account from outside it, and credit the
 * recipient the amount less what this returns. The levy exists to bound the money supply, so a path
 * that skips it is not a missing fee but a hole the whole sink model drains through: crew who notice
 * route their trade down it and the economy has no drain at all.
 *
 * Returns the number of credits destroyed, which may be zero.
 * Arguments:
 * * sender - the account the credits are leaving, or null when banking physical currency.
 * * recipient - the account the credits are arriving in.
 * * amount - the full sum being moved, before the levy.
 * * fraction - the cut to take. [DEPOSIT_LEVY_FRACTION] when banking cash, otherwise the default.
 */
/proc/charge_transaction_levy(datum/bank_account/sender, datum/bank_account/recipient, amount, fraction = TRANSACTION_LEVY_FRACTION)
	var/levy = get_transaction_levy(sender, recipient, amount, fraction)
	if(!levy)
		return 0

	log_econ("[levy] [MONEY_NAME] were taken as a levy on the [amount] paid to [recipient.account_holder][sender ? " by [sender.account_holder]" : " in cash"].")
	SSblackbox.record_feedback("amount", "credits_levied", levy)
	return levy
