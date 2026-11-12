# Actual architecture and control ownership

Start with the installed V2 chain below, then follow the exact requested effect.
Paths are relative to the repository; read their current code before changing a
contract. [V2 integration](../../../../design/V2_SKY_WEATHER_INTEGRATION_2026-10-24.md),
[calendar](../../../../design/V2_WEATHER_CALENDAR_2026-10-24.md),
[celestial reference](../../../../design/CELESTIAL_SKY_CONTRACT.md) and
[live-weather reference](../../../../design/LIVE_WEATHER_CONTRACT.md) provide
context. Older sections can describe V1, old refresh intervals or replaced Moon
behavior; the Bible and actual V2 owners resolve those differences.

## Producer to consumer

| Owner | Responsibility and boundary |
|---|---|
| `game/scripts/building/orison_v2_atmosphere.gd` | Creates per-world Environment, sky material and one celestial key; selects the actual shader. Forward+ normally uses `game/shaders/queens_weather_sky.gdshader`, native half-resolution sky and incremental radiance. `WEATHER_SKY_BASELINE=1` selects `v2_seasonal_sky.gdshader`; Compatibility retains the spatial `orison_waking_sky.gdshader` dome. A source comment saying “seasonal” does not identify the loaded shader. |
| `CampaignClock`, `CampaignClockDriver`, `game/scripts/game/campaign_weather.gd` | Authoritative civil/fractional campaign time and the authored year's interpolated weather/transport. Keep the automatic clock writer and existing explicit seek/prologue paths. The default calendar is invented Queens weather, not recovered historical measurements. |
| `game/scripts/building/WeatherManager.gd` | Owns normalized current/target/origin weather, calendar fallback, transitions, shared conditions publication, phenomena and Queens extension. Publishes `LivingSky` state through the existing material. It does not delegate campaign-time authority to an HTTP feed. |
| `game/scripts/building/live_weather_service.gd` | Optional provider/network adapter and QA simulations; supplies data, not render nodes or a clock. Network weather is off by default in GameBoot. Preserve explicit location consent and Queens fallback; no IP/sensor inference. Read current provider selection/normalization rather than assuming the older Open-Meteo-only reference. |
| `game/scripts/building/v2_city_day_night_director.gd` extending `day_night_director.gd` | Resolves light/environment, V2 fog, solar/lunar/star frames and composed optical changes. The base remains the absolute Environment/exterior-key writer. Inspect `resolved_profile()` and final shader bindings after live/cloud/extreme modifiers, not only the authored keyframes. |
| `game/scripts/building/living_sky.gd`, `game/data/weather/living_sky.json` | Pure three-band interpretation of weather, genera, coverage, wind and continuous campaign transport. No separate HTTP, random weather or save owner. Scenario labels classify eligible states; they do not reroll geometry at midnight. |
| `game/scripts/building/queens_weather_extension.gd` | Existing manager-owned extreme/formation/precipitation translation and shader parameters. Inspect `sky_parameters()` plus its dynamic publish loop: literal `set_shader_parameter("name",...)` searches alone miss these bindings. Render-only temporal projection deliberately excludes surface deposition/world writes. |
| `game/scripts/building/v2_weather_fx.gd` and its inherited weather owner | Own precipitation/air presentation through real cover/exposure queries. Keep rain, sleet, snow and hail distinct and bounded; do not construct duplicate legacy and Queens emitters. Preserve indoor shelter, carried-light fog and existing surface wetness ownership. |
| `celestial_ephemeris.gd`, `skywatch_astronomy.gd`, solar/Moon helpers and shader includes | Compute and present observer-relative astronomy through the director. Date/observer units, apparent direction, telescope frame and current art-directed Moon behavior must agree. A legacy small-Moon or photographed-star description is not the present Queens contract. |
| `sky_phenomena.gd`, `game/data/weather/phenomena.json`, `star_god.gd` | Dated/eligible phenomena and the specifically ruled event. Do not turn forced QA spectacles into everyday weather, substitute a new event calendar or generalize the single sanctioned eclipse exception. |

## What the Queens shader actually renders

Trace `sky()` in `queens_weather_sky.gdshader` and its six recursive includes
before changing quality or compositing. There are three deliberately different
paths:

- Reflection cubemap faces use a cheap haze/coverage/wetness approximation;
  they do not raymarch the clouds. A reflection is not a duplicate sky render.
- The half-resolution pass marches volumetric clouds and writes premultiplied
  cloud RGB plus opacity. Coarse steps, special-shape intervals, lighting taps
  and early opacity termination determine cost; there is no universal quality
  slider that safely replaces those decisions.
