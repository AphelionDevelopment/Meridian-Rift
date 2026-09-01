/**
 * Admin window for the server-wide lobby title screen.
 *
 * Replaces the picker that used to live inside the lobby's own HTML menu. That
 * had grown a list, a preset list and two toggles into a single dropdown; a
 * real TGUI window gives the list, a preview and the per-screen controls room
 * to breathe, and lets an admin assemble a look before committing it.
 *
 * Screen selection and presentation are staged until "Apply" writes them
 * through the subsystem, so a half-finished visual experiment is never
 * broadcast to everyone sitting in the lobby. The independent round-rotation
 * preference is applied immediately by its own control.
 */
/datum/title_screen_manager
	/// The admin this window belongs to.
	var/client/owner
	/// Screen the admin is editing, or null for the neutral Meridian master.
	var/draft_screen
	/// False while the live screen is an unmanaged upload with no editable record.
	var/draft_screen_chosen = FALSE
	/// Whether the admin explicitly chose a different screen in this draft.
	var/draft_selection_changed = FALSE
	/// Working copy of that screen's presentation, not yet applied.
	var/list/draft_settings
	/// Saved presentation the working copy started from.
	var/list/draft_baseline_settings
	/// Monotonic draft revision used to snapshot asynchronous confirmations.
	var/draft_generation = 0

/datum/title_screen_manager/New(client/owner)
	. = ..()
	src.owner = owner
	if(owner)
		RegisterSignal(owner, COMSIG_QDELETING, PROC_REF(on_owner_qdel))
	reset_draft()

/datum/title_screen_manager/Destroy(force)
	if(owner)
		UnregisterSignal(owner, COMSIG_QDELETING)
		if(owner.title_screen_manager == src)
			owner.title_screen_manager = null
	owner = null
	return ..()

/datum/title_screen_manager/proc/on_owner_qdel()
	SIGNAL_HANDLER
	qdel(src)

/// Discards the draft and re-reads whatever the server is actually showing.
/datum/title_screen_manager/proc/reset_draft()
	draft_screen_chosen = SStitle.is_current_title_screen_managed()
	draft_screen = draft_screen_chosen ? SStitle.current_title_name : null
	draft_selection_changed = FALSE
	draft_settings = draft_screen_chosen ? SStitle.get_screen_settings(draft_screen) : null
	draft_baseline_settings = draft_screen_chosen ? draft_settings.Copy() : null
	draft_generation++

/// Whether the draft differs from what is live, which is what gates Apply.
/datum/title_screen_manager/proc/has_pending_changes()
	if(!draft_screen_chosen)
		return FALSE
	if(draft_selection_changed)
		return TRUE
	for(var/field in draft_baseline_settings)
		if(draft_settings[field] != draft_baseline_settings[field])
			return TRUE
	return FALSE

/// Whether two complete presentation records carry the same values.
/datum/title_screen_manager/proc/settings_match(list/first, list/second)
	if(!islist(first) || !islist(second))
		return FALSE
	for(var/field in first)
		if(first[field] != second[field])
			return FALSE
	for(var/field in second)
		if(!(field in first))
			return FALSE
	return TRUE

/**
 * Follows server-side rotations and appearance changes while this draft is
 * untouched. A local selection or appearance edit stays intact, with the live
 * marker updating separately in the UI.
 */
/datum/title_screen_manager/proc/sync_clean_draft_to_live()
	if(has_pending_changes())
		return FALSE
	var/live_screen_chosen = SStitle.is_current_title_screen_managed()
	if(draft_screen_chosen != live_screen_chosen)
		reset_draft()
		return TRUE
	if(!live_screen_chosen)
		return FALSE
	if(draft_screen != SStitle.current_title_name || !settings_match(SStitle.get_screen_settings(draft_screen), draft_baseline_settings))
		reset_draft()
		return TRUE
	return FALSE

/// Whether applying this draft must also make its screen the live selection.
/datum/title_screen_manager/proc/draft_requires_selection()
	if(!draft_screen_chosen)
		return FALSE
	return draft_selection_changed || !SStitle.is_current_title_screen_managed() || draft_screen != SStitle.current_title_name

/datum/title_screen_manager/ui_state(mob/user)
	return ADMIN_STATE(TITLE_SCREEN_ADMIN_RIGHTS)

/datum/title_screen_manager/ui_status(mob/user, datum/ui_state/state)
	// Re-checked on every update, not just on open: an admin who is deadminned
	// while the window is up loses it rather than keeping a live control.
	if(isnull(user.client) || !check_rights_for(user.client, TITLE_SCREEN_ADMIN_RIGHTS))
		return UI_CLOSE
	return UI_INTERACTIVE

