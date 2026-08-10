# MATERIAL PROMPT SHEET — surface assets, slot format

*Companion to `WALL_TEXTURE_PROMPT_SHEET.md`. These are not art
requests; they are **surface asset** requests — material maps for UV
projection. Every prompt below follows the slot template:*

```
[CORE SURFACE] [KEY DETAILS/VARIATION], [CAMERA VIEW], [LIGHTING], [TILEABILITY], [TECH SPECS]
```

- **CAMERA VIEW** — `orthographic view, straight-on, flat lay` (floors
  and ceilings: `top-down`). Any perspective breaks tiling alignment.
- **LIGHTING** — `flat diffuse lighting, no shadows, no highlights,
  base color map only` — this is an ALBEDO: the game supplies all
  light; baked shading repeats as fake dirt.
- **TILEABILITY** — two classes, and the class is marked on every block:
  - **TILING**: `seamless, infinitely wrapping edges, homogeneous
    composition, evenly distributed variation, no unique landmarks` —
    one distinct chip or knot becomes a visible drumbeat when the
    engine repeats the tile every stated interval. Our pipeline still
    runs its own seamless pass as a net, but native beats retrofit.
  - **COMPOSITION**: `single complete composition filling the frame` —
    for assets the engine maps 0..1 exactly once (rug, stair tread,
    paneled surfaces). Landmarks are the point here; tiling language
    would ruin them.
- **TECH SPECS** — `square 1:1 aspect ratio, high resolution, macro
  detail, production-ready surface asset` plus the REAL-WORLD COVERAGE
  ("represents about N meters of surface") — the engine samples at
  physical scale, so detail density must match.

**Delivery:** square PNG 1024×1024+, into `art/textures/ai_sources/`
under the exact filename (Gemini default names fine — say which slot).
Contact sheets with filename labels get sliced. Ingest measures actual
feature scale on arrival and the UV audit adjusts `meters_per_tile` to
match, but the closer the generation is to the stated coverage, the
less correction distorts.

**The bar:** an AI source only takes its slot if it beats the current
set (procedural or prior AI) in-engine against period reference. The
oak lost once; slots are earned.

---

## TALKING TO THE GENERATOR — read this before blaming the prompt

*Added 2026-08-07, after a run of these came back as photographs of
objects in rooms. The blocks above are written in slot language, for a
technical artist who already knows what an albedo is. Gemini does not.
Translate before pasting; the content is right, the dialect is wrong.*

**The one sentence that fixes most of it.** Every prompt should open by
saying it is a **flatbed scanner scan** — "A flatbed scanner scan of…"
or "Photographed from directly overhead on a copy stand." Perspective,
shadow, vignette and staging are all one concept to an image model, and
that concept is *a photograph of a thing*. Naming the scanner replaces
it with a different concept the model has seen a hundred thousand times:
a flat surface, lit dead even, filling the frame. It does more work than
"orthographic, flat diffuse lighting, no shadows, no specular" combined,
because those are four separate negatives it will half-obey.

**Say what it is, not what it must not be.** Negatives are the weakest
instruction in the box; a model asked for "no shadows" will frequently
draw shadows, having been reminded of them. Prefer the positive: "lit
absolutely evenly across the whole frame, like a document scanner." Keep
the negatives only where they are cheap and specific — "no letters or
numbers anywhere" earns its place, because label-adding is the single
most common failure and it is unambiguous.

**Metres mean nothing. Counts mean everything.** "Coverage: 1.2 metres"
is precise, correct, and completely invisible to the generator, which
has no metric sense at all. Say instead how many features should be
visible across the image: *about eight tiles across* · *about five
courses of brick* · *roughly three plank widths*. Scale is the thing
ingest cannot fix well — a swatch generated at the wrong zoom either
tiles into wallpaper or blurs into mud — so this is the most valuable
sentence in the prompt. Keep the metre figure in the sheet for us;
translate it to a count for the generator.

**Stop asking for seamless.** It cannot do it. It will produce something
that *looks* seamless in thumbnail and has a visible seam at 100%, and
sometimes it draws a literal border or grid because "edges" was in the
prompt at all. `ingest_material_sources.py` runs its own seamless pass
as a net, and that pass wants a good crop, not a bad attempt at a tile.
Ask for the crop instead: **"a close crop of a much larger continuous
surface, the material filling the entire frame edge to edge."**

