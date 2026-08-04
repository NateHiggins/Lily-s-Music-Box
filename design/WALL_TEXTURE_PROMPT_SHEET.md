# WALL TEXTURE PROMPT SHEET — copy-paste chunks

*Sixteen source images compose every interior masonry wall finish in the
Orison. Each block below is a complete, self-contained prompt — paste
the whole chunk into Gemini (or any image model) as-is; every technical
constraint is already inside it. Save each result as a **square PNG,
1024×1024 or larger**, into `art/textures/wall_sources/` under the
**exact filename** above its block. Replacing an existing file with a
better generation is always safe — same filename wins.*

*The stated real-world coverage in each prompt matters: the baker
samples these images at physical scale (a plaster image is treated as
2.3 m of wall), so features generated at the wrong scale will read as
toy-sized or giant in game. Three slots are already filled
(`plaster_calcimine`, `plaster_distemper_green`, `plaster_tide`) —
regenerate them only if you can beat what's there.*

When done: tell Claude, or run
`python art/tools/build_wall_finish_textures.py --force` yourself.

---

## PLASTER ALBEDOS — the base surface

### `plaster_calcimine.png` *(already generated — optional upgrade)*

```
Hyperrealistic photographic texture of a 100-year-old lime plaster tenement wall covered in failing white calcimine paint: brittle chalky paint shedding in small flakes, a network of hairline craquelure cracks, faint nicotine yellowing in patches. The visible area is about 2.3 meters wide of real wall. Photographed perfectly flat and straight-on, even diffuse lighting with no cast shadows and no lighting gradient, the wall surface fills the entire frame edge to edge with no perspective, no room context, no objects, no border, no text, no watermark. Documentary architectural photography, sharp focus everywhere, square image.
```

### `plaster_distemper_green.png` *(already generated — optional upgrade)*

```
Hyperrealistic photographic texture of an aged tenement wall plastered and painted with pale institutional green distemper paint, now worn and chalky: decades of scuffs, handling grime at scattered spots, subtle old water staining, small chips revealing white plaster beneath. The visible area is about 2.3 meters wide of real wall. Photographed perfectly flat and straight-on, even diffuse lighting with no cast shadows and no lighting gradient, the wall surface fills the entire frame edge to edge with no perspective, no room context, no objects, no border, no text, no watermark. Documentary architectural photography, sharp focus everywhere, square image.
```

### `plaster_tide.png` *(already generated — optional upgrade)*

```
Hyperrealistic photographic texture of an old lime plaster wall damaged by rising damp: brown tide marks and white mineral salt efflorescence blooming across the lower third, flaking whitewash above, exposed brown scratch-coat plaster where the finish coat has fallen away near the bottom. The visible area is about 2.3 meters wide of real wall. Photographed perfectly flat and straight-on, even diffuse lighting with no cast shadows and no lighting gradient, the wall surface fills the entire frame edge to edge with no perspective, no room context, no objects, no border, no text, no watermark. Documentary architectural photography, sharp focus everywhere, square image.
```

### `plaster_parchment.png`

```
Hyperrealistic photographic texture of a century-old plaster wall aged to the color of old parchment: fine cracks, gentle trowel undulations, ghosts of two or three older paint colors showing through worn patches, decades of accumulated toning. The visible area is about 2.3 meters wide of real wall. Photographed perfectly flat and straight-on, even diffuse lighting with no cast shadows and no lighting gradient, the wall surface fills the entire frame edge to edge with no perspective, no room context, no objects, no border, no text, no watermark. Documentary architectural photography, sharp focus everywhere, square image.
```

---

## WALLPAPERS — hung by the baker in real 0.61 m rolls

### `paper_damask.png`

