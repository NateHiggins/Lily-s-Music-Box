# Service-bulkhead roof cover and rainwater fittings

Evidence class: **INERT**

## Current fitted toe, 2026-10-04

The upper cover, gutter outlet and original wall supports remain geometrically
unchanged. The leader toe now ends at **19.2739 m**, 25 mm above the fitted
flashing at **19.2489 m**; the original floor body's physical field backs it at
**19.2477 m**. Current runtime has **6** partitions and **4,752** native
triangles. The editable builder trims its gutter from the immutable retained
native snapshot so rebuilding cannot progressively trim away its outlet.
Current assembly details are in **roof_drainage.md**. The text below records
the earlier flat-deck toe and its superseded counts and contact heights.

## Historical flat-deck installation

The actual production roof discovery found a flat concrete cap on
**ROOF_SERVICE_CORE**, with no weather finish or runoff route. This bounded
assembly adds a tapered bearing, galvanized sheet cover, folded perimeter
returns, half-round gutter and external open rainleader. The original cap,
interior ceiling, wall, roof deck, stair and door ownership stays in place.
It is an **ADAPTATION** construction recipe; no hydraulic or structural
capacity calculation, complete weather seal or live water control is claimed.

## Sources and fixed construction

**art/data/roof_service_weather/source_plan.json** owns adaptation dimensions.
**scripts/build_roof_service_weathering.py** derives the cap from the actual
roof-source room and blockout dimensions, checks that their projection agrees,
and emits **roof_service_weathering.blend**, its construction JSON,
**game/assets/props/roof_service_weathering.glb** and the portable test fixture.
Source hashes use LF-normalized UTF-8. Hash-bound files are marked **-text**.
Generated glTF is never hand-edited; no reference photograph is committed.

The retained cap top is **22.4 m**. Its bearing toe is **3 mm** and the sheet
roof falls **1% east**; galvanized sheet is **1.2 mm**. Flush solder strips
replace the sheet margins without overlapping or making transverse water dams.
Three folded upstands cover the cap edges; the east apron feeds a **50 mm
radius** gutter. The gutter falls **0.5% toward Z 10.08 m** from both ends.
Its actual outlet is united with the **76.2 mm bore** leader and trimmed to
the inside bowl, removing the original prototype's raised annular obstruction.
The leader has three fitted wall plates/straps; the gutter has rigid brackets.

The leader ends at **19.225 m**, 25 mm above the retained **19.2 m** east deck.
Main-roof drainage and the downstream property connection remain **OPEN**.
The October 3 base-flashing batch adds a 1.2 mm fitted foot below this outlet.
The first-contact ray now requires that foot, with a separate query verifying
the retained deck beneath it; see **roof_base_flashings.md**.
This assembly adds no second maintenance simulation or fictional live control.

The saved source retains **140 closed positive construction pieces**, including
closed counterparts of the bearing wedges. Runtime omits only those wedges'
shared cap-contact bottoms. Six export partitions contain **4,546 triangles**,
bounded to four metres on every axis, with no new internal partition caps.
Five-micrometre conditioning removes Boolean/triangulation degeneracies before
the generator rechecks closure. Per-face orthonormal metre UVs and generated
tangents preserve curved and sloped surface scale. Existing **metal** and
**concrete** keys resolve through MatLib; no texture or global light changes.
Full-precision import is required for thin folded sheets and the open throat.

## Installed inspection and walking

**orison_v2_roof_service_weathering.gd** mounts once after **RoofBulkheadCaps**
in the composed production root. Six fixed triangle bodies match the native
draw geometry. The focused production test measures exact first sheet contacts,
retained original cap contacts, three real wall seats, four bore directions,
gutter falls and an unobstructed outlet using imported triangles and physics.
The cap test retains all original eighteen stations, twenty-four wall bearings,
underside probes and tolerances. It excludes only the new cover's bodies when
checking the original concrete interface beneath that cover; the independent
weather test checks first physical contacts without that exclusion.

The first production run at **tmp/shell-weather/production-weather.log.receipt.json**
failed eleven checks because the initial Godot import compressed thin geometry.
The configured full-precision import preserves this failed receipt separately.
**production2-weather.log.receipt.json** passes **68 checks**, nine roof contacts,
nine retained cap contacts, three wall bearings, open bore and outlet, zero
failures. **production2-caps.log.receipt.json** passes all **210 checks**.
Final current-source route and candidate results are recorded by their own
receipts; these wrapper runs and INERT captures grant no ledger promotion.

**tmp/shell-weather/production-native/native-inspection.json** reopens the saved
native source, binds its SHA-256, verifies all 140 closed positive pieces and
the actual bore/outlet, and renders two directly reviewed views. Studio material,
camera and lighting changes are never saved back into construction. The nineteen
final prototype frames are directly reviewed; roof route views include the
existing radiophone foreground. Five installed close/elevated/player-height
diagnostic frames are directly reviewed. Independent normal-controller routes
record **51 roof** and **79 vertical** waypoints without failures. The resident
key schema-2 contract passes **84 waypoints / 55 checks**, including reconstruction
and teardown. All **46 production2 frames** and both saved-native renders are
directly reviewed. Elevated inspection does not substitute for walking.

The physical addition costs six fixed meshes, six triangle bodies and 4,546
triangles; the test also records five current render-counter observations and
startup timing. These counters do not establish frame-rate or lighting-budget
acceptance. The metal's production-lamp response and final weather materials
remain part of the separate broad surface pass.

## Gates and unfinished shell work

The genuine clean baseline is **tmp/city-foundations/656f7c7-clean-board.json**.
One individually reviewed generated collision-name contract is appended to the
spatial manifest while all **6388** prior records and audit logic remain.
The final candidate verifier must compare all 47 gates, enforce NEW unread zero,
retain all 17 protected paths and V2 default/explicit V1 rollback, and bind the
weather/cap, roof, vertical, resident-key, city composition and reconstruction
suites. Final proof belongs to **tmp/shell-weather/service-roof-verified/verification.json**.

Roof discovery also confirms the Bible-required lobby-to-skylight light court is
missing: the V2 public core has a closed cap and only a 300 mm stair eye. The
working design assumption is to fit a usable light court inside the existing
public core; it is not installed or accepted by this service-roof batch. Public
stairs, landings, clearances, source roof opening and skylight require separate
source projection, native fabrication and normal-controller verification.
Main-roof falls/outlets, residual court drainage, property/street connection,
operating boiler glazing, farther city closure and independent shop services
remain open. Heating cutouts remain parked until shell prerequisites are met.
Raw architecture, full infrastructure and final material polish are unfinished.
