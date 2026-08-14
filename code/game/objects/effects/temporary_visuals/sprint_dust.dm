/// Dust kicked up by a running mob. One per puff, so overlapping puffs do not clobber each other.
/obj/effect/temp_visual/dir_setting/sprint_dust
	icon = 'icons/effects/sprint_dust.dmi'
	icon_state = null
	layer = BELOW_MOB_LAYER

/// Thrown out on setting off at a run. Only drawn facing south.
/obj/effect/temp_visual/dir_setting/sprint_dust/cloud
	icon_state = "sprint_cloud"
	duration = 0.6 SECONDS

/// Thrown out on hitting a sustained stride, or on turning out of one.
/obj/effect/temp_visual/dir_setting/sprint_dust/small
	icon_state = "sprint_cloud_small"
	duration = 0.4 SECONDS

/// Thrown out on doubling back.
/obj/effect/temp_visual/dir_setting/sprint_dust/tiny
	icon_state = "sprint_cloud_tiny"
	duration = 0.3 SECONDS
