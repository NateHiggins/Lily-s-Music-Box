"""Building-front dressing for the near city (Lily's ruling city_next_batch_20261117).

Reads the probe-accepted placements (art/blender/data/city_fronts/accepted.json, judged by
game/tests/v2_city_fronts_probe.gd from candidates.json) and writes game/assets/props/city_fronts.glb: world-frame
meshes for striped shop awnings, signboards, painted wall-advert panels, rooftop billboards and fire escapes, with
metric UVs and catalogue finish names (bound at runtime, as the mid-ground's are). The lettering is not here: the
runtime owner draws it in Label3D from game/data/orison_v2/exterior/city_fronts.json, which this also writes.

    blender -b -P art/blender/scripts/build_city_fronts.py
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bmesh  # noqa: E402
import bpy  # noqa: E402

import build_city_midground as M  # noqa: E402  (part, PARTS)

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
ACCEPTED = os.path.join(ROOT, "art", "blender", "data", "city_fronts", "accepted.json")
OUT = os.path.join(ROOT, "game", "assets", "props", "city_fronts.glb")
DATA = os.path.join(ROOT, "game", "data", "orison_v2", "exterior", "city_fronts.json")
STRIPE_M = 0.24


class Frame:
    """An item's local frame: u along the facade, v up, d out from it; P(u, v, d) is the world point."""

    def __init__(self, at, yaw):
        self.at = at
        self.n = (math.sin(yaw), 0.0, math.cos(yaw))
        self.t = (math.cos(yaw), 0.0, -math.sin(yaw))

    def P(self, u, v, d):
        return (self.at[0] + self.t[0] * u + self.n[0] * d, self.at[1] + v, self.at[2] + self.t[2] * u + self.n[2] * d)


def quad(part, f, a, b, c, d, uvs):
    pts = [f.P(*a), f.P(*b), f.P(*c), f.P(*d)]
    cx = sum(p[0] for p in pts) / 4
    cy = sum(p[1] for p in pts) / 4
    cz = sum(p[2] for p in pts) / 4
    # The part's face() orients the normal away from `centre`; give it a point behind the face.
    e1 = [pts[1][i] - pts[0][i] for i in range(3)]
    e2 = [pts[3][i] - pts[0][i] for i in range(3)]
    n = (e1[1] * e2[2] - e1[2] * e2[1], e1[2] * e2[0] - e1[0] * e2[2], e1[0] * e2[1] - e1[1] * e2[0])
    part.face(pts, uvs, (0.5, 0, 0.5, 0.5), (cx - n[0], cy - n[1], cz - n[2]))


def box(part, f, u0, u1, v0, v1, d0, d1):
    """A box in the item frame with metric UVs on every face."""
    du, dv, dd = u1 - u0, v1 - v0, d1 - d0
    quad(part, f, (u0, v0, d1), (u1, v0, d1), (u1, v1, d1), (u0, v1, d1), [(0, 0), (du, 0), (du, dv), (0, dv)])
    quad(part, f, (u1, v0, d0), (u0, v0, d0), (u0, v1, d0), (u1, v1, d0), [(0, 0), (du, 0), (du, dv), (0, dv)])
    quad(part, f, (u0, v1, d1), (u1, v1, d1), (u1, v1, d0), (u0, v1, d0), [(0, 0), (du, 0), (du, dd), (0, dd)])
    quad(part, f, (u0, v0, d0), (u1, v0, d0), (u1, v0, d1), (u0, v0, d1), [(0, 0), (du, 0), (du, dd), (0, dd)])
    quad(part, f, (u0, v0, d0), (u0, v0, d1), (u0, v1, d1), (u0, v1, d0), [(0, 0), (dd, 0), (dd, dv), (0, dv)])
    quad(part, f, (u1, v0, d1), (u1, v0, d0), (u1, v1, d0), (u1, v1, d1), [(0, 0), (dd, 0), (dd, dv), (0, dv)])


