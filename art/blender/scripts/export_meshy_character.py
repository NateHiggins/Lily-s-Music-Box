"""Export the Meshy character to a glTF the game can load.

Meshy hands back a single dense static mesh with four 2K maps and no
armature. Two things have to be decided here rather than in Godot: how much
of that geometry a background character actually needs, and what the object
is called — the importer turns any node whose name ends in `-col` or
`-colonly` into collision, and a 200k-triangle trimesh collider standing in
the lobby would be a very expensive way to be in the way.
"""
import bpy
import os
import sys

OUT = sys.argv[sys.argv.index("--") + 1]
RATIO = float(sys.argv[sys.argv.index("--") + 2])

ob = bpy.data.objects["mesh_node"]

# Where the feet actually are, in local space, so the placement can sit the
# character ON the floor instead of guessing.
bb = [ob.matrix_world @ type(ob.location)(c) for c in ob.bound_box]
zs = [v.z for v in bb]
xs = [v.x for v in bb]
ys = [v.y for v in bb]
print("BBOX x %.3f..%.3f  y %.3f..%.3f  z %.3f..%.3f"
      % (min(xs), max(xs), min(ys), max(ys), min(zs), max(zs)))
print("TRIS before %d" % len(ob.data.polygons))

if RATIO < 1.0:
    bpy.context.view_layer.objects.active = ob
    mod = ob.modifiers.new(name="decimate", type="DECIMATE")
    mod.ratio = RATIO
    bpy.ops.object.modifier_apply(modifier=mod.name)
    print("TRIS after  %d" % len(ob.data.polygons))

# A neutral, pipeline-legal name. Nothing here should become collision.
ob.name = "lobby_placeholder"
ob.data.name = "lobby_placeholder"

os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=OUT,
    # Separate, like the building's floors — not GLB. Godot's glTF importer
    # extracts embedded textures to disk anyway and rewrites the model to
    # reference them, so a .glb ends up storing every map twice: once inside
    # the binary and once beside it. Deleting the loose copies to "save
    # space" breaks the model, which is how this was discovered.
    export_format="GLTF_SEPARATE",
    export_yup=True,
    export_apply=True,
    export_materials="EXPORT",
    export_image_format="JPEG",
    export_jpeg_quality=88,
    use_selection=False,
)
print("EXPORTED %s (%.1f MB)" % (OUT, os.path.getsize(OUT) / 1048576.0))
