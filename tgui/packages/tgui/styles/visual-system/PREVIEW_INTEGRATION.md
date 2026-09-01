# MeridianOS Preferences preview integration

## Root cause and lifecycle repair

The first-open preview could be tiny because the browser initially measured the
native `ByondUi` while the window was hidden and still had its short,
pre-geometry rectangle. The old locked `tgui-core@6.1.1` mounted the native map
immediately but did not subscribe to `window-geometry-finished`, so the cached
native control retained that first rectangle. Reopening appeared to repair the
problem because recalled window geometry was already available.

Commit 3 locks every workspace consumer to `tgui-core@6.1.3`, which includes
[tgui-core PR #274](https://github.com/tgstation/tgui-core/pull/274). `Window`
now awaits recalled geometry, cancels stale mount generations, and only then
unhides, sends the existing DM-visible signal, and emits
`window-geometry-finished`. The resume handler no longer unhides first. The
`ByondUi` listener debounces one final measurement and applies the final DOM
rectangle and device-pixel ratio to the native child control.

Tests cover an initial 16x16 rectangle followed by 96x128 at 1.5 DPR, an event
before mount, remounting, listener cleanup, native unparenting, awaited ordering,
stale-generation cancellation, and resume sequencing. No delay, geometry
perturbation, or `screen_loc` shake is used.

## Ownership boundary and A-F investigation

The browser and a secondary BYOND map are separate native control surfaces.
[BYOND's control reference](https://secure.byond.com/docs/ref/skinparams.html)
documents map controls and `screen-loc`; repository map-view code registers map
objects and popup plane groups directly with the client. The internal
`healthdoll` is useful only as evidence that native screen objects can render in
a HUD plane. None of its anatomical art, hit regions, or body assumptions is
used here.

| Approach | Experiment | Result | Reason | Performance / maintenance |
|---|---|---|---|---|
| A. HTML over native map | Cross the map edge with the frame's corner/leader pseudo-elements and inspect z-order in BYOND 516. | Exterior half implemented; native-runtime crossing remains to be recorded on a BYOND-capable host. Not selected for interior marks. | HTML can own the surrounding chassis, but the implementation does not assume browser pixels can paint through an independently owned native map surface. | Cheap static CSS; brittle if used as an interior-overlay trick. |
| B. Native HUD/appearance | Add exact-size transparent Standard and Augmentation states after the body appearance on the existing preview canvas. | Implemented. DMI metadata, alpha, state names, 32/64/96 dimensions, replacement behavior, and cleanup are automated; live z-order remains a BYOND acceptance check. | It keeps all interior marks on the same native surface and cannot enlarge the existing canvas. | One static appearance; no processing loop or extra registered map object. |
| C. Hybrid | Combine A's exterior chassis with B's equal-size native interior. | Selected production architecture. | Each renderer owns only pixels it can reliably control. The existing `ByondUi` width, height, rotation, map registration, and cleanup remain authoritative. | Small static CSS plus 2,680 bytes (2.62 KiB) of first-party DMI assets; two finite states. |
| D. Oversized native map/masking | Prototype only if an equal-size appearance cannot satisfy the composition; compare map bounds and autoscale before/after. | Rejected by design; no oversized control was introduced. | CSS masking cannot be relied on for a native child, and a larger map risks changing the very autoscale contract being repaired. | High regression and maintenance cost. |
| E. Snapshot/render target | Evaluate a browser-owned image of the preview against live equipment, direction, species, and appearance updates. | Feasible as a static capture, rejected for production. | It duplicates or delays the live appearance pipeline and complicates rotation and equipment updates. | Additional capture/update traffic and synchronization state. |
| F. Native-window internals | Trace `ByondUi` `winset`, map-object registration, popup plane groups, and browser layout as separate surfaces. | Source-level investigation confirms separate ownership; BYOND 516 instrumentation remains part of final runtime acceptance. | It explains why a lifecycle event plus a hybrid frame is robust and why ordinary CSS is not claimed to cross the map surface. | No new runtime mechanism; establishes a stable maintenance boundary. |

## Final composition and contract

- `PreferencesCharacterPreviewFrame` accepts only `none`, `standard`, or
  `augmentation`. It never changes the child map's dimensions and all exterior
  chrome is pointer-transparent.
- Main, Species, and Loadout use Standard. Antagonists, Occupations, Languages,
  and the hidden 1x1 Quirks preview request none.
- Augments always uses the stronger red/cyan exterior shell. Its native
  interior remains Standard normally; a window-local debug override of
  `meridian_augmentation` switches that interior to Augmentation. Leaving the
  page/theme replaces the state; destroying the owning window clears it.
- DM validates the same finite payload in `set_preview_decoration`. The mode is
  a field on the ephemeral preview map object and is never saved.
- Native overlay order is background canvas, current body appearance, then one
  equal-size decoration appearance. State changes cut and rebuild that stack,
  so overlays cannot accumulate.
- Standard states use four brackets, alignment ticks, two generic region
  leaders, and a registration mark. Augmentation uses a fixed red cage, cyan
  axis, generic `UPPER`, `CORE`, and `LOWER` rails, module sockets, and short
  inward leaders. Nothing follows a silhouette or captures input.

The DMI sources are original Meridian-authored geometry generated by
`generate_preview_decorations.py`; no third-party or healthdoll pixels are
included.

## Runtime acceptance still required

This checkout does not have BYOND/Dream Maker installed. Run the requested 50
cold opens plus 50 reopens in BYOND 516/WebView2 across 32/64/96 canvases,
100/125/150/200% Windows scaling, the 780/940px height transition, all four
directions, and ordinary/oversized/taur/non-human/transformed bodies. Record DOM
rectangle, DPR, native `winget` rectangle, geometry-finished, DM-visible, and map
registration timestamps. Acceptance remains: no tiny first render, no scale
change with decoration, no orphan controls/overlays, and no reopen workaround.
