# Registered city foundations and terrain joins

Evidence class: **INERT**

REPORT - V2 CITY FOUNDATIONS - 2026-10-03

Canonical **main**, construction baseline HEAD/origin/main/merge-base
**4e6c498fb6fdcb9c3b8bb305f99c14bb274ccde4**. This is a bounded geometric
construction record. Raw city architecture, complete infrastructure and final
material/render polish remain open. No completeness requirement is promoted.

## Actual source and the two defects

The saved **city_shells.blend** supplies the exact planar undersides of seven
existing closed neighboring masses. Their authoring roster is
**art/data/city_foundations/source_plan.json**. The generator refuses a bottom
face that is not one flat four-vertex rectangle; a complex mesh's overall box
is never relabelled an exact solid. The existing city conversion and street
registration give Orison-local **(-source X, source Z, source Y - 1.855)**.
The offset is derived from the retained front threshold and **street_frame.json**.

The near northwest neighbor had moved **-3.20 m** in source X to clear the
accepted alley, while the farther northwest row had remained behind. Actual
native bottom faces overlapped by **2.60 m**. **build_city_shells.py** now applies
the same accepted west registration to that whole row. All 335 authored solids,
84 building/material partitions, northeast/bodega registration and southern
bar/arcade frames remain. No generated layout coordinate is hand-edited.
The dormant **site_end_w** mass is outside the active shell filter; this batch
does not claim that old end closure is mounted.

The first foundation prototype also intersected 18 existing public-slab cells.
The retained **160 mm** FrontPavement course remains its owner. New construction
is subtracted around it, leaving the fitted contact course below its underside.
The final exact-component intersection audit reports zero positive overlap.

## Editable construction and surface ownership

**build_city_foundations.py** extracts fresh actual saved undersides. Existing
slab thickness **0.20 m**, outer-wall width **0.35 m** and basement datum
**-3.20 m** supply a contact course **-0.20..0**, perimeter stems
**-3.40..-0.20**, and **0.70 m** wide footing rings **-3.80..-3.40**. This is a
geometric adaptation of intentional inaccessible closed masses. Soil conditions,
reinforcement, loads and bearing capacity are unestablished.

The fitted source has 67 nonoverlapping construction components and seven
positive closed unions with zero nonmanifold edges. The runtime export has
128 bounded metre-UV partitions and 5,076 triangles. Closed native source caps
remain editable; runtime omits shared top/contact planes already owned by the
retained city undersides or public slab. **orison_v2_city_foundations.gd** mounts
once under the registered Orison root, with catalogued concrete, explicit UVs
and native triangle collision. It adds no actor or simulation authority.

**reconcile_city_ground_source.py** validates all unrelated retained bindings,
the current city registration and unchanged 899 classified geometry masks.
It removes only the former bounded-batch neighbor exclusion. The ground builder
then consumes fresh canonical foundation components and underside projections.
No ignored prototype path is a production input. Rebuild order is city shells,
authoring-map reconciliation, city foundations, then Orison ground.

The expanded finite terrain bounds are local X **-44..39.5 m**, Z
**-16.605..24 m**, bottom **-4 m**, original asphalt top **-0.02 m**.
The original 899 masks, 67 fresh foundation components, 46 retained occupation
reservations and 30 alley reservations give 1,042 masks. Actual closed native
volume is **11,099.9397525 m³**, differing from the cell union by
**0.0003171 m³**; zero nonmanifold edges and zero reservation intrusions.
All **112** native foundation underside face probes meet the actual saved soil.

The runtime ground has 247 bounded partitions, 991 coalesced quads and 1,982
triangles. It omits 1,513,477 shared buried interface quads and 199,673 invisible
site-bottom quads; the source retains the closed bottom. This finite boundary
does not establish farther city or street/transit subgrade closure.

## Installed inspection, routes and measured scope

Both production imports complete through the serial lane. New foundation and
existing ground imports use the accepted precision setting; no mapping tolerance
is weakened. Production exports match the directly inspected prototype bytes.
**production-live1.log.receipt.json** passes but has no capture directory.
**production-live2.log.receipt.json** repeats with explicit production captures:
2,590 checks, zero failures, all 48 original ground stations reproduced
(46 terrain contacts and two retained embedded stations), 35 actual original-owned
city/slab underside probes, native mapping and the preserved open boiler throat.

All twelve installed views and four current saved-native renders are directly
reviewed under **tmp/city-foundations/**. Court/frontage/rear terrain joins show
continuous surfaces. The narrow **0.60 m** northwest separation is a geometry
inspection station, narrower than the **0.66 m** capsule; it is not a walking
route. The inherited west-front view enters the retained shop and is obstructed
by its counter. The isolated native rear bearing view is mostly its stem face;
these views do not establish full assembly or final weather/material acceptance.

The paired ignored prototype keeps one actual world and compares six identical
eye-height stations before/after replacement. **city-ground-cost-trial1.log.receipt.json**
and its twelve directly reviewed images record settled main-viewport observations:

| View | Draw change | Primitive change |
|---|---:|---:|
| City plinth | -8 | +948 |
| Front recess | +33 | +1,122 |
| Alley well | +6 | +558 |
| Rear alley | +99 | +1,426 |
| West court | -51 | -22 |
| Street join | +83 | +1,632 |

These counters do not measure FPS or establish a performance verdict. Existing
moving world activity and optical registration limit lighting comparisons in
post-startup prototype replacements. Installed production views govern visual
inspection. Geometry partition/culling refinement remains a measured task.

## Candidate report and remaining work

The complete clean 47-gate baseline is
**tmp/shell-readiness/4e6c498-clean-board.json**. The preliminary board preserves
all existing debt and requirement states; its single new camera reference is
individually reviewed and appended, retaining all 6,387 prior spatial records.
Final candidate results and route PASS lines belong to
**tmp/city-foundations/verified/verification.json** after the named-path commit.
Require zero regressions, NEW unread fields zero, protected 17/17, V2 default
and explicit V1 rollback, and bound alley, basement, street, bodega, keys,
composition and save/reconstruction checks. Source inventory and INERT map
updates are the only work outside the geometry/runtime/test boundary.

The owner capture bytes/absence, lamp energy 6/range 16, boiler outward door
and pipework, shop stock/hours, resident schedules, original keys/copy permission,
saved locks and Dream boundaries remain preservation requirements. Imported
legacy UID cleanup and the verifier record the final clean tree separately.

The final precommit 47-gate comparison has zero regressions and no requirement
changes, with reader NEW zero. Current source audit validates every binding,
fixture equality, all 899 unchanged masks and zero exact retained intersections.
Normal-controller precommit routes pass alley **32**, basement **88**, street
**21** and receiving **30** waypoints. The resident-key schema-2 contract passes
**84 waypoints / 55 checks**; city composition passes **1,253 checks / 450
structural contacts**, preserving two constructions, three hours states and
acoustic teardown. All **104** current precommit/native images are directly
reviewed with the stated foreground/limited-view qualifications. The earlier
incorrect receiving scene name never loaded a suite and grants no proof; the
correct **OrisonV2BodegaReceivingRouteTest** receipt completes successfully.

Still open: farther city boundary/subgrade, residual court drainage and sealing,
downstream street-main connection, roof/light-slot/weather readiness, operating
boiler glazing and independent bar/bodega/arcade services. Heating cutouts remain
parked until those shell prerequisites are met. No owner decision is currently
needed for this bounded batch; continue the wider architecture/infrastructure task.
