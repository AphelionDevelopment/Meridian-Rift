https://github.com/AphelionDevelopment/Meridian-Rift/pull/

## Persistent Economy

Module ID: PERSISTENT_ECONOMY

### Description:

An economy whose balances outlive the round. Department budgets and player accounts both carry over.
Persistence hangs off `/datum/bank_account` itself rather than a savings account beside it, so carried
credits are ordinary credits and every vendor, holopay, paystand and transfer spends them with no
per-surface code.

**The module is off until somebody turns it on.** Two switches, both of which have to be on:

- `PERSISTENT_ECONOMY`, a config flag, defaults on. The host's outer switch. Off, everything below is
  inert and the stock upstream economy runs.
- A stored setting thrown from the Economy Panel, defaults **off**, remembered in
  `data/persistent_economy_settings.json`. This is the one that decides.

The stored setting is read once per round, at the first thing that asks. Throwing the switch therefore
applies from the *next* round, and the panel says so. Accounts bind to their ledgers at roundstart and
as players spawn, so switching on mid-round attaches nothing, and switching off would stop the levy
while already-bound accounts kept writing to disk. Worse, attaching a live account mid-round makes it
adopt its stored balance, replacing this shift's earnings with last shift's figure mid-spend.

#### Ledgers

`/datum/economy_ledger` is a keyed store of account state backed by a `/datum/json_database`, so writes
get its `.savebac` backup and recovery path. One ledger owns one file, and accounts sharing it are told
apart by a namespaced key: `dept:<department_id>`, `char:<slot_index>`, and whatever comes later. Get
ledgers through `get_economy_ledger()`, never `new`.

A database rewrites its whole file on save, which drives three rules: only a bounded set of accounts
shares one file, per-player state gets a per-player file, and history is capped at
`LEDGER_HISTORY_LENGTH`. A full cross-round audit trail needs an append-only store and is not built
here.

Every record carries `LEDGER_SCHEMA_VERSION`; one stamped newer than the running build is refused
rather than guessed at, so a rollback does not rewrite newer records into an older shape. Balances are
clamped to `LEDGER_BALANCE_LIMIT` on both write and read.

Procs on `/datum/bank_account` drive it. `attach_ledger()` binds an account and adopts any stored
balance, debt and history, returning whether a record already existed, which is how a returning account
is told from a first-time one. `flush_to_ledger()` writes back, called from `adjust_money()` and
`Destroy()`. `detach_ledger()` unbinds without touching the record. A key carries at most one live
account: two accounts on one key would each overwrite the other's balance, which duplicates money.

`flush_economy_ledgers()` runs at round end from `SSpersistence.collect_data()`. Ordinary writes ride
on `adjust_money()`, so the flush mostly exists to close every ledger, which is what actually gets the
round onto disk: a `/datum/json_database` defers its writes to a zero-delay timer, so otherwise the
round's last flush would ride on SStimer firing once more before the reboot. The snapshot is taken
first, since it reads open ledgers from memory.

#### Department budgets

Departments share `data/persistent_economy.json`. At roundstart a department carries last round's
balance, pays `DEPARTMENT_UPKEEP_FRACTION` of it as operating costs, and if it ended below its budget
floor is topped up by half the shortfall, never past the floor. Half rather than all, so ending the
shift broke still costs something: a full top-up makes every balance under the floor worth the same
next round and gives a head no reason not to spend down to nothing. Cargo's floor is zero, so it keeps
what it earns and is never subsidised. Budgets are not scoped by map, so a department's money follows
the crew across a rotation.

`SSeconomy`'s inflation baseline is rebased to match. Upstream builds `station_target` from what the
crew should be holding, which only works while balances start near that figure each round; carried
balances are unbounded, so prices would open at whatever multiple of a paycheck the richest shift
banked. `get_station_target()` uses the wealth observed at the round's first payday instead, so
inflation tracks what the crew earns during the shift rather than what it walked in with. Hoarding
between rounds no longer moves prices. With nothing carried over it returns what it always did.

#### Player accounts

Keyed by ckey and character slot, in `data/player_saves/<c>/<ckey>/persistent_economy.json`. The
`STARTING_PAYCHECKS` grant is paid only to a character new to the ledger; a returning one lives on
payday, since paying it every shift is a faucet with nothing on the other side. Overwriting a character
slot inherits that slot's money, which comes with slot-keyed storage and is not handled here.

