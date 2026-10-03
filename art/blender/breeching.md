# Fitted boiler breeching

Evidence class: **INERT**

Rebuild **art/blender/breeching.blend** and **game/assets/props/breeching.glb**
with **art/blender/scripts/build_breeching.py** in Blender. The editable library
contains an annular one-metre pipe, a 45 mm slip band, and a six-gore right-angle
elbow with five rolled seams. Pipe radius is 170 mm, wall thickness 3 mm and
bend centreline radius 270 mm. No generated glTF is hand edited.

**orison_v2_boiler_flue.gd** fits three elbows to the actual boiler collar and
authored shaft. The lower elbow begins horizontally at the collar; tangent
straight sections rise and cross at the original overhead elevation. The
existing logical first section starts at the collar and includes that elbow.
Its body represents only the straight leg; each elbow owns matching triangle
collision. The other straight runs keep cylindrical exterior collision.
This is a service envelope, not a simulated or player-traversable gas passage.

Godot bakes the variable straight lengths into the Blender mesh positions and
metre UVs. Materials reuse the existing **cast_iron** and **metal** catalogue
bindings and local triplanar projection; no lighting or texture source changed.
Three shared elbow instances contain 12,672 triangles in total. Straight shells
and bands are small separate batches; existing boiler and chimney owners remain.

OrisonV2BreechingTest checks open mouths, the actual horizontal collar seat,
continuous walls, eighteen real bend collision contacts, straight visual/contact
agreement and unstretched transform scale. Windowed detail captures and the
production-lamp boiler route are under **tmp/breeching**. The final candidate
result and suite-run receipts belong under **tmp/breeching/verified**. These
checks do not promote runtime-contract evidence or full-building completeness.
