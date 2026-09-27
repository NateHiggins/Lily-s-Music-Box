# V2 stair ironwork

Evidence class: **INERT**

Production outer stair guards use two shared Blender assemblies, fitted to the
public and service stair schedules. Fourteen placements cover both cores from
basement to roof. The review blockout retains its original opaque guards.

Run Blender in background with `-P art/blender/scripts/build_stair_ironwork.py`.
It rebuilds the two adjacent `.blend` sources and corresponding GLBs under
`game/assets/props`. No generated glTF is edited by hand.

Forged posts, socket feet, fixing rivets, collars and timber handrails replace
the opaque guard strips. Each assembly has three material meshes, bound to
existing catalogue keys: cast_iron, wood_dark and steel. Thirty-seven support
markers expose tread and landing bearing points to the geometry test.

The runtime mount accepts only the authored width, tread, rise, landing, gap,
guard height and riser count. A changed stair schedule requires rebuilding its
assembly. Steps, traversal ramps, walls and landings retain collision authority;
the decorative rails add no fall-blocking collision. Inner stair edges and
underside structural detailing remain outside this batch.

`StairIronworkTest` checks all placements, material names, hidden review guards,
and physical support beneath each post. Its four windowed camera stations are
inspection views with a neutral fill light and the carried device hidden; they
do not establish walking or normal lamp appearance. `OrisonV2VerticalRouteTest`
separately exercises actual player movement on the production stairs. Run logs
and wrapper receipts are under `tmp/stair-ironwork`; this note does not promote
completeness-ledger requirements or constitute runtime-contract evidence.
