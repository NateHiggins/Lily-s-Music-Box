# DREAM PRODUCTION RENDERING R2 — THE BUILDING INVITES THE INFECTION

Production capture, 2026-08-20. Governing target:
`art/reference/dream_surface/stage4_room_colonisation.png`. R2 completes the
licensed relief and architecture-bound transition slice. It does not claim the
seeded eye family, torn breach, impossible interior, warp or portal work.

## What changed

- Every room-local Klimt material now receives its authoritative XZ bounds,
  exact 3.015 m ceiling and one surface class. The one durable exposure field
  is biased toward the joints that class actually owns: floor/wall junctions,
  room corners, 140 mm skirting, the 1.32 m dado, 2.18 m picture rail, cornice,
  door/lintel material, shafts and the pressed ceiling rose. This is not a
  second growth simulation and it changes no topology, collision or hazard.
- `dream_architecture_relief.gdshaderinc` supplies a colourless, reusable R2
  vocabulary: 82 mm hand-set tessera faces, narrow 7–9 mm recessed joints,
  deterministic large concentric bosses, their raised rims and a branching
  leaf-crack mask. The existing shader remains the sole colour/exposure owner.
- Stage 1 divides the existing spiral drawing into tesserae. It does not tile
  bare plaster. Stage 2 raises broad 2.80 m-cell medallions through that field
  and opens nonmetallic cracks in the leaf.
- One-step grazing-angle parallax shifts the apparent relief, and four
  meter-space height samples tilt the final shading normal. Tessera relief is
  9–12 mm by surface class; bosses are 26–42 mm. The solid wall and its
  collision never move. This is the brief's licensed parallax answer, not a
  false navigable hole.
- The final normal is now present on solid converted material rather than only
  inside the transient molten bowl. The previous shader calculated relief and
  then mixed it away everywhere except the lamp core.
- `DREAM_SURFACE_DEBUG=1|2|3` provides architecture-pull, relief-height and
  stage-band views in the production shader. These are render modes, not extra
  surfaces or debug geometry.

## Frames

The three top-level beauty frames use `DREAM_TARGET_DWELL_S=5.0`. The shot
harness asks the real `DreamExposureField` to perform one five-second stationary
lamp write and uploads the real production texture; it does not set a shader
stage by hand.

- `01_furnished_breach_lamp_on.png` — after the ruled five-second hold. The
  spiral field breaks into small raised pieces and the denser centre carries
  broad concentric relief while the photographed Orison remains legible.
- `02_furnished_breach_motion.png` — the same camera and durable field 150
  frames later. Material motion changes; collision and topology do not.
- `03_furnished_breach_dark_live.png` — lamp off after the hold. The converted
  ornament persists dimly, the hazard remains wine-dark and live, and no gold
  becomes a room light.
- `control_no_dwell/01_furnished_breach_lamp_on.png` — the same R2 build with
  no authored dwell. It separates the solid-material/architecture change from
  a surface the player deliberately advanced.
- `debug_architecture/01_furnished_breach_lamp_on.png` — white is the bounded
  pull toward construction joints.
- `debug_relief/01_furnished_breach_lamp_on.png` — white is meter-valued
  parallax/normal height.
- `debug_stages/01_furnished_breach_lamp_on.png` — green is Stage 1; red is
  Stage 2, so overlap resolves yellow/white under the bright diagnostic output.

Each diagnostic directory retains the same lamp-on, motion and dark-live
three-frame cadence as the beauty proof, allowing the masks to be checked for
time stability and for accidental dependence on the service lamp.

The beauty set is therefore not a single-variable comparison to R1: it adds a
five-second gameplay-owned field write specifically to demonstrate both R2
stages. The no-dwell frame is the presentation control. Shader `TIME` and the
live hazard continue to move, so pixel subtraction is not claimed as exact.

## Rejected tuning and process findings

1. The first relief tuning put the grout lattice across the whole converted
   plane. The result was a black square grid — graph paper, not mosaic. The
   accepted pass narrows the physical joint and lets the existing spiral
   drawing decide which tesserae exist.
2. Multiplying relief by the already phase-diminished `leaf` value made R2
   mathematically present but nearly absent in the relief diagnostic. The
   shader now preserves the latent motif before the durable phase gate, then
   applies the gate exactly once through the Stage-1 band.
3. A headless beauty run rendered too slowly to produce its first 75-frame
   capture inside the 60-second bound and was terminated. The verified real
   window on the RTX 4080 completed all three frames in 8.8–12.1 seconds. This
   matches the repository rule: render harnesses require a real window;
   headless is for logic tests.

## Proof

- `DreamSurfaceTargetTest.tscn`: **41/41 PASS**. New checks prove the relief
  vocabulary, exact named anchors, room-bound shell/interior materials,
  shallow meter limits and debug selection.
- `DreamRoomBuilderTest.tscn`: **175/175 PASS**.
- `DreamHazardTest.tscn`: **42/42 PASS**.
- `DreamLineageTest.tscn`: **21/21 PASS**.
- Fresh real-window `PERF_DREAM=1` at 2560 × 1440: **PASS**, 0/4 stations over
  16.6 ms. Rows were 2.00 ms / 48 calls, 1.94 / 87, 1.85 / 133 and 1.95 / 172.
  R2 adds fragment work and no submission.
- `WalkTest.tscn` FAST x8/480: **PASS**, while still printing the inherited
  null `GameBoot.layout` error.
- `WalkTest.tscn` FULL x8/480: **PASS**, exit 0 in 43.9 seconds. It retains the
  existing null-layout, resident-route, headless broadcast-texture and
  non-finite safety-net diagnostics; none becomes a test failure.

## Honest boundary

R2 makes the Orison substrate grow raised ornament from its own architectural
joints. It does not yet compose the target room around a seeded family of
eyes, and it does not tear a wall open. R3 is the deterministic eye family:
seeded anchors, scale, blink phase, local orientation and sparse gaze, with
closed/half-lidded rest states dominant. R4 remains the first torn breach and
cheap impossible interior. `DreamAtlas` remains the only topology owner,
`DreamHazard` the only danger owner, and RECURSION remains priced but unlicensed.
