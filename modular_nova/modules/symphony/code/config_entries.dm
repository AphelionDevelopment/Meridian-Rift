/// Master switch, the whole module sits inert without it.
/datum/config_entry/flag/symphony_enabled

/// Where the panel lives, e.g. https://symphony.example.com
/datum/config_entry/string/symphony_url

/// Grace seconds before we boot them to the lobby. Stays under SSsymphony's sweep, or the timer just re-arms forever.
/datum/config_entry/number/symphony_grace_seconds
	default = 30
	integer = TRUE
	min_val = 0
	max_val = 240

/// Lets Discord roles hand out in-game admin ranks. Off by default, whoever can assign the role can mint admins.
/datum/config_entry/flag/symphony_discord_admin_sync
	default = FALSE

/// Only take Symphony topics from addresses we trust, so a leaked comms key isn't enough on its own.
/datum/config_entry/flag/symphony_topics_local_only
	default = FALSE

/// Extra addresses the gate lets through, one per line. Loopback is always fine, so a single box leaves this empty.
/datum/config_entry/str_list/symphony_topics_allowed_addresses
