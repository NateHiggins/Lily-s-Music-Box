# Original neighbouring rooftop tanks

Evidence class: **INERT**

Classification: **ADAPTATION**. The immutable F01 city layout authors fourteen
active tanks as 98 pipe records: bodies, undersized cone proxies, central hoops
and four legs each. Retired end-building records are excluded by the existing
city selector. The Orison house tank and its active services remain separate.

## Source and fit

**art/data/city_tanks/source_plan.json** bounds construction. The native builder
reads the unchanged city layout and **city_shells.blend**, rederives current
registration offsets and verifies all 335 saved masses within 20 micrometres.
Original body radii/heights, relative upper leg positions and cap apex heights
remain inputs. Original positions are retained separately from fitted positions.

The original flat-top aerial records intersect nine of the original tank
placements. Fitting searches nearby positions on the same roof, in 0.1 m radial
steps, requiring complete unsnapped footplate seats and a conservative cylinder
clear of the actual saved mast/aerial edges. Five placements need no translation;
nine trial translations range from 0.3 to 2.3 m. Exact final translations belong
to **city_tanks_construction.json**. No source layout, aerial endpoints, occupied
space, actor, control, key, schedule or building service is moved or invented.
Native stock edges must subsequently pass bidirectional hardware checks.

Each 220 mm square, 12 mm plate carries four hex bolt heads and a collar.
Legs retain their relative upper attachments; actual roof faces determine their
lengths. Two bearers and four diagonal braces support a scored, closed timber
barrel with 60 mm walls/bottom and 2 mm geometric stave grooves. Braces fit clear
of existing stepped bulkheads, including short legs seated above a bulkhead.
Original central hoops retain their radii/heights; lower/upper hoops complete
the assembly. The closed 4 mm cover extends 80 mm beyond the original body,
with a short skirt reaching its underside. Fitted overhang is recorded against
the original undersized cone radius; the original apex datum is retained.

## Closed volume and maps

All source stocks are closed and positive. Each fabricated tank is one connected
material volume with an outward exterior boundary and one inward, fully contained
sealed cavity. Two boundary components are correct for this hollow construction.
Checks require consistent manifold winding, one positive exterior, one negative
cavity, positive net volume and every cavity vertex inside the exterior. They run
before and after triangulation and again after reopening. Recalculating each
boundary outward would incorrectly reverse the cavity and is avoided.

The catalogue adds **tank_staves**, a deterministic periodic straight-fibre finish:
1024 px / 1 m tile, U along the grain, 0.1 mm normal relief, independent albedo,
roughness and physical height. Geometric construction owns the board joints.
No letters, photographs, baked light or bitmap seams are present. The existing
**timber** finish and all fifteen visual locks remain unchanged. Native and runtime
maps come from the shared catalogue contract. The mast/aerial bindings are
regenerated because they bind that whole contract; their portable geometry and
pixels remain unchanged. Build masts/aerials before tanks, whose fitting binds
their saved native geometry. Runtime draws duplicate MatLib locally and retain
native metre charts, precise positions, bounded cells and identical physical faces.

## Inspection and management report

REPORT - CITY TANK FABRICATION - 2026-10-03

Branch / HEAD / origin/main / merge-base: canonical **main** candidate over
**d3fa9497d270183e56799e94d7ba386a41a15215**. Baseline is the complete clean
**tmp/city-porcelain/d3fa949-clean-board.json**. Exact candidate, counts, captures,
receipts and publication status belong to the final verification and publication
report under **tmp/city-tanks**. They are pending until those files record completed
runs. Protected 17 paths, V2 default/explicit V1 rollback, reader NEW unread zero,
47-gate comparison and unchanged ledger are required. This INERT record promotes
no requirement. Wrapper receipts and pictures are not runtime-contract proof.

Native inspection checks every stock, contained cavity, map path, bounded export,
all plate centres/corners, stock-edge crossings and convex city-mass containment.
Bidirectional checks include installed neighbouring mast/aerial surfaces. The
production suite checks actual catalogue maps, UV derivatives/tangents/metre
scale, exact physical triangle equality/world poses, bearings, clear spans and
all fourteen tank renders plus cap/foot details and paired skyline views.
Existing production composition, foundations, controller routes and resident
keys require separate verification. Renderer counts do not establish FPS or
structural capacity. In-place verification does not establish fresh-checkout behavior.

Failed drafts remain in **tmp/city-tanks**: obstructed braces; collinear Boolean
hoop tessellation; a mistaken one-boundary test for the correctly sealed cavity;
and original-placement hardware intersections. The fitted cover skirt trial
removed its oversized raised lip. No tolerance is relaxed or triangle skipped.

Open work: 25 source beacon housings, city weather/contact joints, main-roof
falls/outlets and drainage, courtyard/street closure and independent shop service
routes; broader textures, including collector bronze and public stairs/sheet metal.
Heating cuts stay parked. Owner captures and Mina's own mesh/first twenty clips
remain. Decision needed from owner: none within authorized continuation.
