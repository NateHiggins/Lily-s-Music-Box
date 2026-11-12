# Verification matrix, cost and authority guards

Choose the smallest cases that expose the changed mechanism. Source inventory,
compilation, rendering, behavior, performance and owner artistic approval are
different evidence. Keep failed runs and scope limits; no count of presets or
uniforms establishes complete configuration coverage.

## Record and freeze inputs

Record the actual loaded shader and include hashes, effective uniform values,
owner scripts/data, engine build/renderer, date/observer/seed, weather source and
normalized snapshot. Include camera/viewport, exposure/tonemapping, TAA/upscale,
sky pass/radiance settings, debug flags, warm-up and relevant GPU contention.
Record authored/provider values separately where a conversion is under test.
Bind the test/scene/dependencies and production inputs using existing receipt
and signature owners; a manually written wrapper JSON cannot grant runtime proof.

Inspect setters as well as declarations, including dynamic `sky_parameters()`
bindings and overridden defaults. A CPU inventory is useful for identifying
dead/unbound controls and hard parameters, but cannot establish what rendered.
Do not infer GPU samples, Inspector ranges, valid combinations or performance
from a static uniform list. Update source-bound evidence when changed code/data
affects its claim; reuse equivalent unchanged legs rather than rebuilding every
gallery.

## Matrix for the changed scope

| Axis | Relevant cases and failure checks |
|---|---|
| Weather morphology | Clear, broken, dry low overcast, mid-only, high-only and multi-level; a high veil must not become low stratus. Check scale, continuity, density, horizon/zenith and cloud-shadow/source consistency. |
| Hydrometeors/air | Dry, drizzle, steady/heavy rain, freezing rain, snow/shower, hail and supported mixed/sleet; separate fog/humidity/dust. Cover transitions and indoor/outdoor branches must suppress only their proper emissions. |
| Illumination | Dawn/noon/dusk/night, low Sun back-light/side-light, crescent/quarter/full/daytime Moon where relevant. Include true campaign-time cases, not only forced showcases; check stars and bodies behind opaque cloud. |
| Motion | Still versus moving camera, cardinal winds and calm, normal traversal and large seeks, pause/return/reverse and rebuilt world. Check field drift direction, seeds, float precision, seams, ghosting and temporal popping. Distinguish calendar-pure sky/astronomy from existing live/physical particle animation. |
| Time boundaries | Midnight, adjacent calendar frames, weather-source transition, seasonal shoulder, campaign-year wrap and distant-date prologue traversal. Labels may change; geometry must not reroll merely to satisfy diversity. |
| Optical/rare events | Eligible versus deliberately ineligible case; before/during/after. Clear forced state and verify restoration. Keep the one ruled eclipse separate from routine Sun/Moon crossings; preserve flash accessibility. |
| Camera/composition | Actual street/roof/aperture view and narrow telescope where affected, with sufficient sky coverage to inspect the subject. Record declared starting placement/cinematic camera; it does not prove a walked route or telescope input. |
| Lifecycle | Second world, reload, retired owner/resources, restored TAA/global wetness and event flags. Keep source selection and network/location preference unchanged by a diagnostic. |
| Quality/renderer | Target Forward+ settings and any explicitly supported baseline/Compatibility comparison. Different implementations need their own qualification; do not assume the baseline proves Queens or the reverse. |

For a coupled change, include a control that can expose the failure: wrong wind
direction, missing/mismatched field binder, forced dry/nonstorm transition after
lightning, a high-only deck, or an unchanged baseline image. Keep negative
controls local to the diagnostic and visibly labelled; never weaken production
gates or hide a failure with arbitrary exposure/fog reduction.

## Existing starting points

Inspect current tests and their assertions before reusing them. Available paths
include `CampaignWeatherTest.tscn`, `CampaignWeatherWorldReview.tscn`,
`LiveWeatherServiceTest.tscn`, `CelestialEphemerisTest.tscn`,
`SkyPhenomenaScheduleTest.tscn`, `V2QueensSpectacleBench.tscn`,
`WeatherFlashAccessibilityTest.tscn` and `PrologueTemporalSkyReview.tscn` under
`game/tests/`. These are different scopes, not a mandatory expensive suite list.
An older reference naming another test is not proof that it still exists.

For shared wetness/fallout retirement specifically, use
`WeatherGlobalOwnershipTest.tscn` windowed. It renders global shader values
through a tiny isolated probe and retains real extension publication/manager
teardown; it does not load the city or establish PBR surface acceptance.

Check the programme's override policy before selecting a capture path.
`RoofWeatherPreview._build()` deliberately clears simulated weather, formation,
phenomenon, baseline and forced-hour flags: it reviews the authored calendar.
The spectacle bench's native-plan mode freezes its manager, and its date helper
does not automatically finish the 300-second live-weather transition. An
environment preset alone therefore does not prove the requested state reached
the captured frame. Inspect/assert the resolved manager source and normalized
current conditions, and explicitly settle a simulated transition in the isolated
fixture before freezing it. Never change campaign data or speed up a real save
to make a diagnostic appear settled.

