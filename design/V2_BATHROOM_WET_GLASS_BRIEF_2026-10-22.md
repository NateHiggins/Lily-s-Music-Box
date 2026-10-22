# Bathroom spray, steam and wet glass continuation

Evidence class: **INERT**. Owner brief and implementation notes, not evidence
that the requested effects exist.

The owner requests a visible shower spray cone; local steam while actually hot
water flows; mirror fog; slight edge scuffing on mirrors and windows; and
condensation/rivulets on the appropriate glass side under steam or rain. The
supplied photograph informs droplet/coalescing form only and must not be baked
or committed. No photographic lamp flare may return; retain volumetric light.

Door ease is the subsequent priority: see **V2_EASY_DOORS_2026-10-22.md**.
The toilet and curtain checkpoint is pushed as **e801168b**. The persistent
whole-V2 goal remains active, with hose deployment/aiming/spray and broader
coverage still unfinished. Do not spawn agents without new authorization.

## Existing owners found

- **TapProp.get_flow_state()** supplies effective hot/cold openings, flow and
  mixed temperature, including actual boiler heat. Its comment about hot shower
  fog currently sets operation state only; it creates no local steam.
- **TapProp._build_shower()** presently makes a narrow 17 mm straight stream at
  local (0, 1.82, 0.18), length 1.71 m. Replace its shower presentation, retaining
  valves, water/drain, sound and save authorities.
- **PlanarMirrorRenderer** already lends exactly one reflected SubViewport to
  the selected close mirror. Do not add one camera per wet mirror. Its shared
  shader is **game/shaders/planar_mirror.gdshader**, with existing sinusoidal
  edge/foxing treatment. Inactive mirror fallbacks retain registered stock.
- **orison_v2_window_joinery.gd** walks **root.layout.windows**, retaining each
  record's space and the original **Glazing** node. Those semantic identities
  can bind interior humidity and exterior weather without repeated scans.
- **orison_v2_expressive_glass.gd** retains custom mapped dielectric materials
  and refraction. Preserve their primary UV/PBR/loaded-mip contract.
- Actual live conditions are **world.get_node("WeatherFX")._live_conditions**,
  fed by **world.atmosphere.weather_manager**. The existing weather volume uses
  a bounded FogVolume and shared weather-noise texture. Do not call the weather
  diagnostic snapshot every frame: it also performs cover queries.

## Measurement prepared

**game/tests/V2BathroomOpticsProfile.tscn** runs the real occupied V2 world.
Its new script starts once outside the retained 4B bathroom door, operates it
through ordinary grab/motion/release, walks inside, and then uses actual shower
curtain and valve input. It records dry shower, dry mirror, cold shower,
hot-developing, hot mirror and off/decay phases, using fixed durations and no
image readback during sampling. It records wall/process/physics time, main and
mirror viewport CPU/GPU time, active mirror unit, shader/resource counters,
streaming state, water/heat/weather snapshots and player/input diagnostics.

A batch is queued through the shared lane: easy-door **hand_v4** first, then
**before_v1** under **art/reviews/v2_bathroom_optics_20261022**. The second run
starts only if the first passes. Read stdout, stderr and each wrapper receipt;
a prepared fixture or suite_run does not grant runtime qualification. The
summarizer reports distributions, counts and spikes, with overlapping/stale
counters explicitly described. Baseline has not yet completed at this note.
Freeze production rendering inputs during the run. The new effects are not
installed; measure before adding them and repeat the same settings/route.

## Proposed implementation to verify, not an accepted design

Use a bounded local volumetric emitter and a modest GPU spray cone driven by
actual flow and mixed heat. Humidity should accumulate, spread within the
room, and decay after shutoff. Keep this presentation transient; do not invent
a new work-order, inventory, NPC or save authority.

Bind glass surfaces to room and outdoor exposure once. Steam belongs on the
room side, rain on the exposed outside face, and sheltered faces remain dry.
Exterior droplets must still be visible through the pane from inside; selecting
wetness solely by FRONT_FACING would incorrectly hide exterior rain. Mirrors
need a front film rather than a wet backing. Drying and coalescing rivulets
must remain separate from permanent, restrained edge wear.

Retain registered glass/water roughness and normal maps with loaded mips.
Consider shared film geometry/materials or instancing to avoid one new draw
call per dry pane. A refraction screen read can cost a copy/blur pass; measure
it before accepting. Numerical/procedural optical detail is possible without
AI bitmap generation, but it must not replace the base PBR contract. Local
shader noise should be antialiased and physically scaled. Review rendered
cold/dry/hot/rain cases and side assignments, then compare measured before/after
routes. No global fog overlay or extra reflected worlds are authorized by this
brief. Preserve all failed attempts and call limitations out explicitly.
