https://github.com/AphelionDevelopment/Meridian-Rift/pull/

## Persistent Economy

Module ID: PERSISTENT_ECONOMY

### Description:

An economy whose balances outlive the round. Department budgets and player accounts both carry over.
Persistence hangs off `/datum/bank_account` itself rather than a savings account beside it, so
carried credits are ordinary credits: every vendor, holopay, paystand and transfer spends them with
no per-surface code.

The whole module is gated on the `PERSISTENT_ECONOMY` config flag, on by default. Off, every account
is round-scoped and nothing below applies: no carryover, no levy, no rebased inflation baseline. It is
there so a broken ledger can be taken out of the loop without a recompile.

`/datum/economy_ledger` is a keyed store of account state backed by a `/datum/json_database`, so
writes get its `.savebac` backup and recovery path. One ledger owns one file. Accounts sharing a file
are separated by a namespaced key: `dept:<department_id>`, `char:<slot_index>`, and whatever later
systems need. A database rewrites its whole file on save, so only a bounded set of accounts (the
department budgets) should share one. Per-player state belongs in a per-player file. Get ledgers
through `get_economy_ledger()`, never `new`.

Every record carries `LEDGER_SCHEMA_VERSION`. A record stamped newer than the running build is refused
rather than guessed at, so rolling a server back does not rewrite newer records into an older shape.
Bump the version and handle the older shape in `read_record()` together, in one change.

Balances are clamped to `LEDGER_BALANCE_LIMIT` on both write and read. A hand-edited or corrupted file
cannot put a figure into the economy that no legitimate play could produce.

Procs on `/datum/bank_account` drive it. `attach_ledger()` binds an account to a ledger and adopts any
stored balance, debt and transaction history, returning whether a record already existed. That return
tells a returning account from a first-time one, which decides whether roundstart grants are paid.
`flush_to_ledger()` writes the account back, called from `adjust_money()`, the single proc every
balance change passes through, and from `Destroy()`. `detach_ledger()` unbinds without touching the
stored record.

A key carries at most one live account, enforced in `attach_ledger()`. Two accounts on one key each
write their own balance over the other's, so credits spent from one are restored by the next write
from the other, which duplicates money. An account that loses its key is detached and suspended.

`flush_economy_ledgers()` runs at round end from `SSpersistence.collect_data()`. Ordinary writes ride
on `adjust_money()`, so this only covers state that changed without a transaction behind it and backs
up the last transaction of the round against a missed deferred save.

Ledgers live for the whole round. Accounts hold a hard ref to theirs, so destroying one mid-round
while an account still points at it would hard delete the ledger.

Records keep the last `LEDGER_HISTORY_LENGTH` transactions, the same buffer
`/datum/bank_account/var/transaction_history` holds in-round, restored on attach. It is capped for the
same reason only bounded account sets share a file: the whole file is rewritten on every save, so an
unbounded log here would grow the cost of every future transaction. A full cross-round audit trail
needs a store that appends rather than rewrites, and is not built here.

Department budgets share `data/persistent_economy.json`. At roundstart a department carries over last
round's balance and, if it ended below its budget floor, is topped up by half the shortfall, never past
the floor. Banking a surplus is worth something, a bankrupted department is still playable next shift,
and ending the shift broke still costs something: a full top-up would make every balance under the
floor worth the same next round, leaving a departmental head no reason not to spend down to nothing
before the shift ends. Cargo's floor is zero, so it keeps what it earns and is never subsidised.
Budgets are not scoped by map: a department's money follows the crew across a rotation rather than
belonging to the station they stood on.

`SSeconomy`'s inflation baseline is rebased to match. Upstream builds `station_target` from what the
crew should be holding, every account's paycheck times `STARTING_PAYCHECKS`, which only works while
balances start near that figure each round. Carried balances are unbounded, so vendor prices would
open at whatever multiple of a stock paycheck the richest shift banked. `get_station_target()` uses
the wealth observed at the round's first payday instead, so inflation measures what the crew earns
during the shift rather than what it walked in with. With nothing carried over it returns what it
always did. Consequence: hoarding between rounds no longer drives prices up, only in-shift earnings do.

