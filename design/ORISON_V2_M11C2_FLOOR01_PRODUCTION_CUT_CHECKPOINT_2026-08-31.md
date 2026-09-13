# Orison v2 M11C2 floor-01 production cut checkpoint — 2026-08-31

Evidence class: **TECHNICAL CHECKPOINT — FINAL RECEIPTS BOUND 2026-09-13 — HUMAN REVIEW PENDING**

## Disposition

M11C2 is the authorized production implementation of the owner-first floor-01
cut rehearsed by M11C0 and M11C1. It replaces the production v1
**BuildingRoot** floor-01 geometry load with the reviewed 17-cell export while
preserving a geometry-free **F01** composition host for gameplay and durable
authority. The protected monolith remains a byte-identical rollback input and
may be selected only through a bounded session/test configuration.

The draft of 2026-08-31 left every receipt table PENDING although the frozen
receipts said PASS. This close (task ORISON-V2-M11C2-CLOSE, 2026-09-13) bound
those receipts, fixed the four findings interim management raised, re-ran the
production matrix after the fix, and transcribes the numbers below from the
receipt files. Human review remains **PENDING** and cannot be inferred from a
passing capture.

The production building selector remains **v1**. M11C2 does not authorize M09,
selector cutover, v1 retirement, deletion of the rollback monolith, production
layout replacement, unrelated floor export, speculative streaming, new
gameplay/save authority, or a merge to main.

## Authorization, branch, and commit boundary

- Authorized base: **503465defa24d19d55b53c9a17bf8a4affdfb5eb**.
- Branch: **codex/orison-v2-m11c2-real-floor01-cut**.
- Recorded **origin/main** and merge base before writes:
  **c2dc01771bc25b07f5dcf7a6040102345b8c57d5**; unchanged at close.
- Pre-write worktree: clean. Baseline receipt: **4480a79**.
- Selector before writes and at close: **v1**.
- Production F01 geometry mode after the cut: **owner_first_cells**.
- Rollback F01 geometry mode: **legacy_monolith**, available only through
  explicit session/test injection.
- Production asset/export commit: **46d40e9** (Export owner-first floor01
  production cells, 2026-08-31).
- Production consumer/registry commit: **3ef15f5**.
- Objective proof and evidence commit: **dbdb762**.
- Inert checkpoint/receipt commit: **the commit that lands this document** (its hash cannot be written into itself).

Staging was by named path only; **git diff --cached --name-only** was read
before each commit. No **git add -A** staging was used.

### What the close changed, and why

1. **Godot churn restored.** 135 texture and dream-surface import files that
   Godot had rewritten with different line endings were restored with
   **git checkout**; every one was whitespace-only. Seven minted script-uid
   files were checked against **origin/main** with **git cat-file -e**: none
   exist upstream, and each pairs with a script that is new on this chain, so
   all seven are committed.
2. **Prompt carrier.** The M11A rewrite of the hardware counter prompt had
   produced a legacy carrier literal outside the 186-entry baseline. The prop
   now returns semantic action text (Inspect followed by the surface label)
   and the controller supplies the device carrier, per T2 of the interaction
   contract. The baseline was not extended; its old entry is reported by the
   audit as a cleanup opportunity. The carrier suite is now in the standard
   battery below.
3. **Boot cost.** The registry parsed the 15.7 MB owner lineage at every
   boot to read three header fields. It now binds the lineage by SHA-256
   only; no production reader consumes a lineage field (a repository-wide
   search for the lineage file name finds only the registry, the exporter,
   the export test and the spatial manifest). Configure and mount are now
   timed phase by phase in both modes; numbers below.
4. **Lineage placement.** The production lineage moved from the Godot asset
   root to **art/data/m11c2/floor01_owner_first_lineage.json** beside the
   M11C1 ownership sidecar. Its SHA-256 stays in the asset manifest; the
   registry's expected path and the exporter's allowlist follow it; the
   export was regenerated and byte-checked. The M11C1 packet is untouched.
5. **Line-ending binding (found during the close).** The repository runs
   with core.autocrlf=true and had no attributes file. A conversion-applying
   checkout of the committed cell GLTF rewrote it with 7,487 carriage returns
   and a different SHA-256 than the manifest binds, so any fresh Windows
   checkout would have failed the registry at boot. A scoped
   **.gitattributes** now marks the cell asset root, the registry JSON and the
   lineage sidecar as never-normalized; the same conversion test now
   reproduces the index bytes exactly.

## Expected completeness movement

The expected ledger movement is exactly zero requirements and zero promotions.
This is an architectural production cut of already authored and rehearsed
floor-01 content, not evidence that newly authored building space exists.

The pre-write completeness ledger contains 150 requirements:
**ABSENT 51, HUMAN_ACCEPTED 1, PROGRAMMED 44, RUNTIME_PROVEN 34,
SHELL_ONLY 2, and SPATIALLY_PROVEN 18**. Its blocker scopes are
**0 / 1 / 86 / 45 / 101 / 103**.

Final ledger counts: **ABSENT 51, HUMAN_ACCEPTED 1, PROGRAMMED 44, RUNTIME_PROVEN 34, SHELL_ONLY 2, SPATIALLY_PROVEN 18** (exit 2).

Final blocker scopes: **0 / 1 / 86 / 45 / 101 / 103**.

Evidence-impact receipt for this document: exit 0, requirements_changed = [].

## Deterministic production export

The production export path consumes the reviewed authoritative ownership
registry from M11C1 and batches generated contributions by **owner_cell**
before material. It does not maintain a second hand-edited ownership map. The
export preserves source identity, owner, emission kind, material, collision
class, source/primitive/triangle lineage, compatibility identity, and the
Godot **-col** / **-colonly** importer contracts.

The production cell set is exactly:

1. **CELL_ORISON_F01_INTERIOR**;
2. **CELL_ORISON_FACADE_SHELL**;
3. **CELL_SITE_STREET_COMMON**;
4. **CELL_PASSAGE**;
5. **CELL_SHOP_BAR**;
6. **CELL_SHOP_BODEGA**;
7. **CELL_SHOP_MODEL_LAUNDRY**;
8. **CELL_SHOP_SHOE_REBUILDING**;
9. **CELL_SHOP_KEYS_CUT**;
10. **CELL_SHOP_HARDWARE_PAINT**;
11. **CELL_SHOP_FUNERAL_PARLOUR**;
12. **CELL_SHOP_PHOTO_SUPPLIES**;
13. **CELL_SHOP_RADIO_SERVICE**;
14. **CELL_SHOP_PAWNBROKER**;
15. **CELL_SHOP_NEWS_CIGARS**;
16. **CELL_SHOP_OTIS_SON**;
17. **CELL_SHOP_LUNCHEONETTE**.

The checked-in production manifests bind **5,286 authoritative source
records**, **9,820 generated contributions**, **183,726 triangles**,
**609 output primitives**, **189 semantic owners**, and
**531 compatibility aliases** to those 17 assets. Unresolved lineage
records: **0**. **CELL_LEGACY_MIXED** present: **no**.

The generated assets and machine authorities live at:

