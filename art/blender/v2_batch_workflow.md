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
and metre-scaled UV grain before export. Contact probes must approach the
owner from its outward face; verify the hit normal as well as its distance
so Blender catches back-face probes that Godot collision rays reject. Review catalogue albedo, roughness
and normal response at player distance in the same batch. Generate new maps
only for an observed deficiency, register new catalogue keys, keep textures
unlettered, and use Label3D for lettering. New runtime texture sidecars must
apply **art/tools/fix_runtime_texture_imports.py** policy before the first
import: real mipmaps and disabled automatic 3D redetection, retaining lossless
compression. Check actual loaded mip chains in the shared validator. Render room context and selected
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

For one newly added material, **tools/rebind_additive_material.py** accepts an
explicit **--base**, **--key** and **--out**. Its default is read-only; **--apply**
writes only after proving old catalogue values, generated policies, generator
behavior and shipped texture bytes are unchanged. It updates direct and
transitive fixture provenance in dependency order and rejects unrelated drift.
This avoids rebuilding unrelated assets for a catalogue addition. It creates
INERT comparisons and does not renew their visual acceptance.

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
Update linked-object transforms before native BVH queries. Run fit/support
preflight across the entire batch before rendering; **shop_clerestories** uses
**SHOP_CLERESTORIES_RENDER=0** for this first inspection stage. This avoids
re-rendering early shops when a later one fails. Then render the validated set.
Use draft renders during iteration and one final native review per changed
family. Export the complete batch after fit, support, UV and material checks.

## One composed Godot run

Modules: **pawn_clocks**, **pawn_display**, **pawn_fittings**, **laundry_fittings**,
**laundry_apparatus**, **laundry_trade**, **diner_counter**, **diner_till**,
**hardware_tools**, **photo_cameras**, **photo_counter**, **photo_stock**,
**photo_enlargers**, **photo_portraits**, **radio_wire**, **shop_joinery** and
**shop_clerestories**, **hardware_stock**, **news_fittings**,
**locksmith_fittings**, **druggist_cupboard**, **cobbler_fittings**,
**photo_radio_fittings**, **radio_display**, **task_lamps**, **reading_nook**, **work_tables**, **surface_stock** and
**signal_terminal**, **domestic_seating** and **domestic_tables**. The original
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

## Check known grain directions once per finish batch

Run **art/blender/scripts/audit_fabrication_grain.py** in Blender to identify
slender stocks whose UV grain crosses their actual length. It reads native
construction only and covers two visually checked albedos: timber U and walnut
V. Unknown maps, broad panels and end grain are excluded. Inspect the renders
before acting. **fabrication_grain.py** can orient those known maps along a
stock’s principal length, including angled rails, without moving geometry.

When only UV/tangent data changes, compare expanded indexed physical triangle
bytes, the exported scene graph, all semantic fixture fields and runtime data.
A dependent asset with unchanged geometry, maps and behavior need not be
rebuilt just because a context hash changed. Refresh only explicitly reviewed
dependency hashes, retain the comparison and keep prior proofs’ dates/scope.
Unexpected source drift still requires investigation. The bounded example is
**art/renders/orison_v2/wood_grain_20261007/rebind-grain-dependencies.py**.

## Linked context and fitted edges

Update Blender's view layer immediately after linking accepted native objects,
before building any world-space BVH. A loaded object's unevaluated transform
can otherwise hide real collisions. The existing linked inspectors now do this.
**audit_linked_native_context.py** runs those inspectors in one process, redirects
outputs into a fresh tmp directory and disables renders by default. Its JSON
records every PASS/FAIL; a zero process exit alone is not a passing audit.
Use **--render --view REGEX** only after the affected preflight passes. Only
**rendered_views** are new images; original inspector view lists include skipped
images. Instrumentation and redirected receipts remain INERT native QA.

The joinery inspector collects intersections across all eleven shops before
failing. Fix the complete list in one geometry batch, then repeat affected
preflights and selected renders. Compare canonical physical triangles when
checking unaffected parts: harmless export triangle order changes must not be
mistaken for surface changes. Never waive a real penetration to make a batch pass.

The Hardware validator retains its real purchase/input regression and runs
last in the default 24-module world. Capture suppression keeps geometry and
standing-station checks active. Metadata-only binding refreshes need no import.

Before import, run **audit_native_support_dependents.py** with every changed
family. It resolves grouped source identities and checks consumer bearing
points against the actual native replacement surfaces, with a 30-micrometre
bound. This catches attachments left behind when a provider moves or shrinks.
Its JSON retains hashes, every sample and failures; it grants no runtime proof.
The support audit regression deliberately replays the four old Hardware
spacer points against the fitted rack and requires all four to fail.

## Reuse chart and assembly work

**fabrication_chart_batch.py** computes a complete draw in NumPy, retaining the
scalar float32 precision fallback. Its turned-stock bands use continuous metre
charts instead of a separate chart on every radial facet. Keep the existing
UV/tangent metric gates. **fabrication_normals.py** averages curved corner fans
while preserving sharp boundaries. Prefer these helpers for new recipes; do
not rebuild accepted families merely to adopt the optimization. The desktop
batch builds 55 props together and prepares one imported model for all actors.

Validate retained source bounds and required material fields before native
adoption. Run semantic type checks and review dynamic compositions early enough
to catch invisible needles or primitive child meshes before the final capture.
When only an inspector output path or status prose changes, record a narrow
provenance comparison; do not repeat imports or rendered runtime runs.

## Group exact furniture variants before building

Compare original local geometry, bounds and material assignments before grouping
instances. The apartment batch reduces 103 installations to 17 native variants;
its two builders take about three seconds together in the recorded run. Preserve
every actor identity and placement, then validate every installed support. Share
immutable meshes and collision shapes through a world-owned factory, including
completion copies. Keep per-actor nodes and release the factory with that world.

For curved UV charts, native preflight must cover the engine absolute edge-length
budget as well as relative metric/tangent checks. Mark material tint colour space
explicitly: linear Blender tint values require sRGB encoding when assigned to
StandardMaterial3D albedo_color. Check one composed image before broad rollout.
