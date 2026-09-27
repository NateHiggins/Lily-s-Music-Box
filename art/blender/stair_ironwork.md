# V2 stair ironwork

Evidence class: **INERT**

Production outer stair guards use two shared Blender assemblies, fitted to the
public and service stair schedules. Fourteen placements cover both cores from
basement to roof. The review blockout retains its original opaque guards.

Run Blender in background with `-P art/blender/scripts/build_stair_ironwork.py`.
It rebuilds the two adjacent `.blend` sources and corresponding GLBs under
`game/assets/props`. No generated glTF is edited by hand.

Forged posts, socket feet, fixing rivets, collars and timber handrails replace
the opaque guard strips. Three rail meshes bind to existing catalogue keys:
cast_iron, wood_dark and steel. Thirty-seven support markers expose tread and
landing bearing points to the geometry test.

The second batch adds a fourth mesh for the understructure: paired notched iron
stringers, a cross-bearer beneath each tread and two landing beams. Stringer
notches embed 12 mm into the existing tread underside; forty bearing markers
let the test query the real tread collision. The continuous lower edges make
the construction visible from below without filling the stair volume solid.

The runtime mount accepts only the authored width, tread, rise, landing, gap,
guard height and riser count. A changed stair schedule requires rebuilding its
assembly. Steps, traversal ramps, walls and landings retain collision authority;
the decorative rails add no fall-blocking collision. Inner-edge guards remain
unfinished. This is visual construction, not a structural engineering analysis.

`StairIronworkTest` checks all placements, material names, hidden review guards,
and physical support beneath each post and above each stringer bearing. It also
checks imported structural vertices remain in the half-metre envelope beneath
walking surfaces, preserving over 2.3 metres between stacked envelopes. This
does not claim clearance for every unrelated object in the stairwell.
Its six windowed camera stations are
inspection views with a neutral fill light and the carried device hidden; they
do not establish walking or normal lamp appearance. `OrisonV2VerticalRouteTest`
separately exercises actual player movement on the production stairs. Run logs
and wrapper receipts for the understructure are under `tmp/stair-structure`;
the earlier rail batch is under `tmp/stair-ironwork`. This note does not promote
completeness-ledger requirements or constitute runtime-contract evidence.
