/**
 * Runtime lore metadata generated from lore-overhaul source entries.
 *
 * This datum is the generated runtime contract shared by lore overrides and the AutoWiki adapter.
 */
/datum/lore_overhaul_entry
	/// Stable source-data identifier for this lore entry.
	var/entry_id
	/// Absolute type path targeted by this lore entry.
	var/target_type
	/// Catalog-captured base name used when no lore name override is supplied.
	var/base_name
	/// Catalog-captured base description used when no lore description override is supplied.
	var/base_description
	/// If TRUE, this lore entry should export to AutoWiki.
	var/wiki_enabled = FALSE
	/// Lowercase hyphenated AutoWiki slug for this lore entry.
	var/wiki_slug
	/// Summary text exported to AutoWiki for this lore entry.
	var/wiki_summary
	/// If TRUE, AutoWiki should export an icon for this lore entry.
	var/wiki_export_icon = FALSE
	/// Icon file path exported to AutoWiki for this lore entry.
	var/wiki_icon_file
	/// Icon state exported to AutoWiki for this lore entry.
	var/wiki_icon_state
	/// Explicitly overridden game-facing name, when supplied by the source entry.
	var/display_name
	/// Explicitly overridden game-facing description, when supplied by the source entry.
	var/display_description
	/// Human-readable catalog label for the target type.
	var/type_label
