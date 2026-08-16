# Dogmos/Auxmos branch code review

Date: 2026-08-16  
Branch: `dogmos`  
Branch tip reviewed: `107f8bf4ef2` (`its play testable now`)  
Review base: merge-base `2394b657ffb9276` with `master`

## Scope and method

The branch diff contains 617 files, 13,624 added lines, and 10,188 removed lines from the merge
base. That includes the wholesale Dogmos gas-mixture API migration, the Phase 3 Rust/DM cutovers,
Kennel work, Nova content that was mechanically adapted to the new API, generated bindings, and the
Dogmos harness.

The review covered the complete branch inventory and commit sequence, then performed a deeper review
of the integration-critical surfaces: Rust gas and turf arenas, FFI bindings, registration and
adjacency lifecycle, the SSair fire stages, direct temperature consumers, Dogmos unit tests, and the
PowerShell verification loop. The large mechanical API migration was checked through its wrappers,
call-site searches, golden tests, and compile/test evidence rather than re-reading every unrelated
Nova content file as new design work.

The current uncommitted `change_turf.dm` guard and harness changes were reviewed separately from the
committed branch history. No implementation changes were made in response to the findings below;
they are dispositions for the next review gate.

## Executive assessment

The integration is substantially real and coherent: Dogmos owns gas storage and the cutover stages,
the DM side has explicit wrappers for the changed ABI, registration and adjacency paths are documented,
and the test harness now catches several classes of false pass. The false turf-registration leak
theory was correctly reverted, and the Thunderdome and map-loader fixes are based on observed call
chains rather than assumptions.

It is not yet ready for an unconditional Phase 5 cutover sign-off. Two correctness risks need an
explicit decision and preferably deterministic tests first:

1. Rust heat processing updates a live Rust temperature that several DM consumers do not read.
2. The heat-edge pass uses non-blocking two-sided locks in a parallel loop, so a valid heat exchange
   can be skipped depending on task scheduling.

The remaining issues are mostly observability, lifecycle hardening, and acceptance-test gaps. They do
not invalidate the work already landed, but they make a clean-looking round insufficient as the sole
cutover criterion.

## Findings

### P1 — Two temperature authorities remain in gameplay code

Evidence:

- `aphelion-dogmos/src/turfs/superconduct.rs:507-535` writes `ThermalInfo.temperature` during
  Rust heat processing.
- `modular_aphelion/master_files/code/game/turfs/turf.dm:51-55` updates the DM-side
  `/turf/temperature` only when an explicit `set_temperature()` call succeeds.
- Several consumers still read the DM var directly: `code/modules/atmospherics/machinery/pipes/heat_exchange/he_pipes.dm:35-41`,
  `code/modules/atmospherics/environmental/LINDA_turf_tile.dm:87-88`,
  `code/modules/reagents/chemistry/reagents/other_reagents.dm:154`,
  `code/modules/mob/living/living.dm:1427-1429`, and
  `code/controllers/subsystem/minor_mapping.dm:60`.

This is material for blocked/non-gas-adjacent turfs, which are precisely where Dogmos heat
conduction is relevant. `return_temperature()` reads the Rust heat graph, while the direct reads
above can retain the construction/reset value after Rust has conducted heat. The result can be a
heat-exchanger threshold, reagent cooling amount, creature temperature check, or placement decision
based on a different temperature than the one used by Dogmos physics.

Recommended disposition: treat this as a cutover blocker. Audit every direct turf-temperature read,
separating construction/default comparisons from live gameplay reads, route live reads through the
appropriate virtual getter, and add a regression test where a blocked turf changes through a Rust
heat cycle and a DM consumer observes that change. Also decide whether `set_temperature()` should
preserve the old DM-side write behavior when `DOGMOS` is unavailable; its current early return makes
all converted writes no-ops in that fallback configuration.

### P1 — Heat-edge conduction can be lost to lock contention

Evidence: `aphelion-dogmos/src/turfs/superconduct.rs:507-535` processes every candidate node in a
Rayon `par_iter`. Each task holds the current turf's write lock and then calls `try_write()` on each
neighbor. The neighbor is itself a candidate task and can simultaneously hold its own lock while
trying to acquire the first task's lock. If both attempts overlap, neither side updates the edge and
the failure is silently discarded.

