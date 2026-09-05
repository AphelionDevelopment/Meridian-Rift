/// Standard humanoid maximum health. Original: 135. Custom subtype health offsets are preserved.
#define REFORM_COMBAT_MAX_HEALTH 150
/// Remaining health at which humanoids enter soft crit. Original: 0. Lower values delay crit.
#define REFORM_COMBAT_SOFT_CRIT_THRESHOLD 0
/// Remaining health at which humanoids enter hard crit. Original: -30. Keep below soft crit and above death (-100).
#define REFORM_COMBAT_HARD_CRIT_THRESHOLD -30
/// Humanoid stamina damage cap. Original: 162. Independent of maximum health.
#define REFORM_COMBAT_MAX_STAMINA 162

/// Stamina damage at incapacitation before runtime modifiers. Original: 135. Independent of the cap; keep positive and at or below it.
#define REFORM_COMBAT_STAMINA_CRIT_THRESHOLD 135
/// Health or stamina damage at which humanoid movement slowdown starts. Original: 40. Higher values delay slowdown.
#define REFORM_COMBAT_DAMAGE_SLOWDOWN_THRESHOLD 60
/// Maximum fraction of protection bypassed by 100 AP. Original AP could bypass all protection.
#define REFORM_COMBAT_AP_MAX_BYPASS 0.5
