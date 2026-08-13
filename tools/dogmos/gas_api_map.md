# Gas mixture API map: DM today -> Dogmos

Working document for Phase 2. The call-site sweep is ~500 sites; a wrong mapping does not fail to
compile, it produces slightly-wrong physics. Work from this table, not from memory.

## Strategy: wrap, don't swap

The naive plan was to delete the DM procs and let `bindings.dm` supply the names. Two problems kill it:

1. **12 names collide** with procs `gas_mixture.dm` defines, so the generated file cannot even be
   included alongside them.
2. **Several DM procs have side effects or shapes that Rust does not reproduce** - most importantly
   `merge()`, `remove()`, `remove_ratio()` and `react()` send `COMSIG_GASMIX_MERGED`,
   `COMSIG_GASMIX_REMOVED` and `COMSIG_GASMIX_REACTED`. Gas tanks (`tanks.dm:124-128`) and
   `/datum/component/atmos_reaction_recorder` listen to those. Move the proc to Rust naively and TTV
   assembly and reaction recording break with no error.

Because we own the fork, the better move is to **rename the colliding binds in Rust** to `__`-prefixed
names, then hand-write thin DM procs carrying the tg-facing name, argument shape, return value and
signal. The DM wrapper is a few lines; the Rust does the work; call sites mostly do not change at all.

That converts a 500-site semantic rewrite into a much smaller set of wrapper definitions plus a
genuinely mechanical sweep of the field accesses (`.moles[...]`, `.temperature`).

## The 12 collisions

| DM proc | Dogmos bind | Plan |
|---|---|---|
| `merge(giver)` returns TRUE/FALSE, sends `COMSIG_GASMIX_MERGED` | `merge(giver)` | rename bind to `__merge`; DM wrapper sends signal, returns bool |
| `remove(amount)` returns a **new** mixture or null, sends `COMSIG_GASMIX_REMOVED` | `__remove(into, amount)` writes into a supplied mixture | DM wrapper creates the mixture, calls `__remove`, sends signal, returns it |
| `remove_ratio(ratio)` returns a **new** mixture, empty (not null) when `ratio <= 0` | `__remove_ratio(into, ratio)` | as above; preserve the empty-not-null edge case |
| `react(holder)` returns tg bitflags, sends `COMSIG_GASMIX_REACTED` | `react(holder)` drives reactions from Rust | rename bind to `__react`; DM wrapper sends signal, returns flags |
| `compare(sample, cmp_archive)` | `compare(other)` - no archive arg | archives are gone in Phase 2; drop the argument at call sites, verify each |
| `temperature_share(sharer, coeff, sharer_temp, sharer_cap)` | variadic 3-or-4 arg | direct, but confirm arity at each call site |
| `heat_capacity()` | `heat_capacity()` | direct. Note `/datum/gas_mixture/turf` overrides it to floor at `HEAT_CAPACITY_VACUUM` - preserve |
| `total_moles()` | `total_moles()` | direct |
| `return_pressure()` | `return_pressure()` | direct |
| `return_temperature()` | `return_temperature()` | direct |
| `return_volume()` | `return_volume()` | direct |
| `thermal_energy()` | `thermal_energy()` | direct |
| `set_temperature(target)` | `set_temperature(temp)` | direct, but Dogmos clamps to >= 2.7 and errors on NaN/infinite - DM did neither |

## Renames (no collision, call sites change)

| DM proc | Dogmos bind | Note |
|---|---|---|
| `set_gas(specie, amount)` | `set_moles(id, amt)` | DM version also `garbage_collect()`s; Dogmos manages sparsity itself |
| `adjust_gas(gas, amount)` | `adjust_moles(id, amt)` | DM `QUANTIZE`s the amount - check Dogmos does something equivalent |
| `adjust_multiple_gases(list)` | `adjust_multi(id, amt, ...)` | assoc list becomes variadic pairs |
| `remove_specific(id, amount)` | `__remove_by_flag` / `scrub_into` | no direct equivalent; likely a DM wrapper over `adjust_moles` |
| `remove_specific_ratio(id, ratio)` | as above | same |
| `convert_gas(reactant, product, amt)` | none | keep in DM on top of `adjust_multi` |

## Deleted outright

`assert_gas`, `assert_gases`, `add_gas`, `add_gases`, `garbage_collect`, `archive`,
`heat_capacity_archive`, `share`, `equalize`, `copy`, `copy_from_ratio` - Dogmos manages sparsity and
archival internally, and `share`/`equalize` are subsumed by turf processing and `equalize_with`.

## Kept in DM, reimplemented on the new primitives

`pump_gas_to`, `release_gas_to`, `gas_pressure_calculate`, `gas_pressure_minimum_transfer`,
`gas_pressure_quadratic`, `gas_pressure_approximate`, `get_breath_partial_pressure`, `to_string`,
`check_gases`, `electrolyze`, `has_gas`, `return_visuals`. These are composed of `get_moles`,
`get_gases`, `total_moles` and arithmetic - no Rust needed.

## DM-side behaviour the wrappers must preserve

