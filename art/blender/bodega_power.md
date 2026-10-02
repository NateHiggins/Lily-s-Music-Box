# Bodega independent lighting supply — October 1

Evidence class: **INERT**

REPORT - V2 BODEGA POWER FABRIC - 2026-10-01

## Source and ownership

The owner's October 1 choice gives the bar, bodega and arcade independent
building services. This batch constructs the bodega's property-side lighting
intake, screwed enclosure and supported distribution to four existing fittings.
It does not establish the route beyond this building's concealed boundary.
The three original shop practicals and receiving-room practical keep their
existing bodies, light output and state owners. There is no new electrical
simulation, interactive control, lamp, stock item or task.

**bodega_services_geometry.py** derives the local datums from the registered
**exterior_geometry.json** shop floor, ceiling, right receiving partition and
three existing practical boxes. It shares the receiving-room two-metre extension
with **build_bodega_receiving.py**. **build_bodega_power.py** constructs the native
editable **bodega_power.blend** and exports **bodega_power.glb**; no glTF is edited
after export. The incoming service enclosure, four connector targets, two fabric
ports and bearing markers remain named Blender objects.

The existing **SHOP_BODEGA** resolver supplies the mounted frame to
**orison_v2_bodega_power.gd**. The helper cuts a 44 mm sleeve through the actual
160 mm receiving partition while retaining its original render node, material,
metadata and collision body. Its four box pieces replace that one wall's solid
shape. All other shop surfaces, thresholds and actors retain their owners.
The receiving generator gives its existing combined back-wall partition the
second 44 mm intake bore. It still exports six receiving material partitions;
the accepted bench, floor, fixture stem and doorway remain.

## Fabrication and mapping

The blank cast-iron service enclosure measures 280 by 400 by 120 mm. A screwed
cover and shallow wall flange seat it on the receiving back wall. Four wall
fasteners, two screwed wall saddles and eighteen ceiling bearings support the
lighting intake/rise, main and four branches. Ceiling intervals are at most
1.15 m. The main follows local X **1.6875 m** at Y **3.10 m** beneath the original
**3.15 m** ceiling; the sales-room wall crossing clears both the original door
opening and its moving volume.

Hollow 18 mm steel conduit, threaded sockets, cast junction enclosures and
sleeves retain their physical radii. The receiving connector enters the side
of its existing ceiling casting; the three sales-room drops enter the original
practical bodies. Small fixings use solid eight-sided shafts, and the conduit
uses sixteen sides. Three shared material draws use existing MatLib **metal**,
**cast_iron** and **brass_dull**; no material key or texture is added.

Worked faces use a single active metre UV channel with stable planar orientation.
The initial normalized cube UV channel was removed. The bundled Blender exporter
flips UV V while retaining its native bitangent sign; this generator corrects
that sign in Blender's official pre-serialization hook. The independent exported
triangle derivative check verifies direction and handedness in all three groups.
The committed import metadata preserves vertex precision for the small fittings.
No global shader, material calibration or lighting change is involved.

## Inspection, checks and costs

Before player-height discovery is **tmp/bodega-power/before**, with its bound
wrapper **before.log.receipt.json**. The matching after views show the service
wall, partition crossing, shop distribution and front fitting. Every released
view must be inspected directly. The first failed production run and subsequent
mapping failures remain under **tmp/bodega-power**; they are not acceptance.

**power-flange.log.receipt.json** binds the enclosure mounting production run:
**89 checks**, four fitting connections, twenty conduit bearings, four enclosure
mounts, three draws and **9,556 triangles**, zero failures before the final
service-rise junction enclosure. Its four matched
**after-flange** views were inspected directly. The check verifies original fitting contacts, actual physics
through both fabric bores and retained walls beside them, twenty conduit bearing
contacts, four enclosure fixing contacts, catalogue materials, imported metric
UVs, normals and tangent derivatives. Existing light and interactive authority
must remain unchanged. The bodega receiving walk, city composition and apartment
lifetime checks bind the final candidate separately. Wrapper receipts and images
grant no completeness-ledger or runtime-contract status.

The first export had **24,552** triangles. Using solid fasteners and sixteen-sided
conduit reduced the intermediate assembly to **9,288** triangles with **81** focused
checks and zero failures. The finished enclosure flange and wall fasteners bring
that assembly to **9,556** triangles. Final release byte sizes and the
service-rise junction binding belong to the candidate run. The fitted receiving source is **117,843 bytes**, GLB
**123,964 bytes**, compared with **116,004 / 109,344** before the rear bore.
The power GLB retains twenty-four bearing marker nodes and the port/fitting
datums; these add no draws or simulation. Startup samples are **19,533.354 ms**
before and **19,045.651 ms** after, not stable frame-rate measurements or a
performance acceptance claim.

## Binding and remaining work

The complete clean baseline is **tmp/roof-throats/72b3033-clean-board.json** at
**72b3033117058f17c480bb43092e510c79de7b8e**. Candidate checks belong to
**tmp/bodega-power/verified/verification.json** and must pass before publication.
Require zero new unread fields, zero static regressions, all seventeen protected
paths, V2 default/V1 rollback and unchanged owner capture bytes/absences.

**route.log.receipt.json** records the existing thirty-waypoint public/store/
receiving/return walk with zero failures: both doors use normal input, the leaf
closes and reopens from inside, and the shared stock/job owners remain. The
complete forty-five-gate precommit board has zero regressions, reader NEW **0**,
no new spatial references and unchanged systemic/ledger counts. The final
candidate repeats the geometry, route, composition and lifetime checks.

Raw architecture, infrastructure, mapping preparation and final material polish
remain separate states. This lighting branch does not finish the bodega's heat,
water, drain, other apparatus feeds or communications, or the independent bar
and arcade networks. Concealed service continuation beyond the property-side
intake remains unverified. Continue the shared register and six location queues.
