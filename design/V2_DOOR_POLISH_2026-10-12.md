# REPORT — V2-DOOR-POLISH — 2026-10-12

Evidence class: **INERT**. Section 7 implementation report. No whole-world
photorealism, human acceptance or completeness promotion is claimed.

Branch / starting HEAD / origin/main: **main / 8e762f49 / 8e762f49**.
Clean comparison baseline: **09d0d75d**. Owner decision required: **none**.

## Changes and boundary

Domestic leaves use six source-sized Blender families, with separate stiles,
rails and raised panels, eased edges and grain-oriented metre UVs. Their
original entry/interior colors remain. Actual key passages run through the
wood and existing escutcheons. Service leaves retain their original bracing
and receive pierced native inserts. Solid actor collision remains deliberate;
the small visual keyway does not become a player collision aperture.

The entrance receives eased oak joinery, a dedicated oak finish, fitted native
locksets, thumbpieces and offset pulls, and finer wire inside the glass. Pull
shoes meet the recessed panel and top rail. The timber and both plates share
an actual keyway. The old thick-door hardware proxy is replaced; the later
closer, panic bar, sealed mail slot and bell remain. Door motion, keys, save
state and acoustic ownership retain their existing implementations.

Three catalogue materials are added: **door_oak**, **door_brass**, and
**door_paint**. Oak uses a new unlettered built-in imagegen source and the
established ingest recipe; derived normal/roughness are approximations,
not measured scans. Brass and paint use deterministic periodic maps with
micron-scale relief. Resident paint colors share material instances. Source
images, recipes and mipmapped shipping imports are retained in the repository.
Existing material definitions and 196 original runtime map files are unchanged.

## Native and focused verification

The domestic builder checks 42 closed positive-volume stocks across six
families. Its 12,480 exported triangles pass strict normal, UV and tangent
derivative validation. Submicron bevel artifacts were welded before export;
no validator tolerance was weakened. Neutral narrow/wide leaf and hardware
detail renders were reviewed.

The façade contains 510 closed positive-volume stocks, 61 bounded draws and
36,635 triangles. Eighteen native rays check the timber/plate bores and solid
neighboring material. Export derivatives pass. Exact zero-area tessellation
helpers at collinear Boolean boundaries are omitted from the render mesh;
closed native construction remains available for inspection. Three native
façade views and installed entrance views were reviewed.

The focused Godot check covers four door kinds and all six native size
families: **64 checks, zero failures**, including actual imported UV charts
and clear visual-mesh key passages. The shared façade review additionally
checks actual composed bores, leaf sweep, source bearings, reachable neon
inspection and supported capture stations.

## Provenance and gates

Regenerating the façade plan changed edge segmentation from 130 to 138; the
merged per-owner wall spans are identical. Door, window, blade and entrance
dimensions are unchanged. Adding paint subsequently produced a byte-identical
façade export, allowing its unchanged native review to be reused.

The additive-material tool now accepts several keys in one proven addition.
Its explicit baseline-drift option leaves stale bindings stale only when the
entire fixture payload matches the baseline. It does not renew acceptance or
ignore changed geometry. Five guard tests reject changed geometry, changed
parts, rewritten bindings and missing bindings. Four current provenance
records were refreshed; 804 pre-existing stale bindings remain unresolved.
One new test-generated identity was added to the spatial manifest; prior
records are preserved. The separate unfinished apartment-route edit is
excluded from this batch.

## Remaining scope

Kitchen faucet reconstruction, sink-to-stand fitting and hot/cold operation
checks are the next requested batch. Full V2 remains incomplete, including
the broader room/route, world-development and completion requirements.
The final composed surface run passed 23,917 checks with zero failures and
zero script errors: 23,486 draws, 16,232 meshes, 5,829 materials and 443 textures.
Shared paint instances remove 90 redundant materials; native domestic leaves
remove 114 draws from the preceding door configuration. The first-slice
authority/save/reconstruction suite completed with zero failures. These are
scoped runtime contracts, not proof that all V2 areas are complete.

Reviewed renders and wrapper receipts are in
**art/renders/orison_v2/door_polish_20261012**. Current schema-2 runtime
contracts remain in the canonical surface and first-slice packets.
Clean candidate verification is pending before publication.
