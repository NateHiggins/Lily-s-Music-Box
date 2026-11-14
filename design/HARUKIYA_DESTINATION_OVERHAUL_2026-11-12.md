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

**roster_runtime_03/04** preserve subsequent independent blockers. Runtime03
clears the bed repair, then hits PRIMARY_F03_F04 StairGuards. Both new files
lacked the existing Malcolm3A/Cam-Noel4C intermediate point at
**(3.76,floorY,-3.35)**; added exactly that shared route point. Native guard bounds
explain the old line's0.2988m versus the new0.4046m clearance against the original
0.30m authoring capsule. See **roster_intake_04/SHARED_ROUTE_REVIEW.md**.

Runtime04 at **8b8f112c1** (PR259 integrated) passes all13 Rhea closed-leaf chains,
then fails open-leaf settlement within8s. No guest/open-leaf/walking acceptance.
The prior fixture called **npc_set_open** without normal renewed passage holds;
real closers may return, and per-leaf timeout telemetry was missing. Correction
uses the actual actor's **hold_passage/request_passage**, retains the original8s
bound and native motion, records each leaf, and releases temporary holds before
exact custody restoration. This is a fixture correction; the original timeout
is not retrospectively attributed to a particular leaf without its missing data.

The next mechanical journey begins and ends at the actual **unit:bed** mapping,
with native identity/full-capsule/initial-floor checks and ordinary graph prefix
verified. It will cover both repaired corner legs under the unchanged40mm motor
waypoint rule, if it passes; no extra teleport or forced waypoint is introduced.
PR260 remains draft/unqualified. Reader tests30/0; original failed contracts kept.

**roster_runtime_05**, source **ea967c356**, refines that diagnosis with actual
per-leaf telemetry: all27 closed-leaf chains clear (13Rhea,14guest). Both open
states still fail; F01_DOOR_06 reports opening_clear=false with the real player
at default arrival(0,.04,1.5). The first Rhea attempt has unadvanced moving leaves and expired wall-clock
holds; startup timing is implicated, but render/request/frame costs were not
measured separately; later guest
leaves are all ready except that front leaf. The hold repair alone was not a
successful remedy. Original result remains; no door defect or journey pass is
inferred. Fixture now waits for two actual windowed draws and physically walks
player via the established motor to named sidewalk stations before the same8s
settlement check. No teleport, collision-mask change, timeout relaxation or
production opening/custody change. The next composed result remains required.


### Open-leaf and arrival qualification; return deadlock (November13)

**roster_runtime_06**, **c63909a22**, executes all54 chains with the original
capsule and closed/open states. Actual input withdrawal clears the front sweep;
leaf settlements finish in435–542ms. Exactly two open bathroom-leaf corners
fail on kitchen_hall_opening_b→private_hall. All27 closed chains pass. Original
failure retained; no resident walking in this run.

The two repaired chains add only(-7.65,floorY,-8.20) on the hall side. Original
anchors/endpoints, native fittings, access and capsules stay unchanged. Nearby
**roster_runtime_07/door/door_clearance.json** mounts the real fitted doors from
original layout/specs: both original diagonals fail, both repairs clear at1cm
samples and bidirectional sweeps, as do two4cm early-turn variants. This is an
open-leaf diagnostic only, not all motor trajectories, casings or floor proof.
**roster_intake_05/BATH_LEAF_REVIEW.md** and **DOOR_FIXTURE_REVIEW.md** preserve
geometry/shortcut calculations and limits. Spatial audit remains clean, no drift.

**roster_runtime_07/roster/runtime_contract.json** passes registry, all54 installed
chains, both actual assigned-seat arrivals and exact preview/input custody.
One declared bed-node start per actor, normal1.05m/s, real floor/capsules/doors,
actual real-player withdrawal; unrelated residents frozen/hidden. The run uses
c63909a22 plus the frozen two JSON detours/new nearby fixture; **FREEZE.json**
records actual input hashes. It does not claim a clean candidate checkout.

Return fails at the original300s deadline: both actors safely wait .602499m
apart at z21.755, Rhea x-3.092499 and guest x-2.49. Rhea reverses east from
gallery_rear toward the distant upper stair holding pocket while the guest
walks west along the same aisle. Both seats are released; neither has a return
stair admission. No collision/speed/motion failure was reported, but completed
return/continuous-motion/passage contracts remain FAIL or unexecuted. Test590.264s,
wrapper612.85s; completed failed receipt preserved. This is a real queue-route
conflict, not a reason to extend the timeout or remove body spacing.

Next is a nearby actual-controller reproduction and a FIFO-safe free-stair
admission correction. Busy/opposing/crowd behavior must remain qualified separately.
PR260 stays draft until complete journeys and candidate checks pass. Natural
attendance, cast fit, full occupied-world cost, human play and artistic acceptance
remain open. New main PR261/262 input review is private **roster_intake_05/
MAIN_DELTA_REVIEW.md/json**; broad runtime hashes change and are never repinned.


### Complete registered journeys and FIFO repair (November13)

Main **559e0f431** is integrated at local **0bf7bb594**. The five-line BarRoute
change first tries the existing queue-head/exact-body admission against actual
passage clearance, then uses the original holding pocket only when refused.
Native geometry, route endpoints, collision masks, motor speeds and deadlines
remain authoritative. Near-passage eligibility and active-token safe-exit logic
are unchanged. This fixes the demonstrated free-stair reversal; it does not
promise liveness for every opposing/third-body obstruction or paused actor.

