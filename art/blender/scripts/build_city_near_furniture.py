"""Telegraph poles and their wires for the near city (Lily's ruling city_complete_next_20261117).

Reads the running-world probe's accepted placements (art/blender/data/city_near_furniture/accepted.json, written by
game/tests/v2_near_furniture_probe.gd from candidates.json) and writes:
  - game/assets/props/city_near_furniture.glb: the pole stock (softwood pole, two crossarms with braces, glass
    insulators on pins, step bolts) at the origin, and the wires as one world-frame mesh. Same part conventions as
    the mid-ground (metric UVs, catalogue finish names, PLACEHOLDER materials bound at runtime).
  - game/data/orison_v2/exterior/city_near_furniture.json: the accepted furniture items for the runtime owner.

    blender -b -P art/blender/scripts/build_city_near_furniture.py

Wires run between consecutive accepted poles of the same kerb run, four on the upper arm and two on the lower,
sagging SAG_PER_M of the span at mid-span.
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bmesh  # noqa: E402
import bpy  # noqa: E402

import build_city_midground as M  # noqa: E402  (part, box_world, cylinder_world, PARTS)

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
ACCEPTED = os.path.join(ROOT, "art", "blender", "data", "city_near_furniture", "accepted.json")
OUT = os.path.join(ROOT, "game", "assets", "props", "city_near_furniture.glb")
DATA = os.path.join(ROOT, "game", "data", "orison_v2", "exterior", "city_near_furniture.json")

POLE_H = 9.0
ARMS = [(8.55, 2.4, 4), (7.85, 1.8, 2)]   # height, crossarm length, insulators carried
WIRE_R = 0.006
SAG_PER_M = 0.012
MAX_SPAN_M = 48.0


def pole_stock():
    wood = M.part("furn_telegraph_pole", "site_softwood")
    # The pole tapers: two cylinders, butt to top.
    M.cylinder_world(wood, 0, 0, 0.14, 0.0, 4.5, 10, top=False)
    M.cylinder_world(wood, 0, 0, 0.12, 4.5, POLE_H, 10)
    iron = M.part("furn_telegraph_pole", "iron_neutral")
    glass = M.part("furn_telegraph_pole", "glass_cut")
    for y, length, count in ARMS:
        # The arm crosses the pole across the street's run (x), braced from below.
        M.box_world(wood, -length / 2, -0.05, length / 2, 0.05, y - 0.09, y, bottom=True)
        for s in (-1, 1):
            M.box_world(iron, s * 0.55 - 0.012, -0.012, s * 0.55 + 0.012, 0.012, y - 0.55, y - 0.09)
        for k in range(count):
            x = -length / 2 + 0.15 + k * (length - 0.3) / max(count - 1, 1)
            M.cylinder_world(iron, x, 0, 0.012, y, y + 0.08, 6)
            M.cylinder_world(glass, x, 0, 0.035, y + 0.08, y + 0.17, 8)
    # Step bolts up the pole from 2.4 m, alternate sides.
    for i in range(14):
        y = 2.4 + i * 0.42
        s = 1 if i % 2 == 0 else -1
        M.box_world(iron, -0.012, s * 0.12, 0.012, s * 0.3, y, y + 0.024, bottom=True)


def insulator_points(x, y, z, yaw):
    """World positions of the wire seats on a pole at (x, y, z) facing yaw: arms lie along the pole's local x."""
    c, s = math.cos(yaw), math.sin(yaw)
    out = []
    for h, length, count in ARMS:
        for k in range(count):
            lx = -length / 2 + 0.15 + k * (length - 0.3) / max(count - 1, 1)
            # Local x rotated by yaw about up (Godot: x' = x cos + z sin, z' = -x sin + z cos).
            out.append((x + lx * c, y + h + 0.17, z - lx * s))
    return out


def wires(poles):
    w = M.part("near_wires", "iron_blackened")
    spans = 0
    for a, b in zip(poles, poles[1:]):
        if math.dist((a[0], a[2]), (b[0], b[2])) > MAX_SPAN_M:
            continue
        for p, q in zip(insulator_points(*a), insulator_points(*b)):
            tube(w, p, q)
        spans += 1
    return spans


