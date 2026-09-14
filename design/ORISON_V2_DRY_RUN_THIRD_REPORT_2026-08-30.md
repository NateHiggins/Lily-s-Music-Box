# Orison v2 third dry-run report — 2026-08-30

Evidence class: **REPORT ONLY**

Completeness promotion: **NONE**

Overall result: **PASS**

Owner visual verdict: **HUMAN ACCEPTED**

Decision: **AUTHORIZE THE FIRST BOUNDED V2 BUILD LANDING**

This document summarizes a disposable, commit-pinned rehearsal. It is not a
spatial checkpoint, a completeness source, a production acceptance receipt, a
selector authorization, or authority to promote any ledger requirement. The
frozen machine receipts are not rewritten after the fact.

## Scope and decision

All five technical phases and the human inspection required by
`design/ORISON_V2_DRY_RUN_PLAN_2026-08-30.md` passed for one synthetic exterior
cell: the Orison-side pavement route, one bodega threshold, one shop interior,
and the return direction toward Orison.

After the final machine packet was frozen, the owner reviewed that packet and
supplied the governing-thread verdict exactly as follows:

> Human accepted.

That verdict closes the Phase 4 human gate for the visible primary synthetic
cell only. The generated objective and capture receipts correctly continue to
say `PENDING` because they predate the owner message. They were not altered
retroactively.

The resulting decision is **AUTHORIZE THE FIRST BOUNDED V2 BUILD LANDING**. A
separately reviewed production change may now land the reusable exterior data,
resolver, bucket, and semantic-spatial seams needed for the first
street/bodega/route cell. This does not authorize wholesale promotion of the
disposable proof implementation.

Production v1 remains the default. This report does **not** authorize M09, a
selector-default change, production cutover, v1 retirement, production-layout
replacement, generated-floor replacement, a `floor_01` split, or a
building-wide generation pass.

## Pinned run

| Item | Recorded value |
| --- | --- |
| Integration HEAD | `dcd7f722f0b1e8e5132f4644bfb31749c4b213ac` |
| `origin/main` | `c2dc01771bc25b07f5dcf7a6040102345b8c57d5` |
| Merge base | `c2dc01771bc25b07f5dcf7a6040102345b8c57d5` |
| Branch | `codex/orison-v2-full-rebuild` |
| Initial worktree status | clean; zero entries |
| Pin time | `2026-08-30T08:58:23.0450354-04:00` |
| Disposable artifact root | `C:\PleaseRemainOnTheLine-v2-dry-run-3-output-20260830` |
| Active Godot/Blender census | none |
| Godot actually used | `4.7.1.stable.official.a13da4feb` |
| Godot executable | WinGet console executable resolved by `tools/run_godot_serial.ps1` |
| Blender | `5.2.0 LTS`, build `fbe6228777e7` |
| Python | `3.12.10` |

The paired Godot executable expected beside the worktree was absent. This was
recorded rather than hidden; the serial runner resolved the installed WinGet
console executable and returned exit 0 for its version probe. A cold headless
editor import then completed with exit 0, 680 global classes and 1,600 imported
assets; stderr was empty.

## Phase disposition

| Phase | Result | Binding result |
| --- | --- | --- |
| 0 — pin and inventory | **PASS** | Commit, tools, processes, protected hashes, and baseline ledgers were recorded. Expected incomplete/report-only exits stayed nonzero. |
| 1 — instruments can be red | **PASS** | Runner pass, timeout 124, lane refusal 73, malformed inputs, builder refusals, and unread-data fixtures all produced distinguishable outcomes. |
| 2 — pre-M11 dependencies | **PASS** | The runtime contract passed 11/11 and every plan dependency had a named authority or measurement. Detection gates do not imply that their reported repository debt is resolved. |
| 3 — zero-geometry rehearsal | **PASS (rehearsal scope)** | Candidate evidence impact, source data, save mutation, and two service openings were rehearsed only in disposable copies. Nothing was landed. |
| 4 — synthetic first cell | **PASS (first-cell scope)** | Final objective passed 50/50, final capture passed 4/4, protected controls matched, teardown was clean, and the owner returned “Human accepted.” |

