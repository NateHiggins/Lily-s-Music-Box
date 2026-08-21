# MX-1 — the layered surface, photographed on the flashlight's surfaces

Owner direction 2026-08-21 (`TASKS.md` §MX): treat materials as layered
surface systems, maximum perceived geometric complexity per polygon, masks
as first-class controls, scissor for cutouts, tiers by what a shader can
sell. Built 2026-08-21 after the census (MX-0); in production on the
masonry walls and the compiled wall finishes the same day (MX-4 step 1).

## What was built

**`game/shaders/orison_surface.gdshaderinc`** — one include, the whole stack:

| layer | what it does | cost switch |
|---|---|---|
| base | albedo · OpenGL normal · roughness from R (ingest), G (glTF metallicRoughness) or packed ORM (AO R / rough G / metal B) · metallic | always |
| projection | mesh UV (the builder's world-box metres) or world triplanar (the `MatLib` props), with M-COVER's hex / cell-snapped / row modes ported verbatim so `FloorCoveragePass`'s rules carry over | `uv_mode`, `coverage` |
| height | the set's height map, **calibrated in millimetres over the set's tile in metres**, as offset parallax or POM; the governor is built in — fades at grazing angles and with distance, and `parallax_budget` lets a station's measured cost turn it down; never in triplanar mode | `has_height`, `parallax_mode` |
| detail | a second-frequency albedo/normal pair — dedicated maps, or the set's own maps re-read at 3.718× (self-detail) until MX-3 ships them | `has_detail` |
| masks | eight first-class fields, each an `amount × smoothstep(threshold, softness)` of a texture channel in world metres **or** a procedural fbm of world position (no asset needed): damage, grime, moisture, wear / oxidation, gilding, corruption, emission. Each blends a secondary state: damage shows the substrate (and **tears** a cutout), grime settles where the height is low, moisture darkens and polishes, wear rubs the crests bright, oxidation kills metal, gilding leafs the crests, corruption grows the dream's flesh (`dream_corruption_layers`), emission glows through its mask | a field is only evaluated when its amount is > 0 |
| optional | wrap-translucency (BACKLIGHT), clearcoat, anisotropy; `debug_view` shows the fields, the height, cavity/crest/parallax-fade | uniforms |

Two thin shaders compile it: **`orison_surface.gdshader`** (opaque — no
alpha path at all) and **`orison_surface_cutout.gdshader`** (alpha scissor or
hash for genuine cutouts: the finish survival mask, holes, mesh; corruption
can restore a torn surface as a membrane, damage can tear it further). 85 /
91 uniforms; `ShaderParseCheck.tscn` proves both compile headless.

**`game/scripts/building/surface_pass.gd`** — production. After the floor
scenes load (right after `HeightmapPass`), every surface of a listed class
trades its shipping StandardMaterial3D for the layered surface carrying the
same maps and scalars plus the class recipe. One ShaderMaterial per
(shipping material, recipe), cached — the glTF shares one material per
`M_<key>` per storey, so this is materials, not surfaces, and no draw is
added. `SURFACE=0` is the A of every A/B; `SURFACE_BUDGET` scales the
parallax governor. Recipes today: **walls** POM (6–14 steps) + self-detail;
**finishes** self-detail (they carry no height map).

**`game/tests/SurfaceShot.tscn`** — the proof. Eight stands under the carried
torch, every option built through `SurfacePass.surface_for` (so what it
photographs is what ships), GPU time as the lower of two 48-frame medians,
`surface.json` beside the frames.

## What the frames found, in order

1. **The pipeline is neutral.** `base` (every layer off) is the shipping
   look — `sheet_bed_2a_tiers.jpg`, `sheet_cellar_tiers.jpg`: colour, normal
   strength and roughness carry over exactly. Art direction preserved by
   construction, as the direction asked.
2. **The height tier did not read, and the reason was the data, not the
   shader.** The ingest's heights are band-passed luminance that never span
   0..1: face brick sits between 0.39 and 0.65 (5th–95th percentile),
   concrete between 0.45 and 0.54. "10 mm of relief" was really 2.6 mm. The
   pass now **measures each map's working range** (128×128 resample,
   p5..p95) and the shader maps the millimetres onto that range
   (`height_range`). Then: **only one storey in three had a height map at
   all** — the family variants (`face_brick_b`, `_c`, …) the builder cycles
   per storey never had theirs shipped; 18 base maps, 42 variants copied
   and imported now, and the pass resolves a variant's relief and tile from
   its base key. `sheet_brick_height_tier_zoom.jpg`: `current` → `pom` the
   courses recess behind the torn plaster edge at the calibrated 10 mm;
   `pom_x25` is the 2.5× exaggeration, there for the owner to judge against.
3. **The procedural fields cost where they are evaluated.** The first "base"
   paid 1–2 ms for eight fbm fields nobody asked for; a field is now
   evaluated only when its amount is > 0 and an unused state costs a
   uniform branch.
