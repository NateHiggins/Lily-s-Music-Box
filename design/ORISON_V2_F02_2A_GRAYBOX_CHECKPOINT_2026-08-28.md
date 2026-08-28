# Orison v2 F02/2A gray-box checkpoint — 2026-08-28

Status: **AUTOMATED ROUTE AND CLEARANCE PROOF COMPLETE; CASE/ACOUSTIC AND VISUAL ACCEPTANCE PENDING**

## Exact scope

This checkpoint advances only the parallel v2 path. It completes the primitive
F02 landing-to-2A shell, openings, privacy route, daylight, fixed-use envelopes
and an opt-in F02 controller review entrypoint. It does not add furniture, attach
case logic or change production launch.

Changed paths:

- `game/data/orison_v2_blockout.json`
- `game/scenes/building/orison_v2_f02_review.tscn`
- `game/tests/orison_v2_blockout_test.gd`
- this checkpoint record

## Authored route and room purpose

The public sequence is `F02_LANDING` → 1.20 m cased opening →
`F02_WEST_HALL` → `F02_DOOR_02` → `F02_A_VESTIBULE` → 1.20 m
cased opening → `F02_A_MAIN`. The private distributor then reaches the kitchen,
bath and bedroom without making either wet or sleeping space a through-route.

Three new 0.81 m privacy leaves serve the private hall, bath and bedroom. The
kitchen uses a 0.81 m cased opening. Nine total v2 daylight openings now include
two west main-room windows, one west kitchen window, and west/north bedroom
windows on F02. Route doors remain held open for blockout review; interaction is
not claimed.

Fourteen new F02 reservations establish the landing decision area, 1.20 m public
hall, entry distribution, 14 m² unclaimed main-room floor, caption/file work,
conversation clearance, living/dining use, kitchen work run and 1.05 m aisle,
private distributor, bath fixtures, 0.90 m bedroom route, bed and wardrobe use.
They are envelopes, not authored furniture.

`F02_A_MONITOR_01` is now a schema-derived compatibility anchor alongside the
existing Vantry point and stance. Five additional review positions encode the
stair exit, corridor approach, inside threshold, bath threshold and bedroom
threshold.

## Geometry corrections from blockout proof

The dimension schedule contained two rectangular conflicts that could not be
accepted literally:

1. The proposed main-room north court window occupied the same boundary as the
   bath. It is deliberately absent rather than rendered through an interior wet
   wall. A later court/polygon decision may restore it with valid exterior
   adjacency.
2. The stated bedroom rectangle overlapped the 1.30 m private hall. The gray-box
   bedroom ends at X -10.25 and receives a west-facing hall door, producing a
   legible distributor and a non-overlapping bedroom shell.

F02 shared partitions use explicit wall-side ownership so the vestibule/main,
kitchen/main, hall/main, bath/hall and bedroom/hall relationships do not each
emit two identical wall shells. The continuous west wet chase moves to the bath's
east service wall after collision proof found its former rectangle intruding into
the private hall.

## Review entrypoint

Run `res://scenes/building/orison_v2_f02_review.tscn` explicitly. It instantiates
the development blockout and the existing collision-bearing review controller at
the F02 landing decision point. The camera remains at the established 1.41 m eye
height and uses production movement/look actions. It owns no case, save or
interaction state.

## Validation

- JSON/schema census: PASS — 36 spaces, thirteen leaves, six cased openings,
  nine windows, 24 envelopes and 22 anchors.
- Semantic graph: PASS — F02 landing reaches the 2A main room, bath and bedroom;
  the bath and bedroom are reached through the private distributor.
- Construction: PASS — all three new privacy leaves resolve with complete open
  hinges; all F02 windows, required envelopes and Mina compatibility ids resolve.
- Physical clearance: PASS — a 0.66 m body capsule is collision-clear at eight
  F02 stations spanning landing, hall, vestibule, main/work zone, private hall,
  bath and bedroom threshold.
- Focused `OrisonV2BlockoutTest`: PASS.
- F02 controller review scene headless startup: PASS, exit 0.
- Production layout remained byte-stable during the focused test.
- `git diff --check`: PASS for checkpoint paths.

## Remaining proof

- No production Mina NPC, chirp source, case interaction, job authority or
  acoustic propagation is attached to v2. Only compatible named anchors exist.
- Capsule stations prove local occupancy, not a simulated continuous controller
  walk or navigation path.
- No closed-door sweep, furniture collision or radiator conflict is proved yet.
- The omitted north court window requires a later court/polygon owner decision;
  it must not be restored onto an interior bath boundary.
- Shared-wall ownership is improved for 2A but is not yet a building-wide wall-
  junction census.
- No player-height images, top-down dimensioned capture, performance census or
  human route-readability verdict is claimed.

## Rollback

Revert this checkpoint's v2-only schema, review scene, test and record. Production
continues to load the original title scene and `orison_root.tscn`; no current save
or case owner requires migration or repair.

## Next bounded checkpoint

Build the F04/4B gray-box with complete internal circulation, fixed-use envelopes,
terminal and bedside-return compatibility anchors, then prove its local controller
route before the integrated street-to-F02-to-F04 slice.

Commit SHA: recorded by the publishing commit and final handoff.
