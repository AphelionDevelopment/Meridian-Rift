# Dogmos Glossary

## Auxmos

The atmospheric simulation lineage Dogmos was ported from. Dogmos keeps the useful numerical
foundation while adapting its integration, scheduling, callbacks, and player-facing contracts for
Meridian Rift.

## Dogmos

The Rust-backed atmospheric processing layer in this project. Think of it as the kennel's working
pack: gas flow, reactions, pressure equalization, and blocked-path heat conduction are coordinated
through shared DM/Rust handles.

## EWMA

An exponentially weighted moving average. The Kennel uses it for per-machine processing cost so one
brief noisy tick does not immediately leash a machine, while a repeatedly expensive machine remains
visible. The current sample is blended with the previous estimate through the existing
`MC_AVERAGE` rule.

## FDM

Finite-difference method. Dogmos uses bounded FDM steps to estimate gas movement between registered
turf mixtures. Each step works from the current graph and queues only the DM callbacks needed for
effects and bookkeeping.

## Hotspot

A DM fire datum attached to an open turf. Reactions determine gas changes; hotspots turn those
changes into temperature, fire growth, fuel checks, visual stages, and `fire_act()` consequences.

## Katmos

Dogmos' pressure equalizer. It handles pressure differences, bounded redistribution, hull-breach
flood fills, and the callbacks that need to return to DM. It runs after the main FDM flow pass.

## Kennel

The Dogmos diagnostic interface. It is intentionally bounded: event histories expire or cap their
size, target references are validated when followed, and expensive instrumentation is opt-in.

## LINDA

The inherited DM atmospheric system and the surrounding gameplay contracts. Dogmos replaces the
repeated numerical flow work, but LINDA's names and DM-side effects remain important integration
points for hotspots, machines, firelocks, and compatibility behavior.

## Reaction event

A recorded reaction amount change at or above the configured event threshold. This answers “what
changed enough to matter?” It is not a timing sample.

## Reaction profiling

Optional instrumentation that measures each Rust reaction call and records calls meeting the
high-cost threshold. It answers “which individual reaction calls cost time?” Because the timer is
paid on every call while enabled, profiling belongs in a short diagnostic run.

## TurfHeat

Dogmos' heat-conduction graph for blocked atmospheric paths such as walls, windows, and doors. It
keeps thermal work separate from ordinary gas adjacency and updates DM temperatures through guarded
callbacks.

## Excited group

A bounded group of low-pressure turfs maintained by the atmospheric subsystem. Group processing lets
the station handle connected regions without repeatedly treating every tile as an unrelated scent.