```
Hyperrealistic photographic texture of 1910s damask wallpaper still hanging on a tenement wall after a century: a faded burgundy damask pattern on a tan ground, the repeat about 30 centimeters tall, water stained in places, unevenly sun-bleached, colors dulled with age. The visible area is about 1.9 meters wide of real wall, so roughly three wallpaper roll widths. Photographed perfectly flat and straight-on, even diffuse lighting with no cast shadows, the papered surface fills the entire frame edge to edge with no perspective, no room context, no furniture, no border, no text, no watermark. Documentary architectural photography, sharp focus everywhere, square image.
```

### `paper_stripe.png`

```
Hyperrealistic photographic texture of early-1900s striped wallpaper aged one hundred years: narrow faded olive-green and cream vertical stripes about 4 centimeters wide, scattered brown foxing spots, old paste stains bleeding through from behind, edges slightly darkened. The visible area is about 1.9 meters wide of real wall. Photographed perfectly flat and straight-on, even diffuse lighting with no cast shadows, the papered surface fills the entire frame edge to edge with no perspective, no room context, no furniture, no border, no text, no watermark. Documentary architectural photography, sharp focus everywhere, square image.
```

### `paper_floral.png`

```
Hyperrealistic photographic texture of Victorian floral sprig wallpaper aged one hundred years on a tenement wall: small faded rose motifs about 6 centimeters apart on a grey-green ground in a half-drop repeat, water damage toning in the lower portion, overall sun-faded. The visible area is about 1.9 meters wide of real wall. Photographed perfectly flat and straight-on, even diffuse lighting with no cast shadows, the papered surface fills the entire frame edge to edge with no perspective, no room context, no furniture, no border, no text, no watermark. Documentary architectural photography, sharp focus everywhere, square image.
```

### `paper_anaglypta.png`

```
Hyperrealistic photographic texture of painted-over embossed anaglypta wallpaper on an old apartment wall: a raised Victorian relief pattern filled with many thick coats of cream paint, chips and worn spots revealing older paint layers and grey paper beneath, grime settled into the embossed recesses. The visible area is about 1.9 meters wide of real wall. Photographed perfectly flat and straight-on, even diffuse lighting with no cast shadows, the surface fills the entire frame edge to edge with no perspective, no room context, no furniture, no border, no text, no watermark. Documentary architectural photography, sharp focus everywhere, square image.
```

---

## DAMAGE STENCILS — pure black and white masks
*(These become the alpha channel: black = finish gone, brick exposed.
They must be strictly two-tone — any photographic shading here breaks
the mask.)*

### `mask_delamination.png`

```
A flat graphic stencil image, strictly pure black and pure white with no gray tones, no gradients, no shading, no texture and no color: the silhouette pattern of plaster delamination loss on a very old wall. Several large connected organic black regions with ragged, crumbling, torn coastline-like edges, occupying roughly one third of the image, mostly anchored toward the bottom and one side, with a few small satellite black islands nearby. White everywhere else. The pattern should read at the scale of about 3 meters of real wall. Hard edges only, like a paper cutout or spray stencil, square image, no border, no text.
```

### `mask_peel.png`

```
A flat graphic stencil image, strictly pure black and pure white with no gray tones, no gradients, no shading, no texture and no color: the silhouette pattern of peeling paint and small plaster losses scattered across an old wall. Many medium and small ragged black islands and thin connecting channels with crumbled irregular edges, occupying roughly one quarter of the image, loosely clustered rather than evenly sprinkled. White everywhere else. The pattern should read at the scale of about 3 meters of real wall. Hard edges only, like a paper cutout stencil, square image, no border, no text.
```

### `mask_paper_tear.png`

```
A flat graphic stencil image, strictly pure black and pure white with no gray tones, no gradients, no shading, no texture and no color: the silhouette pattern of wallpaper torn off a wall in long vertical strips. Tall ragged white strips of surviving paper alternating with torn-away black regions, tear edges jagged and curling, strips roughly 20 to 60 centimeters wide at the scale of about 3 meters of real wall, black occupying roughly one third of the image. Hard edges only, like a paper cutout stencil, square image, no border, no text.
```

---

