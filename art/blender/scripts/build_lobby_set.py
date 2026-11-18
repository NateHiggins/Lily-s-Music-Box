"""The lobby set for the V2 building, authored in Blender (V1 retirement, 2026-11-10).

Three assemblies replace V1's procedural boxes, quads and cylinders:

  Bulletin  the building's notice board: moulded oak frame, pinning field,
            legend plate, one pin, and nine separate paper sheets (eight
            notices and the wireless hand-copy) sized to V1's notices.
  Advert    the original Orison broadside: moulded frame and backing, the
            sheet with its loose lower-right corner as a separately pivoted
            flap, ruled border and a line engraving of the house as ink
            geometry (no lettering, no sampled picture), two later service
            slips, corner bosses (one a movable inspection boss), a bead pull
            chain on its bracket, the dust ledge and its debris.
  Chute     the Cutler mail chute and Cusick choke: channel body with wall
            lugs and ceiling collar, glass-fronted sections in brass grooves,
            the choke, the arch letters and their load, locking cover and key,
            catch tray, clearing blade, lamp index, and the collection box
            with its glazed door hinged at one side.

Every vertex is authored in the prop's own Godot frame (x along the wall, y up,
z out of the wall, metres; wall face at z = 0) and converted once to Blender's
Z-up frame. UVs are in metres; the runtime multiplies by the catalogue tile.
Every moving part is its own object with its origin on the pivot V1's own
animation code expects. No lettering is modelled or textured: words are Label3D
at runtime (RUL-008). Deterministic: one seed.

  blender -b --python-exit-code 1 -P art/blender/scripts/build_lobby_set.py -- <review_dir>
Writes game/assets/props/lobby_set.glb, art/blender/lobby_set.blend,
game/data/orison_v2/lobby_set.json and review renders under <review_dir>.
"""
import bpy, bmesh, json, math, random, sys
from mathutils import Vector, Matrix
from pathlib import Path

SEED = 1928
ROOT = next(p for p in Path(__file__).resolve().parents if (p / "game/project.godot").is_file())
OUT = Path(sys.argv[sys.argv.index("--") + 1]) if "--" in sys.argv else ROOT / "tmp/lobby_set_review"
OUT.mkdir(parents=True, exist_ok=True)
CATALOG = json.loads((ROOT / "game/data/runtime_material_sets.json").read_text(encoding="utf-8"))["materials"]
TEXTURES = ROOT / "game/assets/building/textures"
RNG = random.Random(SEED)

# The lobby storey's clear height: the chute rises to this ceiling and enters it.
CEILING = 3.0
# Cutler's dimension, as V1 holds it: the box door bottom, 2 ft 6 in above the floor.
BOX_DOOR_MIN = 0.762

PARTS = []  # (name, assembly, component, key, tint, pivot, MeshBuilder, role, axis_angle)


def conv(p):
    """Prop frame (x, y up, z out of wall) to Blender (x, -z, y)."""
    return Vector((p[0], -p[2], p[1]))


class MB:
    """Faces with explicit per-corner UVs in metres; nothing is shared, so the
    export is flat shaded and every tangent agrees with its own chart."""

    def __init__(self):
        self.v, self.f, self.uv = [], [], []
        self.m = Matrix.Identity(4)

    def face(self, pts, uvs):
        base = len(self.v)
        self.v += [tuple(self.m @ Vector(p)) for p in pts]
        self.f.append(tuple(range(base, base + len(pts))))
        self.uv.append([tuple(u) for u in uvs])

    def poly(self, pts, udir=None):
        """A planar polygon (counter-clockwise seen from outside) with an
        isometric metre chart; udir, when given, is the texture U direction."""
        p = [Vector(q) for q in pts]
        n = Vector((0, 0, 0))
        for i in range(len(p)):
            n += p[i].cross(p[(i + 1) % len(p)])
        n.normalize()
        u = Vector(udir) if udir is not None else (p[1] - p[0])
        u = (u - n * u.dot(n)).normalized()
        w = n.cross(u)
        self.face(p, [((q - p[0]).dot(u), (q - p[0]).dot(w)) for q in p])

    def box(self, lo, hi, grain=None):
        """Axis-aligned stock. grain names the axis the wood runs along; on
        every face that contains it the chart's V follows it."""
        for a in range(3):
            b, c = (a + 1) % 3, (a + 2) % 3
            for side, val in ((1, hi[a]), (-1, lo[a])):
                quad = [(lo[b], lo[c]), (hi[b], lo[c]), (hi[b], hi[c]), (lo[b], hi[c])]
                if side < 0:
                    quad.reverse()
                pts, uvs = [], []
                for qb, qc in quad:
                    p = [0.0, 0.0, 0.0]
                    p[a], p[b], p[c] = val, qb, qc
                    pts.append(p)
                    uvs.append((qc, qb) if grain == b else (qb, qc))
                self.face(pts, uvs)

    def prism(self, pts2d, lo, hi, plane="xy"):
        """Extrude a counter-clockwise polygon along the plane's normal axis."""
        def at(a, b, c):
            return {"xy": (a, b, c), "yz": (c, a, b), "zx": (b, c, a)}[plane]
        n = len(pts2d)
        self.poly([at(a, b, hi) for a, b in pts2d])
        self.poly([at(a, b, lo) for a, b in reversed(pts2d)])
        for i in range(n):
            (a0, b0), (a1, b1) = pts2d[i], pts2d[(i + 1) % n]
            self.poly([at(a0, b0, lo), at(a1, b1, lo), at(a1, b1, hi), at(a0, b0, hi)])

    def frame(self, w, h, profile, centre=(0.0, 0.0), grain_v=True):
        """A mitred moulding round a w x h rectangle. profile is the section
        as (distance in from the outer edge, height out of the wall), walked
        outer-back, outer-front, inner-front, inner-back."""
        lengths = [0.0]
        for i in range(len(profile)):
            a, b = profile[i], profile[(i + 1) % len(profile)]
            lengths.append(lengths[-1] + math.hypot(b[0] - a[0], b[1] - a[1]))
        signs = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
        def ring(i, k):
            d, z = profile[i % len(profile)]
            sx, sy = signs[k % 4]
            return (centre[0] + sx * (w / 2 - d), centre[1] + sy * (h / 2 - d), z)
        for i in range(len(profile)):
            for k in range(4):
                pts = [ring(i, k), ring(i, k + 1), ring(i + 1, k + 1), ring(i + 1, k)]
                axis = 0 if k % 2 == 0 else 1
                s = [lengths[i], lengths[i], lengths[i + 1], lengths[i + 1]]
                uvs = [((s[j], pts[j][axis]) if grain_v else (pts[j][axis], s[j])) for j in range(4)]
                self.face(pts, uvs)

    def lathe(self, profile, origin, axis="z", seg=16):
        """Revolve (radius, height) pairs about an axis through origin. Walk the
        profile from the base outward surface up and then in across the top."""
        basis = {"z": (Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))),
                 "y": (Vector((0, 0, 1)), Vector((1, 0, 0)), Vector((0, 1, 0))),
                 "x": (Vector((0, 1, 0)), Vector((0, 0, 1)), Vector((1, 0, 0)))}[axis]
        o = Vector(origin)
        def pt(r, hgt, t):
            return o + basis[0] * (r * math.cos(t)) + basis[1] * (r * math.sin(t)) + basis[2] * hgt
        run = 0.0
        for i in range(len(profile) - 1):
            (r0, h0), (r1, h1) = profile[i], profile[i + 1]
            step = math.hypot(r1 - r0, h1 - h0)
            for j in range(seg):
                t0, t1 = j / seg * math.tau, (j + 1) / seg * math.tau
                mid, half, mean = (t0 + t1) / 2, (t1 - t0) / 2, (r0 + r1) / 2
                corners = [(r0, h0, t0, -1, run), (r0, h0, t1, 1, run), (r1, h1, t1, 1, run + step), (r1, h1, t0, -1, run + step)]
                if r0 < 1e-7:
                    corners = [corners[0], corners[2], corners[3]]
                elif r1 < 1e-7:
                    corners = [corners[0], corners[1], corners[2]]
                self.face([pt(r, hgt, t) for r, hgt, t, _, _ in corners],
                          [(mid * mean + sgn * half * r, v) for r, _, _, sgn, v in corners])
            run += step

    def sheet(self, w, h, nx, ny, zf, back=True, origin=(0.0, 0.0)):
        """A paper sheet as a grid in the xy plane, lifted by zf(x, y)."""
        def p(i, j, dz=0.0):
            x = origin[0] - w / 2 + w * i / nx
            y = origin[1] - h / 2 + h * j / ny
            return (x, y, zf(x - origin[0], y - origin[1]) + dz)
        for i in range(nx):
            for j in range(ny):
                quad = [(i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)]
                self.face([p(a, b) for a, b in quad], [p(a, b)[:2] for a, b in quad])
                if back:
                    quad.reverse()
                    self.face([p(a, b, -0.0003) for a, b in quad], [p(a, b)[:2] for a, b in quad])

    def bead(self, c, r):
        c = Vector(c)
        ax = [Vector((r, 0, 0)), Vector((0, r, 0)), Vector((0, 0, r))]
        for sx in (1, -1):
            for sy in (1, -1):
                for sz in (1, -1):
                    tri = [c + ax[0] * sx, c + ax[1] * sy, c + ax[2] * sz]
                    if sx * sy * sz < 0:
                        tri.reverse()
                    self.poly(tri)

    def stroke(self, a, b, width, z, clip=None):
        """A ruled ink line lying on a sheet at height z."""
        a, b = Vector((a[0], a[1])), Vector((b[0], b[1]))
        if clip is not None:
            seg = clip(a, b)
            if seg is None:
                return
            a, b = seg
        d = b - a
        if d.length < 1e-6:
            return
        n = Vector((-d.y, d.x)).normalized() * (width / 2)
        self.poly([(a.x - n.x, a.y - n.y, z), (b.x - n.x, b.y - n.y, z), (b.x + n.x, b.y + n.y, z), (a.x + n.x, a.y + n.y, z)])

    def triangles(self):
        return sum(len(f) - 2 for f in self.f)


