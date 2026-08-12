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
