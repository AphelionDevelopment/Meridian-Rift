# Dogmos tooling

Scripts for building and verifying the Dogmos (Rust auxmos fork) atmospherics integration. Written
across the Phase 2/3 sessions after several tools produced false passes - see the postmortem comments
at the top of each script before changing its exit-code or success-criterion logic.

## The loop

For a **Rust change** (in the sibling `aphelion-dogmos` repo):

```
build_dogmos.ps1 [-AcceptBindings]
```
Builds the DLL, regenerates `code/__DEFINES/dogmos_bindings.dm`, and gates on drift between the
generator's output and the vendored file - never hand-edit that file, it's fully generated. Vendors
the DLL and (unless `-SkipSmoke`) runs a post-build smoke test.

For a **DM change**, in order:

```
test_compile_check.ps1                          # ~2 min: does it compile under CIBUILDING/UNIT_TESTS?
run_tests.ps1 -Focus /datum/unit_test/whatever   # iterate on one test without the full suite
boot_probe.ps1                                   # does it boot clean, with real stderr on a crash?
run_tests.ps1                                    # full suite - required before calling anything done
```

The probes resolve DreamMaker and DreamDaemon from `PATH` by default. If BYOND is not on `PATH`, pass
`-DmPath`/`-DreamDaemonPath` as needed; relative paths are resolved from the invoking shell, and no
developer-specific installation path is embedded in the repository.

`test_compile_check.ps1` exists because a plain `dm.exe tgstation.dme` never even sees files under
`code/modules/unit_tests/` - they're CIBUILDING-only. A syntax error there is otherwise invisible until
`run_tests.ps1`'s own compile step, ~10-12 minutes later once the full DreamDaemon run has already
started.

`run_tests.ps1 -Focus` uses the existing `TEST_FOCUS()` macro
(`code/modules/unit_tests/_unit_tests.dm`) to restrict a run to specific tests, instead of the ~495-test
suite, for fast iteration. **A `-Focus` run is not verification** - it only proves the focused test(s)
behave, not that nothing else regressed. Always finish with a full run.

`show_failure.ps1 -TestPath /datum/unit_test/whatever` prints one test's current status/message/runtimes
from `data\unit_tests.json` - a shortcut for reading the JSON directly, nothing more.

## Meridian MCP integration

`meridian-mcp-launch.cmd` is the project-owned stdio bridge for the maintained Meridian MCP checkout.
Configure the MCP client to invoke `cmd.exe /d /c` with this launcher and provide
`MERIDIAN_MCP_REPO` in the client's environment. `DM_MCP_REPO` remains accepted as a migration alias
when the canonical variable is absent. The launcher resolves `target/release/meridian-mcp.exe` from
that checkout and forwards the MCP streams without writing diagnostic text to stdout. This keeps the
local checkout path in client-local configuration instead of tracked repository files and works
around clients that cannot spawn a release binary directly from a user-local directory.

Use Meridian MCP for DreamMaker source navigation, type/proc inspection, source-backed definitions,
map queries, compiler diagnostics, and live DreamDaemon output. The `dm_*` tool names remain stable
for compatibility with existing clients and workflows. Keep the deterministic PowerShell and Rust
harnesses as the authoritative verification path; Meridian MCP is an investigation and diagnosis
layer, not a replacement for those gates.

## The baseline files

- **`test_baseline.json`** - message-level, not just test-name-level: `{ "test_path": "failure message" }`.
  A test already failing for reason A must not silently absorb a new failure for reason B (see
  `/datum/unit_test/create_and_destroy`, which asserts hard-delete counts - the Phase 2 `Del()`
  milestone gate). Comparison normalizes out timestamps/refs/counts (`_common.ps1`'s
  `Get-NormalizedTestMessage`) so noise like a differing mob ref or del-count doesn't read as a new
  failure. Update with `-UpdateBaseline` **only** after confirming a failure is genuinely known/accepted
  - never as a way to make a run go green without reading what changed.
- **`runtime_baseline_boot.json`** / **`runtime_baseline_suite.json`** - runtime-error signatures, split
  by consumer: `_boot` is `boot_probe.ps1`'s clean-boot check specifically (expected empty or
  near-empty - a full test suite legitimately logs runtimes several baselined tests are *supposed* to
  produce, e.g. `door_access_check`/`mob_faction`); `_suite` is `run_tests.ps1`'s own runtime-signature
  diffing over the whole suite. These used to be one shared file - updating it from a full-suite run
  would silently absorb dozens of suite-only signatures into the boot-clean baseline, permanently
  blinding that check. Never edit one script to point at the other's file.
