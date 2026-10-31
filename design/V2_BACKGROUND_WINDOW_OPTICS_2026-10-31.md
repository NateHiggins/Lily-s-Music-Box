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
