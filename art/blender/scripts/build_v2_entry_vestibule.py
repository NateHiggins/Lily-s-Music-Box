"""V2 entry vestibule dress and the one entrance lamp, Queens 1928.

Rule of Signal (design/ORISON_BIBLE.md VIII.2): the brass Vantry signal point
is the only signal object here, so it alone is better made than it should be.
Light carries no signal, so it never advanced: the entrance is still lit by
gas, inverted Welsbach mantles on a surface-run black iron supply. The
directory board, notices, plaque, radiator, mat, hooks and gas fittings are
1927 and second-hand: stained oak, felt, paper, bronze, cast iron, Bakelite and
brass. No aluminium and no stainless anywhere. No lettering in any surface;
names, notices and the plaque legend are Label3D at runtime (RUL-008).

Design packet: design/V2_ENTRY_VESTIBULE_2026-10-24.md.

Exports one native-stock GLB, game/assets/props/v2_entry_vestibule.glb, with
one object per (stock, finish) named `<stock>__<finish>`, and writes the
finish table game/data/orison_v2/entry_vestibule_stock.json from the same
specification. Wall stocks: the wall face is Blender Y 0, the fitting stands
out along -Y (Godot +Z) and its origin is the fitting's mount centre. Floor
stocks: the floor is Z 0. UVs are the shared metre charts
(fabrication_native_batch). Never hand-edit the GLB or the JSON; edit this
recipe and rerun:

    blender -b -P art/blender/scripts/build_v2_entry_vestibule.py
"""
from pathlib import Path
import sys, json, math
import bpy, bmesh
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(Path(__file__).parent))
from fabrication_native_batch import material, partition, export

FAMILY = "v2_entry_vestibule"

FINISHES = {
    "oak": {"catalog_key": "wood_dark", "tint": [1, 1, 1, 1], "normal": 1., "roughness": 1.},
    "felt": {"catalog_key": "fabric_warm", "tint": [0.07, 0.065, 0.06, 1], "normal": .8, "roughness": 1.},
    "paper": {"catalog_key": "paper", "tint": [0.93, 0.90, 0.80, 1], "normal": .4, "roughness": 1.},
    "brass": {"catalog_key": "brass_dull", "tint": [1, 1, 1, 1], "normal": 1., "roughness": 1.},
    "bronze": {"catalog_key": "bronze_sheet", "tint": [0.55, 0.42, 0.26, 1], "normal": 1., "roughness": 1.},
    "bakelite": {"catalog_key": "bakelite_black", "tint": [1, 1, 1, 1], "normal": 1., "roughness": 1.},
    "iron": {"catalog_key": "iron_blackened", "tint": [1, 1, 1, 1], "normal": 1., "roughness": 1.},
    "radiator": {"catalog_key": "radiator_cast_iron", "tint": [1, 1, 1, 1], "normal": 1., "roughness": 1.},
    "valve_brass": {"catalog_key": "radiator_service_brass", "tint": [1, 1, 1, 1], "normal": 1., "roughness": 1.},
    "coir": {"catalog_key": "fabric_warm", "tint": [0.50, 0.37, 0.21, 1], "normal": 1., "roughness": 1.},
    # Gas, not electric: an incandescent Welsbach mantle burns a hard
    # greenish white; the etched shade and the lantern glass glow round it.
    "mantle_lit": {"catalog_key": "milk_glass", "tint": [1, 1, .92, 1], "normal": .3, "roughness": 1., "emission": [1.0, 0.96, 0.80, 3.0]},
    "shade_lit": {"catalog_key": "milk_glass", "tint": [.96, .93, .86, 1], "normal": .5, "roughness": 1., "emission": [1.0, 0.86, 0.62, 0.55]},
    "pane_lit": {"catalog_key": "milk_glass", "tint": [.90, .86, .74, 1], "normal": .5, "roughness": 1., "emission": [1.0, 0.82, 0.55, 0.7]},
}
for spec in FINISHES.values():
    spec.setdefault("pigment", 1.0)

