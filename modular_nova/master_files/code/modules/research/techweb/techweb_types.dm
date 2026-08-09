/// Reference back to code/_defines/machines.dm for types, and this file's mirror for reference.

/datum/techweb/colony_fabricator
	var/allowed_buildtypes = COLONY_FABRICATOR //Used for sorting

/datum/techweb/colony_fabricator/New() //Remove a few things to hopefully get this to work right.
	. = ..()
	for(var/id, current_design in SSresearch.techweb_designs)
		var/datum/design/design = current_design
		if(!(design.build_type & allowed_buildtypes)) //Define hell incoming if we make more subtypes.
			continue

		add_design_by_id(id)

// Admin Techweb, this surely isnt a mistake.
// Must stay under /autounlocking: the design_source unit test only counts a design as reachable if it turns up in a
// techweb node, a design disk, or an autounlocking techweb.
/datum/techweb/autounlocking/admin
	allowed_buildtypes = ADMIN_TECHWEB | COLONY_FABRICATOR