def awning(a):
    f = Frame(a["at"], a["yaw"])
    w, proj = a["width"], a["project"]
    drop = 0.55
    canvas = [M.part("fronts_awning", "fabric_warm"), M.part("fronts_awning", "linen")]
    n = max(2, int(round(w / STRIPE_M)))
    step = w / n
    for i in range(n):
        u0, u1 = -w / 2 + i * step, -w / 2 + (i + 1) * step
        p = canvas[i % 2]
        # The sloped canvas, from the wall down and out, and its valance.
        slope = math.hypot(proj, drop)
        quad(p, f, (u0, 0, 0.02), (u1, 0, 0.02), (u1, -drop, proj), (u0, -drop, proj), [(u0, 0), (u1, 0), (u1, slope), (u0, slope)])
        quad(p, f, (u0, -drop, proj), (u1, -drop, proj), (u1, -drop - 0.22, proj), (u0, -drop - 0.22, proj), [(u0, 0), (u1, 0), (u1, 0.22), (u0, 0.22)])
    iron = M.part("fronts_awning", "iron_blackened")
    for u in (-w / 2 + 0.03, w / 2 - 0.03):
        box(iron, f, u - 0.012, u + 0.012, -drop - 0.012, 0.0, 0.0, proj)
    box(iron, f, -w / 2, w / 2, -drop - 0.012, -drop + 0.012, proj - 0.024, proj)


def signboard(s):
    f = Frame(s["at"], s["yaw"])
    w, h = s["width"], s["height"]
    # Placement is 60 mm proud of the wall. Seat the solid backing in the masonry.
    box(M.part("fronts_sign", "door_paint"), f, -w / 2, w / 2, -h / 2, h / 2, -0.065, 0.04)
    trim = M.part("fronts_sign", "wood_dark")
    box(trim, f, -w / 2 - 0.05, w / 2 + 0.05, h / 2, h / 2 + 0.06, 0.0, 0.07)
    box(trim, f, -w / 2 - 0.05, w / 2 + 0.05, -h / 2 - 0.06, -h / 2, 0.0, 0.07)


def wall_advert(a):
    f = Frame(a["at"], a["yaw"])
    w, h = a["width"], a["height"]
    # A painted ground laid on the brick, a hair proud of it; the border a second coat.
    box(M.part("fronts_wallad", "door_paint"), f, -w / 2, w / 2, -h / 2, h / 2, 0.0, 0.012)
    border = M.part("fronts_wallad", "limewash_plaster")
    for u0, u1, v0, v1 in ((-w / 2, w / 2, h / 2 - 0.18, h / 2), (-w / 2, w / 2, -h / 2, -h / 2 + 0.18),
                           (-w / 2, -w / 2 + 0.18, -h / 2, h / 2), (w / 2 - 0.18, w / 2, -h / 2, h / 2)):
        box(border, f, u0, u1, v0, v1, 0.012, 0.016)


def billboard(b):
    f = Frame(b["at"], b["yaw"])
    w, h = b["width"], b["height"]
    wood = M.part("fronts_board", "site_softwood")
    lift = 2.0
    for u in (-w / 2 + 0.4, 0.0, w / 2 - 0.4):
        box(wood, f, u - 0.08, u + 0.08, 0.0, lift + h, -0.6, -0.44)
        box(wood, f, u - 0.06, u + 0.06, 0.0, lift + h * 0.6, -1.6, -1.48)
    box(wood, f, -w / 2 - 0.1, w / 2 + 0.1, lift - 0.1, lift + h + 0.1, -0.44, -0.36)
    box(M.part("fronts_board", "linen"), f, -w / 2, w / 2, lift, lift + h, -0.36, -0.34)


