# About Dogmos

Dogmos is Meridian Rift's canine-named atmospheric workbench: a Rust-backed simulation layer for
gas movement, reactions, pressure equalization, and heat conduction. The Dogmos Kennel is the
handler's window into that work. It collects bounded histories, exposes safe live switches, and
lets an engineer follow a suspicious tile or machine without turning the whole station into a data
firehose.

## What Dogmos owns

Dogmos stores gas mixtures in its Rust arena and processes registered turf mixtures through the FDM
flow pass. It also runs the Katmos pressure equalizer and the TurfHeat graph for heat that crosses
blocked atmospheric paths. DM remains responsible for the public gas-mixture API, atmospheric
machinery, reactions' player-facing consequences, hotspots, fire groups, overlays, logging, and
subsystem scheduling.

This split is deliberate. Rust handles the repeated numerical work close to the data; DM handles
gameplay contracts and the parts that must talk to players, objects, and the rest of the station.
When a callback crosses the boundary, it checks that its target is still alive before giving the
next hound a job.

## How to use the Kennel

- **Overview** shows live counts, stage costs, pressure populations, heat-graph telemetry, and the
  safe configuration switches.
- **Profiling** separates reaction events from reaction timing. The event history records meaningful
  reaction amount changes. The optional profiler measures every Rust reaction call and stores only
  calls over its cost threshold. It is useful for a short investigation and intentionally costs
  extra while enabled.
- **Fire Groups**, **High-Cost Zones**, **Explosions**, **Breaches**, and **Structures/Machines** are
  bounded trails for finding where the atmosphere's paws have been.
- Dogmos atmospheric goggles bring those trails onto the map: the station-safe pair shows breach and
  reaction profiles, while the administrative pair adds cost, structure, and full-Kennel overlays.
- **About**, **Glossary**, and **Credits** keep the kennel's vocabulary and project history close to
  the tools without making the code carry a second manual.

## A note on the overlays

Gas overlays are tile-local visual feedback. A crisp edge can be the correct picture when a wall,
firelock, or other boundary separates air networks. The Kennel's overlay markers are diagnostic
annotations, not a replacement for the simulation's air topology.
