# Encounter rendering proposal: adversarial integration

Evidence class: **INERT**. Design review and scoped visual criteria, not runtime
proof or acceptance. 2026-10-26.

## Decision and authority

Reviewed the owner's supplied Gemini "Enamel Corridor" technical brief against
the Bible, the tentacle encounter brief, V2 surface requirements and the current
Tardi, guide-bell and tentacle implementations. Keep its tactile visual goals;
do not adopt its proposed architecture wholesale. The preceding literary scene
is mood reference, not evidence that those effects exist or permission to change
ecology, lighting, interaction or campaign authorities.

Tardi's prey remains Euplotes. Guide-bells are a separate maintenance presentation:
nearby Tardi can provoke shelter, and route passage drives irreversible wilt.
Do not turn them into edible prey or couple their retirement to the lunch record.
Tentacles remain curious maintenance-local organisms, without combat or damage.

## Technical decisions

| Proposal | Integration decision and reason |
|---|---|
| Bevels, curvature wear, oily enamel | Retain native Blender form and registered custom UV/PBR recipes. Inspect specular breakup, edge thickness and physical wear. Do not coat every floor with oil or replace existing substance identities. Clearcoat is appropriate to the wet residue and selected finishes, not a global correction. |
| New projector/IES torch and noisy fluorescent light | Reject replacement lighting. Use the existing carried-lamp owner, instantaneous optical field and production atmosphere. A projector texture is not automatically an IES photometric profile. Unmotivated flicker and electrical sound would invent powered-fixture behavior; any future fixture change must use its electrical/audio authorities. |
| Put thin-film interference into roughness | Correct the parameter model. Roughness controls highlight spread; a scalar roughness texture cannot encode angle-dependent spectral colour. Current residue is advected metallic pigment, not a thin-film simulation. Do not label it physically simulated interference. |
| B-Bones and spline IK as required replacements | Reject the rewrite. The live anatomical pose/deformation path must remain coherent across membrane, organs, cilia and collision representation. Blender control rigs would require export baking or a runtime solver; naming a rig does not establish exported behavior. |
| Raymarched Tardi interior with high-radius SSS | Keep actual nested anatomy and current shared microscopy optics. Extra interior marching is not required to establish parallax and could double the organs and shading cost. Inspect existing depth before adding a second representation. Broad SSS must not wash out internal detail or defeat lamp occlusion. |
| Highly metallic claws | Reject as a blanket material rule. A hard biological hook can be a sharp dielectric; metallic response requires an authored material justification, not simply contrast with soft tissue. |
| Alpha hash/scissor on all cilia | Conditional, not mandatory. Existing native cilia have real depth. Cutouts can erase subpixel filaments or introduce temporal stipple; MSAA is not a cure for every transparent sorting problem. Review movement and overlap before changing representation. |
| Global wind and Voronoi dissolve for goblets | Reject replacement lifecycle. Preserve the fixed holdfast and coherent stalk/lip/organ/cilia deformation. Route confirmation, shelter and cancellation remain distinct causes. No whole-body alpha fade or decorative noise should substitute for anatomical collapse. |
| Baked vertex colours represent live strain | Reject that assumption. Static vertex attributes describe rest anatomy; live compression must come from current deformation or baked animation data. Do not overwrite existing anatomical attribute channels or the owner's shaders. |
| Contact normal-map dimple | Keep actual pad compression and contact-latched deformation. Normal perturbation alone changes shading, not silhouette, contact depth or the collider. Actual grab, mouse movement and release remain the input contract. |
| Mantaflow/FLIP to Alembic directly into Godot | Reject as a drop-in workflow. Standard Godot scene import does not provide the proposed Alembic cache path. Topology-changing liquid would require a custom playback/import pipeline or an explicitly designed alternative, with memory, UV, collision and lifetime work. Keep the existing native pool plus coherent anatomical collapse. |
| Metallic rainbow fluid | Already incorporated as time-varying pigment, wet clearcoat, rough char islands, slow spread and floor clipping. Improve by rendered defects, not a speculative new simulation stack. The floor stays physically intact. |
| Custom FogVolume | Already incorporated: bounded density, rolling structure, dark early wisps and a finite purple terminal puff, sampling the accepted lamp field with zero intrinsic emission. Keep explicit retirement and preparation. |
| Stencil-masked second camera inside smoke | Do not adopt as acceptance criteria. Spatial stencil exists, but it does not supply a fog-density silhouette, bent room geometry, shared lighting, correct transparent composition or a second-view resource budget. A reflection probe alone cannot twist pipes. A literal portal needs a separately scoped prototype and proof; the current puff does not claim impossible camera perspectives. |
| 60 FPS on RTX 3060 and fewer than 2,000 draw calls | Treat 16.67 ms as an aspirational frame budget, not an achieved hardware claim. Report actual hardware, resolution, renderer, CPU/GPU distributions, first-use tails and active composition. A draw-call ceiling alone cannot establish performance. No merging of interactable/cullable owners just to meet this arbitrary number. |

