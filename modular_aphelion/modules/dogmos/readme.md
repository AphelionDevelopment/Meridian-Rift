# Dogmos

Module ID: `DOGMOS`

This module initializes the Rust atmospherics library before turf construction and provides the
Dogmos-specific subsystem state and turf hooks that do not belong in the atmospherics core.

## Contents

- `code/dogmos.dm`: Dogmos subsystem and integration state.
- `master_files/code/game/turfs/`: turf registration, temperature authority, adjacency, and space
  boundary overrides.
- `tgui/packages/tgui/interfaces/DogmosKennel/docs/`: Markdown source for the Kennel's About,
  Glossary, and Credits tabs.

The station-safe `/obj/item/clothing/glasses/meson/engine/dogmos` is research-buildable. Its modes
include breach alerts and reaction profiles backed by Kennel overlays. The `/admin` subtype adds
high-cost reaction profiling, structure pins, the full overlay set, and area-blueprint imaging; it
is not a station research design.

Related core includes are `code/__DEFINES/dogmos_defines.dm` and
`code/__DEFINES/dogmos_bindings.dm`; they must remain in core for include-order compatibility.

The remaining gas and turf processing implementation stays in the core atmospherics files because it
must preserve their include order and existing call sites.
