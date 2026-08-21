# MX-0 — the surface census (what the building's materials actually are)

The first slice of the owner's 2026-08-21 direction (`TASKS.md` §MX:
maximum perceived geometric complexity per polygon). Before a layered
surface shader is written, this records what every surface class ships as
today, measured from the booted production building rather than from the
build scripts' intentions.

Instrument: `game/tests/SurfaceCensus.tscn` (`surface_census.gd`) boots
`BuildingRoot` the way the presentation audit does, walks every
`MeshInstance3D` / `MultiMeshInstance3D` surface, resolves the effective
material (surface override → `material_override` → mesh material) and
classifies by origin — **glTF** if the imported scene owns the node, else
**script** (named by the nearest scripted ancestor) — and by buffer name.
`surface_census.md` is the full table; `surface_census.json` the data.
`CENSUS_OUT=<dir>` writes both. 0 script/shader errors.

## The numbers (2026-08-21, all floors shown)

| | surfaces | material type | maps bound | UV law | masks / states |
|---|---:|---|---|---|---|
| glTF architecture (walls ×4 classes, ceiling, slabs, stairs, trim, stone_trim, wainscot, sash, vent_register) | ~175 | StandardMaterial3D, one shared resource per `M_<key>` per storey file (567 imported materials) | albedo, normal (strength 0.42), roughness packed in metallicRoughness.G; **AO 0, detail 0, emission 0**; height on **36 surfaces** (`HeightmapPass`: 31 of 567 materials, 18 shipped height maps, plain offset parallax) | world-box from Blender (terrazzo 4.0 m/unit, oak 2.4 m) | none |
| glTF wall finishes | 81 | 59 Standard (alpha **scissor**) + 22 `wall_encroachment.gdshader` | per-wall compiled albedo + **survival mask in alpha**, relief normal, roughness | per-wall baked UV | the only authored mask in the building; encroachment is a state (WK-1) |
| glTF floors | 26 | all `floor_coverage.gdshader` (MC-P) | albedo, normal, roughness, coverage uniforms | world-box | coverage is a state |
| glTF furnish / furniture / retail / transit / wear | ~850 | Standard | albedo, normal, roughness; 13 with height; wear and 29 retail two-sided | world-box | none |
| glazing | 8 | Standard, two-sided, no albedo | normal / roughness only | — | none |
| script props via `MatLib` (taps 860, stoves 846, doors 564, radiators, fridges, railing polish 292, …) | **4,113** | Standard, `uv1_triplanar`, one cached resource per (key, tint, scale), 35 runtime sets | albedo, roughness, normal (0.35), metallic scalar; **no height, AO, detail** | triplanar at 1 / metres_per_tile | none |
| script props, untextured colour standards (light fixtures 401 of 1,396, reality-affected 324, memory art 290, signage, glows, debug handles) | ~3,900 | Standard, colour only; emission where they glow | — | — | none |
| bespoke shaders | 32 | `scope_screen` ×12, `projected_film` ×6, storm curtains ×6, traffic, weather, commensal | — | — | — |
| **total** | **9,242** | 9,162 Standard, 80 Shader | | | |

Transparency: **803 alpha-blended surfaces** (light glass 248, reality-affected
162, stoves 144, taps 132, memory/story decals 98 + 11, medicine cabinets 39)
against **157 scissor** (the 59 finishes, story decals' stencil, weather).
Glass and glow are honest blends; the reality-affected props, the memory
art and the ground decals are cutouts wearing blend, which is the ordering
the direction says to reverse.

## What the census decides

1. **Where the pixels are is not where the draws are.** Architecture is
   13 % of surfaces and most of the screen; props are 87 % of surfaces and
   the frame is draw-call bound. So per-pixel cost (parallax, detail, masks)
   is spent on the architecture classes and must be governed there; the prop
   path must stay one draw with one cheap material and gets the normal tier
   only.
2. **The swap point already exists.** glTF materials are shared per storey
   file and named `M_<catalog key>`; `HeightmapPass` already re-binds them
   one assignment per material after the floors load. MX-4's rollout is a
   `SurfacePass` in that slot that replaces the `M_<key>` Standard with an
   `orison_surface` ShaderMaterial per key — 567 resources, not 9,242
   surfaces — and `MatLib.get_mat` is the single factory for the other
   4,113. Coverage (26) and encroachment (22) then become **states** of the
   one shader instead of two shaders with their own copies of the base maps.
3. **Height is mostly unused.** The ingest derives a height map for every
   set; 18 ship; 31 materials read them, with offset parallax only. MX-3
   calibrates height in millimetres per set and MX-2 writes the tier rule
   that puts mortar, tile joints, board seams and wainscot mouldings on the
   height tier and plaster and paint on the normal tier (as `HeightmapPass`
   already does by exclusion).
4. **There is one mask.** The finish survival alpha. Everything the
   direction names (damage, grime, moisture, oxidation, wear, corruption,
   gilding, emission, translucency, microdetail) is today either a separate
   shader (coverage, encroachment, the dream's flesh/skin/weld probe) or
   absent. `art/textures/wall_sources` already holds generated stencils and
   overlays (`mask_delamination`, `mask_peel`, `mask_paper_tear`,
   `stain_leak`, `stain_soot`, `stain_tide`, `relief_brick`, `relief_plaster`)
   — the mask library's first members exist and are only used by the
   finish compiler.
5. **AO and detail are absent everywhere.** Packed ORM is an ingest change
   (MX-3); the detail tier is a second-frequency fetch the shader can take
   from the same set (`_b/_c/_d` variants exist per family) until dedicated
   detail maps are ingested.

**Rollout order for MX-4, read from the table:** masonry walls and finish
quads (the flashlight's surfaces, ~255 surfaces, whole-wall pixels) → floors
(fold coverage in, 26) → ceiling, stairs, trim, wainscot, slabs, stone trim
(~130) → glTF furnish / furniture / retail (~850, normal tier, no parallax)
→ `MatLib` props (4,113 from one function, triplanar mode, normal tier) →
untextured colour standards stay `StandardMaterial3D` (nothing to layer).