A player who switches characters mid-round leaves the old account in `SSeconomy.bank_accounts_by_id`,
still collecting payday. Round-scoped that was harmless; persisted it banks one income stream per
character a player cycles through, so `suspend_previous_character_income()` cuts income to every
account already open on that player's ledger. Only income stops, and the money stays spendable.

### Sink model

Everything players do to each other is pure transfer and creates nothing. Money enters from four
faucets: `MAX_GRANT_DPT` (500 per department per five minutes), the roundstart grant, departmental
earnings the grant ceiling does not see (cargo exports, techweb bounties, ordnance funding, shuttle
loans, station traits), and non-trade player earnings (LTSRBT sales, compactor bonus, GBP punchcards,
the powerator). Something has to remove it.

**Departments** are bounded by the `DEPARTMENT_UPKEEP_FRACTION` charge on their carried balance, which
is a hard ceiling: balances settle at earnings ÷ fraction and stop climbing. That is what you want on
an institutional budget. They also stop drawing `MAX_GRANT_DPT` past
`floor_amount * DEPARTMENT_GRANT_CEILING_MULT`, but that ceiling only bounds the passive grant. A
department that earns, cargo above all, keeps climbing on exports, and the 5% roundstart charge alone
settles it at roughly twenty times what it retains per round. That is high. If it turns out to be too
high, `DEPARTMENT_UPKEEP_FRACTION` is the figure to move and the round-end snapshot is what says so.

Cargo is measured against the grant ceiling despite having a floor of zero, which costs it nothing in
practice since exports dwarf the grant, but it is an inconsistency rather than a decision.

**Players** pay nothing on what they hold. The same ceiling caps a character at roughly one shift's
earnings ÷ the fraction and takes the most from someone one shift away from affording something
expensive. This economy is meant to be saved into.

The player-side sink is `TRANSACTION_LEVY_FRACTION` instead: 5% of every crew-to-crew transfer,
destroyed. A charge on movement has no ceiling and scales with how much trade is happening rather than
how much has been banked, so saving is not punished. It is taken from the recipient's side, so the
sender pays the figure they agreed and the seller carries the fee, and it cannot make a transfer fail
because the sender's funds were already checked against the full amount.

**The levy is charged inside `adjust_money()`**, not at the surfaces that move money. This is the
important structural decision here. Applied per surface it was already missing from three of them: the
custom vendor, the display case and the pricetag component all credit an account directly and never
touch `transfer_money()`. The custom vendor is the most used player-run shop in the game, and crew
route trade down whichever path is free. Charging centrally inverts the default, so an unconsidered
surface is taxed rather than free and the failure mode is a fee somebody queries. Anything that is not
crew paying crew has to say so with `LEVY_EXEMPT`:

- Salary out of a department budget, handled in `transfer_money()`.
- The roundstart grant, and any other `free` payday.
- Refunds, currently the PDA betting program.
- Administrative adjustment from the economy panel.

Departmental accounts are exempt on the receiving side automatically, since money paid to a department
or a machine is priced already.

Banking cash is charged `DEPOSIT_LEVY_FRACTION` instead. Withdrawing to a holochip, handing it over and
depositing is a crew-to-crew transfer in disguise and has to cost the same, but the same code path also
banks coins, vendor change and mining payouts that were never anyone else's. Separate define so that
case can be priced on its own later. The two rates are equal today.

The fee is shown wherever it is taken: the ID card says what it withheld, and the holopay tells the
owner the fee rather than a gross it no longer receives. A levy nobody can see reads as a bug.

Remaining sinks are unchanged: vendors and machines destroy what they take, and unbanked cash dies with
the round.

### Economy Panel

`Admin.Game`, `R_ADMIN`. Three views.

**Live and stored.** Editing a live account writes through to its ledger; editing a stored record
changes only the file, so doing that to a character in the round gets overwritten on their next
transaction. Records with a live account behind them are marked. The stored view reads the station
ledger by default and can be pointed at any player's ledger by ckey, the only way to see a character
who is not playing. Later station-side account types appear automatically once they share the station
ledger, since the panel enumerates the file rather than a fixed list.