def tube(part, p, q, segs=12, sides=4):
    span = math.dist(p, q)
    sag = SAG_PER_M * span
    pts = []
    for i in range(segs + 1):
        t = i / segs
        pts.append((p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t - sag * 4 * t * (1 - t), p[2] + (q[2] - p[2]) * t))
    run = 0.0
    for i in range(segs):
        a, b = pts[i], pts[i + 1]
        seg = math.dist(a, b)
        dx, dz = b[0] - a[0], b[2] - a[2]
        h = math.hypot(dx, dz) or 1.0
        side = (-dz / h, 0.0, dx / h)
        up = (0.0, 1.0, 0.0)
        for k in range(sides):
            a0, a1 = 2 * math.pi * k / sides, 2 * math.pi * (k + 1) / sides
            o0 = [WIRE_R * (math.cos(a0) * side[j] + math.sin(a0) * up[j]) for j in range(3)]
            o1 = [WIRE_R * (math.cos(a1) * side[j] + math.sin(a1) * up[j]) for j in range(3)]
            quad = [tuple(a[j] + o0[j] for j in range(3)), tuple(b[j] + o0[j] for j in range(3)),
                    tuple(b[j] + o1[j] for j in range(3)), tuple(a[j] + o1[j] for j in range(3))]
            v0, v1 = WIRE_R * a0, WIRE_R * a1
            centre = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, (a[2] + b[2]) / 2)
            part.face(quad, [(run, v0), (run + seg, v0), (run + seg, v1), (run, v1)], (0.5, 0, 0.5, 0.5), centre)
        run += seg


def export():
    for o in list(bpy.context.scene.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    materials = {}
    for (group, mat), p in sorted(M.PARTS.items()):
        if not (group.startswith("furn_telegraph") or group == "near_wires"):
            continue
        mesh = bpy.data.meshes.new(f"{group}__{mat}")
        bmesh.ops.remove_doubles(p.bm, verts=p.bm.verts, dist=0.0005)
        p.bm.loops.layers.color.remove(p.col)
        p.bm.to_mesh(mesh)
        p.bm.free()
        materials.setdefault(mat, bpy.data.materials.new(mat))
        mesh.materials.append(materials[mat])
        obj = bpy.data.objects.new(f"{group}__{mat}", mesh)
        bpy.context.scene.collection.objects.link(obj)
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_yup=True, export_apply=True,
                              export_normals=True, export_texcoords=True, export_materials="PLACEHOLDER")


def main():
    accepted = json.load(open(ACCEPTED))
    candidates = json.load(open(os.path.join(os.path.dirname(ACCEPTED), "candidates.json")))
    posts = accepted["items"].get("signpost", [])
    # Only a post the running world accepted carries its blades.
    signs, named = [], set()
    for s in candidates.get("signs", []):
        if s["street"][0] in named:
            continue
        if any(abs(p[0] - s["x"]) < 0.01 and abs(p[2] - s["z"]) < 0.01 for p in posts):
            signs.append(s)
            named.add(s["street"][0])
    # One post per crossing: the first accepted corner.
    accepted["items"]["signpost"] = [p for p in posts if any(abs(p[0] - s["x"]) < 0.01 and abs(p[2] - s["z"]) < 0.01 for s in signs)]
    items = accepted["items"]
    # Placement yaw faces the road; turn a quarter so the crossarms lie across the street and the wires run along it.
    poles = [[q[0], q[1], q[2], round(q[3] + math.pi / 2, 4)] for q in items.get("telegraph_pole", [])]
    pole_stock()
    spans = wires(poles)
    export()
    data = {"schema": 1, "frame": "WORLD",
            # The mid-ground's own stock for these kinds (city_midground.glb furn_*), items [x, y, z, yaw].
            "furniture": [{"kind": k, "items": v} for k, v in items.items() if k != "telegraph_pole" and v],
            "poles": poles,
            # Corner signs: two blades on the post, [new name, old name or ""] for each street.
            "signs": signs}
    with open(DATA, "w", encoding="utf8", newline="\n") as handle:
        handle.write(json.dumps(data, separators=(",", ":")) + "\n")
    print("NEAR FURNITURE wrote", OUT, DATA, {k: len(v) for k, v in items.items()}, "spans", spans)


main()