**Ask for the surface, not the object.** The other big failure is a
picture of the thing: a rug lying on a floor, a shelving unit standing
in a shop, an awning on a building. Add "no object edges, no background,
no floor or wall visible, no corners, the surface continues past all
four sides of the frame." A rug prompt that returns a rug has failed;
it should return *rug*.

**Keep landmarks out, and mean it.** One dramatic stain, chip or knot is
what a model reaches for to make an image interesting, and it becomes a
drumbeat the moment the engine repeats the tile. "Wear evenly
distributed across the whole surface, many small blemishes rather than
one large one, nothing that draws the eye to a single spot" beats "no
unique landmarks," which reads to a model as an art-direction note
rather than a rule. COMPOSITION-class assets are the exception and want
the opposite.

**Short beats long.** These prompts are long because they are specs.
Attention gets thinner the further down you go, so put the format first
(scanner, frame-filling, even light), the subject second, and the period
detail last — and cut any clause you would not notice missing.

### The same prompt in both dialects

Sheet language, correct and ignored:

> Seamless tileable texture of a 1960s bar floor in red-orange quarry
> tile, 15 cm square unglazed tiles with thin near-black grout […]
> Orthographic top-down view, flat lay, flat even diffuse lighting, no
> shadows, no specular, base color map only. Seamless, infinitely
> wrapping. Coverage: 1.2 metres, eight tiles across.

Generator language, same asset:

> A flatbed scanner scan of an old bar floor, red-orange unglazed quarry
> tile with thin near-black grout, about eight tiles across the image.
> Decades of spilled-drink grime darkened into the grout lines, the tile
> faces dulled unevenly by traffic, two hairline-cracked tiles and one
> old replacement in a slightly wrong red, a few small cigarette scorch
> marks. Wear spread evenly over the whole surface, many small marks
> rather than one big one. The tile grid runs square to the edges of the
> image. A close crop of a much larger continuous floor: tile fills the
> entire frame edge to edge, no background, no skirting, no floor edges,
> no objects on it. Lit absolutely evenly like a document scanner, no
> shadows and no glare. Flat matte colour only. Square image, sharp,
> high resolution, no letters or numbers anywhere.

Same information. The second one is ordered the way attention actually
falls, states the scale as a count, asks for a crop rather than a
miracle, and spends its negatives where they pay.

### If it still fights you

- **Feed it a winner.** Attach an already-accepted source from
  `art/textures/ai_sources/` and say "match this framing, lighting and
  zoom level; different material." Reference beats description.
- **Generate at the wrong zoom on purpose.** If it keeps coming back too
  close, ask for twice the feature count; the miss is usually zoom, not
  content.
- **Take the good half.** A square with three good quadrants and one
  landmark is fine — crop and let the seamless pass extend it.
- **Two or three tries, then move on.** Drop `<stem>_alt.png` or
  `<stem>_v2.png` beside the source and ingest builds `_b`/`_c`/`_d`
  family variants from the spares automatically, so a near-miss is not
  waste — it is variation.

---

## TIER 1 — architecture

### `common_brick_interior.png` — TILING
```
Aged interior common brick wall surface, 1920s tenement cellar, soft orange-brown bricks in running bond with wide irregular lime mortar joints, whitewash residue ghosting across some courses, efflorescence salts and grime in the raked joints, evenly distributed variation, no unique landmark bricks. Represents about 1 meter of wall, standard bricks about 20 by 6 centimeters. Orthographic view, straight-on, flat diffuse lighting, no shadows, no highlights, base color map only. Seamless, infinitely wrapping edges, homogeneous composition. Square 1:1 aspect ratio, high resolution, production-ready surface asset.
```

### `face_brick_street.png` — TILING
```
Weathered dark iron-spot face brick facade surface, prewar New York apartment building, deep red-brown bricks with flashed darker headers in running bond, tight raked mortar joints, uneven city soot darkening, evenly distributed variation, no unique landmark bricks. Represents about 1.1 meters of wall, standard bricks about 20 by 6 centimeters. Orthographic view, straight-on, flat diffuse lighting, no shadows, no highlights, base color map only. Seamless, infinitely wrapping edges, homogeneous composition. Square 1:1 aspect ratio, high resolution, production-ready surface asset.
```