def part(name, assembly, component, key, mb, pivot=(0.0, 0.0, 0.0), tint=None, role="static", axis_angle=None, smooth=False):
    """smooth: weld the turned work and shade it round, keeping every edge over 38 degrees sharp."""
    PARTS.append({"name": "%s__%s_ON_%s" % (assembly, name, key), "assembly": assembly, "component": component,
                  "key": key, "tint": tint, "pivot": pivot, "mb": mb, "role": role, "axis_angle": axis_angle, "smooth": smooth})


def screw(mb, at, r=0.0045, proud=0.0018, axis="z"):
    """A slotted round-head fastener seated on a surface at `at`."""
    mb.lathe([(r, 0.0), (r * 0.82, proud * 0.7), (r * 0.4, proud), (0.0, proud)], at, axis, 8)


# --------------------------------------------------------------------------
# The notice board
# --------------------------------------------------------------------------
BOARD_W, BOARD_H = 0.92, 0.68
NOTE_W, NOTE_H = 0.205, 0.256
WIRELESS_W, WIRELESS_H = 0.44, 0.50


def paper(w, h, index, nx=6, ny=8):
    """A sheet pinned at its top edge only: flat where the words are, lifting
    at the two bottom corners and a little along the foot."""
    lift_l = 0.004 + 0.007 * RNG.random()
    lift_r = 0.004 + 0.007 * RNG.random()
    bow = 0.0006 + 0.0008 * RNG.random()
    def zf(x, y):
        u, v = x / (w / 2), y / (h / 2)
        foot = max(0.0, -v - 0.80) / 0.20
        left, right = max(0.0, -u - 0.45) / 0.55, max(0.0, u - 0.45) / 0.55
        return bow * (1 - u * u) * max(0.0, -v) + foot * foot * (lift_l * left * left + lift_r * right * right)
    mb = MB()
    mb.sheet(w, h, nx, ny, zf)
    return mb


def build_bulletin():
    frame = MB()
    frame.frame(BOARD_W, BOARD_H, [(0.0, 0.0), (0.0, 0.034), (0.006, 0.040), (0.030, 0.040), (0.038, 0.034),
                                  (0.044, 0.026), (0.050, 0.022), (0.050, 0.0)])
    part("Frame", "Bulletin", "Frame", "oak_quartered", frame, tint=[0.62, 0.50, 0.40])
    field = MB()
    field.box((-BOARD_W / 2 + 0.046, -BOARD_H / 2 + 0.046, 0.002), (BOARD_W / 2 - 0.046, BOARD_H / 2 - 0.046, 0.018))
    part("Field", "Bulletin", "Field", "monks_cloth", field, tint=[0.78, 0.56, 0.34])
    brass = MB()
    # The legend plate on the head rail (the word itself is a Label3D).
    py = BOARD_H / 2 - 0.018
    brass.prism([(-0.130, py - 0.012), (0.130, py - 0.012), (0.130, py + 0.012), (-0.130, py + 0.012)], 0.040, 0.0425)
    brass.prism([(-0.126, py - 0.009), (0.126, py - 0.009), (0.126, py + 0.009), (-0.126, py + 0.009)], 0.0425, 0.0434)
    for sx in (-1, 1):
        screw(brass, (sx * 0.119, py, 0.0434), 0.0024, 0.0010)
    # Four screws hold the frame to the wall through the rails.
    for sx in (-1, 1):
        for sy in (-1, 1):
            screw(brass, (sx * (BOARD_W / 2 - 0.018), sy * (BOARD_H / 2 - 0.018), 0.040), 0.0040, 0.0016)
    part("Brass", "Bulletin", "Brass", "brass", brass, smooth=True)
    pin = MB()
    # One drawing pin, origin where its shank enters the paper.
    pin.lathe([(0.0012, -0.008), (0.0012, 0.0005), (0.0050, 0.0005), (0.0070, 0.0030), (0.0058, 0.0062), (0.0030, 0.0080), (0.0, 0.0084)],
              (0, 0, 0), "z", 10)
    part("Pin", "Bulletin", "Pin", "brass", pin, role="instanced", smooth=True)
    # V1's ages, in its atlas order; the paper's yellowing is a tint over the
    # catalogue sheet instead of a painted texture.
    ages = [0.15, 0.42, 0.30, 0.55, 0.68, 0.80, 0.92, 0.22]
    for i, age in enumerate(ages):
        part("Notice%d" % i, "Bulletin", "Notice", "paper", paper(NOTE_W, NOTE_H, i),
             tint=[1 - 0.175 * age, 1 - 0.213 * age, 1 - 0.269 * age], role="sheet")
    part("Wireless", "Bulletin", "Wireless", "paper", paper(WIRELESS_W, WIRELESS_H, 8, 8, 10), tint=[0.92, 0.88, 0.76], role="sheet")
    rule = MB()
    # The ruled line under a notice's heading, ink on the sheet.
    rule.stroke((-0.0785, 0.0784), (0.0785, 0.0784), 0.0012, 0.0006)
    part("Rule", "Bulletin", "Rule", "paper", rule, tint=[0.16, 0.14, 0.12], role="instanced")


