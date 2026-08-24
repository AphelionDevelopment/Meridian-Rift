# Source authority and lineage

Reviewed local revision: `c34175cab324ce34c768e698a0c7c6c488691f89`

Reviewed Nova revision: `c4846461cc82bce6a87e6efe6ea0c08e440838c6`

Reviewed guide revision: `179d67f3e92a1f1d62892adc638edfc7439708ab`

Reviewed on: `2026-08-23`

| Question | Authority |
| --- | --- |
| Deliberate Meridian product and placement policy | Checked-in Meridian-Rift guidance and implementation. |
| DreamMaker syntax, compilation, or runtime semantics | Official BYOND documentation and reproducible DreamMaker/DreamDaemon behavior. |
| Inherited tgstation systems | Current checked-in tg guides and implementation unless a downstream delta is documented. |
| Inherited Nova modularization | [Local Nova handbook](../../modular_nova/readme.md) and preserved Nova ownership markers. |
| Parser, index, or DreamChecker result | SpacemanDMM/Meridian-MCP as analysis evidence; never compiler truth. |
| Structured lore source and export | Aphelion Content Tools. Generated DM is downstream. |

When authorities disagree, identify the question first. A tg bugfix should normally go upstream; a deliberate Meridian behavior belongs in Aphelion-owned code. A compiler result outranks parser acceptance, while the repository's full build outranks a direct compiler-only completion claim.

Do not invent a tg remote identity. Record the exact local revision and reviewed paths, then follow [upstream drift](upstream-drift.md).

## Human-authored critical infrastructure

Build, bootstrap, release, deployment, and CI entry points and their authoritative configuration are protected review surfaces. Before changing one, an agent must name the exact file and behavioral effect, explain why a separate Meridian-owned wrapper or supported extension point cannot satisfy the requirement, and receive explicit user confirmation. A broad approval to add tooling or complete a feature is not approval to alter this infrastructure.

Prefer a separate Meridian-owned wrapper that delegates to the human-authored workflow. Keep the human entry point authoritative, add drift detection where the wrapper depends on its contract, and document any difference in behavior.
