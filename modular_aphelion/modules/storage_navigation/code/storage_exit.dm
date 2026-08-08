/**
 * The X button on the storage UI, sat next to the back arrow.
 *
 * Closes the storage UI outright, no matter how deep into nested containers the
 * viewer has browsed. The arrow beside it only steps back out one container.
 */
/atom/movable/screen/storage_exit
	name = "close"
	plane = ABOVE_HUD_PLANE
	icon = 'icons/hud/screen_midnight.dmi'
	icon_state = "storage_exit"
	mouse_over_pointer = MOUSE_HAND_POINTER
	hud_group_key = HUD_GROUP_STORAGE

/atom/movable/screen/storage_exit/Initialize(mapload, datum/hud/hud_owner, new_master)
	. = ..()
	master_ref = WEAKREF(new_master)

/atom/movable/screen/storage_exit/Click()
	var/datum/storage/storage = master_ref?.resolve()
	if(!storage)
		return
	storage.hide_contents(usr)
	return TRUE

/**
 * Hands the storage UI over to the storage holding our parent, if there is one.
 *
 * Backs a viewer out of a container into the container it sits in, rather than closing
 * the UI entirely. Only one storage is ever shown at a time, so opening the enclosing
 * storage is what hides us.
 *
 * Arguments:
 * * user - the mob whose storage UI we are moving
 *
 * Returns TRUE if an enclosing storage was opened, FALSE if there was none to open.
 */
/datum/storage/proc/open_enclosing_storage(mob/user)
	if(user.active_storage != src)
		return FALSE

	var/atom/container = parent.loc
	if(!isobj(container))
		return FALSE

	var/datum/storage/enclosing = container.atom_storage
	if(isnull(enclosing) || enclosing == src)
		return FALSE

	return enclosing.open_storage(user)
