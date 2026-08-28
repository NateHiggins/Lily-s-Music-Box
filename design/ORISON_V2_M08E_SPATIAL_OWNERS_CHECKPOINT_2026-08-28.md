# ORISON-V2-M08E spatial-owners checkpoint — 2026-08-28

Status: **TECHNICAL PROOF PASS; HUMAN ACCEPTANCE PENDING**

Scope: physical owners only. M09, selector cutover, `FirstShiftDirector`, and `ServiceRoundDirector` composition remain unauthorized.

## Construction result

The v2 schema now owns a coherent F01 caretaker station, a complete apartment 2B, and the minimum B1 arrival/approach/boiler room. The six required identities resolve exactly once: `F01_WATCHMAN_DETECTOR`, `F01_NIGHT_REGISTER`, `F01_SIGNAL_REGISTER`, `F01_TOUR_KEY_GUARD`, `F02_B_RADIATOR_01`, and `B1_BOILER_01`.

The dimensioned construction basis is [ORISON_V2_M08E_DIMENSIONED_SCHEDULE_2026-08-28.md](ORISON_V2_M08E_DIMENSIONED_SCHEDULE_2026-08-28.md). F01 remains a single 4.20 × 4.40 m workplace with four distinct controls, 0.90 m interaction reaches, a lobby-facing cased opening, and an independent east route to the primary core. 2B provides vestibule, 18.68 m² living/work room, 13.20 m² kitchen, 13.20 m² sleeping room, complete bath, distributor/storage, conversation stance, and exterior-wall radiator service stance. B1 provides the accepted primary stair extension, a 1.20 m approach, 1.05 m self-closing threshold, and a 6.15 × 11.00 m boiler room with tended, water-column, ash/draft, pipe/flue, and retreat reservations.

## Route topology and contracts

The semantic graph records B1↔F01, ritual-station→core, F02-core→2B, threshold→radiator, radiator→porter, and porter→boiler edges. Heat, wet/feed, flue, electrical-service, and kitchen-exhaust connections are explicit. Coordinates remain schema-owned; no gameplay consumer or save authority was added.

The dedicated collision proof traverses boiler control → B1 landing → F01 ritual sequence → F02/2B conversation and radiator → F01 porter → B1 boiler → F02 radiator. It uses the 0.66 m collision-bearing review capsule and physical U-stairs in both directions. Open review leaves are non-colliding while held open; closed leaves retain collision.

## Intentional deviations and defects found during traversal

- The accepted south blockout envelope extends 0.50 m (−12.00 to −12.50) to retain a functional 2B kitchen, bathroom, sleeping room, and distributor instead of compressing them below program minima.
- The F02 east approach is split into a 2.90 × 1.20 m public hall plus a controlled 1.20 × 1.20 m service-spine crossing, preventing positive-area overlap with the north/south service hall.
- The B1 fire door is 1.05 m clear, matching the service-route width and giving the 0.66 m capsule reliable clearance.
- Initial traversal found service risers occupying the boiler approach. The heat, telephone, and electrical risers were moved together into the north service niche; their semantic connections are unchanged.
- Initial traversal also found the service approach opening directly onto the stair void. `B1_PUBLIC_LANDING_E` is the minimum 1.00 × 2.20 m landing bridge to the established south landing.

## Deterministic census and automated validation

| Schema collection | M08D | M08E | Delta |
|---|---:|---:|---:|
| levels | 4 | 5 | +1 |
| spaces | 38 | 50 | +12 |
| doors | 16 | 21 | +5 |
| cased openings | 11 | 19 | +8 |
| exterior windows | 15 | 19 | +4 |
| fixed-use/clearance envelopes | 45 | 70 | +25 |
| fixed fixture masses | 0 | 15 | +15 |
| semantic anchors | 31 | 48 | +17 |
| landing platforms | 20 | 24 | +4 |
| stairs | 6 | 7 | +1 |
| risers | 5 | 7 | +2 |
| route edges | 0 | 6 | +6 |
| service connections | 0 | 6 | +6 |

Validation results:

- `OrisonV2BlockoutTest`: PASS, including deterministic census, uniqueness, overlap/shared-wall, exterior-window, door metadata, fixed-use clearance, route graph, service continuity, existing F01/F02/F04 routes, scene startup, and production-layout SHA-256 stability.
- `OrisonV2M08ESpatialTest`: PASS; complete collision-bearing service-round loop and six exact owners.
- `OrisonV2IntegratedTest` (M08A): PASS; public F01/F02/F04 behavior, save/reconstruct, continuous street-to-bedside route, adapter restoration, 2,186 nodes and 523 collision objects. Startup 17.400 ms; warm sampled process/physics maxima 0.405/1.360 ms; GPU unavailable headlessly.
- Production layout hash remained `9e6b4fa95a88e7ea23fe8bfac188fd094fd1cace628237010a683db7c0c4356e`.
- All focused runs exited without ObjectDB/resource-retention warnings.
- `BuildingRootSelector.DEFAULT_ID` remains `v1`.

## Evidence

Accepted-for-review packet: `art/renders/orison_v2/m08e_spatial_owners_checkpoint_02/`.

Its capture receipt reports PASS, 13/13 PNGs, 1600 × 900 each, in 1.681 seconds. Frames 1–12 use 1.41 m player-eye viewpoints; frame 13 is explicitly top-down with the only semantic route overlay. Clearance/debug envelopes are hidden. The checklist in that directory keeps the verdict pending.

## Dependency audit

The exact assignment baseline was preserved before editing: 3,512 records, 34 documented low-confidence unresolved records, and zero failing drift categories.

The reviewed M08E-only manifest update was generated against commit `0bf89d4`: 3,553 records (data 1,734; production 572; scene 5; test 1,242), 19 intentional new classified records, and 138 reviewed authority/domain promotions. Those promotions are expected: existing B1, 2B, ritual, radiator, and boiler references now resolve to real v2 layout targets. After the update: zero new unclassified production dependencies, authority changes, vanished targets, unresolved save contracts, or stale preserved records; 48/48 audit tests pass.

The live branch also contains nine unrelated F03 shot-test records introduced by a concurrent commit. They remain report-only and were deliberately not blessed into this checkpoint's manifest. The live audit is still clean in every failing category.

## Remaining work and verdict

The missing spatial dependency is technically closed. Runtime parity is not: the next authorized checkpoint must compose the existing first-shift/service-round consumers onto these identities and prove their public behavior without creating duplicate authorities. Anonymous v1 `bed` compatibility remains untouched.

Human question: **Does the packet make the F01 ritual station, complete 2B home/radiator service stance, and B1 boiler route readable, credible, safely approachable, and memorable as one service round?**

Until the owner answers, the status remains **HUMAN ACCEPTANCE PENDING**. M09 and production cutover remain unauthorized.