This is not a Rust data race, but it is a nondeterministic physics result. A larger connected graph
is more likely to contain overlapping opposing attempts, and the current golden test only proves that
one bounded retry eventually observes a temperature change; it does not prove that every eligible edge
is processed or that energy exchange is deterministic.

Recommended disposition: reproduce with a deterministic two-node and small-grid stress test, then
choose an ownership or two-phase-delta algorithm that visits each undirected edge once. If the current
best-effort behavior is intentionally retained, expose a drop/skip counter and document the accepted
accuracy bound; do not describe the stage as a complete graph sweep without that qualification.

### P2 — Main-thread callbacks are silently dropped under queue pressure

The Rust stages use `byond_callback_sender().try_send(...)` in multiple correctness paths, including
reaction/visual updates (`src/turfs/processing.rs:403-431`), pressure/decompression work
(`src/turfs/katmos.rs:575-592`, `src/turfs/katmos.rs:734-742`), melting side effects and cost telemetry
(`src/turfs/superconduct.rs:490-501`, `src/turfs/superconduct.rs:539-556`), and other atmosphere
workers. The return value is generally discarded. The heat notification itself is also a bounded,
non-blocking send (`src/turfs/superconduct.rs:285-303`).

Dropping a heat notification is a defensible self-correcting optimization because the next SSair
cycle sends another one. Dropping a reaction, visual update, pressure callback, decompression action,
or `to_be_destroyed` write is not automatically equivalent: some are observable state changes rather
than merely another sample of a continuous solver.

Recommended disposition: classify callbacks into safe-to-coalesce and must-deliver; add counters or
diagnostics for failed sends; and either retry/coalesce must-deliver work or document the exact
eventual-consistency guarantee. Add a stress test that fills the callback queue and verifies the
chosen behavior.

### P2 — Registration invariants are enforced by process-wide panics more often than by recoverable boundaries

The FFI arena code intentionally treats missing graph and mixture entries as invariant violations,
but the surface is broad: `aphelion-dogmos/src/turfs.rs:110-197`, `221-245`, and
`aphelion-dogmos/src/turfs/superconduct.rs:38-45`, `90`, `221`, `254`, and `378-467` contain
`unwrap()` or panic paths around turf and gas IDs. The newly fixed `if(air)` guard demonstrates that
map-loader ordering can reach a registration call before all expected state exists.

This is not a finding that every `unwrap()` is wrong. It is a request to finish the lifecycle audit:
for each turf and gas-mixture insert, replacement, removal, map-load fallback, and shutdown path,
prove that the corresponding Rust ID remains valid for every background task and callback. In
particular, document why a callback carrying a turf ID cannot outlive a turf replacement, and why a
gas slot cannot be reused before queued work stops referring to it. Keep invariant panics where they
are genuinely impossible, but turn boundary-ordering failures into structured diagnostics where the
game can recover.

### P2 — The infinite-capacity regression test can pass without testing conduction

`code/modules/unit_tests/dogmos_infinite_heat_capacity_conduction.dm:57-75` verifies that two seeded
temperatures do not become a fallback/TCMB value after several notifications, but it does not assert
that either temperature changed. A heat worker that skipped the edge entirely could leave the seeds at
1500K and 1000K and still satisfy the test.

The test is valuable and its `get_share_energy()` fix is well reasoned; it needs one positive
invariant as well. Either assert the finite-side behavior expected from an infinite reservoir or add
a separate deterministic Rust-level test for the harmonic-limit cases. Keep the existing no-NaN/no-TCMB
assertions because they guard the original regression signature.

### P2 — Several integration tests intentionally stop short of physics assertions

`dogmos_excited_groups.dm` documents why it asserts a processed count rather than movement, and that
limitation is credible while Rust does not report zone membership. The high-pressure test does assert
movement, and the finite-capacity superconduction test asserts hot-to-cold movement and no overshoot.
The remaining confidence gap is therefore known rather than hidden, but it means the branch's green
unit-test signal does not yet cover deterministic zone selection or every asynchronous heat edge.

Recommended disposition: retain the honest counter-only tests, add Rust-side deterministic tests for
zone membership/energy conservation where practical, and keep the DM tests focused on the FFI contract
and observable game behavior. Do not weaken the tests merely to accommodate nondeterminism.

