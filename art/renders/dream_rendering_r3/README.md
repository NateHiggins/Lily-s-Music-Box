# DREAM PRODUCTION RENDERING R3 — THE FAMILY LOOKS DIFFERENTLY

Production capture, 2026-08-20. Governing target:
`art/reference/dream_surface/stage4_room_colonisation.png`. R3 completes the
licensed deterministic eye-family slice. It does not claim the torn breach,
impossible interior, phase/warp work, portals or RECURSION.

## What changed

- Every eligible dark-live danger owns five eye anchors on its existing growth
  branches. The target pocket therefore holds at least ten deterministic eye
  records across plural dangers; five are visible in this establishing frame.
  Each record publishes stable eye/source ids, its actual anchor, 0.76–1.34 scale, local
  forward and ±14-degree roll, resting aperture, 0.045–0.073 Hz blink timing,
  and an authored gaze target/behavior.
- Four of every five eyes rest closed or half-lidded. A blink occupies only a
  short part of a long 14–22 second cycle and can close an eye further; it does
  not make a resting closed eye spring open for spectacle.
- One eye in the complete live batch—not one per hazard—is permitted direct
  camera attention. Its shell and lid stay fixed while iris and pupil slide no
  farther than 0.28 of its radius in its own seeded local frame. The remaining
  eyes look at their hazard root, a branch tip or the remembered room centre.
- The first implementation had seeded controls but still photographed as
  repeated gold buttons. The accepted form adds a larger wine-dark physical
  lid and nests antique sclera, iris and black pupil at separately protruding
  depths. The family now has one readable watcher and quieter shut relatives.
- Center/flag, local-side/tracking, local-up/radius and blink/rest/target data
  are four custom vertex channels in `DreamHazardGrowth`'s existing ArrayMesh.
  Every eye and all dark-live hazards remain one submitted surface. There is no
  per-eye node, material, draw, collision, light, damage volume or attention
  system. Eyes remain presentation; `DreamHazardField` remains danger.
- `DREAM_EYE_DEBUG=1` suppresses the body and colours resting aperture from
  ochre to bone while marking the sole direct tracker magenta.
  `DREAM_EYE_DEBUG=2` colours the fixed root/room/branch targets through blue
  and violet and the camera target pink. These are shader views, not geometry.

## Frames

All captures use the real production room, player inspection lamp, exposure
field, furnishings, hazard body and 2560 × 1440 Compatibility renderer.
`DREAM_TARGET_DWELL_S=5.0` asks the real exposure owner for one stationary
five-second write; no eye or corruption stage is forced by the harness.

- `01_furnished_breach_lamp_on.png` — lamp-awakened family. The open eye at
  lower left of the central trunk is the compositional watcher; the long slit
  on the right branch and three quieter anchors show the resting hierarchy.
- `02_furnished_breach_motion.png` — same field and camera 150 frames later.
  Anatomy and asynchronous long-cycle eyes continue moving without topology
  or collision change.
- `03_furnished_breach_dark_live.png` — lamp off. Plum body, dim ochre eyes and
  black pupil remain locally readable; they do not light the apartment.
- `debug_rest_tracking/` — the same three-frame cadence with diagnostic 1.
  Pink is the one direct tracker; darker ochre shapes are closed/half-lidded.
- `debug_gaze_target/` — diagnostic 2. Blue/violet/pink separate authored
  root, room, branch and camera targets while all non-eye anatomy is black.

Shader TIME and the body continue moving, so these are production evidence,
not pixel-identical A/B frames.

## Proof

- `DreamSurfaceTargetTest.tscn`: **47/47 PASS**. The added checks prove five
  unique records per danger; exact deterministic reconstruction; scale, phase,
  rate, orientation and target bounds; four-of-five closed/half-lidded states;
  exactly one camera tracker; fixed gaze diversity; and diagnostics defaulting
  off. The existing ownership checks still prove one surface, no collision and
  one authoritative hazard population.
- `DreamRoomBuilderTest.tscn`: **175/175 PASS**.
- `DreamHazardTest.tscn`: **42/42 PASS**.
- `DreamLineageTest.tscn`: **21/21 PASS**.
- Fresh real-window `PERF_DREAM=1` at 2560 × 1440: **PASS**, 0/4 stations over
  16.6 ms. Rows were 2.45 ms / 45 calls, 2.00 / 78, 1.92 / 133 and 2.04 / 172.
  R3 adds vertices and attributes to the one hazard draw, no submission.
- `WalkTest.tscn` FAST x8/480: **PASS** with the inherited null-layout log.
- The first FULL x8/480 run hit the existing timing-sensitive roof-monitor
  traversal at z=2.9 and exited 1. An immediate fresh-process rerun completed
  **PASS**, exit 0. Both retain the pre-existing null-layout, resident-route,
  headless broadcast-texture and non-finite safety-net diagnostics; the R3
  files own none of those paths.

## Honest boundary

R3 makes eyes individual and compositional; it does not make the wall behind
them deep. R4 is the first torn breach and cheap impossible interior. It must
consume `DreamAtlas`/`DreamRoomBuilder` space and the existing material layers,
not start another topology graph. `DreamHazard` remains the only danger owner.
Warp, phase states and portals wait for their later gates, and RECURSION remains
priced but unlicensed.
