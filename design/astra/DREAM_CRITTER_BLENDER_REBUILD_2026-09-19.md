# Dream critter Blender rebuild — 2026-09-19

Evidence class: **INERT**

REPORT - DREAM-BLENDER-REBUILD - 2026-09-19

Branch: codex/astra-reconcile-20260919. Parent checkpoint: bae816c.
Scope: all sixteen existing warehouse critters. The thirteen researched
organisms were modeled and validated first, followed by the three original
critters. The biology dossier is reference, not new canon. No reference
image bytes were downloaded, projected, baked or committed.

## Implemented

All sixteen now have editable Blender sources, two exported detail levels,
nineteen morph samples, anatomy masks, normals and explicit motion contracts.
Closed continuous cortices carry rooted appendages and contained tissues.
Colonies retain biologically separate closed cells rather than an invented
single fused animal. Topology is checked per declared component.

The existing controller still owns movement, contact, light, feeding, tun,
contraction and life cycles. The opt-in warehouse presentation consumes that
state through one shared float pose atlas and the existing RG8 voxel field.
It keeps two bounded controller batches, each with an opaque organ surface
and one shared outer-envelope surface. The complete cortex, cilia and claws
share one lighting pass; only authored thin-window values admit transmission. Detailed inspection remains under84000 triangles
per controller. There are no per-animal skeletons or materials at runtime.

The stripe-free material uses original procedural grain, species-specific
wine absorption and roughness, anatomical gold boundaries, thin tissue
windows and actual internal geometry. It is not a baked photo texture or
physical refraction simulation. The inspector retains intact, neutral and
explicitly labelled diagnostic cutaway modes.

Tardigrade has rooted lobopods and claws; Vorticella has a coiling stalk and
oral bell; Lacrymaria has a continuous extensible neck and transported head;
Stentor and Spirostomum contract through their own body plans. Volvox has
three daughter inversion membranes and twelve paired flagellar bundles.
Euplotes has fourteen cirral tips driven by the eight existing groups and
four walking states. Euglena preserves independent body/flagellum phases,
with an eyespot and continuous flagellar insertion. Heliozoan retracts one
selected ray. Noctiluca confines its existing diagnostic flash to scintillon
sites. Bacillaria slides separate cells with finite-thickness raphe openings;
Salpingoeca keeps twelve collared cells in a rosette; Mesodinium contains
distinct retained plastid packets and rooted ciliary bundles.

The seam grazer has a shallow mantle and unfolding ventral comb. The listener
keeps a stationary receiver around a rotating resonator, with wet suspension
rings and three-to-five supporting props. The fold crab keeps six-to-eight
CPU-owned joint chains and two deployable mouth manipulators. Three-row sides
use canonical rows0/1/3 to prevent overlapping unused collars. Its limbs are
laminated anatomical blades, not cylindrical walking tubes.

Listener resonator rotation and Volvox colony rotation now move actual
geometry where the preceding presentation rotated an optical shading frame.
These are deliberate visual extensions driven by existing clocks, not new
ecological behaviors. Euplotes has no planted-foot CPU solver; this pass
preserves its existing four-state cirral motion without claiming foot IK.
Noctiluca's pulse button remains an explicit debug stimulus, not a new receptor.

## Source verification

Every source below passes39 evaluated poses at both LODs. Checks cover closed
topology, normals, nonadjacent contacts, contained organs, required rooted
regions and declared attachment drift. They do not prove all intermediate
deformations or clinical biological accuracy.

| Specimen | LOD0 / LOD1 triangles | LOD0 / LOD1 checks |
|---|---:|---:|
| Tardigrade | 17584 / 4812 | 4446 / 4446 |
| Vorticella | 18920 / 4752 | 975 / 975 |
| Lacrymaria | 16004 / 4464 | 1131 / 1131 |
| Volvox | 13176 / 3936 | 1560 / 1560 |
| Stentor | 14184 / 2928 | 1326 / 1326 |
| Spirostomum | 6464 / 2852 | 2262 / 2262 |
| Euplotes | 7032 / 2640 | 1170 / 1170 |
| Euglena | 5388 / 1664 | 1794 / 1794 |
| Heliozoan | 12224 / 3284 | 2808 / 2808 |
| Noctiluca | 13748 / 3608 | 3666 / 3666 |
| Bacillaria | 17280 / 4644 | 4953 / 4953 |
| Salpingoeca | 11024 / 4736 | 4056 / 4056 |
| Mesodinium | 11264 / 1948 | 2613 / 2613 |
| Seam Grazer | 14368 / 3660 | 1326 / 1326 |
| Crystal Listener | 16740 / 4500 | 1326 / 1326 |
| Fold Crab | 10276 / 3696 | 2028 / 2028 |

