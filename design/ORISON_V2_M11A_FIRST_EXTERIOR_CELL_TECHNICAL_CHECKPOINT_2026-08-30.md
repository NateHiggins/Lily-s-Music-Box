# Orison v2 M11A first exterior cell technical checkpoint — 2026-08-30

Evidence class: **TECHNICAL CHECKPOINT — NO STATUS PROMOTION**

## Decision

The bounded production landing is technically complete for one exterior cell:
Orison-side pavement, the bodega threshold and interior, and the semantic
return toward Orison. The final runtime objective is **PASS 35/35**, the final
Forward+ capture is **PASS 4/4**, and the new production packet remains
**HUMAN REVIEW PENDING**.

This checkpoint does not authorize M09, a selector cutover, v1 retirement,
production-layout replacement, broader exterior generation, or a merge to
main. The committed selector default remains **v1**. The branch is only
**codex/orison-v2-m11a-first-exterior-cell**.

The port preserves the accepted synthetic cell's route topology, semantic
threshold, public interaction, simulation ownership, and return contract.
Its night presentation is darker than the disposable accepted packet, so this
report does not transfer that packet's human verdict or self-declare visual
equivalence. The four new production frames require an owner decision.

## Authorization and before-write controls

Authorization came from commit
`3855fa5e55d7d39f5bc146741cae7223540a9e53` and
`design/ORISON_V2_DRY_RUN_THIRD_REPORT_2026-08-30.md`.

Before any write:

- HEAD was `3855fa5e55d7d39f5bc146741cae7223540a9e53`.
- origin/main was `c2dc01771bc25b07f5dcf7a6040102345b8c57d5`.
- The merge base was `c2dc01771bc25b07f5dcf7a6040102345b8c57d5`.
- The new worktree was clean.
- `BuildingRootSelector.DEFAULT_ID` was **v1**.
- All 17 protected files matched the hashes below.
- Completeness contained 150 requirements and the six blocker scopes shown in
  the ledger table below.
- Spatial, systemic, and data-consumption baselines were captured before the
  new exterior source existed.

The expected ledger movement was exactly **region.street** and
**region.shops**, each from **ABSENT** to **PROGRAMMED**. This makes newly
authored exterior scope visible without changing any blocker count. The result
matches that prediction.

## Source-owned bodega simulation bucket

`game/data/orison_v2/exterior/shop_buckets.json` owns the canonical
**SHOP_BODEGA** record and its explicit shopfront lineage. The production
registry validates and consumes every field: durable stock, staffing, hours,
condition, last-advanced minute, and transaction count.

Advancement is a pure catch-up operation to a requested minute. It consumes
timetable facts exposed by the existing resident schedule authority; it does
not introduce a periodic restock timer. Repeating the same target minute is
idempotent. Backward time, duplicate identity, missing lineage, malformed
records, and unknown persisted siblings refuse atomically.

The bucket's stock and transaction values are anonymous retail-simulation
units driven by scheduled visits. They are not MaintenanceInventory parts.
The real maintenance catalog still owns only the carbon transmitter capsule at
**hardware_paint**, with its original nonempty provenance. Therefore the public
bodega counter honestly returns **COUNTER ATTENDED / NO OPEN ORDER** for the
existing **vantry_chirp_2a** awaiting-part job. It grants no item and mutates
neither MaintenanceInventory nor WorkOrders; that unchanged job survives the
save/reload transaction. This proves a public transaction/refusal surface and
work-order continuity, not successful bodega part acquisition.

## Public spatial seams

`OrisonV2ExteriorSpatialResolver` provides production interfaces for authored
regions, named owning surfaces, surface-relative placement, semantic
thresholds, semantic routes, reconstruction, and deterministic teardown.
Only the canonical street root is placed in the ruled shared frame. Child
instances inherit the complete owning-surface transform and add authored UVN
offset and local yaw.

The renderer enumerates source records generically. Authored IDs are metadata,
not generated node-path authority. It contains no first-bodega branch and does
not read either v1 layout for placement. The pinned v1 layouts appear only in
the independent protected-hash test.

The production source contains exactly **STREET_ORISON_01** and
**SHOP_BODEGA**. A disposable test adds **STREET_ROTATED_02** and
**SHOP_BODEGA_ROTATED_02** through the same resolver, bucket registry,
geometry templates, threshold path, route path, counter mount, and teardown.
The second root uses 35 degrees of yaw, remains attached with 0.0 m origin
error, and is absent from production data and human evidence.

## Visible production cell and ownership

`game/scenes/building/orison_v2_exterior_cell.tscn` composes the production
module. It uses the real PlayerController and existing WorkOrders,
MaintenanceInventory, MaintenanceShopService, DoorProp, AudioPolicy, and
BodegaSignage implementations. There is one owner for each authority.