**balcony_departure_01** reproduces the original runtime07 face-off in21.1s.
**roster_runtime_08/09** prove both stair descents but fail at diagnostic remote
goals: first a stopped actor obstructs its follower, then a separate diagonal
clips the real backstage west jamb. Those failures remain. The final nearby
fixture ends at original stair_approach/west_bypass,2.30m apart, already crossed
in the earlier runs. **roster_runtime_10/balcony/runtime_contract.json** is a
schema2 diagnostic,1409/0, both native descents and exact seat/stair releases.
Its endpoints differ from the negative beyond the reproduced upper-gallery
prefix; this is not a strict identical-fixture full end-to-end A/B comparison.

**roster_runtime_10/roster/runtime_contract.json** is completed schema2 runtime
proof:132/0, all seven contracts executed/PASS. Registration, all54 installed
closed/open route chains, both normal1.05m/s bed-to-assigned-balcony arrivals,
both returns to the exact original bed/floor, continuous supported motion,
all8 actor/direction/passage admissions and campaign/input/preview custody pass.
One declared initial placement per actor; all native collision and the real
player remain. Unrelated residents are frozen/hidden. Outbound134.6s, return
149.4s, original300s bounds unchanged; test542.079s/wrapper573.54s, finished
November14 01:19:17Z. The wrapper records clean completion; original driver
OpVectorExtractDynamic messages remain in stderr and are not rendered approval.

The test and broad physical/runtime/transitive inputs remain frozen through
completion. Evidence records **0bf7bb594** plus actual uncommitted input hashes,
not a fabricated clean candidate. Runtime digest **050c7b1c74f51b40480963484a95b3d7f19f4766ba27168573455c74a598838b**;
physical digest **b705674e81dc60267eb678173cc5e8cd01b04fdd9335381d8d180dabf32a564d**.
Candidate reuse must prove exact consumed-input identity; never repin this receipt.
MysteryWiring0fail and CastModelPresentation134/0 cover the integrated main delta;
reservation154/0 is reused against its eight unchanged source hashes. Private
**roster_intake_06/FINAL_CONTROLLER_REVIEW.md** explains queue/retarget and scope.

The added3s early failure requires this isolated pair's exact person-wait state,
nonempty paths and no physical movement; ordinary path-cleared FIFO waiting is
excluded. It shortens a demonstrated diagnostic deadlock, never accepts one.
Hash attributes preserve source bytes; only three new nearby spatial records are
registered. Final clean candidate/gate/merge evidence follows in
**roster_candidate_02**; this runtime result alone does not merge PR260.

Backstage access is still open: actual runtime09 oak collision matches a route
crossing the835mm public aperture off axis; .276m next-step clearance fails the
unchanged .28m radius. Private **roster_intake_06/BACKSTAGE_ACCESS_FINDING.md** and
**roster_intake_07/** retain the measured cause and unqualified minimal waypoint
proposal. Natural attendance, occupied crowds/cost, cast fit, human play and
artistic acceptance remain separate; Lily's own walking/following remains held.


### Backstage public-aperture repair (November13)

PR260 is merged **fcc353bf267b9c4c11df755b982eb938ab257929**, identical tree to
qualified **5f74a1bf6062288db02cb4234abb1a450b32955b**. Clean134-gate candidate
comparison has zero regressions/no waivers,17/17protected,V2,lint0 and unchanged
ledger. **roster_candidate_02/MERGE.json** binds that manual expected-head merge.

The separate backstage branch adds only **backstage_public_axis** at source
(3.15,-35.4,-2.8), splitting the former entrance-to-backstage diagonal. It stays
on the835mm aperture axis until clear of the jamb, before turning toward the
original backstage point. Native meshes, all non-navigation layout values,
existing endpoints, body profiles and motor rules remain unchanged.

**backstage_runtime_01/backstage/runtime_contract.json** is a completed nearby
schema2 diagnostic,80/0, no unexpected engine errors; wrapper33s, finished
November14 01:37:44Z. Both original player/resident diagonal controls hit the
actual oak. Repaired bidirectional1cm capsule samples/sweeps clear with real
floor support. Actual player input walks entrance→backstage→raised stage→entrance
and clears aside through normal input; Rhea then makes the same round trip via
the original route/motor at1.05m/s. Each body has one declared initial placement.
Independent height/support checks prevent the old service-walker's broad Y
arrival tolerance from accepting the lower floor as the stage. The .33×1.524m
player body is unchanged; flat-jamb queries use only a3mm floor skin, while its
unmodified low-step motor proves the stage. Resident .28×1.40m/body lift remains
its production profile. Native oak and ordinary motion are never excluded.

Actual inherited forward/return paths must include the new aperture datum and
stage_e. Test bindings cover reviewed text sources, native GLB/retained glTF/bin,
import declarations/parameters and exact preview restoration. There is no seat,
full-world, crowd, natural-timetable, gameplay-cost or artistic claim. Import and
compile pass; the broker's transient lane-holder-metadata file-lock warning is
retained, with no duplicate engine or lane bypass. A preparation console encoding
error occurred only in the last informational print after files were written;
batch/frozen hashes were verified and the original run retained.

Private **roster_intake_07/APPLIED_NAVIGATION_EQUIVALENCE.json** compares exact
native13 historical layout to current/applied navigation without changing the
original build inventory or receipts. **UNCHANGED_VENUE_PATHS.json** proves72
existing entry/seat/passage shortest paths, seat definitions and passage owners
unchanged. This supports narrow unchanged-geometry/path reuse, not a repinned
broad runtime10 receipt under a different runtime digest. Existing full-world
journey proof remains the qualified PR260 source, with current backstage movement
qualified by the new nearby run. Four new fixture spatial references are recorded;
no existing manifest record or audit rule changes. Final clean candidate and
manual merge remain required before this branch reaches main.
