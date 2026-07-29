"""Blender 4.5 build script for Orison Apartments (Milestone 1 blockout).

Reads the semantic model in art/data/building_layout.json and constructs
deterministic per-floor geometry: slabs with holes, wall runs with door and
window openings, stair flights with walkable ramp colliders, parapets and
the elevator shaft. One joined mesh per (floor, material-category) keeps
draw calls and export size small; nothing is generated at game runtime.

Naming drives Godot's importer:
    *-col       visible mesh + trimesh collision
    *-colonly   invisible collision (stair ramps)

Run headless:  python -c "import build_orison" (with bpy installed)  or
    blender -b -P build_orison.py
Outputs: game/assets/building/*.glb and art/blender/orison_master.blend
"""
import json
import os
import sys

import bpy

ROOT = os.path.abspath(os.path.join(os.path.dirname(
    os.path.abspath(__file__ if "__file__" in globals() else ".")),
    "..", "..", ".."))
DATA = os.path.join(ROOT, "art", "data")
GLB_OUT = os.path.join(ROOT, "game", "assets", "building")
BLEND_OUT = os.path.join(ROOT, "art", "blender", "orison_master.blend")


def load(name):
    with open(os.path.join(DATA, name)) as f:
        return json.load(f)


LAYOUT = load("building_layout.json")
MATERIALS = load("material_catalog.json")
LEVELS = LAYOUT["meta"]["levels"]
LEVEL_ORDER = sorted(LEVELS.items(), key=lambda kv: kv[1])


class MeshBuf:
    """Accumulates boxes/prisms, realized as one mesh object at the end."""

    def __init__(self, name, material):
        self.name = name
        self.material = material
        self.verts = []
        self.faces = []

    def add_box(self, mn, mx):
        if mx[0] - mn[0] < 1e-4 or mx[1] - mn[1] < 1e-4 or mx[2] - mn[2] < 1e-4:
            return
        b = len(self.verts)
        x0, y0, z0 = mn
        x1, y1, z1 = mx
        self.verts += [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
                       (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)]
        self.faces += [(b, b + 3, b + 2, b + 1), (b + 4, b + 5, b + 6, b + 7),
                       (b, b + 1, b + 5, b + 4), (b + 1, b + 2, b + 6, b + 5),
                       (b + 2, b + 3, b + 7, b + 6), (b + 3, b, b + 4, b + 7)]

    def add_ramp(self, x0, z0, x1, z1, y0, y1, thickness=0.08):
        """Inclined slab along X between (x0,z0) and (x1,z1).

        Canonicalized to ascending X with explicit outward winding: physics
        treats a downward-wound "floor" as a wall, which silently blocks
        characters climbing in one direction only.
        """
        if x1 < x0:
            x0, x1 = x1, x0
            z0, z1 = z1, z0
        b = len(self.verts)
        self.verts += [
            (x0, y0, z0), (x0, y1, z0), (x1, y1, z1), (x1, y0, z1),
            (x0, y0, z0 - thickness), (x0, y1, z0 - thickness),
            (x1, y1, z1 - thickness), (x1, y0, z1 - thickness)]
        self.faces += [
            (b, b + 3, b + 2, b + 1),          # top (+z)
            (b + 4, b + 5, b + 6, b + 7),      # bottom (-z)
            (b, b + 4, b + 7, b + 3),          # -y side
            (b + 1, b + 2, b + 6, b + 5),      # +y side
            (b, b + 1, b + 5, b + 4),          # low end (-x)
            (b + 3, b + 7, b + 6, b + 2)]      # high end (+x)

    def realize(self, collection):
        if not self.verts:
            return None
        me = bpy.data.meshes.new(self.name)
        me.from_pydata(self.verts, [], self.faces)
        me.validate()
        me.update()
        me.materials.append(get_material(self.material))
        obj = bpy.data.objects.new(self.name, me)
        collection.objects.link(obj)
        return obj


_mat_cache = {}


def get_material(key):
    if key in _mat_cache:
        return _mat_cache[key]
    spec = MATERIALS.get(key, MATERIALS["plaster"])
    mat = bpy.data.materials.new("M_%s" % key)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = spec["base_color"]
    bsdf.inputs["Roughness"].default_value = spec.get("roughness", 0.7)
    bsdf.inputs["Metallic"].default_value = spec.get("metallic", 0.0)
    _mat_cache[key] = mat
    return mat


def subtract_rect(rects, hole):
    """Axis-aligned rectangle subtraction (for slab holes)."""
    hx0, hy0, hx1, hy1 = hole
    out = []
    for (x0, y0, x1, y1) in rects:
        if hx0 >= x1 or hx1 <= x0 or hy0 >= y1 or hy1 <= y0:
            out.append((x0, y0, x1, y1))
            continue
        cx0, cy0 = max(x0, hx0), max(y0, hy0)
        cx1, cy1 = min(x1, hx1), min(y1, hy1)
        if y0 < cy0:
            out.append((x0, y0, x1, cy0))
        if cy1 < y1:
            out.append((x0, cy1, x1, y1))
        if x0 < cx0:
            out.append((x0, cy0, cx0, cy1))
        if cx1 < x1:
            out.append((cx1, cy0, x1, cy1))
    return out


