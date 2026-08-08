https://github.com/AphelionDevelopment/Meridian-Rift/pull/

## Persistent Economy

Module ID: PERSISTENT_ECONOMY

### Description:

An economy whose balances outlive the round. Department budgets and player accounts both carry over.
Persistence hangs off `/datum/bank_account` itself rather than a savings account beside it, so
carried credits are ordinary credits: every vendor, holopay, paystand and transfer spends them with
no per-surface code.

The whole module is gated, and **it is off until somebody turns it on**. Off, every account is
round-scoped and nothing below applies: no carryover, no levy, no rebased inflation baseline, which is
the stock upstream economy.

There are two switches and both have to be on. The `PERSISTENT_ECONOMY` config flag is the host's,
defaults on, and locks the feature off for a server that does not want it at all. The switch that
actually decides is a stored setting thrown from the Economy Panel, which defaults **off** and is
remembered between rounds in `data/persistent_economy_settings.json`. An economy that quietly starts
remembering balances is a far worse surprise than one that quietly does not, so the default is the one
that changes nothing.

The stored setting is read once, at the first thing that asks in a round, and held for the rest of it.
Throwing the switch therefore applies from the *next* round, never the one in progress, and the panel
says so. This is not laziness: accounts bind to their ledgers at roundstart and as each player spawns,
so switching on mid-round attaches nothing and persists nothing, while switching off mid-round would
stop the levy while accounts that are already bound carried on writing to disk. Worse, attaching a live
account mid-round makes it adopt its stored balance, which would replace a player's earnings this shift
with last shift's figure while they were in the middle of spending them.

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
up the last transaction of the round against a missed deferred save. It then closes every ledger,
which is what actually gets the round onto disk: a `/datum/json_database` defers its writes to a
zero-delay timer and nothing else destroys a ledger, so otherwise the entire round's final flush would
be riding on SStimer firing once more before the world reboots. Destroying the database forces the
save synchronously. The snapshot is taken before the teardown, since it reads open ledgers from memory.

Ledgers otherwise live for the whole round. Accounts hold a hard ref to theirs, so destroying one
mid-round while an account still points at it would hard delete the ledger; `Destroy()` detaches its
live accounts first for that reason.

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

Everything players do to each other, including all player-priced trade, is pure transfer and creates
nothing. Money enters the economy from four kinds of faucet, and the supply grows unless something
removes it:

- `MAX_GRANT_DPT`, 500 per department per five minutes. Ceilinged, see below. Crew payday is a
  transfer out of a department budget rather than new money, so this bounds ordinary crew income.
- The roundstart grant, `STARTING_PAYCHECKS` paid `free`, which mints rather than drawing on a budget.
  Paid once per character rather than once per shift, so it is bounded by how many characters a player
  brings rather than by how long they play.
- Departmental earnings, which the grant ceiling does not see: cargo exports, techweb bounties,
  ordnance paper funding, shuttle loan events and station traits all credit a budget directly.
- Player earnings that are not trade: black market sales through the LTSRBT, the janitor's compactor
  bonus, GBP punchcards, the powerator.

Departments and players are bounded differently, because they are not the same kind of account.

**Departments** keep a proportional charge, `DEPARTMENT_UPKEEP_FRACTION` of the carried balance at
roundstart as operating costs, applied before the floor top-up. They also stop drawing `MAX_GRANT_DPT`
at three times their budget floor. A proportional charge is a hard ceiling: balances settle at
earnings ÷ fraction and stop climbing. On an institutional budget that is exactly what is wanted.

Be clear about where that ceiling actually sits. The grant ceiling bounds only the passive grant, and
a department that earns — cargo above all — keeps climbing past it on exports and bounties. What
bounds those is the 5% roundstart charge alone, which settles a budget at roughly twenty times what it
retains per round, not at three times its floor. That is a high ceiling. If it turns out to be too
high, `DEPARTMENT_UPKEEP_FRACTION` is the figure to move, and the round-end snapshot is what says so.

The grant ceiling is `floor_amount * DEPARTMENT_GRANT_CEILING_MULT` for every department including
cargo, whose subsidy floor is zero. Cargo is therefore measured against a floor it does not otherwise
have. It costs cargo nothing in practice, since exports dwarf the grant, but it is an inconsistency
rather than a decision.

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

