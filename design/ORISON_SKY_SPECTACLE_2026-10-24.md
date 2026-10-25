# Sky spectacle: the year's atmospheric phenomena (2026-10-24)

Evidence class: **INERT**

This note describes how the V2 waking sky stages the owner's list of spectacular
atmospheric phenomena across the campaign year (10 November 1928 to 9 November
1929). It is a design and hand-over note. It proves nothing on its own; the
runtime proof is the schedule test and the bench captures listed at the end.

## What the player sees

There are 41 phenomena in five families: sculpted clouds, the ash wall, high dome
layers, atmospheric electricity, and optics. Each one has at least one dated
occurrence in the campaign year, at a season and time of day that suit it. The
Record and the Speaker report each occurrence the next morning, in 1928
vocabulary: "mock suns", "corposants", "the northern lights", "a water-spout",
"mother-of-pearl clouds". The modern names (sprites, ELVES, STEVE, asperitas,
microburst, pyrocumulonimbus) stay in code and data and never appear in print.
Bible §VIII applies: signal technology is advanced and weather is not, so the
papers describe what the sky did and never explain it.

The aesthetic is painterly grandeur over strict physics. The objects are placed
5 to 15 km out, against the 1928 Queens skyline. The haboob is sepia and ochre,
so it reads as the borough's own coal smog thickening, not as a desert storm.

## Owners (extended, not forked)

| Owner | What it now does |
| --- | --- |
| `game/data/weather/phenomena.json` | The catalogue (slot, family, period label, months, sun window, weather requirements, the weather it forces, the words the papers must or must not print) and the dated occurrences with their press lines. |
| `game/scripts/building/sky_phenomena.gd` | Loader and validator. Queries: active occurrences at an absolute campaign minute, seeded daily rolls, press lines for an issue date, the ear rule. |
| `game/scripts/building/WeatherManager.gd` | Trigger architecture. It owns the schedule, resolves the active set every 0.25 s, forces scheduled weather onto the seasonal presentation, syncs flashes to ground strikes, pushes two uniform arrays to the sky, and drives St. Elmo's fire and the microburst gust. |
| `game/shaders/v2_seasonal_sky.gdshader` | Every visual except the corona and the street-level dust. Deck sculpting is in the existing density field. Sculpted objects use one bounded second march. The dome, electric and optic layers are composited behind or in front of the lower clouds. |
| `game/shaders/v2_weather_air.gdshader`, `game/scripts/building/v2_weather_fx.gd` | The ash front: 2D noise advancing downwind, driving FogVolume density and ochre albedo around the player. |
| `game/scripts/building/v2_city_day_night_director.gd` | The ash wall's depth fog: sepia colour, 4 to 45 m range, and a dimmed key light. |
| `game/scripts/building/weather_fx.gd` | New `ground_strike` signal at each big stroke. `set_burst` speeds the existing splash particles and drives the rain flat as the microburst outflow arrives. |
| `game/scripts/building/orison_v2_lamp_atmosphere.gd` | `set_weather_demand`: the froxel pass stays on while the ash wall blows. |
| `game/scripts/building/orison_v2_st_elmo.gd`, `game/shaders/v2_st_elmo_corona.gdshader` | One instanced, additive, unshaded draw per owner, hidden at zero. Tips are the top vertices of each horizon block's limestone chimney cap (124 blocks), the roof apex of every neighbouring water-tower site (`orison_v2_city_tanks.gd`), and the crown of the Orison's own house tank. |
| `game/scripts/game/newspaper_catalog.gd`, `game/scripts/ui/newspaper_panel.gd` | `sky_notices(date)`: each paper prints its own line under the late wire on the morning after an event. |
| `tools/audit_v2_surfaces.py` | Admits the corona as a named optical effect (class **electric_corona**), but only from its own owner script and shader. |

### GPU budget

The frame is draw-call bound, so everything except the corona is a uniform-gated
branch in the existing sky submission. A phenomenon at level zero costs one
uniform compare. The object march runs only when an object slot is non-zero, and
only across the union of the active objects' bounding spheres: 48 steps, plus one
shadow sample per occupied step. Deck phenomena widen the existing march from 40
to 64 steps only while they show. The corona adds three instanced draws, all
invisible except during the two corposant storms.

## Trigger architecture

