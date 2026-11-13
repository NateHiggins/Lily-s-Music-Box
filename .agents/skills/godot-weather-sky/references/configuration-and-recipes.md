# Configuration grammar and useful recipes

First distinguish three kinds of configuration: existing production data,
supported QA adapters, and a proposed control/recipe. Never imply that a YAML
brief or arbitrary shader-uniform dictionary is already a loadable game preset.

## Existing production data

`game/data/weather/campaign_weather.json` uses `days[].frames[]`, not an
`anchors` property. Author 2..12 frames per day with whole local-day `minute`
values within `0..1439`, strictly increasing and with a first frame at zero.
The current validator checks finite numeric input but compares integer-coerced
minutes/formation; do not describe it as strict integer validation. Keep liquid
and frozen amounts nonnegative. Inspect
`CampaignWeather.valid_day()` for the complete current contract; its structural
validation is not a full physical or artistic range check. Preserve the dated
365-day narrative weather and newspaper/event consumers when editing frames.

`game/data/weather/living_sky.json` has ten genera `Ci,Cc,Cs,Ac,As,Ns,Sc,St,Cu,Cb`,
band indices `0..2` and positive `base_km`, `thickness_km`, `scale_km`,
`optical_depth`. Current validation requires exactly ten genera and fifty
numbered scenario rows. Rows carry genus, arrangement, label and eligibility;
they classify the weather-derived composition rather than supply fifty distinct
mesh/volume presets. Changing a scenario label alone cannot create a new cut of
cloud. Extending counts or arrangements requires deliberately updating the
loader/interpreter and meaningful tests together, not bypassing validation.

`phenomena.json` and its existing schedule own named spectacles and requirements.
Calendar events, provider facts and normalized coastal-storm strengths are
different inputs; do not infer an alert, tornado or new narrative event from a
free-text description. Use the actual enum/ID at each adapter.

## Existing QA grammar

- `WEATHER_SIMULATE` supports `clear`, `scattered`, `overcast`, `drizzle`, `rain`,
  `freezing_rain`, `storm`, `hail_storm`, `snow`, `snow_shower`, `fog`. These
  bypass network input through the existing normalization path; no preset named
  `sleet` or `dust` is implied. Read `SIMULATION_PRESETS` before using a name.
- `WEATHER_SIMULATE_CLOUD_LOW`, `_MID`, `_HIGH`, `_TOTAL` accept fractions
  `0..1`. Omitted total is derived from the maximum overridden strata, not their
  sum. Set all three strata explicitly for a high-only or mid-only comparison.
- `WEATHER_SIMULATE_TEMPERATURE_C` is currently clamped to `-50..55` Celsius;
  `_HUMIDITY` to `0..100` percent, `_WIND_KMH` to `0..120`, and
  `_WIND_DEGREES` wraps through 360 degrees. These adapter limits are not a new
  universal shader tuning range.
- `WEATHER_SEED` controls the existing reproducible presentation path. Keep it
  fixed for comparisons and record the actual resolved value.
- `WEATHER_FORMATION` uses `asperitas`, `fluctus`, `lenticular`, `nacreous` in the
  Queens extension. Its threat/cyclone gates still apply. These names differ
  from spectacle IDs such as `kelvin_helmholtz` or `halo_22`.
- `WEATHER_PHENOMENON=<existing_id>` and
  `WeatherManager.force_phenomenon(id, level, bearing_degrees)` are explicit QA
  forcing. Clear them after the case. A forced manifestation does not prove its
  natural eligibility or dated publication. `set_extreme_event()` currently
  accepts only `hail`, `tornado`, `cyclone`, `severe_storm_threat`, finite numeric
  strengths `0..1`; it is not a general event/formation dictionary.
- `DAYNIGHT_FORCE` and `WEATHER_SKY_BASELINE` change the test mode. Forced hours
  can retain showcase direction instead of production ephemeris; they cannot
  qualify ordinary astronomical motion. Snapshot and restore environment flags
  in the enclosing process so one review cannot contaminate the next.

