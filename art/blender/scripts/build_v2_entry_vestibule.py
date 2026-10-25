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
    "meter_paint": {"catalog_key": "door_paint", "tint": [0.36, 0.14, 0.10, 1], "normal": .7, "roughness": 1.},
    "dial_face": {"catalog_key": "porcelain", "tint": [0.95, 0.93, 0.86, 1], "normal": .3, "roughness": 1.},
    "lead": {"catalog_key": "iron_neutral", "tint": [0.55, 0.56, 0.58, 1], "normal": .6, "roughness": 1.},
    "card": {"catalog_key": "paper", "tint": [0.60, 0.48, 0.32, 1], "normal": .6, "roughness": 1.},
    "ash": {"catalog_key": "porcelain", "tint": [0.80, 0.79, 0.76, 1], "normal": .4, "roughness": 1.},
    # A burner with no mantle: a ragged yellow flame on a blue root.
    "flame_lit": {"catalog_key": "milk_glass", "tint": [1, .78, .40, 1], "normal": .2, "roughness": 1., "emission": [1.0, 0.62, 0.24, 3.2]},
    # The bypass pilot: a bead of blue flame that never goes out.
    "pilot_lit": {"catalog_key": "milk_glass", "tint": [.40, .60, 1, 1], "normal": .2, "roughness": 1., "emission": [0.35, 0.6, 1.0, 2.5]},
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
    above by the surface pipe, a swing arm with its gas cock (the flat key is
    gas_cock_key, so it can turn), a burner hanging an inverted mantle inside
    an etched bell shade."""
    p = {}
    add(p, "brass", cyl((0, -0.008, 0), 0.05, 0.016, "Y", 20),
            cyl((0, -0.022, 0), 0.018, 0.014, "Y", 12),
            cyl((0, -0.022, 0.035), 0.0105, 0.04, "Z", 10),
            sphere((0, -0.03, 0), 0.012, (1, 1, 1), 10, 6),
            tube([(0, -0.03, 0), (0, -0.21, 0)], 0.007, 10),
            cyl((0, -0.11, 0), 0.011, 0.03, "Z", 12),
            sphere((0, -0.21, 0), 0.011, (1, 1, 1), 10, 6),
            tube([(0, -0.21, 0), (0, -0.21, -0.065)], 0.0065, 10),
            torus((0, -0.21, -0.07), 0.042, 0.0035, "Z", 24, 6),
            cyl((0, -0.21, -0.09), 0.013, 0.04, "Z", 12))
    for k in range(3):
        a = 2 * math.pi * k / 3
        add(p, "brass", tube([(0, -0.21, -0.065), (0.042 * math.cos(a), -0.21 + 0.042 * math.sin(a), -0.07)], 0.0025, 5))
    # The bell shade (gas_bracket_shade) slides off this gallery; the mantle
    # (gas_mantle) hangs from the burner's lower end.
    return p


def gas_bracket_shade():
    """A 5.5 inch etched bell, open below so the mantle shows from
    underneath. Origin at the top of the bell, where it sits in the gallery;
    it slides straight down off the burner to reach the mantle."""
    p = {}
    bell = [(0.022, 0.0), (0.042, -0.009), (0.060, -0.040), (0.068, -0.077), (0.071, -0.097),
            (0.066, -0.097), (0.063, -0.078), (0.055, -0.043), (0.039, -0.014), (0.022, -0.006)]
    add(p, "shade_lit", lathe(bell, (0, 0, 0), "Z", 24))
    return p


def gas_mantle():
    """An inverted Welsbach mantle: a sock of rare-earth gauze on a ceramic
    collar, centred on its origin."""
    p = {}
    add(p, "ash", cyl((0, 0, 0.026), 0.012, 0.008, "Z", 12))
    add(p, "mantle_lit", sphere((0, 0, 0), 0.02, (1, 1, 1.45), 12, 8))
    return p


def gas_mantle_broken():
    """What a spent mantle leaves: the collar, a torn cup and a few shreds of
    brittle ash, which crumble at a touch."""
    p = {}
    add(p, "ash", cyl((0, 0, 0.026), 0.012, 0.008, "Z", 12),
            lathe([(0.012, 0.022), (0.018, 0.014), (0.019, 0.004), (0.0175, 0.004), (0.0165, 0.013), (0.011, 0.02)], (0, 0, 0), "Z", 12))
    for k, drop in enumerate((0.022, 0.012, 0.028, 0.016)):
        a = 2 * math.pi * k / 4 + 0.4
        x, y = 0.0175 * math.cos(a), 0.0175 * math.sin(a)
        shred = box((x, y, 0.004 - drop / 2), (0.006, 0.0012, drop))
        shred.data.transform(Matrix.Translation((x, y, 0)) @ Matrix.Rotation(a + math.pi / 2, 4, "Z") @ Matrix.Translation((-x, -y, 0)))
        add(p, "ash", shred)
    return p


def gas_naked_flame():
    """A bare burner's flame: ragged yellow over a blue root, roaring."""
    p = {}
    add(p, "flame_lit", sphere((0, 0, -0.016), 0.011, (1, 1, 2.3), 10, 8))
    add(p, "pilot_lit", sphere((0, 0, 0.012), 0.007, (1, 1, 1.2), 8, 6))
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
    add(p, "brass", cyl((0, -0.075, 0.04), 0.012, 0.032, "Z", 12))
    for x, z in [(-0.035, 0.06), (0.035, 0.06), (-0.035, -0.06), (0.035, -0.06)]:
        add(p, "iron", cyl((x, -0.022, z), 0.007, 0.006, "Y", 8))
    cy, top, bottom = -0.33, -0.05, -0.35
    cap = cyl((0, cy, top + 0.035), 0.125, 0.07, "Z", 4, 0.03)
    cap.data.transform(Matrix.Translation((0, cy, 0)) @ Matrix.Rotation(math.pi / 4, 4, "Z") @ Matrix.Translation((0, -cy, 0)))
    add(p, "iron", cap, cyl((0, cy, top + 0.085), 0.025, 0.03, "Z", 10),
            cyl((0, cy, top + 0.105), 0.035, 0.008, "Z", 12))
    # Three fixed lights; the fourth, facing the street, is gas_lantern_door.
    for side in ("left", "right", "back"):
        add(p, "pane_lit", lantern_pane(side))
    add(p, "brass", tube([(0, cy, top + 0.02), (0, cy, -0.13)], 0.005, 8),
            cyl((0, cy, -0.145), 0.012, 0.03, "Z", 12))
    for sx in (-1, 1):
        for sy in (-1, 1):
            add(p, "iron", tube([(sx * 0.083, cy + sy * 0.083, top), (sx * 0.062, cy + sy * 0.062, bottom)], 0.006, 6))
    base = cyl((0, cy, bottom - 0.012), 0.09, 0.024, "Z", 4, 0.06)
    base.data.transform(Matrix.Translation((0, cy, 0)) @ Matrix.Rotation(math.pi / 4, 4, "Z") @ Matrix.Translation((0, -cy, 0)))
    add(p, "iron", base, sphere((0, cy, bottom - 0.04), 0.012, (1, 1, 1), 8, 5))
    return p


