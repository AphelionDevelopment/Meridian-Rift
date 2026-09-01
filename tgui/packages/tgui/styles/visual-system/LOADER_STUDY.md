# Diagnostic loader study

## Decision

The Meridian-authored **B** geometry ships in production. Candidate **A**, an
exact source-derived circular loader from [Vecteezy
#21604950](https://www.vecteezy.com/vector-art/21604950-digital-interface-hud-elements-set-pack-user-interface-frame-screens-callouts-titles-fui-circle-set-loading-bars-dashboard-reality-technology-screen-vector),
is disqualified because the licensed download archive was not supplied and the
official download endpoint requires an authenticated acquisition. A preview is
not traced or misrepresented as exact source geometry.

The development Kitchen Sink retains a visible A provenance gate beside the B
matrix. Once a licensed archive is available, record its delivered terms and
checksum in `assets/ATTRIBUTIONS.md` before replacing that gate with sanitized
paths.

## Hard gates

| Gate | A | B |
| --- | --- | --- |
| Auditable exact source and terms | Fail | Pass; original repository CSS |
| Legible 48px construction | Not testable | Pass in compiled-CSS local Edge contact sheet; BYOND 516 confirmation pending |
| No clipping at 48/64/96/144px | Not testable | 48/112px pass in compiled-CSS local Edge contact sheet; full debug matrix and BYOND 516 confirmation pending |
| One compositor-driven animated layer | Not testable | Pass; outer cage transform only |
| No filters, glow, or external references | Not testable | Pass |
| Deliberate static reduced-motion state | Not testable | Pass; frozen at 23 degrees |
| Bounded paths/ticks/layers | Not testable | Pass; eight fixed DOM layers |

The compiled CSS was rendered in local Chromium Edge at 48px and 112px across
all eleven skins with no clipping. BYOND 516 and its embedded WebView2 runtime
are not installed on the implementation host, so actual-client DPI and
performance cells remain a handoff gate rather than a fabricated result.

## Weighted score

| Criterion | Weight | A | B |
| --- | ---: | ---: | ---: |
| Cohesion | 25 | Disqualified | 24 |
| Small-size legibility | 20 | Disqualified | 19 |
| Theme integration | 15 | Disqualified | 15 |
| WebView2 cost (provisional static review) | 15 | Disqualified | 14 |
| Reduced motion and accessibility | 10 | Disqualified | 10 |
| Maintenance | 10 | Disqualified | 8 |
| Provenance burden | 5 | Disqualified | 5 |
| **Total (provisional pending BYOND)** | **100** | **0** | **95** |

## Development matrix

Open the Kitchen Sink and select **Loader study**. The current debug skin is
applied to B immediately. Controls cover 48, 64, 96, and 144 CSS pixels; 100%,
125%, and 150% preview scaling; indeterminate and 0/1/50/99/100 percent states;
and an explicit reduced-motion freeze. Repeat the page in all eleven skins in
BYOND 516 before release.
