//"immutable" gas mixture used for immutable calculations
//it can be changed, but any changes will ultimately be undone before they can have any effect
//
//mark_immutable() makes Dogmos itself refuse every mutation (merge, adjust_moles, set_temperature,
//temperature_share, ...) as a no-op, which is strictly stronger than the old DM overrides that only
//blocked the specific procs someone remembered to override. remove()/remove_ratio() are the one
//exception Dogmos doesn't guard - gas_mixture.dm's wrappers check is_immutable() themselves and
//return an inexhaustible copy instead of draining an immutable mixture.
//
//Do NOT mark_immutable() in the base New(): both parse_string_immutable() below and
//SSair.parse_gas_string() populate gas content in a separate step AFTER construction, and Dogmos
//silently no-ops writes to an already-immutable mixture. Each concrete leaf marks immutable itself,
//once its content is actually final.

/datum/gas_mixture/immutable
	var/initial_temperature

/datum/gas_mixture/immutable/New(volume)
	. = ..()
	set_temperature(initial_temperature)

//used by space tiles. Never gets content set after construction, so it's safe to finalize immediately.
/datum/gas_mixture/immutable/space
	initial_temperature = TCMB

/datum/gas_mixture/immutable/space/New(volume)
	. = ..()
	mark_immutable()

/datum/gas_mixture/immutable/space/heat_capacity()
	return HEAT_CAPACITY_VACUUM

//planet side stuff
/datum/gas_mixture/immutable/planetary
	var/list/initial_gas = list()

/datum/gas_mixture/immutable/planetary/proc/parse_string_immutable(gas_string) //I know I know, I need this tho
	gas_string = SSair.preprocess_gas_string(gas_string)

	var/list/mix = initial_gas
	var/list/gas = params2list(gas_string)
	if(gas["TEMP"])
		initial_temperature = text2num(gas["TEMP"])
		gas -= "TEMP"
	mix.Cut()
	for(var/id, value in gas)
		var/path = id
		if(!ispath(path))
			path = gas_id2path(path) //a lot of these strings can't have embedded expressions (especially for mappers), so support for IDs needs to stick around
		mix[path] = text2num(value)

	set_temperature(initial_temperature)
	for(var/gas_id, value in mix)
		set_moles(gas_id, value)
	mark_immutable()
