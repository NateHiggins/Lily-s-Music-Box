# ORISON DRIVING RAIN AND FOUR-STATE SKY

*Owner direction, 2026-08-14. Implemented as T8 on 2026-08-14; §17 is the
as-built proof record. Earlier sections preserve the approved design and its
acceptance contract.*

## 1. The picture

The exterior is one storm seen at four hours.

Rain drives diagonally across an overcast block. The near pavement and the gap
the player is about to cross remain readable; the roadway beyond them loses
contrast into wet grey. A lamp appears first, then enough of a vehicle to judge
its speed, then the body passes and disappears again into the weather. The two
ends of the street no longer look like curtains pasted over a stage edge. They
look like the densest parts of the same weather already occupying the block.

Morning, day, evening and night are not four weather presets. They are four
light sources trying and mostly failing to get through one continuous cloud
deck:

- morning: cold silver rain with a low apricot stain behind eastern cloud;
- day: flat slate daylight, bright enough to read wet brick and never blue;
- evening: bruised mauve cloud with a dirty amber western seam;
- night: blue-black rain carrying sodium city glow, with the moon only a pale
  pressure behind cloud.

Occasionally the cloud thins enough for two or three broad fingers of light.
They are not triumphant beams and they do not clear the rain. They are vague,
depth-tested shafts whose source agrees with the glow in the sky and the
directional light on the world.

The design test is simple:

> **The player can read the next eight metres. The city cannot promise the next
> thirty.**

## 2. What exists now

This is an evolution of the existing owners, not a request for a second weather
stack.

| Existing owner | As built |
|---|---|
| `DayNightDirector` | Four clock grades (`dawn`, `day`, `twilight`, `night`) interpolating ambient color/energy, background, fog color/density, one directional light, sky tint/exposure and `MoonFill` |
| `NightSkyHalfDome` | One 4096 × 2048 upper-hemisphere night panorama on a camera-stable sphere; one unlit Compatibility shader and one draw |
| `WeatherFX` | 430 camera-following drizzle particles, 90 pavement flecks, 44 leaves, two additive lightning cards and hand-drawn wet reflections |
| `Environment` | Exponential fog at density 0.014 plus filmic tonemapping and Compatibility glow |
| `ExteriorDetailPass` | Three localized storm-curtain quads at each approved carriageway end; wet works and collision at exact x −20.10 / +20.60 |
| `StreetTraffic` | At most fourteen vehicles in four shadowless MultiMeshes; visible head/tail lamps and five spatial voices; spawn/retire at ±52 m |
| `MoonFill` | One camera-following cool interior fill in windowed rooms |
| Atrium atmosphere | One fake additive shaft and dust system because real volumetrics are unavailable |