### P2 — Important player-facing behavior is still compile/test-only

The original plan still has three explicit live-validation items:

- the firelock slam-shut/anti-flapping change is compiled but has not been exercised in a real round;
- the flamethrower spread issue is diagnosed as a katmos timing tradeoff but has no implementation
  because it changes room-wide mixing behavior;
- the Equalize/Superconductors cost and count anomaly is unresolved after the false leak theory was
  removed.

These should remain visible as acceptance work, not be represented as completed because focused unit
tests or a clean compile pass.

### P3 — Documentation and branch hygiene items

- `modular_aphelion/modules/dogmos/readme.md:1` contains a placeholder pull-request URL.
- `aphelion-dogmos/src/turfs/superconduct.rs:145` contains a frustrated diagnostic comment that is
  not suitable as maintained project documentation.
- `git diff --check master..dogmos` reports new blank lines at EOF in
  `code/__DEFINES/dogmos_bindings.dm`,
  `code/modules/atmospherics/environmental/LINDA_turf_tile.dm`,
  `code/modules/research/designs/autolathe/service_designs.dm`, and
  `modular_nova/modules/customization/game/objects/items/tanks/n2_tanks.dm`.
  These were not changed as part of this review because they are branch-history hygiene rather than
  a safe incidental cleanup; resolve or explicitly waive them before a merge.

The repository's current Dogmos PowerShell tools no longer contain the developer-specific Rust path.
The probes now resolve BYOND tools from `PATH` by default or accept checkout-relative overrides, so
machine-specific installation paths do not need to enter the repository.

## Verified strengths

- The earlier turf-registration leak fix was disproven with a deliberate-break check and fully
  reverted; stable BYOND turf refs are now treated as a fact in the registration design.
- `register_dogmos_air()` has an explicit documented map-loader fallback, and the
  `CHANGETURF_IGNORE_AIR` temperature resync is guarded against the no-air path that caused the new
  TurfHeat crash.
- Space-boundary registration is lazy and uses a distinct immutable, never-processed gas node rather
  than eagerly registering every space turf or allowing the shared space mixture to diffuse.
- The active-turf walk now has bounded work and removes settled entries; the live round evidence
  recorded in the original plan supports that this addressed the observed unbounded-growth symptom.
- Volume and temperature writes were routed through Dogmos wrappers, generated binding drift is
  gated by the build script, and the harness distinguishes compile, boot, runtime, test, timing, and
  initialization signals.
- dm-mcp hardening is complete as a generic tool: its release build and 18 Rust tests passed, the
  protocol and parser smoke tests passed against the Meridian DME, and the output-drain fix made the
  earlier silent DreamDaemon failure diagnosable.

## Plan merge and next sequence

The original Dogmos/Auxmos plan should retain the already-completed Phase 2 and Phase 3 work, but its
Phase 3 sign-off language should be amended with the following order:

1. Resolve the dual-temperature audit and add live-consumer regression coverage.
2. Reproduce and resolve or explicitly accept the heat-edge lock contention behavior.
3. Define callback delivery guarantees and add pressure/drop telemetry.
4. Complete the turf/gas ID lifecycle audit around map loads, replacements, queued callbacks, and
   shutdown.
5. Re-run a fresh full Dogmos suite and boot probe after the above; retain the known map-preview flake
   as an explicitly independent baseline item.
6. Live-test the firelock change, make the flamethrower timing decision, and investigate the
   Equalize/Superconductors telemetry anomaly.
7. Only then decide whether Kennel Phase 5 cutover is ready.

No code fix is being applied for these findings in this handoff. The next implementation turn should
start with the P1 items after the questions below are answered.

## Questions for the maintainer

1. Should the two P1 issues be treated as hard blockers for Phase 5/cutover, or is a documented
   best-effort model acceptable for either one?
2. For live turf temperature, do you want a strict single source of truth through `return_temperature()`
   / virtual getters, or would you prefer Rust to synchronize the DM-side var after each heat pass?
3. For heat-edge processing, should we prioritize deterministic edge ownership/two-phase deltas even
   if that costs some throughput, or preserve the current non-blocking behavior with skip telemetry?
4. Which callback classes must be guaranteed delivered: reactions, visuals, pressure/firelock events,
   melt/destruction side effects, cost telemetry, or all of them?
