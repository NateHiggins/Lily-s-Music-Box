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
   LightRig distance budgeting (full/half/off + faux bounce + one real
   shadow caster), baked contact shadows and wall-base AO, emissive
   envelopes + halos, tuned fog/glow environment. Remaining: lightmap
   bake / GI fallback and a light-leak pass are still open.
6. **Dress the remaining twenty-three units and all commons to 4B's
   density.** OPEN. Every unit is furnished (parametric library, per
   resident) but only 4B carries benchmark close-detail (blinds,
   crockery, desk clutter, bedding detail).
7. **Performance.** OPEN. Floor-visibility streaming (now atrium-aware)
   is still the stand-in; occluders, HLOD, prop LODs not started.
8. **Atmosphere and post.** PARTLY DONE (depth fog, glow, filmic
   tonemap). Volumetrics, glass treatment and a fuller post chain open.

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