# ---------------------------------------------------------------- geometry

scratch = None


def _clean(bm):
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
    bmesh.ops.dissolve_degenerate(bm, edges=bm.edges[:], dist=1e-6)
    bad = [f for f in bm.faces if f.calc_area() < 1e-9]
    if bad:
        bmesh.ops.delete(bm, geom=bad, context="FACES")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])


def _obj(bm, name="part"):
    _clean(bm)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    scratch.objects.link(obj)
    return obj


def box(c, s, bevel=0.0, seg=1):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(s), verts=bm.verts)
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=bm.edges[:], offset=min(bevel, min(s) * 0.45),
                segments=seg, profile=0.5, affect="EDGES", clamp_overlap=True)
    bmesh.ops.translate(bm, vec=Vector(c), verts=bm.verts)
    return _obj(bm, "box")


def _axis_matrix(axis):
    # Primitive axis is Z; turn it onto the requested axis.
    if axis == "X":
        return Matrix.Rotation(math.pi / 2, 4, "Y")
    if axis == "Y":
        return Matrix.Rotation(-math.pi / 2, 4, "X")
    return Matrix.Identity(4)


def cyl(c, r, depth, axis="Z", n=16, r2=None):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=n,
            radius1=r, radius2=r if r2 is None else r2, depth=depth)
    bmesh.ops.transform(bm, matrix=Matrix.Translation(Vector(c)) @ _axis_matrix(axis), verts=bm.verts)
    return _obj(bm, "cyl")


def sphere(c, r, scale=(1, 1, 1), seg=12, rings=8):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=r)
    bmesh.ops.scale(bm, vec=Vector(scale), verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector(c), verts=bm.verts)
    return _obj(bm, "sphere")


def torus(c, R, r, axis="Z", n1=24, n2=8):
    bm = bmesh.new()
    rings = []
    for i in range(n1):
        a = 2 * math.pi * i / n1
        rings.append([bm.verts.new(((R + r * math.cos(2 * math.pi * j / n2)) * math.cos(a),
                (R + r * math.cos(2 * math.pi * j / n2)) * math.sin(a),
                r * math.sin(2 * math.pi * j / n2))) for j in range(n2)])
    for i in range(n1):
        a, b = rings[i], rings[(i + 1) % n1]
        for j in range(n2):
            bm.faces.new((a[j], b[j], b[(j + 1) % n2], a[(j + 1) % n2]))
    bmesh.ops.transform(bm, matrix=Matrix.Translation(Vector(c)) @ _axis_matrix(axis), verts=bm.verts)
    return _obj(bm, "torus")


def lathe(profile_rz, c, axis="Z", n=16):
    """Revolve (radius, height) points about `axis`, closing the loop."""
    bm = bmesh.new()
    rows = [[bm.verts.new((r * math.cos(2 * math.pi * i / n), r * math.sin(2 * math.pi * i / n), z)) for i in range(n)]
            for r, z in profile_rz]
    for a, b in zip(rows, rows[1:] + rows[:1]):
        for i in range(n):
            bm.faces.new((a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]))
    bmesh.ops.transform(bm, matrix=Matrix.Translation(Vector(c)) @ _axis_matrix(axis), verts=bm.verts)
    return _obj(bm, "lathe")


def tube(points, r, n=6, cap=True):
    """Sweep a circle along a polyline: arms, cage ribs, hooks, pipes."""
    pts = [Vector(p) for p in points]
    bm = bmesh.new()
    rings = []
    u = None
    for i, p in enumerate(pts):
        d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        if u is None:
            seed = Vector((0, 0, 1)) if abs(d.z) < .9 else Vector((1, 0, 0))
            u = d.cross(seed).normalized()
        else:
            # Parallel transport: keep the section from twisting at bends.
            u = (u - d * u.dot(d)).normalized()
        v = d.cross(u).normalized()
        rings.append([bm.verts.new(p + (u * math.cos(2 * math.pi * k / n) + v * math.sin(2 * math.pi * k / n)) * r) for k in range(n)])
    for a, b in zip(rings, rings[1:]):
        for k in range(n):
            bm.faces.new((a[k], a[(k + 1) % n], b[(k + 1) % n], b[k]))
    if cap:
        bm.faces.new(rings[0][::-1])
        bm.faces.new(rings[-1])
    return _obj(bm, "tube")