## Extensible authoring brief

Use this vocabulary to make a requested change concrete. It is a review grammar,
not an implemented serialization format or permission to add another config
system:

```text
intent: defect or target appearance, intended viewing distance
clock: existing source, civil date/time, observer, forward/pause/reverse/seek
weather: authored/simulated/opt-in observed, exact preset or normalized facts
clouds: strata, genus/arrangement, physical size and optical-depth owner
events: existing eligible ID or explicitly labelled forced diagnostic
optics: source direction/phase, extinction, wetness/fog/lamp boundaries
quality: actual renderer, half/full pass, TAA/upscale, radiance and sample policy
evidence: fixed views, temporal samples, controls, performance route and gaps
```

For an actual new runtime control, define typed/unit-bearing fields at the
existing appropriate owner, finite/clamped validation, defaults and migration
behavior where relevant. Bind it once and expose its resolved value to review.
Keep unknown fields explicit errors or supported extensions, not silent knobs
that no consumer reads. Do not duplicate shader defaults in three independent
presets or make artistic QA flags persist in ordinary saves.

## Recipe families and discriminating witnesses

| Family | Build through the actual owner | Witness that distinguishes the intended effect |
|---|---|---|
| Clear/fair weather | `clear`, then controlled strata/coverage with fixed date/seed | Literally empty clear sky; scattered holes; readable daytime gradient and horizon without a residual overcast veil. |
| Dry overcast and layered cloud | `overcast`; compare separate low/mid/high inputs and mixed union | Closed low ceiling versus translucent high veil; underside depth/scale; softened sunlight without invented rain or street fog. |
| Liquid/frozen precipitation | Drizzle/rain/freezing-rain/storm/snow/snow-shower/hail presets; supported provider mapping for mixed/sleet cases | Different occupancy/optics and storm eligibility, consistent wind, actual shelter/indoor emission suppression. Freezing rain remains liquid; snow is not recolored rain; sleet/hail stay distinct. |
| Ground fog/haze | Fog input and humidity through the existing weather/director/air owners | Dry overcast does not manufacture ground mist; fog closes real street range without bleaching the Sun or leaking through every interior. |
| Dust/coal haze | Actual authored dust conditions or existing `haboob` diagnostic | Street visibility and sepia extinction agree with the owner; dust is not a generic gray cloud-cover increase. Clear the event and verify restoration. |
| Rare cloud forms | Existing formation selector or named spectacle, with gates recorded | Recognizable scale and shape at horizon/zenith; no abrupt midnight reroll, repeated radial bands or residual formation after the event. |
| Day/night and Moon | Campaign date/observer through director/ephemeris, including narrow telescope views | Sun/Moon direction and phase, sky visibility, source/key agreement, cloud extinction and current ruled Moon growth/name; forced hour is a separate case. |
| Halos/rainbows/lightning | Eligible existing phenomenon and real optical/lightning owner; force only for isolated diagnosis | Angular/source-relative location, cloud/ice/wet requirements, occlusion and rise/decay; no always-on flash or nonstorm inherited thunder. |
| Authored unusual fallout | Existing dated/seeded calendar fallout and deposition owner | Correct eligibility and elapsed accumulation, seek/reverse/rebuild behavior, and no deposition from a render-only prologue preview. A sky review cannot invent new canon. |
| Prologue annual traversal | Existing temporal sky projection and clock handoff | Continuous bounded seasonal traversal, sampled host month/day/time mapped into the historical annual loop, no intervening-day simulation, no extra weather/world mutations. |

Recipes specify coupled appearance, not just a color. Keep astronomy, cloud
transmittance, air, key light, precipitation and surface response coherent while
preserving their distinct owners. Use measured artistic examples to tune new
controls; do not hard-code one attractive frame as the answer for every season.
