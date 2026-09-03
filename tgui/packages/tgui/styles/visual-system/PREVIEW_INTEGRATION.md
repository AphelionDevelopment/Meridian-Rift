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

## Runtime acceptance still required

This checkout does not have BYOND/Dream Maker installed. Run the requested 50
cold opens plus 50 reopens in BYOND 516/WebView2 across 32/64/96 canvases,
100/125/150/200% Windows scaling, the 780/940px height transition, all four
directions, and ordinary/oversized/taur/non-human/transformed bodies. Record DOM
rectangle, DPR, native `winget` rectangle, geometry-finished, DM-visible, and map
registration timestamps. Acceptance remains: no tiny first render and no reopen
workaround.
