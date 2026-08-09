https://github.com/Skyrat-SS13/Skyrat-tg/pull/872

## Title: More verbs and subtler.

MODULE ID: VERBS

### Description:

Adds a few emotes and verbs for players to use, such as LOOC, subtle, and Notify Admins.

### TG Proc Changes:

- code\modules\admin\sql_ban_system.dm - adds BAN_ADMIN_NOTIFY to the Nova ban options group

### Defines:

- #define CHAT_LOOC (1<<12)
- #define CHAT_LOOC_ADMIN (1<<13)
- #define LOG_SUBTLER (1 << 20)
- #define BAN_ADMIN_NOTIFY "Admin Notify ban"
- #define COMSIG_KB_NOTIFYADMINS_DOWN "keybinding_notify_admins_down"

### Master file additions

- D:\Documents\Github\SS13\Skyrat-tg\modular_nova\master_files\code_globalvars\configuration.dm
- modular_nova\master_files\code\modules\client\preferences\admin_notify.dm

### Included files that are not contained in this module:

- N/A

### Credits:

Gandalf2k15 - porting and refactoring

Moonridden - Notify Admins
