# Orison bounded ground and alley well

Evidence class: **INERT**

This construction report grants no runtime-contract or completeness promotion.
Raw architecture, full infrastructure and final material polish remain open.
Heating-distribution cutouts remain parked until shell readiness is established.

## Problem and source ownership

The accepted front public slab no longer overlapped five occupied floors, but
adjacent court surfaces still ended above empty space. The old alley's solid
substrate covered the existing basement boiler window at Y -0.30 m, and the
three drain grates exposed closed iron beds. Those were real missing connections.
The boiler opening keeps its original X **15.58..15.93 m** reveal, Z **2.6..3.8 m**
width and Y **-1.8..-0.8 m** sill/head; no window is enlarged.

The original **service_alley.blend** and its generator remain the source for
the accepted masonry, coping, lamp supports and original paving dimensions.
The new **build_alley_groundworks.py** reads that source and the canonical V2
layout. The existing ServiceAlley module replaces only its old Paving and Iron
draws/colliders with **alley_groundworks.blend/glb**. Brick, Coping, four cage
lamps, rear DoorProp input and save authority retain their owners.

The separate **orison_ground.blend/glb** mounts once under the registered V2
blockout as Ground. Its bounded region is X **-25.78..20.30 m**, Z
**-16.605..16.245 m**, with bottom **-4 m** and the original court asphalt top
**-0.02 m**. The accepted front slab, floors, basement roofs, footings, service
shafts and original alley substrate retain their volumes. Neighbor plinths and
the broader street/terrain continuation are separate unfinished interfaces.

## Rebuild and source map

Run these Blender scripts in order from the canonical checkout:

1. **art/blender/scripts/build_alley_groundworks.py**
2. **art/blender/scripts/export_alley_groundworks_reservations.py**
3. **art/blender/scripts/build_orison_ground.py**

Each saves editable native source and regenerates its glTF; glTF is never
hand-edited. Both builders emit the matching test construction fixture.
The ground builder also writes an ignored native-cell diagnostic under
**tmp/orison-ground**; that file is reproducible output, not a required source.

**art/data/orison_ground/retained_grade_source.json** is a classified geometry
authoring map captured from the inspected **118d770** sources and active
registered collision. It carries 899 retained component/clearance masks and
47 occupation/reservation masks. Exact original boxes, saved union components,
actual aligned collision boxes and worked-arris clearance bounds retain their
separate meanings. A complex mesh bounding box is never called an exact solid.
The generator validates LF-normalized text/raw binary dependency hashes and
refuses stale owners. Reconcile this map when a bound owner changes; do not
silently reuse it against a new layout. It stores no live gameplay or save state.

The fresh alley export supplies 30 further construction/air/pipe reservations:
the well walls and air, three catches, a small collector trench, four legs and
20 saddle beds. Actual well-wall undersides are **-2.45 m** and actual saddle
bottoms seat on remaining soil. Existing reveal air is reserved through the
complete masonry span, preventing the soil plug found in the second trial.

## Fabrication and mapping

The paving falls toward the three original catch positions. The well has three
concrete sides, a falling floor with an open outlet and two supported iron grate
panels. The retained outer masonry forms its fourth side. The new well grate is
crossed in both directions with the unchanged capsule and controller.

The cast-iron collector is an **ADAPTATION** construction recipe: a hollow
152.4 mm bore with four hollow 101.6 mm branches, bell joints and 20 fitted
concrete saddle beds. Its local axis falls 0.005 toward the public slab boundary.
Outer and inner Boolean unions give continuous pipe walls and air passages.
The property end has a bolted construction blank. The downstream street-main
connection must replace that blank before drainage infrastructure is complete.
There is no added flow simulation or fictional live control.

All 277 editable alley pieces reopen with positive closed volume and zero
nonmanifold edges. Exports contain 32 four-metre partitions / 33,992 triangles.
The ground's closed editable union has zero nonmanifold edges, approximately
4,184.510235 cubic metres, and clears all 976 masks. Its 198 bounded material
parts contain 982 coalesced quads / 1,964 triangles; 552,726 buried exact-owner
interface quads are omitted. Zero-area edge contacts preserve coordinates and
volume while separating coincident topological surface fans.

