"""The V2 apparatus set, authored in Blender (v1r_extinguisher_20261109,
v1r_door_closer_b_20261109).

Two native assemblies whose behaviour stays with their V1 prop scripts:

  Ext__*    the 2 1/2 gallon soda-acid extinguisher on its backboard: copper
            shell with riveted seams and spun dome, brass collar and foot ring,
            screw cap with cross handle (a turning part), Miller's wire cage,
            the acid bottle with its loose lead stopple, lead-and-wire seal,
            rubber hose and brass nozzle in a clip, two iron straps and a shelf
            bolted to a painted board, a blank enamel charge plate and a blank
            paper tag. Authored in the V1 prop's own frame: z = 0 is the board
            face, y = 0 its bottom edge, +z out onto the landing.
  Check__*  the overhead liquid door check for the roof stair door: back plate
            and check cylinder on the head, spring drum and spindle, the two
            jointed arms as separately pivoted parts, the shoe and its leaf
            bracket, the regulating screw as a turning part, the hold-open
            catch. Authored in the DoorProp node's frame: +x along the head
            from the hinge, y up from the sill, +z the side the leaf swings
            AWAY from (the stair side), so nothing fixed stands in the swing.

Every mesh carries metre UVs (u, v in metres; the catalogue material's
uv1_scale turns them into tiles), smooth normals split at worked edges, and
exporter tangents. No lettering: the plate, tag and head legend are Label3D at
runtime. Deterministic: no randomness.

  blender -b --python-exit-code 1 -P art/blender/scripts/build_fire_apparatus.py -- <review_dir>

Writes game/assets/props/fire_apparatus.glb, art/blender/fire_apparatus.blend,
game/data/orison_v2/fire_apparatus.json and review renders under <review_dir>.
Coordinates below are Godot's (x right, y up, z toward the viewer); the mesh
writer turns them into Blender's Z-up once.
"""
import bpy, bmesh, json, math, sys
import numpy as np
from mathutils import Vector, Matrix
from pathlib import Path

ROOT = next(p for p in Path(__file__).resolve().parents if (p / "game/project.godot").is_file())
REVIEW = Path(sys.argv[sys.argv.index("--") + 1]) if "--" in sys.argv else ROOT / "art/blender/fire_apparatus_review"
REVIEW.mkdir(parents=True, exist_ok=True)
CATALOG = json.loads((ROOT / "game/data/runtime_material_sets.json").read_text(encoding="utf-8"))["materials"]
TEXTURES = ROOT / "game/assets/building/textures"

# --- the roof stair door this check is fitted to -----------------------------
# ROOF_PUBLIC_DOOR in game/data/orison_v2_blockout.json: 1.10 x 2.13, hung on
# its left, swinging out onto the roof deck. In the DoorProp node's frame the
# hinge line is x = 0 and the leaf hangs flush with the wall's ROOF face: the
# 0.14 partition runs from z = 0 to z = 0.14 (measured by ray in the booted
# world), so on the stair side the leaf stands in a deep reveal. The iron
# service casing (0.09 wide, 0.018 proud: build_door_casing_mitres.py) stands
# round the opening on both faces.
LEAF_HEIGHT = 2.13
HINGE_AXIS_Z = -0.026       # DoorProp.HINGE_SETBACK: the leaf swings toward -z
LEAF_FACE_Z = 0.034         # stair-side flat-bar face of the service leaf
WALL_ROOF_Z = 0.000         # roof-side face of the partition
WALL_FACE_Z = 0.140         # stair-side face of the partition
HEAD_FACE_Z = 0.158         # stair-side face of the head casing the plate sits on
CASING = 0.090
BARREL_Y = LEAF_HEIGHT + 0.046
BARREL_Z = HEAD_FACE_Z + 0.056
SPINDLE = Vector((0.100, LEAF_HEIGHT - 0.026, BARREL_Z))
SHOE_PIN = Vector((0.330, LEAF_HEIGHT - 0.026, 0.150))
ARM_MAIN, ARM_FORE = 0.30, 0.32     # DoorCheckCloserProp.ARM_MAIN / ARM_FORE
VALVE_REST = Vector((0.432, BARREL_Y, BARREL_Z))
HOLD_PIVOT = Vector((0.028, LEAF_HEIGHT - 0.010, BARREL_Z))
LEGEND = Vector((0.250, BARREL_Y, BARREL_Z + 0.0453))

# --- the extinguisher's V1 datums -------------------------------------------
VESSEL = Vector((0.0, 0.128, 0.135))          # VesselPivot
CAP = Vector((0.0, 0.632, 0.0))               # on VesselPivot
BOTTLE_SEATED = Vector((0.0, 0.664, 0.135))   # bottle, cap on
BOTTLE_DRAWN = Vector((-0.192, 0.126, 0.150)) # bottle, on the shelf
STOPPLE = Vector((0.0, 0.0655, 0.0))          # on the bottle
TAG = Vector((-0.176, 0.452, 0.150))
# Where the cap stands once it is off: on a two-pronged rest on the board, with
# the cage and whatever is in it hanging clear between the prongs. (V1 set the
# cap across the shoulder, which puts a rigid cage through the copper.)
CAP_REST = Vector((0.210, 0.601, 0.100))
# The stair landings are wainscoted (orison_v2_millwork.gd: backing 0.016 proud
# of the plaster, frames 0.036, cap rail 0.050 at 1.32-1.36 m). The board is
# 0.022 thick and stands 0.052 off the plaster: it bears on the cap rail and on
# two packing battens against the panelling below it.
BOARD_BACK_Z = -0.022
WALL_PLANE_Z = BOARD_BACK_Z - 0.052
PANEL_FACE_Z = WALL_PLANE_Z + 0.016


def to_blender(p):
    return Vector((p[0], -p[2], p[1]))


