"""The player's own boots, standing at the Shoe Rebuilding bench. Two draws in metres, on existing catalogue keys.

    blender -b -P art/blender/scripts/build_customer_boots.py

The pair's origin is the middle of the two soles, so the bench moves one node. Uppers and soles are separate draws because
they take different materials. Generated glTF is never hand-edited.
"""
from pathlib import Path
import json, math, sys
import bpy, bmesh
import numpy as np
sys.path.insert(0, str(Path(__file__).resolve().parent))
from fabrication_uvs import chart_for_triangle

ROOT = next(p for p in Path(__file__).resolve().parents if (p / "game/project.godot").is_file())
CATALOG = json.loads((ROOT / "game/data/runtime_material_sets.json").read_text())["materials"]
PARTS = {"upper": "leather_worn", "sole": "rubber_aged"}
TILE = {part: CATALOG[key]["meters_per_tile"] for part, key in PARTS.items()}
LENGTH, WIDTH, GAP = 0.285, 0.104, 0.125
RING = 28
STATIONS = [i / 40 for i in range(41)]


def lerp(a, b, t):
    return a + (b - a) * t


def table(rows, t):
    for (t0, v0), (t1, v1) in zip(rows, rows[1:]):
        if t <= t1:
            return lerp(v0, v1, (t - t0) / (t1 - t0))
    return rows[-1][1]


def half_width(t):
    """A last seen from above: a rounded heel, a waist under the arch, the ball, a blunt round toe."""
    if t < 0.14:
        return 0.3 * WIDTH * math.sqrt(max(0.0, 1 - ((0.14 - t) / 0.14) ** 2)) + 0.002
    if t > 0.8:
        return 0.48 * WIDTH * math.sqrt(max(0.0, 1 - ((t - 0.8) / 0.2) ** 2)) + 0.002
    return table([(0.14, 0.3), (0.42, 0.34), (0.68, 0.5), (0.8, 0.48)], t) * WIDTH


def sole_bottom(t):
    """Heel block and forepart stand on the bench; the waist between them lifts clear."""
    return table([(0.0, 0.0), (0.27, 0.0), (0.3, 0.018), (0.5, 0.012), (0.56, 0.0), (1.0, 0.0)], t)


def sole_top(t):
    return table([(0.0, 0.034), (0.27, 0.034), (0.56, 0.015), (1.0, 0.017)], t)


def upper_top(t):
    """Height of the foot above its sole. Behind the instep the shaft carries on upward."""
    if t > 0.84:
        return 0.056 * math.sqrt(max(0.0, 1 - ((t - 0.84) / 0.16) ** 2)) + 0.002
    return table([(0.0, 0.085), (0.34, 0.1), (0.52, 0.078), (0.7, 0.058), (0.84, 0.056)], t)


def section(cx, y, half, bottom, top, flat):
    """One rib, flat underneath and domed on top; flat ribs are the sole's slab."""
    ring = []
    for j in range(RING):
        a = j * math.tau / RING
        c, s = math.cos(a), math.sin(a)
        x = cx + half * math.copysign(abs(c) ** 0.7, c)
        if flat:
            z = top if s >= 0 else bottom
        else:
            z = bottom + (top - bottom) * abs(s) ** 0.85 if s > 0 else bottom
        ring.append((x, y, z))
    return ring


def closed(verts, count):
    faces = [tuple(reversed(range(RING))), tuple(range((count - 1) * RING, count * RING))]
    faces.extend((k * RING + j, k * RING + (j + 1) % RING, (k + 1) * RING + (j + 1) % RING, (k + 1) * RING + j) for k in range(count - 1) for j in range(RING))
    return verts, faces


def foot(cx):
    verts = []
    for t in STATIONS:
        base = sole_top(t)
        verts.extend(section(cx, LENGTH * (t - 0.5), half_width(t) * 0.97, base, base + upper_top(t), False))
    return closed(verts, len(STATIONS))


def sole(cx):
    verts = []
    for t in STATIONS:
        verts.extend(section(cx, LENGTH * (t - 0.5), half_width(t) * 1.04, sole_bottom(t), sole_top(t), True))
    return closed(verts, len(STATIONS))


def shaft(cx):
    """The leg of the boot: a tube rising from inside the foot, a little wider at the top, with a turned collar and a real wall."""
    n, y0 = 32, -LENGTH * 0.5 + 0.066
    levels = [(0.05, 0.04, 0.056), (0.11, 0.039, 0.056), (0.19, 0.042, 0.06), (0.222, 0.044, 0.062), (0.232, 0.047, 0.065), (0.24, 0.043, 0.061)]
    verts = []
    for z, rx, ry in levels:
        verts.extend((cx + rx * math.cos(i * math.tau / n), y0 + ry * math.sin(i * math.tau / n), z) for i in range(n))
    verts.extend((cx + 0.037 * math.cos(i * math.tau / n), y0 + 0.055 * math.sin(i * math.tau / n), z) for z in (0.24, 0.1) for i in range(n))
    rows = len(levels) + 2
    faces = [tuple(reversed(range(n))), tuple(range((rows - 1) * n, rows * n))]
    faces.extend((k * n + i, k * n + (i + 1) % n, (k + 1) * n + (i + 1) % n, (k + 1) * n + i) for k in range(rows - 1) for i in range(n))
    return verts, faces


def bar(cx, y, z, half, depth):
    """One crossing of the lace, a small raised bar on the front of the boot."""
    h = 0.0022
    verts = [(cx + sx * half, y + sy * depth, z + sz * h) for sz in (-1, 1) for sy in (-1, 1) for sx in (-1, 1)]
    faces = [(0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)]
    return verts, faces


def laces(cx):
    """Five crossings up the shaft's front and three down the instep."""
    front = -LENGTH * 0.5 + 0.066 + 0.056
    pieces = [bar(cx, front + 0.002, 0.13 + i * 0.022, 0.02, 0.004) for i in range(5)]
    for i in range(3):
        t = 0.45 + i * 0.05
        pieces.append(bar(cx, LENGTH * (t - 0.5), sole_top(t) + upper_top(t) + 0.0005, 0.02, 0.0035))
    return pieces


def mesh_of(name, pieces, key, tile):
    verts, faces = [], []
    for piece_verts, piece_faces in pieces:
        offset = len(verts)
        verts.extend(piece_verts)
        faces.extend(tuple(offset + i for i in face) for face in piece_faces)
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    bm = bmesh.new()
    bm.from_mesh(mesh)
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
            # Smooth over the leather's curves; edges sharper than this keep the face's own normal.
            smooth = np.asarray(mesh.vertices[face.vertices[j]].normal[:], dtype=np.float64)
            normals[loop] = tuple(smooth) if float(np.dot(smooth, n)) > 0.72 else tuple(n)
    mesh.normals_split_custom_set(normals)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


bpy.ops.wm.read_factory_settings(use_empty=True)
uppers, soles = [], []
for side in (-1, 1):
    cx = side * GAP * 0.5
    soles.append(sole(cx))
    uppers.extend([foot(cx), shaft(cx)] + laces(cx))
draws = [mesh_of("customer_boots__upper", uppers, PARTS["upper"], TILE["upper"]), mesh_of("customer_boots__sole", soles, PARTS["sole"], TILE["sole"])]
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "art/blender/customer_boots.blend"))
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
bpy.ops.export_scene.gltf(filepath=str(ROOT / "game/assets/props/customer_boots.glb"), export_format="GLB", use_selection=True, export_yup=True,
                          export_tangents=True, export_attributes=True, export_materials="NONE")
print("BOOTS", {o.name: len(o.data.polygons) for o in draws})
