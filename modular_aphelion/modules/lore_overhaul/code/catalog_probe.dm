#ifdef LORE_CATALOG
#define LORE_CATALOG_OUTPUT_PATH "data/lore_overhaul_targets.json"
#define LORE_CATALOG_PROFILE_ATOM_LIKE "atom_like"
#define LORE_CATALOG_PROFILE_NAMED_DATUM "named_datum"
#define LORE_CATALOG_ROOT_TYPE_PATH "type_path"
#define LORE_CATALOG_ROOT_FIELD_PROFILE "field_profile"

/**
 * Queue the lore-overhaul catalog probe for unattended startup.
 *
 * The probe is opt-in behind `LORE_CATALOG` and writes a standalone JSON catalog for the external
 * external lore editor to validate before replacing its committed catalog snapshot.
 */
/proc/setup_lore_catalog()
	Master.sleep_offline_after_initializations = FALSE
	SSticker.OnRoundstart(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(generate_lore_catalog)))
	SSticker.start_immediately = TRUE
	CONFIG_SET(number/round_end_countdown, 0)

/**
 * Generate and write the lore-overhaul target catalog, then terminate the unattended run.
 */
/proc/generate_lore_catalog()
	rustg_file_write(generate_lore_catalog_output(), LORE_CATALOG_OUTPUT_PATH)
	qdel(world)

/**
 * Return the complete JSON target catalog emitted by the conditional BYOND probe.
 */
/proc/generate_lore_catalog_output()
	var/list/output_targets = list()
	var/list/seen_targets = list()

	for (var/list/root_config as anything in get_lore_catalog_root_configs())
		var/datum/editable_root = root_config[LORE_CATALOG_ROOT_TYPE_PATH]
		var/field_profile = root_config[LORE_CATALOG_ROOT_FIELD_PROFILE]
		var/list/target_types = valid_typesof(editable_root)
		if (editable_root == /datum/species)
			target_types = valid_subtypesof(editable_root)
		for (var/datum/target_type as anything in sort_list(target_types, GLOBAL_PROC_REF(cmp_typepaths_asc)))
			if (seen_targets[target_type])
				continue
			seen_targets[target_type] = TRUE
			output_targets += list(build_lore_catalog_target(target_type, editable_root, field_profile))

	return json_encode(output_targets)

/proc/get_lore_catalog_root_configs()
	return list(
		list(
			LORE_CATALOG_ROOT_TYPE_PATH = /datum/language,
			LORE_CATALOG_ROOT_FIELD_PROFILE = LORE_CATALOG_PROFILE_NAMED_DATUM,
		),
		list(
			LORE_CATALOG_ROOT_TYPE_PATH = /datum/species,
			LORE_CATALOG_ROOT_FIELD_PROFILE = LORE_CATALOG_PROFILE_NAMED_DATUM,
		),
		list(
			LORE_CATALOG_ROOT_TYPE_PATH = /obj/item,
			LORE_CATALOG_ROOT_FIELD_PROFILE = LORE_CATALOG_PROFILE_ATOM_LIKE,
		),
		list(
			LORE_CATALOG_ROOT_TYPE_PATH = /obj/machinery,
			LORE_CATALOG_ROOT_FIELD_PROFILE = LORE_CATALOG_PROFILE_ATOM_LIKE,
		),
	)

/proc/build_lore_catalog_target(datum/target_type, datum/editable_root, field_profile)
	return list(
		"type_path" = "[target_type]",
		"label" = build_lore_catalog_label(target_type, field_profile),
		"editable_root" = "[editable_root]",
		"parent_type" = "[target_type.parent_type]",
		"field_profile" = field_profile,
		"base_values" = build_lore_catalog_base_values(target_type, field_profile),
		"icon_metadata" = build_lore_catalog_icon_metadata(target_type, field_profile),
	)

/proc/build_lore_catalog_label(datum/target_type, field_profile)
	var/label = build_lore_catalog_name(target_type, field_profile)
	if (istext(label) && length(label))
		return label

	var/list/path_segments = splittext("[target_type]", "/")
	return capitalize(replacetext(path_segments[path_segments.len], "_", " "))

/proc/build_lore_catalog_name(datum/target_type, field_profile)
	if (field_profile == LORE_CATALOG_PROFILE_ATOM_LIKE)
		var/atom/atom_type = target_type
		return initial(atom_type.name)

	if (field_profile == LORE_CATALOG_PROFILE_NAMED_DATUM)
		if (ispath(target_type, /datum/species))
			var/datum/species/species_type = target_type
			return initial(species_type.name)
		var/datum/language/language_type = target_type
		return initial(language_type.name)

	return null

/proc/normalize_lore_catalog_description(description)
	if (islist(description))
		return jointext(description, "\n\n")
	return description

/proc/build_lore_catalog_base_values(datum/target_type, field_profile)
	var/name = build_lore_catalog_name(target_type, field_profile)
	var/description
	if (field_profile == LORE_CATALOG_PROFILE_ATOM_LIKE)
		var/atom/atom_type = target_type
		description = initial(atom_type.desc)
	else if (field_profile == LORE_CATALOG_PROFILE_NAMED_DATUM)
		if (ispath(target_type, /datum/species))
			var/datum/species/species_type = new target_type
			description = normalize_lore_catalog_description(species_type.get_species_description())
			qdel(species_type)
		else
			var/datum/language/language_type = target_type
			description = initial(language_type.desc)

	return list(
		"name" = name,
		"description" = description,
	)

/proc/build_lore_catalog_icon_metadata(datum/target_type, field_profile)
	var/list/icon_metadata = list()
	if (field_profile != LORE_CATALOG_PROFILE_ATOM_LIKE)
		return icon_metadata

	var/atom/atom_type = target_type
	var/list/icon_record = build_lore_catalog_icon_record(initial(atom_type.icon), initial(atom_type.icon_state))
	if (icon_record)
		icon_metadata["icon"] = icon_record

	if (!ispath(target_type, /obj/item))
		return icon_metadata

	var/obj/item/item_type = target_type
	var/list/worn_icon_record = build_lore_catalog_icon_record(initial(item_type.worn_icon), initial(item_type.worn_icon_state))
	if (worn_icon_record)
		icon_metadata["worn_icon"] = worn_icon_record

	var/inhand_icon_file = initial(item_type.lefthand_file) || initial(item_type.righthand_file)
	var/list/inhand_icon_record = build_lore_catalog_icon_record(inhand_icon_file, initial(item_type.inhand_icon_state))
	if (inhand_icon_record)
		icon_metadata["inhand_icon"] = inhand_icon_record

	return icon_metadata

/proc/build_lore_catalog_icon_record(icon_file, icon_state)
	if (isnull(icon_file) || isnull(icon_state))
		return null

	var/icon_state_text = "[icon_state]"
	if (!length(icon_state_text))
		return null

	return list(
		"file" = replacetext("[icon_file]", "\\", "/"),
		"state" = icon_state_text,
	)

/world/RunUnattendedFunctions()
	..()
	setup_lore_catalog()

#undef LORE_CATALOG_OUTPUT_PATH
#undef LORE_CATALOG_PROFILE_ATOM_LIKE
#undef LORE_CATALOG_PROFILE_NAMED_DATUM
#undef LORE_CATALOG_ROOT_TYPE_PATH
#undef LORE_CATALOG_ROOT_FIELD_PROFILE
#endif