/datum/title_screen_manager/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		// A closed manager has no visible draft to preserve. Re-read the live
		// screen so a round rotation or another admin's change cannot leave the
		// newly opened window highlighting stale state.
		reset_draft()
		// The window renders every screen at once, so they all go out up front.
		SStitle.send_preview_assets(user.client)
		ui = new(user, src, "TitleScreenManager", "Lobby Title Screen")
		ui.open()

/datum/title_screen_manager/ui_assets(mob/user)
	// The scanline texture the preview composites lives with the lobby art.
	return list(get_asset_datum(/datum/asset/simple/namespaced/lobby_menu_icons))

/datum/title_screen_manager/ui_static_data(mob/user)
	return list(
		// The screen effect. The bezel is a separate switch, so any of these can
		// be shown with or without the rim.
		"variants" = list(
			list("id" = "flat", "name" = "Flat", "desc" = "No curvature or falloff"),
			list("id" = "edge", "name" = "Vignette", "desc" = "Flat glass with a soft edge falloff"),
			list("id" = "convex", "name" = "Convex", "desc" = "Curved CRT glass"),
		),
		"textures" = list(
			list("id" = "none", "name" = "None", "desc" = "No scanlines"),
			list("id" = "original", "name" = "Version 1", "desc" = "First-party scanlines"),
			list("id" = "navarobl", "name" = "Version 2", "desc" = "Licensed scanline texture"),
		),
	)

/datum/title_screen_manager/ui_data(mob/user)
	// The subsystem normally pushes title changes to open managers. This also
	// covers a data request that races the broadcast or follows recovery.
	sync_clean_draft_to_live()
	var/list/settings = draft_screen_chosen ? draft_settings : SStitle.default_screen_settings()
	return list(
		"screens" = SStitle.get_title_screen_options(),
		"markUrl" = SStitle.get_title_screen_preview_url(null),
		"liveScreen" = SStitle.current_title_name,
		"liveScreenManaged" = SStitle.is_current_title_screen_managed(),
		"draftScreen" = draft_screen,
		"draftScreenChosen" = draft_screen_chosen,
		"draftVariant" = settings["variant"],
		"draftBezel" = !!settings["bezel"],
		"draftTexture" = settings["texture"],
		"draftWordmark" = !!settings["wordmark"],
		"rotateTitleScreens" = !!SStitle.rotate_title_screens,
		"pending" = has_pending_changes(),
	)

/datum/title_screen_manager/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	if(isnull(usr.client) || !check_rights_for(usr.client, TITLE_SCREEN_ADMIN_RIGHTS))
		message_admins("[key_name(usr)] tried to change the title screen without the required rights.")
		return TRUE

	switch(action)
		if("select")
			// An empty name is the neutral master, which has no config file.
			var/screen_name = params["screen"]
			if(screen_name == "")
				screen_name = null
			if(!SStitle.is_title_screen_available(screen_name))
				return TRUE
			draft_screen = screen_name
			draft_screen_chosen = TRUE
			draft_selection_changed = !SStitle.is_current_title_screen_managed() || draft_screen != SStitle.current_title_name
			draft_settings = SStitle.get_screen_settings(screen_name)
			draft_baseline_settings = draft_settings.Copy()
			draft_generation++
			return TRUE

		if("set")
			if(!draft_screen_chosen)
				return TRUE
			// One control's new value, merged into the draft rather than applied.
			for(var/field in list("wordmark", "bezel"))
				if(!isnull(params[field]))
					draft_settings[field] = !!params[field]
			if(!isnull(params["variant"]))
				draft_settings["variant"] = params["variant"]
			if(!isnull(params["texture"]))
				draft_settings["texture"] = params["texture"]
			draft_generation++
			return TRUE

		if("set_rotation")
			if(isnull(params["rotate"]))
				return TRUE
			var/rotate = !!params["rotate"]
			if(rotate == SStitle.rotate_title_screens)
				return TRUE
			SStitle.set_title_rotation(rotate)
			var/change = rotate ? "enabled" : "disabled"
			log_admin("[key_name(usr)] [change] lobby title-screen rotation.")
			message_admins("[key_name_admin(usr)] [change] lobby title-screen rotation.")
			return TRUE

		if("revert")
			reset_draft()
			return TRUE

		if("apply")
			apply_draft(usr)
			return TRUE

	return FALSE

/**
 * Confirms, then writes the draft through the subsystem.
 *
 * The prompt sleeps, so the exact draft is snapshotted first. Afterwards it
 * re-checks rights and the draft generation. If the draft changed while its
 * confirmation was open, the stale confirmation is rejected.
 */
