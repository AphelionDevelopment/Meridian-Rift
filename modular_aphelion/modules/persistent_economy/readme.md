https://github.com/AphelionDevelopment/Meridian-Rift/pull/

## Persistent Economy

Module ID: PERSISTENT_ECONOMY

### Description:

An economy whose balances outlive the round. Department budgets and player accounts both carry over.
Persistence hangs off `/datum/bank_account` itself rather than a savings account beside it, so
carried credits are ordinary credits: every vendor, holopay, paystand and transfer spends them with
no per-surface code.

`/datum/economy_ledger` is a keyed store of account state backed by a `/datum/json_database`, so
writes get its `.savebac` backup and recovery path. One ledger owns one file. Accounts sharing a file
are separated by a namespaced key: `dept:<department_id>`, `char:<slot_index>`, and whatever later
systems need. A database rewrites its whole file on save, so only a bounded set of accounts (the
department budgets) should share one. Per-player state belongs in a per-player file. Get ledgers
through `get_economy_ledger()`, never `new`.

Two procs on `/datum/bank_account` drive it. `attach_ledger()` binds an account to a ledger and adopts
any stored balance and debt, returning whether a record already existed. That return tells a returning
account from a first-time one, which decides whether roundstart grants are paid. `flush_to_ledger()`
writes the account back, called from `adjust_money()`, the single proc every balance change passes
through.

Ledgers live for the whole round. Accounts hold a hard ref to theirs, so destroying one mid-round
while an account still points at it would hard delete the ledger.

Department budgets share `data/persistent_economy.json`. At roundstart a department carries over last
round's balance and is topped up to its budget floor only if it ended below it, never past. Banking a
surplus is worth something, and a bankrupted department is still playable next shift. Cargo's floor is
zero, so it keeps what it earns and is never subsidised. Budgets are not scoped by map: a department's
money follows the crew across a rotation rather than belonging to the station they stood on.

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

Two faucets were bounded only by the round ending, so both have a counterweight now:

- Departments stop drawing `MAX_GRANT_DPT` at three times their budget floor. This bounds the free
  grant only. A department that earns its money, as cargo does, is not capped.
- Departments and returning characters pay a fraction of their carried balance at roundstart, as
  operating costs and cost of living. A proportional charge never bankrupts a poor account and bounds
  a rich one: balances settle where a shift's earnings meet the charge. Both fractions are 5%, tuned
  independently in their own files.

For departments the charge is applied before the floor top-up, so one below its floor still lands on
it.

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

Two policy calls, both deliberate and both no-ops in code. A balance survives its character's death,
since the record is keyed to the character and not the body. Theft is uncapped: draining a stolen ID
moves money between accounts rather than destroying it, so it stays in the economy. Stealing into an
account with no ledger, such as an antag's forged ID, does destroy it at round end. That is a small
unplanned sink.

### TG Proc/File Changes:

- `code/modules/economy/account.dm`: `/datum/bank_account/proc/adjust_money`. One added call to
  `flush_to_ledger()`. It cannot be a modular override, as there is no subtype seam to hook and DM
  will not take a second definition of the proc on the same type.
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

- `modular_aphelion/modules/persistent_economy/code/economy_ledger.dm`: `LEDGER_FIELD_BALANCE`,
  `LEDGER_FIELD_DEBT`, `LEDGER_FIELD_HOLDER`, `LEDGER_FIELD_UPDATED`. All `#undef`'d in the same file.
- `modular_aphelion/modules/persistent_economy/code/department_budgets.dm`: `STATION_LEDGER_PATH`,
  `DEPARTMENT_KEY_PREFIX`, `DEPARTMENT_GRANT_CEILING_MULT`, `DEPARTMENT_UPKEEP_FRACTION`. All
  `#undef`'d in the same file.
- `modular_aphelion/modules/persistent_economy/code/character_accounts.dm`: `CHARACTER_KEY_PREFIX`,
  `CHARACTER_UPKEEP_FRACTION`. Both `#undef`'d in the same file.
- `modular_aphelion/modules/persistent_economy/code/economy_admin_panel.dm`: `ADMIN_BALANCE_LIMIT`.
  `#undef`'d in the same file.

### Included files that are not contained in this module:

- `tgui/packages/tgui/interfaces/EconomyAdminPanel.tsx`. The Economy Panel interface. New TGUI files
  cannot live inside a module folder, as the bundler only reads `tgui/packages/tgui/interfaces/`.

### Credits:

- pepe