# --------------------------------------------------------------------------
# The Orison broadside
# --------------------------------------------------------------------------
AD_W, AD_H = 1.425, 1.925
SHEET_W, SHEET_H = 1.08, 1.45
SHEET_Z = 0.0412
CREASE_A, CREASE_B = Vector((0.32, -0.725)), Vector((0.54, -0.535))
INK = [0.17, 0.12, 0.09]
# The lobby walls carry a wainscot whose cap rail stands 50 mm off the plaster
# and whose backing stands 16 mm off it (orison_v2_millwork.gd). The board
# hangs across it as V1 hung it: its back (z = 0) bears on the cap rail, a
# batten packs its head out to the plaster, and the ledge brackets seat on the
# wainscot backing.
CAP_STANDOFF = 0.050
BACKING_STANDOFF = 0.016


def crease_clip(a, b):
    """Keep the part of a ruled line that lies on the fixed sheet, off the loose corner."""
    d = CREASE_B - CREASE_A
    n = Vector((-d.y, d.x))  # points to the fixed side (up and left)
    sa, sb = (a - CREASE_A).dot(n), (b - CREASE_A).dot(n)
    if sa <= 0 and sb <= 0:
        return None
    if sa > 0 and sb > 0:
        return a, b
    t = sa / (sa - sb)
    m = a + (b - a) * t
    return (a, m) if sa > 0 else (m, b)


def engraving(ink, centre, width, z):
    """A line engraving of a six-storey corner block in two-point perspective,
    drawn as ruled ink: no lettering and no sampled picture."""
    la, lb, hgt = 38.0, 24.0, 22.5      # the two street fronts and the cornice height, metres
    eye = Vector((30.0, -34.0, 9.0))
    look = Vector((-7.0, 4.0, 10.0))
    fwd = (look - eye).normalized()
    right = fwd.cross(Vector((0, 0, 1))).normalized()
    up = right.cross(fwd)
    def proj(p):
        d = Vector(p) - eye
        depth = d.dot(fwd)
        return Vector((d.dot(right) / depth, d.dot(up) / depth))
    # Front A runs west from the corner along -x; front B runs north along +y.
    def a(s, t):
        return proj((-s, 0.0, t))
    def b(s, t):
        return proj((0.0, s, t))
    outline = [a(la, 0), a(la, hgt), a(0, hgt), b(lb, hgt), b(lb, 0), a(0, 0)]
    lo = Vector((min(p.x for p in outline), min(p.y for p in outline)))
    hi = Vector((max(p.x for p in outline), max(p.y for p in outline)))
    scale = width / (hi.x - lo.x)
    mid = (lo + hi) / 2
    def place(p):
        return Vector((centre[0] + (p.x - mid.x) * scale, centre[1] + (p.y - mid.y) * scale))
    def line(p, q, w=0.0014):
        ink.stroke(place(p), place(q), w, z)
    def fill(pts):
        ink.poly([(place(p).x, place(p).y, z) for p in pts])
    for front, length, bays in ((a, la, 12), (b, lb, 8)):
        line(front(0, 0), front(length, 0), 0.0022)
        line(front(0, hgt), front(length, hgt), 0.0022)
        line(front(length, 0), front(length, hgt), 0.0018)
        line(front(0, hgt - 1.1), front(length, hgt - 1.1), 0.0010)      # cornice
        line(front(0, hgt + 0.9), front(length, hgt + 0.9), 0.0012)      # parapet
        line(front(length, hgt), front(length, hgt + 0.9), 0.0012)
        line(front(0, 4.3), front(length, 4.3), 0.0012)                  # water table over the ground storey
        for floor in range(6):
            base = 0.9 + floor * 3.55 if floor else 1.0
            top = base + (2.5 if floor else 2.7)
            for bay in range(bays):
                s0 = (bay + 0.26) * length / bays
                s1 = (bay + 0.74) * length / bays
                fill([front(s0, base), front(s1, base), front(s1, top), front(s0, top)] if front is b
                     else [front(s1, base), front(s0, base), front(s0, top), front(s1, top)])
                line(front(s0 - 0.12, base - 0.14), front(s1 + 0.12, base - 0.14), 0.0007)   # sill
    line(a(0, 0), a(0, hgt + 0.9), 0.0024)                               # the corner
    # The entrance canopy on the long front, and the pavement and kerb lines.
    fill([a(19.9, 0.2), a(18.1, 0.2), a(18.1, 3.0), a(19.9, 3.0)])
    for s in (17.0, 21.0):
        line(proj((-s, -1.6, 0.0)), proj((-s, -1.6, 3.3)), 0.0012)
    line(proj((-17.0, -1.6, 3.3)), proj((-21.0, -1.6, 3.3)), 0.0016)
    line(a(17.0, 3.3), proj((-17.0, -1.6, 3.3)), 0.0012)
    line(a(21.0, 3.3), proj((-21.0, -1.6, 3.3)), 0.0012)
    for off, w in ((3.2, 0.0012), (3.7, 0.0008)):
        line(proj((-la - 6, -off, 0)), proj((off, -off, 0)), w)
        line(proj((off, -off, 0)), proj((off, lb + 6, 0)), w)
    return place(Vector((mid.x, lo.y))).y, place(Vector((mid.x, hi.y))).y


