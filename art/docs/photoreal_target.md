# Target state: a photoreal Orison Apartments, fully realized and explorable

This is the definition of done for the building. It is a target, not a
plan — the ordering of work is in the roadmap at the bottom, and the
current position is in `HANDOFF.md`.

## The goal in one paragraph

A stranger should be able to spawn on the sidewalk in front of a 1927
Midwestern brick apartment block, believe it is a photograph of a real
building that has stood for a century, walk in the front door, and reach
every space the building has — basement boiler room to roof hatch, all
twenty-four units, both stair halls, the elevator, the light court, the
rear porches — without ever meeting a placeholder surface, an invisible
wall, a door that is neither openable nor diegetically explained, or a
room that is obviously empty because nobody dressed it. The building
should read as *occupied*: someone lives in every apartment, and you can
tell who from what's on their counters. And it should read as *aged*: the
century of wear already in the data model should be visible as staining,
patching, sagging, and mismatched repair, not just as extra geometry.

## What "photoreal" means concretely here

Photorealism in this project is a materials-and-light problem, not a
polycount problem. The geometry is procedurally generated and already
architecturally correct; what's missing is surface and light.

**Materials.** Every surface currently uses a flat-color
`StandardMaterial3D` driven by `material_catalog.json`. The target is a
full PBR material library — base color, normal, roughness, AO, and where
relevant height — with real tiling textures, authored or sourced under a
license that permits committing them. Requirements:

- Consistent texel density. Standard: 512 px/m on hero surfaces the
  player stands within a meter of (4B's counters, door hardware, the
  entrance limestone), 256 px/m on general architecture (walls, floors,
  corridors), 128 px/m on the site and neighbor masses.
- Real UVs from the generator. `build_orison.py` must emit UVs with
  world-space-consistent scale so tiling never visibly stretches or
  changes density across a wall.
- Trim sheets and decals rather than unique textures per object. One
  brick sheet, one plaster sheet, one oak sheet; variation comes from
  masks and decals.
- Material response that matches the era: 1927 face brick is matte and
  slightly chalky; the aluminum-painted radiators are semi-metallic;
  century-old oak floors are worn glossy in traffic lanes and matte at
  the edges; painted plaster has visible brush texture at grazing angles.

**Light.** The target is baked lightmaps for all static geometry plus
real-time GI (SDFGI) as the fallback for dynamic props, with physically
plausible luminance ratios and color temperatures:

- Interior incandescent/CFL retrofits ~2700 K, corridor fixtures dimmer
  and greener than apartment lights, basement fluorescents ~4000 K with
  a slight flicker, exterior sodium streetlamps ~2000 K.
- Real falloff. A corridor lit by three fixtures 6 m apart should have
  visible pools and dark thirds, not uniform fill.
- Light leaks: under apartment doors, through the transoms, from the
  light court into the units facing it, from neighbor windows into the
  alley.
- Windows that carry the exterior into the interior and vice versa —
  emissive interiors visible from the street at night, streetlamp shafts
  landing on interior floors at the correct angle.

**Aging as surface.** `aging_pass()` already places the century of
repair, storm, fire, and use as geometry and material assignments. The
target is that same seeded data driving decals and masks: water staining
below the F01 damp line, soot gradients around the 5D fire, wear lanes
worn *into* the floor material rather than a differently-colored box,
mismatched brick patches that differ in both color and roughness, rust
bleeding below the fire escape and porch hardware, paint failure on the
porch decks, tar patch sheen on the roof.

