https://github.com/AphelionDevelopment/Meridian-Rift/pull/

## Storage UI back navigation

Module ID: STORAGE_NAVIGATION

### Description:

The storage UI's arrow used to close the UI outright. It now steps back out into the container
holding the one you are looking at, so browsing a box inside a backpack and clicking the arrow puts
you back in the backpack. If there is nothing to step back into, it closes as before.

A new X button sits next to the arrow. It always closes the storage UI, however deep you have
browsed. Its sprite is built from each UI style's own `storage_close` button, so it themes with the
rest of the HUD.

### TG Proc/File Changes:

- `code/_onclick/hud/screen_objects/screen_objects.dm`: `/atom/movable/screen/close/Click()`
- `code/datums/storage/storage_interface.dm`: `var/exit_button`, `New()`, `proc/list_ui_elements()`,
  `Destroy()`, `proc/update_position()`
- `icons/hud/screen_midnight.dmi`, `screen_retro.dmi`, `screen_plasmafire.dmi`, `screen_slimecore.dmi`,
  `screen_operative.dmi`, `screen_clockwork.dmi`, `screen_glass.dmi`, `screen_trasenknox.dmi`,
  `screen_detective.dmi`: added the `storage_exit` state

### Modular Overrides:

- N/A

### Defines:

- `code/__DEFINES/~nova_defines/hud.dm`: `STORAGE_UI_BUTTON_WIDTH`

### Included files that are not contained in this module:

- N/A

### Credits:

- pepe
