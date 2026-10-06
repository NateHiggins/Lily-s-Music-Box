# Orison v2 completeness ledger

Evidence class: **INERT**

| Metric | Value |
| --- | --- |
| requirements | 240 |
| by_status | ABSENT=21, HUMAN_ACCEPTED=1, PROGRAMMED=119, RUNTIME_PROVEN=27, SHELL_ONLY=3, SPATIALLY_PROVEN=69 |
| blockers_by_scope | FIRST_SLICE_TECHNICAL=7, GOLDEN_SHIFT_V2=8, FULL_BUILDING_STRUCTURAL=127, FULL_BUILDING_RUNTIME=42, PRODUCTION_CUTOVER=151, V1_RETIREMENT=153 |
| v1_fallbacks | 2 |
| heuristic_conclusions | 117 |
| anchor_only_findings | 0 |
| stale_checkpoint_ids | 1 |

## Blockers by readiness scope

- **FIRST_SLICE_TECHNICAL**: 7
  - ritual.F01_WATCHMAN_DETECTOR
  - ritual.F01_NIGHT_REGISTER
  - ritual.F01_SIGNAL_REGISTER
  - ritual.F01_TOUR_KEY_GUARD
  - contract.B1_BOILER_01
  - contract.F02_B_RADIATOR_01
  - job.lena_radiator_round_2b
- **GOLDEN_SHIFT_V2**: 8
  - ritual.F01_WATCHMAN_DETECTOR
  - ritual.F01_NIGHT_REGISTER
  - ritual.F01_SIGNAL_REGISTER
  - ritual.F01_TOUR_KEY_GUARD
  - contract.B1_BOILER_01
  - contract.F02_B_RADIATOR_01
  - job.lena_radiator_round_2b
  - golden.eleven_beats
- **FULL_BUILDING_STRUCTURAL**: 127
  - region.street
  - region.construction_seam
  - region.arcade_portal
  - region.arcade_throat
  - region.arcade_hall
  - region.shops
  - f01.mail_telephone
  - f01.parcel_package
  - f01.common_room
  - circ.F02.public_landing
  - circ.F02.public_core
  - circ.F02.service_core
  - circ.F02.service_route
  - circ.F03.public_landing
  - circ.F03.public_core
  - circ.F03.service_core
  - circ.F03.service_route
  - circ.F04.public_landing
  - circ.F04.public_core
  - circ.F04.service_core
  - circ.F04.service_route
  - circ.F05.public_landing
  - circ.F05.public_core
  - circ.F05.service_core
  - circ.F05.service_route
  - circ.F06.public_landing
  - circ.F06.public_core
  - circ.F06.service_core
  - circ.F06.service_route
  - circ.F01.public_landing
  - floor.F01
  - floor.F02
  - floor.F03
  - floor.F04
  - floor.F05
  - floor.F06
  - floor.ROOF
  - unit.2A
  - unit.2A.cooking
  - unit.2A.sanitary
  - ... 87 more
- **FULL_BUILDING_RUNTIME**: 42
  - f01.street_vestibule
  - f01.lobby
  - f01.watch_station
  - f01.mail_telephone
  - f01.parcel_package
  - f01.common_room
  - f01.staff_restroom
  - ritual.F01_WATCHMAN_DETECTOR
  - ritual.F01_NIGHT_REGISTER
  - ritual.F01_SIGNAL_REGISTER
  - ritual.F01_TOUR_KEY_GUARD
  - unit.2A
  - unit.3A
  - unit.3B
  - unit.4A
  - unit.4B
  - unit.5A
  - unit.5B
  - unit.5C
  - unit.6A
  - unit.6B
  - unit.6C
  - service.wet_stack
  - service.heat_stack
  - service.telephone_riser
  - service.passenger_lift
  - service.service_lift
  - service.electrical_riser
  - service.fire_service
  - contract.B1_BOILER_01
  - contract.F01_LOBBY
  - contract.F02_A_MAIN
  - contract.F02_B_RADIATOR_01
  - contract.F04_B_ALCOVE
  - contract.F04_B_BATH
  - contract.F04_B_CLOSET
  - contract.F04_B_KITCHEN
  - contract.F04_B_MAIN
  - contract.F04_B_VESTIBULE
  - job.lena_radiator_round_2b
  - ... 2 more
- **PRODUCTION_CUTOVER**: 151
  - region.street
  - region.construction_seam
  - region.arcade_portal
  - region.arcade_throat
  - region.arcade_hall
  - region.shops
  - f01.street_vestibule
  - f01.lobby
  - f01.watch_station
  - f01.mail_telephone
  - f01.parcel_package
  - f01.common_room
  - f01.staff_restroom
  - ritual.F01_WATCHMAN_DETECTOR
  - ritual.F01_NIGHT_REGISTER
  - ritual.F01_SIGNAL_REGISTER
  - ritual.F01_TOUR_KEY_GUARD
  - circ.F02.public_landing
  - circ.F02.public_core
  - circ.F02.service_core
  - circ.F02.service_route
  - circ.F03.public_landing
  - circ.F03.public_core
  - circ.F03.service_core
  - circ.F03.service_route
  - circ.F04.public_landing
  - circ.F04.public_core
  - circ.F04.service_core
  - circ.F04.service_route
  - circ.F05.public_landing
  - circ.F05.public_core
  - circ.F05.service_core
  - circ.F05.service_route
  - circ.F06.public_landing
  - circ.F06.public_core
  - circ.F06.service_core
  - circ.F06.service_route
  - circ.F01.public_landing
  - floor.F01
  - floor.F02
  - ... 111 more
