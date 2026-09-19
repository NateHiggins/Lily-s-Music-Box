import bpy
import bmesh
import glob
import os


root = os.environ["S2_LOD_DIR"]
for filepath in sorted(glob.glob(os.path.join(root, "*.glb"))):
    basename = os.path.basename(filepath)
    if not basename.startswith("transmembrane_complex_lod"):
        continue
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=filepath)
    repairs = 0
    for obj in [item for item in bpy.context.scene.objects if item.type == "MESH"]:
        mesh = obj.data
        bm = bmesh.new()
        bm.from_mesh(mesh)
        before = len(bm.faces)
        bmesh.ops.triangulate(bm, faces=list(bm.faces), quad_method="BEAUTY", ngon_method="BEAUTY")
        relative_epsilon = max(obj.dimensions.length_squared * 1.0e-14, 1.0e-20)
        zero_area = [face for face in bm.faces if face.calc_area() < relative_epsilon]
        if zero_area:
            bmesh.ops.delete(bm, geom=zero_area, context="FACES")
        repairs += abs(before - len(bm.faces))
        bm.normal_update()
        bm.to_mesh(mesh)
        mesh.update()
        bm.free()
    bpy.ops.export_scene.gltf(
        filepath=filepath,
        export_format="GLB",
        use_selection=False,
        export_apply=True,
        export_normals=True,
        export_tangents=False,
        export_materials="EXPORT",
    )
    print("[S2I REPAIR] %s bounded_face_repairs=%d" % (basename, repairs))
