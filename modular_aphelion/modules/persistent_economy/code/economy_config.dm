/**
 * Whether balances outlive the round at all.
 *
 * Off, every account is round-scoped, no ledger is attached, no roundstart carryover or upkeep is
 * applied and no transaction levy is taken, which is the stock upstream economy. Defaults on, since a
 * server running this module wants it; it exists so a broken ledger can be taken out of the loop
 * without a recompile.
 */
/datum/config_entry/flag/persistent_economy
	default = TRUE
