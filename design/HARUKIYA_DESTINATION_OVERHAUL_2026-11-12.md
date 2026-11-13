# Harukiya as a full-cast destination

Evidence class: **INERT**. Owner commission and implementation plan, November 12.
Integration owner: Codex. Room/controller checkpoint merged in PR258; scoped
technical receipts are below. Full-roster scheduling, cast fit, performance,
play and artistic acceptance remain open.

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

## Initial constraints and findings (November12; historical)

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

The weak-owner lifecycle now passes117 focused checks in **runtime_05/**,
including shared player contention, FIFO, cancellation mid-seat/departure,
replacement-owner protection, revisit and unavailable-destination refusal.
This synthetic clip/isolated-physics fixture does not prove scheduled arrivals.
Player seats use existing grab/move/release **SeatGestures**, sharing occupancy
with residents. New click-to-toggle sockets are not added.

## Current integration and evidence (November13)

Codex integrates in **C:/ov/ldv**, the existing sky-verify checkout, branch
**codex/harukiya-integration-20261113**. Pushed **f4cdf27ab** incorporates main
**f1f524cc1**. Canonical checkout/index remain untouched. Intake36named paths and
five excluded bass WIP paths are recorded in **integration_intake_01/MANIFEST.json**
under **C:/ov/reports/harukiya_overhaul_20261112/**. Claude owns cast replacement.
Actual clean main baseline: **baseline_f1f524cc1/board.json**,134gates,
128PASS/5existingFAIL/1INCOMPLETE. Spatial union9584/zero drift; reader NEW0.

The seating repair lifts beside the high cushion, translates, then lowers;
departure reverses it. Each separately swept leg retains the full torso and
people checks, including interrupted movement and long frames. Ten new balcony
chairs are now complete upholstered low stools; nine ground backed seats retain
furniture origins and140mm forward sitter contacts. The upper lounge ledge and
its bearing move150mm wallward. Native13 retains24,788triangles/35surfaces and
859closed stocks. North seat pitch610mm preserves the narrow east aisle; return
pitch660mm leaves player courtesy clearance. Lounge04 moves210mm west on its
support deck and lounge03 has a clear approach. Rejected native11's wider north
pitch remains recorded; no collision body was shrunk or excluded.

Current source-bound technical evidence:

- **runtime_14/stance/runtime_contract.json**:885/0. All24 native supports,
  rendered support surfaces, full player approaches and bidirectional torso
  paths;48 synthetic occupied-NPC path checks and real-player obstruction
  negative control. The original high-stool diagonal still collides.
- **stance_preflight_06/reservation/runtime_contract.json**:154/0 unchanged
  lifecycle checks, raised obstacle, interruptions, cancellation and corners.
- **runtime_14/destination/runtime_contract.json**:1394/0/eight contracts,
  nearby motor stage/backstage/balcony roundtrip including east aisle, actual
  seat input, original games twice reopened, stair obstruction and loaded
  UV/PBR/mips. Five technical views inspected.
- **runtime_14/geometry/batch.json**:28571/0: furniture1657, mounts364,
  stage24454, pipe supports2096. Strict contacts, self-support exclusions and
  original fixtures retained. Receiving retirement aliases and coplanar support
  recognition are test repairs, not fixture repins. Furniture emits schema2;
  aggregate and other modules remain legacy diagnostics. Eight backend shader
  warnings remain in stderr; do not claim clean stderr or promote batch evidence.
- **runtime_14/crowd/crowd_diagnostic.json**:223/0,21 current presentations,
  six inspected images. Eighteen legacy residents, shipped Lily/Stacy and the
  labelled legacy Adela preview. Private pelvis offsets are not production fit.
  Empty controls drift; no reliable incremental or complete-world cost claim.

**runtime_16/attendance/runtime_contract.json** is terminal PASS41/0, all five
contracts: three actual nearby arrivals, opposing balcony FIFO, player obstruction
and ordinary withdrawal, departure with exact seat release, and continuous motion.
Test229.586s, wrapper254s; runtime/physical/test bindings stayed frozen. Other
residents were hidden/frozen; this is not natural schedule or whole-roster proof.

Two original failures remain: runtime14's3D walking-speed validator mistook a
supported175mm tread for a teleport; runtime15's actual departure hit the retained
lobby litter crate. Motion validation now retains horizontal/seating limits and
independently ray-tests nontrivial vertical corrections, including a20mm unsupported
lift negative. Two authored lobby waypoints route around the crate without changing
its stock, collision or body sizes. **runtime_16/stance** passes904/0 including
native forward/reverse capsule sweeps and the original blocked straight-path
negative. This is narrower than a full-size player entrance proof.

**runtime_16/GEOMETRY_REUSE.json** records deep equality of layout content except
navigation. Native13's original inventory source binding is preserved, not changed
to imply a rebuild. Runtime14 room/support/surface/game/geometry/crowd evidence is
reused only for unchanged claims; the changed graph is exercised by runtime16.
All original failures and warnings remain preserved. No artistic acceptance.

Next is a qualified room/controller checkpoint and clean candidate comparison.
The full order stays open for reviewed Rhea/guest route registration, natural
scheduled attendance, model contact fit, occupied gameplay and whole-world cost,
human play and artistic acceptance. Private roster drafts are not installed.
Claude owns the new Stacy investigator brief and confirms no competing owner of
those two route drafts. Preserve one Stacy actor; her future travel must not
accidentally hide Lily. Do not confuse posed crowd evidence with full-roster
attendance or a wrapper receipt with a test-written runtime contract.

## Merged checkpoint and remaining roster intake

PR258 merged **971e651ea**, identical tree to qualified **8bd9cba07**. Candidate
comparison reports zero regressions,17/17 protected paths, V2 and clean document
lint. Three audit changes were reviewed; all9327 prior spatial records remain
exactly, plus257 additions. No new file-reader exceptions or gate waivers.

Root's follow-up **codex/harukiya-roster-20261113** locally registers the two
reviewed Rhea/guest drafts through the existing route table. They are not mechanically qualified or merged. The obsolete mail chain and
subsequently reproduced bed-corner approaches changed from the preserved
historical sources. Current geometry/registered-owner movement and then conditional
natural attendance remain required; Juno's presence can legitimately deter Rhea.
The cast/main/lane hold is released to Claude, with future source freezes coordinated.

## Roster intake diagnosis, November 13

**roster_runtime_01** at **d6f725ebe**: registration and exact preview/input custody
PASS; first Rhea closed-leaf bedroom chain fails at the native bed corner. Guest,
open-leaf and all travel contracts are unexecuted. No ordinary-walker failure is
claimed: this is the unchanged 0.30m authoring probe (walker radius0.28m). The
original receipt remains intact. One source-supported graph detour is applied
to each matching apartment, preserving endpoints/furniture/keys/capsules; both
new segments require actual validation. See **roster_intake_03/** for native
part equivalence, limitations and proposed/current source hashes. No full order
closure, played or artistic acceptance follows.

**roster_runtime_02** at **874d5604d** (PR257 integrated) preserves the second
failure: first suggested **bed_approach -> bed** path still hits3D_bed at40%.
Registration/custody PASS, all walking unexecuted. Import and compile passed;
world startup95.336s, fixture130.355s. Installed native bed transforms and four
identity-local ConcavePolygonShape3D parts are recorded in its schema2 contract.

**bed_preflight_01** is a nearby native-only diagnostic, not runtime qualification.
It mounts the production bedding variants through the actual furniture factory
at those observed transforms. Original direct and first-repair paths both block
on both beds; three wider candidates pass1cm samples and bidirectional continuous
sweeps with the original0.30x1.40 authoring capsule (397ms). Applied the smallest
one-point alternative **(-13.20,floorY,-9.96)**, preserving every original endpoint
and all mechanical authorities. Full floor/furnishing/door checks and actual
walking remain next. Its JSON retains source hashes, controls, hits and sweeps;
original failed cases are not overwritten. Natural plan now explicitly separates
60x idle pacing/retargeting from route failures; proposed Juno special-day rows
cannot be promoted into ratified canon or guaranteed attendance.
