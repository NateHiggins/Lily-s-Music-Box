# Clean C1 source replay preparation

This new directory contains exactly the eight reviewed export dependencies and two focused tests from clean C1 reference `c34ad283df148496fbd98e68638470835c930c5c`. All ten files were extracted directly from their Git blobs and match the prior `source_inventory.json` blob IDs, byte counts and SHA256 values. No source was taken from committed or dirty C2.

The current canonical context is `9c12f19cf468d81c76369aca8a4f545a2129240b`, which adds the verified campaign-time/hearing slice to e723. Current material, renderer and navigation candidates remain separate. These source files do not replace any of those production owners.

`tree/` preserves the intended repository-relative paths for review:

| Role | Path within tree |
| --- | --- |
| Authored ownership catalog | `art/data/m11c1/floor01_source_ownership.json` |
| Package | `tools/m11c1_floor01_owner_first/__init__.py` |
| Authorship check | `tools/m11c1_floor01_owner_first/author_source_ownership.py` |
| Blender adapter | `tools/m11c1_floor01_owner_first/generate_owner_first_candidate.py` |
| Export validation and composition | `tools/m11c1_floor01_owner_first/owner_first_export.py` |
| Disposable process controller | `tools/m11c1_floor01_owner_first/run_disposable_export.py` |
| Source ownership validator | `tools/m11c1_floor01_owner_first/source_ownership.py` |
| Existing C0 asset/recomposition helpers | `tools/rehearse_orison_floor01_partition.py` |
| Focused ownership test | `tools/tests/test_m11c1_floor01_source_ownership.py` |
| Focused exporter test | `tools/tests/test_m11c1_owner_first_export.py` |

`source_manifest.json` binds every exact extracted byte sequence, its source Git object and its local destination. Nine Python files parsed with `ast.parse`, and the catalog parsed as JSON. No replayed Python module was imported, no test ran, and neither the generator nor Blender/Godot executed. AST validity is not a test result or export-equivalence proof.

The catalog retains its existing 5,286 source records, 17 explicit owner cells, three explicit owner rulings and declared source-layout binding. Its milestone/status vocabulary is historical source data. This preparation does not promote the human-pending C1 rehearsal or accept an F01 geometry cut.

The replay directory is **not an executable project**. Several copied files compute their repository root from `__file__`; from here that root is `tree/`, which intentionally lacks the protected authored layout, current generator, runtime assets and material textures. `generate_owner_first_candidate.py` imports Blender's `bpy`. Do not run these files from the review directory and interpret missing dependencies as a production failure, or silently redirect their root into live data. Root will review a concrete installation/execution boundary before actual source/export work.

No extracted source path existed at its live repository destination during preparation. No live `game/`, `tools/` or `art/` file was installed or modified. The 17 protected paths' HEAD/index Git blobs and file size/mtime metadata were checked before/after and remained identical. Their raw bytes were not broadly rehashed while another agent owned the engine lane; this is an exact write-scope and metadata check, not a new raw asset census.

After review, the next batch can install only this ten-file allowlist into an explicitly chosen execution context, rebind its actual materialized bytes and all protected/current input dependencies, then run the focused Python tests and a disposable export through an outer controller. That controller still needs the full 17-path protection boundary, raw stdout/stderr and exact process exits, two fresh export destinations, and independently checked ownership/alias/canonical equivalence. Existing C1 wrappers alone do not prove current production provider or consumer behavior. The broader plan and missing provider/alias contracts remain in the parent directory's README and consumer review.

No live selector, floor assets, generated cells, registry/provider, baseline or acceptance record is part of this source replay.
