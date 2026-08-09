/// Whether something is repairable by the anvil
#define ANVIL_REPAIR (1<<0)
/// Whether obj is used for ERP
#define ERP_ITEM (1<<1)
/// If toggled, the obj cannot be stored by cryopods
#define NO_CRYO_FREEZE (1<<2)
/// Prevents an item from being stripped unless you are an admin privileges holder.
#define NOSTRIP (1<<3)
/// Is this an Admin item? Adds an 'admistrative' obj detail, similar to how sec gloves show they cuff quickly or insuls provide insulation
#define ADMIN_ITEM (1<<4)

/// Admin Items and Flags
/// These three defines belong to three different bitfields and are NOT interchangeable - the bits overlap.
/// ADMIN_OBJ_FLAGS goes on obj_flags, ADMIN_OBJ_FLAGS_NOVA goes on obj_flags_nova, ADMIN_CLOTHING_FLAGS goes on clothing_flags.
#define ADMIN_OBJ_FLAGS (XENOMORPH_HOLDABLE | UNIQUE_RENAME)
/// Prevents removal through strip menu, and tags the item as administrative on examine
#define ADMIN_OBJ_FLAGS_NOVA (NOSTRIP | ADMIN_ITEM)
/// Admin worn gear doesn't get knocked off and doesn't get eaten by moths. Apply with |= so the parent type's own flags survive.
#define ADMIN_CLOTHING_FLAGS (SNUG_FIT | INEDIBLE_CLOTHING)