- The full-resolution pass builds the celestial background, high ice layer,
  cirrus and behind-cloud spectacles, then composites
  `base * (1 - cloud_alpha) + cloud_rgb`. Point stars have an additional
  transmission gate so the march's residual numerical transmission does not
  reveal HDR stars through an opaque ceiling. Front spectacles, integrated
  height haze and the narrow solar filter follow. Preserve this ordering.

Useful families to trace through their binders are `living_layer_0..2`,
`living_brush_0..2`, `living_motion_0..2`, `living_drift_0..2` and
`living_flow_0..2` for cloud structure/transport; `wx_*` for formations and
extreme optics; `sun_*`, `moon_*`, equatorial axes and the skywatch includes
for celestial appearance; and `spectacle` arrays for eligible events. The
director's `exposure` is distinct from the Environment's tone mapping and
key-light energy. `fog_horizon_color`, `living_aerosol` and `wx_whiteout`
participate in sky haze; ordinary scene depth fog is a separate director-owned
operation. Turning down one to hide an error in the other can break street/sky
agreement. Inspect the final loaded parameters, not these names alone.

## Units at the boundary

| Value | Actual convention to preserve |
|---|---|
| Calendar `days[].frames[].minute` | Author whole minutes since local midnight, with first frame at zero; current validation compares integer-coerced values. Date/UTC conversion belongs to CampaignClock; fixed EST campaign assumptions are not host daylight-saving conversion. |
| `temperature_c`, `pressure_hpa` | Celsius and hPa; retain finite-value normalization and current provider mappings. |
| Authored/provider `relative_humidity` | Percent at the raw snapshot/calendar input. `LiveWeatherService.presentation()` publishes a fraction `0..1`. Putting `0.6` in a raw calendar frame means 0.6 percent, not 60 percent. |
| `cloud_total`, `cloud_low/mid/high` | Fractions `0..1`; total and strata are not blindly summed. LivingSky reconciles their optical union. |
| `wind_speed_kmh`, `wind_gusts_kmh` | km/h at the normalized weather interface. Convert once for m/s particle/extension vectors or km/hour transport integration. |
| `wind_direction_degrees` | Meteorological “comes from,” clockwise from north. Existing Godot travel vector is `(-sin(bearing), 0, cos(bearing))`: an east wind moves west. Do not reverse it twice. |
| Raw `rain_mm`, `snowfall_cm`; presentation intensities | Different physical units at raw input; normalized liquid/frozen intensity at presentation. Preserve provider-ID versus WMO distinctions and the documented nominal-intensity exceptions. |
| Cloud `base_km`, `thickness_km`, `scale_km`, `offset_km` | Kilometres; positive physical sizes. World/camera positions are metres; `wx_camera_km` converts through `camera_position_m * .001`. Use the actual composed coordinate frame, not an arbitrary origin. |
| Phenomenon bearing | Public `force_phenomenon(..., bearing_degrees)` takes degrees; the schedule/internal representation uses radians. Read the adapter before directly editing data. |
| Optical depth, gains and normalized intensities | Dimensionless, with clamps from the actual owner. `set_tuning_offsets(ambient,fog,key)` clamps gains to `0..2`; these are presentation gains, not new weather facts. |

## Defaults, overrides and real controls

For each candidate control record its declaration/default, shader uses, include
path, setter(s), dynamic dictionary key and final loaded value. Classify it as
weather-derived, calendar/astronomy-derived, owner tuning, debug-only, shader-only
or declared-but-unused. A shader default can be overwritten each publication;
editing it will not necessarily change the game. Source expressions/loop counts
without uniforms are hard parameters, not Inspector controls.

Do not invent Inspector ranges from visual intuition: the inspected Queens
uniforms did not declare `hint_range`. Derive constraints from normalization,
shader math and demonstrated valid cases; new constraints belong to the new
control's contract. `lower_cloud_strength` and `temporal_phase` declarations do
not establish useful controls in the current Queens draw. Similarly, a familiar
`sun_eye` name is not proof of the active solar feature's binder.

Keep continuous advection in its existing double-precision transport owner;
periodic shader coordinates are reduced before float upload. Avoid resetting
large offsets or using per-instance uptime to repair distant-date precision.
Such shortcuts can introduce midnight, rebuild or reverse-time jumps. Profile
quality/sample-count changes against the real half-resolution/TAA/upscale and
radiance path; a declaration list does not describe the actual execution cost.