### `limestone_carved.png` — TILING
```
Aged Indiana limestone surface from a 1920s building entrance, pale warm grey stone with fine fossil speckle, tooled finish softened by a century of weather, faint sooty toning in low spots, hairline weather cracks, homogeneous composition, no unique landmarks. Represents about 1.6 meters of stone. Orthographic view, straight-on, flat diffuse lighting, no shadows, no highlights, base color map only. Seamless, infinitely wrapping edges. Square 1:1 aspect ratio, high resolution, production-ready surface asset.
```

### `floor_oak_worn.png` — TILING *(slot retired until this beats the procedural set)*
```
Base color map of 100-year-old oak strip flooring, narrow 5.7 centimeter tongue-and-groove strips, warm amber-to-chestnut shellac tone, staggered end joints, gaps darkened with old dirt, gentle traffic dulling as a broad even gradient not a landmark path, fine grain, evenly distributed variation, no unique knots or stains. Represents about 2 meters of floor, boards running vertically. Top-down orthographic view, flat lay, flat diffuse lighting, no shadows, no highlights, base color map only. Seamless, infinitely wrapping edges, homogeneous composition. Square 1:1 aspect ratio, high resolution, production-ready surface asset.
```

### `terrazzo_lobby.png` — TILING
```
Aged 1920s lobby terrazzo floor surface, cream and grey marble chips in a warm tan cement matrix, thin brass divider strips crossing as a regular panel grid, polish dulled evenly, fine hairline settlement cracks, homogeneous composition, no unique landmark stains. Represents about 2 meters of floor with the brass grid aligned to the image edges. Top-down orthographic view, flat lay, flat diffuse lighting, no shadows, no reflections, base color map only. Seamless, infinitely wrapping edges. Square 1:1 aspect ratio, high resolution, production-ready surface asset.
```

### `stair_marble_worn.png` — COMPOSITION *(unit-mapped per tread once the per-tread UV pass lands)*
```
Single worn white-marble stair tread surface seen from directly above, the stone dished into a shallow polished valley by a century of footsteps, grey-blue veining, hairline chips along the front nosing edge at the bottom of the frame, compacted grime along the back edge at the top of the frame. Single complete composition filling the frame: one tread, about 1.2 meters wide by 30 centimeters deep stretched to the square. Top-down orthographic view, flat lay, flat diffuse lighting, no shadows, no reflections, base color map only. Square 1:1 aspect ratio, high resolution, production-ready surface asset.
```

### `wainscot_beadboard.png` — TILING
```
Painted beadboard wainscot surface, vertical tongue-and-groove boards about 8 centimeters wide with beaded joints, many coats of aged ivory oil paint, grime settled evenly into the grooves, small chips only as fine evenly distributed wear, no unique landmark damage. Represents about 0.65 meters of wall so roughly eight boards. Orthographic view, straight-on, flat diffuse lighting, no shadows, no highlights, base color map only. Seamless, infinitely wrapping edges, homogeneous composition. Square 1:1 aspect ratio, high resolution, production-ready surface asset.
```

### `trim_painted_layers.png` — TILING
```
Old painted wood surface under many coats of oil paint, aged ivory-cream, wood grain nearly drowned, alligatored and crazed paint film as fine even craquelure, only two or three small chips exposing ochre and bottle-green earlier layers, otherwise homogeneous composition with no unique landmarks. Represents about 1 meter of painted surface, macro detail. Orthographic view, straight-on, flat diffuse lighting, no shadows, no highlights, base color map only. Seamless, infinitely wrapping edges. Square 1:1 aspect ratio, high resolution, production-ready surface asset.
```

### `ceramic_hex_bath.png` — TILING
```
1920s bathroom floor of small white unglazed porcelain hexagonal mosaic tiles, 2.5 centimeter hexagons, grout aged to uneven grey-brown, one or two hairline-cracked tiles, wear as broad even toning not a landmark path, homogeneous composition. Represents about 1 meter of floor. Top-down orthographic view, flat lay, flat diffuse lighting, no shadows, no reflections, base color map only. Seamless, infinitely wrapping edges. Square 1:1 aspect ratio, high resolution, production-ready surface asset.
```