Adjust obeys the account's rules, so debt collection takes its cut and an overdraft is refused; Set
overwrites outright. Every mutation is logged to `log_admin` and `message_admins`. Rows expand to the
last `LEDGER_HISTORY_LENGTH` transactions, newest first, and a suspended account is marked.

**All Ledgers** reads every ledger on the server, players not in the round included, richest first with
a running total. It answers who is rich and whether anyone got rich suddenly, which the other views
cannot. Run on request rather than in `ui_data()`, since it walks every player save directory, with the
age of the scan shown beside it. Open ledgers are read from memory and closed ones off disk.

**Clear Ledger** erases every record in whichever ledger the stored view is pointed at, for a ledger
that has gone wrong or a test server starting from nothing. It detaches bound accounts, which is what
makes the wipe hold: otherwise each one writes itself back and the wipe looks like it silently failed.
Detached accounts keep the credits they are holding, since erasing what carries over and confiscating a
balance mid-shift are separate decisions.

The panel is also where persistence is switched. The header states what the round in progress is
running under and the button states what the next one will run under, since conflating those is how an
admin concludes the switch is broken. The button is disabled with a reason when the config flag is off.

### Measurement

`log_economy_snapshot()` runs once at round end, from `flush_economy_ledgers()` after every account has
written back. It logs total credits held, split between departments and players, the record counts
behind those figures, and outstanding debt, and records the totals to blackbox.

Every figure this module turns on is a guess without it. The levies, the grant ceiling and the upkeep
charge are all calibrated against how fast the supply is growing, and nothing else measures that:
blackbox tracks flows like credits levied, which says how hard the sinks are working but not whether
they are keeping up.

Two policy calls, both deliberate and both no-ops in code. A balance survives its character's death,
since the record is keyed to the character and not the body. Theft is uncapped, since draining a stolen
ID moves money rather than destroying it; stealing into an account with no ledger, such as an antag's
forged ID, does destroy it at round end, which is a small unplanned sink.

### TG Proc/File Changes:

None of these can be modular overrides: there is no subtype seam to hook and DM will not take a second
definition of a proc on the same type.

- `code/modules/economy/account.dm`: `/datum/bank_account/proc/adjust_money`. Gains a `levy_fraction`
  argument defaulting to `TRANSACTION_LEVY_FRACTION`, charges the levy on incoming credits, and calls
  `flush_to_ledger()`. Both halves of the module hang off this one chokepoint.
- `code/modules/economy/account.dm`: `/datum/bank_account/department/adjust_money`. Signature kept in
  step with its parent, so the override cannot silently drop the argument if the exemption ever moves.
- `code/modules/economy/account.dm`: `/datum/bank_account/Destroy`. Added `flush_to_ledger()` and
  `detach_ledger()`.
- `code/modules/economy/account.dm`: `/datum/bank_account/proc/payday`. Returns early on a suspended
  account, and `LEVY_EXEMPT` on the `free` grant.
- `code/modules/economy/account.dm`: `/datum/bank_account/proc/transfer_money`. Passes `LEVY_EXEMPT`
  when the sender is departmental, which keeps payday from being docked.
- `code/modules/economy/account.dm`: `/datum/bank_account/proc/add_log_to_history`. The literal `20`
  became `LEDGER_HISTORY_LENGTH`. They were equal by coincidence, and a record restored into a
  differently sized buffer than it was written from would have failed quietly.
- `code/modules/economy/holopay.dm`: `/obj/structure/holopay/proc/alert_buyer`. Takes a levy fraction
  rather than a precomputed levy, and tells the owner the fee instead of a gross it no longer receives.
  The holochip branch of `item_interact` passes the deposit rate.
- `code/game/objects/items/cards_ids.dm`: `/obj/item/card/id/proc/insert_money` and
  `/obj/item/card/id/proc/mass_insert_money`. Bank at `DEPOSIT_LEVY_FRACTION`; `insert_money` reports
  the fee.
- `code/modules/modular_computers/file_system/programs/betting.dm`: the five refund paths in
  `/datum/active_bet` are `LEVY_EXEMPT`. Winnings are levied, since a pot is other players' money.