LANTERN_CY, LANTERN_TOP, LANTERN_BOTTOM = -0.33, -0.05, -0.35
LANTERN_HALF_TOP, LANTERN_HALF_BOTTOM = 0.081, 0.060


def _slab(corners, thickness):
    """A thin glazed light from four corners, thickened along its normal."""
    bm = bmesh.new()
    a = [Vector(c) for c in corners]
    n = (a[1] - a[0]).cross(a[3] - a[0]).normalized() * (thickness / 2)
    front = [bm.verts.new(v + n) for v in a]
    back = [bm.verts.new(v - n) for v in a]
    bm.faces.new(front)
    bm.faces.new(back[::-1])
    for i in range(4):
        j = (i + 1) % 4
        bm.faces.new((front[i], back[i], back[j], front[j]))
    return _obj(bm, "slab")


def _pane_corners(side):
    cy, t, b = LANTERN_CY, LANTERN_TOP, LANTERN_BOTTOM
    ht, hb = LANTERN_HALF_TOP, LANTERN_HALF_BOTTOM
    if side == "front":
        return [(-ht, cy - ht, t), (ht, cy - ht, t), (hb, cy - hb, b), (-hb, cy - hb, b)]
    if side == "back":
        return [(ht, cy + ht, t), (-ht, cy + ht, t), (-hb, cy + hb, b), (hb, cy + hb, b)]
    if side == "left":
        return [(-ht, cy + ht, t), (-ht, cy - ht, t), (-hb, cy - hb, b), (-hb, cy + hb, b)]
    return [(ht, cy - ht, t), (ht, cy + ht, t), (hb, cy + hb, b), (hb, cy - hb, b)]


