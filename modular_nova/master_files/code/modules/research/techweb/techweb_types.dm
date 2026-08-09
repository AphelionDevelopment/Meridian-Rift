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
// Subtyped off autounlocking rather than hand-rolling the same design loop a third time - that parent already walks
// every design matching allowed_buildtypes, and the design_source unit test only counts a design as reachable if it
// turns up in a techweb node, a design disk, or an autounlocking techweb.
// COLONY_FABRICATOR rides along so the administrative fabricator is a superset of the rapid construction one rather
// than a sidegrade that can't print girders.
/datum/techweb/autounlocking/admin
	allowed_buildtypes = ADMIN_TECHWEB | COLONY_FABRICATOR