- **V1_RETIREMENT**: 153
  - region.street
  - region.construction_seam
  - region.arcade_portal
  - region.arcade_throat
  - region.arcade_hall
  - region.shops
  - f01.street_vestibule
  - f01.lobby
  - f01.watch_station
  - f01.mail_telephone
  - f01.parcel_package
  - f01.common_room
  - f01.staff_restroom
  - ritual.F01_WATCHMAN_DETECTOR
  - ritual.F01_NIGHT_REGISTER
  - ritual.F01_SIGNAL_REGISTER
  - ritual.F01_TOUR_KEY_GUARD
  - circ.F02.public_landing
  - circ.F02.public_core
  - circ.F02.service_core
  - circ.F02.service_route
  - circ.F03.public_landing
  - circ.F03.public_core
  - circ.F03.service_core
  - circ.F03.service_route
  - circ.F04.public_landing
  - circ.F04.public_core
  - circ.F04.service_core
  - circ.F04.service_route
  - circ.F05.public_landing
  - circ.F05.public_core
  - circ.F05.service_core
  - circ.F05.service_route
  - circ.F06.public_landing
  - circ.F06.public_core
  - circ.F06.service_core
  - circ.F06.service_route
  - circ.F01.public_landing
  - floor.F01
  - floor.F02
  - ... 113 more

## v1 fallbacks

- acoustic.v2_rederivation [PROGRAMMED] (absence)
- save.bedside_return [RUNTIME_PROVEN] (redundancy)

## Findings


**stale checkpoint identifiers (1):**

- ! B1_PUBLIC_LANDING_E - checkpointed identifier absent from current v2 layout (design/ORISON_V2_M08E_SPATIAL_OWNERS_CHECKPOINT_2026-08-28.md)

**runtime receipts rejected (15):**

- ! art/renders/orison_v2/building_surface_finish_20261005/runtime_authority_receipt.json - runtime-input SHA-256 is stale
- ! art/renders/orison_v2/cobbler_fittings_20261005/runtime_authority_receipt.json - runtime-input SHA-256 is stale
- ! art/renders/orison_v2/front_court_roof_20261005/runtime_authority_receipt.json - runtime-input SHA-256 is stale
- ! art/renders/orison_v2/front_facade_20261005/runtime_authority_receipt.json - runtime-input SHA-256 is stale
- ! art/renders/orison_v2/front_facade_air_20261005/runtime_authority_receipt.json - runtime-input SHA-256 is stale
- ! art/renders/orison_v2/hardware_apparatus_20261005/runtime_authority_receipt.json - runtime-input SHA-256 is stale
- ! art/renders/orison_v2/hardware_drawers_20261005/runtime_authority_receipt.json - runtime-input SHA-256 is stale
- ! art/renders/orison_v2/hardware_stock_20261005/runtime_authority_receipt.json - runtime-input SHA-256 is stale
- ! art/renders/orison_v2/hardware_tools_20261005/runtime_authority_receipt.json - runtime-input SHA-256 is stale
- ! art/renders/orison_v2/lamp_surface_balance_20261005/runtime_authority_receipt.json - runtime-input SHA-256 is stale
- ! art/renders/orison_v2/locksmith_fittings_20261005/runtime_authority_receipt.json - runtime-input SHA-256 is stale
- ! art/renders/orison_v2/m08f_runtime_composition_01/runtime_authority_receipt.json - schema-2 runtime_contract required; capture-only receipts do not execute runtime contracts
- ! art/renders/orison_v2/news_fittings_20261005/runtime_authority_receipt.json - runtime-input SHA-256 is stale
- ! art/renders/orison_v2/photo_cameras_20261005/runtime_authority_receipt.json - runtime-input SHA-256 is stale
- ! art/renders/orison_v2/photo_counter_20261005/runtime_authority_receipt.json - runtime-input SHA-256 is stale

## Requirements

