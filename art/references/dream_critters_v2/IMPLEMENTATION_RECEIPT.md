# DREAM-CRITTER-VOXEL implementation receipt

## Result

Four authored critter species now share one bounded runtime draw and interpret
the production `DreamExposureField` through four different object-space optical
grammars. The new fourth species is a 0.55–0.72 m tardigrade: deliberately
house-cat sized, while retaining four leg pairs, paired claws, a circumoral
apparatus, stylets, sucking pharynx, storage-rich gut, cuticle folds and the
posterior-to-anterior gait relation reported in the research checkpoint.

## Authority and resources

- `LampOpticalInstrument` remains the instantaneous physical-light owner.
- `DreamExposureField` remains the only RG8 voxel authority.
- `DreamVoxelLightPresenter` binds that one world texture to the existing
  `DreamCritterController`; it creates no fauna field or material.
- `DreamCritterController` retains one `ShaderMaterial`, one `ArrayMesh`, one
  surface and one draw for all live species.
- No per-critter field, texture, mesh construction or material is introduced.
- The existing `DREAM_VOXEL_LIGHT=1` capability remains default-off. No selector
  default changed.

## Four optical expressions

| Species | Object-space microanatomy | Current G | Durable R |
|---|---|---|---|
| Seam grazer | wet ventral comb, bifurcating/rejoining capillaries, pores | comb front and live capillary flow | seam-following vascular memory |
| Crystal listener | stationary dark dome, rotating angular ribs and resonant chambers | polarized moving caustics | angular mineral lattice memory |
| Fold crab | dorsal plates, dark sutures, socket-to-ventrum load paths, transfer rosette | local mechanical load paths | sutures and rear rosette |
| Cat-sized tardigrade | folded reticulate cuticle, pseudopores, projected pharynx/gut, muscle fields, high-index claws | near-side pharynx, gut transport and muscle work | annuli, gut route, pseudopores and claws |

The surface remains opaque/depth-writing. Thickness, SSS transmittance,
backlight, phase-boundary relief and projected internal absorption provide the
microscopy read; whole-shell alpha was not reintroduced.

## Bounded geometry and focused verification

- Full twelve-slot batch: **84,000 triangles**.
- Live cap: eight animals; buffer cap: twelve slots (including grazer twins).
- Material count: **1**.
- Shared voxel texture count: **1**.
- Focused headless receipt: **526 checks, 0 failures**.
- Forward+ renderer: Vulkan on NVIDIA RTX 4080; shader compiled without error.
- Forward+ staged history/current split (presentation diagnostics, not painted
  panel values): left R/G **0.102/0.000**, right R/G **0.020/0.109**.
- Contact sheet: `art/renders/dream_critter_voxel_v2/dream_critter_voxel_species_contact_sheet.png`.

The existing DREAM-VOXEL-V1 adapter suite passes **19/19**. The full-Orison
`DreamCritterTest` passes **43/43** after its test fixture was brought up to the
current production contract by explicitly arranging mature complex moss
habitat and one law subject of each species. That change is confined to the
harness; production ecology and stochastic birth selection are unchanged.

## Research grounding

The primary-source anatomy and optics notes, direct links, and the mapping from
observed biological features to runtime forms are in
`TARDIGRADE_RESEARCH.md`. The scaled creature is explicitly speculative in
size; the retained anatomy is not presented as a claim about real tardigrade
allometry.