def lantern_pane(side):
    return _slab(_pane_corners(side), 0.003)


def gas_lantern_door():
    """The lantern's street-facing light, framed in iron, hung on its left
    post so it swings out to reach the mantle. Origin at the top of the hinge
    post; the hinge axis runs down the post to its foot."""
    p = {}
    c = _pane_corners("front")
    o = Vector(c[0])
    corners = [tuple(Vector(v) - o) for v in c]
    add(p, "pane_lit", _slab(corners, 0.003))
    tl, tr, br, bl = [Vector(v) for v in corners]
    add(p, "iron", tube([tuple(tl), tuple(tr)], 0.004, 6), tube([tuple(bl), tuple(br)], 0.004, 6),
            tube([tuple(tr), tuple(br)], 0.004, 6))
    mid = (tr + br) / 2 + Vector((-0.012, -0.004, 0))
    add(p, "brass", sphere(tuple(mid), 0.005, (1, 1, 1), 8, 5))
    return p


def mantle_carton():
    """A card carton of a dozen mantles, open-topped under its lid. Origin
    at the middle of its bottom; its back (+Y) goes to the wall."""
    p = {}
    w, d, h, t = 0.24, 0.16, 0.07, 0.003
    add(p, "card", box((0, 0, t / 2), (w, d, t)),
            box((0, -d / 2 + t / 2, h / 2), (w, t, h)), box((0, d / 2 - t / 2, h / 2), (w, t, h)),
            box((-w / 2 + t / 2, 0, h / 2), (t, d, h)), box((w / 2 - t / 2, 0, h / 2), (t, d, h)))
    return p


def mantle_carton_lid():
    """The carton's lid with its front tuck flap; origin on the hinge, the
    carton's top back edge, the lid lying forward along -Y."""
    p = {}
    add(p, "card", box((0, -0.082, 0.002), (0.244, 0.164, 0.004)),
            box((0, -0.164, -0.008), (0.244, 0.004, 0.02)))
    return p


def mantle_packet():
    """One mantle in its tissue and paper sleeve, standing on its origin."""
    p = {}
    add(p, "paper", box((0, 0, 0.03), (0.045, 0.03, 0.06), 0.002))
    add(p, "card", box((0, 0, 0.0605), (0.046, 0.031, 0.004), 0.001))
    return p


def gas_mantle_shelf(service):
    """A short oak shelf for the mantle carton on the workroom's east wall,
    in the blockout frame, from gas_service.json's carton entry."""
    c = service["carton"]
    wall, z, y = c["wall_face_x"], c["along_z"], c["shelf_y"]
    p = {}
    add(p, "oak", box(blender((wall - 0.1, y + 0.0125, z)), (0.2, 0.34, 0.025), 0.003))
    for dz in (-0.12, 0.12):
        add(p, "iron", box(blender((wall - 0.006, y - 0.06, z + dz)), (0.012, 0.03, 0.12), 0.002),
                box(blender((wall - 0.09, y - 0.006, z + dz)), (0.17, 0.03, 0.012), 0.002),
                tube([blender((wall - 0.012, y - 0.11, z + dz)), blender((wall - 0.15, y - 0.012, z + dz))], 0.005, 6))
    return p


def gas_cock_key():
    """The flat key of a plug cock, authored shut (across the pipe); the
    owner turns it a quarter turn about its own vertical axis, in line with
    the pipe when open. Origin on the plug's axis at the cock body's centre."""
    p = {}
    add(p, "brass", cyl((0, 0, 0.0175), 0.0035, 0.009, "Z", 8),
            box((0, 0, 0.024), (0.045, 0.005, 0.012), 0.001))
    return p


def gas_pilot():
    """The bypass pilot jet's flame, a few millimetres of blue at the burner."""
    p = {}
    add(p, "pilot_lit", sphere((0, 0, 0), 0.0045, (1, 1, 1.9), 8, 6))
    return p


PIPE_R = 0.0107       # half-inch black iron gas pipe, 21.3 mm outside
PIPE_OFF = 0.022      # pipe centreline off the wall face, on its straps