def build_advert():
    wood = MB()
    wood.frame(AD_W, AD_H, [(0.0, 0.0), (0.0, 0.090), (0.010, 0.1075), (0.045, 0.1075), (0.060, 0.095), (0.090, 0.095),
                            (0.105, 0.110), (0.112, 0.1475), (0.140, 0.1475), (0.150, 0.130), (0.150, 0.0)])
    # The backing board the sheet lies on, let into the frame.
    wood.box((-AD_W / 2 + 0.150, -AD_H / 2 + 0.150, 0.010), (AD_W / 2 - 0.150, AD_H / 2 - 0.150, 0.040), grain=1)
    # The bottom ledge (V1's dust ledge) on two brackets that reach the wall.
    ledge_y = -0.99
    seat = BACKING_STANDOFF - CAP_STANDOFF
    wood.prism([(ledge_y - 0.0375, seat), (ledge_y + 0.0375, seat), (ledge_y + 0.0375, 0.175), (ledge_y - 0.0275, 0.175), (ledge_y - 0.0375, 0.165)],
               -0.735, 0.735, "yz")
    # The batten that packs the head of the frame out to the plaster.
    wood.box((-0.62, 0.800, -CAP_STANDOFF), (0.62, 0.900, 0.0), grain=0)
    for sx in (-0.52, 0.52):
        wood.prism([(ledge_y - 0.150, seat), (ledge_y - 0.0375, seat), (ledge_y - 0.0375, 0.150), (ledge_y - 0.150, 0.022)], sx - 0.016, sx + 0.016, "yz")
    part("Frame", "Advert", "Frame", "wood_dark", wood, tint=[0.50, 0.42, 0.38])

    sheet = MB()
    hw, hh = SHEET_W / 2, SHEET_H / 2
    sheet.poly([(-hw, -hh, SHEET_Z), (CREASE_A.x, CREASE_A.y, SHEET_Z), (CREASE_B.x, CREASE_B.y, SHEET_Z), (hw, hh, SHEET_Z), (-hw, hh, SHEET_Z)],
               udir=(1, 0, 0))
    part("Sheet", "Advert", "Sheet", "paper", sheet, tint=[0.86, 0.74, 0.52])

    # The loose corner: a flap hinged on the crease, curling up off the board.
    crease = CREASE_B - CREASE_A
    length = crease.length
    mid = (CREASE_A + CREASE_B) / 2
    along = crease.normalized()
    corner = Vector((hw, -hh))
    apex_x = (corner - mid).dot(along)
    depth = abs((corner - mid).dot(Vector((-along.y, along.x))))
    radius, rows = 0.085, 9
    flap = MB()
    def flap_pt(s, f, dz=0.0):
        xl = -length / 2 + (apex_x + length / 2) * (s / depth)
        xr = length / 2 + (apex_x - length / 2) * (s / depth)
        ang = s / radius
        return (xl + (xr - xl) * f, -radius * math.sin(ang), radius * (1 - math.cos(ang)) + dz)
    for r in range(rows):
        s0, s1 = depth * r / rows, depth * (r + 1) / rows
        if r == rows - 1:
            tri = [flap_pt(s0, 0), flap_pt(s1, 0.5), flap_pt(s0, 1)]
            flap.face(tri, [(tri[0][0], -s0), (tri[1][0], -s1), (tri[2][0], -s0)])
            tri = [(p[0], p[1], p[2] - 0.0003) for p in reversed(tri)]
            flap.face(tri, [(tri[0][0], -s0), (tri[1][0], -s1), (tri[2][0], -s0)])
        else:
            quad = [flap_pt(s1, 0), flap_pt(s1, 1), flap_pt(s0, 1), flap_pt(s0, 0)]
            uvs = [(quad[0][0], -s1), (quad[1][0], -s1), (quad[2][0], -s0), (quad[3][0], -s0)]
            flap.face(quad, uvs)
            flap.face([(p[0], p[1], p[2] - 0.0003) for p in reversed(quad)], list(reversed(uvs)))
    part("LooseCorner", "Advert", "LooseCorner", "paper", flap, pivot=(mid.x, mid.y, SHEET_Z), tint=[0.86, 0.74, 0.52],
         role="moving", axis_angle=(math.atan2(along.y, along.x), (0, 0, 1)))

    ink = MB()
    z = SHEET_Z + 0.0005
    for inset, w in ((0.030, 0.0030), (0.040, 0.0010)):
        x, y = hw - inset, hh - inset
        for p, q in (((-x, -y), (x, -y)), ((x, -y), (x, y)), ((x, y), (-x, y)), ((-x, y), (-x, -y))):
            ink.stroke(p, q, w, z, crease_clip)
    # Corner ornaments: a lozenge in each of the three fixed corners.
    for sx, sy in ((-1, 1), (1, 1), (-1, -1)):
        cx, cy = sx * (hw - 0.064), sy * (hh - 0.064)
        ink.poly([(cx - 0.012, cy, z), (cx, cy - 0.012, z), (cx + 0.012, cy, z), (cx, cy + 0.012, z)])
        ink.stroke((cx, cy), (cx - sx * 0.05, cy), 0.0010, z)
        ink.stroke((cx, cy), (cx, cy - sy * 0.05), 0.0010, z)
    foot, head = engraving(ink, (0.0, 0.055), 0.80, z)
    # Short rules that separate the lines of type, and the closing ornament.
    for y, half in ((-0.405, 0.045), (-0.462, 0.030)):
        ink.stroke((-half, y), (half, y), 0.0009, z)
    oy = -0.672
    ink.poly([(-0.016, oy, z), (0.0, oy - 0.009, z), (0.016, oy, z), (0.0, oy + 0.009, z)])
    for sx in (-1, 1):
        ink.stroke((sx * 0.024, oy), (sx * 0.075, oy), 0.0012, z)
        ink.poly([(sx * 0.082 - 0.005, oy, z), (sx * 0.082, oy - 0.004, z), (sx * 0.082 + 0.005, oy, z), (sx * 0.082, oy + 0.004, z)])
    # The inspector's stamp bar on the later slip (V1's InspectionStamp).
    ink.stroke((-0.725, -0.300), (-0.535, -0.300), 0.012, 0.1491)
    part("Ink", "Advert", "Ink", "paper", ink, tint=INK)

    slips = MB()
    # Two later service slips pinned over the frame, as V1 hangs them.
    def slip(cx, cy, w, h, tilt, base):
        slips.m = Matrix.Translation((cx, cy, base)) @ Matrix.Rotation(tilt, 4, "Z")
        bow = 0.003 + 0.003 * RNG.random()
        slips.sheet(w, h, 4, 5, lambda x, y: bow * max(0.0, -y / (h / 2)) ** 2)
        slips.m = Matrix.Identity(4)
    slip(-0.63, -0.35, 0.28, 0.34, 0.03, 0.1485)
    slip(0.61, 0.31, 0.30, 0.19, -0.045, 0.1485)
    # A dead moth's wing on the ledge.
    slips.poly([(0.03, -0.9520, 0.105), (0.085, -0.9520, 0.118), (0.05, -0.9520, 0.090)])
    part("Slips", "Advert", "Slips", "paper", slips, tint=[0.62, 0.55, 0.40])

    brass = MB()
    boss = [(0.060, -0.0125), (0.060, 0.0), (0.062, 0.006), (0.054, 0.014), (0.046, 0.016), (0.040, 0.026), (0.026, 0.036), (0.012, 0.040), (0.0, 0.041)]
    corners = [(-0.655, -0.905), (0.655, -0.905), (-0.655, 0.905), (0.655, 0.905)]
    for cx, cy in corners[1:]:
        brass.lathe(boss, (cx, cy, 0.1075), "z", 20)
    for at in ((-0.586, -0.19, 0.1490), (0.586, 0.395, 0.1490)):       # the bent tacks holding the slips
        brass.lathe([(0.0016, -0.006), (0.0016, 0.0), (0.014, 0.0012), (0.016, 0.004), (0.009, 0.008), (0.0, 0.009)], at, "z", 10)
    for at in ((0.0, 0.700, SHEET_Z), (0.0, -0.700, SHEET_Z), (-0.515, 0.700, SHEET_Z), (0.515, 0.700, SHEET_Z)):
        brass.lathe([(0.004, 0.0), (0.0065, 0.002), (0.004, 0.005), (0.0, 0.0055)], at, "z", 8)
    # The pull chain's bracket: a rose on the wall, an arm, and the eye the chain hangs from.
    cx, cy, cz = 0.82, 0.78, 0.15
    brass.lathe([(0.030, 0.0), (0.030, 0.004), (0.020, 0.010), (0.007, 0.014)], (cx, cy + 0.012, -CAP_STANDOFF), "z", 14)
    brass.lathe([(0.0055, 0.012), (0.0055, cz + CAP_STANDOFF + 0.010), (0.0, cz + CAP_STANDOFF + 0.012)], (cx, cy + 0.012, -CAP_STANDOFF), "z", 8)
    brass.lathe([(0.0035, -0.012), (0.0035, 0.0)], (cx, cy + 0.012, cz), "y", 8)
    part("Brass", "Advert", "Brass", "brass", brass, smooth=True)

    knob = MB()
    knob.lathe(boss, (0, 0, -0.0175), "z", 20)
    part("InspectionBoss", "Advert", "InspectionBoss", "brass", knob, pivot=(corners[0][0], corners[0][1], 0.125), role="moving", smooth=True)

    chain = MB()
    n = 68
    for i in range(n):
        chain.bead((0, -0.004 - i * 0.0086, 0), 0.0030)
    chain.lathe([(0.0008, -0.004 - (n - 1) * 0.0086), (0.0008, 0.0)], (0, 0, 0), "y", 5)
    end = -0.004 - n * 0.0086
    # The bell pull at the chain's end (profile walked downward, so it is mirrored).
    chain.lathe([(0.0105, end - 0.034), (0.009, end - 0.030), (0.004, end), (0.0, end + 0.004)], (0, 0, 0), "y", 12)
    chain.poly([(0.0105 * math.cos(t), end - 0.034, 0.0105 * math.sin(t)) for t in [k / 12 * math.tau for k in range(12)]])
    part("Chain", "Advert", "Chain", "brass", chain, pivot=(cx, cy, cz), role="moving", smooth=True)

    debris = MB()
    top = ledge_y + 0.0375
    for cx, size, zc in ((-0.51, 0.045, 0.110), (-0.25, 0.070, 0.085), (0.18, 0.038, 0.125), (0.46, 0.060, 0.095)):
        hgt = size * (0.30 + 0.25 * RNG.random())
        ang = RNG.random() * math.tau
        pts = [(cx + size * 0.5 * math.cos(ang + k * math.tau / 5) * (0.7 + 0.3 * RNG.random()),
                zc + size * 0.33 * math.sin(ang + k * math.tau / 5) * (0.7 + 0.3 * RNG.random())) for k in range(5)]
        debris.prism([(zc_, x_) for x_, zc_ in pts][::-1], top, top + hgt, "zx")
    part("Debris", "Advert", "Debris", "limewash_plaster", debris, tint=[0.78, 0.74, 0.66])
    return {"engraving_foot": foot, "engraving_head": head}


