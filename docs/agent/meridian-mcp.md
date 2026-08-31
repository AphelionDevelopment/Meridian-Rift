# Meridian-MCP workflow

Meridian-MCP is preferred for repository-scale DreamMaker navigation and diagnostics:

1. Call `dm_parse_environment` with `tgstation.dme`.
2. Use `dm_search_context` for behavioral discovery or `dm_search_symbols` for names.
3. Verify candidates with `dm_get_type`, `dm_get_proc`, `dm_get_var`, or `dm_get_definition`.
4. Reparse after source changes. Results from an older state generation are stale.
5. Use `dm_check_errors` as SpacemanDMM evidence and report it as such.

Analysis mode is the default and should cover normal source work. Development-mode compiler, map-output, DreamDaemon, and `Topic()` tools require explicit launch configuration and contained roots. `dm_compile` is a fast direct DreamMaker gate, not the authoritative full build.

On Windows, `rift_compile` is separately absent by default and requires `MERIDIAN_MCP_RIFT_BUILD=offline|network` at server startup. It runs only this checkout's qualified root `RIFT_BUILD.cmd`, which accepts no arguments and delegates to `RIFT.cmd compile --mode full`. Caller `network_mode` is `offline` by default or `allow` under the configured network ceiling. `force_rebuild=true` removes only canonical compiled artifacts immediately before the build and is the reliable way to establish a fresh managed provenance record; an unchanged build without a valid record can correctly return insufficient evidence even when RIFT itself exits zero.

Restart Meridian-MCP only when its binary or launch configuration changed. Controller source/documentation changes do not by themselves require a server restart. Parse this exact checkout before its DM source tools, and keep the MCP build result distinct from direct CLI evidence.

Humans continue to use `BUILD.cmd`. Agents must not modify that human entry point, `RUN_SERVER.cmd`, or inherited critical build/bootstrap infrastructure without first naming exact files/effects and obtaining explicit confirmation.

Use PowerShell for Windows build and test orchestration. Follow [verification](verification.md) and the [RIFT reference](../../tools/rift/README.md), record exact commands/run IDs, and distinguish parser, compiler, full-build, focused-test, runtime, soak, and full-suite evidence.
