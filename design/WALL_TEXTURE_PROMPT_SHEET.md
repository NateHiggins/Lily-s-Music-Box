# WALL TEXTURE PROMPT SHEET — brick/plaster/wallpaper, 100 years of neglect

*Sixteen source images compose every interior masonry wall finish. The
baker (`art/tools/build_wall_finish_textures.py`) crops, warps, and
combines them per wall — you never need one image per wall, just these
sixteen layers. Generate with any image model (Gemini, FLUX, etc.) and
save as `art/textures/wall_sources/<filename>.png`, 1024×1024 or
better. Square, flat-on, evenly lit, surface filling the whole frame —
no perspective, no room context, no dramatic lighting.*

*Vocabulary sourced from period building pathology: calcimine/distemper
(chalk paints that shed every later coat), plaster delaminating off its
lath keys, rising damp tide marks with salt efflorescence.*
*Research: [Old House Web on paint failure](https://www.oldhouseweb.com/how-to-advice/curing-paint-failure-problems-on-old-walls.shtml),
[Peter Lord on calcimine](https://plasterlord.com/notebook/cures-for-calcimine-ceilings/),
[The Craftsman Blog on diagnosing plaster](https://thecraftsmanblog.com/how-to-diagnose-plaster-problems/),
[Heritage House on damp](https://www.heritage-house.org/damp-and-condensation/managing-damp-in-old-buildings.html)*

Append to every ALBEDO/OVERLAY prompt:
> photographed perfectly flat and frontal, even diffuse lighting, no
> shadows cast, full-frame surface fills the whole image, documentary
> architectural photography, sharp focus

## Plaster albedos (the base coat, per-wall variety)

| File | Prompt |
|---|---|
| `plaster_calcimine.png` | hyperrealistic close texture of a 100 year old lime plaster tenement wall, failing white calcimine paint shedding in brittle flakes, hairline craquelure, faint nicotine yellowing |
| `plaster_distemper_green.png` | hyperrealistic texture of aged tenement wall plaster painted with pale institutional green distemper, worn and chalky, decades of scuffs and grime, subtle water staining |
| `plaster_tide.png` | hyperrealistic texture of old lime plaster wall damaged by rising damp, brown tide marks and salt efflorescence blooming near the bottom, flaking whitewash above |
| `plaster_parchment.png` | hyperrealistic texture of century old plaster wall the color of aged parchment, fine cracks, trowel undulations, patches of older paint colors ghosting through |

## Wallpapers (hung in 0.61 m rolls by the baker)

| File | Prompt |
|---|---|
| `paper_damask.png` | hyperrealistic texture of 1910s damask wallpaper on a tenement wall, faded burgundy pattern on tan ground, water stained, sun-bleached unevenly, edges lifting |
| `paper_stripe.png` | hyperrealistic texture of early 1900s striped wallpaper, narrow faded olive and cream vertical stripes, foxing spots, aged paste stains bleeding through |
| `paper_floral.png` | hyperrealistic texture of victorian floral sprig wallpaper aged 100 years, small faded rose motifs on grey-green ground, water damaged corners |
| `paper_anaglypta.png` | hyperrealistic texture of painted-over embossed anaglypta wallpaper, thick cream paint filling a raised victorian pattern, chips revealing older layers |

## Damage masks (pure black/white stencils — the alpha layer)

| File | Prompt |
|---|---|
| `mask_delamination.png` | high contrast black and white silhouette mask of plaster delamination loss on an old wall, large connected organic black regions with torn crumbling edges, white intact areas, binary stencil, no gradients, no shading, flat graphic |
| `mask_peel.png` | high contrast black and white stencil of peeling paint and plaster loss, scattered ragged black islands and channels, crumbled irregular coastline edges, binary mask, flat graphic, no gradients |
| `mask_paper_tear.png` | high contrast black and white stencil of torn wallpaper sheets, long vertical ripped strips, curling torn edges, black torn-away regions, binary mask, flat graphic, no gradients |

## Relief maps (grayscale height — becomes the normal map)

| File | Prompt |
|---|---|
| `relief_plaster.png` | grayscale displacement height map of crumbling plaster over brick, raised plaster crust in light gray, recessed exposed brick courses in dark gray, torn stepped edges between, technical heightmap, no lighting, no color |
| `relief_brick.png` | grayscale displacement height map of an old common brick wall with raked lime mortar joints, bricks light, mortar recessed dark, slight per-brick height variation, technical heightmap, no lighting |

## Stain overlays (on pure white — multiplied over everything)

| File | Prompt |
|---|---|
| `stain_tide.png` | watercolor-like brown water stain tide marks and mineral salt efflorescence on a pure white background, horizontal banded staining, isolated overlay texture |
| `stain_leak.png` | long vertical water leak stains running down on a pure white background, brown and grey drip trails, rust streak, isolated overlay texture |
| `stain_soot.png` | soft grey soot and smoke staining cloud on a pure white background, heavier at the top, isolated overlay texture |

## After dropping files in

```bash
python art/tools/build_wall_finish_textures.py --force
```

then the usual rebuild (gen_layout stamps ids → blender build → copy
jsons → godot import). Any file you replace with a better generation
just needs the same filename.
