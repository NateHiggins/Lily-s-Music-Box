# Live weather contract

The Orison may borrow the player's real weather, but it may not silently
borrow the player's location.

## Player contract

- The default observer is fixed at Queens, New York (`40.75, -73.92`).
- Local matching is an explicit settings checkbox.
- The player supplies a city or postal code. The game does not inspect an IP
  address, query a device location sensor, or infer a location from locale.
- Disabling the checkbox stops sending the authored query. A blank query also
  resolves to Queens.
- A failed or incomplete request leaves the authored Queens storm intact.
- A request that cannot start clears its in-flight gate before reporting
  failure, so a later fifteen-minute refresh can retry instead of freezing.
- A successful geocode starts one weather request and returns immediately;
  geocoder JSON is never cross-parsed as a failed weather observation.

## Data and ownership

`LiveWeatherService` uses Open-Meteo's TLS geocoding and forecast endpoints.
It normalizes current cloud strata, precipitation, snow, wind, temperature,
humidity and daylight into a data-only snapshot. It owns no renderer node.

`DayNightDirector` remains the only absolute writer for the Environment,
exterior key and sky material. Live cloud cover adjusts the depth of the lower
cloud deck and horizon atmosphere while retaining the four authored Orison
panoramas. `WeatherFX` remains the owner of precipitation, mist and wind.
Presentation carries `rain_intensity` and `snow_intensity` separately while
retaining their maximum as the general atmospheric precipitation term. Mixed
observations may emit both. The named `snow` simulator is pure frozen
precipitation, and the rain spatter/middle batches must be off while its snow
field is on; every player-following branch shares the building exposure query.
Lightning is equally literal: only WMO thunderstorm codes 95, 96 and 99 arm the
existing two-pulse flash. Changing to any other observation cancels an active
flash and holds its published level at zero, so clear, fog and snow cannot
inherit a scheduler that happened to start under an earlier storm.

Normalized precipitation magnitude is not merely an enable bit. Liquid
intensity drives the existing close-particle occupancy and the optical strength
of both middle-distance shells; frozen intensity drives the existing snow-field
occupancy. Thus drizzle, steady rain and storm remain quantitatively distinct
without another draw owner or an unbounded particle count.
Snow's horizontal gravity follows the same gusted meteorological vector as the
existing windborne debris while retaining a shallow authored terminal fall; an
east wind therefore carries both clouds and flakes west.

Ground mist is not inferred from low cloud fraction. Wet weather may keep the
authored roadway vapor, while dry vapor requires WMO fog code 45 or depositing
rime-fog code 48. A 100% dry overcast therefore owns a ceiling but no street
mist; the feed's named `fog` simulator reaches the same existing mist owner
without pretending that rain fell.

The lower deck is evaluated from the view direction, not panorama UV. Six
nonparallel analytic waves form broad moving cells on the dome; because the
input direction is continuous, the result has no equirectangular seam and no
latitude/azimuth grid. Coverage moves a density threshold rather than merely
changing opacity. Zero coverage therefore remains literally empty, scattered
weather has holes, and the final overcast band closes the hemisphere while
retaining a separate, unsaturated underside-relief channel from the same six
wave evaluations. It stays in the existing sky draw and
adds no texture, volume, node, light or shadow caster.
The density-to-opacity step uses exponential optical depth, so low and broken
reports remain photographically visible instead of becoming a nearly
transparent tint; an exact zero-strength clear report still evaluates to zero.

The same normalized strata also attenuate the one exterior directional key and
hard-ray term. Low cover supplies full effective depth, mid cover `0.68`, and
high cover `0.32`. Clear transmits `1.0`; a closed low report keeps `0.12` as
diffuse-through-cloud directional shape. Ambient Environment fill is
not multiplied down, so overcast becomes soft rather than implausibly black.
The sky shader independently obscures the visible Sun or Moon at the exact
local cloud cell; the bulk coefficient describes average light reaching the
street and does not add a second light owner.

