# V2 geometry and texture batch workflow

Evidence class: **INERT**. Procedure, not acceptance evidence.
Owner direction, 2026-10-07: minimize Godot launches, tokens and elapsed time
while continuing the full V1-to-V2 geometry and texture pass.

Before starting the combined Godot run, check catalogue projections, texture
import policy, focused geometry/material tests and the reader baseline. Include
**tools/tests/test_material_catalog_persistence.py** when adding catalogue keys;
the layout generator must retain the exact registered definitions. Retiring
a generated visual can leave a source field unread even when the native render
passes. Resolve source-to-native compatibility before freezing the rendering
inputs, so a cheap reader defect does not force another full world build.

When adding an older suite to a shared-world pass, preflight its selected
fixtures' source_bindings before booting Godot. Regenerate expired bindings
through their owning builder and compare actual geometry; never repin a receipt.
Assertions about shared material defaults must account for V2's active UV
policy and verify restoration after world teardown. Check runtime registration
as well as the art catalogue: an art key alone does not populate MatLib's sets.

Before the final capture, run the complete static/tools board in a clean
candidate checkout as well as the focused preflight. Review and register new
spatial dependencies without replacing existing manifest rows. Renew source
discoveries through their actual probe before freezing surface inputs: even
an unchanged trim-instance set with a renewed layout binding invalidates the
broad surface and access digests. Catch that metadata change before the long
Godot batch, rather than repeating unchanged world builds afterward.

For a reflection defect, isolate its actual light and emitting geometry before
altering material roughness. Compare the configured source size with the native
emitting envelope, and inspect other fixtures in that same physical family at
adjoining windows before freezing the broad capture. Keep optical controls
disposable; apply production calibration through the existing lighting authority.

## Visual detail priority (owner direction, 2026-10-17)

Furnishing placement is measured against installed wall finishes, including
baseboard beads, panel caps and rails, rather than the bare wall plane. Keep
the whole actor, collision, supported stock, appliances and approach anchors
together. Wall hangings must clear trim without floating off the plaster.
The composed surface suite includes **v2_furnishing_clearance_review.gd**;
unresolved placements fail qualification. Retain clear walking routes and
exercise moving parts after refitting an installation.
Include adjacent service access in that review: trim-clear furniture can still
occlude a valve or a loose part during removal. Check the real grab, withdrawal,
carry and replacement path before renewing the broad surface and route proofs.

Prioritize observed material and construction defects within each batch,
especially surfaces seen close up or handled repeatedly. A catalogue entry,
valid UVs and complete mipmaps are necessary checks, not visual acceptance.
The radiator's flat appearance is an open defect even though its normal maps
are enabled. Track specific visible defects and their locations rather than
calling an entire family polished after a representative asset passes.

Review each changed assembly at normal player distance and close inspection:

- Compare diffuse room light, grazing light and the carried flashlight. Inspect
  the actual loaded albedo, roughness, normal strength, metallic response and
  local reflection context together. Keep a controlled-light view so lighting
  cannot conceal a weak material or justify a global normal-strength increase.
- Distinguish cast skin, worked fittings, paint, plating, cloth and exposed
  substrates. Give relief a physical scale and roughness a material purpose;
  avoid baked highlights, arbitrary mottling and large repeating grime marks.
- Inspect silhouettes, eased edges, seams, fasteners, wall/floor contact,
  hollow openings and underside normals. Texture detail cannot substitute for
  missing geometry or a mechanical joint that does not fit.
- Inspect each operable part through its travel, including exposed interiors,
  shadows and moving connections. Preserve interaction and save authorities.

Fix source geometry and matched PBR maps before export; review the corrected
detail in the composed game before closing its defect. Reuse unchanged views
and batch related corrections into one Godot capture. Unreviewed details stay
open, including when static gates pass.

On manufactured flats, measure the corner normals against the actual plane
and check the tangent at the adjoining bevel. Area weighting alone can bend
a small cap's reflection by thirteen degrees. Use named planar axes only on
genuinely flat stock, keep convex lenses/turned skins curved, and retain an
unanchored negative control. Compare exported triangles, UV derivatives and
moving-shape positions so a shading repair cannot hide a fit change.

Separate material defects with mapped, normal-off and constant-finish views
under the same controlled lights. Mottling can come from pigment, roughness or
biased geometry normals; raising normal strength does not diagnose it. Keep
physical height calibration and optical contrast distinct. Retiring an AI
plate includes its active visual lock and ingestion route: a later --full
must stage the catalogue's custom recipe rather than resurrect the old plate.