## Command and exit ledger

The audit and test commands below are the receipt-bearing commands used by the
run. Phase 0 retained exact command names and exits. For several Phase 1–4
Godot calls, the raw PowerShell argv was not written to a consolidated receipt;
their project, scene, timeout where applicable, log path, and native result are
recoverable from the runner logs and test sources. Such rows are explicitly
marked **effective command reconstructed** and are not claimed to be a
byte-for-byte shell transcript. This is a receipt-quality limitation, not a
substitution of a green result for a red one.

### Phase 0

| Command or probe | Exit | Result/artifact |
| --- | ---: | --- |
| Godot version probe through the serial runner | 0 | `phase0_godot_resolution.json`; resolved 4.7.1 |
| Blender version probe | 0 | `blender_version.txt` |
| Python version probe | 0 | `python_version.txt` |
| Headless Godot editor import | 0 | `phase0_godot_import.log`; empty stderr |
| `python tools/audit_orison_v2_completeness.py --json` | 2 | Expected: whole rebuild incomplete; `phase0_completeness.json` |
| `python tools/audit_orison_spatial_dependencies.py --json` | 0 | Clean drift result; `phase0_spatial.json` |
| `python tools/audit_systemic_situation_authority.py --json` | 0 | No new actionable finding; `phase0_systemic.json` |
| `python tools/audit_data_consumption.py --json` | 1 | Expected report-only repository debt; `phase0_data_consumption.json` |
| `python tools/tests/test_orison_v2_completeness.py` | 0 | 91/91 |
| `python tools/tests/test_orison_spatial_dependencies.py` | 0 | 51/51 |
| `python tools/tests/test_systemic_situation_authority.py` | 0 | 34/34 |
| `python tools/tests/test_data_consumption.py` | 0 | 14/14 |

### Phase 1

| Effective command/scope | Exit | Result/artifact |
| --- | ---: | --- |
| Serial runner, `res://tests/orison_v2_presence_ledger_test.tscn`, cold cache, 60 s | 124 | Honest pre-import timeout with missing-class parse diagnostics; not used as the suite verdict; `phase1_runner_pass.log[.stderr]` |
| Serial runner, same presence-ledger scene after import | 0 | 17/17; `phase1_runner_pass_after_import.log` |
| Serial runner, `res://tests/OrisonV2M08ESpatialTest.tscn`, `-TimeoutSeconds 1` | 124 | Valid partial log and six early PASS lines; `phase1_runner_timeout_expected.log` |
| Serial runner while controlled shared mutex was held | 73 | Prelaunch refusal; holder remained alive; runner contract intentionally writes no child log |
| Serial runner, `res://tests/OrisonV2BlockoutGuardTest.tscn` | 0 | 26 refusal/guard checks; intentional rejected-fixture errors in stderr; `phase1_builder_guard.log[.stderr]` |
| Completeness audit against malformed `bad_completeness` fixture | 3 | Malformed v2 layout refused; `phase1_bad_completeness.log` |
| Spatial audit with `malformed_spatial.json` | 3 | Manifest record without key refused; `phase1_bad_spatial.log` |
| Systemic audit against malformed baseline plus actionable fixture | 5 | Both conditions remained visible; `phase1_bad_systemic.log` |
| Data audit against `reader_bad` | 1 | Exactly four blockers; `phase1_reader_bad.log` |
| Data audit against `reader_green` | 0 | Zero blockers; `phase1_reader_green.json` |

The known-pass scene records one existing nonblocking behavior gap: hearing is
not presence-gated, so an absent resident may still earn an in-home hearing
belief. It was pinned, not reclassified as a dry-run success.

