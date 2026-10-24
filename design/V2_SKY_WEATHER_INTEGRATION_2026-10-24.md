# V2 seasonal sky and road-end weather retirement

Evidence class: **INERT**. Integration and cinematic art-review notes only.
No full-world performance qualification, played access, runtime-contract grant
or human acceptance is claimed.

The owner requested installation of the Parts2/3 sky prototype, removal of the
placeholder overpass/fog screens at both road ends, and dramatic example renders.

## Installed candidate

- The existing V2 atmosphere selects **queens_weather_sky.gdshader** and keeps
  its incremental128 radiance, celestial ephemeris, moon, star catalogue and
  approved panoramas. **WEATHER_SKY_BASELINE=1** retains the previous sky and
  precipitation backend for later matched-route measurement.
- The existing **WeatherManager** owns the extension and its interpolation.
  There is no additional HTTP request, campaign clock or save authority. The
  provider retains its explicit condition ID and pressure through presentation.
  Explicit OpenWeather precipitation IDs supply a nominal intensity when the
  optional1h amount is missing; WMO zero-observation behavior remains unchanged.
  Coastal events accept validated numeric strengths through **set_extreme_event**.
- **DayNightDirector** remains the absolute light/environment writer. Its V2
  profile applies the low-sun green gate, storm desaturation, wet ambient response
  and whiteout range. The carried-lamp owner observes the independent outdoor
  fog requirement rather than disabling it when the lamp is off.
- The existing V2 particle owner prepares four reusable GPU emitters. Its
  Forward+ path does not also construct the former CPU snow/hail and rain/mist
  draws. Compatibility and the explicit baseline retain their original backend.
  The existing cover query gates precipitation, sampled at10Hz. Sky motion and
  extreme-state uniforms publish at most10Hz.
- Outdoor fog occupies the actual road corridor,120m by9.144m and28m tall,
  transformed through the registered street boundary frame. It is not a camera
  cube overlapping occupied rooms. Its moving noise band is centered18m above
  the street. Storms request96m froxel reach; lamp-only operation keeps12m.
- The global **wetness** drives the sky and exposed layered asphalt/sidewalk
  surfaces. It preserves their PBR maps and changes albedo, roughness and specular.
  This does not qualify every StandardMaterial exterior surface or side-correct
  glass moisture; the existing glass authority remains separate.
- The V2 street-end detail subclass retains the real pavement works and eastern
  dogleg. It creates no road-end fog cards, gantry posts/crossbeam or matching
  invisible road collision. V1's retained detail builder is unchanged.

## Actual-world review

The first capture startup fails because the new wetness hook references a local
material key before its declaration. Original **sky_integration_v1** logs and
wrapper receipt remain preserved externally; this is a real parse error, not the
wrapper's generic stale-cache suspicion. Move the hook below the declaration.
Two subsequent imports complete, and **sky_integration_v2** captures five states
with empty stderr and a failed-check list of zero. Its street composition hides
too much sky to serve as a useful showcase.

**sky_integration_v3** uses an explicitly stationary cinematic station25m above
the street. Its five1280x720 captures, original diagnostic JSON, wrapper and
compressed logs are preserved in **art/reviews/v2_sky_weather_20261024/**. The
windowed run completes in145seconds with empty stderr and no failed checks.
The actual production world, lighting, materials, camera and renderer are used;
the weather states and viewpoints are authored review inputs, not observed API
occurrence or evidence of player access to the camera station.

| Location | Reproduction | Severity / evidence | Repair and verification |
|---|---|---|---|
| Both road mouths | Inspect the old fog/gantry locations | Visible placeholder and invisible road collision | No storm-card draws or road collision spans enter V2; independent road-mouth rays are clear and downward rays find retained grade beyond both former boundaries. Actual walking beyond them remains unverified. |
| Funnel | View a low-sun tornado | Original isolated prototype glows like a white rope | Shorter self-shadow taps and additional core extinction darken the funnel. The viewed actual-world capture shows it behind the skyline. Lighting and silhouette still need refinement. |
| Lenticular and asperitas | View the authored fair-weather states | Formation selectors are active but visual distinction is insufficient | Lens spacing/softness and bounds were adjusted; the images were reviewed. Stacked lenses remain obscured in this composition and asperitas lacks the desired dramatic underside definition. Neither formation is visually accepted. |
| Nacreous twilight | Set the real campaign ephemeris just below the horizon | Pastel high wisps are subtle against bright lower clouds | High-layer strength increased. The reviewed image remains a twilight-cloud example; it is not proof of a convincing mother-of-pearl formation. |

## Verification boundary and next work

Reader audit: zero NEW unread fields. Spatial audit: clean, no new failing or
changed classifications. A focused rerun of the authored-shader invalidation
sentinel passes after import completes; its prior full-board failure is retained
and no clean full-board verdict is substituted for it.

The earlier integration batch stops at its first import's180second ceiling and
runs no gameplay suites. A long-lane import subsequently completes in175seconds,
followed by a second complete import. Original timeout and failed outputs are
not replaced. Imported sidecar normalization still needs named-path review.

The captures are appearance diagnostics. Actual movement/turning/transition
frame distributions, a matched baseline comparison, API/particle regression
checks, full surface renewal and the final candidate verifier remain pending.
No performance improvement or complete seasonal-weather acceptance is claimed.
Continue refining the rare formations and closing the existing V2 repair queue.

The first **LiveWeatherServiceTest** completes with one failed source-template
check while its functional weather cases pass. Its source string comparison does
not normalize Windows CRLF. Normalize only line endings before the same checks;
retain the original failed run. Add explicit pressure/provider-ID, missing-amount
heavy snow, freezing rain and malformed-pressure refusal cases. A fresh result
is required before claiming this service suite passes; no network is needed.

The corrected service run now completes PASS with empty stderr, retaining all
previous checks and the four new provider cases. Its separate original wrapper
and logs are archived beside the images. This does not promote a rendered review
or source-template check into an interaction or runtime contract.
