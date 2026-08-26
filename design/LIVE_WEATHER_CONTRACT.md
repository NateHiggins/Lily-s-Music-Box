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

## Data and ownership

`LiveWeatherService` uses Open-Meteo's TLS geocoding and forecast endpoints.
It normalizes current cloud strata, precipitation, snow, wind, temperature,
humidity and daylight into a data-only snapshot. It owns no renderer node.

`DayNightDirector` remains the only absolute writer for the Environment,
exterior key and sky material. Live cloud cover adjusts the depth of the lower
cloud deck and horizon atmosphere while retaining the four authored Orison
panoramas. `WeatherFX` remains the owner of precipitation, mist and wind.

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

The same normalized total-cover fact also attenuates the one exterior
directional key and hard-ray term. Clear transmits `1.0`; a closed report keeps
`0.12` as diffuse-through-cloud directional shape. Ambient Environment fill is
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

## Verification

`LiveWeatherServiceTest` proves Queens fallback, explicit text-only geocoding,
response rejection and normalization. `WeatherSkyTest` proves the production
sky and weather owners remain bounded after integration.
