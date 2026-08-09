https://github.com/AphelionDevelopment/Meridian-Rift/pull/

## Admin Notify

Module ID: ADMIN_NOTIFY

### Description:

Sometimes things move too quickly, or are too surprising, to write a proper adminhelp. This gives
players a "Notify Admins" verb under the OOC tab that pings staff to come and observe, and an
optional hotkey paired to it.

The hotkey is unbound by default and has to be held for two seconds before it fires, so a stray
keypress does not ping the whole staff team. The verb itself is on a two minute cooldown, matching
adminhelp's. Players can be role banned from it with the "Admin Notify ban" ban option, and admins
who would rather not be pinged can turn the alert off in their game preferences.

### TG Proc/File Changes:

- `code/modules/admin/sql_ban_system.dm`: `/datum/admins/proc/ban_panel()` - adds
  `BAN_ADMIN_NOTIFY` to the Nova ban options group

### Modular Overrides:

- N/A

### Defines:

- `code/__DEFINES/~nova_defines/banning.dm`: `BAN_ADMIN_NOTIFY`
- `code/__DEFINES/~nova_defines/keybindings.dm`: `COMSIG_KB_NOTIFYADMINS_DOWN`

### Included files that are not contained in this module:

- `tgui/packages/tgui/interfaces/PreferencesMenu/preferences/features/game_preferences/aphelion/admin_notify.tsx`

### Credits:

- Moonridden
