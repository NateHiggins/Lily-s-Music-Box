"""V2 period street traffic for Queens, November 1928 to November 1929.

Rule of Signal (design/ORISON_BIBLE.md VIII.2): anything that carries,
captures, switches, stores or reproduces a signal is forty years early. The
police sound wagon, the telephone line truck, the Record's broadcast car, the
cab's dispatch set and the valve merchant's cargo are the only advanced parts.
Every chassis, horse, wheel and seat is 1927 and second-hand. Bakelite, wet
cells, cloth-braided flex, brass, nickel, cast and blackened iron. No
aluminium and no stainless anywhere.

Design packet: design/V2_PERIOD_TRAFFIC_2026-10-24.md.

Exports one native-stock GLB, game/assets/props/v2_period_traffic.glb, with
one object per (stock, finish) named `<stock>__<finish>`, and writes the
runtime table game/data/orison_v2/exterior/street_traffic.json from the same
specification. Nose is Blender +X, left is +Y, ground is Z 0. Wheels, horse
legs and seated figures are separate shared stocks so the runtime can turn,
swing and omit them. UVs are the shared metre charts (fabrication_native_batch).
Never hand-edit the GLB or the JSON; edit this recipe and rerun:

    blender -b -P art/blender/scripts/build_v2_period_traffic.py
"""
from pathlib import Path
import sys, json, math, hashlib
import bpy, bmesh
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(Path(__file__).parent))
from fabrication_native_batch import material, partition, export

FAMILY = "v2_period_traffic"

# Finish id -> catalogue stock. `paint` finishes take the runtime per-vehicle
# colour; their tint here is only the Blender review colour.
FINISHES = {
    "coachwork": {"catalog_key": "car_paint", "tint": [0.30, 0.31, 0.34, 1], "normal": .55, "roughness": .62, "paint": True},
    "wagon_paint": {"catalog_key": "door_paint", "tint": [0.45, 0.38, 0.22, 1], "normal": .8, "roughness": 1., "paint": True},
    "japan_black": {"catalog_key": "car_paint", "tint": [0.075, 0.072, 0.07, 1], "normal": .6, "roughness": .55},
    "running_iron": {"catalog_key": "iron_blackened", "tint": [1, 1, 1, 1], "normal": 1., "roughness": 1.},
    "cast_iron": {"catalog_key": "cast_iron", "tint": [1, 1, 1, 1], "normal": 1., "roughness": 1.},
    "hardwood": {"catalog_key": "wood_dark", "tint": [1, 1, 1, 1], "normal": 1., "roughness": 1.},
    "timber": {"catalog_key": "timber", "tint": [1, 1, 1, 1], "normal": 1., "roughness": 1.},
    "tyre": {"catalog_key": "rubber_aged", "tint": [1, 1, 1, 1], "normal": 1., "roughness": 1.},
    "nickel": {"catalog_key": "nickel_plated", "tint": [1, 1, 1, 1], "normal": 1., "roughness": 1.},
    "brass": {"catalog_key": "brass_dull", "tint": [1, 1, 1, 1], "normal": 1., "roughness": 1.},
    "lamp_lit": {"catalog_key": "milk_glass", "tint": [1, .93, .80, 1], "normal": .5, "roughness": 1., "emission": [1.0, 0.80, 0.52, 2.2]},
    "lamp_tail": {"catalog_key": "milk_glass", "tint": [.75, .16, .10, 1], "normal": .5, "roughness": 1., "emission": [0.85, 0.10, 0.05, 1.6]},
    "lamp_oil": {"catalog_key": "milk_glass", "tint": [1, .82, .58, 1], "normal": .5, "roughness": 1., "emission": [1.0, 0.58, 0.26, 1.2]},
    "valve_glow": {"catalog_key": "milk_glass", "tint": [1, .7, .45, 1], "normal": .4, "roughness": 1., "emission": [1.0, 0.42, 0.14, 1.4]},
    "leather": {"catalog_key": "leather_worn", "tint": [1, 1, 1, 1], "normal": 1., "roughness": 1.},
    "canvas": {"catalog_key": "fabric_warm", "tint": [0.62, 0.57, 0.46, 1], "normal": 1., "roughness": 1.},
    "tarp": {"catalog_key": "fabric_warm", "tint": [0.20, 0.22, 0.17, 1], "normal": 1., "roughness": 1.},
    "hood_cloth": {"catalog_key": "fabric_warm", "tint": [0.10, 0.10, 0.10, 1], "normal": 1., "roughness": 1.},
    "upholstery": {"catalog_key": "fabric_warm", "tint": [0.10, 0.085, 0.075, 1], "normal": .8, "roughness": 1.},
    "wool": {"catalog_key": "fabric_warm", "tint": [0.17, 0.16, 0.17, 1], "normal": 1., "roughness": 1.},
    "skin": {"catalog_key": "linen", "tint": [0.78, 0.60, 0.50, 1], "normal": .4, "roughness": 1.},
    "hide": {"catalog_key": "leather_worn", "tint": [0.42, 0.26, 0.15, 1], "normal": .7, "roughness": 1., "paint": True},
    "hoof": {"catalog_key": "leather_worn", "tint": [0.12, 0.10, 0.09, 1], "normal": 1., "roughness": 1.},
    "bakelite": {"catalog_key": "bakelite_black", "tint": [1, 1, 1, 1], "normal": 1., "roughness": 1.},
    "coal": {"catalog_key": "soot", "tint": [0.55, 0.55, 0.58, 1], "normal": 1., "roughness": .8},
    "silk_flex": {"catalog_key": "fabric_warm", "tint": [0.55, 0.13, 0.08, 1], "normal": 1., "roughness": 1.},
    "produce": {"catalog_key": "plant", "tint": [1, 1, 1, 1], "normal": 1., "roughness": 1.},
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


def _apply(obj, matrix):
    obj.data.transform(matrix)
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


def torus(c, R, r, axis="Y", n1=24, n2=8, flat=1.0):
    """Ring about `axis`; `flat` squashes the tube section across the axis."""
    bm = bmesh.new()
    rings = []
    for i in range(n1):
        a = 2 * math.pi * i / n1
        ring = []
        for j in range(n2):
            b = 2 * math.pi * j / n2
            rr = R + r * math.cos(b)
            ring.append(bm.verts.new((rr * math.cos(a), rr * math.sin(a), r * flat * math.sin(b))))
        rings.append(ring)
    for i in range(n1):
        for j in range(n2):
            a, b = rings[i], rings[(i + 1) % n1]
            bm.faces.new((a[j], b[j], b[(j + 1) % n2], a[(j + 1) % n2]))
    bmesh.ops.transform(bm, matrix=Matrix.Translation(Vector(c)) @ _axis_matrix(axis), verts=bm.verts)
    return _obj(bm, "torus")


def ring(c, r_out, r_in, width, axis="Y", n=24):
    """Rectangular-section hoop: iron tyres, felloes, solid rubber."""
    bm = bmesh.new()
    loops = []
    for rad, z in [(r_out, -width / 2), (r_out, width / 2), (r_in, width / 2), (r_in, -width / 2)]:
        loops.append([bm.verts.new((rad * math.cos(2 * math.pi * i / n), rad * math.sin(2 * math.pi * i / n), z)) for i in range(n)])
    for k in range(4):
        a, b = loops[k], loops[(k + 1) % 4]
        for i in range(n):
            bm.faces.new((a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]))
    bmesh.ops.transform(bm, matrix=Matrix.Translation(Vector(c)) @ _axis_matrix(axis), verts=bm.verts)
    return _obj(bm, "ring")


def prism(profile_xz, y0, y1, bevel=0.0):
    """Side profile in XZ (counter-clockwise seen from +Y) extruded across Y."""
    bm = bmesh.new()
    a = [bm.verts.new((x, y0, z)) for x, z in profile_xz]
    b = [bm.verts.new((x, y1, z)) for x, z in profile_xz]
    n = len(profile_xz)
    bm.faces.new(a[::-1])
    bm.faces.new(b)
    for i in range(n):
        bm.faces.new((a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]))
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=bm.edges[:], offset=bevel, segments=1, profile=0.5,
                affect="EDGES", clamp_overlap=True)
    return _obj(bm, "prism")


def lathe(profile_rz, c, axis="Z", n=16):
    """Revolve (radius, height) points about `axis`; radius 0 points close."""
    bm = bmesh.new()
    rows = []
    for r, z in profile_rz:
        if r <= 1e-6:
            rows.append([bm.verts.new((0, 0, z))])
        else:
            rows.append([bm.verts.new((r * math.cos(2 * math.pi * i / n), r * math.sin(2 * math.pi * i / n), z)) for i in range(n)])
    for a, b in zip(rows, rows[1:]):
        if len(a) == 1 and len(b) == 1:
            continue
        for i in range(n):
            if len(a) == 1:
                bm.faces.new((a[0], b[i], b[(i + 1) % n]))
            elif len(b) == 1:
                bm.faces.new((a[i], b[0], a[(i + 1) % n]))
            else:
                bm.faces.new((a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]))
    bmesh.ops.transform(bm, matrix=Matrix.Translation(Vector(c)) @ _axis_matrix(axis), verts=bm.verts)
    return _obj(bm, "lathe")


def tube(points, r, n=6, cap=True):
    """Sweep a circle along a polyline: shafts, rails, aerial wires, traces."""
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