Beyond the signals, `react()` carries logic Rust knows nothing about:

- **Hypernoblium oppression.** `gas_mixture.dm`'s `react()` returns `STOP_REACTIONS` outright when
  hypernoblium is at or above `REACTION_OPPRESSION_THRESHOLD` and the mix is hotter than
  `REACTION_OPPRESSION_MIN_TEMP`, before any reaction runs. Dogmos has no equivalent, so a wrapper must
  apply this check *before* delegating, or hypernob stops suppressing reactions entirely.
- **Reaction results bookkeeping.** `reaction_results` is rebuilt per react() call and read by the
  atmos reaction recorder and TTV analysis.
- **Empty-mix short circuit.** `react()` returns early when the mix has no gases.

## Shape asymmetries that look like tidying opportunities but are not

- **`remove()` returns null, `remove_ratio()` returns an empty mixture.** For `amount <= 0`,
  `remove()` returns `null`; for `ratio <= 0`, `remove_ratio()` returns a *new empty mixture*. Callers
  differ accordingly, some null-checking and some not. Making them consistent during the rewrite would
  silently change behaviour at every call site that relied on one or the other.
- **`remove()` clamps to available moles** rather than allowing a negative result.
- **`/datum/gas_mixture/turf/heat_capacity()` floors at `HEAT_CAPACITY_VACUUM`**; the base type returns
  the raw value. Turf mixes go through Rust in Phase 3, so this floor has to survive somewhere.

## Disposition of every proc in gas_mixture.dm

Derived from a full read of the file at `1808f41`. Line numbers are from that revision.

**Renamed in Rust, DM keeps a wrapper** (done in the fork at `afc728f`):
- `merge(giver)` → calls `__merge`, sends `COMSIG_GASMIX_MERGED`, returns TRUE/FALSE, returns FALSE on
  null giver.
- `react(holder)` → the hypernoblium gate and `reaction_results` stay in DM; delegate the reaction loop
  to `__react`, send `COMSIG_GASMIX_REACTED` when anything changed. **Note `react()` currently filters
  reactions in DM using `reaction.requirements` (L534-543); Dogmos does that gating itself from
  `min_requirements`, so the DM loop goes away — but the return value must stay a bitflag union.**

**Delete; the Dogmos bind takes the name directly** — no wrapper, no call-site change:
`heat_capacity`, `total_moles`, `return_pressure`, `return_temperature`, `return_volume`,
`thermal_energy`, `set_temperature`, `copy_from`, `compare`, `temperature_share`.
- `compare` loses its `cmp_archive` argument; archives are gone, so drop it at call sites. **Return
  type also differs** — DM's `compare()` returns a string (a gas id, `"temp"`, or `""`); Dogmos'
  returns a boolean. Checked all 3 real call sites (`LINDA_turf_tile.dm:308,336`, `air.dm:574`) — all
  three only test truthiness in an `if()`, never read the string. Confirmed safe as a direct swap.
- `set_temperature` becomes stricter: Dogmos clamps to >= 2.7 and rejects non-finite. Check for call
  sites that currently set below `TCMB`.
- `/datum/gas_mixture/turf/heat_capacity()` must **stay** as a DM override calling `..() ||
  HEAT_CAPACITY_VACUUM`, since only the turf subtype floors at vacuum.

**Delete outright, no replacement needed:**
`assert_gas`, `assert_gases`, `add_gas`, `add_gases`, `garbage_collect`, `archive`,
`heat_capacity_archive`, `/datum/gas_mixture/turf/heat_capacity_archive`.

**Rename at call sites:**
`set_gas` → `set_moles`, `adjust_gas` → `adjust_moles`, `adjust_multiple_gases` → `adjust_multi`
(assoc list becomes variadic pairs).

**Reimplement in DM on the new primitives:**
- `remove(amount)` / `remove_ratio(ratio)` — allocate the destination, call `__remove`/`__remove_ratio`,
  send `COMSIG_GASMIX_REMOVED`, preserve the null-vs-empty asymmetry above.
- `remove_specific(gas_id, amount)` / `remove_specific_ratio` (L249-278) — no Dogmos equivalent; build
  on `get_moles`/`adjust_moles` into a fresh mixture.
- `copy()` (L311) — returns a **new** mixture; `copy_from` only fills an existing one.
- `copy_from_ratio` (L345) — `copy_from` then `multiply(partial)`.
- `convert_gas` (L194) — `adjust_multi` with a negative and a positive term.
- `equalize(other)` (L282) — pure DM arithmetic today; rewrite on `get_gases`/`set_moles`. Distinct from
  Dogmos' `equalize_with`, which is volume-scaled copy, **not** the same operation.
- `share(sharer, our_coeff, sharer_coeff)` (L359) — depends on archived values that no longer exist, so
  it must be rewritten, **not deleted**. Verified callers reach well beyond LINDA:
  `closets.dm`, `morgue.dm`, `transit_tubes/station.dm`, `unary_devices/passive_vent.dm` and
  `modular_nova/modules/liquids/code/liquid_systems/liquid_controller.dm`. Those survive Phase 3, so
  `share` needs a real implementation on Dogmos primitives — the archived-value consistency it provides
  is exactly what Dogmos does internally for turfs, but these callers are not turfs.

