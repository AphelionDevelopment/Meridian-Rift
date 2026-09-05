/**
 * Returns armor protection after projectile AP bypasses a bounded proportion of it.
 *
 * AP is a percentage of the configured maximum bypass, reached at 100 AP.
 *
 * Arguments:
 * * armor - Protection before penetration, including any weakness multiplier.
 * * penetration - Projectile AP, clamped to the range 0 to 100.
 */
/proc/get_projectile_armor_after_penetration(armor, penetration)
	return armor * (1 - clamp(penetration, 0, 100) * 0.01 * REFORM_COMBAT_AP_MAX_BYPASS)