| id | dimension | status | required | blocking scopes | fallback | heuristic |
| --- | --- | --- | --- | --- | --- | --- |
| site.street_threshold | 01 site and street | RUNTIME_PROVEN | RUNTIME_PROVEN | - |  |  |
| region.street | 01b exterior and region axis | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| region.construction_seam | 01b exterior and region axis | ABSENT | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| region.arcade_portal | 01b exterior and region axis | ABSENT | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| region.arcade_throat | 01b exterior and region axis | ABSENT | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| region.arcade_hall | 01b exterior and region axis | ABSENT | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| region.shops | 01b exterior and region axis | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| f01.street_vestibule | 02 public arrival and F01 program | SPATIALLY_PROVEN | RUNTIME_PROVEN | FULL_BUILDING_RUNTIME, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| f01.lobby | 02 public arrival and F01 program | SPATIALLY_PROVEN | RUNTIME_PROVEN | FULL_BUILDING_RUNTIME, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| f01.watch_station | 02 public arrival and F01 program | SPATIALLY_PROVEN | RUNTIME_PROVEN | FULL_BUILDING_RUNTIME, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| f01.mail_telephone | 02 public arrival and F01 program | PROGRAMMED | RUNTIME_PROVEN | FULL_BUILDING_STRUCTURAL, FULL_BUILDING_RUNTIME, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| f01.parcel_package | 02 public arrival and F01 program | PROGRAMMED | RUNTIME_PROVEN | FULL_BUILDING_STRUCTURAL, FULL_BUILDING_RUNTIME, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| f01.common_room | 02 public arrival and F01 program | PROGRAMMED | RUNTIME_PROVEN | FULL_BUILDING_STRUCTURAL, FULL_BUILDING_RUNTIME, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| f01.staff_restroom | 02 public arrival and F01 program | SPATIALLY_PROVEN | RUNTIME_PROVEN | FULL_BUILDING_RUNTIME, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| ritual.F01_WATCHMAN_DETECTOR | 10 F01 administrative/watch functions | SPATIALLY_PROVEN | RUNTIME_PROVEN | FIRST_SLICE_TECHNICAL, GOLDEN_SHIFT_V2, FULL_BUILDING_RUNTIME, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| ritual.F01_NIGHT_REGISTER | 10 F01 administrative/watch functions | SPATIALLY_PROVEN | RUNTIME_PROVEN | FIRST_SLICE_TECHNICAL, GOLDEN_SHIFT_V2, FULL_BUILDING_RUNTIME, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| ritual.F01_SIGNAL_REGISTER | 10 F01 administrative/watch functions | SPATIALLY_PROVEN | RUNTIME_PROVEN | FIRST_SLICE_TECHNICAL, GOLDEN_SHIFT_V2, FULL_BUILDING_RUNTIME, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| ritual.F01_TOUR_KEY_GUARD | 10 F01 administrative/watch functions | SPATIALLY_PROVEN | RUNTIME_PROVEN | FIRST_SLICE_TECHNICAL, GOLDEN_SHIFT_V2, FULL_BUILDING_RUNTIME, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| circ.F02.public_landing | 03/04 circulation | SHELL_ONLY | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| circ.F02.public_core | 03/04 circulation | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| circ.F02.service_core | 03/04 circulation | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| circ.F02.service_route | 03/04 circulation | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| circ.F03.public_landing | 03/04 circulation | SHELL_ONLY | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| circ.F03.public_core | 03/04 circulation | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| circ.F03.service_core | 03/04 circulation | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| circ.F03.service_route | 03/04 circulation | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| circ.F04.public_landing | 03/04 circulation | SHELL_ONLY | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| circ.F04.public_core | 03/04 circulation | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| circ.F04.service_core | 03/04 circulation | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| circ.F04.service_route | 03/04 circulation | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| circ.F05.public_landing | 03/04 circulation | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| circ.F05.public_core | 03/04 circulation | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| circ.F05.service_core | 03/04 circulation | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| circ.F05.service_route | 03/04 circulation | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| circ.F06.public_landing | 03/04 circulation | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| circ.F06.public_core | 03/04 circulation | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| circ.F06.service_core | 03/04 circulation | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| circ.F06.service_route | 03/04 circulation | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| circ.F01.public_landing | 03/04 circulation | ABSENT | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| circ.F01.public_core | 03/04 circulation | SPATIALLY_PROVEN | SPATIALLY_PROVEN | - |  |  |
| circ.F01.service_core | 03/04 circulation | SPATIALLY_PROVEN | SPATIALLY_PROVEN | - |  |  |
| circ.F01.service_route | 03/04 circulation | SPATIALLY_PROVEN | SPATIALLY_PROVEN | - |  |  |
| floor.B1 | 05 canonical floors | SPATIALLY_PROVEN | SPATIALLY_PROVEN | - |  |  |
| floor.F01 | 05 canonical floors | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| floor.F02 | 05 canonical floors | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| floor.F03 | 05 canonical floors | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| floor.F04 | 05 canonical floors | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| floor.F05 | 05 canonical floors | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| floor.F06 | 05 canonical floors | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| floor.ROOF | 05 canonical floors | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| unit.1A | 06 canonical units | SPATIALLY_PROVEN | SPATIALLY_PROVEN | - |  | yes |
| unit.1A.cooking | 07 domestic minimums | SPATIALLY_PROVEN | SPATIALLY_PROVEN | - |  | yes |
| unit.1A.entry | 07 domestic minimums | SPATIALLY_PROVEN | SPATIALLY_PROVEN | - |  | yes |
| unit.1A.living | 07 domestic minimums | SPATIALLY_PROVEN | SPATIALLY_PROVEN | - |  | yes |
| unit.1A.sanitary | 07 domestic minimums | SPATIALLY_PROVEN | SPATIALLY_PROVEN | - |  | yes |
| unit.1A.sleep | 07 domestic minimums | SPATIALLY_PROVEN | SPATIALLY_PROVEN | - |  | yes |
| unit.1A.storage | 07 domestic minimums | SPATIALLY_PROVEN | SPATIALLY_PROVEN | - |  | yes |
| unit.1D | 06 canonical units | SPATIALLY_PROVEN | SPATIALLY_PROVEN | - |  | yes |
| unit.1D.cooking | 07 domestic minimums | SPATIALLY_PROVEN | SPATIALLY_PROVEN | - |  | yes |
| unit.1D.entry | 07 domestic minimums | SPATIALLY_PROVEN | SPATIALLY_PROVEN | - |  | yes |
| unit.1D.living | 07 domestic minimums | SPATIALLY_PROVEN | SPATIALLY_PROVEN | - |  | yes |
| unit.1D.sanitary | 07 domestic minimums | SPATIALLY_PROVEN | SPATIALLY_PROVEN | - |  | yes |
| unit.1D.sleep | 07 domestic minimums | SPATIALLY_PROVEN | SPATIALLY_PROVEN | - |  | yes |
| unit.1D.storage | 07 domestic minimums | SPATIALLY_PROVEN | SPATIALLY_PROVEN | - |  | yes |
| unit.2A | 06 canonical units | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, FULL_BUILDING_RUNTIME, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| unit.2A.cooking | 07 domestic minimums | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| unit.2A.entry | 07 domestic minimums | SPATIALLY_PROVEN | SPATIALLY_PROVEN | - |  |  |
| unit.2A.living | 07 domestic minimums | SPATIALLY_PROVEN | SPATIALLY_PROVEN | - |  |  |
| unit.2A.sanitary | 07 domestic minimums | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| unit.2A.sleep | 07 domestic minimums | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| unit.2A.storage | 07 domestic minimums | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| unit.2B | 06 canonical units | SPATIALLY_PROVEN | SPATIALLY_PROVEN | - |  | yes |
| unit.2B.cooking | 07 domestic minimums | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.2B.entry | 07 domestic minimums | SPATIALLY_PROVEN | SPATIALLY_PROVEN | - |  | yes |
| unit.2B.living | 07 domestic minimums | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.2B.sanitary | 07 domestic minimums | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.2B.sleep | 07 domestic minimums | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.2B.storage | 07 domestic minimums | SPATIALLY_PROVEN | SPATIALLY_PROVEN | - |  | yes |
| unit.2C | 06 canonical units | SPATIALLY_PROVEN | SPATIALLY_PROVEN | - |  | yes |
| unit.2C.cooking | 07 domestic minimums | SPATIALLY_PROVEN | SPATIALLY_PROVEN | - |  | yes |
| unit.2C.entry | 07 domestic minimums | SPATIALLY_PROVEN | SPATIALLY_PROVEN | - |  | yes |
| unit.2C.living | 07 domestic minimums | SPATIALLY_PROVEN | SPATIALLY_PROVEN | - |  | yes |
| unit.2C.sanitary | 07 domestic minimums | SPATIALLY_PROVEN | SPATIALLY_PROVEN | - |  | yes |
| unit.2C.sleep | 07 domestic minimums | SPATIALLY_PROVEN | SPATIALLY_PROVEN | - |  | yes |
| unit.2C.storage | 07 domestic minimums | SPATIALLY_PROVEN | SPATIALLY_PROVEN | - |  | yes |
| unit.2D | 06 canonical units | PROGRAMMED | PROGRAMMED | - |  | yes |
| unit.3A | 06 canonical units | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, FULL_BUILDING_RUNTIME, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.3A.cooking | 07 domestic minimums | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.3A.entry | 07 domestic minimums | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.3A.living | 07 domestic minimums | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.3A.sanitary | 07 domestic minimums | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.3A.sleep | 07 domestic minimums | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.3A.storage | 07 domestic minimums | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.3B | 06 canonical units | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, FULL_BUILDING_RUNTIME, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.3B.cooking | 07 domestic minimums | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.3B.entry | 07 domestic minimums | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.3B.living | 07 domestic minimums | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.3B.sanitary | 07 domestic minimums | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.3B.sleep | 07 domestic minimums | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.3B.storage | 07 domestic minimums | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.3C | 06 canonical units | PROGRAMMED | PROGRAMMED | - |  | yes |
| unit.3D | 06 canonical units | SPATIALLY_PROVEN | SPATIALLY_PROVEN | - |  | yes |
| unit.3D.cooking | 07 domestic minimums | SPATIALLY_PROVEN | SPATIALLY_PROVEN | - |  | yes |
| unit.3D.entry | 07 domestic minimums | SPATIALLY_PROVEN | SPATIALLY_PROVEN | - |  | yes |
| unit.3D.living | 07 domestic minimums | SPATIALLY_PROVEN | SPATIALLY_PROVEN | - |  | yes |
| unit.3D.sanitary | 07 domestic minimums | SPATIALLY_PROVEN | SPATIALLY_PROVEN | - |  | yes |
| unit.3D.sleep | 07 domestic minimums | SPATIALLY_PROVEN | SPATIALLY_PROVEN | - |  | yes |
| unit.3D.storage | 07 domestic minimums | SPATIALLY_PROVEN | SPATIALLY_PROVEN | - |  | yes |
| unit.4A | 06 canonical units | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, FULL_BUILDING_RUNTIME, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.4A.cooking | 07 domestic minimums | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.4A.entry | 07 domestic minimums | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.4A.living | 07 domestic minimums | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.4A.sanitary | 07 domestic minimums | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.4A.sleep | 07 domestic minimums | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.4A.storage | 07 domestic minimums | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.4B | 06 canonical units | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, FULL_BUILDING_RUNTIME, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| unit.4B.cooking | 07 domestic minimums | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| unit.4B.entry | 07 domestic minimums | SPATIALLY_PROVEN | SPATIALLY_PROVEN | - |  |  |
| unit.4B.living | 07 domestic minimums | SPATIALLY_PROVEN | SPATIALLY_PROVEN | - |  |  |
| unit.4B.sanitary | 07 domestic minimums | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| unit.4B.sleep | 07 domestic minimums | SPATIALLY_PROVEN | SPATIALLY_PROVEN | - |  |  |
| unit.4B.storage | 07 domestic minimums | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| unit.4C | 06 canonical units | SPATIALLY_PROVEN | SPATIALLY_PROVEN | - |  | yes |
| unit.4C.cooking | 07 domestic minimums | SPATIALLY_PROVEN | SPATIALLY_PROVEN | - |  | yes |
| unit.4C.entry | 07 domestic minimums | SPATIALLY_PROVEN | SPATIALLY_PROVEN | - |  | yes |
| unit.4C.living | 07 domestic minimums | SPATIALLY_PROVEN | SPATIALLY_PROVEN | - |  | yes |
| unit.4C.sanitary | 07 domestic minimums | SPATIALLY_PROVEN | SPATIALLY_PROVEN | - |  | yes |
| unit.4C.sleep | 07 domestic minimums | SPATIALLY_PROVEN | SPATIALLY_PROVEN | - |  | yes |
| unit.4C.storage | 07 domestic minimums | SPATIALLY_PROVEN | SPATIALLY_PROVEN | - |  | yes |
| unit.4D | 06 canonical units | SPATIALLY_PROVEN | SPATIALLY_PROVEN | - |  | yes |
| unit.4D.cooking | 07 domestic minimums | SPATIALLY_PROVEN | SPATIALLY_PROVEN | - |  | yes |
| unit.4D.entry | 07 domestic minimums | SPATIALLY_PROVEN | SPATIALLY_PROVEN | - |  | yes |
| unit.4D.living | 07 domestic minimums | SPATIALLY_PROVEN | SPATIALLY_PROVEN | - |  | yes |
| unit.4D.sanitary | 07 domestic minimums | SPATIALLY_PROVEN | SPATIALLY_PROVEN | - |  | yes |
| unit.4D.sleep | 07 domestic minimums | SPATIALLY_PROVEN | SPATIALLY_PROVEN | - |  | yes |
| unit.4D.storage | 07 domestic minimums | SPATIALLY_PROVEN | SPATIALLY_PROVEN | - |  | yes |
| unit.5A | 06 canonical units | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, FULL_BUILDING_RUNTIME, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.5A.cooking | 07 domestic minimums | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.5A.entry | 07 domestic minimums | ABSENT | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.5A.living | 07 domestic minimums | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.5A.sanitary | 07 domestic minimums | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.5A.sleep | 07 domestic minimums | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.5A.storage | 07 domestic minimums | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.5B | 06 canonical units | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, FULL_BUILDING_RUNTIME, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.5B.cooking | 07 domestic minimums | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.5B.entry | 07 domestic minimums | ABSENT | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.5B.living | 07 domestic minimums | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.5B.sanitary | 07 domestic minimums | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.5B.sleep | 07 domestic minimums | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.5B.storage | 07 domestic minimums | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.5C | 06 canonical units | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, FULL_BUILDING_RUNTIME, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.5C.cooking | 07 domestic minimums | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.5C.entry | 07 domestic minimums | ABSENT | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.5C.living | 07 domestic minimums | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.5C.sanitary | 07 domestic minimums | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.5C.sleep | 07 domestic minimums | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.5C.storage | 07 domestic minimums | ABSENT | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.5D | 06 canonical units | PROGRAMMED | PROGRAMMED | - |  | yes |
| unit.6A | 06 canonical units | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, FULL_BUILDING_RUNTIME, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.6A.cooking | 07 domestic minimums | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.6A.entry | 07 domestic minimums | ABSENT | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.6A.living | 07 domestic minimums | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.6A.sanitary | 07 domestic minimums | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.6A.sleep | 07 domestic minimums | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.6A.storage | 07 domestic minimums | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.6B | 06 canonical units | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, FULL_BUILDING_RUNTIME, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.6B.cooking | 07 domestic minimums | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.6B.entry | 07 domestic minimums | ABSENT | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.6B.living | 07 domestic minimums | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.6B.sanitary | 07 domestic minimums | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.6B.sleep | 07 domestic minimums | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.6B.storage | 07 domestic minimums | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.6C | 06 canonical units | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, FULL_BUILDING_RUNTIME, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.6C.cooking | 07 domestic minimums | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.6C.entry | 07 domestic minimums | ABSENT | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.6C.living | 07 domestic minimums | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.6C.sanitary | 07 domestic minimums | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.6C.sleep | 07 domestic minimums | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.6C.storage | 07 domestic minimums | ABSENT | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| unit.6D | 06 canonical units | PROGRAMMED | PROGRAMMED | - |  | yes |
| b1.boiler_room | 11 maintenance/service spaces | SPATIALLY_PROVEN | SPATIALLY_PROVEN | - |  |  |
| b1.coal_room | 11 maintenance/service spaces | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| b1.electrical_room | 11 maintenance/service spaces | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| b1.laundry | 11 maintenance/service spaces | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| b1.maintenance_shop | 11 maintenance/service spaces | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| b1.resident_storage | 11 maintenance/service spaces | ABSENT | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| roof.roof_bulkhead | 11 maintenance/service spaces | PROGRAMMED | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| roof.tank_machinery | 11 maintenance/service spaces | ABSENT | SPATIALLY_PROVEN | FULL_BUILDING_STRUCTURAL, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| service.wet_stack | 12 service continuity | PROGRAMMED | RUNTIME_PROVEN | FULL_BUILDING_STRUCTURAL, FULL_BUILDING_RUNTIME, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| service.heat_stack | 12 service continuity | PROGRAMMED | RUNTIME_PROVEN | FULL_BUILDING_STRUCTURAL, FULL_BUILDING_RUNTIME, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| service.telephone_riser | 12 service continuity | PROGRAMMED | RUNTIME_PROVEN | FULL_BUILDING_STRUCTURAL, FULL_BUILDING_RUNTIME, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| service.passenger_lift | 12 service continuity | PROGRAMMED | RUNTIME_PROVEN | FULL_BUILDING_STRUCTURAL, FULL_BUILDING_RUNTIME, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| service.service_lift | 12 service continuity | PROGRAMMED | RUNTIME_PROVEN | FULL_BUILDING_STRUCTURAL, FULL_BUILDING_RUNTIME, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| service.electrical_riser | 12 service continuity | ABSENT | RUNTIME_PROVEN | FULL_BUILDING_STRUCTURAL, FULL_BUILDING_RUNTIME, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| service.fire_service | 12 service continuity | ABSENT | RUNTIME_PROVEN | FULL_BUILDING_STRUCTURAL, FULL_BUILDING_RUNTIME, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| contract.B1_BOILER_01 | 13/14 semantic contracts | SPATIALLY_PROVEN | RUNTIME_PROVEN | FIRST_SLICE_TECHNICAL, GOLDEN_SHIFT_V2, FULL_BUILDING_RUNTIME, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| contract.F01_DOOR_06 | 13/14 semantic contracts | RUNTIME_PROVEN | RUNTIME_PROVEN | - |  |  |
| contract.F01_HOUSE_TELEPHONE_BOARD | 13/14 semantic contracts | RUNTIME_PROVEN | RUNTIME_PROVEN | - |  |  |
| contract.F01_LOBBY | 13/14 semantic contracts | SPATIALLY_PROVEN | RUNTIME_PROVEN | FULL_BUILDING_RUNTIME, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| contract.F02_A_MAIN | 13/14 semantic contracts | SPATIALLY_PROVEN | RUNTIME_PROVEN | FULL_BUILDING_RUNTIME, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| contract.F02_A_MAIN_VANTRY_POINT | 13/14 semantic contracts | RUNTIME_PROVEN | RUNTIME_PROVEN | - |  |  |
| contract.F02_B_RADIATOR_01 | 13/14 semantic contracts | SPATIALLY_PROVEN | RUNTIME_PROVEN | FIRST_SLICE_TECHNICAL, GOLDEN_SHIFT_V2, FULL_BUILDING_RUNTIME, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| contract.F02_DOOR_02 | 13/14 semantic contracts | RUNTIME_PROVEN | RUNTIME_PROVEN | - |  |  |
| contract.F04_B_ALCOVE | 13/14 semantic contracts | PROGRAMMED | RUNTIME_PROVEN | FULL_BUILDING_RUNTIME, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| contract.F04_B_BATH | 13/14 semantic contracts | PROGRAMMED | RUNTIME_PROVEN | FULL_BUILDING_RUNTIME, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| contract.F04_B_BED | 13/14 semantic contracts | RUNTIME_PROVEN | RUNTIME_PROVEN | - |  |  |
| contract.F04_B_CLOSET | 13/14 semantic contracts | PROGRAMMED | RUNTIME_PROVEN | FULL_BUILDING_RUNTIME, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| contract.F04_B_KITCHEN | 13/14 semantic contracts | PROGRAMMED | RUNTIME_PROVEN | FULL_BUILDING_RUNTIME, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| contract.F04_B_MAIN | 13/14 semantic contracts | SPATIALLY_PROVEN | RUNTIME_PROVEN | FULL_BUILDING_RUNTIME, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| contract.F04_B_MONITOR_01 | 13/14 semantic contracts | RUNTIME_PROVEN | RUNTIME_PROVEN | - |  |  |
| contract.F04_B_VESTIBULE | 13/14 semantic contracts | SPATIALLY_PROVEN | RUNTIME_PROVEN | FULL_BUILDING_RUNTIME, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| contract.F04_DOOR_03 | 13/14 semantic contracts | RUNTIME_PROVEN | RUNTIME_PROVEN | - |  |  |
| contract.LobbyMailBank | 13/14 semantic contracts | RUNTIME_PROVEN | RUNTIME_PROVEN | - |  |  |
| contract.LobbyPorterBoard | 13/14 semantic contracts | RUNTIME_PROVEN | RUNTIME_PROVEN | - |  |  |
| contract.LobbyServiceDumbwaiter | 13/14 semantic contracts | RUNTIME_PROVEN | RUNTIME_PROVEN | - |  |  |
| job.lena_radiator_round_2b | 15 jobs and case routes | PROGRAMMED | RUNTIME_PROVEN | FIRST_SLICE_TECHNICAL, GOLDEN_SHIFT_V2, FULL_BUILDING_RUNTIME, PRODUCTION_CUTOVER, V1_RETIREMENT |  | yes |
| job.vantry_chirp_2a | 15 jobs and case routes | RUNTIME_PROVEN | RUNTIME_PROVEN | - |  |  |
| acoustic.v2_rederivation | 16 acoustic topology | PROGRAMMED | RUNTIME_PROVEN | FULL_BUILDING_RUNTIME, PRODUCTION_CUTOVER, V1_RETIREMENT | yes |  |
| save.bedside_return | 17 save/wake reconstruction | RUNTIME_PROVEN | RUNTIME_PROVEN | V1_RETIREMENT | yes |  |
| save.unit_rect_facts | 17 save/wake reconstruction | PROGRAMMED | RUNTIME_PROVEN | FULL_BUILDING_RUNTIME, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| interaction.F01_DOOR_06 | 18 interaction ownership | RUNTIME_PROVEN | RUNTIME_PROVEN | - |  |  |
| interaction.F01_HOUSE_TELEPHONE_BOARD | 18 interaction ownership | RUNTIME_PROVEN | RUNTIME_PROVEN | - |  |  |
| interaction.F02_A_MAIN_VANTRY_POINT | 18 interaction ownership | RUNTIME_PROVEN | RUNTIME_PROVEN | - |  |  |
| interaction.F02_A_MONITOR_01 | 18 interaction ownership | RUNTIME_PROVEN | RUNTIME_PROVEN | - |  |  |
| interaction.F02_DOOR_02 | 18 interaction ownership | RUNTIME_PROVEN | RUNTIME_PROVEN | - |  |  |
| interaction.F04_B_BED | 18 interaction ownership | RUNTIME_PROVEN | RUNTIME_PROVEN | - |  |  |
| interaction.F04_B_BEDSIDE_RETURN | 18 interaction ownership | RUNTIME_PROVEN | RUNTIME_PROVEN | - |  |  |
| interaction.F04_B_MONITOR_01 | 18 interaction ownership | RUNTIME_PROVEN | RUNTIME_PROVEN | - |  |  |
| interaction.F04_DOOR_03 | 18 interaction ownership | RUNTIME_PROVEN | RUNTIME_PROVEN | - |  |  |
| interaction.LobbyMailBank | 18 interaction ownership | RUNTIME_PROVEN | RUNTIME_PROVEN | - |  |  |
| interaction.LobbyPorterBoard | 18 interaction ownership | RUNTIME_PROVEN | RUNTIME_PROVEN | - |  |  |
| interaction.LobbyServiceDumbwaiter | 18 interaction ownership | RUNTIME_PROVEN | RUNTIME_PROVEN | - |  |  |
| human.route_readability | 19 human route readability | HUMAN_ACCEPTED | HUMAN_ACCEPTED | - |  |  |
| evidence.receipts | 20 performance/evidence coverage | RUNTIME_PROVEN | RUNTIME_PROVEN | - |  |  |
| evidence.whole_building_stations | 20 performance/evidence coverage | ABSENT | RUNTIME_PROVEN | PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| human.whole_building_navigation | 19 human route readability | ABSENT | HUMAN_ACCEPTED | PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| selector.reversible_two_root | 21 reversible selector and v1 fallback | RUNTIME_PROVEN | RUNTIME_PROVEN | - |  |  |
| furnishing.envelopes | 22 final-furnishing readiness | PROGRAMMED | PROGRAMMED | - |  |  |
| golden.eleven_beats | 15/19 golden shift | ABSENT | HUMAN_ACCEPTED | GOLDEN_SHIFT_V2, PRODUCTION_CUTOVER, V1_RETIREMENT |  |  |
| retirement.authorization | 21 reversible selector and v1 fallback | ABSENT | HUMAN_ACCEPTED | V1_RETIREMENT |  |  |