### Phase 2

| Effective command/scope | Exit | Result/artifact |
| --- | ---: | --- |
| Serial runner, `res://tests/AdminPrereqContractTest.tscn` | 0 | 11/11; `phase2_admin_prereq_contract.log[.stderr]` |

The only Phase 2 stderr warning is the intentional refusal boundary: saved
dream revision 999 is unavailable and reconstruction is cancelled before world
swap.

### Phase 3

| Effective command/scope | Exit | Result/artifact |
| --- | ---: | --- |
| `python tools/audit_orison_v2_completeness.py --evidence-impact design/ORISON_V2_ACCEPTED_SPACES_AMENDMENT_CHECKPOINT_2026-08-30.md` in scratch | 1 | Expected nonzero: exactly two predicted promotions; `phase3_checkpoint_evidence_impact.log` |
| Completeness audit over the final Phase 3 full snapshot | 2 | Expected incomplete result; frozen ledger under `phase3_full_completeness/` |
| `python tools/audit_data_consumption.py --root phase3_scratch --json` | 1 | Expected unchanged 1,304 global findings and zero shop-bucket findings; `phase3_shop_data_audit.json` |
| Serial runner, standalone `phase3_bucket_project/BucketTest.tscn` | 0 | 9/9 mutation/save/refusal checks; `phase3_synthetic_bucket.log` |
| Serial runner, standalone `phase3_opening_project/OpeningTest.tscn` | 0 | 10/10 opening/collision checks; `phase3_service_opening_rehearsal.log` |
| `python tools/audit_orison_spatial_dependencies.py --root phase3_scratch --json` on the complete snapshot | 0 | 3,635 records; no failing drift, class change, vanished target, unresolved save, or stale record |
| Earlier spatial audit against an incomplete partial root | 4 | Correct refusal because required trees were absent; raw argv/standalone receipt was not retained; complete-snapshot rerun above is authoritative |

### Phase 4 and final gates

| Effective command/scope | Exit | Result/artifact |
| --- | ---: | --- |
| Serial runner, `res://tests/OrisonV2Phase4FirstCellTest.tscn`, final binding run | 0 | 50/50, zero failures, empty stderr; `phase4_output/objective_14/` |
| Capture preflight for the final scene/run directory | 0 | Free lane and non-overwrite boundary |
| `tools/run_godot_capture.ps1` for `res://tests/OrisonV2Phase4FirstCellShot.tscn`, `windowed_04`, four frames, 1600×900, 60 s | 0 | 4/4, engine exit 0; `phase4_output/capture/windowed_04/` |
| Same capture wrapper for superseded framing runs `windowed_01` through `windowed_03` | 0 each | Each produced 4/4 nonempty 1600×900 frames; only `windowed_04` was frozen for owner review |
| `python tools/audit_orison_v2_completeness.py --json` in final scratch | 2 | Expected incomplete result; `phase4_output/static_final/completeness.json` |
| `python tools/audit_orison_spatial_dependencies.py --json` in final scratch | 0 | Clean; `phase4_output/static_final/spatial_02.json` |
| `python tools/audit_systemic_situation_authority.py --json` in final scratch | 0 | No new actionable/policy finding; `phase4_output/static_final/systemic_02.json` |
| `python tools/audit_data_consumption.py --json` in final scratch | 1 | Expected unchanged baseline debt; `phase4_output/static_final/data_02.json` |
| `python tools/tests/test_orison_v2_completeness.py` | 0 | 91/91 |
| `python tools/tests/test_orison_spatial_dependencies.py` | 0 | 51/51 |
| `python tools/tests/test_systemic_situation_authority.py` | 0 | 34/34 |
| `python tools/tests/test_data_consumption.py` | 0 | 14/14 |

