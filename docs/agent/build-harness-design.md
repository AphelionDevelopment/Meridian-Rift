# RIFT build-controller design

Status: implemented Plan A design, 2026-08-31. Plan B Dogmos migration remains separate.

## Goals

RIFT provides one non-interactive Windows interface for repository qualification, fast/full compilation, isolated boot, isolated unit tests, bounded soak runs, and stored reports. It is optimized for deterministic control and machine-readable evidence while remaining useful to humans.

It must:

- use repository-pinned tools and exact BYOND pins;
- delegate the inherited full-build graph;
- fail offline before an owned build can fetch;
- isolate mutable runtime configuration, maps, data, and logs;
- supervise exact owned process trees with wall, idle, readiness, and bounded-run limits;
- classify structured game output and preserve artifacts;
- produce stable exits, ordered events, and atomic summaries;
- leave no owned process, workflow lock, transient workspace, or run-specific root scratch file after normal cleanup.

It is not a replacement for the interactive human launchers, hosted CI, production TGS supervision, or full live-round validation.

## Ownership boundary

Protected inherited infrastructure remains authoritative:

- `BUILD.cmd` is the human full-build entry point.
- `RUN_SERVER.cmd` is the human interactive server entry point.
- `tools/build/build.bat`, `tools/build/build.ts`, Juke, and bootstrap scripts remain the inherited implementation.

RIFT owns:

- `RIFT.cmd`;
- `RIFT_BUILD.cmd` as a no-argument compatibility shim;
- `tools/rift/rift.ts`, `process.ts`, `report.ts`, `profiles.json`, tests, and documentation.

The controller validates the exact protected delegation before a full build. It invokes only allowlisted fixed targets and never forwards arbitrary target or shell text.

## Architecture

```text
PowerShell caller
  -> RIFT.cmd
     -> offline pinned-Bun check OR existing allow-mode Bun bootstrap
     -> tools/rift/rift.ts
        -> qualification / pins / profile / lock
        -> compile service
           -> direct pinned DreamMaker for fast evidence
           -> inherited fixed build target for full evidence
        -> isolated deployment
        -> owned DreamDaemon lifecycle
        -> structured log and artifact collectors
        -> events.ndjson + summary.json

Meridian-MCP rift_compile
  -> RIFT_BUILD.cmd (no arguments)
  -> RIFT.cmd compile --mode full [--force]
```

The implementation uses Bun/TypeScript standard and Node-compatible APIs. Windows-specific process discovery/resource reads use fixed encoded PowerShell programs internal to `process.ts`; callers cannot supply program text. Tree termination first requests shutdown through the owned Bun process handle, then force-stops only observed descendants whose PID, executable name, and creation time still match the captured process instance.

## Repository and tool qualification

The controller root is derived from its module path, not the caller's current directory. Qualification requires the expected DME, dependency pins, launchers, build delegate, and exact protected build contract.

Pins are parsed as literal `export KEY=value` assignments from `dependencies.sh`; shell evaluation is forbidden. Offline preflight requires:

- pinned Bun and matching `bun --version`;
- pinned embedded Python, pip, and a matching requirements marker;
- the pinned icon cutter;
- root and TGUI Bun lockfiles;
- successful offline/frozen dry-run resolution for both Bun projects.

Offline child environments disable Bun telemetry/config lookup and set Bun/pip offline controls. This is process-local enforcement, not a network firewall.

BYOND resolution order is `DM_EXE`, default `tools/build/dm_versions.json` entry when present, standard installation paths, registry, then `PATH`. Candidates must report the exact pin and have a sibling DreamDaemon.

## Profiles

`tools/rift/profiles.json` is a strict schema. Unknown keys, invalid regexes, unsafe paths, and unsupported versions fail before execution. Profiles define configuration source, default map, compile defines, DreamDaemon flags, readiness/fatal rules, required children, required artifacts, timeouts, minimum tests, and resource interval.

Plan A profiles:

- `default`: repository config, no implicit map override, normal trusted/verbose server.
- `ci`: CI config, MetaStation, close/trusted/verbose, clean-run and unit-test artifacts.

Representative map gates use `_maps/metastation.json` or `_maps/runtimestation.json`. Minimal/debug map results are not completion evidence.

## Compilation

Fast compilation:

1. creates `.rift-<run-id>.test.dme` after proving its exact three scratch names are absent;
2. invokes pinned DreamMaker directly with `-DCBT` and profile defines;
3. requires natural zero exit and an explicit zero-error diagnostic line;
4. requires new nonempty scratch DMB/RSC files;
5. hashes copies into the run artifacts;
6. removes only those exact scratch names in `finally`.

This produces `compiler` evidence only.

Full compilation validates the human build contract, then invokes the fixed non-interactive `tools/build/build.bat build` delegate. It requires successful exit and nonempty canonical artifacts. Without force it compares before/after size, timestamp, and hash to classify rebuilt/reused results. Force deletes only the two canonical compiled artifacts and requires freshly produced replacements. This produces `full_build` evidence.