class Stock:
    """One draw: triangles and quads with per-corner metre UVs, in Godot
    coordinates LOCAL to `origin` (the part's pivot at rest in its assembly)."""

    def __init__(self, name, key, origin=(0, 0, 0), parent=None, tint=None, component="Fixed"):
        self.name, self.key, self.origin = name, key, Vector(origin)
        self.parent, self.tint, self.component = parent, tint, component
        self.faces = []   # list of [(position, uv), ...]

    def face(self, corners):
        corners = [(Vector(p), (float(u), float(v))) for p, (u, v) in corners]
        # Every chart is right-handed on its outward face (dP/du x dP/dv along
        # the normal), so one tangent sign serves the whole asset. A chart that
        # arrives mirrored is turned over in u; its scale is untouched.
        chart = [uv for _, uv in corners]
        if sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(chart, chart[1:] + chart[:1])) < 0.0:
            corners = [(p, (-u, v)) for p, (u, v) in corners]
        self.faces.append(corners)

    # -- primitives ---------------------------------------------------------
    def box(self, lo, hi):
        lo, hi = Vector(lo), Vector(hi)
        x0, y0, z0 = lo
        x1, y1, z1 = hi
        quads = [
            ([(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)], 0, 1),   # +z
            ([(x1, y0, z0), (x0, y0, z0), (x0, y1, z0), (x1, y1, z0)], 0, 1),   # -z
            ([(x1, y0, z1), (x1, y0, z0), (x1, y1, z0), (x1, y1, z1)], 2, 1),   # +x
            ([(x0, y0, z0), (x0, y0, z1), (x0, y1, z1), (x0, y1, z0)], 2, 1),   # -x
            ([(x0, y1, z1), (x1, y1, z1), (x1, y1, z0), (x0, y1, z0)], 0, 2),   # +y
            ([(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)], 0, 2),   # -y
        ]
        for points, ua, va in quads:
            self.face([(p, (p[ua], p[va])) for p in points])

    def obox(self, centre, size, basis):
        """A box turned by a 3x3 basis (columns = its local axes)."""
        centre, h = Vector(centre), Vector(size) * 0.5
        sub = Stock("", self.key)
        sub.box(-h, h)
        for corners in sub.faces:
            self.face([(centre + basis @ p, uv) for p, uv in corners])

    def lathe(self, profile, origin=(0, 0, 0), axis=(0, 1, 0), ref=(1, 0, 0), segments=24, sweep=math.tau, start=0.0):
        """Revolve (radius, height) pairs about `axis`. Walk the profile
        counter-clockwise in the (radius, height) plane for outward normals."""
        origin, axis, ref = Vector(origin), Vector(axis).normalized(), Vector(ref).normalized()
        ref = (ref - axis * ref.dot(axis)).normalized()
        side = axis.cross(ref)
        lengths = [0.0]
        for (r0, h0), (r1, h1) in zip(profile, profile[1:]):
            lengths.append(lengths[-1] + math.hypot(r1 - r0, h1 - h0))

        def point(r, h, a):
            return origin + axis * h + (ref * math.cos(a) + side * math.sin(a)) * r

        for i in range(len(profile) - 1):
            (r0, h0), (r1, h1) = profile[i], profile[i + 1]
            if math.hypot(r1 - r0, h1 - h0) < 1e-9:
                continue
            for s in range(segments):
                a0 = start + sweep * s / segments
                a1 = start + sweep * (s + 1) / segments
                c0, c1 = sweep * (s / segments - 0.5), sweep * ((s + 1) / segments - 0.5)
                p00, p01 = point(r0, h0, a0), point(r0, h0, a1)
                p10, p11 = point(r1, h1, a0), point(r1, h1, a1)
                u = lambda r, c: -r * c
                if r0 < 1e-9:
                    self.face([(p00, (0.0, lengths[i])), (p11, (u(r1, c1), lengths[i + 1])), (p10, (u(r1, c0), lengths[i + 1]))])
                elif r1 < 1e-9:
                    self.face([(p00, (u(r0, c0), lengths[i])), (p01, (u(r0, c1), lengths[i])), (p10, (0.0, lengths[i + 1]))])
                else:
                    self.face([(p00, (u(r0, c0), lengths[i])), (p01, (u(r0, c1), lengths[i])),
                               (p11, (u(r1, c1), lengths[i + 1])), (p10, (u(r1, c0), lengths[i + 1]))])

    def tube(self, path, radius, sides=8, closed=False, caps=True):
        """A round section swept along a polyline (parallel-transport frames)."""
        pts = [Vector(p) for p in path]
        n = len(pts)
        radii = radius if isinstance(radius, (list, tuple)) else [radius] * n
        tangents = []
        for i in range(n):
            a = pts[(i - 1) % n] if (closed or i > 0) else pts[i]
            b = pts[(i + 1) % n] if (closed or i < n - 1) else pts[i]
            tangents.append((b - a).normalized())
        seed = Vector((0, 1, 0)) if abs(tangents[0].y) < 0.9 else Vector((1, 0, 0))
        u = tangents[0].cross(seed).normalized()
        frames = []
        for i in range(n):
            if i:
                u = (u - tangents[i] * u.dot(tangents[i])).normalized()
            frames.append((u.copy(), tangents[i].cross(u)))
        if closed:
            # Remove the accumulated twist so the last ring meets the first.
            u0, v0 = frames[0]
            un = (frames[-1][0] - tangents[0] * frames[-1][0].dot(tangents[0])).normalized()
            twist = math.atan2(un.dot(v0), un.dot(u0))
            for i in range(n):
                a = -twist * i / n
                fu, fv = frames[i]
                frames[i] = (fu * math.cos(a) + fv * math.sin(a), fv * math.cos(a) - fu * math.sin(a))
        along = [0.0]
        for i in range(1, n + (1 if closed else 0)):
            along.append(along[-1] + (pts[i % n] - pts[i - 1]).length)

        def ring(i, s):
            fu, fv = frames[i % n]
            a = math.tau * s / sides
            return pts[i % n] + (fu * math.cos(a) + fv * math.sin(a)) * radii[i % n]

        for i in range(n if closed else n - 1):
            for s in range(sides):
                r = radii[i % n]
                c0, c1 = math.tau * (s / sides - 0.5) * r, math.tau * ((s + 1) / sides - 0.5) * r
                self.face([(ring(i, s), (c0, along[i])), (ring(i, s + 1), (c1, along[i])),
                           (ring(i + 1, s + 1), (c1, along[i + 1])), (ring(i + 1, s), (c0, along[i + 1]))])
        if caps and not closed:
            for end, flip in ((0, True), (n - 1, False)):
                fu, fv = frames[end]
                corners = []
                for s in range(sides):
                    a = math.tau * s / sides
                    corners.append((pts[end] + (fu * math.cos(a) + fv * math.sin(a)) * radii[end],
                                    (math.cos(a) * radii[end], math.sin(a) * radii[end])))
                self.face(list(reversed(corners)) if flip else corners)

    def prism(self, outline, y0, y1):
        """Extrude an (x, z) outline, counter-clockwise seen from +y, along y."""
        n = len(outline)
        self.face([((x, y1, z), (x, z)) for x, z in reversed(outline)])
        self.face([((x, y0, z), (x, z)) for x, z in outline])
        run = 0.0
        for i in range(n):
            (xa, za), (xb, zb) = outline[i], outline[(i + 1) % n]
            step = math.hypot(xb - xa, zb - za)
            self.face([((xa, y0, za), (run, y0)), ((xa, y1, za), (run, y1)),
                       ((xb, y1, zb), (run + step, y1)), ((xb, y0, zb), (run + step, y0))])
            run += step

    def rivet(self, at, normal, radius=0.0045, segments=6):
        self.lathe([(radius, 0.0), (radius * 0.72, radius * 0.52), (0.0, radius * 0.72)],
                   origin=at, axis=normal, ref=_perp(normal), segments=segments)

    def hexbolt(self, at, normal, across=0.014, height=0.006, washer=True):
        if washer:
            self.lathe([(across * 0.78, 0.0), (across * 0.78, 0.0015), (0.0, 0.0015)], origin=at, axis=normal,
                       ref=_perp(normal), segments=10)
        r = across / math.sqrt(3.0)
        self.lathe([(r, 0.0015), (r, height), (r * 0.82, height + 0.0012), (0.0, height + 0.0012)],
                   origin=at, axis=normal, ref=_perp(normal), segments=6)

    def screw(self, at, normal, radius=0.005):
        """Round-head screw with a slot standing as a shallow ridge either side."""
        self.lathe([(radius, 0.0), (radius * 0.86, radius * 0.42), (radius * 0.45, radius * 0.66), (0.0, radius * 0.7)],
                   origin=at, axis=normal, ref=_perp(normal), segments=8)


def _perp(normal):
    n = Vector(normal).normalized()
    seed = Vector((0, 1, 0)) if abs(n.y) < 0.9 else Vector((1, 0, 0))
    return n.cross(seed).normalized()


def arc(centre, radius, a0, a1, steps, y):
    """Points on a horizontal arc, angle measured from +x toward +z."""
    return [(centre[0] + radius * math.cos(a0 + (a1 - a0) * i / steps), y,
             centre[1] + radius * math.sin(a0 + (a1 - a0) * i / steps)) for i in range(steps + 1)]


def bezier(p0, p1, p2, p3, steps):
    out = []
    for i in range(steps + 1):
        t = i / steps
        out.append(Vector(p0) * (1 - t) ** 3 + Vector(p1) * 3 * t * (1 - t) ** 2
                   + Vector(p2) * 3 * t * t * (1 - t) + Vector(p3) * t ** 3)
    return out