### `subway_tile_aged.png` — TILING
```
Aged white glazed subway tile wall surface, 7.5 by 15 centimeter tiles in running bond, crazed glaze with fine grey craquelure, grout lines darkened unevenly but without landmark stains, one or two chipped corners at most, homogeneous composition. Represents about 0.55 meters of wall. Orthographic view, straight-on, flat diffuse lighting, no shadows, soft even sheen only, base color map only. Seamless, infinitely wrapping edges. Square 1:1 aspect ratio, high resolution, production-ready surface asset.
```

### `concrete_cellar.png` — TILING
```
1920s hand-troweled cellar concrete floor surface, grey with faint trowel arcs, fine coal grit dusting, hairline shrinkage cracks, oil toning as broad even variation, no unique landmark patches or puddles, homogeneous composition. Represents about 2.8 meters of floor. Top-down orthographic view, flat lay, flat diffuse lighting, no shadows, base color map only. Seamless, infinitely wrapping edges. Square 1:1 aspect ratio, high resolution, production-ready surface asset.
```

### `timber_joist.png` — TILING
```
Rough-sawn old-growth structural timber surface, dense straight grain running horizontally, circular saw marks, age-darkened amber-brown, fine checks along the grain, a few small nail holes evenly distributed, no unique landmark splits. Represents about 1 meter of beam face. Orthographic view, straight-on, flat diffuse lighting, no shadows, base color map only. Seamless, infinitely wrapping edges, homogeneous composition. Square 1:1 aspect ratio, high resolution, production-ready surface asset.
```

---

## TIER 2 — metals, fixtures, machines

### `brass_aged.png` — TILING
```
Aged unlacquered sheet brass surface, warm gold with uneven brown patina, tarnish clouds, fine multidirectional scratches, small verdigris specks evenly distributed, no unique landmark spots, homogeneous composition. Represents about 25 centimeters of metal, macro detail. Orthographic view, straight-on, flat diffuse lighting, soft even sheen, no mirror reflections, no hotspot, base color map only. Seamless, infinitely wrapping edges. Square 1:1 aspect ratio, high resolution, production-ready surface asset.
```

### `enamel_appliance_smooth.png` — TILING (emits `enamel_appliance`)
```
Authentic warm ivory vitreous enamel surface from a well-used 1922–1928 domestic gas range. The fired glaze is fundamentally smooth: most of the surface remains calm and continuous, with sparse hairline crazing in only a few small areas, a handful of pinprick dark chips exposing black iron, faint warm cleaning discoloration and extremely subtle hand-polished variation. Never stucco, plaster, concrete, orange peel, pebbled paint or dense full-surface crackle. Represents about 0.72 metres of enamel. Orthographic close crop containing only the material surface, flat diffuse evenly-lit document scan, no highlights, shadows, vignette, gradient, reflected room, baked lighting or directional landmark. Seamless and infinitely wrapping on every edge. Square 1:1, high resolution, no letters, numbers, words, labels, logos, borders, fixtures, handles, perspective or watermark.
```

### `galvanized_aged.png` — TILING
```
Aged galvanized sheet steel surface from old ductwork, dull grey spangled zinc crystal pattern, white oxidation bloom in soft even patches, light streaky handling marks, no unique landmark rust or rivet lines, homogeneous composition. Represents about 0.8 meters of metal. Orthographic view, straight-on, flat diffuse lighting, no hard reflections, base color map only. Seamless, infinitely wrapping edges. Square 1:1 aspect ratio, high resolution, production-ready surface asset.
```

### `cast_iron_radiator.png` — TILING
```
Painted cast iron surface from a 1920s radiator, many coats of metallic silver-bronze paint over an older cream layer, brush-dabbed unevenly, rust freckles bleeding up through the silver evenly across the surface, sand-cast graininess showing under the paint, at most two small chips to black iron, no unique landmark damage, homogeneous composition. Represents about 40 centimeters of painted metal, macro detail. Orthographic view, straight-on, flat diffuse lighting, soft metallic sheen, no hotspot, no shadows, base color map only. Seamless, infinitely wrapping edges. Square 1:1 aspect ratio, high resolution, production-ready surface asset.
```