When production physics disagrees with Blender, isolate the imported mesh and
its existing factory in a small brokered bench before another full world boot.
Keep contact tolerances and expected owners/normals intact; use a floating or
wrong-part negative control before changing query parameters. The seating bench
reproduces short-ray misses while longer rays meet the same 40-micron limit.
After diagnosis, validate the correction in the combined production world.

For lighting comparisons, operate the lamp's real logical switch and verify
its rendered output has settled. Visibility alone can be rewritten by its
presentation owner. Production optics retain a thermal tail that a simple
bench light does not share; wait on the actual output with a bounded deadline
rather than assuming an identical fixed cooldown. Retain rejected controls.

Short, broad wood offcuts need explicit grain charts when the shared slender-
stock heuristic does not apply. Verify exported tangent direction against the
stock's length while retaining metre scale. Screw geometry and operating travel
must share pitch and engagement; test actual mating surfaces throughout travel
and include a wrong-phase collision control. Manufacturing-only parameters stay
in the art authority, with a checked projection of the few runtime inputs.

For small replacement parts, fit the actual collision to the native stem and
head separately; a whole-part convex hull can falsely widen a narrow stem.
Review storage against the loaded room and furniture, with a clear player
approach. Plan coordinates alone do not establish that a shelf has a wall or
that the player can see and reach it. Retain failed placement captures.

On curved castings and Boolean fillets, measure local chart density as well as
total UV area. A globally correct area concealed severe stretch on small
radiator faces. Retain sound continuous charts and repair only distorted local
charts; record their physical scale range. Make native previews use the same
triangulation and corner-normal policy as export, so a smooth Blender preview
cannot conceal hard or biased shading in the imported model. Inspect retained
stock buffers and moving-part fit before importing a geometry correction.

Test ray acquisition again after a loose part has fallen and been restored.
An overlap query alone does not prove that the cursor can pick it up. The
sub-millimetre packing skin kept its native convex physical collision, while
oriented bounds on its individual curved sectors supplied reliable cursor
targets and retained the opening. Reuse the existing separation between
physical collision and small-part interaction bounds. Cache bearing solves
when only supply or heat changes; detailed shoe vertices need rescanning only
when the physical pitch changes.

Measure the actual visible skin against its support, rather than checking only
the object's origin. For thin loose parts, distinguish contact while tumbling
from settled contact and include an inclined support. Keep failed diagnostic
runs. The current packing still needs a convincing fabric finish and the union
hardware needs eased edges; passing its input/contact bench does not close
those appearance defects.

When refining an exported stock, discard and rebuild its corner tangent guides
after changing topology. Duplicate guide attributes can silently retain stale
values. Weld Boolean slivers before unwrapping and validate final float32
tangent derivatives. For fitting-only batches, reuse reviewed casting stocks
through the preparation tool's retained-native input and compare their actual
exported buffers, rather than regenerating unchanged Boolean solids.

Thin loose parts also need contact tolerances at their physical scale. V2's
space-scoped contact policy uses 0.5 mm penetration tolerance and restores the
previous setting when the last V2 owner retires. The liner-specific position
correction was removed after intermittent inclined-contact failures. Check
multiple released orientations and another loose-part mechanism under the same
policy; a single settled sample does not establish stable contact behavior.
Inspect a service chamber from its real opening, and test Space with actual
key events as well as mouse grabs. Cap removal must retain the installed
orifice's identity; replacing its grade remains a separate physical operation.

## Batch by room

For a new service mechanism, finish the complete grab, mouse motion and release
gestures in a fast bench using the production player before reloading the full
world. Exercise the real input events and physics cursor, rather than calling
part setters to simulate a successful grab. Then reuse that gesture driver in
the composed review. Camera offsets must use the actor's basis: a world-space
offset can put the eye behind a rotated fitting's wall. Aim a screw review at
its visible face so the gesture follows the projected circular path. The
radiator cutover caught a bad camera setup and an occluded socket target before
the castings became the actual withdrawal grip. A focused bench resolved these
without repeating broad runtime suites during the unfinished control pass.

Before launching long spatial-contract runs, run
`python tools/preflight_spatial_test_bindings.py --all`. Repair missing
transitive test bindings before opening Godot. An inherited helper is part of
the receipt even when that particular route never calls its method. This
preflight checks source declarations only; runtime receipts still require the
actual run and independent validation. Never add hashes to a finished receipt.

