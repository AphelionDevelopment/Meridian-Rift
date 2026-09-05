# Generated content and Aphelion Content Tools

Aphelion Content Tools is the external source project for structured lore, schemas, validation, browser workflow, and staged export. The historical integration used `tools/lore_editor/content/` within that project and designated this generated game destination:

`modular_aphelion/modules/lore_overhaul/code/generated_lore_overrides.dm`

The destination is absent in this checkout as inspected on 2026-09-05. Confirm the active Content Tools revision, source path, export schema, and target integration before beginning export work; this guide does not establish that an export has been installed. When generated DM is present, never hand-edit it or treat it as canonical source. Coordinate schema changes in Content Tools first.

Creative authorship remains with humans. Agents may implement and maintain schemas, validation, review workflows, export infrastructure, and runtime integration, but must not author or rewrite lore, descriptions, flavor text, user-facing names, or other creative content. Prompt the user for final wording and preserve user-approved material through mechanical validation, serialization, and generation rather than attempting to improve it.

The required export contract has two phases. Prepare must validate structured content, repository identity, `tgstation.dme`, schema/manifest versions, source revision, content hashes, and the allowed destination. Apply must recheck those facts against a compatible checkout, preserve unrelated changes, and replace the artifact atomically. Verify these guarantees in the current exporter; no external exporter was requalified by this repository's documentation checks. Review the manifest and generated diff before handoff.

The game repository owns compile, runtime, and unit-test acceptance of installed artifacts. If AutoWiki publishing is in scope, verify its current consumer and authorization path separately. Keep wiki credentials out of browser payloads. Catalog loading or a live process is not proof of a valid export or wiki publication.