/datum/title_screen_manager/proc/apply_draft(mob/user)
	set waitfor = FALSE

	if(!draft_screen_chosen || !islist(draft_settings))
		return
	if(!SStitle.is_title_screen_available(draft_screen))
		to_chat(user, span_warning("That title screen is no longer available; the draft was reset."))
		reset_draft()
		SStgui.update_uis(src)
		return
	var/list/current_settings_before_prompt = SStitle.get_screen_settings(draft_screen)
	if(!settings_match(current_settings_before_prompt, draft_baseline_settings))
		// Another admin changed this screen after the draft was opened. Refresh
		// its appearance instead of treating their change as ours or overwriting
		// it with a stale complete record.
		draft_settings = current_settings_before_prompt.Copy()
		draft_baseline_settings = current_settings_before_prompt.Copy()
		draft_generation++
		to_chat(user, span_warning("This title screen changed elsewhere. Its appearance draft was refreshed; review it and apply again."))
		SStgui.update_uis(src)
		return
	var/screen_to_apply = draft_screen
	var/list/settings_to_apply = draft_settings.Copy()
	var/list/settings_before_prompt = current_settings_before_prompt.Copy()
	// The live screen may have changed since this window's draft was created.
	// Applying an appearance draft still means making its screen the live one,
	// even when no explicit tab click originally had to be staged.
	var/selection_to_apply = draft_requires_selection()
	var/generation_to_apply = draft_generation
	var/live_screen_before_prompt = SStitle.current_title_screen
	var/live_name_before_prompt = SStitle.current_title_name
	var/label = isnull(screen_to_apply) ? "the default Meridian Rift screen" : "\"[screen_to_apply]\""
	var/rotation_state = SStitle.rotate_title_screens ? "enabled" : "disabled"
	var/answer = tgui_alert(
		user,
		"Apply this title screen to everyone? [label] becomes the lobby for every connected player now, and its presentation persists across rounds. Automatic title-screen rotation is currently [rotation_state].",
		"Change the title screen for everyone?",
		list("Apply for everyone", "Cancel"),
		timeout = 30 SECONDS,
	)
	if(answer != "Apply for everyone")
		return
	if(QDELETED(src) || !user.client || !check_rights_for(user.client, TITLE_SCREEN_ADMIN_RIGHTS))
		return
	if(draft_generation != generation_to_apply)
		to_chat(user, span_warning("The title-screen draft changed while confirmation was open. Review it and apply again."))
		SStgui.update_uis(src)
		return
	if(SStitle.current_title_screen != live_screen_before_prompt || SStitle.current_title_name != live_name_before_prompt)
		to_chat(user, span_warning("The live title screen changed while confirmation was open. Review the current state and apply again."))
		SStgui.update_uis(src)
		return
	var/list/current_settings = SStitle.get_screen_settings(screen_to_apply)
	if(!settings_match(current_settings, settings_before_prompt))
		draft_settings = current_settings.Copy()
		draft_baseline_settings = current_settings.Copy()
		draft_generation++
		to_chat(user, span_warning("This title screen's appearance changed while confirmation was open. The draft was refreshed; review it and apply again."))
		SStgui.update_uis(src)
		return

	if(!SStitle.is_title_screen_available(screen_to_apply) || !SStitle.set_screen_settings(screen_to_apply, settings_to_apply))
		to_chat(user, span_warning("That title screen is no longer available; no changes were applied."))
		reset_draft()
		SStgui.update_uis(src)
		return
	if(selection_to_apply)
		SStitle.set_title_selection(screen_to_apply)
	reset_draft()
	SStgui.update_uis(src)

	log_admin("[key_name(user)] applied the lobby title screen [label] for everyone.")
	message_admins("[key_name_admin(user)] applied the lobby title screen [label] for everyone.")

/// Open manager, one per admin; each newly opened window starts from live state.
/client/var/datum/title_screen_manager/title_screen_manager

/**
 * Opens the title screen manager for this client, creating it on first use.
 *
 * Shared by the admin verb and the lobby's own button so both routes land on
 * the same manager. A still-open window keeps its draft; reopening it resets
 * from the title screen that is actually showing.
 */
/client/proc/open_title_screen_manager()
	if(!check_rights_for(src, TITLE_SCREEN_ADMIN_RIGHTS))
		return FALSE
	if(!title_screen_manager)
		title_screen_manager = new(src)
	title_screen_manager.ui_interact(mob)
	return TRUE

ADMIN_VERB(open_title_screen_manager, R_FUN, "Title Screen: Manage", "Pick and style the lobby title screen everyone sees.", ADMIN_CATEGORY_FUN)
	user.open_title_screen_manager()
