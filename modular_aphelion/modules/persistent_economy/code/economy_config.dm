/**
 * Whether the persistent economy is available on this server at all.
 *
 * The host's switch, and the outer of the two. Off, every account is round-scoped, nothing carries
 * over and no levy is taken, which is the stock upstream economy, and no admin can turn any of it back
 * on from the panel.
 *
 * Defaults on, because this is not the switch that decides whether the feature runs. That is the
 * stored setting behind the economy panel, which is off until an admin throws it. This one exists so a
 * server that does not want the module can rule it out for good, and so a broken ledger can be taken
 * out of the loop without waiting for someone with panel access.
 */
/datum/config_entry/flag/persistent_economy
	default = TRUE
