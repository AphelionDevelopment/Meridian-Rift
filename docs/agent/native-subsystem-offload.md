# Native subsystem offload

This guide records investigation context and source ownership for work that moves expensive DreamMaker processing into Rust. The original Dogmos observations below are historical; verify the selected checkout and artifact pair before treating them as current implementation facts. This is an investigation aid, not approval of a particular architecture or implementation plan.

## Source authority

- DreamMaker integration is owned by the `dogmos` branch of `AphelionDevelopment/Meridian-Rift`.
- Rust implementation is owned by the `dogmos` branch of `AphelionDevelopment/aphelion-dogmos`.
- The Meridian-Rift `aphelion-agents` branch contains agent guidance and the RIFT controller. Its game code is not evidence of the active Dogmos implementation.
- Generated `code/__DEFINES/dogmos_bindings.dm` is an artifact of the Rust exports. Change the Rust binding declaration and regenerate it instead of hand-editing the generated wrapper.
- Reverify the active branches, revisions, generated DLL, generated bindings, and BYOND version together before debugging cross-repository behavior.

## Historical Dogmos boundary and current source routing

The original investigation examined an in-process, 32-bit ByondAPI DLL whose allocations occupied DreamDaemon's address space. It recorded two execution models:

- The main gas pass enters Rust synchronously and uses Rayon internally before returning to DreamMaker.
- TurfHeat uses a persistent asynchronous worker and queues operations that require BYOND access for main-thread execution.

Reusable patterns from that investigation include a Rust-owned mirrored graph, stable numeric turf references, registration generations that reject stale callbacks, explicit callback draining, per-fire time budgets, telemetry, and idempotent shutdown. The queue inspected then was unbounded and atmos-specific; recheck the current queue contract before reuse.

At local `origin/dogmos` revision `39e05dec05938972148414074b68386eea83ff3e`, inspected on 2026-09-05, `modular_aphelion/modules/dogmos/code/service_backend.dm` starts `dogmosd` through `dogmos_service_start()` and requires its health check. The generated bindings expose service lifecycle and telemetry calls. This is source evidence for a service-backed integration, not a fresh native build or live runtime qualification. Read that branch's integration, service-lifecycle, and native-artifact guides with its paired Rust revision; do not assume all simulation state still resides in DreamDaemon.

Never retain or dereference ordinary BYOND references from arbitrary worker threads. Copy required scalar state into Rust-owned structures. Re-enter BYOND only through the supported main-thread mechanism, and validate the object's generation before applying delayed work.

## Lighting structure

Read `.github/guides/VISUALS.md` before changing this system.

The complex-lighting path is source-driven and has three DreamMaker queue stages. The four items below include the controller entry point and those three stages:

1. `code/controllers/subsystem/lighting.dm` runs `/datum/light_source/update_corners()`.
2. `code/modules/lighting/lighting_source.dm` discovers affected turfs with BYOND `view()`, expands them to shared lighting corners, applies cached falloff, and accumulates RGB contributions.
3. `code/modules/lighting/lighting_corner.dm` quantizes changed corner colors and queues affected turf lighting objects.
4. `code/modules/lighting/lighting_object.dm` builds the final per-turf color matrix on the BYOND lighting object.

One lighting object is attached to each participating turf. A lighting corner can affect four turfs. Movable light sources enqueue updates through movement signals. Opacity changes invalidate affected visibility.

Falloff-sheet generation is pure and cached. Moving only that calculation to Rust is mechanically easy, but it does not remove BYOND `view()`, associative-list set operations, corner accumulation, or final object mutation. Treat it as a possible micro-optimization, not proof that the subsystem has been offloaded.

A substantial offload requires a mirrored topology and a visibility implementation with demonstrated parity against BYOND `view()`, including opacity, directional opacity, built-in luminosity behavior, multiz transparency, z-stack relationships, fractional ranges, offsets, direction, angle, height, and final color rounding. Final BYOND object mutation remains a main-thread responsibility.