## Recommended queue

### M08E-f01-rituals-2b-b1
- scope: Build and spatially prove the F01 ritual desk spaces/identities, apartment 2B, and the B1 service route (boiler endpoint) in the v2 schema.
- prerequisite: M08D runtime-parity checkpoint (done)
- outstanding: 4 requirements
- exit: All four ritual identities, unit 2B and the B1 boiler endpoint resolve uniquely in v2 with SPATIALLY_PROVEN status.

### M08F-runtime-composition-of-m08e
- scope: Compose and runtime-prove the M08E spaces: first shift ritual, service round and night register under the v2 runtime root; authority census 1:1.
- prerequisite: M08E-f01-rituals-2b-b1
- outstanding: 3 requirements
- exit: M08D authority census reports 1:1 for FirstShiftDirector and ServiceRoundDirector under explicit v2 selection.  FIRST_SLICE_TECHNICAL clean - production cutover NOT implied.

### M10-golden-shift-v2
- scope: Author and human-run the eleven golden-shift beats under EXPLICIT v2 selection (K3 matrix); v1 stays the production default throughout.
- prerequisite: M08F-runtime-composition-of-m08e
- outstanding: 2 requirements
- exit: GOLDEN_SHIFT_V2 scope clean - still not a production-default authorization.

### M11-structural-floors
- scope: Build remaining canonical floors structurally: F03 full program, F05, F06, B1 full program, ROOF; electrical + fire risers; declared service-hall openings.
- prerequisite: M08F-runtime-composition-of-m08e
- outstanding: 40 requirements
- exit: All eight canonical floors PROGRAMMED and SPATIALLY_PROVEN with circulation and riser endpoints.