Phase 4 also retained the failed and superseded repair iterations instead of
overwriting them. `objective` and `objective_02` rejected before generating a
receipt; `objective_03` failed 35/37; `objective_04` failed 37/38 and exposed
shutdown retention; `objective_05` and `_06` passed their then-current logical
checks but still emitted shutdown diagnostics; `_07` through `_09` were clean
39/39 runs; `_10` rejected during the next expansion; `_11` and `_12` were
clean 48/48; `_13` and the frozen `_14` were clean 50/50. The per-iteration raw
runner exits were not consolidated, so only the binding `_14` native exit is
asserted numerically above.

## Phase 2 prerequisite table

| Plan dependency | Result | Evidence and qualification |
| --- | --- | --- |
| New `game/data` has a reader or named exception | **YES** | Data audit v2 finds unread files/fields. The standing 1,304 findings remain debt; detection is proven, resolution is not. |
| Persisted numeric fields are not invisible monotonic feedback | **YES, gate proven** | Nested audit exposes `building_stability` and `reality_coherence` as the two standing monotonic-only fields. |
| Element lineage vocabulary covers exterior/service kinds | **YES** | Registry resolves street, apron, arcade, shopfront, B1, and service lineage; street-era jurisdiction remains separate from resident wounds. |
| Street/neighbourhood origin is ruled | **YES** | Shared frame fixes the Orison front-door threshold, outward `+Z`, and metric authority. |
| Shop identifier namespace is ruled | **YES** | Legacy `BODEGA` canonicalizes to `SHOP_BODEGA`. |
| Simulation-tier epoch is ruled | **YES** | Captured campaign epoch crosses midnight independently of host time and reconstructs. |
| Anomaly/space binding frame is ruled | **YES** | Required shared-frame record validates, with independent era/wound accessors. |
| Completeness has an exterior/region axis | **YES** | 150-requirement ledger includes six exterior regions; completeness tests pass 91/91. |
| v2 exterior data has an isolated authoritative home | **YES** | Runtime contract asserts `res://data/orison_v2/`, separate from v1 authorities. |
| Saved dream-module revision reconciliation exists | **YES** | Compatible revision reconstructs; future revision 999 visibly cancels. |
| Floor-residency measurement precedes split choice | **YES** | Seven-floor measurement is recorded in `design/ORISON_V2_ADMIN_PREREQ_1_REPORT_2026-08-30.md`; it was not rerun by the 11-check scene. |

The verification-middleware ablation remains separately pre-registered and
unproven. It was not promoted into rebuild gate authority.

## Zero-geometry rehearsal

The non-landed candidate amendment backticked `F02_B_VESTIBULE` and
`F01_WATCH`, and removed the stale evidentiary use of
`B1_PUBLIC_LANDING_E`. Its evidence-impact run predicted exactly two status
changes:

- `f01.watch_station`: `PROGRAMMED` → `SPATIALLY_PROVEN`
- `unit.2B.entry`: `PROGRAMMED` → `SPATIALLY_PROVEN`

The candidate amendment was not landed merely to improve the ledger.

The synthetic shop bucket passed its nine checks: binding, advance to minute
90, idempotence, serialization, exact reconstruction, backward-time refusal,
missing-bucket refusal, and teardown. The F02/F04 service-opening rehearsal
passed ten checks: exact hall/core records plus a collision-clear void,
collision-bearing adjacent wall, and collision-bearing head at each opening.

The original Phase 3 bucket fixture duplicated its starting defaults in
`RealityState`, assumed the first shop and one hard-coded identity, and did not
load and validate its JSON record at runtime. Its 9/9 result therefore proved
durable mutation and reconstruction, not sole source ownership or cheap Nth
expansion. Phase 4 repaired that weakness in disposable full scratch; the
earlier receipt is not overstated.

No Phase 3 amendment, opening, bucket, geometry, or evidence was committed.
The openings remain `PROGRAMMED` and do not imply complete service routes.

## Synthetic first-cell proof

