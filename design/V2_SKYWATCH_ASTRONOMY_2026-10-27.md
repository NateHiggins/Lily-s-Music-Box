# Skywatcher Club: Moon, historical sky and telescope

Evidence class: **INERT**. Owner-directed V2 work and implementation log;
not runtime qualification or artistic acceptance.

## Order and preserved baseline

The owner requests Parts 6–8 of the astronomical brief next, integrated with
the previously requested relief Moon and rooftop Skywatcher Club. This belongs
in V2 after weather, as recorded in
[the larger game goal](THE_YEAR_YOU_DIED_POST_V2_2026-10-26.md).

Weather PR #66 merged at **0b51a9f0**. Its candidate **3a0c0096** passed the
114-gate comparison against clean main **e2760631**, zero regressions and no
waivers, 17/17 protected paths unchanged, V2 selector, zero design-lint errors.
The verifier used **--no-godot**; separately executed source-bound runtime,
save/load, surface and annual-night evidence remains in the
[weather ledger](V2_SKY_WEATHER_INTEGRATION_2026-10-24.md). The verifier does
not establish fresh-checkout imports, whole-year artistic acceptance or closure
of first-view stalls. Those limitations survive this merge.

## Required result

- A usable brass refractor in a rooftop club for astronomy, weather and alien
  watching; barbecue, seating, serving space and unobstructed service access.
  Inspect the actual roof before choosing locations. Use the native Blender,
  custom PBR, metric UV and loaded-mipmap workflow.
- An enlarged Moon with measured relief, lunar phase geometry and terrain
  shadows under grazing sunlight, including identifiable Tycho/Copernicus
  regions. Keep expensive fine terrain work local to its visible projection
  and telescope viewing. The inherited spherical albedo disc is insufficient.
- Deterministic observer-relative Mercury, Venus, Mars, Jupiter and Saturn.
  Vibrant enlarged discs, Jupiter bands, Saturn's luminous rings and stronger
  near-horizon shimmer are deliberate art direction, not physical angular size.
  Buildings, clouds and weather must occlude them.
- A real optical equivalent of 0.5–0.1 degree telescope fields, brass aperture,
  stable geared aiming, interruptible entry/exit and correct focus ownership.
  Godot 4.7.1 Camera3D rejects FOV below one degree; use a correctly sized
  frustum rather than silently clamping requested magnification.
- Magnified Jupiter turbulence, two belts, rotating Great Red Spot, Galilean
  satellites and shadow transits; Saturn's A/B/C rings, Cassini division,
  measured ring orientation and mutual shadows; Mars albedo, seasonal caps and
  phase; Venus phases and cream atmosphere. Do not present arbitrary orbit
  phases or an unverified ring tilt as historical ephemerides.
- Bounded weather-driven atmospheric seeing, restrained refractor colour
  fringes, eyepiece dust/oil/vignette and radial softness. Optical effects must
  preserve detail and legibility. Compare costs at identical settings.
- Deterministic Leonids with the Leo radiant, green/white/blue/orange palette,
  occasional slower persistent fireballs and a bounded rooftop flash respecting
  flashing accessibility. Use the campaign timestamp, not accumulated spawning
  history, so reverse travel/reload returns the same sky.
- Historically located eclipse events and a moving soft penumbral shadow,
  without a red lunar-eclipse disc. No naked-eye comets invented for this year.
  Newspaper and dialogue access remain with existing dated reading owners.

The supplied attachment is Part 8, the telescopic optics brief; it supplements
the inline Parts 6 and 7. It is recorded here so its extra requirements are not
lost by treating it as a duplicate attachment.

## Research corrections and numerical limits

NASA's [solar table](https://eclipse.gsfc.nasa.gov/SEdecade/SEdecade1921.html)
places greatest eclipse on May 9 and November 1, 1929. Neither visibility region
includes New York. Do not occult or dim the Queens Sun because an eclipse occurs
elsewhere. The campaign also includes the November 12, 1928 partial solar
eclipse, likewise outside New York's visibility region. Historical reporting
may acknowledge remote events through its normal publication authority.