4. **Damage on a finish is a tear, not a stain.** The first damage demo
   painted a brown blob on plaster; the cutout shader now cuts alpha under
   the damage field (ragged edge from a finer octave) so the masonry shows
   through — `sheet_states_cellar_close.jpg`, top right.

## States, each alone at 0.9 (`sheet_states_*.jpg`)

Grime and wear are quiet under the torch hotspot (they are meant to be:
they modulate the authored albedo, never replace it); moisture, damage,
corruption and emission read at once; oxidation and gilding are shown on
plaster here only to prove the field — they are metal and ornament states
and will be photographed there (MX-4). Corruption is recognisably the
dream's flesh from EN-1 — cells, vessel lines, a wet film — growing over
the ordinary states, which is the "supernatural on top" the direction asked
for.

## Cost (GPU ms, medians, 1280×720, Compatibility; `surface.json`)

| stand | shipping | base | POM | detail | masks (procedural) | full | corrupted |
|---|---:|---:|---:|---:|---:|---:|---:|
| bed_2a | 3.59 | 3.92 | 4.07 | 3.37 | 4.24 | 3.79 | 5.14 |
| cellar | 1.19 | 2.11 | 1.99 | 1.98 | 2.29 | 2.19 | 2.31 |
| corridor | 12.87 | 12.74 | 12.70 | 12.67 | 12.76 | 13.55 | 12.40 |
| lobby | 10.56 | 11.00 | 10.81 | 10.88 | 10.88 | 10.97 | 11.19 |
| brick_close | 0.81 | 1.37 | 1.38 | 1.40 | 1.62 | 1.62 | 1.74 |
| cellar_close | 2.25 | 2.53 | 2.53 | 2.54 | 4.02 | 4.04 | 5.08 |

Read: the layered base costs 0.3–0.9 ms over StandardMaterial3D where a
wall fills the frame and nothing where the frame is draw-bound (corridor,
lobby: 14–16 k draws); POM at calibrated relief and self-detail are free
over base; **procedural** mask fields cost 0.3–1.5 ms on a close wall — they
are an authoring convenience, and production masks should be textures
(MX-3's mask library); corruption adds 0.2–1.0 ms where it covers the
frame. Stand-to-stand noise is ±0.3 ms.

Gates with the pass in production: WalkTest FAST PASS, LightingAudit PASS,
0 script/shader errors (see the commit).

## What this does not do yet

- The tier rule is in the shader (normal → height → geometry, the governor),
  not yet written per class in millimetres; MX-2.
- Height maps are calibrated at runtime by measurement; the ingest should
  write them spanning their range with the relief in `material.json`, and
  ship ORM and detail maps; MX-3. The 42 variant height maps are unmipped
  like the 18 before them (§MP).
- Floors stay on `floor_coverage.gdshader`, the 22 case-flat finishes on
  `wall_encroachment.gdshader`; both become recipes of this surface when
  their classes roll (MX-4), as do trims, glTF furnishing and the `MatLib`
  props (triplanar mode is built and untested in frames).

## Addendum 2026-08-21 — the ruling, the floors, the trims (MX-4 steps 2–3)

Owner on the frames above: **"exaggeration is cool"** — relief ships at
2.5× the calibrated millimetres (`SurfacePass.RELIEF_EXAGGERATION`), the
`pom_x25` frame is now the `ship` look (`floors/sheet_brick_ship_zoom.jpg`).

**Floors** became a class of the same surface: M-COVER's rule per set
(cell-snapped terrazzo, row-offset oak, hex ceramic and concrete) lives in
`SurfacePass.COVERAGE_RULES` and is applied as part of the floor's base look,
plus the height tier (terrazzo 0.6 mm, oak seams 1.5 mm, × 2.5) and
self-detail. `FloorCoveragePass` is superseded and no longer applied.
`floors/sheet_oak_floor.jpg`, `floors/sheet_corridor_floor.jpg`: `current`
here is the bare StandardMaterial3D (the tile-period joint line is back in
it), `base` / `ship` carry the staggered rows; costs oak 2.50 → 3.03 ms,
corridor floor 6.24 → 6.30 ms.

**Trims**: wainscot (beadboard, POM), tin ceiling, stairs, slabs, limestone
stone trim (offset parallax), painted trim and sash (self-detail, no height
map). Ten classes, **307 surfaces on 260 materials**; corridor 12.74 →
13.00 ms, lobby 11.95 → 11.40 ms (noise). `floors/sheet_lobby_ship.jpg`,
`floors/sheet_corridor_ship.jpg`. WalkTest FAST PASS, LightingAudit PASS,
0 script/shader errors.

Left for the rollout: glTF furnishing (normal tier), the `MatLib` props
(`get_mat` returns a typed StandardMaterial3D that 52 callers may duplicate
and tint — a `get_surface` beside it, not a swap), the 22 encroached
finishes as a corruption recipe, and the metal states photographed on
metal.
