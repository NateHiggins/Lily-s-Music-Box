# Arcade fabric candidate

Evidence class: **INERT**. Offline native asset preparation. No installed-world,
navigation, mipmap, weather, interaction, regional or V2 acceptance grant.

The current game is unchanged. These files prepare one coordinated arcade
installation, so repeated whole-world runs are not spent on unfinished stock.

The retained source roof uses twenty horizontal glass boxes under an intended
barrel. It leaves open shoulders. Stepped end gables both miss the roof and
protrude through it near the crown. The lantern's six glass diaphragms cross
the nave below the arch while its exterior shoulders remain open. These are
geometry defects; stronger normal maps cannot close them.

The candidate follows all ten original ribs' actual sixteen chord segments.
It has 192 six-millimetre barrel panes, six lantern side panes and two shaped
lantern spandrels. Glass sits above the original 45 mm rib radius. Cap stock
and diamond relief follow the individual pane planes. Four closed plaster
prisms replace the stepped upper gables and retain the south lunette opening.
The lantern's cap, clock, curb, source rib actors and lights remain owned by
the original scene. The editable file contains 162 source rib/ridge guides;
they are explicitly excluded from the four-draw candidate GLB. The retirement
plan names 34 original box boundaries, not entire material partitions.

**canopy/arcade_canopy.blend** is editable. **canopy/arcade_canopy.glb** is a
Blender export, not edited glTF. **canopy/canopy_plan.json** records original
boundaries, exact stock, physical coordinates and outstanding installation.
**canopy/native_review.json** binds its actual recipe, source plan, native
file and export. Four PNGs show the candidate with retained source rib guides;
they do not show a composed game or prove retirement of the old geometry.

The fine light/dark terrazzo uses new generated diffuse stock, preserved
byte-exact. Exact prompts and built-in image_gen provenance are in
**art/textures/ai_sources/arcade_terrazzo_20261018.json**. The physical scale is
**0.4 m per repeat**, calibrated for fine aggregate rather than the prompt's
requested one-metre patch. Independent polish and micropores supply roughly
**0.053 mm** total height range. No luminance-to-stone-displacement conversion
is used. The chips remain ground flush. Map metadata binds the generator and
all four maps. The 16-bit height is a calibration source, not a second runtime
texture requirement. Only albedo/roughness/normal are intended for runtime.

The first mirrored UV bench produced conspicuous symmetric mineral motifs.
It was rejected. **rejected_mirrored_stock.zip** retains its maps, bench,
images and original recipes. The current candidate requires ordinary repeat
UVs and independently periodic microrelief. **terrazzo_repeat_diffuse.png**
and **terrazzo_repeat_grazing.png**, with their editable bench, show the
revised treatment. Source edge differences and wider-area repetition still
need close inspection in the arcade. No texture has been called accepted.

The additional **art/textures/ai_sources/arcade_brick_face_20261018.png**
is a new diffuse-only clay-face ingredient. Its adjacent JSON retains the
exact built-in image_gen prompt. It contains no courses, mortar or whitewash;
the native brick/joint geometry and independent PBR maps remain unfinished.

Rebuild from the repository root:

```powershell
python art/tools/build_arcade_terrazzo.py --out-root art/reviews/v2_arcade_fabric_20261018
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --python-exit-code 1 --python art/blender/arcade_fabric_candidate/build_arcade_canopy.py -- --work-dir C:/PleaseRemainOnTheLine/art/reviews/v2_arcade_fabric_20261018/canopy
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --python-exit-code 1 --python art/blender/arcade_fabric_candidate/review_floor_stock.py -- --work-dir C:/PleaseRemainOnTheLine/art/reviews/v2_arcade_fabric_20261018
python tools/check_v2_arcade_fabric_candidate.py art/reviews/v2_arcade_fabric_20261018 --out art/reviews/v2_arcade_fabric_20261018/candidate_checks.json
python -m unittest tools.tests.test_arcade_canopy_shells -v
```

The offline checker measures final exported UV stretch, tangent derivatives,
each of six faces on all 198 rectangular glass shells, and normals derived
independently from the stored physical height. Two shaped lantern spandrels
are checked for closure in Blender before export; the rectangular-face check
does not claim to cover their polygonal topology. Tests deliberately remove
and invert one actual exported underside and require rejection. All three
tests pass. The current GLB has **39,888 triangles / four draws**, minimum
tangent agreement **0.9999999585**, metric UV range
**0.999771–1.000196**, maximum rectangular face-area error **0.0175%**.

Next, finish the arcade brick stock, register the new floor finishes through
the catalogue and ingestion owner, and install the source-fitted roof through
the existing surgical native mounting mechanism. Replace the matching source
collision, retire all three old decorative ceiling draws, bind glass through
the architectural optical owner, and preserve source actor/lifecycle ownership.
Then review the whole batch in one combined windowed Godot capture, including
close/grazing/carried light, roof undersides, portal/throat/hall and Passage
stream-out/reconstruction. Freeze the production sources before renewing
globally source-bound surface/gameplay/access receipts. Do not repin receipts.
Missing region records remain open; adding paper region tags is not completion.

The retained **checks/board.json** is a dirty canonical-tree static run at
**951fec693f053000cf8e6a4cad0bd9d6d4bee323**, compared with the previous clean
board (**5a4a320cdea6fd253382d97605c3fbe1e4ecb3f1**). All **82 gate rows**
finish, with **zero regressions**, zero improvements and no requirement changes;
all **70 tools suites / 983 tests** pass. The only new row is the passing
three-test shell suite. The completeness
ledger remains incomplete at **0 / 1 / 48 / 25 / 65 / 67** blockers. The
reader audit reports **zero NEW** unread fields. This is not a fresh clean-tree
candidate verification. Existing canonical surface qualification independently
remains current (**checks/unchanged_surface_qualification.json**, 25,649
draws / 6,096 materials / 482 textures). No Godot process was launched for
this offline checkpoint and no runtime receipt was rewritten or repinned.
