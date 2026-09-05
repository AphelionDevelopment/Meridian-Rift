// Name must differ from the admin verb, BYOND keys the verb panel on it and they collide.
GAME_VERB_PROC_DESC(/client, import_preferences, "Import Character Preferences", "Upload a character preferences JSON file, replacing your current one.", "OOC")
	if(preferences_import_in_progress)
		to_chat(src, span_warning("A preferences import is already in progress."))
		return
	preferences_import_in_progress = TRUE
	var/imported = FALSE
	try
		imported = prefs_import_upload()
	catch(var/exception/error)
		log_game("Preferences import for [ckey] failed: [error]")
		to_chat(src, span_warning("The preferences import failed. Please notify an administrator."))
	if(src && !imported)
		preferences_import_in_progress = FALSE

/// The verb holds its lock across every prompt and query, including early returns.
/client/proc/prefs_import_upload()

	if(CONFIG_GET(flag/forbid_preferences_import))
		to_chat(src, span_warning("Preference importing is disabled on this server."))
		return

	if(!prefs)
		to_chat(src, span_warning("Your preferences are not loaded yet. Try again in a moment."))
		return

	if(is_guest_key(key)) // key, not ckey - ckey() eats the hyphen is_guest_key looks for
		to_chat(src, span_warning("Guest accounts cannot import preferences."))
		return

	var/datum/preferences/import_prefs = prefs
	if(!prefs_import_available(import_prefs))
		return

	if(world.time < persistent_client.next_preferences_import)
		var/wait_seconds = round((persistent_client.next_preferences_import - world.time) / 10)
		to_chat(src, span_warning("Please wait [wait_seconds] more second\s before importing again."))
		return

	to_chat(src, span_boldwarning("This REPLACES all of your current characters with the contents of the uploaded file."))
	var/confirm = tgui_alert(
		mob,
		"Replace all of your characters with an uploaded file? A backup of your current preferences is kept. You will be disconnected to finish.",
		"Import Character Preferences",
		list("Import", "Cancel"),
	)
	if(confirm != "Import")
		return

	if(!prefs_import_available(import_prefs))
		return

	var/uploaded_file = input(mob, "Choose a preferences JSON file", "Import Character Preferences") as null|file
	if(!isfile(uploaded_file) || !length(uploaded_file))
		return

	// input(as file) yields too. Permissions and even this client may have changed.
	if(!prefs_import_available(import_prefs))
		return
	if(world.time < persistent_client.next_preferences_import)
		return
	var/cooldown = CONFIG_GET(number/seconds_cooldown_for_preferences_import)
	persistent_client.next_preferences_import = world.time + (cooldown SECONDS)

	if(!findtext("[uploaded_file]", ".json", -5))
		to_chat(src, span_warning("That is not a .json file."))
		return

	var/filesize = length(uploaded_file)
	var/size_limit = CONFIG_GET(number/savefile_upload_limit) * 1024
	if(filesize > size_limit)
		to_chat(src, span_warning("That file is too large ([round(filesize / 1024)] KB; the limit is [round(size_limit / 1024)] KB)."))
		return

	var/raw = file2text(uploaded_file)
	if(!length(raw))
		to_chat(src, span_warning("That file was empty or unreadable."))
		return

	var/list/json_tree
	try
		json_tree = json_decode(raw)
	catch(var/exception/err)
		to_chat(src, span_warning("That file is not valid JSON."))
		log_game("Preferences import by [ckey] failed to parse: [err]")
		return

	// Depth goes on the decoded tree, a text scan first is slower than decoding.
	if(prefs_import_tree_too_deep(json_tree))
		to_chat(src, span_warning("That file is nested too deeply to be a preferences file."))
		log_admin("[key_name(src)] attempted a preferences import with excessive JSON nesting.")
		return

	var/problem = prefs_import_prevalidate(json_tree, prefs)
	if(problem)
		to_chat(src, span_warning("That file was rejected: [problem]."))
		return

	json_tree = prefs_import_pass1(json_tree, import_prefs.savefile.get_entry())

	if(!prefs_import_available(import_prefs))
		return
	// A commendation may have arrived during the final entitlement query.
	json_tree["hearted_until"] = import_prefs.hearted_until

	var/folder_path = "data/player_saves/[ckey[1]]/[ckey]"
	var/savefile_path = "[folder_path]/preferences.json"

	if(!prefs_import_backup(savefile_path))
		to_chat(src, span_warning("Could not back up your existing preferences. Nothing was changed."))
		return

	var/install_error = prefs_import_replace(savefile_path, json_encode(json_tree))
	if(install_error)
		to_chat(src, span_warning("Could not install the imported preferences: [install_error]."))
		log_game("Preferences import for [ckey] was not installed: [install_error]")
		return

	// Else the still-connected client writes its stale prefs over the import.
	GLOB.preferences_datums[ckey] = null

	log_admin("[key_name(src)] imported their own preferences ([filesize] bytes).")
	message_admins("[key_name(src)] imported their own preferences via the whitelisted-player import.")

	to_chat(src, span_boldnotice("Preferences imported. You will be disconnected now; reconnect to finish."))
	to_chat(src, span_notice("Anything the server could not accept will be reset to a default when you return."))
	QDEL_IN(src, 2)
	return TRUE

