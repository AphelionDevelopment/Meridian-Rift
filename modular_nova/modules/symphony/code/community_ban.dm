/// Minutes for one unit of each duration interval the ban panel offers.
GLOBAL_LIST_INIT(symphony_interval_minutes, list(
	"SECOND" = 1,
	"MINUTE" = 1,
	"HOUR" = 60,
	"DAY" = 1440,
	"WEEK" = 10080,
	"MONTH" = 43200,
	"YEAR" = 525600,
))

/// Ban duration in minutes, as SSymphony records it. 0 is permanent.
/proc/symphony_ban_minutes(duration, interval)
	if(isnull(duration))
		return 0
	var/amount = isnum(duration) ? duration : text2num(duration)
	if(!amount)
		return 0
	var/per = GLOB.symphony_interval_minutes[interval] || 1
	return max(1, round(amount * per))

/**
 * Record a request for this ban to apply on every server in the community.
 *
 * The ban is already in this server's own table. SSymphony polls this table, applies the ban to the
 * other servers, and keeps applying it to servers added later. Returns FALSE if nothing was written.
 */
/proc/symphony_request_community_ban(target_ckey, list/roles, reason, duration, interval, admin_ckey)
	if(!target_ckey || !length(roles) || !SSdbcore.Connect())
		return FALSE
	var/minutes = symphony_ban_minutes(duration, interval)
	var/list/rows = list()
	for(var/role in roles)
		rows += list(list(
			"ckey" = target_ckey,
			"role" = role,
			"reason" = reason,
			"duration_mins" = minutes,
			"admin_ckey" = admin_ckey,
		))
	if(!SSdbcore.MassInsert(format_table_name("symphony_ban_intents"), rows, warn = TRUE))
		return FALSE
	log_admin_private("[admin_ckey] requested a community-wide ban for [target_ckey].")
	message_admins("[admin_ckey] requested a COMMUNITY-WIDE ban for [target_ckey] - SSymphony will apply it to the other servers.")
	return TRUE
