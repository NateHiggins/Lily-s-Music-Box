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

### Part 10: painterly ice, twilight and growing airship trade

The owner adds ice-halo complexes, urban light pillars, twilight geometry,
mirages, aviation/industry and deep-night dust to this same V2 work. The owner
explicitly authorizes growing airship traffic as alternate history: atmosphere
and the rule of cool take priority over an exact historical traffic timetable.
This does not change the campaign clock, newspaper publication times or story
authorities. The historical October 15, 1928 Graf Zeppelin arrival precedes the
November 10 campaign start; it must not silently become a recurring historical
arrival during the playable year. The
[Smithsonian's transport exhibition](https://www.americanhistory.si.edu/explore/exhibitions/america-on-the-move/online/connected-city)
places the start of commercial transatlantic passenger service in October 1928;
the [FAI account](https://www.fai.org/news/ninety-years-first-round-world-airship-flight)
describes the external flight-deck/passenger gondola. Our liner is a fictional
168 m adaptation, not an exact Graf Zeppelin model or a sourced Queens 4 PM track.

The existing **41-slot** scheduled-phenomena ABI and authored weather calendar
remain intact. The V2 director derives ordinary cirrus ice and freezing-fog
strength from its existing live conditions. The retained seasonal renderer keeps
its old presentation. Extended V2 optics add a dispersed **46-degree** halo to
the existing 22-degree ring, select the Moon at night with phase-dependent gain,
give the dogs an outer blue fringe, and restrict source pillars to low elevations.
The antisolar civil-twilight pass adds a blue-violet Earth-shadow band and pink
Belt of Venus. Night radiance adds restrained green airglow, an equatorial-axis
ecliptic dust cone and Gegenschein, suppressed by daylight and an above-horizon
bright Moon. Existing cloud compositing and horizon haze still occlude these.
These are painterly approximations, not precision radiative-transfer solutions.

Actual native 3440x1440 paired controls are under **skywatch34/**.
**atmosphere_gated.log.receipt.json** completed with eight component assertions
passing and empty stderr. Enabled/disabled frame distributions for its one
clear solar optical scene were p50 **1.976/1.749 ms**, p95 **2.149/1.911 ms**,
p99 **2.164/1.929 ms**, maximum **2.205/1.935 ms**. These are uncapped RTX 4080
bench frames, not whole-world movement, shader-compilation attribution or an
annual performance budget. Earlier ungated and initial-source runs are retained.

The four installed street lamps' existing clock owner now attaches a slim
additive, depth-tested optical quad to each actual globe. No new light,
collider, shadow map or gameplay state is created. Freezing humidity enables
the effect; the existing dusk/dawn owner controls its colour and illumination.
V2 stops drawing the old hash-generated city-pillar bearings. The older renderer
retains them for rollback. The first blocker assertion erroneously sampled
unrelated twinkling stars outside its occluder. The actual covered beam footprint
had zero displayed difference. The corrected source-family diagnostic,
**atmosphere_sources_fixed.log.receipt.json**, passes twelve assertions with
empty stderr: actual signal, weather binding, daylight extinction and real
foreground depth protection included. This is not yet installed-street or
full-world surface qualification. The original failure remains archived.

The Blender liner has stitched envelope panels, ring stations, four fins with
separate control leaves, an external windowed gondola, five braced engine cars
and shared wooden propeller stock. Its 203 closed construction pieces export
as five material primitives and **24,860 triangles**; UV/tangent validation
passes at minimum tangent agreement **0.99999996**. Actual studio renders
include the assembled propellers. The first empty unused-material partition
failure is retained. Runtime materials reuse registered catalogue stock.

The V2 director installs the passive aircraft presentation. Four daily route
windows have deterministic date-keyed offsets; position, heading and propeller
angle derive directly from fractional campaign minutes. An out-of-order date
return reconstructs the same pose. Strong wind or substantial precipitation
holds the fictional service. Ordinary world depth and the existing celestial
light/shadow system apply; there is no depth-disabled aircraft or second sun.
The native optical bench proves visibility, continuity, pause, weather hold and
out-of-order reconstruction, not disk save/load or an occupied-world shadow.
The initial script type-inference failure required stopping only this owned
diagnostic process; its negative-exit receipt and stderr are retained. Its
wrapper's stale-cache suspicion was not the cause. A subsequent full-frame
occlusion check also included unrelated weather/sky pixels; the corrected
clear-scene check uses the actual projected stock bounds.

**airship_precision.log.receipt.json** completes with eight assertions passing,
empty stderr, after reimport with mesh compression disabled for metric/native
precision. The cached import's source MD5 matches the final GLB. Both new native
imports are source-retained; the physical-import-source gate now passes. The
final combined-source atmosphere run, **atmosphere_final.log.receipt.json**,
also passes twelve assertions with empty stderr. These remain component optics
diagnostics. The earlier post-rebuild captures using an older imported model
are preserved and do not qualify the refreshed source.

The initial full static board ran 114 gates against the previous clean weather
baseline. It found unretained imports, four cross-helper finish-reader findings,
two new test-camera spatial references, and the expected stale surface packet.
The imports are now retained, the finish schema is validated before delegation
to the existing material binder, and the reader audit reports **zero NEW**.
Only the two reviewed test/capture spatial records are appended to the spatial
manifest; its current drift is empty. The source-frozen occupied-world surface
renewal remains necessary. No old receipt is repinned or treated as a waiver.
The focused rerun, **part10_scoped_board/board.json**, passes the nine affected
static gates with zero regressions against that baseline. It deliberately omits
the other 105 gates and is not a complete candidate verification. The compact
Part 10 contact sheet and appended diagnostic archive preserve tested source,
original failures, wrapper receipts, numeric samples and raw capture hashes.

#### Part 10 work still required

- Inspect installed-world halos and lamp pillars in actual scheduled winter fog;
  qualify loaded materials, updated surfaces and occupied-world costs. Broad
  component image differences do not prove accurate ring angles or artistic merit.
- Qualify the new real-geometry Fata Morgana pass in the occupied world and
  at an actual river/shore viewing site. The previous checkpoint still painted
  an invented far shore. That fallback remains only in the older renderer;
  V2's new camera pass must protect nearby objects, glass and the interface.
- Finish convincing cloud-gap crepuscular/anticrepuscular rays and a genuinely
  brief horizon-rim green flash. Existing versions are authored approximations.
  Inspect the scheduled circumzenithal arc alongside the new ice complex.
- Build and inspect bounded period airfield searchlight fixtures/beams, drifting
  biplane skywriting and wind-responsive industrial coal plumes. Avoid calling
  the later modern Astoria generating units a 1928 plant; generic period works
  or a researched early site are appropriate. Do not invent an early Holmes
  Airport opening without a source. Fictional airfield traffic is authorized.
- Verify the liner's lit silhouette, ordinary cast shadow, horizon/weather
  integration, distant culling, actual loaded mips and frame tails in the occupied
  world. Add no playable air-travel system merely to support an ambient crossing.
- Preserve a separate historical/retrospective treatment of October 15 rather
  than moving the campaign start. The actual Graf replica and dated shadow event
  are not implemented by the fictional liner.
- Inspect night dust orientation, airglow restraint and changing lunar wash with
  real scheduled clouds and telescope fields. Annual artistic acceptance remains
  open. None of this closes the roof club/telescope interaction work above.

### Real-geometry mirage and multisample resolve

V2 now forwards only the existing scheduled mirage intensity, bearing and phase
to a camera-local presentation effect. The calendar, forcing, weather recipes,
press times and persistent state remain with their existing owners. The older
seasonal renderer retains its old shoreline; extended V2 stops painting it.
The native compositor folds real scene-colour rays inside the scheduled sector
and a low horizon band. It protects destination and bilinear-source depths below
80 m. An immutable pre-transparent snapshot also protects visible transparent
contributions without relying on their writing depth. Contrast falls into the
existing horizon haze. This is an authored ray duct, not a refractive-index
integration through a measured temperature profile.

The project's MSAA setting is retained. The first attempt exposed real API and
verification defects, preserved under **C:/ov/reports/skywatch35/**:

| Location / reproduction | Severity and evidence | Repair / verification |
| --- | --- | --- |
| Copy the renderer colour buffer using a transfer operation | Prototype invalid; **mirage_compiled.log.stderr** rejects the missing transfer-source usage bit, despite printed test PASS lines | Use a GPU compute copy with the buffer's existing sampling/storage usage; no renderer flag mutation |
| Write refraction immediately after the sky with MSAA enabled | Visible effect missing; TAA-off **mirage_far_station** has exactly zero displayed change | Refraction runs after the final multisample resolve; the earlier pass only captures immutable colour |
| Count any TAA-on full-image difference as evidence | False positive; moving edge coverage produced a small signal without actual refraction | Freeze moving weather and disable TAA for paired optical controls; inspect actual inverted buildings. Production MSAA stays enabled |
| Restore a camera with no previous effect list | Runtime type error in the prototype detach path | Compare ordinary arrays and remove only this effect pair; original camera compositor and unrelated effect survive the native test |
| Resize a secondary viewport, then compare Vector2i with Vector2 | Diagnostic interrupted after the successful resize | Explicit integer-size conversion; retain the negative-exit receipt, not an invented completed run |

**mirage_final.log.receipt.json** completes native fullscreen 3440x1440 with
twelve assertions passing, empty stderr and no leaked-RID shutdown warning.
The actual May 9 occurrence drives the effect. Paired controls show real
inverted/stretched buildings, preserve nearby opaque stock, a striped transparent
pane with depth writes disabled, and canvas pixels; source taps drag no nearby
red stock into the sky. Camera binding preserves another effect and restores
the previous compositor. A 1024x512 multisampled secondary viewport and return
to native size exercise snapshot resizing. Inactive weather dispatches no pass.

The first neighbouring row in the optical bench lies within the deliberately
protected range. Its controlled far-city comparisons translate the observer
120 m back, with that station recorded in the tested source. This is not a
walked roof route or evidence of a river at the installed club. The initial
scheduled capture retains the original station and actual weather recipe.
River-site placement and artistic acceptance remain open.

The paired clear-city optical frames on RTX 4080, 3440x1440, 8x MSAA, TAA off,
uncapped, report enabled/disabled p50 **1.862/1.532 ms**, p95 **3.954/1.639 ms**,
p99 **3.958/1.647 ms**, maximum **3.964/1.666 ms**. The two full-resolution
RGBA16F snapshots cache **79,257,600 bytes** until resize or world teardown.
This avoids repeated allocations but is a real memory cost. These figures do
not establish an occupied-world speedup or attribute the tail to an individual
GPU stage. The original occupied-world diagnostic is retained as a failure,
**mirage_world.log.receipt.json** (246 s): it did not complete all four blocks.
Both completed legs include a 1.36–1.38 s synchronous PNG readback/encode inside
the measured interval. This is observer overhead, not evidence that refraction
causes a loading or script stall. Profiling now suppresses that inherited midroute
capture; ordinary crossing tests retain it. The next block also attempted to
grab a partly closing leaf from 2.285 m. The repeated fixture now restores the
leaf through actual reachable grab/move/release outside timed collection, rather
than changing the game's reach or disabling physical protection.

The separate native **mirage_fractional_fixed.log.receipt.json** passes fourteen
assertions with empty stderr. Fractional campaign seconds now reach only the new
mirage presentation hook; pause holds its phase exactly. Shimmer periods divide
the bounded 256-second phase so wrapping is continuous. The first attempted
launch, **mirage_fractional.log.receipt.json**, is retained as an invalid invocation:
PowerShell serialized its CLI array as one argument; the owned process was stopped
and the corrected batch passed. No playtest is claimed for that failed launch.

**mirage_world_fixed.log.receipt.json** completes in 347 s with zero route
failures and empty stderr. Its four 29-waypoint measured blocks cover 5,818
frames in the occupied V2 world, at 3440x1440, 8x MSAA, TAA on, uncapped RTX 4080.
Door restoration between blocks is outside collection; complete route trace has
124 waypoints including setup/restoration. Weather/time and traffic seed are held;
NPC animation and physical traffic remain live. This is a diagnostic, not a
schema-2 runtime qualification or proof of artistic acceptance.

| Block | Wall p50 / p95 / p99 / maximum, ms | GPU median, ms |
| --- | --- | --- |
| Cold off | 31.501 / 48.390 / 58.416 / 114.936 | 14.452 |
| Warm on | 32.727 / 48.156 / 55.505 / 104.031 | 14.802 |
| Warm on | 31.739 / 48.954 / 54.996 / 99.049 | 14.548 |
| Warm off | 31.861 / 47.889 / 54.186 / 97.118 | 14.542 |

Enabled blocks dispatch refraction; both disabled blocks dispatch zero passes.
Runtime source digests match before/after. Original failed-run shader/script
LF hashes were also compared unchanged before fixture repair. The warm medians
correspond to roughly 30–32 FPS, not acceptable evidence that the world's
responsiveness is solved. GPU medians near 14.5 ms are not whole-frame FPS.
Residual 97–115 ms spikes remain, including passage residency and door approaches;
low-rate Performance monitors cannot individually attribute each wall spike.
The player profiler also records roughly 5.3 ms slide calls on the landing.
No actual loading, physics or script optimization is claimed by removing PNG
observer overhead. Nine affected static gates pass with zero regressions against
the previous scoped board; the one new test-coordinate record was reviewed as
fixture data. This is not a complete new 114-gate candidate verification.

### Owner addenda: fluid clouds and the inhabited sky

Parts 11 and 12 are accepted scope for the ongoing sky pass, not completed
features. The owner explicitly authorizes alternate-universe embellishment:
airship trade can be thriving, aviation beacons and industrial silhouettes can
be theatrically legible, and birds and optical events can favor the rule of cool.
Keep these fictional choices consistent with the actual campaign calendar,
reading owners and established world. Do not present invented historical facts
as researched evidence. The November 6 election spectacle precedes the campaign;
it belongs in retrospective material unless a separate fictional event is authored.

- First improve the existing three-stratum density function with coherent flow,
  nested warping, altitude-weighted erosion and wind shear. Preserve integrated
  calendar transport, pause/reversal and shared density for self-shadowing.
  Existing stock is a mipmapped 64-cubed RG base/erosion volume, not the proposed
  128-cubed base plus separate 64-cubed detail. Measure changes before selecting
  a larger stock or adding per-sample finite-difference fetches. Curl-derived
  coordinate deformation is an artistic flow approximation; finite warping and
  erosion do not establish conserved cloud mass.
- Fold airway beacons into the already queued airfield searchlights. Use one
  intentional fictional sweep period; the submitted brief's six-second rotation
  and ten-second flash descriptions are alternatives, not simultaneous facts.
  Maintain bounded light/shadow costs and avoid forced blinding camera flashes.
- Add small-droplet solar/lunar coronae separately from ice halos, gated by the
  actual moist thin-cloud state and source elevation. Inspect rendered colored
  rings rather than counting a shader function as visual acceptance.
- Consider deterministic trolley contact sparks, yard steam/coal plumes and
  construction lanterns where matching world infrastructure exists. Local flashes
  must not replace the weather owner's global illumination or become lightning.
- Consider bounded dawn/dusk pigeon flocks and seasonal migration silhouettes,
  using instanced low-poly wing animation. Prefer convincing collective paths
  over an expensive new general boids simulation. Ordinary world depth must
  occlude birds and aircraft. Do not spawn thousands of independent rigid bodies.

The currently built fictional rigid liner covers part of the aviation request;
airmail planes, advertising blimps, beacons, coronae and flocks remain unbuilt.
These additions do not supersede cloud quality, the rooftop club, its telescope,
barbecue access or the outstanding occupied-world and surface qualification.

### Queued presentation experiment: early-film cadence

Owner's October 27 film brief is queued after weather/cloud integration and
baseline responsiveness diagnosis. It authorizes an optional Graphics setting:
Smooth (default), Cinematic 24, Early Film 18. This is a future implementation,
not an enabled frame cap or a claim of 60+ FPS on the current world.

- Keep the camera, actual grab/drag state, held mechanisms and text presentation
  on the ordinary responsive path. Step only eligible visual animation poses
  and decorative shader time; retain continuous authoritative transforms,
  collision, navigation, animation events and attachments. Inspect owner scripts
  before moving any AnimationMixer into manual advancement. Stepping must not
  replay/skip gameplay method tracks or double-advance animation owners.
- Reject a low-frequency whole-world SubViewport as the general solution: its
  captured view would still update the camera image at 18 Hz. Preserve the
  current separate companion compositing, lamp visibility and real occlusion.
  The companion is physical paper and machinery, not a replaceable text overlay;
  protect the existing display's readability rather than flattening it into HUD.
- Cadence reduction alone does not create over-speed. Explore visual pose holds
  and snappier transitions while keeping authoritative travel and mechanisms
  unchanged. Never alter Engine time scale or assume the campaign runs at one
  in-game second per real second. Preserve its current clock rate in every mode.
- Gate weave, exposure flicker and orthochromatic/sepia grading are independent,
  optional and restrained. Exclude readable companion surfaces, UI and input
  framing from displacement/flicker. Provide a motion/flicker-free choice.
  Temporal AA and motion-vector behavior need real rendered evaluation; FXAA
  is spatial and does not itself interpolate animation time. Do not globally
  disable the existing AA setting merely to imitate a shutter.
- First profile Smooth. Then compare identical routes in all three modes:
  frame-time distributions, input-to-visible-motion, typing/cancel/release,
  clock/save continuity, event ordering and held-object alignment. Visual
  stepping cannot repair or conceal late engine frames. Native-refresh camera
  presentation is a target bounded by hardware performance, not a guarantee.

A true 24 FPS engine cap may be a clearly labeled temporary comparison only,
never the normal mode. Do not add another viewport or post-process dependency
before measuring whether the existing presentation path can support the effect.

### October 27 shutdown checkpoint — cloud-flow candidate, not production

The owner requested a pause to shut down and relocate the computer. Preserve
this branch and draft PR #68; do not merge this candidate on diagnostic evidence.
The previous pushed checkpoint is **fb16e9e8** (real-city mirage and profiling)
with **ba36d282** adding the analyzed film-cadence queue. Main remains
**6ff8922f**. The following cloud changes are a new WIP checkpoint.

Implemented in the existing density include and weather owners:

- Seeded 128-cubed R8 macro noise and 32-cubed RGB curl flow, with complete loaded
  3D mip chains, total **2,509,092 bytes**. Existing 64-cubed RG Worley stock is
  reused for erosion. The extended existing baker derives curl from periodic
  central differences of three scalar potentials; no runtime fluid solver.
  Its pre-quantization discrete divergence maximum is **5.96e-8**. Quantization,
  interpolation, finite warps and erosion are not a claim of conserved mass.
  Method reference: [Bridson, Hourihan and Nordenstam, Curl-Noise for Procedural
  Fluid Flow](https://www.cs.ubc.ca/~rbridson/docs/bridson-siggraph2007-curlnoise.pdf).
- Coherent rolling deformation, nested detail warping, wind-aligned altitude
  shear and height-weighted erosion in ordinary layers; sheets retain continuous
  ceilings and cirrus retains its ice-fibre brush. The severe deck also samples
  flow without moving the finite funnel SDF. View and shadow marches share density.
- Flow phase derives from fractional campaign seconds; existing layer wind and
  precise integrated transport remain authoritative. Existing 10 Hz publication
  is retained. Raw stock export filters and binary Git attributes are explicit.
- Corrected an inactive legacy shape envelope disabling empty-air layer skipping.
  It now matters only when a shape is active. The actual legacy animal envelope
  itself still follows instance age; its out-of-order behavior remains debt.

Evidence under **C:/ov/reports/skywatch36/** must be preserved, including failures.
The initial candidate produced nearly featureless clouds because the texture
binding guard queried an unset shader default. Enumerating declared uniforms
and asserting actual bound texture dimensions/mips corrected it. Initial test
type errors and attempted bit-exact render checks also remain in original logs.
Paused optical frames themselves have edge variation; do not call that cloud
movement or quietly raise an arbitrary image threshold. Final checks compare
160x90 composition against measured paused variation and separately require
all published sky uniforms to return exactly. The controlled comparison disables
TAA, volumetric fog and legacy animal appearance only for its rewind subcase.

**final_V2SkySpectacleBench.log.receipt.json** completes in 18 s, eight assertions
passing, empty stderr. It covers real dated Sc/Ns/Ci/Cu/Cb layers selected at
09:00, 12:00, 15:00 and 18:00, not every genus or the whole year. Reconstructed
uniforms match; composition error is **0.000565**, paused error **0.000552**,
and two minutes of transport gives **0.034600**. An inactive shape timer also
passes its independent rendered comparison. The older scoped return error
before the gap-condition repair was **0.004112**, versus **0.000562** after;
this is optical evidence, not an isolated GPU speedup measurement.

The five dated optical medians changed from **2.352/3.052/2.391/1.998/1.988 ms**
to **2.510/3.385/2.871/2.367/2.335 ms**, same native resolution and authored
states. Raw p95/p99/maxima are retained, including a **25.301 ms** Sc outlier.
These small city-horizon benches do not establish occupied-world performance.
Final CampaignWeatherTest and SkyPhenomenaScheduleTest pass; WeatherSkyTest
passes with its existing legacy character/found-art stderr warnings.

**final_V2WeatherRouteProfile** was interrupted for the owner's shutdown request.
Its wrapper exit alone, including a possible graceful exit 0, cannot count as a
completed cloud ABBA route. See **user_shutdown_interruption.json**. No occupied
cloud qualification, severe-deck render acceptance, new surface renewal or full
candidate verification is claimed. The completed mirage ABBA above remains valid
for that earlier rendering state, not the new cloud code.

Resume by inspecting Git, the lane and the patched engine configuration. Re-run
the pending June 25 cloud ABBA from **skywatch36/final_batch.json** (the first
four runs already completed; do not repeat them unchanged merely for reporting).
Use **SKYWATCH_CLOUD_PROFILE=1** and the native fullscreen wrapper arguments.
Inspect the affected severe/funnel renders, resolve measured costs and remaining
visual limits, then renew source-bound qualification after the batch settles.
Do not rerun firehose interaction as part of this sky checkpoint. Continue the
cloud/rooftop work before the newly queued optional film presentation experiment.

### Resumed qualification and owner-reported cloud pixelation

The clean pushed **8d065ec6** checkpoint was resumed with main still at
**6ff8922f**, no unrelated changes and the patched Vulkan lane free. No firehose
interaction test ran. The previously interrupted cloud comparison was rerun,
not relabeled as passing: **skywatch37/cloud_world.log.receipt.json** completes
in 358 s, empty stderr, four measured 29-waypoint blocks and 4,843 frames;
the complete controller trace includes 124 waypoints with restoration.
All runtime and explicit shader/noise-stock before/after bindings match.

Its native 3440x1440, 8x MSAA, TAA-on heavy-rain medians were off/on/on/off
**35.742/35.374/37.540/36.645 ms**; GPU medians
**14.900/15.114/15.190/15.020 ms**. The 138 ms largest active frame coincides
with LOADING, with a much smaller measured main-viewport GPU interval. This is
correlation, not function-level CPU/streaming attribution. Severe/funnel review
also produced eight matched pre-flow/current views with empty stderr; these
capture checks did not establish artistic acceptance. The owner then correctly
identified objectionable pixel noise in the new cloud renders.

| Location / reproduction | Severity / evidence | Repair / verification |
| --- | --- | --- |
| June 25 storm, luminous cloud underside at native resolution | High visual defect: conspicuous bright square clusters; **skywatch38/current** preserves the original optical control | Replace randomized ray-start offsets with coherent midpoint sampling in both deck and rare-object marches. Same step counts, density fields, self-shadow taps and resolution; no blur pass |
| Previous held-image diagnostic | Its paused-image tolerance did not reject spatial grain; functional PASS was insufficient picture-quality evidence | Keep the old logs and add a rendered fixed-clock/changed-legacy-phase regression; the retained old shader fails this one assertion, and production passes |
| Ordinary walking in heavy rain | Responsiveness remains incomplete: roughly 28 FPS and substantial spikes after the visual repair | Preserve the complete new ABBA arrays; investigate existing world costs separately. Do not hide stalls behind the queued film cadence |

Three controlled shaders differ only in the two ray-start expressions:
original random offsets, midpoint and reduced-amplitude random offsets. The
existing native colour/alpha bench renders identical dated Cu and Cb conditions,
seed 1928, with repeated samples. At the explicitly recorded storm crop
**(1000,100)-(2600,800)**, displayed RGB high-pass RMS (2-pixel Gaussian
residual, including rain) changes **0.004379 -> 0.000764**, about **83% lower**;
the small-jitter alternative is **0.001149**. This is an image measurement,
not a perceptual acceptance score or a claim that all renderer variation is gone.
Actual native images were inspected: the bright square clusters disappear
without blurring the broader folds. Storm mean alpha remains **0.9555**, with
**0.9783** of sampled upper-frame pixels above alpha 0.1 in both controls.
Cu mean alpha changes **0.4616 -> 0.4632**; its thresholded coverage changes
**0.8630 -> 0.8416**, so exact pixel/coverage identity is not claimed.

**skywatch38/midpoint_production.log.receipt.json** passes nine assertions plus
the final result, empty stderr, 14 s. The rendered legacy-phase regression is
exercised against the retained noisy source in **negative_old_jitter.log**:
one assertion fails as intended (two FAIL lines including the result). This is
an expected negative control, not a production failure or an altered receipt.
**vortex_midpoint.log.receipt.json** completes eight matched views in 27 s,
empty stderr; the single SDF funnel and its parent cloud remain joined.

The repaired production shader also completes the occupied ABBA in
**skywatch38/midpoint_world.log.receipt.json**, 353 s, empty stderr,
**4,965 measured frames**, 124 total waypoints, zero failures and unchanged
source bindings. The measured blocks each contain the same 29 route waypoints.

| Block | Wall p50 / p95 / p99 / max, ms | Main-viewport GPU p50, ms |
| --- | --- | --- |
| Cold flow off | 34.863 / 67.316 / 79.759 / 190.920 | 14.989 |
| Warm flow on | 35.074 / 63.429 / 71.827 / 100.158 | 14.770 |
| Warm flow on | 35.685 / 65.064 / 75.985 / 99.684 | 14.871 |
| Warm flow off | 36.223 / 66.462 / 79.425 / 106.084 | 15.018 |

The first cold spike remains in the record. Live NPC/traffic variation, driver
cache and process order remain limits; do not attribute differing medians or
maxima solely to midpoint sampling. CPU/physics monitors lag and overlap, and
main-viewport GPU timing excludes any claim of a complete per-view GPU sum.
The nine affected static gates pass with no regressions against the prior
scoped board; reader has zero NEW fields and spatial drift is zero. This is
not full candidate verification, renewed surface qualification, annual visual
acceptance or a statement that V2/the weather module is complete. The retained
animal-cloud envelope's instance-age behavior and the wider frame spikes remain
open. The ornate front-entrance references and optional film modes are queued
in TASKS; neither displaced this repair or changed the installed door.

### Cloud self-shadow filtering and retirement of novelty silhouettes

Evidence class remains **INERT**. This section records diagnostics, not annual
artistic acceptance or production qualification.

| Location / reproduction | Severity / evidence | Repair / verification |
| --- | --- | --- |
| January 8 noon Cu, native close crop after midpoint repair | High visual defect: coherent but coarse bright blocks remained even after random grain was removed | Integrate only self-shadow sample footprints using existing loaded noise mips and a filtered height ramp. Primary density, silhouettes, analytic high ice, sample counts and textures remain unchanged |
| Full-density filtering control | Unacceptable tradeoff: Cu mean alpha fell from 0.4632 to 0.3812 | Rejected; the retained source-controlled trials isolate height, macro and shadow-only filtering |
| Duck/whale/ship cloud experiment | Owner retired the experiment on October 27 | Remove daily eligibility, scene-age state, debug forcing, SDFs, march branches and obsolete review controls from current and fallback skies. Keep natural rare formations and their existing calendar owners |
| Raw cloud texture evidence | Qualification input discovery did not include the new R8/RGB8 stock | Bind both raw extensions; mutation regression requires either field to expire prior proof |

Native final colour/alpha captures in **skywatch39/final_detail** show Cu mean
alpha **0.463172 -> 0.462696**, thresholded coverage **0.841579 -> 0.840688**;
Cb remains **0.955471 / 0.978251**. Small repeat variation remains. Actual
native-pixel crops were inspected: the coarse bright Cu blocks are suppressed,
with broad folds retained; no full-screen blur was added. The retained
**cloud_lighting_contact.png** shows the midpoint control beside final source.
These two dates are specific regression evidence, not proof of annual diversity.

Before the owner's retirement request, a calendar-age repair passed its new
pause/rewind checks, after an original failure exposed pending 10 Hz publication.
Both the failed **final_V2SkySpectacleBench** log and passing **published** log
are retained. That repair and its tests were then removed along with the whole
experiment; no new civil-noon appearance schedule ships.

The lighting version completed **published_V2WeatherRouteProfile**, 345 s,
124 controller waypoints, 4,821 measured frames, empty stderr and unchanged
before/after source bindings. This precedes novelty retirement; the subsequent
optical review verifies that removal. No speedup is attributed to either change.

| Block | Wall p50 / p95 / p99 / max, ms | Main-viewport GPU p50, ms |
| --- | --- | --- |
| Cold flow off | 35.646 / 65.699 / 78.663 / 139.884 | 14.710 |
| Warm flow on | 37.327 / 64.512 / 76.931 / 118.878 | 15.158 |
| Warm flow on | 36.329 / 65.792 / 74.396 / 103.543 | 15.066 |
| Warm flow off | 37.640 / 66.257 / 77.435 / 104.175 | 15.381 |

Live NPC/traffic variance, cold traversal and overlapping/lagged CPU monitors
limit attribution. The worst frame is a walk with residency DORMANT; a residency
label alone does not identify a responsible function. Responsiveness debt remains.

After retirement, **retired_cloud.log.receipt.json** passes eight assertions plus
the final result, 15 s, empty stderr: five actual dated genera, fractional motion,
pause, legacy-phase noise control and out-of-order visual/uniform reconstruction.
**final_detail.log.receipt.json** completes four native colour/alpha samples in
13 s, zero failures. **final_vortex.log.receipt.json** completes four production
severe/funnel views in 17 s. These are optical diagnostics, not runtime contracts.

A clean 114-gate main baseline is retained at **skywatch38/main_baseline/board.json**,
main **6ff8922f**, tree **a5e533fb538e7608e8eb9a445c99c793e96aeb27**.
The original **candidate_ad9302f8/verification.json** correctly fails on stale
rendered-review/surface qualification, with no other gate regressions, all 17
protected paths unchanged, selector V2 and no ledger promotion. No waiver or
repinning was applied. Renew actual source-bound surface evidence after rendering
inputs settle, then repeat candidate verification against that clean baseline.
No whole-game production or human acceptance is claimed.


The fallback **retired_millwork.log.receipt.json** passes 35 checks, empty stderr;
its retired-shape assertions and captures were deleted rather than retained as
claims about removed behavior. The historical period audit also passes.

The 41 Python surface-requirement tests pass (195.762 s), including mutation
checks for both raw cloud fields. Reader audit reports zero NEW fields.
These checks do not renew the stale runtime surface packet.

### Existing route costs: narrowed follow-up, not a new speedup

Read-only aggregation of the retained **skywatch39/published_V2WeatherRouteProfile**
arrays is in **skywatch40/phase_attribution_limits.json**. Pooled walking has
3,482 samples, wall p50/p95 **35.591/69.216 ms**; outdoor turning has 636,
**24.486/39.670 ms**; the fixed sky bearing has 623, **51.063/57.304 ms**.
Different bearings, residency and visible stock prevent causal comparisons
between these phases. Main-viewport GPU medians are respectively **14.654**,
**11.041** and **20.502 ms**; private viewport costs are not summed.

The bounded final 256 input records contain 197 constrained-motion calls,
median **0.011 ms**, maximum **0.038 ms**, but 20 release/end calls at median
**13.390 ms**, maximum **14.502 ms**. The separately timed world-modified signal
is at most **0.011 ms**. Three thresholded slow player-physics records show
landing slide calls around **5.3 ms**; they are not a complete physics distribution.
Static tracing puts transform publication, physics synchronization, settling
and the manipulation-changed/save notification inside the release interval.
The next release investigation must separate those costs before changing any
save or collision owner. This evidence narrows the target; it does not identify
a responsible function or explain the 100+ ms frames. No firehose run was used.

### Surface classification failure retained before renewed qualification

**skywatch40/surface_clouds.log.receipt.json** completes with exit 1 in **783 s**,
**39,169 checks**, one assertion failure. Its inventory has **27,820 draws**,
**17,006 meshes**, **6,309 materials**, **527 textures**. All four technical
findings are the actual street lamps' **IcePillar** optical quads. The lamp
owner already labels these **weather_optics**; the audit did not recognize the
new shader/owner combination. There is no missing physical-lamp material repair.

The audit now classifies only the exact unshaded **street_ice_pillar.gdshader**,
weather-optics role, exterior-cell owner, installed street subtree and terminal
IcePillar part as an urban ice light effect. A focused unit regression passes
with negative controls for housing/foreign paths, physical role, wrong owner,
wrong shader and shaded material. This follows the existing separate optical
inventory rule; it is not an exemption for physical stock.

Re-evaluation of the unchanged failed-run inventory reports zero unresolved
surfaces in **reclassified_diagnostic.json**. That is a diagnostic only: the
original test-written failed runtime contract and stderr remain untouched.
The checker is a bound input, so a fresh complete surface run remains required.
The failed packet is not published, repinned or described as partial acceptance.

### Fresh surface result and publication

**skywatch40/surface_classified.log.receipt.json** completes successfully in
**784 s**, native fullscreen **3440x1440**, patched Vulkan, empty stderr:
**39,169 checks / zero failures**. Its schema-2 runtime contract records PASS
for production composition, loaded surface requirements and runtime-owned
teardown. Inventory: **27,820 draws**, **17,006 meshes**, **6,309 materials**,
**527 textures**. Fire-service interaction was explicitly skipped; its physical
draws remain inventoried. Save reconstruction is **NOT_EXECUTED**, not a pass.

Seven actual current captures were reviewed: street skyline, storm skyline,
front gallery, paving, entrance, public arcade and bathroom corner. Native
source PNGs and their hashes are in the published packet. The storm ceiling
is still low contrast and the street exposure remains dark; this surface review
does not grant annual atmospheric or lighting artistic acceptance. The new
cloud optics have their separate native-pixel controlled comparisons above.

The existing surface publisher validates and installs the new test-written
contract, raw inventory, corroborating logs and review, with zero defects.
The previous packet is preserved externally in **skywatch40/publication_backup**;
the failed original run, classifier source/control and fresh result are retained
under **urban_pillar_surface_qualification/** in the existing diagnostic archive.
No failed receipt was edited or promoted. Full candidate comparison against the
clean **6ff8922f** main baseline is the next integration gate; the broader
weather/roof and responsiveness limitations above remain open.

### Candidate verification and main integration

[PR 68](https://github.com/NateHiggins/Lily-s-Music-Box/pull/68) merged at
**900789b82677831d8bd3c6118844a65996ae3fdf**. Canonical main was fast-forwarded
and its complete Git tree compared equal to tested candidate
**67c614b04561035d86e164f1fefd5d9f269e40f7**. This following ledger/archive update
changes no runtime, test, material or geometry input.

**skywatch40/candidate_qualified/verification.json** reports MERGE-CANDIDATE:
all **114 gates**, **zero regressions**, **zero waivers**, **17/17 protected
paths unchanged**, selector V2, zero design-lint errors and no changed
requirement status. Known whole-game baseline failures remain; this does not
make main universally green. Both brokered imports and the pure-data
CampaignWeatherTest pass, with its suite receipt binding to the candidate.
Native optical/interaction and composed surface evidence above remains scoped
to its actual execution; the headless data suite is not a visual playtest.

The four changed gate files were reviewed: a descriptive retired-shape period
label; exact optical-pillar recognition plus physical-stock negative controls;
three test-only spatial-coordinate groups; and stronger raw-noise mutation
coverage. No production spatial authority was reassigned. The in-place run
supplies no fresh-checkout/autocrlf qualification or human artistic acceptance.

The import stage generated **627 untracked UID sidecars** and **14 line-ending-only
import changes**, from an initially clean checkout. UID creation times fall
within that import window; all bytes were backed up externally before removal.
The sidecars were restored only after exact LF-normalized equality to HEAD.
An empty orphan index lock from the same window was preserved and removed only
after no Git process and a successful exclusive-open check. Authored/shared work
was not discarded. Post-import surface verification still reports zero defects.

The existing archive preserves raw candidate verification, import/suite logs,
receipts and churn provenance under **candidate_67c614b0_main_merge/**. Runtime
qualification, annual visual diversity, performance and owner acceptance remain
separate claims. Next: refresh the 365-date/six-period gallery on merged source,
inspect weak/repetitive skies and continue the existing weather/roof work.

