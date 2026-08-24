# Meridian-MCP workflow

Meridian-MCP is preferred for repository-scale DreamMaker navigation and diagnostics:

1. Call `dm_parse_environment` with `tgstation.dme`.
2. Use `dm_search_context` for behavioral discovery or `dm_search_symbols` for names.
3. Verify candidates with `dm_get_type`, `dm_get_proc`, `dm_get_var`, or `dm_get_definition`.
4. Reparse after source changes. Results from an older state generation are stale.
5. Use `dm_check_errors` as SpacemanDMM evidence and report it as such.

Analysis mode is the default and should cover normal source work. Development-mode compiler, map-output, DreamDaemon, and `Topic()` tools require explicit launch configuration and contained roots. `dm_compile` is a fast direct DreamMaker gate, not the authoritative full build.

On Windows, `rift_compile` is separately absent by default and requires `MERIDIAN_MCP_RIFT_BUILD=offline|network` at server startup. It runs only this checkout's qualified root `RIFT_BUILD.cmd`; caller `network_mode` is `offline` by default or `allow` under a network startup ceiling. Humans continue to use `BUILD.cmd`. Agents must not modify that human entry point or inherited critical build/bootstrap infrastructure without first naming the exact files and effects and obtaining a new explicit confirmation.

Use PowerShell for Windows build and test orchestration. Follow [verification](verification.md), record exact commands, and distinguish parser, compiler, focused-test, runtime, and full-suite evidence.