def add(parts, finish, *objs):
    parts.setdefault(finish, []).extend(objs)


# ---------------------------------------------------------------- stocks
# Wall stocks below; gas_pipe_vestibule is the one frame stock, authored in
# the blockout frame and placed at the blockout origin.

def directory_board():
    """Wall case of stained oak round a black felt letter board. The brass
    header strip and the felt take Label3D lettering; neither carries any."""
    p = {}
    add(p, "oak", box((0, -0.006, 0), (0.58, 0.012, 0.88), 0.002))
    for x in (-0.2925, 0.2925):
        add(p, "oak", box((x, -0.025, 0), (0.055, 0.05, 0.94), 0.006))
    for z in (-0.4425, 0.4425):
        add(p, "oak", box((0, -0.025, z), (0.53, 0.05, 0.055), 0.006))
    add(p, "oak", box((0, -0.021, 0.322), (0.53, 0.03, 0.018), 0.003))
    add(p, "felt", box((0, -0.016, -0.045), (0.53, 0.008, 0.71)))
    add(p, "brass", box((0, -0.0135, 0.378), (0.40, 0.003, 0.058), 0.001))
    for x in (-0.22, 0.22):
        add(p, "brass", box((x, -0.0015, 0.49), (0.03, 0.003, 0.05), 0.0008),
                cyl((x, -0.004, 0.502), 0.004, 0.003, "Y", 8))
    return p


def notice_frame():
    """A narrow stained-oak frame screwed to the wall over a printed sheet."""
    p = {}
    add(p, "paper", box((0, -0.006, 0), (0.30, 0.003, 0.40)))
    add(p, "oak", box((0, -0.002, 0), (0.33, 0.004, 0.43)))
    for x in (-0.1575, 0.1575):
        add(p, "oak", box((x, -0.011, 0), (0.025, 0.022, 0.44), 0.003))
    for z in (-0.2075, 0.2075):
        add(p, "oak", box((0, -0.011, z), (0.29, 0.022, 0.025), 0.003))
    for x in (-0.1575, 0.1575):
        for z in (-0.2075, 0.2075):
            add(p, "brass", cyl((x, -0.0225, z), 0.0045, 0.002, "Y", 8))
    return p


def bronze_plaque():
    """The EST. 1928 plaque: a cast bronze tablet with a raised border and
    four bronze screws. Origin at the tablet centre; its back is +Y 0.0225."""
    p = {}
    add(p, "bronze", box((0, 0, 0), (0.90, 0.045, 0.62), 0.008, 2))
    for x in (-0.42, 0.42):
        add(p, "bronze", box((x, -0.0255, 0), (0.022, 0.007, 0.58), 0.002))
    for z in (-0.28, 0.28):
        add(p, "bronze", box((0, -0.0255, z), (0.862, 0.007, 0.022), 0.002))
    for x in (-0.385, 0.385):
        for z in (-0.245, 0.245):
            add(p, "bronze", cyl((x, -0.0265, z), 0.014, 0.008, "Y", 12))
    return p


