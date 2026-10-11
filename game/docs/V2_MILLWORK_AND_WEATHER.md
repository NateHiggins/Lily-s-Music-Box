# V2 continuous millwork and NYC seasonal sky

Evidence class: **INERT**. Assembly and implementation guide, not a completion receipt.

The production V2 root assembles this system automatically. Explicit V1 rollback
keeps its existing scene and weather presentation. No API credential is shipped.

```text
OrisonV2Runtime (Node3D)
├── OrisonV2Blockout / room owners
│   ├── HistoricMillwork (MultiMesh: baseboard, bead, eye rail, crown)
│   ├── PublicWainscot (MultiMesh: backing)
│   ├── PublicWainscotFrames (MultiMesh: separate rails and stiles)
│   └── PublicWainscotCap (MultiMesh: separately textured molded wood)
├── Passage / ResidentGeometry / shop cells / StandardWallMillwork
├── WakingAtmosphere (Node3D)
│   ├── WorldEnvironment → Environment → Sky → v2_seasonal_sky.gdshader
│   ├── NightSkyHalfDome (Compatibility fallback, hidden in Forward+)
│   ├── CelestialKey (DirectionalLight3D)
│   ├── DayNightDirector (sole absolute light/environment writer)
│   └── WeatherManager
│       └── LiveWeatherService → LiveWeatherHTTPRequest
├── WeatherFX (existing precipitation owner, V2 subclass)
│   ├── rain, splash, snow, hail, leaf stock and roadway mist
│   └── SeasonalOutdoorAir (FogVolume, Forward+)
└── LampAtmosphere (existing carried-lamp optical authority)
```

Millwork is fitted after all physical room walls exist, so both faces of a shared
wall can be finished. Collision boxes supply cut-wall fragments and exposed end
returns. Opening casings and window recesses clip the visual stock; doors,
collisions, schedules and source wall ownership remain authoritative.

Baseboards are 140 mm high with a separate 26 mm bead. Decorative rooms have a
42 mm eye rail centered at 1.65 m. Public panel backing is 16 mm thick; its cap
is a separate 40 mm high, 50 mm deep molded piece centered at 1.34 m. Cap, frame
and upright grain follows the member's length. Painted stock uses catalogue
**trim**, wood uses **wood_dark**, with custom albedo, roughness and normal maps.
The Blender source owns the profile and stock UVs; instance dimensions convert
UVs to meters. Imported shop wall finishes are fitted from original structural
massing/floor records on initial load and every geometry reload.

Enable the existing `weather_network_enabled` setting for live conditions.
With `OPENWEATHERMAP_API_KEY` in the game's process environment, the provider
requests OpenWeatherMap Current Weather at Queens, NYC (40.75, -73.92), metric
units, every 600 seconds. Without that credential it retains the existing
keyless Open-Meteo provider. An explicit player-local-location opt-in continues
to use the existing geocoder/provider. Network weather remains off by default;
no IP geolocation, device location, or additional opt-in is introduced.

The OpenWeather adapter validates clouds, humidity, temperature, wind speed,
wind bearing and weather ID before publishing a complete snapshot. Wind m/s is
converted to the existing km/h contract; meteorological bearings are interpreted
as the direction wind comes from. Observed precipitation drives existing
rain/snow/hail states. IDs alone never fabricate rainfall. Credentials are never
stored in resources, receipts or diagnostic messages. HTTP timeout is eight
seconds; failures and rate-limit responses fall back rather than retrying in a
tight loop. The next scheduled refresh remains ten minutes away.

`WeatherManager.receive_snapshot(snapshot)` accepts the existing normalized
provider contract. `current`, `target`, `source`, and `last_error` expose its state.
`conditions_changed` publishes resolved presentation conditions. Numeric values
use a five-minute smoothstep interpolation from the current state to the new
observation; wind bearing follows the shortest angular arc. The lighting owner
receives one update per second, while wind offset and temporal samples advance
each rendered frame. Wind integration avoids jumps when reported speed changes.

Fallback temperatures use the [NWS Central Park 1991–2020 monthly normals](https://www.weather.gov/media/okx/Climate/CentralPark/nycnormals.pdf).
Cloud, wind and humidity fallback values are explicitly idealized art recipes.
They are neither today's observations nor reconstructed 1928 weather. The
saved CampaignClock controls the seasonal blend, Gregorian date, sun, moon and
stars. Live observations cannot replace the campaign date with the host year.
Leap-day celestial calculations remain Gregorian; the gameplay's 365-key
schedule convention remains unchanged.

Forward+ uses a native Godot sky with a half-resolution cloud pass. The shader
combines artistic Rayleigh phase, a humidity-dependent Mie halo, saturated
twilight, existing calibrated night/star/moon assets, and an independently
panning 2D cirrus layer. Seasonal density envelopes favor a flat winter deck,
variable spring cells, tall summer volumes, and sparse autumn low cloud with
high wisps. Directional light and ambient color respond to the same conditions.
Outdoor fog receives real engine light/shadow scattering; covered positions
suppress precipitation and the local weather fog. The carried-lamp fog retains
its separate density/resource owner.

The authored tileable 64³ Perlin-Worley volume uses two RG8 density channels and
seven complete 3D mip levels (599,186 bytes total). Its generator is
`tools/build_weather_noise.py`; the runtime loader uploads all 127 mip slices
once. The cirrus mask has ordinary GPU-compressed mipmapped import. Cloud rays
use 40 samples, 64 when a rare recognizable shape is present, two short light
samples, and early termination below 0.5% transmission. Reflection radiance uses
a cheap cloud-color approximation and a 128-pixel incremental cubemap, avoiding
six additional volumetric marches. These are bounded costs, not an FPS promise.

The viewport's Forward+ TAA supplies camera reprojection and temporal history;
the cloud shader adds stratified ray jitter. This implementation does not claim
a separate cloud motion-vector/history buffer. `weather_taa_enabled=false`
retains the user's viewport setting. Compatibility retains the inexpensive
spatial sky and weather presentation; volumetric clouds, local fog and TAA
require Forward+. See [Godot sky shader passes](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/sky_shader.html)
and [ImageTexture3D](https://docs.godotengine.org/en/stable/classes/class_imagetexture3d.html).

One deterministic 1% eligibility draw is made per campaign date and seed. Duck,
whale and three-masted ship SDFs contribute translucent density, with noise
modulating their contours. They share cloud wind advection, fade in over 90
seconds and retire by 900 seconds. Reloads retain the same daily eligibility;
they do not multiply the random chance. Debug `WEATHER_CLOUD_SHAPE=duck|whale|ship`
forces an example. Existing `WEATHER_SIMULATE`, `WEATHER_SEED`, `DAYNIGHT_FORCE`,
and reduced-flash settings remain available.

Run lightweight `V2MillworkWeatherTest.tscn` and `V2SkyReview.tscn` through the
Godot lane before the expensive production composition. Render the native
Blender profile first. Then run `OrisonV2SurfaceInventory.tscn` once with
`-Windowed`, `-ShotDir` and `-LogPath` for combined wall-ray coverage, seasonal
captures, loaded UV/PBR/mip qualification and a test-written runtime contract.
Inspect shader errors in stderr even when a wrapper exit is zero. Renew the
source-bound surface review after changes; old receipts cannot qualify new art.
The provider reference is [OpenWeather Current Weather](https://openweathermap.org/api/current).
