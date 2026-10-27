# Skywatcher Club: Moon, historical sky and telescope

Evidence class: **INERT**. Owner-directed V2 work and implementation log;
not runtime qualification or artistic acceptance.

## Order and preserved baseline

The owner requests Parts 6–9 of the astronomical brief next, integrated with
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
- Part 9: replace V2's photographic stellar points with analytical catalogue
  points and faint fixed celestial hash cells; spectral colour, magnitude HDR,
  independent weather/airmass scintillation, sharp 0.1-degree optics and Airy
  rings. Bake BSC5 offline, preserve proper motion and precession, avoid a
  per-pixel whole-catalogue scan, and keep weather/building occlusion.

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

## Part 9: analytical stellar presentation

The new V2 sky replaces enlarged photographic star texels and the twelve old
expanded catalogue markers with analytical point-spread functions. Celestial
cells remain fixed when zoom changes; pixel derivatives control the footprint.
The actual camera projection supplies its vertical field, including frustum
fields below Camera3D's one-degree perspective limit. Bright telescopic sources
use a circular-aperture Airy profile based on the
[Bessel series](https://dlmf.nist.gov/10.2.E2) and
[asymptotic expansion](https://dlmf.nist.gov/10.17.E3).
The weak four-point spikes are the owner's artistic addition; a clean circular
refractor aperture does not inherently produce four diffraction spikes.

The [CDS/VizieR BSC5 ReadMe](https://vizier.cfa.harvard.edu/vizier/ftp/cats/v/50/ReadMe)
defines the fixed-width input, missing records and projected RA proper motion.
Credit Hoffleit and Warren (1991), NASA NSSDC/ADC and CDS/VizieR V/50. The
authoring source and retrieval hash are in **art/data/astronomy/**. Runtime
loads three compact native data textures; it performs no download or text
parsing. All 9,096 stellar records survive; fourteen retained non-stellar
records are skipped. For 310 missing B–V measurements, spectral class supplies
an explicitly approximate colour, including historical luminosity prefixes.

Raw global RA in RGBAH lost up to **805.66 arcseconds**, exceeding the entire
0.1-degree field. The authoritative packing therefore uses RGBAF coordinates
and RGBAH photometry/proper-motion metadata. Measured extra RA quantization in
RGBAF is at most **0.04918 arcsecond**. This is encoding error, not total
astrometric accuracy: catalogue precision, linear proper-motion propagation,
precession and omitted parallax/nutation have their own limitations. The
provided GDScript also exposes raw RA/Dec/magnitude/B–V texture packing, with
the half-float variant retained to demonstrate its precision failure.

GPU lookup uses 64-by-64 cells on six celestial cube faces. Each direction
looks up its bucket and nearby boundary buckets, with duplicate removal at
face seams. The actual maximum is **11 records per bucket**, not a scan of
9,096 entries at each pixel. The sparse 3D hash background uses fixed celestial
cells and a Galactic latitude weighting; these faint illustrative stars are
not asserted to be measured BSC records. Neither type can create story evidence.
The V2 director rotates the J2000 basis with date precession and observer
sidereal geometry. V1/Compatibility retain their original presentation.

Magnitude maps through **10^(-0.4*(m-1))** into HDR radiance; spectral colour is
an artistic B–V ramp. Scintillation combines per-star phases/frequencies,
brightness, colour, horizon airmass and weather turbulence. Its bounded clock
comes from CampaignClock fractions, not shader TIME or a second simulation.
Integer cycle counts and modular phase arithmetic preserve continuity at the
4096-second precision wrap. Pause/reload/rewind use that same time source;
installed-world pause/reload qualification is still required.

The cloud test exposed a real bright-point leak through the raymarch's early
opacity termination. The repair separates stellar radiance until compositing
and smoothly suppresses its tiny residual transmission near an opaque ceiling,
using the existing cloud alpha. No second cloud scan or render pass was added.
High ice, cirrus, the Moon, foreground geometry and height haze keep their
occlusion roles. Source-bound original failed runs are retained.

An initial wrap test compared maximum pixel differences in Airy rings. Even
after settling TAA, a roughly **0.016-pixel centroid shift** produced a larger
peak difference while the measured integrated, linearized displayed light
changed only **0.074%** across the two-millisecond boundary. The corrected
continuity test measures integrated light; it also records peak differences.
The original failed criterion, captures and logs remain diagnostics, not passes.

The catalogue bake passed eleven assertions (twelve PASS log lines including
its result) through the lane, including all bucket ranges, the half-float
precision control, a historical-prefix colour regression and native saving.
Native wide/one-degree/0.1-degree optical controls show sharp Sirius and its
rings, changing scintillation and disappearance behind the production
nimbostratus brush and an opaque world mesh. These are optical diagnostics,
not a completed rooftop telescope interaction or human acceptance.

Current-source lane receipts:

- **catalogue_prefix_repair.log.receipt.json**: eleven bake assertions pass.
- **astronomy_with_analytical_stars.log.receipt.json**: all 42 original
  astronomy/optical assertions still pass, empty stderr.
- **stars_final_source.log.receipt.json**: eight optical assertions pass,
  empty stderr; native 3440x1440 fullscreen. Clear-star peak contribution
  **0.83137** in displayed RGB; the complete production nimbostratus and
  opaque-world controls both reduce the measured contribution to **zero**.
  Integrated displayed-light change at the wrap is **0.0691%** in this run;
  the separately retained peak-pixel difference is **0.04314**.
- **ephemeris_star_shared_regression.log.receipt.json** and
  **weather_sky_star_shared_regression.log.receipt.json**: original suites
  pass after the shared WeatherManager presentation hook. The V1 test retains
  its legacy wall-placement stderr warnings; it is not new V2 acceptance.

These receipts and full-resolution images live under
**C:/ov/reports/skywatch33/**. Compact durable copies, tested source, hashes,
raw distributions and contact views extend the existing review archive.
The first shader/parser failures, failed cloud controls and failed peak-pixel
wrap controls remain available with their original results.

Uncapped native controls record all 120 frame times per setting. In the
observed 78-degree clear bench, catalogue plus faint stars add approximately
**0.4–0.5 ms median** over the current cheap no-catalogue underlay. That control
is not a matched comparison against the former photographic sky or an occupied
route, and does not resolve the known whole-world stutter. Retain distribution,
hardware and source context when comparing later results.

This work does not change campaign, inventory, work-order, resident, quest,
reading or save authorities. Club flavour must preserve the established alien
premise without inventing communication, decoded clues or story revelations.

### Fractional-clock telescope correction

The retained director updates world lighting every eight seconds. A frozen
optical bench concealed the resulting jump at extreme magnification. V2 now
publishes stellar orientation from the existing campaign clock's fractional
seconds every frame. Narrow telescope fields also refresh orbital projection;
the whole lighting/fog/weather pipeline retains its existing cadence. The
temporary shared WeatherManager hook is removed: that file again matches main.

**stars_fractional_clock.log.receipt.json** completed fullscreen 3440x1440
with ten assertions passing (eleven PASS lines including the result), empty
stderr. Nine rendered Sirius centroids over 0.4 campaign seconds advance
continuously by about 22.8 pixels, with each 0.05-second increment moving
approximately 2.7–2.9 pixels. The narrow-field director calls took 247–376
microseconds in this diagnostic, not an occupied-world CPU budget. Cloud and
world controls still extinguish the measured star signal; wrap-integrated
displayed light changes by 0.109%. Raw samples, logs and tested source are
appended to the diagnostic archive, preserving earlier failures.

The initial complete static board at **bd2d307a** found only the expected
surface-qualification invalidation: rendering inputs changed and the old
rendered review is stale. These are two open defects, not waived passes.
The other gates did not regress against the unchanged merged weather tree.

### Composed-world surface renewal

The two stale-evidence defects above were resolved by a fresh source-frozen
production-world run, not repinned old receipts. At code checkpoint
**1b0b5997**, **surface_astronomy.log.receipt.json** completed in 843 seconds
on the patched Vulkan engine, native fullscreen 3440x1440. The test-written
schema-2 runtime contract reports **39,165 checks, zero failures**, including
production composition, loaded surface requirements and teardown. Shutdown
stderr is empty. The inventory contains **27,810 draws, 6,303 materials and
527 textures**. Seven actual composed images were inspected and published
with image hashes; independent packet qualification passes with zero defects.

**ORISON_SURFACE_SKIP_FIRE_INTERACTION=1** explicitly excludes the unchanged
fire-service interaction programme. Its physical draws remain in the surface
inventory. Earlier fire-service evidence is retained; this run grants no new
hose-input, save/load or astronomical telescope interaction qualification.
The earlier stale board, all raw diagnostics and prior packet are preserved.
No annual artistic acceptance or whole-game completion follows from this pass.

### Roof discovery and native instrument authoring after PR #67

PR #67 merged the qualified astronomy foundation at **6ff8922f**. A new
roof survey mode reuses the existing clearance probe; it deliberately records
posed authoring data rather than admitting a played route. Patched Vulkan,
fullscreen 3440x1440 **roof_survey.log.receipt.json** completed in 145 seconds
with empty stderr. It records **2,961** half-metre standing-capsule samples,
**2,386 clear**, **2,857 supported**, and **911** bounded mesh records.
Coordinates are in the installed roof's actual rotated frame.

The northwestern telescope candidate at **(-11,6)** has a 3 m square of
49/49 clear samples. Its measured centre floor height is **19.2702503 m**;
nearby sloping floor heights vary and the tripod feet still require exact
installed fitting. The long table candidate is **(-7.5,9)**, the camp cooker
candidate **(-3.5,9.5)**. These are authoring placements, not accepted stock
footprints. Tank service, ventilators, bulkhead doors and the weather inspector
at **(3,-9)** remain reserved.

The native refractor is informed by the museum's
[Cooke instrument, 1897–1922](https://www.rmg.co.uk/collections/objects/rmgc-object-11096):
75 mm aperture, a long brass tube, wooden tripod, focusing wheel and supporting
brackets. The planned camp cooker is informed by the
[1922 folding camp-stove patent](https://patents.google.com/patent/US1438345A/en),
not a later suburban kettle grill. Both are adaptations; no replica or precise
historical ownership is asserted.

Blender now contains the telescope's hollow tube/cells, finder, drawtube,
packed saddle straps, fork journals, retaining boss, braced tripod and visible
two-axis worm drives. Actual rendered review exposed a faceted brass texture
mosaic. Continuous developed cylinder charts and the registered aged-brass
finish repair that defect. Submillimetre bevels use one segment. The initial
unguided stock was 70,728 triangles; the chart/bevel revision was 25,936, and
the subsequent real gear/hub details bring the current instrument to **42,436
triangles**, **238 closed construction pieces**, **10 runtime partitions** and
**22 material primitives**. This is a geometry count, not a measured runtime
speedup. Final exported UV/tangent validation passes, minimum tangent agreement
**0.99999975**. The initial missing-glass-recipe and studio-world failures remain
in the authoring logs. The clear dielectric reuses its existing registered finish.

Actual Blender whole/objective/mount renders and roof captures are indexed in
the compact rooftop contact/review archive. Raw evidence lives under
**C:/ov/reports/skywatch34/**. The telescope is **not installed or gameplay
qualified** at this authoring checkpoint. Exact foot contact, runtime materials,
moving part ownership, 0.1-degree eyepiece input, controller/cancel ownership,
save policy, party fittings and occupied-world costs remain open. Main's old
surface receipt does not qualify these new assets.