Low cloud alone supplies only bounded aerial perspective (`0.78–0.84` of the
authored fog ceiling). Precipitation adds up to `0.18`, and WMO present-weather
codes 45/48 explicitly receive that full fog term. Thus a dry overcast report
softens the block without erasing it; rain, storm and actual fog may still close
the distance. Cloud cover never impersonates ground fog merely because both
facts are gray.
Relative humidity is normalized to `0–1`; only the band above `0.72` adds haze,
with a hard maximum of `0.08`. Even saturated clear air therefore remains below
the extinction supplied by rain or WMO fog codes. Temperature is carried and
bounded for downstream ambience but does not independently recolor the sky.

The normalized meteorological wind also advects the lower deck. The service's
degrees-from-north bearing is reversed from “comes from” to “moves toward” and
converted once into Godot X/Z space; observed kilometres per hour scale the
angular motion. Zero wind freezes bulk travel while a small opposed evolution
keeps the analytic field from reading as a rigid painted shell. Precipitation,
clouds and period ambience therefore agree on one reported wind without
sharing node ownership.

Cloud strata remain distinct after normalization. Low cover owns the optical
deck; mid cover contributes at `0.48` strength / `0.38` coverage and also feeds
a `0.55` high veil; high cover owns only that translucent veil. A 100% high-only
report therefore cannot close the hemisphere like stratus. At this scenery LOD
the high stratum is a homogeneous `0.18` cirrostratus veil: it partially
extinguishes stars and the celestial source without inventing procedural wisps
that read as projected stripes or cubic shards. It adds no texture, volume,
node or light; shaped wind motion remains the lower/middle deck's job.

`weather_code` and `wind_direction_degrees` remain canonical presentation
facts after normalization. Consumers must not invent shortened aliases. The
period aircraft reverses the meteorological “comes from” bearing through the
same X/Z convention as the cloud deck, so an east wind moves both west; WMO fog
codes can reach the weather and distant-ambience consumers intact.

This separation is the pattern for future reality-selling feeds: network code
publishes bounded facts; an existing production owner translates those facts;
failure preserves authored art; and no feed gains authority over cases, saves,
simulation time or unrelated systems.

## Cost envelope

- One request on entry and at most one refresh per fifteen minutes.
- One optional geocoding request when the player opts in.
- No additional sky draw, light or shadow caster.
- No per-frame network polling.

## Complete simulation

Set `WEATHER_SIMULATE` to `clear`, `scattered`, `overcast`, `rain`, `storm`,
`snow`, or `fog`. Simulation bypasses the network and uses the same normalized
contract as live observations. `clear` is exactly zero cloud and precipitation;
`overcast` and `storm` close the dynamic hemisphere. Snow owns a distinct
particle field rather than masquerading as rain. These presets are production
debug inputs, not a second visual implementation.
Set `WEATHER_SIMULATE_WIND_KMH` (bounded `0–120`) and
`WEATHER_SIMULATE_WIND_DEGREES` (wrapped through `0–359.999…`) to exercise
calm, speed and every meteorological bearing through that same contract.
`WEATHER_SIMULATE_CLOUD_LOW`, `_MID`, `_HIGH` and `_TOTAL` accept bounded
`0–1` fractions. When one or more strata are supplied without `_TOTAL`, the
simulator derives total cover from their maximum. This permits high-only,
mid-only and low-deck proofs without contradictory illumination facts.
`WEATHER_SIMULATE_TEMPERATURE_C` is bounded to `-50–55`; humidity is supplied
as `WEATHER_SIMULATE_HUMIDITY` in percent and bounded to `0–100`.

## Verification

`LiveWeatherServiceTest` proves Queens fallback, explicit text-only geocoding,
response rejection and normalization. `WeatherSkyTest` proves the production
sky and weather owners remain bounded after integration.
