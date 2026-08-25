## Medical Projection System

Module ID: MEDICAL_PROJECTION_SYSTEM

### Description

Adds a station-wide, manually maintained emergency-care network.

- Medical staff fulfill a rotating reagent or organ request at the Lifeline synthesis reservoir.
- Existing DeForest first aid stations use the shared reservoir to refill Lifeline field sprayers.
- Sprayers can heal one random damage type and wound at low efficiency.
- Sprayers can temporarily stabilize a critical patient for transport without healing the patient or allowing hand use.
- Sprayers can project a temporary stasis cocoon with an audible recovery beacon; the projection dissolves when opened.
- The reservoir does not support plumbing or unattended reagent transfer.

### TG Proc/File Changes

- `code/game/machinery/wall_healer.dm`: Extends `/obj/machinery/wall_healer/add_context()` and `/obj/machinery/wall_healer/item_interaction()` with field sprayer refills.

### Modular Overrides

- N/A

### Defines

- `LIFELINE_MODE_HEAL`, `LIFELINE_MODE_STABILIZE`, and `LIFELINE_MODE_STASIS` are local to `medical_projection_system.dm`.

### Included files that are not contained in this module

- `tgstation.dme`: Includes the module code.

### Credits

- Original implementation for Meridian Rift.
