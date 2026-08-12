// Imported savefiles are hostile input, and the load path never calls is_valid().

/// Cap on JSON nesting depth, json_decode has none of its own.
#define PREFS_IMPORT_MAX_DEPTH 24
/// Cap on character slots in an imported file.
#define PREFS_IMPORT_MAX_SLOTS 60
/// Marks a file as waiting on pass 2.
#define PREFS_IMPORT_PENDING_KEY "aphelion_import_pending"
/// Have we already shown them the import notice?
#define PREFS_IMPORT_NOTICE_KEY "aphelion_import_notice_seen"

/// Depth check. Iterative, because recursing a deep tree is its own overflow.
/proc/prefs_import_tree_too_deep(tree)
	if(!islist(tree))
		return FALSE
	// Parallel stacks, DM has no tuple.
	var/list/nodes = list(tree)
	var/list/depths = list(1)
	while(length(nodes))
		var/node = nodes[length(nodes)]
		var/depth = depths[length(depths)]
		nodes.len--
		depths.len--
		if(depth > PREFS_IMPORT_MAX_DEPTH)
			return TRUE
		if(!islist(node))
			continue
		var/list/as_list = node
		for(var/key in as_list)
			// Assoc values live under the key, plain entries ARE the key.
			var/value = key
			if(!isnum(key) && !isnull(as_list[key]))
				value = as_list[key]
			if(!islist(value))
				continue
			nodes += list(value)
			depths += depth + 1
	return FALSE

/// Structural checks. Returns an error string, or null if it's fine.
/proc/prefs_import_prevalidate(list/json_tree, datum/preferences/prefs)
	if(!islist(json_tree) || !length(json_tree))
		return "file is empty or not a savefile"
	var/version = json_tree["version"]
	if(!isnum(version))
		return "missing version"
	// The version defines are #undef'd elsewhere, so use the datum's helper.
	if(prefs?.check_savedata_version(json_tree) == SAVE_DATA_OBSOLETE)
		return "savefile version [version] is too old to be migrated"
	var/slots = 0
	for(var/key in json_tree)
		if(findtext(key, "character") == 1)
			slots++
	if(slots > PREFS_IMPORT_MAX_SLOTS)
		return "too many character slots ([slots])"
	return null

/// Pass 1. Cleans what deserialize() won't. Unknown keys stay, migration reads them.
/proc/prefs_import_pass1(list/json_tree)
	for(var/key in json_tree)
		if(findtext(key, "character") != 1)
			continue
		var/list/slot = json_tree[key]
		if(!islist(slot))
			json_tree[key] = list()
			continue
		slot["loadout_lists"] = prefs_import_clean_loadout_presets(slot["loadout_lists"])
		// Pre-preset savefiles still carry the flat key; migration reads it.
		if("loadout_list" in slot)
			slot["loadout_list"] = prefs_import_clean_loadout(slot["loadout_list"])
		slot["alt_job_titles"] = sanitize_alt_job_titles(slot["alt_job_titles"])
		slot["augments"] = prefs_import_clean_assoc_paths(slot["augments"])
		slot["augment_limb_styles"] = prefs_import_clean_assoc_paths(slot["augment_limb_styles"])
		slot["languages"] = prefs_import_clean_assoc_paths(slot["languages"])
	json_tree[PREFS_IMPORT_PENDING_KEY] = TRUE
	return json_tree

/// loadout_lists is preset -> path -> details, so unwrap a level first.
/proc/prefs_import_clean_loadout_presets(raw)
	if(!islist(raw))
		return list()
	var/list/out = list()
	for(var/preset in raw)
		if(!istext(preset))
			continue
		out[copytext(html_encode(preset), 1, MAX_NAME_LEN)] = prefs_import_clean_loadout(raw[preset])
	return out

/// The UI encodes and caps these, the load path doesn't, so we redo it here.
/proc/prefs_import_clean_loadout(raw)
	if(!islist(raw))
		return list()
	var/list/out = list()
	for(var/path in raw)
		// A number indexes the list instead of keying it, and runtimes.
		if(!istext(path) && !ispath(path))
			continue
		var/list/details = raw[path]
		if(!islist(details))
			out[path] = list()
			continue
		var/list/clean = list()
		for(var/detail_key in details)
			var/value = details[detail_key]
			if(istext(value))
				var/cap = (detail_key == INFO_DESCRIBED) ? MAX_DESC_LEN : MAX_NAME_LEN
				clean[detail_key] = copytext(html_encode(value), 1, cap)
			else if(isnum(value) || islist(value))
				clean[detail_key] = value
		out[path] = clean
	return out