Engine references checked: [scene formats](https://docs.godotengine.org/en/latest/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html),
[spatial shader parameters and stencil](https://docs.godotengine.org/en/4.6/tutorials/shaders/shader_reference/spatial_shader.html),
and [fog shader interface](https://docs.godotengine.org/en/latest/tutorials/shaders/shader_reference/fog_shader.html).
Latest documentation is not a compatibility guarantee; the installed 4.7.1
source independently exposes spatial stencil modes. These references support
API constraints, not the visual acceptance of this project.

## Integrated rendered review criteria

Use existing review scenes and captures; do not make a new standalone corridor.
These criteria describe observations to record, not additional claimed passes.

1. **Tardi:** Front/side and moving-lamp views must distinguish membrane from
   internal tube and organs through parallax. Track foot placement and segment
   compression during stalking, missed lunges, feeding and grooming. Euplotes
   removal requires mouth proximity and unobstructed contact; sheltering
   guide-bells remain independent. Reuse unchanged lunch evidence where valid.
2. **Guide-bells:** Inspect germination, shelter, wilt and retraction separately.
   The holdfast stays seated; rim, stalk and internal anatomy collapse together.
   Test filament visibility at grazing angles and during camera motion. A
   time-based global opacity decrease does not establish this visual contract.
3. **Tentacle exploration:** Existing front/side/back and clearance captures must
   show independently curious tips reaching real radiator surfaces without
   intersecting intervening solids. Colour must remain legible under the shared
   moving lamp; it must not imply unimplemented live strain measurements.
4. **Touch:** Inspect the contact and alarm captures alongside actual input
   checks. The touched represented pad compresses before coordinated recoil;
   highlighting, aiming, proximity and an uncompressed grab cannot start melt.
5. **Melt:** Review early retreat, root withdrawal and floor drain as a temporal
   sequence. Body and pool must overlap continuously without a mesh-switch pop.
   Require viscous broad motion, coloured folds and wet highlights alongside
   rough blackened regions. Reject water-like speed, uniform mirror finish,
   floating puddles and abruptly disappearing intact limbs.
6. **Puff:** Review early wisps, peak purple volume, late dissipation and clean
   floor, with hidden-volume and lamp-off controls. Require visible internal
   density variation and bounded disappearance. This proves volumetric smoke,
   not a portal or literal higher-dimensional space.
7. **Cost and ownership:** Retain first-use timing for emergence, melt and puff,
   full stderr, optical registration/resource retirement and installed-world
   checks. Passing the focused 100 ms hitch guard does not prove stable 60 FPS.
8. **Surface admission:** Every physical anatomy and residue surface still needs
   metric UVs, registered custom PBR and loaded filtered mip chains. Procedural
   pigment/wear does not waive primary maps. Fog retains its named optical role.

## Current evidence and remaining limits

The focused tentacle run in **tmp/tentacle_acceptance/acceptance_focused** reports
393 passing checks; the installed encounter reports 19. These are scoped
receipts, not a global surface pass. The reflection-atlas minimal control
isolates the historical seven Texture RIDs; the upstream-backported engine
removes that warning in the minimal and installed encounter runs.

The completed **tmp/tentacle_acceptance/surface_final/runtime_contract.json**
reports FAIL: 38,048 checks, 19 failures, 67 unresolved physical surfaces.
Its diagnostics include incomplete PBR, loaded-mip and sampler defects, plus
composition/traversal/capture failures. Full-run stderr additionally reports
six Mesh, two Material and one Shader RID leaks. These are distinct from the
seven Texture RIDs and remain open; do not describe all-world teardown as clean.
This review neither promotes the failed packet nor replaces the canonical
qualification evidence. Diagnose those findings before global acceptance.

## Change scope

This integration adds the decision record and links the visual criteria from
the encounter implementation guide. It deliberately makes no speculative shader,
ecology or lighting changes. Runtime implementation remains the ongoing work;
the owner's shader edits are preserved. No new requirement-ledger evidence,
save fields, selector changes or protected-world changes are introduced.
