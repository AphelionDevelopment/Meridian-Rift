/// Lets the panel flip the whitelist gate at runtime, it persists to file for the next boot.
/datum/world_topic/symphony/set_enforcement
	keyword = "symphony_set_enforcement"
	require_comms_key = TRUE

/datum/world_topic/symphony/set_enforcement/Run(list/input)
	. = list()
	// Not gated behind symphony_enabled like the rest of us, this is the thing that turns it on.
	var/admin_name = input["admin_name"] || "Discord Admin"
	var/raw = input["enabled"]
	if(isnull(raw))
		.["success"] = FALSE
		.["message"] = "missing enabled"
		return
	var/enabled = (raw == "1" || raw == "true" || raw == 1)

	// Hardcoded on purpose, nobody gets to ask us to set some other entry.
	var/datum/config_entry/entry = global.config.entries["symphony_enabled"]
	if(!entry)
		.["success"] = FALSE
		.["message"] = "symphony_enabled is not a known config entry on this server"
		return

	var/old_value = entry.config_entry_value
	if(!entry.ValidateAndSet(enabled ? "1" : "0"))
		.["success"] = FALSE
		.["message"] = "the game refused the value"
		return

	.["success"] = TRUE
	.["enabled"] = enabled
	log_admin("[admin_name] (via Symphony) set whitelist enforcement to [enabled ? "on" : "off"] (was [old_value]).")
	message_admins("[html_encode(admin_name)] (via Symphony) turned whitelist enforcement [enabled ? "ON" : "OFF"].")
