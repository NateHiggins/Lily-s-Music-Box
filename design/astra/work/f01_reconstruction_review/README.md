# Clean F01 owner-first reconstruction plan

Preparation only. No generator, Godot, worktree creation, asset adoption, selector edit, production edit, staging or commit was performed for this review. The base is `e72320288d256e4d20386e8f28c116fe962788fc`; current uncommitted foundation bytes are separately bound in `source_inventory.json`. Root owns those continuing repairs, so implementation must refresh the binding after they settle.

The next useful slice is to reconstruct the source-owned F01 export from attributable C1 inputs, then build the missing production provider against today's BuildingRoot. Replaying the dirty C2 branch is unnecessary. C1's isolated adapter receipt remains historical and human-pending; it is not acceptance of a production F01 cut.

## Accepted boundary and evidence

`design/astra/evidence/m11b_integration.json` records integration commit `cc95005d2c24b6be5cb04e728c5229c5d416954b`, source tip `a9e455bfede9f89193c9acd0796eb8fc5a0c3548`, and unchanged v1 selector/protected files. Its original `LANDED_VALIDATION_PENDING` status is an integration-time record, not a current replacement for later runtime receipts.

The human receipt `design/ORISON_V2_M11B_HUMAN_ACCEPTANCE_RECEIPT_2026-08-31.md` accepts the deliberate F02/F04 service hall/core openings implemented at `0ea23bfd1296a3779773886b1fc062f10288fa23`. The real source-to-runtime seam is `game/data/orison_v2_blockout.json` → `game/scripts/building/orison_v2_blockout.gd`; the opening geometry is derived from shared wall boundaries. It does not authorize an F01 geometry switch or assert completion of the full service spine. Retain its recorded darkness, tight F04 framing, southern riser choke and missing F03 lateral hall as scoped observations.

M11A/AA accepts the standalone exterior/bodega route composition, not mounting that geometry alongside legacy F01. The current semantic owners in `game/data/orison_v2/exterior/regions.json`, the exterior resolver, shop registry and exterior semantic state are usable contracts. Avoid double-loading their standalone geometry into a newly partitioned F01 that already contains the same frontage.

The retained independent forensic record is `design/astra/reviews/m11_review.md` and `.json`. C1 source reference is `c34ad283df148496fbd98e68638470835c930c5c`; its final closure document is at `503465defa24d19d55b53c9a17bf8a4affdfb5eb:design/ORISON_V2_M11C1_OWNER_FIRST_EXPORT_CHECKPOINT_2026-08-31.md`. C2 committed reference `46d40e9a916ffa7c7cc2ae5031fa6bcbcdeb7777` and the dirty C2 snapshot stay provenance/comparison evidence.

## Inputs that can be reconstructed cleanly

The current `art/data/building_layout.json`, its `game/data` mirror, `art/data/gen_layout.py`, and `art/blender/scripts/build_orison.py` match the C1 source after Git's CRLF/LF materialization. The two layouts' actual Windows byte hash is `68838c933c0954092c63403f36ec7fb26d6c0956c01c23109465c680608b399d`, exactly the raw layout hash declared by the C1 sidecar. Git blob hashes and raw file hashes are intentionally separate in the inventory; no normalization was written to disk.

All 17 protected paths have the same accepted-M11B, C1, current HEAD and clean-filtered worktree Git blobs. The raw hashes of both layouts, selector and seven glTF/bin pairs are retained individually. The roof, 304 referenced image dependencies, generator and other current sources remain read-only too; being outside the historical 17-path list does not permit modifying them.

The smallest attributable export dependency closure is eight files, all at `c34ad283`:

- `art/data/m11c1/floor01_source_ownership.json`.
- `tools/rehearse_orison_floor01_partition.py` (C0's asset reader, canonicalizer, cell writer and recomposition helpers; using these helpers does not accept C0's failed partition).
- Six Python files under `tools/m11c1_floor01_owner_first/`: `__init__.py`, `source_ownership.py`, `author_source_ownership.py`, `generate_owner_first_candidate.py`, `owner_first_export.py`, `run_disposable_export.py`.

The catalog explicitly owns all 5,286 source records: 4,415 furniture, 188 markers, 42 walls, 16 rooms, 26 ceilings, 3 vent registers, 30 sockets, 565 site lights and one slab. It uses authored context and durable IDs, not bounds or post-export material grouping. Preserve the `98cc6c1` correction assigning the 11 shared-shopfront stallboards to `CELL_PASSAGE`, and the three explicitly ruled street-common window-card lights. An older pre-correction catalog is not a substitute.