# ============================================================================
# The extinguisher
# ============================================================================
def build_extinguisher():
    parts = []

    # -- the painted backboard, lagged to the wall ---------------------------
    board = Stock("Ext__Board_ON_fire_cabinet_enamel", "fire_cabinet_enamel", component="Bracket")
    board.box((-0.310, 0.0, -0.022), (0.292, 0.700, 0.0))
    for y0, y1 in ((0.030, 0.085), (0.415, 0.470)):
        board.box((-0.290, y0, PANEL_FACE_Z), (0.272, y1, BOARD_BACK_Z))
    # A cover bead round the face keeps the edge from reading as a slab.
    for lo, hi in [((-0.310, 0.688, 0.0), (0.292, 0.700, 0.004)), ((-0.310, 0.0, 0.0), (0.292, 0.012, 0.004)),
                   ((-0.310, 0.012, 0.0), (-0.298, 0.688, 0.004)), ((0.280, 0.012, 0.0), (0.292, 0.688, 0.004))]:
        board.box(lo, hi)
    parts.append(board)

    iron = Stock("Ext__Iron_ON_iron_blackened", "iron_blackened", component="Bracket")
    for x in (-0.285, 0.267):
        for y in (0.045, 0.655):
            iron.hexbolt((x, y, 0.0), (0, 0, 1), across=0.017, height=0.008)
    # Two flat-iron straps round the shell, each on a stand-off foot bolted
    # through the board.
    for y in (0.215, 0.520):
        iron.lathe([(0.1150, -0.014), (0.1182, -0.014), (0.1182, 0.014), (0.1150, 0.014), (0.1150, -0.014)],
                   origin=(0.0, y, 0.135), segments=32)
        iron.box((-0.045, y - 0.020, 0.0), (0.045, y + 0.020, 0.0185))
        for x in (-0.030, 0.030):
            iron.hexbolt((x, y, 0.0185), (0, 0, 1), across=0.012, height=0.005, washer=False)
    # The shelf: one plate carrying the foot cup and the drawn bottle, on two
    # gussets with bolted flanges.
    front = arc((0.0, 0.135), 0.128, math.radians(25.5), math.radians(154.5), 12, 0.0)
    outline = [(-0.250, 0.0), (0.140, 0.0), (0.140, 0.190)] + [(p[0], p[2]) for p in front] + [(-0.250, 0.190)]
    iron.prism(outline, 0.064, 0.070)
    # The foot cup: a pressed ring the vessel's foot stands in.
    iron.lathe([(0.1205, 0.070), (0.1235, 0.070), (0.1235, 0.128), (0.1205, 0.128), (0.1205, 0.070)],
               origin=(0.0, 0.0, 0.135), segments=32)
    iron.lathe([(0.1205, 0.1115), (0.0, 0.1115)], origin=(0.0, 0.0, 0.135), segments=32)
    for x in (-0.200, 0.095):
        # Gusset: a triangular web under the shelf, with a flange on the board.
        web = [(x - 0.003, 0.064, 0.004), (x - 0.003, 0.064, 0.170), (x - 0.003, 0.008, 0.004)]
        webb = [(x + 0.003, p[1], p[2]) for p in web]
        iron.face([(web[0], (web[0][2], web[0][1])), (web[2], (web[2][2], web[2][1])), (web[1], (web[1][2], web[1][1]))])
        iron.face([(webb[0], (webb[0][2], webb[0][1])), (webb[1], (webb[1][2], webb[1][1])), (webb[2], (webb[2][2], webb[2][1]))])
        hyp = math.hypot(0.166, 0.056)
        iron.face([(web[2], (0.0, 0.0)), (webb[2], (0.006, 0.0)), (webb[1], (0.006, hyp)), (web[1], (0.0, hyp))])
        iron.box((x - 0.020, 0.006, 0.0), (x + 0.020, 0.064, 0.004))
        for y in (0.018, 0.050):
            iron.hexbolt((x + 0.012, y, 0.004), (0, 0, 1), across=0.010, height=0.004, washer=False)
    # The cap rest: two prongs the unscrewed cap stands on, cage hanging between.
    iron.box((CAP_REST.x - 0.056, CAP_REST.y - 0.026, 0.0), (CAP_REST.x + 0.056, CAP_REST.y + 0.012, 0.005))
    for side in (-1.0, 1.0):
        x = CAP_REST.x + side * 0.043
        iron.tube([(x, CAP_REST.y - 0.0048, 0.004), (x, CAP_REST.y - 0.0048, 0.160), (x, CAP_REST.y - 0.002, 0.168),
                   (x, CAP_REST.y + 0.008, 0.171)], 0.0046, sides=8)
        iron.hexbolt((x, CAP_REST.y - 0.018, 0.005), (0, 0, 1), across=0.010, height=0.004, washer=False)
    parts.append(iron)

    # -- the blank enamel charge plate (lettered at runtime) -------------------
    plate = Stock("Ext__ChargePlate_ON_enamel_appliance", "enamel_appliance", tint=[0.15, 0.145, 0.14], component="Bracket")
    plate.box((-0.292, 0.553, 0.0), (-0.100, 0.623, 0.0030))
    plate.box((-0.288, 0.557, 0.0030), (-0.104, 0.619, 0.0042))
    parts.append(plate)
    fixed_brass = Stock("Ext__PlateScrews_ON_brass", "brass", component="Bracket")
    for x in (-0.283, -0.109):
        fixed_brass.screw((x, 0.588, 0.0042), (0, 0, 1), radius=0.0042)
    parts.append(fixed_brass)

    # -- the vessel: everything that tips as one object ---------------------
    shell = Stock("Ext__Vessel_ON_copper_aged", "copper_aged", origin=VESSEL, component="Vessel")
    profile = [(0.0, -0.012), (0.108, -0.012), (0.113, -0.006), (0.113, 0.022), (0.1160, 0.026), (0.1160, 0.034),
               (0.113, 0.038), (0.113, 0.486), (0.1160, 0.490), (0.1160, 0.499), (0.113, 0.504)]
    for i in range(1, 7):
        t = i / 6 * math.pi * 0.5
        profile.append((0.056 + 0.057 * math.cos(t), 0.504 + 0.080 * math.sin(t)))
    profile += [(0.052, 0.590), (0.052, 0.602)]
    shell.lathe(profile, segments=32)
    # The filling neck, looking down it with the cap off.
    shell.lathe([(0.0405, 0.630), (0.0405, 0.440), (0.0, 0.440)], segments=20)
    seam = math.radians(128.0)   # the vertical lap, on the left shoulder
    for i in range(10):
        y = 0.062 + i * 0.044
        n = (math.cos(seam), 0.0, math.sin(seam))
        shell.rivet((0.1128 * n[0], y, 0.1128 * n[2]), n)
    lap = [(0.1136 * math.cos(seam + a), 0.1136 * math.sin(seam + a)) for a in (-0.085, 0.085)]
    lap_in = [(0.1118 * math.cos(seam + a), 0.1118 * math.sin(seam + a)) for a in (0.085, -0.085)]
    shell.prism([lap[0], lap[1], lap_in[0], lap_in[1]], 0.040, 0.484)
    for ring_y, ring_r, tilt in ((0.012, 0.1128, 0.0), (0.514, 0.1118, 0.45)):
        for i in range(14):
            a = math.tau * (i + 0.5) / 14
            n = Vector((math.cos(a) * math.cos(tilt), math.sin(tilt), math.sin(a) * math.cos(tilt)))
            shell.rivet((ring_r * math.cos(a), ring_y, ring_r * math.sin(a)), n, radius=0.0038)
    parts.append(shell)

    brass = Stock("Ext__VesselBrass_ON_brass", "brass", origin=VESSEL, component="Vessel")
    brass.lathe([(0.108, -0.016), (0.117, -0.016), (0.1185, -0.010), (0.1185, 0.011), (0.1140, 0.016)], segments=32)
    brass.lathe([(0.0525, 0.594), (0.060, 0.594), (0.060, 0.603), (0.050, 0.607), (0.050, 0.630), (0.0405, 0.630)], segments=28)
    for side in (-1.0, 1.0):
        brass.box((side * 0.066 - 0.008, 0.612, -0.013), (side * 0.066 + 0.008, 0.628, 0.013))
        brass.box((min(side * 0.049, side * 0.060), 0.614, -0.006), (max(side * 0.049, side * 0.060), 0.626, 0.006))
    # Hose outlet boss on the right shoulder, and the union that takes the hose.
    hose_angle = math.radians(38.0)
    radial = Vector((math.cos(hose_angle), 0.0, math.sin(hose_angle)))
    boss = radial * 0.108 + Vector((0, 0.452, 0))
    brass.lathe([(0.019, 0.0), (0.019, 0.008), (0.014, 0.012), (0.014, 0.022), (0.0175, 0.024), (0.0175, 0.036),
                 (0.0125, 0.038)], origin=boss, axis=radial, ref=(0, 1, 0), segments=12)
    # The play-pipe, standing in its spring clip on the shell.
    nozzle_at = radial * 0.139
    brass.lathe([(0.0, 0.166), (0.0085, 0.166), (0.0095, 0.172), (0.0085, 0.178), (0.0135, 0.236), (0.0165, 0.240),
                 (0.0165, 0.256), (0.0155, 0.262), (0.0, 0.262)], origin=(nozzle_at.x, 0.0, nozzle_at.z), segments=12)
    clip_y = 0.229
    brass.lathe([(0.0135, clip_y - 0.007), (0.0155, clip_y - 0.007), (0.0155, clip_y + 0.007), (0.0135, clip_y + 0.007),
                 (0.0135, clip_y - 0.007)], origin=(nozzle_at.x, 0.0, nozzle_at.z), segments=12,
                sweep=math.radians(250), start=-hose_angle + math.radians(55))
    tangent = Vector((-radial.z, 0.0, radial.x))
    brass.obox(radial * 0.1185 + Vector((0, clip_y, 0)), (0.013, 0.014, 0.010), Matrix((radial, (0, 1, 0), tangent)).transposed())
    parts.append(brass)

    hose = Stock("Ext__Hose_ON_rubber_aged", "rubber_aged", origin=VESSEL, component="Vessel")
    start = boss + radial * 0.030
    top_of_nozzle = Vector((nozzle_at.x, 0.268, nozzle_at.z))
    path = bezier(start, start + radial * 0.055 + Vector((0, 0.004, 0)),
                  top_of_nozzle + Vector((radial.x * 0.030, 0.120, radial.z * 0.030)), top_of_nozzle, 14)
    hose.tube(path, 0.0125, sides=8)
    parts.append(hose)

    # -- the cap, and Miller's cage riding under it ----------------------------
    cap = Stock("Ext__Cap_ON_brass", "brass", origin=VESSEL + CAP, parent="VesselPivot", component="Cap")
    cap.lathe([(0.0, 0.004), (0.0520, 0.004), (0.0520, 0.0), (0.0600, 0.0), (0.0600, 0.040), (0.0640, 0.043),
               (0.0640, 0.052), (0.0580, 0.055), (0.0300, 0.058), (0.0220, 0.062), (0.0220, 0.079), (0.0160, 0.083),
               (0.0, 0.083)], segments=28)
    for i in range(16):
        a = math.tau * i / 16
        out = Vector((math.cos(a), 0.0, math.sin(a)))
        cap.obox(out * 0.0612 + Vector((0, 0.021, 0)), (0.0044, 0.034, 0.0058),
                 Matrix((out, (0, 1, 0), (-out.z, 0, out.x))).transposed())
    # The cross handle through the boss: this is what the hand turns.
    cap.lathe([(0.0, -0.070), (0.0095, -0.070), (0.0115, -0.064), (0.0095, -0.057), (0.0068, -0.054), (0.0068, 0.054),
               (0.0095, 0.057), (0.0115, 0.064), (0.0095, 0.070), (0.0, 0.070)],
              origin=(0.0, 0.0705, 0.0), axis=(0, 0, 1), ref=(1, 0, 0), segments=10)
    for side in (-1.0, 1.0):
        cap.box((side * 0.066 - 0.008, 0.002, -0.013), (side * 0.066 + 0.008, 0.016, 0.013))
        cap.box((min(side * 0.059, side * 0.0665), 0.003, -0.006), (max(side * 0.059, side * 0.0665), 0.015, 0.006))
    parts.append(cap)

    cage = Stock("Ext__Cage_ON_fire_hardware_steel", "fire_hardware_steel", origin=VESSEL + CAP, parent="Cap", component="Cage")
    for k in range(4):
        a = math.pi * 0.25 + k * math.pi * 0.5
        d = Vector((math.cos(a), 0.0, math.sin(a)))
        cage.tube([d * 0.031 + Vector((0, 0.004, 0)), d * 0.031 + Vector((0, -0.010, 0)), d * 0.0235 + Vector((0, -0.024, 0)),
                   d * 0.031 + Vector((0, -0.040, 0)), d * 0.031 + Vector((0, -0.150, 0)), d * 0.022 + Vector((0, -0.156, 0))],
                  0.0018, sides=5)
    for y in (-0.014, -0.148):
        cage.tube(arc((0.0, 0.0), 0.031, 0.0, math.tau, 20, y)[:-1], 0.0020, sides=5, closed=True)
    parts.append(cage)

    # -- the lead-and-wire seal -----------------------------------------------
    seal = Stock("Ext__Seal_ON_zinc_quiet", "zinc_quiet", origin=VESSEL + CAP, parent="VesselPivot", component="Seal")
    path = [(-0.066, 0.019, 0.0), (-0.066, -0.021, 0.0)]
    path += [(p[0], -0.024 - 0.010 * math.sin(math.pi * i / 12), p[2]) for i, p in enumerate(arc((0.0, 0.0), 0.0745, math.pi, 0.0, 12, 0.0))][1:-1]
    path += [(0.066, -0.021, 0.0), (0.066, 0.019, 0.0)]
    # The arc above runs through -z; the pellet hangs at the front, so mirror it.
    path = [(p[0], p[1], abs(p[2])) for p in path]
    seal.tube(path, 0.0014, sides=4)
    for side in (-1.0, 1.0):
        seal.tube(arc((side * 0.066, 0.0), 0.0046, 0.0, math.tau, 8, 0.019)[:-1], 0.0013, sides=4, closed=True)
    seal.lathe([(0.0, -0.0032), (0.0066, -0.0032), (0.0076, 0.0), (0.0066, 0.0032), (0.0, 0.0032)],
               origin=(0.0, -0.0375, 0.0745), axis=(0, 0, 1), ref=(1, 0, 0), segments=10)
    parts.append(seal)

    # -- the eight-ounce acid bottle and its loose cap ---------------------------
    bottle = Stock("Ext__Bottle_ON_glass_drawn_expressive", "glass_drawn_expressive", origin=BOTTLE_SEATED, component="Bottle")
    bottle.lathe([(0.0, -0.056), (0.0255, -0.056), (0.0275, -0.052), (0.0275, 0.044), (0.0245, 0.050), (0.0155, 0.058),
                  (0.0155, 0.066), (0.0175, 0.066), (0.0175, 0.070), (0.0108, 0.070), (0.0108, 0.030), (0.0, 0.030)],
                 segments=20)
    parts.append(bottle)
    acid = Stock("Ext__Acid_ON_bakelite_black", "bakelite_black", origin=BOTTLE_SEATED, parent="AcidBottle",
                 tint=[0.62, 0.42, 0.16], component="AcidLevel")
    acid.lathe([(0.0, -0.0535), (0.0240, -0.0535), (0.0250, -0.050), (0.0250, -0.002), (0.0, -0.002)], segments=16)
    parts.append(acid)
    stopple = Stock("Ext__Stopple_ON_zinc_quiet", "zinc_quiet", origin=BOTTLE_SEATED + STOPPLE, parent="AcidBottle",
                    component="LooseCap")
    stopple.lathe([(0.0090, -0.0300), (0.0090, 0.0050), (0.0186, 0.0050), (0.0186, -0.0105), (0.0215, -0.0105), (0.0215, 0.0075),
                   (0.0185, 0.0105), (0.0, 0.0105)], segments=16)
    stopple.lathe([(0.0, -0.0300), (0.0090, -0.0300)], segments=16)
    parts.append(stopple)

    # -- the blank tag on its twine, tied to the upper strap -------------------
    tag = Stock("Ext__Tag_ON_paper", "paper", origin=TAG, component="Tag")
    c = 0.011
    card = [(-0.047, -0.0275), (0.047, -0.0275), (0.047, 0.0275 - c), (0.047 - c, 0.0275), (-0.047 + c, 0.0275), (-0.047, 0.0275 - c)]
    tag.face([((x, y, 0.0007), (x, y)) for x, y in card])
    tag.face([((x, y, -0.0007), (-x, y)) for x, y in reversed(card)])
    run = 0.0
    for i in range(len(card)):
        (xa, ya), (xb, yb) = card[i], card[(i + 1) % len(card)]
        step = math.hypot(xb - xa, yb - ya)
        tag.face([((xa, ya, -0.0007), (run, 0.0)), ((xb, yb, -0.0007), (run + step, 0.0)),
                  ((xb, yb, 0.0007), (run + step, 0.0014)), ((xa, ya, 0.0007), (run, 0.0014))])
        run += step
    tag.lathe([(0.0030, 0.0007), (0.0062, 0.0007), (0.0062, 0.0013), (0.0030, 0.0013)], origin=(0.0, 0.0195, 0.0),
              axis=(0, 0, 1), ref=(1, 0, 0), segments=10)
    strap_point = Vector((-0.1182 * math.cos(math.radians(8)), 0.520, 0.135 + 0.1182 * math.sin(math.radians(8)))) - TAG
    twine = bezier((0.0, 0.0195, 0.0016), (0.004, 0.040, 0.004), strap_point + Vector((-0.010, -0.022, 0.002)),
                   strap_point + Vector((-0.002, -0.012, 0.0)), 8)
    tag.tube(twine, 0.0011, sides=4)
    tag.tube([strap_point + Vector((-0.002, -0.0155, 0.0)), strap_point + Vector((-0.0022, 0.0155, 0.0)),
              strap_point + Vector((0.0, 0.0165, 0.0))], 0.0011, sides=4)
    parts.append(tag)
    return parts


