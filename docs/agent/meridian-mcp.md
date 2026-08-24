# Meridian-MCP workflow

Meridian-MCP is preferred for repository-scale DreamMaker navigation and diagnostics:

1. Call `dm_parse_environment` with `tgstation.dme`.
2. Use `dm_search_context` for behavioral discovery or `dm_search_symbols` for names.
3. Verify candidates with `dm_get_type`, `dm_get_proc`, `dm_get_var`, or `dm_get_definition`.
4. Reparse after source changes. Results from an older state generation are stale.
5. Use `dm_check_errors` as SpacemanDMM evidence and report it as such.

Analysis mode is the default and should cover normal source work. Development-mode compiler, map-output, DreamDaemon, and `Topic()` tools require explicit launch configuration and contained roots. MCP compilation is a fast DreamMaker compiler gate, not the authoritative full build.

Use PowerShell for Windows build and test orchestration. Follow [verification](verification.md), record exact commands, and distinguish parser, compiler, focused-test, runtime, and full-suite evidence.