There are 17 explicit owners: Orison F01 interior, facade shell, street common, Passage, bar, bodega, and the eleven named Passage shops. Historical C1 output reports 609 primitives, 183,726 triangles, 345,536 referenced vertices, 189 semantic owners and all 531 legacy geometry aliases (47 expand to multiple targets). These are reproducibility targets to verify afresh, not current runtime passes or adjustable baselines. `CELL_LEGACY_MIXED` and unresolved lineage are refusals.

Generation depends on the current authored layout and `build_orison.py` helper definitions plus Blender's bundled `bpy`. Python dependencies are otherwise standard-library modules. The 304 material images and 30 wall-finish texture aliases are read-only dependencies. Preserve the known `f01_w00..09` / `f01_wall_00..09` naming relationship rather than renaming textures. The authored inverted `retail_bar_darts_door-1` box has a receipted zero-emission result; do not add geometry merely to remove that exception.

The current generator ends with an unconditional build sentinel at line 4688. Never import it directly. C1's adapter checks for exactly one known sentinel and suppresses it before loading definitions, then exports only into an empty external directory. C2's later `ORISON_DEFINITIONS_ONLY` generator edit is not required for this clean replay. A future generator change should cause the old adapter to refuse until deliberately reviewed.

## Deterministic replay sequence after implementation authorization

First materialize only the eight reviewed C1 dependencies into their expected repository-relative locations, verifying the Git blobs listed in `source_inventory.json`. Do not copy a historical project, current dirty C2 source, protected layout, selector, or generated C2 asset. Extract Git object bytes with a byte-preserving tool rather than shell text redirection. Record any intentional line-ending difference and bind the actual executed bytes in the new receipt.

Commands below are proposed, **not executed**. They assume those dependencies have been deliberately installed into `C:\PleaseRemainOnTheLine-astra`. Use fresh nonexistent/empty external output paths; never reuse an old evidence directory.

```powershell
Set-Location -LiteralPath 'C:\PleaseRemainOnTheLine-astra'
python tools/m11c1_floor01_owner_first/source_ownership.py --root 'C:\PleaseRemainOnTheLine-astra' --json
python tools/m11c1_floor01_owner_first/author_source_ownership.py --root 'C:\PleaseRemainOnTheLine-astra' --check
python -m unittest tools.tests.test_m11c1_floor01_source_ownership tools.tests.test_m11c1_owner_first_export
python tools/m11c1_floor01_owner_first/run_disposable_export.py --output 'C:\OrisonF01Reconstruction\export_a_01' --blender 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
python tools/m11c1_floor01_owner_first/run_disposable_export.py --output 'C:\OrisonF01Reconstruction\export_b_01' --blender 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
```

The two named tests are additional C1 files under `tools/tests`, included in the inventory's rehearsal/test group. Run them only after they are materialized. Check both real exporter process exits, exactly one Blender summary marker, all source bindings, canonical equivalence, complete transaction artifact hashes and both before/after protected-path censuses. C1's own wrapper guards a narrower set than all 17; the new outer controller must enforce the full current protection manifest on every stage and refusal. Preserve full stdout/stderr separately: the historical wrapper stores their hashes but does not itself retain the raw streams.

Compare the candidate and all 17 cell glTF/bin pairs across two fresh runs (36 files). Do not compare host-path-bearing receipt bytes as if those were portable deterministic artifacts. Independently compare the semantic owners, alias target sets, triangle/collision/material/transform census and canonical lineage. A changed input or result must remain a difference to investigate, not trigger a baseline rewrite.

For the attributable isolated rehearsal, the additional closure is listed exactly in `source_inventory.json`: the C0 seam/capture manifest, the C1 runtime config schema/preparer/README, all nine C1 harness source/scene files with their available UID sidecars, and four C1 Python test files. The preparer copies current project code/data plus literal and enumerated dynamic assets into a scratch project. It includes an engine import internally, so it requires the exclusive Godot lane despite being a Python command.

