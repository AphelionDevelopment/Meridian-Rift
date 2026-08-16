This module is maintained as part of the Dogmos integration branch.

## Dogmos gas registration subsystem

Module ID: DOGMOS

### Description:

`SUBSYSTEM_DEF(dogmos)` hands the Dogmos (Rust) atmospherics library its gas registry and reaction
table at `INITSTAGE_EARLY`, before any turf builds its air. It cannot live in SSair - see the doc
comment on the subsystem for why. Also carries `runtimes_at_init_complete`, a snapshot used by
`/datum/unit_test/no_runtimes_during_init` to assert a clean boot.

The rest of the Dogmos/atmos-FFI integration lives in `code/` proper (declared fork-owned in
`tools/dogmos/`, not modularized - see the plan doc referenced in `project-dogmos-integration` memory
for why the atmos tree itself is a boundary declaration rather than per-file modularization). This
subsystem, its Dogmos configuration vars, and the runtime-tracking global are the pieces with no
atmos-tree dependency and no `.dme` include-order constraint, so they moved here.

### TG Proc/File Changes:

- N/A

### Modular Overrides:

- `modular_aphelion/modules/dogmos/code/dogmos.dm`: `SUBSYSTEM_DEF(dogmos)` (new subsystem, not an
  override of anything TG), `GLOBAL_VAR_INIT(runtimes_at_init_complete)`, and the SSair temperature,
  Equalize-profile, and superconductivity telemetry vars.
- `modular_aphelion/master_files/code/game/turfs/turf.dm`: `/turf/var/initial_temperature`,
  `/turf/var/conductivity_blocked_directions`, `/turf/Initalize_Atmos()`, `/turf/proc/register_dogmos_air()`,
  `/turf/proc/set_temperature()`.
- `modular_aphelion/master_files/code/game/turfs/open/_open.dm`: `/turf/open/Initalize_Atmos()` (chains
  to the base override above via `..()`, since core's `/turf/open/Initalize_Atmos()` does not call
  `..()` itself and this needed to run before it).
- `modular_aphelion/master_files/code/game/turfs/open/space/space.dm`: `/turf/open/space/register_dogmos_air()`,
  `/turf/open/space/sync_dogmos_adjacency()` - space turfs skip Initalize_Atmos() entirely (see
  space_EXPENSIVE.dm), so the base register_dogmos_air()'s init_air gate meant no space turf ever
  registered into Dogmos, which meant gas never diffused into space and katmos breach detection never
  had a neighbor to find. These overrides register one specific space turf on demand, the moment
  either side's adjacency plumbing actually touches it (DOGMOS_SIMULATION_SPACE_BOUNDARY, see
  dogmos_defines.dm and hook_register_turf in aphelion-dogmos/src/turfs.rs).

### Defines:

- `code/__DEFINES/dogmos_defines.dm`: hand-maintained FFI constants plus the blocked-turf temperature
  authority and Equalize performance-profile values. This remains a core include because generated
  bindings and core atmos files consume it before modular files are loaded.

### Included files that are not contained in this module:

- `code/__DEFINES/dogmos_bindings.dm`, `code/__DEFINES/dogmos_defines.dm`: must stay in core - both
  are included before `modular_aphelion` in `tgstation.dme`, and core atmos files consume their macros.

### Credits:

- Ported from `code/controllers/subsystem/dogmos.dm` as part of the Phase 3 `AGENTS.md` compliance
  pass. Original authorship: the Dogmos integration work.
