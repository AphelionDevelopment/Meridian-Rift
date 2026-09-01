# MeridianOS visual system

MeridianOS is a scoped console family layered on top of tgui-core. It does not
restyle terminal, synth, paper, cat, spooky, syndicate, wizard, clockwork,
hackerman, retro-95, or other specialty themes.

## Architecture

1. `_palette.scss` contains private color primitives.
2. `_display-font.scss` exposes the licensed display face to both TGUI bundles.
3. `_tokens.scss` defines runtime semantic variables and maps them to the
   public tgui-core component variables.
4. `_themes.scss` supplies palette and construction profiles for Standard and
   ten development skins.
5. `_components.scss` applies shared component states using semantic variables
   only.
6. `_loader.scss` provides the fixed diagnostic-instrument layer set shared by
   the ordinary TGUI and lobby bundles. Theme variables reshape it without
   cloning component markup.
7. `_decoration.scss` owns pointer-transparent shell, title-rail, and corner
   motifs.
8. `_motion.scss` owns the small interaction transitions, reduced-motion
   behavior, and forced-colors fallback.

`Layout` resolves the window-local development override first, then the
requested/device theme, then Standard. It reconciles only the classes it owns,
so unrelated root modifiers and multi-class specialty themes survive updates.
The old base ID is accepted as an invisible compatibility alias; new devices
request `meridian`.

## Skin catalog

Only **Standard** (`meridian`) is production-facing. These variants are
available from the development Kitchen Sink and are deliberately absent from
preference, PDA, Themeify, and persistence lists:

- Vector — paired notches, calibration ticks, and measurement rails.
- Foundry — recessed machinery, fasteners, and warning-only hatching.
- Diagnostic — square brackets, alignment ticks, and acquisition nodes.
- Highline — accessibility-first square boundaries and inverse selection.
- Synapse — aubergine surfaces, asymmetric cuts, and teal status pins.
- Cyberpunk — hot-red broken rails and cyan inner registration marks.
- Augmentation — ordered clinical trapezoids and module sockets matching the
  Augments workstation.
- Afterlight — retrofit/noir bezel slabs and substantial keycaps.
- Relay — manufactured-spacecraft equipment bays, labels, and lamp blocks.
- Bastion — monumental slab rails, portal corners, and large negative fields.

In a development build, open the Kitchen Sink with the title-bar bug button or
F11. Use **Inherit**, previous, next, or the skin dropdown. The selection applies
to the current window immediately, remains active after leaving the Kitchen
Sink, and is discarded when that TGUI window closes.

The **Loader study** page compares the production Meridian-authored instrument
at 48/64/96/144px, three scaling factors, determinate checkpoints, and a manual
reduced-motion freeze. Candidate A remains visibly provenance-gated until an
auditable #21604950 source archive is acquired; see `LOADER_STUDY.md`.

## Research translation

The primary visual references are the supplied cyberpunk/FUI links, the
existing Augments and Microfusion interfaces, and the resource ledger in
`assets/ATTRIBUTIONS.md`. The implementation borrows vocabulary rather than
franchise layouts or third-party paths:

- [Caves of Qud](https://cavesofqud.com/roadmap/) informs the rhythm of short display labels only. VCR OSD Mono is
  limited to 13px-or-larger display labels in Vector, Cyberpunk, and
  Augmentation. Body copy and forms retain the system sans stack.
- [Blade Runner production commentary](https://www.wired.com/2007/09/ff-bladerunner-full/) informs visible retrofit layers and
  service seams; [Star Wars “used future” production principles](https://www.starwars.com/news/blind-ltd-solo) inform plainly
  manufactured Relay controls; [Dune production-design commentary](https://www.pushing-pixels.org/2024/04/10/production-design-of-dune-interview-with-patrice-vermette.html) informs
  Bastion's restrained, monumental negative space. No franchise marks,
  alphabets, layouts, or type are copied.
- The [W3C Design Tokens Community Group](https://www.w3.org/community/reports/design-tokens/CG-FINAL-format-20251028/), [Fluent 2](https://fluent2.microsoft.design/design-tokens), and [Carbon](https://carbondesignsystem.com/elements/color/overview/) inform the
  primitive-to-semantic-to-component layering.
- [WCAG 2.2](https://www.w3.org/TR/WCAG22/), [WAI-ARIA Authoring Practices](https://www.w3.org/WAI/ARIA/apg/patterns/tabs/), [GOV.UK focus guidance](https://design-system.service.gov.uk/get-started/focus-states/), and [NASA crew
  interface guidance](https://www.nasa.gov/reference/10-0-crew-interfaces-vol-2/) constrain contrast, state redundancy, focus visibility,
  and task hierarchy.
- Motion uses short compositor-friendly transforms only, follows [web.dev's
  animation guidance](https://web.dev/articles/animations-guide),
  and becomes static under reduced motion. There is no
  idle full-window animation, page-wide grid, scanline layer, blur, or glow.

The palette contract test checks every skin's normal/muted text, meaningful
boundary, selection, accent, and focus pairs. Construction—not hue alone—is
what differentiates skins in grayscale.
