# V2 floor and ceiling surface ownership

Production storeys share a 200 mm slab: the ceiling box of the lower room and
floor box of the upper room occupy the same vertical interval. Rendering all
six faces of both boxes made ceiling plaster appear at the upper walking
surface, competing with the flooring as the camera moved.

The blockout builder now partitions rendering by face. Floors and platforms
retain their top and edge faces; ceilings retain only their downward face.
BoxMesh UVs, normals and tangents are preserved in the derived ArrayMesh.
The original full BoxShape3D floor collision, positions and dimensions remain
unchanged. Standalone review blockouts retain the original box representation.

OrisonV2FloorSurfaceTest checks the actual composed floor/ceiling triangles and
raycasts each retained floor body at its authored walking height. Individually
identified furnishings above the probe point are excluded from that floor-only
query. Windowed captures cover occupied rooms on three successive storeys.
The existing vertical route exercises production movement and stairs separately.
