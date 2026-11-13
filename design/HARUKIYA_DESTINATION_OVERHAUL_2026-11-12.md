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

The weak-owner lifecycle now passes117 focused checks in **runtime_05/**,
including shared player contention, FIFO, cancellation mid-seat/departure,
replacement-owner protection, revisit and unavailable-destination refusal.
This synthetic clip/isolated-physics fixture does not prove scheduled arrivals.
Player seats use existing grab/move/release **SeatGestures**, sharing occupancy
with residents. New click-to-toggle sockets are not added.

## Current integration and evidence (November13)

Codex reuses **C:/ov/ldv** (existing sky-verify checkout), branch
**codex/harukiya-integration-20261113**, based on main **2f133edd1** after the
qualified door/loop PR255 merge. Canonical **C:/PleaseRemainOnTheLine** and its
index remain untouched. The36named source intake and five excluded bass WIP
paths are preserved in **integration_intake_01/MANIFEST.json** under
**C:/ov/reports/harukiya_overhaul_20261112/**. Main's cast/voice/companion hash
rules and door route behavior remain. Fable/Claude owns cast replacements.

The actual clean comparison board is **baseline_2f133edd1/board.json**:
132gates,127PASS,4existingFAIL,1INCOMPLETE. The earlier35e586b baseline is
historical, not the comparison for this candidate. Reader NEW0 is established
using exact delegated consumers/metadata and moving genuinely inactive planning
fields to **art/blender/harukiya_destination_authoring_notes.json**. Original
planning values and their source hash remain there.

Original failed cases remain preserved through **runtime_11/**; none is
relabelled or overwritten. **runtime_09/destination/runtime_contract.json**
passes 1,396 checks: complete nearby player motor routes, stair obstruction
negative control, actual seating, both original games opened/cancelled twice,
loaded UV/PBR/mips, 24 seat supports and five inspected views. Native08 exports
25,868 triangles in 36 surfaces. Cabinet/panel wall depth and their 33 mm
separation are corrected; eight original loaded bearings pass. Curtains are
visible again. Original source fixtures remain unchanged.

The one-world original geometry batch records stage 24,454/0 and fixture
mounts 364/0. Two furniture failures are the validator overlooking the disabled
receiving owner's removal record. Five pipe-bearing failures sample one landing
mesh across a coplanar landing/balcony seam; actual native rays demonstrate full
support. These two validator corrections are pending, with strict contact
tolerances and self-support exclusions retained.

**runtime_11/crowd/crowd_diagnostic.json** passes 223 checks, with 21 actual
current presentations and six inspected images. Eighteen resident presentations
use existing models/clips; Lily/Stacy use shipped base wardrobes and Adela uses
the explicitly labelled legacy preview. Candidate seating offsets remain
private diagnostics and are not applied to production. Empty controls drifted
materially, so this packet does not establish a stable incremental crowd cost
or complete-world performance. Detailed limitations are in **VISUAL_REVIEW.json**.

Attendance stopped at setup: its initial full player capsule blocking stance
was invalid. None of the five attendance contracts ran. Repair that nearby
fixture before the next composed launch; preserve real NPC owners, normal motor
movement and actual obstruction/release. Final candidate also needs integration
with main **01454f8c3**, a genuine clean board from that commit, and verification.
No Harukiya merge, human play or artistic acceptance is claimed.