Follow the existing Godot skill/lane for actual execution, hidden windows and
receipts. Confirm delivered viewport dimensions and inspect native frames and
motion; headless execution cannot qualify sky appearance. A gallery of forced
states does not prove calendar selection, authored event eligibility, telescope
controls, historical accuracy or a save/reload route.

## Measure the real cost

For ordinary cloud revisions, `V2SkySpectacleBench.tscn` supports layer-isolated
`SKY_BRUSH_REVIEW=1` and four-date `SKY_MOTION_REVIEW=1` reviews. Add
`SKY_CAMERA_MOTION_REVIEW=1` for a scripted pan with 28 frames; this is not native
mouse input, and sparse frames cannot exclude fast shimmer. Keep environment
modes mutually exclusive and compare source-bound shader/include stacks, not
an old top-level shader with today's includes.

`V2PrecipitationVisibilityProbe.tscn` uses the real player and V2WeatherFX with
TAA, camera motion and shelter/resumption in an isolated fixture. Its local
checks do not establish an occupied route, save reconstruction or emitter
retirement. In particular, cover currently hides the camera-centred field, so
outdoor particles through an opening still need separate presentation work.

`RoofWeatherPreviewTest.tscn` retains real roof input and restoration checks.
For sky optics obscured by passing residents, optional `ROOF_SKY_REVIEW=1`
raises only the camera four metres after those checks, records the offset and
restores its transform. Label these frames as elevated optical views, not the
normal player placement. Do not hide residents/buildings to claim a complete
composition. Inspect stderr even when all test assertions pass: missing imported
city geometry invalidates that composition. Use the existing autoload-aware
`CompileChangedScripts.tscn` for script preflights; a standalone `--check-only`
script invocation does not supply project autoload identifiers.

Compare the same occupied composition, camera, resolution, quality, weather/date
and warmed state. Report CPU/GPU/frame-time distributions and spikes where
available, cold shader/radiance/startup separately, and the cost of each affected
sky march, self-shadow sample, compositor, air/fog volume or precipitation draw.
Keep image encoding and unrelated jobs out of timed spans. Check temporal and
grazing quality before increasing samples or reducing resolution; do not trade
away the intended atmosphere based on an isolated average FPS.

Fast campaign traversal is its own workload. Measure whether a bounded seek
evaluates the destination/analytic transport rather than iterating every crossed
day or rebuilding assets each frame. Keep frame-time behavior separate from
wall-time cinematic encoding and gameplay budgets. Do not reset offsets, reduce
annual diversity or disable effects globally to disguise a precision/cost defect.

## Protected authorities and honest acceptance

The [Bible](../../../../design/ORISON_BIBLE.md) and
[prologue ledger](../../../../design/V2_PROLOGUE_2026-10-28.md) own the destination
and ending. Sample host local month/day/time once and map it within the modeled
November 1928 to November 1929 annual loop; never replace the campaign with the
modern host year. Preserve the existing leap-date mapping, fixed geographic
reference, monotonic deadlines, input/reload/skip and the exact protected ending.
Parametric sky preview must not simulate missing resident history, forecasts,
precipitation deposition, saves or every intervening day.

Weather appearance work adds no new campaign clock, location inference, live
request policy, event canon, authoritative light or independent weather roll.
Changes to those contracts need their actual owner and authorized scope. Keep
new normal-weather improvements distinct from the single dated spectacle ruling.

Close with the tested matrix cells and source-bound receipts, actual visible
result, performance limits and unverified combinations. Broad configurability
is an engineering interface with validation, not evidence that all its possible
outputs have already been rendered or accepted.


## Stable sampling and compact moving evidence

Fixed screen-space ray offsets can replace coherent bands with visible grain.
Use paired native views to distinguish that noise from resolved distant cloud
shapes. Finite primary footprints must not accidentally switch off the detail
path: keep sample role explicit. Two Gauss density samples can share midpoint
lighting, but measure their cost. A high plane needs projected pixel derivatives;
plain distance is not the same footprint, especially through a telescope.
Stretch fine cirrus fibres separately from their supporting packets. Never scale
an already wrapped phase by a noninteger frequency; publish that frequency's
phase independently or use an integer periodic transform.

For a short actual-city day/night film, use **V2DayNightFilm.tscn** and the bounded
CPU helper **tools/encode_sky_film.py**. Supply explicit Python/helper/ffmpeg paths
through SKY_FILM_PYTHON, SKY_FILM_ENCODER_RELAY and SKY_FILM_FFMPEG, a fresh SHOT_DIR,
and launch through the lane with --fixed-fps 48, a hidden native window and Vulkan.
The fixture streams 576 ready RGB frames at 24 fps, retains a few native stills,
and records sources, every date/pose and restoration assertions. Godot consumes
recognized engine flags; validate actual process delta instead of expecting those
flags in OS.get_cmdline_args(). Require complete decode, exact dimensions/duration,
two renderer steps per output, bounded child cleanup and native/moving review.
Its detached day_info epoch seed belongs only to the preview copy. Keep elevated
optical placement, frozen agenda and inherited HUD/companion hiding explicit;
a time-lapse does not establish played routes or real-time frame rate.
