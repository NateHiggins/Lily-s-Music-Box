# Orison v2 M11C0 disposable floor-01 cut validation receipt — 2026-08-31

Evidence class: **DISPOSABLE REHEARSAL RECEIPT — NO PRODUCTION EVIDENCE**

## Scope and authority

This receipt records a read-only census and an external disposable cut of the
protected **floor_01.gltf/.bin**. The rehearsal was run from
**a9e455bfede9f89193c9acd0796eb8fc5a0c3548** on branch
**codex/orison-v2-m11c0-floor01-cut-rehearsal**, whose requested M11B merge
base is **0ea23bfd1296a3779773886b1fc062f10288fa23**.

The final disposable output was written outside the repository at
**C:\PleaseRemainOnTheLine-v2-m11c0-output-20260831\cut_06**. No production
layout, floor asset, selector, runtime scene, project setting, or historical
evidence was written. The committed selector remains **v1**.

This receipt does not authorize production mutation. It tests whether a
source-owned production partition can be defended and whether the current
monolithic export can be split and recomposed without inventing ownership.

## Deterministic source census

The source-layout census classifies **5,286/5,286** records exactly once into
a proposed **17-cell** target partition. It found **608** records without
durable source identities: **42 walls, 565 site lights, and one slab**. The
rehearsal gives those records canonical content hashes for comparison only;
those hashes are not gameplay, save, or future production identities.

The protected export contains:

| Property | Value |
| --- | ---: |
| GLTF / BIN bytes | 682,906 / 12,020,428 |
| Nodes / meshes / primitives | 531 / 531 / 531 |
| Accessors / buffer views | 1,740 / 1,740 |
| Materials / textures / images | 104 / 304 / 304 |
| Referenced vertices / triangles | 345,536 / 183,726 |
| Collision-tagged nodes | 380 |

Only **397** protected primitives can be attributed to a target cell from
their exported lineage. The remaining **134** are lineage-unresolved legacy
material/procedural primitives. Specific furniture, material, wear, and wall
families among them are demonstrated cross-owner; the census does not assume
that every member is cross-owner. Centroid, bounds, connected-component, and
triangle-position assignment were deliberately refused.

## Target partition and safe-current rehearsal

The smallest defensible target partition is:

1. **CELL_ORISON_F01_INTERIOR**;
2. **CELL_ORISON_FACADE_SHELL**;
3. **CELL_SITE_STREET_COMMON**;
4. **CELL_PASSAGE**;
5. **CELL_SHOP_BAR**;
6. **CELL_SHOP_BODEGA**; and
7. eleven independently owned Passage shops.

The facade is a shared residency dependency with one geometry owner. Orison
residency is interior plus facade; exterior residency is street plus facade.
A geometry-free **F01_COMPOSITION_HOST** must retain gameplay and service
ownership above those residency sets.

The current export supports only this exact whole-node disposable split:

| Safe-current cell | Nodes | GLTF bytes | BIN bytes | Collision-tagged nodes |
| --- | ---: | ---: | ---: | ---: |
| CELL_LEGACY_MIXED | 134 | 278,793 | 9,377,348 | 43 |
| CELL_SITE_STREET_DEDICATED | 8 | 19,428 | 22,320 | 8 |
| CELL_PASSAGE_PORTAL_PROXY | 12 | 25,898 | 303,008 | 11 |
| CELL_PASSAGE_SHELL | 20 | 45,929 | 733,024 | 15 |
| CELL_SHOP_BAR | 31 | 72,982 | 155,160 | 31 |
| CELL_SHOP_BODEGA | 16 | 38,082 | 125,232 | 16 |
| CELL_SHOP_MODEL_LAUNDRY | 32 | 73,955 | 155,996 | 23 |
| CELL_SHOP_SHOE_REBUILDING | 20 | 47,883 | 85,008 | 20 |
| CELL_SHOP_KEYS_CUT | 20 | 47,803 | 151,296 | 20 |
| CELL_SHOP_HARDWARE_PAINT | 21 | 50,920 | 186,360 | 21 |
| CELL_SHOP_FUNERAL_PARLOUR | 23 | 54,381 | 94,512 | 23 |
| CELL_SHOP_PHOTO_SUPPLIES | 34 | 77,481 | 120,716 | 25 |
| CELL_SHOP_RADIO_SERVICE | 35 | 78,837 | 101,948 | 26 |
| CELL_SHOP_PAWNBROKER | 34 | 77,033 | 121,964 | 25 |
| CELL_SHOP_NEWS_CIGARS | 27 | 61,501 | 89,516 | 18 |
| CELL_SHOP_OTIS_SON | 30 | 70,568 | 150,480 | 30 |
| CELL_SHOP_LUNCHEONETTE | 34 | 77,481 | 138,064 | 25 |

