# Lobby menu styles

[_menu-common.scss](_menu-common.scss) supplies geometry and behavior for all
fourteen HTML menus: placement, size limits, scrolling, text wrapping, heading
alignment, stable pointer/focus markers, and nonanimated poll indicators. These
39 declarations previously appeared in each of the four layout stylesheets.
The common selectors are deliberately less specific than the theme profiles.

[_themed-menus.scss](_themed-menus.scss) supplies the default instrument layout,
native-control states, and keyboard focus treatment for eleven menus.
[_instrument-menus.scss](_instrument-menus.scss) supplies eight instrument
profiles; [_signal-menus.scss](_signal-menus.scss) supplies Cyberpunk,
Augmentation, and Synapse. Profiles set `--menu-*` colors, typography, frame
weights, edge rules, and hover surfaces. Keep compound backgrounds opaque and
decoration at the casing edges, clear of text and hit boxes.

The distinct Wastelander, Highline, and Aphelion layouts remain in
[_wastelander.scss](_wastelander.scss), [_highline.scss](_highline.scss), and
[_aphelion-theme.scss](_aphelion-theme.scss). They do not receive the shared
`data-menu-treatment="instrument"` layout.

Keep fonts, control height and padding, heading proportions, surface textures,
frame weights, focus colors, and accessibility palette overrides in their
profiles. For example, Highline's ceramic header, Wastelander's worn glass, and
Aphelion's spectrum rule must not become a single generic panel. HTML actions,
disabled controls, headings, and scanline composition already share React
components; duplicating those per theme is unnecessary.

[menuTheme.ts](../menuTheme.ts) maps each saved theme ID to its menu heading and
identifies which menus use the shared layout. `AphelionLobbyMenu` uses the same
mapping to place menus beneath the selected scanline glass. The separate
[_menu-scanlines.scss](_menu-scanlines.scss) layer is decorative and ignores
pointer input. Choosing no scanlines suppresses it; increased contrast and
forced colors hide it. Startup and transparent lobbies keep their existing
overlay gates.

| Theme | Material and construction |
| --- | --- |
| Standard | Navy inset panel, thin frame, segmented teal rule. |
| Classic NT | Subdued purple-to-blue CRT surface, pixel lettering, shallow stepped rim. |
| Vector | Blue calibration ticks, precise double frame, monospaced labels. |
| Foundry | Amber industrial housing, weighted upper/left edges, small corner fasteners. |
| Diagnostic | Dark green readout, narrow side brackets, short registration ticks. |
| Afterlight | Worn steel inset, heavy upper/left lip, restrained amber and cyan marks. |
| Relay | Manufactured shell, lower reinforcement, fasteners, orange/cyan rule. |
| Bastion | Gold slab frame, asymmetric edge weights, broad registration rail. |
| Cyberpunk | Dark red housing, broken red rails, cyan state accents. |
| Augmentation | Cyan module frame, balanced segments, central red registration mark. |
| Synapse | Violet sign rule, teal offset edge, sparse contrasting accents. |

All new menu decoration is original CSS. Existing theme palette IDs and shared
colors remain unchanged; menu-only shades soften surfaces where needed. No
artwork from the reference games is bundled into these menus.

The signal profiles interpret primary visual references: CD Projekt Red's
[Cyberpunk 2077 accessibility settings](https://www.cyberpunk.net/en/news/49591/update-2-1-accessibility-features),
R. Talsorian Games' [Cyberpunk RED Single Shot Pack](https://rtalsoriangames.com/wp-content/uploads/2021/02/RTG-CPRed-SingleShotPackv1.1.pdf),
and the official [Hotline Miami Steam page](https://store.steampowered.com/app/219150/Hotline_Miami/).
These inform the restrained red/cyan controls, segmented labels, and violet/teal
sign treatment; they are references rather than copied interface assets.
