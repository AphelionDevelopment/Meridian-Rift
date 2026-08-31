# RIFT controller implementation plan

Plan date: 2026-08-31. Implementation branch: `codex/rift-controller`. Base revision: `a249749d13486ac5c58d5270bf50bec794d6f44c`.

This plan implements [the approved design](build-harness-design.md) without modifying protected `BUILD.cmd`, `RUN_SERVER.cmd`, the inherited build graph, bootstrap implementation, CI, release, or deployment entry points.

## Phase 1: contracts and pure foundations

- [x] Define strict versioned `default` and `ci` profiles.
- [x] Define evidence/status/event/summary/artifact schemas.
- [x] Write ordered NDJSON events and atomically publish summaries.
- [x] Add human rendering, JSONL replay, path redaction, and artifact hashing.
- [x] Parse all commands/options without shell evaluation.
- [x] Qualify the module-relative repository and protected build contract.
- [x] Parse literal dependency pins and resolve exact pinned BYOND.
- [x] Add offline Bun/Python/icon-cutter/lockfile preflight.
- [x] Allocate unique run directories and an atomic mutating-workflow lock.

Verification: Bun fixture tests cover strict schemas, duplicates/unknowns, unsafe maps, focus grammar, pin parsing, build drift, missing offline prerequisites, named BYOND resolution, report ordering, hashes, redaction, and lock handling.

## Phase 2: owned process and compile services

- [x] Spawn child processes from argument arrays with explicit cwd/environment.
- [x] Stream both output channels and track exact root/descendant PIDs.
- [x] Sample private/working-set memory by stable role.
- [x] Enforce wall/idle timeouts and activity-file changes.
- [x] Stop only exact owned trees and verify cleanup.
- [x] Add cancellation state and stable exit 130.
- [x] Implement fast scratch compilation with explicit diagnostics/fresh artifacts.
- [x] Implement fixed-target full builds with rebuilt/reused/forced classification.

Verification: generated fixture processes cover nonzero exits, interleaved/partial output, silent idle timeout, descendant wall timeout, unrelated-process preservation, cancellation, fixed-target allowlisting, missing diagnostics, missing artifacts, and scratch cleanup.

## Phase 3: isolated runtime workflows

- [x] Copy a fixed runtime manifest into a per-run workspace.
- [x] Isolate repository/CI config and contained map selection.
- [x] Watch structured runtime JSON with late-file/header/partial-line handling and plain-log fallback.
- [x] Implement readiness, fatal rules, normalized runtime signatures, and artifact collection.
- [x] Implement immediate/bounded `run` with post-readiness fatal monitoring.
- [x] Implement strict focused/full unit-test result validation and CI artifacts.
- [x] Implement bounded soak rules, resource maxima, child liveness, and overlays.
- [x] Persist phase, supervised-process, test, runtime, resource, artifact, and cleanup summaries.

Verification: fixture workflows cover isolated configuration/map behavior, traversal rejection, cleanup failure, readiness/fatal/timeout behavior, MetaStation selection, unstable native DreamDaemon close values accepted only after strict passing evidence and natural termination, bounded duration, post-readiness fatal rules, required-child loss, and stable resource aggregation.

## Phase 4: launchers and compatibility

- [x] Add `RIFT.cmd` with offline pre-Bun selection and quoted argument forwarding.
- [x] Convert `RIFT_BUILD.cmd` to no-argument `RIFT.cmd compile --mode full` delegation.
- [x] Test spaces/metacharacters, both network forms, missing Bun, invalid environments, unexpected compatibility arguments, force mapping, and exact zero exit.
- [x] Run real direct full builds through both launchers.
- [x] Run Meridian-MCP against this exact checkout and establish a forced fresh-artifact build record.
- [x] Remove the superseded four-file agent PowerShell wrapper after parity.

The authoritative `BUILD.cmd` hash was checked before/after direct launcher gates and remained unchanged.

## Phase 5: documentation and acceptance

- [x] Add the command/report reference in `tools/rift/README.md`.
- [x] Add research, design, verification, MCP, and guide-index documentation.
- [x] Document representative MetaStation/RuntimeStation requirements and reject minimal-map completion evidence.
- [x] Document Docker only as an optional MariaDB provider, not a RIFT dependency.
- [x] Run the final pure/formatter/diff/privacy/process gates after all documentation edits.
- [x] Run the final direct fast/full/doctor compatibility gates after all controller edits.
- [x] Re-establish final forced Meridian-MCP provenance after all compatibility edits.
- [x] Record the final uncommitted handoff and all unrun hosted/full/live gates.

## Real acceptance matrix

Use PowerShell and inspect `$LASTEXITCODE` after every command:

```powershell
.\RIFT.cmd doctor --network offline
.\RIFT.cmd compile --mode fast --network offline
.\RIFT.cmd compile --mode full --network offline
.\RIFT.cmd run --profile default --map _maps/metastation.json --port 1339 --network offline
.\RIFT.cmd test --profile ci --map _maps/metastation.json --focus /datum/unit_test/simple_animal_freeze --network offline
.\RIFT.cmd soak --profile default --map _maps/runtimestation.json --run-seconds 30 --network offline
```

The already recorded implementation evidence includes a MetaStation readiness run, a fresh focused MetaStation unit test, and a 30-second MetaStation soak. Final reruns are required only when subsequent code changes could invalidate the relevant behavior.

Final run records:

- doctor: `20260831T014922Z-66af140d`;
- fast compile: `20260831T014929Z-db19e40e`;
- MetaStation boot with post-readiness monitoring: `20260831T015220Z-3f0cb61c`;
- focused MetaStation test: `20260831T021757Z-0666f42a`;
- final 30-second full RuntimeStation soak: `20260831T023121Z-927d4a93`;
- direct full compatibility build: `20260831T022435Z-86cf88f8`;
- forced Meridian-MCP full build: `20260831T022536Z-587bfd45`, build record `86ca9bb1ef7535993d2bea9ccef1c2be`.

The focused-test investigation also measured three different native DreamDaemon exits (224, 176, and 160) for clean natural shutdowns with the same passing result/clean-run contract. Native exit is retained as process evidence; it is not used instead of fresh game evidence.

Post-review repairs added inherited Bun offline configuration, enforced representative-map and CI test-profile contracts, continuous post-readiness monitoring, cancellable bounded tasks, process-instance identity checks, race-safe lock reaping and finalization, typed exit classification, recursive structured-report redaction, stored-report validation, and explicit retained-workspace reporting. Fresh repair evidence:

- doctor: `20260831T035633Z-4ae3d8fb`;
- fast compile: `20260831T035643Z-31c650ce`;
- bounded MetaStation boot: `20260831T035854Z-1bf7f38d`;
- focused MetaStation CI test: `20260831T040216Z-ef0689c5`;
- 30-second full RuntimeStation soak: `20260831T041132Z-f3f2d903`;
- controller tests: 78 passed, 0 failed with Bun 1.3.5;
- Biome: all `tools/rift` files checked with no diagnostics.

## Handoff boundary

Leave all changes uncommitted. Report exact tool versions, run IDs, evidence scopes, process/lock/worktree cleanliness, and remaining gates. Do not describe focused MetaStation evidence as a full test suite, hosted CI, or production/live-round result.