# --------------------------------------------------------------------------
# The mail chute
# --------------------------------------------------------------------------
def envelope(mb, size, m=None):
    """A sealed letter: a thin closed stock, chart along its length."""
    if m is not None:
        mb.m = m
    w, t, d = size
    mb.box((-w / 2, -t / 2, -d / 2), (w / 2, t / 2, d / 2))
    mb.m = Matrix.Identity(4)


def build_chute():
    box_lo, box_hi = BOX_DOOR_MIN - 0.018, BOX_DOOR_MIN + 0.398
    floor_top = box_lo + 0.026
    iron = MB()
    # The channel: a back and two cheeks, open behind the glass (V1's rule: a
    # channel, not a solid). It rises from the box into the ceiling.
    iron.box((-0.095, box_hi, 0.0), (0.095, CEILING, 0.028))
    for sx in (-1, 1):
        x0, x1 = sorted((sx * 0.069, sx * 0.095))
        iron.box((x0, box_hi, 0.028), (x1, CEILING, 0.1295))
        # Cusick's expansion chamber stands out at each side above the choke.
        x0, x1 = sorted((sx * 0.095, sx * 0.1045))
        iron.prism([(1.68, 0.0), (1.66, 0.118), (1.38, 0.118), (1.36, 0.0)], x0, x1, "yz")
        # The choke: a cheek whose upper face carries a letter's low end and
        # whose lip narrows the passage to a throat.
        pts = [(sx * 0.069, 1.292), (sx * 0.069, 1.215), (sx * 0.030, 1.235), (sx * 0.030, 1.262)]
        iron.prism(pts[::-1] if sx > 0 else pts, 0.028, 0.112)
    # Wall lugs: plates screwed to the wall beside the channel at three heights.
    for y in (1.26, 2.135, CEILING - 0.11):
        for sx in (-1, 1):
            x0, x1 = sorted((sx * 0.095, sx * 0.140))
            iron.box((x0, y - 0.030, 0.0), (x1, y + 0.030, 0.008))
            screw(iron, (sx * 0.1215, y, 0.008), 0.0055, 0.0022)
    # The collar where the chute enters the ceiling.
    iron.box((-0.130, CEILING - 0.022, 0.0), (0.130, CEILING, 0.158))
    # The peg the clearing blade hangs on, beside the choke.
    iron.lathe([(0.0035, 0.0), (0.0035, 0.137), (0.0, 0.139)], (0.16, 1.385, 0.0), "z", 8)
    # The collection box: a case, not a solid (V1), hung at Cutler's height.
    iron.box((-0.170, box_lo, 0.0), (0.170, box_hi, 0.026))
    for sx in (-1, 1):
        x0, x1 = sorted((sx * 0.144, sx * 0.170))
        iron.box((x0, box_lo, 0.026), (x1, box_hi, 0.198))
    iron.box((-0.144, box_lo, 0.026), (0.144, floor_top, 0.198))
    # The box head, open under the channel throat.
    iron.box((-0.144, box_hi - 0.026, 0.1295), (0.144, box_hi, 0.198))
    for sx in (-1, 1):
        x0, x1 = sorted((sx * 0.095, sx * 0.144))
        iron.box((x0, box_hi - 0.026, 0.026), (x1, box_hi, 0.1295))
    # The box front: a plate with the door's opening in it.
    iron.box((-0.170, 1.087, 0.198), (0.170, box_hi, 0.210))
    iron.box((-0.170, box_lo, 0.198), (0.170, 0.797, 0.210))
    for sx in (-1, 1):
        x0, x1 = sorted((sx * 0.135, sx * 0.170))
        iron.box((x0, 0.797, 0.198), (x1, 1.087, 0.210))
    # Two straps carry the box from the wall.
    for sx in (-1, 1):
        x0, x1 = sorted((sx * 0.170, sx * 0.205))
        iron.box((x0, box_hi - 0.075, 0.0), (x1, box_hi - 0.015, 0.008))
        screw(iron, (sx * 0.189, box_hi - 0.045, 0.008), 0.0055, 0.0022)
    part("Body", "Chute", "Body", "iron_blackened", iron, smooth=True)

    brass = MB()
    # The grooves the glass runs in, both sections.
    for sx in (-1, 1):
        x0, x1 = sorted((sx * 0.066, sx * 0.098))
        brass.box((x0, box_hi, 0.1295), (x1, 2.130, 0.1375))
        brass.box((x0, 2.140, 0.1295), (x1, CEILING - 0.022, 0.1375))
    # The rail between the two glass sections.
    brass.box((-0.069, 2.118, 0.1090), (0.069, 2.152, 0.1160))
    # The legend plate on the box head (the marking is a Label3D).
    brass.box((-0.100, box_hi - 0.0455, 0.2100), (0.100, box_hi - 0.0005, 0.2140))
    for sx in (-1, 1):
        screw(brass, (sx * 0.090, box_hi - 0.023, 0.2140), 0.0028, 0.0012)
    # The fixed leaves of the door's two hinges, on the box's west stile.
    for y in (BOX_DOOR_MIN + 0.07, BOX_DOOR_MIN + 0.29):
        brass.box((-0.170, y - 0.022, 0.210), (-0.1505, y + 0.022, 0.2135))
    part("Brass", "Chute", "Brass", "brass", brass, smooth=True)

    glass = MB()
    glass.box((-0.0675, -0.53, -0.003), (0.0675, 0.53, 0.003))
    part("Glass", "Chute", "Glass", "glass", glass, pivot=(0.0, 1.58, 0.124), role="moving")
    upper = MB()
    upper.box((-0.0675, 2.150, 0.1100), (0.0675, CEILING - 0.022, 0.1160))
    part("UpperGlass", "Chute", "UpperGlass", "glass", upper)

    for name, at, tint in (("ArchWest", (-0.022, 1.325, 0.070), [0.92, 0.90, 0.80]), ("ArchEast", (0.022, 1.335, 0.066), [0.86, 0.83, 0.72])):
        mb = MB()
        envelope(mb, (0.115, 0.014, 0.080))
        part(name, "Chute", name, "paper", mb, pivot=at, tint=tint, role="moving")
    load = MB()
    # The loose mail standing on the arch: letters on edge, leaning on one another.
    for i, (dx, dy, dz, lean) in enumerate([(-0.004, -0.006, -0.028, -0.09), (0.004, 0.004, -0.015, 0.07), (-0.002, -0.002, -0.002, -0.04),
                                            (0.003, 0.008, 0.011, 0.10), (-0.005, 0.002, 0.024, -0.08)]):
        envelope(load, (0.112, 0.006 + 0.002 * (i % 2), 0.132 + 0.008 * (i % 3)),
                 Matrix.Translation((dx, dy, dz)) @ Matrix.Rotation(lean, 4, "Z") @ Matrix.Rotation(math.pi / 2, 4, "X"))
    part("Load", "Chute", "Load", "paper", load, pivot=(0.0, 1.45, 0.068), tint=[0.90, 0.87, 0.76], role="moving")

    # V1 moves the cover only along z, the key only about z, the tray, the lamp
    # index and the glass only along y and the blade only along x. Their meshes
    # are set off from those pivots so each sits on real construction: the
    # cover and key on the channel front above the box head, the tray above
    # the box, the index on the east groove.
    cover = MB()
    cover.prism([(-0.1075, 0.025), (0.1075, 0.025), (0.1075, 0.105), (-0.1075, 0.105)], 0.0095, 0.0215)
    cover.prism([(-0.0975, 0.035), (0.0975, 0.035), (0.0975, 0.095), (-0.0975, 0.095)], 0.0215, 0.0255)
    cover.lathe([(0.030, 0.0255), (0.030, 0.0280), (0.0215, 0.0295)], (0, 0.065, 0), "z", 16)
    part("Cover", "Chute", "Cover", "brass", cover, pivot=(0.0, 1.14, 0.128), role="moving", smooth=True)
    key = MB()
    key.lathe([(0.020, 0.0035), (0.020, 0.020), (0.017, 0.024), (0.0, 0.024)], (0, 0, 0), "z", 14)
    key.box((-0.0035, -0.016, 0.024), (0.0035, 0.016, 0.046))     # the bow of the key, so its turn can be read
    part("Key", "Chute", "Key", "brass", key, pivot=(0.0, 1.205, 0.150), role="moving", smooth=True)

    tray = MB()
    ty = 0.100
    tray.box((-0.100, ty - 0.008, -0.015), (0.100, ty - 0.004, 0.085))
    for lo, hi in (((-0.100, ty - 0.004, -0.015), (-0.096, ty + 0.012, 0.085)), ((0.096, ty - 0.004, -0.015), (0.100, ty + 0.012, 0.085)),
                   ((-0.096, ty - 0.004, 0.081), (0.096, ty + 0.012, 0.085)), ((-0.096, ty - 0.004, -0.015), (0.096, ty + 0.012, -0.011))):
        tray.box(lo, hi)
    part("Tray", "Chute", "Tray", "metal", tray, pivot=(0.0, 1.06, 0.155), role="moving")
    blade = MB()
    blade.prism([(-0.014, -0.085), (0.0, -0.100), (0.014, -0.085), (0.014, 0.100), (-0.014, 0.100)], 0.0, 0.003)
    part("Blade", "Chute", "Blade", "metal", blade, pivot=(0.16, 1.30, 0.130), role="moving")

    door = MB()
    # The glazed door, origin on the hinge line at the west stile of the box.
    hx = 0.150
    door.frame(0.300, 0.320, [(0.0, -0.006), (0.0, 0.008), (0.004, 0.012), (0.020, 0.012), (0.024, 0.008), (0.024, -0.006)], centre=(hx, 0.0),
               grain_v=False)
    for y in (-0.110, 0.110):
        door.lathe([(0.006, -0.022), (0.006, 0.022), (0.0, 0.024)], (0.0, y, 0.004), "y", 8)
    door.lathe([(0.009, 0.012), (0.011, 0.016), (0.008, 0.026), (0.0, 0.028)], (hx + 0.138, 0.0, 0.0), "z", 12)   # the catch knob
    part("BoxDoor", "Chute", "BoxDoor", "brass", door, pivot=(-0.150, BOX_DOOR_MIN + 0.180, 0.216), role="moving", smooth=True)
    pane = MB()
    pane.box((hx - 0.128, -0.138, -0.004), (hx + 0.128, 0.138, 0.0))
    part("BoxDoorGlass", "Chute", "BoxDoorGlass", "glass", pane, pivot=(-0.150, BOX_DOOR_MIN + 0.180, 0.216), role="moving")

    test = MB()
    # The test piece comes to rest on the box floor, leaning on the door stile
    # just behind the glass, where it can be seen from the floor of the room.
    pivot_y = BOX_DOOR_MIN + 0.075
    envelope(test, (0.175, 0.014, 0.115), Matrix.Translation((0.0, floor_top - pivot_y + 0.050, 0.002)) @ Matrix.Rotation(math.radians(-52.5), 4, "X"))
    part("TestPiece", "Chute", "TestPiece", "paper", test, pivot=(0.0, pivot_y, 0.168), tint=[1.0, 0.98, 0.90], role="moving")
    index = MB()
    # The lamp index: a slider on the east groove with a pointer across the glass.
    iy = 0.130
    index.box((-0.047, iy - 0.011, -0.0025), (-0.015, iy + 0.011, 0.0100))
    index.prism([(-0.082, iy), (-0.047, iy - 0.005), (-0.047, iy + 0.005)], 0.002, 0.006)
    part("LampIndex", "Chute", "LampIndex", "brass", index, pivot=(0.115, 1.06, 0.140), role="moving")