Use a whole room/shop or approximately 4â€“10 related fittings as the work unit.
Extend an existing builder instead of starting a build/test/report cycle for
each small prop. Keep accepted work unless an observed defect or source change
invalidates it. Read the Bible, source records and fabrication coverage once
per batch. Use `tools/inventory_v2_fabrication.py` for broader V1 coverage;
the hash planner inventories registered fixtures, not all unfinished V1.

In Blender, load adjacent accepted geometry and the retained shell. Resolve
silhouette, joints, hollow interiors, supports, clearances, bevels, normals
and metre-scaled UV grain before export. Contact probes must approach the
owner from its outward face; verify the hit normal as well as its distance
so Blender catches back-face probes that Godot collision rays reject. After
transforming a BMesh into the owner frame, update its normals before creating
the BVH; transformed vertices with stale face normals produce false failures.
Review catalogue albedo, roughness
and normal response at player distance in the same batch. Generate new maps
only for an observed deficiency, register new catalogue keys, keep textures
unlettered, and use Label3D for lettering. New runtime texture sidecars must
apply **art/tools/fix_runtime_texture_imports.py --v2** policy before the first
import: real mipmaps, disabled automatic 3D redetection and reviewed efficient
GPU compression. Owner direction 2026-10-11 requires this policy; preserve
normal RGB semantics, and follow **design/V2_SURFACE_REQUIREMENTS_2026-10-11.md**
(RUL-012). Check actual loaded mip chains in the shared validator. Render room context and selected
details. A clean mesh census alone does not certify photorealism. Godot must
still confirm its final lighting, glass, collisions and composed appearance.
Preserve source plans and all non-visual owners; never hand-edit generated glTF.

After adding a service opening, regenerate every native leaf that consumes it;
the JSON declaration alone changes only the procedural owners. Before broad
runtime renewal, acquire the actual composed corridor with the full changed
stocks and adjacent retained services. Check couplings, hangers and main
extensions against that geometry, including electrical and telephone fittings.
Classify flush seating and embedded bearings by their actual owners and bounds;
do not waive all architectural contact. Exercise new openings with physical
collision rays and nearby solid controls so missing colliders cannot report a
false clearance. The 2026-10-17 heating refit exposed both an electrical clash
and an unregenerated masonry leaf only after this composed check.
For this native family, run **tools/review_v2_heating_mesh_contacts.py** through
Blender with **--context**, **--build-dir**, and **--out** after its **--** separator.
It rejects stale context unless explicitly requested as a historical diagnostic.
Then run **tools/review_v2_heating_contacts.py** with **--diagnostic**, **--build-dir**
and **--out**. The latter rejects mismatched native provenance and unexplained
contacts; its clear result remains scoped to the acquired corridor.
Include the full changed main height in acquisition coverage, not only its branch
takeoffs. Run **tools/review_v2_heating_assembly_contacts.py** separately against
retained native heating: duplicate-distribution exclusion in the world diagnostic
does not test those native joints.

Before renewing a receipt, identify its actual binding domain. A native-only
change invalidates rendering-bound surface and access proofs. It does not by
itself invalidate a runtime-only control/save receipt whose runtime and complete
executed-helper hashes still match. Preserve that original receipt and its
captures; use fresh composed captures for the changed geometry. Never copy new
images over a historical run's images or alter its hashes to claim a new run.

Prototype changed entry bores and supporting joints before repeating a large
assembly. Joined groups may contain overlapping individually closed stocks;
drill those solids separately or regularize the Boolean inputs first. A positive
closed-mesh census does not prove that a suspension, union or conduit still
connects. Probe its retained wall at several heights and render the connection
before instancing it. The front-lighting candidate initially passed that census
while an oversized bore had erased part of its suspension. Batch fixed supply
by floor/material for export, retaining separate interactive owners; check the
scratch export/reimport before touching shipping inputs.

Before the final combined capture, stage new texture and sidecar paths **by
name**, then run **art/tools/fix_runtime_texture_imports.py --v2 --check --json**
and **art/tools/fix_v2_mesh_imports.py --check**. The texture gate includes
tracked shipping files as well as referenced maps; an unreferenced new duplicate
is invisible to that inventory until it is staged. Correct those imports and
re-import before qualifying the world, so the clean-checkout gate does not
invalidate an otherwise finished capture batch.

