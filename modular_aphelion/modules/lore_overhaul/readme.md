https://github.com/AphelionDevelopment/Meridian-Rift/pull/

## Lore Overhaul content pipeline contract

Module ID: LORE_OVERHAUL

### Description:

Establishes the runtime contract for lore-overhaul entries generated from human-authored source
data in the external `AphelionDevelopment/aphelion-content-tools` repository.

`modular_aphelion/modules/lore_overhaul/code/generated_lore_overrides.dm` is generator-owned and
must be regenerated from the JSON source; it is never edited by hand.

`/datum/lore_overhaul_entry` is the shared runtime datum for future lore import and AutoWiki
adapter work.

Module files:
- `modular_aphelion/modules/lore_overhaul/code/lore_entry.dm`
- `modular_aphelion/modules/lore_overhaul/code/catalog_probe.dm` (catalog export probe)
- `modular_aphelion/modules/lore_overhaul/code/autowiki.dm`
- `modular_aphelion/modules/lore_overhaul/code/autowiki_tests.dm` (unit-test build only)
- `modular_aphelion/modules/lore_overhaul/code/generated_lore_overrides.dm`
- `modular_aphelion/modules/lore_overhaul/icons/.gitkeep`
- `modular_aphelion/modules/lore_overhaul/sound/.gitkeep`

### TG Proc/File Changes:

- `tgstation.dme`: include the lore module code files exactly once.
- `code/modules/autowiki/autowiki.dm`: marked `LORE_OVERHAUL` addition skips the adapter base type so only generated page subtypes are published.

### Modular Overrides:

- N/A

### Defines:

- N/A

### External source and export tool

The canonical source, catalog, browser editor, reviews, groups, and validation code live in
`https://github.com/AphelionDevelopment/aphelion-content-tools`. The game repository intentionally keeps
only this runtime module and the generated DM artifact. A maintainer prepares and validates an export in
the external tool, then applies it to a clean game checkout. The export writes only
`modular_aphelion/modules/lore_overhaul/code/generated_lore_overrides.dm`.

### Writer workflow

Writers start Aphelion Content Tools through its shipped launcher. They search the catalog,
filter by the pre-populated lore groups, and use the Configuration tab to
maintain group labels, keywords, type-path prefixes, and colors. Directional and redundant subtype
entries are hidden until their visibility toggles are enabled.

Review decisions are independent of content overrides: **Mark reviewed** approves the current base
entry, while **Flag needs attention** creates a writer-owned action item. Overrides can change names,
descriptions, special examine descriptions and their requirements, icon references, and AutoWiki metadata.
Item-like targets support the optional special-description fields, which map to the existing
`EXAMINE_CHECK_*` constants; role, job, and faction requirements use the target's existing lists.
Named-datum targets, such as languages, do not support these fields. The icon editor displays the base asset and
override asset independently and supports DMI files under `icons/`, `modular_nova/modules/*/icons/`,
`modular_nova/master_files/icons/`, and `modular_aphelion/modules/*/icons/`.

The external editor validates the complete JSON corpus before preparing an export. Its Tools panel runs
catalog refresh, validation, generation, and combined refresh/validation while streaming output and
writing bounded local logs. Review the prepared manifest and generated game-repository diff before
submitting.

The review API pages broad result sets in 500-entry batches so changing filters does not render the
entire catalog at once. Its catalog classification index is reused until `targets.json` or
`groups.json` changes, while writer edits remain visible on the next request.

The target catalog is refreshed explicitly from the external tool after a successful catalog probe. The
probe covers all concrete `/obj/item` and
`/obj/machinery` descendants plus languages and species, so configurable groups can find company
references in ordinary objects and machines. Group keywords use whole-word or type-path-segment
matching and ignore icon metadata; each review entry reports the fields that caused its group
matches. Icon records retain only their selected file and state. The editor loads available states
from the DMI on demand instead of repeating the full state list on every target. AutoWiki templates
and optional icon assets are generated from the same source and compiled values, while publication
remains CI-only. This module does not contain credentials or a browser publishing path, and
generated template pages are not edited manually.

### Credits:

- Codex