The frozen objective at `phase4_output/objective_14/` passed 50/50 with zero
failures. Its stderr is empty and its log contains no ObjectDB, retained
resource, or shutdown-leak warning.

The final repair closed five specific seams exposed by earlier iterations:

1. Bucket data moved from validation-only/hard-coded defaults to one
   source-owned generic registry. Two explicit identities seed, advance,
   refuse an invalid sibling atomically, preserve existing save values, and
   reload through the same path.
2. Test-owned spatial save state was replaced by a disposable public semantic
   owner. It serializes identities rather than world coordinates, destroys the
   scene, reloads, resolves, and reconstructs a fresh production player.
3. The bodega metric stopped comparing a candidate to itself. The proof reads
   the protected production layout independently, hashes it, requires unique
   `F01_DOOR_06` and `F01_BODEGA_DOOR` records, applies `GameBoot.b2g`, and
   checks the hinge-origin delta.
4. The second route stopped being resolver-only. The builder enumerates every
   authored route and constructs mesh/collision topology through the same
   templates. The second instance is intentionally hidden from this first-cell
   packet.
5. The Orison landmark stopped bypassing public behavior. It uses the public
   `orison_threshold` surface and a real `DoorProp` hinge.

Externally observable results include:

- one legitimate initial placement, then 26.6572299003601 m and 552 objective
  collision-walk steps through the production `PlayerController`;
- public prompt/acquisition and interaction against the real storefront leaf;
- collision-bearing threshold crossing, shop-floor support, and a public
  `MaintenanceShopService` transaction that preserves `MaintenanceInventory`
  and `WorkOrders` ownership;
- semantic save → complete root destruction → load → same-source rebuild → one
  legitimate reconstruction placement, with no world coordinate in the saved
  spatial payload;
- exact preservation of shop facts, second-shop facts, inventory provenance,
  and job stage;
- independent layout SHA-256
  `68838c933c0954092c63403f36ec7fb26d6c0956c01c23109465c680608b399d`,
  unique reference `F01_DOOR_06` at `[-0.455, -9.795, 0]`, unique target
  `F01_BODEGA_DOOR` at `[18.2, -11.92, 0]`, and derived
  `door_marker_hinge_origin_delta` `[18.655, 0, 2.125]`;
- zero retained external audio-policy voices after teardown.

Bounded structural costs were:

| Instance | Nodes | Meshes | Collision objects |
| --- | ---: | ---: | ---: |
| Primary shop | 74 | 32 | 18 |
| Second shop | 73 | 32 | 18 |
| Primary street | 32 | 12 | 8 |
| Second street | 13 | 4 | 4 |

The second shop and route prove generic construction and equal/bounded cost;
they were deliberately not shown as human evidence for the first cell.

## Frozen human packet

`phase4_output/capture/windowed_04/capture_receipt.json` records 4/4 nonempty
frames at 1600×900, wrapper and engine exit 0, 12.628 seconds wrapper elapsed,
and 11.040 seconds inside Godot. All views use the production
`PlayerController` camera. Capture recorded one initial placement, 602 total
walk steps, and zero later teleports.

| Frame | Bytes | SHA-256 | Human question |
| --- | ---: | --- | --- |
| `01_orison_side_route_to_bodega.png` | 54,503 | `049a8503bec133cec5fc90251f4c7b31900e1dc9a489432122c72a31f669bbba` | Where does the pavement route begin on the Orison side? |
| `02_bodega_threshold_approach.png` | 163,369 | `357c257a06ed7371f1fe9d26896bea70c6e9d3409774f650fade727b064dd0d5` | Which opening is the bodega entrance and threshold? |
| `03_inside_bodega_context.png` | 188,914 | `da9cea0b6afbb8ad38c601dbfe6fff44f926d40ba62f793a333e0c9ed3226e77` | Where does the route continue inside the shop? |
| `04_return_route_to_orison.png` | 62,865 | `f668f954bc2d509779f5f3dbef98e99fa09553640884167cd44cbda36c7fcdae` | Which direction returns toward Orison? |

