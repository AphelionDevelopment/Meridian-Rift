/**
 * Generates namespaced AutoWiki templates for enabled lore-overhaul entries.
 *
 * The generated lore registry supplies the final game-facing values and validated icon references.
 * This adapter never reads the editor's JSON source or publishes directly to the wiki.
 */
/datum/autowiki/lore_overhaul
	/// Generated lore registry subtype to render.
	var/entry_type

/**
 * Render one generated lore entry as a namespaced AutoWiki template.
 *
 * Values are escaped before being passed to the existing AutoWiki template helper. Optional icon
 * export uses the existing upload path and a slug-derived namespace.
 */
/datum/autowiki/lore_overhaul/generate()
	var/datum/lore_overhaul_entry/lore_entry = new entry_type
	var/final_name = lore_entry.display_name || lore_entry.base_name || lore_entry.type_label
	var/final_description = lore_entry.display_description || lore_entry.base_description || ""
	var/list/template_parameters = list(
		"id" = escape_value(lore_entry.entry_id),
		"name" = escape_value(final_name),
		"description" = escape_value(final_description),
		"summary" = escape_value(lore_entry.wiki_summary),
		"type" = escape_value(lore_entry.type_label),
	)

	if (lore_entry.wiki_export_icon)
		var/asset_name = "LoreOverhaul-[lore_entry.wiki_slug]"
		template_parameters["icon"] = escape_value(asset_name)
		upload_icon(icon(lore_entry.wiki_icon_file, lore_entry.wiki_icon_state, frame = 1), asset_name)

	return include_template("Autowiki/AphelionLoreEntry", template_parameters)
