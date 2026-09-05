/// The roles Discord roles can map onto. The panel can't add any, this list is the lot.
GLOBAL_LIST_INIT(symphony_ingame_roles, list(
	"whitelist" = "Required to join the round.",
))

/// Hands them over so the panel can build its role mapping UI.
/datum/world_topic/symphony/ingame_roles
	keyword = "symphony_ingame_roles"

/datum/world_topic/symphony/ingame_roles/Run(list/input)
	. = list()
	var/list/roles = list()
	for(var/key in GLOB.symphony_ingame_roles)
		roles += list(list("key" = key, "description" = GLOB.symphony_ingame_roles[key]))
	.["roles"] = roles