- `code/datums/quirks/negative_quirks/indebted.dm`: `/datum/quirk/indebted/add_unique`. A character
  that still owes keeps what it owes; one that has cleared its debt rolls a fresh one. `add_unique`
  runs on every spawn, so with balances carrying over the quirk rolled a fresh
  `PAYCHECK_CREW * rand(275, 325)` every round on top of whatever was left, faster than debt collection
  could retire it. Skipping the roll outright left a cleared character with a `-2` quirk and no
  downside, so it re-rolls instead. The achievement is per-player and is not awarded twice.
- `code/controllers/subsystem/persistence/_persistence.dm`:
  `/datum/controller/subsystem/persistence/proc/collect_data`. One call to `flush_economy_ledgers()`.
- `modular_nova/master_files/code/modules/cargo/packs/_companies.dm`:
  `/datum/supply_pack/companies/generate`. Cargo's cut was written straight to `account_balance`, the
  one path that skipped `adjust_money()` and never reached the ledger. Now goes through it.
- `code/controllers/subsystem/economy.dm`: `/datum/controller/subsystem/economy/proc/Initialize`. One
  call to `restore_department_budgets()`, after the accounts are built.
- `code/controllers/subsystem/economy.dm`: `/datum/controller/subsystem/economy/proc/fire`. The
  `station_target` assignment now calls `get_station_target()`. This leaves `temporary_total`
  accumulated in `issue_paydays()` but unread, kept to hold the diff to one line.
- `code/controllers/subsystem/economy.dm`:
  `/datum/controller/subsystem/economy/proc/departmental_payouts`. Gates the grant on
  `should_receive_department_grant()`.
- `code/modules/jobs/job_types/_job.dm`: `/mob/living/carbon/human/proc/on_job_equipping`. The
  unconditional `payday(STARTING_PAYCHECKS)` now calls `attach_character_account()`, which pays it only
  when the character is new to the ledger.

### Modular Overrides:

- N/A

### Defines:

- `code/__DEFINES/~aphelion_defines/persistent_economy.dm`: `PERSISTENT_ECONOMY_ENABLED`,
  `LEDGER_SCHEMA_VERSION`, `LEDGER_BALANCE_LIMIT`, `LEDGER_HISTORY_LENGTH`,
  `TRANSACTION_LEVY_FRACTION`, `DEPOSIT_LEVY_FRACTION`, `LEVY_EXEMPT`, and the `LEDGER_FIELD_*` record
  keys. Shared across files: the record keys are read straight off disk by `economy_snapshot.dm`, and
  the levy defines are reachable from any core file that credits an account.
- `modular_aphelion/modules/persistent_economy/code/department_budgets.dm`: `STATION_LEDGER_PATH`,
  `DEPARTMENT_KEY_PREFIX`, `DEPARTMENT_GRANT_CEILING_MULT`, `DEPARTMENT_UPKEEP_FRACTION`,
  `DEPARTMENT_SUBSIDY_FRACTION`.
- `modular_aphelion/modules/persistent_economy/code/economy_snapshot.dm`: `PLAYER_SAVES_PATH`,
  `PLAYER_LEDGER_FILENAME`.
- `modular_aphelion/modules/persistent_economy/code/economy_settings.dm`: `ECONOMY_SETTINGS_PATH`,
  `SETTING_KEY_ENABLED`.
- `modular_aphelion/modules/persistent_economy/code/character_accounts.dm`: `CHARACTER_KEY_PREFIX`.
- `modular_aphelion/modules/persistent_economy/code/economy_admin_panel.dm`: `ADMIN_BALANCE_LIMIT`.
- `code/modules/unit_tests/~aphelion/persistent_economy.dm`: `TEST_LEDGER_PATH`.

All single-file defines are `#undef`'d in the file that declares them.

### Included files that are not contained in this module:

- `tgui/packages/tgui/interfaces/EconomyAdminPanel.tsx`. The panel interface. New TGUI files cannot
  live in a module folder, as the bundler only reads `tgui/packages/tgui/interfaces/`.
- `code/modules/unit_tests/~aphelion/persistent_economy.dm`. Ledger and levy tests. Unit tests are
  gathered from `code/modules/unit_tests/`.
- `code/__DEFINES/~aphelion_defines/persistent_economy.dm`. The defines shared across the module.

### Credits:

- pepe
