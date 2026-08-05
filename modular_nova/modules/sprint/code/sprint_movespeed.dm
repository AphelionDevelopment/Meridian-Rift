/// Move delay removed while running, on top of the configured run delay of 1.5.
#define RUN_SPEED_BONUS -0.2
/// Move delay removed while walking, on top of the configured walk delay of 4.
#define WALK_SPEED_BONUS -1

/// Speedup applied while on run intent.
/datum/movespeed_modifier/run_pace
	multiplicative_slowdown = RUN_SPEED_BONUS

/// Speedup applied while on walk intent, since walking is now the default pace.
/datum/movespeed_modifier/walk_pace
	multiplicative_slowdown = WALK_SPEED_BONUS

#undef RUN_SPEED_BONUS
#undef WALK_SPEED_BONUS