## Camera structure

The camera system is chunk-driven:

- `code/controllers/subsystem/cameras.dm` owns cameras, generated chunks, and the lazy update queue.
- `code/modules/mob/living/silicon/ai/freelook/chunk.dm` owns chunk visibility, obscured-turf images, watchers, and resumable updates.
- `code/game/machinery/camera/camera.dm` implements `/obj/machinery/camera/can_see()` with BYOND `view()` plus multiz expansion.
- `code/__DEFINES/cameranets.dm` sets `MAX_CAMERA_RANGE` to 7 and `CHUNK_SIZE` to 8. The range cap is coupled to invalidation coverage.

Watched chunks request a near-immediate timer update. Unwatched chunks coalesce changes for the background camera subsystem. Applying `client.images` changes must remain on the BYOND thread.

The current chunk loop can call `can_see()` for the same camera while updating multiple neighboring chunks. Before translating the existing loop literally, profile a camera-centric alternative that computes each dirty camera's visible set once per update epoch and distributes that result to affected chunks. Any native implementation still needs parity tests for ordinary cameras, X-ray cameras, darkness/luminosity behavior, opacity changes, camera movement, multiz traversal, and watched-chunk latency.

## Candidate deployment models

Keep the domain implementation independent of the transport so both models can be measured:

- In-process DLL: lowest boundary overhead and simplest reuse of ByondAPI, but it remains inside the 32-bit address space and a fatal native fault can terminate DreamDaemon.
- Separate 64-bit worker: removes the worker's state from DreamDaemon and improves fault isolation, but requires an explicit protocol, lifecycle supervision, bounded queues, resynchronization, stale-result rejection, and latency measurements.
- Hybrid bridge: a small 32-bit ByondAPI DLL owns BYOND interaction while a supervised 64-bit process owns computation and large mirrored state. This was a candidate in the original investigation; the Dogmos service integration now needs to be evaluated from its own current source and artifacts.

For an out-of-process design, use fixed-width values and offsets rather than pointers across the 32/64-bit boundary. Batch topology and source events. A control channel can carry handshake, health, shutdown, and resync messages while a bounded shared-memory data path carries high-volume work. Use per-world and per-object generations, monotonically increasing input epochs, explicit deadlines, latest-state coalescing, and observable backpressure. Define what happens when the worker is absent, late, restarted, or incompatible before enabling it in production.

## Latency classes

Do not apply one scheduling policy to every update:

- Active movable lights and watched camera chunks are interactive work. Measure them against a strict next-render or next-subsystem-fire deadline.
- Map-load lighting, static topology rebuilds, and unwatched camera chunks can use larger asynchronous batches.
- Final lighting matrices and camera images are BYOND mutations and must be applied under a bounded main-thread budget.

Results from an older epoch must never overwrite newer state. If a result misses its deadline, the design must specify whether DreamMaker computes a fallback, preserves the last valid render, or marks the subsystem degraded.

## Required evidence

Do not approve a native rewrite from an idle server trace alone.

1. Capture startup, populated-round, movable-light burst, door/opacity churn, watched-camera, unwatched-camera, camera-movement, multiz, and map-change workloads.
2. Record queue depths, coalesced events, dropped or superseded work, worker time, bridge time, main-thread apply time, end-to-end age, memory, and restart/resync duration.
3. Build a deterministic replay corpus from DreamMaker inputs and compare native outputs with the DreamMaker reference implementation before changing ownership.
4. Keep a feature flag or shadow mode while measuring parity. Shadow mode must not double-apply effects.
5. Test DLL/worker version mismatch, absent artifacts, panic, process crash, hung worker, queue saturation, world reboot, and hard shutdown.
6. Verify the exact 32-bit DLL ABI and the exact 64-bit worker artifact in CI and release packaging.

Meridian-MCP parsing and Tracy captures are evidence sources, not compiler or product-acceptance gates. Report invalid profiler clocks, synthetic maps, missing players, and unexercised branches explicitly.