def arc_fender(cx, cz, r, y0, y1, a0, a1, t=0.025, n=10):
    """Curved mudguard over a wheel, from angle a0 to a1 (degrees, 0 = nose)."""
    prof = []
    for i in range(n + 1):
        a = math.radians(a0 + (a1 - a0) * i / n)
        prof.append((cx + (r + t) * math.cos(a), cz + (r + t) * math.sin(a)))
    for i in range(n, -1, -1):
        a = math.radians(a0 + (a1 - a0) * i / n)
        prof.append((cx + r * math.cos(a), cz + r * math.sin(a)))
    return prism(prof, y0, y1)


def skin(points, edges, radii, subdiv=1):
    """Organic stock from a skin-modifier skeleton: horses and figures."""
    mesh = bpy.data.meshes.new("skin")
    mesh.from_pydata(points, edges, [])
    obj = bpy.data.objects.new("skin", mesh)
    scratch.objects.link(obj)
    mod = obj.modifiers.new("skin", "SKIN")
    mod.use_smooth_shade = True
    for v, rad in zip(mesh.skin_vertices[0].data, radii):
        v.radius = rad if isinstance(rad, (tuple, list)) else (rad, rad)
    mesh.skin_vertices[0].data[0].use_root = True
    if subdiv:
        sub = obj.modifiers.new("sub", "SUBSURF")
        sub.levels = subdiv
    dg = bpy.context.evaluated_depsgraph_get()
    baked = bpy.data.meshes.new_from_object(obj.evaluated_get(dg))
    bpy.data.objects.remove(obj)
    bm = bmesh.new()
    bm.from_mesh(baked)
    bpy.data.meshes.remove(baked)
    return _obj(bm, "skin")


def mirror_y(builder):
    return [builder(1), builder(-1)]


# ---------------------------------------------------------------- shared stock

def wheel_stock(kind):
    """Reference wheels, axle on Y, centred at the origin. Runtime scales them."""
    R = 0.5
    p = {}
    if kind == "wagon":
        p["running_iron"] = [ring((0, 0, 0), R, R - 0.022, 0.07, n=28)]
        p["hardwood"] = [ring((0, 0, 0), R - 0.022, R - 0.075, 0.065, n=28)]
        p["hardwood"] += [tube([(0, 0, 0), (math.cos(a) * (R - 0.06), 0, math.sin(a) * (R - 0.06))], 0.018, 6)
                for a in [2 * math.pi * i / 12 for i in range(12)]]
        p["cast_iron"] = [cyl((0, 0, 0), 0.075, 0.18, "Y", 12, 0.06)]
    elif kind == "artillery":
        p["tyre"] = [torus((0, 0, 0), R - 0.07, 0.07, n1=28, n2=8, flat=1.05)]
        p["hardwood"] = [ring((0, 0, 0), R - 0.12, R - 0.17, 0.08, n=28)]
        p["hardwood"] += [prism([(0.06, -0.025), (R - 0.15, -0.012), (R - 0.15, 0.012), (0.06, 0.025)], -0.03, 0.03)]
        base = p["hardwood"].pop()
        for i in range(12):
            o = base.copy()
            o.data = base.data.copy()
            scratch.objects.link(o)
            _apply(o, Matrix.Rotation(2 * math.pi * i / 12, 4, "Y"))
            p["hardwood"].append(o)
        bpy.data.objects.remove(base)
        p["nickel"] = [lathe([(0, 0.11), (0.05, 0.10), (0.075, 0.06), (0.08, 0.0)], (0, 0, 0), "Y", 14)]
        p["japan_black"] = [cyl((0, 0, 0), 0.07, 0.12, "Y", 14)]
    elif kind == "wire":
        p["tyre"] = [torus((0, 0, 0), R - 0.075, 0.075, n1=28, n2=8)]
        p["japan_black"] = [ring((0, 0, 0), R - 0.13, R - 0.16, 0.07, n=28)]
        spokes = []
        for i in range(24):
            a = 2 * math.pi * i / 24
            side = 0.05 if i % 2 else -0.05
            spokes.append(tube([(math.cos(a) * 0.07, side, math.sin(a) * 0.07), (math.cos(a + .2) * (R - 0.155), 0, math.sin(a + .2) * (R - 0.155))], 0.006, 4))
        p["nickel"] = spokes + [lathe([(0, 0.1), (0.045, 0.09), (0.07, 0.05), (0.075, -0.05), (0, -0.06)], (0, 0, 0), "Y", 14)]
    elif kind == "disc":
        p["tyre"] = [torus((0, 0, 0), R - 0.08, 0.08, n1=28, n2=8, flat=1.1)]
        p["japan_black"] = [lathe([(0, 0.05), (0.11, 0.05), (0.2, 0.03), (R - 0.14, 0.045), (R - 0.14, -0.045), (0.2, -0.03), (0, -0.05)], (0, 0, 0), "Y", 24)]
        p["nickel"] = [lathe([(0, 0.11), (0.05, 0.10), (0.07, 0.055)], (0, 0, 0), "Y", 14)]
        p["running_iron"] = [cyl((math.cos(a) * 0.14, 0.055, math.sin(a) * 0.14), 0.014, 0.02, "Y", 6) for a in [2 * math.pi * i / 6 for i in range(6)]]
    elif kind == "solid":
        p["tyre"] = [ring((0, 0, 0), R, R - 0.075, 0.14, n=28)]
        p["cast_iron"] = [ring((0, 0, 0), R - 0.075, R - 0.11, 0.13, n=28), cyl((0, 0, 0), 0.11, 0.2, "Y", 12)]
        for i in range(8):
            a = 2 * math.pi * i / 8
            p["cast_iron"].append(tube([(math.cos(a) * 0.09, 0, math.sin(a) * 0.09), (math.cos(a) * (R - 0.1), 0, math.sin(a) * (R - 0.1))], 0.03, 6))
    return p


def horse_body():
    """A heavy van horse, standing frame without legs. Withers ~1.62 m."""
    pts = [(-0.70, 0, 1.30), (-0.25, 0, 1.30), (0.25, 0, 1.30), (0.62, 0, 1.36),
           (0.86, 0, 1.70), (1.02, 0, 1.86), (1.28, 0, 1.52),
           (-0.80, 0, 1.38), (-0.92, 0, 0.92),
           (1.00, 0.07, 1.98), (1.00, -0.07, 1.98)]
    edges = [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 6), (0, 7), (7, 8), (5, 9), (5, 10)]
    radii = [(0.30, 0.34), (0.34, 0.37), (0.33, 0.37), (0.27, 0.33), (0.16, 0.21), (0.12, 0.14),
             (0.075, 0.09), (0.06, 0.06), (0.04, 0.03), (0.025, 0.03), (0.025, 0.03)]
    p = {"hide": [skin(pts, edges, radii, 1)]}
    p["leather"] = [torus((0.72, 0, 1.55), 0.21, 0.055, "X", 18, 6),
                    box((0.05, 0, 1.68), (0.42, 0.62, 0.06), 0.02),
                    tube([(-0.62, 0.34, 1.25), (-0.92, 0.0, 1.1), (-0.62, -0.34, 1.25)], 0.02, 5, False),
                    tube([(0.72, 0.28, 1.45), (0.05, 0.36, 1.28), (-0.6, 0.36, 1.22)], 0.018, 5),
                    tube([(0.72, -0.28, 1.45), (0.05, -0.36, 1.28), (-0.6, -0.36, 1.22)], 0.018, 5),
                    tube([(1.05, 0.1, 1.8), (1.2, 0.09, 1.55)], 0.015, 5), tube([(1.05, -0.1, 1.8), (1.2, -0.09, 1.55)], 0.015, 5)]
    p["brass"] = [sphere((0.74, 0.2, 1.85), 0.035), sphere((0.74, -0.2, 1.85), 0.035)]
    return p


LEG_LENGTH = 1.12
# Pivots in the horse frame, in Blender axes (x forward, y left, z up).
HORSE_LEGS = [(0.55, 0.19, LEG_LENGTH), (0.55, -0.19, LEG_LENGTH),
              (-0.52, 0.2, LEG_LENGTH), (-0.52, -0.2, LEG_LENGTH)]


def horse_leg():
    L = LEG_LENGTH
    pts = [(0, 0, 0), (0.02, 0, -0.32), (0.03, 0, -0.58), (0.02, 0, -0.88), (0.05, 0, -1.0)]
    radii = [(0.12, 0.10), (0.085, 0.07), (0.06, 0.055), (0.045, 0.042), (0.06, 0.055)]
    return {"hide": [skin(pts, [(0, 1), (1, 2), (2, 3), (3, 4)], radii, 1)],
            "hoof": [cyl((0.05, 0, -L + 0.05), 0.07, 0.1, "Z", 10, 0.06)]}


def seated_figure():
    """Teamster or motorist on a seat; origin at the seat surface."""
    pts = [(0, 0, 0.08), (0.02, 0, 0.36), (0.03, 0, 0.58), (0.04, 0, 0.68),
           (0.42, 0.11, 0.10), (0.46, 0.11, -0.36), (0.58, 0.11, -0.40),
           (0.42, -0.11, 0.10), (0.46, -0.11, -0.36), (0.58, -0.11, -0.40),
           (0.04, 0.2, 0.55), (0.18, 0.24, 0.30), (0.42, 0.14, 0.30),
           (0.04, -0.2, 0.55), (0.18, -0.24, 0.30), (0.42, -0.14, 0.30)]
    edges = [(0, 1), (1, 2), (2, 3), (0, 4), (4, 5), (5, 6), (0, 7), (7, 8), (8, 9),
             (2, 10), (10, 11), (11, 12), (2, 13), (13, 14), (14, 15)]
    radii = [(0.17, 0.15), (0.17, 0.13), (0.2, 0.12), (0.07, 0.07),
             (0.08, 0.08), (0.06, 0.06), (0.05, 0.08), (0.08, 0.08), (0.06, 0.06), (0.05, 0.08),
             (0.06, 0.06), (0.05, 0.05), (0.04, 0.04), (0.06, 0.06), (0.05, 0.05), (0.04, 0.04)]
    return {"wool": [skin(pts, edges, radii, 1), cyl((0.06, 0, 0.88), 0.115, 0.06, "Z", 14, 0.105),
                     prism([(0.08, 0.855), (0.24, 0.85), (0.24, 0.862), (0.08, 0.875)], -0.1, 0.1)],
            "skin": [sphere((0.07, 0, 0.8), 0.095, (1, 0.9, 1.1))]}


