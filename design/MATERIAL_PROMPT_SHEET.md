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

### `enamel_appliance.png` — TILING
```
Aged white porcelain enamel surface from a 1930s kitchen appliance, creamy white yellowed unevenly, fine spider-web crazing across the whole surface, cleaning micro-scratch swirls, at most two small chips with thin rust halos, otherwise homogeneous composition with no unique landmarks. Represents about 0.85 meters of enamel. Orthographic view, straight-on, flat diffuse lighting, soft even sheen, no hard reflections, base color map only. Seamless, infinitely wrapping edges. Square 1:1 aspect ratio, high resolution, production-ready surface asset.
```

### `galvanized_aged.png` — TILING
```
Aged galvanized sheet steel surface from old ductwork, dull grey spangled zinc crystal pattern, white oxidation bloom in soft even patches, light streaky handling marks, no unique landmark rust or rivet lines, homogeneous composition. Represents about 0.8 meters of metal. Orthographic view, straight-on, flat diffuse lighting, no hard reflections, base color map only. Seamless, infinitely wrapping edges. Square 1:1 aspect ratio, high resolution, production-ready surface asset.
```

### `cast_iron_radiator.png` — TILING
```
Painted cast iron surface from a 1920s radiator, many coats of metallic silver-bronze paint over an older cream layer, brush-dabbed unevenly, rust freckles bleeding up through the silver evenly across the surface, sand-cast graininess showing under the paint, at most two small chips to black iron, no unique landmark damage, homogeneous composition. Represents about 40 centimeters of painted metal, macro detail. Orthographic view, straight-on, flat diffuse lighting, soft metallic sheen, no hotspot, no shadows, base color map only. Seamless, infinitely wrapping edges. Square 1:1 aspect ratio, high resolution, production-ready surface asset.
```

### `porcelain_fixture.png` — TILING
```
Aged vitreous china surface from a 1920s bathroom fixture, white glaze grown ivory with age, fine network of crazing lines stained pale tan, faint mineral haze as broad even variation, no drain, no fixture edges, no unique landmark cracks, homogeneous composition. Represents about 40 centimeters of glaze, macro detail. Orthographic view, straight-on, flat diffuse lighting, soft even sheen, no hard reflections, base color map only. Seamless, infinitely wrapping edges. Square 1:1 aspect ratio, high resolution, production-ready surface asset.
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