The project is on Godot 4.7's Compatibility renderer. Compatibility supports
depth and height fog, but not volumetric fog; this proposal deliberately uses
the supported depth fog plus cheap local geometry rather than changing
renderer. See the official
[renderer feature table](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html)
and [`Environment` fog controls](https://docs.godotengine.org/en/stable/classes/class_environment.html).

### Existing defects this pass must not preserve

1. The four clock states tint the same night image. Day can brighten it, but it
   cannot become a real overcast day.
2. The current precipitation reads as the tail of a storm: sparse drizzle and
   leaves. The owner has now ruled driving rain.
3. Exponential fog gently grades everything but does not own a deliberate
   middle-distance visibility envelope.
4. The road-end weather and camera-following weather look like separate
   effects.
5. `DayNightDirector` and `LightRig.apply_tuning()` can both write absolute
   ambient, fog and directional-light values. A debug adjustment can therefore
   be overwritten eight seconds later. The redesign needs one resolved writer.
6. The directional node is named `ExteriorMoon` even while it performs as a
   daytime sun. The stable node name may remain for compatibility, but the
   design concept is an **overcast sky key**, not always the moon.

## 3. Binding visual laws

1. **Overcast is permanent.** No clean blue sky, visible stars, crisp sun disc,
   crisp moon disc or weather-clearing transition belongs in this pass.
2. **Driving rain is the canonical exterior state.** Time changes its color and
   legibility, not whether it exists.
3. **Near-field safety outranks atmospheric density.** The player must still
   judge the near lane and hear a gap. Fog begins after the useful crossing
   information, not between the player and the kerb.
4. **Bodies disappear before lamps and sound.** Weather removes detail first,
   silhouette second, light third and sound last.
5. **The celestial source is an occluded glow, not a sky object.** It may be
   locatable, never cleanly outlined.
6. **God rays are weather, not revelation.** Rare, broad, quiet and never a
   camera event.
7. **No new unexplained collision.** The existing visible works and storm-owned
   road boundaries stay at their approved coordinates.
8. **No new realtime light budget.** Reuse the one directional exterior key;
   rain, fog sheets, celestial glow and fingers of light are shader response,
   not more lights.
9. **The four sky images share one geography.** The Queens skyline, bridge
   sector, horizon height, camera projection, wrap and zenith must not jump
   between hours.
10. **The storm is allowed to be beautiful.** Physical plausibility is a tool,
    not a brake on the composition.

## 4. Ownership after the change

No new manager is justified.

| Owner | Sole responsibility after this pass |
|---|---|
| `DayNightDirector` | Authoritative time; state interpolation; resolved Environment values; adjacent sky textures/blend; celestial direction/color/strength; one weather presentation profile sent to existing owners |
| sky-dome shader | Blend two adjacent panoramas; render the cloud-hidden celestial glow; merge its horizon into the resolved fog color |
| `WeatherFX` | Rain particles, middle rain sheets, ground spatter, roadway mist, wind/gusts, lightning and weather audio mix; exterior presence only |
| `ExteriorDetailPass` | Fixed road-end architecture, storm-mouth meshes, puddles and wet surfaces; it accepts palette/flash input but owns no clock |
| `StreetTraffic` | Vehicle cadence, crossing promise, motion, lamps, collision and audio voices; it does not know about fog |
| `LightRig` | Fixture working set and owner-facing tuning offsets; it stops being a second absolute writer of environment time state |
| `MoonFill` | Windowed-room fill using a scale supplied by `DayNightDirector`; no independent time logic |

The smallest clean implementation is a profile dictionary owned by
`DayNightDirector`. If the table becomes too large for code, move the data to
`game/data/environment_states.json`; do not add an `EnvironmentManager` beside
the director that already owns the job.

### Resolve the two-writer problem first

`DayNightDirector` produces the base grade. `LightRig` debug controls become
offsets or multipliers applied by the director:

- `ambient_gain` multiplies the state ambient energy;
- `fog_gain` multiplies the state fog maximum;
- `sky_key_gain` multiplies the state directional energy;
- fixture gain, fixture shadows and fixture budgets remain wholly `LightRig`.

No subsystem writes `Environment.fog_*`, `ambient_light_*` or the exterior
directional light after the director's resolved apply.

## 5. Four sky variants

### Asset contract

Create four matched upper-hemisphere panoramas from the existing approved
Queens night geography:

```text
orison_queens_morning_rain_half_dome_4k.png
orison_queens_day_rain_half_dome_4k.png
orison_queens_evening_rain_half_dome_4k.png
orison_queens_night_rain_half_dome_4k.png
```

For every file:

- 4096 × 2048, 360° cylindrical upper hemisphere;
- top edge zenith, bottom edge horizon;
- skyline confined to the bottom 16–20 percent;
- the exact same Queens roofscape and southwest bridge/Manhattan sector;
- 192-pixel horizontal wrap feather;
- 72-pixel zenith convergence treatment;
- 90–100% cloud coverage;
- no near building pretending to stand across the street;
- no readable modern signage, vehicles, people or aircraft;
- no crisp celestial disc;
- alpha stores broad cloud optical thickness for the runtime glow mask;
- a 1024-pixel preview and the untouched generation/edit source are retained.

Generate or paint the four states as edits of the same source, never as four
independent prompts. A sky whose skyline changes between 15:59 and 16:01 is a
larger error than a visible color crossfade.

### Starting palette and source placement

These are render-start values, not acceptance by spreadsheet.

| State | Canonical force time | Cloud/horizon | Hidden source | Direction | World response |
|---|---|---|---|---|---|
| **morning** | 07:00 | cold grey zenith; weak peach-grey east seam | filtered sun | east-southeast, elevation 9–16° | long vague cool shadows, warm wet highlights, silver rain |
| **day** | 12:30 | high chalk/slate overcast; brightest zenith | broad white sun stain | south, elevation 48–58° | lowest shadow contrast, readable brick, road still greyed by rain |
| **evening** | 17:30 | mauve/charcoal deck; dirty amber west seam | filtered sun | west-southwest, elevation 7–13° | warm rim on wet edges, interiors begin to win |
| **night** | 03:00 | blue-black cloud with low sodium city bounce | clouded moon pressure | south-southwest, elevation 30–40° | existing cool floor and warm/cold fixture contrast preserved |

Keep `dawn` as an alias of `morning` and `twilight` as an alias of `evening` so
existing tools and tests do not break merely because the owner chose better
names.

### One dome, two resident textures

The dome shader receives:

```text
panorama_a
panorama_b
sky_blend
fog_horizon_color
celestial_direction
celestial_color
celestial_strength
celestial_core_radius
celestial_halo_radius
```

Only the two adjacent state textures remain resident. The shader samples and
blends those two on the existing dome, preserving one sky draw. Finished states
may release the old texture after the transition. A 45–90 second blend is slow
enough that ordinary clock updates never read as a lighting cut.

The bottom 10–14 percent of the panorama blends into the same resolved fog
color used by the Environment. This joins sky and weather without asking the
global fog to affect the dome, whose current material intentionally disables
fog.

## 6. The hidden sun and moon

The source is rendered inside the dome shader from the dot product between view
direction and the director-supplied celestial direction.

It has three components:

1. a very soft core smaller than the width of a thumb at arm's length;
2. a broad halo six to fourteen times that radius;
3. two or three even broader radial streaks visible only when the cloud mask
   thins.

The panorama alpha/cloud mask attenuates all three. The core may vanish
completely while the halo remains, which is the desired “something bright is
behind there” reading.

The same direction drives the existing `ExteriorMoon` directional node. The
node may retain its name to avoid incidental breakage, but a comment and public
API should call it the `sky_key`. Direction, color and energy must agree with
the dome; a western glow casting eastern light is a failed state.

### Directional-light policy

- one light only;
- no vehicle shadows;
- energy remains subordinate to ambient overcast light;
- day has the weakest shadow opacity even when it has the highest energy;
- morning/evening may carry longer readable form shadows;
- night retains the accepted cool directional shadow language;
- no lightning DirectionalLight: the existing sky/ground flash cards remain
  the correct solution.

## 7. Fog: a visibility envelope, not milk in the camera

Use two scales of fog for two different jobs.

### 7.1 Global depth fog

Switch the Environment to depth-fog mode and tune an explicit envelope rather
than relying only on exponential density.

Prototype starting range:

```text
fog_depth_begin: 12–16 m
fog_depth_end:   48–58 m
fog_depth_curve: 1.2–1.6
fog_density:     0.78–0.90 maximum at depth end
```

The exact values vary slightly by time state because daylight increases fog
luminance, not because the storm lifts. Do not use strong global height fog:
world-height fog would also thicken the basement and lower storeys. The
existing gentle interior aerial perspective should survive.

### 7.2 Roadway mist

Build one batched local mist owner spanning the carriageway and its two mouths:

- three long, depth-tested, double-sided ribbons;
- bottom at road level, soft fade by 1.4–1.8 m high;
- low-frequency noise moving mostly with the wind and slightly against it;
- denser in gutters and at ±20 m road mouths;
- color supplied by `DayNightDirector`;
- no collision, shadows or light;
- one MultiMesh submission if transparent ordering proves stable; otherwise
  two submissions, near and far.

The ribbon's job is to erase wheels, lower bodies and distant road texture
before global fog removes the whole silhouette. It also makes the existing end
curtains look like the densest continuation of one weather system.

### Traffic visibility sequence

| Distance/read | Required result |
|---|---|
| 0–10 m | body type, direction, speed and lane readable; crossing remains fair |
| 10–20 m | body becomes a wet silhouette; cab/wheels subordinate; lamps clean |
| 20–32 m | body contrast collapses into fog; lamp and spatial voice remain |
| beyond ~32 m | no useful body detail; intermittent lamp pressure and sound only |
| road mouth | vehicle fully disappears behind the existing storm owner before any spawn/despawn becomes visible |

Do not add per-instance transparency to the traffic MultiMeshes unless the fog
and mist fail the test. Opaque bodies naturally fogged by depth preserve cheap,
stable batching and avoid transparent-sort artifacts.

## 8. Driving rain in three layers

The current 430 drops over a 52 × 52 m box are too sparse because they attempt
to own every distance at once. Density comes from layering.

### Near layer — particles

- camera-following `CPUParticles3D`, exterior only;
- 12–16 m useful radius rather than the current 26 m half-width;
- initial prototype 650–850 thin streaks;
- fall velocity 16–23 m/s;
- streak length 0.75–1.25 m, width 0.012–0.022 m;
- 14–26° wind lean with gust excursions;
- lifetime under one second, preprocessed so arrival is already wet;
- cool diffuse color by day, higher lamp response by night;
- no giant foreground drops crossing the whole screen.

### Middle layer — shader sheets

- two crossed or gently curved rain-sheet meshes outside the near emitter;
- narrow procedural streaks scrolling at different speeds;
- depth tested, soft-edged, with no opaque override path;
- one or two submissions total;
- strongest when seen against sky, road-end weather and dark façades;
- fades before reaching the camera so it never exposes a sheet edge.

### Ground layer — impact and runoff

- increase spatter only after measuring; starting range 140–200 flecks;
- retain wet glare and authored puddles;
- add no simulated drop collision;
- gutter sheen/ripple belongs in existing puddle shaders, not hundreds of new
  nodes;
- reduce airborne leaves from 44 to a sparse storm-debris accent if the rain
  already carries the frame. Driving rain plus a decorative leaf storm is two
  weather stories.

### Exterior detection

Replace the current single height-and-envelope heuristic. It currently requires
`player.y < 1.9`, so it classifies the authored roof at elevation 19.2 m as
indoors and guarantees a dry roof. That was adequate for ground-level drizzle
suppression and is wrong for a building in driving rain.

`WeatherFX` should receive one exposure query from the existing building root,
not infer architecture from height. The query derives from layout/zone facts:

- `STREET` and the exterior pavements/roadway are exposed;
- `ROOF` walkable exterior is exposed;
- the Orison rooms, lobby, vestibule, basement and Passage are sheltered;
- the atrium under intact glazing is sheltered even though the sky is visible;
- a later opened/broken window may affect audio and local wetness, but does not
  turn an apartment into a rain emitter volume.

The required test matrix is:

- north and south pavement;
- roadway;
- roof;
- lobby and vestibule;
- Passage throat and arcade interior;
- 2A and 4B near open/closed windows;
- atrium under glazing;
- basement.

The sky may be visible from indoors. Rain particles may not fall through six
storeys or inside the Vantry Arcade.

## 9. Fingers of light

True volumetric shafts are unavailable on Compatibility. Fake them the same
honest way the atrium already does.

### Far-field fingers

Paint or render broad radial cloud streaks in the dome shader around the
celestial halo. They belong to the sky and cost no geometry.

### Near-field fingers

At most two depth-tested tapered prism/quad shafts may reach into the exterior
block:

- one batched owner;
- unshaded additive material with color near black and a very low addition,
  following the proven atrium-shaft lesson;
- source end points toward the celestial direction;
- fade before the player intersects the mesh;
- no shadow, light or collision;
- morning and evening only by default;
- 12–35 second swell, never a flash;
- combined opacity sufficiently low that brick and navigation remain intact.

The atrium shaft should accept the same time-state tint and strength so the
skylight, sky and street appear to receive one storm. Do not add another atrium
volume.

If the near-field geometry reads as a cone, stage light or supernatural event,
delete it. The sky streak plus wet-surface response may be enough.

## 10. Lightning and rain sound

### Lightning

Keep the existing paired distant impulses and shadowless sky/ground cards.
Extend their output narrowly:

- feed `ExteriorDetailPass.set_weather_flash(level)` so puddles and road-end
  storm share the flash;
- tint the dome very briefly rather than adding a world light;
- never flash interior walls uniformly;
- retain seeded timing for deterministic renders.

### Sound

The rain needs the same distance structure as the image:

- exterior broadband rain bed following the player at low volume;
- local rain-on-metal at awnings, fire escape and bus shelter when it returns;
- gutter/downpipe detail near façades;
- traffic voices remain audible after bodies disappear;
- interior rain becomes filtered window/roof transmission, not the exterior
  bed at reduced volume;
- speech, immediate interaction and threat retain priority over weather.

Reuse the existing `ambient_roof_storm_city.ogg`, `rain_on_metal.ogg` and
`distant_rain_people_train.ogg` only where their licenses/attribution and sound
fit. This proposal does not declare placeholders final.

## 11. Determinism and controls

Retain `DAYNIGHT_FORCE`, with these accepted values:

```text
morning | dawn | HH:MM
day
evening | twilight
night
```

Add only the diagnostic controls needed to prove the system:

```text
WEATHER_SEED=<integer>       # particles, gust phase, lightning timing
WEATHER_RAIN=0|1             # diagnostic isolation, not a player setting
WEATHER_MIST=0|1             # diagnostic isolation
WEATHER_RAYS=0|1             # diagnostic isolation
```

`DAYNIGHT=0` continues to produce canonical 03:00 night so the existing suite
does not become a time-of-day lottery. Performance probes remain pinned to
canonical night unless a test names another state.

## 12. Implementation order

### W1 — baseline and single ownership

1. Capture the current street, road mouth, roof, atrium and lobby at forced
   morning/day/evening/night.
2. Record street CPU/GPU frame, objects, draws and lights with rain visible.
3. Make `DayNightDirector` the resolved Environment writer; turn `LightRig`
   environment tuning into offsets.
4. Add a focused state test proving each writer and alias.

No intended visual change in W1.

### W2 — matched sky family

1. Produce the four geography-locked panoramas and previews.
2. Extend the existing one-dome shader to two-texture blending.
3. Add cloud-mask celestial glow synchronized to the exterior key.
4. Prove wrap, zenith, horizon, roof and street continuity.

### W3 — visibility envelope

1. Prototype depth-fog begin/end/curve values.
2. Add one batched roadway-mist owner and merge it into the existing mouths.
3. Record traffic approach/departure clips from both pavements.
4. Tune until bodies vanish in the middle distance while the near lane and
   lamp/audio cues remain fair.

### W4 — driving rain

1. Replace wide sparse drizzle with near particles plus middle rain sheets.
2. Tune spatter and reduce conflicting leaves.
3. Prove exterior/indoor suppression across the matrix in §8.
4. Measure before adding any more density.

### W5 — fingers, lightning integration and audio

1. Add sky-only radial streaks.
2. Trial no more than two near-field fake shafts; keep them only if they read as
   cloud light rather than geometry.
3. Route the existing lightning level to puddles/end weather/sky tint.
4. Establish exterior, surface and filtered-interior rain mix states.

### W6 — proof and acceptance

1. Produce the render matrix and transition clips.
2. Run focused weather, containment, route, lighting and traffic tests.
3. Run WalkTest FAST and FULL one Godot at a time under the established
   60-second bound.
4. Record canonical-night performance and separate forced-day numbers; never
   compare unlike hours.

## 13. Proof matrix

### Static renders

Five stations × four states:

1. north pavement looking across the roadway;
2. south pavement looking back to the Orison;
3. east/west road mouth with one approaching vehicle;
4. roof looking toward the directional skyline sector;
5. atrium eye looking toward the skylight.

Twenty labeled frames, fixed camera and `WEATHER_SEED`.

### Motion proof

- one vehicle approaches from invisible → lamp/sound → silhouette → readable
  near field;
- the same vehicle departs in reverse without a visible pop;
- one 90-second morning→day or evening→night sky blend with no geography jump;
- one exterior→lobby→Passage walk proving rain suppression and sensible audio
  filtering;
- one morning/evening fingers-of-light clip proving the effect is weather, not
  an event.

### Automated checks

Add focused tests for:

- four state resources and two legacy aliases;
- one authoritative Environment writer;
- one directional exterior key and no new weather lights;
- sky texture dimensions/wrap contract;
- rain absent from classified interiors and present on roof/street;
- both fixed street-end weather owners still visible and collidable;
- `MAX_WAIT <= 8` and `GAP_SECONDS >= 3` unchanged;
- deterministic seed and lightning sequence;
- no source texture or generated preview loaded into production by mistake.

## 14. Acceptance gates

The proposal is implemented only when all are true:

### Image

- all four hours are identifiable without a UI label;
- every hour remains overcast and rainy;
- the celestial source is locatable but never cleanly outlined;
- no panorama seam, zenith pinwheel, horizon stretch or skyline jump;
- the street-end curtains read as the densest continuation of block weather;
- traffic bodies disappear into middle distance before any lifecycle pop;
- near-lane direction and speed remain readable;
- god rays survive only if they do not read as supernatural stage lighting.

### Performance

- one sky draw remains one sky draw;
- no new realtime or shadow-casting weather lights;
- local fog/rain/ray geometry adds no more than four steady exterior
  submissions over the current weather owner;
- canonical-night street frame cost increases by no more than 0.8 ms against a
  same-build, same-seed negative control, unless separately measured work buys
  that cost back;
- interior performance stays within its recorded noise floor when rain is
  suppressed;
- mobile/Compatibility appearance is the authority, not a Forward+ preview.

### Play

- crossing remains continuous, fair and UI-free;
- a gap is audible with the camera turned away;
- the player never encounters invisible boundary collision;
- rain never occupies an interior volume;
- speech and interaction remain intelligible;
- time transitions never interrupt control or call/conversation protection.

## 15. Explicit non-goals

- no renderer migration;
- no volumetric fog or volumetric-light plugin;
- no accurate astronomy, latitude/calendar simulation or dynamic moon phase;
- no clear-weather state;
- no screen-space raindrop lens overlay;
- no wetness simulation on every material;
- no traffic redesign, new vehicle kinds or changed crossing cadence;
- no reopening the approved stage boundary or final map geometry;
- no extra sun/moon/lightning light nodes;
- no four independently generated skylines;
- no claim that proposed color/fog numbers are final before renders exist.

## 16. Recommendation

Build the visibility envelope before increasing particle count. The important
new image is not “more drops”; it is the road losing certainty while the near
crossing stays legible. Once depth fog, roadway mist, end weather and traffic
agree, a moderate near rain layer will read as a downpour because the entire
world behind it already behaves like rain.

The four-state sky should be the second move, using one geography-locked source
family and one hidden celestial glow synchronized with the existing exterior
key. Add the fingers of light last. They are the garnish most likely to turn an
excellent overcast block into a game effect.

## 17. T8 as-built record — 2026-08-14

T8 is complete. The shipped exterior is one continuous overcast storm with
morning, day, evening and night lighting states. It changes the weather and
lighting substrate only; the approved three-zone map, two visible street ends,
traffic cadence and crossing promise are unchanged.

### Sky family and provenance

The production family is:

- `orison_queens_morning_rain_half_dome_4k.png`;
- `orison_queens_day_rain_half_dome_4k.png`;
- `orison_queens_evening_rain_half_dome_4k.png`;
- `orison_queens_night_rain_half_dome_4k.png`.

Each is 4096 × 2048 RGBA. The generated storm-cloud source is retained as
`orison_queens_storm_overcast_master_source.png`; the deterministic
`art/tools/build_storm_skies.py` builder restores the accepted Queens lower
skyline pixel-for-pixel, repairs the cloud/skyline seam, makes all four grades,
and writes the 1024-pixel review previews. Neither source nor preview is loaded
by production. Only the two adjacent production panoramas are resident during
a transition.

`DayNightDirector` is now the sole absolute writer of Environment and the
existing `ExteriorMoon` directional node, which remains named for compatibility
but functions as the overcast sky key. `LightRig` supplies gains rather than
competing absolute values. The dome blends the matched panorama pair, fog
horizon, hidden celestial glow, restrained cloud-light fingers, and the lower
cloud stratum in its existing single draw. No new realtime light exists.

### Dynamic lower cloud amendment

The owner added a moving low cloud layer during execution. It is not a second
dome, particle emitter or transparent card. Two seam-periodic procedural fields
drift at different, deliberately slow rates inside the existing sky shader,
modulated by the source texture's optical-thickness alpha and faded out before
the fixed skyline. This supplies parallax-like depth without a seam, skyline
swim or extra submission. A fixed-camera day proof separated by 20 seconds
changes 5.30 percent of sky pixels by more than one level, with maximum channel
delta 3: movement is measurable but does not look like a texture sliding past.

### Visibility envelope and exposure

The Environment uses bounded depth fog rather than near-camera milk: state
profiles keep the clear foreground at 13–15 m and finish the dissolve at
50–56 m, with density 0.80–0.86. One batched roadway ribbon and its two storm
mouth planes lower contrast around wheels and join the road to the already
approved end architecture. `ExteriorDetailPass` accepts the same interpolated
mist palette and lightning flash, so the old boundary curtains no longer read
as a separate effect.

`BuildingRoot.weather_exposure_at()` is the sole shelter classification.
STREET, both pavements, the carriageway and open roof are wet; the Orison rooms,
lobby, atrium beneath intact glazing, apartments, basement and Vantry Arcade
are dry. Weather follows the production player and cannot infer exposure from
height alone.

### Rain: rejected versions and final visual

Three implementation attempts were rejected by measurement before the final
one:

1. 760 near, 170 spatter and 12 debris CPU particles read as a cartoon curtain
   and added 2.66 ms at the real north-pavement player position.
2. Reduced CPU counts remained submission-bound and added 2.18 ms.
3. `GPUParticles3D` still expanded into hundreds of Compatibility submissions;
   changing particle ownership did not change the renderer's economics.

The accepted airborne rain is two curved instances in one `MultiMesh` draw.
The shader produces three overlapping exposure scales: fine and middle rain at
different wind angles, plus a sparser close layer. Column phases, head onset,
length, width, opacity and tail duration all vary deterministically. Heads and
tails feather independently; color is desaturated and low-contrast. This is
the owner-requested realism correction to the earlier bright, upright bars.
Only 72 cheap ground spatters and eight debris flecks remain as particles. Rain,
spatter, debris and roadway mist cast no shadows. The completed owner has four
steady submissions total, one more than the old three-part weather owner and
well inside the allowance of four additional submissions.

### Performance proof

The real-player `WeatherPerf.tscn` station is the north pavement at 1440p,
canonical night, 16/16 light budget, 30 warm-up and 120 sampled frames. The
first accepted batched-rain A/B pair set measured weather at 43.083/41.634 ms
and its off control at 42.501/41.306 ms: means 42.359 versus 41.904, a
conservative +0.455 ms. After the final realism-only shader tuning, fresh
runs measured 40.667/41.071 on and 41.306/42.185 off. The sign inversion is
runtime noise, not a claimed speed-up; it proves the added shader detail does
not produce a measurable regression above the earlier conservative result.
Both results clear the +0.8 ms contract. The established aerial STREET station
also remained within contract at a conservative +0.775 ms.

**2026-08-14 absolute-baseline correction.** The weather A/B deltas above
remain valid because both sides used the same stream state, but their absolute
frame totals are not production-player baselines. The probe left a detached
camera in `BuildingRoot.view_override`; its 1.68 m eye height admitted F02
through the 1.75 m overlap where production streams from the controller's
0.27 m feet. `WeatherPerf` now moves the player to the lens and clears the
override. The first corrected production frame was 35.680 ms / 19,897 objects /
25,235 calls. T7b's subsequent STREET/core shadow ownership pass brings that
same lens to 26.486/27.042 ms; see `ORISON_STREET_BRIEF.md` §7. The correction
does not alter or reprice T8's weather delta.

### Durable proofs

The fixed render matrix is under `art/renders/weather_sky_t8`: 20 before and
20 final frames, five stations at each of four hours. `cloud_motion` contains
the clean fixed-camera 20-second lower-cloud pair. All use
`WEATHER_SEED=19280731`; the README beside the renders records commands and
interpretation.

The final production revision passed:

- `WeatherSkyTest` — 31/31, including resources, writer ownership, light count,
  fog bounds, exposure matrix, batching, seed, traffic promises and street-end
  survival;
- `StreetContainmentTest` — PASS;
- `FinalMapRouteTest` — PASS;
- `LightingAudit` — 127-space PASS;
- `PassageVisibilityTest` — 32/32;
- `PassageOwnershipAudit` — zero visible unclassified F01 draws;
- `WalkTest FULL` at x8 / 480 Hz — PASS inside the 60-second bound.

One Godot instance ran at a time throughout. The generated sky family, final
rain, fog, lower cloud and proof harnesses are the T8 production checkpoint.
