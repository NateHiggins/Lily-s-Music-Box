# Background-window optical prototype

Evidence class: **INERT**. Implementation report and isolated diagnostics;
not a runtime qualification, installed-city acceptance or artistic approval.

## Delivered scope

**K-V2-WINDOW-DEPTH** now has a reusable spatial shader, a private catalogue
material factory and an isolated 64-pane MultiMesh bench. Ray/box intersections
project a room and bounded furniture behind a flat pane. Four caller-selected
uses cover dwellings, offices, workshops and shops. These are restrained
background suggestions, not fully authored playable interiors. Beds, pillows,
cupboards, tables, chair/crate silhouettes and shop shelves supply depth cues.
Fixed building/pane identity varies furnishings, curtains and lighting hours.
There are no added lights, textures, room meshes or per-window viewports.

The factory reads existing mirror, limewash and walnut catalogue textures;
it never changes shared MatLib resources. Primary glazing maps sample metric
UV0. The separately named room projection requires normalized, top-left-origin
UV2 per pane. Callers supply pane dimensions in metres. MultiMesh custom-data R
is a normalized pane identity; keep it stable through LOD substitution and use
one identity across multiple pieces of the same window. Standalone panes can
use the material's building seed. The seed varying is flat: interpolated float
roundoff passed through a hash caused the original close-view speckling.

The optional **sync_clock** adapter reads CampaignClock's valid day/minute and
weekend fields. It leaves the last valid presentation alone on an invalid
clock, never advances time, and owns no saved state. The bench uses explicit
test-only presentation hours; it has not exercised that adapter in the city.
Suggested lit windows imply anonymous background activity, never named
residents, discoveries or story facts.

## Executed checks and observed result

Through the shared lane and pinned patched Vulkan 4.7.1, **bench04** completed
with an empty failure list and empty stderr at native fullscreen 3440 by 1440
on the RTX 4080. Five loaded map roles per material had mipmaps. Four actual
frames cover 10:00, 20:00, an oblique evening view and a close evening view.
They were inspected: rooms exhibit parallax, different day/evening activity,
curtains and furniture silhouettes; the speckling is absent. This is an
isolated facade board, not a screenshot of installed city buildings.