### M12-apartments-by-case-dependency
- scope: Build occupied apartments in case-dependency order (units with active case routes first), then transient 4D.
- prerequisite: M11-structural-floors
- outstanding: 76 requirements
- exit: Every occupied unit >= SPATIALLY_PROVEN with all six domestic functions present.

### M14-service-topology-and-acoustics
- scope: Regenerate acoustic graph and service networks from v2 topology, retaining externally consumed node ids; retire adapter positional overrides.
- prerequisite: M11-structural-floors
- outstanding: 8 requirements
- exit: Graph positions derive from v2; adapter positional overrides retired.

### M15-whole-building-runtime-matrix
- scope: Whole-building runtime consumer and save matrix: every job, case, interaction, resident, wake and organism fact resolves and reconstructs under explicit v2 selection.
- prerequisite: M12-apartments-by-case-dependency + M14-service-topology-and-acoustics
- outstanding: 12 requirements
- exit: FULL_BUILDING_RUNTIME scope clean.

### M16-whole-building-performance-navigation
- scope: Whole-building performance stations, human navigation acceptance, resident schedule proof.
- prerequisite: M15-whole-building-runtime-matrix
- outstanding: 2 requirements
- exit: Whole-building route budget met and owner-accepted.

### M09-production-cutover-proposal
- scope: Evidence-backed production default switch: flip BuildingRootSelector.DEFAULT_ID with a tagged v1 fallback and rollback instructions.  May exist earlier only as a dormant proposal template.
- prerequisite: M16-whole-building-performance-navigation (PRODUCTION_CUTOVER scope must be clean)
- outstanding: 151 requirements
- exit: Owner-signed production-cutover authorization; DEFAULT_ID flips with a one-line revert as rollback.

