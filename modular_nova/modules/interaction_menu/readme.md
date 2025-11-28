## Title: INTERACTION MENU

### Description:

The Ctrl+Shift click interaction panel: the `/datum/interaction` definitions, the `/datum/component/interactable`
that drives the TGUI panel, and `/datum/interaction_route`.

A route describes how an interaction is reaching its target when it isn't happening face to face - something is
standing in for them somewhere else. The base datum knows nothing about what that something is; modules that can
represent a person at a distance subclass `/datum/interaction_route` and override `/atom/movable/interaction_route_for()`
on the stand-in. The lewd_items module's portal relays are the current implementation.

### TG Proc/File Changes:

- N/A

### Defines:

- N/A

### Master file additions

- N/A

### Included files that are not contained in this module:

- N/A

### Credits:
