#define DEFAULT_TITLE_MAP_LOADTIME (150 SECONDS)

#define DEFAULT_TITLE_SCREEN_IMAGE 'modular_nova/modules/title_screen/icons/meridian_rift_title_mask.png'
#define DEFAULT_TITLE_LOADING_SCREEN 'modular_nova/modules/title_screen/icons/loading_screen.png'

#define TITLE_PROGRESS_CACHE_FILE "data/progress_cache.json"
#define TITLE_PROGRESS_CACHE_VERSION "2"
/// Cap on how many boot terminal lines we keep/send - matches how many the client ever displayed.
#define MAX_STARTUP_MESSAGES 27

/// Base name for the lobby's background image asset. The title image changes over time
#define LOBBY_TITLE_ASSET_PREFIX "lobby_title_screen"
/// Asset name for the neutral Meridian Rift wordmark. Unlike the title screen this
/// never changes, so it registers once under a fixed name.
#define LOBBY_TITLE_MARK_ASSET_NAME "lobby_title_mark.png"

/// Server-wide, admin-chosen title screen presentation. Survives restarts.
#define TITLE_SETTINGS_FILE "data/title_screen_settings.json"
#define TITLE_SETTINGS_VERSION "1"

/// How the lobby should render the current title screen.
/// No Meridian treatment; the raw image fills the backdrop.
#define TITLE_TREATMENT_NONE "none"
/// The image is a neutral alpha master that TGUI tints with the active theme.
#define TITLE_TREATMENT_MASK "mask"
/// The image renders as-is with the themed wordmark composited over it.
#define TITLE_TREATMENT_OVERLAY "overlay"