# ============================================================================
# The door check
# ============================================================================
def build_check():
    parts = []
    H, W = LEAF_HEIGHT, HEAD_FACE_Z
    sx, sz = SPINDLE.x, SPINDLE.z

    body = Stock("Check__Body_ON_iron_blackened", "iron_blackened", component="Box")
    # Back plate, screwed to the iron head casing above the opening.
    body.box((0.012, H + 0.003, W), (0.444, H + 0.087, W + 0.010))
    # The check cylinder, with its two cast saddles.
    body.lathe([(0.0, 0.066), (0.043, 0.066), (0.043, 0.396), (0.0, 0.396)], origin=(0.0, BARREL_Y, BARREL_Z),
               axis=(1, 0, 0), ref=(0, 1, 0), segments=24)
    for x in (0.130, 0.352):
        body.lathe([(0.043, x - 0.013), (0.0475, x - 0.013), (0.0475, x + 0.013), (0.043, x + 0.013)],
                   origin=(0.0, BARREL_Y, BARREL_Z), axis=(1, 0, 0), ref=(0, 1, 0), segments=24)
        body.box((x - 0.013, BARREL_Y - 0.040, W + 0.010), (x + 0.013, BARREL_Y + 0.040, W + 0.030))
    # The cast pad the legend stands on (lettered at runtime).
    body.box((0.180, BARREL_Y - 0.0125, BARREL_Z + 0.036), (0.320, BARREL_Y + 0.0125, BARREL_Z + 0.0445))
    # The spring drum under the hinge end of the cylinder, with the notched band
    # the catch drops against.
    body.lathe([(0.0, H - 0.012), (0.0285, H - 0.012), (0.0300, H - 0.010), (0.0300, H + 0.004), (0.0240, H + 0.008)],
               origin=(sx, 0.0, sz), segments=20)
    for i in range(10):
        a = math.tau * i / 10
        out = Vector((math.cos(a), 0.0, math.sin(a)))
        body.obox(Vector((sx, H - 0.004, sz)) + out * 0.0308, (0.0036, 0.010, 0.0056),
                  Matrix((out, (0, 1, 0), (-out.z, 0, out.x))).transposed())
    # The lug that carries the catch, off the plate's hinge end.
    body.box((HOLD_PIVOT.x - 0.010, H - 0.018, W + 0.010), (HOLD_PIVOT.x + 0.010, H + 0.014, HOLD_PIVOT.z - 0.0045))
    for x in (0.024, 0.432):
        for y in (H + 0.013, H + 0.077):
            body.screw((x, y, W + 0.010), (0, 0, 1), radius=0.0052)
    parts.append(body)

    trim = Stock("Check__BodyBrass_ON_brass", "brass", component="Box")
    for x0, x1 in ((0.050, 0.070), (0.392, 0.414)):
        trim.lathe([(0.0, x0), (0.047, x0), (0.047, x1), (0.0, x1)], origin=(0.0, BARREL_Y, BARREL_Z), axis=(1, 0, 0),
                   ref=(0, 1, 0), segments=24)
    # The filler plug, square-headed, on top of the cylinder.
    trim.lathe([(0.014, 0.041), (0.014, 0.050), (0.0, 0.050)], origin=(0.215, BARREL_Y, BARREL_Z), segments=12)
    trim.lathe([(0.0085, 0.050), (0.0085, 0.059), (0.0, 0.059)], origin=(0.215, BARREL_Y, BARREL_Z), segments=4)
    # The spindle the arm ships onto.
    trim.lathe([(0.0, H - 0.044), (0.0095, H - 0.044), (0.0095, H - 0.012)], origin=(sx, 0.0, sz), segments=12)
    parts.append(trim)

    witness = Stock("Check__Witness_ON_indicator_enamel", "indicator_enamel", component="Box")
    # The witness mark the tang is read against: a pointer on top of the end
    # cap, standing just proud of its face. It never turns.
    witness.box((0.397, BARREL_Y + 0.0465, BARREL_Z - 0.0035), (0.4225, BARREL_Y + 0.0585, BARREL_Z + 0.0035))
    parts.append(witness)

    # The regulating screw: thumb head, slot and the index tang it is read by.
    valve = Stock("Check__RegulatingScrew_ON_brass", "brass", origin=VALVE_REST, component="Valve")
    valve.lathe([(0.0, -0.018), (0.0075, -0.018), (0.0075, -0.010), (0.0190, -0.010), (0.0205, -0.006), (0.0205, 0.006),
                 (0.0190, 0.010), (0.0, 0.010)], axis=(1, 0, 0), ref=(0, 1, 0), segments=18)
    for i in range(12):
        a = math.tau * i / 12
        out = Vector((0.0, math.cos(a), math.sin(a)))
        valve.obox(out * 0.0205, (0.012, 0.0030, 0.0042), Matrix(((1, 0, 0), out, Vector((1, 0, 0)).cross(out))).transposed())
    valve.box((0.0010, 0.0, -0.0036), (0.0080, 0.052, 0.0036))
    valve.box((0.0100, -0.014, -0.0016), (0.0122, 0.014, 0.0016))
    parts.append(valve)

    # The main arm: hub on the spindle, flat bar, and the elbow eye.
    arm = Stock("Check__MainArm_ON_iron_blackened", "iron_blackened", origin=SPINDLE, component="MainArm")
    arm.lathe([(0.0, -0.011), (0.0205, -0.011), (0.0225, -0.008), (0.0225, 0.008), (0.0205, 0.011), (0.0, 0.011)], segments=16)
    arm.box((0.014, -0.0055, -0.0125), (ARM_MAIN - 0.012, 0.0055, 0.0125))
    arm.lathe([(0.0, -0.0065), (0.0165, -0.0065), (0.0165, 0.0065), (0.0, 0.0065)], origin=(ARM_MAIN, 0.0, 0.0), segments=14)
    arm.lathe([(0.0075, 0.0065), (0.0075, 0.0100), (0.0, 0.0115)], origin=(ARM_MAIN, 0.0, 0.0), segments=8)
    parts.append(arm)

    # The forearm: under the main arm at the elbow, out to the eye on the shoe pin.
    fore = Stock("Check__Forearm_ON_iron_blackened", "iron_blackened", origin=SPINDLE + Vector((ARM_MAIN, 0, 0)),
                 parent="MainArm", component="Forearm")
    fy = -0.0135
    fore.lathe([(0.0, fy - 0.006), (0.0155, fy - 0.006), (0.0155, fy + 0.006), (0.0, fy + 0.006)], segments=14)
    fore.lathe([(0.0, fy - 0.0105), (0.0075, fy - 0.009), (0.0075, fy - 0.006)], segments=8)
    fore.box((0.012, fy - 0.005, -0.0105), (ARM_FORE - 0.013, fy + 0.005, 0.0105))
    fore.lathe([(0.0075, fy - 0.006), (0.0155, fy - 0.006), (0.0155, fy + 0.006), (0.0075, fy + 0.006), (0.0075, fy - 0.006)],
               origin=(ARM_FORE, 0.0, 0.0), segments=14)
    parts.append(fore)

    # The shoe: an angle bracket bolted through the leaf's top rail, carrying the
    # pin. Its origin is the hinge line, so the leaf's own angle turns it.
    pivot = Vector((0.0, 0.0, HINGE_AXIS_Z))
    shoe = Stock("Check__Shoe_ON_iron_blackened", "iron_blackened", origin=pivot, component="Shoe")
    px, py = SHOE_PIN.x, SHOE_PIN.y
    pz = SHOE_PIN.z - HINGE_AXIS_Z          # everything below is local to the hinge line
    zf = LEAF_FACE_Z - HINGE_AXIS_Z
    shoe.box((px - 0.050, py - 0.046, zf), (px + 0.050, py + 0.012, zf + 0.006))
    shoe.box((px - 0.022, py - 0.036, zf + 0.006), (px + 0.022, py - 0.028, pz + 0.020))
    web = [(px - 0.003, py - 0.046, zf + 0.006), (px - 0.003, py - 0.036, zf + 0.006), (px - 0.003, py - 0.036, pz - 0.014)]
    webb = [(px + 0.003, q[1], q[2]) for q in web]
    shoe.face([(web[0], (web[0][2], web[0][1])), (web[2], (web[2][2], web[2][1])), (web[1], (web[1][2], web[1][1]))])
    shoe.face([(webb[0], (webb[0][2], webb[0][1])), (webb[1], (webb[1][2], webb[1][1])), (webb[2], (webb[2][2], webb[2][1]))])
    hyp = (Vector(web[2]) - Vector(web[0])).length
    shoe.face([(web[0], (0.0, 0.0)), (webb[0], (0.006, 0.0)), (webb[2], (0.006, hyp)), (web[2], (0.0, hyp))])
    shoe.lathe([(0.0, py - 0.028), (0.0068, py - 0.028), (0.0068, py - 0.004), (0.0095, py - 0.004), (0.0095, py - 0.001), (0.0, py)],
               origin=(px, 0.0, pz), segments=10)
    for x in (px - 0.036, px + 0.036):
        for y in (py - 0.038, py + 0.002):
            shoe.hexbolt((x, y, zf + 0.006), (0, 0, 1), across=0.010, height=0.004, washer=False)
    parts.append(shoe)

    # The hold-open catch: a short pawl on a pin at the hinge end. It stands
    # upright, clear of the arm; thrown, it lies against the drum's notched band.
    hold = Stock("Check__HoldOpenCatch_ON_iron_blackened", "iron_blackened", origin=HOLD_PIVOT, component="Hold")
    hold.lathe([(0.0, -0.0045), (0.0085, -0.0045), (0.0085, 0.0045), (0.0, 0.0045)], axis=(0, 0, 1), ref=(1, 0, 0), segments=12)
    hold.box((-0.0050, 0.0050, -0.0038), (0.0050, 0.0400, 0.0038))
    hold.lathe([(0.0, 0.0038), (0.0060, 0.0038), (0.0078, 0.0085), (0.0060, 0.0130), (0.0, 0.0140)], origin=(0.0, 0.031, 0.0),
               axis=(0, 0, 1), ref=(1, 0, 0), segments=10)
    parts.append(hold)
    return parts


