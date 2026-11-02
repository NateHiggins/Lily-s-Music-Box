"""A paper claim tag for a parcel on the Model Laundry wall, facing +X. One draw in metres.

    blender -b -P art/blender/scripts/build_parcel_tag.py

The origin is the middle of the back of the card, so the wall sets one instance per parcel. Generated glTF is never hand-edited.
"""
from pathlib import Path
import json, sys
import bpy, bmesh
import numpy as np
sys.path.insert(0, str(Path(__file__).resolve().parent))
from fabrication_uvs import chart_for_triangle

ROOT = next(p for p in Path(__file__).resolve().parents if (p / "game/project.godot").is_file())
CATALOG = json.loads((ROOT / "game/data/runtime_material_sets.json").read_text())["materials"]
KEY = "paper"
TILE = CATALOG[KEY]["meters_per_tile"]
THICK, WIDTH, HEIGHT = 0.002, 0.075, 0.042


def block(cx, cy, half_x, half_y, bottom, top, bevel):
    bm = bmesh.new()
    verts = [bm.verts.new((cx + sx * half_x, cy + sy * half_y, bottom if sz < 0 else top)) for sz in (-1, 1) for sy in (-1, 1) for sx in (-1, 1)]
    for a, b, c, d in [(0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)]:
        bm.faces.new((verts[a], verts[b], verts[c], verts[d]))
    bm.normal_update()
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=3, profile=0.5, affect="EDGES")
    return bm


def mesh_of(name, blocks, key, tile):
    bm = bmesh.new()
    mesh = bpy.data.meshes.new(name)
    for piece in blocks:
        temporary = bpy.data.meshes.new("piece")
        piece.to_mesh(temporary)
        piece.free()
        bm.from_mesh(temporary)
        bpy.data.meshes.remove(temporary)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bmesh.ops.triangulate(bm, faces=list(bm.faces))
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    mesh.materials.append(bpy.data.materials.new(key))
    uv = mesh.uv_layers.new(name="Metres")
    uv.active_render = True
    guides = mesh.attributes.new(name="_tangent_guide", type="FLOAT_VECTOR", domain="CORNER")
    normals = [None] * len(mesh.loops)
    for face in mesh.polygons:
        points = np.asarray([mesh.vertices[i].co[:] for i in face.vertices], dtype=np.float64)
        n, u, values, _local = chart_for_triangle(points, np.zeros(3), tile, False)
        for j, loop in enumerate(face.loop_indices):
            uv.data[loop].uv = tuple(values[j])
            guides.data[loop].vector = (float(u[0]), float(u[2]), float(-u[1]))
            smooth = np.asarray(mesh.vertices[face.vertices[j]].normal[:], dtype=np.float64)
            normals[loop] = tuple(smooth) if float(np.dot(smooth, n)) > 0.72 else tuple(n)
    mesh.normals_split_custom_set(normals)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


bpy.ops.wm.read_factory_settings(use_empty=True)
draws = [mesh_of("parcel_tag__paper", [block(THICK * 0.5, 0, THICK * 0.5, WIDTH * 0.5, -HEIGHT * 0.5, HEIGHT * 0.5, 0.0)], KEY, TILE)]
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "art/blender/parcel_tag.blend"))
for obj in draws:
    obj.select_set(True)


class ExportUVHandedness:
    def gather_mesh_hook(self, mesh, blender_data, blender_object, vertex_groups, modifiers, materials, export_settings):
        for primitive in mesh.primitives:
            def vectors(key):
                accessor = primitive.attributes[key]
                return np.frombuffer(accessor.buffer_view.data, dtype="<f4").reshape((-1, 3)).astype(np.float64)
            n = vectors("NORMAL")
            n /= np.linalg.norm(n, axis=1)[:, None]
            guide = vectors("_TANGENT_GUIDE")
            tangent = guide - n * np.sum(guide * n, axis=1)[:, None]
            tangent /= np.linalg.norm(tangent, axis=1)[:, None]
            tangent = np.column_stack((tangent, -np.ones(len(n)))).astype(np.float32)
            from io_scene_gltf2.io.exp.binary_data import BinaryData
            from io_scene_gltf2.io.com.constants import BufferViewTarget
            primitive.attributes["TANGENT"].buffer_view = BinaryData(tangent.tobytes(), BufferViewTarget.ARRAY_BUFFER)
            for key in list(primitive.attributes):
                if key.upper() == "_TANGENT_GUIDE":
                    del primitive.attributes[key]


import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension = ExportUVHandedness
bpy.ops.export_scene.gltf(filepath=str(ROOT / "game/assets/props/parcel_tag.glb"), export_format="GLB", use_selection=True, export_yup=True,
                          export_tangents=True, export_attributes=True, export_materials="NONE")
print("TAG", {o.name: len(o.data.polygons) for o in draws})