**Glass and atmosphere.** Real transmission with dirt masks and
per-window variation (some units keep clean glass, some don't); interiors
visible through them. Volumetric fog in the stairwell and corridors at
low density, heavier in the basement; dust motes in the light court.
Post: subtle bloom, mild chromatic aberration, film grain tuned to the
prototype's tone, no heavy DOF during gameplay.

## What "fully realized and explorable" means concretely

- **Continuity.** B1 through ROOF plus the exterior block form one
  continuous walkable volume. No invisible walls. Where the player is
  stopped, it's a locked door, a real barrier, or the edge of the block
  handled diegetically (neighbor buildings, fenced alley).
- **Every door resolves.** Openable, or locked with a reason the world
  states — the former-suite storage rooms, 6D, the management office
  after hours.
- **All twenty-four units dressed.** Apartment 4B is the density
  benchmark (`furnish_4b_detail()`); every other unit should read as
  someone's home at that level, with the resident's character legible
  from the dressing. `dress_unit()` is the hook; the Case Network docs
  name the residents.
- **Commons dressed.** Lobby, mail wall, management office, package
  room, laundry, boiler room, storage cages, both stair halls, elevator
  cab and machine room, roof, porches, alley.
- **Every acoustic graph node has a visible body.** If sound propagates
  through it, the player can see and ideally touch the thing it
  propagates through — radiators, risers, flue breasts, porch decks,
  panels, fixtures. No invisible nodes.
- **Performance that permits exploring.** 60 fps at 1440p on a
  mid-range GPU while walking the whole building. That requires
  occlusion culling and HLOD replacing the coarse per-floor visibility
  currently in `building_root.gd`, LODs on repeated props, and a VRAM
  budget the material library is authored against.

## Roadmap

Ordered so each phase is verifiable before the next depends on it.
Status markers reflect main as of 2026-07-30.

1. **Close the navigability gaps.** DONE. The street-doorway blocker
   (the B1 bearing wall's above-grade curb) is fixed; a generator-side
   movement audit gates every build (door swings, L-route reachability
   into every living area, circulation-space checks), and the test
   suite physically walks the corridor ring, the relocated A/D bedroom
   doors, the atrium climb corridor-to-corridor, the street exit to the
   sidewalk, and the roof monitor door.
2. **UVs and the material system.** DONE. `build_orison.py` emits
   deterministic world-projected UVs (per polygon loop, TEXCOORD_0);
   `art/textures/catalog_mapping.json` is the single mapping authority
   with build-time validation; floors export GLTF_SEPARATE with one
   shared, deterministically named texture directory; Godot props load
   the same maps through `MatLib` (world triplanar at physical scale).
3. **Texture authoring.** LARGELY DONE: 35 of 39 catalog materials are
   texture-backed (generated sets + the curated library: face brick,
   limestone, walnut, upholstery, enamel, brushed steel, porcelain,
   ceramic tile...). glassish/screen/fx_* stay shader-only by design.
   Remaining: replace the weaker synthesized sets with authored ones
   where close-up scrutiny warrants (trim, some fabrics).
4. **Aging as masks and decals.** PARTLY DONE: tile-global wear is
   precomposited per material (compose_overlays.py) and spatial wear is
   placed as decal quads (thresholds, traffic lanes, radiator drips,
   range grease, the 5D burn). Remaining: convert the aging_pass's
   thin-box patches (facade brick patches, damp bases) to mask-driven
   decals for softer edges.
5. **Lighting.** LARGELY DONE: 128 period fixtures across seven types,
   baked contact shadows and wall-base AO, emissive envelopes + halos,
   tuned fog/glow environment. The LightRig now gates by storey and then
   holds a bounded working set of the nearest fixtures, weighting
   circulation above rooms — necessary because GL compatibility caps
   lights per OBJECT and each floor's walls are one merged mesh, so
   lighting a whole storey at once silently starves the corridor.
   Circulation fixtures take their authored range as a throw rather than
   only a cap, and the atrium is exempt from the storey gate since it is
   one seven-storey volume. The light-leak pass is in: every closed door on
   a corridor whose room is awake carries a bar of light on the floor and a
   hairline around the leaf, batched into ONE unshaded mesh for the whole
   building rather than a light per door, which the per-object cap could
   not have afforded. It asks the window pass which rooms are awake, so
   both sides of the same wall tell the same story. Transom spill is
   deliberately not faked — the geometry has no transom openings, and a
   glow on solid plaster is a worse artefact than an absent one. Remaining:
   lightmap bake / GI fallback.
6. **Dress the remaining twenty-three units and all commons to 4B's
   density.** DONE. Three layers land it: the shared close-detail layer
   (blinds, crockery, towels), a deterministic lived-in surface pass on
   every dining/coffee/desk top, and identity dressing — eleven named
   supporting residents carry story clusters (`RESIDENT_STORIES`), and
   the six heroes carry full personality installations (Mina's squared
   caption desk, Juno's amp stack/guitars/record crates, Omar's
   categorized bench with pegboard and parts trays, Rhea's booth with
   playback console, Nadia's contradictory plan wall and massing model
   of this very building, Sacha's tripod/softbox capture kit), all from
   a 20-piece clutter assembly library (`furniture_references.md`).
   Units that read dark (Juno, Rhea) do so by resident light character,
   not neglect — revisit under phase 5's remaining lightmap work.
7. **Performance.** LARGELY DONE, and measured rather than asserted:
   `game/tests/Perf.tscn` parks the camera at six worst-case stations and
   reports objects/draw calls/primitives and frame time (run it windowed;
   headless reports zeroes, which the probe now fails on rather than
   passing). Two changes carried it. Shadows are budgeted separately from
   light and far more tightly — an omni's shadow is a cube, so each caster
   re-renders the visible set six times, and dropping 14 casters to the
   nearest 8 halved draw calls with no visible loss. Then occlusion
   culling: 1091 box occluders are generated at load from the same wall and
   slab data everything else reads, cut around every door and window so a
   sightline through an opening is never wrongly culled. At 1440p on an
   RTX 4080 the worst station went 18.5 ms -> 9.9 ms. Then a census of
   where the geometry actually lives found the column radiator was 62
   MeshInstance3Ds — 23 props carrying 56% of ALL prop meshes — so
   `FunctionalProp.merge_static()` bakes a fixed sub-tree down to one
   mesh per finish (the radiator's knock shakes the whole body, so
   nothing there moves independently). Scene meshes fell 3028 -> 1682
   with primitive counts unchanged, and every station now runs 112-161
   fps. Remaining: that headroom still needs proving on genuinely
   mid-range hardware, and HLOD is untouched. The remaining prop meshes
   are 4-7 each (light fixtures, mostly), where merging would have to
   step around animated bulb materials, billboarded halos and the
   deliberate cast_shadow=off — worth doing only if measurement says so.
8. **Atmosphere and post.** PARTLY DONE (depth fog, glow, filmic
   tonemap, night sky dome). "Emissive interiors visible from the street
   at night" is now in: every exterior window carries an unshaded quad
   just behind the glazing, single-sided and facing out, so it reads from
   the sidewalk and is invisible from the room (you see its culled back
   face and the real night beyond). It is deliberately NOT a light —
   lighting is gated to one storey by the per-object cap, which is why
   the building used to read derelict from outside. What each window
   shows comes from the room behind it, so the building tells the truth:
   2D sealed and 5D burnt stay black, vacant 3C and the 6D crate store
   are unlit, kitchens run cooler than living rooms, and a third of the
   rest are dark because people are asleep. Remaining: volumetrics are
   not available on the Compatibility renderer at all, so the stairwell
   and basement fog needs a different technique; glass still has no dirt
   masks or per-window variation. The SITE is no longer the weak point it
   was: the block runs to ±58 m with a taller ring beyond it, so no
   sightline from the pavement or the roof reaches open sky; streetlamps
   light the pavement; and ~1,570 neighbour windows are lit as data rather
   than as lights. Neon on the street elevation (blade + tenant sign) is a
   conductor body that surges on the motif and drops letters at high
   infection. Weather is in as an after-the-storm state: light gusting
   wind, drizzle, falling leaves, wet road and pavement with gutter
   puddles and storm debris. Volumetrics and SSR are both unavailable on
   Compatibility, so the drizzle is particles and the wet REFLECTS by
   drawing the reflection — an additive smear under each lamp and sign,
   which is the technique that actually sells it. Neighbour windows now
   carry sashes and mullions, batched into a handful of meshes rather than
   one draw call each, so the detail cost less than the flat version did.

## Invariants that survive all of it

- One source of truth. `gen_layout.py` authors coordinates; Blender and
  Godot both consume its JSON. Never hand-edit geometry or the JSONs.
- Determinism. Same inputs, same building, byte-identical rebuilds.
  Seeded randomness only (`random.Random(1927)`).
- Self-validating generation. The overlap, footprint, door-width, and
  door-swing audits are permanent failing checks; add new audits as new
  classes of defect are found, never relax an existing one.
- Physics-verified navigability. Claims about reachability are proven by
  a capsule walking the route in `WalkTest`, not by looking at it.
- The test suite only grows.