1. **Dated occurrences.** The file lists 51 of them. Each has a date, a
   local start time (EST, UTC-5, the campaign clock's frame), a duration, a
   bearing, an intensity and an optional weather override. The envelope is
   a smoothstep fade in and out over the phenomenon's **fade_minutes**.
2. **Seeded daily rolls** for the rarities: **noctilucent** 3.0%, **aurora** 0.5%, **halo_22** 1.2%, **sun_dogs** 1.2%, **light_pillars** 1.0%, **crepuscular_rays** 1.2%, **green_flash** 0.8%. The roll hashes the
   salt, the phenomenon id, the day ordinal and the weather seed
   (`WEATHER_SEED`, default 1928, the seed the cloud shapes already use). A
   reload of the same campaign therefore shows the same sky. A rolled day must
   also be in season, its seasonal weather must meet the requirements, and, when
   the papers are on the rack, its printed weather must allow it. The roll picks a
   start inside the sun window from a quarter-hour scan of the day.
3. **Weather forcing.** While an event shows in seasonal mode, its forced
   weather is blended into WeatherManager's presentation by the envelope:
   numeric fields are interpolated and flags switch past 0.35. Everything
   downstream reads the result, so the rain, fog, key light, ambient audio and
   the resident agenda's exposure penalties all follow the storm. Forced flags
   reset to the target every frame, so they never outlive their event. With
   opt-in live weather the schedule never overwrites an observation. An event
   shows only if the live conditions already meet its requirements.
4. **Flashes.** Sprites, blue jets, gigantic jets and ELVES ride
   WeatherFX's big ground strokes. Each lasts 1 to 3 frames and picks one of the
   active kinds. Anvil crawlers flash on strokes and on their own 3 to 9 s timer,
   decaying with a 0.35 s constant. Plume lightning in the fire cloud has its own
   2 to 6 s timer, because a dry fire plume raises no WeatherFX thunderstorm.
5. **Publication.** **current.phenomena** lists the active events (id, period
   label, family, level, bearing). It reaches every `conditions_changed`
   listener. This is the hook the resident agenda can use to send residents to
   the roof for a spectacle.
6. **Debug and benches.** `force_phenomenon(id, level, bearing)` and the
   `WEATHER_PHENOMENON=<id>` environment variable show any phenomenon now.
   `trigger_flash()` fires every active flash phenomenon.

## Shader math the brief asked for

- **Smooth-minimum SDF blends.** The lenticular is four squashed ellipsoids
  (radii shrinking 1.9, 1.55, 1.15, 0.62 km) stacked 0.19, 0.36 and 0.50 km
  apart and folded together with the polynomial smooth minimum
  `h = clamp(.5+.5(b-a)/k, 0, 1); mix(b,a,h) - k h (1-h)` (k = 0.07 to 0.09).
  Mammatus is a cell grid of jittered spheres hung under the base, smooth-min
  blended (k = 0.07) into an inverted-noise underside, `(1.30 - (1-n)·0.16) - y`.
  A low sun lights them from below with a fiery term that grows as the sun
  approaches the horizon (`smoothstep(.24, 0, sun.y)`).
- **Noctilucent sun-pitch illumination.** The light is
  `smoothstep(-13.5, -11, e) · (1 - smoothstep(-6.5, -4.5, e))`, where e is the
  sun's altitude in degrees. The layer is therefore lit only while the sun is 6 to
  12 degrees down. The same factor multiplies the lower clouds' lighting by
  (1 - 0.9 · NLC), which leaves them black against the electric blue and silver.
- **Branching noise for spider lightning.** The ray is projected onto the cloud
  base plane (y = 1.25 km). A cellular F2 minus F1 edge distance is taken over a
  domain-warped coordinate, at a trunk scale and a twig scale, and put through a
  harsh step (smoothstep 0 to 0.035). The network grows outward from the stroke's
  bearing as the flash decays and re-roots every burst. It shows only where the
  cloud alpha says there is a base to crawl on.
- Other sculpting follows the brief. The shelf cloud is a slab minus a wedge, the
  front plane sloping up and back. The wall cloud is a descending cylinder with
  scud. The morning glory is three rolling tubes across the horizon axis. Virga is
  noise stretched downward and faded before the ground. The microburst is a shaft
  to the ground plus an outflow curl. The tornado is a central cylinder and three
  orbiting suction cylinders with debris. The waterspout is a laminar funnel with
  spray. The fire cloud is black-brown smoke condensing into white cumulus, with
  flickering firelight at its foot. The striated supercell is stacked flaring
  plates, and the anvil carries an optional overshooting dome. The pileus is a cap
  lens over a cauliflower tower. Asperitas warps the deck base with crossed
  swells. Kelvin-Helmholtz is hollow leaning curls on a sheared layer. The
  fallstreak hole is a round cut in the deck with ice falling out of it.
- High layers: aurora is three folded curtains from domain warp and panning
  sines, green at the foot and magenta then violet above, with ray striations.
  STEVE is a narrow mauve great-circle arc tilted poleward of the zenith, with a
  stepped green picket fence on its equatorward side. Nacreous clouds are
  thin-film cosine colours on lens-shaped fbm, lit only from sunset to 8 degrees
  below.
- Optics: the 22 degree halo (red inner rim). Sun dogs placed by
  `cos θ = sin²e + cos²e cos Δaz` with θ = 22 + 0.12e. The circumhorizontal arc
  46 degrees under a sun above 58 degrees. The circumzenithal arc at
  (44 - e) degrees from the zenith. Sun and city-lamp pillars. The primary bow
  (40.6 to 42.4 degrees, red outside) and the secondary (50.4 to 53.6 degrees,
  reversed), with Alexander's dark band between and supernumerary fringes inside.
  Crepuscular beams, converging again at the antisolar point. Glory rings on the
  fog. Iridescence on thin cloud near the sun. The green flash as a refracted rim
  on the last sliver of disc. Fata Morgana as erect and inverted towers mirrored
  about a duct line over the Sound.

## Period and plausibility choices

- **volcanic_lightning** is staged as lightning in the Newtown Creek oil-works
  fire plume (pyrocumulonimbus), because no volcano is near Queens. It is the
  same dirty-plume discharge.
- **haboob** comes from the Corona ash dumps, the valley of ashes, in dry
  windy weather. The Speaker's ear already prints "Smoke over Corona" on 5 March
  and the Record prints "Fair, windy. Smoke over Corona" on 20 April 1929.
- Rare high-latitude sights (aurora, noctilucent and nacreous clouds) are set on
  clear nights or twilights that the papers print as fair or bitter. Noctilucent
  clouds fall on the solstice twilight. Nacreous clouds fall on the coldest evening
  in the papers (20 January 1929, high 8).
- The **green_flash** rides the city skyline, not the sea horizon. From a Queens
  roof the sun rises and sets behind buildings about 3 degrees up, so the flash is
  staged at that hard edge, as it is seen on a far ridge. Its sun window is 2 to
  4.5 degrees.
- Every storm phenomenon falls on one of the four evenings the papers forecast
  thunder (25 June, 11 July, 19 July, 6 August 1929), or the morning after
  ("Cooler after storms") for asperitas. The ice-crystal optics fall on the cold,
  clear days of the winter ears. The thundersnow corposants fall on the 7 February
  "Snow tonight" ear.

## The year

The sun column is the altitude at the midpoint, from the same ephemeris the
director uses. The ear column is the Record's printed weather for that day.

| Date | Start (EST) | Length | Phenomenon | Sun | Record ear |
| --- | --- | --- | --- | --- | --- |
| 1928-11-20 | 10:00 | 120 min | **halo_22** (the ring round the sun) | 29 deg | Cloudy, cold. High 37. The Weather Bureau expects snow tomorrow afternoon. |
| 1928-12-09 | 16:15 | 30 min | **light_pillars** (pillars of light) | -1 deg | Clear and bitter. High 19. Low 8 at 6:30 a.m. Wind northwest, moderate. |
| 1928-12-14 | 21:30 | 120 min | **aurora** (the northern lights) | -66 deg | Fair and cold. High 25. Low 13. The Sound ice twelve inches at Whitestone. |
| 1928-12-19 | 13:00 | 120 min | **lenticular** (lens clouds standing in the wind) | 19 deg | Fair and colder. High 24. Low 11 tonight. Wind northwest, fresh. |
| 1929-01-08 | 07:15 | 40 min | **glory** (the glory on the fog) | 2 deg | Fog, then mild. High 50. Low 41. The Weather Bureau gives no frost before Friday. |
| 1929-01-17 | 10:30 | 50 min | **fallstreak_hole** (the hole punched in the cloud) | 26 deg | Cloudy and colder. High 25. Low 16. Snow flurries by evening. |
| 1929-01-19 | 07:50 | 50 min | **sun_dogs** (mock suns) | 9 deg | Fair and bitter cold. High 12. Low 1. The Sound freezing to Throgs Neck. |
| 1929-01-20 | 17:00 | 35 min | **nacreous** (mother-of-pearl clouds) | -4 deg | Clear and bitter. High 8. Low 2 below at 6 a.m. Sound frozen to Throgs Neck. |
| 1929-01-21 | 22:00 | 60 min | **light_pillars** (pillars of light) | -61 deg | Clear and cold. High 14. Low 3. Coldest January Sunday since 1918. |
| 1929-02-06 | 14:30 | 30 min | **kelvin_helmholtz** (breaking-wave clouds) | 23 deg | Fair and cold. High 26. Low 15. Northwest wind. |
| 1929-02-07 | 21:10 | 40 min | **st_elmos_fire** (corposants on the stacks) | -47 deg | Cloudy, colder. High 22. Low 10. Snow tonight. |
| 1929-02-20 | 09:10 | 40 min | **circumzenithal_arc** (the upside-down bow) | 27 deg | Fair and cold. High 33. Low 22. |
| 1929-03-05 | 14:00 | 30 min | **haboob** (the ash wall from the Corona dumps) | 35 deg | Clearing and colder. High 39. Low 28. |
| 1929-03-22 | 15:00 | 60 min | **virga** (rain that never lands) | 28 deg | Fair. High 50. Low 37. |
| 1929-03-29 | 22:00 | 90 min | **aurora** (the northern lights) | -42 deg | Fair. High 55. Low 42. Good Friday. |
| 1929-04-14 | 11:00 | 40 min | **iridescence** (rainbow-edged clouds) | 58 deg | Cloudy. High 61. Low 49. |
| 1929-04-17 | 16:20 | 30 min | **rainbow** (the double bow) | 22 deg | Showers, clearing. High 56. Low 45. |
| 1929-04-20 | 15:10 | 45 min | **haboob** (the ash wall from the Corona dumps) | 34 deg | Fair, windy. High 61. Low 44. Smoke over Corona. |
| 1929-05-09 | 13:30 | 90 min | **fata_morgana** (the castles over the Sound) | 51 deg | Fair and warm. High 81. Low 63. |
| 1929-05-13 | 17:10 | 30 min | **rainbow** (the double bow) | 17 deg | Showers. High 64. Low 52. |
| 1929-06-09 | 04:44 | 8 min | **green_flash** (the green flash) | 3 deg | Fair, calm. High 77. Low 60. |
| 1929-06-14 | 11:20 | 70 min | **circumhorizontal_arc** (the fire rainbow) | 73 deg | Fair. High 80. Low 64. |
| 1929-06-21 | 20:05 | 45 min | **noctilucent** (luminous night clouds) | -9 deg | Hot. High 90. Low 72. Sunrise 5:25 a.m. The longest day. |
| 1929-06-25 | 15:30 | 95 min | **anvil_cumulonimbus** (the anvil thunderhead) | 34 deg | Hot, humid. High 94. Low 75. Thunderstorms likely by evening. |
| 1929-06-25 | 15:50 | 60 min | **overshooting_top** (the dome over the anvil) | 33 deg | Hot, humid. High 94. Low 75. Thunderstorms likely by evening. |
| 1929-06-25 | 18:40 | 50 min | **mammatus** (pouched storm clouds) | 3 deg | Hot, humid. High 94. Low 75. Thunderstorms likely by evening. |
| 1929-06-26 | 08:00 | 50 min | **asperitas** (the rough sea overhead) | 42 deg | Cooler after storms. High 76. Low 64. |
| 1929-07-03 | 20:10 | 40 min | **noctilucent** (luminous night clouds) | -10 deg | Fair, hot. High 90. Low 73. |
| 1929-07-11 | 14:10 | 40 min | **pileus** (the cap cloud) | 54 deg | Hot. High 96. Low 78. Thunderstorms tonight, the Bureau states. |
| 1929-07-11 | 17:20 | 25 min | **shelf_cloud** (the roll before the squall) | 20 deg | Hot. High 96. Low 78. Thunderstorms tonight, the Bureau states. |
| 1929-07-11 | 20:10 | 60 min | **spider_lightning** (lightning crawling under the cloud) | -12 deg | Hot. High 96. Low 78. Thunderstorms tonight, the Bureau states. |
| 1929-07-11 | 21:30 | 60 min | **elves** (the red ring) | -21 deg | Hot. High 96. Low 78. Thunderstorms tonight, the Bureau states. |
| 1929-07-12 | 07:20 | 60 min | **asperitas** (the rough sea overhead) | 34 deg | Cooler after storms. High 81. Low 67. |
| 1929-07-19 | 16:40 | 60 min | **striated_supercell** (the banded storm) | 23 deg | Hot. High 95. Low 77. Storms tonight, the Bureau states. |
| 1929-07-19 | 17:40 | 30 min | **wall_cloud** (the lowered storm floor) | 15 deg | Hot. High 95. Low 77. Storms tonight, the Bureau states. |
| 1929-07-19 | 18:05 | 18 min | **tornado** (the twister) | 11 deg | Hot. High 95. Low 77. Storms tonight, the Bureau states. |
| 1929-07-19 | 18:30 | 40 min | **st_elmos_fire** (corposants on the stacks) | 5 deg | Hot. High 95. Low 77. Storms tonight, the Bureau states. |
| 1929-07-19 | 22:10 | 50 min | **red_sprite** (red flashes over the storm) | -25 deg | Hot. High 95. Low 77. Storms tonight, the Bureau states. |
| 1929-07-19 | 22:40 | 30 min | **blue_jet** (blue jets from the storm top) | -27 deg | Hot. High 95. Low 77. Storms tonight, the Bureau states. |
| 1929-08-06 | 17:30 | 15 min | **microburst** (the downburst) | 15 deg | Hot. High 96. Low 77. Storms by evening, the Bureau states. |
| 1929-08-06 | 20:20 | 40 min | **spider_lightning** (lightning crawling under the cloud) | -16 deg | Hot. High 96. Low 77. Storms by evening, the Bureau states. |
| 1929-08-06 | 21:50 | 40 min | **gigantic_jet** (the great jet) | -27 deg | Hot. High 96. Low 77. Storms by evening, the Bureau states. |
| 1929-08-15 | 17:50 | 40 min | **crepuscular_rays** (sunbeams fanned over the borough) | 7 deg | Fair, cool. High 82. Low 66. |
| 1929-08-15 | 18:00 | 35 min | **anticrepuscular_rays** (beams meeting in the east) | 6 deg | Fair, cool. High 82. Low 66. |
| 1929-08-24 | 15:00 | 260 min | **pyrocumulonimbus** (the fire cloud over Newtown Creek) | 16 deg | Fair, warm. High 86. Low 70. |
| 1929-08-24 | 18:30 | 50 min | **volcanic_lightning** (lightning in the fire cloud) | -3 deg | Fair, warm. High 86. Low 70. |
| 1929-09-12 | 11:20 | 20 min | **waterspout** (the water-spout on the Sound) | 53 deg | Fair, cooler. High 71. Low 54. |
| 1929-09-17 | 21:40 | 110 min | **aurora** (the northern lights) | -44 deg | Fair. High 71. Low 54. |
| 1929-09-17 | 23:05 | 25 min | **steve** (the violet arch) | -47 deg | Fair. High 71. Low 54. |
| 1929-09-24 | 05:40 | 40 min | **morning_glory** (rolling clouds off the Sound) | 2 deg | Fair, cool. High 64. Low 48. |
| 1929-10-04 | 17:09 | 8 min | **green_flash** (the green flash) | 3 deg | Fair, mild. High 71. Low 55. Sundown 5:36 p.m. |

## Verification

- `game/tests/SkyPhenomenaScheduleTest.tscn` holds the schedule. It loads with
  no validation errors (every phenomenon dated inside the year, in season, inside
  its sun window, under weather that meets its requirements). Every dated day's
  printed weather allows its event, and every event is reported the next morning.
  Rolls are reproducible from the seed, in season, inside the window, and rare. A
  broken document is refused. The production WeatherManager shows the dated
  tornado, forces its storm, publishes it to residents and pushes the slot to the
  sky shader.
- `game/tests/V2SkySpectacleBench.tscn` walks the schedule and saves one frame
  per phenomenon (two for the ash wall), windowed through the lane, over the real
  V2 city horizon.
- Gates: `tools/audit_data_consumption.py --baseline` (0 new),
  `tools/audit_period_dates.py` (pass, with `sky_phenomena.gd` classified as an
  authored campaign calendar consumer), and the corona admission test in
  `tools/tests/test_v2_surface_requirements.py`. No surface textures were added;
  the corona is procedural.

## Follow-ups

- The resident agenda can read **current.phenomena** to draw residents to the
  roof, and can let them remark on the event.
- The papers' ears are authored text. The schedule was fitted to them, and the
  test holds that fit. Any future edit to an ear on a scheduled day must keep the
  test green.
