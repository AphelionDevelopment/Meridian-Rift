/// Whether balances outlive the round. Every entry point into the persistent economy checks this, so
/// switching it off leaves the stock upstream economy behind.
///
/// Two switches, and both have to be on. The config flag is the host's, and locks the feature off for
/// a server that does not want it at all. The stored setting is the admin's, thrown from the economy
/// panel and remembered between rounds, and is off until somebody turns it on. See
/// [/datum/config_entry/flag/persistent_economy] and [/proc/persistent_economy_active].
#define PERSISTENT_ECONOMY_ENABLED (CONFIG_GET(flag/persistent_economy) && persistent_economy_active())

/// Schema version stamped into every ledger record written. Bump when the shape of a record changes,
/// and handle the older shape in [/datum/economy_ledger/proc/read_record] at the same time.
#define LEDGER_SCHEMA_VERSION 1

/// Largest balance or debt the ledger will load off disk, in either direction. A record beyond this is
/// clamped rather than trusted, so a hand-edited or corrupted file cannot mint an unspendable fortune.
#define LEDGER_BALANCE_LIMIT 1000000000

/// How many transaction history entries a ledger record carries. [/datum/bank_account/proc/add_log_to_history]
/// caps the round-scoped buffer at this same figure, so restoring a record fills it exactly.
#define LEDGER_HISTORY_LENGTH 20

/// Key of the schema version inside a ledger record. Absent on records written before versioning.
#define LEDGER_FIELD_VERSION "version"
/// Key of the credit balance inside a ledger record.
#define LEDGER_FIELD_BALANCE "balance"
/// Key of the outstanding debt inside a ledger record.
#define LEDGER_FIELD_DEBT "debt"
/// Key of the account holder's name inside a ledger record. For admin readability, never read back.
#define LEDGER_FIELD_HOLDER "holder"
/// Key of the `world.realtime` stamp of the last write inside a ledger record.
#define LEDGER_FIELD_UPDATED "updated"
/// Key of the transaction history inside a ledger record. An array of `adjusted_money`/`reason` pairs.
#define LEDGER_FIELD_HISTORY "history"

/// Fraction of every player-to-player transfer destroyed as a transaction levy. The economy's main
/// continuous sink. See the sink model in the module readme before changing it.
#define TRANSACTION_LEVY_FRACTION 0.05

/// Fraction of physical currency destroyed when it is banked. Without it, withdrawing to a holochip,
/// handing it over and depositing moves credits between crew at no charge, which is the transaction
/// levy with extra steps. Tuned apart from that levy because it also catches cash that was never
/// anyone else's, such as coins and vendor change.
#define DEPOSIT_LEVY_FRACTION 0.05

/// Passed as [/datum/bank_account/proc/adjust_money]'s `levy_fraction` to let credits in untaxed.
/// Every path that is not crew paying crew has to say so, since the levy is charged by default.
/// Reserved for salary, grants, refunds and administrative action. See the module readme.
#define LEVY_EXEMPT 0