def signal_point():
    """The Vantry point (Bible VIII.3): a flush brass outlet with a Bakelite
    jack boss, set beside the Bakelite power socket. Nothing is plugged in."""
    p = {}
    add(p, "brass", box((-0.05, -0.003, 0), (0.075, 0.006, 0.115), 0.002))
    add(p, "bakelite", cyl((-0.05, -0.011, 0.012), 0.017, 0.011, "Y", 16))
    add(p, "brass", torus((-0.05, -0.0168, 0.012), 0.0085, 0.0022, "Y", 16, 6))
    for z in (-0.042, 0.045):
        add(p, "brass", cyl((-0.05, -0.007, z), 0.0042, 0.003, "Y", 8))
    add(p, "bakelite", box((0.05, -0.004, 0), (0.075, 0.008, 0.075), 0.003))
    for x in (0.038, 0.062):
        add(p, "brass", torus((0.05 + (x - 0.05), -0.0085, 0.004), 0.0045, 0.0014, "Y", 12, 5))
    add(p, "brass", cyl((0.05, -0.0085, -0.025), 0.0038, 0.002, "Y", 8))
    return p


SECTIONS = 8
PITCH = 0.068


def radiator():
    """One-pipe steam (Bible VIII.5.c): a cast column radiator on feet, its
    bottom-fed supply valve and floor stub at one end, the air vent high at
    the other. Dress only: it is not on the house heating graph."""
    p = {}
    length = (SECTIONS - 1) * PITCH
    for i in range(SECTIONS):
        x = -length / 2 + i * PITCH
        for y in (-0.072, -0.138):
            add(p, "radiator", cyl((x, y, 0.40), 0.026, 0.56, "Z", 12),
                    sphere((x, y, 0.68), 0.026, (1, 1, 0.7), 12, 6),
                    sphere((x, y, 0.12), 0.026, (1, 1, 0.7), 12, 6))
        add(p, "radiator", box((x, -0.105, 0.40), (0.012, 0.05, 0.50)))
    for y in (-0.072, -0.138):
        for z in (0.135, 0.665):
            add(p, "radiator", cyl((0, y, z), 0.019, length + 0.04, "X", 10))
    for x in (-length / 2, length / 2):
        add(p, "radiator", box((x, -0.105, 0.05), (0.05, 0.11, 0.10), 0.006))
    vx = -length / 2 - 0.075
    add(p, "valve_brass", cyl((vx + 0.03, -0.105, 0.135), 0.021, 0.07, "X", 12),
            cyl((vx, -0.105, 0.15), 0.026, 0.07, "Z", 12),
            torus((vx, -0.105, 0.225), 0.034, 0.005, "Z", 18, 6),
            cyl((vx, -0.105, 0.205), 0.006, 0.035, "Z", 8))
    add(p, "iron", cyl((vx, -0.105, 0.055), 0.019, 0.11, "Z", 12))
    add(p, "iron", cyl((vx, -0.105, 0.003), 0.045, 0.006, "Z", 16))
    ax = length / 2 + 0.03
    add(p, "valve_brass", cyl((ax, -0.105, 0.60), 0.011, 0.04, "X", 10),
            cyl((ax + 0.02, -0.105, 0.625), 0.009, 0.05, "Z", 10),
            sphere((ax + 0.02, -0.105, 0.655), 0.008, (1, 1, 1), 8, 5))
    return p


def door_mat():
    """Coir, worn thinner where the door is."""
    p = {}
    add(p, "coir", box((0, 0, 0.009), (0.95, 0.60, 0.018), 0.006))
    return p


def coat_hooks():
    """A stained-oak rail with three blackened cast-iron double hooks."""
    p = {}
    add(p, "oak", box((0, -0.011, 0), (0.62, 0.022, 0.085), 0.004))
    for x in (-0.27, 0.27):
        add(p, "brass", cyl((x, -0.0225, 0), 0.0045, 0.002, "Y", 8))
    for x in (-0.18, 0.0, 0.18):
        add(p, "iron", cyl((x, -0.025, 0.0), 0.016, 0.007, "Y", 12),
                tube([(x, -0.026, 0.004), (x, -0.07, 0.016), (x, -0.086, 0.048), (x, -0.077, 0.064)], 0.0055, 8),
                tube([(x, -0.026, -0.006), (x, -0.092, -0.024), (x, -0.108, 0.004), (x, -0.098, 0.022)], 0.006, 8),
                sphere((x, -0.077, 0.066), 0.0065, (1, 1, 1), 8, 5),
                sphere((x, -0.098, 0.024), 0.007, (1, 1, 1), 8, 5))
    return p


