# DREAM ORISON WALLS V1 — ARCHITECTURE THE BODY CAN OVERTAKE

Production capture, 2026-08-20. Governing composition reference:
`art/reference/dream_surface/stage4_room_colonisation.png`.

The previous target pass proved dangerous animated limbs and real Orison prop
meshes, but the room holding them was still four dark procedural boxes. This
slice gives each remembered generation the waking building's architectural
grammar before allowing the organic layer to consume it.

## Architecture

`DreamOrisonInterior` adds shallow, visual-only historic relief to the exact
room envelope owned by `DreamRoomBuilder`:

- 140 mm skirting and the Orison's canonical 1.32 m dado;
- framed wainscot fields in corridor/service modules;
- a 2.18 m picture rail and three-step cornice under the exact 3.015 m ceiling;
- jambs, head and cap around every live 0.91 × 2.13 m opening;
- a two-ring pressed ceiling medallion;
- the same analytic service-lamp material boundary as the walls, so the relief
  is not physically present but black because it missed the lamp update.

Every strip is one transform of a unit box. One historic-millwork MultiMesh and
one wainscot MultiMesh submit a complete room in at most two draws. The pass
owns no collision, light, sound, interaction or navigation state; the original
wall boxes and door records remain exact authority. BLANKING removes this
descriptive relief as well as contents and frames.

## Corruption

Every load-bearing hazard crawler now terminates in a shallow wall/ceiling
graft: six overlapping closed organic lobes with changing normals and real
cast-shadow thickness, plus seven fine capillaries running over adjacent
millwork. These stay inside the existing single growth surface. Fine wall
tissue is visual; the substantial crawler in front is still registered with
and evaluated by its source `DreamHazard`.

The first implementation was rejected from its own render. It used one broad
triangulated membrane whose constant normal read as a paper sail at the 2.08 m
hall camera. No acceptance frame from that shape was kept. Closed lobes replaced
it. The organic shader's gold was likewise changed from broad round spots to a
thin three-direction ridge network: wine-purple body remains visible in the
beam while gold is confined to veins, seams and eyes.

## Frames

- `01_furnished_breach_lamp_on.png` — the real service beam is biased onto the
  right wall contact so the dado, field panels, picture rail and living graft
  share the frame with the dangerous limb.
- `02_furnished_breach_motion.png` — same production camera and topology 150
  frames later; changed silhouette is shader motion.
- `03_furnished_breach_dark_live.png` — same frame with the service lamp off.
  Architecture falls away; the hazard and graft retain the ruled subordinate
  wine-dark presence and remain live.

The harness adds no helper light, environment, furniture, hazard, collision or
presentation geometry.

## Proof

- `DreamSurfaceTargetTest.tscn`: **31/31 PASS**. New assertions cover a shell
  decision per live generation, historic relief in every nonblank room,
  honest BLANKING, at most two added draws per room, no borrowed owner, exact
  dado/casing schedule, compiled service-lamp materials, wall grafts and
  same-surface capillaries. The pre-existing owner/contact/dark-live contract
  remains green.
- `DreamRoomBuilderTest.tscn`: **175/175 PASS** — 60-room walk, exact joins,
  bounded pocket, route and fairness geometry unchanged.
- `DreamHazardTest.tscn`: **42/42 PASS**.
- `DreamLineageTest.tscn`: **21/21 PASS**.
- `WalkTest.tscn` FAST x8/480: **PASS**, while still printing the inherited
  null `GameBoot.layout` error at `walk_test.gd:885`.
- `WalkTest.tscn` FULL x8/480: **two consecutive FAIL (1) runs at different
  unrelated waking traversals**. Run one missed the roof-monitor exit (final
  z=2.9) and passed the 2A bedroom; run two passed the roof (z=4.3) and missed
  the 2A bedroom (z=1.89). Both print the inherited null-layout, headless
  broadcast-texture and resident-route errors. The non-repeating failure on an
  unchanged build demonstrates the long harness is presently unstable. This
  pass changes only dream-scene code and enters neither waking route, so the
  red result is recorded as external flaky proof debt, not hidden as green.

Two fresh 2560 × 1440 `PERF_DREAM=1` runs stayed at **1.60–2.04 ms**, zero of
four rows over 16.6 ms. Census: 118 `GeometryInstance3D`, 61 shader-material
instances, 29 distinct molten materials; worst observed view was 172 calls.
The previous slice's worst observed row was 2.01 ms / 160 calls, so the added
architectural vocabulary spends at most twelve observed submissions and no
measurable frame headroom.

## Honest boundary

This resolves the owner's complaint that the room geometry did not resemble an
Orison interior. It does **not** close N10 C or D. The gold infection still
needs true tessera/grout and cracked-medallion surface relief; the wall still
needs the torn body-sized breach, rubble and impossible interior-mapped depth.
This is the architecture those later stages can now damage rather than another
flat wall they would replace.