Before the broad contract batch, new permanent furniture must also pass the
existing nearby walking legs with the ordinary production controller. Being
inside a room does not prove access: the lobby bench initially fit its new
waiting bay but its arm blocked the established diagonal entry. Reuse the
existing route helper in the focused installation diagnostic, then preserve
that route in the broad check. Do not move a verification waypoint to hide a
new obstruction.

Run the full static board before freezing a runtime batch. Resolve engineering
failures such as source/projection drift, namespace/API errors and import or
reader regressions first. Live-proof assertions can remain pending only while
the changed runtime has not yet been re-executed; renew that proof genuinely.
Update authoring rosters together with their runtime projection, and migrate
old click-toggle diagnostics before relying on them for direct manipulation.

## Check source portability before captures

Before freezing a batch, review new nonignored authored inputs:

```powershell
git ls-files --others --exclude-standard -- game/assets art/blender/scripts game/scripts game/scenes game/data game/tests/fixtures
```

The surface fingerprint includes new nonignored assets. Every authored input
must travel in the named commit. Classify generated GLB texture extracts using
the current GLB image manifest and actual source references; ignore only the
proven derived namespace. The tracked GLB remains a hashed source. Stale,
unreferenced extracts must not become shipping textures merely to preserve an
old fingerprint. The washer leftovers exposed this distinction on October 16.

Set hash-bound Git attributes before final verification. Compare the frozen
source in a fresh checkout before publication. If a portability correction
changes only the surface fingerprint, renew the surface and affected spatial
contracts by execution; reuse unchanged runtime-only contracts after checking
their bindings. Never repin a completed receipt. Report canonical execution,
fresh static checks, fresh imports and human acceptance at their actual scope.

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
reviewed renders. Investigate drift before choosing rebuild stages.
Front-pavement historical hash drift remains visible; the October 8 street
review compares its unchanged consumed fields and 24 native masks explicitly
in **game/tests/fixtures/orison_front_pavement_review.json**. It does not repin
the original fixture or approve unrelated masonry changes.
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
**signal_terminal**, **domestic_seating**, **domestic_tables**, **domestic_storage**,
**prep_cabinets** and **household_wardrobes**. The original
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

Before an expensive world composition, batch changed GDScript paths through
**CompileChangedScripts.tscn** with **ORISON_SCRIPT_CHECK** set to a nonempty
JSON array of **res://** paths. Run through the lane with a named log. This
loads scripts under the real autoload context without constructing V2, so it
catches syntax and inferred-type errors quickly. Plain **--script --check-only**
cannot resolve production autoload identifiers such as Conductor and is not
an equivalent check. This preflight grants no geometry, gameplay or receipt
acceptance; a successful changed-family world run is still required. Reuse
its result while those scripts and their dependencies are unchanged.

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
stockâ€™s principal length, including angled rails, without moving geometry.

When only UV/tangent data changes, compare expanded indexed physical triangle
bytes, the exported scene graph, all semantic fixture fields and runtime data.
A dependent asset with unchanged geometry, maps and behavior need not be
rebuilt just because a context hash changed. Refresh only explicitly reviewed
dependency hashes, retain the comparison and keep prior proofsâ€™ dates/scope.
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

## Check capture framing and moving-stock sweeps before repeating a world

For a translating mechanism, compare each moving stock swept bound against
fixed stock across its full travel before import. Review every changed native
state, including closed leaves, before starting the editor import. Preserve
the existing mechanism and collision owner when replacing only visuals.

Storage captures check the complete assembly and retained stock against the
camera frame, then cast visibility rays to reject obstructed stations. Fifteen-
degree candidate angles fit around nearby furniture. A corrective capture can
set **ORISON_FABRICATION_ACTORS** to one known representative ID; all actor
geometry checks still run, but unchanged screenshots and other modules need
not repeat. Actual capture feet are recorded in the module result.

For live controls, await the original tween completion signal before checking
its final pose; a fixed timer can expire before tweens during a heavy startup
frame. For high-mounted cabinets, require the full projected bounding box and
visible front controls. Do not require visibility through its actual shelf to
rear underside corners. Preserve failed frames and receipts when improving
these checks. Review occluding piers and noncollision trim visually as well.

For animatable collision under a rotating parent, verify the physics body
actually reaches the parent target. Record rejected camera collider paths and
local hit/target positions, so a blocked camera cannot conceal a stale body.
After a local prototype repair, compare all unchanged glTF accessors exactly
before reusing their native views; review changed views before shared import.