### M17-v1-fallback-window
- scope: Post-cutover rollback window: v1 stays selectable and tagged; regressions revert the one-line DEFAULT_ID change.
- prerequisite: M09-production-cutover-proposal
- outstanding: 1 requirements
- exit: Window closed by the owner with no rollback.

### M18-v1-retirement
- scope: Retire the v1 fallback: remove the anonymous-bed fallback, freeze v1 generation as a migration fixture, retire adapter aliases id-by-id.
- prerequisite: M17-v1-fallback-window
- outstanding: 153 requirements
- exit: No TEMPORARY_V1_FALLBACK flag remains anywhere in this ledger; v1 tagged as frozen fixture.

## Provenance

- `art/data/building_layout.json` sha256 `f4815741dd37ab14...`
- `art/renders/orison_v2/building_surface_finish_20261005/runtime_authority_receipt.json` sha256 `b792e5efd1fb8018...`
- `art/renders/orison_v2/cobbler_fittings_20261005/runtime_authority_receipt.json` sha256 `f4116ede94c5262f...`
- `art/renders/orison_v2/f04_4b_checkpoint_02/scene_capture_receipt.json` sha256 `544bb75d35a73c4f...`
- `art/renders/orison_v2/front_court_roof_20261005/runtime_authority_receipt.json` sha256 `5e26f5379b290c58...`
- `art/renders/orison_v2/front_facade_20261005/runtime_authority_receipt.json` sha256 `1b8f798a90ac6c81...`
- `art/renders/orison_v2/front_facade_air_20261005/runtime_authority_receipt.json` sha256 `8e0fad1ed7845bf4...`
- `art/renders/orison_v2/hardware_apparatus_20261005/runtime_authority_receipt.json` sha256 `9f2132f0d7d2ff46...`
- `art/renders/orison_v2/hardware_drawers_20261005/runtime_authority_receipt.json` sha256 `8efc20ee5e2a01b4...`
- `art/renders/orison_v2/hardware_stock_20261005/runtime_authority_receipt.json` sha256 `b1a14561ecae26c9...`
- `art/renders/orison_v2/hardware_tools_20261005/runtime_authority_receipt.json` sha256 `7a45613a0f6d97a4...`
- `art/renders/orison_v2/lamp_surface_balance_20261005/runtime_authority_receipt.json` sha256 `250a66cba7ee590f...`
- `art/renders/orison_v2/locksmith_fittings_20261005/runtime_authority_receipt.json` sha256 `d44c859635227a58...`
- `art/renders/orison_v2/m08_integrated_checkpoint_01/scene_capture_receipt.json` sha256 `f0c1cb99fd4d1f59...`
- `art/renders/orison_v2/m08a_readability_checkpoint_04/scene_capture_receipt.json` sha256 `e8f73826954a48f2...`
- `art/renders/orison_v2/m08e_spatial_owners_checkpoint_02/scene_capture_receipt.json` sha256 `2807d068dcdd577b...`
- `art/renders/orison_v2/m08e_spatial_owners_checkpoint_03/scene_capture_receipt.json` sha256 `25fdb35974fc6211...`
- `art/renders/orison_v2/m08f_runtime_composition_01/runtime_authority_receipt.json` sha256 `df1cd431570a3f3c...`
- `art/renders/orison_v2/m08f_runtime_composition_01/scene_capture_receipt.json` sha256 `1d8d128cc2514cd0...`
- `art/renders/orison_v2/m11a_first_exterior_cell_01/scene_capture_receipt.json` sha256 `3c91391ef705607e...`
- `art/renders/orison_v2/m11aa_first_exterior_cell_readability_01/scene_capture_receipt.json` sha256 `b37cd4d362cc750a...`
- `art/renders/orison_v2/m11b_service_openings_02/scene_capture_receipt.json` sha256 `472c33b61fc3cc5c...`
- `art/renders/orison_v2/news_fittings_20261005/runtime_authority_receipt.json` sha256 `49b1e38e56d2b7f4...`
- `art/renders/orison_v2/photo_cameras_20261005/runtime_authority_receipt.json` sha256 `ea0f16fe15238021...`
- `art/renders/orison_v2/photo_counter_20261005/runtime_authority_receipt.json` sha256 `ad4ae5baf46989b3...`
- `art/renders/orison_v2/photo_stock_20261005/runtime_authority_receipt.json` sha256 `0fe76abab1724f14...`
- `design/ORISON_REBUILD_MIGRATION_CONTRACT_2026-08-28.md` sha256 `534567ba02295ef7...`
- `design/ORISON_V2_COMPLETION_INTERIORS_CHECKPOINT_2026-09-25.md` sha256 `d4758366076e3309...`
- `design/ORISON_V2_F01_GRAYBOX_CHECKPOINT_2026-08-28.md` sha256 `6bbb9e719408adc9...`
- `design/ORISON_V2_F02_2A_GRAYBOX_CHECKPOINT_2026-08-28.md` sha256 `9b1cf53b753d9ff2...`
- `design/ORISON_V2_F04_4B_GRAYBOX_CHECKPOINT_2026-08-28.md` sha256 `7becd4429dd05f0f...`
- `design/ORISON_V2_FLOOR_LANDING_REHEARSAL_CHECKPOINT_2026-08-29.md` sha256 `33e53eac6ec02a7c...`
- `design/ORISON_V2_M08A_ACCEPTANCE_HARDENING_CHECKPOINT_2026-08-28.md` sha256 `aaadce2c9f8e38a1...`
- `design/ORISON_V2_M08A_HUMAN_ACCEPTANCE_2026-08-28.json` sha256 `0681e59ad90e631e...`
- `design/ORISON_V2_M08C_PRODUCTION_COMPOSITION_CHECKPOINT_2026-08-28.md` sha256 `9aa359821f302e57...`
- `design/ORISON_V2_M08D_RUNTIME_PARITY_CHECKPOINT_2026-08-28.md` sha256 `f53deef977f1218b...`
- `design/ORISON_V2_M08E_A_HUMAN_ACCEPTANCE_RECEIPT_2026-08-28.md` sha256 `aee694ddd37d57f5...`
- `design/ORISON_V2_M08E_A_HUMAN_READABILITY_CHECKPOINT_2026-08-28.md` sha256 `cc5155b4fed1ea2b...`
- `design/ORISON_V2_M08E_SPATIAL_OWNERS_CHECKPOINT_2026-08-28.md` sha256 `6c142a4ac669707f...`
- `design/ORISON_V2_M08F_RUNTIME_COMPOSITION_CHECKPOINT_2026-08-28.md` sha256 `cbd6162c3f655bb9...`
- `design/ORISON_V2_M08_INTEGRATED_FIRST_SLICE_CHECKPOINT_2026-08-28.md` sha256 `358e82f0d9e17e83...`
- `design/ORISON_V2_M10_PREPARATION_CHECKPOINT_2026-08-28.md` sha256 `f56c648289ceef75...`
- `design/ORISON_V2_M11A_A_HUMAN_ACCEPTANCE_RECEIPT_2026-08-30.md` sha256 `626f2c98ab30b66f...`
- `design/ORISON_V2_M11A_A_HUMAN_READABILITY_CHECKPOINT_2026-08-30.md` sha256 `88130c965cfacd77...`
- `design/ORISON_V2_M11A_FIRST_EXTERIOR_CELL_TECHNICAL_CHECKPOINT_2026-08-30.md` sha256 `73a6d3125d8f7785...`
- `design/ORISON_V2_M11B_HUMAN_ACCEPTANCE_RECEIPT_2026-08-31.md` sha256 `ae80aa770a0bc7af...`
- `design/ORISON_V2_M11B_SERVICE_OPENINGS_CHECKPOINT_2026-08-30.md` sha256 `ac9a2fc8fa30b647...`
- `design/ORISON_V2_M11C0_DISPOSABLE_CUT_VALIDATION_RECEIPT_2026-08-31.md` sha256 `6fb9a3d2ddc8246f...`
- `design/ORISON_V2_M11C0_FLOOR01_CUT_REHEARSAL_CHECKPOINT_2026-08-31.md` sha256 `d48772789e675e98...`
- `design/ORISON_V2_M11C1_OWNER_FIRST_EXPORT_CHECKPOINT_2026-08-31.md` sha256 `c709ec7a922ed3b3...`
- `design/ORISON_V2_M11C2_FLOOR01_PRODUCTION_CUT_CHECKPOINT_2026-08-31.md` sha256 `1f0288d28e4887b1...`
- `design/ORISON_V2_M11D_ZERO_GEOMETRY_CHECKPOINT_2026-09-13.md` sha256 `ce217547a44aa2ae...`
- `design/ORISON_V2_SCHEMA_GENERATOR_CHECKPOINT_2026-08-28.md` sha256 `f8660762823f1865...`
- `design/ORISON_V2_VERTICAL_CORE_CHECKPOINT_2026-08-28.md` sha256 `83cff9b36fd379d2...`
- `game/data/orison_v2_blockout.json` sha256 `053033cbe95d8775...`
- `game/scripts/building/orison_v2_anchor_adapter.gd` sha256 `59a544e60c3b4751...`
- `game/tests/orison_v2_resident_key_route_test.gd` sha256 `b64bac7ebf7b7492...`
- `tools/orison_spatial_dependency_manifest.json` sha256 `4d27937a85f05556...`