# ============================================================================
# Meshes, materials, checks, renders, export
# ============================================================================
def material(key, tint):
    name = key if tint is None else "%s|%s" % (key, ",".join("%.3f" % c for c in tint))
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    spec = CATALOG[key]
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    node = mat.node_tree.nodes["Principled BSDF"]
    node.inputs["Metallic"].default_value = spec["metallic"]
    coord = mat.node_tree.nodes.new("ShaderNodeTexCoord")
    scale = mat.node_tree.nodes.new("ShaderNodeVectorMath")
    scale.operation = "SCALE"
    scale.inputs["Scale"].default_value = 1.0 / spec["meters_per_tile"]
    mat.node_tree.links.new(coord.outputs["UV"], scale.inputs[0])
    glass = key.startswith("glass_")
    for index, target in ((0, "Base Color"), (1, "Roughness"), (2, "Normal")):
        image = bpy.data.images.load(str(TEXTURES / spec["files"][index]), check_existing=True)
        # Relative to art/blender/, where the .blend is saved: no machine path in it.
        image.filepath = "//../../game/assets/building/textures/" + spec["files"][index]
        if index:
            image.colorspace_settings.name = "Non-Color"
        tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = image
        mat.node_tree.links.new(scale.outputs["Vector"], tex.inputs["Vector"])
        if index == 2:
            normal = mat.node_tree.nodes.new("ShaderNodeNormalMap")
            normal.inputs["Strength"].default_value = 0.35
            mat.node_tree.links.new(tex.outputs["Color"], normal.inputs["Color"])
            mat.node_tree.links.new(normal.outputs[0], node.inputs[target])
        elif index == 1:
            mul = mat.node_tree.nodes.new("ShaderNodeMath")
            mul.operation = "MULTIPLY"
            mul.inputs[1].default_value = spec["roughness_multiplier"]
            mat.node_tree.links.new(tex.outputs["Color"], mul.inputs[0])
            mat.node_tree.links.new(mul.outputs[0], node.inputs[target])
        elif glass:
            node.inputs["Base Color"].default_value = (0.9, 0.97, 0.94, 1)
        elif tint is not None:
            mix = mat.node_tree.nodes.new("ShaderNodeMixRGB")
            mix.blend_type = "MULTIPLY"
            mix.inputs[0].default_value = 1.0
            mix.inputs[2].default_value = (*tint, 1.0)
            mat.node_tree.links.new(tex.outputs["Color"], mix.inputs[1])
            mat.node_tree.links.new(mix.outputs[0], node.inputs[target])
        else:
            mat.node_tree.links.new(tex.outputs["Color"], node.inputs[target])
    if glass:
        node.inputs["Transmission Weight"].default_value = 1.0
        node.inputs["Roughness"].default_value = 0.06
        node.inputs["IOR"].default_value = 1.5
    return mat


