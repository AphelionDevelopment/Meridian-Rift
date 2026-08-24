# Meridian-Rift agent instructions

Meridian-Rift is a BYOND/DreamMaker SS13 codebase downstream of Nova Sector and tgstation. Be direct, research existing implementations with `rg` before editing, preserve unrelated work, and do not commit, push, reset, checkout, or merge without explicit authorization.

## Required reading

- All code: [.github/guides/STYLE.md](.github/guides/STYLE.md), [.github/guides/AUTODOC.md](.github/guides/AUTODOC.md), and [.github/guides/STANDARDS.md](.github/guides/STANDARDS.md).
- Placement and ownership: [docs/agent/placement-and-markers.md](docs/agent/placement-and-markers.md) and [modular_nova/readme.md](modular_nova/readme.md).
- Source conflicts: [docs/agent/source-authority.md](docs/agent/source-authority.md).
- Verification: [docs/agent/verification.md](docs/agent/verification.md).
- Meridian-MCP: [docs/agent/meridian-mcp.md](docs/agent/meridian-mcp.md).
- Generated content: [docs/agent/generated-content.md](docs/agent/generated-content.md).
- Upstream review: [docs/agent/upstream-drift.md](docs/agent/upstream-drift.md).
- Full routing index: [docs/agent/README.md](docs/agent/README.md).

Read [.github/guides/HARDDELETES.md](.github/guides/HARDDELETES.md) before `Destroy()` or reference ownership changes, and [.github/guides/VISUALS.md](.github/guides/VISUALS.md) before planes, layers, filters, overlays, or visual systems.

## High-frequency rules

New Meridian-owned work belongs under `modular_aphelion` and uses canonical `APHELION EDIT` markers. Preserve inherited `modular_nova` paths and `NOVA EDIT` ownership; do not convert Nova content in bulk. Prefer existing helpers, components, subsystems, defines, and patterns. Treat player input as hostile, revalidate context after interactive input, scope references, pair registration with cleanup, and keep `Destroy()` free of side effects.

Use Meridian-MCP for DreamMaker parsing and navigation after `dm_parse_environment`; reparse after changes. Use PowerShell for Windows builds and tests. Direct `dm.exe` is a fast compiler gate. `BUILD.cmd` is the authoritative full build. Focused tests are iteration evidence, never a full-completion claim.