The owner answered the packet with “Human accepted.” That is a manual PASS for
these four questions and this visible cell, not for the unseen second instance,
the complete exterior, the complete building, or final art.

## Before/after protected controls

The final comparator checked 17 protected files in both the disposable scratch
root and the integration root: 34 comparisons, zero mismatches.

| Protected path | Before SHA-256 | After SHA-256 |
| --- | --- | --- |
| `game/data/building_layout.json` | `68838c933c0954092c63403f36ec7fb26d6c0956c01c23109465c680608b399d` | same |
| `art/data/building_layout.json` | `68838c933c0954092c63403f36ec7fb26d6c0956c01c23109465c680608b399d` | same |
| `game/scripts/building/building_root_selector.gd` | `d2b3db95d72e4a418c0e7184e6b3368da723a945192024a10ee937ea604c9802` | same; `DEFAULT_ID := "v1"` |
| `game/assets/building/floor_01.bin` | `e1d3454afb6079602b8cfe0dcb00d255e6aa68f7f247c5ecc39bd5791cfdc477` | same |
| `game/assets/building/floor_01.gltf` | `906f1f48c2fc8ff6e6af3048d0abca46416cd103bee8d818606a3c32c71fe5b1` | same |
| `game/assets/building/floor_02.bin` | `4b7d16ae8ed7df4a90f0626746ca5987bd02c61268f372fced86a3782760b69e` | same |
| `game/assets/building/floor_02.gltf` | `b3977546cabc72775ad63be53bfb2001ace51d13094b4ed8b719a979adc2d640` | same |
| `game/assets/building/floor_03.bin` | `8f84cb67f5f2fa8f2c5a5e47fbc418630957dbc8d6a96576e005c92ac6fcc9f8` | same |
| `game/assets/building/floor_03.gltf` | `21c506695edf27effa20c711f1daed939c807a774f5076656e8ff3e8be898d3f` | same |
| `game/assets/building/floor_04.bin` | `f57f45d79738086a5da23afd7d9a04d6f5596641193ec22856929de30b03e266` | same |
| `game/assets/building/floor_04.gltf` | `c1a03abba15f481e6318e27d5035dae13e3e5173f16c2f208711769ce3bf8df1` | same |
| `game/assets/building/floor_05.bin` | `a8e7f0fd106696a1c6c9823f30cf013b0f664e4dac5d763fc2c3d2c072dd54d8` | same |
| `game/assets/building/floor_05.gltf` | `d5860b28c47a110fcced5b8cd22c0f5d4ae0fc036dfc0d44fbe884a2def41e7a` | same |
| `game/assets/building/floor_06.bin` | `8389d2264ea4c6e4eb59fb35b58d7480b3823641c1471b593a85613883bd9f5f` | same |
| `game/assets/building/floor_06.gltf` | `96991ecf897b7882c68897eb9c8df5a678046e1567e8f59d51f21f6646209422` | same |
| `game/assets/building/floor_b1.bin` | `226437a3e2816882c04749918a4d99540ff2a4714d0a914b2dd2606ace8c4449` | same |
| `game/assets/building/floor_b1.gltf` | `f151ff10c8d2420340fc522df5e9eb2ffbdf200be6068b302c6769881af8eb3e` | same |

## Ledger and final audit comparison

The “after” column is the disposable full-scratch ledger, not a durable
production promotion.