```powershell
python -m unittest tools.tests.test_m11c1_runtime_rehearsal tools.tests.test_m11c1_scanner_consumer_adapter
python tools/m11c1_floor01_rehearsal/prepare_runtime_rehearsal.py --export-root 'C:\OrisonF01Reconstruction\export_a_01' --scratch-root 'C:\OrisonF01Reconstruction\scratch_a_01'
$env:M11C1_MODE = 'runtime'
$env:M11C1_RUNTIME_CONFIG = 'C:\OrisonF01Reconstruction\scratch_a_01\m11c1_runtime_config.json'
$env:M11C1_RUNTIME_RECEIPT = 'C:\OrisonF01Reconstruction\scratch_a_01\m11c1_receipts\runtime_01.json'
& .\tools\run_godot_serial.ps1 -ProjectPath 'C:\OrisonF01Reconstruction\scratch_a_01' -Scene 'res://tests/orison_v2_m11c1_owner_first/m11c1_owner_first_harness.tscn' -LogPath 'C:\OrisonF01Reconstruction\scratch_a_01\m11c1_receipts\runtime_01.stdout.log' -TimeoutSeconds 180
```

Give import/runtime/capture an isolated APPDATA and a frozen source interval in the outer controller, then restore task-specific environment values afterward. The installed Blender 5.2 and Godot 4.7.1 binary paths/hashes are recorded without launching them. Capture uses the same scratch path, `M11C1_MODE=capture`, a fresh `M11C1_CAPTURE_DIR`, windowed Forward+ at 1600×900. Verify actual `res://` import mappings and `-col`/`-colonly` collisions; raw external glTF loading was diagnostic only. This C1 harness must be reviewed against current autoload contracts before running; its old adapter result cannot substitute for the real-root proof below.

## Production work to prepare after export equivalence

1. **Stable deployment artifacts.** Derive a new allowlisted 17-pair output bundle plus lineage, compatibility aliases, asset manifest and runtime registry from the just-verified export. Suggested existing destination convention is `game/assets/building/floor_01_cells/` and `game/data/floor_01_cell_registry.json`; nothing exists canonically at those paths today. The committed C2 exporter describes stable URI rewriting and the 38-file deployment allowlist, and may be reviewed as an algorithm reference. Do not copy its generated bytes or inherited `status: PASS` claims. Its `default_mode=owner_first_cells` is a production policy change and must not enter through an otherwise descriptive registry. Keep the current canonical mode while proving an explicit candidate session.

2. **Current production provider.** Build a real registry/provider that validates hashes, unique owner IDs, dependencies, cycles, semantic ownership and one-to-many alias targets before exposing cells. Preserve a geometry-free F01 host for service/director ownership. Refuse simultaneous monolith and cells. Define loading, resident, unloading and unloaded states with a deterministic teardown protocol. A descriptor saying `unload_destroys_durable_authority=false` does not prove that property; the production owner must be exercised.

3. **Current consumer integration.** Adapt actual BuildingRoot discovery/indexing and consumers to the provider, not a test-only registry or adapter. Existing aliases must return every target, with stable source/owner metadata available to scans; do not truncate the 47 one-to-many aliases to a first node. A cell unload must remove its own render/collision/index/listener registrations while preserving unrelated resident cells and persistent gameplay owners. Repeated load must not duplicate radios, props, service counters, audio, nav links or affordances. `consumer_review.md` supplies the independent exact current-file map; any unavailable consumer remains a named gap rather than an inferred compatibility pass.

4. **Actual-root proof and review.** Construct the current real BuildingRoot through CampaignShell with the candidate provider, then perform real player collision/threshold traversals, full and selective residency changes, repeated unload/reload, and save/reconstruction. Preserve the current renderer's SubViewport-world boundary, exact mask restoration, audio owner teardown, protected save/load and campaign clock contracts, timestamp provenance, and newly repaired resident portal/lift approach rules. Do not restore historical C1/C2 versions of these files. The unmodified selector remains part of the 17-file guard. A candidate geometry-mode proof is separate from accepting it as the canonical default.

These are ordered implementation batches, not a new authority layer or a request to redo sanitation. The source/export work can be made concrete first. A reviewed real-root provider and its consumers are the next missing substrate, before extending the street threshold or F03 vertical proof.

Concrete prospective file boundaries are:

