## Combat reform

Module ID: REFORM_COMBAT

### Description

This module combines humanoid health and damage slowdown tuning with bounded projectile armor penetration.
All balance settings live in `code/__DEFINES/~aphelion_defines/reform_combat.dm`.
Edit the defines and rebuild; no other file needs changing to tune these values.

| Define                                    | Default | Meaning                                                                    |
| ----------------------------------------- | ------- | -------------------------------------------------------------------------- |
| `REFORM_COMBAT_MAX_HEALTH`                | 150     | Standard humanoid maximum health; previously 135.                          |
| `REFORM_COMBAT_SOFT_CRIT_THRESHOLD`       | 0       | Remaining health at soft crit, before runtime modifiers.                   |
| `REFORM_COMBAT_HARD_CRIT_THRESHOLD`       | -30     | Remaining health at hard crit.                                             |
| `REFORM_COMBAT_MAX_STAMINA`               | 162     | Maximum humanoid stamina damage.                                           |
| `REFORM_COMBAT_STAMINA_CRIT_THRESHOLD`    | 135     | Stamina damage at incapacitation, before runtime modifiers.                |
| `REFORM_COMBAT_DAMAGE_SLOWDOWN_THRESHOLD` | 60      | Health or stamina damage at which movement slowdown starts; previously 40. |
| `REFORM_COMBAT_AP_MAX_BYPASS`             | 0.5     | Maximum fraction of armor protection bypassed by projectile AP.            |

Soft and hard crit are remaining-health values, not damage totals. Lower values
delay incapacitation. Keep hard crit below soft crit and above the existing death
threshold of -100. Maximum health and stamina must be positive; AP bypass ranges
from 0 to 1. These are compile-time settings, applied to humanoids on initialization.
Custom humanoid health offsets and existing runtime crit modifiers are preserved.

`REFORM_COMBAT_STAMINA_CRIT_THRESHOLD` is independent of the stamina damage cap.
Its default is 135. Keep it positive and at or below `REFORM_COMBAT_MAX_STAMINA`
so stamina damage can reach it. Changing the cap, maximum health, or configured
soft/hard crit thresholds does not change stamina incapacitation. Runtime soft-crit modifiers,
such as mood, still affect stamina as before. Temporary stamina-cap effects retain
their existing independent behavior; they do not change the configured threshold.

Stamina entry, recovery, and HUD scaling share one threshold proc. No baseline is
stored on each mob. The HUD scales to the actual threshold, including runtime
modifiers. Non-humanoids retain their original health-based threshold calculation.
The stamina effect's initial extra damage checks the mob's actual cap instead of
the old hardcoded 162. Stamina regeneration and diminishing returns are unchanged.

Humanoid damage slowdown starts at `REFORM_COMBAT_DAMAGE_SLOWDOWN_THRESHOLD`,
using the greater of health damage and stamina damage. The default raises its
onset from 40 to 60 damage. Once active, the original `damage / 75` movement-delay
contribution applies. The divisor controls the penalty's growth, independently
of its onset. The threshold is a cutoff, so at 60 damage the penalty starts at
0.8 rather than growing from zero. Other movement modifiers still apply normally.

Projectile protection is `armor * (1 - clamp(AP, 0, 100) / 100 * maximum bypass)`.
With the defaults, 40 AP bypasses 20% of protection and 100+ AP bypasses 50%.

| Armor rating | 0 AP | 40 AP | 100 AP |
| ------------ | ---- | ----- | ------ |
| 30 (III)     | 30%  | 24%   | 15%    |
| 50 (V)       | 50%  | 40%   | 25%    |
| 80 (VIII)    | 80%  | 64%   | 40%    |

Some high armor ratings retain less protection than under the original formula:
80 armor against 40 AP previously retained approximately 66.7%. Coverage, damage
category, existing armor sources, and the projectile damage reduction cap still apply.
Pre-hit AP changes, including hardened armor setting AP to zero, are respected.
The new calculation also supplies armor protection for projectile status effects.
Melee, thrown attacks, objects, separate secondary damage checks, and mobs with
their own projectile armor override retain their existing behavior.

### TG Proc/File Changes

- `code/modules/mob/living/carbon/human/human.dm`: `Initialize` applies combat settings;
  `updatehealth` uses the configured damage slowdown threshold.
- `code/modules/mob/living/carbon/damage_procs.dm`: stamina entry uses the shared threshold.
- `code/datums/status_effects/debuffs/stamcrit.dm`: stamina recovery uses the shared
  threshold; initial extra stamina damage respects the actual cap.
- `code/modules/mob/living/living.dm`: the stamina HUD uses the shared threshold.
- `code/modules/mob/living/living_defense.dm`: `run_armor_check` accepts an optional
  projectile AP flag; `check_projectile_armor` opts in. Silent and visible checks agree.
- `tgstation.dme`: includes the defines and module code.

### Modular Overrides

- `code/health.dm`: humanoid `get_stamina_crit_threshold` specializes the new living proc.

### Defines

All settings, including the independent stamina incapacitation threshold, are in
`code/__DEFINES/~aphelion_defines/reform_combat.dm`.

### Included files that are not contained in this module

- `code/__DEFINES/~aphelion_defines/reform_combat.dm`.

### Credits

Meridian contributors.
