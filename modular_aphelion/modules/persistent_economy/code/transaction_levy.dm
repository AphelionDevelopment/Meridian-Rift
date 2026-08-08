/**
 * The cut destroyed when credits land in an account.
 *
 * The economy's main continuous sink, and what replaces a roundstart charge on held credits. A charge
 * on a balance is a hard ceiling: balances settle where a shift's earnings meet the charge and stop,
 * which walls off exactly the saving this economy is built around. A charge on movement has no
 * ceiling. It scales with how much trade is happening rather than how much has been banked, so a busy
 * shift drains more than a quiet one and saving is not punished.
 *
 * Charged inside [/datum/bank_account/proc/adjust_money], the one proc every balance change passes
 * through, rather than at each surface that moves money. Per surface, any path nobody remembered to
 * edit was a hole the whole sink drained through, and three went unnoticed. Charging it centrally
 * makes an unconsidered path taxed rather than free, so the failure mode is a fee someone queries
 * instead of an economy with no drain.
 *
 * Taken from the recipient's side, so the sender pays the figure they agreed and the seller carries
 * the fee, the way a broker's cut works. A transfer checks the sender's funds against the full amount
 * before this is worked out, so the levy cannot make one fail.
 *
 * Departmental accounts are exempt: they are the faucet the crew is paid out of, and money paid to one
 * is priced already. Anything else has to ask, with [LEVY_EXEMPT].
 *
 * Returns the number of credits to destroy, which may be zero.
 * Arguments:
 * * recipient - the account the credits are arriving in.
 * * amount - the sum arriving, before the levy.
 * * fraction - the cut to take. [LEVY_EXEMPT] on salary, grants and refunds, [DEPOSIT_LEVY_FRACTION]
 * when banking physical currency, otherwise the default.
 */
/proc/get_transaction_levy(datum/bank_account/recipient, amount, fraction = TRANSACTION_LEVY_FRACTION)
	if(!PERSISTENT_ECONOMY_ENABLED || amount <= 0 || fraction <= 0)
		return 0

	if(IS_DEPARTMENTAL_ACCOUNT(recipient))
		return 0

	return round(amount * fraction)

/**
 * Works out the levy on a sum and records that it was taken.
 *
 * Called from [/datum/bank_account/proc/adjust_money]. Nothing else should need it: crediting an
 * account is what gets you levied, and a surface that should not be passes [LEVY_EXEMPT] rather than
 * skipping this.
 *
 * Returns the number of credits destroyed, which may be zero.
 * Arguments:
 * * recipient - the account the credits are arriving in.
 * * amount - the sum arriving, before the levy.
 * * fraction - the cut to take.
 */
/proc/charge_transaction_levy(datum/bank_account/recipient, amount, fraction = TRANSACTION_LEVY_FRACTION)
	var/levy = get_transaction_levy(recipient, amount, fraction)
	if(!levy)
		return 0

	log_econ("[levy] [MONEY_NAME] were taken as a levy on the [amount] paid to [recipient.account_holder].")
	SSblackbox.record_feedback("amount", "credits_levied", levy)
	return levy