| Measure | Before | Final scratch |
| --- | ---: | ---: |
| Requirements | 150 | 150 |
| `ABSENT` | 52 | 52 |
| `HUMAN_ACCEPTED` | 1 | 1 |
| `PROGRAMMED` | 42 | 41 |
| `RUNTIME_PROVEN` | 34 | 34 |
| `SHELL_ONLY` | 3 | 2 |
| `SPATIALLY_PROVEN` | 18 | 20 |
| First-slice technical blockers | 0 | 0 |
| Golden-shift v2 blockers | 1 | 1 |
| Full-building structural blockers | 86 | 84 |
| Full-building runtime blockers | 45 | 45 |
| Production-cutover blockers | 101 | 100 |
| V1-retirement blockers | 103 | 102 |
| V1 fallbacks | 7 | 7 |
| Heuristic conclusions | 27 | 27 |
| Anchor-only findings | 0 | 0 |
| Stale checkpoint IDs | 1 | 0 |

Final static disposition:

- Spatial: exit 0, `clean`, 3,640 records, zero new failing, class-change,
  vanished-target, or unresolved-save finding. Fourteen newly reported records
  were classified as shared-frame/test/metric provenance, not hidden drift.
- Systemic: exit 0, 57 findings, zero new actionable or policy violation. Its
  JSON is byte-identical to baseline, SHA-256
  `5186e322b55bfecdf9033c903c7ad2bfe77e2f3fa1db489c90a50480c8d5367b`.
- Data: expected exit 1, the same 1,304 known findings: 1,290
  `FIELD_UNREAD`, 11 `FILE_UNREAD`, one `MALFORMED`, and two
  `DURABLE_NUMERIC_MONOTONIC_ONLY`. Its JSON is byte-identical to baseline,
  SHA-256
  `4704a4a82650beea2e35f69e54e4e1949f590d763dd2da7e6da6b05d12841ad1`.
- Completeness: expected exit 2. It is evidence that the full rebuild remains
  incomplete, not a completeness pass.

## Remaining prerequisites and limitations

These items do not block the first bounded landing, but they remain binding for
their later scopes:

- The second/Nth shop and route prove generic topology and bounded cost but
  were intentionally hidden and did not receive human visual review.
- Both synthetic instances use yaw 0. A nonzero-yaw instance must be proven
  before the disposable renderer can be adopted as a general production seam;
  the first landing should either avoid that claim or include the rotated proof.
- The candidate builder, semantic spatial adapter, fixtures, and repair scripts
  are disposable proof material, not automatically production architecture.
- The clean audio teardown in the fixture reaches pooled voice nodes by name.
  That is test-only. Production composition needs a public deterministic
  teardown surface rather than that node-name reach-in.
- The packet proves gray-box route readability, not final art, whole-exterior
  navigation, whole-building navigation, GPU performance, full boot/selector
  composition, or cutover readiness.
- The independent metric check reads the pinned production layout as test
  provenance. A production v2 runtime resolver must remain independent of v1
  layout ownership.
- The repository-wide 1,304 data-consumption findings and the completeness
  counts above remain honest debt. They block the scopes named by their audits,
  not this first bounded landing.
- The recorded Phase 1–4 command metadata lacks a consolidated byte-exact argv
  transcript. Future rehearsals should emit one machine-readable command/exit
  manifest at invocation time.
- The floor-residency measurement was referenced from the dated admin report,
  not remeasured during this run.
- Verification-middleware ablation remains pre-registered future work and has
  no gate authority yet.

## Authorized landing boundary

The next production change may be proposed only as a bounded, reviewable port
for the first street/bodega/exterior-route cell. It must retain source-owned
durable data, public surface/placement resolution, semantic save state without
raw world coordinates, existing gameplay owners, deterministic public teardown,
and the v1 protected hashes/default verified above. It must add rotated-instance
proof if it generalizes the renderer beyond yaw 0.

The following remain forbidden by this report: changing
`BuildingRootSelector.DEFAULT_ID`, beginning M09, redirecting production runtime
ownership, replacing either production layout, regenerating protected floor
assets, retiring v1, treating the disposable packet as building-wide evidence,
or applying the candidate generator across the building.

**Final decision: AUTHORIZE THE FIRST BOUNDED V2 BUILD LANDING.**
