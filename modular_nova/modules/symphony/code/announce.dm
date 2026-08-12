/// Message from SSymphony to the people in the round. audience: all|admins. style: notice|warning|alert.
/datum/world_topic/symphony/announce
	keyword = "symphony_announce"
	require_comms_key = TRUE

/datum/world_topic/symphony/announce/Run(list/input)
	. = list()
	var/message = input["message"]
	if(!message)
		.["success"] = FALSE
		.["message"] = "missing message"
		return

	var/style = input["style"] || "notice"
	var/audience = input["audience"] || "all"
	var/title = input["title"]
	var/from = input["from"]

	var/body = html_encode(message)
	switch(style)
		if("alert")
			body = span_userdanger(body)
		if("warning")
			body = span_boldwarning(body)
		else
			body = span_boldnotice(body)

	var/header = title ? span_boldannounce(html_encode(title)) : null
	var/footer = from ? span_smallnotice("- [html_encode(from)] via SSymphony") : null
	var/list/lines = list()
	if(header)
		lines += header
	lines += body
	if(footer)
		lines += footer
	var/out = "<div class='SSymphony_announce'>[lines.Join("<br>")]</div>"

	var/sent = 0
	for(var/client/target as anything in GLOB.clients)
		if(audience == "admins" && !target.holder)
			continue
		to_chat(target, out)
		sent++

	log_admin_private("SSymphony announcement ([audience], [style])[from ? " from [from]" : ""]: [message]")
	.["success"] = TRUE
	.["sent"] = sent