### `porcelain_fixture_smooth.png` — TILING (emits `porcelain_fixture`)
```
Authentic warm ivory vitreous china glaze from a c.1920s New York apartment lavatory. The hard fired surface is overwhelmingly smooth and calm, with extremely subtle diffuse mineral haze, minute pinholes and only a very few isolated short hairline crazing marks. No bowl shape, drain, faucet, fixture edge, circular ring, concentric wear, reflected room, gradient, vignette, baked shadow, hotspot, rust streak, aggregate, plaster, concrete, orange peel, speckled stone, dense crackle or directional landmark. Represents about 0.40 metres of glaze. Orthographic close crop containing only the material surface, flat diffuse evenly-lit document scan, seamless and infinitely wrapping on every edge. Square 1:1, high resolution, no letters, numbers, words, labels, logos, borders, perspective or watermark.
```

### `bakelite.png` — TILING
```
Aged dark brown bakelite surface, deep chocolate marbled swirl, polish gone slightly matte with fine micro-scratches, handling patina as broad even toning, no unique landmark chips, homogeneous composition. Represents about 30 centimeters, macro detail. Orthographic view, straight-on, flat diffuse lighting, soft sheen, no mirror reflections, base color map only. Seamless, infinitely wrapping edges. Square 1:1 aspect ratio, high resolution, production-ready surface asset.
```

---

## TIER 3 — floors and soft goods

### `linoleum_kitchen.png` — TILING
```
1930s inlaid linoleum kitchen floor surface, faded geometric checker pattern in oxblood red, cream and grey-green, squares about 6 centimeters, decades of wax yellowing as broad even toning, fine heel scuffs evenly distributed, no unique landmark wear-throughs. Represents about 0.8 meters of floor with the checker grid aligned to the image edges. Top-down orthographic view, flat lay, flat diffuse lighting, no reflections, base color map only. Seamless, infinitely wrapping edges, homogeneous composition. Square 1:1 aspect ratio, high resolution, production-ready surface asset.
```

### `walnut_furniture.png` — TILING
```
Aged walnut furniture wood surface, rich brown cathedral grain under thin worn shellac, honey sun-fading as a broad even gradient, fine scratches evenly distributed, no unique landmark rings or damage, grain running vertically. Represents about 0.6 meters of wood. Orthographic view, straight-on, flat diffuse lighting, soft sheen, no hard reflections, base color map only. Seamless, infinitely wrapping edges, homogeneous composition. Square 1:1 aspect ratio, high resolution, production-ready surface asset.
```

### `upholstery_rust.png` — TILING
```
Aged rust-orange mohair upholstery fabric surface, dense short pile with even crushing variation, sun-fading as broad gradients, fine fuzz, no seams, no piping, no unique landmark patches, homogeneous composition. Represents about 0.6 meters of fabric. Orthographic view, straight-on, flat diffuse lighting, no shadows, base color map only. Seamless, infinitely wrapping edges. Square 1:1 aspect ratio, high resolution, production-ready surface asset.
```

### `rug_persian_worn.png` — COMPOSITION *(unit-mapped: the full rug maps 0..1 exactly once)*
```
Complete worn 1920s Persian wool rug seen from directly above, full border pattern around a field with a central medallion, muted madder red, indigo and cream, pile worn to visible warp threads along realistic traffic zones, colors softened by decades of sun, one moth-worn patch. Single complete composition filling the frame edge to edge: the whole rug, about 1.5 by 1.5 meters, no floor visible, no fringe overhang. Top-down orthographic view, flat lay, flat diffuse lighting, no shadows, base color map only. Square 1:1 aspect ratio, high resolution, production-ready surface asset.
```

### `linen_aged.png` — TILING
```
Aged household linen fabric surface, plain weave natural flax, yellowed fold-line toning as soft even bands, pressed-flat gentle rumple, no unique landmark stains or mends, homogeneous composition. Represents about 0.5 meters of cloth. Orthographic view, flat lay, flat diffuse lighting, no shadows, base color map only. Seamless, infinitely wrapping edges. Square 1:1 aspect ratio, high resolution, production-ready surface asset.
```

