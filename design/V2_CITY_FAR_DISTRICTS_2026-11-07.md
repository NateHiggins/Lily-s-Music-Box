# V2 distant districts — November 7

Evidence class: **INERT**. Build report and technical view record. This is not runtime
acceptance, whole-city qualification or Lily's artistic acceptance.

Lily's ruling **city_finish_owner** (2026-11-07): Claude authors the next distant-city batch
in Blender; Canonical Codex keeps integration and qualification. Proposal:
C:/ov/reports/city_completion_proposal_20261107/PROPOSAL.md. Stacked on PR 170
(**0eb365963**), whose bound native loaders, rail and bulkhead composers remain in service.

## What is added

- **Midtown Manhattan**, south of the bridge. It holds the 1929 towers at their real
  distances from the 59th Street anchorage, refitted to the installed straight river:
  Chanin, the Chrysler steel climbing past its masonry, New York Central, Graybar, Ritz
  Tower, Sherry-Netherland, Fred F. French, Beekman Tower, Paramount, Tudor City, Lefcourt
  and Lincoln. Waterside Station's six stacks stand on the shore. Ordinary blocks fill an
  avenue grid turned with the bridge (west-north-west), with Central Park left open.
- **Welfare Island**: penitentiary, workhouse, City Hospital, smallpox ruin, octagon and the
  north lighthouse.
- **Queens**:
  - the LIRR powerhouse's four stacks on the Hunters Point waterfront
  - Sunnyside Yard east of Queens Plaza: car rows, catenary portals and the shop
  - Newtown Creek with its oil tanks
  - the Greenpoint gas holders and spire
  - the Astoria holder
  - industrial and row-house fill outside the apron
- **Ground and water** carried from the installed bridge sheet and apron edges out to
  3.8 km, inside the 4 km camera far plane. The creek, the island's tips and the river
  continue the sheet's own profile, so there is no seam or cliff.
- **Window lamps** on every facade (game/shaders/v2_far_city_facade.gdshader):
  - catalogue PBR on metric UV0
  - the background windows' schedule and tungsten palette, read from the campaign clock
  - per-pane detail that resolves to its mean below pixel size
  - a blue-hour lift
- **Fog**: the shader writes its own depth fog from the live Environment, so lit panes read
  through haze while unlit walls take the full fog.
- **Motion** (orison_v2_city_far_motion.gd):
  - screen-sized headlights and tail lamps on the roadway
  - lit el cars on the upper deck
  - one tug in the west channel
  - smoke from 77 recorded chimneys, in one particle system that drifts with the wind
    published to the sky
- **Prologue**: the rooftop montage projects its detached clock onto the far lamps, as it
  does for the near windows.

## Frames

The V2 ground and blockout are turned in the world: world = (−x, y, −z − 11.65)
(tests/V2FrameProbe.tscn). The bridge, the far shore and these districts use the world
frame and mount on the runtime root. The apron survey is converted when it is sampled.
Earlier captures that mounted under the ground came out mirrored; they are superseded.

## Reproduction

- **Ground survey:** art/blender/scripts/survey_city_far_ground.py writes
  art/blender/data/city_far_survey/h_near.npy and h_far.npy.
- **Districts:** art/blender/scripts/build_city_far_districts.py writes
  game/assets/props/city_far_districts.glb and
  game/data/orison_v2/exterior/city_far_districts.json (stack tops).
- **Faces:** every face is oriented by construction.
- **Size:** 56 draws and about 107k triangles. Nothing casts shadows or carries collision.

## Historical author captures

Test: tests/V2CityFarDistrictViews.tscn, windowed on the hidden desktop. It captures ten
views at noon, dusk and 19:10 on 23 February 1929:
- four roof bearings
- both street ends
- the bridge upper deck
- the canal
- the rail cut
- the telescope at 14°

The author run passed 30 frame writes and retained the gameplay clock. Its wrapper recorded a dirty checkout at the prior base. The east view faced a doorway, the telescope wall obscured most of its frame, and the bridge camera stood over the lower roadway. Original frames and receipts remain in **C:/ov/reports/city_finish_20261107/views_06/** and **lane/**.

Matched cost (60 frames each, districts present against hidden) at the night roof views:

| View | Draw calls | GPU |
|---|---|---|
| East | +17 to +31 | within run-to-run noise (−2.3 to +0.2 ms) |
| West | +17 to +31 | within run-to-run noise (−2.3 to +0.2 ms) |

CPU cost is +0.1 to +0.2 ms. This is one machine under lane contention, not a frame budget.

## Integration verification

The north bank now follows the west-north-west Manhattan grid. A 513-point exported ground sample found the retained bridge shore under all checked footprint neighborhoods. The native focused run at **b78ed2389** reviewed 30 captures with corrected east, telescope and upper timber stations. The two night roof comparisons added 31 and 17 draws. The measured viewport GPU differences were −0.276 and +0.068 ms. Cold world startup took 137.8 s in the views run and 137.1 s in the prologue run. These are single-host observations.

The production prologue passed 122 checks, including far facade projection and immediate restoration, ordinary bridge lamp, elevated car and tug motion, and campaign clock custody. The first original surface run refused the two light overlays and the chimney particle sprite. The fix recognizes their exact optical signatures in the auditor. The game tree is byte-identical from the focused source to **9a3bd953e**.

The original suites passed 379 authority/save checks, 60 rooms over nine apartment legs, 38,947 surface checks over 30,987 loaded draws, and 6 exterior routes. The real-controller eastern suffix reached 449.703 m at the retained wall and retreated with no unsupported ticks or recovery. Technical review covered all 82 qualification frames. See **art/reviews/v2_qualification_far_city_20261107/** for source bindings, reviews and the preserved first failure.

## Open

- Lily's artistic review and human play. The sparse foreground and low daytime contrast remain visible from both street endpoints.
- The continuous threshold route and a composed whole-city LOD or frame-time sweep. The eastern suffix is the bounded ground check.
- Daytime bridge vehicle bodies, Queens Boulevard trams (**T-V2-TRAMS**) and the separate sky owner's cloud relief and haze work.