Use the same **C:/ov/v2-fabrication** verifier work directory across batches.
Its baseline board cache is keyed by merge-base and tool version; changing the
work directory needlessly reruns the unchanged baseline. Temporary checkouts
still retire normally, while cached baseline boards remain for reuse.

For fixed lights, use the production actor yaw convention in native context
checks: passage and non-sconce bar markers negate authored yaw, while bar
sconces retain the existing inward-facing correction. Fit local presentation
offsets without moving semantic anchors. Match photometric checks to the
unchanged LightRig maintenance-card tuning applied after mounts. Use retained
floor heights and projected full bounds when placing corrective cameras.

For household appliances, native context should cover the complete seeded
inventory placement envelope and adjacent appliances' full service travel.
Validate both exact source owner names and target poses before a broad capture.
Camera visibility must include native structural carcasses and moving leaves;
the original closed collision body cannot describe an open door. The
household_fridges module applies these checks to every actor while allowing
only failed views to be recaptured. Reuse unchanged views only after exact
asset/runtime comparison, and keep failed run receipts with the final packet.

## Owner building finish review (2026-10-08)

The batch also accepts **owner_building_finish** and **owner_building_routes**.
The finish module embeds the existing facade, roof membrane, fan, city tank,
aerial, lift joinery and gate validators in the same production world.
**ORISON_BUILDING_INSPECTORS** narrows those embedded validators by comma-separated
names; omit it for all seven. **ORISON_BUILDING_ROUTES** similarly selects
front, inner, roof or lift routes. Runtime contracts are test-written and
explicitly exclude save reconstruction. Keep unrelated family evidence when
its geometry and authority inputs are unchanged.

**ORISON_FIXED_LIGHTING_CAPTURE_IDS** selects the actual installed fixture
owners for powered/off pairs, including variants whose first representative
is another actor. **ORISON_FABRICATION_ACTORS** does not replace this selector.
The owner building packet records rejected diagnostic runs as well as final
proof; check stderr and helper completion, not just the wrapper exit.

## Street paving continuation (2026-10-08)

The batch accepts **front_pavement** and **street_paving_details**. The original
fitted-slab checks run in the shared world. **ORISON_STREET_CAPTURE_IDS** selects
named views for correction without repeating unchanged photographs; all source,
material, support and original crossing checks remain active. Source drift for
the slab uses an explicit consumed-field/native-mask comparison, preserving
original fixture pins. A blocked camera is a failed run, not visual acceptance.

### Restoring occupied building volume

Include adjoining entrance assemblies in the native fit review when adding
floors or moving exterior walls. Check canopy tops against slab undersides,
backplates against the full door sweep, and old window stonework against new
passage openings before the combined capture.

Finish the visual harness before renewing globally bound apartment and save
receipts. Seasonal camera sweeps deliberately change calendar dates: use the
supported frozen campaign-time driver in that visual suite, while ordinary
access and save/reconstruction suites retain live time. Never use frozen
camera captures as evidence that campaign simulation advances correctly.

### Curved textile charts

A swept cord keeps its continuous rest-length/radius chart. Do not force each
bent triangle into an independent flat chart: inspect the weave for seams.
After rebuilding task-lamp supply, run **inspect_flex_rest_uv.py** in Blender
and the brokered **RecipeMigrationBench.tscn**. The INERT native witness checks
physical radius, cumulative length and a wrong-radius negative control; the
bench checks exact imported position/UV identity plus basis and derivatives.
Every other manufactured mesh keeps the strict planar metric. These checks
supply no routing, interaction or visual acceptance.

### Cast joining rims

Do not infer a finished edge from a bevel modifier. Probe the final solid:
small Boolean intersections can clamp a global bevel to zero. Author the
radiator joining rim profile before union, retain the port and sealing-face
datums, and run **review_radiator_section_joints.py** with an unrelieved source
negative control. Review the port side under diffuse and grazing light;
the opposite side can conceal these joints. Keep native and exported machined
face normals consistent. Recheck actual retained stock buffers, native fit and
player manipulation before the combined world capture.

If only surface publication fails, use **tools/publish_v2_surface_packet.py**
on the already qualified and reviewed capture. It preserves the previous
packet and performs staged replacements; do not repeat Godot solely to copy an
unchanged, successfully qualified inventory.