Player accounts carry over per character, keyed by ckey and character slot in
`data/player_saves/<c>/<ckey>/persistent_economy.json`. The `STARTING_PAYCHECKS` grant is paid only to
a character new to the ledger; a returning one lives on passive payday, since paying it every shift
would be a faucet with nothing on the other side. Overwriting a character slot inherits that slot's
money, a property of slot-keyed storage that is not handled here.

A player who switches characters mid-round leaves the old account in `SSeconomy.bank_accounts_by_id`,
where it keeps collecting payday. Round-scoped that was harmless. Persisted it banks one income stream
per character a player cycles through, so `suspend_previous_character_income()` cuts income to every
account already open on that player's ledger. Only income stops; the money stays spendable and
transferable, since it is still that character's.

### Sink model

Money is created in only one place: `MAX_GRANT_DPT`, 500 per department per five minutes. Crew payday
is a transfer out of a department budget, not new money, so the department grant is what ultimately
bounds crew income. Everything players do to each other, including all player-priced trade, is pure
transfer and creates nothing. So the supply only grows unless something removes it.

Departments and players are bounded differently, because they are not the same kind of account.

**Departments** keep a proportional charge, 5% of the carried balance at roundstart as operating
costs, applied before the floor top-up so one below its floor still lands on it. They also stop
drawing `MAX_GRANT_DPT` at three times their budget floor. A proportional charge is a hard ceiling:
balances settle at earnings ÷ fraction and stop climbing. On an institutional budget that is exactly
what is wanted. Cargo, which earns rather than draws, is still not capped by the grant ceiling.

**Players** pay nothing on what they hold. The same ceiling that suits a department is wrong for a
player: it caps a character at roughly one shift's earnings ÷ the fraction, which for payday-only
income is about 24,000 credits, and it takes the most from someone one shift from affording something
expensive. This economy is meant to be saved into.

The player-side sink is `TRANSACTION_LEVY_FRACTION` instead: 5% of every crew-to-crew transfer,
destroyed. A charge on movement has no ceiling. It scales with how much trade is happening rather than
how much has been banked, so a busy shift drains more than a quiet one and saving is not punished. It
is taken from the recipient's side, so the sender pays the figure they agreed and the seller carries
the fee, as a broker's cut works, and it cannot make a transfer fail because the sender's funds were
already checked against the full amount.

Transfers where either side is a departmental account are exempt. That covers payday, which would
otherwise be docked on the way out of a budget, and covers paying a department or a machine for a
service, which is priced already. What is left is crew paying crew.

A levy is only a sink if it cannot be walked around, and `transfer_money()` is not the path most
credits take between two players. `charge_transaction_levy()` exists so every path charges the same
cut: the ID card transfer verb, the holopay and paystand, and banking physical currency. Add the call
to any new path that moves credits into an account, or that path becomes the one everybody uses.

Banking cash is charged `DEPOSIT_LEVY_FRACTION` rather than the transfer levy, because it is not quite
the same thing. Withdrawing to a holochip, handing it over and depositing is a crew-to-crew transfer
wearing a disguise and has to cost the same, but the same code path also banks coins, vendor change
and mining payouts that were never anyone else's. It is a separate define so that case can be priced
on its own without reopening the hole.

The remaining sinks are unchanged: vendors and machines destroy what they take, and cash that is never
banked dies with the round.

**Economy Panel** (`Admin.Game`, `R_ADMIN`) is the admin-side view. It separates the accounts that
exist this round, station budgets and crew accounts, from the records sitting in a ledger on disk,
because they are not the same. Editing a live account changes the account and writes through to its
ledger. Editing a stored record changes only the file, so doing that to a character in the round gets
overwritten on their next transaction. Records with a live account behind them are marked live.

The stored view reads the station ledger by default and can be pointed at any player's ledger by
ckey, the only way to see the balance of a character who is not playing. Later station-side account
types such as factions or ships appear there automatically once they share the station ledger, since
the panel enumerates the file rather than a fixed list of categories.