The visible route is:

1. **ORISON_EXIT** to **PAVEMENT_TURN** on the Orison-side pavement;
2. **BODEGA_ALIGNMENT** and **BODEGA_EXTERIOR**;
3. the real **SHOP_BODEGA_STOREFRONT_LEAF** threshold interaction;
4. **BODEGA_INTERIOR** and the continuing deliveries opening;
5. **ROUTE_SHOP_BODEGA_TO_ORISON** back through the same collision-bearing
   pavement route.

The production controller walked 55.8 m in the objective transaction without
noclip or an intermediate teleport. The only placement was the legitimate
initial/reconstruction contract. The capture adds an authored overview detour
and returns through **PAVEMENT_TURN** to avoid the collision-bearing street
lamp before resuming the canonical route.

Teardown uses public counter unmount and AudioPolicy source release. It does
not reach into pooled render or audio nodes by name.

## Narrow production modifications outside the likely file boundary

The expected boundary allowed narrowly required adapter/composition changes.
The following existing files changed for specific bounded reasons:

- `game/scripts/game/reality_game_state.gd` adds backward-compatible empty
  durable containers for shop buckets and exterior semantic cursors. It does
  not move save authority or change the save version.
- `game/scripts/characters/schedule_director.gd` exposes pure place-activity
  facts from existing resident schedules. It does not move schedule authority
  or create a new clock.
- `game/scripts/game/maintenance_shop_service.gd` adds public semantic
  mount/unmount while preserving the v1 layout-driven counter path.
- `game/scripts/game/maintenance_shop_counter.gd` accepts a physical surface
  label while preserving the v1 hardware-counter default and transaction
  authority.
- `game/scripts/audio/audio_policy.gd` adds public semantic-source release so
  teardown never needs an audio-pool node path.
- `game/scripts/props/bodega_signage_prop.gd` binds that semantic audio source
  and retains its legacy node-name fallback for existing composition.

Existing job, case, save, inventory, interaction, audio, resident, and schedule
facts are unchanged. The objective suite, save compatibility run, spatial
audit, systemic audit, and data audit provide the focused regression proof.

## Exact save, destruction, reload, and reconstruction

The durable exterior payload contains only the state identity, route identity,
waypoint identity, threshold identity, bodega bucket, and existing gameplay
facts. It contains no world coordinate.

The test saves **ROUTE_SHOP_BODEGA_TO_ORISON** at non-default waypoint
**PAVEMENT_TURN**, destroys the module, reloads RealityState, reconstructs the
same identities, and then feeds those identities through the module's public
placement method. A production PlayerController injected under a transformed
external parent lands on the resolved pavement, proving the method consumes a
world-space semantic result rather than accidentally succeeding at the
default spawn.

- Save SHA-256:
  `edcf2609d0317b58a5efba5e829fedca4f1417e32a5238db2b73f2fbbad822a5`
- Canonical saved subset SHA-256:
  `7adc56b73c342f06725fb7a45c692e5f2c610bf31be46268371a8d94e87f18af`
- Reloaded subset SHA-256: identical.
- Bucket, semantic cursor, WorkOrders stage, serialized subset, resolved route,
  and public placement comparisons: all true.
- No saved world-coordinate key: true.

## Piece-two cost and rotation proof

| Measure | First street + shop | Rotated second street + shop |
| --- | ---: | ---: |
| Nodes | 120 | 120 |
| Mesh instances | 62 | 62 |
| Collision shapes | 32 | 32 |
| Collision objects | 4 | 4 |

The second root yaw is 34.9999998 degrees, its owning-surface attachment error
is 0.0 m, and the two cost dictionaries are byte-for-byte equivalent. The
second instances remain disposable test data and have no human acceptance.

The complete visible production module contains 194 nodes, 62 mesh instances,
34 collision shapes, six collision objects, one storefront leaf, one service
counter, ten lights, 41 shared meshes, 20 shared materials, and 24 shared
shapes.

## Final four-frame packet

Packet: `art/renders/orison_v2/m11a_first_exterior_cell_01/`

All frames are 1600×900 Forward+, use the real production module and current
PlayerController camera, retain the production carried lamp and HUD, contain
no capture-only geometry/light or developer overlay, and use one semantic
initial placement followed only by collision-bearing movement.