5. Should the unresolved Equalize/Superconductors count/cost anomaly block Kennel Phase 5, or can it be
   deferred behind added telemetry and an explicit known-limitation entry?
6. For the flamethrower issue, do you want a global katmos timing change, or should we design a
   flamethrower-local spread mechanism that preserves the current room-wide equalizer behavior?
7. What real-round acceptance scenario should define the firelock test (breach, pressure recovery,
   repeated door cycles, or a specific map fixture)?
8. Should the placeholder README URL, diagnostic comment, and EOF whitespace be cleaned in the next
   code pass, or remain separate hygiene work after correctness blockers?

This review is intentionally a pause point. The working trees remain uncommitted and unpushed for
your review.

## Follow-up implementation after maintainer acceptance

Zoe accepted the recommendations and implementation proceeded without waiting for a separate cutover
approval. The two P1 correctness findings are now addressed as follows:

- Temperature authority is explicitly configurable for blocked turfs through
  `SSair.dogmos_blocked_turf_temperature_authority`. Marked core `GetTemperature()` edits preserve
  gas-mixture semantics for gas-admitting open turfs and route blocked turfs through a DM/Rust selector.
  The Rust read bind returns null for an unregistered or non-finite heat node, and the DM setter always
  updates its compatibility value while Rust safely ignores pre-registration writes.
- The superconductivity edge pass now snapshots temperatures, visits each undirected edge once,
  accumulates endpoint deltas, and writes each endpoint once with a blocking lock. It no longer relies
  on opposing non-blocking neighbor locks that silently skipped valid edges.

The Equalize decision is implemented as `FAST_ZONE` versus `FDM_ONLY` under a new SSair performance
profile, with `equalize_enabled` still authoritative. It is intentionally global because the
flamethrower issue is a Katmos timing effect, not a local flamethrower defect. Firelock behavior is
accepted from Zoe's live test report and is not changed here.

Superconductivity diagnostics now expose graph nodes, unique edge attempts/applied, lock contention,
registration changes, and cycle cost through SSair and the Kennel overview. The remaining P2 callback
delivery classification/drop counters and FFI lifecycle audit remain open; they are not being hidden by
the P1 fixes.

Verification for the follow-up: five targeted Rust turf tests passed; the Dogmos release build and
generated-binding drift check passed; the CIBUILDING DreamMaker compile reported 0 errors; three focused
DM regressions passed with 0 runtimes; and the TGUI TypeScript check passed. The final source rebuild,
full suite, boot probe, and TGUI Rspack build also passed. Phase 5 cutover remains a separate decision.
All changes remain uncommitted and unpushed.

Final verification update: the complete suite recorded 516 tests, 499 passed, 8 known-baseline
failures, 10 runtime records across 4 known-baseline signatures, and no new failures or runtimes. The
standalone boot probe compiled `tgstation.dmb` with 0 errors, initialized in 64.8688 seconds, and
reported 0 runtime errors. The TGUI Rspack build completed successfully.

Callback finding disposition: `crates/auxcallback` creates an unbounded channel, so the generic
callback `try_send()` sites do not drop work due to queue capacity. The bounded heat-notification
channel is separate and intentionally coalescible; a later SSair trigger requests another heat cycle.
The remaining FFI lifecycle and error-boundary audit stays open.

Final hardening audit:

- The safe Rust temperature read now uses `is_finite()` rather than `is_normal()`, matching its
  documented contract and preserving valid zero/subnormal finite values.
- The focused Rust turf suite was rerun after that correction: 5 passed, 0 failed. The release DLL
  rebuilt successfully and the 65-proc generated-binding drift check remained clean.
- A later focused DM run reached its 900-second timeout before DreamMaker produced a compile artifact.
  The timeout exposed a harness cleanup gap: `run_tests.ps1` swept DreamDaemon/DreamMaker but not the
  `dm.exe` compiler child. Cleanup now snapshots and stops only newly-created `dm`, DreamDaemon, and
  DreamMaker processes. The run is recorded as an infrastructure timeout, not a code-test result.
- All Dogmos PowerShell scripts parse cleanly, `git diff --check` is clean in both repositories, the
  generated map-preview binary was restored after test-generated drift, and no personal absolute paths
  are present in scanned repository artifacts.
