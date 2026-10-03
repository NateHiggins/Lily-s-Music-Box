# V2 roof access and resident door passages

Evidence class: **INERT**

REPORT - V2-ROOF-ACCESS / MINA-DOOR-PASSAGES - 2026-09-25

Branch / implementation HEAD / origin/main / merge-base:
main / 92447e5a4bfa6182f3354cb807af8b42464e2f48 /
3e46e7b3027da95aafd32f63b82a20e40e511035 /
3e46e7b3027da95aafd32f63b82a20e40e511035.
The final candidate includes this report. Its exact SHA and committed-tree
checks are recorded by the canonical verifier before push.

Worktree clean at end: implementation committed; the owner's modified
art/renders/insitu/shots.md and untracked shot_024.png, shot_025.png and
shot_026.png are retained separately from this work. Import-generated
untracked UIDs are removed. No secondary checkout is created.

Protected 17/17: unchanged from the merge-base. Selector: v2, with explicit
ORISON_BUILDING_ROOT=v1 rollback retained. Historical evidence is unchanged.

Ledger before -> after: 7/8/136/50/159/161 -> 7/8/136/50/159/161.
Requirements changed: **floor.ROOF** and **roof.roof_bulkhead**, ABSENT to
PROGRAMMED. They remain structural/cutover blockers: source geometry and
suite-run receipts are not schema-2 runtime-contract evidence. Tank/machinery
remains ABSENT. No evidence document promotes this work.

## Implemented scope

The roof at 19.2 m has seven connected deck sections, primary and service
bulkheads, both F06-to-roof U-stairs, landing slabs, two production DoorProp
leaves and continuous colliding parapets with coping. Only the two F06 core
ceilings change below it. The additive roof generator retains unrelated
records; source and projection checks cover this boundary. Existing brick
textures enter the runtime material table through its generator, without new
texture bytes or a visual-lock exception.

Mina now acquires doors crossed by her remaining route, waits for settled
leaves, and closes only doors she opened after people clear the swept volume.
Locks and opening/closing remain DoorProp-owned. Previously open doors remain
open. The player and residents participate in opening/closing clearance.
Her bathroom destination moves from the toilet collision to the existing
sink stance. Movement continues to test the installed collision world.

## Gates and executed checks

Static board: tmp/v2-roof/final-board/board.json, compared with the complete
clean board extracted from tmp/v2-cutover/verified/verification.json at the
merge-base. Result: NO REGRESSIONS. Completeness exits 2; spatial, systemic,
period, reader, carriers and rulings exit 0. Of 37 tools suites, 36 exit 0;
test_m11c1_runtime_rehearsal retains its existing exit 1 hash-related debt.
The reader has zero new unread fields. The spatial manifest adds 13 reviewed
dependencies and updates 26 ROOF references from floor to floor+v2_blockout;
their preservation obligations are unchanged. The live ledger test now expects
the roof to be PROGRAMMED, still blocking cutover, and machinery still ABSENT.

Godot ran serially through the approved lane, with double imports and windowed
routes/captures. Logs below each have an adjacent .receipt.json:

- tmp/v2-roof/roof-final.log: 41 waypoints, 0 failures. Both roof stairs and
  doors, continuous deck traversal, four edge-collider rays, a live player
  stopped by the west parapet, and return to F06. No script errors.
- tmp/v2-roof/domestic.log: bedroom, bathroom, kitchen and desk, 41.86 m;
  2,695 leaf-overlap observations and 143 opening-hold observations, no failures.
- tmp/v2-roof/blockout.log: 1,538 PASS lines; schema/collision suite PASS.
- tmp/v2-roof/upper.log: 666 checks, 0 failures.
- tmp/v2-resident-doors/routes/safety.log: 52 checks, 0 failures, including
  moving-leaf waits, transformed doors, player/resident occupancy, locks and
  preserving pre-opened leaves. V1 readiness also passed 134 checks.
- The same resident-doors/routes directory contains passing shop-out,
  shop-return, laundry, mail, off-map, player-doors and recurrence runs from
  before the roof addition. These are scoped regression observations, not
  fresh roof-composition proof.

Rendered roof arrival and next-morning views were inspected in
tmp/v2-roof/roof-final. Bathroom/kitchen captures were also inspected. Early
runs exposed a missing runtime brick binding and a door-hold observation radius
that omitted the actual stopping distance; both were corrected and rerun.
The canonical committed-candidate check writes tmp/v2-roof/verified.

## Remaining work and decisions

Changes outside the expected boundary: the shared DoorProp gains an angle
accessor used by its existing tween and clearance checks; its angle, timing,
locks and ordinary player interaction are unchanged. Material manifests are
generated derivatives of the added existing brick policy entry.

Open findings not fixed: the roof remains plain, with no tank/machinery or
rooftop maintenance activity. Night lighting is too dim. The owner's requested
voxel-light coverage and primary-light brightness remain a separate unfinished
priority after architecture. Other missing apartments, staff restroom,
whole-building architectural validation and accepted H23 seams remain open.
The preserved V1 resident service-door branch was not merged. This does not
claim general collision-safe routing for every resident or a completed V2.

Decision needed from owner: none for this bounded implementation.

MERGE-CANDIDATE 92447e5a4bfa6182f3354cb807af8b42464e2f48
