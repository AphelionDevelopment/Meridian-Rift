# Meridian-Rift agent build wrapper

`RIFT_BUILD.cmd` is the non-interactive build entry point owned by Meridian's agent tooling. Humans continue to use the authoritative root `BUILD.cmd`.

The wrapper validates the current human build contract, then delegates to the fixed `tools/build/build.bat build` operation without `--wait-on-error`. It accepts no command-line arguments. Its only inputs are:

- `MERIDIAN_RIFT_BUILD_NETWORK=offline|allow`, defaulting to `offline`.
- `MERIDIAN_RIFT_FORCE_REBUILD=0|1`, defaulting to `0`.

Offline mode requires the pinned Bun, Python, pip requirements marker, icon cutter, and Bun lockfiles to already be present. It performs frozen, offline Bun resolution checks and configures Bun and pip to fail instead of fetching. This is cooperative process-level enforcement, not an operating-system firewall.

Allow mode preserves the inherited bootstrap behavior, including its ability to reach the network when a dependency is missing. Meridian-MCP performs any requested best-effort endpoint audit; this wrapper does not monitor network activity.

Do not change `BUILD.cmd`, the inherited bootstrap scripts, the build implementation, or other human-authored critical infrastructure as part of maintaining this wrapper. Such changes require separate, explicit user approval after explaining why this isolated extension point is insufficient.
