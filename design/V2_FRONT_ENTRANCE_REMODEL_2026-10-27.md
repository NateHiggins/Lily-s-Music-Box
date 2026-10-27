# Orison front entrance: remodel plan and example adaptation

Evidence class: **INERT**. Queued authoring plan, not modeled work, runtime
qualification or artistic acceptance. Weather/noise repair remains first.

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