---

### `mirror_aged.png` — TILING
```
Square, high-resolution, seamless, flat evenly-lit document-scan material swatch of aged early-twentieth-century back-silvered bathroom mirror viewed from the glass side; pale cool silver-grey with faint warm mercury-grey clouding, sparse black pinprick oxidation, subtle damp haze and very fine cleaning scratches, extremely low contrast, no reflected room, no reflected objects or people, no highlights, no perspective, no frame, no border, no watermark, no letters, numbers, words, labels, symbols or logos. Edge-to-edge infinitely wrapping surface, production-ready base color asset.
```

---

## TIER 4 — exterior and grounds

### `sidewalk_slab.png` — TILING
```
Aged New York bluestone and concrete sidewalk surface, large weathered slabs with dark grime-filled expansion joints aligned to the image edges, hairline cracks and mica sparkle evenly distributed, no unique landmark patches or gum spots. Represents about 2.5 meters of pavement. Top-down orthographic view, flat lay, overcast flat lighting, no shadows, base color map only. Seamless, infinitely wrapping edges, homogeneous composition. Square 1:1 aspect ratio, high resolution, production-ready surface asset.
```

### `asphalt_street.png` — TILING
```
Aged city asphalt street surface, grey-black aggregate with even polish variation, fine alligator cracking evenly distributed, no lane paint, no potholes, no unique landmark patches, homogeneous composition. Represents about 2.5 meters of road. Top-down orthographic view, flat lay, overcast flat lighting, no shadows, base color map only. Seamless, infinitely wrapping edges. Square 1:1 aspect ratio, high resolution, production-ready surface asset.
```

### `tin_ceiling.png` — TILING
```
1920s pressed tin ceiling surface, repeating 30 centimeter embossed square panels with a floral rosette motif, the panel grid perfectly aligned to the image edges, many coats of cream oil paint, rust bleeding softly at panel seams evenly across the surface, no unique landmark stains. Represents about 1.2 meters so a 4 by 4 panel grid. Orthographic view, straight-on, flat diffuse lighting, no shadows, base color map only. Seamless, infinitely wrapping edges. Square 1:1 aspect ratio, high resolution, production-ready surface asset.
```

### `marble_lobby_base.png` — COMPOSITION *(unit-mapped per panel at placement)*
```
Single aged white Vermont marble wainscot panel from a 1920s lobby, white stone with soft grey clouded veining, a simple rectangular border profile framing the panel, polish gone matte at hand height as an even band, fine chips along the base edge. Single complete composition filling the frame: one panel, about 1.5 meters wide by 1 meter tall stretched to the square. Orthographic view, straight-on, flat diffuse lighting, no reflections, base color map only. Square 1:1 aspect ratio, high resolution, production-ready surface asset.
```

---

## APPLIANCE IDENTITIES — the same enamel, five lives

*The landlord bought forty identical ranges; a century of tenants made
them different. These five wear-variants map onto the appliance bible's
per-apartment table. All TILING, all the same base white, distinguished
only by what happened to them. Save as `enamel_<name>.png`.*

### `enamel_pristine.png` — Mae 6C, Evelyn 1A
```
Aged white porcelain enamel appliance surface kept meticulously for a century, fine even crazing across the glaze, no chips, faint circular polish swirl from decades of careful wiping, uniform ivory tone, homogeneous composition, no unique landmarks. Represents about 0.85 meters of enamel. Average surface color approximately #F2EEE2, neutral 6500K white balance, sRGB, mid-tone exposure, no vignette. Orthographic view, straight-on, flat diffuse lighting, soft even sheen, no hard reflections, base color map only. Seamless, infinitely wrapping edges. Square 1:1 aspect ratio, high resolution, production-ready surface asset.
```

### `enamel_paintflecked.png` — Iris 5C
```
Aged white porcelain enamel appliance surface in a painter's kitchen, scattered dried oil-paint flecks in ochre, viridian and lead white distributed evenly across the whole surface, faint coloured thumbprints, underlying crazed glaze, homogeneous composition, no unique landmark spills. Represents about 0.85 meters of enamel. Average surface color approximately #E9E3D2, neutral 6500K white balance, sRGB, mid-tone exposure, no vignette. Orthographic view, straight-on, flat diffuse lighting, soft even sheen, base color map only. Seamless, infinitely wrapping edges. Square 1:1 aspect ratio, high resolution, production-ready surface asset.
```