def blender(point):
    """Godot blockout-frame (x, y, z) to Blender (x, -z, y)."""
    x, y, z = point
    return (x, -z, y)


def gas_pipe(points, p=None, floor_flange="start", cock=True):
    """Surface-run black iron supply in the blockout frame (Godot x, y, z):
    malleable elbows at each bend, a floor flange where it leaves the floor,
    a plug cock low on the riser, straps to the wall about every 0.8 m."""
    b = [blender(q) for q in points]
    p = {} if p is None else p
    add(p, "iron", tube(b, PIPE_R, 10))
    for q in b[1:-1]:
        add(p, "iron", sphere(q, PIPE_R * 1.55, (1, 1, 1), 10, 6))
    if floor_flange:
        x, y, z = b[0] if floor_flange == "start" else b[-1]
        add(p, "iron", cyl((x, y, z + 0.004), 0.034, 0.008, "Z", 14),
                cyl((x, y, z + 0.03), PIPE_R * 1.45, 0.04, "Z", 10))
    if cock:
        x, y, z = b[0]
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


def gas_meter_hand():
    """One index hand: a blackened needle on a brass boss, authored pointing
    up the dial (Blender +Z), pivot at the origin, standing off the face."""
    p = {}
    add(p, "iron", box((0, -0.004, 0.009), (0.0026, 0.0012, 0.024), 0.0004))
    add(p, "brass", cyl((0, -0.0035, 0), 0.0035, 0.003, "Y", 10))
    return p


