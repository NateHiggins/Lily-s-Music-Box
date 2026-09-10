# Lamp material integration: shared Dream response and opaque tissue

Continues the owner's request to integrate all materials. This packet is a
tested integration checkpoint, not completion of all material or V2 gates.
Base: 9473df4, canonical Astra worktree. No geometry or ecological-law edit.

## Production changes

- Separate opaque eyeball/flesh lids from transparent cornea/third eyelid.
  Previously any ALPHA write in the shared shader selected the transparent
  pipeline, including the opaque branches. Shared shader includes preserve the
  original vertex and tissue calculations; only transparent variants write ALPHA.
  This correction affects the shared ocular owner, including V1.
- Dream architecture, lineage gold and fauna read the instantaneous optical
  field for direct response instead of the rate-limited ecological G channel.
  Durable R still selects colour bands. Bound direct response cannot be sustained
  by either ecological channel after the lamp turns off. Unbound consumers retain
  the previous response; Compatibility does not create the compute bridge.
- The real Dream root observes its existing lamp presentation through one field.
  Its gutter/electrical owner and DreamExposureField remain unchanged. This does
  not install the waking thermal driver into Dream or complete sleep/wake handoff.
- V2's existing optical registry binds late Dream surface overrides, including
  MultiMesh instances. Shared materials stay bound until their last registered
  surface leaves. These surfaces retain their geometry, visibility and render
  layers. The separate glass haze retains its lamp-only layer policy.
- Pending optical initialization is dark, not an ecological fallback; field
  failure disables bound samples. Teardown clears ownership and resources.

The shared direct-response normalization is 4.0 and luminance based. It is an
art response scale, not a measured physical material coefficient. This packet
does not claim full spectral hue transfer or additional material performance gains.

## Final checks

| Run | Result | What it establishes |
| --- | --- | --- |
| tissue_03 | 5/0 | Real ocular owner selects separate variants; original-vs-candidate depth-buffer controls restore opaque depth for lids and globe |
| irradiance_01 | 16/16 | Existing real Dream root gutter, pursuit, hazard and ecological irradiance checks remain valid |
| dream_05 | 45/0 | Actual root binds all three shaders; direct on/off despite maximal retained exposure, translated-away rejection, legacy fallback, retirement and field release |
| receivers_02 | 22/0 | Native glass shadow controls plus late/shared binding and last-user cleanup for each Dream shader |
| native_02 | 24/0 | Twelve native material variants respond to a spotlight and lose its contribution behind a real mesh shadow |
| composed_01 | 38/0 | Existing V2 air/dust/glass composition, lamp control and resource teardown regression |

150 checks in these scoped suites, no failures; final stderr files empty.
All engine runs used the existing exclusive serial runner and 180-second ceiling.

Native fixture order, left to right, top to bottom: hero flesh, gold, crystal,
membrane skin; wet sucker, cilium skin, orbital flesh cilium, orbital gold cilium;
orbital crystal cilium, flesh lid, eyeball, third eyelid. The spheres deliberately
exercise shaders, including the actual cilia MultiMesh custom-data selector.
They are not modeled anatomy, authored UV/map acceptance, or an S2J replacement.
Authored emission remains present in the off control and is subtracted from the
measured lamp contribution. Backlit captures are visual records, not a separate
quantitative SSS or transmission acceptance.

Dream captures include the actual root's optical/legacy/restored material modes.
The frozen root prevents gameplay advancement, but shader TIME is not frozen:
these are visual controls, not a claim of exact pixel restoration. The synthetic
response probe separately measures on=1, off=0, translated=0, legacy=1.

## Material coverage and remaining work

| Family | Current integration | Still open |
| --- | --- | --- |
| Ordinary opaque surfaces | Native spotlight and shadow map | Composed visual acceptance across rooms |
| Wet flesh / clearcoat | Existing native PBR, native shadow controls pass | Authored close-range material review |
| Fine gold/flesh/crystal fibers | Existing native anisotropy and MultiMesh selectors, native shadow controls pass | Actual geometry/coverage and aliasing review |
| Thin tissue | Native backlight and transparent membrane variants preserved | Thickness-dependent transmission and interior scattering |
| Subsurface flesh | Opaque depth routing restored; native SSS outputs retained | Quantitative SSS and actual anatomy review |
| Cellular/lineage/architectural Dream surfaces | Instantaneous optical response bound in Dream and V2 | Full spectral transfer and scene-geometry occlusion in voxel field |
| Clear glass | Previous 3B native dielectric plus shared-field haze retained | Other authored glass consumers; green table glass remains unidentified |
| Air / dust | Previously integrated field with native mesh-shadow attenuation | Full effect/scene performance acceptance |
| Cloud interiors / depth structures | Existing authored surface treatment remains | True interior volume integration and preserved-anatomy composed proof |

The optical field still accepts at most eight explicit analytic AABB blockers.
This work does not voxelize the building's mesh geometry. Native PBR/air/glass
shadow controls must not be presented as mesh-shadow acceptance for unshaded
Dream field consumers. Failed S2J anatomy status remains failed/open. V1 remains
the selector default; full V2 completion, human acceptance and release remain open.

## Retained unsuccessful fixtures

- tissue_01/02: depth probe pass/culling setup was wrong; fixed for tissue_03.
- dream_01: inferred Variant warning treated as a parse error; corrected type.
- dream_02: center sample intersected UI and the empty array lacked its element
  type. Corrected fixture camera/environment/UI isolation and typed array.
- dream_03/04, native_01: passing intermediate fixtures superseded by the broader
  final controls. No failed shader result is treated as a pass.

Original shaders are retained under tests/fixtures/lamp_material for depth controls.
See summary.json for source hashes and recorded final log status.