# --------------------------------------------------------------------------
# Scene, review and export
# --------------------------------------------------------------------------
def material(key, tint):
    name = key if tint is None else "%s_%02x%02x%02x" % (key, *[int(255 * c) for c in tint])
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    node = mat.node_tree.nodes["Principled BSDF"]
    if key == "glass":
        node.inputs["Base Color"].default_value = (0.82, 0.90, 0.88, 1)
        node.inputs["Roughness"].default_value = 0.05
        node.inputs["Transmission Weight"].default_value = 1.0
        return mat
    spec = CATALOG[key]
    node.inputs["Metallic"].default_value = spec["metallic"]
    coord = mat.node_tree.nodes.new("ShaderNodeTexCoord")
    scale = mat.node_tree.nodes.new("ShaderNodeVectorMath")
    scale.operation = "SCALE"
    scale.inputs["Scale"].default_value = 1 / spec["meters_per_tile"]
    mat.node_tree.links.new(coord.outputs["UV"], scale.inputs[0])
    for index, target in ((0, "Base Color"), (1, "Roughness"), (2, "Normal")):
        image = bpy.data.images.load(str(TEXTURES / spec["files"][index]), check_existing=True)
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
        elif index == 0 and tint is not None:
            mix = mat.node_tree.nodes.new("ShaderNodeMixRGB")
            mix.blend_type = "MULTIPLY"
            mix.inputs[0].default_value = 1.0
            mix.inputs[2].default_value = (*[c ** 2.2 for c in tint], 1)
            mat.node_tree.links.new(tex.outputs["Color"], mix.inputs[1])
            mat.node_tree.links.new(mix.outputs[0], node.inputs[target])
        else:
            mat.node_tree.links.new(tex.outputs["Color"], node.inputs[target])
    return mat