## Deployment and runtime

Each runtime workflow creates only `data/rift-runs/<run-id>/workspace`. A fixed manifest copies compiled artifacts and required runtime trees. The profile's repository/CI config and selected map are copied into the workspace. Source configuration and maps are never edited.

DreamDaemon receives direct argument elements for the DMB, port, profile flags, and `log-directory=rift`. Readiness follows structured JSON log records, tolerates late files/header/partial lines, and has a plain runtime-log fallback. Fatal rules count matching structured records. Runtime errors are normalized by replacing BYOND refs with `[ref]` and decimal runs with `N`.

`run` compiles, deploys, reaches readiness, optionally monitors a bounded window, then intentionally stops and returns `ready_then_stopped`. It continues fatal-log monitoring during a requested post-readiness window.

`test` defaults to the `ci` profile, runs fixed Juke prerequisites, appends validated `TEST_FOCUS()` macros to the run scratch DME, compiles with `CBT` and `CIBUILDING`, deploys under the selected profile, and requires strict unit-test JSON/minimum/artifact/process policies. Alternate test profiles must retain the CI config, `-close`, and required nonempty unit-test and clean-run artifacts. CI uses MetaStation by default. BYOND 516.1687/Bun 1.3.5 produced different Windows native exits (224 and 176) for clean natural MetaStation shutdowns. RIFT records that value as process evidence but makes fresh passing result JSON, zero runtime failures, required clean artifacts, and natural termination authoritative.

`soak` requires 30-1800 seconds after readiness. It continuously evaluates fatal/child rules and samples private/working-set bytes by stable role. It fails immediately on policy violations. Optional Dogmos shim/service inputs must be supplied together, be nonempty files, and are copied only into the workspace under fixed names.

## Process ownership and cancellation

Every owned root records descendants discovered from Windows process parentage. The supervisor streams stdout/stderr, samples resources, observes activity files, and enforces independent idle/wall limits. Stop and cancellation target only captured process instances and verify that those exact identities are gone. PID reuse cannot redirect cleanup to an unrelated process, and unrelated processes are never selected by executable name alone.

Ctrl+C/Ctrl+Break set controller cancellation state, stop all active owned processes with cancellation semantics, allow workflow artifact/cleanup handling, publish the summary, and return 130.

One atomic `.active.lock` serializes mutating workflows. Live locks fail or wait for the requested bounded interval. Stale lock records are preserved under `stale-locks`; release removes the lock only when its token still matches.

## Evidence and reports

Evidence classes are:

| Class | Meaning |
| --- | --- |
| `inspection` | Read-only qualified observation. |
| `compiler` | Direct DreamMaker gate only. |
| `full_build` | Inherited complete build target. |
| `boot` | Selected deployment reached readiness. |
| `focused_test` | Only named unit-test types ran. |
| `full_test` | Selected complete unit-test configuration ran. |
| `soak` | Bounded selected workload met policies. |

Parser success, process liveness, focused tests, and full builds are not interchangeable evidence.

Each run has ordered `events.ndjson`, raw controller child output logs, atomically published `summary.json`, copied/hashed artifacts, and a transient workspace. The summary includes phase durations, supervised process termination/native exits, stable CLI exit, tests, runtime signatures, resource maxima, cleanup state, and failures. Artifact paths are run-relative. Structured reports recursively redact user-profile path segments; raw child output remains exact local evidence. Environments and secret-bearing command strings are not serialized. Cleanup records intentional retention separately from removal failures.

Stable exits are 0 success, 2 usage, 3 preflight, 4 compile, 5 runtime/test/policy/artifact/cleanup, 6 timeout, 7 lock, and 130 cancellation. Native child exits remain process evidence.

## Acceptance criteria

Plan A is acceptable when tests and real gates demonstrate:

- strict CLI/profile/path/pin/build-contract validation;
- launcher quoting and offline pre-Bun failure;
- direct and fixed-target compile success/failure/stale handling;
- late/partial structured readiness and fatal detection;
- exact process-tree timeout/cancellation cleanup without harming an unrelated process;
- isolated configuration/map/test artifacts and exact workspace cleanup;
- representative MetaStation or RuntimeStation boot/test/soak evidence;
- ordered events, phase/process summaries, hashes, redaction, and stable exits;
- direct `RIFT_BUILD.cmd` compatibility and Meridian-MCP forced-build provenance;
- no owned process, active lock, or workflow-created tracked mutation after completion.

Hosted CI, full game unit tests, and production/live-round evidence remain separate gates.

## Plan B

Dogmos migration adds a strict profile, required `dogmosd` child rules, panic/stage-response rules, separate process/resource series, and old/new parity measurements. The general controller must not acquire Dogmos-specific build ownership. Generated interface synchronization can remain in its existing Python tool until separately migrated.