# ---------------------------------------------------------------- vehicles
# Each builder returns {finish: [objects]}; `add` merges lists.

def add(parts, finish, *objs):
    parts.setdefault(finish, []).extend(objs)


def shafts(parts, x0, x1, z0, z1, gauge=0.38):
    for s in (1, -1):
        add(parts, "hardwood", tube([(x0, s * gauge, z0), ((x0 + x1) / 2, s * (gauge + 0.04), (z0 + z1) / 2 + 0.05), (x1, s * gauge, z1)], 0.03, 6))
    add(parts, "hardwood", box((x0 + 0.05, 0, z0 - 0.02), (0.07, gauge * 2 + 0.12, 0.06)))


def wagon_gear(parts, xf, xr, rf, rr, track, bed_z):
    """Undercarriage of a horse wagon: reach, bolsters, axles, springs."""
    add(parts, "hardwood", box(((xf + xr) / 2, 0, bed_z - 0.18), (xf - xr + 0.3, 0.12, 0.08)))
    for x, r in ((xf, rf), (xr, rr)):
        add(parts, "running_iron", box((x, 0, r), (0.07, track + 0.12, 0.07)))
        add(parts, "hardwood", box((x, 0, (r + bed_z) / 2), (0.12, track - 0.2, max(0.06, bed_z - r - 0.05))))
        for s in (1, -1):
            add(parts, "running_iron", box((x, s * (track / 2 - 0.22), bed_z - 0.07), (0.6, 0.06, 0.035), 0.01))


def lamp(parts, x, y, z, r, finish="lamp_lit", shell="nickel", axis="X", depth=0.14):
    add(parts, shell, lathe([(0, -depth), (r * 0.6, -depth), (r, -depth * 0.35), (r * 1.05, 0)], (x, y, z), axis, 14))
    add(parts, finish, lathe([(r * 0.95, 0.0), (r * 0.6, 0.02), (0, 0.025)], (x, y, z), axis, 14))


def side_lantern(parts, x, y, z):
    """Kerosene wagon lamp: a japanned box with a lit front glass."""
    add(parts, "japan_black", box((x, y, z), (0.12, 0.12, 0.2), 0.01), cyl((x, y, z + 0.13), 0.035, 0.07, "Z", 8))
    add(parts, "lamp_oil", box((x + 0.062, y, z), (0.008, 0.085, 0.13)))


def ice_wagon():
    p = {}
    wagon_gear(p, 0.95, -1.05, 0.42, 0.55, 1.5, 0.9)
    add(p, "wagon_paint", prism([(-1.7, 0.9), (0.85, 0.9), (0.85, 2.25), (0.75, 2.35), (-1.6, 2.35), (-1.7, 2.25)], -0.78, 0.78, 0.02))
    add(p, "timber", box((-0.42, 0, 2.38), (2.6, 1.7, 0.05), 0.01))
    add(p, "canvas", box((-1.715, 0, 1.65), (0.02, 1.4, 1.2)))
    add(p, "running_iron", tube([(-0.5, 0.81, 1.25), (-0.5, 0.86, 1.05), (-0.42, 0.86, 0.98)], 0.012, 5), tube([(-0.35, 0.81, 1.25), (-0.35, 0.86, 1.05), (-0.43, 0.86, 0.98)], 0.012, 5))
    add(p, "brass", cyl((-1.5, -0.84, 1.75), 0.09, 0.05, "Y", 12), box((-1.5, -0.84, 1.55), (0.02, 0.02, 0.3)))
    # The driver's box and dashboard.
    add(p, "hardwood", box((1.1, 0, 1.42), (0.4, 1.3, 0.08)), box((1.32, 0, 1.15), (0.06, 1.1, 0.5)), box((0.95, 0, 1.6), (0.12, 1.2, 0.3)))
    add(p, "leather", box((1.05, 0, 1.5), (0.32, 1.1, 0.06), 0.015))
    shafts(p, 1.2, 3.1, 1.02, 1.12)
    side_lantern(p, 0.9, 0.82, 1.9)
    side_lantern(p, 0.9, -0.82, 1.9)
    add(p, "lamp_tail", box((-1.72, -0.7, 1.2), (0.01, 0.06, 0.06)))
    return p


def coal_cart():
    p = {}
    wagon_gear(p, 0.85, -0.95, 0.42, 0.5, 1.5, 0.92)
    add(p, "wagon_paint", prism([(-1.55, 0.92), (0.75, 0.92), (0.95, 1.7), (-1.75, 1.7)], -0.62, 0.62, 0.02))
    for s in (1, -1):
        add(p, "wagon_paint", prism([(-1.55, 0.92), (0.75, 0.92), (0.95, 1.7), (-1.75, 1.7)], s * 0.62, s * 0.62 + s * 0.04))
        add(p, "running_iron", box((-0.4, s * 0.68, 1.3), (2.6, 0.02, 0.05)))
    # The heaped load rises above the sides; coal is never level.
    add(p, "coal", skin([(-1.45, 0, 1.6), (-0.4, 0, 1.75), (0.6, 0, 1.62)], [(0, 1), (1, 2)], [(0.42, 0.18), (0.55, 0.28), (0.4, 0.16)], 1))
    add(p, "running_iron", prism([(-1.78, 1.0), (-1.62, 1.0), (-1.62, 1.5), (-1.78, 1.55)], -0.25, 0.25))
    add(p, "hardwood", box((1.05, 0, 1.62), (0.35, 1.25, 0.08)), box((1.25, 0, 1.3), (0.05, 1.1, 0.5)))
    add(p, "leather", box((1.0, 0, 1.69), (0.3, 1.05, 0.06), 0.015))
    shafts(p, 1.15, 3.2, 1.02, 1.12)
    side_lantern(p, 0.95, 0.68, 1.95)
    return p


def milk_wagon():
    p = {}
    wagon_gear(p, 0.75, -0.85, 0.36, 0.48, 1.38, 0.6)
    # Low route body; the driver stands or perches in the open front.
    add(p, "wagon_paint", prism([(-1.35, 0.6), (0.95, 0.6), (0.95, 1.05), (0.6, 1.05), (0.6, 1.95), (-1.35, 1.95)], -0.68, 0.68, 0.02))
    add(p, "timber", prism([(-1.45, 1.95), (1.15, 1.95), (1.05, 2.08), (-1.4, 2.12)], -0.75, 0.75))
    for s in (1, -1):
        add(p, "wagon_paint", box((0.95, s * 0.64, 1.5), (0.06, 0.08, 0.95)))
    add(p, "upholstery", box((0.6, 0, 1.45), (0.02, 1.2, 0.85)))
    add(p, "hardwood", box((0.78, 0, 1.12), (0.3, 1.0, 0.05)))
    add(p, "timber", box((0.82, 0.35, 1.25), (0.26, 0.36, 0.22)))
    add(p, "lamp_oil", *[cyl((0.74 + 0.08 * i, 0.27 + 0.1 * j, 1.42), 0.03, 0.12, "Z", 8) for i in range(2) for j in range(2)])
    shafts(p, 0.95, 2.9, 0.78, 1.1)
    side_lantern(p, 0.96, 0.75, 1.75)
    side_lantern(p, 0.96, -0.75, 1.75)
    return p


def valve_wagon():
    """Express wagon of a valve merchant. The wagon is 1927; the load is not."""
    p = {}
    wagon_gear(p, 0.8, -0.95, 0.42, 0.5, 1.45, 0.92)
    add(p, "wagon_paint", box((-0.35, 0, 0.98), (2.3, 1.3, 0.1), 0.01))
    for s in (1, -1):
        add(p, "wagon_paint", box((-0.35, s * 0.63, 1.14), (2.3, 0.04, 0.24), 0.008))
    add(p, "wagon_paint", box((-1.48, 0, 1.14), (0.04, 1.26, 0.24)))
    # Sleeve crates of salvaged valves, roped under oilcloth.
    for i, (x, y, z) in enumerate([(-1.1, 0.3, 1.2), (-1.1, -0.3, 1.2), (-0.55, 0.3, 1.2), (-0.55, -0.3, 1.2), (-0.82, 0, 1.6)]):
        add(p, "timber", box((x, y, z), (0.5, 0.55, 0.4), 0.01))
    add(p, "tarp", prism([(-1.4, 1.42), (-0.25, 1.42), (-0.25, 1.62), (-0.55, 1.86), (-1.1, 1.86), (-1.4, 1.62)], -0.6, 0.6, 0.02))
    add(p, "canvas", *[tube([(x, 0.62, 1.2), (x, 0.62, 1.62), (x, 0, 1.9), (x, -0.62, 1.62), (x, -0.62, 1.2)], 0.008, 4, False) for x in (-1.25, -0.7)])
    # The sample chest: Bakelite, brass-bound, one tester valve lit in its window.
    add(p, "bakelite", box((0.0, 0.25, 1.17), (0.42, 0.34, 0.28), 0.02))
    add(p, "brass", box((0.0, 0.25, 1.32), (0.44, 0.36, 0.02)), box((0.0, 0.25, 1.03), (0.44, 0.36, 0.02)))
    add(p, "valve_glow", lathe([(0, 0), (0.03, 0.01), (0.035, 0.08), (0.025, 0.12), (0, 0.13)], (0.0, 0.25, 1.33), "Z", 10))
    add(p, "hardwood", box((0.62, 0, 1.38), (0.32, 1.2, 0.07)), box((0.82, 0, 1.15), (0.05, 1.0, 0.4)))
    add(p, "leather", box((0.58, 0, 1.44), (0.28, 1.0, 0.05), 0.012))
    shafts(p, 0.85, 2.85, 0.95, 1.08)
    side_lantern(p, 0.7, 0.68, 1.6)
    return p


