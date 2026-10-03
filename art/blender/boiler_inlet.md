# Retained steam inlet: structural crossings and open equalizer tee

Evidence class: **INERT**

The installed steam feed crossed solid boiler-room and approach walls and
ended inside the solid heat-chase reservation. Its independent equalizer
pieces also left an internal ring and side wall across the steam bore.
This batch opens those bounded crossings, fits steel to their actual seats,
and opens the hidden tee without moving the installed pipe route or controls.
Distribution beyond the receiver remains open work.

## Sources, ownership and construction

**art/data/orison_v2/boiler_inlet_source.json** owns two room-wall apertures
and one receiver cavity in **HEAT_STACK**. **tools/build_v2_boiler_inlet.py**
projects only those heat records into the shared wall/chase tables. Its three
tests preserve independent owners, round-trip formatting and idempotence,
reject foreign/duplicate records, and commute with ventilation regeneration.
The ventilation fabric test still requires all **67** ventilation wall ports;
it now counts that owner's roster within the shared table, which also admits
the two new heat ports. No ventilation aperture or other owner is replaced.

The **200 mm** square cuts follow the existing **156 mm** steam pipe. Three
**2 mm** steel linings retain **196 mm** internal square clearance. Five
**248 mm** bearing plates have **170 mm** circular openings and twenty fixed
hex bolts. Plates seat **2.5 mm** inside the real fabric and show **1.5 mm**
outside it. The existing west-wall escutcheon remains **0.5 mm** clear of the
new plate. Its pipe, socket bands and three original ceiling hangers remain
in place. The receiver lining covers its first **80 mm**; the bounded cavity
admits the retained mouth without claiming a finished vertical distribution.

**scripts/build_boiler_inlet.py** retains **57** editable native solids and a
welded export preview. Local mesh coordinates around the inlet avoid the
Boolean precision faults seen in the first global-coordinate construction.
The final union has **zero** nonmanifold edges. The generator triangulates
and removes submicrometre degeneracies before assigning metre UVs and
correcting exported tangent handedness. **boiler_inlet.blend** is **261,905**
bytes; its GLB is **615,648** bytes, **5,560** triangles and one material draw.
The existing **metal** material is reused. No bitmap, material key, state,
light or interactive control is added. Precision-controlled import metadata
and binary attributes are committed with the native source and export.

**scripts/build_boiler_pipework.py** now subtracts only the two internal
tee lumens. The smaller lumen opens the equalizer through the parent steam
wall; the larger removes the redundant hidden ring inside the takeoff.
The permanent boiler boss remains the deliberate upstream receptor boundary.
Native comparison against the clean baseline finds **62** unchanged source
objects. Only the steam straight, equalizer straight and wholly hidden socket
change geometry; every added/removed vertex lies within the two internal
cutter volumes, using **1 micrometre** coordinate quantization and a
**3 micrometre** boundary allowance. **native-invariance.json** and its Blender
log record the comparison. Local edited tee surfaces receive metre mapping.
The installed source route, external silhouettes, supports, visible sockets,
equalizer/discharge endpoints and mechanism authority are retained.

The two original pipe meshes now contain **26,028** triangles and the GLB is
**1,669,644** bytes. Combined with the fitted inlet, the existing helper mounts
three draws and three matching triangle-collision bodies. A body takes its
draw's complete relative transform; its shape stays at that body's origin.
**BoilerProp**, BoilerTend, HeatBalance, the **23** demand records and **18**
installed radiators retain state authority. The V1 path and rollback remain.

## Inspection and limits

**tmp/boiler-inlet/focused-10.log.receipt.json** records the passing focused
production check: **167** checks, three retained straight legs, **32** elbow
chords and one equalizer tee leg. **324** live-physics samples cover the main
**136 mm** sampled bore and smaller **56 mm** tee bore. Actual imported
triangles independently check every lumen volume, with **zero** obstructions.
Straight volumes stop at the source receptor boundary instead of expanding
back into the permanent boss. This does not omit a downstream wall or pipe.
All **40** plate-perimeter stations meet actual structural triangles and live
collision, and all **20** bolt heads meet their own exported collision.
Imported normals, UVs, tangent directions and handedness pass unchanged
mapping tolerances. **19,467.640 ms** is a single startup observation.

