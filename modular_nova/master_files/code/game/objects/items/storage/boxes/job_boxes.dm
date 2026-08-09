/obj/item/storage/box/survival
	/// TRUE = ignore Cache tank/mask picks entirely - for boxes with funny baked-in contents (clown/mime tanks, looking at you) that shouldn't get swapped out.
	var/cache_locked = FALSE

/// Which standing pouch wants Cache tab picks of this slot? Plain survival boxes shrug and say none - personal_cache overrides this to actually answer.
/obj/item/storage/box/survival/proc/get_pouch_for_slot(cache_slot)
	return null

/obj/item/storage/box/survival/hug
	cache_locked = TRUE
