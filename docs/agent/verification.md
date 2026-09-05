# Verification matrix

| Evidence | Use | Completion boundary |
| --- | --- | --- |
| Static inspection | `rg`, Meridian-MCP navigation, and review | Discovery only. |
| Fast compiler gate | PowerShell invokes `.\RIFT.cmd compile --mode fast --network offline` | DreamMaker acceptance only; does not build TGUI. |
| Authoritative full build | `powershell -NoProfile -Command ".\\BUILD.cmd"` | Repository build entry point; inspect `$LASTEXITCODE`. |
| Agent full build | PowerShell invokes `.\RIFT.cmd compile --mode full --network offline`; Meridian-MCP uses `.\RIFT_BUILD.cmd` | Non-interactive delegation to the same base build target; report separately from human `BUILD.cmd`. |
| Boot | `.\RIFT.cmd run --profile default --map _maps/metastation.json --network offline` | Structured readiness for the selected map/profile only. |
| Focused unit tests | `.\RIFT.cmd test --profile ci --map _maps/metastation.json --focus <type> --network offline` | Iteration evidence for named tests only. |
| Unfocused unit tests for one map | `.\RIFT.cmd test --profile ci --map _maps/metastation.json --network offline` | Runs tests selected by that map and compiled configuration; does not cover every map or CI gate. |
| Bounded soak | `.\RIFT.cmd soak --profile default --map _maps/runtimestation.json --run-seconds 30 --network offline` | Selected bounded workload only; not production/live-round evidence. |
| TGUI | `tools/build/build.bat --wait-on-error lint tgui-test` or the matching checked-in CI command | Lint, typecheck, and tests for frontend changes. |
| Maps | Mapmerge/maplint plus automapper validation | Required for changed maps or automapper definitions. |
| Rust/Dogmos | Workspace `cargo fmt`, clippy, tests, build, generated bindings, and game integration | Both native and DM sides must pass. |
| Generated content | Content Tools validation, staged manifest/hash checks, game compile/tests | Generation alone is not game acceptance. |
| Real entry point | Launch the shipped `.cmd`, browser route, binary, or installed MCP path | Required when changing user launch/integration behavior. |

`BUILD.cmd` delegates to `tools/build/build.bat --wait-on-error build` and is the Windows authoritative full build. Do not describe the fast compiler gate, parser success, a focused test, or process liveness as equivalent.

Humans continue to use `BUILD.cmd` and `RUN_SERVER.cmd`. Agents and developers use `RIFT.cmd` for non-interactive workflows; `RIFT_BUILD.cmd` is only the no-argument Meridian-MCP compatibility entry. Offline mode requires the pinned bootstrap cache to be warm and fails before fetching; it is cooperative process-local enforcement, not a firewall. Use PowerShell for orchestration and inspect `$LASTEXITCODE`. Any proposed edit to `BUILD.cmd`, `RUN_SERVER.cmd`, inherited bootstrap/build implementation, release/deployment scripts, or CI requires an exact-file/effect explanation and explicit confirmation unless that change is already authorized in the session.

Map boot/test/soak completion evidence must use MetaStation or full RuntimeStation. Do not use `_maps/runtimestation_minimal.json`. The CI profile selects MetaStation by default.

RIFT's `full_test` evidence label means an unfocused invocation for the selected map/configuration. The DM runner still applies `DEBUG_MAP_ONLY` and existing `TEST_FOCUS` selection, and RIFT's `CIBUILDING` compile does not enable `RUNNING_LOCAL_TESTS`. Report the selected map and completed test identities/counts. Passing this gate alone does not establish all-map, hosted-CI, or whole-project completion.

RIFT evidence and stored reports are documented in [the controller reference](../../tools/rift/README.md). Docker is not part of the harness. It may optionally provide the repository's external MariaDB service for DB-backed game tests; report that dependency separately.

For guidance and marker-checker changes, run these repository-local checks with the configured Python interpreter:

```text
python -m unittest tools.ci.tests.test_check_agent_docs modular_aphelion.tools.tests.test_aphelion_marker_check
python tools/ci/check_agent_docs.py
python modular_aphelion/tools/aphelion_marker_check.py --base origin/master
```

These validate documentation routing and marker regressions only. The marker check includes tracked working-tree changes relative to the merge base; review untracked files separately. A documentation-only or Python-checker-only change does not require compiling unrelated DM code.

Report evidence as:

```text
Command:
Platform/tool version:
Scope: focused | subsystem | full
Result:
Artifacts/log marker:
Required gates not run:
```