def fire_escape(e):
    f = Frame(e["at"], e["yaw"])
    w, depth = e["width"], e["depth"]
    iron = M.part("fronts_escape", "iron_blackened")
    levels = e["levels"]
    for y in levels:
        # A slatted platform, its rail and posts, and brackets into the wall.
        for k in range(int(depth / 0.09)):
            d = 0.06 + k * 0.09
            box(iron, f, -w / 2, w / 2, y - 0.03, y, d, d + 0.05)
        box(iron, f, -w / 2, w / 2, y + 0.96, y + 1.0, depth - 0.03, depth)
        for u in (-w / 2, -w / 4, 0.0, w / 4, w / 2 - 0.03):
            box(iron, f, u, u + 0.03, y, y + 1.0, depth - 0.03, depth)
        for u in (-w / 2 + 0.05, w / 2 - 0.08):
            box(iron, f, u, u + 0.03, y, y + 1.0, 0.0, 0.03)
            box(iron, f, u, u + 0.03, y - 0.5, y - 0.03, 0.0, 0.03 + 0.4)
    # Stairs between platforms, alternating ends; a drop ladder below the lowest.
    for i in range(len(levels) - 1):
        lo, hi = levels[i], levels[i + 1]
        s = 1 if i % 2 == 0 else -1
        steps = int((hi - lo) / 0.2)
        for k in range(steps):
            u = s * (-w / 2 + 0.3 + k * (w - 0.9) / steps)
            y = lo + (k + 1) * (hi - lo) / (steps + 1)
            box(iron, f, u - 0.12, u + 0.12, y - 0.025, y, 0.15, 0.75)
    lowest = levels[0]
    for u in (w / 2 - 0.6, w / 2 - 0.2):
        box(iron, f, u, u + 0.025, lowest - 2.4, lowest, depth - 0.12, depth - 0.095)
    for k in range(10):
        y = lowest - 2.3 + k * 0.24
        box(iron, f, w / 2 - 0.6, w / 2 - 0.175, y, y + 0.02, depth - 0.12, depth - 0.1)


def tank_stock():
    tanks = json.load(open(os.path.join(ROOT, "art", "blender", "city_tanks_construction.json")))
    assembly = "site_far_ne__Tank"
    t = next(t for t in tanks["tanks"] if t["assembly"] == assembly)
    base = min(c["point"][2] for c in tanks["contacts"] if c["assembly"] == assembly and c["role"] == "post_base")
    cx, cy = t["center"][0], t["center"][1]
    return {"assembly": assembly, "base": [round(cx, 4), round(base, 4), round(-cy, 4)]}


def export():
    for o in list(bpy.context.scene.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    materials = {}
    for (group, mat), p in sorted(M.PARTS.items()):
        if not group.startswith("fronts_"):
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
    items = json.load(open(ACCEPTED))["items"]
    for a in items.get("awning", []):
        awning(a)
    for s in items.get("signboard", []):
        signboard(s)
    for a in items.get("wall_advert", []):
        wall_advert(a)
    for b in items.get("billboard", []):
        billboard(b)
    for e in items.get("fire_escape", []):
        fire_escape(e)
    export()
    data = {"schema": 1, "frame": "WORLD",
            # Lettering for the runtime's Label3D: [line, ...] per item, at the item's own frame.
            "signs": [{"at": s["at"], "yaw": s["yaw"], "width": s["width"], "height": s["height"], "lines": [s["text"]]} for s in items.get("signboard", [])],
            "wall_adverts": [{"at": a["at"], "yaw": a["yaw"], "width": a["width"], "height": a["height"], "lines": a["text"]} for a in items.get("wall_advert", [])],
            "billboards": [{"at": b["at"], "yaw": b["yaw"], "width": b["width"], "height": b["height"], "lines": b["text"]} for b in items.get("billboard", [])],
            # Roof tanks from the existing tank stock (city_tanks.glb), [x, y, z, yaw].
            "roof_tanks": [[t["at"][0], t["at"][1], t["at"][2], t["yaw"]] for t in items.get("roof_tank", [])],
            # The stock they copy: one existing tank assembly on its 3 m stand, and its post base in that asset's frame
            # (Godot axes, before the city shells' own placement), so a copy stands on the accepted roof point.
            "tank_stock": tank_stock()}
    # The two gable-sized adverts that close the avenue's vistas are authored in the data file, not placed by the
    # survey: a rebuild keeps them.
    if os.path.exists(DATA):
        with open(DATA, encoding="utf8") as handle:
            kept = json.load(handle).get("vista_adverts")
        if kept:
            data["vista_adverts"] = kept
    with open(DATA, "w", encoding="utf8", newline="\n") as handle:
        handle.write(json.dumps(data, separators=(",", ":")) + "\n")
    print("FRONTS wrote", OUT, {k: len(v) for k, v in items.items()})


main()