def pushcart():
    p = {}
    add(p, "timber", box((0, 0, 0.82), (1.75, 0.82, 0.06)), box((0, 0.42, 0.92), (1.75, 0.03, 0.2)), box((0, -0.42, 0.92), (1.75, 0.03, 0.2)),
        box((0.89, 0, 0.92), (0.03, 0.82, 0.2)), box((-0.89, 0, 0.92), (0.03, 0.82, 0.2)))
    for s in (1, -1):
        add(p, "hardwood", tube([(-0.8, s * 0.36, 0.78), (-1.6, s * 0.3, 0.98)], 0.022, 6), tube([(0.75, s * 0.32, 0.78), (0.75, s * 0.32, 0.0)], 0.03, 6))
    add(p, "running_iron", box((-0.2, 0, 0.5), (0.06, 1.12, 0.06)))
    add(p, "produce", skin([(-0.55, 0.15, 0.95), (-0.15, 0.1, 0.98)], [(0, 1)], [(0.22, 0.18), (0.2, 0.15)], 1),
        skin([(0.15, -0.1, 0.94), (0.6, -0.1, 0.95)], [(0, 1)], [(0.2, 0.16), (0.22, 0.13)], 1))
    add(p, "canvas", box((0.3, 0.2, 0.9), (0.4, 0.35, 0.1), 0.02))
    return p


def model_a_tudor(p=None, roof=True):
    """1928-29 Ford Model A Tudor sedan."""
    p = {} if p is None else p
    rr = 0.37
    add(p, "coachwork", prism([(-1.86, 0.5), (0.48, 0.5), (0.5, 1.08), (0.3, 1.12), (0.18, 1.72), (-1.52, 1.74), (-1.78, 1.58), (-1.9, 1.05)], -0.77, 0.77, 0.04))
    add(p, "coachwork", prism([(0.45, 0.62), (1.6, 0.62), (1.6, 1.06), (0.45, 1.12)], -0.38, 0.38, 0.03))
    add(p, "hood_cloth", box((-0.62, 0, 1.745), (1.5, 1.2, 0.02)))
    add(p, "nickel", prism([(1.6, 0.56), (1.7, 0.56), (1.72, 1.18), (1.6, 1.16)], -0.32, 0.32, 0.015))
    add(p, "running_iron", box((1.715, 0, 0.86), (0.012, 0.52, 0.5)))
    for s in (1, -1):
        add(p, "upholstery", box((-0.95, s * 0.772, 1.42), (0.95, 0.01, 0.38)), box((-0.05, s * 0.772, 1.42), (0.38, 0.01, 0.36)))
        add(p, "japan_black", arc_fender(1.31, rr, rr + 0.05, s * 0.6, s * 0.86, -10, 175), arc_fender(-1.32, rr, rr + 0.05, s * 0.6, s * 0.86, 5, 185),
            box((-0.02, s * 0.8, 0.44), (1.95, 0.22, 0.03), 0.01))
        add(p, "tyre", box((-0.02, s * 0.8, 0.462), (1.85, 0.18, 0.012)))
        lamp(p, 1.66, s * 0.42, 1.02, 0.11)
        add(p, "nickel", tube([(1.6, s * 0.42, 0.92), (1.55, s * 0.6, 0.7)], 0.012, 5))
        add(p, "lamp_tail", box((-1.95, s * 0.55, 0.75), (0.02, 0.06, 0.06)))
    add(p, "upholstery", prism([(0.3, 1.12), (0.2, 1.68), (0.17, 1.68), (0.27, 1.12)], -0.6, 0.6), box((-1.88, 0, 1.36), (0.02, 0.6, 0.22)))
    add(p, "nickel", tube([(1.9, -0.75, 0.5), (1.92, 0, 0.5), (1.9, 0.75, 0.5)], 0.025, 6), tube([(-2.0, -0.7, 0.5), (-2.02, 0, 0.5), (-2.0, 0.7, 0.5)], 0.022, 6),
        cyl((1.74, 0, 1.22), 0.03, 0.05, "Z", 10))
    add(p, "running_iron", box((-0.1, 0, 0.42), (3.4, 0.7, 0.1)), box((1.31, 0, rr), (0.06, 1.3, 0.06)), box((-1.32, 0, rr), (0.08, 1.3, 0.08)))
    add(p, "tyre", torus((-1.98, 0, 1.0), 0.29, 0.07, "X", 22, 6))
    return p


def broadcast_car():
    """The Record's remote car: a Tudor with a cage aerial and a pickup horn."""
    p = model_a_tudor()
    for x in (-1.3, 0.0):
        add(p, "hardwood", box((x, 0, 1.98), (0.05, 1.5, 0.05)))
        for s in (1, -1):
            add(p, "nickel", tube([(x, s * 0.6, 1.76), (x, s * 0.7, 1.98)], 0.012, 5))
    for y in (-0.6, -0.2, 0.2, 0.6):
        add(p, "brass", tube([(-1.45, y, 2.01), (0.15, y, 2.01)], 0.004, 4))
    add(p, "bakelite", lathe([(0.03, 0), (0.05, 0.2), (0.11, 0.42), (0.2, 0.52)], (-0.65, 0.25, 1.82), "X", 14), box((-0.75, 0.25, 1.8), (0.2, 0.14, 0.1)))
    add(p, "brass", torus((-0.65 + 0.52, 0.25, 1.82), 0.2, 0.012, "X", 18, 5))
    # Wet cells in a slatted crate on the running board. Batteries are enormous.
    add(p, "timber", box((-0.75, -0.82, 0.68), (0.62, 0.2, 0.42), 0.01))
    add(p, "bakelite", *[box((-0.95 + 0.2 * i, -0.82, 0.9), (0.12, 0.14, 0.03)) for i in range(3)])
    add(p, "silk_flex", tube([(-0.75, -0.82, 0.92), (-0.75, -0.7, 1.3), (-0.65, -0.5, 1.75), (-0.65, 0.2, 1.8)], 0.012, 5, False))
    return p


def model_t_touring():
    """A 1926-27 Model T touring car, top up, second-hand by 1928."""
    p = {}
    rr = 0.38
    add(p, "coachwork", prism([(-1.65, 0.62), (0.32, 0.62), (0.35, 1.1), (-0.2, 1.12), (-0.4, 1.05), (-0.75, 1.15), (-1.55, 1.18), (-1.68, 1.0)], -0.72, 0.72, 0.03))
    add(p, "coachwork", prism([(0.32, 0.72), (1.35, 0.74), (1.35, 1.12), (0.32, 1.16)], -0.34, 0.34, 0.02))
    add(p, "japan_black", prism([(1.35, 0.66), (1.47, 0.66), (1.47, 1.24), (1.35, 1.22)], -0.3, 0.3, 0.012))
    add(p, "upholstery", box((-1.15, 0, 1.08), (0.55, 1.3, 0.12)), box((-0.2, 0, 0.98), (0.45, 1.3, 0.1)), box((-1.38, 0, 1.25), (0.1, 1.3, 0.35)), box((-0.42, 0, 1.18), (0.1, 1.3, 0.32)))
    add(p, "hood_cloth", prism([(0.28, 1.8), (-1.45, 1.84), (-1.7, 1.55), (-1.7, 1.45), (-1.55, 1.75), (0.26, 1.77)], -0.74, 0.74, 0.01))
    for s in (1, -1):
        add(p, "japan_black", tube([(0.33, s * 0.7, 1.15), (0.28, s * 0.7, 1.78)], 0.012, 5), tube([(-1.45, s * 0.72, 1.17), (-1.45, s * 0.72, 1.82)], 0.012, 5))
        add(p, "japan_black", arc_fender(1.2, rr, rr + 0.05, s * 0.56, s * 0.8, -5, 170), arc_fender(-1.34, rr, rr + 0.05, s * 0.56, s * 0.8, 10, 185),
            box((-0.07, s * 0.74, 0.47), (1.85, 0.2, 0.025)))
        lamp(p, 1.45, s * 0.38, 1.05, 0.1, shell="japan_black")
        add(p, "lamp_tail", box((-1.7, s * 0.5, 0.8), (0.02, 0.05, 0.05)))
    add(p, "japan_black", box((0.32, 0, 1.3), (0.03, 1.3, 0.3)), box((-0.1, 0, 0.45), (3.0, 0.6, 0.09)))
    add(p, "running_iron", box((1.2, 0, rr), (0.06, 1.25, 0.06)), box((-1.34, 0, rr), (0.08, 1.25, 0.08)))
    return p


