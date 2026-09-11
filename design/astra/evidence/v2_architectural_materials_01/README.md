# Apply architectural materials to the playable V2 world

Base c604a9d. Owner reported that materials did not appear applied. Inspection
confirmed that V2's architecture still used the blockout palette. Individual
props had materials, but that was not whole-room material integration.

The runtime now explicitly enables architectural materials on the semantic
geometry builder. Standalone review/blockout scenes keep their palette. Seven
architectural keys were added to the existing runtime material generator,
using catalog texture identity and physical scale: stained plaster, oak floor,
ceramic, subway tile, concrete, terrazzo and stair stone. Generated manifests
and GDScript were regenerated; all previous material records remain unchanged.
The unshipped plain-plaster albedo/roughness pair was rejected by the generator;
the integration uses the available catalogued stained-plaster family instead.

The architectural resolver assigns floors by room class, plaster or tile to
walls, painted trim to ceilings/frames, wood to door leaves, stone to steps,
metal to guards and the existing lamp glass shader to glazing. Opaque surfaces
consume the established SurfacePass recipes with triplanar projection at the
catalogue scale. Material instances are cached; no new surface geometry or
collision is introduced. This is a semantic base assignment, not final
per-room material/art direction or performance acceptance.

Playable V2 also suppresses the obsolete BedHomeContext, its demonstration
light and the nearby route band. The schematic bed was overlapping the real
furnished bed. Standalone readability review retains those defaults.

run_01: actual earned Dream/V2 reconstruction passes 46 checks, including
albedo/normal/roughness bindings, expected material families, no duplicate bed,
the east enclosure, facing direction, eight ordinary wake/switch waypoints,
lifetime and disk reload. 1,057 architectural meshes carry material bindings;
all checked opaque surfaces have actual maps. Stderr is empty.

The actual wake image was inspected. It confirms the placeholder is gone and
glazing no longer renders as an opaque panel, but the room is too dark for
adequate material review after removing its demonstration light. An explicit
WAKE_FIXTURE diagnostic was added for power, energy, budget scale, world
position and active floor. run_02 was refused before launch by the serial
runner while foreign Godot tests were active. That diagnostic remains pending;
do not call the lighting or the material appearance approved.

Next: rerun OrisonV2EarnedDreamBoundaryTest through the unchanged serial runner
with the prior earned Dream-pending save; inspect WAKE_FIXTURE, correct the
real room-light issue and review materials under usable light. Then resume
OrisonV2PlayedDreamTest. V2 remains unfinished and V1 remains default.
