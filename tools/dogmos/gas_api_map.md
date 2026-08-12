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

## Open questions to resolve while writing the wrappers

- Does Dogmos `adjust_moles` quantize the way `QUANTIZE()` does? If not, small transfers will drift
  relative to today's behaviour.
- `set_temperature` clamping to 2.7 and rejecting non-finite values is stricter than DM. Find call
  sites that currently set below `TCMB` or rely on the lack of validation.
- `/datum/gas_mixture/turf` subtype: confirm the `HEAT_CAPACITY_VACUUM` floor survives, since turf
  mixes go through Rust.