def gas_bracket():
    """Inverted-mantle gas bracket (after c. 1905): a brass rosette fed from
    above by the surface pipe, a swing arm with its gas cock and flat key, a
    burner hanging an inverted mantle inside an etched bell shade."""
    p = {}
    add(p, "brass", cyl((0, -0.008, 0), 0.05, 0.016, "Y", 20),
            cyl((0, -0.022, 0), 0.018, 0.014, "Y", 12),
            cyl((0, -0.022, 0.035), 0.0105, 0.04, "Z", 10),
            sphere((0, -0.03, 0), 0.012, (1, 1, 1), 10, 6),
            tube([(0, -0.03, 0), (0, -0.21, 0)], 0.007, 10),
            cyl((0, -0.11, 0), 0.011, 0.03, "Z", 12),
            box((0, -0.11, 0.024), (0.045, 0.005, 0.012), 0.001),
            sphere((0, -0.21, 0), 0.011, (1, 1, 1), 10, 6),
            tube([(0, -0.21, 0), (0, -0.21, -0.065)], 0.0065, 10),
            torus((0, -0.21, -0.07), 0.042, 0.0035, "Z", 24, 6),
            cyl((0, -0.21, -0.09), 0.013, 0.04, "Z", 12))
    for k in range(3):
        a = 2 * math.pi * k / 3
        add(p, "brass", tube([(0, -0.21, -0.065), (0.042 * math.cos(a), -0.21 + 0.042 * math.sin(a), -0.07)], 0.0025, 5))
    # A 5.5 inch etched bell, open below so the mantle shows from underneath.
    bell = [(0.022, -0.068), (0.042, -0.077), (0.060, -0.108), (0.068, -0.145), (0.071, -0.165),
            (0.066, -0.165), (0.063, -0.146), (0.055, -0.111), (0.039, -0.082), (0.022, -0.074)]
    add(p, "shade_lit", lathe(bell, (0, -0.21, 0), "Z", 24))
    add(p, "mantle_lit", sphere((0, -0.21, -0.132), 0.02, (1, 1, 1.45), 12, 8))
    return p


def gas_lantern():
    """Street-door gas lantern: a blackened iron wall plate and scrolled arm,
    a tapered four-light lantern with a vented cap, an inverted mantle within.
    The supply comes through the masonry into the wall plate."""
    p = {}
    add(p, "iron", box((0, -0.01, 0.0), (0.10, 0.02, 0.18), 0.004),
            tube([(0, -0.02, 0.04), (0, -0.33, 0.04)], 0.011, 10),
            tube([(0, -0.02, -0.08), (0, -0.09, -0.04), (0, -0.17, 0.0), (0, -0.25, 0.03), (0, -0.30, 0.04)], 0.007, 8),
            torus((0, -0.12, -0.005), 0.026, 0.004, "X", 18, 5),
            torus((0, -0.33, 0.012), 0.022, 0.004, "X", 16, 5),
            cyl((0, -0.33, -0.025), 0.004, 0.035, "Z", 6))
    for x, z in [(-0.035, 0.06), (0.035, 0.06), (-0.035, -0.06), (0.035, -0.06)]:
        add(p, "iron", cyl((x, -0.022, z), 0.007, 0.006, "Y", 8))
    cy, top, bottom = -0.33, -0.05, -0.35
    cap = cyl((0, cy, top + 0.035), 0.125, 0.07, "Z", 4, 0.03)
    cap.data.transform(Matrix.Translation((0, cy, 0)) @ Matrix.Rotation(math.pi / 4, 4, "Z") @ Matrix.Translation((0, -cy, 0)))
    add(p, "iron", cap, cyl((0, cy, top + 0.085), 0.025, 0.03, "Z", 10),
            cyl((0, cy, top + 0.105), 0.035, 0.008, "Z", 12))
    glass = cyl((0, cy, (top + bottom) / 2), 0.115, top - bottom, "Z", 4, 0.085)
    glass.data.transform(Matrix.Translation((0, cy, 0)) @ Matrix.Rotation(math.pi / 4, 4, "Z") @ Matrix.Translation((0, -cy, 0)))
    add(p, "pane_lit", glass)
    for sx in (-1, 1):
        for sy in (-1, 1):
            add(p, "iron", tube([(sx * 0.083, cy + sy * 0.083, top), (sx * 0.062, cy + sy * 0.062, bottom)], 0.006, 6))
    base = cyl((0, cy, bottom - 0.012), 0.09, 0.024, "Z", 4, 0.06)
    base.data.transform(Matrix.Translation((0, cy, 0)) @ Matrix.Rotation(math.pi / 4, 4, "Z") @ Matrix.Translation((0, -cy, 0)))
    add(p, "iron", base, sphere((0, cy, bottom - 0.04), 0.012, (1, 1, 1), 8, 5))
    return p


