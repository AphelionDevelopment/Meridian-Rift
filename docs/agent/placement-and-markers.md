# Placement and edit markers

New Meridian-owned content uses this flat layout:

```text
modular_aphelion/modules/<module_id>/code/
modular_aphelion/modules/<module_id>/icons/
modular_aphelion/modules/<module_id>/sound/
modular_aphelion/master_files/<mirrored core path>
```

Do not mirror the core tree inside a module or mix file types. Non-trivial modules use [the Aphelion template](../../modular_aphelion/module_template.md). Shared defines follow the checked-in define organization; file-local defines are declared at the top and `#undef`ed at the bottom. Do not edit tg maps when an automapper can express the change.

Unavoidable core edits use exact module IDs in `SCREAMING_SNAKE_CASE`:

```dm
// APHELION EDIT ADDITION START - MODULE_ID
new_code()
// APHELION EDIT ADDITION END

/* // APHELION EDIT REMOVAL START - MODULE_ID
old_code()
*/ // APHELION EDIT REMOVAL END

// APHELION EDIT CHANGE - MODULE_ID - ORIGINAL: the complete original line
changed_line()
```

Multi-line changes use removal plus addition, not a multi-line change marker. A narrow marked edit is preferable to copying a large upstream proc whose future changes would silently diverge.

`modular_nova` and `NOVA EDIT` remain inherited Nova ownership. Preserve them and do not convert them to Aphelion. New Nova markers are permitted only during an explicit reviewed Nova synchronization using the checker's maintainer-only `--allow-nova-sync` flag. That flag does not change ownership.

Fixes applicable to tgstation should be prepared upstream. If urgency requires a local patch, document the upstream issue/PR and the condition for removing the delta.
