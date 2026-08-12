/// Addresses that mean "this machine".
GLOBAL_LIST_INIT(symphony_local_addresses, list("127.0.0.1", "::1", "localhost"))

/// TRUE if a topic from this sender is allowed to run.
/proc/symphony_address_allowed(addr)
	if(!CONFIG_GET(flag/symphony_topics_local_only))
		return TRUE
	// Null addr means the sender is on this machine.
	if(!addr)
		return TRUE
	var/sender = LOWER_TEXT(trim(addr))
	if(sender in GLOB.symphony_local_addresses)
		return TRUE
	for(var/allowed in CONFIG_GET(str_list/symphony_topics_allowed_addresses))
		if(LOWER_TEXT(trim(allowed)) == sender)
			return TRUE
	return FALSE

/// Subtype this and the address gate comes along for free.
/datum/world_topic/symphony
	abstract_type = /datum/world_topic/symphony
	require_comms_key = TRUE

/datum/world_topic/symphony/AddressAllowed(addr)
	if(symphony_address_allowed(addr))
		return TRUE
	log_admin("Symphony: refused topic \"[keyword]\" from [addr] - not an allowed address.")
	return FALSE

/datum/world_topic/symphony/TryRun(list/input, addr)
	. = ..()
	// Anyone can claim to be the panel, so only a topic that got the comms key right is believed.
	if(key_valid)
		symphony_note_panel(input, addr)

/// What SSymphony last told us about itself. Empty until it says hello.
GLOBAL_LIST_EMPTY(symphony_panel)
/// Same, for a caller the gate turned away. Its own slot so it can't bury the real panel.
GLOBAL_LIST_EMPTY(symphony_panel_refused)

/// Remember who called, so the status verb can compare the two halves.
/proc/symphony_note_panel(list/input, addr)
	// No version means a panel too old to introduce itself, which is still worth knowing about.
	var/list/said = list(
		"version" = input["symphony_version"],
		"needs" = text2num(input["symphony_needs"]),
		"wants" = text2num(input["symphony_wants"]),
		"addr" = addr,
		"at" = REALTIMEOFDAY,
	)
	// A refused topic never ran, so it doesn't get to be "the panel" - a barred host polling every
	// few seconds would otherwise erase the real one, right when someone is diagnosing the gate.
	if(!symphony_address_allowed(addr))
		GLOB.symphony_panel_refused = said
		return
	GLOB.symphony_panel = said

/// How long ago a stamp was. DisplayTimeText already says "right now", and "right now ago" reads wrong.
/proc/symphony_ago(stamp)
	var/text = DisplayTimeText(REALTIMEOFDAY - stamp)
	return text == "right now" ? text : "[text] ago"

/datum/world_topic/symphony/whitelist_revoke
	keyword = "whitelist_revoke"
	require_comms_key = TRUE

/datum/world_topic/symphony/whitelist_revoke/Run(list/input)
	. = list()
	var/target_ckey = ckey(input["target_ckey"])
	if(!target_ckey)
		.["success"] = FALSE
		.["message"] = "missing target_ckey"
		return
	symphony_revoke(target_ckey)
	.["success"] = TRUE

/datum/world_topic/symphony/whitelist_grant
	keyword = "whitelist_grant"
	require_comms_key = TRUE

/datum/world_topic/symphony/whitelist_grant/Run(list/input)
	. = list()
	var/target_ckey = ckey(input["target_ckey"])
	if(!target_ckey)
		.["success"] = FALSE
		.["message"] = "missing target_ckey"
		return
	symphony_notify_grant(target_ckey)
	.["success"] = TRUE
