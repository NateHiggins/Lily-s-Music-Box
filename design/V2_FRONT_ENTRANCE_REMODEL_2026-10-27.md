# Orison front entrance: remodel plan and example adaptation

Evidence class: **INERT**. Authoring plan and native integration record;
runtime qualification and artistic acceptance are reported separately below.

## Owner direction and form references

Build one coherent, ornate luxury Queens entrance from the owner's alternatives:
Jackson Heights garden-apartment Neo-Baroque/Italianate tapestry brick with a
carved limestone pediment; Beaux-Arts iron-and-glass portal and warm marble
vestibule; or Renaissance Revival carved hardwood with columns and an arched
fanlight. Preserve the Orison's identity, clear opening, easy fixed-travel door
gesture and existing access/save authorities. Keep the improved installed door
until its replacement has been rendered and verified.

The three owner photos remain external at **C:/ov/references/orison_front_20261027/**
and are never baked, projected or committed:

- **01_carved_hardwood_arch.png**: deep round stone arch, carved capitals, warm semicircular fanlight/lantern, molded timber panels and small upper lights, long brass plate/pull.
- **02_iron_glass_portal.png**: black scroll/Greek-key ironwork, matching ornamental transom, limestone entablature, granite base, brass knobs and mosaic vestibule.
- **03_brick_garden_pediment.png**: planted tapestry-brick court, pale broken-scroll pediment/urn/acanthus, molded surround, iron sunburst fanlight and black rails.

Borrow proportions, joinery and material contrasts, not photographed addresses
or modern additions. Research the selected historical details during authoring;
the owner's alternate universe permits deliberate artistic departures.

## Attached example retained as a starting point

The October 27 pasted technical specification proposes these allocations. They
are examples to evaluate against the installed opening and close-up views:

| Element | Example dimensions / triangle allocation | Adaptation |
| --- | --- | --- |
| Frame/stiles | 4.5 in wide, 2.25 in deep; about 600 triangles | Measure actual stock and reveals first; match full-depth 45-degree wood-frame mitres |
| Raised panels | 1.5 in recess; about 400 triangles | Model visible stepped/ogee relief and credible remaining leaf thickness; bake subordinate carving |
| Iron grille | 0.75 in square bar; about 1,200 triangles | Use real near-camera bars/scroll depth and attachment feet; square bars are not six-sided round rods |
| Bronze hardware | about 1,500 triangles | Prioritize cast pull, mortise plate, escutcheon, fasteners and contact seating; add only fittings useful to this door |
| Stone surround | 12–18 in projection; about 1,800 triangles | Check stoop, wall and canopy fit; model profile/silhouette, bake fine carved relief |
| Complete portal | 7 ft by 10.5 ft; 5,500–8,000 triangles | Provisional visual budget, not permission to resize the opening or introduce a second leaf |

Do not apply the example's 15 mm bevel to every timber edge. Use measured/profiled
arrises; test close diffuse and grazing views. Stone construction must read as
supported masonry. A structural lintel or continuous arch is distinct from the
mitred decorative surround. Fit the canopy, wall depth, threshold and lantern.

The example's 4096-square trim sheet separates stone, timber, metals and accents
into four equal V bands and proposes **1024 pixels/metre**. Keep the reusable
trim idea, but allocate area by actual visible stock lengths, chart orientation
and near-camera readability. Equal bands do not guarantee that density. Reuse
registered maps when suitable, prevent filtering bleed with padded borders and
complete mipmaps, and measure loaded texture memory before adopting another 4K
set. Glass remains its own optical material, not an opaque atlas band.

## Material and baking corrections

- **Wood:** example warm dark browns **#2B1810–#3D2217**, roughness **0.35–0.45**, optional restrained coat. Start from registered timber recipes and their calibrated normals/scale. Keep rail/stile grain coherent; judge dark finish under actual light rather than multiplying it into muddy black. Wear may polish high contact or scuff exposed areas; it is not universally roughness 0.70.
- **Brass/bronze:** example **#C5A059**, high metallic on exposed metal, roughness **0.18–0.25** on polished grips and **0.55–0.70** in aged recesses. Treat these as appearance trials, with spatial finish masks, real attachment plates and restrained patina. Anisotropy is optional only where supported by the registered shader and aligned tangents.
- **Painted iron:** dark charcoal/pitting is appropriate direction; continuous paint is dielectric. Reserve metallic response for exposed substrate instead of the example's uniform 0.80–0.85 through paint.
- **Glass:** use the existing registered glass owner, preserving tint, alpha, culling, normal/roughness maps and side-correct moisture. Alpha scissor is for cutouts, not a substitute for a translucent pane. Beveled edges need credible thickness/seating. Describe period plate/drawn glass; industrial float manufacture was introduced decades later, unless deliberately fictionalized.
- **Bakes:** evaluate high and low meshes, cage/ray distances and UV padding; bake tangent-space OpenGL normals and inspect the exported tangent basis. Derive curvature through an explicit mask recipe rather than assuming a portable native Curvature bake type. Roughness/AO are linear data. Do not bake scene lighting into albedo.
- **Packing:** the example's RGB convention is **ORM**, not a new ORMM standard: R occlusion, G roughness, B metallic. Pack only if the actual material owner/exporter consumes those channels; retain required provenance/maps. Normal remains separate. Do not replace shared materials globally.
- **Lettering:** an optional mail slot's lettering is separate Label3D authoring under the existing rule, never generated/baked texture text. Do not add a mail mechanism merely because it appears in the example.
- **Origins/export:** use an explicit assembly datum for snapping, while movable leaves retain their actual hinge pivots and operable-part names. Apply/evaluate modifiers consistently; never hand-edit exported glTF.

Official references: [Blender glTF materials](https://docs.blender.org/manual/en/5.2/addons/import_export/scene_gltf2.html),
[Cycles baking](https://docs.blender.org/manual/en/5.2/render/cycles/baking.html),
[Godot transparency and ORM](https://docs.godotengine.org/en/stable/tutorials/3d/standard_material_3d.html),
[Pilkington float-process history](https://www.pilkington.com/en-gb/united-kingdom/about-us/pilkington-history/the-inventor-of-float-glass).
Local executable reports Blender **5.2.0 LTS**. The versioned Blender web pages
were unavailable to this session; verify bake/export RNA in that executable
before coding. Godot stable documentation is guidance, not executable proof.

## Authoring and verification sequence

Survey the installed owner, opening, neighboring stock and material bindings.
Author and review a candidate blend with closed construction and separate moving
parts. Reuse existing fabrication UV/grain/normal/mitre helpers, and batch static
stock by material. Inspect native front/back/edge views and motion extremes.
Check final float32 export and imported UV/tangent precision before the full
world. Then inspect the installed entrance in native-resolution daylight and
gaslight, from approach and close-up, including transparent overlap and detail
readability. Exercise actual grab/motion/release, easy passage and affected
save/load owners. Compare frame-time distributions on the same approach route;
triangle targets alone do not qualify responsiveness. Preserve original defects
and renew only affected evidence after sources settle.

## October29 delivery intake and selective native integration

REPORT — ENTRANCE-NATIVE-INTAKE — 2026-10-29. Parent **fccd68cb**.
The external **C:/ov/asset-prototypes/orison-front-entrance-20261029/** delivery
passes128 manifest hashes,20 current source bindings and both repository tangent
checks. Its final source SHA256 is
**d210b8927737ae57be9f9bd12fb8a8f5158749bf337f17eba1ce7058a38db7d4**.
It is a partial portal, not a complete replacement facade. The combined source
is merged in Blender by retiring only the seven named fixed stocks in its
replacement manifest and the old moving leaf. No donor context, copied original
construction, reference pixels, lettering, cameras or lights are installed.

**385 retained editable stocks** have unchanged native fingerprints. All arrays
and transforms in52 untouched export draws remain exact. In the eight mixed
draws, every retained triangle's position, normal, UV and tangent remains exact;
only the1,308 declared retired fixed triangles are removed. All five new portal
partitions retain the delivered arrays exactly. The complete asset is59 draws,
41,302 triangles versus68/37,687 previously, with no embedded materials/images.
GLB size falls from5,654,716 to5,306,272bytes. These are asset measurements,
not a frame-time improvement. Closed construction now totals633 stocks.

The first external merge attempt stops on a missing retained material binding
after removal of the old oak; the original failure remains in **merge_first.log**.
Capturing material owners before retirement fixes it. Native previews inspect
the combined closed approach and open rear joinery. Canonical export succeeds
with minimum tangent agreement0.9999954422, noncollapsed geometry/UVs and all
draws bounded to4metres. Existing fixture evidence is renewed for the actual
complete asset, without changing retained source bindings. The native source and
**export_front_facade.py** drive ordinary rebuilds; the old generator delegates
to that export, reserving **--legacy-baseline** for historical reconstruction.

The local finish proposal uses dark oiled oak and warm stone through duplicated
materials; shared catalogue defaults and the established clear-glass owner are
retained. Door, lock, save, closer, mail repair, panic bar, marquee, acoustic sign,
lamp and entrance placement authorities are unchanged. Actual loaded appearance,
glass, player grab and composed fit remain pending the queued shared-lane review.
The existing facade test now uses the golden route's physical mouse driver for
the new leaf. This statement records implementation, not a passing playtest.

Evidence and preserved originals are under
**C:/ov/reports/prologue_20261028/entrance_delivery_review/**: **manifest_check.json**,
**source_recheck.json**, **combined_candidate/merge_review.json**,
**export_preservation.json**, **mixed_draw_preservation.json** and
**donor_stream_preservation.json** within that combined-candidate directory.
The two combined CPU images are native review only. Six scoped static gates
pass with0NEW unread fields and no regressions against the retained board;
this does not replace current-main candidate verification or surface renewal.

### Other waiting deliveries: actual disposition

- **Phone-scale arm and clawfoot tub:** already installed with later cassette,
  plumbing, curtain and UV repairs. Do not overwrite these with earlier external
  prototypes or apply the arm's0.42scale again.
- **Model A Tudor:**63 manifest files match. The complete assembly is29,662
  triangles including four wheel instances and driver;22,390 counts unique
  mesh data only. Original export fails the canonical UV-derivative tangent
  check at the rear quarter, despite unit/orthogonal tangents. An external native
  corner-guide re-export passes0.9999999570 minimum agreement, preserving all
  triangle positions/normals/UVs,27 encoded images and named transforms exactly.
  It is not installed. Catalogue/traffic batches, physical0.381m wheel radius,
  driver ownership, lamp optics and runtime cost still need integration.
- **Gas streetlamp:**40 manifest files match. The original22,444triangle export
  fails the same derivative check at the base cock. A native corner-guide study
  passes0.9999999590 while preserving triangle positions/normals/UVs,14 encoded
  images and transforms exactly. It is not installed. The existing gaslight
  clock, emitter budget, crossing signal box, glass and collision owners must
  survive conversion; a visible mantle does not create a simulated gas service.
- **Tardi organ:** remains explicitly INERT research-only. Intake does not
  authorize runtime attachment or changes to Tardi's exterior/current shader.
- **Voice sketch:** audio, not a Blender delivery; not treated as an installed
  companion voice system.

Car/lamp originals, manifest results and failed checks remain external alongside
**other_delivery_checks.json**, **tangent_studies/review.json** and
**tangent_studies/preservation.json**. Four original car/lamp CPU views are
inspected for form; the re-export preservation checks are not optical renders
or artistic acceptance. Their bundled maps still require catalogue integration.
The Blender skill records both derivative and selective-merge lessons; its
structural validator passes. No broad task or V2 completion is declared.

## Approved small entrance batch — October29

The owner delegates selection from the twelve proposed props. Approve only
these two isolated native candidates, in order; this is authoring authorization,
not placement, runtime qualification or artistic acceptance:

1. **Cast-iron boot scraper:** one restrained ornamental casting with a worn
   scraping edge, credible base and real pavement anchors. Static visual prop;
   no new boot-cleaning mechanic or interaction actor.
2. **Umbrella stand and removable drip tray:** practical period iron construction,
   stable feet, rounded contact edges and a seated tray with a clear extraction
   path. Reuse suitable existing umbrella/stand stock before rebuilding it.
   Separate the tray for possible later direct manipulation; do not implement
   water simulation or promise new inventory/save behavior.

The external Blender agent owns authoring once given the handoff; canonical
Codex owns later integration. Use **C:/ov/asset-prototypes/orison-entry-small-stock-20261029/**;
the repository stays read-only for that agent. Inspect current entrance blend,
runtime anchors and **entry_vestibule.json** before choosing dimensions. Show a
measured placement proposal and explicit keep-clear envelope for the door,
threshold, mailbox approach and normal full-size player route. If neither prop
fits, report it rather than relocating doors, lights or other contributors' work.

Deliver one concise construction report for both props, editable native source,
efficient material-key exports and modest closed/service/grazing CPU views.
Keep meaningful manufacturing stocks editable, batch static render partitions,
and provide a simple replacement body LOD if silhouette cost warrants one.
Use existing registered PBR maps with metre charts and loaded-mipmap-compatible
bindings; report triangles, material partitions and any new texture bytes.
Run the repository's final float32 metric/UV/tangent checks rather than checking
only normal/tangent orthogonality. Reference pixels and texture lettering stay
out. Do not copy packed catalogue images or historical authoring logs into the
repository. No Godot, catalogue, scene, interaction or placement edits in the
external authoring chat. No deadline is assigned.

Defer the other suggestions from this batch, without deleting installed work:

- **Mailbox bank:** already native via **mail_bank.blend** and
  **orison_v2_native_mail_bank.gd**, with real compartment/motion, mail custody,
  resident cards and inventory owners. A new formed-steel style is not approved
  as an incidental replacement of its existing finishes and behavior.
- **Entrance gas lantern, lobby radiator and notice cabinet:** current
  **orison_v2_entry_vestibule.gd**, native stock and data already provide gas
  fittings, radiator dress and authored notice frames. No demonstrated defect
  here justifies another parallel replacement or another light.
- **Mosaic threshold:** defer until the door/threshold and street-grade work
  are qualified; avoid competing floor transitions and additional texture work.
- **Doorbell/annunciator and service electrical cabinet:** preserve the existing
  telephone, dispatch, electrical and direct-manipulation owners; no replacement
  is authorized by this small decorative batch.
- **High-level cistern, shower curtain and kitchen sink:** outside the entrance
  batch. Preserve the repaired close-coupled toilet, clawfoot bath/plumbing and
  curtain, plus existing kitchen fixtures. Revisit only a reproduced defect or
  separately approved need.

The two-prop approval adds no V2-wide completion gate. Existing prologue, city,
weather, audio, persistence and performance commitments retain their priorities.


### First composed entrance review — October29

**import.log.receipt.json** passes in27.42seconds with empty stderr. The first
occupied fullscreen3440x1440 run, **world_first.log.receipt.json**, ends exit1
in188.33seconds:672 checks report one failure. Loaded metric mapping, materials,
matching fixed collision, retained bearings and door sweep report no failures,
but this failed aggregate grants no runtime qualification. Its new hand check
mistakenly uses layout coordinates as world coordinates: the logged camera is
at worldZ-13.55 while its actual leaf contact is atZ+0.315. Correct the fixture
stance through **door.to_global**, preserving production reach and collision.
The original failure, six optical frames and stderr remain external.

The loaded close/approach images show the new oak, carved panels, six retained
glass lights and stone arch; the facade is not artistically accepted. A diagonal
white streak remains visible in the review. Inspection finds the temporary
Camera3D uses its default all-layer mask, including the reflection-only player
avatar that the real first-person camera excludes. The review now copies the
actual player camera mask and asserts avatar privacy; attribution/removal of
the streak still requires a fresh render. No avatar, mirror or sky production
shader is modified. The corrected hand/camera rerun is queued on the same live
shared-lane waiter, with other contributors' processes preserved. It has not yet
returned a result. Routine import rewrites are verified normalization-only and
excluded from staging; no other contributor's assets or UIDs are discarded.