def checker_cab():
    """Checker Model K (October 1928), with its fleet dispatch receiver."""
    p = {}
    rr = 0.39
    add(p, "coachwork", prism([(-2.2, 0.55), (0.62, 0.55), (0.64, 1.15), (0.42, 1.2), (0.32, 1.92), (-1.0, 1.95), (-2.05, 1.92), (-2.25, 1.6), (-2.3, 1.1)], -0.82, 0.82, 0.04))
    add(p, "coachwork", prism([(0.6, 0.66), (1.85, 0.68), (1.85, 1.12), (0.6, 1.18)], -0.4, 0.4, 0.03))
    add(p, "nickel", prism([(1.85, 0.6), (1.96, 0.6), (1.98, 1.26), (1.85, 1.24)], -0.34, 0.34, 0.015))
    add(p, "running_iron", box((1.975, 0, 0.92), (0.012, 0.55, 0.52)))
    # Landaulet rear quarter: leather over the back seat, with its irons.
    add(p, "leather", prism([(-2.06, 1.4), (-1.05, 1.4), (-1.05, 1.96), (-2.06, 1.93), (-2.26, 1.62)], -0.83, 0.83, 0.02))
    for s in (1, -1):
        add(p, "nickel", tube([(-1.95, s * 0.84, 1.45), (-1.7, s * 0.85, 1.62), (-1.45, s * 0.84, 1.5)], 0.012, 5))
        add(p, "upholstery", box((-0.55, s * 0.822, 1.55), (0.9, 0.01, 0.4)), box((0.12, s * 0.822, 1.52), (0.4, 0.01, 0.38)))
        add(p, "japan_black", arc_fender(1.62, rr, rr + 0.05, s * 0.64, s * 0.92, -10, 175), arc_fender(-1.6, rr, rr + 0.05, s * 0.64, s * 0.92, 5, 185),
            box((0.0, s * 0.86, 0.46), (2.4, 0.24, 0.03), 0.01))
        lamp(p, 1.92, s * 0.46, 1.08, 0.11)
        add(p, "lamp_tail", box((-2.32, s * 0.6, 0.8), (0.02, 0.06, 0.06)))
    add(p, "upholstery", prism([(0.42, 1.2), (0.32, 1.86), (0.29, 1.86), (0.39, 1.2)], -0.65, 0.65))
    add(p, "nickel", tube([(2.12, -0.8, 0.52), (2.14, 0, 0.52), (2.12, 0.8, 0.52)], 0.025, 6), tube([(-2.4, -0.75, 0.52), (-2.42, 0, 0.52), (-2.4, 0.75, 0.52)], 0.022, 6),
        tube([(0.5, 0.42, 1.2), (0.52, 0.48, 1.38)], 0.012, 5), box((0.52, 0.48, 1.45), (0.03, 0.14, 0.1)))
    add(p, "running_iron", box((0.0, 0, 0.44), (4.0, 0.72, 0.1)), box((1.62, 0, rr), (0.06, 1.36, 0.06)), box((-1.6, 0, rr), (0.08, 1.36, 0.08)))
    # Dispatch: a square loop aerial on the roof and the receiver cabinet on
    # the near running board, Bakelite with a brass grille. Fleet cabs have
    # taken calls from the garage board since before the Model K.
    add(p, "bakelite", box((-0.15, 0, 2.04), (0.05, 0.05, 0.16)), box((-0.15, 0, 2.38), (0.03, 0.62, 0.03)), box((-0.15, 0, 2.12), (0.03, 0.62, 0.03)))
    for s in (1, -1):
        add(p, "bakelite", box((-0.15, s * 0.3, 2.25), (0.03, 0.03, 0.26)))
    add(p, "brass", *[box((-0.15, 0, 2.15 + 0.03 * i), (0.008, 0.58, 0.006)) for i in range(7)])
    add(p, "bakelite", box((0.85, 0.86, 0.68), (0.42, 0.22, 0.4), 0.025))
    add(p, "brass", box((0.85, 0.972, 0.72), (0.3, 0.008, 0.22)))
    add(p, "silk_flex", tube([(0.85, 0.86, 0.88), (0.6, 0.8, 1.3), (0.0, 0.7, 1.9), (-0.15, 0.3, 2.0)], 0.01, 5, False))
    return p


def aa_cab(p, paint="coachwork"):
    """1928-29 Ford Model AA front end and closed cab. Front axle x 1.75."""
    rr = 0.42
    add(p, paint, prism([(0.95, 0.78), (2.05, 0.8), (2.05, 1.3), (0.95, 1.35)], -0.4, 0.4, 0.03))
    add(p, "nickel", prism([(2.05, 0.72), (2.15, 0.72), (2.17, 1.4), (2.05, 1.38)], -0.34, 0.34, 0.015))
    add(p, "running_iron", box((2.165, 0, 1.05), (0.012, 0.54, 0.55)))
    add(p, paint, prism([(-0.15, 0.78), (0.98, 0.78), (1.0, 1.34), (0.78, 1.38), (0.68, 2.08), (-0.15, 2.1)], -0.78, 0.78, 0.035))
    add(p, "hood_cloth", box((0.25, 0, 2.112), (0.75, 1.3, 0.02)))
    for s in (1, -1):
        add(p, "upholstery", box((0.3, s * 0.782, 1.7), (0.55, 0.01, 0.4)))
        add(p, "japan_black", arc_fender(1.75, rr, rr + 0.06, s * 0.62, s * 0.9, -10, 165), box((0.5, s * 0.84, 0.62), (0.75, 0.24, 0.03)))
        lamp(p, 2.12, s * 0.45, 1.18, 0.11)
        add(p, "lamp_tail", box((-2.66, s * 0.8, 0.95), (0.02, 0.06, 0.06)))
    add(p, "upholstery", prism([(0.78, 1.38), (0.68, 2.02), (0.65, 2.02), (0.75, 1.38)], -0.62, 0.62))
    add(p, "running_iron", box((-0.3, 0.38, 0.72), (4.75, 0.08, 0.16)), box((-0.3, -0.38, 0.72), (4.75, 0.08, 0.16)),
        box((1.75, 0, rr), (0.07, 1.4, 0.07)), cyl((-1.59, 0, rr), 0.1, 1.4, "Y", 12))
    add(p, "nickel", tube([(2.32, -0.82, 0.62), (2.34, 0, 0.62), (2.32, 0.82, 0.62)], 0.025, 6))
    return p


def aa_stake():
    p = aa_cab({})
    add(p, "timber", box((-1.45, 0, 0.88), (2.4, 1.85, 0.08)))
    for s in (1, -1):
        for i in range(5):
            add(p, "timber", box((-2.55 + 0.55 * i, s * 0.9, 1.25), (0.06, 0.05, 0.75)))
        add(p, "timber", box((-1.45, s * 0.9, 1.1), (2.35, 0.03, 0.1)), box((-1.45, s * 0.9, 1.45), (2.35, 0.03, 0.1)))
    add(p, "timber", box((-1.9, 0.35, 1.15), (0.6, 0.55, 0.45), 0.01), box((-1.3, -0.4, 1.12), (0.55, 0.6, 0.4), 0.01))
    add(p, "canvas", skin([(-0.8, 0.3, 1.02), (-0.6, 0.3, 1.04)], [(0, 1)], [(0.2, 0.12), (0.2, 0.12)], 1),
        skin([(-0.7, -0.3, 1.02), (-0.5, -0.3, 1.04)], [(0, 1)], [(0.2, 0.12), (0.2, 0.12)], 1))
    return p


def line_truck():
    """Telephone company line truck. The reel and test set are the signal."""
    p = aa_cab({})
    add(p, "coachwork", box((-1.45, 0, 0.92), (2.4, 1.85, 0.1)))
    for s in (1, -1):
        add(p, "coachwork", box((-1.45, s * 0.84, 1.2), (2.4, 0.18, 0.45), 0.02))
        add(p, "nickel", *[box((-2.25 + 0.8 * i, s * 0.932, 1.3), (0.06, 0.01, 0.03)) for i in range(3)])
    # Ladder rack over the bed.
    add(p, "running_iron", tube([(-2.6, 0.6, 1.4), (-2.6, 0.6, 2.25)], 0.02, 5), tube([(-2.6, -0.6, 1.4), (-2.6, -0.6, 2.25)], 0.02, 5),
        box((-2.6, 0, 2.25), (0.04, 1.25, 0.04)))
    for s in (1, -1):
        add(p, "hardwood", box((-0.9, s * 0.25, 2.29), (4.2, 0.05, 0.05)))
    add(p, "hardwood", *[box((-2.8 + 0.32 * i, 0, 2.29), (0.03, 0.5, 0.03)) for i in range(13)])
    # The cable reel: timber drum wound with cloth-braided, silk-covered pair.
    add(p, "timber", cyl((-1.6, 0, 1.55), 0.58, 0.05, "Y", 24), cyl((-1.6, 0, 1.55), 0.58, 0.05, "Y", 24))
    p["timber"][-2].data.transform(Matrix.Translation((0, 0.33, 0)))
    p["timber"][-1].data.transform(Matrix.Translation((0, -0.33, 0)))
    add(p, "silk_flex", cyl((-1.6, 0, 1.55), 0.45, 0.6, "Y", 24))
    add(p, "running_iron", tube([(-1.6, 0.45, 1.55), (-1.6, 0.6, 0.98)], 0.03, 6), tube([(-1.6, -0.45, 1.55), (-1.6, -0.6, 0.98)], 0.03, 6), cyl((-1.6, 0, 1.55), 0.04, 1.0, "Y", 8))
    add(p, "silk_flex", tube([(-1.6, 0.1, 2.0), (-2.4, 0.1, 1.6), (-2.7, 0.1, 1.0)], 0.015, 5, False))
    # Test set: Bakelite panel, brass terminals, wet-cell crate below.
    add(p, "bakelite", box((-0.4, -0.94, 1.25), (0.5, 0.02, 0.36), 0.008))
    add(p, "brass", *[cyl((-0.55 + 0.1 * i, -0.955, 1.32), 0.015, 0.02, "Y", 8) for i in range(4)])
    add(p, "lamp_lit", cyl((-0.25, -0.955, 1.18), 0.018, 0.015, "Y", 8))
    add(p, "timber", box((-0.4, -0.86, 0.72), (0.6, 0.18, 0.28), 0.01))
    return p