## RELIEF HEIGHTMAPS — grayscale, brightness equals height
*(These drive the normal maps. No lighting, no shadows, no color — just
height encoded as brightness.)*

### `relief_plaster.png`

```
A technical grayscale displacement heightmap, not a photograph: brightness encodes surface height, with no lighting, no shadows, no color and no perspective. Subject: the surface relief of crumbling lime plaster over a brick wall. Raised surviving plaster crust as light gray with gentle trowel undulation, recessed damaged areas as dark gray showing horizontal brick coursing, stepped torn transitions between the two levels, fine crack lines as thin darker seams. The area shown is about 2 meters of real wall. Matte flat rendering, uniform mid-tone contrast, square image, edge-to-edge surface, no border, no text.
```

### `relief_brick.png`

```
A technical grayscale displacement heightmap, not a photograph: brightness encodes surface height, with no lighting, no shadows, no color and no perspective. Subject: an old common brick wall in running bond with raked lime mortar joints. Brick faces as lighter gray rectangles with slight per-brick height variation and worn rounded arrises, mortar joints as clearly darker recessed lines about 1 centimeter wide. Standard brick size, about 20 by 6 centimeters, with the area shown covering about 2 meters of real wall. Matte flat rendering, square image, edge-to-edge surface, no border, no text.
```

---

## STAIN OVERLAYS — isolated on pure white
*(These are multiplied over the finished surface: white areas leave the
wall untouched, colored staining darkens it. The white background must
stay clean.)*

### `stain_tide.png`

```
An isolated overlay texture on a pure clean white background: brown watercolor-like rising damp tide marks and pale mineral salt efflorescence, arranged as uneven horizontal bands with darker concentrated edge lines where each wetting cycle dried, concentrated in the lower half of the image and fading to pure white above. The area shown is about 2.8 meters of real wall. Perfectly flat, no perspective, no wall texture, no objects, no shadows — only the staining itself on white. Square image, no border, no text.
```

### `stain_leak.png`

```
An isolated overlay texture on a pure clean white background: long vertical water leak stains running from the top, brown and grey drip trails of varying width with one rusty orange streak, darker where trails begin and feathering out toward the bottom. The area shown is about 2.8 meters of real wall. Perfectly flat, no perspective, no wall texture, no objects, no shadows — only the staining itself on white. Square image, no border, no text.
```

### `stain_soot.png`

```
An isolated overlay texture on a pure clean white background: a soft grey veil of soot and smoke staining, densest along the top edge of the image and dissolving to pure white by the middle, with faint cloudy unevenness like decades of lamp smoke settled on a wall. The area shown is about 2.8 meters of real wall. Perfectly flat, no perspective, no wall texture, no objects, no shadows — only the staining itself on white. Square image, no border, no text.
```

---

## Fidelity checklist (applies to every image)

- **Square**, 1024×1024 minimum; PNG.
- **Flat-on**: no perspective, no vanishing lines, no room context.
- **Even light**: no cast shadows, no vignette, no lighting gradient
  (the game relights everything; baked-in lighting reads as dirt).
- **Edge to edge**: the surface fills the whole frame; no borders,
  frames, captions, watermarks, or text.
- **Scale discipline**: keep features at the stated real-world coverage
  — the baker samples at physical scale.
- Masks: **two-tone black/white only**. Reliefs: **grayscale only,
  brightness = height**. Stains: **on pure white**.

*Prompt vocabulary grounded in period building pathology —
calcimine/distemper failure, lath delamination, rising damp:
[Old House Web](https://www.oldhouseweb.com/how-to-advice/curing-paint-failure-problems-on-old-walls.shtml) ·
[Peter Lord Plaster & Paint](https://plasterlord.com/notebook/cures-for-calcimine-ceilings/) ·
[The Craftsman Blog](https://thecraftsmanblog.com/how-to-diagnose-plaster-problems/) ·
[Heritage House](https://www.heritage-house.org/damp-and-condensation/managing-damp-in-old-buildings.html)*
