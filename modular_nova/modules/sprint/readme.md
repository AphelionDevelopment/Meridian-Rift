https://github.com/AphelionDevelopment/Meridian-Rift/pull/<!--PR Number-->

## Sprint

Module ID: SPRINT

### Description:

Makes running fast and tiring, and walking the default. Two paces instead of three:

- **Walk** (default) - free, and slightly quicker than stock walking now that it is the resting pace.
  Silent footsteps, no slipping, ignores caltrops and holobarriers.
- **Run** (intent toggle) - noticeably faster than it used to be, and spends stamina every tile.

Running spends the mob's ordinary stamina, the same pool tasers, shoves and tackles draw from, at 0.4%
of maximum per tile. Mobs with `TRAIT_FREERUNNING` pay 0.7x. Running kicks up dust - a full cloud on setting off, a smaller puff on
crossing 8 sustained tiles or on turning while sustained, and a tiny puff on doubling back.

At 40% of maximum stamina lost the mob is winded: it gains `TRAIT_NORUNNING`, drops to a walk, and cannot
toggle back to run until it has recovered past 30%. On our 162 point pool that cuts running off at 64.8
loss against a stamina crit threshold of 100, so running alone can never knock a mob out - only running
stacked on top of combat damage will.

### TG Proc/File Changes:

- `code/modules/mob/living/living.dm`: `/mob/living/proc/MobBump` no longer returns early on walk
  intent, so walking bumps, swaps and pushes the way run intent did.

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