Raw reports, frozen producer/checker snapshots, actual root-centroid audits,
Euglena split-phase tests and narrowly scoped negative controls are retained
in art/renders/dream_critter_blender_rebuild_20260919. The Fold source mapping
has18 bounded probes across both LODs and6/7/8 limbs; those use nominal feet,
not live raycasts. Jaw normal transport remains a local approximation.

All32 raw GLB exports also pass the independent attribute audit: unit
normals/tangents within exporter precision, normalized weights, declared
semantic UV roles and all18 morph target POSITION/NORMAL channels. The
reader gate reports zero NEW unread fields against its existing baseline.
The subsequent Godot comparison also passes for all 32 imports.

## Native verification and review

The shared lane became free after the owner closed Project Manager. Both
imports completed successfully. The final all-sixteen diagnostic passes
**486/486 checks**, with empty captured errors, warnings and stderr. It covers
all 32 imported pose arrays, attachment atlases, malformed manifest rejection,
complete-envelope/opaque-organ index partitions, stable draw identities,
count variants, inspection LODs, paused light rebinding and resource release.
These are scoped INERT diagnostics, not schema-2 campaign runtime contracts.

The first native run exposed JSON float-versus-integer Array equality in
Euplotes admission. The decoder now checks exact numeric values, refusing
fractional and string controls as well as the wrong cirral mapping. Original
attempt receipts are retained under the native review folder.

Existing controller clocks were observed for 18 seconds without writing
their state. All sixteen advanced their own phase; the seam grazer stayed
folded and Noctiluca did not spontaneously flash during that interval. Their
unfold/flash review captures are explicitly staged. The fixture also saves
the Fold Crab's real support-frame feet before its controlled poses.

The [native gallery](../../art/renders/dream_critter_blender_rebuild_20260919/native/index.html)
contains 150 full captures, with neutral 0/half/full poses, cutaways, dark,
oblique and accumulated-lamp views, appendage counts, jaws and hunting reach.
All sixteen were visually inspected. The Listener's broad mineral shading
was narrowed to its existing anatomical ridges; sustained light preserves
wine tissue. Wall-mounted specimens and Fold Crab use clearer default views.
The complete outer envelope now stays in one lighting pass, avoiding the
artificial polygon boundary from splitting smooth tissue at a window threshold.
Opaque internal organs retain depth. The shared draw and triangle budgets
are unchanged; this is approximate transmission, not physical refraction.

The last frame sample records 240 desktop frame intervals: median
20.004 ms and p95 20.806 ms, 226 whole-warehouse draw calls
and 113505 primitives at the fixed Tardigrade camera. CPU clocks were
paused; this includes the rescued hero, palps and architecture. It is not GPU
timing or a performance guarantee. The shared pose atlas is approximately
116 MiB (1024 x 7413 RGBAF), covering both detail levels of all sixteen.

Regressions pass: zoo 147/147, debug entry 13/13 and existing critters 70/70.
The entry test was repeated after the camera/text fixes and also passes.
Full-world entry and critter logs retain previously observed resident-route
errors; they are not globally clean runs. The isolated zoo and Blender logs
have no native errors. The final reader gate reports zero NEW unread fields.

Fine cilia remain bundled and internal organs simplified for the budgets.
Fold limbs are deliberately laminated blades; their knee overlap depends on
view angle, and nominal/source contact checks do not prove every live
raycast pose. Lacrymaria's default view leaves room for its full search reach;
use the wheel for close inspection. Closely layered cells and membranes use
approximate alpha sorting. Finite pose checks are not a continuum collision
proof. This pass is available for owner art review; acceptance is not claimed.

The [source gallery](../../art/renders/dream_critter_blender_rebuild_20260919/gallery/index.html)
remains separate: its sixteen previews match the committed LOD0 Blender
sources but use controlled studio shading. Historical lane blockage is
retained in lane_blocker.json; it no longer blocks this pass.

## Reproduce and inspect

Open a source in art/blender/dream_critters. Rebuild one with Blender's
background runner and art/blender/scripts/build_dream_critter.py, passing
--species, --output-root, --seed and --lod both. The current generator covers
all sixteen. Exact historical producers are preserved beside their reports.
Use tools/lane.ps1 for two imports, then res://tests/DreamBlenderCritterTest.tscn
with a fresh ShotDir, Windowed and an explicit log. The warehouse is reached
through F1 → GO → Dream ecology or tools/open_dream_ecology.ps1.

Prior rescued hero/organelle work and the reserved zoo stations remain.
No main merge or push. No selector/protected gameplay-authority change is
intended, and no campaign-completeness promotion is claimed.

Last line: all-sixteen Blender rebuild and native debug integration verified;
review gallery, diagnostics and reproducible sources saved on the work branch.