def sound_wagon():
    """Police Department sound wagon: a closed AA van that records the street."""
    p = aa_cab({})
    add(p, "coachwork", prism([(-2.7, 0.88), (-0.12, 0.88), (-0.12, 2.18), (-0.3, 2.28), (-2.6, 2.28), (-2.7, 2.18)], -0.92, 0.92, 0.03))
    for s in (1, -1):
        add(p, "upholstery", *[box((-2.2 + 0.7 * i, s * 0.922, 1.95), (0.42, 0.01, 0.2)) for i in range(3)])
    add(p, "japan_black", box((-2.705, 0, 1.5), (0.01, 0.02, 1.15)))
    add(p, "nickel", box((-2.71, 0.15, 1.5), (0.02, 0.05, 0.12)), box((-2.71, -0.15, 1.5), (0.02, 0.05, 0.12)))
    add(p, "running_iron", box((-2.85, 0, 0.82), (0.3, 1.5, 0.05)))
    # Recording horns on a turntable, a contact mast and the cable reel.
    add(p, "cast_iron", cyl((-1.4, 0, 2.32), 0.32, 0.06, "Z", 20))
    for s in (1, -1):
        horn = lathe([(0.05, 0), (0.07, 0.22), (0.14, 0.45), (0.28, 0.58)], (-1.4, 0.12, 2.55), "Y", 16)
        if s < 0:
            horn.data.transform(Matrix.Translation((-1.4, 0, 2.55)) @ Matrix.Rotation(math.pi, 4, "Z") @ Matrix.Translation((1.4, 0, -2.55)))
        add(p, "bakelite", horn)
        add(p, "brass", torus((-1.4, s * 0.70, 2.55), 0.28, 0.014, "Y", 20, 5))
    add(p, "bakelite", box((-1.4, 0, 2.45), (0.3, 0.3, 0.2), 0.02))
    add(p, "brass", tube([(-0.5, 0.0, 2.3), (-0.5, 0.0, 3.05)], 0.025, 8), tube([(-0.5, 0.0, 3.05), (-0.5, 0.0, 3.25)], 0.017, 8), torus((-0.5, 0, 3.3), 0.09, 0.015, "X", 16, 5))
    add(p, "bakelite", cyl((-0.5, 0, 3.3), 0.085, 0.04, "X", 16))
    add(p, "timber", cyl((-2.85, 0.45, 1.25), 0.3, 0.04, "X", 18), cyl((-2.85, 0.45, 1.25), 0.3, 0.04, "X", 18))
    p["timber"][-2].data.transform(Matrix.Translation((0.12, 0, 0)))
    p["timber"][-1].data.transform(Matrix.Translation((-0.12, 0, 0)))
    add(p, "silk_flex", cyl((-2.85, 0.45, 1.25), 0.22, 0.2, "X", 18))
    # Wet cells slung between the axles: three crates, lead posts in Bakelite.
    for i in range(3):
        add(p, "timber", box((-0.9 + 0.35 * i - 0.5, -0.6, 0.62), (0.3, 0.42, 0.34), 0.01))
        add(p, "bakelite", box((-0.9 + 0.35 * i - 0.5, -0.6, 0.8), (0.2, 0.3, 0.025)))
    add(p, "brass", lathe([(0, 0), (0.06, 0.02), (0.08, 0.1), (0.05, 0.14), (0, 0.15)], (2.1, 0.55, 1.36), "Z", 12))
    return p


def mack_ac():
    """Mack AC 'Bulldog' coal dumper: chain drive, solid tyres, scuttle hood."""
    p = {}
    add(p, "coachwork", prism([(1.25, 0.95), (2.95, 0.95), (2.95, 1.28), (1.25, 1.78)], -0.48, 0.48, 0.04))
    add(p, "cast_iron", box((1.18, 0, 1.38), (0.14, 1.02, 1.0), 0.03))
    add(p, "running_iron", box((1.105, 0, 1.38), (0.01, 0.8, 0.8)))
    add(p, "japan_black", box((0.55, 0, 1.25), (0.08, 1.7, 0.6)), box((-0.1, 0, 1.68), (0.08, 1.8, 1.4)))
    add(p, "leather", box((0.12, 0, 1.38), (0.38, 1.4, 0.12), 0.02), box((-0.04, 0, 1.68), (0.08, 1.4, 0.5), 0.02))
    add(p, "japan_black", box((0.25, 0, 2.48), (1.1, 1.85, 0.05), 0.01))
    for x in (0.75, -0.25):
        for s in (1, -1):
            add(p, "japan_black", box((x, s * 0.88, 1.85), (0.05, 0.05, 1.25)))
    for s in (1, -1):
        add(p, "japan_black", arc_fender(2.25, 0.45, 0.52, s * 0.66, s * 0.98, 0, 170), box((0.55, s * 0.9, 0.98), (0.6, 0.3, 0.03)))
        add(p, "running_iron", box((-1.6, s * 0.98, 0.5), (0.4, 0.03, 0.4)), tube([(-1.6, s * 0.97, 0.5), (-0.7, s * 0.97, 0.75)], 0.03, 6))
        lamp(p, 1.9, s * 0.62, 1.55, 0.09, shell="brass")
        add(p, "lamp_tail", box((-3.12, s * 0.9, 0.95), (0.02, 0.06, 0.06)))
    add(p, "running_iron", box((-0.3, 0.42, 0.8), (6.1, 0.1, 0.22)), box((-0.3, -0.42, 0.8), (6.1, 0.1, 0.22)),
        box((2.25, 0, 0.45), (0.1, 1.5, 0.1)), cyl((-1.6, 0, 0.5), 0.12, 1.6, "Y", 12), cyl((-0.7, 0, 0.75), 0.07, 2.0, "Y", 10),
        box((3.05, 0, 0.7), (0.12, 1.6, 0.18)))
    # The steel dump body and its heaped load.
    add(p, "wagon_paint", prism([(-3.1, 1.05), (0.25, 1.05), (0.4, 2.1), (-3.1, 2.1)], -1.0, 1.0, 0.03))
    add(p, "coal", skin([(-2.9, 0, 2.05), (-1.4, 0, 2.3), (0.05, 0, 2.1)], [(0, 1), (1, 2)], [(0.7, 0.2), (0.85, 0.32), (0.65, 0.16)], 1))
    add(p, "running_iron", tube([(-3.1, 0, 0.95), (-3.25, 0, 1.4), (-3.12, 0, 2.0)], 0.05, 6))
    return p


def saloon_bus():
    """Single-deck saloon bus of a Queens franchise line, 1928."""
    p = {}
    add(p, "coachwork", prism([(-4.0, 0.58), (3.0, 0.58), (3.0, 2.72), (2.85, 2.88), (-3.85, 2.88), (-4.0, 2.72)], -1.18, 1.18, 0.07))
    add(p, "hood_cloth", box((-0.5, 0, 2.9), (6.9, 2.1, 0.03)))
    add(p, "coachwork", prism([(3.0, 0.82), (3.85, 0.85), (3.85, 1.55), (3.0, 1.62)], -0.48, 0.48, 0.03))
    add(p, "nickel", prism([(3.85, 0.78), (3.95, 0.78), (3.97, 1.62), (3.85, 1.6)], -0.4, 0.4, 0.015))
    add(p, "running_iron", box((3.965, 0, 1.2), (0.012, 0.64, 0.66)))
    for s in (1, -1):
        add(p, "upholstery", *[box((-3.45 + 0.88 * i, s * 1.182, 2.05), (0.72, 0.01, 0.58)) for i in range(7)])
        add(p, "japan_black", arc_fender(2.9, 0.48, 0.54, s * 0.86, s * 1.22, -10, 175), arc_fender(-1.9, 0.48, 0.54, s * 0.9, s * 1.22, 0, 180),
            box((-0.5, s * 1.17, 0.66), (7.0, 0.04, 0.08)))
        lamp(p, 3.9, s * 0.62, 1.4, 0.11)
        add(p, "lamp_tail", box((-4.02, s * 0.95, 0.95), (0.02, 0.06, 0.06)))
    add(p, "upholstery", box((3.01, 0, 2.1), (0.01, 2.0, 0.62)), box((-4.01, 0, 2.15), (0.01, 1.6, 0.42)), box((2.5, -1.182, 1.45), (0.62, 0.01, 1.6)))
    add(p, "nickel", tube([(4.12, -1.0, 0.65), (4.15, 0, 0.65), (4.12, 1.0, 0.65)], 0.03, 6), tube([(-0.5, 1.19, 2.42), (2.4, 1.19, 2.42)], 0.012, 5))
    add(p, "running_iron", box((0.4, 0, 0.5), (7.2, 1.0, 0.16)), box((2.9, 0, 0.48), (0.08, 1.85, 0.08)), cyl((-1.9, 0, 0.48), 0.12, 1.9, "Y", 12))
    add(p, "lamp_lit", box((2.95, 0, 2.78), (0.03, 0.9, 0.12)))
    return p


