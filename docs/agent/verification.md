# Verification matrix

| Evidence | Use | Completion boundary |
| --- | --- | --- |
| Static inspection | `rg`, Meridian-MCP navigation, and review | Discovery only. |
| Fast compiler gate | PowerShell invokes `C:\Program Files (x86)\BYOND\bin\dm.exe tgstation.dme` | DreamMaker acceptance only; does not build TGUI. |
| Authoritative full build | `powershell -NoProfile -Command ".\\BUILD.cmd"` | Repository build entry point; inspect `$LASTEXITCODE`. |
| Focused unit tests | Existing targeted unit-test harness/configuration | Iteration evidence for named tests only. |
| Full unit-test suite | CI-equivalent complete unit-test configuration | Required for DM behavior completion when applicable. |
| TGUI | `tools/build/build.bat --wait-on-error lint tgui-test` or the matching checked-in CI command | Lint, typecheck, and tests for frontend changes. |
| Maps | Mapmerge/maplint plus automapper validation | Required for changed maps or automapper definitions. |
| Rust/Dogmos | Workspace `cargo fmt`, clippy, tests, build, generated bindings, and game integration | Both native and DM sides must pass. |
| Generated content | Content Tools validation, staged manifest/hash checks, game compile/tests | Generation alone is not game acceptance. |
| Real entry point | Launch the shipped `.cmd`, browser route, binary, or installed MCP path | Required when changing user launch/integration behavior. |

`BUILD.cmd` delegates to `tools/build/build.bat --wait-on-error build` and is the Windows authoritative full build. Do not describe the fast compiler gate, parser success, a focused test, or process liveness as equivalent.

Report evidence as:

```text
Command:
Platform/tool version:
Scope: focused | subsystem | full
Result:
Artifacts/log marker:
Required gates not run:
```
