https://github.com/AphelionDevelopment/Meridian-Rift/pull/<!--PR Number-->

## Sprint

Module ID: SPRINT

### Description:

Makes running fast and tiring, and walking the default. Two paces instead of three:

- **Walk** (default) - free, and slightly quicker than stock walking now that it is the resting pace.
  Silent footsteps, no slipping, ignores caltrops and holobarriers.
- **Run** (intent toggle) - noticeably faster than it used to be, and spends stamina every tile.

Running is the sprint. There is no separate sprint key or sprint state - toggling to run is the whole
interaction, and the choice is whether the speed is worth the stamina.

Running spends the mob's ordinary stamina, the same pool tasers, shoves and tackles draw from, at 0.4%
of maximum per tile. Mobs with `TRAIT_FREERUNNING` pay 0.7x. Diagonals cost the same as cardinals; they
only fill the dust counter faster. Running kicks up dust - a full cloud on setting off, a smaller puff on
crossing 8 sustained tiles or on turning while sustained, and a tiny puff on doubling back.

At 40% of maximum stamina lost the mob is winded: it gains `TRAIT_NORUNNING`, drops to a walk, and cannot
toggle back to run until it has recovered past 30%. On our 162 point pool that cuts running off at 64.8
loss against a stamina crit threshold of 100, so running alone can never knock a mob out - only running
stacked on top of combat damage will.

Stamina here recovers in one jump once `stamina_regen_time` (10 seconds) passes without further damage,
rather than trickling back, so recovering from winded is a flat cooldown followed by a full refill.

There is no sound on running, only the dust.

### Known scope limits

- Only humans pay for running. Other carbons walk by default but run for free.
- Walking by default means players get walking's benefits without opting in, notably silent footsteps
  and slip immunity, and lose running's, notably climbing `/obj/structure/steps` and
  `/datum/element/skittish`. That is the intended trade, not an oversight.
- Both speed bonuses are flat defines rather than config entries, applied per mob rather than through
  `RUN_DELAY`/`WALK_DELAY` so that borgs and simple animals keep stock speeds. Retune `RUN_SPEED_BONUS`
  and `WALK_SPEED_BONUS` at the top of `sprint_movespeed.dm`.

### TG Proc/File Changes:

- N/A

### Modular Overrides:

- `modular_nova/master_files/code/modules/mob/living/carbon/carbon_defines.dm`: `var/move_intent`
  default changed to `MOVE_INTENT_WALK`
- `modular_nova/master_files/code/modules/mob/living/carbon/human/human.dm`: `proc/Initialize` now
  attaches `/datum/component/sprint`

### Defines:

- N/A - all tuning values are declared and undefined within the module's own files.

### Included files that are not contained in this module:

- N/A

### Credits:

Dust sprites are Goonstation-derived art.
