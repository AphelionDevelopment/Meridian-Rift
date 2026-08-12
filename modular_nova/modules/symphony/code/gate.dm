/// Href keys a gated player can still send.
GLOBAL_LIST_INIT(symphony_gate_free_hrefs, list("src", "title_is_ready", "server_swap"))

/// Every key has to be gate-free, one we don't know and the gate applies.
/proc/symphony_href_is_gate_free(list/href_list)
	if(!length(href_list))
		return FALSE
	for(var/key in href_list)
		if(!(key in GLOB.symphony_gate_free_hrefs))
			return FALSE
	return TRUE

/// TRUE means this new_player isn't getting into the round.
/mob/dead/new_player/proc/symphony_blocks_play()
	if(!CONFIG_GET(flag/symphony_enabled))
		return FALSE
	if(!client)
		return TRUE
	// We're fail-closed, so without this a DB blip locks the admins out of their own round.
	if(client.holder)
		return FALSE
	return !is_symphony_whitelisted(ckey)

/mob/dead/new_player/proc/symphony_gate_notice()
	// `key`, not `ckey` - ckey() strips the hyphen that is_guest_key matches on
	if(is_guest_key(key))
		to_chat(src, span_userdanger("You are logged in as a BYOND guest."))
		to_chat(src, span_warning("Guest accounts cannot be whitelisted. Sign in with a real BYOND account and reconnect to play."))
		return
	to_chat(src, span_userdanger("You are not whitelisted."))
	to_chat(src, span_warning("<a href='byond://?src=[REF(src)];get_whitelisted=1'><b>Click here to Get Whitelisted</b></a> - link your Discord account to gain access. You must stay in the Discord with the whitelist role to play."))