def motorcycle():
    """Indian Scout with a sidecar. The rider is a shared figure."""
    p = {}
    add(p, "coachwork", prism([(-0.25, 0.86), (0.35, 0.86), (0.42, 0.98), (-0.2, 1.0)], -0.12, 0.12, 0.04))
    add(p, "japan_black", tube([(0.62, 0, 1.05), (0.4, 0, 0.55), (-0.15, 0, 0.42), (-0.72, 0, 0.34)], 0.025, 6), tube([(0.42, 0, 0.95), (0.62, 0, 1.05)], 0.025, 6),
        tube([(-0.2, 0, 0.92), (-0.72, 0, 0.34)], 0.02, 6), tube([(0.6, 0.05, 1.05), (0.72, 0.05, 0.34)], 0.018, 6), tube([(0.6, -0.05, 1.05), (0.72, -0.05, 0.34)], 0.018, 6),
        arc_fender(0.72, 0.34, 0.36, -0.07, 0.07, 10, 150), arc_fender(-0.72, 0.34, 0.36, -0.07, 0.07, 30, 175))
    add(p, "cast_iron", box((0.05, 0, 0.6), (0.36, 0.2, 0.28), 0.03), cyl((0.0, 0, 0.82), 0.07, 0.24, "Z", 10), cyl((0.16, 0, 0.82), 0.07, 0.24, "Z", 10))
    add(p, "leather", box((-0.3, 0, 0.98), (0.3, 0.24, 0.07), 0.02))
    add(p, "nickel", tube([(0.62, -0.38, 1.18), (0.6, 0, 1.12), (0.62, 0.38, 1.18)], 0.012, 5), tube([(0.1, 0.12, 0.45), (-0.75, 0.13, 0.42)], 0.025, 6))
    lamp(p, 0.72, 0, 1.0, 0.09)
    add(p, "lamp_tail", box((-1.02, 0, 0.62), (0.02, 0.05, 0.05)))
    # Sidecar on the right (off) side.
    add(p, "coachwork", lathe([(0, -1.0), (0.18, -0.85), (0.3, -0.4), (0.32, 0.2), (0.24, 0.6), (0, 0.75)], (-0.15, -0.72, 0.6), "X", 16))
    p["coachwork"][-1].data.transform(Matrix.Translation((0.15, 0.72, -0.6)))
    p["coachwork"][-1].data.transform(Matrix.Scale(1.1, 4, (0, 0, 1)))
    p["coachwork"][-1].data.transform(Matrix.Translation((-0.15, -0.72, 0.62)))
    add(p, "upholstery", box((-0.35, -0.72, 0.9), (0.45, 0.4, 0.04)))
    add(p, "japan_black", tube([(-0.3, -0.05, 0.42), (-0.3, -0.72, 0.42), (-0.3, -1.05, 0.31)], 0.022, 6), tube([(0.4, -0.05, 0.5), (0.3, -0.72, 0.42)], 0.02, 6),
        arc_fender(-0.3, 0.31, 0.33, -1.12, -0.98, 20, 160))
    return p


STOCKS = {
    "ice_wagon": ice_wagon, "coal_cart": coal_cart, "milk_wagon": milk_wagon, "valve_wagon": valve_wagon,
    "pushcart": pushcart, "model_a_tudor": model_a_tudor, "broadcast_car": broadcast_car,
    "model_t_touring": model_t_touring, "checker_cab": checker_cab, "aa_stake": aa_stake,
    "line_truck": line_truck, "sound_wagon": sound_wagon, "mack_ac": mack_ac,
    "saloon_bus": saloon_bus, "motorcycle": motorcycle,
}

SHARED = {"wheel_wagon": lambda: wheel_stock("wagon"), "wheel_artillery": lambda: wheel_stock("artillery"),
          "wheel_wire": lambda: wheel_stock("wire"), "wheel_disc": lambda: wheel_stock("disc"),
          "wheel_solid": lambda: wheel_stock("solid"), "horse_body": horse_body, "horse_leg": horse_leg,
          "figure": seated_figure}

# ---------------------------------------------------------------- runtime table
# Coordinates in this table are Godot vehicle-local: x forward, y up, z right
# (Blender -Y). Positions come from the same numbers the builders use.


def W(x, y_left, z):
    return [round(x, 4), round(z, 4), round(-y_left, 4)]


def four(xf, xr, half_f, half_r=None):
    half_r = half_f if half_r is None else half_r
    return [[xf, half_f], [xf, -half_f], [xr, half_r], [xr, -half_r]]


def wheels(kind, pairs, radius, width=1.0):
    return [{"stock": "wheel_" + kind, "at": W(x, y, radius), "radius": radius, "width": width} for x, y in pairs]


HORSE = lambda x, scale=1.0: {"at": W(x, 0, 0), "scale": scale, "legs": [W(*leg) for leg in HORSE_LEGS]}
FIG = lambda x, y, z: W(x, y, z)

PAINTS = {
    "ford": [[0.10, 0.11, 0.12], [0.20, 0.23, 0.30], [0.14, 0.19, 0.16], [0.30, 0.27, 0.22], [0.24, 0.12, 0.11]],
    "black": [[0.075, 0.072, 0.07], [0.09, 0.085, 0.08]],
    "cab": [[0.58, 0.46, 0.16], [0.18, 0.30, 0.20], [0.42, 0.13, 0.11], [0.62, 0.52, 0.22]],
    "trade": [[0.20, 0.26, 0.21], [0.30, 0.18, 0.13], [0.22, 0.22, 0.28], [0.36, 0.31, 0.22]],
    "ice": [[0.62, 0.58, 0.45], [0.30, 0.42, 0.40], [0.55, 0.48, 0.25]],
    "milk": [[0.70, 0.68, 0.62], [0.62, 0.60, 0.52]],
    "coal": [[0.25, 0.14, 0.11], [0.18, 0.20, 0.16]],
    "police": [[0.10, 0.16, 0.14]],
    "phone": [[0.16, 0.20, 0.17], [0.24, 0.20, 0.13]],
    "record": [[0.30, 0.10, 0.10]],
    "bus": [[0.38, 0.32, 0.20], [0.20, 0.27, 0.22]],
    "indian": [[0.42, 0.09, 0.07], [0.20, 0.22, 0.26]],
    "hide": [[0.42, 0.26, 0.15], [0.20, 0.14, 0.10], [0.55, 0.52, 0.48], [0.12, 0.10, 0.09], [0.48, 0.32, 0.18]],
}