Adjust obeys the account's own rules: debt collection takes its cut and an overdraft is refused. Set
overwrites outright and is the way around that. Every mutation is logged to `log_admin` and
`message_admins`.

Every row in both views expands to the last `LEDGER_HISTORY_LENGTH` transactions on that account,
newest first. A live account shows what it has done this round, a stored record shows what it carried
in. An account whose income has been suspended is marked in its row.

**All Ledgers** is the third view, and the only one that does not need to be told where to look. It
reads every ledger on the server, players who are not in the round included, and lists them richest
first with a running total. That answers the two questions the other views cannot: who is rich, and
did anyone get rich suddenly. They are the same question, and both need the accounts of people who are
not playing. Each row jumps the stored view to that ledger for editing.

It is run on request rather than gathered in `ui_data()`, because it walks every player save directory
on disk and `ui_data()` runs on every update. The result is held on the panel with the age of the scan
shown beside it. Open ledgers are read from memory and closed ones off disk, since a
`/datum/json_database` defers its writes and a file behind a ledger that is open right now is at least
one save stale.

### Measurement

`log_economy_snapshot()` runs once at round end, from `flush_economy_ledgers()` after every account has
written itself back. It logs total credits held, split between departments and players, the number of
records behind those figures, and outstanding debt, and records the totals to blackbox.

Every figure this module turns on is a guess without it. The transaction levy, the deposit levy, the
department grant ceiling and the operating charge are all calibrated against how fast the supply is
growing, and nothing else measures that: blackbox tracks flows such as credits levied, which says how
hard the sinks are working but not whether they are keeping up. Prices for whatever persistent money
eventually buys have to come from this number too.

Two policy calls, both deliberate and both no-ops in code. A balance survives its character's death,
since the record is keyed to the character and not the body. Theft is uncapped: draining a stolen ID
moves money between accounts rather than destroying it, so it stays in the economy. Stealing into an
account with no ledger, such as an antag's forged ID, does destroy it at round end. That is a small
unplanned sink.

### TG Proc/File Changes:

None of these can be modular overrides: there is no subtype seam to hook and DM will not take a second
definition of a proc on the same type.

- `code/modules/economy/account.dm`: `/datum/bank_account/proc/adjust_money`. One added call to
  `flush_to_ledger()`.
- `code/modules/economy/account.dm`: `/datum/bank_account/Destroy`. Added `flush_to_ledger()` and
  `detach_ledger()`, so a destroyed account writes its last state and stops the ledger holding a ref
  to it.
- `code/modules/economy/account.dm`: `/datum/bank_account/proc/payday`. Two added lines returning
  early on a suspended account.
- `code/modules/economy/account.dm`: `/datum/bank_account/proc/transfer_money`. The recipient's
  `adjust_money()` now takes the transaction levy off first.
- `code/modules/economy/holopay.dm`: `/obj/structure/holopay/proc/alert_buyer`. Takes the levy already
  charged on the payment and credits the owner net of it. Defaulted to zero so nothing else changes.
- `code/modules/economy/holopay.dm`: the holochip branch of `item_interact` and
  `/obj/structure/holopay/proc/pay`. Both charge the levy and hand it to `alert_buyer()`. The paystand
  paid the owner and charged the payer with two separate `adjust_money()` calls, never touching
  `transfer_money()`, so it was the untaxed path for the surface most player trade actually uses.
- `code/game/objects/items/cards_ids.dm`: `/obj/item/card/id/proc/insert_money` and
  `/obj/item/card/id/proc/mass_insert_money`. Both take `DEPOSIT_LEVY_FRACTION` off the sum before it
  is banked. Withdraw, hand over the holochip, deposit was otherwise a transfer with no levy on it.
- `code/datums/quirks/negative_quirks/indebted.dm`: `/datum/quirk/indebted/add_unique`. Returns early
  on a character that has played before, keeping the debt it already owes. `add_unique` runs every
  time a character spawns, so with balances carrying over the quirk rolled a fresh
  `PAYCHECK_CREW * rand(275, 325)` every round on top of whatever was left, far faster than debt
  collection retires it. The debt became unpayable and the achievement for clearing it unreachable.
