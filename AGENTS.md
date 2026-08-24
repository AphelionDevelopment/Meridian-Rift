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

Treat human-authored work as protected. Agents support the project through code, infrastructure, tooling, validation, integration, and other technical work; they do not supply or revise creative authorship. Do not create, rewrite, or materially alter art, sprites, icons, sound, music, lore, flavor text, descriptions, user-facing names for items, characters, locations, organizations, jobs, abilities, or similar concepts, or comparable creative content. Prompt the user to supply final creative material. For art, sound, or other external assets, agents may instead search online for suitable candidates that are freely licensed for the intended use and can be attributed properly; record the source, author, license, and attribution requirements, present the candidates for human selection, and do not import one without user approval. Mechanically integrating user-approved material is allowed when its creative substance is preserved.

Human-authored critical infrastructure is protected under the same principle. This includes build, bootstrap, release, deployment, and CI entry points and their authoritative configuration. Before changing one, identify the exact file and effect, explain why a separate Meridian-owned wrapper or extension point is insufficient, and obtain explicit user confirmation. Approval to add agent tooling does not authorize changing this infrastructure. Prefer a separate wrapper that delegates to the authoritative human workflow.

Use Meridian-MCP for DreamMaker parsing and navigation after `dm_parse_environment`; reparse after changes. Use PowerShell for Windows builds and tests. Direct `dm.exe` is a fast compiler gate. `BUILD.cmd` is the authoritative full build. Focused tests are iteration evidence, never a full-completion claim.