def realise(stock):
    """Turn a Stock into a Blender mesh object with origin at its pivot."""
    bm = bmesh.new()
    layer = bm.loops.layers.uv.new("Metres")
    cache = {}

    def vert(p):
        local = to_blender(p)
        key = (round(local.x, 6), round(local.y, 6), round(local.z, 6))
        if key not in cache:
            cache[key] = bm.verts.new(local)
        return cache[key]

    skipped = 0
    for corners in stock.faces:
        verts = [vert(p) for p, _ in corners]
        if len(set(verts)) < 3:
            skipped += 1
            continue
        try:
            face = bm.faces.new(verts)
        except ValueError:
            # The same three vertices already carry a face (a zero-thickness lap).
            skipped += 1
            continue
        for loop, (_, uv) in zip(face.loops, corners):
            loop[layer].uv = uv
        face.smooth = True
    bmesh.ops.triangulate(bm, faces=list(bm.faces))
    mesh = bpy.data.meshes.new(stock.name)
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(material(stock.key, stock.tint))
    mesh.set_sharp_from_angle(angle=math.radians(38.0))
    # The exact direction of increasing u on every triangle, already in glTF's
    # axes: the exporter hook below turns it into the tangent.
    guides = mesh.attributes.new(name="_tangent_guide", type="FLOAT_VECTOR", domain="CORNER")
    charts = mesh.uv_layers["Metres"].data
    for poly in mesh.polygons:
        loops = list(poly.loop_indices)
        p = [mesh.vertices[mesh.loops[i].vertex_index].co for i in loops]
        t = [Vector(charts[i].uv) for i in loops]
        e1, e2, d1, d2 = p[1] - p[0], p[2] - p[0], t[1] - t[0], t[2] - t[0]
        det = d1.x * d2.y - d2.x * d1.y
        if abs(det) < 1e-14:
            raise RuntimeError("%s: collapsed UV triangle" % stock.name)
        du = ((e1 * d2.y - e2 * d1.y) / det).normalized()
        for i in loops:
            guides.data[i].vector = (du.x, du.z, -du.y)
    obj = bpy.data.objects.new(stock.name, mesh)
    obj.location = to_blender(stock.origin)
    bpy.context.scene.collection.objects.link(obj)
    # Checks: finite positions, every triangle with real area and a real chart.
    mesh.calc_loop_triangles()
    uv = mesh.uv_layers["Metres"].data
    for tri in mesh.loop_triangles:
        a, b, c = [mesh.vertices[i].co for i in tri.vertices]
        area = (b - a).cross(c - a).length * 0.5
        if area < 1e-10:
            raise RuntimeError("%s: collapsed triangle" % stock.name)
        ua, ub, uc = [Vector(uv[i].uv) for i in tri.loops]
        chart = abs((ub - ua).x * (uc - ua).y - (ub - ua).y * (uc - ua).x) * 0.5
        if not (chart > 1e-10) or not all(math.isfinite(v) for v in (*ua, *ub, *uc)):
            raise RuntimeError("%s: collapsed or non-finite UV triangle" % stock.name)
        stretch = chart / area
        if stretch < 0.05 or stretch > 20.0:
            raise RuntimeError("%s: chart off physical scale (%.3f)" % (stock.name, stretch))
    return obj, len(mesh.loop_triangles)


