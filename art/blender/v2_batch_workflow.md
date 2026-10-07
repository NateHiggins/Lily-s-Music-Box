# V2 geometry and texture batch workflow

Evidence class: **INERT**. Procedure, not acceptance evidence.
Owner direction, 2026-10-07: minimize Godot launches, tokens and elapsed time
while continuing the full V1-to-V2 geometry and texture pass.

## Batch by room

Use a whole room/shop or approximately 4–10 related fittings as the work unit.
Extend an existing builder instead of starting a build/test/report cycle for
each small prop. Keep accepted work unless an observed defect or source change
invalidates it. Read the Bible, source records and fabrication coverage once
per batch. Use `tools/inventory_v2_fabrication.py` for broader V1 coverage;
the hash planner inventories registered fixtures, not all unfinished V1.

In Blender, load adjacent accepted geometry and the retained shell. Resolve
silhouette, joints, hollow interiors, supports, clearances, bevels, normals
and metre-scaled UV grain before export. Review catalogue albedo, roughness
and normal response at player distance in the same batch. Generate new maps
only for an observed deficiency, register new catalogue keys, keep textures
unlettered, and use Label3D for lettering. Render room context and selected
details. A clean mesh census alone does not certify photorealism. Godot must
still confirm its final lighting, glass, collisions and composed appearance.
Preserve source plans and all non-visual owners; never hand-edit generated glTF.

## Plan only changed work

```powershell
python tools/plan_v2_fabrication.py --out tmp/v2-fabrication/before.json
# After edits; optional --family pawn_display narrows the queue, not inventory.
python tools/plan_v2_fabrication.py --baseline tmp/v2-fabrication/before.json --out tmp/v2-fabrication/after.json
```

The planner discovers 73 source-bound fixtures at introduction. It compares
normalized source hashes, native files, exports, fixtures and inherited tests;
shared runtime/shader changes invalidate every registered family. Shared
inputs are hashed once per invocation. `review_queue` retains missing/stale
inputs even when a repeated snapshot has no new edits. `unregistered_builders`
keeps older/nonstandard builders visible. `BOUND` means hashes match, not
visual acceptance. Reuse a snapshot only alongside successful receipts and
reviewed renders. Investigate drift before choosing rebuild stages. Existing
front-pavement drift in world_connection and exterior_masonry remains open.
The planner does not rebuild assets, approve appearance or promote the ledger.

## Batch compatible Blender recipes

Save an explicit plan in `tmp/v2-fabrication/batch.json`:

```json
{"stages":[
  {"script":"art/blender/scripts/build_pawn_display.py"},
  {"script":"art/blender/scripts/inspect_pawn_display.py"}
]}
```

```powershell
python art/blender/scripts/run_fabrication_batch.py --plan tmp/v2-fabrication/batch.json --dry-run
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --python-exit-code 1 --python art/blender/scripts/run_fabrication_batch.py -- --plan tmp/v2-fabrication/batch.json --receipt tmp/v2-fabrication/blender.json
```

Put changed builders in dependency order, then their inspectors. Each stage
can provide an `env` object for existing output/render overrides. The runner
resets Blender's scene, restores environment/cwd/arguments/import paths and
stops on failure. Python's module cache stays shared: group compatible recipes
and inspect every result. Its initial two-file smoke test opened both accepted
Pawn native files; it did not rebuild or qualify all 141 existing builders.
Use draft renders during iteration and one final native review per changed
family. Export the complete batch after fit, support, UV and material checks.

## One composed Godot run

Modules: **pawn_clocks**, **pawn_display** and **pawn_fittings**. The original
clock/display checks remain; display now also checks the fitted safe boundary.
Their standalone scenes still work. As another family
is touched, extract its detailed checks to `validate_in_world(world)` and
register it in `orison_v2_fabrication_batch.gd`. Keep its specific checks.

```powershell
$env:ORISON_FABRICATION_MODULES='pawn_clocks,pawn_display'
$env:ORISON_FABRICATION_CAPTURES='pawn_display'
pwsh -File tools/run_godot_serial.ps1 -Scene res://tests/OrisonV2FabricationBatch.tscn -ProjectPath game -Windowed -TimeoutSeconds 180 -LogPath tmp/v2-fabrication/batch.log -ShotDir C:/PleaseRemainOnTheLine/tmp/v2-fabrication/shots
Remove-Item Env:ORISON_FABRICATION_MODULES,Env:ORISON_FABRICATION_CAPTURES
```

Omitted capture selection captures selected modules. `none` skips images and
render waits while preserving station/support checks; that mode may run
headless. Use a fresh output directory each run. Invalid modules, empty batches
and headless capture requests fail. The scene loads one world, uses normal
passage prefetch, runs modules sequentially, records separate results and
tears down once. Its INERT `batch.json` and the lane's `suite_run` receipt do
not replace schema-2 runtime contracts or grant ledger proof.

Warm canonical checkout: import once only if new/changed assets need it;
already imported assets and test-script edits can go straight to the batch.
Fresh checkout: keep the required two imports, then one combined batch.
Use the lane broker when busy. Do not launch an editor for each prop. Stay
within the serial ceiling; split larger batches or justify a long run with
measurements under the existing lane rules.

## Verification and reporting budget

| Change | Work required |
|---|---|
| Geometry/local materials | Native render/fit checks; one composed batch of changed and directly affected families |
| Mount/residency/shared behavior | Add relevant lifecycle, ownership or simulation contracts once per integrated batch |
| Global optics/materials | Broaden affected-family checks and visual stations |
| Fresh-checkout candidate | Two imports, combined batch, relevant contracts; reuse complete clean baseline board |
| Reports/capture index/docs only | Lint and hash/status comparison; no repeated Godot or Blender run |

Use targeted static checks during edits and one full gate board at the
candidate boundary. Reuse the clean complete cached baseline; prefer in-place
verification when its prerequisites hold. Do not repeat all shop suites per
prop or recapture an unchanged baseline. Preserve protected paths, zero NEW
unread fields, V1 rollback and cabinet restoration policy.

Review one contact sheet, then full-size changed or uncertain views. Retain
full-resolution changed images and raw receipts once; reference unchanged
evidence by path/hash. Write one concise section-7 report and continuation
update per batch. Read summaries and failures before full logs. Avoid rereading
unchanged scripts, regenerating accepted assets and repeating long updates.

Initial observation: the two separate Pawn runs took 49.01 s and 48.93 s;
the combined run took 48.73 s with 1,313 checks and seven new-display frames.
Two launches became one. This is an observed comparison, not a controlled
benchmark. Other families need incremental adapters. V2 remains incomplete.
