# DREAM PRODUCTION RENDERING R4 — THE WALL IS THINNER THAN THE ROOM

Production capture, 2026-08-20. Governing target:
`art/reference/dream_surface/stage4_room_colonisation.png`. R4 completes the
licensed torn-breach and cheap impossible-interior slice. It does not claim
stage-ramped geometry, phase/warp states, a view portal or RECURSION.

## What changed

- One eligible dark-live danger in the complete live batch deterministically
  owns one dominant breach. The selected `hollow_runner@1.2` wound is attached
  to the positive long wall of its actual `DreamAtlas` room, displaced along
  that wall so its own root does not visually plug the opening. The record
  publishes hazard, socket, module, centre, inward normal and dimensions.
- Eighteen seeded torn-edge points define a 1.28 × 2.24 m ragged aperture.
  Broken plaster, six pieces of exposed timber lath, an interrupted living rim
  and seven shallow rubble pieces are real triangles. All remain inside
  `DreamHazardGrowth`'s existing `ArrayMesh` surface.
- The apparent interior is one opaque wall-thin face. Nine bounded angular
  frame bands, false-depth cables and one vanishing-point eye are evaluated in
  the existing lineage shader. The authored apparent depth is 32 m while the
  complete physical recess is 87 mm. No geometry is repeated down the tunnel.
- The aperture is deliberately double-wound rather than disabling culling for
  the much larger living body. This keeps the face readable under inherited
  mirrored room transforms while preserving the existing material and draw.
- The authoritative wall is not cut. A production physics ray still hits it
  behind the image. There is no new door, navigation edge, room, camera,
  `SubViewport`, `World3D`, collision owner, damage volume or hazard. This is a
  rendering consumer of Atlas space, not a destination.
- `DREAM_BREACH_DEBUG=1` isolates surface ownership: cyan is the mapped face,
  bone is plaster/rubble, and red-brown is timber. The living body is black.
  `DREAM_BREACH_DEBUG=2` shows recession bands, false-depth cables and the
  vanishing eye. These are shader views, not helper geometry.

## Frames

All nine captures use the real production room, furnishing, player inspection
lamp, exposure owner, hazard body and Compatibility renderer in a requested
2560 × 1440 real window (Windows yields a 2560 × 1421 client viewport). The
camera stands inside the breach owner's Atlas room and looks obliquely across
the face; no showcase light, wall, hazard or furniture is added.

- `beauty/01_furnished_breach_lamp_on.png` — lamp-awakened wine tissue,
  interrupted wound edge, exposed lath and antique angular recession.
- `beauty/02_furnished_breach_motion.png` — same production pocket 150 frames
  later. The living body continues moving; the wall and false volume do not.
- `beauty/03_furnished_breach_dark_live.png` — service lamp off. The body and
  rim retain their subordinate plum read while the impossible interior falls
  back toward a black void.
- `debug_ownership/` — the same three-frame cadence with diagnostic 1.
- `debug_recession/` — the same cadence with diagnostic 2. Gold identifies the
  nested frame lattice, pale curves the false-depth cables, and red the one
  vanishing eye.

Shader `TIME` and the body continue moving, so these are production evidence,
not pixel-identical A/B frames.

## Rejected passes and corrected readings

1. The first wall normal used `-Vector3.FORWARD` for the positive-Z wall. In
   Godot that points positive Z, outside the room; the real wall correctly
   occluded the entire breach. The inward normal is now negative Z and the
   camera proof prints centre, normal and stand position.
2. The first readable tunnel multiplied pale leaf above one and photographed
   as a white stage portal. The accepted pass is antique orange-brown with
   thinner bands, an almost-black volume and two crooked internal cables.
3. Individual rim ellipsoids read as gemstones pinned around an oval. They
   were removed. The accepted rim is a seeded, varying-radius path with three
   plaster gaps; its broken continuity reads as a wound, not a decorated gate.
4. A first test rejected the world because it counted every production camera.
   That repeated the project's known ownership-probe mistake. The corrected
   proof scopes camera/viewport absence to the breach owner and also requires
   it to share the root's `World3D`.

The three obsolete 1280 × 720 diagnostic iterations were deleted after the
causes above were corrected; only evidence from the final implementation is
retained.

## Proof

- `DreamSurfaceTargetTest.tscn`: **59/59 PASS**. The twelve R4 checks prove one
  deterministic breach, exact hazard/socket/module provenance, Atlas-wall
  attachment and authored-door clearance, physical tear counts, shallow/false
  depth separation, one submitted surface, intact wall collision, shared world
  ownership, no hidden viewport/camera, diagnostics defaulting off and exact
  reconstruction.
- `DreamRoomBuilderTest.tscn`: **175/175 PASS**.
- `DreamHazardTest.tscn`: **42/42 PASS**.
- `DreamLineageTest.tscn`: **21/21 PASS**.
- Fresh real-window `PERF_DREAM=1` at requested 2560 × 1440: **PASS**, 0/4
  stations over 16.6 ms. Rows were 2.16 ms / 45 calls, 1.98 / 78, 1.88 / 133
  and 1.97 / 172. The deep-pocket worst call count remains 172; the breach
  adds fragment/vertex work to the existing growth draw, not a submission.
- `WalkTest.tscn` FAST x8/480: **PASS**, exit 0.
- `WalkTest.tscn` FULL x8/480: **PASS**, exit 0 in 44.8 s. Both retain the
  inherited null-layout, resident-route, headless broadcast-texture and
  non-finite safety-net diagnostics; R4 owns none of those paths.

## Honest boundary

R4 proves a torn Orison wall can appear deeper than its whole room for the cost
of one face in the existing hazard surface. It does not yet make the breach
arrive through the durable exposure stages; geometry cannot pop into view.
R5 owns the bounded phase/warp-state decision and must stage any breach reveal
through continuous material state while preserving this wall/navigation
contract. R6 remains the first possible view-only portal. RECURSION is still
priced and unlicensed.