Meshes use explicit metre UVs, material assignments and precision imports.
The alley exporter derives planar tangents from its authored charts, correcting
Mikk fallback on long narrow Boolean facets. The existing strict imported
UV/normal/tangent derivative checker remains unchanged and passes. No global
Blender exporter, Godot test tolerance, camera height or capsule is altered.
**asphalt** is admitted through the existing catalogue runtime-policy generator:
three existing maps, their authored **2.5 m** scale, no new visual lock. Soil,
concrete and iron reuse their catalogue keys; these assemblies use their UVs.

## Scoped inspection and route evidence

All paths below are ignored local evidence, with no runtime-contract claim.
The two approved production imports finish successfully with empty stderr.
**groundworks-production-ground1.log.receipt.json** reports 1,535 checks,
46 new terrain contacts, two retained embedded-masonry stations and exact
reproduction of all 48 original discovery results when new ground is excluded.
None of those stations is moved. Nine production frames are directly reviewed.
The visible neighbor/plinth void remains an open finding.

**groundworks-production-alley1.log.receipt.json** reports 195 strict mapping
checks, 32 normal-controller waypoints and zero failures. It preserves the
inherited 25-waypoint rear-door/street/front-threshold round trip, seven original
ground contacts and 12 closed storey-band contacts, then adds seven well-crossing
waypoints. Four actual outlet rays, the axial collector bore and original boiler
throat are clear. The combined prototype basement run also passes 88 waypoints
and the unchanged existing door/service checks, with empty stderr. Current
candidate route receipts must bind the installed source separately.

The saved production Blender ground and six alley renders are inspected without
saving studio changes. Fresh native runoff discovery samples 48,817 actual
surface stations at 50 mm spacing plus the exact low line/receiver centres:
all reach one of four receivers; none is missing or stranded. This is a geometric
discovery result. Joint-scale sealing, drainage capacity and downstream operation
are not established by that grid.

The paired prototype view observations retain the published composition as
their before source, under **groundworks-cost-trial1/groundworks-cost.json**:

| Normal-height view | Change in visible draws | Change in primitives |
|---|---:|---:|
| Front recess | +155 | +7,599 |
| Alley well | +48 | +4,517 |
| Rear alley | +31 | +4,745 |
| West court | +83 | +372 |
| Street join | +127 | +17,872 |

These are settled main-viewport geometry observations in the same world, not
a frame-rate or performance acceptance verdict. Installed ground inspection
also records matched shown/hidden costs for each of its nine views. Existing
moving world/lighting activity limits attribution of total composed counters.

## Batch verification and open work

The complete clean baseline is **tmp/front-pavement/118d770-clean-board.json**.
The candidate verifier must compare all 47 gates, preserve the 17 protected
paths and V2 default/explicit V1 rollback, require NEW unread fields **0**, lint
the changed design map and bind the installed opening, basement, vertical,
street, receiving, paving and resident-key suites. Its final result belongs to
**tmp/shell-readiness/groundworks-verified/verification.json** after the named-path
commit. The first preflight's four new spatial findings are individually reviewed
test references; only those four are appended, preserving all 6,383 old records.
Known baseline tool-test debt is retained; no gate or verifier is weakened.

The owner capture files retain their existing exact bytes/absence and are never
staged. The boiler swing, pipework, lamp energy/range, hours, stock, schedules,
Dream boundary, original keys/copy permission and saved locks remain preserved.

Still open: downstream street main, all residual courtyard falls/outlets, original
3 mm paving-joint sealing, boiler-window operating glazing, full neighbor plinths
and terrain joins, roof/weather/light-slot readiness and the remaining independent
bodega/arcade/bar utility routes. Raw architecture and infrastructure across the
six location buckets remain unfinished. No owner decision is needed for this
bounded construction batch; continue the dependency queues after verification.