| Frame | SHA-256 | CPU median ms | Physics median ms | GPU median ms | Draw calls |
| --- | --- | ---: | ---: | ---: | ---: |
| `01_orison_side_route_beginning.png` | `53b1a6c3817ef599f54343e447a0e03263b4ae6561d42ab0a780045f51edee20` | 1.653 | 0.180 | 0.424 | 173 |
| `02_bodega_threshold_approach.png` | `b5c9f036536cfda15e37049b4499db7739e8b8be9a736e89cc5742e0bd0f08c2` | 1.695 | 0.236 | 0.764 | 171 |
| `03_bodega_interior_continuing_route.png` | `5af6156ecb858a087aa2eea3afe9b9f13e8b4de7f6bbc3360e864dc5155a5aab` | 2.004 | 0.222 | 0.833 | 76 |
| `04_return_direction_toward_orison.png` | `3986e5a745ab68bbc77c9c6e5febf5b5dd896b8e720091cc2a6c97da068b3030` | 1.947 | 0.218 | 0.697 | 90 |

GPU timing was measured by Forward+ and reported trustworthy for all eight
samples per station. The production storefront opened through
PlayerController's public interaction entrypoint in 0.967 ms before animation
settle.

The packet technically communicates the route stripe, the named storefront
and threshold, the two-aisle interior and continuing deliveries opening, and
the return stripe to the illuminated Orison portal. It remains a restrained,
dark night presentation and differs from the brighter disposable synthetic
packet. Human acceptance is therefore pending.

## Teardown disposition

The warmed objective process starts at 1,797 objects, 62 resources and zero
orphan nodes, then finishes at 1,737 objects, 62 resources and zero orphan
nodes. Its deltas are -60 objects, zero resources, and zero orphans. Every
module reports zero retained strong references, repeat teardown is idempotent,
and the player/module weak references clear.

The windowed capture process separately records +53 objects and +6 resources
after capture. Both cell and player weak references still clear, the public
receipt reports zero retained strong references, and orphan delta is zero.
The exact retained classes, owners, and reference chains behind that
process-level initialization delta were not traced, so it is not classified as
renderer caching or claimed as zero. The warmed objective transaction is the
zero-retained-instance/resource proof.

## Audit and test results

| Command | Exit | Result |
| --- | ---: | --- |
| `python tools/audit_orison_v2_completeness.py` | 2 | Expected incomplete full-rebuild ledger; exact two-region movement below. |
| `python tools/audit_orison_spatial_dependencies.py` | 0 | 3,652 records; no new failing, classification change, vanished target, or unresolved save contract. |
| `python tools/audit_systemic_situation_authority.py` | 0 | 59 findings; production remains 35; zero new actionable or policy violations. |
| `python tools/audit_data_consumption.py` | 1 | 1,303 reviewed historical findings; zero M11A exterior findings; one static token-audit record disappeared. |
| `python tools/tests/test_orison_v2_completeness.py` | 0 | 91/91. |
| `python tools/tests/test_orison_spatial_dependencies.py` | 0 | 51/51. |
| `python tools/tests/test_systemic_situation_authority.py` | 0 | 34/34. |
| `python tools/tests/test_data_consumption.py` | 0 | 14/14. |
| M11A objective scene | 0 | 35/35; stderr empty. |
| M11A final Forward+ capture scene | 0 | 4/4; stderr empty. |
| `python tools/audit_orison_v2_completeness.py --evidence-impact design/ORISON_V2_M11A_FIRST_EXTERIOR_CELL_TECHNICAL_CHECKPOINT_2026-08-30.md --json` | 0 | Admitted as **CHECKPOINT**; `requirements_changed` is empty. |

Completeness scope exits are first-slice 0 and golden-shift,
full-building-structural, full-building-runtime, production-cutover, and
retirement 2. These are expected scope verdicts, not suppressed failures.

The repository-wide data audit changed from 1,304 to 1,303 findings:
FIELD_UNREAD 1,290 to 1,289; FILE_UNREAD 11, MALFORMED 1, and
DURABLE_NUMERIC_MONOTONIC_ONLY 2 unchanged. The static record for the generic
key **released** in **game/data/audio_cues.json** disappeared because the token
now appears in the public release API; that lexical audit effect is not proof
of semantic cue-field consumption. M11A adds zero unread files, unread fields,
or monotonic-only durable values.

The spatial audit changed from 3,634 records in 741 files to 3,652 records in
751 files. Its 18 new incidental records are test/evidence provenance: the
capture scene path, protected layout/floor paths, and one disposable test
coordinate. All five initially exposed generated-name couplings were repaired
without baselining them.

## Completeness ledger movement

| Status | Before | After | Delta |
| --- | ---: | ---: | ---: |
| ABSENT | 52 | 50 | -2 |
| PROGRAMMED | 42 | 44 | +2 |
| HUMAN_ACCEPTED | 1 | 1 | 0 |
| RUNTIME_PROVEN | 34 | 34 | 0 |
| SHELL_ONLY | 3 | 3 | 0 |
| SPATIALLY_PROVEN | 18 | 18 | 0 |