Diagnostic output and original wrapper receipts live in
**C:/ov/reports/window_interior_20261031/**. Final frames and JSON are in
**final04/**; **bench04.log.receipt.json** is the wrapper receipt. The bench
writes diagnostic JSON, not a schema-2 runtime contract. **bench01** failed
parsing the bench's inferred floor expression and was stopped by this agent;
its stderr/receipt remain. **bench02** exposed seed speckle. Its screenshots
were accidentally overwritten by bench03 because the initial bench ignored
SHOT_DIR; the bench02 log remains, but its original pixels are not retained.
Bench03's inspected images/JSON are preserved in **review03/**. The output
directory now follows the wrapper's SHOT_DIR; bench04 is separate.

## Timing limits

At one unchanged close-view pose, 120 samples per phase after 90 warm frames
compare interiors disabled/enabled/disabled. Frame median/p99/max in ms:

| Phase | Median | p99 | Max |
| --- | ---: | ---: | ---: |
| Before control | 20.004 | 20.563 | 21.249 |
| Interiors | 20.017 | 20.664 | 21.049 |
| After control | 20.014 | 20.747 | 21.070 |

CPU-render medians were 0.200/0.191/0.200 ms. GPU-render medians drifted
2.271/1.373/3.765 ms; these do not support attributing an incremental GPU cost.
The control disables interior presentation in the same shader, not a native
material baseline. Three visible draws were reported in each close-view phase;
other facade batches were off camera. Frame pacing is limited around 20 ms.
This neither measures a speedup nor establishes a city-wide performance budget.
Screenshot encoding was outside the timed sections. No full-world walking,
hose, interaction or unrelated suite was repeated for this optical prototype.

## Remaining work and pause

The architect's city loader, geometry, original glass bindings, collisions and
source fixtures are unchanged. Native stock does not yet provide the required
per-pane optical UV2 contract. Before rollout, reconcile those charts in the
native builder, preserve UV0/TBN and stable window identities across body LODs,
then bind only opaque noninteractive background panes. Do not replace actual
occupied-room windows or transparent/interactive glass with this opaque shader.
Measure against native stock at matched street, roof and telescope views;
check motion, true foreground occlusion, LOD transitions and composition with
the existing sky. The current close view still shows simple analytic furniture,
not telescope-quality furnished rooms. Office weekend lighting is authored
presentation, not a simulated schedule. Artistic approval remains Lily's.

Per Lily's instruction, new work pauses after this shader checkpoint. These
rollout gaps remain queued; no whole-city or V2 completion is claimed.

## Reproduce

From the canonical checkout, use the repository lane only:

```powershell
pwsh -File tools/lane.ps1 run -Scene res://tests/V2BackgroundWindowBench.tscn -Runner serial -TimeoutSeconds 100 -Windowed -ShotDir C:/ov/reports/window_interior_review -LogPath C:/ov/reports/window_interior_review/bench.log -WaitMinutes 30
```

The bench requests native fullscreen, does not capture the mouse, and exits
after its bounded captures and timing samples. It does not mount the city or
modify campaign state. Do not treat a wrapper exit alone as visual acceptance.

## Installed city and rooftop review — later on October 31

Lily subsequently requested installation and a starlit rooftop photograph.
The frozen city export checkpoint **1d62881e** and its evidence-only follow-up
**57cb7e78** were merged, preserving their distinct native and rendered scopes.
The horizon loader now installs the optical shader on its 124 opaque background
window draws using three shared materials: dwelling, office and workshop.
Builder-derived **window_typology** carries the existing building typology into
runtime metadata; it introduces no occupied programme or resident facts.

Private runtime meshes add only optical UV2 and float CUSTOM0 attributes.
Original positions, metric UV0, index arrays and LOD index bytes were compared
on every installed window draw in the composed world. Original collision meshes
and shadow meshes remain with their owners. A quarter-second bounded clock
check republishes three materials only when the authoritative minute changes.
No per-window processing, lights, viewports or persistent state were introduced.

**city01** and **city02** completed through the pinned Vulkan lane with empty
failure lists and empty shutdown stderr. Both selected the authored clear
evening of **1929-02-23 at 19:30**, with lunar illumination **0.996588**. The
camera is posed above the Orison roof at world **(-14,22.8,-2.650001)**; a real
floor query checks the roof below it. No walked rooftop-access claim is made.
The normal device overlay and personal lamp are hidden only for photography.
The 100-degree horizontal view and 65-degree companion view are native
3440 by 1440 renders. Loaded optical map mipmaps, shader bindings and campaign
clock uniforms were checked. These remain INERT optical diagnostics, not a
schema-2 runtime qualification or Lily's artistic acceptance.

The original photograph revealed unlit coal haze radiating its daytime sepia
value at night and lunar albedo multiplied by the old dim source gain. Two
bounded shader corrections now scale haze radiance by solar elevation and
increase the phase-lit lunar-disc radiance. Density, ephemeris, lunar relief,
shadows, angular scale and the sun's disc term remain unchanged. Daytime haze
above the +0.03 solar-Y boundary is algebraically unchanged. Both original
and corrected photographs are retained; the corrected views were inspected.
This is a focused night review, not renewed annual weather qualification.

Projection preparation took **838.184 / 778.740 ms** during **136.270 / 130.706 s**
world startup. Different startup samples do not establish a speedup or a frame
budget. The family bench also exercises optical projection while comparing
physical attributes and original LOD bytes. Its original invalid CUSTOM0 input
and the capture script's inferred-type failure remain in the external logs;
the corrected import, compilation and family checks passed before composition.

**C:/ov/reports/window_install_20261031/** holds the original receipts, failures,
source-projection reconciliation and full captures. The committed
**art/reviews/city_streets_20261029/window_optics_review.zip** retains selected
original and final evidence without adding loose image files to the game.
The native metadata renewal proves all 34 GLB hashes unchanged, the builder AST
unchanged except the typology projection, runtime metadata unchanged except
that field, and original loader statements retained. Only eight declared
horizon/street source bindings were renewed; 118 fixture preflights introduced
no new source errors. No historical runtime receipt was repinned.
The broader scan still reports pre-existing source errors in 97 fixture records;
this reconciliation does not waive or repair that unrelated debt.

Remaining limits are installed street/telescope/LOD-transition artistic review,
matched occupied-world frame distributions and full surface/weather receipt
renewal. Analytic furniture remains deliberately simple. New development pauses
again after this requested installation/capture checkpoint.

The full 119-gate static board was executed and retained. Against the
architect-only baseline it reports three incidental test-camera references and
an additional stale surface-test binding. The three references were subsequently
registered without replacing existing manifest records. The surface-test file
is LF-byte-identical to pre-install **f0bf4491**: that stale binding predates this
installation on the integration branch. The original board is not rewritten or
called green. Existing whole-game gate failures, source debt and runtime
qualification remain open; this checkpoint is not merged into main as accepted V2.

## All neighbouring buildings and restrained variation

Lily then requested every windowed building except the Orison and more realistic
variation. The 25 retained near-city elevation assemblies now join the 124
horizon assemblies: **149 window partitions / six shared materials**. The
Orison, its occupied interiors and its shop glazing are outside this installation.
Near-city scenic panes formerly used transparent glass over decorative backing;
they now use the opaque optical-room presentation. Their original physical
geometry, backing/curtain stock, collision and authored body LODs remain intact.
Projection also handles sloping/horizontal glazing, retaining small edge faces
as ordinary glass. Building clocks retain their existing pose and time authority.

Fixed per-pane traits vary room depth **2.85–4.75 m**, bed versus desk/chair
arrangements, desaturated cloth/plaster colours, rounded lamp shades, curtain
openings and roller blinds. Lamp colour spans a warm, approximately
**2300–3300 K** artistic palette; intensity spans **0.35–1.25 relative units**.
These are restrained rendering parameters, not calibrated temperature/lux
measurements. The hash traits are flat vertex outputs, avoiding interpolated
seed noise and repeated fragment hashes. No additional lights, textures,
per-window callbacks or gameplay occupants were added.

The focused family bench and a single composed-world review completed with
empty failure lists and stderr. The composed review checks all 149 bindings,
original position/UV0/index/LOD data, loaded mips, authoritative time, and that
no Orison draw uses this shader. Native-fullscreen night captures and close
family views were inspected. **17 focused tooling tests passed**, reader NEW
remains zero, and the focused spatial audit has no drift. Two elevation GLBs
are byte-exact to **12aac6d7**; four native metadata bindings were reconciled
with 118 fixture checks and no new source errors. No runtime receipt was renewed.

Original and current evidence share the existing window review ZIP, under an
added **all_buildings/** prefix; prior members remain byte-exact. Full loose
receipts/captures are at **C:/ov/reports/window_all_buildings_20261031/**.
The previous full static board and broader qualification limits remain as
recorded above; no additional full-year or whole-game acceptance is claimed.