PIPE_R = 0.0107       # half-inch black iron gas pipe, 21.3 mm outside
PIPE_OFF = 0.022      # pipe centreline off the wall face, on its straps


def gas_pipe(points):
    """Surface-run black iron supply in the blockout frame (Godot x, y, z),
    from a floor flange: malleable elbows at each bend, a plug cock low on
    the riser, straps to the wall about every 0.8 m."""
    b = [(x, -z, y) for x, y, z in points]
    p = {}
    add(p, "iron", tube(b, PIPE_R, 10))
    for q in b[1:-1]:
        add(p, "iron", sphere(q, PIPE_R * 1.55, (1, 1, 1), 10, 6))
    x, y, z = b[0]
    add(p, "iron", cyl((x, y, z + 0.004), 0.034, 0.008, "Z", 14),
            cyl((x, y, z + 0.03), PIPE_R * 1.45, 0.04, "Z", 10))
    add(p, "brass", cyl((x, y, z + 0.9), PIPE_R * 1.7, 0.05, "Z", 10),
            box((x, y, z + 0.9), (0.016, 0.05, 0.016), 0.002))
    wall_n = Vector((0, 0, 0))
    for a, c in zip(b, b[1:]):
        a, c = Vector(a), Vector(c)
        n = max(1, int((c - a).length / 0.8))
        for i in range(n):
            q = a + (c - a) * ((i + 0.5) / n)
            d = (c - a).normalized()
            add(p, "iron", box(q, (0.012 if abs(d.x) < .5 else 0.03, 0.012, 0.03 if abs(d.z) < .5 else 0.012), 0.002))
    return p


STOCKS = {
    "directory_board": directory_board,
    "notice_frame": notice_frame,
    "bronze_plaque": bronze_plaque,
    "signal_point": signal_point,
    "radiator": radiator,
    "door_mat": door_mat,
    "coat_hooks": coat_hooks,
    "gas_bracket": gas_bracket,
    "gas_lantern": gas_lantern,
}

PERIOD = {
    "directory_board": "Felt changeable-letter tenant directory in a stained oak wall case.",
    "notice_frame": "A printed house notice in a narrow oak frame, screwed up so nobody takes it.",
    "bronze_plaque": "The building's cast bronze identity plaque, EST. 1928, moved in from the pier.",
    "signal_point": "Vantry & Co. brass flush signal outlet beside the house power socket (Bible VIII.3).",
    "radiator": "Cast-iron one-pipe steam column radiator with bottom-fed valve and air vent (Bible VIII.5.c).",
    "door_mat": "Coir door mat.",
    "coat_hooks": "Cast-iron double coat hooks on a stained oak rail.",
    "gas_bracket": "Inverted Welsbach mantle gas bracket with swing arm, gas cock and etched bell shade (after c. 1905).",
    "gas_lantern": "Wall-bracket gas lantern with a tapered four-light frame and an inverted mantle.",
    "gas_pipe_vestibule": "Surface-run half-inch black iron gas supply, floor flange, plug cock and straps.",
}


