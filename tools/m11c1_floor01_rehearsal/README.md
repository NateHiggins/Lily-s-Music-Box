# M11C1 owner-first target-cell rehearsal

This directory defines the input contract for the test-only M11C1 runtime and
capture harness in `game/tests/orison_v2_m11c1_owner_first/`.  The harness runs
against the real game project so it can instantiate the production
`PlayerController`, `ResidentNav`, save authority, and M11A exterior scene.  It
does not replace `BuildingRoot`, redirect a production consumer, change the
selector, or write any production asset.

The owner-first exporter writes its cells anywhere disposable. The preparation
tool copies the exact cell GLTF/BIN pairs into an ignored, detached scratch copy
of the `game/` project, imports them there, and generates `cell_resources` from
the partition hashes. Runtime import of an absolute GLTF is diagnostic only;
every collision, navigation, PlayerController and capture proof requires an
imported `res://cells/*.gltf` resource so the real `-col` / `-colonly` importer
contract is present. Never run the import step in the protected source worktree.

## Inputs

Set `M11C1_RUNTIME_CONFIG` to an absolute path or a `res://` path containing a
JSON object with schema `orison.m11c1.target-cell-runtime-config.v1`.  The JSON
Schema in `m11c1_runtime_config.schema.json` is the normative shape.  The
harness additionally enforces these semantic invariants:

- `partition_manifest` names the exporter's
  `owner_first_partition_manifest.json` and that manifest names exactly the 17
  target cells. `CELL_LEGACY_MIXED` is forbidden.
- `lineage_manifest` and `equivalence_receipt` name passing machine receipts.
  Every lineage output cell must be declared, and unresolved lineage must be
  zero before runtime work begins.
- `protected_source` names the actual scratch-project
  `res://assets/building/floor_01.gltf` and `.bin`; both are hashed at runtime
  and must exactly match the partition's `source.protected_hashes` pins.
- `cell_resources` maps every target cell ID to the exact imported
  `res://cells/*.gltf` named by the partition. The harness hashes that source
  GLTF and its sibling BIN both in the export transaction and under `res://`,
  rejecting stale, swapped, or detached imports.
- `residency_sets` declares the canonical Orison-plus-facade,
  street-plus-facade, Passage, thirteen shop-only, and full-recomposition sets
  exactly. Membership is checked against the fixed owner-first design; it is
  never derived from scene names or positions.
- `semantic_expectations` is an exact, explicit list of compatibility identity
  and owner-cell pairs. It must cover every identity present in lineage. The
  five special identities are mandatory, every discovered `SITE_SHOP_*`
  identity must be covered, and the v1 `F01_BODEGA_DOOR` must remain distinct
  from `THRESHOLD_SHOP_BODEGA_FRONT`.
- `seams` declares explicit cells, start point, forward waypoints, return
  waypoints, crossing plane, authored opening bounds, production-capsule
  clearance floors, grounded floor (never below 0.90), and positive expected
  collision-owner cells.
  The five dangerous seam IDs are mandatory. Passage/shop coverage must name
  the eleven Passage-fronting shop cells (bar and bodega are not Passage
  shops), and one traversal must be
  `PASSAGE_SHOE_REBUILDING_BIDIRECTIONAL`. The separate historical regression
  probe `M11C0_PASSAGE_AISLE_WEST_055` repeats the original vertical ray from
  `(11.02, 2.0, 45.0)` to `(11.02, -1.0, 45.0)`: it must hit `CELL_PASSAGE`,
  never `CELL_SHOP_SHOE_REBUILDING`, at the former 0.55 m intercept.
- Ten Passage shops exercise real `DoorProp.interact()` open contracts and
  bidirectional PlayerController crossings. NEWS & CIGARS exercises the real
  locked refusal and a customer-side ResidentNav service destination; it is
  never misreported as physically crossable.
- `capture_views` gives authored eyes/targets and exact cell lists for all five
  dangerous seams. Capture uses the production PlayerController camera and
  flashlight, applicable real detail passes, and the production M11A
  environment resource without importing M11A geometry into the cell view. A
  luma gate, target-occlusion ray, hashes and per-frame lifecycle gate apply.
- `resident_nav_queries` gives semantic test endpoints. They are executed by a
  real `ResidentNav` built from an F01-only view of the unchanged layout and
  collision-validated against the active target-cell world.
- `save_reconstruction` supplies `state_id`, `route_id`, `waypoint_id`,
  `threshold_id`, and the canonical 17 `required_cell_ids`. The harness mounts
  all cells and the real M11A scene, records through
  `OrisonV2ExteriorSemanticState`, saves through `RealityState`, publicly tears
  down every root, loads, mounts fresh roots, resolves the semantic cursor and
  consumes the public route placement with a grounded production player. It
  restores all RealityState globals/signals and rejects GLTF paths, NodePaths,
  selectors, and raw world coordinates.

Relative paths are resolved against the JSON file that contains them. Every
input file is SHA-256 receipted.

## Runs

From the repository root, after the disposable cells have been imported into
the scratch game project:

```text
M11C1_MODE=runtime M11C1_RUNTIME_CONFIG=C:/scratch/m11c1_runtime_config.json godot --headless --path game res://tests/orison_v2_m11c1_owner_first/m11c1_owner_first_harness.tscn
M11C1_MODE=capture M11C1_RUNTIME_CONFIG=C:/scratch/m11c1_runtime_config.json M11C1_CAPTURE_DIR=C:/scratch/captures godot --path game --resolution 1600x900 res://tests/orison_v2_m11c1_owner_first/m11c1_owner_first_harness.tscn
```

`M11C1_RUNTIME_RECEIPT` and `M11C1_CAPTURE_RECEIPT` override receipt paths.
Runtime performs one unreported cache warm-up (including the named F01 scanner
consumers) followed by two complete,
reported load/unload cycles. Each cycle measures every cell independently,
every required residency set, full recomposition, consumer adaptations, real
bidirectional controller traversal, scoped production navigation, save/root
reconstruction, and public teardown. BuildingRoot loading/index/visibility is
explicitly an isolated adapter contract; the F01 scanner census executes the
real HeightmapPass, SurfacePass, AtmosphericDecalPass, BroadcastDirector,
ArcadeRow, FurnitureInteractionPass, FoundArtPass, DomesticWitnessSystem,
ApartmentEncroachment applicability, and resident-floor binding APIs. Capture
requires Forward+ at 1600x900 and emits one PNG per authored view plus lifecycle
and render receipts.

Exit `0` means PASS. Exit `2` means a failed invariant. Exit `3` means the
configuration or import mode left an explicitly reported proof blocker.
