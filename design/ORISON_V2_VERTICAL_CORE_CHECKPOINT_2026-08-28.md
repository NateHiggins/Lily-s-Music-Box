# Orison v2 vertical-core checkpoint — 2026-08-28

Status: **AUTOMATED GEOMETRY PROOF COMPLETE; WALK AND VISUAL ACCEPTANCE PENDING**

## Exact scope

This checkpoint advances only the parallel, development-only v2 path. It replaces
the provisional vertical proof runs with explicit public and service core geometry
from F01 through F04, including the intermediate F03 transfer level. Production
launch, the v1 layout and existing exported building assets remain unchanged.

Changed paths:

- `game/data/orison_v2_blockout.json`
- `game/scripts/building/orison_v2_blockout.gd`
- `game/tests/orison_v2_blockout_test.gd`
- this checkpoint record

## Authored vertical core

- Four transfer levels are explicit at F01 0.00 m, F02 3.20 m, F03 6.40 m and
  F04 9.60 m.
- Six storey-by-storey U-stairs connect both networks across F01–F02, F02–F03
  and F03–F04. Each has two ten-riser flights, uniform 0.16 m rises, an explicit
  half landing and primitive outside/landing guards at 0.91 m.
- Public flights use 1.20 m clear width and 0.285 m treads. Service flights use
  1.05 m clear width and 0.275 m treads.
- Twenty explicit level platforms keep the stair wells open while providing the
  required public and service landing slabs at all four levels.
- Passenger and service lift shafts are continuous, non-solid reservations from
  below F01 through above F04. Eight level-specific landing records generate
  jamb/head markers and visible approach-clearance reservations.
- Core rooms suppress their former full-span floor and ceiling slabs so those
  shells no longer seal the stairs. The narrow F01 public/service connector emits
  only its required north and south walls to reduce duplicated shared mass.

## Validation

- JSON parse/schema census: PASS — four levels, 36 spaces, 20 platforms, eight
  lift landings, six U-stairs and sixteen named anchors.
- Stair dimensional assertions: PASS — twenty uniform 160 mm risers per storey,
  tread at least 275 mm, clear width at least 1.05 m and guards at least 0.91 m.
- Conservative crossover calculation: PASS — at least 2.20 m schematic headroom
  for all six stairs.
- Generated-node assertions: PASS — every half landing, landing guard, passenger
  and service shaft, and lift-landing clearance resolves.
- Existing semantic route, required identity, door-hinge and nine-station F01
  collision checks: PASS.
- Focused `OrisonV2BlockoutTest`: PASS.
- F01 controller review scene headless startup: PASS, exit 0.
- Production layout remained byte-stable during the focused test.
- `git diff --check`: PASS for the checkpoint paths.

## Decisions and remaining proof

F03 is represented now as a bounded transfer level rather than skipped by a
double-height proof stair. This keeps every storey transition inspectable and
allows later F03 program to attach without changing the vertical topology.

Still unproved:

- No player-driven bottom-to-top stair walk or integrated navigation/path proof
  has been performed. Existing capsule tests remain stationary F01 route samples.
- The lifts are reserved shafts and landing openings only; there are no cars,
  doors, controls, motion, interlocks or gameplay behavior.
- Guards are stepped primitive panels, not final rails or balustrades.
- Shared and exterior core walls still require full consolidation and a wall-
  junction/opening census.
- The headroom check is a conservative schema calculation, not a swept-volume or
  code-review certification. No building-code compliance claim is made.
- No player-height captures, dimensioned review images, performance census or
  human readability/comfort verdict is claimed.

## Rollback

Revert this checkpoint's v2-only schema, builder, test and record. Production
continues to load the original title scene and `orison_root.tscn`; no save data or
v1 asset requires migration or repair.

## Next bounded checkpoint

Consolidate shared core walls and obtain a player-height vertical walk/capture
review, then author the F02/2A internal shell and fixed-use envelopes against the
accepted core without furnishing or production cutover.

Commit SHA: recorded by the publishing commit and final handoff.