REVIEW_AT = {"Bulletin": (-1.9, 1.87, 0.0), "Advert": (0.0, 1.52, 0.0), "Chute": (1.9, 0.0, 0.0)}


def assemble():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    roots, objs = {}, []
    for name, at in REVIEW_AT.items():
        empty = bpy.data.objects.new(name, None)
        empty.location = conv(at)
        bpy.context.collection.objects.link(empty)
        roots[name] = empty
    for row in PARTS:
        mb = row["mb"]
        mesh = bpy.data.meshes.new(row["name"])
        mesh.from_pydata([conv(v) for v in mb.v], [], mb.f)
        layer = mesh.uv_layers.new(name="UVMap")
        k = 0
        for uvs in mb.uv:
            for uv in uvs:
                layer.data[k].uv = uv
                k += 1
        mesh.validate()
        # Triangles only: the exporter cannot compute tangents on an n-gon, and
        # a curled sheet's quads are not planar.
        bm = bmesh.new()
        bm.from_mesh(mesh)
        if row["smooth"]:
            bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-6)
        bmesh.ops.triangulate(bm, faces=bm.faces[:])
        bm.to_mesh(mesh)
        bm.free()
        if row["smooth"]:
            for polygon in mesh.polygons:
                polygon.use_smooth = True
            mesh.set_sharp_from_angle(angle=math.radians(38))
        mesh.update()
        obj = bpy.data.objects.new(row["name"], mesh)
        obj.parent = roots[row["assembly"]]
        obj.location = conv(row["pivot"])
        if row["axis_angle"] is not None:
            angle, axis = row["axis_angle"]
            obj.rotation_mode = "AXIS_ANGLE"
            obj.rotation_axis_angle = (angle, *conv(axis))
        mesh.materials.append(material(row["key"], row["tint"]))
        bpy.context.collection.objects.link(obj)
        row["object"] = obj
        row["triangles"] = len(mesh.polygons)
        objs.append(obj)
    return roots, objs


