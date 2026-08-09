/// The Cache tab's slot categories - see modular_nova/modules/personal_cache/
#define CACHE_SLOT_TANK "tank"
#define CACHE_SLOT_MASK "mask"
#define CACHE_SLOT_RATION "ration"
#define CACHE_SLOT_GENERAL "general"

/// sort_priority bands for bluespace matrices - sort_into_matrix() offers a dropped item to the lowest number first, so the picky ones get first refusal and the junk drawer eats last. New matrix? Pick a number, that's the whole integration.
#define CACHE_SORT_IDENTITY 10 // matches on trait rather than type, so it can't steal anything - safe to ask first
#define CACHE_SORT_RESTRICTED 20 // tight hand-picked lists that overlap the broad ones below (the love matrix and its masks)
#define CACHE_SORT_SURVIVAL 30
#define CACHE_SORT_RATIONS 40
#define CACHE_SORT_CATCHALL 100 // the junk drawer. Always last, nothing goes below it.