Every cell imports independently. The split assigns **531/531** nodes and
**531/531** primitives exactly once with no duplicates or omissions. Canonical
node names, transforms, world bounds, materials, attributes, index streams,
and buffer payloads match the protected monolith. Primitive and node-name
multiset hashes match, and the recomposition receipt is **PASS**.

The descriptor-plus-BIN source is **12,703,334 bytes**. The cell descriptors
and BINs total **13,310,907 bytes**. Measured contributors to that overhead
include **156 extra accessor records**, **367 extra material records**,
repeated texture/image descriptors, 17 sampler records, per-cell scene/asset
metadata, and buffer payload/alignment effects. All **304** texture files,
totaling **208,081,567 bytes**, are shared once rather than copied per cell.

This is not the target partition: **CELL_LEGACY_MIXED** still carries the
lineage-unresolved remainder, including demonstrated Orison/facade/site
cross-owner batches, so Orison interior and the exterior cannot be
independently resident.

## Runtime recomposition and seam observations

The disposable Forward+ Godot harness imports the protected monolith and all
17 safe-current cells through public configuration. It uses
**M11C0CellComposition.public_teardown()**, never reaches into child nodes by
name, never force-deletes an Object, and clears every strong scene,
**PackedScene**, query, space-state, and world reference it creates.

| Runtime property | Original | Recomposed |
| --- | ---: | ---: |
| Scene nodes | 1,283 | 1,300 |
| Mesh instances / primitives | 522 / 522 | 522 / 522 |
| Estimated render primitives | 182,610 | 182,610 |
| Collision objects / shapes | 380 / 380 | 380 / 380 |
| World bounds | [-112, -2.9, -66] to [108, 53.585228, 102.2] | identical |

The 17 additional nodes are the expected disposable cell roots, not geometry.
Eight original/recomposed rays have the same hit/clear result, collider class,
and contact position at the Orison/street, street/Passage, Passage/shop, and
bodega/street inspection boundaries. That is exact safe-current collision
recomposition evidence, not target-cell ownership proof. In particular, the
ray named **passage_aisle_west** first contacts collision owned by the
shoe-rebuilding cell at elevation **0.55 m** on both versions; it therefore
cannot prove that the future Passage owner supplies the aisle contact. The
facade-shell/interior seam is also **UNPROVEN** because those owners do not yet
exist as independent export cells. None of these vertical contact rays proves
bidirectional PlayerController or navigation continuity across a future cut.

The first warmed cycle reports an interim **+1 Object** from the harness's
active GDScript await state. The final count is taken at a deferred,
non-coroutine boundary after that instrumentation state releases. The second
warmed cycle adds **0 objects, 0 resources, 0 nodes, and 0 orphans**. Final
counts relative to the warmed baseline are **-6 objects, 0 resources, 0
nodes, and 0 orphans**. There are no retained tracked rehearsal owners and no
ObjectDB/resource shutdown warning.

## Timing and cost context

These are uncached/headless resource timings in a disposable Forward+ project,
not production streaming or gameplay performance:

| Warmed cycle | Original load / instantiate | Recomposed load / instantiate | Sum of 17 independent loads / instantiates | Legacy-mixed load / instantiate |
| --- | ---: | ---: | ---: | ---: |
| 1 | 2,356.628 / 14.780 ms | 2,348.914 / 14.717 ms | 11,329.751 / 14.676 ms | 2,043.282 / 5.445 ms |
| 2 | 2,334.087 / 14.287 ms | 2,337.143 / 14.502 ms | 11,216.678 / 14.198 ms | 2,016.024 / 5.132 ms |

The sum of 17 independent loads intentionally measures every resource from a
cold per-cell release boundary. It is not a proposed production load schedule.
CPU frame time and VRAM were not measured trustworthily and are not inferred.

## Dangerous-seam visual packet