def render(name, location, target, lens=50.0):
    scene = bpy.context.scene
    camera = scene.camera
    camera.location = to_blender(Vector(location))
    direction = to_blender(Vector(target)) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    camera.data.lens = lens
    scene.render.filepath = str(REVIEW / name)
    bpy.ops.render.render(write_still=True)


def review_stage():
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 32
    scene.cycles.use_denoising = True
    scene.render.resolution_x, scene.render.resolution_y = 840, 840
    world = bpy.data.worlds.new("review")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.20, 0.20, 0.21, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.55
    extras = []
    cam_data = bpy.data.cameras.new("review")
    cam_data.clip_start = 0.01
    camera = bpy.data.objects.new("ReviewCamera", cam_data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    extras.append(camera)

    def light(kind, at, energy, size=0.6):
        data = bpy.data.lights.new("review", kind)
        data.energy = energy
        if kind == "AREA":
            data.size = size
        obj = bpy.data.objects.new("ReviewLight", data)
        obj.location = to_blender(Vector(at))
        obj.rotation_euler = (-obj.location).to_track_quat("-Z", "Y").to_euler()
        scene.collection.objects.link(obj)
        extras.append(obj)
        return obj

    def wall(lo, hi, colour):
        stock = Stock("ReviewWall", "paper")
        stock.box(lo, hi)
        obj, _ = realise(stock)
        mat = bpy.data.materials.new("review_wall")
        mat.use_nodes = True
        mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*colour, 1)
        mat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.9
        obj.data.materials.clear()
        obj.data.materials.append(mat)
        extras.append(obj)
        return obj

    return extras, light, wall


def pose(obj, location=None, rotation=None):
    """Pose in Godot terms: location (x, y, z) and a Godot basis as a Matrix."""
    if location is not None:
        obj.location = to_blender(Vector(location))
    if rotation is not None:
        convert = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))
        obj.rotation_euler = (convert @ rotation @ convert.transposed()).to_euler()


def roty(a):
    return Matrix(((math.cos(a), 0, math.sin(a)), (0, 1, 0), (-math.sin(a), 0, math.cos(a))))


def rotz(a):
    return Matrix(((math.cos(a), -math.sin(a), 0), (math.sin(a), math.cos(a), 0), (0, 0, 1)))


def solve_arm(angle):
    """Arm and forearm yaw (Godot rotation.y) that put the eye on the shoe pin
    with the leaf turned `angle` about the hinge line; elbow toward +z."""
    rel = Vector((SHOE_PIN.x, SHOE_PIN.z - HINGE_AXIS_Z))
    pin = Vector((rel.x * math.cos(angle) + rel.y * math.sin(angle), -rel.x * math.sin(angle) + rel.y * math.cos(angle) + HINGE_AXIS_Z))
    dx, dz = pin.x - SPINDLE.x, pin.y - SPINDLE.z
    reach = min(max(math.hypot(dx, dz), 0.001), ARM_MAIN + ARM_FORE - 0.001)
    phi = math.atan2(-dz, dx)
    beta = math.acos(max(-1.0, min(1.0, (reach ** 2 + ARM_MAIN ** 2 - ARM_FORE ** 2) / (2 * reach * ARM_MAIN))))
    gamma = math.acos(max(-1.0, min(1.0, (ARM_MAIN ** 2 + ARM_FORE ** 2 - reach ** 2) / (2 * ARM_MAIN * ARM_FORE))))
    return phi - beta, math.pi - gamma, math.hypot(dx, dz)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    stocks = build_extinguisher() + build_check()
    objects, rows, total = {}, [], 0
    for stock in stocks:
        obj, triangles = realise(stock)
        objects[stock.name] = obj
        total += triangles
        row = {"name": stock.name, "component": stock.component, "material": stock.key, "triangles": triangles}
        if stock.tint is not None:
            row["tint"] = stock.tint
        rows.append(row)
    # The link solution must close at every leaf angle the door allows.
    worst = 0.0
    for step in range(0, 101):
        worst = max(worst, solve_arm(math.radians(step))[2])
    if worst > ARM_MAIN + ARM_FORE - 0.008:
        raise RuntimeError("arm cannot reach the shoe at full swing: needs %.3f" % worst)
    closed = solve_arm(0.0)[2]
    if closed < abs(ARM_MAIN - ARM_FORE) + 0.02:
        raise RuntimeError("arm cannot fold to the shut leaf")

    # ---- review renders, in the frames the game mounts them in ---------------
    if "--no-review" in sys.argv:
        return export(objects, rows, total, closed, worst)
    extras, light, wall = review_stage()
    ext = {n: o for n, o in objects.items() if n.startswith("Ext__")}
    chk = {n: o for n, o in objects.items() if n.startswith("Check__")}
    for o in chk.values():
        o.hide_render = True
    wall((-0.9, -0.5, WALL_PLANE_Z - 0.04), (0.9, 1.4, WALL_PLANE_Z), (0.62, 0.60, 0.54))
    wall((-0.9, -0.5, WALL_PLANE_Z), (0.9, 0.62, PANEL_FACE_Z), (0.30, 0.17, 0.10))
    wall((-0.9, 0.62, WALL_PLANE_Z), (0.9, 0.66, WALL_PLANE_Z + 0.050), (0.30, 0.17, 0.10))
    light("AREA", (0.9, 1.3, 1.3), 90)
    light("AREA", (-1.0, 0.5, 1.0), 35)
    rest = {n: (o.location.copy(), o.rotation_euler.copy()) for n, o in objects.items()}
    render("extinguisher_front.png", (0.05, 0.52, 1.25), (-0.05, 0.40, 0.0), 50)
    render("extinguisher_three_quarter.png", (0.85, 0.75, 0.95), (-0.03, 0.42, 0.08), 55)
    render("extinguisher_left.png", (-0.95, 0.60, 0.75), (-0.05, 0.42, 0.08), 55)
    render("extinguisher_cap_close.png", (0.22, 0.98, 0.52), (0.0, 0.76, 0.135), 60)
    # The inspection pose: seal cut, cap set across the shoulder with the cage,
    # bottle drawn and standing on the shelf with its cap lifted proud.
    ext["Ext__Seal_ON_zinc_quiet"].hide_render = True
    for name in ("Ext__Cap_ON_brass", "Ext__Cage_ON_fire_hardware_steel"):
        pose(ext[name], CAP_REST)
    for name, lift in (("Ext__Bottle_ON_glass_drawn_expressive", Vector()), ("Ext__Acid_ON_bakelite_black", Vector()),
                       ("Ext__Stopple_ON_zinc_quiet", STOPPLE + Vector((0, 0.026, 0)))):
        pose(ext[name], BOTTLE_DRAWN + lift)
    render("extinguisher_opened.png", (-0.20, 0.95, 1.25), (0.0, 0.42, 0.10), 45)
    render("extinguisher_cap_rest.png", (0.75, 0.80, 0.70), (0.16, 0.56, 0.10), 60)
    render("extinguisher_bottle_close.png", (-0.42, 0.30, 0.55), (-0.192, 0.15, 0.15), 70)
    for name, (loc, rot) in rest.items():
        objects[name].location, objects[name].rotation_euler = loc, rot
    ext["Ext__Seal_ON_zinc_quiet"].hide_render = False

    for o in ext.values():
        o.hide_render = True
    for o in chk.values():
        o.hide_render = False
    for o in list(extras):
        if o.name.startswith("ReviewWall") or o.type == "LIGHT":
            bpy.data.objects.remove(o)
            extras.remove(o)
    H = LEAF_HEIGHT
    # The partition round the opening, the iron casing on its stair face, and a
    # stand-in leaf.
    wall((-0.7, H, WALL_ROOF_Z), (1.9, H + 0.8, WALL_FACE_Z), (0.62, 0.60, 0.54))
    wall((-0.7, 1.2, WALL_ROOF_Z), (0.0, H, WALL_FACE_Z), (0.62, 0.60, 0.54))
    wall((1.1, 1.2, WALL_ROOF_Z), (1.9, H, WALL_FACE_Z), (0.62, 0.60, 0.54))
    wall((-CASING, H, WALL_FACE_Z), (1.1 + CASING, H + CASING, HEAD_FACE_Z), (0.22, 0.23, 0.22))
    wall((-CASING, 1.2, WALL_FACE_Z), (0.0, H, HEAD_FACE_Z), (0.22, 0.23, 0.22))
    wall((1.1, 1.2, WALL_FACE_Z), (1.1 + CASING, H, HEAD_FACE_Z), (0.22, 0.23, 0.22))
    leaf = wall((0.01, 1.2, -0.026 - HINGE_AXIS_Z), (1.09, H - 0.01, 0.034 - HINGE_AXIS_Z), (0.36, 0.38, 0.36))
    leaf.location = to_blender(Vector((0.0, 0.0, HINGE_AXIS_Z)))
    light("AREA", (0.9, H + 0.3, 1.4), 110)
    light("AREA", (-0.6, H - 0.5, 1.0), 40)
    light("AREA", (0.6, H - 0.2, -1.3), 60)

    def swing(angle):
        a1, a2, _ = solve_arm(angle)
        pose(chk["Check__MainArm_ON_iron_blackened"], SPINDLE, roty(a1))
        elbow = SPINDLE + Vector((ARM_MAIN * math.cos(a1), 0.0, -ARM_MAIN * math.sin(a1)))
        pose(chk["Check__Forearm_ON_iron_blackened"], elbow, roty(a1 + a2))
        pose(chk["Check__Shoe_ON_iron_blackened"], (0.0, 0.0, HINGE_AXIS_Z), roty(angle))
        pose(leaf, (0.0, 0.0, HINGE_AXIS_Z), roty(angle))

    swing(0.0)
    render("check_closed_stair_side.png", (0.95, H - 0.35, 1.25), (0.26, H + 0.02, 0.14), 45)
    render("check_closed_under.png", (0.30, H - 0.75, 0.75), (0.25, H + 0.0, 0.16), 40)
    render("check_screw_close.png", (0.72, H + 0.08, 0.42), tuple(VALVE_REST), 70)
    render("check_catch_close.png", (-0.12, H - 0.10, 0.50), (0.07, H + 0.0, BARREL_Z), 70)
    swing(math.radians(50))
    render("check_half_open.png", (0.95, H - 0.35, 1.25), (0.26, H + 0.0, 0.0), 40)
    swing(math.radians(100))
    render("check_open_stair_side.png", (1.05, H - 0.35, 1.25), (0.20, H + 0.0, -0.10), 36)
    render("check_open_roof_side.png", (0.95, H - 0.45, -1.35), (0.15, H + 0.0, -0.20), 36)
    swing(0.0)
    for o in ext.values():
        o.hide_render = False
    for o in extras:
        if o.name in bpy.data.objects:
            bpy.data.objects.remove(o)
    for o in list(bpy.data.objects):
        if o.name.startswith("ReviewWall") or o.type in ("LIGHT", "CAMERA"):
            bpy.data.objects.remove(o)

    export(objects, rows, total, closed, worst)


