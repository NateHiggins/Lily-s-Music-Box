# REPORT - Vorticella maintenance guide-bells - 2026-10-25

Evidence class: **INERT**

Implementation report; no completeness-ledger promotion or merge recommendation.

Branch / HEAD / origin/main / merge-base:
**codex/v2-acoustic-topology** /
**7a548239e3fddba395341e05fcb3be6ec583ae3e** /
**20b7fee5f2122dd44065623e0d13b47794a56fc8** /
**7a548239e3fddba395341e05fcb3be6ec583ae3e**.
The existing shared checkout was reused without switching its branch. The
checkpoint is assembled in an isolated index on **origin/main** at
**f18d87c8da869df2e6aff6ef18e313438b737e82**, preserving other agents' staging.

Worktree clean at end: **no**. The checkout already contained extensive parallel
work. This task adds guide-bell runtime, native Blender source/GLB/custom maps,
two contract scenes, review artifacts and documentation. Shared integration
edits are limited to the V2 runtime mount, two maintenance eligibility flags,
their library validation, two catalogue entries, texture import policy and DOCS.
Other agents' edits are retained.

Protected 17/17: **unchanged against HEAD**; selector remains **v2** with explicit
V1 rollback. The historical protected receipt was not edited.

Ledger before -> after: **not measured -> not measured**;
requirements_changed: **none asserted**. Both design documents are inert.

## Implementation and numbers

A read-only maintenance adapter constructs candidates from authored spaces,
portals and native stair landings. Loaded collision sweeps and floor samples
must prove every route leg; unavailable routes produce no trail. The same
polyline supplies placements and remaining route metres. Cells attach to real
floor/wall seams, point to the next waypoint, retain fixed holdfasts, and keep
clear of doors and repair controls.

The window is at most eight cells, with 2.75 m placement spacing, a strict
0.55 m passing margin and 0.4 s confirmation. Germination/wilt/retraction take
1.3/1.6/0.85 s. Consumed positions do not regrow on backtracking. Cancellation,
unloading and invalidation release geometry and shared lamp registrations.
Private Euplotes presentation instances never enter the hunting authority.

The native export has eight meshes and 21,208 triangles, with zero collapsed
UV triangles. Six authored source maps provide custom PBR inputs. The owner's
visual revision adds soft purple density mottling and thinner, clearer membrane
patches while retaining the thicker rim and senescent clouding. It uses scene
light transmission rather than uniform alpha fading or intrinsic emission.

The owner's follow-up also applies the same mottling to the tardigrade/Euplotes
shared membrane maps and the tentacle gang's membrane/tissue maps. Those
generators modulate scalar brightness and roughness, preserving mean RGB and
the existing species tints. Mineral and eye maps and all anatomy/behavior are
unchanged. These additional edits are in **build_tardigrade_maps.py** and
**build_tentacle_gang_maps.py** and their generated outputs; render checks are
captured separately from the guide-bell integration test. Tardigrade/Euplotes
passed **103 checks** and the tentacle gang passed **381 checks**, both with
empty failure lists. Their schema-2 receipts and process receipts are in
**art/reviews/cellular_mottling_20261025**. The tentacle implementation itself
belongs to parallel work not yet on the checkpoint's base; its palette-preserving
generator patch and four changed maps are also saved there for integration.

## Gates and scoped evidence

- Reader baseline: **exit 0, NEW 0**.
- Surface/data-consumption tools tests: **exit 0, 61 tests OK**.
- Exported native UV check: **exit 0, PASS**; review artifact
  **art/reviews/vorticella_guide_bells_20261025/native_uv.json**.
- Brief design lint and tracked-path whitespace checks: **exit 0**.
- Final optical/lifecycle runtime: **60 checks passed**, no engine errors,
  **tmp/guide_bell/mottled/runtime_contract.json**; runner process receipt
  **tmp/guide_bell/mottled.log.receipt.json** reports **exit 0**.
  Front, side, back, lamp-off, wilt, retraction and clean frames were captured.
- Route regression after the support fix: **60 checks passed**,
  **tmp/guide_bell/route_regression/runtime_contract.json** and
  **tmp/guide_bell/route_regression.log.receipt.json** (**exit 0**).
- Composed-world run: **exit 1**, solely the primary inter-floor route assertion.
  Placement, monotonic progress, static attachment, control clearance, route
  legs, unchanged task authority, cancellation and engine-error checks pass.
  **art/reviews/vorticella_guide_bells_20261025/world_runtime_contract.json**
  and **world_suite_run.json** preserve the actual failing result.
- Full gate board, completeness/spatial/systemic/period comparison and candidate
  verifier: **not run**. No clean merge-base board or merge candidate is asserted.

Changes outside the expected file boundary, and why: **none by this task**.
The preexisting unrelated working-tree changes remain outside its scope.

Open findings not fixed: the composed-world primary stair route remains rejected,
although all seven native-shell stair legs and the complete shell route pass
**GuideBellRouteDiagnostic**. Next inspect per-leg rejection reasons in the
composed world, including added blockers and the bounded search. Do not relax
collision checks to force a path. Placement now passes after using the physical
inspection point and trying nearby clear seams. The generator was made independent
of the changing tentacle build script and its final export passes native UV
checks; reimport and windowed review of that final export remain to be run.
Stair paths preserve separate ramp and landing endpoints. Moving lift
travel is deliberately not accepted as an edge; no valid stair alternative
means no guidance. World observation positions are fixtures, not played travel.

Decision needed from owner: **none**.

BLOCKED composed-world stair route and final independent-export review; checkpoint only
