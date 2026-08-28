# Orison v2 F04/4B gray-box checkpoint — 2026-08-28

Status: **SOURCE COMPLETE; SERIALIZED GODOT AND VISUAL PROOF BLOCKED BY OCCUPIED LANE**

Milestone: `ORISON-V2-M07`

## Exact scope

This checkpoint advances only the parallel v2 gray-box. It authors the complete
F04 landing-to-4B route, apartment shell, fixed-use/clearance reservations,
compatibility anchors, controller review entrypoint, continuous-walk test and
seven-view evidence harness. Production v1, default launch, case/save ownership
and the legacy anonymous-bed fallback remain unchanged.

Changed paths:

- `game/data/orison_v2_blockout.json`
- `game/scripts/building/orison_v2_blockout.gd`
- `game/scenes/building/orison_v2_f04_review.tscn`
- `game/tests/orison_v2_blockout_test.gd`
- `game/tests/orison_v2_f04_shot.gd`
- `game/tests/OrisonV2F04Shot.tscn`
- this checkpoint record

## Resulting room schedule and route

Public route: `F04_LANDING` → 1.20 m cased opening → `F04_WEST_HALL` →
`F04_DOOR_03` → `F04_B_VESTIBULE` → 1.20 m cased opening →
`F04_B_MAIN`.

Private route: main → 0.81 m privacy leaf → `F04_B_PRIVATE_HALL` →
1.20 m turn → `F04_B_ALCOVE_APPROACH`. The lower distributor serves the bath;
the upper distributor serves the 0.76 m closet leaf and the 2.40 m sleeping-
alcove opening. Neither sleeping nor closet circulation crosses the bathroom.

The scheduled clear boundaries are retained for vestibule, main, kitchen, bath,
closet and sleeping alcove. The main room reserves exactly 12 m² of unclaimed
floor beside, not beneath, the work zone. The vestibule reserves a 1.50 m turn;
the galley reserves a 1.05 m aisle; the terminal and bedside return each reserve
0.90 × 1.20 m. Bath fixtures, closet storage, bed use, radiator and telephone/
message conduit remain gray-box envelopes rather than furniture or systems.

Six F04 windows are restricted to declared exterior sides: two main-room west,
one kitchen west, one bath east, and sleeping-alcove west/north openings.

## Intentional deviations and construction corrections

1. The schedule named no connector between the main room and the separated bath,
   closet and alcove. Without one, the flat required circulation through the bath
   or unexplained open gaps. The smallest correction is an L-shaped private
   distributor represented by two non-overlapping rectangular semantic records
   in the unused band. No scheduled room is enlarged.
2. `F04_DOOR_03` remains 0.91 m and left-hand entering. Its swing reservation is
   placed against the vestibule north wall, leaving the 1.50 m southern turn clear.
3. The bath leaf swings into the private hall, outside the fixture envelope. The
   closet leaf swings into the approach, outside the 0.65 m storage depth.
4. Shared partitions use explicit single-side ownership. The focused source test
   derives every adjacent F04 room pair and requires exactly one wall owner.
5. The continuous wet chase remains on the bath east service wall established by
   the preceding F02 collision correction; it does not enter the F04 distributor.

## Migration and interaction contracts

- `F04_B_MONITOR_01`: exact generated position `(-9.05, 10.35, 1.25)`, preserving
  the planned local X/Z point `(-9.05, 1.25)`.
- `F04_B_MONITOR_STANCE`: exact floor position `(-9.90, 9.60, 1.25)` with a
  0.90 × 1.20 m clearance reservation.
- `F04_B_BED`: exact generated anchor `(-13.10, 10.15, 8.90)`.
- `F04_B_BEDSIDE_RETURN`: exact floor position `(-11.95, 9.60, 8.90)`, facing
  west, with a 0.90 × 1.20 m clearance reservation.
- `F04_B_MESSAGE_POINT` and its service-wall reservation establish physical
  telephone/message provision without taking runtime ownership.

These records are compatible named targets only. `CallInterface`,
`VirusSoundDirector`, the case library, acoustic consumers, `CoreLoopDirector`,
wake placement and save restoration are not redirected in this milestone. The
legacy anonymous-bed fallback is deliberately retained.

## Authored proof

The focused test now checks deterministic census; F04 non-overlap; derived shared-
wall ownership; every window against its owner's declared exterior side; door
boundary, hinge, latch, handedness and swing records; clearance sizes and swing/
fixed-use separation; semantic routes; exact monitor/bed/return transforms; eleven
schema-declared 0.66 m capsule stations; the F01/F02 regression surface; production
layout hashing; F04 review startup; and a collision-bearing continuous local
controller traversal from landing to bedside return.

`OrisonV2F04Shot.tscn` is a seven-frame windowed evidence harness for one top-down
plan plus landing, corridor, vestibule/main, terminal, kitchen and bedside views.
It refuses missing/non-absolute `SHOT_DIR` values and refuses overwrites through
the shared shot harness.

## Validation receipts

Completed source-level checks:

- current `HEAD` and `origin/main` began at
  `dfd8f3ac8418cf0de59d591a97a2fd8d1bbbeb62`;
- JSON parse and census: PASS — 38 spaces, 16 doors, 11 cased openings,
  15 windows, 45 envelopes, 31 anchors and 11 capsule stations;
- duplicate-id census across all schema tables: PASS — zero duplicates;
- F04 positive-area room-overlap census: PASS — zero overlaps;
- derived shared-partition census: PASS — 12 adjacencies, zero ownership errors;
- exterior-window census: PASS — 15 checked, zero invalid wall assignments;
- F04 semantic route graph: PASS — bath, closet and alcove are reachable;
- exact clearance areas: PASS — 2.25 m² vestibule turn, 12.00 m² unclaimed
  main floor, and 1.08 m² each for terminal and bedside stances;
- required monitor, monitor stance, bed and bedside-return ids: PASS;
- `git diff --check`: PASS for milestone source paths.

Blocked serialized checks:

- Focused `OrisonV2BlockoutTest`: NOT RUN on this source revision.
- F04 controller review headless startup: NOT RUN.
- Continuous controller traversal: AUTHORED, NOT RUN.
- Production-layout before/after byte-stability assertion: AUTHORED, NOT RUN.
- Seven-view capture and receipt: AUTHORED, NOT RUN; no images are claimed.

The lane was occupied throughout validation by an existing responsive, CPU-active
headless `OrisonV2BlockoutTest` process pair started at 05:34:57. Per coordination
rules it was not terminated or disturbed. No Blender process was started.

## Remaining risks and integrated-slice readiness

- The milestone is **not yet accepted for integrated-slice work**. Its Godot parse,
  generated collision, continuous walk, review startup and visual evidence must
  run cleanly after the serialized lane becomes available.
- Door-swing envelopes are schema proofs; closed-leaf dynamic interaction remains
  outside this gray-box.
- Fixed-use records prove space allocation, not furniture fit after actual props.
- Runtime call/audio/wake/save consumers still target production owners. This is
  intentional until integrated migration proof.
- No acoustic propagation, performance census, human route-readability verdict or
  production cutover is claimed.

## Rollback

Revert only the seven paths listed above. Production continues to load the current
title scene and `orison_root.tscn`; no save, case, audio or wake owner needs repair.

## Recommended next milestone

First close the blocked M07 serialized validation and capture packet without source
expansion. If every authored check passes, begin the separately bounded M08
integrated street → F01 → F02/2A → F04/4B route proof. Do not combine that work
with this checkpoint.

Commit SHA: recorded by the publishing commit and final handoff.