KINDS = [
    # id, weight, speed m/s, signal, paint palette, extent [back, front], width, wheels, horse, figures, voice, lamps, period note
    {"id": "model_a_tudor", "weight": 17, "speed": [5.2, 7.4], "signal": False, "paint": "ford", "extent": [-2.05, 1.95], "width": 1.72,
     "wheels": wheels("wire", four(1.31, -1.32, 0.71), 0.37), "figures": [], "voice": "motor",
     "period": "Ford Model A Tudor, introduced December 1927; the new car on the street."},
    {"id": "model_t_touring", "weight": 13, "speed": [4.6, 6.6], "signal": False, "paint": "black", "extent": [-1.75, 1.5], "width": 1.6,
     "wheels": wheels("artillery", four(1.2, -1.34, 0.67), 0.38), "figures": [FIG(-0.35, 0.33, 1.05)], "voice": "motor",
     "period": "Ford Model T touring, production ended May 1927; second-hand and everywhere."},
    {"id": "checker_cab", "weight": 12, "speed": [5.0, 7.2], "signal": True, "paint": "cab", "extent": [-2.45, 2.18], "width": 1.84,
     "wheels": wheels("disc", four(1.62, -1.6, 0.74), 0.39), "figures": [], "voice": "motor",
     "period": "Checker Model K, October 1928. The garage dispatch receiver and roof loop are the signal."},
    {"id": "aa_stake", "weight": 9, "speed": [4.4, 6.2], "signal": False, "paint": "trade", "extent": [-2.68, 2.36], "width": 1.9,
     "wheels": wheels("disc", [[1.75, 0.74], [1.75, -0.74], [-1.59, 0.8], [-1.59, -0.8]], 0.42, 1.5), "figures": [], "voice": "motor",
     "period": "Ford Model AA 1.5-ton stake truck, 1928."},
    {"id": "mack_ac", "weight": 5, "speed": [3.6, 5.0], "signal": False, "paint": "coal", "extent": [-3.3, 3.1], "width": 2.0,
     "wheels": wheels("solid", [[2.25, 0.8], [2.25, -0.8]], 0.45) + wheels("solid", [[-1.6, 0.82], [-1.6, -0.82]], 0.5, 1.7),
     "figures": [FIG(0.12, 0.42, 1.44)], "voice": "heavy",
     "period": "Mack AC 'Bulldog', chain drive, solid tyres; a Vernon Avenue yard coal dumper."},
    {"id": "saloon_bus", "weight": 3, "speed": [4.2, 5.8], "signal": False, "paint": "bus", "extent": [-4.05, 4.18], "width": 2.4,
     "wheels": wheels("disc", [[2.9, 1.0], [2.9, -1.0]], 0.48) + wheels("disc", [[-1.9, 1.0], [-1.9, -1.0]], 0.48, 1.6), "figures": [], "voice": "heavy",
     "period": "Single-deck saloon bus of a private Queens franchise line; buses began replacing trolleys from 1926."},
    {"id": "motorcycle", "weight": 3, "speed": [5.6, 7.6], "signal": False, "paint": "indian", "extent": [-1.05, 0.9], "width": 1.3,
     "wheels": [{"stock": "wheel_wire", "at": W(0.72, 0, 0.34), "radius": 0.34, "width": 0.5}, {"stock": "wheel_wire", "at": W(-0.72, 0, 0.34), "radius": 0.34, "width": 0.5},
                {"stock": "wheel_wire", "at": W(-0.3, -1.05, 0.31), "radius": 0.31, "width": 0.5}],
     "figures": [FIG(-0.28, 0, 1.0)], "voice": "motor",
     "period": "Indian Scout with sidecar."},
    {"id": "ice_wagon", "weight": 9, "speed": [2.4, 3.4], "signal": False, "paint": "ice", "extent": [-1.75, 4.05], "width": 1.7,
     "wheels": wheels("wagon", four(0.95, -1.05, 0.75), 0.42) + [] , "horse": HORSE(2.55), "figures": [FIG(1.05, 0.25, 1.53)], "voice": "hooves",
     "period": "Ice wagon of the Flushing Bay, Bowery Bay or Astoria companies; horse-drawn into the 1930s."},
    {"id": "coal_cart", "weight": 7, "speed": [2.2, 3.2], "signal": False, "paint": "coal", "extent": [-1.8, 4.1], "width": 1.6,
     "wheels": wheels("wagon", [[0.85, 0.75], [0.85, -0.75]], 0.42) + wheels("wagon", [[-0.95, 0.75], [-0.95, -0.75]], 0.5),
     "horse": HORSE(2.6, 1.08), "figures": [FIG(1.0, 0.25, 1.72)], "voice": "hooves",
     "period": "Coal wagon behind a Percheron, a Vernon Avenue yard horse."},
    {"id": "milk_wagon", "weight": 6, "speed": [2.2, 3.0], "signal": False, "paint": "milk", "extent": [-1.5, 3.85], "width": 1.5,
     "wheels": wheels("wagon", [[0.75, 0.69], [0.75, -0.69]], 0.36) + wheels("wagon", [[-0.85, 0.69], [-0.85, -0.69]], 0.48),
     "horse": HORSE(2.35, 0.95), "figures": [FIG(0.78, 0.15, 1.15)], "voice": "hooves",
     "period": "Douglaston dairy route wagon; milk stayed horse-drawn until the late 1930s."},
    # The one that is wrong and true. Milk horses knew the round and walked it
    # while the driver was on a doorstep. Nobody remarks on it, ever.
    {"id": "milk_wagon_riderless", "stock": "milk_wagon", "weight": 1.5, "speed": [1.8, 2.4], "signal": False, "paint": "milk", "extent": [-1.5, 3.85], "width": 1.5,
     "wheels": wheels("wagon", [[0.75, 0.69], [0.75, -0.69]], 0.36) + wheels("wagon", [[-0.85, 0.69], [-0.85, -0.69]], 0.48),
     "horse": HORSE(2.35, 0.95), "figures": [], "voice": "hooves",
     "period": "The same wagon with nobody on it. Period-correct and never acknowledged."},
    {"id": "valve_wagon", "weight": 3, "speed": [2.4, 3.2], "signal": True, "paint": "trade", "extent": [-1.55, 3.7], "width": 1.5,
     "wheels": wheels("wagon", [[0.8, 0.73], [0.8, -0.73]], 0.42) + wheels("wagon", [[-0.95, 0.73], [-0.95, -0.73]], 0.5),
     "horse": HORSE(2.3, 0.92), "figures": [FIG(0.6, 0.25, 1.47)], "voice": "hooves",
     "period": "A horse delivering the Hollander receiver's salvaged valves in lots of six hundred."},
    {"id": "line_truck", "weight": 2.5, "speed": [4.2, 5.8], "signal": True, "paint": "phone", "extent": [-2.75, 2.36], "width": 1.9,
     "wheels": wheels("disc", [[1.75, 0.74], [1.75, -0.74], [-1.59, 0.8], [-1.59, -0.8]], 0.42, 1.5), "figures": [], "voice": "motor",
     "period": "New York Telephone line truck on an AA chassis: silk-braided pair on a timber reel, a live test set."},
    {"id": "sound_wagon", "weight": 1.5, "speed": [3.8, 5.0], "signal": True, "paint": "police", "extent": [-3.0, 2.36], "width": 1.9,
     "wheels": wheels("disc", [[1.75, 0.74], [1.75, -0.74], [-1.59, 0.8], [-1.59, -0.8]], 0.42, 1.5), "figures": [], "voice": "motor",
     "period": "Police Department sound wagon (Captain Galvin's): it records the street as it drives."},
    {"id": "broadcast_car", "weight": 1.5, "speed": [4.6, 6.4], "signal": True, "paint": "record", "extent": [-2.05, 1.95], "width": 1.72,
     "wheels": wheels("wire", four(1.31, -1.32, 0.71), 0.37), "figures": [], "voice": "motor",
     "period": "The Record's remote car: cage aerial, pickup horn and its own wet cells."},
]
for kind in KINDS:
    kind.setdefault("stock", kind["id"])
    kind.setdefault("horse", None)
    kind["paint"] = PAINTS[kind["paint"]]

PARKED = [{"stock": "pushcart", "x": -12.4, "z": 5.42, "yaw_degrees": 180.0, "extent": [-1.6, 0.9], "width": 0.9,
           "wheels": wheels("wagon", [[0.75, 0.48], [0.75, -0.48]], 0.45, 0.8), "period": "Peddler's pushcart left at the kerb."}]


def main():
    global scratch
    bpy.ops.wm.read_factory_settings(use_empty=True)
    catalog = json.loads((ROOT / "game/data/runtime_material_sets.json").read_text())["materials"]
    scratch = bpy.data.collections.new("EditableTrafficParts")
    bpy.context.scene.collection.children.link(scratch)
    exports = bpy.data.collections.new("PeriodTrafficExport")
    bpy.context.scene.collection.children.link(exports)
    mats = {}
    for fid, spec in FINISHES.items():
        mats[fid] = material(ROOT, fid, spec, catalog)
        if "emission" in spec:
            node = mats[fid].node_tree.nodes["Principled BSDF"]
            node.inputs["Emission Color"].default_value = spec["emission"][:3] + [1.0]
            node.inputs["Emission Strength"].default_value = spec["emission"][3]
    for fid, spec in FINISHES.items():
        # Paint and hide take the runtime colour through their albedo map, so
        # the runtime divides out the map's own mean (sRGB) to land on the
        # palette. Measured here from the catalogue image, never typed.
        image = bpy.data.images.load(str(ROOT / "game/assets/building/textures" / catalog[spec["catalog_key"]]["files"][0]), check_existing=True)
        px = list(image.pixels[:])
        step = max(4, (len(px) // 4 // 4096) * 4)
        samples = [px[i:i + 3] for i in range(0, len(px) - 3, step)]
        spec["albedo_mean"] = [round(sum(c[k] for c in samples) / len(samples), 4) for k in range(3)]
    triangles = {}
    stocks = dict(SHARED)
    stocks.update(STOCKS)
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
    runtime_kind_keys = ("id", "stock", "weight", "speed", "paint", "extent", "width", "wheels", "horse", "figures", "voice")
    runtime_finish_keys = ("catalog_key", "tint", "normal", "roughness", "paint", "emission", "albedo_mean")
    table = {
        "schema": "orison.v2.street-traffic.v1",
        "frame": "ORISON_FRONT_DOOR_THRESHOLD",
        "street_instance": "STREET_ORISON_01",
        "stock": "res://assets/props/v2_period_traffic.glb",
        "site": {"road_y": -0.10, "lane_west_z": 7.205, "lane_east_z": 12.005,
                 "carriageway_z": [4.955, 14.1], "spawn_x": 25.5, "despawn_x": 27.0},
        "timing": {"max_vehicles": 8, "max_wait": 8.0, "gap_seconds": 3.4, "following_gap_m": 2.2,
                   "yield_lookahead_m": 7.0, "yield_stop_m": 1.4, "acceleration": 2.2, "braking": 4.5,
                   "stride_m": 1.7, "leg_swing_degrees": 22.0},
        "finishes": [dict({"id": fid}, **{k: v for k, v in spec.items() if k in runtime_finish_keys}) for fid, spec in FINISHES.items()],
        "kinds": [{k: kind[k] for k in runtime_kind_keys} for kind in KINDS],
        "parked": [{k: v for k, v in parked.items() if k != "period"} for parked in PARKED],
        "horse_coats": PAINTS["hide"],
    }
    out = ROOT / "game/data/orison_v2/exterior/street_traffic.json"
    out.write_text(json.dumps(table, indent=1) + "\n", newline="\n")
    # Provenance stays with the art: period notes, Rule of Signal flags and
    # the triangle budget are for review, not for the runtime to carry.
    manifest = {
        "evidence_class": "INERT",
        "source": "art/blender/scripts/build_v2_period_traffic.py",
        "design": "design/V2_PERIOD_TRAFFIC_2026-10-24.md",
        "runtime_table": "game/data/orison_v2/exterior/street_traffic.json",
        "export_proof": {k: v for k, v in proof.items() if k != "asset"},
        "stocks": [{"id": k["id"], "stock": k["stock"], "signal": k["signal"], "period": k["period"]} for k in KINDS]
                  + [{"id": p["stock"], "stock": p["stock"], "signal": False, "period": p["period"]} for p in PARKED],
        "triangles": triangles,
    }
    (ROOT / "art/data/v2_period_traffic_manifest.json").write_text(json.dumps(manifest, indent=1) + "\n", newline="\n")
    print(json.dumps({"proof": proof, "triangles": triangles}))


if __name__ == "__main__":
    main()