NASA's [lunar catalogue](https://eclipse.gsfc.nasa.gov/LEcat5/LE1901-2000.html)
identifies May 23, 1929 as penumbral, greatest eclipse **12:37:45 TD**, with
273.7 minutes of penumbral duration. TD is not UTC. Contact times and local
Moon altitude must be verified before enabling a visible shadow in Queens;
the catalogue does not license inventing a locally visible night-time eclipse.
Its [May plot](https://eclipse.gsfc.nasa.gov/LEplot/LEplot1901/LE1929May23N.pdf)
gives P1 **10:20:29 UT**, maximum **12:37:20.7 UT** and P4 **14:54:10 UT**.
The catalogue also includes a **November 27, 1928 total lunar eclipse**, omitted
from the supplied brief. Its
[plot](https://eclipse.gsfc.nasa.gov/LEplot/LEplot1901/LE1928Nov27T.pdf)
gives P1 **06:27:00 UT**, U1 **07:24:18**, U2 **08:33:59**, maximum
**09:01:22.6**, U3 **09:28:46**, U4 **10:38:28**, P4 **11:35:45**.
Credit: Eclipse Predictions by Fred Espenak, NASA's GSFC.

[JPL's compact elements](https://ssd.jpl.nasa.gov/planets/approx_pos.html)
cover 1800–2050, but list nominal outer-planet heliocentric longitude errors
of hundreds of arcseconds. They suit a stylized wide sky; they do not establish
precise 0.1-degree pointing or authentic Galilean shadow-transit timing.
Independent Horizons samples test the approximation rather than repeating its
formula. Use a bounded higher-accuracy solution for genuinely historical
telescopic events. Precess J2000 vectors to the date before applying local
mean sidereal time; don't mix those frames.

NASA's [meteor summary](https://ntrs.nasa.gov/api/citations/20200000049/downloads/20200000049.pdf)
lists enhanced Leonid activity in 1928 at about 50 per hour. The supplied
74/20/1/1 colour percentages total 96%; its requested random thresholds instead
assign 3% each to blue and orange. Until a primary historical observation
supports those colour fractions, describe them as the requested artistic
palette, not a measured 1928 distribution. The
[Australian Bureau of Meteorology](https://www.sws.bom.gov.au/Educational/4/1/5)
provides the nominal radiant. Use a precessed reference radiant, not an
invented fixed local direction.

NASA SVS's [CGI Moon kit](https://svs.gsfc.nasa.gov/4720/) supplies measured
LOLA displacement and normalized LROC albedo, not a reference photograph baked
onto a manufactured prop. Credit NASA Scientific Visualization Studio / Ernie
Wright, the LRO LOLA and LROC teams. Source URLs and hashes are in
**art/reviews/skywatch_20261027/moon_sources.json**. The packed linear two-byte
height map must remain lossless: block compression corrupts its half-metre
encoding. Albedo uses high-quality GPU compression; both require loaded mips.

## Issue log

| Location / reproduction | Severity / evidence | Repair / verification |
|---|---|---|
| Existing Moon, magnified view | Major visual: smooth sphere with 1k albedo, no terrain shadows | Measured heightfield lighting and bounded spherical shadow search rendered; 0.1-degree detail remains too soft for final telescope acceptance |
| Night sky, five planets | Missing requested feature | Pure JPL approximation and sky-composited procedural discs rendered; 20 independent reference comparisons passed |
| Telescope field below 1 degree | Engine API limit confirmed in pinned 4.7.1 Camera3D source | Frustum-based optical review; installed aiming/focus route pending |
| Roof club, telescope and barbecue | Requested V2 content absent | Roof survey and Blender batch pending; no installed acceptance claimed |
| Magnified Moon halo / dark side | Broad additive halo flattened contrast; stars survived over the unlit hemisphere | Restrained halo, solid Moon occultation, bounded albedo sampling; rendered control pair inspected |
| Planet phase / magnified Jupiter | Earth-relative illumination made Saturn half-lit; band pigment leaked into halo | Planet-relative Sun vectors, consistent retarded geometry and unbanded glow; original failed phase checks retained, all five pass after repair |

## Executed foundation checkpoint, not completion

The production V2 atmosphere now loads the 4k albedo and packed LOLA terrain.
The existing V2 director publishes the five planets and two dated lunar eclipse
tracks from its CampaignClock. Sky projections add no meshes, lights or particle
emitters. The Moon's apparent radius is artistically enlarged 2.5 times; terrain
height is exaggerated 2.5 times. Sixteen bounded terrain samples test shadowing
only within its visible disc. This is heightfield shading/self-shadowing, not
the completed Blender relief model, libration or final telescope terrain.

Eclipse tracks fit NASA's contact duration, closest separation and angular
radii in a tangent plane. Their track angles are approximate diagram fits;
do not call them exact Besselian elements or precise crater-contact predictions.
Only umbral immersion turns copper. The May penumbra stays grey/brown; its
below-horizon maximum does not dim the Queens world. The actual November total
eclipse now renders, and the director attenuates its lunar key without replacing
the surface shadow with a blanket light fade. Solar eclipses elsewhere produce
no local occultation or fake global dimming.

**C:/ov/reports/skywatch33/optical_qualified_diagnostic.log.receipt.json**:
42 diagnostic assertions passed (43 PASS log lines including the result), native 3440x1440 fullscreen, patched Vulkan
Forward+, RTX 4080, empty stderr, approximately 11 seconds. This bench uses
the production sky, existing director and campaign clock, but deliberately
clears weather for optical comparison. It is not an occupied rooftop input,
collision, save/load or schema-2 runtime-contract qualification.

Twenty Horizons ICRF comparisons span four campaign instants for each planet.
Largest observed angular error is Jupiter, **0.10936 degrees**; inner-planet
errors stay below **0.0072 degrees** in these samples. They are sparse checks,
not a proven annual maximum. Five additional phase checks compare the same
retarded planet-to-Sun/observer geometry used by rendering. Actual visible
night instants were selected for five planet captures. The rings and surface
details are preliminary wide-sky designs, not the Part 8 telescope rendering.

Both new optical maps passed loaded mip checks. The imported height remains
linear lossless packed data; albedo uses BPTC/ASTC high-quality compression.
Full-resolution optical controls and frame samples remain external. The compact
review package retains hashes, receipts, logs, numerical samples and contact
images, including the initial parser/shader failure and later failed phase
checks. Those failures are not reclassified as passes.

The original **CelestialEphemerisTest** and **WeatherSkyTest** also passed
through the lane. WeatherSkyTest explicitly mounts V1; it protects rollback
and does not qualify the new V2 presentation. Its original stderr contains
legacy wall-placement warnings and is retained. The period-date audit passes;
the data-consumption audit reports **zero NEW unread fields**.

Native uncapped clear-bench timing compares 120 frames per relief setting at
78-degree and 0.1-degree fields. The 0.1-degree terrain view adds roughly
0.4–0.6 ms median across the observed optical controls. This is not isolated GPU
attribution or a playable-world performance result. Earlier 20 ms-capped samples
and a sample overlapping import-cache housekeeping are retained as diagnostics,
not presented as an optimization result. Do not compare their averages to the
occupied weather route or claim that V2 stutter is resolved.

Still required: actual roof survey and native club/telescope/BBQ stock; direct
entry, geared aiming, zoom, interruption and exit input; sharper regional lunar
terrain, relief geometry and orientation; Galilean ephemerides/transits and
historical ring orientation; the Leonid renderer and fireballs; magnified
planet optics and weather seeing; occupied-world occlusion/performance and
runtime qualification; full candidate gates and human artistic judgment.

This work does not change campaign, inventory, work-order, resident, quest,
reading or save authorities. Club flavour must preserve the established alien
premise without inventing communication, decoded clues or story revelations.
