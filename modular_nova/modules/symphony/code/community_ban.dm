/// Minutes in one unit of each interval.
GLOBAL_LIST_INIT(symphony_interval_minutes, list(
	"SECOND" = 1,
	"MINUTE" = 1,
	"HOUR" = 60,
	"DAY" = 1440,
	"WEEK" = 10080,
	"MONTH" = 43200,
	"YEAR" = 525600,
))

/// Ban length in minutes, 0 being permanent.
/proc/symphony_ban_minutes(duration, interval)
	if(isnull(duration))
		return 0
	var/amount = isnum(duration) ? duration : text2num(duration)
	if(!amount)
		return 0
	var/per = GLOB.symphony_interval_minutes[interval] || 1
	return max(1, round(amount * per))

/// We're already banned here, this just asks SSymphony to spread it to the rest.
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