- **`test_runtime_signature_baseline.json`** - per-test runtime-error *counts* (`run_tests.ps1`'s
  `-UpdateTestRuntimeBaseline`), distinct from the two files above: those track runtime error
  *messages*, this tracks *which tests* are expected to log any, and how many. A test that starts
  logging runtimes it never used to - even if it still "passes" - is a real regression signal that used
  to be printed and silently discarded.
- **`test_timing_baseline.json`** - per-test duration (`run_tests.ps1`'s `-UpdateTimingBaseline`).
  Trend detection, not a hard gate - only flags a test running at least 5x its baselined duration and
  at least 2s slower in absolute terms, so ordinary CI noise doesn't trip it. This is what makes the
  steady-state cost question the SSAIR_EXCITEDGROUPS/SUPERCONDUCTIVITY stages both parked on a manual
  round into something this script can actually catch automatically.

## Known accepted noise

- `Generated map previews were different than what is currently saved` - a pre-existing,
  out-of-scope `icons/obj/fluff/map_previews.dmi` regeneration flake. Not a Dogmos issue; do not "fix"
  it as part of this work.
- The 8 pre-existing baselined failures (`door_access_check`, `mafia`, `mob_faction`,
  `revolution_conversion`, `shuttle_call_times`, `fish_portal_gen_linking`, `job_display_order`,
  `create_and_destroy`) predate any Dogmos work and are unrelated to atmos - confirmed by reading their
  actual failure messages, not just their names.

## The `__`-prefix FFI convention

Raw Dogmos binds that collide with a tg-facing proc name, or that need a DM-side wrapper for a
different reason (space-turf guards, signal sends, argument shape), are `__`-prefixed in the Rust
`#[byondapi::bind(...)]` attribute - e.g. `__set_temperature`, `__get_gases`, `__remove`. The clean
tg-facing name is a separate DM proc that wraps the raw bind:

- Gas-level wrappers live in `code/modules/atmospherics/gasmixtures/gas_mixture.dm`.
- Turf-level wrappers live in `modular_aphelion/master_files/code/game/turfs/turf.dm` (see
  `register_dogmos_air()`, `set_temperature()`).

When adding a new bind that needs a wrapper, follow this pattern rather than inventing another one.

## Modularization boundary (2026-08-14)

The atmos tree (`code/modules/atmospherics/`, `code/__DEFINES/atmospherics/`, the turf files Dogmos
touches) is declared fork-owned rather than marked file-by-file with `APHELION EDIT` comments - ~90% of
its diff against master is forced by the deleted `gas_mixture` API and has no modular expression that
isn't worse than the core edit (AGENTS.md §1's "do not copy a core proc to change one line" rule). Files
**outside** the atmos tree that get touched for Dogmos reasons (e.g. `holo_effect.dm`,
`fix_air.dm` for the temperature setter) get real markers and, where the change is genuinely
self-contained, get modularized into `modular_aphelion/` - see the "AGENTS.md compliance" commit and
the Phase 3 plan doc's "Modularization assessment" section for the full reasoning and what's still
deferred (a marker pass over the ~125 forced-by-API-change files, deferred until Phase 3's remaining
fire()-stage cutovers stop churning that tree).

## Files in this directory

| File | Purpose |
|---|---|
| `build_dogmos.ps1` | Build the Rust DLL, regenerate bindings, gate on drift |
| `boot_probe.ps1` | Boot DreamDaemon directly, report real completion/crash signal |
| `run_tests.ps1` | Full (or `-Focus`ed) unit test suite, diffed against baseline |
| `test_compile_check.ps1` | Fast CIBUILDING/UNIT_TESTS syntax check, no DreamDaemon |
| `show_failure.ps1` | Print one test's current result from `data\unit_tests.json` |
| `_common.ps1` | Shared helpers: safe log reads, runtime signature normalization, baseline diffing |
| `test_baseline.json`, `runtime_baseline_boot.json`, `runtime_baseline_suite.json`, `test_runtime_signature_baseline.json`, `test_timing_baseline.json` | The baselines described above |
| `gas_api_map.md` | Phase 2's proc-by-proc DM↔Dogmos gas API mapping table |
| `setup_rust_toolchain.ps1` | One-time machine setup for building the Rust fork |
