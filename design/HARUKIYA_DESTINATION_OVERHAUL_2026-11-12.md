# Harukiya as a full-cast destination

Evidence class: **INERT**. Owner commission and implementation plan, November 12.
Integration owner: Codex. Native and narrow technical checks are listed below;
installed room, attendance and artistic acceptance remain pending.

## Owner's current program

Lily commissioned a complete overhaul of the bar as a major destination capable
of holding the entire cast in a lively scene, then explicitly requested a full
drum set, a stage for a full performance, a backstage area, room to play pool and
darts, seating for everyone, and a balcony. These are required deliverables.
They expand the November 1 stage commission; do not freeze the older small stage.

Provide at least 21 actual NPC seat locations plus room for the player; aim for
24 seats if occupied clearance supports it. The count is 18 resident places
(including one alternating guest slot), Stacy, Lily and Adela. Performer/service
standing positions do not count as seats. Mina needs a reserved seat and a nearby
standing position until an approved seated presentation exists. Do not manufacture
an extra guest or ignore Adela's chronology merely to fill a review scene.

## Existing constraints and implementation findings

- The current main room spans source x -11.50..4.00, y -37.90..-28.70, floor
  z -2.80. The east descent remains 1.60 m clear; preserve the red door, threshold
  and practical entry route. Source coordinates pass through **GameBoot.b2g()**
  once and the bar region's -9.795 m world-Z translation.
- The existing well spans x -5.60..0.60, y -35.90..-31.00, with soffit z 2.52.
  Its 5.32 m clear height is the first balcony candidate. Survey continuous
  headroom, player capsules, structural bearings, stairs and stage sightlines;
  preserve the adjacent diner and outer building mass. The inherited low counter
  canopy stays. Ledger amendments in **docs/harukiya_reference_notes.md §0**
  govern identity and allowed section changes; stale Compatibility/arcade notes
  are superseded by current Vulkan and retired-cabinet decisions.
- Current stage is only 3.8 by 1.4 m. Design the stage, full drum kit, piano/bench,
  bass/singing positions, backstage and nearest audience tables together. Include
  hand/foot working envelopes and instrument transport, not just static bounds.
- Pool and Rainbow Round darts already have working rules/panels. Preserve their
  prop IDs, scoring and control owners while providing real cue/throwing space.
  Their panel interaction remains existing direct-manipulation migration debt.
- The 18-place resident registry is mounted but only consumed by a review bench.
  **ScheduleDirector.setup(null, layout)** intentionally disables the legacy
  physical dispatcher. Active V2 route graphs omit **harukiya_bar**: elective
  visits are filtered out and timetable visits map to offscreen **away**.
  A manually positioned crowd does not establish live attendance.
- Sixteen residents have walking owners. Rhea/guest route drafts exist but are
  unregistered and not played. Revalidate those drafts against changed collision
  before claiming the whole roster arrives. Stacy/Lily already have separate
  staff presentations; avoid duplicate actors. Preserve conversation/knowledge,
  calendar, disappearance and save authorities.

## Build and merge order

1. Freeze a measured floor plan and section: all seats, circulation, stage,
   backstage, pool/darts envelopes, balcony, stairs and load/support locations.
2. Rebuild affected native room families and new drum kit with shared UV/PBR
   helpers. Retain original failures and prove unrelated stock unchanged. Source
   plans, exact triangle retirement bindings and runtime geometry move together.
3. Connect active resident routes to actual bar access and reserve/arrive/present/
   depart/release occupancy. Support player seat contention and concurrent arrivals.
4. Integrate compatible cast presentation without editing Fable's owned wardrobe,
   hair, rig or clip files. Add purposeful groups/reactions through existing
   authored owners; no runtime language model or invented mystery knowledge.
5. Verify native/imported surfaces, occupied routes, normal bar services/games,
   real scheduled arrivals, teardown/save boundaries and measured full-cast cost.
   Capture ground/balcony/stage/backstage views with actual production lighting.

Use nearby preflights before the composed run and reuse unchanged evidence.
All Godot/GPU work remains on the logged FIFO lane and hidden desktop. Distinguish
implemented, technically verified, played and artistically accepted outcomes.

## Current implementation checkpoint

The selected plan keeps the original room and tall well: a 5.5 by 3.25 m stage,
approximately 6.75 m² backstage, a balcony floor at source z 0.0, 16 rises of
175 mm and 24 actual seats. Ten seats are upstairs, fourteen downstairs. The
upper landing has a real open passage beneath it; the ground-floor west route
must use that passage rather than cross the middle of the stair flight. Pool
moves one metre west; darts receives a separate south-facing backstop, score
panel and throwing lane. Exact datums live in the new destination layout JSON.

The immutable original shop cell is a retirement witness. The source preparation
recovers each named stock's actual original vertices, selects its exported faces,
and requires exact counts before writing a retirement manifest. Runtime removes
those faces and their collision counterparts, preserving unrelated imported
attributes. Original native pool, piano, microphone, curtains and dart target fit
their old source first, then receive explicit assembly transforms. Removed chairs,
decks, rods and plants must leave neither ghost collisions nor baked shadows.

The full native kit is built: 31,468 triangles, thirteen surfaces, footprint
approximately 2.0 by 1.56 m. Four neutral native views and strict metric-chart,
tangent, closed-stock and exported-contact checks passed. Kit placement, loaded
materials and actual performer contacts are not yet qualified.

The weak-owner reservation lifecycle passed 80 checks in the focused Godot
fixture, including player contention, false owners, FIFO, cancellation and dead
actors. This is a narrow state test, not a claim of scheduled arrivals. The
new player seats use the existing grab/move/release **SeatGestures** owner,
sharing occupancy with residents; new click-to-toggle sockets are not added.

The exact clean baseline at **35e586b939297150c1dca5705f813387fcdb0675** is in
**C:/ov/reports/harukiya_overhaul_20261112/baseline_board/**: 122 gates,
117 PASS, four existing FAIL and one INCOMPLETE. The reused **sky-verify**
checkout is static verification only, under Codex custody, with no Godot runs.
Final comparison must use this board and preserve its original failures.

## Current work custody

Codex owns canonical integration, source retirement and actor placement. Bounded
agents own the new native architecture/layout, reservation/route/seat integration,
and nearby actual-player verification. Native kit work is delivered. Fable was
notified through the bridge; her cast files remain hers. Reports:
**C:/ov/reports/harukiya_overhaul_20261112/**. The current branch is
**codex/harukiya-overhaul-20261112**; the machinima skill checkpoint is
**6ce4a812a**. The first nearby production run mounted the room and passed independent original-
face retirement and stage/kit/backstage/balcony contracts. It exposed compressed
metric charts, five pre-existing uncollidable retained stool tops and one blocked
balcony approach. Original **runtime_01/** compile failure and **runtime_02/**
loaded failures are preserved. The two-line route type repair compiled cleanly;
all 80 narrow reservation/FIFO checks passed. Source is released for those bounded
repairs; actual-input routes, crowd, attendance and candidate qualification remain
open. No artistic acceptance is claimed.
