# V1-to-V2 import continuation

Evidence class: **INERT**

REPORT - Import preparation and dossier closeout - 2026-10-08

Branch / starting HEAD / origin/main / merge-base: **main / 0aaf3b17 / same / same**.

The owner dossier is complete and pushed: **37db375a** implements the final
batch and **0aaf3b17** records verified completion. Its 40 cards comprise 39
reviewed items and conditional **G15**, which stays uninstalled. The
[illustrated review](../output/pdf/V2_dossier_implementation_review.pdf) and
[final report](ORISON_V2_OWNER_BUILDING_FINISHES_2026-10-08.md) retain the exact
scope and limitations. Broader V2 geometry, textures and world acceptance
remain open. No dossier implementation or verification run is waiting to finish.

The [coverage index](../art/blender/v2_fabrication_coverage.md) removes superseded
household, cord, shop and skyline finish obligations. The regenerated inventory
records 200 spaces and 90 installed-data files. The
[planner baseline](../art/data/v2_import_resume_20261008/fabrication_baseline.json)
has 102 registered families, 34 with historical source drift, zero missing
registered inputs and 69 builders outside its fixture convention. A repeat
snapshot has zero changed families. These are discovery counts, not completion
percentages; unchanged fingerprints do not erase historical drift.

## Next batch: street paving and entrance boundaries

Start with eight existing pavement joints, five curb-coping records, four
passage paving slabs and three wet-surface patches. The
[resume manifest](../art/data/v2_import_resume_20261008/resume.json) freezes these
20 targets and seven collision/route context records, including poses and roles.
Authority is **TEMPLATE_STREET_SEGMENT_V1**, composed as **STREET_ORISON_01**.
Retain the named entrance, bodega, arcade and street-floor owners.

The [October 5 street views](../art/renders/orison_v2/building_surface_finish_20261005/city/07.jpg)
show broad dark seams and rectangular wet patches. These older images motivate
native review; they are not current-head acceptance. Inspect seam width/depth
and terminations, coping joints/bearings, slab interfaces, concrete/asphalt scale
and wet-edge breakup. Preserve crossing heights, door clearance, route-guide
visibility and existing light/interaction owners. Keep adequate simple solids.

Resolve fitted-slab source drift before rebuilding:

1. Fixture-bound blockout **3fbba2e5** has identical consumed front-door and
   F01 floor fields, despite a different current whole-file hash.
2. Fixture-bound world connection **118d7703** has the same removal list.
   Only the arrival standoff changed; the paving builder does not use it.
   Both historical hashes were checked against the original fixture pins.
3. Changed **exterior_masonry.blend** still needs native comparison of
   **PreServiceMasonry** masks intersecting paving height. No mask, export or
   collision equivalence is claimed. Keep the original fixture bindings.

Use existing **build_front_pavement.py**, construction report and standalone
**OrisonV2FrontPavementTest.tscn**. There is no **inspect_front_pavement.py** or
shared **front_pavement** module yet. Add a read-only native comparison/render
stage, then extract the existing detailed checks into **validate_in_world**.
Do not run a plan referencing nonexistent stages or unsupported modules.

## Execution and remaining queue

```powershell
python tools/plan_v2_fabrication.py --baseline art/data/v2_import_resume_20261008/fabrication_baseline.json --out tmp/v2-import-prep/current.json
python tools/inventory_v2_fabrication.py --out tmp/v2-import-prep/current-inventory.json
```

Follow [the batch workflow](../art/blender/v2_batch_workflow.md). Review changed
construction and accepted neighbors in Blender first. Reuse unchanged assets
and exact-source evidence; batch native checks, renders and exports. Then import
changed assets and run one combined windowed production capture through the
lane with log/receipt, retaining paving and directly affected boundary/route
checks. Respect fresh-checkout double imports and runner ceilings. This
preparation needs no Godot launch.

Next review rear/service shell interfaces and remaining city ground/roof
boundaries against their existing reports. Choose observed defects or surviving
V1 visual stock; primitives, stale hashes and reserved spaces are not missing-art
counts. The requested Fable narrative walkthrough is a separate input. Preserve
the carried service set, accepted Dream/zoo assets, nonvisual authorities and
conditional **G15** policy.

## Closeout record

Worktree clean at end: no; owner insitu files, two pre-existing EOL-only changes,
supplied answering dossier/review inputs and unrelated generated UIDs remain
outside this change. Other agents' worktrees are untouched.

Protected 17/17 and selector: unchanged by this preparation; default V2 and
explicit V1 rollback retained. No game, test, shader, native or texture file
changes. Prior verification keeps its original candidate attribution. Ledger
counts are not rerun; no requirement changes or runtime promotion are claimed.

Gates: design-doc lint and source/snapshot integrity for report/inventory changes.
Full gate board, candidate verifier, Blender and Godot suites are not repeated
for prose. The native masonry-mask comparison remains open. Changes outside
expected boundary: none. Decision needed from owner: none.

Last line: preparation complete; next work begins with native paving-boundary review.