- `code/controllers/subsystem/persistence/_persistence.dm`:
  `/datum/controller/subsystem/persistence/proc/collect_data`. One added call to
  `flush_economy_ledgers()`.
- `modular_nova/master_files/code/modules/cargo/packs/_companies.dm`:
  `/datum/supply_pack/companies/generate`. Cargo's cut was written straight to `account_balance`,
  which is the one path that skipped `adjust_money()` and so never reached the ledger. Now goes
  through `adjust_money()`.
- `code/controllers/subsystem/economy.dm`: `/datum/controller/subsystem/economy/proc/Initialize`. One
  added call to `restore_department_budgets()`, after the accounts are built.
- `code/controllers/subsystem/economy.dm`: `/datum/controller/subsystem/economy/proc/fire`. The
  `station_target` assignment now calls `get_station_target()`. This leaves `temporary_total`
  accumulated in `issue_paydays()` but unread; it is left in place to keep the diff to one line.
- `code/controllers/subsystem/economy.dm`: `/datum/controller/subsystem/economy/proc/departmental_payouts`.
  Two added lines gating the grant on `should_receive_department_grant()`.
- `code/modules/jobs/job_types/_job.dm`: `/mob/living/carbon/human/proc/on_job_equipping`. The
  unconditional `payday(STARTING_PAYCHECKS)` now calls `attach_character_account()`, which pays it
  only when the character is new to the ledger.

### Modular Overrides:

- N/A

### Defines:

- `code/__DEFINES/~aphelion_defines/persistent_economy.dm`: `PERSISTENT_ECONOMY_ENABLED`,
  `LEDGER_SCHEMA_VERSION`, `LEDGER_BALANCE_LIMIT`, `LEDGER_HISTORY_LENGTH`,
  `TRANSACTION_LEVY_FRACTION`, `DEPOSIT_LEVY_FRACTION`, and the `LEDGER_FIELD_*` record keys. Used
  across more than one file, so they live here rather than in the module. The record keys moved here
  from `economy_ledger.dm` once `economy_snapshot.dm` needed to read records straight off disk.
- `modular_aphelion/modules/persistent_economy/code/department_budgets.dm`: `STATION_LEDGER_PATH`,
  `DEPARTMENT_KEY_PREFIX`, `DEPARTMENT_GRANT_CEILING_MULT`, `DEPARTMENT_UPKEEP_FRACTION`,
  `DEPARTMENT_SUBSIDY_FRACTION`. All `#undef`'d in the same file.
- `modular_aphelion/modules/persistent_economy/code/economy_snapshot.dm`: `PLAYER_SAVES_PATH`,
  `PLAYER_LEDGER_FILENAME`. Both `#undef`'d in the same file.
- `modular_aphelion/modules/persistent_economy/code/character_accounts.dm`: `CHARACTER_KEY_PREFIX`.
  `#undef`'d in the same file.
- `modular_aphelion/modules/persistent_economy/code/economy_admin_panel.dm`: `ADMIN_BALANCE_LIMIT`.
  `#undef`'d in the same file.
- `code/modules/unit_tests/~aphelion/persistent_economy.dm`: `TEST_LEDGER_PATH`. `#undef`'d in the
  same file.

### Config:

- `PERSISTENT_ECONOMY`, a flag, on by default. Off, the module does nothing and the stock upstream
  economy is left behind.

### Included files that are not contained in this module:

- `tgui/packages/tgui/interfaces/EconomyAdminPanel.tsx`. The Economy Panel interface. New TGUI files
  cannot live inside a module folder, as the bundler only reads `tgui/packages/tgui/interfaces/`.
- `code/modules/unit_tests/~aphelion/persistent_economy.dm`. The ledger and levy tests. Unit tests
  cannot live inside a module folder, as they are gathered from `code/modules/unit_tests/`.
- `code/__DEFINES/~aphelion_defines/persistent_economy.dm`. The defines shared across the module's
  files.

### Credits:

- pepe