The immutable packet at
**art/renders/orison_v2/m11c0_floor01_cut_rehearsal_01/** contains matched
original/recomposed views rendered at **1600×900 Forward+** with one harness
camera and no harness geometry, lights, environment, labels, or arrows:

1. [Orison shell/street — original](../art/renders/orison_v2/m11c0_floor01_cut_rehearsal_01/01_orison_shell_street_original.png) and [recomposed](../art/renders/orison_v2/m11c0_floor01_cut_rehearsal_01/01_orison_shell_street_recomposed.png);
2. [street/Passage portal — original](../art/renders/orison_v2/m11c0_floor01_cut_rehearsal_01/02_street_passage_portal_original.png) and [recomposed](../art/renders/orison_v2/m11c0_floor01_cut_rehearsal_01/02_street_passage_portal_recomposed.png);
3. [Passage/shop aisle — original](../art/renders/orison_v2/m11c0_floor01_cut_rehearsal_01/03_passage_west_shop_aisle_original.png) and [recomposed](../art/renders/orison_v2/m11c0_floor01_cut_rehearsal_01/03_passage_west_shop_aisle_recomposed.png); and
4. [bodega/street threshold — original](../art/renders/orison_v2/m11c0_floor01_cut_rehearsal_01/04_bodega_street_threshold_original.png) and [recomposed](../art/renders/orison_v2/m11c0_floor01_cut_rehearsal_01/04_bodega_street_threshold_recomposed.png).

The first three pairs are byte-identical. The bodega pair differs at exactly
**20 of 1,440,000 pixels (0.0013889%)**, with maximum normalized channel
difference **0.1529412** and mean absolute channel difference
**0.0000009023**. Geometry, bounds, draw count, visible primitives, and the
eight recorded contact signatures are equal; the measured image difference is consistent
with an order-sensitive coincident-surface raster result, but is not relabeled
as byte identity.

| View | Draw calls original/recomposed | Visible primitives | GPU ms original/recomposed |
| --- | ---: | ---: | ---: |
| Orison shell/street | 142 / 142 | 141,148 | 0.190 / 0.194 |
| Street/Passage portal | 427 / 427 | 110,208 | 0.188 / 0.163 |
| Passage/shop aisle | 196 / 196 | 94,626 | 0.187 / 0.197 |
| Bodega/street threshold | 102 / 102 | 89,506 | 0.165 / 0.194 |

## Validation exits

The final validation used these exact invocations from the M11C0 worktree
(PowerShell environment assignments on a line apply to the command that
follows):

```powershell
python tools/tests/test_orison_floor01_source_ownership.py
python tools/tests/test_rehearse_orison_floor01_partition.py
python tools/tests/test_m11c0_floor01_harness_contract.py
python tools/audit_orison_floor01_source_ownership.py
python -c 'import hashlib,json,subprocess; d=json.loads(subprocess.check_output(["python","tools/audit_orison_floor01_source_ownership.py","--json"], text=True)); b=json.dumps(d["partition"]["assignments"], sort_keys=True, separators=(",",":"), ensure_ascii=False).encode(); h=hashlib.sha256(b).hexdigest(); print("rows=%d bytes=%d sha256=%s"%(len(d["partition"]["assignments"]),len(b),h)); assert len(b)==1737062 and h=="4f758413b49680bd43d7a9e1804366a0dd14dc37ad5bca1874fa0c6abeecffb6"'
python tools/rehearse_orison_floor01_partition.py --manifest design/ORISON_V2_M11C0_FLOOR01_PARTITION_MANIFEST_2026-08-31.json --output C:\PleaseRemainOnTheLine-v2-m11c0-output-20260831\cut_06
Godot_v4.7.1-stable_win64_console.exe --headless --editor --path C:\PleaseRemainOnTheLine-v2-m11c0-output-20260831\cut_06 --quit
$env:M11C0_MODE='runtime'; $env:M11C0_CONFIG='res://split_receipt.json'; $env:M11C0_MANIFEST='res://partition_manifest.json'; $env:M11C0_RUNTIME_RECEIPT='C:\PleaseRemainOnTheLine-v2-m11c0-output-20260831\cut_06\receipts\runtime_validation_receipt.json'; $log='C:\PleaseRemainOnTheLine-v2-m11c0-output-20260831\cut_06\receipts\runtime_process_stdout.log'; powershell -ExecutionPolicy Bypass -File tools/run_godot_serial.ps1 -Scene res://harness_main.tscn -ProjectPath C:\PleaseRemainOnTheLine-v2-m11c0-output-20260831\cut_06 -LogPath $log -TimeoutSeconds 60
$env:M11C0_MODE='capture'; $env:M11C0_CONFIG='res://split_receipt.json'; $env:M11C0_MANIFEST='res://partition_manifest.json'; $env:M11C0_CAPTURE_DIR='C:\PleaseRemainOnTheLine-v2-m11c0-output-20260831\cut_06\captures\attempt_10'; $env:M11C0_CAPTURE_RECEIPT='C:\PleaseRemainOnTheLine-v2-m11c0-output-20260831\cut_06\captures\attempt_10\matched_capture_receipt.json'; pwsh -NoProfile -File tools/run_godot_capture.ps1 -Scene res://harness_main.tscn -ShotRoot C:\PleaseRemainOnTheLine-v2-m11c0-output-20260831\cut_06\captures -RunName attempt_10 -ExpectedFrames 8 -ProjectPath C:\PleaseRemainOnTheLine-v2-m11c0-output-20260831\cut_06 -Resolution 1600x900 -TimeoutSeconds 60
python tools/tests/test_orison_v2_completeness.py
python tools/tests/test_orison_spatial_dependencies.py
python tools/tests/test_systemic_situation_authority.py
python tools/tests/test_data_consumption.py
python tools/audit_orison_v2_completeness.py
python tools/audit_orison_spatial_dependencies.py
python tools/audit_systemic_situation_authority.py
python tools/audit_data_consumption.py
python tools/audit_orison_v2_completeness.py --evidence-impact design/ORISON_V2_M11C0_FLOOR01_CUT_REHEARSAL_CHECKPOINT_2026-08-31.md
python tools/audit_orison_v2_completeness.py --evidence-impact design/ORISON_V2_M11C0_DISPOSABLE_CUT_VALIDATION_RECEIPT_2026-08-31.md
python -m py_compile tools/audit_orison_floor01_source_ownership.py tools/rehearse_orison_floor01_partition.py tools/tests/test_orison_floor01_source_ownership.py tools/tests/test_rehearse_orison_floor01_partition.py tools/tests/test_m11c0_floor01_harness_contract.py
ruff.exe check tools/audit_orison_floor01_source_ownership.py tools/rehearse_orison_floor01_partition.py tools/tests/test_orison_floor01_source_ownership.py tools/tests/test_rehearse_orison_floor01_partition.py tools/tests/test_m11c0_floor01_harness_contract.py
$selector = @(Select-String -LiteralPath game/scripts/building/building_root_selector.gd -Pattern '^const DEFAULT_ID\s*:?=\s*"v1"'); if ($selector.Count -ne 1) { exit 1 }
$protected = Get-Content -Raw design/ORISON_V2_M11C0_PROTECTED_FINAL_RECEIPT_2026-08-31.json | ConvertFrom-Json; foreach ($file in $protected.files) { if ((Get-FileHash -Algorithm SHA256 -LiteralPath $file.path).Hash.ToLowerInvariant() -ne $file.final_sha256) { exit 1 } }; if (-not $protected.all_match -or $protected.selector_default -ne 'v1') { exit 1 }
$source_manifest = Get-Content -Raw design/ORISON_V2_M11C0_FLOOR01_PARTITION_MANIFEST_2026-08-31.json | ConvertFrom-Json; $materialized_manifest = Get-Content -Raw C:\PleaseRemainOnTheLine-v2-m11c0-output-20260831\cut_06\partition_manifest.json | ConvertFrom-Json; $split_receipt = Get-Content -Raw C:\PleaseRemainOnTheLine-v2-m11c0-output-20260831\cut_06\split_receipt.json | ConvertFrom-Json; if (($source_manifest | ConvertTo-Json -Depth 100 -Compress) -cne ($materialized_manifest | ConvertTo-Json -Depth 100 -Compress) -or $split_receipt.input_manifest_sha256 -ne (Get-FileHash -Algorithm SHA256 design/ORISON_V2_M11C0_FLOOR01_PARTITION_MANIFEST_2026-08-31.json).Hash.ToLowerInvariant()) { exit 1 }
$runtime_process = Get-Content -Raw art/renders/orison_v2/m11c0_floor01_cut_rehearsal_01/runtime_process_receipt.json | ConvertFrom-Json; if ($runtime_process.engine_exit -ne 0 -or $runtime_process.warning_scan.objectdb_or_instance_leak_matches -ne 0 -or $runtime_process.warning_scan.resource_leak_matches -ne 0 -or $runtime_process.warning_scan.error_line_matches -ne 0 -or $runtime_process.warning_scan.warning_line_matches -ne 0) { exit 1 }; if ((Get-FileHash -Algorithm SHA256 C:\PleaseRemainOnTheLine-v2-m11c0-output-20260831\cut_06\receipts\runtime_process_stdout.log).Hash.ToLowerInvariant() -ne $runtime_process.stdout.external_raw_sha256) { exit 1 }
$packet_root = 'art/renders/orison_v2/m11c0_floor01_cut_rehearsal_01'; $packet = Get-Content -Raw "$packet_root/committed_packet_receipt.json" | ConvertFrom-Json; foreach ($file in $packet.files) { $stage = @(git ls-files --stage -- "$packet_root/$($file.path)"); if ($stage.Count -ne 1 -or (($stage[0] -split '\s+')[1]) -ne $file.git_blob) { exit 1 } }
```

| Command or check | Exit | Result |
| --- | ---: | --- |
| floor-01 source-ownership focused suite | 0 | 13/13 PASS |
| disposable splitter focused suite | 0 | 5/5 PASS |
| disposable Godot harness contract suite | 0 | 5/5 PASS |
| source-ownership audit | 0 | PASS; 5,286 records exact once |
| source assignment digest | 0 | 5,286 ordered rows; 1,737,062 canonical bytes; SHA-256 matches compact receipt |
| disposable materialized split | 0 | PASS; 531/531 whole primitives exact once |
| source/materialized manifest binding | 0 | exact semantic equality; splitter input hash matches committed source manifest |
| disposable Godot import | 0 | all original/cell GLTF resources imported |
| disposable runtime harness | 0 | PASS_WITH_UNPROVEN_SEAMS; shell/interior explicitly unproven |
| runtime process/log verification | 0 | engine exit 0; zero ObjectDB/resource/error/warning matches; external stdout hash matches |
| disposable capture harness | 0 | 8/8 files, exact 1600×900 Forward+ |
| completeness static suite | 0 | 99/99 PASS |
| spatial static suite | 0 | 51/51 PASS |
| systemic-authority static suite | 0 | 34/34 PASS |
| data-consumption static suite | 0 | 14/14 PASS |
| completeness audit | 2 | unchanged 150-row incomplete ledger; zero intended movement |
| spatial audit | 0 | unchanged 3,684 records; no new drift |
| systemic-authority audit | 0 | unchanged 59 findings; no new violation |
| data-consumption audit | 1 | unchanged reviewed debt: 1,289 fields, 11 files, 2 monotonic-only values, 1 malformed record |
| selector assertion | 0 | DEFAULT_ID remains v1 |
| protected-hash comparison | 0 | 17/17 protected files match |
| checkpoint evidence-impact | 0 | requirements_changed = [] |
| validation-receipt evidence-impact | 0 | requirements_changed = [] |
| Python compile / Ruff | 0 / 0 | all five new Python files compile and lint cleanly |
| committed packet blob verification | 0 | all 21 listed artifacts match their Git-normalized blob identities |

The machine-readable source census, protected-GLTF census, assignment,
measurements, recomposition, runtime, capture, and process receipts are stored
beside the images. **partition_binding_receipt.json** proves the committed
source manifest and materialized manifest are semantically identical and that
the splitter consumed the committed source hash. **runtime_process_receipt.json**
binds the exit code, stdout/stderr hashes, warning scan, and runtime receipt.
**committed_packet_receipt.json** maps every external-run artifact to its
durable repository-relative copy and Git-normalized blob hash. The final 17-path
comparison is independently recorded in
**design/ORISON_V2_M11C0_PROTECTED_FINAL_RECEIPT_2026-08-31.json**. The
repository-wide nonzero audit exits are reported as reviewed pre-existing
debt, not converted to PASS and not baselined.

## Production refusal boundary

A real cut remains unsafe until the source exporter:

- gives every anonymous source record a durable identity and explicit owner;
- batches by **owner_cell before material**;
- resolves all 134 lineage-unresolved primitives into the 17 target cells;
- proves the independent Orison, facade, street, Passage, and shop residency
  sets rather than retaining a legacy-mixed dependency;
- adapts every identified monolithic runtime consumer while leaving the M11A
  exterior composition independent;
- proves unique semantic owners and compatibility aliases under those target
  cells; and
- proves collision and navigation continuity at the actual facade/interior and
  other named boundaries.

Decision: **REVISE THE PARTITION BEFORE PRODUCTION MUTATION.**