- **game/assets/building/floor_01_cells/** — 17 GLTF/BIN pairs plus the asset
  and compatibility-alias manifests;
- **art/data/m11c2/floor01_owner_first_lineage.json** — the owner-lineage
  sidecar, hash-bound through the asset manifest, never parsed at boot;
- **game/data/floor_01_cell_registry.json** — the production cell and
  residency authority;
- **tools/m11c2_floor01_production/export_floor01_cells.py** — the deterministic
  clean-checkout export/check path; and
- **art/data/m11c1/floor01_source_ownership.json** — the reviewed source-owned
  input shared with M11C1 rather than duplicated for the production cut.

### Regeneration receipt

Two independent Blender generations ran on 2026-09-13 through the exporter,
each from a fresh temporary export root against the protected inputs:

| Run | Mode | Generation run id | Blender exit | Artifacts | Operation | Protected unchanged |
| --- | --- | --- | ---: | ---: | --- | --- |
| write | write | M11C1-0b0f7d4a4d12c3379bd0bf2e | 0 | 38 | changed 3: floor01_owner_first_lineage.json, floor01_asset_manifest.json, floor_01_cell_registry.json | yes |
| check | check | M11C1-04bba7f62be17b37e799e72b | 0 | 38 | matched 38, missing 0, different 0 | yes |

The two runs produced identical artifact hashes for all 38 artifacts: **yes**.
The write run changed only the relocated lineage, the asset manifest and the
registry; all 34 cell GLTF/BIN files and the alias manifest are byte-identical
to commit 46d40e9. The lineage bytes differ from the 46d40e9 blob in exactly
one field, the exporter's own hash under authoritative_inputs, because the
exporter changed. Receipts: **receipts/m11c2_production_export_write_2026-09-13.json**
and **receipts/m11c2_production_export_check_2026-09-13.json** in the packet.

### Authorized production hash set

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| art/data/m11c2/floor01_owner_first_lineage.json | 15,687,735 | 313436bc2d17134c4e3a0055487c6a0a04e9eae016a451339ba25b4bfd441fe4 |
| game/assets/building/floor_01_cells/floor01_asset_manifest.json | 86,479 | 2c80df4489bd51e7b777654cdec4f4e11ef89cea4b714b4206a269da7a185081 |
| game/assets/building/floor_01_cells/floor01_compatibility_aliases.json | 149,272 | ef2c3bf206e57118065de0696de5ebcdd3684c2e51619d0b6386e0a33557ca9a |
| game/assets/building/floor_01_cells/orison_f01_interior.bin | 5,041,436 | 42d4bbe5aa6bf9b1772e7c43ec4c1090235b09569793176fcc69e8f18f95f012 |
| game/assets/building/floor_01_cells/orison_f01_interior.gltf | 168,259 | bc6ff5536e374be8385232b65c0404014d5970c9a27f016c0a301d01748c48e4 |
| game/assets/building/floor_01_cells/orison_facade_shell.bin | 1,239,972 | e5666a66f32f7e86fbe30c404b20bf1be3f7d1fbd369e314f7c7d89089be777b |
| game/assets/building/floor_01_cells/orison_facade_shell.gltf | 66,765 | c47a6eeefe146ff9bebb6d09a8ae5d24f6beb6f9a69a15a4f79b2b8e9c2314c8 |
| game/assets/building/floor_01_cells/passage.bin | 741,472 | 2861fceab55c8883fa24b7d3f03525fa26ee6eee25ea629bd2dda5df231fac36 |
| game/assets/building/floor_01_cells/passage.gltf | 60,429 | 143d159a55e1bebdf1507b0ea2e515ccd763bf2b47770cdd11bb0349cf0f9907 |
| game/assets/building/floor_01_cells/shop_bar.bin | 1,255,696 | eba87f1d58ed50bf4437dc4698bb69d6f9d4ab17b545dd4088747edce662692f |
| game/assets/building/floor_01_cells/shop_bar.gltf | 149,853 | cdf5febdda279dd8c0abd82924052aa2a47892ca2b5886e95376153e43ce1f76 |
| game/assets/building/floor_01_cells/shop_bodega.bin | 156,300 | 639c74a18a499d042af8a44f6a11b70fc739e5ba81382a1769788990b4fa67aa |
| game/assets/building/floor_01_cells/shop_bodega.gltf | 52,019 | 98c241f535cf369f6c5302b704d334c423d51dfe24f545d827a3ecb49c45c68f |
| game/assets/building/floor_01_cells/shop_funeral_parlour.bin | 93,812 | 2aba70fa1cf9027b4725edef8e1f598b3d274e7e839a80ea502d62c9332721f4 |
| game/assets/building/floor_01_cells/shop_funeral_parlour.gltf | 57,090 | 156126eccebb5136d505943080fd8ec7d25ec84880f3ab82d9e865cb0e238be8 |
| game/assets/building/floor_01_cells/shop_hardware_paint.bin | 185,660 | 8d3c8326480aa5714fe085ddd33cc1e71ea674c69185a5b6d13631b8ff7c98eb |
| game/assets/building/floor_01_cells/shop_hardware_paint.gltf | 53,565 | c4c7573c3dbec95bec3b1c30a3858915f21cd1e0953ca77b10705a0fefc37fec |
| game/assets/building/floor_01_cells/shop_keys_cut.bin | 150,596 | 115f13475d0874826a975abba23ec20abed310e27b5e2d73e26f30ceb502097f |
| game/assets/building/floor_01_cells/shop_keys_cut.gltf | 50,215 | e9654a3ffc0f08c3c048afbecbca468857a1ab6b6a210b088e478d9f15efa2be |
| game/assets/building/floor_01_cells/shop_luncheonette.bin | 137,364 | 6c452bffc072137581e636c16ded29daa203bf1320b4ff42eac5f71a8f0e9274 |
| game/assets/building/floor_01_cells/shop_luncheonette.gltf | 80,173 | 55e327d213c21a453b0040d7f8c8e69105e307f0fb912a2cea259b03f3653c58 |
| game/assets/building/floor_01_cells/shop_model_laundry.bin | 155,284 | 3147958516513b9d8ac0bed0150eff8037b0e6e0371a1c737ab61175bfc960f4 |
| game/assets/building/floor_01_cells/shop_model_laundry.gltf | 76,460 | 0e8fff621511552fc51b7aa9b5d5fb9ed5ec89e976fc9bfd077dbbd986437af8 |
| game/assets/building/floor_01_cells/shop_news_cigars.bin | 88,804 | a5f02344357a93404ff20ded11527b5c04e7a90b56d25fafbd5cb0f34338b926 |
| game/assets/building/floor_01_cells/shop_news_cigars.gltf | 63,946 | 2504ef7ff2283a7f32a8cae426dfdf1a70760e5d7719a32cf63daad9e50a8871 |
| game/assets/building/floor_01_cells/shop_otis_son.bin | 149,276 | ba098fd79b25a9b30690ef3fdd7b448938668a079626b9218378de9b6f56bb4a |
| game/assets/building/floor_01_cells/shop_otis_son.gltf | 72,634 | 352a40ef1a5a5196d4945349d410dc023d17e11629e11b22d36bb3a68c5e2c61 |
| game/assets/building/floor_01_cells/shop_pawnbroker.bin | 121,252 | 98f78900ca59f236d1bc55ece6c94825c4abe942c057586001d272a62c75bdff |
| game/assets/building/floor_01_cells/shop_pawnbroker.gltf | 79,375 | 7c8a009e1a5cefeb2767bd83b58a8b6fae400b248049f484032bd6480a84d6b2 |
| game/assets/building/floor_01_cells/shop_photo_supplies.bin | 119,212 | 518a8a727adbf5925b0e1968aefe0da1af592383b37ae387d9206de927973705 |
| game/assets/building/floor_01_cells/shop_photo_supplies.gltf | 79,883 | 3a79e94e3d29d38e4265573f503ea38141e3b9f1ab402e2d08ab1d9914aeca87 |
| game/assets/building/floor_01_cells/shop_radio_service.bin | 101,236 | ab65af2e3e4e5ce57fd9f64eac09df45468a06b1b03f47b2a41cf9270f14b2f6 |
| game/assets/building/floor_01_cells/shop_radio_service.gltf | 81,449 | c1786e26dbae42f23bc9da9dcb7afc3629e09615ef104e01fe5e769d6050300a |
| game/assets/building/floor_01_cells/shop_shoe_rebuilding.bin | 84,308 | a8c0cd8fa55990d23b8658168ee39b8218d2202305ea3aea1ae30bdb52b75918 |
| game/assets/building/floor_01_cells/shop_shoe_rebuilding.gltf | 50,571 | 7c5e3a4aff034e7533fed0c157ca4da7ad264d4d7632d9ff91fbd4622f7dc8d6 |
| game/assets/building/floor_01_cells/site_street_common.bin | 2,288,868 | 4b8d4a73f088df1b067f850689c2bc436517ef3e13e2e98e18a90a90b51cafa9 |
| game/assets/building/floor_01_cells/site_street_common.gltf | 99,719 | 102693f5e35816da2650f81065219a19daa9a77a96b4c9b232a6fcdf4c04a6a2 |
| game/data/floor_01_cell_registry.json | 158,426 | d4c9f1032676dfa5bdfb50af5f1176078e8be016277dd99c6adb810451bb3e2f |

Every hash above was re-read from disk at checkpoint time and matches the
manifest binding: **yes**.
Registry binding of the asset manifest: **2c80df4489bd51e7b777654cdec4f4e11ef89cea4b714b4206a269da7a185081** (matches disk: **yes**).
Asset-manifest binding of the lineage sidecar: **313436bc2d17134c4e3a0055487c6a0a04e9eae016a451339ba25b4bfd441fe4** at **art/data/m11c2/floor01_owner_first_lineage.json** (matches disk: **yes**, 15,687,735 bytes).

| Cell | GLTF bytes | BIN bytes | Primitives | Triangles | Vertices | Collision objects |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| **CELL_ORISON_F01_INTERIOR** | 168,259 | 5,041,436 | 80 | 78,846 | 143,116 | 18 |
| **CELL_ORISON_FACADE_SHELL** | 66,765 | 1,239,972 | 31 | 18,422 | 35,334 | 10 |
| **CELL_SITE_STREET_COMMON** | 99,719 | 2,288,868 | 51 | 33,634 | 65,295 | 40 |
| **CELL_PASSAGE** | 60,429 | 741,472 | 31 | 10,920 | 21,182 | 26 |
| **CELL_SHOP_BAR** | 149,853 | 1,255,696 | 72 | 19,036 | 35,786 | 33 |
| **CELL_SHOP_BODEGA** | 52,019 | 156,300 | 23 | 2,296 | 4,533 | 17 |
| **CELL_SHOP_MODEL_LAUNDRY** | 76,460 | 155,284 | 33 | 2,300 | 4,478 | 23 |
| **CELL_SHOP_SHOE_REBUILDING** | 50,571 | 84,308 | 21 | 1,226 | 2,452 | 20 |
| **CELL_SHOP_KEYS_CUT** | 50,215 | 150,596 | 21 | 2,174 | 4,348 | 20 |
| **CELL_SHOP_HARDWARE_PAINT** | 53,565 | 185,660 | 22 | 2,678 | 5,356 | 21 |
| **CELL_SHOP_FUNERAL_PARLOUR** | 57,090 | 93,812 | 24 | 1,370 | 2,740 | 23 |
| **CELL_SHOP_PHOTO_SUPPLIES** | 79,883 | 119,212 | 35 | 1,832 | 3,542 | 25 |
| **CELL_SHOP_RADIO_SERVICE** | 81,449 | 101,236 | 36 | 1,532 | 2,942 | 26 |
| **CELL_SHOP_PAWNBROKER** | 79,375 | 121,252 | 35 | 1,820 | 3,518 | 25 |
| **CELL_SHOP_NEWS_CIGARS** | 63,946 | 88,804 | 28 | 1,340 | 2,558 | 18 |
| **CELL_SHOP_OTIS_SON** | 72,634 | 149,276 | 31 | 2,186 | 4,372 | 30 |
| **CELL_SHOP_LUNCHEONETTE** | 80,173 | 137,364 | 35 | 2,114 | 3,984 | 25 |

## Production registry and lifecycle authority

**Floor01CellRegistry** is the only production F01 geometry registry. It owns
imported cell or rollback-monolith instances and session-local residency facts;
it does not own gameplay state or durable save facts. Its public contract:

- validates the registry schema and the hash-bound asset and alias manifests
  before owner-first mounting, and hash-binds the lineage sidecar without
  parsing it;
- refuses unknown cells, duplicate cell or semantic owners, dependency cycles,
  incompatible aliases, invalid lifecycles, unknown residency sets, a missing
  or mismatched bound file, and simultaneous monolith/cell composition;
- exposes semantic-owner, compatibility-alias, cell-instance, and geometry
  queries without requiring consumers to assume generated node paths;
- supports the complete **FULL_RECOMPOSITION** set and the reviewed independent
  residency sets without inventing an automatic streaming policy;
- releases imported geometry and non-owning references through a deterministic
  public teardown API; and
- reports wall-clock phase timings for configure and mount as diagnostics that
  are never compared between modes as semantic facts.

All 17 cells remain resident by default at this checkpoint. Independent
addressability is a proven interface, not authority to add an automatic
streaming policy. Registry suite result: see the validation table.

### Boot-cost attribution (management item 3)

Before the close the registry read the whole lineage sidecar as JSON at every
owner-first boot to check three header fields. Measured on 2026-09-13 in the
same Godot build with a one-off headless probe over the 15,687,735-byte file,
three rounds each:

| Operation on the lineage sidecar | Round 1 | Round 2 | Round 3 |
| --- | ---: | ---: | ---: |
| SHA-256 (kept) | 38.266 ms | 37.784 ms | 37.659 ms |
| read as text (dropped) | 15.434 ms | 13.880 ms | 14.423 ms |
| JSON parse (dropped) | 249.227 ms | 235.119 ms | 237.098 ms |
| release parsed tree (dropped) | 44.383 ms | 50.387 ms | 38.678 ms |

So the dropped parse path cost between 299.4 and 309.0 ms per boot, against about 38 ms to hash the file. Hashing the
34 cell assets is not the cost: it is measured below at under 40 ms for
13,452,953 bytes. No import-time check is proposed; the remaining hash work is
under 80 ms per boot in total and keeps the fail-closed binding at runtime.

Registry phase timings from the re-run production matrix (the lines the
registry prints at every configure and mount; first occurrence of each mode in
the matrix log, warm cache, same process as the matched measurement):

- **legacy_monolith configure** (7 occurrences in the log; first shown): index_ms 1.041; registry_manifest_read_parse_ms 2.452; registry_manifest_validate_ms 3.601; total_ms 7.102.
- **legacy_monolith mount** (7 occurrences in the log; first shown): attach_ms 0.768; cell_count 0.0; instantiate_ms 14.961; load_ms 2399.446; total_ms 2415.297.
- **owner_first_cells configure** (7 occurrences in the log; first shown): alias_target_check_ms 2.478; asset_manifest_parse_ms 1.344; asset_manifest_sha256_ms 0.390; bound_files_total_ms 113.180; cell_asset_files_hashed 34.0; cell_asset_sha256_ms 38.008; cell_descriptor_parse_ms 22.788; compatibility_aliases_parse_ms 2.297; compatibility_aliases_parsed true; compatibility_aliases_sha256_ms 0.532; index_ms 1.048; lineage_parsed false; lineage_sha256_ms 36.924; registry_manifest_read_parse_ms 2.595; registry_manifest_validate_ms 3.648; total_ms 120.483.
- **owner_first_cells mount** (7 occurrences in the log; first shown): attach_ms 0.897; cell_count 17.0; instantiate_ms 14.521; load_ms 2208.792; total_ms 2225.401.

The mount phase in owner-first mode is the ResourceLoader load of 17 GLTF
cells versus one monolith; instantiate and attach are milliseconds in both.
Attribution of the +344.146 ms measured on 2026-08-31 therefore rests on the
dropped parse path (roughly 300 to 310 ms) plus the cell hashing and
descriptor parsing that legitimately remain (about 60 ms). After the fix the
registry's configure differs between modes by about 113 ms; the remainder of
the re-run delta below is outside the registry and inside the spread between
two consecutive cycles of the same mode (per-cycle table), so it is not
attributed further.

| Matched performance | Legacy monolith | Owner-first cells | Cells minus legacy |
| --- | ---: | ---: | ---: |
| ready_and_settle_ms, 2026-08-31 (parse at boot) | 14,622.783 | 14,966.929 | 344.146 |
| ready_and_settle_ms, 2026-09-13 (hash only) | 14,322.651 | 14,575.029 | 252.378 |

Both rows average the two measured cycles per mode inside one process; the
whole BuildingRoot ready-and-settle is measured, not the registry alone, so
run-to-run noise of tens of milliseconds is expected in either direction.

## Geometry-free F01 host and production consumer topology

**BuildingRoot** now creates one persistent, geometry-free **F01** host before
the remaining floor roots. The host retains production services, passes,
directors, semantic interaction objects, and durable authorities. Its child
**Floor01GeometryProvider** mounts either the full owner-first cell residency
or the protected rollback monolith, never both.

The reviewed consumer topology is:

| Production consumer | Production-cut boundary |
| --- | --- |
| BuildingRoot loading | Requests the configured provider and keeps **floor_nodes[F01]** bound to the persistent host. |
| Indexing and visibility | Queries active owner cells and compatibility aliases instead of assuming the monolith subtree. |
| F01 host passes/directors | Remain children/consumers of the persistent host and survive geometry teardown. |
| OrisonDetailPass | Continues to mount production detail through the F01 host while resolving active cell geometry semantically. |
| VantryPointNetwork | Keeps its existing point and audio authority; cell ownership changes no job/case fact. |
| ExteriorDetailPass | Reads the governed exterior/facade residency without duplicating M11A exterior authority. |
| ResidentNav | Validates the active semantic world without serializing residency or asset paths. |
| M11A exterior composition | Remains an independent production module; the floor cut neither absorbs nor duplicates its route/simulation authority. |
| Save/reconstruction | Reconstructs the selected building root and session geometry mode while durable state remains semantic and mode-free. |

### Two-mode runtime matrix receipt

Receipt: **runtime/m11c2_production_matrix_receipt.json**, SHA-256 **befa6d94547d6f2ccae92f9c6806d3195af61d5640151a8501c6e54dba0d1e8a**,
schema **orison.m11c2.production-matrix.v1**, status **PASS**, checks passed **26/26**, failures **[]**,
matrix harness SHA-256 **53c47b46a92da50e26d3d217940004517319ae532d8788cbd176e6b94556fd8f**. Re-run 2026-09-13 after the registry change under the shared Godot lane
mutex with a 1,500-second ceiling (the committed serial runner caps at 180 s; the launcher reproduces its mutex, process census and log contract).
Comparison controls: same root **res://scenes/building/orison_root.tscn**, renderer **forward_plus**,
simulation time **12:30**, clock frozen **yes**,
both providers prewarmed **yes**, counterbalanced order **yes**,
residency **FULL_RECOMPOSITION**, shop access **ordinary trading hours; NEWS/CIGARS locked**.
Selector: default **v1**, requested **v1**, scene **res://scenes/building/orison_root.tscn**.

| # | Check | Result |
| ---: | --- | --- |
| 1 | M11C1 seam/traversal config matches its immutable normalized hash | PASS |
| 2 | M11C1 seam/traversal config parses | PASS |
| 3 | production layout parses read-only | PASS |
| 4 | M11C1 contract supplies exactly five dangerous seams | PASS |
| 5 | M11C1 contract supplies exactly five matched cameras | PASS |
| 6 | M11C1 contract supplies the reviewed seventeen-cell set | PASS |
| 7 | production Floor01GeometryConfiguration loads | PASS |
| 8 | BuildingRootSelector default remains v1 | PASS |
| 9 | explicit v1 selector resolves the production BuildingRoot | PASS |
| 10 | legacy_monolith production warmup | PASS |
| 11 | owner_first_cells production warmup | PASS |
| 12 | independent M11A production scene warmup | PASS |
| 13 | legacy_monolith cycle_1 complete production cycle | PASS |
| 14 | owner_first_cells cycle_1 complete production cycle | PASS |
| 15 | owner_first_cells cycle_2 complete production cycle | PASS |
| 16 | legacy_monolith cycle_2 complete production cycle | PASS |
| 17 | legacy_monolith independent M11A lifecycle | PASS |
| 18 | owner_first_cells independent M11A lifecycle | PASS |
| 19 | M11A independent lifecycle is mode-independent and normalized-equal | PASS |
| 20 | M11A MatLib dependencies reuse the exact warmed resources in both modes | PASS |
| 21 | legacy_monolith_to_legacy_monolith save/destroy/CampaignShell reconstruction | PASS |
| 22 | owner_first_cells_to_owner_first_cells save/destroy/CampaignShell reconstruction | PASS |
| 23 | legacy_monolith_to_owner_first_cells save/destroy/CampaignShell reconstruction | PASS |
| 24 | owner_first_cells_to_legacy_monolith save/destroy/CampaignShell reconstruction | PASS |
| 25 | legacy monolith and owner-first cells expose the same semantic world | PASS |
| 26 | warmed matrix retains no production nodes or orphans | PASS |

## Selector, rollback, and save boundary

Three decisions remain intentionally separate:

- **BuildingRootSelector.DEFAULT_ID = v1** selects the production v1 root and
  is unchanged;
- **Floor01GeometryConfiguration.DEFAULT_MODE = owner_first_cells** selects the
  production F01 geometry provider inside that root; and
- **legacy_monolith** is an explicit injected diagnostic/test mode for rollback
  proof.

The geometry-mode override is session-local, has no public write into save
state, and resets independently of player, campaign, job, case, audio, wake,
interaction, or route authority. Neither the mode nor node paths, asset paths,
residency IDs, cell IDs, compatibility aliases, or world coordinates may
become durable state.

The protected rollback input remains **game/assets/building/floor_01.gltf** and
**game/assets/building/floor_01.bin**; its byte comparison is in the protected
boundary table below.

### Save, destruction and CampaignShell reconstruction receipt

| Direction | Saved | Save bytes | Save ms | State load ms | Origin compose ms | Reconstructed compose ms | Forbidden save fact | Provider absent from save | Semantic world equal | Semantic SHA-256 origin = reconstructed | Zero retained production-cut owners |
| --- | --- | ---: | ---: | ---: | ---: | ---: | --- | --- | --- | --- | --- |
| legacy_monolith_to_legacy_monolith | yes | 3,491 | 0.457 | 0.378 | 14,424.574 | 14,487.094 | none | yes | yes | yes (10d3a58db600539f) | yes |
| legacy_monolith_to_owner_first_cells | yes | 3,492 | 0.458 | 0.355 | 14,408.984 | 14,533.246 | none | yes | yes | yes (10d3a58db600539f) | yes |
| owner_first_cells_to_legacy_monolith | yes | 3,491 | 0.484 | 0.366 | 14,470.146 | 14,241.899 | none | yes | yes | yes (10d3a58db600539f) | yes |
| owner_first_cells_to_owner_first_cells | yes | 3,469 | 0.493 | 0.345 | 14,572.241 | 14,560.068 | none | yes | yes | yes (10d3a58db600539f) | yes |

## World and semantic equivalence

The final proof compared **legacy_monolith** and **owner_first_cells** under
the same production root, renderer/profile, complete residency, simulation
time, and cache treatment.

Equivalence result: semantic world equal **yes**; legacy semantic SHA-256 **618e541a3820f2130e8d2302211401bff7223f27c775b8f3a3f22e6dbf448f13**;
cells semantic SHA-256 **618e541a3820f2130e8d2302211401bff7223f27c775b8f3a3f22e6dbf448f13**; raw coordinates compared **no**;
node or asset paths compared as semantic facts **no**.

Semantic-owner result: check 25 above (legacy monolith and owner-first cells
expose the same semantic world) and the registry suite's alias resolution
check (every compatibility alias resolves, including all 47 legitimate splits).

| Tree metric (measured cycles, per mode) | Legacy monolith | Owner-first cells | Cells minus legacy |
| --- | ---: | ---: | ---: |
| nodes | 18,368 | 18,516 | 148 |
| mesh_instances | 9,617 | 9,692 | 75 |
| collision_objects | 1,640 | 1,660 | 20 |
| collision_shapes | 1,662 | 1,682 | 20 |
| mesh_surfaces (cycle 1) | 9,611 | 9,686 | 75 |
| lights (cycle 1) | 661 | 661 | 0 |
| triangles (cycle 1) | 5,412,631 | 5,412,631 | 0 |
| vertices (cycle 1) | 4,460,065 | 4,460,065 | 0 |

Production rebatching legitimately changes descriptor topology: the extra
nodes, mesh instances and collision objects are the 17 cell wrappers and the
owner-first split of shared surfaces, while triangles and vertices are
identical. Every such difference is structurally explained by the alias
manifest's split identities; no unexplained world-payload or semantic
difference was found.

## Collision-bearing seam and route proof

The run used the real **PlayerController**, one legitimate initial placement,
public interaction surfaces, and collision-bearing movement, in both modes.

| Route fact | Legacy monolith | Owner-first cells |
| --- | --- | --- |
| status | PASS | PASS |
| noclip | no | no |
| teleports | 0 | 0 |
| intermediate transform writes | 0 | 0 |
| initial placements | 1 | 1 |
| initial grounded | yes | yes |
| legs | 43 | 43 |
| crossings | facade_out yes, facade_return yes, shell_out yes, shell_return yes | facade_out yes, facade_return yes, shell_out yes, shell_return yes |

| Contract | Legacy monolith | Owner-first cells |
| --- | --- | --- |
| Orison interior ↔ facade ↔ street | orison_to_street reached yes, grounded 1.000, 2.23 m, 44 physics frames; street_to_interior reached yes, grounded 1.000, 2.28 m, 45 physics frames | orison_to_street reached yes, grounded 1.000, 2.23 m, 44 physics frames; street_to_interior reached yes, grounded 1.000, 2.28 m, 45 physics frames |
| Street ↔ Passage | passage_enter reached yes, grounded 1.000, 2.90 m, 58 physics frames; passage_to_portal reached yes, grounded 1.000, 13.25 m, 265 physics frames; passage_to_street reached yes, grounded 1.000, 2.90 m, 58 physics frames | passage_enter reached yes, grounded 1.000, 2.90 m, 58 physics frames; passage_to_portal reached yes, grounded 1.000, 13.25 m, 265 physics frames; passage_to_street reached yes, grounded 1.000, 2.90 m, 58 physics frames |
| Passage ↔ each accessible shop | PASSAGE_MODEL_LAUNDRY_BIDIRECTIONAL crossed yes; PASSAGE_SHOE_REBUILDING_BIDIRECTIONAL crossed yes; PASSAGE_KEYS_CUT_BIDIRECTIONAL crossed yes; PASSAGE_HARDWARE_PAINT_BIDIRECTIONAL crossed yes; PASSAGE_FUNERAL_PARLOUR_BIDIRECTIONAL crossed yes; PASSAGE_PHOTO_SUPPLIES_BIDIRECTIONAL crossed yes; PASSAGE_RADIO_SERVICE_BIDIRECTIONAL crossed yes; PASSAGE_PAWNBROKER_BIDIRECTIONAL crossed yes; PASSAGE_NEWS_CIGARS_LOCKED_SERVICE_FRONTAGE crossed no, locked; PASSAGE_OTIS___SON_BIDIRECTIONAL crossed yes; PASSAGE_LUNCHEONETTE_BIDIRECTIONAL crossed yes | PASSAGE_MODEL_LAUNDRY_BIDIRECTIONAL crossed yes; PASSAGE_SHOE_REBUILDING_BIDIRECTIONAL crossed yes; PASSAGE_KEYS_CUT_BIDIRECTIONAL crossed yes; PASSAGE_HARDWARE_PAINT_BIDIRECTIONAL crossed yes; PASSAGE_FUNERAL_PARLOUR_BIDIRECTIONAL crossed yes; PASSAGE_PHOTO_SUPPLIES_BIDIRECTIONAL crossed yes; PASSAGE_RADIO_SERVICE_BIDIRECTIONAL crossed yes; PASSAGE_PAWNBROKER_BIDIRECTIONAL crossed yes; PASSAGE_NEWS_CIGARS_LOCKED_SERVICE_FRONTAGE crossed no, locked; PASSAGE_OTIS___SON_BIDIRECTIONAL crossed yes; PASSAGE_LUNCHEONETTE_BIDIRECTIONAL crossed yes |
| Bodega ↔ street | street_to_bodega_start reached yes, grounded 1.000, 18.68 m, 374 physics frames; bodega_enter reached yes, grounded 1.000, 2.31 m, 46 physics frames; bodega_return reached yes, grounded 1.000, 2.21 m, 44 physics frames | street_to_bodega_start reached yes, grounded 1.000, 18.68 m, 374 physics frames; bodega_enter reached yes, grounded 1.000, 2.31 m, 46 physics frames; bodega_return reached yes, grounded 1.000, 2.21 m, 44 physics frames |
| Established F01 vertical/core connections | status PASS; elevator F01/F02 contract yes; derived without embedded coordinates yes; lobby_to_public_core reached yes, grounded 1.000, 8.90 m, 178 frames; f01_to_f02_public_stair reached yes, grounded 1.000, 18.89 m, 367 frames; f02_to_f01_public_stair reached yes, grounded 1.000, 18.72 m, 359 frames; public_core_to_f01_hall reached yes, grounded 1.000, 4.70 m, 94 frames | status PASS; elevator F01/F02 contract yes; derived without embedded coordinates yes; lobby_to_public_core reached yes, grounded 1.000, 8.90 m, 178 frames; f01_to_f02_public_stair reached yes, grounded 1.000, 18.89 m, 367 frames; f02_to_f01_public_stair reached yes, grounded 1.000, 18.72 m, 359 frames; public_core_to_f01_hall reached yes, grounded 1.000, 4.70 m, 94 frames |
| NEWS/CIGARS authored locked refusal | PASSAGE_NEWS_CIGARS_LOCKED_SERVICE_FRONTAGE: crossed no, locked yes, status PASS | PASSAGE_NEWS_CIGARS_LOCKED_SERVICE_FRONTAGE: crossed no, locked yes, status PASS |
| Semantic seam chains (M11C1 endpoints) | bodega_to_passage_start reached yes (2 sublegs, grounded 1.000, 0.949); street_to_orison reached yes (1 sublegs, grounded 0.929) | bodega_to_passage_start reached yes (2 sublegs, grounded 1.000, 0.941); street_to_orison reached yes (1 sublegs, grounded 0.974) |

Simulation time for both providers: **12:30**, shop access state **ordinary trading hours; NEWS/CIGARS locked**.
The locked refusal is correct collision behaviour, not a missing route.

## Performance and lifecycle

Both providers were measured under identical root, renderer/profile,
residency set, simulation time, cache state, and sampling procedure
(profile: same process, root, renderer, fixed simulation facts, warm cache; measured cycles per mode: 2 and 2).

| Measure | Legacy monolith | Owner-first cells | Delta |
| --- | ---: | ---: | ---: |
| Disk/BIN footprint (bytes on disk) | 12,703,334 | 13,452,953 | 749,619 |
| Startup/import/load (root scene load_ms) | 0.520 | 0.507 | -0.013 |
| Instantiation (root instantiate_ms) | 0.035 | 0.031 | -0.004 |
| Ready and settle (ms) | 14,322.651 | 14,575.029 | 252.378 |
| First-shift/service initialization (first_interaction_ms) | 3.747 | 2.656 | -1.090 |
| Save/reconstruction (same-mode save ms / state load ms) | 0.457 / 0.378 | 0.493 / 0.345 | see reconstruction table |
| Warm CPU frame (process_ms) | 2.619 | 3.594 | 0.975 |
| Warm physics frame (physics_process_ms) | 0.538 | 0.511 | -0.027 |
| GPU frame | not measured (headless; trustworthy no) | not measured (trustworthy no) | not measured |
| VRAM | not measured (trustworthy no) | not measured (trustworthy no) | not measured |
| Draw calls | 0 (headless) | 0 (headless) | 0 |
| Nodes / meshes / collisions | 18,368 / 9,617 / 1,640 | 18,516 / 9,692 / 1,660 | 148 / 75 / 20 |

GPU time, VRAM and draw calls are not inferred: the matrix ran headless and
the engine returned no measured value, which the receipt records as untrusted.

### Per-cycle receipt

| Mode | Cycle | Measured | Status | ready_and_settle_ms | first_interaction_ms | process_ms | physics_ms | Process delta objects / resources / nodes / orphans | Tracked owner resources | Retained | Teardown zero | Weakrefs released |
| --- | --- | --- | --- | ---: | ---: | ---: | ---: | --- | ---: | ---: | --- | --- |
| legacy_monolith | cycle_1 | yes | PASS | 14,238.466 | 2.851 | 3.004 | 0.518 | +965 / +5 / +0 / +0 | 1,175 | 0 | yes | yes |
| legacy_monolith | cycle_2 | yes | PASS | 14,406.836 | 4.642 | 2.234 | 0.558 | -701 / +0 / +0 / +0 | 1,175 | 0 | yes | yes |
| owner_first_cells | cycle_1 | yes | PASS | 14,541.645 | 2.619 | 5.051 | 0.520 | +736 / +0 / +0 / +0 | 1,988 | 0 | yes | yes |
| owner_first_cells | cycle_2 | yes | PASS | 14,608.412 | 2.694 | 2.136 | 0.502 | +20 / +2 / +0 / +0 | 1,988 | 0 | yes | yes |

### Lifecycle receipt and retained-object finding (management item 4)

Warmed baseline: objects 4,219, resources 1,501, nodes 35, orphans 0.
Final: objects 4,213, resources 1,508, nodes 35, orphans 0.
Final delta from warmed: objects -6, resources +7, nodes +0, orphans +0 (receipt flag aggregate_object_resource_delta_observational = yes).
The 2026-08-31 run recorded objects +101, resources +7, nodes +0, orphans +0.

**Open lifecycle finding, not written as zero.** The draft required retained
production-cut owners, resources, nodes and orphans all zero. What the
receipts prove is narrower and is stated as such:

- Owner-specific evidence: every measured cycle tracks the provider-owned
  Mesh, Material, Shape3D and MultiMesh resources by weak reference and
  reports **0 retained** (tracked counts in the per-cycle table); every
  teardown receipt reports 0 retained instances, resources and strong
  references; nodes and orphan nodes are 0 in every delta; the four
  reconstruction directions report no retained production-cut resources,
  nodes or orphans.
- Aggregate evidence: the process-wide ObjectDB and resource counters drift
  by objects -6 and resources +7 over the whole matched run. The same
  counters swing by hundreds of objects in either direction between
  consecutive cycles of the same mode (per-cycle table), so they cannot
  attribute a residual to either provider. No matched control that isolates
  this drift from production-cut ownership was run; the M11A independent
  lifecycle rows (below) are mode-independent but are not that control.

The aggregate residual is therefore recorded as an open lifecycle finding
for the owner, with the owner-specific zeros standing as the production-cut
ownership evidence. It is not hidden, reclassified, or averaged.

| M11A independent lifecycle | Elapsed ms | Process delta objects / resources / nodes / orphans | Public teardown ok | Normalized modes equal | Shared MatLib dependencies stable |
| --- | ---: | --- | --- | --- | --- |
| legacy_monolith | 197.205 | -845 / +0 / +0 / +0 | yes | yes | yes |
| owner_first_cells | 199.695 | +4 / +0 / +0 / +0 | yes | yes | yes |

## Matched human-review packet

The immutable packet root is **art/renders/orison_v2/m11c2_floor01_production_cut_01/**.
Capture receipt: **receipts/m11c2_production_capture_receipt.json**, schema **orison.m11c2.production-matched-capture.v2**, status **PASS**, failures **[]**,
re-merged 2026-09-13 by **tools/merge_m11c2_capture_receipts.py** so that it binds the re-run matrix receipt
(bound matrix SHA-256 **befa6d94547d6f2ccae92f9c6806d3195af61d5640151a8501c6e54dba0d1e8a**, matrix harness **53c47b46a92da50e26d3d217940004517319ae532d8788cbd176e6b94556fd8f**).
The PNG frames, their hashes, cameras and simulation facts are the frozen 2026-08-31 captures; the capture harness SHA-256 is **44d94c27374a25c04eba7109341b476a0ec672963fdc5c97daa9b28ed49d0dd5** and all parts are exact: **yes**.

Capture boundary: capture_collision_changes no; harness_added_collision no; harness_added_geometry no; harness_added_labels_arrows_or_seam_covers no; harness_added_lights no; harness_added_world_environment no; production_player_and_camera yes; production_root_through_selector yes; provider_teardown_during_capture no; render_node_mutation no.
Frames: matched 10, route 9, total 19. Renderer forward_plus, 1600×900, production PlayerController camera.
Simulation state: initial exact **yes**, capture-end exact **yes**, fixed through the public campaign clock **yes**; capture-end facts SHA-256 **aefc4e2b644ca5bf16d80e22b15eee8577692bcb3084c9af0b49a23b2692b9f9**
(campaign clock day-of-year 243, minute 750, weekday mon, elapsed 0.0; core loop boundary wake_complete, safe return anchor **F04_B_BED**; first shift phase complete, filing fault_corrected, report **vantry_chirp_2a**).

| # | Seam | Pair id | Camera exact | Dimensions exact | Legacy PNG SHA-256 | Cells PNG SHA-256 | Changed pixel fraction | Mean abs RGB | Max abs RGB |
| ---: | --- | --- | --- | --- | --- | --- | ---: | --- | --- |
| 1 | **SEAM_ORISON_SOUTH_SHELL_STREET** | orison_shell_street | yes | yes | 08ce9a8948038979459e4db60fc172517e9e38120d6a1094ebeb82c0b1c07bc3 | d6bf6c9216f365f21b7d66fedce97107d1426c7272acc03cb0009b61d00b81a2 | 0.196160 | 0.229, 0.279, 0.332 | 131, 91, 86 |
| 2 | **SEAM_STREET_PASSAGE_PORTAL** | street_passage_portal | yes | yes | 662a8c658bafc6f2b48251c980d745a1ed0ac22e724c214a4195c5521d6d36eb | 37b680424df6fe09ac4649e51da07b4ad2b4f5691fed0aa1c6a1c7a32b85925b | 0.435719 | 1.050, 0.932, 0.668 | 131, 98, 100 |
| 3 | **SEAM_PASSAGE_SHOP_AISLES** | passage_west_shop_aisle | yes | yes | 18613ba3e6ae3e5bfce7ec3e0ffb76dfff57e9d7363e650f7a59d2b2e22b46ef | 465d08b97973c04836a42662fa21ff8c26c03120a78a81e53a4b13d756e2817a | 0.705270 | 0.919, 0.664, 0.388 | 131, 91, 73 |
| 4 | **SEAM_BODEGA_STREET** | bodega_street_threshold | yes | yes | 8707aee2249bbccdb7470ed54ae91a18ac53dfad629cfe5649f09e470e5d3263 | 3581cae2a19ca9f226dccd5846c114a66ffd663b0a1383781254df5bef294614 | 0.282114 | 0.321, 0.350, 0.370 | 153, 163, 57 |
| 5 | **SEAM_SHELL_INTERIOR** | facade_shell_interior | yes | yes | 2a80cea8615034f25efe5b75529d9850122ba0c7ba6579f84c7edc4ef0f7dc0b | feb0a7230292dabeeee398d43d01fb0bd24ed8058e04a8b7087f9cafee2cf5fd | 0.630645 | 0.590, 0.335, 0.155 | 154, 123, 78 |

| # | Matched frame | Eye | Target | FOV | Legacy mean luma | Cells mean luma |
| ---: | --- | --- | --- | ---: | ---: | ---: |
| 1 | orison_shell_street | 0.000, 1.390, 18.000 | 0.000, 1.450, 9.700 | 64.0 | 19.09 | 19.09 |
| 2 | street_passage_portal | 9.000, 1.390, 21.000 | 14.000, 1.550, 31.000 | 62.0 | 15.06 | 15.56 |
| 3 | passage_west_shop_aisle | 14.200, 1.420, 49.425 | 11.340, 1.050, 49.425 | 62.0 | 35.28 | 35.34 |
| 4 | bodega_street_threshold | 12.000, 1.390, 18.000 | 17.400, 1.350, 10.500 | 62.0 | 19.38 | 19.45 |
| 5 | facade_shell_interior | 0.000, 1.433, 8.250 | 0.000, 1.200, 9.795 | 64.0 | 32.92 | 32.58 |

| # | Route frame (owner-first cells) | Status | Grounded | Noclip | Player feet | PNG SHA-256 | Mean luma | Fraction below 16 |
| ---: | --- | --- | --- | --- | --- | --- | ---: | ---: |
| 1 | orison_interior_looking_to_street | PASS | yes | no | 0.000, 0.022, 8.950 | b00f8c1fb61bdd640f60131ebf6e34cb664a41d7d28a1b3568a3559556799571 | 24.71 | 0.3485 |
| 2 | street_looking_to_bodega | PASS | yes | no | 0.000, 0.038, 11.151 | 8e196ea1716c6bc1cdc051bb76433265e76ba6cce77b0b925c54e20b57f0a7fc | 58.04 | 0.1520 |
| 3 | bodega_interior_looking_to_street | PASS | yes | no | 18.639, 0.050, 10.777 | 86f3ee34f2e3974bf1e32470e1cac2eb34f111718f5bc2c0eea760dbf97bdd0b | 49.82 | 0.3044 |
| 4 | passage_looking_to_shop_aisles | PASS | yes | no | 13.999, 0.011, 29.973 | 0d9fa6e3bb1b5e60172bac9fd8c2ee855fcb242b2269c185a0c26791eb7cc6ae | 40.00 | 0.0982 |
| 5 | passage_after_all_shop_fronts | PASS | yes | no | 15.823, 0.011, 43.319 | aa80df2bfb088837d5bef9da1ee741aec17fca111f7856a871e249cf5a2c9ffb | 41.28 | 0.1329 |
| 6 | street_return_looking_to_orison | PASS | yes | no | 0.074, 0.039, 11.325 | 20594f0ad4a73bde0017f57a11ee06aeea7fdfcf9ea31217c11e6f26a0aa1d72 | 58.75 | 0.1579 |
| 7 | orison_return_complete | PASS | yes | no | 0.004, 0.021, 9.075 | 649489e29e90b256852f12d28083c1fa7338e622818a641633b47af757573ed7 | 70.62 | 0.0935 |
| 8 | f02_public_hall_arrival | PASS | yes | no | -1.135, 3.201, 4.870 | 846d61eaf5c4da81d36756b97505eaefe9e0458e61cfae297846e094a4836c22 | 38.61 | 0.1130 |
| 9 | f01_public_hall_return | PASS | yes | no | -1.142, 0.001, 4.868 | 7adfdd761e291c50efc046ff130d29e4946dcf25b0e2fe9de4f609a8cb28fc16 | 39.97 | 0.1044 |

Legacy route control: initial facts match **yes**, end facts match **yes**, semantic contract match **yes**, exact contract match **no** (timing fields differ by construction), all non-timing fields exact **yes**, differences **[]**, grounded-fraction comparisons **46** with maximum absolute delta **0.013652**.
Renderer diagnostics: classification historical Godot 4.7 Forward+ visibility and process-retirement light/geometry unpair diagnostic; new error signatures **[]**; legacy/cell signature sets equal **yes**; route sets equal **yes**; cell minus legacy known signature counts {'light_geometry_index': 2, 'softshadow_unpair': 13}.

Human review verdict: **HUMAN REVIEW PENDING**. Producing or automatically
checking the packet does not grant human acceptance. The question for the
owner is the receipt's own: Do the matched legacy/cell seams and the complete owner-first player route preserve the same world without cracks, doubled surfaces, missing detail, material or lighting discontinuities, or incorrect facade/interior ownership?

## Validation and audit disposition

Standard battery from this checkpoint on: completeness, spatial, systemic
authority, period dates, data consumption (reader), the interaction prompt
carrier suite, every tools test, and the Godot suites below, all with real
exit codes captured through log paths, never through a pipe.

| Proof | Command or scene | Exit | Result |
| --- | --- | ---: | --- |
| Completeness audit | python tools/audit_orison_v2_completeness.py | 2 | ABSENT 51, HUMAN_ACCEPTED 1, PROGRAMMED 44, RUNTIME_PROVEN 34, SHELL_ONLY 2, SPATIALLY_PROVEN 18; blockers 0 / 1 / 86 / 45 / 101 / 103 (historical, unchanged) |
| Evidence impact of this checkpoint | python tools/audit_orison_v2_completeness.py --evidence-impact design/ORISON_V2_M11C2_FLOOR01_PRODUCTION_CUT_CHECKPOINT_2026-08-31.md | 0 | requirements_changed = []; prose inert |
| Spatial dependency audit | python tools/audit_orison_spatial_dependencies.py | 0 | clean |
| Systemic situation authority audit | python tools/audit_systemic_situation_authority.py | 0 | vanished baseline entries (cleanup): 0 |
| Period date audit | python tools/audit_period_dates.py | 0 | PERIOD DATE AUDIT: PASS (10 classified findings) |
| Data-consumption (reader) audit | python tools/audit_data_consumption.py | 1 | report, zero exceptions; see before/after below |
| Interaction prompt carrier audit (report) | python tools/audit_interaction_prompt_carriers.py | 1 | forbidden 2 (clock_prop Hold E, pre-existing, awaiting K2), legacy_uncovered 0, covered 184, stale 0, cleanup 2 |
| tools/tests/test_data_consumption.py | python tools/tests/test_data_consumption.py | 0 | OK, 15 tests |
| tools/tests/test_interaction_implementors.py | python tools/tests/test_interaction_implementors.py | 0 | OK, 31 tests |
| tools/tests/test_interaction_prompt_carriers.py | python tools/tests/test_interaction_prompt_carriers.py | 0 | OK, 28 tests |
| tools/tests/test_m11c0_floor01_harness_contract.py | python tools/tests/test_m11c0_floor01_harness_contract.py | 0 | OK, 5 tests |
| tools/tests/test_m11c1_floor01_source_ownership.py | python tools/tests/test_m11c1_floor01_source_ownership.py | 0 | OK, 25 tests |
| tools/tests/test_m11c1_owner_first_export.py | python tools/tests/test_m11c1_owner_first_export.py | 0 | OK, 11 tests |
| tools/tests/test_m11c1_runtime_rehearsal.py | python tools/tests/test_m11c1_runtime_rehearsal.py | 0 | OK, 17 tests |
| tools/tests/test_m11c1_scanner_consumer_adapter.py | python tools/tests/test_m11c1_scanner_consumer_adapter.py | 0 | OK, 7 tests |
| tools/tests/test_m11c2_floor01_production_export.py | python tools/tests/test_m11c2_floor01_production_export.py | 0 | OK, 11 tests |
| tools/tests/test_m11c2_production_harness_contract.py | python tools/tests/test_m11c2_production_harness_contract.py | 0 | OK, 22 tests |
| tools/tests/test_orison_floor01_source_ownership.py | python tools/tests/test_orison_floor01_source_ownership.py | 0 | OK, 13 tests |
| tools/tests/test_orison_spatial_dependencies.py | python tools/tests/test_orison_spatial_dependencies.py | 0 | OK, 52 tests |
| tools/tests/test_orison_v2_completeness.py | python tools/tests/test_orison_v2_completeness.py | 0 | OK, 99 tests |
| tools/tests/test_rehearse_orison_floor01_partition.py | python tools/tests/test_rehearse_orison_floor01_partition.py | 0 | OK, 5 tests |
| tools/tests/test_room_checkpoint_linter.py | python tools/tests/test_room_checkpoint_linter.py | 0 | OK, 29 tests |
| tools/tests/test_room_checkpoint_reconciler.py | python tools/tests/test_room_checkpoint_reconciler.py | 0 | OK, 38 tests |
| tools/tests/test_room_evidence_verifier.py | python tools/tests/test_room_evidence_verifier.py | 0 | OK, 34 tests |
| tools/tests/test_room_gate_hook.py | python tools/tests/test_room_gate_hook.py | 0 | OK, 24 tests |
| tools/tests/test_room_layout_workbench.py | python tools/tests/test_room_layout_workbench.py | 0 | OK, 35 tests |
| tools/tests/test_room_reconstruction_gate.py | python tools/tests/test_room_reconstruction_gate.py | 0 | OK, 26 tests |
| tools/tests/test_room_reconstruction_progress.py | python tools/tests/test_room_reconstruction_progress.py | 0 | OK, 24 tests |
| tools/tests/test_systemic_situation_authority.py | python tools/tests/test_systemic_situation_authority.py | 0 | OK, 34 tests |
| Godot OrisonV2BlockoutTest | tools/run_godot_serial.ps1 -Scene res://tests/OrisonV2BlockoutTest.tscn -LogPath (file) | 0 | ORISON V2 BLOCKOUT TEST: PASS |
| Godot OrisonV2M11C2Floor01RegistryTest | tools/run_godot_serial.ps1 -Scene res://tests/orison_v2_m11c2_floor01_registry_test.tscn -LogPath (file) | 0 | [M11C2-REGISTRY] PASS (0 failure(s)) |
| Godot OrisonV2M11AFirstExteriorCellTest | tools/run_godot_serial.ps1 -Scene res://tests/OrisonV2M11AFirstExteriorCellTest.tscn -LogPath (file) | 0 | ORISON V2 M11A FIRST EXTERIOR CELL: PASS checks=40 |
| Godot OrisonV2M11BServiceOpeningsTest | tools/run_godot_serial.ps1 -Scene res://tests/OrisonV2M11BServiceOpeningsTest.tscn -LogPath (file) | 0 | ORISON V2 M11B SERVICE OPENINGS: PASS checks=75 |
| Godot DreamBoundaryTest | tools/run_godot_serial.ps1 -Scene res://tests/DreamBoundaryTest.tscn -LogPath (file) | 0 | DREAM BOUNDARY TEST: PASS (39 checks) |
| Godot GoldenLoopTest | tools/run_godot_serial.ps1 -Scene res://tests/GoldenLoopTest.tscn -LogPath (file) | 1 | [K6] CHECKS: 87/87 fails=2; COMPLETE: FAIL. Fails 'restored objective presents the authored title' and 'the objective now directs the player to Mina, not another part'. Reproduced at the accepted base 503465d with the identical two failing checks (exit 1); pre-existing chain debt tied to the beat-4 part-source conflict already before the owner, not introduced by this close. |
| Godot OrisonV2M08ESpatialTest | tools/run_godot_serial.ps1 -Scene res://tests/OrisonV2M08ESpatialTest.tscn -LogPath (file) | 0 | ORISON V2 M08E SPATIAL TEST: PASS |
| Godot OrisonV2M08FRuntimeTest | tools/run_godot_serial.ps1 -Scene res://tests/orison_v2_m08f_runtime_test.tscn -LogPath (file) | 0 | ORISON V2 M08F RUNTIME: PASS checks=29 |
| Godot OrisonV2TwoRootMatrixTest | tools/run_godot_serial.ps1 -Scene res://tests/orison_v2_two_root_matrix_test.tscn -LogPath (file) | 0 | ORISON V2 TWO-ROOT MATRIX: PASS totals={ "v1_to_v1": 1, "v2_to_v2": 1, "v1_to_v2": 1, "v2_to_v1": 1 } checks=24 |
| Godot ServiceWireResponseTest | tools/run_godot_serial.ps1 -Scene res://tests/ServiceWireResponseTest.tscn -LogPath (file) | 124 | TIMEOUT KILL at 180 s after SCRIPT ERROR: the test reads counter._counter_tap, a property main removed from maintenance_shop_counter.gd in 2082b4c (2026-08-27) while the test kept referencing it; the suite hangs on main and at 503465d (exit 124 there too). Pre-existing, not introduced by this close; the assertion on the counter prompt was updated to the ruled carrier-free text. |
| Godot OrisonV2M11C2ProductionMatrix (re-run) | res://tests/orison_v2_m11c2_production_matrix.tscn under the lane mutex, 1,500 s ceiling, -LogPath (file) | 0 | ORISON V2 M11C2 PRODUCTION MATRIX: PASS checks=26 failures=0 |
| Capture receipt re-merge | python tools/merge_m11c2_capture_receipts.py | 0 | M11C2 capture merge: PASS pairs=5 route=9 |
| Production export regeneration | python tools/m11c2_floor01_production/export_floor01_cells.py --write, then --check | 0 | PASS both; 38 artifact hashes identical across two Blender generations; 34 cell files byte-identical to 46d40e9 |

Data-consumption (reader) audit before/after: the audit is a report with zero
exceptions, exit 1 at both ends. Base **503465d**: FIELD_UNREAD 1,289, FILE_UNREAD 11, MALFORMED 1, DURABLE_NUMERIC_MONOTONIC_ONLY 2, blocking 1,303. This close: FIELD_UNREAD 1,288, FILE_UNREAD 11, MALFORMED 1, DURABLE_NUMERIC_MONOTONIC_ONLY 2, blocking 1,302.
Record-level comparison by kind, file and field: **0 new records, 1 record gone** (FIELD_UNREAD game/data/building_layout.json field mount). Zero new unread files, unread fields, malformed records or monotonic-only values are attributed to M11C2.
The DYNAMIC_MAP_PATHS_BY_SCHEMA table added to the audit is schema-scoped
classification (the registry's two identity maps are authored record
identities, values still traversed), not a baseline; no audit baseline was
changed to make a gate green.

Spatial dependency manifest: re-inventoried with --update-manifest (the only write path) because the lineage token left the Godot resource namespace; check mode then exits 0 (clean). Row-level delta against the pre-close working manifest: 1 row removed (the lineage token, asset_path res://assets/building/floor_01_cells/floor01_owner_first_lineage.json in floor01_cell_registry.gd, which left the Godot resource namespace); 220 rows changed, of which 214 are line-number re-resolutions only and 6 also re-resolved symbol/context/count after the M11C2 edits to building_root.gd, the registry, window_shot.gd and street_core_visibility_test.gd; 132 rows added, all new inventory of tokens that the chain's earlier accepted commits (M11A, M11B, M11C1 harnesses and tests) and the M11C2 test scripts introduced without re-inventorying (the manifest was last inventoried on main at 568a6c2): 7 in game/data/orison_v2_shared_frames.json (data, UNRESOLVED); 2 in game/scripts/building/floor01_cell_registry.gd (production, UNRESOLVED); 1 in game/tests/floor_residency_measurement.gd (test, UPDATE_TEST_FIXTURE); 2 in game/tests/orison_v2_blockout_guard_test.gd (test, UNRESOLVED); 7 in game/tests/orison_v2_blockout_guard_test.gd (test, UPDATE_TEST_FIXTURE); 5 in game/tests/orison_v2_blockout_test.gd (test, UPDATE_TEST_FIXTURE); 1 in game/tests/orison_v2_m11a_exterior_capture_lifecycle_test.gd (test, UPDATE_TEST_FIXTURE); 1 in game/tests/orison_v2_m11a_first_exterior_cell_shot.gd (test, UPDATE_TEST_FIXTURE); 1 in game/tests/orison_v2_m11a_first_exterior_cell_test.gd (test, REGENERATE_CONSUMER); 16 in game/tests/orison_v2_m11a_first_exterior_cell_test.gd (test, UPDATE_TEST_FIXTURE); 7 in game/tests/orison_v2_m11b_service_openings_shot.gd (test, UPDATE_TEST_FIXTURE); 1 in game/tests/orison_v2_m11b_service_openings_test.gd (test, REGENERATE_CONSUMER); 9 in game/tests/orison_v2_m11b_service_openings_test.gd (test, UPDATE_TEST_FIXTURE); 1 in game/tests/orison_v2_m11c1_owner_first/m11c1_capture.gd (test, REGENERATE_CONSUMER); 2 in game/tests/orison_v2_m11c1_owner_first/m11c1_capture.gd (test, UPDATE_TEST_FIXTURE); 1 in game/tests/orison_v2_m11c1_owner_first/m11c1_cell_registry.gd (test, REGENERATE_CONSUMER); 2 in game/tests/orison_v2_m11c1_owner_first/m11c1_consumer_adaptation.gd (test, UNRESOLVED); 1 in game/tests/orison_v2_m11c1_owner_first/m11c1_consumer_adaptation.gd (test, UPDATE_TEST_FIXTURE); 2 in game/tests/orison_v2_m11c1_owner_first/m11c1_harness_support.gd (test, REGENERATE_CONSUMER); 6 in game/tests/orison_v2_m11c1_owner_first/m11c1_harness_support.gd (test, UNRESOLVED); 10 in game/tests/orison_v2_m11c1_owner_first/m11c1_harness_support.gd (test, UPDATE_TEST_FIXTURE); 2 in game/tests/orison_v2_m11c1_owner_first/m11c1_marker_consumer_adapter.gd (test, UPDATE_TEST_FIXTURE); 1 in game/tests/orison_v2_m11c1_owner_first/m11c1_runtime_validation.gd (test, REGENERATE_CONSUMER); 2 in game/tests/orison_v2_m11c1_owner_first/m11c1_runtime_validation.gd (test, UNRESOLVED); 11 in game/tests/orison_v2_m11c1_owner_first/m11c1_runtime_validation.gd (test, UPDATE_TEST_FIXTURE); 1 in game/tests/orison_v2_m11c1_owner_first/m11c1_scanner_consumer_adapter.gd (test, UNRESOLVED); 1 in game/tests/orison_v2_m11c1_owner_first/m11c1_scanner_consumer_adapter.gd (test, UPDATE_TEST_FIXTURE); 1 in game/tests/orison_v2_m11c2_production_capture.gd (test, REGENERATE_CONSUMER); 7 in game/tests/orison_v2_m11c2_production_capture.gd (test, UPDATE_TEST_FIXTURE); 1 in game/tests/orison_v2_m11c2_production_matrix.gd (test, REGENERATE_CONSUMER); 2 in game/tests/orison_v2_m11c2_production_matrix.gd (test, UNRESOLVED); 18 in game/tests/orison_v2_m11c2_production_matrix.gd (test, UPDATE_TEST_FIXTURE). The 2 production-tier additions are the registry's facade-sharing rule ids F01_STREET_FACADE, F01_ORISON_INTERIOR_FACADE (id_candidate, UNRESOLVED, RUNTIME_LOOKUP): contract identities, not spatial ids; reported, not classified. The M11C2 KNOWN_CONTRACTS entries (asset_path and floor_reference F01 for the registry) were already in the pre-close manifest and are unchanged. universe_counts v2_blockout moved 316 to 318 by re-scan.

## Protected boundary

| Path | Baseline bytes | Bytes now | Baseline SHA-256 | Identical |
| --- | ---: | ---: | --- | --- |
| art/data/building_layout.json | 2,624,829 | 2,624,829 | 68838c933c0954092c63403f36ec7fb26d6c0956c01c23109465c680608b399d | yes |
| game/data/building_layout.json | 2,624,829 | 2,624,829 | 68838c933c0954092c63403f36ec7fb26d6c0956c01c23109465c680608b399d | yes |
| game/scripts/building/building_root_selector.gd | 1,461 | 1,461 | d2b3db95d72e4a418c0e7184e6b3368da723a945192024a10ee937ea604c9802 | yes |
| game/assets/building/floor_01.gltf | 682,906 | 682,906 | 906f1f48c2fc8ff6e6af3048d0abca46416cd103bee8d818606a3c32c71fe5b1 | yes |
| game/assets/building/floor_01.bin | 12,020,428 | 12,020,428 | e1d3454afb6079602b8cfe0dcb00d255e6aa68f7f247c5ecc39bd5791cfdc477 | yes |
| game/assets/building/floor_02.gltf | 166,867 | 166,867 | b3977546cabc72775ad63be53bfb2001ace51d13094b4ed8b719a979adc2d640 | yes |
| game/assets/building/floor_02.bin | 6,144,948 | 6,144,948 | 4b7d16ae8ed7df4a90f0626746ca5987bd02c61268f372fced86a3782760b69e | yes |
| game/assets/building/floor_03.gltf | 189,693 | 189,693 | 21c506695edf27effa20c711f1daed939c807a774f5076656e8ff3e8be898d3f | yes |
| game/assets/building/floor_03.bin | 6,245,068 | 6,245,068 | 8f84cb67f5f2fa8f2c5a5e47fbc418630957dbc8d6a96576e005c92ac6fcc9f8 | yes |
| game/assets/building/floor_04.gltf | 178,788 | 178,788 | c1a03abba15f481e6318e27d5035dae13e3e5173f16c2f208711769ce3bf8df1 | yes |
| game/assets/building/floor_04.bin | 6,417,828 | 6,417,828 | f57f45d79738086a5da23afd7d9a04d6f5596641193ec22856929de30b03e266 | yes |
| game/assets/building/floor_05.gltf | 184,558 | 184,558 | d5860b28c47a110fcced5b8cd22c0f5d4ae0fc036dfc0d44fbe884a2def41e7a | yes |
| game/assets/building/floor_05.bin | 6,335,272 | 6,335,272 | a8e7f0fd106696a1c6c9823f30cf013b0f664e4dac5d763fc2c3d2c072dd54d8 | yes |
| game/assets/building/floor_06.gltf | 175,408 | 175,408 | 96991ecf897b7882c68897eb9c8df5a678046e1567e8f59d51f21f6646209422 | yes |
| game/assets/building/floor_06.bin | 6,391,960 | 6,391,960 | 8389d2264ea4c6e4eb59fb35b58d7480b3823641c1471b593a85613883bd9f5f | yes |
| game/assets/building/floor_b1.gltf | 150,777 | 150,777 | f151ff10c8d2420340fc522df5e9eb2ffbdf200be6068b302c6769881af8eb3e | yes |
| game/assets/building/floor_b1.bin | 2,778,748 | 2,778,748 | 226437a3e2816882c04749918a4d99540ff2a4714d0a914b2dd2606ace8c4449 | yes |

Protected comparison against **design/ORISON_V2_M11C2_PREWRITE_BASELINE_2026-08-31.md**: **17/17 byte-identical**.
The asset manifest's own protected_hashes block matches the baseline for every row: **yes**.

## Push weight

Compressed pack for origin/main..HEAD before the close: 27,861,618 bytes (90,773,668 bytes of blobs uncompressed). After the close commits: 108,249,495 bytes compressed. The lineage JSON compresses about eightfold (1,935,982 bytes per blob). The 2026-08-31 blob remains in commit 46d40e9's history; relocating the file in a new commit adds one compressed copy rather than removing one. Removing it would require rewriting the tip commit, which this close did not do. The bulk of the pack is the frozen packet itself: 83,249,112 bytes of matched Forward+ captures, route frames, logs and receipts, committed as evidence.

## Remaining limitations and debts

- The rollback monolith intentionally remains committed. It is not loaded
  simultaneously with owner-first cells and is not v1-retirement debt.
- All 17 production cells remain resident by default. Independent
  addressability is proved, but no speculative streaming policy is added.
- The layout-to-bake wall-finish naming debt described by M11C1 remains
  historical authoring debt; M11C2 does not rewrite production layouts.
- **retail_bar_darts_door-1** remains the explicitly rejected inverted source
  record with zero emission; it may not be silently repaired or called new
  unresolved lineage.
- **ROOF_DOOR_01** remains an off-slice dependency and is not fabricated by the
  floor-01 cut.
- **NEWS/CIGARS** remains authored locked. Correct collision refusal is not a
  missing accessible-shop route.
- Aggregate ObjectDB drift across the matched run is an open lifecycle
  finding (above); owner-specific retention is zero.
- The exporter's protected and authoritative-input hashes are taken from the
  working tree, and the protected inputs (layouts, the monolith, the M11C1
  ownership sidecar) are still line-ending-normalized by git. Their hashes are
  therefore checkout-dependent between platforms; this close pinned only the
  new hash-bound artifacts. Open for the owner.
- The spatial inventory added two production-tier UNRESOLVED rows for the
  registry's facade-sharing rule ids, which are contract identities rather
  than spatial ids; they are reported, not classified green.
- The hardware counter's delegated service prompt still authors a legacy
  carrier that predates this chain on main; the T2 scan does not reach it and
  it was left as is.
- Two suites in the standard battery fail before and after this close:
  GoldenLoopTest (87/87 checks run, two objective-title checks fail, the
  same two at the accepted base 503465d) and ServiceWireResponseTest (script
  error on a counter property main removed on 2026-08-27, then a hang to the
  runner ceiling, on main and at 503465d alike). Neither is attributable to
  M11C2; both are open for the owner and were not repaired here.
- The production matrix exceeds the committed serial runner's 180-second
  ceiling and was run through a launcher that reproduces the runner's lane
  contract with a 1,500-second ceiling; the runner itself was not changed.
- Final technical equivalence, lifecycle closure and performance disposition
  are recorded above; human seam review remains pending.
- M09, root-selector cutover, v1 retirement, production-layout replacement,
  and main merge remain unauthorized.

## Decision

The implementation is eligible for a merge recommendation only if the final
receipts prove deterministic export, protected rollback bytes, full two-mode
world equivalence, unique semantic ownership, collision-bearing seams and
route continuity, exact semantic reconstruction, zero retained production-cut
owners, acceptable measured performance, zero audit regression, and an
inspectable matched packet.

Technical recommendation: **MERGE-CANDIDATE, subject to the open lifecycle
finding and the human packet review recorded above**.

Human review: **PENDING**.