| Slice | Paths | Treatment |
| --- | --- | --- |
| Source/export | The eight C1 paths above; two focused Python tests | Materialize attributable clean source, then make any necessary current compatibility delta reviewable. |
| Deployment | `tools/m11c2_floor01_production/export_floor01_cells.py`, its `tools/tests/test_m11c2_floor01_production_export.py`, the 38 generated destinations listed in the inventory | These are existing committed reference paths, not approved code/output. Review the stable deployment algorithm, remove implicit cutover policy, and regenerate from new receipts before installing an allowlist. A newly named exporter is also possible; do not keep an old milestone name as a claim of acceptance. |
| Provider | Proposed `game/scripts/building/floor01_cell_registry.gd` and `floor01_geometry_configuration.gd` | These names appear in the retained dirty snapshot but have no canonical implementation. Reconstruct the needed contract afresh; do not adopt their untracked bytes. Keep mode configuration session-scoped and outside save authority. |
| Actual root/consumers | `game/scripts/building/building_root.gd`, `surface_pass.gd`; only demonstrated needs in `game/scripts/dream/campaign_shell.gd`, `game/scripts/game/maintenance_shop_service.gd` and the consumers mapped separately | Narrow modifications against current source. Preserve F01 parent/markers, class and alias metadata, owner-specific release, and current immediate root destruction. Many consumers can remain unchanged if the provider supplies their existing contract. |
| New proof | New focused registry/provider lifecycle fixtures plus existing `StreetCoreVisibilityTest`, `PassageVisibilityTest`, FirstShift/M08F and the current two-root matrix | Fresh source-bound controls through existing serial runners. Historical C1/C2 fixture names or counters do not establish new runtime coverage. |

The test names in the last row refer to the canonical scene/script contracts, not an instruction to run them during this read-only task. Do not introduce placeholder providers or a registry consumed only by a fixture and then call the substrate complete.

## Required negative controls and limits

- Remove or duplicate one ownership row, change a source record, use an unknown owner, restore the pre-correction stallboard owner, or corrupt a source binding: exporter refuses before production writes.
- Remove one alias target from a known one-to-many alias, corrupt a cell hash, introduce a cycle or duplicate semantic owner, or request unknown/simultaneous modes: registry refuses; no partial live cell composition is accepted.
- Omit one actual source-owned runtime family through a test fixture route, or omit one real index entry: independently sourced coverage fails. Keep both protected layout files unchanged in such controls. The unresolved Harukiya `>250` historical threshold stays separate; a new cell count cannot silently close it.
- Unload a real cell with active owned interaction/audio/dynamic children, retain a neighbor, reload twice, then reconstruct through CampaignShell: assert exact expected owner counts, no stale indices/weak references or retained registrations, actual neighbor preservation and clean teardown. Do not mute/reset global systems to hide lifetime failures.
- Persist and reload a meaningful current job/item/dream/clock state through the cell lifecycle. Geometry mode and engine nodes never become durable save authority. Include the accepted route/threshold IDs and idempotent shop-service behavior; bodega's prior no-order refusal does not prove every fulfillment path.

Named anchor compatibility includes `F01_DOOR_06`, `F01_LOBBY`, `F01_BODEGA_DOOR`, `F01_BAR_DOOR`, `THRESHOLD_SHOP_BODEGA_FRONT`, `PASSAGE_PORTAL_LT_W/E`, every `SITE_SHOP_*` identity, `LobbyMailBank`, `LobbyPorterBoard` and `F01_HOUSE_TELEPHONE_BOARD`. F01 door and threshold IDs are distinct contracts. Keep off-slice floor/unit/room/case/service anchors available; `ROOF_DOOR_01` is not to be fabricated inside an F01 fixture. Room IDs retain their acoustic and save meaning.

No dynamic streaming/performance claim follows from having all 17 cells independently addressable or initially resident. C1's isolated lifecycle/capture claims, C2's 26-check matrix and pending human report, and current real-root measurements have different scopes. Reconstructing the data is supportable; accepting a complete F01 production cut still requires the new provider/consumer/runtime evidence and review of the actual composition.

## Review artifacts

- `capture_inventory.py`: read-only Git/file/hash inventory; writes only the adjacent report.
- `source_inventory.json`: exact C1/C2 dependency paths/blobs, current protection hashes, 304 image dependencies, installed binary hashes and the separate current foundation snapshot.
- `consumer_review.md` / `consumer_review.json`: independent current consumer/provider map from branch_forensics; twelve contracts and fifteen exact source hashes.
- `review_checks.json`: preparation-only checks; all protected raw bytes still match the inventory, both JSON documents parse, and current consumer source bindings match.

The only executed validation in this task was the read-only inventory and source inspection. No regeneration or runtime result is claimed.
