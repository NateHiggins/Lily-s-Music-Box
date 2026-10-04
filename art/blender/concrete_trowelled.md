# Trowelled concrete and slab finish

Evidence class: **INERT**

Classification: **ADAPTATION**. The existing **concrete**, **concrete_b**,
**concrete_c**, **concrete_d**, **slab**, **slab_b**, **slab_c** and **slab_d**
catalogue families use a quieter cement-paste plate. The former plate repeated
large crack and tool bands across service walls, floors and neighbouring roofs.
The replacement retains each family's 2.8-metre chart and mean RGB within 1.1
channel units. Positional damage remains the responsibility of local owners.

## Source and rebuild

**art/textures/ai_sources/concrete_trowelled.png** is a 1254-square RGB source
generated with the built-in ImageGen tool on 2026-10-04. Its SHA-256 is
**23a5ff6e2552e0a5e7cf63be4c5f4a6b9de5a1fc82e34cdc398b9ddd7e58a003**.
It has no lettering, baked object edges or reference photograph. The former
**concrete_cellar.png** and **concrete_cellar_alt.png** remain historical art.
Two coarser scratch plates were rejected before this source was selected.

The generation prompt was:

> Use case: photorealistic-natural. One square seamless PBR BASE COLOUR source
> plate of mature, well-trowelled poured concrete, a flat orthographic material
> scan covering 2.8 metres square edge to edge. Calm medium warm grey cement
> matrix, with diffuse low-contrast curing mottles and very fine silty mineral
> texture. This is smooth trowelled concrete: the sand grains are below half a
> millimetre and should be mostly unresolved at the image's scale. Only
> occasional tiny irregular dark 1–3 millimetre pinholes, widely separated.
> Mostly intact quiet cement paste, faint subtle clouding, very delicate
> hair-thin tool variation with no obvious direction. The appearance must be
> smoother and quieter than exposed-aggregate concrete: NO individually
> prominent stones or white chips, NO gravel or pebbled stucco, NO busy stipple,
> terrazzo or coarse sandy granules. Matte, mineral and photoreal; natural
> variation at a broad scale with extremely delicate surface detail. Base
> colour only under perfectly uniform diffuse illumination. No directional
> light, shadows, ambient occlusion, highlights, cracks, edges, panel seams,
> form-board patterns, borders, objects, perspective, words, numbers, letters,
> symbols, logos or watermarks. Seamless all four edges. Fill the whole square
> with the material plane, never a concrete wall, room or object.

Rebuild using:

    python art/tools/ingest_material_sources.py --slot concrete_trowelled
    python art/tools/ship_surface_tables.py --key concrete --key concrete_b --key concrete_c --key concrete_d --key slab --key slab_b --key slab_c --key slab_d
    python art/tools/ingest_material_sources.py --check

The single source produces all four retained members in each family through
quarter-turn phase changes and the existing family synthesis. There are no new
catalogue keys. The ingest flattens illumination and blends boundaries;
independent periodic microrelief, small pores and subtle tool variation span
**0.8 mm**. Normal slopes derive from that height field in metres. Roughness
remains approximately **0.858**. Pigment cannot carve cracks or aggregate.
Normal, roughness and height are 512-square; base albedo is 1024-square and
family albedos are 972-square. The shipper preserves authored height pixels and
the **0–1** range, with the existing owner relief multiplier.

The semantic concrete factory supplies a stable **M_concrete** copy to
SurfacePass so that actual service walls and floors bind their height. It
preserves separate wall/floor recipes and leaves shared MatLib resources intact.
The previously accepted stair identity and calibration remain active.

After a reviewed material change, refresh only the existing **concrete_b** and
**slab_b** texture pins in the first-floor manifest:

    python art/tools/rebind_catalog_textures.py --base <reviewed-before-commit> --key concrete_b --key slab_b --write

The tool validates every cell and protected input and changes six existing
texture hash/size rows plus the registry manifest pin. Rebuild the city material
master with **art/blender/scripts/build_city_closure.py** in background Blender.
Its generated reports update three concrete source bindings. The delivered
**city_shells.glb** remains byte-identical to **d1a204b9**: 335 source records,
25 joined parapet rings, 84 partitions and 14,098 triangles.

## Inspection

Sixteen Blender comparisons cover both views of all eight families with
immutable before maps extracted from **d1a204b9**. Four delivered game captures
compare the actual basement wall and floor against the same old map bytes:
**2,376 checks, zero failures**. These use the production environment, practical
lighting and unchanged lamp; the carrier capture toggle hides the handheld.
Geometry and material owners are retained. Local records are in
**tmp/material-review/native-concrete-production** and
**tmp/material-review/concrete-delivery**.

**HonedStairMaterialTest** now checks active physical calibration on **294**
stair and **247** concrete architectural surfaces, separate wall/floor recipes,
stable caches and unchanged shared materials. The Python map suite checks
pigment independence, physical normal slopes and unchanged authored shipping
for both mineral models. One new test asset reference was appended to the
spatial manifest without removing historical records.

The city closure suite checks the real inventory, charts, matching collision,
all joined parapets and **1,205** original roof-hardware contact samples:
**2,074 checks, zero failures**, with 29 windowed captures. Its process record
is **tmp/material-review/city-concrete.log.receipt.json**. Wrapper receipts and
this note are INERT; they do not confer runtime-contract or ledger promotion.
Other material families and the broader construction review remain open.

A fresh-output rebuild reproduced **73** delivered files with zero differences
and left both catalogue owners unchanged. An earlier in-place attempt stopped
on a Windows invalid-argument file-open error; it provides no rebuild verdict.
The successful comparison kept all delivered paths read-only and generated into
a temporary directory. Its record is
**tmp/material-review/concrete-rebuild-determinism.json**.