**Keep unchanged except `temperature` → `return_temperature()`:**
`has_gas`, `return_visuals`, `get_breath_partial_pressure` (L565),
`gas_pressure_minimum_transfer` (L575), `gas_pressure_calculate` (L586, reads `temperature` at
L592/596/606/616/617/668), `gas_pressure_quadratic`, `gas_pressure_approximate`, `pump_gas_to` (L700),
`release_gas_to` (L729), `electrolyze`, `to_string` (L765, iterates `moles`), `check_gases` (L796,
iterates `moles`).

The last three iterate the `moles` list directly and need `get_gases()` instead.

## Volume: a gap the original mapping missed entirely

`GasArena::register_mix` reads a var named **`initial_volume`**, not `volume`, to seed the Rust-side
mixture (`gas.rs:183`). Rust then tracks its own volume internally, used by `return_pressure()` and
`heat_capacity()`; nothing keeps it synced to DM's `var/volume` automatically, since BYOND has no
setter interception.

Decision: keep `var/volume` as a plain DM field for reads (dozens of legitimate call sites across
`gas_pressure_calculate` and friends — rewriting all of them to `return_volume()` buys nothing, since
volume essentially never changes post-construction). Add `var/initial_volume`, set from `volume` in
`New()` immediately before `__gasmixture_register()`. At the only real reassignment sites
(`datum_pipeline.dm:77,130` — confirmed by grepping for `X.volume =` restricted to gas-mixture-shaped
receiver names; the 394 raw `.volume` hits are almost all `sound`/`reagent`, unrelated), call
`set_volume()` immediately after the DM assignment so Rust's internal volume never goes stale.

**Also found in the same pass, mandatory for `New()` to work at all:** `mark_immutable()` blocks
`merge()` and `copy_from_mutable()` but **not** `remove_into`/`remove_ratio_into` — removing gas from
an immutable mixture (space) would silently deplete it, unlike upstream tg's
`/datum/gas_mixture/immutable/space/remove()` which returns an inexhaustible copy. No `is_immutable()`
bind existed to let DM detect this. Added one to the fork (`afc728f`+); the `remove`/`remove_ratio`
wrappers must check it and short-circuit to a copy for immutable mixtures.

## Sweep methodology (learned during execution)

Regex-based bulk transform works well but has three recurring failure modes, all silent until either
grep or the compiler catches them - check for all three after every transform pass, before compiling:

1. **Trailing `//` comments get pulled inside the new call's parens** when the original line ended in
   a comment after the value (`cached_moles[x] -= y //comment`). Check: `grep '//[^()\n]*\)\s*$'`.
2. **`+=`/`-=` regex anchored to a specific indentation depth misses deeper-nested lines** (inside
   `if`/`else`), which a later generic-read pass then corrupts into `get_moles(x) += y` (assigning to a
   proc call - DM catches this one as a hard error, at least). Prefer unanchored `(\w+)\.moles\[...\]`
   over line-start-anchored patterns for this reason.
3. **`.volume` regex is riskier than `.temperature`/`.moles`.** Volume collides with unrelated
   `.volume` vars far more often - reagent containers, individual reagents, sound objects all have
   their own. A blanket `(\w+)\.volume\b` pass silently corrupted `beaker.volume` and
   `reagent.volume` in cryo.dm into calls to a gas_mixture proc that has nothing to do with either.
   Only apply the volume regex to receivers confirmed `/datum/gas_mixture`-typed, and always diff the
   file's `.volume` sites against the compiler's original error list before trusting a transform -
   if a site wasn't flagged as broken before, it wasn't a gas_mixture access.

4. **Multi-line assignments** (`X.temperature = clamp(\n\ta,\n\tb,\n)`) only have their first line
   matched by a single-line regex, leaving an unbalanced paren the compiler reports far from the real
   site. Check paren balance per-file after every transform (strip strings and comments first, count
   `(` vs `)`) before trusting a "0 errors" result.

## Sweep mechanics

Removing `moles` and `temperature` from the datum makes the DM compiler enumerate most call sites for
you: access through a **typed** `var/datum/gas_mixture/` is a compile error. Untyped access is not, so
the compiler list is a floor, not a ceiling - `rg '\.moles\b|\.temperature\b'` afterwards to catch the
rest.

Work hottest-file-first and compile between files. Run the five golden tests after the wrappers land,
after the datum is gutted, and after the sweep - not only at the end.

## Open questions to resolve while writing the wrappers

- Does Dogmos `adjust_moles` quantize the way `QUANTIZE()` does? If not, small transfers will drift
  relative to today's behaviour.
- `set_temperature` clamping to 2.7 and rejecting non-finite values is stricter than DM. Find call
  sites that currently set below `TCMB` or rely on the lack of validation.
- `/datum/gas_mixture/turf` subtype: confirm the `HEAT_CAPACITY_VACUUM` floor survives, since turf
  mixes go through Rust.