def export(objects, rows, total, closed, worst):
    # ---- save and export ------------------------------------------------------
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "art/blender/fire_apparatus.blend"), check_existing=False)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects.values():
        obj.select_set(True)
    asset = ROOT / "game/assets/props/fire_apparatus.glb"

    class ExportChartTangents:
        """Write each corner's tangent from its own chart (the project's
        exporter convention, as in build_pawn_clocks.py): the u direction,
        made square to the exported normal, with the one handedness."""
        corrected = 0

        def gather_mesh_hook(self, mesh, blender_data, blender_object, vertex_groups, modifiers, materials, export_settings):
            from io_scene_gltf2.io.exp.binary_data import BinaryData
            from io_scene_gltf2.io.com.constants import BufferViewTarget
            for primitive in mesh.primitives:
                def vectors(key):
                    accessor = primitive.attributes[key]
                    assert accessor.component_type == 5126 and accessor.type == "VEC3"
                    return np.frombuffer(accessor.buffer_view.data, dtype="<f4").reshape((-1, 3)).astype(np.float64)
                n = vectors("NORMAL")
                n /= np.linalg.norm(n, axis=1)[:, None]
                guide = vectors("_TANGENT_GUIDE")
                tangent = guide - n * np.sum(guide * n, axis=1)[:, None]
                tangent /= np.linalg.norm(tangent, axis=1)[:, None]
                assert np.isfinite(tangent).all()
                packed = np.column_stack((tangent, -np.ones(len(n)))).astype(np.float32)
                primitive.attributes["TANGENT"].buffer_view = BinaryData(packed.tobytes(), BufferViewTarget.ARRAY_BUFFER)
                type(self).corrected += 1
                for key in list(primitive.attributes):
                    if key.upper() == "_TANGENT_GUIDE":
                        del primitive.attributes[key]

    import io_scene_gltf2
    io_scene_gltf2.glTF2ExportUserExtension = ExportChartTangents
    bpy.ops.export_scene.gltf(filepath=str(asset), export_format="GLB", use_selection=True, export_yup=True,
                              export_apply=True, export_normals=True, export_tangents=True, export_texcoords=True,
                              export_attributes=True, export_materials="NONE", export_animations=False)
    assert ExportChartTangents.corrected == len(objects), (ExportChartTangents.corrected, len(objects))
    v = lambda p: [round(c, 6) for c in p]
    data = {
        "schema_version": 1,
        "asset": "res://assets/props/fire_apparatus.glb",
        "source": "art/blender/scripts/build_fire_apparatus.py",
        "triangles": total,
        "extinguisher": {
            "vessel_pivot": v(VESSEL), "cap": v(CAP), "bottle_in_cage": v(BOTTLE_SEATED - VESSEL - CAP),
            "stopple": v(STOPPLE), "tag": v(TAG), "cap_rest": v(CAP_REST), "bottle_drawn": v(BOTTLE_DRAWN),
            "plate_face_z": 0.0042, "board_back_z": BOARD_BACK_Z, "wall_plane_z": round(WALL_PLANE_Z, 6), "board_x": [-0.310, 0.292], "board_height": 0.700,
            "shelf_top_y": 0.070,
        },
        "door_check": {
            "leaf_height": LEAF_HEIGHT, "hinge_axis_z": HINGE_AXIS_Z, "leaf_face_z": LEAF_FACE_Z,
            "wall_face_z": WALL_FACE_Z, "head_face_z": HEAD_FACE_Z, "spindle": v(SPINDLE), "shoe_pin": v(SHOE_PIN), "valve_rest": v(VALVE_REST),
            "hold_pivot": v(HOLD_PIVOT), "forearm_drop": -0.0135, "legend": v(LEGEND),
        },
        "parts": rows,
    }
    (ROOT / "game/data/orison_v2/fire_apparatus.json").write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8", newline="\n")
    ext_tris = sum(r["triangles"] for r in rows if r["name"].startswith("Ext__"))
    print("[FIRE APPARATUS] %d parts, %d triangles (extinguisher %d, door check %d); arm reach %.3f shut, %.3f at full swing"
          % (len(rows), total, ext_tris, total - ext_tris, closed, worst))


main()