### `enamel_dented.png` — Cam 4C
```
Aged white porcelain enamel appliance surface, hard-used: shallow dents evenly distributed, chipped enamel at several points showing dark steel with thin rust halos, scuff marks from bags and buckles, crazed glaze between, homogeneous composition, no single dominant dent. Represents about 0.85 meters of enamel. Average surface color approximately #E4DDCC, neutral 6500K white balance, sRGB, mid-tone exposure, no vignette. Orthographic view, straight-on, flat diffuse lighting, soft sheen, base color map only. Seamless, infinitely wrapping edges. Square 1:1 aspect ratio, high resolution, production-ready surface asset.
```

### `enamel_greasy.png` — Juno 2C, Jonah 6B
```
Aged white porcelain enamel appliance surface gone amber with cooking film, an even veil of grease and nicotine toning, fingerprints and smears distributed across the whole surface, crazed glaze darkened in the craze lines, homogeneous composition, no unique landmark stains. Represents about 0.85 meters of enamel. Average surface color approximately #DCD2B8, neutral 6500K white balance, sRGB, mid-tone exposure, no vignette. Orthographic view, straight-on, flat diffuse lighting, soft sheen, base color map only. Seamless, infinitely wrapping edges. Square 1:1 aspect ratio, high resolution, production-ready surface asset.
```

### `enamel_workshop.png` — Omar 3B
```
Aged white porcelain enamel appliance surface belonging to a repairman, masking-tape residue rectangles distributed across it, faded marker numbering and small handwritten codes, one region of slightly mismatched replacement paint, crazed glaze, homogeneous composition, no unique landmark labels. Represents about 0.85 meters of enamel. Average surface color approximately #E6E1D4, neutral 6500K white balance, sRGB, mid-tone exposure, no vignette. Orthographic view, straight-on, flat diffuse lighting, soft sheen, base color map only. Seamless, infinitely wrapping edges. Square 1:1 aspect ratio, high resolution, production-ready surface asset.
```

---

## COLOR ANCHORS — absolute references

Append to any prompt for tighter color fidelity: *"average surface
color approximately #HEX, neutral 6500K white balance, sRGB, mid-tone
exposure, no vignette"*. The pipeline also ENFORCES these at ingest
(each delivered albedo's mean is pulled halfway to its anchor,
variation preserved), so a generator that drifts still lands on grade:

| Slot | Anchor | Slot | Anchor |
|---|---|---|---|
| floor_oak | `#9A6132` | common_brick | `#A5663F` |
| face_brick | `#6B3B33` | brick | `#8A4A3A` |
| trim / baluster | `#E3DAC3` | wainscot | `#E5DCC6` |
| limestone | `#C8C1B1` | terrazzo | `#C7BDA6` |
| stair | `#DCD9D2` | ceramic hex | `#ECE7DC` |
| subway_tile | `#EAE4D6` | concrete / slab | `#98958E` |
| timber | `#8A6A48` | brass | `#A67C3E` |
| appliance | `#F0EBDE` | metal | `#9AA0A0` |
| cast_iron | `#B5B2AA` | porcelain | `#EFE9D6` |
| bakelite | `#452C20` | linoleum | `#B08A6A` |
| walnut | `#5C3A26` | upholstery | `#B0552F` |
| rug | `#9E4A3C` | linen | `#D8CBAA` |
| sidewalk | `#9A9A92` | asphalt | `#4B4B49` |
| tin_ceiling | `#E2DAC6` | marble_lobby | `#E8E6E0` |

## Why the slots matter here specifically

Three in-engine failures this pipeline already survived, each traceable
to a missing slot: the oak tile carried **baked lighting** (orange
blotches repeating as fake stains — LIGHTING slot), the trim carried a
**unique landmark** (one chip cluster drumming every 40 cm — the
homogeneity term), and object photos carried **perspective** (a radiator
with shading, a sink with its drain — CAMERA slot). Every block above
exists to make those three mistakes impossible to request.