def main():
    global scratch
    bpy.ops.wm.read_factory_settings(use_empty=True)
    catalog = json.loads((ROOT / "game/data/runtime_material_sets.json").read_text())["materials"]
    scratch = bpy.data.collections.new("EditableVestibuleParts")
    bpy.context.scene.collection.children.link(scratch)
    exports = bpy.data.collections.new("EntryVestibuleExport")
    bpy.context.scene.collection.children.link(exports)
    mats = {}
    for fid, spec in FINISHES.items():
        mats[fid] = material(ROOT, fid, spec, catalog)
        if "emission" in spec:
            node = mats[fid].node_tree.nodes["Principled BSDF"]
            node.inputs["Emission Color"].default_value = spec["emission"][:3] + [1.0]
            node.inputs["Emission Strength"].default_value = spec["emission"][3]
    # The surface gas run is derived from the placement data, so the pipe
    # always lands on the bracket's rosette: up the riser corner, along the
    # wall under the cornice, and down into the rosette's top boss.
    place = json.loads((ROOT / "game/data/orison_v2/entry_vestibule.json").read_text(encoding="utf-8"))
    gas = place["gas"]
    stocks = dict(STOCKS)
    for row in place["lamps"]["fittings"]:
        if "wall" not in row:
            continue
        assert row["wall"] == "north", "the gas run is authored for the north wall"
        z = place["wall_faces"]["north"] - PIPE_OFF
        rx, top = gas["riser"], gas["run_height"]
        x, y = row["along"], row["height"] + 0.055
        route = [(rx, 0.0, z), (rx, top, z), (x, top, z), (x, y, z)]
        stocks["gas_pipe_vestibule"] = lambda route=route: gas_pipe(route)
    triangles = {}
    for name, build in stocks.items():
        parts = build()
        triangles[name] = 0
        for fid, objs in parts.items():
            assert fid in FINISHES, (name, fid)
            obj = partition(exports, f"{name}__{fid}", objs, FINISHES[fid], mats[fid], Matrix.Identity(4), catalog)
            triangles[name] += len(obj.data.polygons)
    scratch.hide_render = True
    scratch.hide_viewport = True
    proof = export(ROOT, FAMILY, exports, material_names_only=True, staged_output=True)
    runtime_finish_keys = ("catalog_key", "tint", "normal", "roughness", "emission")
    table = {
        "schema": "orison.v2.entry-vestibule-stock.v1",
        "stock": "res://assets/props/v2_entry_vestibule.glb",
        "finishes": [dict({"id": fid}, **{k: v for k, v in spec.items() if k in runtime_finish_keys}) for fid, spec in FINISHES.items()],
        "stocks": sorted(stocks),
    }
    out = ROOT / "game/data/orison_v2/entry_vestibule_stock.json"
    out.write_text(json.dumps(table, indent=1) + "\n", newline="\n")
    manifest = {
        "evidence_class": "INERT",
        "source": "art/blender/scripts/build_v2_entry_vestibule.py",
        "design": "design/V2_ENTRY_VESTIBULE_2026-10-24.md",
        "runtime_table": "game/data/orison_v2/entry_vestibule_stock.json",
        "export_proof": {k: v for k, v in proof.items() if k != "asset"},
        "stocks": [{"id": k, "signal": k == "signal_point", "period": PERIOD[k]} for k in stocks],
        "triangles": triangles,
    }
    (ROOT / "art/data/v2_entry_vestibule_manifest.json").write_text(json.dumps(manifest, indent=1) + "\n", newline="\n")
    print(json.dumps({"proof": proof, "triangles": triangles}))


if __name__ == "__main__":
    main()
