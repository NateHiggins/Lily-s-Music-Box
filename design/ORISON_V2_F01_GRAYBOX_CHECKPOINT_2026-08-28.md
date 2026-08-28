# Orison v2 F01 arrival gray-box checkpoint — 2026-08-28

Status: **AUTOMATED ROUTE PROOF COMPLETE; VISUAL ACCEPTANCE PENDING**

## Exact scope

This checkpoint advances only the parallel v2 path. It authors the F01 street and
rear aprons, arrival/service connections, daylight openings, fixed-use envelopes
and an opt-in controller review scene. Production launch and v1 remain unchanged.

Changed paths:

- `game/data/orison_v2_blockout.json`
- `game/scripts/building/orison_v2_blockout.gd`
- `game/scripts/building/orison_v2_review_controller.gd`
- `game/scenes/building/orison_v2_f01_review.tscn`
- `game/tests/orison_v2_blockout_test.gd`
- this checkpoint record

## Authored F01 route

Public: `F01_STREET_APRON` → `F01_DOOR_06` → `F01_VESTIBULE` →
`F01_INNER_DOOR` → `F01_LOBBY` → 3.20 m cased opening →
`F01_PUBLIC_CORE`.

Service: `F01_REAR_APRON` → `F01_REAR_SERVICE_DOOR` →
`F01_SERVICE_HALL` → `F01_SERVICE_CORE_DOOR` → `F01_SERVICE_CORE`.
The controlled cross-connection is `F01_PUBLIC_CORE` → 1.20 m cased opening →
`F01_CORE_TO_SERVICE` → 1.20 m cased opening → `F01_SERVICE_HALL`.
No private room participates in the service route.

Support access is explicit: watch-to-mail, mail-to-package, watch-to-public-core
and package-to-common-room each have a complete 0.91 m leaf, frame and open hinge.
The leaves remain held open for blockout inspection; interaction behavior is not
claimed.

## Fixed reservations and daylight

- A 1.50 m street-to-lobby route, 1.50 m lobby turn, 1.50 × 1.80 m core decision
  zone, 1.05 m package aisle and 1.20 m rear service route are visible semantic
  envelopes generated from the schema.
- Watch and mail/telephone work fronts, passenger-lift shaft/landing and two lobby
  radiator/service bays are reserved before props.
- Two 1.50 × 1.70 m lobby windows and two 1.50 × 1.70 m common-room windows are
  real wall openings with glazing/jamb geometry. Window sills are 0.75 m and heads
  are 2.45 m.
- Cased openings and windows are cut by the same wall-derivation path as doors;
  they are not decorative quads placed over solid collision.

## Controller review entrypoint

Run `res://scenes/building/orison_v2_f01_review.tscn` explicitly. It instantiates
the development blockout and a 0.33 m-radius, 1.524 m-tall collision-bearing player
at the street apron. The camera is at the established 1.41 m eye height. Movement
uses the production keyboard and left-stick actions; mouse and right-stick look
are supported. The controller owns no interaction, gameplay, case or save state.

## Validation

- JSON/schema census: PASS — 34 spaces, ten leaves, three cased openings, four
  windows, ten use/clearance envelopes and sixteen named anchors.
- Semantic graph: PASS — street reaches the public core; rear service reaches the
  public core and service core; service-to-core path crosses no private room.
- Door construction: PASS — every required F01/F02/F04 route leaf resolves with
  a complete hinge rotated into its blockout-open state.
- Physical clearance: PASS — a 0.66 m body capsule is collision-clear at nine
  samples spanning street apron, vestibule, lobby, lobby/core opening,
  core/service openings, service hall and rear apron.
- Review scene headless startup: PASS, exit 0.
- Focused `OrisonV2BlockoutTest`: PASS.
- Production layout remained byte-stable during the focused test.
- `git diff --check`: PASS for the checkpoint paths.

## Decisions and remaining proof

Technical decision: F01 gets a controlled public/service transfer because the
player's maintenance route requires access to both networks, but deliveries and
ordinary residents do not share the lobby's central line. This remains reversible
inside the accepted H-plan.

Still unproved:

- Shared partitions are still duplicated by adjacent space shells. Their openings
  align, but consolidation and a wall-junction census remain required.
- Passenger lift, U-stair landings/rails/headroom, internal service-lift apparatus,
  lighting, signage and dynamic door behavior remain reservations or primitives.
- The physical test samples stations rather than integrating navigation/path
  following; a human controller walk is still required.
- No player-height images, top-down dimensioned plan, swing capture, performance
  census or human readability verdict is claimed yet.
- No functional furniture or decoration has been added.

## Rollback

Revert this checkpoint's v2-only schema/builder/review/test changes. Production
continues to load the original title scene and `orison_root.tscn`; no save or v1
asset requires migration or repair.

## Next bounded checkpoint

Replace primitive straight stairs with dimensioned U-stairs and landings through
F01/F02/F03/F04; consolidate shared core walls; author passenger/service lift
landing openings; then prove headroom, guards, landing clearances, vertical route
continuity and intermediate-floor behavior before 2A furnishing envelopes.

Commit SHA: recorded by the publishing commit and final handoff.