/// The role query may sleep; perform all non-sleeping state checks after it returns.
/client/proc/prefs_import_available(datum/preferences/import_prefs)
	if(!src || prefs != import_prefs || !persistent_client)
		return FALSE
	// The entitlement version, not the lobby gate: disabling Symphony grants no role.
	var/has_role = symphony_holds_whitelist_role(ckey)
	if(!src || prefs != import_prefs || GLOB.preferences_datums[ckey] != import_prefs || GLOB.directory[ckey] != src || persistent_client?.client != src)
		return FALSE
	if(!has_role || !CONFIG_GET(flag/symphony_enabled) || CONFIG_GET(flag/forbid_preferences_import))
		to_chat(src, span_warning("Importing is no longer available. It requires the whitelist role and must be enabled on this server."))
		return FALSE
	return TRUE

/// Write and verify the candidate before touching the destination. Returns an error, or null on success.
/proc/prefs_import_replace(savefile_path, contents)
	var/candidate_path = "[savefile_path].importtmp"
	var/restore_path = "[savefile_path].importrestore"
	if(fexists(restore_path))
		return "a recovery backup from an earlier failed import needs administrator attention"
	if(fexists(candidate_path) && !fdel(candidate_path))
		return "could not clear the temporary candidate file"
	if(!text2file(contents, candidate_path))
		return "could not write the temporary candidate file"
	// text2file appends a newline. Compare the parsed content, then retain the exact bytes for copying.
	var/candidate_contents = file2text(candidate_path)
	var/candidate_valid = FALSE
	try
		candidate_valid = json_encode(json_decode(candidate_contents)) == json_encode(json_decode(contents))
	catch
		candidate_valid = FALSE
	if(!candidate_valid)
		fdel(candidate_path)
		return "the temporary candidate failed verification"

	var/had_original = fexists(savefile_path)
	var/original_contents
	if(had_original)
		original_contents = file2text(savefile_path)
		if(isnull(original_contents))
			fdel(candidate_path)
			return "could not read the previous preferences for recovery"
		if(!fcopy(savefile_path, restore_path) || file2text(restore_path) != original_contents)
			fdel(candidate_path)
			return "could not create a verified recovery backup"

	// fcopy replaces existing files; never delete the live file before a write.
	if(!fcopy(candidate_path, savefile_path) || file2text(savefile_path) != candidate_contents)
		var/restored = had_original ? (fcopy(restore_path, savefile_path) && file2text(savefile_path) == original_contents) : (!fexists(savefile_path) || fdel(savefile_path))
		fdel(candidate_path)
		if(!restored)
			return "replacement failed; the recovery backup was retained for administrator recovery"
		fdel(restore_path)
		return "replacement failed and the previous preferences were restored"

	fdel(candidate_path)
	fdel(restore_path)
	fdel("[savefile_path].updatebac")
	return null

/// Stashes a copy of the savefile, oldest one drops off the end.
/proc/prefs_import_backup(savefile_path)
	if(!fexists(savefile_path))
		return TRUE // nothing to back up, which is fine
	var/limit = CONFIG_GET(number/preferences_import_backup_limit)
	var/list/existing = list()
	for(var/i = 1 to limit)
		var/candidate = "[savefile_path].importbac-[i]"
		if(fexists(candidate))
			existing += candidate
	if(length(existing) >= limit)
		for(var/i = 2 to limit)
			var/from_path = "[savefile_path].importbac-[i]"
			if(!fexists(from_path))
				continue
			if(!fcopy(from_path, "[savefile_path].importbac-[i - 1]"))
				return FALSE
	var/slot = min(length(existing) + 1, limit)
	return fcopy(savefile_path, "[savefile_path].importbac-[slot]")

/client
	/// Held across every import prompt and query, until cancellation or disconnect.
	var/preferences_import_in_progress = FALSE

/datum/persistent_client
	/// world.time before another attempt; survives reconnecting and replacing the preferences datum.
	var/next_preferences_import = 0
