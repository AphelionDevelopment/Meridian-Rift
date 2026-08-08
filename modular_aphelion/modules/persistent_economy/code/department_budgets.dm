/// File the shared station ledger backs onto. Holds the department budgets, and any later account whose count is bounded.
#define STATION_LEDGER_PATH "data/persistent_economy.json"
/// Namespace prefix for department budget keys within the station ledger.
#define DEPARTMENT_KEY_PREFIX "dept:"
/// Multiple of the budget floor at or above which a department stops drawing its passive grant.
#define DEPARTMENT_GRANT_CEILING_MULT 3
/// Fraction of a department's carried balance taken at roundstart as operating costs.
#define DEPARTMENT_UPKEEP_FRACTION 0.05
/// Fraction of the shortfall a department below its budget floor is topped up by at roundstart.
#define DEPARTMENT_SUBSIDY_FRACTION 0.5

/datum/controller/subsystem/economy
	/// Balance at or above which a department stops drawing [MAX_GRANT_DPT]. Zero disables the ceiling.
	var/department_grant_ceiling = 0

/**
 * Returns the ledger shared by accounts whose count is bounded: the department budgets today, and any
 * later station-side account that sits alongside them.
 *
 * The path lives here alone so nothing else hardcodes it.
 */
/proc/get_station_ledger()
	return get_economy_ledger(STATION_LEDGER_PATH)

/**
 * Puts the department budgets onto the station ledger, carrying balances over from last round.
 *
 * Called from [/datum/controller/subsystem/economy/proc/Initialize] once the accounts exist, so each
 * already holds its stock roundstart budget by the time we run.
 *
 * A department with no stored record keeps that stock budget, and attaching writes it out as the
 * opening record. One with a record adopts its carried balance, then is topped up by half of whatever
 * it ended short of the floor, never past it. Banking a surplus is therefore worth something, and a
 * bankrupted department is still playable next shift.
 *
 * Half the shortfall rather than all of it, so ending a shift broke still costs something. A full
 * top-up would make every balance below the floor worth the same next round, leaving a head no reason
 * not to spend down to nothing before the shift ends.
 *
 * Cargo's floor is zero, since it has always started with nothing, so it keeps what it earns and is
 * never subsidised.
 *
 * Budgets are not scoped by map: the money belongs to the department, not the station it stood on, so
 * it follows the crew across a rotation. Scoping it means changing the key built below, which orphans
 * every existing record.
 *
 * The proportional operating cost applies here but not to player accounts. A ceiling is what you want
 * on an institutional budget, since departments are a faucet rather than somewhere anyone saves.
 * Arguments:
 * * floor_amount - the per-department budget floor, the same stock figure the accounts were built with.
 */
/datum/controller/subsystem/economy/proc/restore_department_budgets(floor_amount)
	if(!PERSISTENT_ECONOMY_ENABLED)
		return

	var/datum/economy_ledger/station_ledger = get_station_ledger()
	department_grant_ceiling = floor_amount * DEPARTMENT_GRANT_CEILING_MULT

	for(var/datum/bank_account/department/department_account as anything in departmental_accounts)
		var/had_record = department_account.attach_ledger(
			attached_ledger = station_ledger,
			key = "[DEPARTMENT_KEY_PREFIX][department_account.department_id]",
		)
		if(!had_record)
			continue

		var/upkeep = round(department_account.account_balance * DEPARTMENT_UPKEEP_FRACTION)
		if(upkeep > 0)
			department_account.adjust_money(-upkeep, "Nanotrasen: Operating Costs")
			log_econ("[upkeep] [MONEY_NAME] were taken from [department_account.account_holder] as operating costs.")

		var/floor_for_department = (department_account.department_id == ACCOUNT_CAR) ? 0 : floor_amount
		if(department_account.account_balance >= floor_for_department)
			continue

		var/subsidy = round((floor_for_department - department_account.account_balance) * DEPARTMENT_SUBSIDY_FRACTION)
		if(subsidy <= 0)
			continue

		department_account.adjust_money(subsidy, "Nanotrasen: Budget Subsidy")
		log_econ("[subsidy] [MONEY_NAME] were granted to [department_account.account_holder], half its shortfall against a budget floor of [floor_for_department].")

/**
 * Whether a department should still draw its passive grant this tick.
 *
 * [MAX_GRANT_DPT] was self-correcting while budgets died with the round. Carried over it compounds, so
 * a department at or above a multiple of its floor stops drawing it. This bounds the free grant only.
 * A department that earns its money, as cargo does, is not capped.
 * Arguments:
 * * department_account - the budget being considered for a grant.
 */
/datum/controller/subsystem/economy/proc/should_receive_department_grant(datum/bank_account/department/department_account)
	if(!department_grant_ceiling)
		return TRUE

	return department_account.account_balance < department_grant_ceiling

#undef STATION_LEDGER_PATH
#undef DEPARTMENT_KEY_PREFIX
#undef DEPARTMENT_GRANT_CEILING_MULT
#undef DEPARTMENT_UPKEEP_FRACTION
#undef DEPARTMENT_SUBSIDY_FRACTION
