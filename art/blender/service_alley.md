# Rear service alley

Evidence class: **INERT**

The owner selected a street-connected service alley on September 29. The
former rear review apron ended over empty space and overlapped the corner of
the service core. Production now substitutes a fitted Blender paving assembly,
following the stepped building perimeter and joining the existing sidewalk.
The standalone review apron and its semantic identity remain available.

Rebuild **art/blender/service_alley.blend** and
**game/assets/props/service_alley.glb** with
**art/blender/scripts/build_service_alley.py**. The generator reads the front
and rear thresholds, service core and outer room boundaries from the V2 source.
**orison_v2_service_alley.gd** mounts the asset inside the same registered
building frame as the rear door. No second street coordinate conversion is
introduced. The sidewalk, street barriers, shops and Passage retain ownership.

Jointed paving seats on continuous substrate. Masonry boundaries have bonded
piers and jointed stone coping; the street mouth stays open. Three recessed
iron gratings occupy Boolean-cut paving pockets. Four retained cage fixtures
hang from fitted iron plates and cantilever arms. The narrow side stretch has
more than two metres of clear width, including the pier projections. Geometry
exports as 22,556 triangles in four finish batches; collision uses those exact mesh triangles.
The October 8 finish pass replaces the absent **limestone** catalogue lookup
with local **concrete** mineral maps and reuses **iron_neutral** for ironwork.
Brick/paving response is calibrated alongside them. Boundary world projection
is retained; groundworks use metric UVs. Native geometry is unchanged. See
**design/V2_ALLEY_FINISH_2026-10-08.md** and the read-only
**review_service_alley_finish.py**.

The rear door now uses the existing production DoorProp, fabricated hinges and
knob, with an outward swing onto the receiving approach. State and interaction
remain with that owner. The focused test requires shut-leaf blocking, real
player interaction, a continuous 25-waypoint rear-to-street/front-entrance and
return walk, and seven supporting floor contacts. It preserves the production
controller, gravity, collision mask and lamp. Inspection copies hide only the
carried overlay; normal captures retain it. Evidence is under
**tmp/service-alley**, with final candidate receipts under **verified**.
The alley view exposed 200 mm open bands above the service-core walls. Rooms
without ceiling slabs now continue their walls to the next storey instead of
stopping at the ceiling height. Twelve rays check the formerly open core bands;
the full vertical route checks that stair travel remains clear. Ordinary
ceiling/floor face ownership and all authored apertures remain unchanged.

The final alley run passes 25 waypoints, seven ground contacts and twelve
storey-band contacts. Seventeen normal-height inspection views were reviewed,
including the corrected core seam. No runtime-contract or completeness-ledger
promotion is claimed. The full vertical route passes 79 walking waypoints.

## Connected-world regression fixture maintenance

The broader connected-world check predates the Blender water closets and the
expanded fitting roster. Its imported-model branch now requires each reference
mesh to appear exactly once and remain visible. Raw-surface checks remain for
the other records. Drain-side mutations target kitchen sinks by fixture kind,
instead of adding a sink-only field to the first record (now a shower).

Unspecified switch test poses are selected from nearby supported floor positions
using the unchanged real capsule and a direct plate-targeting ray. Authored
stance anchors remain authoritative. Actual player input, circuit isolation,
power output and looking-away checks still execute for all 81 switches over two
world constructions. Alternate poses receive inspection captures. The former
3B main-room capsule test point intersected the dining table; its X coordinate
now matches the already-authored and walked dining-table stance at 12.5 m.
No furniture, collision dimensions, interaction range or control is weakened.

The sixth-floor study switch stance moves 0.51 m clear of the kitchen door's
intermediate sweep. The old stance was clear at both endpoints but intersected
the leaf from 10 to 50 degrees. Eleven sampled door angles now receive strict
capsule checks before the full switch interaction loop.

The initial headless stair attempt waited for a capture and was interrupted;
the initial connected-world fixture raised an absent-surfaces error. Those
attempts are preserved under **initial-verification** and are not passing
receipts. The repaired full connected-world run uses the long windowed runner,
because its expanded 81-switch roster exceeds the short runner budget.
