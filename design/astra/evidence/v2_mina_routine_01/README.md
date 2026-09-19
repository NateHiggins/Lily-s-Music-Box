# V2 Mina routine, physical encounter and service access

Mina now consumes the existing campaign timetable in the composed V2 world. Nine authored destination tokens resolve to a connected route graph. Live transitions walk supported collision geometry, open the bodega and laundry doors, and stop on obstructions. Initial placement reconstructs from campaign time; exact mid-route position is not persisted. Off-map Saturday walking is abstracted beyond the actual street threshold, with disappearance and reappearance deferred while observed.

The canonical Mina mesh and personal walk remain unchanged. Pose review exposed deformation in borrowed idle animations. A restrained idle now uses Mina's own skeleton rest frame, lowered arms and subtle breathing. `poses_02/mina_calm_idle.png` and the physical complaint capture show an intact body. This is not final animation or human acceptance; scheduled sleeping, washing, cooking, folding, shopping transactions and costume changes remain unembodied.

## Runtime evidence

All runs use the unchanged exclusive native runner, with its 180-second maximum. Successful focused runs have empty stderr:

| Run | Result |
| --- | --- |
| outbound_06 | 76.34 m, apartment to bodega |
| return | 76.38 m, bodega to apartment |
| domestic_02 | Bedroom, bathroom, kitchen and unit, 41.54 m |
| mail_04 | Mail and return, 99.52 m |
| laundry | Basement laundry and return, 129.20 m |
| off_map | Observed threshold controls and return, 94.91 m |
| laundry_input_02 | 17 player waypoints; physical door, both light states, washer lid and airer |
| mail_input_02 | 16 player waypoints; actual tour-key take/return and mailbox access |

The new basement laundry uses existing washer and airer mechanisms at explicit semantic anchors, a shared room-light circuit and a physical service door. It is not a finished basement or complete laundry simulation. Mail access required shortening a wiring column that blocked the doorway, relocating the guard and its stance together, and orienting its interaction face toward that stance. The player capsule passes the resulting opening. Mailbox tenant interactions are not claimed by this route.

## Failed controls and reassessment

Earlier outbound runs stopped at ramp end caps and the kerb. The supported-step rule now admits a 25 cm step with capsule clearance and checks both floor support and overhead/body obstruction; stairs were not changed. Earlier mail attempts stopped at the desk and obstructing wiring column. The initial domestic fixture incorrectly expected the ordinary weekday desk block during the authored Sunday override; the corrected fixture respects that override. The first laundry input aimed through a competing wringer control; the final approach reaches the lid from the side without changing shared hit regions. The first mail player test exposed the guard's reversed face and incorrect target point.

`encounter.log` is **not accepted**, despite its printed zero-failure count: stderr contains a missing case-stage error. The production case owner now safely activates an absent case, and the route explicitly requires visible protected complaint dialogue. This prevents the earlier false green in which later inspection could activate the case without the resident interaction succeeding.

Historical focused runs correspond to their then-current source, not identical final bytes. Final composed regressions and source hashes are recorded separately below. Failures and images are retained.

`encounter_02.log` passes the strengthened 73-waypoint physical complaint/inspection/hardware/repair route with empty stderr. `service_runtime.log` passes all 29 direct-owner M08F checks, also with empty stderr; this does not establish its separate resource-retention contract.

`composition.log` fails nine assertions after one missed kitchen-switch input in its first reconstruction; the second reconstruction succeeds. Its camera hit differs from the prescribed aim. The controlled-standing fixture now disables desktop mouse-look callbacks while retaining production polled interaction, and holds each press across two rendered frame boundaries. `composition_02.log` passes all 521 checks across both reconstructions with empty stderr. No production switch behavior was changed for this correction.

## Presentation and remaining scope

The mailbox capture is too dark, and 2A remains sparsely furnished. The corrected actor pose and successful mechanics do not constitute visual completion. Full manifestation/fridge binding, recurrence, wake/return, remaining apartments and cast, derived acoustic topology, save reconstruction of actor travel, resource retention, performance, export and human/default gates remain open. V1 remains the default.

`save_matrix.log` passes all 38 checks and all four V1/V2 disk-save directions, preserving calendar, inventory and case selections. Stderr contains the deliberate invalid-selector warning and existing V1 found-art warning; no new errors. Actor mid-route persistence is not part of this matrix.
