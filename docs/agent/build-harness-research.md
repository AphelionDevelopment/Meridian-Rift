# Build and test harness research

Research date: 2026-08-31. Repository revision at implementation start: `a249749d13486ac5c58d5270bf50bec794d6f44c`.

## Conclusion

The replacement controller should be TypeScript running on the repository-pinned Bun runtime.

That choice removes PowerShell as the orchestration language while reusing the runtime already required by the authoritative Juke build graph. Bun provides direct argument-array process spawning, streamed output, promises for exit, TypeScript execution, and a built-in test runner. The remaining Windows-specific surface is limited to exact-PID descendant discovery and termination.

Python was rejected as the main controller because the repository's Python bootstrap is itself PowerShell-based and Python is not the authoritative build runtime. Rust was rejected for this first migration because the game checkout does not pin and bootstrap a harness Rust toolchain; distributing the controller would become a prerequisite for compiling the game.

## Local source findings

The protected human paths are intentionally thin:

```text
BUILD.cmd
  -> tools/build/build.bat --wait-on-error build
  -> tools/bootstrap/javascript.bat
  -> tools/build/build.ts / Juke

RUN_SERVER.cmd
  -> tools/build/build.bat --wait-on-error server
  -> the same pinned Bun/Juke graph
  -> compile, then interactive DreamDaemon launch
```

The inherited build graph already owns dependency bootstrapping, icon generation, map includes, TGUI, DreamMaker invocation, and the interactive server target. Reimplementing that graph would create an upstream merge liability. The automation controller should qualify the contract and delegate fixed targets.

The previous agent wrapper spread qualification, offline checks, subprocess management, artifact checks, and tests across `RIFT_BUILD.cmd` plus four `tools/build/rift` PowerShell files. The Dogmos branch contained another independent group of PowerShell helpers for compilation, boot probes, unit tests, liveness, and child-process observation. Both families duplicated timeout, restoration, process, and report behavior.

The game unit-test path is not merely a DreamDaemon launch. It requires a `CIBUILDING` compile, CI configuration, structured `data/unit_tests.json`, clean-run evidence, and—for DB-backed initialization—the repository's MariaDB configuration. Docker is not a build-harness dependency. During validation, a disposable loopback-only MariaDB container was sufficient to provide that existing external service and was removed afterward.

Map evidence must be representative. The CI profile selects `_maps/metastation.json`. Explicit real gates used MetaStation; `_maps/runtimestation.json` is also allowed. `_maps/runtimestation_minimal.json` is a debug/minimal map and is not accepted as completion evidence.

## Controlled `RUN_SERVER.cmd` observation

The interactive entry point was executed before implementation with the pinned Bun 1.3.5 and BYOND 516.1687 environment.

Observed behavior:

1. Juke performed its normal build work and launched DreamDaemon.
2. The server emitted the structured initialization-complete marker.
3. Stopping the exact owned DreamDaemon after readiness caused the Juke `server` target to see the intentional stop as a nonzero native exit.
4. `--wait-on-error` then prompted for human inspection instead of returning a stable automation result.
5. No owned BYOND/Bun child remained and no tracked file changed.

This is correct behavior for an interactive launcher and poor behavior for bounded automation. `RUN_SERVER.cmd` should remain human-owned; RIFT should supervise DreamDaemon directly after delegating compile work.

## Upstream and platform evidence

tgstation and Nova use the same basic separation: a thin command launcher over a TypeScript build graph, plus isolated CI server execution. Relevant reviewed sources:

- [tgstation RUN_SERVER.cmd at the researched revision](https://raw.githubusercontent.com/tgstation/tgstation/68651c87fb893d6bb5e0fd3ee6d7c5467bc43da4/RUN_SERVER.cmd)
- [tgstation TypeScript build graph](https://github.com/tgstation/tgstation/blob/68651c87fb893d6bb5e0fd3ee6d7c5467bc43da4/tools/build/build.ts)
- [tgstation isolated CI server runner](https://github.com/tgstation/tgstation/blob/68651c87fb893d6bb5e0fd3ee6d7c5467bc43da4/tools/ci/run_server.sh)
- [tgstation build-system documentation](https://github.com/tgstation/tgstation/blob/master/tools/build/README.md)
- [Nova RUN_SERVER.cmd at the researched revision](https://github.com/NovaSector/NovaSector/blob/6d8cfba859a22568047b9ca5f0130b86404bd29b/RUN_SERVER.cmd)
- [Nova TypeScript build graph](https://github.com/NovaSector/NovaSector/blob/6d8cfba859a22568047b9ca5f0130b86404bd29b/tools/build/build.ts)
- [Nova isolated CI server runner](https://github.com/NovaSector/NovaSector/blob/6d8cfba859a22568047b9ca5f0130b86404bd29b/tools/ci/run_server.sh)

The [official BYOND DM reference](https://www.byond.com/docs/ref/info.html) documents DreamDaemon's port, parameter, logging, verbose, close, and trust options. These should be passed as typed argument-array elements instead of shell-composed strings.

[Bun child-process documentation](https://bun.com/docs/runtime/child-process) covers direct spawning, working directory, environment, piped streams, exit promises, and signals. [Bun test documentation](https://bun.com/docs/test) covers the repository-local TypeScript test runner used for controller fixtures.

Windows `taskkill /T` terminates a specified PID and its descendants; see [Microsoft taskkill documentation](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/taskkill). The controller combines exact root/descendant ownership, targeted termination, and post-stop liveness verification. It never kills by image name. [Windows Job Objects](https://learn.microsoft.com/en-us/windows/win32/procthread/job-objects) remain a possible later hardening step if race measurements justify native integration.

[tgstation-server](https://github.com/tgstation/tgstation-server) remains the production deployment/watchdog system. RIFT is intentionally a local developer/agent controller and does not attempt to replace production supervision.

## Required architecture

The research supports these boundaries:

- keep `BUILD.cmd`, `RUN_SERVER.cmd`, `tools/build/build.bat`, and the Juke graph authoritative and human-owned;
- add one thin `RIFT.cmd` launcher and one Bun/TypeScript controller;
- keep `RIFT_BUILD.cmd` only as the no-argument Meridian-MCP compatibility contract;
- use fixed target allowlists and argument arrays, never arbitrary shell text;
- deploy run state under `data/rift-runs/<run-id>/workspace`;
- treat structured readiness, test JSON, clean-run markers, fatal logs, and process/resource samples as first-class evidence;
- write ordered NDJSON events and an atomic JSON summary;
- use one workflow lock and terminate only exact owned process trees;
- preserve compiler, full-build, boot, focused-test, full-test, and soak evidence as distinct scopes;
- migrate Dogmos as profiles/overlays/probes after the general controller is stable, rather than creating another process library.

## Validation boundary

Local compiler, MetaStation boot, focused MetaStation test, and short soak results validate the controller and the named workflow only. They are not hosted CI, a complete game unit-test suite, or production live-round evidence. Those remaining gates must be stated explicitly in handoff reports.
