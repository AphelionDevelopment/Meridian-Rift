/// Whether balances outlive the round. Every entry point into the persistent economy checks this, so
/// switching it off leaves the stock upstream economy behind. See [/datum/config_entry/flag/persistent_economy].
#define PERSISTENT_ECONOMY_ENABLED (CONFIG_GET(flag/persistent_economy))

/// Schema version stamped into every ledger record written. Bump when the shape of a record changes,
/// and handle the older shape in [/datum/economy_ledger/proc/read_record] at the same time.
#define LEDGER_SCHEMA_VERSION 1

/// Largest balance or debt the ledger will load off disk, in either direction. A record beyond this is
/// clamped rather than trusted, so a hand-edited or corrupted file cannot mint an unspendable fortune.
#define LEDGER_BALANCE_LIMIT 1000000000

/// How many transaction history entries a ledger record carries. Matches the round-scoped cap in
/// [/datum/bank_account/proc/add_log_to_history], so restoring a record fills the same buffer.
#define LEDGER_HISTORY_LENGTH 20

/// Fraction of every player-to-player transfer destroyed as a transaction levy. The economy's main
/// continuous sink. See the sink model in the module readme before changing it.
#define TRANSACTION_LEVY_FRACTION 0.05
