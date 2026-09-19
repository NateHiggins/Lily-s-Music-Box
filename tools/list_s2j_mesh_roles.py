import bpy
import os

for filename in ("cellular_interior_lod0.glb", "transmembrane_complex_lod0.glb"):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    path = os.path.join(os.environ["S2_LOD_DIR"], filename)
    bpy.ops.import_scene.gltf(filepath=path)
    print("[S2J ROLES]", filename)
    rows=[]
    for obj in bpy.context.scene.objects:
        if obj.type == "MESH":
            volume=obj.dimensions.x*obj.dimensions.y*obj.dimensions.z
            rows.append((volume,obj.name,tuple(round(x,4) for x in obj.dimensions),len(obj.data.polygons)))
    for row in sorted(rows,reverse=True): print(row)