**The levy is charged inside `adjust_money()`**, the one proc every balance change already passes
through, and not at the surfaces that move money. This is the important structural decision in the
module and it was arrived at the hard way.

The levy was first applied per surface: `transfer_money()`, the holopay, the ID card deposit procs.
That makes correctness depend on every future contributor remembering to add the call, and three
surfaces were already missing it — the custom vendor, the display case and the pricetag component, all
of which credit an account directly with two `adjust_money()` calls and never touch `transfer_money()`.
The custom vendor is the most used player-run shop in the game. A levy with holes that size is not a
sink at all, because crew route their trade down whichever path is free.

Charging it centrally inverts the default. A surface nobody considered is taxed rather than free, so
the failure mode is a fee somebody queries rather than an economy with no drain. Anything that is
genuinely not crew paying crew has to say so, by passing `LEVY_EXEMPT`:

- Salary out of a department budget, handled in `transfer_money()` when the sender is departmental.
- The roundstart grant, and any other `free` payday.
- Refunds, currently the PDA betting program. Taxing money coming back is a straight bug.
- Administrative adjustment from the economy panel. An admin typing a figure means that figure.

Departmental accounts are exempt on the receiving side automatically, since money paid to a department
or a machine is priced already.

Banking cash is charged `DEPOSIT_LEVY_FRACTION` rather than the transfer levy, because it is not quite
the same thing. Withdrawing to a holochip, handing it over and depositing is a crew-to-crew transfer
wearing a disguise and has to cost the same, but the same code path also banks coins, vendor change
and mining payouts that were never anyone else's. It is a separate define so that case can be priced
on its own without reopening the hole. The two rates are equal today.

The fee is shown to the player wherever it is taken: the ID card says what it withheld, and the holopay
tells the owner the fee rather than reporting the gross it no longer receives. A levy nobody can see
reads as a bug.

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
overwrites outright and is the way around that. Administrative adjustment is exempt from the levy, as
an admin typing a figure means that figure to arrive. Every mutation is logged to `log_admin` and
`message_admins`.

The panel is also where persistence is switched on and off. The header states what the round in
progress is running under, and the button states and sets what the next one will run under, since
those are different questions and conflating them is how an admin concludes the switch is broken. The
button is disabled outright when the config flag is off, with the reason shown, rather than silently
doing nothing.

**Clear Ledger** erases every record in whichever ledger the stored view is pointed at. The per-record
delete beside each row is for one account that has gone wrong; this is for a ledger that has, or for a
test server that wants to start from nothing. It detaches any account still bound to the ledger, which
is what makes the wipe hold: a bound account writes itself back on its next transaction, so emptying
the file alone would undo itself one account at a time and look exactly like the wipe failing silently.
Detached accounts keep the credits they are holding, because erasing what carries over and confiscating
a balance mid-shift are separate decisions and only one of them was asked for. It also drops the
cross-ledger scan, which would otherwise go on listing records that no longer exist.

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

- `code/modules/economy/account.dm`: `/datum/bank_account/proc/adjust_money`. Gains a `levy_fraction`
  argument defaulting to `TRANSACTION_LEVY_FRACTION`, charges the levy on incoming credits, and calls
  `flush_to_ledger()`. This is where both halves of the module hang off the same chokepoint.
- `code/modules/economy/account.dm`: `/datum/bank_account/department/adjust_money`. Signature kept in
  step with its parent. Departments are exempt regardless, so this is only to stop the override
  silently dropping the argument if that exemption ever moves.
- `code/modules/economy/account.dm`: `/datum/bank_account/Destroy`. Added `flush_to_ledger()` and
  `detach_ledger()`, so a destroyed account writes its last state and stops the ledger holding a ref
  to it.
- `code/modules/economy/account.dm`: `/datum/bank_account/proc/payday`. Two added lines returning
  early on a suspended account, and `LEVY_EXEMPT` on the `free` grant.
- `code/modules/economy/account.dm`: `/datum/bank_account/proc/transfer_money`. Passes `LEVY_EXEMPT`
  when the sender is a departmental account, which is what keeps payday from being docked.
- `code/modules/economy/account.dm`: `/datum/bank_account/proc/add_log_to_history`. The literal `20`
  became `LEDGER_HISTORY_LENGTH`. The two were equal by coincidence, and a record restored into a
  differently sized buffer than the one it was written from would have failed quietly.
