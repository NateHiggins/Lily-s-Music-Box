# DREAM-CRITTER-VOXEL-V3 implementation receipt

Status: **human visual atlas accepted for a bounded branch commit; not merged**.

## Human visual review — 2026-08-31

PASS for the static twelve-species atlas. The review found twelve genuinely
different biological strategies rather than palette variants. Lacrymaria's
extended neck, Euplotes' plated crawling form, the heliozoan axopods,
Bacillaria's raft and Salpingoeca's rosette were the strongest reads.

Before merge, a bounded motion packet must prove the existing twelve
presentation laws under the shared voxel field. It must especially separate
Volvox from Noctiluca and Stentor from Vorticella. The shared dark membrane can
also suppress internal anatomy in some views; this is recorded as non-blocking
debt and does not authorize new materials or geometry.

## Result

Twelve source-derived microorganisms were added to the four existing authored
fauna species:

1. Stentor
2. Lacrymaria
3. Vorticella
4. Euplotes
5. Spirostomum
6. Actinosphaerium-like heliozoan
7. Euglena
8. Volvox
9. Noctiluca
10. Bacillaria
11. Salpingoeca rosetta
12. Mesodinium

The research-to-form mapping and primary references are in
`MICROORGANISM_RESEARCH.md`.

## Production architecture

- `DreamCritterSpecies.Kind` now has 16 stable authored plans.
- `DreamCritterGenerator` still produces bounded individual variation inside
  each plan; it does not synthesize arbitrary species.
- `DreamCritterController` still owns one batched mesh, one shared
  `ShaderMaterial`, up to eight live animals and twelve draw slots.
- The existing primitive pool is unchanged: body, eight limb bundles, twelve
  feelers, bounded detail bodies, fibers and terminal branches.
- The complete draw remains **84,000 triangles, one mesh surface, one material
  and one fauna draw**. Adding twelve species did not add geometry to the batch.
- All 16 plans sample the same world-owned `DreamExposureField` `ImageTexture3D`.
  No per-organism field, texture, mesh or material was added.
- G remains reversible current irradiance. R remains durable exposure history.
  Each species has a distinct named optical interpretation; channel authority
  is unchanged.
- The twelve presentation laws animate cell mechanics only. They never write
  ecology goals, prey choice, phenotype, senescence or colony decisions.

## Authored visual mechanisms

- Stentor: oral spiral, cortical myonemes and habituating contraction.
- Lacrymaria: one telescoping helical neck, terminal head and stochastic reach.
- Vorticella: peristomial vortex and one coiling spasmoneme stalk.
- Euplotes: armored dorsal shield and gait-state cirral bundles.
- Spirostomum: twisting contraction front, cortical fishnet and damped interior.
- Heliozoan: primary/secondary axopod sun and one retracting capture ray.
- Euglena: spiral metaboly, single flagellum, eyespot and chloroplast packets.
- Volvox: cellular parent sphere, daughter bulges and radial bridges/flagella.
- Noctiluca: giant vacuolate rind, capture tentacle, cords and scintillon wave.
- Bacillaria: parallel perforated silica frustules sliding as one raft.
- Salpingoeca: attached clonal rosette, intercellular bridges and outward flagella.
- Mesodinium: bilobed host, ciliary girdles, kleptokaryon and borrowed plastids.

## Verification

### Focused deterministic test

Command:

```text
Godot_v4.7.1-stable_win64_console.exe --headless --path game \
  res://tests/DreamCritterVoxelTest.tscn
```

Result:

```text
[DREAM-CRITTER-VOXEL] checks=2104 failures=0 species=16 triangles=84000
materials=1 shared_texture=1 per_critter_field=false
```

Coverage includes 128 generated individuals per species, all 16 unique laws,
all 16 named voxel-optics functions, shared geometry functions, bounded batch,
one-field binding/teardown, presentation-law advancement and an explicit check
that presentation leaves ecology authority untouched.

### Production ecology regression

Command:

```text
Godot_v4.7.1-stable_win64_console.exe --headless --path game \
  res://tests/DreamCritterTest.tscn
```

Result:

```text
DREAM CRITTER TEST: PASS (43/43)
```

The live Orison run naturally spawned five of the new species in its first
census and seven in its final census, retained one draw/material, walked on the
architecture, and preserved the original four species' impossible-law tests.
Existing unrelated resident-navigation warnings were emitted during the Orison
fixture; they did not fail the critter test.

### Forward+ atlas

Renderer:

```text
Vulkan Forward+ — NVIDIA GeForce RTX 4080
```

Result:

```text
[DREAM-MICROORGANISM-ATLAS] species=12 materials=1 textures=1 fields=1
per_species_allocations=false
```

Artifact: `art/renders/dream_critter_voxel_v3/dream_microorganism_atlas.png`
(2400×1800). Every panel uses the same enclosed white microscopy room, physical
lights, shared production material and shared real RG8 field.

## Scope held

- No new ecology or light simulation authority.
- No per-species or per-organism material allocation.
- No global selector/default changes.
- No Orison architecture edits.
- No S2J/L1D status changes.
- No merge and no commit.
