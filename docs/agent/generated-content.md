# Generated content and Aphelion Content Tools

Aphelion Content Tools owns the canonical writer source at `tools/lore_editor/content/`, its schemas, validation, browser workflow, and staged export implementation. Meridian-Rift receives only the generated runtime artifact:

`modular_aphelion/modules/lore_overhaul/code/generated_lore_overrides.dm`

Never hand-edit the generated DM or treat it as canonical source. Coordinate schema changes in Content Tools first.

Creative authorship remains with humans. Agents may implement and maintain schemas, validation, review workflows, export infrastructure, and runtime integration, but must not author or rewrite lore, descriptions, flavor text, user-facing names, or other creative content. Prompt the user for final wording and preserve user-approved material through mechanical validation, serialization, and generation rather than attempting to improve it.

Export has two phases. Prepare validates all structured content, repository identity, `tgstation.dme`, schema/manifest versions, source revision, content hashes, and the single allowed destination. Apply rechecks those facts against a clean compatible checkout and replaces the artifact atomically. Review the manifest and generated diff before handoff through GitHub Desktop.

The game repository still owns compile, runtime, unit-test, and AutoWiki acceptance. AutoWiki is a downstream consumer of the same structured model; the browser never receives wiki credentials and never publishes directly. Catalog loading or a live process is not proof of a valid export.
