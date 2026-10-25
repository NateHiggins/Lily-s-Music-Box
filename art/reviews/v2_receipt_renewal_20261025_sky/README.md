# V2 receipt renewal after the sky spectacle, 2026-10-25

Evidence class: **INERT**

This folder archives the three V2 packets that were replaced when they were
re-earned on main 25d5902c. That main includes PR 36 (sky spectacle) and the
gas mantles merge, and both had expired the PR 34 receipts.

| Packet | Suite | Result |
|---|---|---|
| `art/renders/orison_v2/first_slice_contract_20261011/` | `orison_v2_first_slice_contract_test.tscn` | PASS, 0 failures |
| `art/renders/orison_v2/surface_requirements_20261011/` | `OrisonV2SurfaceInventory.tscn` | PASS, 0 defects (28,533 draws) |
| `art/renders/orison_v2/access_upper_cohort_20261018/` | `OrisonV2UpperAccessCohort.tscn` | PASS, 69 rooms |

PR 36 changed `orison_v2_city_horizon.gd`, which made
`orison_city_horizon.json` stale. It was rebound by re-running
`build_city_horizon.py`, and the GLBs are byte-identical.

## Archive

- `previous_first_slice_packet/`: the replaced first-slice receipt and logs
- `previous_surface_packet/`: the replaced surface packet
- `previous_upper_packet/`: the replaced upper cohort packet
