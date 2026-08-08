/**
 * The X button on the storage UI, sat next to the back arrow.
 *
 * Closes the storage UI outright, no matter how deep into nested containers the
 * viewer has browsed. The arrow beside it only steps back out one container.
 */
/atom/movable/screen/storage_exit
	name = "close"
	plane = ABOVE_HUD_PLANE
	/// One state per UI style, each named for its key in [GLOB.available_ui_styles].
	/// set_ui_style() picks between them, until then this falls back to the icon's first state.
	icon = 'modular_aphelion/modules/storage_navigation/icons/storage_exit.dmi'
	mouse_over_pointer = MOUSE_HAND_POINTER
	hud_group_key = HUD_GROUP_STORAGE

/atom/movable/screen/storage_exit/Initialize(mapload, datum/hud/hud_owner, new_master)
	. = ..()
	master_ref = WEAKREF(new_master)

/**
 * Themes this button to a UI style.
 *
 * The storage interface stamps its style's icon file onto every element it owns, which would take
 * this button's own icon with it, so this puts both the icon and the state back. A style we have no
 * sprite for falls back to the default style rather than rendering blank.
 *
 * Arguments:
 * * ui_style - the icon file of the UI style being applied
 */
/atom/movable/screen/storage_exit/proc/set_ui_style(ui_style)
	var/static/list/style_names_by_icon
	if(isnull(style_names_by_icon))
		style_names_by_icon = list()
		for(var/style_name in GLOB.available_ui_styles)
			style_names_by_icon[GLOB.available_ui_styles[style_name]] = style_name

	icon = /atom/movable/screen/storage_exit::icon
	var/style_name = style_names_by_icon[ui_style]
	icon_state = icon_exists(icon, style_name) ? style_name : GLOB.available_ui_styles[1]

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