- `code/modules/economy/holopay.dm`: `/obj/structure/holopay/proc/alert_buyer`. Takes a levy fraction
  rather than a precomputed levy, and tells the owner what the fee was instead of announcing a gross
  figure it no longer receives. The holochip branch of `item_interact` passes the deposit rate.
- `code/game/objects/items/cards_ids.dm`: `/obj/item/card/id/proc/insert_money` and
  `/obj/item/card/id/proc/mass_insert_money`. Bank at `DEPOSIT_LEVY_FRACTION`, and `insert_money`
  reports the fee. Withdraw, hand over the holochip, deposit was otherwise a transfer with no levy.
- `code/modules/modular_computers/file_system/programs/betting.dm`: the five refund paths in
  `/datum/active_bet`. All `LEVY_EXEMPT`. Winnings are levied, since a pot is other players' money.
- `code/datums/quirks/negative_quirks/indebted.dm`: `/datum/quirk/indebted/add_unique`. A character
  that still owes keeps what it owes rather than being handed more; one that has cleared its debt
  rolls a fresh one. `add_unique` runs every time a character spawns, so with balances carrying over
  the quirk rolled a fresh `PAYCHECK_CREW * rand(275, 325)` every round on top of whatever was left,
  far faster than debt collection retires it, and the debt became unpayable. Skipping the roll outright
  for a returning character fixed that but left a cleared character holding a `-2` quirk with no
  downside at all, which is a free positive quirk. Re-rolling on a cleared debt keeps it costing
  something. The achievement is per-player and is not awarded twice.
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
  `TRANSACTION_LEVY_FRACTION`, `DEPOSIT_LEVY_FRACTION`, `LEVY_EXEMPT`, and the `LEDGER_FIELD_*` record
  keys. Used across more than one file, so they live here rather than in the module. The record keys
  moved here from `economy_ledger.dm` once `economy_snapshot.dm` needed to read records straight off
  disk, and the levy defines are reachable from any core file that credits an account.
- `modular_aphelion/modules/persistent_economy/code/department_budgets.dm`: `STATION_LEDGER_PATH`,
  `DEPARTMENT_KEY_PREFIX`, `DEPARTMENT_GRANT_CEILING_MULT`, `DEPARTMENT_UPKEEP_FRACTION`,
  `DEPARTMENT_SUBSIDY_FRACTION`. All `#undef`'d in the same file.
- `modular_aphelion/modules/persistent_economy/code/economy_snapshot.dm`: `PLAYER_SAVES_PATH`,
  `PLAYER_LEDGER_FILENAME`. Both `#undef`'d in the same file.
- `modular_aphelion/modules/persistent_economy/code/economy_settings.dm`: `ECONOMY_SETTINGS_PATH`,
  `SETTING_KEY_ENABLED`. Both `#undef`'d in the same file.
- `modular_aphelion/modules/persistent_economy/code/character_accounts.dm`: `CHARACTER_KEY_PREFIX`.
  `#undef`'d in the same file.
- `modular_aphelion/modules/persistent_economy/code/economy_admin_panel.dm`: `ADMIN_BALANCE_LIMIT`.
  `#undef`'d in the same file.
- `code/modules/unit_tests/~aphelion/persistent_economy.dm`: `TEST_LEDGER_PATH`. `#undef`'d in the
  same file.

### Config:

- `PERSISTENT_ECONOMY`, a flag, on by default. The host's outer switch. Off, the module does nothing,
  the stock upstream economy is left behind, and no admin can turn any of it back on from the panel.
  It is not the switch that decides whether the feature runs: that is the stored setting behind the
  Economy Panel, which is off until thrown and lives in `data/persistent_economy_settings.json` rather
  than in config, so it survives a reboot without anyone editing files on the host.

### Included files that are not contained in this module:

- `tgui/packages/tgui/interfaces/EconomyAdminPanel.tsx`. The Economy Panel interface. New TGUI files
  cannot live inside a module folder, as the bundler only reads `tgui/packages/tgui/interfaces/`.
- `code/modules/unit_tests/~aphelion/persistent_economy.dm`. The ledger and levy tests. Unit tests
  cannot live inside a module folder, as they are gathered from `code/modules/unit_tests/`.
- `code/__DEFINES/~aphelion_defines/persistent_economy.dm`. The defines shared across the module's
  files.

### Credits:

- pepe
