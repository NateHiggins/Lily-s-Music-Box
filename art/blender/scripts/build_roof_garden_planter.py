"""Build the small communal roof herb bed from metric, catalogue-bound stocks."""
import json
import os
from math import cos, pi, sin
from pathlib import Path
import sys

import bpy
import bmesh
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(os.environ.get("ORISON_GARDEN_OUTPUT", str(ROOT)))
sys.path.insert(0, str(ROOT / "art/blender/scripts"))
from fabrication_uvs import chart_for_triangle
from fabrication_native_batch import export

bpy.ops.wm.read_factory_settings(use_empty=True)
catalog = json.loads((ROOT / "game/data/runtime_material_sets.json").read_text(encoding="utf-8"))["materials"]
roles = {
    "Timber": ("timber", (0.25, 0.15, 0.075), 0.8),
    "Soil": ("soil", (0.081, 0.047, 0.028), 0.98),
    "Stems": ("plant", (0.107, 0.177, 0.055), 0.78),
    "Leaves": ("plant", (0.165, 0.258, 0.073), 0.65),
}
assert all(key in catalog for key, _, _ in roles.values())
materials = {}
geometry = {role: {"verts": [], "faces": []} for role in roles}

for role, (key, rgb, roughness) in roles.items():
    material = bpy.data.materials.new(f"{role}__{key}")
    material.diffuse_color = (*rgb, 1)
    material.use_nodes = True
    shader = material.node_tree.nodes["Principled BSDF"]
    shader.inputs["Base Color"].default_value = (*rgb, 1)
    shader.inputs["Roughness"].default_value = roughness
    materials[role] = material

def part(role, vertices, faces):
    entry = geometry[role]
    offset = len(entry["verts"])
    entry["verts"].extend(vertices)
    entry["faces"].extend(tuple(offset + index for index in face) for face in faces)

def stock(role, center, size):
    x, y, z = center
    w, d, h = (value / 2 for value in size)
    vertices = [(x + a * w, y + b * d, z + c * h) for a, b, c in
                ((-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),
                 (-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1))]
    part(role, vertices, [(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)])

def stem(start, end, radius):
    start, end = Vector(start), Vector(end)
    axis = (end - start).normalized()
    u = axis.cross(Vector((1, 0, 0))).normalized()
    v = axis.cross(u)
    circle = [u * cos(step * pi / 3) + v * sin(step * pi / 3) for step in range(6)]
    vertices = [tuple(point + direction * radius * scale)
                for point, scale in ((start, 1.0), (end, 0.43)) for direction in circle]
    faces = [tuple(reversed(range(6))), tuple(range(6, 12))]
    for step in range(6):
        nxt = (step + 1) % 6
        faces.append((step, nxt, nxt + 6, step + 6))
    part("Stems", vertices, faces)

def leaf(start, heading, length, width):
    start = Vector(start)
    forward = Vector((cos(heading), sin(heading), 0))
    across = Vector((-sin(heading), cos(heading), 0))
    middle = start + forward * (length * .52)
    peak = middle + Vector((0, 0, .011))
    tip = start + forward * length + Vector((0, 0, .019))
    vertices = [start, middle + across * width, tip, middle - across * width,
                peak, middle - Vector((0, 0, .004))]
    part("Leaves", [tuple(vertex) for vertex in vertices],
         [(0,1,4),(1,2,4),(2,3,4),(3,0,4),(1,0,5),(2,1,5),(3,2,5),(0,3,5)])

# Small raised timber bed in the same construction vocabulary as the
# original communal roof beds. The floor contacts are two wide skids.
for x in (-.42, .42):
    stock("Timber", (x, 0, .055), (.105, .55, .11))
stock("Timber", (0, 0, .119), (1.12, .48, .034))
for y in (-.238, .238):
    stock("Timber", (0, y, .277), (1.12, .039, .274))
for x in (-.54, .54):
    stock("Timber", (x, 0, .277), (.04, .435, .274))
for x in (-.43, .43):
    for y in (-.207, .207):
        stock("Timber", (x, y, .269), (.045, .047, .267))
stock("Soil", (0, 0, .343), (1.032, .43, .094))

# Authored roof herbs are distinct from Malcolm's protected indoor cutting.
for index, (x, y) in enumerate(((-.35,-.07),(-.2,.08),(-.06,-.056),(.09,.07),(.27,-.04),(.38,.06))):
    for branch in range(4):
        angle = index * .81 + branch * 1.6
        reach = .060 + (branch % 3) * .008
        start = Vector((x, y, .385))
        end = start + Vector((reach * cos(angle), reach * sin(angle), .112 + (index + branch) % 4 * .023))
        stem(start, end, .0048)
        for rung in range(3):
            node = start.lerp(end, .36 + rung * .24)
            side = (1 if rung % 2 else -1) * 1.12
            leaf(node, angle + side, .052 + rung * .005, .012 + (rung % 2) * .002)
            leaf(node, angle - side, .049 + rung * .005, .011)

for role, entry in geometry.items():
    mesh = bpy.data.meshes.new(role)
    mesh.from_pydata(entry["verts"], [], entry["faces"])
    mesh.update()
    editable = bmesh.new()
    editable.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(editable, faces=list(editable.faces))
    bmesh.ops.triangulate(editable, faces=list(editable.faces))
    editable.to_mesh(mesh)
    editable.free()
    mesh.update()
    obj = bpy.data.objects.new(f"RoofGarden_{role}", mesh)
    bpy.context.collection.objects.link(obj)
    mesh.materials.append(materials[role])
    uv = mesh.uv_layers.new(name="Metric")
    guide = mesh.attributes.new(name="_tangent_guide", type="FLOAT_VECTOR", domain="CORNER")
    repeats = float(catalog[roles[role][0]]["meters_per_tile"])
    for face in mesh.polygons:
        vertices = [tuple(mesh.vertices[mesh.loops[index].vertex_index].co) for index in face.loop_indices]
        _, u, chart, _ = chart_for_triangle(vertices, (0, 0, 0), repeats)
        for index, coords in zip(face.loop_indices, chart):
            uv.data[index].uv = tuple(coords)
            guide.data[index].vector = (u[0], u[2], -u[1])


proof = export(OUT, "roof_garden_planter", bpy.context.scene.collection, material_names_only=True, staged_output=True)
proof["native_triangles"] = sum(len(obj.data.polygons) for obj in bpy.context.scene.objects)
assert proof["native_triangles"] == proof["triangles"]
print(json.dumps(proof))
