Evidence class: INERT. Native cast refinement and scoped diagnostics.

The source builder now regenerates the two cast stocks: a 48-segment,
24-ring header/column casting with 1.2 mm junction radii, and a 64-sided shoe
with a shape-preserving curved profile. The 92 mm section pitch, 230 mm depth
envelope, 670 mm casting height, 105 mm shoe bearing, port centres and bores
are retained. The builder checks closed positive solids, open pressure paths,
outside convection paths, finite charts and unchanged geometry for every
other source object. New contours are geometry rather than a normal-strength
adjustment. The registered oxide finish from cast_surface is retained.

The first build encountered empty Boolean-generated material slots. Clearing
those before restoring the retained slots fixed it. The second exported a
shoe mesh with an automatic .001 suffix because its retired mesh occupied
the name. Retiring that unused mesh before export restored exact stock names.
Both failed logs are retained. A native preview also exposed smooth cap
shading that did not match the export policy; native and export now use the
same triangulation and manufactured-stock corner normals.

UV review found severe local distortion despite correct global chart area.
The final casting repairs 176 local triangle charts, retaining the sound
continuous unwrap elsewhere. Every final native triangle has physical chart
scale between 0.7533 and 1.3119. Shoe charts require no local repair, ranging
from 0.7981 to 1.0954. The original uncorrected range reached 51.87 on a few
small casting faces, so that intermediate version was not installed.

The final prepared GLB passes strict derivative/handedness checks on 125,312
triangles. Seventeen retained stock buffers, material identities, indices,
all packing morph attributes and every node frame match the preceding GLB.
Only the casting and shoe buffers are allowed to change. Native fit passes
1,486 checks against real shoe/floor seats, retainer travel and all 46 surveyed
wall ties. These are native diagnostics, not runtime controls or collision
route proof.

Both final header and shoe views were individually reviewed under diffuse
and grazing light. The curved foot loses the former abrupt angular shoulder
and visibly faceted flange. Header contours and small junction radii are
finer; additional cast and machined detail can still be improved. The final
shoe buffer is unchanged by the local casting-chart repair, so its two final
native views are reused. Earlier header and normal-only trials remain in
their original packets.

The two native stocks are installed locally. The import wrapper completes
with exit 0 and no script errors. cast_detail_world_named completes with exit
0, reporting 653 checks and zero failures: all 23 installed actors, imported
UVs/PBR/loaded complete mip chains on the representative rig, retained real
grab/move/release gestures, static inspection and household settings capture.
Seven room/detail frames were individually viewed, including the actual
headers and shoe framed from the moving body's count and transform.

The first world attempt had a duplicate local variable in the new capture
code and never ran the suite. Only its two verified Godot processes were
stopped; its terminal -1 receipt is retained. Renaming that local fixed the
parse error. No other project's Godot was interrupted.

The composed harness inspects loaded buffers/maps in the already-built world,
avoiding a second native-review Godot launch. These captures and suite_run
receipts do not constitute a test-written runtime_contract, disk restore or
broad V2 qualification. Seven Texture RIDs are still warned at teardown;
cause and baseline comparison remain unresolved.

Packing/vent physical service, continuous pitch handling, repair completion,
custody edge cases, disk reconstruction, broad qualification, teardown and
human visual acceptance remain open. This is not an integration candidate or
completion of the V2 goal.