def build_wall(buf, w):
    """Wall run with openings, thickness centered on the a->b line."""
    ax, ay = w["a"]
    bx, by = w["b"]
    z, h, t = w["z"], w["h"], w["t"]
    horizontal = abs(by - ay) < 1e-6
    length = abs((bx - ax) if horizontal else (by - ay))
    start = min(ax, bx) if horizontal else min(ay, by)
    cross = ay if horizontal else ax

    def seg_box(d0, d1, z0, z1):
        if horizontal:
            buf.add_box((start + d0, cross - t / 2, z + z0),
                        (start + d1, cross + t / 2, z + z1))
        else:
            buf.add_box((cross - t / 2, start + d0, z + z0),
                        (cross + t / 2, start + d1, z + z1))

    openings = sorted(w["openings"], key=lambda o: o["at"])
    cursor = 0.0
    for o in openings:
        d0 = max(o["at"] - o["w"] / 2, 0.0)
        d1 = min(o["at"] + o["w"] / 2, length)
        if d0 > cursor:
            seg_box(cursor, d0, 0.0, h)
        top = o["sill"] + o["h"]
        if top < h:                       # lintel
            seg_box(d0, d1, top, h)
        if o["sill"] > 0.0:               # window sill wall
            seg_box(d0, d1, 0.0, o["sill"])
        cursor = d1
    if cursor < length:
        seg_box(cursor, length, 0.0, h)


def floor_for_z(z):
    prev = LEVEL_ORDER[0][0]
    for name, lz in LEVEL_ORDER:
        if z >= lz - 0.01:
            prev = name
    return prev


def floor_key(fid):
    return {"B1": "floor_b1", "ROOF": "roof"}.get(
        fid, "floor_%s" % fid[1:].lower())


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    root_col = bpy.data.collections.new("ORISON")
    scene.collection.children.link(root_col)

    floor_cols = {}
    bufs = {}

    def buf(fid, cat, mat):
        key = (fid, cat)
        if key not in bufs:
            bufs[key] = MeshBuf("%s_%s" % (fid, cat), mat)
        return bufs[key]

    for fl in LAYOUT["floors"]:
        fid = fl["id"]
        col = bpy.data.collections.new(fid)
        root_col.children.link(col)
        floor_cols[fid] = col
        for s in fl["slabs"]:
            rects = [tuple(s["rect"])]
            for hole in s["holes"]:
                rects = subtract_rect(rects, tuple(hole))
            for (x0, y0, x1, y1) in rects:
                buf(fid, "slabs-col", "slab").add_box(
                    (x0, y0, s["z_top"] - s["t"]), (x1, y1, s["z_top"]))
        for w in fl["walls"]:
            cat = {"brick": "walls_brick-col",
                   "concrete": "walls_conc-col"}.get(w["mat"], "walls-col")
            build_wall(buf(fid, cat, w["mat"]), w)
        for m in fl["markers"]:
            e = bpy.data.objects.new("MK_%s" % m["id"], None)
            e.empty_display_size = 0.2
            e.location = (m["pos"][0], m["pos"][1], m["pos"][2])
            col.objects.link(e)

    # stairs: visible steps + invisible walk ramps, filed under lower floor
    for st in LAYOUT["stairs"]:
        wx0, wy0, wx1, wy1 = st["well"]
        pair = []
        for part in st["parts"]:
            if part["kind"] == "flight":
                fid = floor_for_z(part["z0"] + 0.01)
                vis = buf(fid, "stairs", "stair")
                ramp = buf(fid, "stairs_ramp-colonly", "stair")
                n, rise, tread = part["n"], part["rise"], part["tread"]
                xs, d = part["x_start"], part["dir"]
                for i in range(1, n + 1):
                    x_lo = xs + d * i * tread
                    x_hi = xs + d * (i - 1) * tread
                    if d < 0:
                        x_lo, x_hi = x_lo, x_hi
                    else:
                        x_lo, x_hi = x_hi, x_lo
                    vis.add_box((min(x_lo, x_hi), part["y0"], part["z0"]),
                                (max(x_lo, x_hi), part["y1"],
                                 part["z0"] + i * rise))
                x_end = xs + d * n * tread
                ramp.add_ramp(xs, part["z0"], x_end, part["z0"] + n * rise,
                              part["y0"], part["y1"])
                pair.append(part)
                if d > 0:  # top infill from last step to well edge
                    top_z = part["z0"] + n * rise
                    edge = wx1 if d > 0 else wx0
                    vis.add_box((min(x_end, edge), part["y0"], top_z - 0.18),
                                (max(x_end, edge), part["y1"], top_z))
                    ramp.add_box((min(x_end, edge), part["y0"], top_z - 0.18),
                                 (max(x_end, edge), part["y1"], top_z))
            elif part["kind"] == "landing":
                fid = floor_for_z(part["z"] - 0.5)
                r = part["rect"]
                for b in (buf(fid, "stairs", "stair"),
                          buf(fid, "stairs_ramp-colonly", "stair")):
                    b.add_box((r[0], r[1], part["z"] - 0.18),
                              (r[2], r[3], part["z"]))

    for (fid, cat), b in bufs.items():
        b.realize(floor_cols[fid])

    os.makedirs(GLB_OUT, exist_ok=True)
    for fid, col in floor_cols.items():
        bpy.ops.object.select_all(action="DESELECT")
        for obj in col.objects:
            if obj.type == "MESH":
                obj.select_set(True)
        path = os.path.join(GLB_OUT, floor_key(fid) + ".glb")
        bpy.ops.export_scene.gltf(filepath=path, use_selection=True,
                                  export_apply=True)
        print("exported", path)

    bpy.ops.wm.save_as_mainfile(filepath=BLEND_OUT)
    print("saved", BLEND_OUT)


if __name__ == "__main__" or True:
    build()