| Scope | Before | After |
| --- | ---: | ---: |
| FIRST_SLICE_TECHNICAL | 0 | 0 |
| GOLDEN_SHIFT_V2 | 1 | 1 |
| FULL_BUILDING_STRUCTURAL | 86 | 86 |
| FULL_BUILDING_RUNTIME | 45 | 45 |
| PRODUCTION_CUTOVER | 101 | 101 |
| V1_RETIREMENT | 103 | 103 |

The two changed requirements are only **region.street** and
**region.shops**, exactly as predicted before implementation. No evidence tier
or blocker count moved.

## Protected hash comparison

All before/after SHA-256 values match:

| Protected path | SHA-256 before and after |
| --- | --- |
| `game/data/building_layout.json` | `68838c933c0954092c63403f36ec7fb26d6c0956c01c23109465c680608b399d` |
| `art/data/building_layout.json` | `68838c933c0954092c63403f36ec7fb26d6c0956c01c23109465c680608b399d` |
| `game/scripts/building/building_root_selector.gd` | `d2b3db95d72e4a418c0e7184e6b3368da723a945192024a10ee937ea604c9802` |
| `game/assets/building/floor_01.gltf` | `906f1f48c2fc8ff6e6af3048d0abca46416cd103bee8d818606a3c32c71fe5b1` |
| `game/assets/building/floor_01.bin` | `e1d3454afb6079602b8cfe0dcb00d255e6aa68f7f247c5ecc39bd5791cfdc477` |
| `game/assets/building/floor_02.gltf` | `b3977546cabc72775ad63be53bfb2001ace51d13094b4ed8b719a979adc2d640` |
| `game/assets/building/floor_02.bin` | `4b7d16ae8ed7df4a90f0626746ca5987bd02c61268f372fced86a3782760b69e` |
| `game/assets/building/floor_03.gltf` | `21c506695edf27effa20c711f1daed939c807a774f5076656e8ff3e8be898d3f` |
| `game/assets/building/floor_03.bin` | `8f84cb67f5f2fa8f2c5a5e47fbc418630957dbc8d6a96576e005c92ac6fcc9f8` |
| `game/assets/building/floor_04.gltf` | `c1a03abba15f481e6318e27d5035dae13e3e5173f16c2f208711769ce3bf8df1` |
| `game/assets/building/floor_04.bin` | `f57f45d79738086a5da23afd7d9a04d6f5596641193ec22856929de30b03e266` |
| `game/assets/building/floor_05.gltf` | `d5860b28c47a110fcced5b8cd22c0f5d4ae0fc036dfc0d44fbe884a2def41e7a` |
| `game/assets/building/floor_05.bin` | `a8e7f0fd106696a1c6c9823f30cf013b0f664e4dac5d763fc2c3d2c072dd54d8` |
| `game/assets/building/floor_06.gltf` | `96991ecf897b7882c68897eb9c8df5a678046e1567e8f59d51f21f6646209422` |
| `game/assets/building/floor_06.bin` | `8389d2264ea4c6e4eb59fb35b58d7480b3823641c1471b593a85613883bd9f5f` |
| `game/assets/building/floor_b1.gltf` | `f151ff10c8d2420340fc522df5e9eb2ffbdf200be6068b302c6769881af8eb3e` |
| `game/assets/building/floor_b1.bin` | `226437a3e2816882c04749918a4d99540ff2a4714d0a914b2dd2606ace8c4449` |

The selector line remains `const DEFAULT_ID := "v1"`. Neither production
layout, any floor GLTF/BIN, the selector, nor project settings changed.

## Remaining limitations

- Human review of the new production packet is pending. Prior synthetic human
  acceptance does not transfer.
- The night packet is darker than the accepted synthetic presentation. Route
  topology is technically preserved; visual preservation is an owner decision.
- No production-authorized bodega maintenance part/order exists. The public
  counter proves an honest no-open-order refusal and persistence, not a grant.
- The production cell remains an isolated approved v2 exterior module. It is
  not selector-wired and does not redirect runtime ownership.
- The rotated second shop and route are disposable proof only and have no human
  acceptance.
- Full exterior, full building, golden shift, production cutover, and v1
  retirement remain blocked by the unchanged ledger scopes above.

## Evidence index

- `art/renders/orison_v2/m11a_first_exterior_cell_01/production_cell_capture_receipt.json`
- `art/renders/orison_v2/m11a_first_exterior_cell_01/scene_capture_receipt.json`
- `art/renders/orison_v2/m11a_first_exterior_cell_01/objective_test_receipt.json`
- `art/renders/orison_v2/m11a_first_exterior_cell_01/validation_receipt.json`

No historical evidence was copied, replaced, or promoted. This report is an
inert technical receipt and must not move unrelated ledger requirements.
