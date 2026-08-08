/// File the module's own settings are stored in.
#define ECONOMY_SETTINGS_PATH "data/persistent_economy_settings.json"
/// Key the enabled switch is stored under.
#define SETTING_KEY_ENABLED "enabled"

/// The settings store, opened on first use. See [/proc/get_economy_settings].
GLOBAL_DATUM(economy_settings_store, /datum/json_database)
/// Whether persistence is running this round, captured once. See [/proc/persistent_economy_active].
GLOBAL_VAR(persistent_economy_active)

/**
 * The store the module's own settings live in, opened on first use.
 *
 * Deliberately not the station ledger, and deliberately not a config entry. Not the ledger, because
 * clearing a ledger has to be able to erase every record in it without also resetting whether the
 * module is switched on. Not config, because the switch is meant to be thrown from the panel by
 * someone who is not editing files on the host and restarting.
 */
/proc/get_economy_settings()
	if(isnull(GLOB.economy_settings_store))
		GLOB.economy_settings_store = new /datum/json_database(ECONOMY_SETTINGS_PATH)

	return GLOB.economy_settings_store

/**
 * The stored setting, which is what the next round will run under.
 *
 * Off unless somebody has switched it on. An economy that quietly starts remembering balances is a
 * much worse surprise than one that quietly does not, so the default is the one that changes nothing.
 */
/proc/persistent_economy_setting()
	return get_economy_settings().get_key(SETTING_KEY_ENABLED) ? TRUE : FALSE

/**
 * Whether persistence is running for the round in progress.
 *
 * Read from disk once, the first time anything asks, and then held for the rest of the round. The
 * panel's switch writes the stored setting without touching this, so a round runs start to finish
 * under one answer.
 *
 * Not live for a reason. Accounts bind to ledgers at roundstart and as each player spawns, so
 * switching on mid-round would attach nothing and persist nothing, while switching off mid-round would
 * stop the levy and the carryover reasoning while already-bound accounts carried on writing themselves
 * to disk. Worse, attaching a live account mid-round would overwrite the balance it is holding with
 * whatever it ended the last round on, taking credits off players in the middle of a shift. A round
 * that is half persistent is harder to reason about than one that waits.
 */
/proc/persistent_economy_active()
	if(isnull(GLOB.persistent_economy_active))
		GLOB.persistent_economy_active = persistent_economy_setting()

	return GLOB.persistent_economy_active

/**
 * Writes the stored setting. Takes effect from the next round, never the one in progress.
 * Arguments:
 * * enabled - whether balances should outlive the round from the next round onwards.
 */
/proc/set_persistent_economy_setting(enabled)
	get_economy_settings().set_key(SETTING_KEY_ENABLED, enabled ? TRUE : FALSE)

#undef ECONOMY_SETTINGS_PATH
#undef SETTING_KEY_ENABLED