def gas_service(service):
    """The house gas service in the front workroom, in the blockout frame,
    from game/data/orison_v2/gas_service.json: the service through the
    street wall with the gas company's plug cock, its lock wings wired and
    sealed with lead; a painted steel-plate dry meter on an oak shelf, its
    index of small dials and its sealed inlet union; and the house outlet
    down into the floor."""
    m = service["meter"]
    wall, cx, sy = m["wall_face_z"], m["centre_x"], m["shelf_y"]
    p = {}
    # Shelf and its two iron brackets.
    add(p, "oak", box(blender((cx, sy + 0.0125, wall + 0.13)), (0.42, 0.26, 0.025), 0.003))
    for dx in (-0.15, 0.15):
        add(p, "iron", box(blender((cx + dx, sy - 0.07, wall + 0.006)), (0.03, 0.012, 0.14), 0.002),
                box(blender((cx + dx, sy - 0.006, wall + 0.11)), (0.03, 0.2, 0.012), 0.002),
                tube([blender((cx + dx, sy - 0.13, wall + 0.012)), blender((cx + dx, sy - 0.012, wall + 0.19))], 0.005, 6))
    # The meter case: steel plate, rolled top rim, side seams.
    top = sy + 0.425
    add(p, "meter_paint", box(blender((cx, sy + 0.225, wall + 0.13)), (0.34, 0.20, 0.40), 0.008),
            box(blender((cx, top - 0.008, wall + 0.13)), (0.355, 0.215, 0.016), 0.004))
    for dx in (-0.171, 0.171):
        add(p, "meter_paint", box(blender((cx + dx, sy + 0.225, wall + 0.13)), (0.006, 0.18, 0.38), 0.002))
    # Index: a brass bezel round the dial plate, each dial's face and ticks.
    face = wall + 0.23
    add(p, "brass", box(blender((cx, sy + 0.19, face + 0.002)), (0.27, 0.004, 0.25), 0.002))
    add(p, "meter_paint", box(blender((cx, sy + 0.19, face + 0.004)), (0.25, 0.003, 0.23), 0.001))
    for dial in m["dials"]:
        dx, dy = dial["offset"]
        r = dial["radius"]
        c = blender((cx + dx, sy + dy, face + 0.0065))
        add(p, "dial_face", cyl(c, r, 0.002, "Y", 24))
        add(p, "brass", torus(c, r + 0.002, 0.0015, "Y", 24, 5))
        for k in range(10):
            a = 2 * math.pi * k / 10
            t = (c[0] + math.sin(a) * r * 0.82, c[1] - 0.0012, c[2] + math.cos(a) * r * 0.82)
            add(p, "iron", box(t, (0.0012, 0.0006, r * (0.3 if k == 0 else 0.2))))
    # Blank brass nameplate; no lettering in any surface.
    add(p, "brass", box(blender((cx, sy + 0.36, face + 0.002)), (0.12, 0.003, 0.03), 0.001))
    # Unions on top, inlet and outlet.
    for q in (service["service"][-1], service["outlet"][0]):
        add(p, "brass", cyl(blender((q[0], top + 0.012, q[2])), 0.02, 0.024, "Z", 6),
                cyl(blender((q[0], top + 0.03, q[2])), 0.016, 0.014, "Z", 6))
    # Service and outlet runs; the service cock is the company's, sealed.
    gas_pipe(service["service"], p, floor_flange=None, cock=False)
    gas_pipe(service["outlet"], p, floor_flange="end", cock=False)
    wx, wy, _ = service["service"][0]
    add(p, "iron", cyl(blender((wx, wy, wall - 0.003)), 0.035, 0.008, "Y", 14))
    rx, _, rz = service["service"][2]
    cy = service["company_cock_y"]
    add(p, "brass", cyl(blender((rx, cy, rz)), PIPE_R * 1.8, 0.06, "Z", 10),
            cyl(blender((rx, cy, rz + 0.026)), 0.006, 0.02, "Y", 8),
            box(blender((rx, cy, rz + 0.04)), (0.012, 0.004, 0.03), 0.001))
    # Lock wing on the plug and its twin on the body, wired and lead-sealed.
    add(p, "brass", box(blender((rx + 0.024, cy + 0.012, rz + 0.012)), (0.018, 0.003, 0.012), 0.001),
            box(blender((rx + 0.024, cy - 0.012, rz + 0.012)), (0.018, 0.003, 0.012), 0.001))
    add(p, "iron", tube([blender((rx + 0.03, cy + 0.012, rz + 0.012)), blender((rx + 0.036, cy, rz + 0.016)),
            blender((rx + 0.03, cy - 0.012, rz + 0.012)), blender((rx + 0.04, cy - 0.03, rz + 0.016))], 0.0008, 4))
    add(p, "lead", cyl(blender((rx + 0.04, cy - 0.038, rz + 0.016)), 0.008, 0.004, "Y", 12))
    ix, _, iz = service["service"][-1]
    add(p, "iron", tube([blender((ix + 0.02, top + 0.02, iz)), blender((ix + 0.03, top - 0.01, iz + 0.11))], 0.0008, 4))
    add(p, "lead", cyl(blender((ix + 0.03, top - 0.018, iz + 0.112)), 0.007, 0.004, "Y", 12))
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
    "gas_cock_key": gas_cock_key,
    "gas_pilot": gas_pilot,
    "gas_meter_hand": gas_meter_hand,
    "gas_bracket_shade": gas_bracket_shade,
    "gas_mantle": gas_mantle,
    "gas_mantle_broken": gas_mantle_broken,
    "gas_naked_flame": gas_naked_flame,
    "gas_lantern_door": gas_lantern_door,
    "mantle_carton": mantle_carton,
    "mantle_carton_lid": mantle_carton_lid,
    "mantle_packet": mantle_packet,
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
    "gas_cock_key": "Flat brass key of a quarter-turn plug cock.",
    "gas_pilot": "Bypass pilot flame of an inverted burner.",
    "gas_meter_hand": "Blackened index hand of a dry gas meter dial.",
    "gas_bracket_shade": "Etched glass bell shade that slides off the bracket's gallery.",
    "gas_mantle": "Inverted Welsbach mantle on its ceramic collar.",
    "gas_mantle_broken": "A spent mantle's collar, torn cup and brittle ash shreds.",
    "gas_naked_flame": "The ragged yellow flame of a burner with no mantle.",
    "gas_lantern_door": "The lantern's iron-framed street light, hung on its left post.",
    "mantle_carton": "Card carton for a dozen spare mantles.",
    "mantle_carton_lid": "The carton's lid and tuck flap.",
    "mantle_packet": "One spare mantle in its tissue and paper sleeve.",
    "gas_mantle_shelf": "Short oak shelf for the mantle carton, on the workroom wall.",
    "gas_service_workroom": "House gas service: sealed company cock, painted steel-plate dry meter with a small-dial index on an oak shelf, outlet to the floor.",
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
    service = json.loads((ROOT / "game/data/orison_v2/gas_service.json").read_text(encoding="utf-8"))
    stocks["gas_service_workroom"] = lambda: gas_service(service)
    stocks["gas_mantle_shelf"] = lambda: gas_mantle_shelf(service)
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
