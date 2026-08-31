# Dogmos harness migration plan

This is Plan B. Start only after the general RIFT controller is accepted on the target Dogmos checkout and branch.

## Preconditions

- Rebase/port the general `tools/rift` controller without taking ownership of inherited build entry points.
- Record the exact Dogmos DLL/service build commands, generated binding contract, runtime filenames, CI defines, maps, child topology, and current PowerShell command behavior.
- Use MetaStation or full RuntimeStation for runtime evidence, never RuntimeStation Minimal.
- Preserve DreamDaemon 32-bit memory and `dogmosd` 64-bit memory as separate series.

## Migration tasks

1. Add a strict `dogmos` profile with repository config, Dogmos compile defines, readiness/fatal rules, required artifacts, and exactly one continuous `dogmosd.exe` descendant.
2. Use the existing paired `--shim`/`--service` overlay inputs to copy release artifacts only into the run workspace as `dogmos.dll` and `dogmosd.exe`.
3. Add fatal rules for nonempty panic output, `StageConflict`, malformed stage responses, pending-stage timeouts, lifecycle rejection, and normalized DreamMaker runtime errors.
4. Add Dogmos-specific result extraction without duplicating process, timeout, log, cleanup, locking, or report infrastructure.
5. Retain generated contract synchronization in its current Python tool unless separately approved for migration.
6. Map every old compile, boot-probe, focused-test, and liveness-soak command to one RIFT invocation and one profile/evidence class.
7. Run old/new parity on identical native artifacts, map, config, port policy, duration, and workload. Compare readiness, tests, runtime signatures, required-child observations, and numeric/event outputs.
8. Run the pinned Rust format, clippy, tests, and builds for i686 shim and x86_64 service as applicable; report exact `rustc --version`.
9. Delete Dogmos PowerShell lifecycle helpers only after applicable parity, cancellation, timeout, cleanup, and real runtime gates pass.

## Acceptance

- The DLL/service pair is never copied into or restored through the repository root for a run.
- Missing, extra, early-exiting, or continuously absent `dogmosd` fails with structured evidence.
- DreamDaemon and service memory maxima remain separate and use matched workloads.
- Runtime and panic/stage failures stop the exact owned tree and retain artifacts.
- Focused tests/short soaks remain focused evidence; matched live-round or production evidence is reported separately.
- No old script is removed before its command mapping and parity record is durable.