def review(roots):
    """Review poses: the notices at V1's own layout, the board against a wall."""
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 40
    scene.render.threads_mode = "FIXED"     # leave cores for whoever holds the Godot lane
    scene.render.threads = 8
    scene.render.resolution_x, scene.render.resolution_y = 1280, 960
    temp = []
    world = bpy.data.worlds.new("review")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.20, 0.19, 0.18, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.6
    def plane(name, loc, rot, size, color):
        bpy.ops.mesh.primitive_plane_add(size=1, location=loc, rotation=rot)
        o = bpy.context.object
        o.name = name
        o.scale = size
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*color, 1)
        m.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.9
        o.data.materials.append(m)
        temp.append(o)
    plane("review_wall", (0, CAP_STANDOFF + 0.0005, 1.5), (math.radians(90), 0, 0), (8, 3.0, 1), (0.50, 0.46, 0.38))
    plane("review_floor", (0, -2, 0), (0, 0, 0), (8, 4, 1), (0.22, 0.16, 0.11))
    plane("review_ceiling", (0, -2, CEILING), (math.radians(180), 0, 0), (8, 4, 1), (0.6, 0.58, 0.52))
    # V1's own layout for the eight notices and the wireless copy.
    layout = [(-0.255, 0.175, -0.030, 0.024), (0.010, 0.185, 0.021, 0.024), (0.268, 0.168, -0.014, 0.024), (-0.262, -0.135, 0.034, 0.024),
              (0.004, -0.128, -0.023, 0.024), (0.262, -0.142, 0.017, 0.024), (0.640, 0.095, 0.052, 0.008), (0.655, -0.185, -0.041, 0.008)]
    by_name = {row["name"]: row["object"] for row in PARTS}
    pin, rule = by_name["Bulletin__Pin_ON_brass"], by_name["Bulletin__Rule_ON_paper"]
    for i, (x, y, tilt, depth) in enumerate(layout):
        sheet = by_name["Bulletin__Notice%d_ON_paper" % i]
        sheet.location = conv((x, y, depth))
        sheet.rotation_mode = "AXIS_ANGLE"
        sheet.rotation_axis_angle = (tilt, 0, -1, 0)
        for src, at in ((pin, (0, NOTE_H / 2 - 0.014, 0.0)), (rule, (0, 0, 0))):
            copy = src.copy()
            copy.parent = sheet
            copy.location = conv(at)
            bpy.context.collection.objects.link(copy)
            temp.append(copy)
    wireless = by_name["Bulletin__Wireless_ON_paper"]
    wireless.location = conv((-0.80, 0.0, 0.006))
    copy = pin.copy()
    copy.parent = wireless
    copy.location = conv((0, 0.235, 0))
    bpy.context.collection.objects.link(copy)
    temp.append(copy)
    pin.hide_render = rule.hide_render = True
    for at, energy in (((-1.9, -1.6, 2.6), 160), ((0.0, -1.8, 2.7), 220), ((1.9, -1.4, 2.4), 160)):
        bpy.ops.object.light_add(type="AREA", location=at)
        lamp = bpy.context.object
        lamp.data.energy = energy
        lamp.data.size = 0.6
        lamp.data.color = (1.0, 0.86, 0.66)
        lamp.rotation_euler = (math.radians(38), 0, 0)
        temp.append(lamp)
    bpy.ops.object.camera_add()
    camera = bpy.context.object
    scene.camera = camera
    temp.append(camera)
    (OUT / "review").mkdir(exist_ok=True)
    def shot(name, eye, target, lens=35):
        camera.location = conv(eye)
        camera.data.lens = lens
        direction = conv(target) - conv(eye)
        camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(OUT / "review" / (name + ".png"))
        bpy.ops.render.render(write_still=True)
    shot("set_overview", (0.0, 1.55, 4.6), (0.0, 1.5, 0.0), 30)
    shot("bulletin_front", (-1.95, 1.85, 1.45), (-1.95, 1.87, 0.0), 35)
    shot("bulletin_raking", (-1.2, 1.75, 0.55), (-1.95, 1.90, 0.0), 35)
    shot("advert_front", (0.0, 1.50, 2.45), (0.0, 1.50, 0.0), 35)
    shot("advert_corner", (0.95, 1.05, 0.75), (0.38, 0.86, 0.04), 40)
    shot("advert_engraving", (0.0, 1.58, 0.95), (0.0, 1.58, 0.0), 40)
    shot("chute_front", (1.9, 1.45, 2.3), (1.9, 1.75, 0.0), 30)
    shot("chute_box", (2.45, 1.30, 0.80), (1.9, 1.10, 0.08), 35)
    # The service pose: glass drawn, cover off, tray up, blade in, test piece landed.
    moved = {"Chute__Glass_ON_glass": (0.0, 1.58 + 0.62 * 0.58, 0.124), "Chute__Tray_ON_metal": (0.0, 1.20, 0.155),
             "Chute__Blade_ON_metal": (0.16 - 0.20 * 0.41, 1.30, 0.130), "Chute__Cover_ON_brass": (0.0, 1.14, 0.146)}
    rest = {name: by_name[name].location.copy() for name in moved}
    for name, at in moved.items():
        by_name[name].location = conv(at)
    shot("chute_service", (2.30, 1.42, 0.70), (1.9, 1.28, 0.06), 35)
    for name, at in rest.items():
        by_name[name].location = at
    for o in temp:
        bpy.data.objects.remove(o)
    pin.hide_render = rule.hide_render = False
    for row in PARTS:   # every part back on its exported pivot
        row["object"].location = conv(row["pivot"])
        if row["axis_angle"] is None:
            row["object"].rotation_mode = "XYZ"
            row["object"].rotation_euler = (0, 0, 0)
    scene.camera = None


def export(roots, objs, facts):
    blend = ROOT / "art/blender/lobby_set.blend"
    for image in bpy.data.images:   # the editable source refers to the catalogue maps relatively
        if image.source == "FILE":
            image.filepath = bpy.path.relpath(image.filepath, start=str(ROOT / "art/blender"))
    bpy.ops.wm.save_as_mainfile(filepath=str(blend), check_existing=False)
    bpy.ops.object.select_all(action="DESELECT")
    for o in list(roots.values()) + objs:
        o.select_set(True)
    glb = ROOT / "game/assets/props/lobby_set.glb"
    bpy.ops.export_scene.gltf(filepath=str(glb), export_format="GLB", use_selection=True, export_yup=True, export_apply=True,
                              export_normals=True, export_tangents=True, export_texcoords=True, export_materials="PLACEHOLDER",
                              export_vertex_color="NONE", export_animations=False)
    rows = [{"name": row["name"], "assembly": row["assembly"], "component": row["component"], "material": row["key"],
             "role": row["role"], **({"tint": row["tint"]} if row["tint"] is not None else {})} for row in PARTS]
    data = {"schema_version": 1, "asset": "res://assets/props/lobby_set.glb", "source": "art/blender/scripts/build_lobby_set.py",
            "seed": SEED, "ceiling_m": CEILING, "box_door_min_m": BOX_DOOR_MIN, "advert_wall_standoff_m": CAP_STANDOFF, "triangles": sum(row["triangles"] for row in PARTS),
            "parts": rows}
    (ROOT / "game/data/orison_v2/lobby_set.json").write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8", newline="\n")
    manifest = {"triangles_total": sum(row["triangles"] for row in PARTS),
                "objects": [{"name": row["name"], "triangles": row["triangles"], "pivot": list(row["pivot"])} for row in PARTS], **facts}
    (OUT / "lobby_set_manifest.json").write_text(json.dumps(manifest, indent=1), encoding="utf-8")
    for assembly in REVIEW_AT:
        print("[LOBBY SET] %s: %d objects, %d triangles" % (assembly, sum(1 for r in PARTS if r["assembly"] == assembly),
                                                          sum(r["triangles"] for r in PARTS if r["assembly"] == assembly)))
    print("[LOBBY SET] %d objects, %d triangles" % (len(PARTS), manifest["triangles_total"]))


build_bulletin()
facts = build_advert()
build_chute()
roots, objs = assemble()
if "--no-review" not in sys.argv:
    review(roots)
export(roots, objs, facts)