The earlier focused runs remain in the same directory. They expose native
degeneracies, short-ray misses and the original tee obstruction; they are not
passing evidence. A **2 m** bolt ray still requires the first contact within
**20 micrometres** of the exported head, **15 mm** from its start. Godot's
[segment/triangle implementation](https://raw.githubusercontent.com/godotengine/godot/master/core/math/geometry_3d.h)
uses segment length in its determinant. The longer query avoids tiny-face
rejection while preserving the required contact and owner; collision flags
and imported surfaces are not relaxed.

Three player-height inlet views and one explicitly internal receiver view
are captured and directly inspected. The internal view is construction
inspection, not walking proof. New views use existing scene lighting and the
retained carried lamp, energy **6**, range **16**, with no fill or global change.
The production lighting is very warm and the small plates blend into the
surrounding finishes; final render/material polish is not accepted here.
The retained pipework regression passes **7** contacts and three moving draft
settings; its original inspection-fill fixture is unchanged. Normal boiler,
basement, hot-water, radiator and resident-key routes require the final bound
regression checks.

## Candidate binding and continuation

The clean comparison baseline is **tmp/vent-wall-ports/bfaeb9d-clean-board.json**
at published **bfaeb9d15b4ee763ffab43075980679429bca06b**, with **46** gates.
The new projection suite adds one gate.
The initial board's added authority review was a heuristic match on the word
**proof** and the existing adapter's anchor lookup. The header now names this
scope as construction inspection; no actor consequence is invoked, no check
is removed and the authority baseline remains unchanged. Complete boards,
protected-path,
reader and candidate-bound runtime checks must pass before publication;
their final results belong under **tmp/boiler-inlet/verified**. This note,
captures and wrapper receipts grant no runtime-contract or ledger promotion.
In-place verification does not prove fresh-checkout/autocrlf behavior.

Published candidate **e93b9c25dc4e439a75222c0e89efe326b07f0848** passes the
complete **47**-gate comparison with zero regressions, zero new unread fields,
unchanged completeness counts and all **17** protected paths. The four newly
registered spatial references and three owner-preservation projection tests
are reviewed; no audit baseline or classifier is weakened.
**tmp/boiler-inlet/verified/verification.json** records two completed imports
and eleven successful binding windowed suites: inlet, retained pipework, boiler
body, outward door movement, boiler service route, basement circuit, ventilation
fabric, apartment batch, hot water, resident-key route and city composition.
The actual clean candidate board is retained as
**tmp/boiler-inlet/e93b9c2-clean-board.json**. The key test writes its own
schema-2 contract; the new construction test makes no actor-consequence claim.

The final candidate's four inlet frames and original production-lamp pipework
view are directly inspected. Because this verifier's output argument was
relative, captures are under **game/tmp/boiler-inlet/verified/godot**; log and
verification files remain under **tmp/boiler-inlet/verified**. Their paths and
scope are retained in **tmp/boiler-inlet/validation-index.json**. The owner's
capture log retains SHA-256 **1C97D690FD73325B00AE1F7AE84311BDDD42DBD25BC10AE417830C8E3EF03525**,
and the five owner-removed images remain absent. Only the 259 untracked
import-generated legacy UIDs are removed after verification.

Continue the four physical heat risers and pitched routes to the eighteen
actual installed feeds. The first draft's straight runs crossed unoccupied
gaps and door trim; revised routes need rendered geometry, stair/headroom,
support, expansion and access inspection before authoring. The first-floor
west feed also needs a supported route beyond the excavated basement, rather
than an exposed pipe outside the enclosure or a condensate-trapping overhead
supply. Do not reuse the legacy simulation-budget coordinates as installation
positions. Keep heating, water/drainage, ventilation support/access, power,
lift, communications/delivery and independent bar/shop services open until
their source-to-endpoint construction and relevant routes are verified.