/// We just guarantee the shape, the owning loaders resolve them.
/proc/prefs_import_clean_assoc_paths(raw)
	if(!islist(raw))
		return list()
	var/list/out = list()
	for(var/key in raw)
		if(!istext(key) && !ispath(key))
			continue
		out[key] = raw[key]
	return out

/// Pass 2. Rebuilds every known pref through the validating write path.
/datum/preferences/proc/prefs_import_finalise()
	if(!savefile)
		return FALSE
	if(!savefile.get_entry(PREFS_IMPORT_PENDING_KEY))
		return FALSE

	var/list/player_prefs = list()
	var/list/character_prefs = list()
	for(var/key in GLOB.preference_entries_by_key)
		var/datum/preference/preference = GLOB.preference_entries_by_key[key]
		if(isnull(preference))
			continue
		switch(preference.savefile_identifier)
			if(PREFERENCE_PLAYER)
				player_prefs += preference
			if(PREFERENCE_CHARACTER)
				character_prefs += preference

	var/list/counts = list("rebuilt" = 0, "reset" = 0)

	// Player scope lives at the root, one pass covers it.
	prefs_import_rebuild(player_prefs, counts)

	// Character scope goes through default_slot, so we visit each slot.
	var/original_slot = default_slot
	var/slots = 0
	var/list/tree = savefile.get_entry()
	if(islist(tree))
		for(var/tree_key in tree)
			if(findtext(tree_key, "character") != 1)
				continue
			var/slot_number = text2num(copytext(tree_key, 10))
			if(!isnum(slot_number) || !islist(tree[tree_key]))
				continue
			default_slot = slot_number
			prefs_import_forget(character_prefs)
			prefs_import_strip_empty_loadout_keys(tree[tree_key])
			prefs_import_rebuild(character_prefs, counts)
			slots++

	default_slot = original_slot
	prefs_import_forget(character_prefs)
	savefile.set_entry("default_slot", original_slot)

	prefs_import_prune_unknown()
	savefile.remove_entry(PREFS_IMPORT_PENDING_KEY)
	savefile.save()

	log_game("Preferences import finalised for [parent?.ckey]: [slots] slot\s, [counts["rebuilt"]] preferences rebuilt, [counts["reset"]] reset to defaults.")
	return TRUE

/// Round-trips each pref through the write path, tallying as we go.
/datum/preferences/proc/prefs_import_rebuild(list/preferences, list/counts)
	for(var/datum/preference/preference as anything in preferences)
		var/value
		var/usable = FALSE
		try
			value = read_preference(preference.type)
			usable = !isnull(value) && preference.is_valid(value, src)
		catch
			usable = FALSE
		var/written
		if(usable)
			// write_preference deserialises, so hand it the serialised form back.
			written = write_preference(preference, preference.serialize(value))
		else
			written = write_preference(preference, preference.create_informed_default_value(src))
			counts["reset"]++
		if(written)
			counts["rebuilt"]++

/// Drops cached values so the next read hits the new slot.
/datum/preferences/proc/prefs_import_forget(list/preferences)
	for(var/datum/preference/preference as anything in preferences)
		value_cache -= preference.type

/// Migration leaves null keys behind, and sanitize_loadout_list stack_traces on them.
/proc/prefs_import_strip_empty_loadout_keys(list/slot)
	// Runs post-migration: presets are the live shape, the flat key may linger.
	prefs_import_strip_empty_keys(slot, "loadout_list")
	var/list/presets = slot["loadout_lists"]
	if(!islist(presets))
		return
	for(var/preset in presets)
		prefs_import_strip_empty_keys(presets, preset)

/// Drops null and empty keys from one loadout list, in place.
/proc/prefs_import_strip_empty_keys(list/holder, key)
	var/list/loadout = holder[key]
	if(!islist(loadout))
		return
	var/list/clean = list()
	for(var/path in loadout)
		if(isnull(path) || (istext(path) && !length(path)))
			continue
		clean[path] = loadout[path]
	if(length(clean) != length(loadout))
		holder[key] = clean

/// Only out-of-range slots go. load_preferences scans these names, other junk is inert.
/datum/preferences/proc/prefs_import_prune_unknown()
	var/list/tree = savefile.get_entry()
	if(!islist(tree))
		return
	var/list/dropped = list()

	for(var/key in tree)
		if(findtext(key, "character") != 1)
			continue
		var/slot_number = text2num(copytext(key, 10))
		if(isnum(slot_number) && slot_number >= 1 && slot_number <= PREFS_IMPORT_MAX_SLOTS)
			continue
		dropped += key

	for(var/key in dropped)
		tree -= key

	if(!length(dropped))
		return
	log_game("Preferences import dropped [length(dropped)] out-of-range character slot\s for [parent?.ckey]: [jointext(dropped, ", ")]")

// Not #undef'd on purpose, the import verb reads these.
