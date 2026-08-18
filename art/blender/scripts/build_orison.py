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
import hashlib
import os
import zlib
import sys
import time

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

# ------------------------------------------------------------- textures
# art/textures/catalog_mapping.json is the single mapping authority:
# every semantic catalog material maps to a texture set (or null for the
# specialized shader-only materials: glassish, screen, fx_ao, fx_shadow).
# The build validates coverage in both directions and fails early if a
# mapped set is missing files, so a stale mapping can't ship silently.
TEX_ROOT = os.path.join(ROOT, "art", "textures")
with open(os.path.join(TEX_ROOT, "catalog_mapping.json")) as _f:
    CAT_TEX = json.load(_f)

# Second-generator takes ingest as "<key>_b". They inherit their base's
# blockout numbers rather than carrying their own: an alt is the same
# surface photographed twice, so hand-writing base_color and roughness
# for it would only create a second place to get them wrong. Doing this
# here also keeps the catalog validator happy in both directions without
# gen_layout having to know which slots happen to have an alt.
for _key in list(CAT_TEX):
    if _key[-2:] in ("_b", "_c", "_d") and _key not in MATERIALS:
        _base = _key[:-2]
        if _base in MATERIALS:
            MATERIALS[_key] = dict(MATERIALS[_base])

ROOMS_BY_FLOOR = {f["id"]: f.get("rooms", [])
                  for f in LAYOUT["floors"]}

SHADER_ONLY = {k for k, v in CAT_TEX.items() if v is None}

# declarative UV handling per catalog material:
#   "world"  - dominant-axis world projection (default)
#   "vgrain" - world projection, U/V swapped on vertical faces so brushed
#              grain runs vertically on fronts
#   "unit"   - each quad spans 0..1 (framed artwork, decal quads)
UV_MODE_BY_MAT = {
    "chrome": "vgrain", "metal": "vgrain",
    "art": "unit", "fx_ao": "unit", "fx_shadow": "unit",
    # A television carries one picture across its whole face. On the default
    # world-metre projection a 1.04 m screen sampled 1.04 tiles of the
    # broadcast texture, so every set showed a tiled fragment with the seam
    # running through it rather than the programme.
    "screen": "unit",
    "book_burgundy": "unit", "book_green": "unit", "book_navy": "unit",
    "book_ochre": "unit", "book_teal": "unit", "book_brown": "unit",
    # A rug carries one composition (border, field, medallion) across its
    # whole face; world-metre projection put the medallion at an arbitrary
    # phase and cut it at the binding. Same disease the televisions had.
    "rug_warm": "unit", "rug_cool": "unit", "rug_green": "unit",
}
VGRAIN = {k for k, m in UV_MODE_BY_MAT.items() if m == "vgrain"}

# Surfaces with no grain direction, which can be turned a quarter turn
# per room for extra variety. Anything with boards, tiles, a weave or a
# printed composition is excluded: rotating oak flooring ninety degrees
# lays the boards across the room instead of along it, and that is a
# construction mistake, not variety. The _b alts inherit the property.
ROTATABLE = {
    "concrete", "slab", "plaster", "plaster_stained", "terrazzo",
    "terrazzo_dark", "asphalt", "wet_asphalt", "soil", "char", "soot",
}


# Materials that are ALWAYS sampled by an explicit UV window and must
# never be world-projected, whatever buffer they land in.
EXPLICIT_MATS = {"stair_treads", "art", "sidewalk_haunted"}


def _base_mat(mat):
    return mat[:-2] if mat[-2:] in ("_b", "_c", "_d") else mat


def _rotatable(mat):
    return _base_mat(mat) in ROTATABLE


def _validate_texture_catalog():
    problems = []
    for key in MATERIALS:
        if key not in CAT_TEX:
            problems.append("material %r missing from catalog_mapping"
                            % key)
    for key, rel in CAT_TEX.items():
        if key not in MATERIALS:
            problems.append("mapping key %r not in material_catalog" % key)
        if rel is None:
            continue
        base = os.path.join(TEX_ROOT, *rel.split("/"))
        for fname in ("albedo.png", "roughness.png", "normal.png"):
            if not os.path.exists(os.path.join(base, fname)):
                problems.append("%s: missing %s" % (rel, fname))
        if not (os.path.exists(os.path.join(base, "material.json"))
                or os.path.exists(os.path.join(base, "asset.json"))):
            problems.append("%s: missing metadata" % rel)
    if problems:
        raise SystemExit("texture catalog invalid:\n  "
                         + "\n  ".join(problems))
    mapped = sum(1 for v in CAT_TEX.values() if v)
    print("texture catalog OK: %d mapped, %d shader-only (%s)"
          % (mapped, len(SHADER_ONLY), ", ".join(sorted(SHADER_ONLY))))


_validate_texture_catalog()

_tex_cache = {}


def tex_set(key):
    """Resolve a material's texture file set, or None. Albedo/roughness
    come from the pre-composited overlay variant when one exists (the
    glTF exporter cannot serialize mix-node graphs, so wear is baked by
    tools/compose_overlays.py); normals always come from the clean set."""
    if key in _tex_cache:
        return _tex_cache[key]
    rel = CAT_TEX.get(key)
    if rel is None:
        _tex_cache[key] = None
        return None
    base = os.path.join(TEX_ROOT, *rel.split("/"))
    over = os.path.join(TEX_ROOT, "generated", "_overlaid", key)
    meta_p = os.path.join(base, "material.json")
    if not os.path.exists(meta_p):
        meta_p = os.path.join(base, "asset.json")
    if not os.path.exists(os.path.join(base, "albedo.png")):
        _tex_cache[key] = None
        return None
    with open(meta_p) as f:
        meta = json.load(f)
    src = over if os.path.exists(os.path.join(over, "albedo.png")) else base
    _tex_cache[key] = {
        "albedo": os.path.join(src, "albedo.png"),
        "roughness": os.path.join(src, "roughness.png"),
        "normal": os.path.join(base, "normal.png"),
        "mpt": float(meta.get("meters_per_tile", 2.0)),
        "slug": rel.replace("/", "_"),
    }
    return _tex_cache[key]


def tex_mpt(key):
    ts = tex_set(key)
    return ts["mpt"] if ts else 2.0


def _image(path, slug, kind, srgb):
    """Load a map via a uniquely-named staging copy. The glTF exporter
    names written files after the source basename — every set is
    'albedo.png', so exports would collide across floors with
    order-dependent suffixes. Staging as T_<slug>_<kind>.png makes the
    shared texture dir deterministic and collision-free."""
    import shutil
    stage_dir = os.path.join(TEX_ROOT, "_export")
    os.makedirs(stage_dir, exist_ok=True)
    staged = os.path.join(stage_dir, "T_%s_%s.png" % (slug, kind))
    if (not os.path.exists(staged)
            or os.path.getmtime(staged) < os.path.getmtime(path)):
        shutil.copy2(path, staged)
    img = bpy.data.images.load(staged, check_existing=True)
    img.name = "T_%s_%s" % (slug, kind)
    img.colorspace_settings.name = "sRGB" if srgb else "Non-Color"
    return img


class MeshBuf:
    """Accumulates boxes/prisms, realized as one mesh object at the end."""

    def __init__(self, name, material, uv_mode="world"):
        # Rooms of the floor this buffer belongs to, filled in by the
        # caller. Used only to break up world-projected horizontals.
        self.rooms = []
        self.name = name
        self.material = material
        self.uv_mode = uv_mode   # "world" projection or per-quad "unit"
        self.verts = []
        self.faces = []
        self.face_uvs = []

    def add_quad(self, c0, c1, c2, c3):
        """Single upward-facing quad (contact shadows, AO strips)."""
        b = len(self.verts)
        self.verts += [c0, c1, c2, c3]
        self.faces.append((b, b + 1, b + 2, b + 3))
        self.face_uvs.append(None)

    def add_quad_uv(self, c0, c1, c2, c3, uv0, uv1, uv2, uv3):
        """Quad with explicit atlas coordinates (wall-spanning finishes)."""
        b = len(self.verts)
        self.verts += [c0, c1, c2, c3]
        self.faces.append((b, b + 1, b + 2, b + 3))
        self.face_uvs.append((uv0, uv1, uv2, uv3))

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
        self.face_uvs += [None] * 6

    def add_ramp(self, x0, z0, x1, z1, y0, y1, thickness=0.08, axis="x"):
        """Inclined slab between (a0,z0) and (a1,z1) along `axis`, spanning
        (y0,y1) on the cross axis (named for the historical X case).

        Canonicalized to ascending run with explicit outward winding:
        physics treats a downward-wound "floor" as a wall, which silently
        blocks characters climbing in one direction only.
        """
        if x1 < x0:
            x0, x1 = x1, x0
            z0, z1 = z1, z0

        def v(a, c, z):
            return (a, c, z) if axis == "x" else (c, a, z)

        b = len(self.verts)
        self.verts += [
            v(x0, y0, z0), v(x0, y1, z0), v(x1, y1, z1), v(x1, y0, z1),
            v(x0, y0, z0 - thickness), v(x0, y1, z0 - thickness),
            v(x1, y1, z1 - thickness), v(x1, y0, z1 - thickness)]
        if axis == "x":
            self.faces += [
                (b, b + 3, b + 2, b + 1),          # top (+z)
                (b + 4, b + 5, b + 6, b + 7),      # bottom (-z)
                (b, b + 4, b + 7, b + 3),          # -y side
                (b + 1, b + 2, b + 6, b + 5),      # +y side
                (b, b + 1, b + 5, b + 4),          # low end
                (b + 3, b + 7, b + 6, b + 2)]      # high end
        else:  # mirrored winding keeps the top face up when axes swap
            self.faces += [
                (b, b + 1, b + 2, b + 3),
                (b + 7, b + 6, b + 5, b + 4),
                (b + 3, b + 7, b + 4, b, ),
                (b + 5, b + 6, b + 2, b + 1),
                (b + 4, b + 5, b + 1, b),
                (b + 2, b + 6, b + 7, b + 3)]

    def add_hex(self, corners):
        """Generic hexahedron: 8 corners, bottom ring CCW then top ring
        (same order as add_box). Any proper rotation keeps the winding."""
        b = len(self.verts)
        self.verts += list(corners)
        self.faces += [(b, b + 3, b + 2, b + 1), (b + 4, b + 5, b + 6, b + 7),
                       (b, b + 1, b + 5, b + 4), (b + 1, b + 2, b + 6, b + 5),
                       (b + 2, b + 3, b + 7, b + 6), (b + 3, b, b + 4, b + 7)]

    def add_lathe(self, cx, cy, profile, n=14, sx=1.0, phase=0.0):
        """Surface of revolution about the vertical axis through (cx, cy).
        profile = [(radius, z), ...] bottom-up; radius 0 collapses to an
        apex. sx squashes X for elliptical sections; phase rotates the
        ring seam (useful with sx when the piece itself is rotated)."""
        import math as _m
        rings = []
        for (r, z) in profile:
            if r < 1e-5:
                rings.append(len(self.verts))
                self.verts.append((cx, cy, z))
                continue
            b = len(self.verts)
            rings.append(b)
            for i in range(n):
                a = phase + 2.0 * _m.pi * i / n
                self.verts.append((cx + _m.cos(a) * r * sx,
                                   cy + _m.sin(a) * r, z))
        for k in range(len(profile) - 1):
            r0, r1 = profile[k][0] >= 1e-5, profile[k + 1][0] >= 1e-5
            b0, b1 = rings[k], rings[k + 1]
            for i in range(n):
                j = (i + 1) % n
                if r0 and r1:
                    self.faces.append((b0 + i, b0 + j, b1 + j, b1 + i))
                elif r0:            # collapse up to apex
                    self.faces.append((b0 + i, b0 + j, b1))
                elif r1:            # apex opening downward
                    self.faces.append((b0, b1 + j, b1 + i))
        if profile[0][0] >= 1e-5:   # bottom cap (faces down)
            c = len(self.verts)
            self.verts.append((cx, cy, profile[0][1]))
            for i in range(n):
                self.faces.append((c, rings[0] + (i + 1) % n, rings[0] + i))
        if profile[-1][0] >= 1e-5:  # top cap (faces up)
            c = len(self.verts)
            self.verts.append((cx, cy, profile[-1][1]))
            for i in range(n):
                self.faces.append((c, rings[-1] + i, rings[-1] + (i + 1) % n))

    def add_cyl(self, cx, cy, z0, z1, r0, r1=None, n=12, sx=1.0, phase=0.0):
        self.add_lathe(cx, cy, [(r0, z0), (r0 if r1 is None else r1, z1)],
                       n, sx, phase)

    def add_tbox(self, p0, p1, w, t):
        """Box along the 3D segment p0->p1 (width w, thickness t): legs at
        any splay, braces, rails, curved runs by chaining segments."""
        ax = (p1[0] - p0[0], p1[1] - p0[1], p1[2] - p0[2])
        ln = max(1e-9, (ax[0] ** 2 + ax[1] ** 2 + ax[2] ** 2) ** 0.5)
        a = (ax[0] / ln, ax[1] / ln, ax[2] / ln)
        ref = (0.0, 0.0, 1.0) if abs(a[2]) < 0.985 else (1.0, 0.0, 0.0)
        s = (ref[1] * a[2] - ref[2] * a[1], ref[2] * a[0] - ref[0] * a[2],
             ref[0] * a[1] - ref[1] * a[0])
        sl = max(1e-9, (s[0] ** 2 + s[1] ** 2 + s[2] ** 2) ** 0.5)
        s = (s[0] / sl * w / 2, s[1] / sl * w / 2, s[2] / sl * w / 2)
        u3 = (a[1] * s[2] - a[2] * s[1], a[2] * s[0] - a[0] * s[2],
              a[0] * s[1] - a[1] * s[0])
        ul = max(1e-9, (u3[0] ** 2 + u3[1] ** 2 + u3[2] ** 2) ** 0.5)
        u = (u3[0] / ul * t / 2, u3[1] / ul * t / 2, u3[2] / ul * t / 2)
        corners = []
        for p in (p0, p1):
            for (fs, fu) in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                corners.append((p[0] + fs * s[0] + fu * u[0],
                                p[1] + fs * s[1] + fu * u[1],
                                p[2] + fs * s[2] + fu * u[2]))
        self.add_hex(corners)

    def add_tube(self, p0, p1, r, n=10):
        """Cylinder along an arbitrary 3D segment: pipes, rails, rods."""
        import math as _m
        ax = (p1[0] - p0[0], p1[1] - p0[1], p1[2] - p0[2])
        ln = max(1e-9, (ax[0] ** 2 + ax[1] ** 2 + ax[2] ** 2) ** 0.5)
        a = (ax[0] / ln, ax[1] / ln, ax[2] / ln)
        ref = (0.0, 0.0, 1.0) if abs(a[2]) < 0.985 else (1.0, 0.0, 0.0)
        s = (ref[1] * a[2] - ref[2] * a[1], ref[2] * a[0] - ref[0] * a[2],
             ref[0] * a[1] - ref[1] * a[0])
        sl = max(1e-9, (s[0] ** 2 + s[1] ** 2 + s[2] ** 2) ** 0.5)
        s = (s[0] / sl, s[1] / sl, s[2] / sl)
        u = (a[1] * s[2] - a[2] * s[1], a[2] * s[0] - a[0] * s[2],
             a[0] * s[1] - a[1] * s[0])
        b0 = len(self.verts)
        for p in (p0, p1):
            for i in range(n):
                t = 2.0 * _m.pi * i / n
                self.verts.append((
                    p[0] + (_m.cos(t) * s[0] + _m.sin(t) * u[0]) * r,
                    p[1] + (_m.cos(t) * s[1] + _m.sin(t) * u[1]) * r,
                    p[2] + (_m.cos(t) * s[2] + _m.sin(t) * u[2]) * r))
        b1 = b0 + n
        for i in range(n):
            j = (i + 1) % n
            self.faces.append((b0 + i, b0 + j, b1 + j, b1 + i))
        c0 = len(self.verts)
        self.verts.append(tuple(p0))
        c1 = len(self.verts)
        self.verts.append(tuple(p1))
        for i in range(n):
            j = (i + 1) % n
            self.faces.append((c0, b0 + j, b0 + i))
            self.faces.append((c1, b1 + i, b1 + j))

    def realize(self, collection):
        if not self.verts:
            return None
        me = bpy.data.meshes.new(self.name)
        me.from_pydata(self.verts, [], self.faces)
        me.validate()
        me.update()
        self._project_uvs(me)
        me.materials.append(get_material(self.material))
        obj = bpy.data.objects.new(self.name, me)
        collection.objects.link(obj)
        return obj

    def _project_uvs(self, me):
        """Deterministic world-scale box projection, per polygon loop:
        the dominant component of each face normal picks the projection
        plane, world meters divide by the set's meters_per_tile. World
        space keeps oak boards continuous across a room, keeps fabric
        from twisting between adjacent faces, and survives the glTF trip
        (TEXCOORD_0) untouched. Brushed metals swap U/V on vertical
        faces so the grain falls vertically on fronts."""
        uv = me.uv_layers.new(name="UVMap")
        if self.uv_mode == "explicit":
            for poly in me.polygons:
                coords = self.face_uvs[poly.index]
                if coords is None:
                    coords = ((0, 0), (1, 0), (1, 1), (0, 1))
                for j, li in enumerate(poly.loop_indices):
                    uv.data[li].uv = coords[j]
            return
        if self.uv_mode == "unit":   # decal quads: corners span 0..1
            # Derived from each vertex's POSITION within its own face, not
            # from its loop index. The index form assigned the four corners
            # as k % 4, which is only correct while the face is still a
            # quad — and these meshes are triangulated, so every triangle
            # took three of the four corners and the texture landed on a
            # fraction of the surface. A television showed a quarter of its
            # own picture.
            #
            # Per-polygon bounds are safe here because splitting a rectangle
            # along its diagonal leaves both triangles with the rectangle's
            # own axis-aligned bounds, so each half still resolves the full
            # 0..1 range.
            for poly in me.polygons:
                n = poly.normal
                axis = max(range(3), key=lambda i: abs(n[i]))
                ui, vi = ((1, 2), (0, 2), (0, 1))[axis]
                pts = [me.vertices[me.loops[li].vertex_index].co
                       for li in poly.loop_indices]
                u0 = min(p[ui] for p in pts)
                v0 = min(p[vi] for p in pts)
                du = max(p[ui] for p in pts) - u0
                dv = max(p[vi] for p in pts) - v0
                du = du if abs(du) > 1e-9 else 1.0
                dv = dv if abs(dv) > 1e-9 else 1.0
                for li in poly.loop_indices:
                    p = me.vertices[me.loops[li].vertex_index].co
                    uv.data[li].uv = ((p[ui] - u0) / du, (p[vi] - v0) / dv)
            return
        tile = tex_mpt(self.material)
        inv = 1.0 / tile
        vgrain = self.material in VGRAIN
        # Per-room shift for horizontal surfaces.
        #
        # World projection is right for continuity - it keeps oak boards
        # running across a room and stops fabric twisting between faces -
        # but it also means every room on a floor samples ONE continuous
        # field. So identical repeats line up across rooms: the same
        # stain sits at the same place relative to the same doorway in
        # eighteen apartments, which is the one artefact that reads as
        # software rather than as a building.
        #
        # Each room's floor and ceiling therefore get their own offset,
        # and non-directional surfaces additionally get a quarter turn.
        # Only HORIZONTALS are shifted: a wall stands between two rooms,
        # so shifting it per room would put a hard seam down the middle
        # of every partition. Floors and ceilings belong to exactly one
        # room and can be moved freely.
        rot_ok = _rotatable(self.material)
        shifts = {}

        def _shift_for(cx, cy):
            for r in self.rooms:
                x0, y0, x1, y1 = r["rect"]
                if not (min(x0, x1) <= cx <= max(x0, x1)
                        and min(y0, y1) <= cy <= max(y0, y1)):
                    continue
                rid = r["id"]
                if rid not in shifts:
                    # crc32, not hash(): Python salts string hashing per
                    # process, so hash() would rebuild the same layout
                    # differently every run.
                    hv = zlib.crc32(rid.encode("utf-8"))
                    shifts[rid] = (
                        ((hv & 0xFF) / 255.0) * tile,
                        (((hv >> 8) & 0xFF) / 255.0) * tile,
                        ((hv >> 16) & 3) if rot_ok else 0,
                        (min(x0, x1) + max(x0, x1)) * 0.5,
                        (min(y0, y1) + max(y0, y1)) * 0.5)
                return shifts[rid]
            return None

        for poly in me.polygons:
            n = poly.normal
            ax, ay, az = abs(n.x), abs(n.y), abs(n.z)
            horizontal = az >= ax and az >= ay
            sh = None
            if horizontal and self.rooms:
                c = poly.center
                sh = _shift_for(c[0], c[1])
            for li in poly.loop_indices:
                co = me.vertices[me.loops[li].vertex_index].co
                if horizontal:                 # floor / ceiling
                    u, v = co.x, co.y
                    if sh is not None:
                        ox, oy, turns, rcx, rcy = sh
                        du, dv = u - rcx, v - rcy
                        for _ in range(turns):
                            du, dv = -dv, du
                        u, v = rcx + du + ox, rcy + dv + oy
                elif ax >= ay:                 # X-facing
                    u, v = co.y, co.z
                    if vgrain:
                        u, v = v, u
                else:                          # Y-facing
                    u, v = co.x, co.z
                    if vgrain:
                        u, v = v, u
                uv.data[li].uv = (u * inv, v * inv)


_mat_cache = {}


FX_TEX = {
    "fx_shadow": "generated/fx/shadow_blob.png",
    "fx_ao": "generated/fx/ao_strip.png",
    "fx_traffic": "generated/fx/wear_traffic.png",
    "fx_scuff": "generated/fx/wear_scuff.png",
    "fx_drip": "generated/fx/wear_drip.png",
    "fx_grease": "generated/fx/wear_grease.png",
    "fx_burn": "generated/fx/wear_burn.png",
    "fx_patch": "generated/fx/age_patch.png",
    "fx_damp": "generated/fx/age_damp.png",
    # Approved landing soffit plate. Full-bleed opacity means its boundary is
    # the real slab edge; there is no rectangular decal island.
    "fx_ceiling_soffit_failed": "ai_sources/ceiling_soffit_failed_v1.png",
}


# Materials that genuinely face both ways. Everything else is a solid
# surface and gets backface culling, without which "single-sided
# geometry" is a fiction: the floor quads and ceiling quads would still
# render from behind, and the atrium would show terrazzo for a soffit.
TWO_SIDED = {
    "glassish",          # a window is looked through from both sides
    "screen", "art",     # thin quads
    "plant", "linen",    # cross-planes and hanging cloth
    "fx_ao", "fx_shadow", "fx_traffic", "fx_scuff", "fx_drip",
    "fx_grease", "fx_burn", "fx_patch", "fx_damp",
}


def get_material(key):
    """Catalog material -> Blender Principled node tree. Textured sets
    wire albedo (sRGB), roughness (non-color) and a tangent normal map at
    conservative strength — a plain pattern the glTF exporter reduces
    cleanly. Catalog color/roughness stay as the untextured fallback and
    metallic always comes from the catalog."""
    if key in _mat_cache:
        return _mat_cache[key]
    spec = MATERIALS.get(key, MATERIALS["plaster"])
    mat = bpy.data.materials.new("M_%s" % key)
    # Blender 5 materials are node-backed by default and deprecate assigning
    # use_nodes; 4.x still requires the opt-in.
    if bpy.app.version < (5, 0, 0):
        mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = spec["base_color"]
    bsdf.inputs["Roughness"].default_value = spec.get("roughness", 0.7)
    bsdf.inputs["Metallic"].default_value = spec.get("metallic", 0.0)
    if key.startswith("wallfinish_"):
        wall_id = key[len("wallfinish_"):]
        base = os.path.join(TEX_ROOT, "wall_finishes", wall_id)
        for kind, srgb, y in (("albedo", True, 300),
                              ("roughness", False, 20),
                              ("normal", False, -260)):
            node = nt.nodes.new("ShaderNodeTexImage")
            node.name = node.label = kind
            node.image = _image(os.path.join(base, kind + ".png"),
                                "wallfinish_%s" % wall_id, kind, srgb)
            node.location = (-420, y)
            if kind == "albedo":
                nt.links.new(node.outputs["Color"], bsdf.inputs["Base Color"])
                # The alpha channel IS the finish-survival mask: where the
                # century stripped the plaster, the quad vanishes and the
                # masonry behind it shows. Clip, not blend — torn plaster
                # has an edge, not a fade.
                nt.links.new(node.outputs["Alpha"], bsdf.inputs["Alpha"])
            elif kind == "roughness":
                nt.links.new(node.outputs["Color"], bsdf.inputs["Roughness"])
            else:
                nrm = nt.nodes.new("ShaderNodeNormalMap")
                nrm.inputs["Strength"].default_value = 0.42
                nrm.location = (-160, -260)
                nt.links.new(node.outputs["Color"], nrm.inputs["Color"])
                nt.links.new(nrm.outputs["Normal"], bsdf.inputs["Normal"])
        if hasattr(mat, "surface_render_method"):
            mat.surface_render_method = "DITHERED"
        elif hasattr(mat, "blend_method"):
            mat.blend_method = "CLIP"
        if hasattr(mat, "alpha_threshold"):
            mat.alpha_threshold = 0.5
        mat.use_backface_culling = key not in TWO_SIDED             and not key.startswith("fx_")
        _mat_cache[key] = mat
        return mat
    if key == "glassish":
        # Architectural glass, and it has to survive the trip.
        #
        # This used to ask for physically-correct glass: transmission
        # 0.72, IOR 1.46, dithered blending. The exporter faithfully
        # wrote KHR_materials_transmission into the glTF and the game
        # renders on gl_compatibility, which does not implement that
        # extension. The result was the exact failure the old comment
        # here claimed to be fixing - from the street every window was a
        # flat blue-grey panel with no room behind it, and it changed
        # with the viewing angle, which is what gave it away.
        #
        # So: no transmission extension, no refraction. Just a lightly
        # tinted, mostly clear alpha-blended pane. Less physical, and it
        # is the version that actually looks like glass on the target
        # renderer - which is the only place anyone sees it.
        bsdf.inputs["Base Color"].default_value = (0.76, 0.85, 0.89, 1.0)
        bsdf.inputs["Roughness"].default_value = 0.06
        if "Transmission Weight" in bsdf.inputs:
            bsdf.inputs["Transmission Weight"].default_value = 0.0
        bsdf.inputs["Alpha"].default_value = 0.16

        # THE TWO MAPS THAT MAKE OLD GLASS LOOK OLD.
        #
        # Colour and alpha above stay exactly as tuned -- that is the part
        # that survives gl_compatibility and it is not to be relitigated here.
        # What is added is the surface itself.
        #
        # Float glass did not exist until 1959, so every pane in this building
        # is drawn or cylinder glass: faint vertical draw lines from the ribbon
        # being pulled, and a slow waviness from uneven cooling. You never see
        # the ripple, you see what it does to the REFLECTION as you walk past,
        # and that motion is most of what reads as a period window. A roughness
        # value cannot do it; only a normal can.
        #
        # The roughness map then puts the dirt where dirt actually goes -- the
        # perimeter and the corners, against the putty line, where nobody
        # wipes. A single 0.06 across the sheet says "cleaned this morning,
        # edge to edge", which no window in the Orison has been.
        g_base = os.path.join(TEX_ROOT, "generated", "glass")
        g_rough = os.path.join(g_base, "roughness.png")
        g_normal = os.path.join(g_base, "normal.png")
        if os.path.exists(g_rough) and os.path.exists(g_normal):
            gr = nt.nodes.new("ShaderNodeTexImage")
            gr.name = gr.label = "roughness"
            gr.image = _image(g_rough, "glass", "rough", False)
            gr.location = (-420, 20)
            nt.links.new(gr.outputs["Color"], bsdf.inputs["Roughness"])
            gn_tex = nt.nodes.new("ShaderNodeTexImage")
            gn_tex.name = gn_tex.label = "normal"
            gn_tex.image = _image(g_normal, "glass", "normal", False)
            gn_tex.location = (-420, -260)
            gn = nt.nodes.new("ShaderNodeNormalMap")
            # Stronger than the decals' 0.28 and weaker than a wall's 0.42.
            # Glass has no texture to speak of, but the deviation it does have
            # is the whole point, and reflections amplify it.
            gn.inputs["Strength"].default_value = 0.55
            gn.location = (-160, -260)
            nt.links.new(gn_tex.outputs["Color"], gn.inputs["Color"])
            nt.links.new(gn.outputs["Normal"], bsdf.inputs["Normal"])
        if hasattr(mat, "surface_render_method"):
            mat.surface_render_method = "BLENDED"
        elif hasattr(mat, "blend_method"):
            mat.blend_method = "BLEND"
        if hasattr(mat, "use_transparency_overlap"):
            mat.use_transparency_overlap = False
    if key in FX_TEX:
        rel = FX_TEX[key]
        img = _image(os.path.join(TEX_ROOT, *rel.split("/")), "fx", key, True)
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = img
        tex.location = (-420, 300)
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        nt.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])

        # A DEPOSIT IS MATTER; A SHADOW IS NOT.
        #
        # This branch used to pin Roughness to 1.0 and Specular to 0.0 for
        # every decal, which made all nine of them pure darkening: a grease
        # stain could not be glossier than the wall behind it, and a plaster
        # repair could not be chalkier. That is most of why they read as
        # stickers rather than as dirt. Roughness is the channel that says
        # "wet", and it was nailed shut.
        #
        # build_fx_decals.py now emits `_rough` and `_normal` beside the seven
        # plates that are actually substances. `ao_strip` and `shadow_blob`
        # deliberately have none -- they are fake lighting, and a shadow that
        # changed how the floor reflected would give itself away instantly --
        # so they fall through to the old flat behaviour, which is correct for
        # them and only for them.
        stem = rel.rsplit(".", 1)[0]
        r_rel, n_rel = stem + "_rough.png", stem + "_normal.png"
        r_abs = os.path.join(TEX_ROOT, *r_rel.split("/"))
        n_abs = os.path.join(TEX_ROOT, *n_rel.split("/"))
        if os.path.exists(r_abs) and os.path.exists(n_abs):
            rough = nt.nodes.new("ShaderNodeTexImage")
            rough.name = rough.label = "roughness"
            rough.image = _image(r_abs, "fx", key + "_rough", False)
            rough.location = (-420, 20)
            nt.links.new(rough.outputs["Color"], bsdf.inputs["Roughness"])
            nrm_tex = nt.nodes.new("ShaderNodeTexImage")
            nrm_tex.name = nrm_tex.label = "normal"
            nrm_tex.image = _image(n_abs, "fx", key + "_normal", False)
            nrm_tex.location = (-420, -260)
            nrm = nt.nodes.new("ShaderNodeNormalMap")
            # Held well below the surface maps' own 0.42: a decal's relief has
            # to be felt at the stain's edge without embossing a rectangle
            # where the quad ends.
            nrm.inputs["Strength"].default_value = 0.28
            nrm.location = (-160, -260)
            nt.links.new(nrm_tex.outputs["Color"], nrm.inputs["Color"])
            nt.links.new(nrm.outputs["Normal"], bsdf.inputs["Normal"])
            # Specular comes back, or the roughness map has nothing to modulate.
            bsdf.inputs["Specular IOR Level"].default_value = 0.5
        else:
            bsdf.inputs["Roughness"].default_value = 1.0
            bsdf.inputs["Specular IOR Level"].default_value = 0.0
        mat.blend_method = "BLEND"
        mat.use_backface_culling = key not in TWO_SIDED             and not key.startswith("fx_")
        _mat_cache[key] = mat
        return mat
    ts = tex_set(key)
    if ts:
        alb = nt.nodes.new("ShaderNodeTexImage")
        alb.name = alb.label = "albedo"
        alb.image = _image(ts["albedo"], ts["slug"] +
                           ("_worn_%s" % key if "_overlaid" in ts["albedo"]
                            else ""), "albedo", True)
        alb.location = (-420, 300)
        nt.links.new(alb.outputs["Color"], bsdf.inputs["Base Color"])
        rough = nt.nodes.new("ShaderNodeTexImage")
        rough.name = rough.label = "roughness"
        rough.image = _image(ts["roughness"], ts["slug"] +
                             ("_worn_%s" % key if "_overlaid"
                              in ts["roughness"] else ""), "rough", False)
        rough.location = (-420, 20)
        nt.links.new(rough.outputs["Color"], bsdf.inputs["Roughness"])
        nrm_tex = nt.nodes.new("ShaderNodeTexImage")
        nrm_tex.name = nrm_tex.label = "normal"
        nrm_tex.image = _image(ts["normal"], ts["slug"], "normal", False)
        nrm_tex.location = (-420, -260)
        nrm = nt.nodes.new("ShaderNodeNormalMap")
        nrm.inputs["Strength"].default_value = 0.35
        nrm.location = (-160, -260)
        nt.links.new(nrm_tex.outputs["Color"], nrm.inputs["Color"])
        nt.links.new(nrm.outputs["Normal"], bsdf.inputs["Normal"])
    mat.use_backface_culling = key not in TWO_SIDED and not key.startswith("fx_")
    _mat_cache[key] = mat
    return mat


def furniture_batch_prefix(batch_key):
    """Turn an authored batch owner into a stable exported mesh prefix.

    Shop batches predate every other local furniture owner and therefore used
    to be unconditionally named ``retail_*``.  Transit/site architecture now
    needs the same bounded AABB for GL Compatibility light selection without
    lying about ownership in the glTF node name.
    """
    safe_batch = "".join(c if c.isalnum() else "_"
                         for c in str(batch_key)).strip("_")
    if safe_batch.startswith(("transit_", "site_")):
        return safe_batch
    return "retail_%s" % safe_batch


# ================================================================ assets
# Parametric furnishing library. Every piece is an ORIGINAL design in the
# spirit of an iconic typology (documented in art/docs/furniture_references
# .md): bentwood cafe chairs, tulip-style pedestal tables, spool beds,
# Frankfurt-kitchen cabinetry, rounded-shoulder 1950s refrigerators,
# enamel ranges, bakelite toggle switches. Local space: origin at the
# footprint center on the floor, front toward +Y; `yaw` rotates CCW.

import math


class Frame:
    """Placement frame: local -> world, one visual buffer per material,
    plus a coarse invisible collision hull per assembly."""

    def __init__(self, get_buf, hull_buf, ox, oy, oz, yaw_deg, finish=0.0):
        self.g = get_buf
        self.hb = hull_buf
        self.o = (ox, oy, oz)
        # Floor finish under this assembly, so its baked contact shadow
        # lands on the floor rather than hovering over it. Zero for
        # anything standing on a shelf or counter: there the shadow is
        # already relative to the surface it sits on.
        self.finish = finish
        a = math.radians(yaw_deg)
        self.c, self.s = math.cos(a), math.sin(a)
        self.yaw = a

    def pt(self, x, y, z):
        return (self.o[0] + x * self.c - y * self.s,
                self.o[1] + x * self.s + y * self.c, self.o[2] + z)

    def box(self, mat, x0, y0, z0, x1, y1, z1):
        cs = [self.pt(x0, y0, z0), self.pt(x1, y0, z0), self.pt(x1, y1, z0),
              self.pt(x0, y1, z0), self.pt(x0, y0, z1), self.pt(x1, y0, z1),
              self.pt(x1, y1, z1), self.pt(x0, y1, z1)]
        self.g(mat).add_hex(cs)

    def lathe(self, mat, cx, cy, profile, n=14, sx=1.0):
        p = self.pt(cx, cy, 0.0)
        prof = [(r, self.o[2] + z) for (r, z) in profile]
        self.g(mat).add_lathe(p[0], p[1], prof, n, sx, self.yaw)

    def cyl(self, mat, cx, cy, z0, z1, r0, r1=None, n=12, sx=1.0):
        self.lathe(mat, cx, cy, [(r0, z0), (r0 if r1 is None else r1, z1)],
                   n, sx)

    def tube(self, mat, p0, p1, r, n=10):
        self.g(mat).add_tube(self.pt(*p0), self.pt(*p1), r, n)

    def tbox(self, mat, p0, p1, w, t):
        self.g(mat).add_tbox(self.pt(*p0), self.pt(*p1), w, t)

    def hull(self, x0, y0, z0, x1, y1, z1):
        cs = [self.pt(x0, y0, z0), self.pt(x1, y0, z0), self.pt(x1, y1, z0),
              self.pt(x0, y1, z0), self.pt(x0, y0, z1), self.pt(x1, y0, z1),
              self.pt(x1, y1, z1), self.pt(x0, y1, z1)]
        self.hb().add_hex(cs)
        # baked contact shadow: the cheapest convincing ray of them all
        mx = (x1 - x0) * 0.08 + 0.04
        my = (y1 - y0) * 0.08 + 0.04
        zq = self.finish + 0.004  # just clear of the finish it sits on
        self.g("fx_shadow").add_quad(
            self.pt(x0 - mx, y0 - my, zq), self.pt(x1 + mx, y0 - my, zq),
            self.pt(x1 + mx, y1 + my, zq), self.pt(x0 - mx, y1 + my, zq))


def _jit(seed, k, lo, hi):
    """Deterministic jitter from the piece's id string."""
    h = (hash_str(seed) * 31 + k * 977) % 1000 / 999.0
    return lo + (hi - lo) * h


def hash_str(s):
    h = 0
    for ch in str(s):
        h = (h * 131 + ord(ch)) % 100003
    return h


def asm_sofa(F, p):
    L = p.get("L", 1.95)
    d, mat = 0.88, p.get("mat", "fabric_warm")
    leg = p.get("leg_mat", "wood_dark")
    for lx in (-L / 2 + 0.10, L / 2 - 0.10):
        for ly in (-d / 2 + 0.09, d / 2 - 0.09):
            F.cyl(leg, lx, ly, 0.0, 0.15, 0.030, 0.019, 8)
    F.box(mat, -L / 2 - 0.02, -d / 2, 0.15, L / 2 + 0.02, d / 2, 0.31)
    nc = 2 if L > 1.4 else 1
    cw = (L - 0.04 * (nc + 1)) / nc
    for i in range(nc):
        x0 = -L / 2 + 0.04 + i * (cw + 0.04)
        F.box(mat, x0, -d / 2 + 0.16, 0.31, x0 + cw, d / 2 - 0.03, 0.455)
        F.box(mat, x0 + 0.01, d / 2 - 0.055, 0.42, x0 + cw - 0.01,
              d / 2 - 0.015, 0.47)          # piped front roll
        F.box(mat, x0, -d / 2 + 0.10, 0.455, x0 + cw, -d / 2 + 0.30, 0.82)
        F.box(mat, x0 + 0.015, -d / 2 + 0.08, 0.60, x0 + cw - 0.015,
              -d / 2 + 0.115, 0.79)         # back piping line
    for sx_ in (-1, 1):
        F.box(mat, sx_ * L / 2 + (0.02 if sx_ > 0 else -0.18),
              -d / 2, 0.15, sx_ * L / 2 + (0.18 if sx_ > 0 else -0.02),
              d / 2, 0.62)
    # Piping and stitch breaks keep the cushions from reading as boxes.
    seam = "linen"
    for i in range(nc):
        x0 = -L / 2 + 0.04 + i * (cw + 0.04)
        for sx_ in (x0 + 0.018, x0 + cw - 0.018):
            F.tube(seam, (sx_, -d / 2 + 0.17, 0.458),
                   (sx_, d / 2 - 0.04, 0.458), 0.006, 6)
        for k in range(5):
            sy = -d / 2 + 0.20 + k * (d - 0.28) / 4.0
            F.box(seam, x0 + cw / 2 - 0.018, sy, 0.458,
                  x0 + cw / 2 + 0.018, sy + 0.012, 0.463)
    F.hull(-L / 2 - 0.18, -d / 2, 0.0, L / 2 + 0.18, d / 2, 0.8)


def asm_chair(F, p):
    """Viennese-cafe spirit: round seat, splayed legs, steamed hoop back."""
    wood = p.get("mat", case_wood(p))
    F.cyl(wood, 0, 0, 0.44, 0.478, 0.215, 0.215, 14)
    F.lathe(wood, 0, 0, [(0.20, 0.415), (0.215, 0.44)], 14)  # seat rim
    for fx, fy in ((-0.14, 0.12), (0.14, 0.12), (-0.14, -0.11),
                   (0.14, -0.11)):
        F.tbox(wood, (fx * 1.30, fy * 1.45, 0.0), (fx, fy, 0.44),
               0.030, 0.030)
    for s in (-1, 1):
        F.tbox(wood, (s * 0.15, -0.155, 0.45), (s * 0.135, -0.205, 0.72),
               0.028, 0.028)
        F.tbox(wood, (s * 0.135, -0.205, 0.72), (s * 0.095, -0.225, 0.93),
               0.026, 0.026)
    F.tube(wood, (-0.095, -0.225, 0.93), (0.0, -0.245, 0.965), 0.015, 8)
    F.tube(wood, (0.0, -0.245, 0.965), (0.095, -0.225, 0.93), 0.015, 8)
    F.tube(wood, (-0.10, -0.205, 0.70), (0.0, -0.225, 0.725), 0.011, 8)
    F.tube(wood, (0.0, -0.225, 0.725), (0.10, -0.205, 0.70), 0.011, 8)
    F.hull(-0.22, -0.25, 0.0, 0.22, 0.22, 0.95)


def asm_table_round(F, p):
    """Pedestal-table spirit: one sculpted stem, no leg forest."""
    top = p.get("mat", "floor_oak")
    F.lathe("trim", 0, 0, [(0.27, 0.0), (0.24, 0.02), (0.075, 0.10),
                           (0.042, 0.42), (0.05, 0.64), (0.11, 0.685)], 16)
    F.lathe(top, 0, 0, [(0.50, 0.685), (0.55, 0.70), (0.55, 0.725),
                        (0.50, 0.735), (0.001, 0.735)], 18)
    F.hull(-0.55, -0.55, 0.0, 0.55, 0.55, 0.74)


def asm_table_rect(F, p):
    L, W = p.get("L", 1.20), p.get("W", 0.80)
    wood = p.get("mat", "floor_oak")
    F.box(wood, -L / 2, -W / 2, 0.70, L / 2, W / 2, 0.745)
    F.box("wood_dark", -L / 2 + 0.07, -W / 2 + 0.07, 0.62, L / 2 - 0.07,
          W / 2 - 0.07, 0.70)
    for lx in (-L / 2 + 0.10, L / 2 - 0.10):
        for ly in (-W / 2 + 0.10, W / 2 - 0.10):
            F.lathe("wood_dark", lx, ly,
                    [(0.034, 0.0), (0.026, 0.10), (0.040, 0.155),
                     (0.024, 0.48), (0.032, 0.60), (0.038, 0.62)], 10)
    F.hull(-L / 2, -W / 2, 0.0, L / 2, W / 2, 0.75)


def asm_coffee(F, p):
    """Biomorphic-studio spirit: elliptical glass over two keeled fins."""
    F.tbox("wood_dark", (-0.30, -0.10, 0.0), (0.18, 0.13, 0.345),
           0.30, 0.045)
    F.tbox("wood_dark", (0.28, -0.07, 0.0), (-0.14, 0.15, 0.345),
           0.26, 0.045)
    F.cyl("glassish", 0, 0, 0.35, 0.365, 0.55, 0.55, 18, 0.62)
    F.hull(-0.55, -0.36, 0.0, 0.55, 0.36, 0.37)


def asm_nightstand(F, p):
    wood = p.get("mat", case_wood(p))
    F.box(wood, -0.225, -0.21, 0.12, 0.225, 0.21, 0.52)
    F.box(wood, -0.20, 0.212, 0.30, 0.20, 0.225, 0.47)   # drawer face
    F.cyl("brass", 0.0, 0.23, 0.385, 0.395, 0.016, 0.010, 8)
    F.box("paper", -0.14, -0.10, 0.52, 0.02, 0.01, 0.555)   # bedside book
    F.cyl("glassish", 0.10, 0.06, 0.52, 0.625, 0.035, 0.030, 8)
    for lx, ly in ((-0.17, -0.15), (0.17, -0.15), (-0.17, 0.15),
                   (0.17, 0.15)):
        F.cyl(wood, lx, ly, 0.0, 0.12, 0.020, 0.014, 8)
    F.hull(-0.23, -0.22, 0.0, 0.23, 0.23, 0.53)


def asm_bed(F, p):
    """Spool-bed spirit: turned posts, spindle head, deep bedding."""
    W, L = p.get("W", 1.50), p.get("L", 2.05)
    blanket = p.get("blanket", "fabric_warm")
    post = [(0.034, 0.0), (0.026, 0.22), (0.042, 0.27), (0.028, 0.62),
            (0.044, 0.70), (0.030, 0.86), (0.042, 0.92), (0.001, 0.99)]
    foot = [(0.034, 0.0), (0.026, 0.20), (0.042, 0.25), (0.028, 0.44),
            (0.040, 0.50), (0.001, 0.56)]
    for sx_ in (-1, 1):
        F.lathe(case_wood(p), sx_ * (W / 2 - 0.05), -L / 2 + 0.05, post, 10)
        F.lathe(case_wood(p), sx_ * (W / 2 - 0.05), L / 2 - 0.05, foot, 10)
        F.box(case_wood(p), sx_ * (W / 2 - 0.03) - 0.012, -L / 2 + 0.05,
              0.24, sx_ * (W / 2 - 0.03) + 0.012, L / 2 - 0.05, 0.33)
    F.box(case_wood(p), -W / 2 + 0.05, -L / 2 + 0.028, 0.78, W / 2 - 0.05,
          -L / 2 + 0.072, 0.86)             # head rail
    for i in range(5):
        sxp = -W / 2 + 0.16 + i * (W - 0.32) / 4.0
        F.cyl(case_wood(p), sxp, -L / 2 + 0.05, 0.33, 0.78, 0.014, 0.014, 8)
    F.box(case_wood(p), -W / 2 + 0.05, L / 2 - 0.068, 0.40, W / 2 - 0.05,
          L / 2 - 0.028, 0.47)              # foot rail
    F.box("linen", -W / 2 + 0.06, -L / 2 + 0.08, 0.33, W / 2 - 0.06,
          L / 2 - 0.08, 0.50)
    F.box(blanket, -W / 2 + 0.035, -L / 2 + 0.68, 0.50, W / 2 - 0.035,
          L / 2 - 0.045, 0.565)
    F.box(blanket, -W / 2 + 0.035, -L / 2 + 0.68, 0.44, W / 2 - 0.035,
          -L / 2 + 0.80, 0.575)             # folded turnback
    for sx_ in (-1, 1):
        F.lathe("paper", sx_ * 0.30, -L / 2 + 0.33,
                [(0.001, 0.50), (0.19, 0.525), (0.21, 0.56), (0.14, 0.60),
                 (0.001, 0.615)], 10, 1.55)
    F.hull(-W / 2, -L / 2, 0.0, W / 2, L / 2, 0.9)


def case_wood(p):
    """Walnut or quartered oak, decided per unit.

    Every bed, wardrobe, nightstand and chair in the building was the
    same walnut, so eighteen flats read as furnished from one catalogue
    page on one afternoon. Both woods are correct for this class and
    period and these tenants did not shop together.

    Keyed on the unit prefix of the item's id, not on the item, so a
    bedroom suite agrees with itself: a bed, its nightstand and the
    wardrobe beside it are one purchase, not three coincidences.
    """
    if p.get("case_wood") in ("oak_quartered", "wood_dark"):
        return p["case_wood"]
    ident = str(p.get("id", ""))
    unit = ident.split("_", 1)[0] if "_" in ident else ident
    return "oak_quartered" if zlib.crc32(unit.encode()) & 1 else "wood_dark"


def asm_wardrobe(F, p):
    """Armoire spirit: plinth, cabinet, cornice and resident garments.

    The two framed leaves and their knobs are runtime-owned moving parts. They
    must not also survive in these merged floor buffers: duplicating them here
    makes an apparently opening door leave a second closed door behind.
    """
    W, d = p.get("W", 1.30), 0.62
    wood = case_wood(p)
    F.box(wood, -W / 2, -d / 2, 0.0, W / 2, d / 2, 0.07)
    # A real hollow carcass, not the old solid block revealed when the doors
    # move: back, two cheeks, bottom and top remain static and batch cleanly.
    F.box(wood, -W / 2 + 0.02, -d / 2 + 0.02, 0.07,
          W / 2 - 0.02, -d / 2 + 0.055, 1.86)
    for sx_ in (-1, 1):
        x0 = -W / 2 + 0.02 if sx_ < 0 else W / 2 - 0.07
        F.box(wood, x0, -d / 2 + 0.02, 0.07, x0 + 0.05,
              d / 2 - 0.03, 1.86)
    F.box(wood, -W / 2 + 0.02, -d / 2 + 0.02, 0.07,
          W / 2 - 0.02, d / 2 - 0.03, 0.12)
    F.box(wood, -W / 2 + 0.02, -d / 2 + 0.02, 1.81,
          W / 2 - 0.02, d / 2 - 0.03, 1.86)
    F.box(wood, -0.018, -d / 2 + 0.04, 0.12, 0.018,
          d / 2 - 0.05, 1.81)
    F.box(wood, -W / 2 + 0.055, -d / 2 + 0.055, 0.43,
          W / 2 - 0.055, d / 2 - 0.08, 0.475)
    F.tube("metal", (-W / 2 + 0.10, 0.02, 1.61),
           (W / 2 - 0.10, 0.02, 1.61), 0.012, 8)
    # A few owned garment silhouettes make an opened cabinet truthful without
    # turning private clothing into inventory or a generic loot container.
    seed = str(p.get("id", "wardrobe"))
    garment_mats = ("fabric_warm", "fabric_cool", "fabric_green", "linen")
    for i, gx in enumerate((-0.38, -0.13, 0.13, 0.38)):
        mat = garment_mats[(hash_str(seed) + i * 3) % len(garment_mats)]
        hem = _jit(seed, i + 41, 0.55, 0.82)
        half_w = _jit(seed, i + 51, 0.085, 0.115)
        F.box(mat, gx - half_w, -0.01, hem, gx + half_w, 0.105, 1.53)
        F.tbox("metal", (gx, 0.02, 1.53), (gx, 0.02, 1.60),
               half_w * 1.75, 0.008)
    F.box(wood, -W / 2 - 0.03, -d / 2 - 0.01, 1.86, W / 2 + 0.03,
          d / 2 + 0.03, 1.91)
    F.box(wood, -W / 2 - 0.015, -d / 2, 1.91, W / 2 + 0.015,
          d / 2 + 0.015, 1.945)
    F.hull(-W / 2 - 0.03, -d / 2, 0.0, W / 2 + 0.03, d / 2 + 0.03, 1.95)


def asm_shelf(F, p):
    """Wall-system spirit: slim steel ladders carrying oak boards."""
    W, d, books = p.get("W", 1.10), 0.30, p.get("books", True)
    h = p.get("H", 1.88)
    for sx_ in (-1, 1):
        for fy in (-d / 2 + 0.02, d / 2 - 0.02):
            F.cyl("metal", sx_ * (W / 2 - 0.02), fy, 0.0, h, 0.013,
                  0.013, 8)
    boards = [0.06, 0.50, 0.94, 1.38, h - 0.06]
    for bz in boards:
        F.box("floor_oak", -W / 2, -d / 2, bz, W / 2, d / 2, bz + 0.032)
    seed = p.get("id", "shelf")
    for i, bz in enumerate(boards[:-1]):
        if not books:
            if i < 2:
                F.box("trim", -W / 2 + 0.06, -d / 2 + 0.04, bz + 0.032,
                      -W / 2 + 0.42, d / 2 - 0.04, bz + 0.26)
                F.box("metal", W / 2 - 0.40, -d / 2 + 0.05, bz + 0.032,
                      W / 2 - 0.06, d / 2 - 0.05, bz + 0.22)
            continue
        # a lived-with shelf: runs start where the last hand left them,
        # spines sit proud or pushed back, heights range from paperback
        # to atlas, a pulled book leaves its gap, and some rows end in a
        # flat stack instead of a leaner
        run = _jit(seed, i, 0.40, 0.78) * W
        x = -W / 2 + 0.05 + _jit(seed, i + 61, 0.0, 0.10) * W
        k = 0
        while x + 0.05 < -W / 2 + run:
            if _jit(seed, i * 5 + k, 0.0, 1.0) > 0.87:
                x += _jit(seed, i * 3 + k, 0.03, 0.09)   # the pulled book
            bw = _jit(seed, i * 7 + k, 0.018, 0.062)
            bh = _jit(seed, i * 13 + k, 0.15, 0.325)
            push = _jit(seed, i * 19 + k, 0.0, 0.05)
            bm = ("book_burgundy", "book_green", "book_navy", "book_ochre",
                  "book_teal", "book_brown")[(i + k + len(seed)) % 6]
            F.box(bm, x, -d / 2 + 0.05 + push, bz + 0.032, x + bw,
                  d / 2 - 0.06 + push * 0.4, bz + 0.032 + bh)
            x += bw + 0.004
            k += 1
        if _jit(seed, i + 71, 0.0, 1.0) > 0.45 and x + 0.26 < W / 2:
            fz = bz + 0.032
            for f_ in range(2 + int(_jit(seed, i + 77, 0.0, 1.99))):
                fw = _jit(seed, i * 23 + f_, 0.15, 0.21)
                fh = _jit(seed, i * 29 + f_, 0.028, 0.042)
                fo = _jit(seed, i * 33 + f_, -0.018, 0.018)
                fm = ("book_navy", "book_brown", "book_teal",
                      "book_burgundy")[(i + f_) % 4]
                F.box(fm, x + 0.03 + fo, -d / 2 + 0.055, fz,
                      x + 0.03 + fo + fw, d / 2 - 0.075, fz + fh)
                fz += fh
        else:
            F.tbox("paper", (x + 0.10, 0.0, bz + 0.032),
                   (x + 0.015, 0.0, bz + 0.30), 0.19, 0.03)  # the leaner
    F.hull(-W / 2, -d / 2, 0.0, W / 2, d / 2, h)


def asm_tv(F, p):
    """A portrait panel on a slim stand.

    Rebuilt around the footage rather than the furniture. Every clip the
    building broadcasts is vertical, and a 4:3 tube can only show a vertical
    picture by throwing away the top and bottom of it or stranding it in
    black bars — both were tried, and both read as a fault rather than as a
    television. So the screen is the shape of the signal: 0.50 x 0.90
    against the reel's 320x576, so nothing is cropped or padded on its way
    to the glass.

    A vertical display in a 1927 block is an anachronism, and a deliberate
    one. The building is a century old; its residents are not.
    """
    # Foot and stem, narrow because the panel above them is narrow.
    F.box("wood_dark", -0.26, -0.17, 0.0, 0.26, 0.17, 0.045)
    F.tbox("metal", (0.0, 0.0, 0.045), (0.0, 0.0, 0.32), 0.05, 0.05)
    # Bezel, then glass standing proud of it on +Y — the face you see from
    # inside the room, verified by putting a camera at the sofa and looking
    # back. If a set still plays to its own back, the fault is that unit's
    # `yaw` in gen_layout rather than this assembly. The glass carries the
    # `screen` material, which takes unit UVs (UV_MODE_BY_MAT), so the quad
    # carries exactly one picture.
    F.box("bakelite", -0.275, -0.022, 0.275, 0.275, 0.014, 1.235)
    # No glass here any more: the screen is a runtime prop (tv_prop.gd)
    # with its own state, shader and glow — a merged mesh cannot be turned
    # off per set. The cabinet keeps the socket the prop sits in.
    F.hull(-0.29, -0.19, 0.0, 0.29, 0.19, 1.25)


def asm_plant(F, p):
    """A potted houseplant. The pot is always good; the plant depends on
    who waters it.

    Species chosen from what a New York apartment building actually held
    and could actually keep alive, because a plant is a statement about
    its owner and the wrong one says nothing:

      ASPIDISTRA  the cast-iron plant. Broad lance leaves straight out
                  of the soil; survives a dark hall and being forgotten
                  for a decade. This is the LOBBY plant, and it is why
                  every pre-war lobby in the city had one.
      SANSEVIERIA mother-in-law's tongue. Stiff vertical blades.
                  Indestructible, and everywhere after 1955.
      POTHOS      devil's ivy trailing over the rim and down the pot.
      RUBBER      ficus elastica: one thick stem, big glossy ovals.
                  Somebody's idea of a living-room tree.
      SPIDER      arching strappy leaves throwing runners with plantlets
                  on the ends - the plant that gives you more plants.
      FERN        Boston fern, many arching fronds from a crown. Wants a
                  humidity no steam-heated flat can give it.
      DRACAENA    bare cane with a topknot. The office plant that came
                  home.
      DEAD        the same crown, brown and collapsed. Some of these
                  people do not water anything.
    """
    species = p.get("species", "ficus")
    if species != "ficus":
        return _plant_species(F, p, species)
    big = p.get("big", False)
    s = 1.35 if big else 1.0
    seed = p.get("id", "plant")
    # drip saucer, thrown body, rolled rim lip
    F.lathe("terracotta", 0, 0, [(0.150 * s, 0.0), (0.168 * s, 0.010 * s),
                                 (0.158 * s, 0.032 * s)], 16)
    F.lathe("terracotta", 0, 0, [(0.105 * s, 0.014 * s),
                                 (0.148 * s, 0.055 * s),
                                 (0.175 * s, 0.290 * s),
                                 (0.178 * s, 0.302 * s)], 16)
    F.lathe("terracotta", 0, 0, [(0.178 * s, 0.302 * s),
                                 (0.196 * s, 0.314 * s),
                                 (0.198 * s, 0.352 * s),
                                 (0.180 * s, 0.360 * s),
                                 (0.160 * s, 0.350 * s)], 16)
    # potting soil mounded toward the stems, tucked under the rim
    F.lathe("soil", 0, 0, [(0.160 * s, 0.335 * s), (0.118 * s, 0.360 * s),
                           (0.045 * s, 0.374 * s), (0.001, 0.378 * s)], 14)
    for i in range(4 if big else 3):
        a = math.radians(_jit(seed, i, 0.0, 360.0))
        lean = _jit(seed, i + 9, 0.10, 0.22) * s
        top = _jit(seed, i + 17, 0.62, 0.92) * s
        bx = 0.030 * s * math.cos(a)
        by = 0.030 * s * math.sin(a)
        tx, ty = lean * math.cos(a), lean * math.sin(a)
        F.tube("timber", (bx, by, 0.355 * s),
               (tx * 0.6, ty * 0.6, top * 0.62), 0.010 * s, 6)
        F.tube("timber", (tx * 0.6, ty * 0.6, top * 0.62), (tx, ty, top),
               0.008 * s, 6)
        n_leaf = 6 if big else 5
        for k in range(n_leaf):
            t = 0.42 + 0.58 * (k / float(n_leaf - 1))
            lx = tx * t + _jit(seed, i * 31 + k, -0.055, 0.055) * s
            ly = ty * t + _jit(seed, i * 37 + k, -0.055, 0.055) * s
            lz = top * 0.62 + (top - top * 0.62) * t \
                - 0.025 * s * (k % 3) / 3.0
            lr = _jit(seed, i * 41 + k, 0.055, 0.095) * s
            # a leaf: flattened elliptical disk, tip drooping below the
            # midrib so the silhouette breaks instead of ballooning
            F.lathe("plant", lx, ly,
                    [(0.001, lz - 0.012 * s), (lr, lz),
                     (0.001, lz + 0.006 * s)], 7,
                    _jit(seed, i * 43 + k, 0.42, 0.68))
    F.hull(-0.20 * s, -0.20 * s, 0.0, 0.20 * s, 0.20 * s, 0.95 * s)


def _plant_pot(F, s, glazed=False):
    """The thrown pot, saucer and soil, shared by every species."""
    clay = "enamel" if glazed else "terracotta"
    F.lathe(clay, 0, 0, [(0.150 * s, 0.0), (0.168 * s, 0.010 * s),
                         (0.158 * s, 0.032 * s)], 16)
    F.lathe(clay, 0, 0, [(0.105 * s, 0.014 * s), (0.148 * s, 0.055 * s),
                         (0.175 * s, 0.290 * s),
                         (0.178 * s, 0.302 * s)], 16)
    F.lathe(clay, 0, 0, [(0.178 * s, 0.302 * s), (0.196 * s, 0.314 * s),
                         (0.198 * s, 0.352 * s), (0.180 * s, 0.360 * s),
                         (0.160 * s, 0.350 * s)], 16)
    F.lathe("soil", 0, 0, [(0.160 * s, 0.335 * s), (0.118 * s, 0.360 * s),
                           (0.045 * s, 0.374 * s), (0.001, 0.378 * s)], 14)


def _blade(F, mat, base_z, length, width, lean, twist):
    """One strap leaf: a tapered arc of flattened discs. It reads as a
    leaf because it narrows and bends, rather than hanging as a card."""
    steps = 4
    for i in range(steps):
        t0 = float(i) / steps
        t1 = float(i + 1) / steps
        bend = lean * t1 * t1
        r = width * (1.0 - 0.72 * t1)
        F.lathe(mat, math.cos(twist) * bend, math.sin(twist) * bend,
                [(0.001, base_z + length * t0),
                 (r, base_z + length * (t0 + t1) * 0.5),
                 (0.001, base_z + length * t1)], 5, 0.30)


GARDEN = ("tomato", "beans", "herb", "geranium", "sunflower", "fig")


def _plant_species(F, p, species):
    s = 1.35 if p.get("big", False) else 1.0
    seed = p.get("id", "plant")
    mat = "timber" if species == "dead" else "plant"
    if species in GARDEN:
        # A raised bed already has soil in it; a pot inside a bed is how
        # you can tell nobody has actually grown anything.
        return _garden_species(F, p, species, s, seed, mat)
    _plant_pot(F, s, glazed=p.get("glazed", False))
    soil_z = 0.372 * s

    if species in ("aspidistra", "sansevieria", "spider", "fern", "dead"):
        counts = {"aspidistra": 7, "sansevieria": 6, "spider": 9,
                  "fern": 11, "dead": 6}
        for i in range(counts[species]):
            a = math.radians(_jit(seed, i, 0.0, 360.0))
            if species == "sansevieria":
                _blade(F, mat, soil_z, _jit(seed, i + 5, 0.42, 0.68) * s,
                       0.028 * s, 0.045 * s, a)
            elif species == "aspidistra":
                _blade(F, mat, soil_z, _jit(seed, i + 5, 0.30, 0.46) * s,
                       0.058 * s, 0.16 * s, a)
            elif species == "fern":
                _blade(F, mat, soil_z, _jit(seed, i + 5, 0.24, 0.40) * s,
                       0.036 * s, 0.26 * s, a)
            elif species == "dead":
                _blade(F, mat, soil_z, _jit(seed, i + 5, 0.14, 0.26) * s,
                       0.030 * s, 0.30 * s, a)
            else:
                ln = _jit(seed, i + 5, 0.22, 0.38) * s
                _blade(F, mat, soil_z, ln, 0.030 * s, 0.22 * s, a)
                if i % 3 == 0:
                    rx = math.cos(a) * 0.30 * s
                    ry = math.sin(a) * 0.30 * s
                    F.tube(mat, (0, 0, soil_z + ln * 0.8),
                           (rx, ry, soil_z + ln * 0.35), 0.005 * s, 5)
                    for k in range(3):
                        _blade(F, mat, soil_z + ln * 0.30, 0.09 * s,
                               0.016 * s, 0.03 * s, a + k * 2.1)
    elif species == "pothos":
        for i in range(6):
            a = math.radians(_jit(seed, i, 0.0, 360.0))
            drop = _jit(seed, i + 4, 0.20, 0.44) * s
            ex = math.cos(a) * 0.19 * s
            ey = math.sin(a) * 0.19 * s
            F.tube(mat, (0, 0, soil_z), (ex, ey, soil_z - 0.02 * s),
                   0.006 * s, 5)
            F.tube(mat, (ex, ey, soil_z - 0.02 * s),
                   (ex * 1.15, ey * 1.15, soil_z - drop), 0.005 * s, 5)
            for k in range(4):
                t = (k + 1) / 5.0
                lz = soil_z - drop * t
                F.lathe(mat, ex * (1.0 + 0.15 * t), ey * (1.0 + 0.15 * t),
                        [(0.001, lz - 0.010 * s), (0.042 * s, lz),
                         (0.001, lz + 0.008 * s)], 6, 0.55)
    elif species in ("rubber", "dracaena"):
        cane_h = (0.86 if species == "dracaena" else 0.62) * s
        F.tube("timber", (0, 0, soil_z),
               (0.02 * s, 0.01 * s, soil_z + cane_h), 0.020 * s, 7)
        if species == "dracaena":
            for i in range(9):
                a = math.radians(_jit(seed, i, 0.0, 360.0))
                _blade(F, mat, soil_z + cane_h * 0.92,
                       _jit(seed, i + 3, 0.16, 0.28) * s, 0.026 * s,
                       0.20 * s, a)
        else:
            for i in range(6):
                a = math.radians(_jit(seed, i, 0.0, 360.0))
                lz = soil_z + cane_h * (0.34 + 0.11 * i)
                r = _jit(seed, i + 6, 0.070, 0.105) * s
                F.lathe(mat, math.cos(a) * 0.075 * s,
                        math.sin(a) * 0.075 * s,
                        [(0.001, lz - 0.014 * s), (r, lz),
                         (0.001, lz + 0.010 * s)], 7, 0.46)
    F.hull(-0.20 * s, -0.20 * s, 0.0, 0.20 * s, 0.20 * s, 0.95 * s)


def _garden_species(F, p, species, s, seed, mat):
    """What is actually growing on a New York roof in August.

    These sit straight in the bed soil rather than in a pot, and they are
    all things somebody would eat or pick. A roof garden is not
    decoration - it is the only ground these tenants have, and what is in
    it says so: tomatoes because they are worth the carrying, beans
    because they climb and the roof has more air than floor, herbs by the
    door where you can reach them without going out in the rain.
    """
    if species == "tomato":
        # staked stem, jagged foliage, and trusses of fruit at three
        # heights - green at the top, ripe at the bottom, like a real one
        h = _jit(seed, 1, 0.72, 1.05) * s
        F.tube("timber", (0, 0, 0.0), (0.02, 0.01, h), 0.016 * s, 6)
        F.tube("timber", (0.06 * s, 0.04 * s, 0.0),
               (0.06 * s, 0.04 * s, h * 1.05), 0.012 * s, 5)   # the cane
        for i in range(7):
            a = math.radians(_jit(seed, i + 3, 0.0, 360.0))
            lz = h * (0.22 + 0.11 * i)
            r = _jit(seed, i + 11, 0.075, 0.115) * s
            F.lathe(mat, math.cos(a) * 0.085 * s, math.sin(a) * 0.085 * s,
                    [(0.001, lz - 0.020 * s), (r, lz),
                     (0.001, lz + 0.014 * s)], 6, 0.42)
        for k, (tz, ripe) in enumerate(((0.34, True), (0.58, True),
                                        (0.80, False))):
            for j in range(3):
                a2 = math.radians(_jit(seed, k * 13 + j, 0.0, 360.0))
                fx = math.cos(a2) * 0.075 * s
                fy = math.sin(a2) * 0.075 * s
                F.cyl("terracotta" if ripe else "plant", fx, fy,
                      h * tz, h * tz + 0.055 * s, 0.030 * s, 0.030 * s, 7)
    elif species == "beans":
        # a vine twining up its cane, with pods hanging off it
        h = _jit(seed, 2, 1.10, 1.55) * s
        F.tube("timber", (0, 0, 0.0), (0.05 * s, 0.03 * s, h), 0.013 * s, 5)
        turns = 7
        for i in range(turns):
            t0 = float(i) / turns
            t1 = float(i + 1) / turns
            a0 = t0 * 9.0
            a1 = t1 * 9.0
            r = 0.045 * s
            F.tube(mat, (math.cos(a0) * r, math.sin(a0) * r, h * t0),
                   (math.cos(a1) * r, math.sin(a1) * r, h * t1),
                   0.007 * s, 4)
            if i % 2 == 0:
                F.lathe(mat, math.cos(a0) * 0.10 * s,
                        math.sin(a0) * 0.10 * s,
                        [(0.001, h * t0 - 0.02 * s), (0.062 * s, h * t0),
                         (0.001, h * t0 + 0.012 * s)], 6, 0.45)
            if i % 3 == 1:
                F.tube(mat, (math.cos(a0) * r, math.sin(a0) * r, h * t0),
                       (math.cos(a0) * r * 1.6, math.sin(a0) * r * 1.6,
                        h * t0 - 0.13 * s), 0.010 * s, 5)
    elif species == "herb":
        # a low bushy mound: parsley, thyme, whatever survived
        for i in range(14):
            a = math.radians(_jit(seed, i, 0.0, 360.0))
            r = _jit(seed, i + 7, 0.02, 0.11) * s
            hz = _jit(seed, i + 19, 0.05, 0.20) * s
            F.lathe(mat, math.cos(a) * r, math.sin(a) * r,
                    [(0.001, hz - 0.030 * s), (0.040 * s, hz),
                     (0.001, hz + 0.018 * s)], 5, 0.50)
    elif species == "geranium":
        for i in range(9):
            a = math.radians(_jit(seed, i, 0.0, 360.0))
            r = _jit(seed, i + 5, 0.03, 0.10) * s
            hz = _jit(seed, i + 15, 0.10, 0.26) * s
            F.lathe(mat, math.cos(a) * r, math.sin(a) * r,
                    [(0.001, hz - 0.026 * s), (0.055 * s, hz),
                     (0.001, hz + 0.014 * s)], 6, 0.48)
        for i in range(4):                       # the flower heads
            a = math.radians(_jit(seed, i + 30, 0.0, 360.0))
            r = _jit(seed, i + 33, 0.02, 0.07) * s
            F.cyl("terracotta", math.cos(a) * r, math.sin(a) * r,
                  0.28 * s, 0.32 * s, 0.045 * s, 0.030 * s, 8)
    elif species == "sunflower":
        h = _jit(seed, 4, 1.30, 1.85) * s
        F.tube("timber", (0, 0, 0.0), (0.03 * s, 0.02 * s, h), 0.020 * s, 6)
        for i in range(5):
            a = math.radians(_jit(seed, i + 2, 0.0, 360.0))
            lz = h * (0.28 + 0.13 * i)
            F.lathe(mat, math.cos(a) * 0.10 * s, math.sin(a) * 0.10 * s,
                    [(0.001, lz - 0.030 * s), (0.115 * s, lz),
                     (0.001, lz + 0.020 * s)], 6, 0.40)
        F.lathe("soil", 0.03 * s, 0.02 * s,
                [(0.001, h - 0.02 * s), (0.115 * s, h + 0.01 * s),
                 (0.001, h + 0.04 * s)], 12, 0.30)
        F.lathe("brass", 0.03 * s, 0.02 * s,
                [(0.115 * s, h + 0.005 * s), (0.185 * s, h + 0.02 * s),
                 (0.115 * s, h + 0.035 * s)], 14, 0.30)
    elif species == "fig":
        h = _jit(seed, 6, 0.80, 1.10) * s
        F.tube("timber", (0, 0, 0.0), (0.04 * s, 0.02 * s, h), 0.034 * s, 7)
        for i in range(8):
            a = math.radians(_jit(seed, i + 1, 0.0, 360.0))
            lz = h * (0.34 + 0.09 * i)
            r = _jit(seed, i + 21, 0.10, 0.155) * s
            F.lathe(mat, math.cos(a) * 0.12 * s, math.sin(a) * 0.12 * s,
                    [(0.001, lz - 0.030 * s), (r, lz),
                     (0.001, lz + 0.020 * s)], 5, 0.44)
    F.hull(-0.18 * s, -0.18 * s, 0.0, 0.18 * s, 0.18 * s, 1.10 * s)


def asm_watering_can(F, p):
    """Galvanised can, and the fact that somebody carries it up here.

    A roof garden with no watering kit is a set dressing of a roof
    garden. There is no tap on this roof, which is the point: everything
    in those beds was carried up the stair in this."""
    F.lathe("metal", 0.0, 0.0, [(0.0, 0.0), (0.115, 0.015), (0.125, 0.30),
                                (0.112, 0.335), (0.0, 0.345)], 14)
    # spout, rising from the base and out past the rim
    F.tube("metal", (0.09, 0.0, 0.06), (0.34, 0.0, 0.30), 0.026, 8)
    F.lathe("metal", 0.36, 0.0, [(0.030, 0.30), (0.058, 0.325),
                                 (0.056, 0.335)], 10)
    # handles: one over the top, one at the back to tip it with
    F.tube("metal", (-0.10, 0.0, 0.30), (0.0, 0.0, 0.44), 0.013, 6)
    F.tube("metal", (0.0, 0.0, 0.44), (0.10, 0.0, 0.30), 0.013, 6)
    F.tube("metal", (-0.12, 0.0, 0.14), (-0.19, 0.0, 0.24), 0.011, 6)
    F.tube("metal", (-0.19, 0.0, 0.24), (-0.12, 0.0, 0.30), 0.011, 6)


def asm_kitchen(F, p):
    """Frankfurt-kitchen cabinetry around a marker-owned sink opening."""
    L = p.get("L", 2.5)
    cw = L - 0.75
    sx0 = -cw / 2 + cw * 0.30
    # The complete roll-rim prop is 610 x 460 mm. Its cavity must clear
    # through the worktop AND the carcass below. Segmenting only the top
    # exposed the solid cabinet's top face as a false bottom to the hole.
    bx0, bx1 = sx0 - 0.305, sx0 + 0.305
    by0, by1 = -0.23, 0.23
    # carcass centered on the origin
    F.box("soot", -cw / 2 + 0.02, -0.28, 0.0, -cw / 2 + cw - 0.02, 0.26, 0.07)
    for cx0, cy0, cx1, cy1 in (
            (-cw / 2, -0.30, bx0, 0.28),
            (bx1, -0.30, cw / 2, 0.28),
            (bx0, -0.30, bx1, by0),
            (bx0, by1, bx1, 0.28)):
        F.box("trim", cx0, cy0, 0.07, cx1, cy1, 0.86)
    # counter, segmented around a real sink cutout (no booleans in the
    # box world: the hole is the four boards that don't cover it)
    for cx0, cy0, cx1, cy1 in (
            (-cw / 2 - 0.015, -0.315, bx0, 0.315),
            (bx1, -0.315, cw / 2 + 0.015, 0.315),
            (bx0, -0.315, bx1, by0),
            (bx0, by1, bx1, 0.315)):
        F.box("countertop", cx0, cy0, 0.86, cx1, cy1, 0.895)
    F.box("countertop", -cw / 2 - 0.015, -0.315, 0.895,
          -cw / 2 + cw + 0.015,
          -0.27, 0.97)                      # backsplash lip
    nd = max(2, int(cw / 0.45))
    dw = (cw - 0.02 * (nd + 1)) / nd
    for i in range(nd):
        x0 = -cw / 2 + 0.02 + i * (dw + 0.02)
        F.box("trim", x0, 0.281, 0.10, x0 + dw, 0.301, 0.80)
        F.box("soot", x0 + 0.02, 0.283, 0.74, x0 + dw - 0.02, 0.303, 0.775)
    F.box("trim", -cw / 2, -0.30, 1.46, -cw / 2 + cw, 0.05, 2.16)
    for i in range(nd):
        x0 = -cw / 2 + 0.02 + i * (dw + 0.02)
        F.box("trim", x0, 0.051, 1.50, x0 + dw, 0.071, 2.12)
        F.box("soot", x0 + 0.02, 0.053, 1.52, x0 + dw - 0.02, 0.073, 1.555)
    F.hull(-cw / 2, -0.32, 0.0, -cw / 2 + cw, 0.32, 0.92)


def rounded_body(F, mat, x0, y0, x1, y1, z0, z1, r=0.055, seg=10):
    """A box with genuinely rounded vertical edges.

    Prewar and midcentury appliance cabinets have no sharp corners -
    they are pressed steel with a generous radius, which is most of why
    a stacked-box appliance reads as a modern fridge in fancy dress.
    Two inset slabs plus four corner columns give the silhouette back
    for six primitives.
    """
    F.box(mat, x0 + r, y0, z0, x1 - r, y1, z1)
    F.box(mat, x0, y0 + r, z0, x1, y1 - r, z1)
    for cx, cy in ((x0 + r, y0 + r), (x1 - r, y0 + r),
                   (x0 + r, y1 - r), (x1 - r, y1 - r)):
        F.cyl(mat, cx, cy, z0, z1, r, r, seg)


def asm_desk(F, p):
    """Mid-century writing desk: floating top, splayed legs, one drawer."""
    L = p.get("L", 1.40)
    wood, top = "wood_dark", p.get("mat", "floor_oak")
    F.box(top, -L / 2, -0.325, 0.70, L / 2, 0.325, 0.735)
    F.box(wood, -L / 2 + 0.06, -0.28, 0.585, L / 2 - 0.06, 0.28, 0.70)
    F.box(wood, -L / 2 + 0.09, 0.281, 0.60, -0.02, 0.295, 0.685)
    F.box("soot", -L / 2 + 0.13, 0.296, 0.635, -0.06, 0.30, 0.655)
    for lx in (-L / 2 + 0.10, L / 2 - 0.10):
        for ly, splay in ((-0.26, -1), (0.26, 1)):
            F.tbox(wood, (lx * 1.10, ly + splay * 0.05, 0.0),
                   (lx, ly, 0.585), 0.034, 0.034)
        F.tbox(wood, (lx, -0.20, 0.16), (lx, 0.20, 0.16), 0.028, 0.028)
    F.hull(-L / 2, -0.33, 0.0, L / 2, 0.33, 0.74)


def asm_plantable(F, p):
    """Drafting-room spirit: trestle table heaped with contradicting plans."""
    F.box("floor_oak", -1.0, -0.6, 0.76, 1.0, 0.6, 0.80)
    for tx in (-0.72, 0.72):
        for ly in (-0.52, 0.52):
            F.tbox("wood_dark", (tx + (0.14 if tx < 0 else -0.14),
                                 ly * 0.45, 0.0), (tx, ly, 0.76),
                   0.05, 0.05)
        F.tbox("wood_dark", (tx, -0.52, 0.60), (tx, 0.52, 0.60),
               0.045, 0.045)
        F.tbox("wood_dark", (tx, 0.0, 0.0), (tx, 0.0, 0.60), 0.05, 0.05)
    F.tbox("wood_dark", (-0.72, 0.0, 0.28), (0.72, 0.0, 0.28), 0.05, 0.04)
    seed = p.get("id", "plans")
    for i in range(6):
        px = _jit(seed, i, -0.7, 0.45)
        py = _jit(seed, i + 11, -0.4, 0.15)
        F.box("paper", px, py, 0.80 + i * 0.0035,
              px + _jit(seed, i + 5, 0.45, 0.75),
              py + _jit(seed, i + 7, 0.3, 0.5), 0.803 + i * 0.0035)
    F.tube("paper", (0.75, -0.45, 0.80), (0.75, -0.45, 0.83), 0.04, 8)
    F.tube("paper", (0.82, -0.38, 0.80), (0.82, -0.38, 0.86), 0.035, 8)
    F.hull(-1.0, -0.6, 0.0, 1.0, 0.6, 0.81)


def asm_workbench(F, p):
    """Machinist-bench spirit: angle-steel legs, butcher top, side vise."""
    F.box("floor_oak", -1.1, -0.4, 0.85, 1.1, 0.4, 0.91)
    for lx in (-1.0, 1.0):
        for ly in (-0.32, 0.32):
            F.tbox("metal", (lx, ly, 0.0), (lx, ly, 0.85), 0.05, 0.012)
            F.tbox("metal", (lx + (0.012 if lx < 0 else -0.012), ly, 0.0),
                   (lx + (0.012 if lx < 0 else -0.012), ly, 0.85),
                   0.012, 0.05)
    F.box("metal", -1.02, -0.34, 0.22, 1.02, 0.34, 0.25)
    F.box("metal", -0.55, -0.36, 0.60, 0.05, 0.36, 0.82)
    F.box("metal", -0.52, 0.361, 0.63, 0.02, 0.375, 0.79)
    F.tube("metal", (-0.36, 0.39, 0.71), (-0.14, 0.39, 0.71), 0.010, 8)
    F.box("metal", 0.92, 0.40, 0.78, 1.1, 0.56, 0.91)
    F.tube("chrome", (1.01, 0.56, 0.845), (1.01, 0.64, 0.845), 0.014, 8)
    F.tube("metal", (0.95, 0.64, 0.845), (1.07, 0.64, 0.845), 0.010, 8)
    F.hull(-1.1, -0.4, 0.0, 1.1, 0.56, 0.92)


def asm_toilet(F, p):
    """Close-coupled porcelain: lathe bowl, seat, tank against the wall."""
    F.lathe("porcelain", 0, 0.06, [(0.145, 0.0), (0.105, 0.05),
                                   (0.125, 0.16), (0.19, 0.30),
                                   (0.185, 0.40)], 12, 0.85)
    F.lathe("porcelain", 0, 0.06, [(0.185, 0.40), (0.195, 0.415),
                                   (0.17, 0.425)], 12, 0.85)
    F.lathe("trim", 0, 0.06, [(0.17, 0.425), (0.178, 0.45),
                              (0.001, 0.46)], 12, 0.85)
    F.box("porcelain", -0.19, -0.34, 0.30, 0.19, -0.13, 0.72)
    F.box("porcelain", -0.20, -0.35, 0.72, 0.20, -0.12, 0.77)
    F.cyl("chrome", 0.0, -0.235, 0.77, 0.782, 0.028, 0.028, 10)
    F.hull(-0.20, -0.35, 0.0, 0.20, 0.30, 0.78)


def asm_sink_ped(F, p):
    """Pedestal lavatory: flared basin on a slender column, cross taps."""
    F.lathe("porcelain", 0, 0, [(0.10, 0.0), (0.065, 0.05), (0.052, 0.55),
                                (0.08, 0.66)], 12)
    F.lathe("porcelain", 0, 0.02, [(0.05, 0.66), (0.225, 0.76),
                                   (0.245, 0.80), (0.215, 0.815),
                                   (0.10, 0.79)], 14, 0.9)
    F.tube("chrome", (0.0, -0.16, 0.815), (0.0, -0.16, 0.90), 0.011, 8)
    F.tube("chrome", (0.0, -0.16, 0.90), (0.0, -0.045, 0.875), 0.010, 8)
    for tx in (-0.09, 0.09):
        F.tube("chrome", (tx, -0.17, 0.815), (tx, -0.17, 0.855), 0.009, 8)
        F.tube("chrome", (tx - 0.028, -0.17, 0.855),
               (tx + 0.028, -0.17, 0.855), 0.007, 6)
        F.tube("chrome", (tx, -0.198, 0.855), (tx, -0.142, 0.855),
               0.007, 6)
    # The mirror is the door of a medicine cabinet, and the door belongs
    # to the prop - the same split the range, the refrigerator and the
    # taps use. What the assembly leaves is the carcass recessed into the
    # wall, its shelves, and the frame the door closes onto.
    F.box("enamel", -0.22, -0.235, 1.05, 0.22, -0.215, 1.55)   # back
    for sx in (-0.22, 0.20):
        F.box("enamel", sx, -0.235, 1.05, sx + 0.02, -0.150, 1.55)
    F.box("enamel", -0.22, -0.235, 1.05, 0.22, -0.150, 1.07)
    F.box("enamel", -0.22, -0.235, 1.53, 0.22, -0.150, 1.55)
    for shz in (1.20, 1.35):
        F.box("glassish", -0.20, -0.232, shz, 0.20, -0.155, shz + 0.008)
    F.box("trim", -0.24, -0.168, 1.03, 0.24, -0.150, 1.05)
    F.box("trim", -0.24, -0.168, 1.55, 0.24, -0.150, 1.57)
    F.hull(-0.24, -0.22, 0.0, 0.24, 0.22, 0.82)


def asm_shower(F, p):
    """Corner stall rebuilt for close-up. Local frame matches every other
    bath fixture: the run wall is behind the piece at -Y (a toilet's tank
    faces -Y for the same reason), and `mirror` says which X side the
    corner's second wall is on. Ceramic-tiled back and corner walls,
    chrome-channeled glass on the two open sides with a 0.38 m entry,
    and plumbing mounted ON the tile: escutcheon mixer, riser, and a
    head angled down at a standing user's crown."""
    m = 1.0 if p.get("mirror") else -1.0    # corner-wall side sign

    def bx(mat, x0, y0, z0, x1, y1, z1):
        F.box(mat, min(x0, x1), min(y0, y1), z0, max(x0, x1),
              max(y0, y1), z1)
    F.box("porcelain", -0.40, -0.40, 0.0, 0.40, 0.40, 0.12)
    F.box("soot", -0.34, -0.34, 0.045, 0.34, 0.34, 0.125)
    # tiled surround: back wall (-Y) and the corner-side wall, capped
    bx("ceramic", -0.43, -0.435, 0.0, 0.43, -0.405, 2.06)
    bx("ceramic", m * 0.405, -0.43, 0.0, m * 0.435, 0.42, 2.06)
    bx("trim", -0.435, -0.437, 2.06, 0.435, -0.402, 2.10)
    bx("trim", m * 0.402, -0.437, 2.06, m * 0.437, 0.42, 2.10)
    # glass: full panel down the open side, and a front panel returning
    # from the corner wall, leaving the entry beside the open-side glass
    bx("glassish", -m * 0.388, -0.40, 0.13, -m * 0.400, 0.30, 1.90)
    bx("glassish", m * 0.40, 0.390, 0.13, m * 0.02, 0.402, 1.90)
    # chrome channels: sill and head rails plus corner posts seat the
    # panels instead of letting them float
    bx("chrome", -m * 0.383, -0.40, 0.12, -m * 0.405, 0.30, 0.145)
    bx("chrome", -m * 0.383, -0.40, 1.88, -m * 0.405, 0.30, 1.905)
    bx("chrome", m * 0.40, 0.385, 0.12, m * 0.02, 0.407, 0.145)
    bx("chrome", m * 0.40, 0.385, 1.88, m * 0.02, 0.407, 1.905)
    F.tube("chrome", (-m * 0.394, -0.40, 0.12),
           (-m * 0.394, -0.40, 1.90), 0.011, 8)
    F.tube("chrome", (-m * 0.394, 0.30, 0.12),
           (-m * 0.394, 0.30, 1.90), 0.011, 8)
    F.tube("chrome", (m * 0.02, 0.396, 0.12), (m * 0.02, 0.396, 1.90),
           0.011, 8)
    # plumbing on the back tile: mixer escutcheon + lever, riser, arm,
    # and the head pitched down-forward toward a 1.7 m user
    bx("chrome", -0.07, -0.407, 0.98, 0.07, -0.392, 1.16)
    F.tube("bakelite", (0.0, -0.392, 1.07), (0.0, -0.335, 1.02),
           0.011, 8)
    F.tube("chrome", (0.0, -0.393, 1.16), (0.0, -0.393, 1.94), 0.012, 8)
    F.tube("chrome", (0.0, -0.393, 1.94), (0.0, -0.20, 1.87), 0.012, 8)
    F.tube("chrome", (0.0, -0.20, 1.87), (0.0, -0.152, 1.785), 0.056, 12)
    F.tube("soot", (0.0, -0.176, 1.827), (0.0, -0.146, 1.774), 0.050, 12)
    F.hull(-0.40, -0.40, 0.0, 0.40, 0.40, 0.13)


def asm_sink_basin(F, p):
    """Standalone undermount basin for hand-built counters (4B's galley).
    Origin sits at the CENTER of the counter cutout, on the finished top
    surface; the bowl hangs below and the mixer rises behind at +Y. The
    counter itself must be laid as segments around the same opening —
    there are no booleans in this box world, so the hole is the boards
    that aren't there."""
    W, D = p.get("W", 0.50), p.get("D", 0.38)
    depth = p.get("depth", 0.19)
    hw, hd = W / 2.0, D / 2.0
    for rx0, ry0, rx1, ry1 in ((-hw - 0.018, -hd - 0.018, hw + 0.018, -hd),
                               (-hw - 0.018, hd, hw + 0.018, hd + 0.018),
                               (-hw - 0.018, -hd, -hw, hd),
                               (hw, -hd, hw + 0.018, hd)):
        F.box("chrome", rx0, ry0, 0.0, rx1, ry1, 0.011)
    for wx0, wy0, wx1, wy1 in ((-hw, -hd, hw, -hd + 0.012),
                               (-hw, hd - 0.012, hw, hd),
                               (-hw, -hd, -hw + 0.012, hd),
                               (hw - 0.012, -hd, hw, hd)):
        F.box("metal", wx0, wy0, -depth, wx1, wy1, 0.003)
    F.box("metal", -hw, -hd, -depth, hw, hd, -depth + 0.02)
    F.cyl("soot", 0.0, 0.0, -depth + 0.02, -depth + 0.027, 0.030, 0.030, 10)
    F.lathe("chrome", 0.0, 0.0, [(0.030, -depth + 0.027),
                                 (0.040, -depth + 0.031),
                                 (0.032, -depth + 0.034)], 10)
    # mixer behind the bowl: riser, swan spout, two cross taps
    by = hd + 0.055
    F.lathe("chrome", 0.0, by, [(0.032, 0.0), (0.036, 0.012),
                                (0.014, 0.020)], 10)
    F.tube("chrome", (0.0, by, 0.012), (0.0, by, 0.235), 0.014, 8)
    F.tube("chrome", (0.0, by, 0.235), (0.0, by - 0.085, 0.268), 0.013, 8)
    F.tube("chrome", (0.0, by - 0.085, 0.268), (0.0, by - 0.145, 0.225),
           0.012, 8)
    for tx in (-0.105, 0.105):
        F.tube("chrome", (tx, by, 0.010), (tx, by, 0.075), 0.010, 8)
        F.tube("chrome", (tx - 0.030, by, 0.075), (tx + 0.030, by, 0.075),
               0.007, 6)
        F.tube("chrome", (tx, by - 0.030, 0.075), (tx, by + 0.030, 0.075),
               0.007, 6)


def asm_switch(F, p):
    """The reopening contractor's c.1920 GE-pattern push-button switch.

    The former long Bakelite tumbler was plausible by 1928, but its thick
    molded trim surround read as a modern plastic switch at player distance.
    A stamped plate and two distinct buttons are both earlier and clearer:
    one button remains proud while its mate sits home.  The whole building
    received the same cheap fitting in the 1928 conversion; individuality
    comes from the wall and the hands around it, not twenty plate designs.
    """
    # 88 x 132 mm is the original plate envelope, only 1.4 mm proud of the
    # plaster. A shallow rolled rim catches the bathroom sconce without
    # turning a two-dollar fitting into decorative hardware.
    F.box("brass_dull", -0.044, 0.0, -0.066, 0.044, 0.0014, 0.066)
    F.box("brass_dull", -0.040, 0.0014, -0.062, 0.040, 0.0032, 0.062)
    # GE sold the mechanism with a Bakelite body and buttons. One projects
    # 7 mm, the other 3 mm: the circuit's state is legible without a label.
    for z, depth in ((0.021, 0.010), (-0.021, 0.006)):
        F.cyl("bakelite_black", 0.0, 0.0032, z - 0.006, z + 0.006,
              0.010, 0.010, 12, sx=1.0)
        F.box("bakelite_black", -0.010, 0.0032, z - 0.006,
              0.010, depth, z + 0.006)
    # Slotted brass fasteners, vertical like the surviving catalogue pieces.
    for sz in (-0.053, 0.053):
        F.box("brass_bright", -0.0042, 0.0032, sz - 0.0042,
              0.0042, 0.0050, sz + 0.0042)
        F.box("soot", -0.0030, 0.0050, sz - 0.0007,
              0.0030, 0.0054, sz + 0.0007)


def asm_pipe(F, p):
    """Raw endpoints are world-space by default (the basement services
    are authored that way); `local: true` routes them through the frame
    so a run can anchor to a marker's position and yaw."""
    a, b = tuple(p["p0"]), tuple(p["p1"])
    if p.get("local"):
        a, b = F.pt(*a), F.pt(*b)
    F.g(p.get("mat", "metal")).add_tube(a, b, p.get("r", 0.045), 10)


def asm_bench(F, p):
    """Somewhere to sit. Two kinds, because a lobby and a laundry do not
    buy the same furniture.

    SETTLE (default) is the hall settle a 1926 lobby was fitted with:
    slat seat, turned legs, spindle back, dark stained oak. It is meant
    to be looked at as much as sat on.

    SLAT is what gets bought later and put where things get wet - a
    backless plank bench on square legs with steel angle brackets, in
    plain timber that nobody minds. Laundry, basement corridor, roof.
    """
    if p.get("style", "settle") == "slat":
        return _bench_slat(F, p)
    L = p.get("L", 1.5)
    for i in range(3):
        F.box("wood_dark", -L / 2, -0.20 + i * 0.145, 0.44, L / 2,
              -0.085 + i * 0.145, 0.475)
    for lx in (-L / 2 + 0.08, L / 2 - 0.08):
        for ly in (-0.16, 0.16):
            F.lathe("wood_dark", lx, ly, [(0.028, 0.0), (0.022, 0.14),
                                          (0.034, 0.20), (0.024, 0.44)], 8)
    F.box("wood_dark", -L / 2, -0.235, 0.86, L / 2, -0.19, 0.92)
    for i in range(7):
        sxp = -L / 2 + 0.10 + i * (L - 0.20) / 6.0
        F.cyl("wood_dark", sxp, -0.21, 0.475, 0.86, 0.012, 0.012, 8)
    F.hull(-L / 2, -0.24, 0.0, L / 2, 0.24, 0.93)


def _bench_slat(F, p):
    """Backless plank bench: three boards, square legs, angle brackets."""
    L = p.get("L", 1.3)
    for i in range(3):
        F.box("timber", -L / 2, -0.17 + i * 0.125, 0.41, L / 2,
              -0.075 + i * 0.125, 0.445)
    for lx in (-L / 2 + 0.10, L / 2 - 0.10):
        for ly in (-0.13, 0.13):
            F.box("timber", lx - 0.028, ly - 0.028, 0.0,
                  lx + 0.028, ly + 0.028, 0.41)
        # the steel angle that stops it racking
        F.box("metal", lx - 0.034, -0.15, 0.33, lx + 0.034, 0.15, 0.36)
    F.hull(-L / 2, -0.19, 0.0, L / 2, 0.19, 0.45)


def asm_mailbank(F, p):
    """Brass pigeon bank: 4x5 doors, label slots, one hanging open."""
    F.box("wood_dark", -0.80, -0.02, 0.30, 0.80, 0.13, 1.72)
    for r in range(4):
        for c in range(5):
            x0 = -0.72 + c * 0.29
            z0 = 0.42 + r * 0.30
            F.box("brass", x0, 0.13, z0, x0 + 0.25, 0.145, z0 + 0.24)
            F.box("paper", x0 + 0.05, 0.145, z0 + 0.145, x0 + 0.20,
                  0.149, z0 + 0.185)
            F.cyl("bakelite", x0 + 0.21, 0.152, z0 + 0.06, z0 + 0.075,
                  0.012, 0.008, 6)
    F.tbox("brass", (-0.72 + 2 * 0.29, 0.13, 0.42 + 0.30),
           (-0.72 + 2 * 0.29 + 0.20, 0.28, 0.42 + 0.24), 0.24, 0.012)
    F.hull(-0.80, -0.02, 0.30, 0.80, 0.16, 1.72)


# ---- resident personality clutter (Phase 6 hero pass). Small originals
# in the same spirit-of-a-typology language: stage gear for Juno, bench
# electronics for Omar, playback for Rhea, paperwork for Nadia, capture
# kit for Sacha, tidy desk order for Mina. Tabletop pieces skip hull()
# on purpose: no physics, no floor shadow quad floating mid-air.

def asm_amp(F, p):
    """Guitar combo amp: vinyl cab, cloth grille, knob row, pilot lamp."""
    W, H, D = p.get("W", 0.56), p.get("H", 0.46), 0.27
    F.box("soot", -W / 2, -D / 2, 0.02, W / 2, D / 2, H)
    F.box("linen", -W / 2 + 0.035, D / 2 - 0.004, 0.05, W / 2 - 0.035,
          D / 2 + 0.012, H - 0.115)
    F.box("bakelite", -W / 2 + 0.03, D / 2 - 0.02, H - 0.105,
          W / 2 - 0.03, D / 2 + 0.004, H - 0.03)
    nk = max(3, int(W / 0.10))
    for i in range(nk):
        kx = -W / 2 + 0.07 + i * (W - 0.14) / (nk - 1)
        F.tube("chrome", (kx, D / 2 + 0.004, H - 0.068),
               (kx, D / 2 + 0.022, H - 0.068), 0.011, 6)
    F.tube("brass", (W / 2 - 0.045, D / 2 + 0.004, H - 0.068),
           (W / 2 - 0.045, D / 2 + 0.016, H - 0.068), 0.005, 6)
    F.tbox("bakelite", (-0.09, 0.0, H + 0.015), (0.09, 0.0, H + 0.015),
           0.035, 0.030)
    for fx in (-W / 2 + 0.05, W / 2 - 0.05):
        for fy in (-D / 2 + 0.05, D / 2 - 0.05):
            F.cyl("bakelite", fx, fy, 0.0, 0.02, 0.020, 0.024, 6)
    F.hull(-W / 2, -D / 2, 0.0, W / 2, D / 2, H + 0.03)


def asm_guitar(F, p):
    """Guitar leaning on whatever was closest: waisted slab body, long
    neck to a paddle head, back tipped toward local -Y."""
    body = "timber" if p.get("acoustic") else "enamel"
    F.tbox(body, (0.0, -0.02, 0.03), (0.0, -0.10, 0.44), 0.32, 0.065)
    F.tbox(body, (0.0, -0.035, 0.10), (0.0, -0.075, 0.31), 0.40, 0.060)
    F.tbox("wood_dark", (0.0, -0.105, 0.46), (0.0, -0.175, 0.83),
           0.048, 0.030)
    F.tbox("wood_dark", (0.0, -0.178, 0.845), (0.0, -0.205, 0.985),
           0.062, 0.024)
    F.tube("chrome", (0.0, -0.052, 0.20), (0.0, -0.150, 0.72), 0.004, 4)
    F.hull(-0.19, -0.16, 0.0, 0.19, 0.06, 0.48)


def asm_pedalboard(F, p):
    """Plywood pedalboard: four mismatched stomp pedals, patch leads."""
    seed = p.get("id", "pb")
    F.box("plywood", -0.30, -0.16, 0.0, 0.30, 0.16, 0.04)
    for i, pm in enumerate(("bakelite", "enamel", "metal",
                            "fabric_green")):
        px = -0.225 + i * 0.15
        py = _jit(seed, i, -0.055, 0.035)
        F.box(pm, px - 0.052, py - 0.085, 0.04, px + 0.052, py + 0.085,
              0.095)
        F.cyl("chrome", px, py + 0.042, 0.095, 0.112, 0.013, 0.013, 6)
        F.tube("bakelite", (px - 0.028, py - 0.055, 0.095),
               (px - 0.028, py - 0.055, 0.112), 0.008, 6)
    F.tube("soot", (-0.17, 0.10, 0.052), (-0.075, 0.13, 0.052), 0.006, 6)
    F.tube("soot", (-0.075, 0.13, 0.052), (0.075, 0.115, 0.052), 0.006, 6)
    F.hull(-0.30, -0.16, 0.0, 0.30, 0.16, 0.12)


def asm_micstand(F, p):
    """Round-base mic stand; the boom drops the capsule toward +Y."""
    F.lathe("metal", 0, 0, [(0.135, 0.0), (0.11, 0.018), (0.02, 0.035),
                            (0.013, 0.05)], 10)
    F.cyl("metal", 0, 0, 0.05, 1.08, 0.011, 0.009, 8)
    F.tube("metal", (0.0, 0.0, 1.08), (0.0, 0.30, 1.32), 0.008, 6)
    F.tube("soot", (0.0, 0.30, 1.32), (0.0, 0.355, 1.278), 0.023, 8)
    F.hull(-0.135, -0.135, 0.0, 0.135, 0.135, 0.30)


def asm_reeldeck(F, p):
    """Reel-to-reel playback deck: twin reels, head block, VU windows."""
    F.box("metal", -0.24, -0.17, 0.0, 0.24, 0.17, 0.07)
    F.box("bakelite", -0.235, -0.165, 0.07, 0.235, 0.165, 0.105)
    for rx in (-0.115, 0.115):
        F.cyl("soot", rx, 0.03, 0.105, 0.117, 0.10, 0.10, 14)
        F.cyl("enamel", rx, 0.03, 0.117, 0.124, 0.03, 0.03, 8)
    F.box("metal", -0.055, -0.135, 0.105, 0.055, -0.085, 0.135)
    for vx in (-0.16, 0.16):
        F.box("paper", vx - 0.028, -0.15, 0.106, vx + 0.028, -0.10, 0.110)
    for kx in (-0.06, 0.0, 0.06):
        F.tube("bakelite", (kx, -0.045, 0.105), (kx, -0.045, 0.122),
               0.010, 6)


def asm_headphones(F, p):
    """Cans hung on a turned desk stand, cable slumped to the surface."""
    F.lathe("wood_dark", 0, 0, [(0.065, 0.0), (0.05, 0.012),
                                (0.012, 0.022), (0.009, 0.24),
                                (0.02, 0.25), (0.001, 0.265)], 8)
    F.tbox("soot", (-0.055, 0.0, 0.20), (0.0, 0.0, 0.262), 0.036, 0.012)
    F.tbox("soot", (0.055, 0.0, 0.20), (0.0, 0.0, 0.262), 0.036, 0.012)
    for s in (-1, 1):
        F.lathe("soot", s * 0.062, 0.0,
                [(0.012, 0.115), (0.04, 0.135), (0.044, 0.185),
                 (0.022, 0.198)], 10)
    F.tube("soot", (-0.062, 0.0, 0.115), (0.05, 0.09, 0.004), 0.004, 4)


def asm_mug(F, p):
    m = p.get("mat", "porcelain")
    F.lathe(m, 0, 0, [(0.034, 0.0), (0.040, 0.008), (0.040, 0.092),
                      (0.035, 0.10)], 10)
    F.tube(m, (0.038, 0.0, 0.030), (0.062, 0.0, 0.052), 0.007, 6)
    F.tube(m, (0.062, 0.0, 0.052), (0.040, 0.0, 0.078), 0.007, 6)


def asm_dishrack(F, p):
    """Narrow wire rack with plates on edge; unmistakable at counter scale.

    The previous 'mugs / plates / board' were three cuboids. They satisfied
    a data inventory and looked like packing blocks abandoned in the sink.
    Circular plate rims and a nickel wire cradle spend fewer triangles than
    those boxes while finally saying what the objects are.
    """
    W, D = p.get("W", 0.12), p.get("D", 0.26)
    n = max(2, int(p.get("n", 4)))
    # cradle and raised side rails
    for x in (-W * 0.5, W * 0.5):
        F.tube("nickel_plated", (x, -D * 0.5, 0.012),
               (x, D * 0.5, 0.012), 0.005, 6)
        F.tube("nickel_plated", (x, -D * 0.5, 0.012),
               (x, -D * 0.5, 0.105), 0.005, 6)
        F.tube("nickel_plated", (x, D * 0.5, 0.012),
               (x, D * 0.5, 0.105), 0.005, 6)
    F.tube("nickel_plated", (-W * 0.5, -D * 0.5, 0.105),
           (W * 0.5, -D * 0.5, 0.105), 0.005, 6)
    F.tube("nickel_plated", (-W * 0.5, D * 0.5, 0.105),
           (W * 0.5, D * 0.5, 0.105), 0.005, 6)
    # Plates stand in Y/Z planes. Chained tubes give each a real circular
    # silhouette without introducing a high-sided dish mesh for six pixels.
    radius = min(0.095, D * 0.40)
    for i in range(n):
        px = -W * 0.36 + (W * 0.72 * i / max(1, n - 1))
        for k in range(16):
            a0 = 2.0 * math.pi * k / 16.0
            a1 = 2.0 * math.pi * (k + 1) / 16.0
            p0 = (px, math.cos(a0) * radius, 0.105 + math.sin(a0) * radius)
            p1 = (px, math.cos(a1) * radius, 0.105 + math.sin(a1) * radius)
            F.tube("porcelain", p0, p1, 0.006, 5)
    F.hull(-W * 0.55, -D * 0.55, 0.0, W * 0.55, D * 0.55, 0.21)


def asm_papers(F, p):
    """Loose paper stack; `mess` spreads the drift."""
    seed, n = p.get("id", "pp"), p.get("n", 6)
    mess = 1.0 + 3.0 * p.get("mess", 0.0)
    for i in range(n):
        ox = _jit(seed, i, -0.018, 0.018) * mess
        oy = _jit(seed, i + 9, -0.014, 0.014) * mess
        F.box("paper", -0.105 + ox, -0.148 + oy, i * 0.0075,
              0.105 + ox, 0.148 + oy, i * 0.0075 + 0.005)


def asm_bookpile(F, p):
    """Horizontal pile of mismatched volumes (or tape boxes, or manuals)."""
    seed, n = p.get("id", "bk"), p.get("n", 4)
    mats = ("book_burgundy", "book_green", "book_navy", "book_ochre",
            "book_teal", "book_brown")
    z = 0.0
    for i in range(n):
        w = _jit(seed, i, 0.14, 0.19)
        d = _jit(seed, i + 5, 0.21, 0.27)
        h = _jit(seed, i + 11, 0.028, 0.048)
        ox = _jit(seed, i + 17, -0.02, 0.02)
        oy = _jit(seed, i + 23, -0.02, 0.02)
        F.box(mats[(hash_str(seed) + i) % len(mats)],
              ox - w / 2, oy - d / 2, z,
              ox + w / 2, oy + d / 2, z + h)
        z += h


def asm_pinboard(F, p):
    """Cork board on the wall: cards in a tidy grid, or drifted layers
    of them fighting for space. Front faces +Y."""
    W, H = p.get("W", 0.90), p.get("H", 0.60)
    seed, neat = p.get("id", "pin"), p.get("neat", True)
    F.box("wood_dark", -W / 2, 0.0, 0.0, W / 2, 0.016, H)
    F.box("timber", -W / 2 + 0.03, 0.016, 0.03, W / 2 - 0.03, 0.026,
          H - 0.03)
    n = p.get("cards", 12)
    cols = max(2, int(round(n / 3.0)))
    for i in range(n):
        if neat:
            px = -W / 2 + 0.08 + (i % cols) * (W - 0.16) / (cols - 1)
            pz = H - 0.10 - (i // cols) * 0.135
            cw, ch = 0.037, 0.05
        else:
            px = _jit(seed, i, -W / 2 + 0.09, W / 2 - 0.09)
            pz = _jit(seed, i + 31, 0.10, H - 0.10)
            cw = _jit(seed, i + 57, 0.03, 0.075)
            ch = _jit(seed, i + 71, 0.04, 0.09)
        F.box("paper", px - cw, 0.026, pz - ch, px + cw,
              0.028 + 0.002 * (i % 3), pz + ch)


def asm_toolboard(F, p):
    """Pegboard: wrench row by size, hammer, a coil of cord on a nail."""
    W, H = p.get("W", 1.05), p.get("H", 0.70)
    seed = p.get("id", "tb")
    F.box("plywood", -W / 2, 0.0, 0.0, W / 2, 0.018, H)
    for i in range(5):
        tx = -W / 2 + 0.10 + i * (W - 0.55) / 4.0
        L = _jit(seed, i, 0.15, 0.24)
        F.box("metal", tx - 0.010, 0.018, H - 0.10 - L, tx + 0.010,
              0.030, H - 0.10)
        F.cyl("metal", tx, 0.024, H - 0.10 - L - 0.025, H - 0.10 - L,
              0.018, 0.014, 6)
    hx = W / 2 - 0.22
    F.box("timber", hx - 0.012, 0.018, H - 0.38, hx + 0.012, 0.032,
          H - 0.10)
    F.box("metal", hx - 0.055, 0.014, H - 0.145, hx + 0.055, 0.040,
          H - 0.095)
    cx_ = W / 2 - 0.09
    for k in range(6):
        F.tube("soot", (cx_ + 0.055 * math.cos(k * 1.047), 0.030,
                        H - 0.44 + 0.055 * math.sin(k * 1.047)),
               (cx_ + 0.055 * math.cos((k + 1) * 1.047), 0.030,
                H - 0.44 + 0.055 * math.sin((k + 1) * 1.047)), 0.009, 6)


def asm_partstray(F, p):
    """Sorting tray of small parts; optionally the opened chassis it
    all came out of, valves still socketed."""
    seed = p.get("id", "pt")
    F.box("metal", -0.20, -0.14, 0.0, 0.20, 0.14, 0.012)
    for s in (-1, 1):
        F.box("metal", s * 0.20 - 0.006, -0.14, 0.0, s * 0.20 + 0.006,
              0.14, 0.045)
        F.box("metal", -0.20, s * 0.14 - 0.006, 0.0, 0.20,
              s * 0.14 + 0.006, 0.045)
    for i in range(12):
        bx = -0.15 + (i % 4) * 0.10
        by = -0.085 + (i // 4) * 0.085
        pm = ("brass", "chrome", "bakelite", "metal")[
            (hash_str(seed) + i) % 4]
        F.box(pm, bx - 0.028, by - 0.024, 0.012, bx + 0.028, by + 0.024,
              0.012 + _jit(seed, i, 0.012, 0.035))
    if p.get("chassis"):
        F.box("bakelite", 0.26, -0.12, 0.0, 0.52, 0.12, 0.05)
        for i, tx in enumerate((0.32, 0.40, 0.47)):
            F.cyl("glassish", tx, _jit(seed, i + 40, -0.06, 0.06), 0.05,
                  0.115, 0.014, 0.012, 6)
        F.cyl("brass", 0.34, 0.07, 0.05, 0.085, 0.022, 0.022, 8)


def asm_jarrow(F, p):
    """Salvage jars in a row: screws, washers, fuses, sorted by kind."""
    seed, n = p.get("id", "jr"), p.get("n", 4)
    for i in range(n):
        jx = (i - (n - 1) / 2.0) * 0.115
        fill = ("metal", "brass", "chrome", "bakelite")[
            (hash_str(seed) + i) % 4]
        F.box(fill, jx - 0.030, -0.030, 0.006, jx + 0.030, 0.030,
              _jit(seed, i, 0.035, 0.10))
        F.lathe("glassish", jx, 0, [(0.042, 0.0), (0.046, 0.01),
                                    (0.046, 0.115), (0.038, 0.125)], 8)
        F.lathe("bakelite", jx, 0, [(0.040, 0.125), (0.040, 0.148),
                                    (0.001, 0.148)], 8)


def asm_tripod(F, p):
    """Camera on sticks: splayed legs, body, lens out the front line."""
    h = p.get("H", 1.32)
    for a in (90, 210, 330):
        r = math.radians(a)
        F.tbox("metal", (0.30 * math.cos(r), 0.30 * math.sin(r), 0.0),
               (0.0, 0.0, h - 0.22), 0.026, 0.018)
    F.cyl("metal", 0, 0, h - 0.26, h - 0.015, 0.020, 0.017, 8)
    F.box("soot", -0.075, -0.10, h, 0.075, 0.095, h + 0.11)
    F.tube("metal", (0.0, 0.095, h + 0.055), (0.0, 0.185, h + 0.055),
           0.033, 10)
    F.box("screen", -0.055, -0.102, h + 0.02, 0.055, -0.099, h + 0.09)
    F.hull(-0.30, -0.30, 0.0, 0.30, 0.30, 0.60)


def asm_softbox(F, p):
    """Work light on a stand, diffuser panel pitched down at the subject
    (subject toward +Y)."""
    for a in (30, 150, 270):
        r = math.radians(a)
        F.tbox("metal", (0.26 * math.cos(r), 0.26 * math.sin(r), 0.0),
               (0.0, 0.0, 0.55), 0.024, 0.016)
    F.cyl("metal", 0, 0, 0.50, 1.52, 0.014, 0.012, 8)
    F.tbox("soot", (0.0, -0.02, 1.66), (0.0, 0.17, 1.44), 0.46, 0.09)
    F.tbox("linen", (0.0, 0.175, 1.437), (0.0, 0.215, 1.39), 0.42, 0.012)
    F.hull(-0.26, -0.26, 0.0, 0.26, 0.26, 0.55)


def asm_cablecoil(F, p):
    """A coil of instrument cable nobody has put away, tail wandering."""
    seed, r = p.get("id", "cc"), p.get("r", 0.11)
    pts = [(r * math.cos(math.radians(a)), r * math.sin(math.radians(a)))
           for a in range(0, 360, 45)]
    for i in range(8):
        xa, ya = pts[i]
        xb, yb = pts[(i + 1) % 8]
        F.tube("soot", (xa, ya, 0.014 + 0.010 * (i % 2)),
               (xb, yb, 0.014 + 0.010 * ((i + 1) % 2)), 0.010, 6)
    F.tube("soot", (r, 0.0, 0.012),
           (r + _jit(seed, 1, 0.18, 0.30), _jit(seed, 2, -0.15, 0.15),
            0.012), 0.008, 6)


def asm_crate(F, p):
    """Slat crate: a record collection filed edge-on, or a gear jumble."""
    W, D, H = p.get("W", 0.42), p.get("D", 0.35), p.get("H", 0.33)
    seed = p.get("id", "cr")
    F.box("timber", -W / 2, -D / 2, 0.0, W / 2, D / 2, 0.02)
    for s in (-1, 1):
        F.box("timber", s * W / 2 - 0.011, -D / 2, 0.0,
              s * W / 2 + 0.011, D / 2, H)
    for s in (-1, 1):
        for za, zb in ((0.03, 0.14), (0.19, H - 0.03)):
            F.box("timber", -W / 2 + 0.011, s * D / 2 - 0.011, za,
                  W / 2 - 0.011, s * D / 2 + 0.011, zb)
    if p.get("records"):
        n = int((W - 0.08) / 0.016)
        for i in range(n):
            rx = -W / 2 + 0.04 + i * 0.016
            lean = _jit(seed, i, 0.0, 0.012)
            F.box(("soot", "paper", "fabric_cool", "fabric_warm",
                   "fabric_green")[(hash_str(seed) + i) % 5],
                  rx, -D / 2 + 0.03 + lean, 0.02, rx + 0.011,
                  D / 2 - 0.03 + lean, _jit(seed, i + 50, 0.27, 0.31))
    else:
        F.box(p.get("fill", "soot"), -W / 2 + 0.03, -D / 2 + 0.03, 0.02,
              W / 2 - 0.03, D / 2 - 0.03, _jit(seed, 3, 0.15, H - 0.06))
    F.hull(-W / 2, -D / 2, 0.0, W / 2, D / 2, H)


def asm_radio(F, p):
    """Bench radio: wood cab, cloth grille, dial strip, two knobs."""
    F.box("wood_dark", -0.19, -0.11, 0.0, 0.19, 0.11, 0.28)
    F.box("linen", -0.125, 0.105, 0.115, 0.125, 0.118, 0.245)
    F.box("paper", -0.10, 0.105, 0.05, 0.10, 0.114, 0.085)
    F.box("brass", -0.015, 0.114, 0.052, -0.011, 0.118, 0.083)
    for kx in (-0.14, 0.14):
        F.tube("bakelite", (kx, 0.11, 0.062), (kx, 0.132, 0.062),
               0.015, 8)


def asm_sitemodel(F, p):
    """Chipboard massing study: the Orison and its three neighbors."""
    F.box("plywood", -0.30, -0.22, 0.0, 0.30, 0.22, 0.012)
    F.box("paper", -0.27, -0.19, 0.012, 0.08, 0.19, 0.018)
    F.box("trim", -0.22, -0.13, 0.012, 0.0, 0.13, 0.20)
    F.box("trim", -0.155, -0.045, 0.20, -0.065, 0.045, 0.225)
    for bx, by, w_, d_, h_ in ((0.06, -0.16, 0.15, 0.10, 0.085),
                               (0.10, -0.02, 0.13, 0.13, 0.125),
                               (0.05, 0.13, 0.19, 0.06, 0.065)):
        F.box("timber", bx, by, 0.012, bx + w_, by + d_, 0.012 + h_)


def asm_bottles(F, p):
    """Empties colonizing a flat surface; one has already fallen over.
    cans=True swaps the long necks for short drink cans."""
    seed, n = p.get("id", "bt"), p.get("n", 5)
    m = "metal" if p.get("cans") else "glassish"
    for i in range(n - 1):
        bx = _jit(seed, i, -0.14, 0.14)
        by = _jit(seed, i + 7, -0.09, 0.09)
        if p.get("cans"):
            F.cyl(m, bx, by, 0.0, 0.13, 0.032, 0.032, 8)
        else:
            h = _jit(seed, i + 13, 0.17, 0.26)
            F.lathe(m, bx, by, [(0.031, 0.0), (0.033, h * 0.55),
                                (0.013, h * 0.72), (0.012, h)], 8)
    fx = _jit(seed, 30, -0.10, 0.10)
    F.tube(m, (fx, 0.10, 0.030), (fx + 0.19, 0.16, 0.030), 0.030, 8)


def asm_safety_barrier(F, p):
    """Cheap contractor barricade: two weighted cones and a striped rail."""
    W = p.get("W", 1.55)
    for sx in (-W / 2, W / 2):
        F.box("soot", sx - 0.18, -0.14, 0.0, sx + 0.18, 0.14, 0.045)
        F.lathe("safety_orange", sx, 0.0,
                [(0.14, 0.045), (0.11, 0.12), (0.065, 0.48),
                 (0.035, 0.58)], 10)
        F.lathe("trim", sx, 0.0, [(0.077, 0.30), (0.068, 0.39)], 10)
    F.box("safety_orange", -W / 2, -0.055, 0.64,
          W / 2, 0.055, 0.83)
    for i in range(6):
        x0 = -W / 2 + i * W / 6.0
        F.tbox("trim", (x0 + 0.11, 0.058, 0.645),
               (x0 + 0.28, 0.058, 0.825), 0.10, 0.008)
    F.hull(-W / 2 - 0.18, -0.14, 0.0, W / 2 + 0.18, 0.14, 0.84)


def asm_reno_gear(F, p):
    """Abandoned renovation cluster: ladder, paint bucket, bags and cord."""
    # Folding ladder leaning a little too casually against the work wall.
    for x in (-0.31, 0.31):
        F.tube("metal", (x, 0.10, 0.0), (x, -0.08, 1.82), 0.025, 8)
    for i in range(6):
        z = 0.24 + i * 0.25
        F.tube("metal", (-0.29, 0.075 - z * 0.10, z),
               (0.29, 0.075 - z * 0.10, z), 0.018, 8)
    # Half-dry joint compound bucket with handle.
    F.lathe("trim", 0.52, 0.02,
            [(0.16, 0.0), (0.17, 0.04), (0.15, 0.34),
             (0.14, 0.37)], 12)
    F.tube("metal", (0.37, 0.02, 0.26), (0.52, -0.10, 0.46), 0.009, 6)
    F.tube("metal", (0.52, -0.10, 0.46), (0.67, 0.02, 0.26), 0.009, 6)
    # Torn plaster bags and an unplugged extension cable.
    F.box("paper", -0.64, -0.20, 0.0, -0.18, 0.14, 0.14)
    F.box("paper", -0.56, -0.13, 0.14, -0.12, 0.12, 0.25)
    for i in range(9):
        a0, a1 = math.tau * i / 9.0, math.tau * (i + 1) / 9.0
        F.tube("safety_orange",
               (0.18 * math.cos(a0), 0.18 * math.sin(a0), 0.025),
               (0.18 * math.cos(a1), 0.18 * math.sin(a1), 0.025),
               0.012, 6)
    F.hull(-0.72, -0.24, 0.0, 0.72, 0.20, 1.84)


def asm_fire_escape(F, p):
    """Five-storey riveted iron egress tower with alternating stairs."""
    levels = p.get("levels", 5)
    dz = p.get("floor_h", 3.2)
    width, depth = p.get("W", 2.25), p.get("D", 1.18)
    for level in range(levels):
        z = dz * (level + 1)
        F.box("metal", -width / 2, 0.0, z - 0.07,
              width / 2, depth, z)
        # Perimeter guards and wall anchors.
        for x in (-width / 2, width / 2):
            F.tube("metal", (x, 0.04, z), (x, depth, z), 0.022, 6)
            F.tube("metal", (x, depth, z), (x, depth, z + 0.92), 0.025, 6)
        F.tube("metal", (-width / 2, depth, z + 0.92),
               (width / 2, depth, z + 0.92), 0.028, 6)
        F.tube("metal", (-width / 2, depth, z + 0.47),
               (width / 2, depth, z + 0.47), 0.018, 6)
        for x in (-width * 0.38, width * 0.38):
            F.tube("metal", (x, 0.0, z - 0.02),
                   (x, -0.22, z - 0.02), 0.030, 8)
        if level == 0:
            continue
        # Alternating diagonal stair flights preserve the classic zig-zag.
        flip = -1 if level % 2 else 1
        x0, x1 = flip * width * 0.34, -flip * width * 0.34
        low, high = z - dz, z
        for y in (0.22, depth - 0.22):
            F.tube("metal", (x0, y, low), (x1, y, high), 0.035, 8)
        for step in range(11):
            u = step / 10.0
            x = x0 + (x1 - x0) * u
            sz = low + (high - low) * u
            F.tube("metal", (x - 0.42, 0.20, sz),
                   (x + 0.42, depth - 0.20, sz), 0.018, 6)
    # Drop ladder and roof gooseneck.
    for x in (-0.24, 0.24):
        F.tube("metal", (x, depth, 0.15), (x, depth, dz), 0.025, 8)
        F.tube("metal", (x, depth, dz * (levels + 1) - 0.1),
               (x, depth, dz * levels), 0.025, 8)
    for i in range(10):
        z = 0.25 + i * (dz - 0.30) / 9.0
        F.tube("metal", (-0.24, depth, z), (0.24, depth, z), 0.018, 6)
    for i in range(4):
        z = dz * levels + i * dz / 3.0
        F.tube("metal", (-0.24, depth, z), (0.24, depth, z), 0.018, 6)
    # No coarse assembly hull: a single six-storey box would make the open
    # ironwork behave like an invisible solid tower. These are exterior
    # silhouette/egress evidence until a dedicated walkable fire-escape
    # collision asset replaces the batched low-overhead version.


def asm_entrance_marquee(F, p):
    """Suspended cast-iron and prismatic-glass entrance marquee, 1926.

    Researched against the type that survives all over pre-war New York -
    Grand Concourse, Riverside Drive, the Jackson Heights garden blocks.
    The apartment-house marquee is not a fabric awning on a folding arm;
    that is a shopfront. It is a structural steel tray hung off the
    facade, and every part of it is doing a job:

      LEDGER      a steel angle lag-bolted through the brick, carrying
                  the whole inner edge. Bolt heads are visible because
                  nobody hid them, and a century of rain has bled rust
                  down the brick beneath them.
      TIE RODS    two forged rods running back up to anchor rosettes
                  above, taking the outer edge in tension. Each has a
                  turnbuckle at mid-span - the fitting that let a
                  1920s ironworker take the sag out, and the fitting
                  that seizes first.
      TRAY        rolled channel perimeter with outriggers front to
                  back and cross T-bars, making a 4 x 3 grid of bays.
      GLAZING     prismatic glass set in that grid, laid to daylight
                  the entrance from above rather than to keep rain off
                  it. That is the whole point of the type and the
                  reason it earns a centrepiece: it is a lit ceiling
                  over the door. Two panes are not glass any more -
                  one plywood, one mismatched tin - because no one has
                  been able to buy a matching prismatic pane since
                  about 1955.
      FASCIA      ornamental cast iron: a bead-and-reel course under a
                  run of alternating palmette and lotus cresting, with
                  a bronze name panel dead centre.
      DRAINAGE    the deck falls to a scupper at the east end, which
                  pipes back along the tray and down the building line.
                  A downspout that emptied onto the middle of the
                  sidewalk would be a lawsuit, then and now.

    Local frame: origin sits on the facade face at the door centre, so
    the canopy projects along -y and every visible part has y < 0.
    """
    HW = 1.80            # half width, 300 mm proud of the stone surround
    PROJ = 1.80          # projection over the sidewalk
    Z_BOT, Z_TOP = 3.28, 3.46          # the structural tray
    Z_GLASS = 3.395                    # deck, inside the tray
    ANCHOR_Z = 5.08      # clear brick pier between the F02 windows

    iron, glass, bronze = "cast_iron", "glassish", "brass"

    # ---- ledger: the inner edge, bolted through the brick
    F.box(iron, -HW, -0.07, 3.26, HW, 0.0, 3.50)
    for i in range(7):
        bx = -1.56 + i * 0.52
        F.tube("metal", (bx, -0.07, 3.38), (bx, -0.115, 3.38), 0.017, 6)
    # rust bleeding out of the anchors and the ledger bolts
    for sx in (-1.0, 1.0):
        F.box("soot", sx * 1.55 - 0.055, -0.012, 4.16,
              sx * 1.55 + 0.055, 0.0, ANCHOR_Z - 0.02)
    F.box("soot", -HW + 0.10, -0.010, 2.62, HW - 0.10, 0.0, 3.26)

    # ---- tray: perimeter channel, outriggers, cross bars
    F.box(iron, -HW, -PROJ, Z_BOT, HW, -PROJ + 0.06, Z_TOP)
    F.box(iron, -HW, -PROJ, Z_BOT, -HW + 0.06, 0.0, Z_TOP)
    F.box(iron, HW - 0.06, -PROJ, Z_BOT, HW, 0.0, Z_TOP)
    for ox in (-0.90, 0.0, 0.90):
        F.box(iron, ox - 0.025, -PROJ + 0.02, 3.32, ox + 0.025, 0.0, 3.44)
    for oy in (-0.60, -1.20):
        F.box(iron, -HW + 0.04, oy - 0.02, 3.36, HW - 0.04, oy + 0.02, 3.42)

    # ---- glazing: 4 bays x 3 courses, two of them long since replaced
    bays = ((-HW + 0.06, -0.925), (-0.875, -0.025),
            (0.025, 0.875), (0.925, HW - 0.06))
    rows = ((-0.58, -0.02), (-1.18, -0.62), (-PROJ + 0.06, -1.22))
    gone = {(0, 2): "plywood", (3, 0): "metal"}
    for bi, (gx0, gx1) in enumerate(bays):
        for ri, (gy0, gy1) in enumerate(rows):
            mat = gone.get((bi, ri), glass)
            th = 0.018 if mat != glass else 0.012
            F.box(mat, gx0, gy0, Z_GLASS, gx1, gy1, Z_GLASS + th)

    # ---- fascia, bead-and-reel, cresting
    F.box(iron, -HW - 0.06, -PROJ - 0.08, 3.18, HW + 0.06, -PROJ, 3.50)
    for sx in (-1.0, 1.0):
        F.box(iron, sx * (HW + 0.06), -PROJ - 0.08, 3.18,
              sx * HW, -0.30, 3.50)
    n_bead = 25
    for i in range(n_bead):
        bx = -HW + 0.06 + (2 * HW - 0.12) * i / float(n_bead - 1)
        F.lathe(bronze, bx, -PROJ - 0.085,
                [(0.005, 3.205), (0.030, 3.232), (0.005, 3.258)], 6)
    n_crest = 15
    for i in range(n_crest):
        cx = -HW + 0.10 + (2 * HW - 0.20) * i / float(n_crest - 1)
        tall = (i % 2 == 0)
        ch = 0.17 if tall else 0.105
        # Gilded cresting. Painted iron at night is a silhouette; the
        # brass catches the trough light and gives the roofline its edge.
        F.box(bronze, cx - 0.048, -PROJ - 0.065, 3.50,
              cx + 0.048, -PROJ - 0.025, 3.50 + ch * 0.55)
        F.lathe(bronze, cx, -PROJ - 0.045,
                [(0.048, 3.50 + ch * 0.55), (0.030, 3.50 + ch * 0.85),
                 (0.0, 3.50 + ch)], 7, 0.42)

    # ---- bronze name panel, centre of the fascia
    F.box(bronze, -0.80, -PROJ - 0.115, 3.20, 0.80, -PROJ - 0.08, 3.46)
    for ex in (-0.80, 0.80):
        F.box(bronze, ex - 0.028, -PROJ - 0.125, 3.18,
              ex + 0.028, -PROJ - 0.08, 3.48)
    F.box(bronze, -0.83, -PROJ - 0.125, 3.44, 0.83, -PROJ - 0.08, 3.48)
    F.box(bronze, -0.83, -PROJ - 0.125, 3.18, 0.83, -PROJ - 0.08, 3.22)

    # ---- tie rods with turnbuckles, back to rosettes on the brick
    for sx in (-1.0, 1.0):
        rx = sx * 1.55
        F.lathe(iron, rx, -0.03,
                [(0.0, ANCHOR_Z - 0.10), (0.115, ANCHOR_Z - 0.075),
                 (0.125, ANCHOR_Z - 0.03), (0.052, ANCHOR_Z + 0.02),
                 (0.030, ANCHOR_Z + 0.075)], 12)
        top = (rx, -0.06, ANCHOR_Z)
        bot = (rx, -PROJ + 0.10, Z_TOP + 0.02)
        F.tube("metal", top, bot, 0.017, 7)
        # turnbuckle: the fitting that took the sag out, and the first
        # thing to seize solid
        def lerp(t):
            return tuple(top[k] + (bot[k] - top[k]) * t for k in range(3))
        F.tube("metal", lerp(0.40), lerp(0.60), 0.040, 6)
        F.tube("metal", lerp(0.38), lerp(0.42), 0.026, 6)
        F.tube("metal", lerp(0.58), lerp(0.62), 0.026, 6)
        # clevis where the rod picks up the tray
        F.box(iron, rx - 0.035, -PROJ + 0.06, Z_TOP - 0.02,
              rx + 0.035, -PROJ + 0.16, Z_TOP + 0.06)

    # ---- drainage: scupper east, piped back to the building line
    F.box("metal", 1.50, -PROJ - 0.02, 3.29, 1.66, -PROJ + 0.10, 3.35)
    F.tube("metal", (1.58, -PROJ + 0.10, 3.24), (1.58, -0.20, 3.24),
           0.048, 8)
    F.cyl("metal", 1.58, -0.20, 0.16, 3.26, 0.048, 0.048, 8)
    for sz in (0.90, 2.10):
        F.tube("metal", (1.50, -0.20, sz), (1.66, -0.20, sz), 0.014, 6)
    F.lathe("metal", 1.58, -0.20,
            [(0.048, 0.16), (0.070, 0.10), (0.070, 0.05)], 8)


def asm_vault_lights(F, p):
    """Sidewalk vault lights: the detail that proves there is a basement.

    Every pre-war New York building with a coal vault under its pavement
    had these - a cast-iron frame set flush in the walk, filled with
    round glass prisms that daylight the cellar below. They are the
    reason a 1920s basement has light at all before the electric went
    in, and a century of feet has worn every prism from clear to a
    bruised violet, because manganese in the old glass solarises in
    sunlight. Nobody who has walked a Manhattan side street has failed
    to see them; almost nobody models them.

    The frame sits 12 mm proud, which is what you catch your heel on.
    """
    W = p.get("W", 2.60)
    D = p.get("D", 1.15)
    iron, glass = "cast_iron", "glassish"
    hw, hd = W * 0.5, D * 0.5
    # perimeter angle, set into the concrete
    F.box(iron, -hw, -hd, -0.06, hw, hd, 0.012)
    F.box("concrete", -hw + 0.05, -hd + 0.05, -0.07,
          hw - 0.05, hd - 0.05, -0.02)
    cols, rows = 7, 3
    for i in range(cols + 1):
        x = -hw + W * i / cols
        F.box(iron, x - 0.016, -hd, -0.02, x + 0.016, hd, 0.014)
    for j in range(rows + 1):
        y = -hd + D * j / rows
        F.box(iron, -hw, y - 0.016, -0.02, hw, y + 0.016, 0.014)
    # the prisms themselves, one per cell, a few cracked out and patched
    for i in range(cols):
        for j in range(rows):
            cx = -hw + W * (i + 0.5) / cols
            cy = -hd + D * (j + 0.5) / rows
            gone = ((i * 3 + j * 5) % 11) == 4
            mat = "concrete" if gone else glass
            F.cyl(mat, cx, cy, -0.015, 0.006, 0.052, 0.052, 10)


def asm_coal_chute(F, p):
    """The cast-iron coal-hole cover, and the ring it has worn.

    Coal went into the cellar through a 460 mm hole in the pavement, shut
    with a plate whose raised diamonds were there to stop a horse
    slipping on it. The plate turns in its seat, so the seat is polished
    bright and the plate itself is dished from a century of being trodden
    into it.
    """
    r = p.get("R", 0.235)
    F.lathe("cast_iron", 0.0, 0.0,
            [(r + 0.045, -0.055), (r + 0.045, 0.004), (r + 0.010, 0.006),
             (r + 0.010, -0.050)], 24)
    F.lathe("cast_iron", 0.0, 0.0,
            [(0.0, 0.014), (r * 0.55, 0.016), (r, 0.011), (r, -0.030),
             (0.0, -0.030)], 24)
    # raised diamonds, two rings of them
    for ring, count in ((r * 0.52, 8), (r * 0.84, 13)):
        for k in range(count):
            a = 2.0 * math.pi * k / count
            dx, dy = ring * math.cos(a), ring * math.sin(a)
            F.box("cast_iron", dx - 0.022, dy - 0.022, 0.014,
                  dx + 0.022, dy + 0.022, 0.024)
    # the lifting slot
    F.box("soot", -0.055, -0.014, 0.010, 0.055, 0.014, 0.020)


def asm_utility_cover(F, p):
    """Water or gas valve box: a small square plate with a lettered boss."""
    h = p.get("S", 0.15)
    F.box("cast_iron", -h - 0.022, -h - 0.022, -0.045, h + 0.022,
          h + 0.022, 0.004)
    F.box("cast_iron", -h, -h, -0.030, h, h, 0.012)
    F.cyl("cast_iron", 0.0, 0.0, 0.012, 0.019, h * 0.55, h * 0.55, 10)


def asm_modern_boiler(F, p):
    """What replaced the coal: an oil-fired packaged steam boiler.

    When the coal plant was condemned nobody rebuilt the plant room -
    they stood a packaged boiler next to the dead one and piped it into
    the same chimney and the same steam main. That is why basements like
    this hold two boilers, one of which has not been lit since Kennedy.

    A conversion of this vintage is a sheet-metal jacket over a cast-iron
    block, with the parts that keep it legal bolted to the outside where
    an inspector can see them:
      BURNER      gun-type oil burner on the front door - motor, blower
                  scroll, ignition transformer, and the oil line coming
                  in off the floor through a filter
      DRAFT HOOD  a barometric damper again, because the chimney is the
                  same chimney
      CONTROLS    pressuretrol and aquastat in grey boxes on flex conduit
      SIGHT GLASS the water column, this one still intact, with its
                  low-water cutoff hanging off the side
      HEADER      insulated steam main leaving the top, and the Hartford
                  loop that stops the boiler emptying itself into the
                  return
    """
    jacket = p.get("jacket", "appliance")
    metal, brass, iron = "metal", "brass", "cast_iron"
    W, D, H = 0.92, 1.24, 1.48

    F.box("concrete", -W / 2 - 0.10, -D / 2 - 0.10, 0.0,
          W / 2 + 0.10, D / 2 + 0.10, 0.09)
    F.box(jacket, -W / 2, -D / 2, 0.09, W / 2, D / 2, H)
    # jacket panel seams and the maker's badge
    for sz in (0.52, 1.02):
        F.box(metal, -W / 2 - 0.006, -D / 2 - 0.006, sz,
              W / 2 + 0.006, D / 2 + 0.006, sz + 0.014)
    F.box(brass, -0.16, -D / 2 - 0.012, 1.16, 0.16, -D / 2 - 0.004, 1.28)

    # ---- gun burner on the front, and its oil line
    F.cyl(metal, 0.0, -D / 2 - 0.24, 0.44, 0.74, 0.145, 0.145, 12)
    F.tube(metal, (0.0, -D / 2 - 0.24, 0.59), (0.0, -D / 2 + 0.02, 0.59),
           0.075, 10)
    F.box(metal, -0.10, -D / 2 - 0.40, 0.50, 0.10, -D / 2 - 0.22, 0.68)
    F.box("bakelite", -0.085, -D / 2 - 0.30, 0.74, 0.085, -D / 2 - 0.14,
          0.86)                                          # ign transformer
    F.tube(metal, (0.10, -D / 2 - 0.30, 0.10), (0.10, -D / 2 - 0.30, 0.52),
           0.014, 6)
    F.cyl(metal, 0.10, -D / 2 - 0.30, 0.10, 0.30, 0.055, 0.055, 8)  # filter

    # ---- draft hood into the same chimney
    F.box(metal, -0.20, D / 2 - 0.04, H - 0.02, 0.20, D / 2 + 0.22, H + 0.26)
    F.cyl(metal, 0.0, D / 2 + 0.34, H + 0.06, H + 0.30, 0.165, 0.165, 14)
    F.tube(metal, (0.0, D / 2 + 0.34, H + 0.26),
           (0.0, D / 2 + 0.86, H + 0.26), 0.165, 14)

    # ---- controls, in grey boxes on flex conduit
    for cz, cw in ((0.92, 0.13), (1.16, 0.11)):
        F.box(metal, W / 2 + 0.01, -0.16, cz, W / 2 + 0.10, -0.16 + cw,
              cz + cw)
        F.tube(metal, (W / 2 + 0.055, -0.16 + cw * 0.5, cz),
               (W / 2 + 0.055, -0.16 + cw * 0.5, cz - 0.22), 0.011, 6)

    # ---- water column, sight glass, low-water cutoff
    F.cyl(iron, W / 2 + 0.14, 0.22, 0.66, 1.12, 0.040, 0.040, 8)
    F.cyl("glassish", W / 2 + 0.20, 0.22, 0.74, 1.04, 0.016, 0.016, 8)
    for tz in (0.76, 0.90, 1.04):
        F.cyl(brass, W / 2 + 0.14, 0.14, tz, tz + 0.026, 0.016, 0.016, 6)
    F.box(iron, W / 2 + 0.06, 0.34, 0.60, W / 2 + 0.26, 0.56, 0.78)

    # ---- steam main out of the top, lagged, and the Hartford loop
    F.tube("linen", (0.0, -0.10, H + 0.14), (0.0, D / 2 + 0.70, H + 0.14),
           0.075, 10)
    F.cyl("linen", 0.0, -0.10, H + 0.02, H + 0.20, 0.075, 0.075, 10)
    F.tube(metal, (-W / 2 - 0.10, 0.30, 0.16), (-W / 2 - 0.10, 0.30, 0.78),
           0.038, 8)
    F.tube(metal, (-W / 2 - 0.10, 0.30, 0.78), (-W / 2 - 0.10, -0.34, 0.78),
           0.038, 8)
    F.cyl(brass, -W / 2 - 0.10, -0.34, 0.78, 0.86, 0.052, 0.052, 8)
    # the service sticker somebody has been signing since 1974
    F.box("paper", -0.12, -D / 2 - 0.013, 0.94, 0.14, -D / 2 - 0.009, 1.10)


def asm_coal_furnace(F, p):
    """The original coal plant, dead since about 1961.

    A 1926 apartment house of this size burned coal in a cast-iron
    SECTIONAL steam boiler: cast sections bolted together into a barrel,
    lagged with asbestos plaster, wrapped in canvas and banded with steel
    straps. Coal went in the upper firing door onto grate bars; ash fell
    through to the pit behind the lower door; the smoke left through a
    hood at the back into a breeching pipe with a barometric damper on
    it, and so to the chimney.

    Decommissioning one is not demolition - it is abandonment in place,
    because the thing weighs four tons and the door is 900 mm wide. So
    what is left is the whole boiler with:
      - the breeching cut and the chimney thimble plated over
      - both fire doors bolted shut, not merely closed
      - the steam header's pipes cut and capped, unions hanging
      - the gauge glass broken out and the try-cocks seized
      - a condemned tag wired to the firing door and left to yellow
      - the lagging torn where somebody took a sample, showing the
        fibrous core nobody wants to talk about
    """
    iron, metal, brass = "cast_iron", "metal", "brass"
    canvas, soot = "linen", "soot"
    W, D = 1.16, 1.02
    HB = 1.62                       # top of the barrel

    # ---- hearth apron and the ash pit the boiler stands over
    F.box("concrete", -W / 2 - 0.14, -D / 2 - 0.30, 0.0,
          W / 2 + 0.14, D / 2 + 0.10, 0.10)
    F.box(iron, -W / 2, -D / 2, 0.10, W / 2, D / 2, 0.30)
    # ---- the barrel: sections, then lagging over them, then the bands
    F.box(iron, -W / 2, -D / 2, 0.30, W / 2, D / 2, HB)
    F.box(canvas, -W / 2 - 0.035, -D / 2 - 0.035, 0.40,
          W / 2 + 0.035, D / 2 + 0.035, HB - 0.08)
    for bz in (0.56, 0.94, 1.32):
        F.box(metal, -W / 2 - 0.045, -D / 2 - 0.045, bz,
              W / 2 + 0.045, D / 2 + 0.045, bz + 0.035)
    # somebody took a sample of the lagging and never patched it
    F.box(soot, -W / 2 - 0.05, -D / 2 - 0.05, 0.66,
          -W / 2 + 0.14, -D / 2 + 0.02, 0.86)

    # ---- firing door, ash door, and the bolts that shut them for good
    for (dz, dh, tag) in ((0.92, 0.40, True), (0.40, 0.26, False)):
        F.box(iron, -0.30, -D / 2 - 0.075, dz, 0.30, -D / 2 - 0.035,
              dz + dh)
        for hz in (dz + 0.05, dz + dh - 0.05):      # strap hinges
            F.box(iron, -0.33, -D / 2 - 0.085, hz - 0.022,
                  -0.05, -D / 2 - 0.030, hz + 0.022)
        # the latch, and the bolt run through it so it cannot be opened
        F.cyl(iron, 0.235, -D / 2 - 0.09, dz + dh * 0.5 - 0.05,
              dz + dh * 0.5 + 0.05, 0.030, 0.030, 8)
        F.tube(metal, (0.16, -D / 2 - 0.115, dz + dh * 0.5),
               (0.31, -D / 2 - 0.115, dz + dh * 0.5), 0.010, 6)
        if tag:
            # peep hole with its slide, and the condemned tag on a wire
            F.cyl(iron, -0.16, -D / 2 - 0.085, dz + 0.28, dz + 0.30,
                  0.048, 0.048, 10)
            F.box(metal, -0.21, -D / 2 - 0.10, dz + 0.315,
                  -0.05, -D / 2 - 0.088, dz + 0.345)
            F.tube(metal, (0.02, -D / 2 - 0.10, dz + dh * 0.5),
                   (0.02, -D / 2 - 0.10, dz + dh * 0.5 - 0.10), 0.004, 5)
            F.box("paper", -0.045, -D / 2 - 0.108, dz + dh * 0.5 - 0.22,
                  0.085, -D / 2 - 0.104, dz + dh * 0.5 - 0.10)

    # ---- smoke hood, breeching, and the plate where it was cut
    F.box(iron, -0.34, D / 2 - 0.10, HB - 0.06, 0.34, D / 2 + 0.16, HB + 0.30)
    F.cyl(metal, 0.0, D / 2 + 0.30, HB + 0.04, HB + 0.34, 0.185, 0.185, 14)
    F.tube(metal, (0.0, D / 2 + 0.30, HB + 0.30),
           (0.0, D / 2 + 0.86, HB + 0.30), 0.185, 14)
    # barometric damper: a hinged disc in its own collar
    F.cyl(metal, 0.0, D / 2 + 0.62, HB + 0.30, HB + 0.34, 0.205, 0.205, 14)
    F.box(iron, -0.13, D / 2 + 0.60, HB + 0.30, 0.13, D / 2 + 0.64,
          HB + 0.56)
    # the cut end, blanked off with a plate and four bolts
    F.box(metal, -0.21, D / 2 + 0.86, HB + 0.09, 0.21, D / 2 + 0.90,
          HB + 0.51)
    for bx in (-0.15, 0.15):
        for bz in (HB + 0.15, HB + 0.45):
            F.cyl(metal, bx, D / 2 + 0.92, bz, bz + 0.018, 0.014, 0.014, 6)

    # ---- steam header, gauge, safety valve, and the dead water column
    F.tube(metal, (-W / 2 + 0.10, -0.10, HB + 0.16),
           (W / 2 - 0.10, -0.10, HB + 0.16), 0.052, 10)
    F.cyl(brass, W / 2 - 0.16, -0.10, HB + 0.16, HB + 0.34, 0.030, 0.030, 8)
    F.lathe(brass, W / 2 - 0.16, -0.10,
            [(0.0, HB + 0.34), (0.075, HB + 0.36), (0.075, HB + 0.42),
             (0.0, HB + 0.44)], 12)                      # pressure gauge
    F.cyl(brass, -0.10, -0.10, HB + 0.16, HB + 0.40, 0.036, 0.028, 8)
    F.box(brass, -0.10, -0.24, HB + 0.36, 0.14, -0.16, HB + 0.40)
    # water column: the glass is gone, the try-cocks are seized
    F.cyl(iron, -W / 2 + 0.16, -D / 2 - 0.02, 0.86, 1.34, 0.042, 0.042, 8)
    for tz in (0.94, 1.10, 1.26):
        F.cyl(brass, -W / 2 + 0.16, -D / 2 - 0.10, tz, tz + 0.030,
              0.018, 0.018, 6)
    # feed pipe, cut short, with the union left hanging open
    F.tube(metal, (W / 2 + 0.02, 0.10, 0.62), (W / 2 + 0.02, 0.10, 1.24),
           0.030, 8)
    F.cyl(brass, W / 2 + 0.02, 0.10, 1.24, 1.30, 0.046, 0.046, 8)

    # ---- what was left standing beside it
    F.box(metal, W / 2 + 0.22, -D / 2 + 0.06, 0.0, W / 2 + 0.52,
          -D / 2 + 0.36, 0.34)                          # ash bucket
    F.tube(metal, (W / 2 + 0.24, -D / 2 + 0.10, 0.34),
           (W / 2 + 0.50, -D / 2 + 0.32, 0.34), 0.008, 5)
    F.tube("timber", (-W / 2 - 0.24, -D / 2 - 0.12, 0.0),
           (-W / 2 - 0.10, -D / 2 + 0.30, 1.24), 0.022, 7)   # shovel haft
    F.box(metal, -W / 2 - 0.20, -D / 2 - 0.10, 0.0,
          -W / 2 - 0.02, -D / 2 + 0.10, 0.05)


def asm_couch(F, p):
    """An old overstuffed sofa doing booth duty. Brief section 8.

    Four distinct modules, not four recolors: the variant changes the
    upholstery, the arm profile, the sag and the damage, because the
    Harukiya acquired its seating one dead sofa at a time. Cushions sit
    at slightly different heights and tilts - compressed foam has no
    two survivors alike - and every module's middle sits lower than its
    ends, which is where everyone always sits.
    """
    v = int(p.get("variant", 0)) % 4
    L = float(p.get("L", 1.5))
    mat = ("fabric_green", "fabric_warm", "fabric_cool", "rug_warm")[v]
    seed = p.get("id", "couch")
    D = 0.86
    # plinth and frame
    F.box("wood_dark", -L / 2, -D / 2, 0.03, L / 2, D / 2, 0.10)
    # seat deck
    F.box(mat, -L / 2, -D / 2 + 0.04, 0.10, L / 2, D / 2, 0.34)
    # seat cushions: three, unequal, the middle one flattened
    n_c = 3 if L > 1.25 else 2
    cw = (L - 0.06) / n_c
    for i in range(n_c):
        x0 = -L / 2 + 0.03 + i * cw
        sag = 0.055 if (n_c == 3 and i == 1) else _jit(seed, i, 0.0, 0.02)
        tilt = _jit(seed, i + 7, -0.008, 0.012)
        F.box(mat, x0 + 0.012, -D / 2 + 0.06, 0.34 - sag,
              x0 + cw - 0.012, D / 2 - 0.14, 0.475 - sag + tilt)
    # back: a leaning slab with loose back cushions
    F.box(mat, -L / 2, D / 2 - 0.16, 0.10, L / 2, D / 2, 0.78)
    for i in range(n_c):
        x0 = -L / 2 + 0.03 + i * cw
        lean = _jit(seed, i + 13, 0.0, 0.035)
        F.box(mat, x0 + 0.02, D / 2 - 0.26 + lean, 0.44,
              x0 + cw - 0.02, D / 2 - 0.10, 0.82 - lean)
    # arms differ by variant: rolled (lathe) on 0/1, square on 2/3
    for sx in (-1.0, 1.0):
        ax = sx * (L / 2 + 0.09)
        if v < 2:
            F.tube(mat, (sx * L / 2, -D / 2 + 0.10, 0.58),
                   (sx * L / 2 + sx * 0.17, -D / 2 + 0.10, 0.58), 0.09, 10)
            F.box(mat, min(ax, sx * L / 2), -D / 2, 0.10,
                  max(ax, sx * L / 2), D / 2, 0.56)
        else:
            F.box(mat, min(ax, sx * L / 2), -D / 2, 0.10,
                  max(ax, sx * L / 2), D / 2, 0.66)
    # damage: variant 1 has a repaired tear (timber batten under a
    # patch), variant 3 has one dead cushion showing its underside
    if v == 1:
        F.box("linen", -L * 0.18, -D / 2 + 0.055, 0.40,
              -L * 0.02, -D / 2 + 0.075, 0.47)
    if v == 3:
        F.box("linen", L * 0.12, -D / 2 + 0.06, 0.43,
              L * 0.34, D / 2 - 0.16, 0.455)
    F.hull(-L / 2 - 0.26, -D / 2, 0.0, L / 2 + 0.26, D / 2, 0.85)


def asm_arcade_cab(F, p):
    """Four late-century cabinets, four silhouettes. Brief section 9.

    Not recolors: 0 is the traditional upright, 1 the flamboyant
    late-80s shape with fins and an oversized marquee, 2 the
    music-adjacent chrome amusement, 3 the compact low unit with a
    steeply raked screen. Screens are the dark "screen" material - the
    glow is the Godot prop's job (attract mode is runtime, not
    geometry). Every cabinet gets a coin door, vents, and feet, because
    a cabinet with no coin door is furniture pretending.
    """
    v = int(p.get("variant", 0)) % 4
    body = ("metal", "fabric_cool", "chrome", "enamel")[v]
    W, D = 0.66, 0.72
    if v == 3:
        W, D = 0.60, 0.60
    H = (1.83, 1.90, 1.72, 1.45)[v]
    # carcass
    F.box(body, -W / 2, -D / 2, 0.02, W / 2, D / 2, H - (0.22 if v == 1
          else 0.0))
    # feet
    for fx in (-W / 2 + 0.06, W / 2 - 0.06):
        for fy in (-D / 2 + 0.06, D / 2 - 0.06):
            F.cyl("bakelite", fx, fy, 0.0, 0.03, 0.025, 0.025, 8)
    # control panel wedge on the front (front = -y)
    F.box("bakelite_black", -W / 2 + 0.02, -D / 2 - 0.13,
          (0.92, 0.95, 0.88, 0.72)[v],
          W / 2 - 0.02, -D / 2 + 0.02, (1.02, 1.06, 0.97, 0.80)[v])
    # buttons and stick
    for i in range(3):
        F.cyl("terracotta" if i == 0 else "enamel",
              -W / 2 + 0.16 + i * 0.12, -D / 2 - 0.065,
              (1.02, 1.06, 0.97, 0.80)[v],
              (1.035, 1.075, 0.985, 0.815)[v], 0.016, 0.016, 8)
    F.cyl("bakelite_black", -W / 2 + 0.13, -D / 2 - 0.09,
          (1.02, 1.06, 0.97, 0.80)[v],
          (1.10, 1.14, 1.05, 0.88)[v], 0.008, 0.008, 6)
    # screen: recessed dark glass, raked harder on the compact unit
    sz0 = (1.10, 1.14, 1.02, 0.84)[v]
    sz1 = (1.48, 1.55, 1.38, 1.12)[v]
    F.box("bakelite_black", -W / 2 + 0.03, -D / 2 - 0.02, sz0 - 0.04,
          W / 2 - 0.03, -D / 2 + 0.06, sz1 + 0.04)
    F.box("screen", -W / 2 + 0.06, -D / 2 - 0.005, sz0,
          W / 2 - 0.06, -D / 2 + 0.005, sz1)
    # marquee
    if v == 1:
        # the flamboyant one: fins and a lit-header oversize marquee
        F.box("milk_glass", -W / 2 - 0.05, -D / 2 - 0.06, H - 0.22,
              W / 2 + 0.05, -D / 2 + 0.10, H)
        for sx in (-1.0, 1.0):
            F.box("terracotta", sx * (W / 2 + 0.045) - 0.015,
                  -D / 2, 0.55, sx * (W / 2 + 0.045) + 0.015,
                  D / 2 - 0.10, H - 0.10)
    elif v != 3:
        F.box("milk_glass", -W / 2 + 0.02, -D / 2 - 0.03, H - 0.16,
              W / 2 - 0.02, -D / 2 + 0.05, H - 0.02)
    # coin door low on the front
    F.box("brass", -0.09, -D / 2 - 0.012, 0.38, 0.09, -D / 2, 0.55)
    F.cyl("bakelite_black", 0.0, -D / 2 - 0.02, 0.44, 0.455,
          0.012, 0.012, 8)
    # side vents (louvre slits)
    for i in range(4):
        F.box("bakelite_black", W / 2 - 0.005, D / 2 - 0.30,
              0.30 + i * 0.05, W / 2 + 0.005, D / 2 - 0.12,
              0.315 + i * 0.05)
    F.hull(-W / 2 - 0.06, -D / 2 - 0.14, 0.0, W / 2 + 0.06,
           D / 2, H)


def asm_jukebox(F, p):
    """The hero music machine. Brief section 10: tacky, impressive,
    expensive when new, badly dated now, lovable. Rounded chrome crown
    over a lit sign, brass mesh grille below, a rank of selection
    buttons - and it still works, which in this bar is a character
    trait."""
    W, D, H = 0.92, 0.62, 1.58
    F.box("wood_dark", -W / 2, -D / 2, 0.02, W / 2, D / 2, 0.55)
    F.box("chrome", -W / 2, -D / 2, 0.55, W / 2, D / 2, 0.62)
    # grille: brass mesh face in a chrome surround
    F.box("brass_mesh", -W / 2 + 0.08, -D / 2 - 0.008, 0.12,
          W / 2 - 0.08, -D / 2, 0.50)
    # body rising to the crown
    F.box("enamel", -W / 2, -D / 2, 0.62, W / 2, D / 2, 1.06)
    # the lit sign band
    F.box("milk_glass", -W / 2 + 0.05, -D / 2 - 0.02, 1.06,
          W / 2 - 0.05, -D / 2 + 0.04, 1.26)
    # rounded crown, lathe half-drum along x approximated by cyl slices
    F.lathe("chrome", 0.0, 0.0,
            [(W * 0.28, 1.26), (W * 0.46, 1.34), (W * 0.5, 1.44),
             (W * 0.42, 1.54), (W * 0.2, 1.58), (0.001, 1.585)], 16)
    # selection buttons: two ranks of bakelite
    for r_i in range(2):
        for i in range(8):
            F.box("bakelite", -W / 2 + 0.10 + i * 0.09,
                  -D / 2 - 0.02, 0.80 - r_i * 0.075,
                  -W / 2 + 0.16 + i * 0.09, -D / 2, 0.845 - r_i * 0.075)
    # window over the mechanism
    F.box("glassish", -W / 2 + 0.10, -D / 2 - 0.005, 0.88,
          W / 2 - 0.10, -D / 2 + 0.005, 1.04)
    F.hull(-W / 2 - 0.04, -D / 2 - 0.05, 0.0, W / 2 + 0.04, D / 2, H)


def asm_coal_heap(F, p):
    """What is left in the bunker: a heap, not a box.

    The coal pile was a rectangular block of the SLAB material - grey
    concrete, in the shape of a crate. Coal does not stack; it slumps to
    its angle of repose, which for broken anthracite is about 27 degrees.
    So this is a low mound with a scatter of loose lumps at its foot,
    black and dusty, sitting on the bunker floor where the last delivery
    ran out.
    """
    W = p.get("W", 1.0)
    D = p.get("D", 1.8)
    H = p.get("H", 0.62)
    steps = 5
    for i in range(steps):
        t = float(i) / steps
        F.box("soot", -W * 0.5 * (1.0 - t * 0.72), -D * 0.5 * (1.0 - t * 0.55),
              H * t, W * 0.5 * (1.0 - t * 0.72), D * 0.5 * (1.0 - t * 0.55),
              H * (t + 1.0 / steps))
    # lumps that rolled off the toe of the heap
    for k in range(9):
        a = 2.0 * math.pi * ((k * 97) % 360) / 360.0
        r = W * 0.52 + (k % 3) * 0.09
        lx = math.cos(a) * r
        ly = math.sin(a) * (D * 0.52 + (k % 2) * 0.08)
        sz = 0.035 + ((k * 31) % 5) * 0.012
        F.box("soot", lx - sz, ly - sz, 0.0, lx + sz, ly + sz, sz * 1.6)


ASM = {
    "couch": asm_couch, "arcade_cab": asm_arcade_cab,
    "jukebox": asm_jukebox,
    "sofa": asm_sofa, "chair": asm_chair, "table_round": asm_table_round,
    "table_rect": asm_table_rect, "coffee": asm_coffee,
    "nightstand": asm_nightstand, "bed": asm_bed, "wardrobe": asm_wardrobe,
    "shelf": asm_shelf, "tv": asm_tv, "plant": asm_plant,
    "kitchen": asm_kitchen,
    "desk": asm_desk, "plantable": asm_plantable,
    "workbench": asm_workbench, "toilet": asm_toilet,
    "switch": asm_switch,
    "pipe": asm_pipe, "bench": asm_bench, "mailbank": asm_mailbank,
    "amp": asm_amp, "guitar": asm_guitar, "pedalboard": asm_pedalboard,
    "micstand": asm_micstand, "reeldeck": asm_reeldeck,
    "headphones": asm_headphones, "mug": asm_mug,
    "dishrack": asm_dishrack, "papers": asm_papers,
    "bookpile": asm_bookpile, "pinboard": asm_pinboard,
    "toolboard": asm_toolboard, "partstray": asm_partstray,
    "jarrow": asm_jarrow, "tripod": asm_tripod, "softbox": asm_softbox,
    "cablecoil": asm_cablecoil, "crate": asm_crate, "radio": asm_radio,
    "sitemodel": asm_sitemodel, "bottles": asm_bottles,
    "safety_barrier": asm_safety_barrier, "reno_gear": asm_reno_gear,
    "fire_escape": asm_fire_escape,
    "entrance_marquee": asm_entrance_marquee,
    "vault_lights": asm_vault_lights,
    "coal_chute": asm_coal_chute,
    "utility_cover": asm_utility_cover,
    "coal_furnace": asm_coal_furnace,
    "modern_boiler": asm_modern_boiler,
    "coal_heap": asm_coal_heap,
    "watering_can": asm_watering_can,
}


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


def build_wall(buf, w, trim_buf=None, glass_buf=None, wains_buf=None,
               stone_buf=None, ao_buf=None, fl=None):
    """Wall run with openings, thickness centered on the a->b line.
    Door openings get jamb/head trim; windows get a frame, sill lip and a
    collidable glass pane. Detail pass (unless details=False): baseboards
    and a top cornice on both faces, plus a wainscot band with dado cap on
    walls flagged wainscot (corridors, cores, stairwell).
    """
    ax, ay = w["a"]
    bx, by = w["b"]
    z, h, t = w["z"], w["h"], w["t"]
    horizontal = abs(by - ay) < 1e-6
    length = abs((bx - ax) if horizontal else (by - ay))
    start = min(ax, bx) if horizontal else min(ay, by)
    cross = ay if horizontal else ax

    def box(bf, d0, d1, z0, z1, tt):
        if horizontal:
            bf.add_box((start + d0, cross - tt / 2, z + z0),
                       (start + d1, cross + tt / 2, z + z1))
        else:
            bf.add_box((cross - tt / 2, start + d0, z + z0),
                       (cross + tt / 2, start + d1, z + z1))

    def side_box(bf, d0, d1, z0, z1, side, depth=0.02):
        c2 = cross + side * (t / 2 + depth / 2)
        if horizontal:
            bf.add_box((start + d0, c2 - depth / 2, z + z0),
                       (start + d1, c2 + depth / 2, z + z1))
        else:
            bf.add_box((c2 - depth / 2, start + d0, z + z0),
                       (c2 + depth / 2, start + d1, z + z1))

    def seg_box(d0, d1, z0, z1):
        box(buf, d0, d1, z0, z1, t)

    details = w.get("details", True) and h > 2.0 and trim_buf is not None
    wains = w.get("wainscot", False) and wains_buf is not None
    is_brick = w["mat"] in ("face_brick", "common_brick", "brick",
                            "concrete")

    def detail_seg(d0, d1):
        """Baseboard/wainscot on a stretch of wall between doors,
        plus a floor AO gradient strip on both faces — the corner
        darkening a path tracer would give the wall/floor junction."""
        if d1 - d0 < 0.05 or not details:
            return
        if is_brick and w.get("in_side"):
            # exterior masonry is furred and plastered on the inside only,
            # so its baseboard runs on the interior face
            side_box(trim_buf, d0, d1, 0.0, 0.11, w["in_side"], 0.036)
        else:
            box(trim_buf, d0, d1, 0.0, 0.11, t + 0.036)
        if wains:
            # The dado runs to 1.32 and a borrow light sills at 1.05, so
            # the board crossed the bottom of every aperture on the hall
            # side. Under one, it stops at the sill.
            dado_top = 1.32
            for o2 in openings:
                if not o2.get("decorative_alcove"):
                    continue
                od0 = o2["at"] - o2["w"] * 0.5
                od1 = o2["at"] + o2["w"] * 0.5
                if d0 < od1 and d1 > od0:
                    dado_top = min(dado_top, float(o2.get("sill", 1.32)))
            # A tiled dado belongs to the wet room only: bathroom walls
            # record which face is the bath, and the band goes on that
            # side alone so the bedroom next door keeps its plaster.
            dado_side = w.get("wains_side")
            if dado_side:
                side_box(wains_buf, d0, d1, 0.11, dado_top, dado_side,
                         0.024)
            else:
                box(wains_buf, d0, d1, 0.11, dado_top, t + 0.022)
            # A bordered composition cannot be tiled. The lobby marble
            # source carries a moulded panel edge down two sides, so
            # running it along a wall under scalar world UVs prints that
            # moulding through the middle of the run, where no moulding
            # exists. Lay it as what it physically is - discrete panels,
            # each mapped 0..1 - and the border lands on a panel edge.
            if w.get("wains_mat") == "marble_lobby":
                span = d1 - d0
                n_panels = max(1, int(round(span / 0.86)))
                lift = 0.024 if dado_side else 0.011
                for pi in range(n_panels):
                    p0 = d0 + span * pi / n_panels
                    p1 = d0 + span * (pi + 1) / n_panels
                    for sgn in ((dado_side,) if dado_side else (1, -1)):
                        pf = cross + sgn * (t / 2 + lift + 0.004)
                        if horizontal:
                            pts = ((start + p0, pf, z + 0.11),
                                   (start + p1, pf, z + 0.11),
                                   (start + p1, pf, z + dado_top),
                                   (start + p0, pf, z + dado_top))
                        else:
                            pts = ((pf, start + p0, z + 0.11),
                                   (pf, start + p1, z + 0.11),
                                   (pf, start + p1, z + dado_top),
                                   (pf, start + p0, z + dado_top))
                        wains_buf.add_quad_uv(*pts, (0.0, 0.0), (1.0, 0.0),
                                              (1.0, 1.0), (0.0, 1.0))
            box(trim_buf, d0, d1, dado_top, dado_top + 0.04, t + 0.040)
            # A small bullnose bead catches a soft highlight and makes the
            # dado read as installed millwork instead of a razor-edged box.
            # Run it on both wall faces so corridor and room views agree.
            #
            # It rides on dado_top, NOT on a constant. It was pinned at
            # 1.355 - which is 1.32 + 0.035, the default dado read off a
            # wall with no alcove in it - so wherever the rail stepped
            # down to an alcove sill the bead stayed up at full height
            # and hung in the air with daylight under it. A chair rail
            # is nailed to the top of the panelling; it goes where the
            # panelling goes.
            bead_z = dado_top + 0.035
            a0, a1 = start + d0, start + d1
            for sgn in (-1, 1):
                face = cross + sgn * (t / 2.0 + 0.031)
                if horizontal:
                    trim_buf.add_tube((a0, face, z + bead_z),
                                      (a1, face, z + bead_z), 0.024, 8)
                else:
                    trim_buf.add_tube((face, a0, z + bead_z),
                                      (face, a1, z + bead_z), 0.024, 8)
        if ao_buf is None:
            return
        # A contact-shadow strip belongs to a wall/floor junction, and a
        # perimeter wall only has one of those - the inside. Drawn on
        # both faces it hung a 20 mm band right around the outside of the
        # building at every storey line, 160 mm proud of the brick: the
        # dark horizontal bars ruled across the facade in a grid matching
        # the floors, straight through the tenant's neon. The baseboard
        # two blocks up already knew this and asked in_side; the strip
        # never did.
        sides = (w["in_side"],) if w.get("in_side") else (1, -1)
        for sgn in sides:
            face = cross + sgn * (t / 2.0 + 0.02)
            outer = face + sgn * 0.14
            a0, a1 = start + d0, start + d1
            # Each side of a wall can face a different finish - terrazzo
            # corridor one side, ceramic bathroom the other - so the strip
            # is levelled per face rather than per wall.
            mid = (a0 + a1) * 0.5
            sx, sy = (mid, outer) if horizontal else (outer, mid)
            zq = z + finish_at(fl, sx, sy) + 0.002
            if horizontal:
                pts = [(a1, face), (a0, face), (a0, outer), (a1, outer)]                         if sgn < 0 else                         [(a0, face), (a1, face), (a1, outer), (a0, outer)]
                ao_buf.add_quad((pts[0][0], pts[0][1], zq),
                                (pts[1][0], pts[1][1], zq),
                                (pts[2][0], pts[2][1], zq),
                                (pts[3][0], pts[3][1], zq))
            else:
                pts = [(face, a0), (face, a1), (outer, a1), (outer, a0)]                         if sgn < 0 else                         [(face, a1), (face, a0), (outer, a0), (outer, a1)]
                ao_buf.add_quad((pts[0][0], pts[0][1], zq),
                                (pts[1][0], pts[1][1], zq),
                                (pts[2][0], pts[2][1], zq),
                                (pts[3][0], pts[3][1], zq))

    openings = sorted(w["openings"], key=lambda o: o["at"])
    cursor = 0.0
    d_cursor = 0.0
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
        if o["type"] == "door" or o["sill"] <= 0.0:
            detail_seg(d_cursor, d0)      # skirting stops at door reveals
            d_cursor = d1
        if trim_buf is not None:
            surround = stone_buf if (is_brick and stone_buf is not None)                     else trim_buf
            ft = t + 0.04
            if o["type"] == "door":
                box(surround, d0, d0 + 0.05, 0.0, top, ft)
                box(surround, d1 - 0.05, d1, 0.0, top, ft)
                box(surround, d0, d1, top, top + 0.06, ft)
            elif o.get("decorative_alcove"):
                # A borrow light is a hole cut between the stair and the
                # corridor, not a window onto anything. It was being
                # dressed as one: jambs, a head, a sill board projecting
                # 5 cm into the hall, and a soldier lintel over it. All
                # of that is gone. What lines the aperture is what
                # really would - the plaster returning into the reveal
                # on all four sides, and nothing else.
                for zz0, zz1 in ((o["sill"], o["sill"] + 0.018),
                                 (top - 0.018, top)):
                    box(trim_buf, d0, d1, zz0, zz1, t - 0.004)
                for dd0, dd1 in ((d0, d0 + 0.018), (d1 - 0.018, d1)):
                    box(trim_buf, dd0, dd1, o["sill"], top, t - 0.004)
            else:
                box(surround, d0, d0 + 0.06, o["sill"], top, ft)
                box(surround, d1 - 0.06, d1, o["sill"], top, ft)
                box(surround, d0, d1, top - 0.06, top, ft)
                # projecting sill (limestone on masonry)
                box(surround, max(d0 - 0.04, 0.0), min(d1 + 0.04, length),
                    o["sill"] - 0.04, o["sill"] + 0.02, t + 0.10)
                if is_brick:  # soldier-course lintel proud of the face
                    box(buf, d0 - 0.02, d1 + 0.02, top + 0.06,
                        min(top + 0.26, h), t + 0.05)
                if glass_buf is not None and not o.get("decorative_alcove"):
                    box(glass_buf, d0 + 0.05, d1 - 0.05, o["sill"] + 0.05,
                        top - 0.05, 0.02)
                    # 1-over-1 double-hung meeting rail
                    box(surround, d0 + 0.04, d1 - 0.04,
                        o["sill"] + (top - o["sill"]) * 0.5 - 0.02,
                        o["sill"] + (top - o["sill"]) * 0.5 + 0.02,
                        t + 0.05)
        cursor = d1
    if cursor < length:
        seg_box(cursor, length, 0.0, h)
    detail_seg(d_cursor, length)
    # Crown moulding belongs to the ceiling plane, not the door schedule.
    # It therefore spans lintels continuously while baseboard and dado stop
    # at the jambs. The old shared detail interval punched door-width gaps
    # into this runner throughout the building.
    if details:
        if is_brick and w.get("in_side"):
            side_box(trim_buf, 0.0, length, h - 0.07, h,
                     w["in_side"], 0.030)
        else:
            box(trim_buf, 0.0, length, h - 0.07, h, t + 0.030)


def build_baked_wall_finish(target, w, side):
    """One continuous, uniquely baked finish over a room-facing wall.

    Openings are subtracted geometrically, but every remaining rectangle uses
    coordinates from the same wall-wide 0..1 texture. This prevents windows
    from stretching a fresh copy of the image into each lintel and sill.
    """
    ax, ay = w["a"]
    bx, by = w["b"]
    z, h, t = w["z"], w["h"], w["t"]
    horizontal = abs(by - ay) < 1e-6
    length = abs((bx - ax) if horizontal else (by - ay))
    start = min(ax, bx) if horizontal else min(ay, by)
    cross = ay if horizontal else ax
    rects = [(0.0, 0.0, length, h)]
    for opening in w.get("openings", []):
        d0 = max(0.0, opening["at"] - opening["w"] * .5)
        d1 = min(length, opening["at"] + opening["w"] * .5)
        z0 = opening.get("sill", 0.0)
        z1 = min(h, z0 + opening["h"])
        rects = subtract_rect(rects, (d0, z0, d1, z1))
    face = cross + side * (t * .5 + .006)
    for d0, z0, d1, z1 in rects:
        if horizontal:
            pts = ((start + d0, face, z + z0),
                   (start + d1, face, z + z0),
                   (start + d1, face, z + z1),
                   (start + d0, face, z + z1))
        else:
            pts = ((face, start + d0, z + z0),
                   (face, start + d1, z + z0),
                   (face, start + d1, z + z1),
                   (face, start + d0, z + z1))
        target.add_quad_uv(*pts,
                           (d0 / length, z0 / h),
                           (d1 / length, z0 / h),
                           (d1 / length, z1 / h),
                           (d0 / length, z1 / h))


def build_stripped_wall_finish(plaster_buf, wallpaper_buf, damp_buf, w,
                               sides=(-1, 1)):
    """Cause-shaped historic finish failure on the inside of masonry.

    Damage is evaluated in continuous wall coordinates. Rising damp makes an
    uneven tide line; a high leak makes a narrow wandering wet path; movement
    starts diagonal loss at opening corners; broad detached islands bridge
    those causes. Wallpaper follows real roll widths and can exist only where
    plaster survives. The fine tessellation is merely geometry resolution --
    it never decides damage independently, so there is no random checkerboard.
    """
    ax, ay = w["a"]
    bx, by = w["b"]
    z, h, t = w["z"], w["h"], w["t"]
    horizontal = abs(by - ay) < 1e-6
    length = abs((bx - ax) if horizontal else (by - ay))
    start = min(ax, bx) if horizontal else min(ay, by)
    cross = ay if horizontal else ax
    openings = w.get("openings", [])
    seed = int(round((ax + 31.0) * 17 + (ay + 37.0) * 29
                     + (bx + 41.0) * 11 + (by + 43.0) * 7
                     + (z + 5.0) * 13))

    def covered_by_opening(d0, d1, z0, z1):
        for opening in openings:
            od0 = opening["at"] - opening["w"] * 0.5
            od1 = opening["at"] + opening["w"] * 0.5
            oz0 = opening.get("sill", 0.0)
            oz1 = oz0 + opening["h"]
            if d0 < od1 and d1 > od0 and z0 < oz1 and z1 > oz0:
                return True
        return False

    def face_quad(target, d0, d1, z0, z1, side, lift):
        face = cross + side * (t * 0.5 + lift)
        if horizontal:
            pts = [(start + d0, face, z + z0),
                   (start + d1, face, z + z0),
                   (start + d1, face, z + z1),
                   (start + d0, face, z + z1)]
        else:
            pts = [(face, start + d0, z + z0),
                   (face, start + d1, z + z0),
                   (face, start + d1, z + z1),
                   (face, start + d0, z + z1)]
        if side < 0:
            pts.reverse()
        target.add_quad(*pts)

    phase = (seed % 97) / 97.0 * math.tau
    leak_u = 0.68 + ((seed // 7) % 17) / 100.0
    island_u = 0.28 + ((seed // 11) % 35) / 100.0

    def tide(u):
        """Nonuniform capillary/rising-damp loss, strongest at the floor."""
        return 0.075 + 0.052 * (math.sin(u * 8.2 + phase) * 0.5 + 0.5) \
            + 0.030 * (math.sin(u * 21.0 + phase * 0.7) * 0.5 + 0.5)

    def leak_center(v):
        # A leak follows gravity but meanders at cracks and mortar joints.
        return leak_u + math.sin(v * 12.0 + phase) * 0.018 \
            + math.sin(v * 31.0 + phase * 0.4) * 0.008

    def opening_corner_loss(u, v):
        """Diagonal settlement cracks and detached shoulders at openings."""
        for opening in openings:
            center = opening["at"] / max(length, 0.001)
            half = opening["w"] * 0.5 / max(length, 0.001)
            top = (opening.get("sill", 0.0) + opening["h"]) / max(h, 0.001)
            for corner, direction in ((center - half, -1.0),
                                      (center + half, 1.0)):
                # Crack rises and travels away from the opening corner.
                run = max(0.0, v - top)
                line_u = corner + direction * run * 0.58
                width = 0.012 + run * 0.075
                if run < 0.34 and abs(u - line_u) < width:
                    return True
                # Loss fans below the crack where the plaster key detached.
                du = (u - (corner + direction * 0.055)) / 0.115
                dv = (v - (top - 0.075)) / 0.16
                if du * du + dv * dv < 1.0:
                    return True
        return False

    def plaster_missing(u, v):
        # 1. Ground moisture: connected, never evenly sprinkled.
        if v < tide(u):
            return True
        # 2. One high leak: narrow stain above, plaster failure where water
        # accumulates lower down and beside the pipe/radiator zone.
        wet_width = 0.022 + max(0.0, 0.62 - v) * 0.095
        if v < 0.60 and abs(u - leak_center(v)) < wet_width:
            return True
        # 3. Structural movement anchored to actual openings.
        if opening_corner_loss(u, v):
            return True
        # 4. One broad delamination island bridges cracks/damp. Its wobbled
        # ellipse yields the large connected silhouette seen in the target.
        du = (u - island_u) / 0.17
        dv = (v - 0.27) / 0.19
        wobble = 0.86 + 0.10 * math.sin(u * 29.0 + phase) \
            + 0.07 * math.sin(v * 37.0 - phase)
        return du * du + dv * dv < wobble

    def wallpaper_present(u, v):
        # Historic rolls create broad vertical fields with real aligned seams.
        metres = u * length
        roll = int(math.floor((metres + (seed % 19) * 0.031) / 0.61))
        in_roll = (metres + (seed % 19) * 0.031) % 0.61
        if in_roll < 0.012 or in_roll > 0.598:  # lifted/open roll seam
            return False
        if (roll * 7 + seed) % 10 >= 4:         # many rolls already stripped
            return False
        # Paper fails before plaster at damp edges and down the leak path.
        if v < tide(u) + 0.10:
            return False
        if abs(u - leak_center(v)) < 0.055 + max(0.0, 0.72 - v) * 0.04:
            return False
        # Alternating torn lower edge avoids a ruler-straight surviving roll.
        torn_edge = 0.18 + ((roll * 13 + seed) % 9) * 0.018
        return v > torn_edge

    def moisture_stain(u, v):
        # Stain extends beyond material loss, coherently crossing paper and
        # plaster. High leak tracks and low tide marks share one overlay.
        if v < tide(u) + 0.11:
            return True
        width = 0.035 + max(0.0, 0.90 - v) * 0.035
        return v < 0.94 and abs(u - leak_center(v)) < width

    cell_w, cell_h = 0.18, 0.16
    cols = max(1, int(math.ceil(length / cell_w)))
    rows = max(1, int(math.ceil(h / cell_h)))
    for ci in range(cols):
        d0, d1 = ci * length / cols, (ci + 1) * length / cols
        for ri in range(rows):
            z0, z1 = ri * h / rows, (ri + 1) * h / rows
            if covered_by_opening(d0, d1, z0, z1):
                continue
            u = ((d0 + d1) * 0.5) / max(length, 0.001)
            v = ((z0 + z1) * 0.5) / max(h, 0.001)
            missing = plaster_missing(u, v)
            for side in sides:
                if not missing:
                    face_quad(plaster_buf, d0, d1, z0, z1, side, 0.011)
                if not missing and wallpaper_present(u, v):
                    face_quad(wallpaper_buf, d0, d1, z0, z1, side, 0.017)
                if moisture_stain(u, v):
                    face_quad(damp_buf, d0, d1, z0, z1, side, 0.021)


# room kind -> floor finish overlay (material, thickness). Nested rooms
# (bathrooms, D offices) get a slightly thicker overlay so surfaces stack
# instead of z-fighting the host room's boards.
KIND_FLOOR = {
    "corridor": ("terrazzo", 0.012), "hall": ("terrazzo", 0.012),
    # The lobby was never in this table, so the building's showpiece
    # floor rendered as bare slab. The atrium ring walks on the same
    # terrazzo, as the 1920s intended.
    "lobby": ("terrazzo", 0.012), "atrium": ("terrazzo", 0.012),
    "living": ("floor_oak", 0.012), "bedroom": ("floor_oak", 0.012),
    "alcove": ("floor_oak", 0.012),
    # Boards. The linoleum is not the room's floor - it is a bound
    # square laid over the boards under the run (see _lino_field in
    # gen_layout). Flooring the whole room in it was wrong: most of
    # these kitchens are a corner of a living room.
    "kitchen": ("floor_oak", 0.012),
    "closet": ("floor_oak", 0.012), "vestibule": ("floor_oak", 0.012),
    "common": ("floor_oak", 0.012),
    "office": ("floor_oak", 0.016),
    "bathroom": ("ceramic", 0.020),
    # The west suite kept its boards when it became storage - nobody
    # relays a floor to stack crates on it. Without this the room
    # rendered as bare structural slab, which is what made it read as
    # unfinished geometry.
    "storage": ("floor_oak", 0.012),
    "utility": ("concrete", 0.012),
}


def finish_at(fl, x, y):
    """Thickness of the floor finish under a plan point.

    Everything painted on the floor - wall AO strips, contact shadows,
    wear decals - used to be authored against the bare slab and lifted
    clear of the thickest finish in the building (bathroom ceramic, 20
    mm) so it could never z-fight. In a corridor, whose terrazzo is 12
    mm, that left the decal floating 12-16 mm in the air. Opaque, lit on
    its upper face, and running the length of every wall and straight
    across every threshold, it read as a kerb: the hump at the bottom of
    doorways and open archways.

    Painted-on things now ask what they are painted on.
    """
    if not fl:
        return 0.0
    for r in fl.get("rooms", ()):
        x0, y0, x1, y1 = r["rect"]
        if x0 <= x <= x1 and y0 <= y <= y1:
            spec = KIND_FLOOR.get(r["kind"])
            return spec[1] if spec else 0.0
    return 0.0


def build_floor_overlay(buf, fid, fl, r):
    spec = KIND_FLOOR.get(r["kind"])
    if spec is None:
        return
    mat, th = spec
    z = fl["z"]
    rects = [tuple(r["rect"])]
    if r["kind"] == "corridor":  # ring only: the whole core column is
        rects = subtract_rect(rects, (-3.43, -6.93, 3.43, 6.93))
    # A floor finish may never cover a hole in its own slab. This used to
    # be done for corridors and halls only, so the moment the atrium and
    # lobby were given a finish they paved the light well and the stair
    # opening - the floor rendered straight across the void the stairs
    # rise through.
    for hole in fl["slabs"][0]["holes"]:
        rects = subtract_rect(rects, tuple(hole))
    for (x0, y0, x1, y1) in rects:
        # A floor finish is one upward face. The old box also drew an
        # underside (buried in the slab, free to z-fight) and four edge
        # walls, six faces where the eye can only ever see one.
        buf(fid, "floors_%s" % mat, mat).add_quad(
            (x0, y0, z + th), (x1, y0, z + th),
            (x1, y1, z + th), (x0, y1, z + th))


def build_ceiling_overlay(buf, fid, face):
    """One generator-owned, downward ceiling face.

    These used to be inferred only for the core while the flats borrowed the
    slab above. Keeping the semantic faces in layout data makes ownership
    assertable before Blender and keeps every same-finish face in one buffer.
    """
    x0, y0, x1, y1 = face["rect"]
    ztop = float(face["z"])
    mat = face.get("mat", "plaster")
    # Reversed winding: this face looks DOWN into the room.
    buf(fid, "ceiling_%s" % mat, mat).add_quad(
        (x0, y1, ztop), (x1, y1, ztop),
        (x1, y0, ztop), (x0, y0, ztop))


def build_vent_register(buf, fid, register):
    """A passive 1928 stamped-steel ceiling register, not a little fan.

    Twenty-three scripted owners would be the most expensive way to model a
    hole in a duct.  Bars from every bathroom share the floor's trim buffer;
    only the four motors on the roof remain FunctionalProps.
    """
    x, y, z = map(float, register["pos"])
    half, rim, depth = 0.17, 0.035, 0.022
    frame = buf(fid, "vent_register_trim", "trim")
    throat = buf(fid, "vent_register_throat", "cast_iron")
    screws = buf(fid, "vent_register_screws", "brass_dull")
    # A dark shallow box behind real gaps reads as duct depth without cutting
    # the ceiling mesh or adding a collision surface above the player's head.
    throat.add_box((x - half + rim, y - half + rim, z - 0.008),
                   (x + half - rim, y + half - rim, z - 0.003))
    for mn, mx in (
            ((x - half, y - half, z - depth),
             (x + half, y - half + rim, z)),
            ((x - half, y + half - rim, z - depth),
             (x + half, y + half, z)),
            ((x - half, y - half + rim, z - depth),
             (x - half + rim, y + half - rim, z)),
            ((x + half - rim, y - half + rim, z - depth),
             (x + half, y + half - rim, z))):
        frame.add_box(mn, mx)
    # Louver pitch alternates with the stack's run, breaking the building-
    # wide ceiling grid while leaving the same cheap stamped fitting.
    across_x = int(register.get("yaw_deg", 0)) % 180 == 0
    for i in range(5):
        offset = -0.10 + i * 0.05
        if across_x:
            frame.add_box((x - 0.115, y + offset - 0.010, z - 0.030),
                          (x + 0.115, y + offset + 0.010, z - 0.012))
        else:
            frame.add_box((x + offset - 0.010, y - 0.115, z - 0.030),
                          (x + offset + 0.010, y + 0.115, z - 0.012))
    for sx, sy in ((-1, -1), (-1, 1), (1, -1), (1, 1)):
        screws.add_box((x + sx * 0.137 - 0.008,
                        y + sy * 0.137 - 0.008, z - 0.034),
                       (x + sx * 0.137 + 0.008,
                        y + sy * 0.137 + 0.008, z - 0.028))


# ---------------------------------------------------------------- stair
# The balustrade is the one assembly every resident touches twice a day
# and the player climbs seven times, so it is built as joinery rather
# than as a fence. Prewar New York apartment stairs pair a wrought-iron
# balustrade with a moulded hardwood handrail: the iron is cheap to
# repeat and impossible to burn, the rail is what the hand wants. Both
# have been repainted often enough that the paint is part of the
# profile.
#
# Everything here is modelled the way it was made, because the missing
# engineering is what made the old boxes read as a fence: balusters sit
# in a shoe rail with a cast collar at each foot, the handrail is a real
# moulded section rather than a bar, newels are through-bolted to a
# plinth with the nut and washer showing, and every rail-to-newel joint
# carries the plugged access hole of a handrail bolt.

HANDRAIL_W = 0.062          # a hand closes on 60-65 mm
HANDRAIL_H = 0.052
SHOE_H = 0.038
BAL_PITCH = 0.115           # 4 1/2 inch centres: no 100 mm sphere passes


def _handrail_section(rail, a0, a1, z0, z1, cross, axis, mat_buf=None):
    """A moulded handrail, not a bar.

    Four courses make the section read: a wide fillet under the hand, the
    swelled body, a narrow bead each side, and the undercut groove the
    fingers actually curl into. Cheap in triangles, and it is the
    difference between a handrail and a plank.
    """
    def band(w, zlo, zhi):
        if axis == "y":
            rail.add_ramp(a0, z0 + zlo, a1, z1 + zlo,
                          cross - w * 0.5, cross + w * 0.5,
                          thickness=(zhi - zlo), axis="y")
        else:
            rail.add_ramp(a0, z0 + zlo, a1, z1 + zlo,
                          cross - w * 0.5, cross + w * 0.5,
                          thickness=(zhi - zlo), axis="x")
    band(HANDRAIL_W * 0.74, 0.0, 0.012)          # fillet under the hand
    band(HANDRAIL_W, 0.012, 0.040)               # the swelled body
    band(HANDRAIL_W * 0.86, 0.040, HANDRAIL_H)   # crowned top
    band(HANDRAIL_W * 0.42, -0.016, 0.0)         # the finger undercut


def _baluster(bal, brass, x, y, z0, z1):
    """One iron baluster: square die, turned vase, twisted centre, collar.

    The die at each end is what a real baluster is mortised by; the
    collar is the cast shoe that hides the joint, and it is the detail
    whose absence made the old 36 mm sticks read as dowels.
    """
    h = z1 - z0
    bal.add_box((x - 0.017, y - 0.017, z0), (x + 0.017, y + 0.017,
                                             z0 + 0.075))
    bal.add_lathe(x, y, [(0.019, z0 + 0.075), (0.029, z0 + 0.105),
                         (0.023, z0 + 0.150), (0.013, z0 + 0.205)], 10)
    # twisted centre: a square bar given a quarter turn per 120 mm
    twist = max(2, int((h - 0.36) / 0.06))
    for k in range(twist):
        za = z0 + 0.205 + k * (h - 0.36) / twist
        zb = z0 + 0.205 + (k + 1) * (h - 0.36) / twist
        bal.add_cyl(x, y, za, zb, 0.0135, 0.0135, 4,
                    phase=k * 0.39)
    bal.add_lathe(x, y, [(0.013, z1 - 0.155), (0.023, z1 - 0.110),
                         (0.029, z1 - 0.070), (0.019, z1 - 0.045)], 10)
    bal.add_box((x - 0.017, y - 0.017, z1 - 0.045),
                (x + 0.017, y + 0.017, z1))
    # cast collar at the foot, where the iron enters the shoe rail
    brass.add_lathe(x, y, [(0.030, z0 + 0.004), (0.033, z0 + 0.016),
                           (0.024, z0 + 0.030)], 10)


def _newel(rail, brass, metal, x, y, z0, top):
    """A gallery newel: plinth, moulded base, turned shaft, capped.

    Through-bolted to the plinth with the washer and nut left showing,
    which is how these were actually fixed and the first thing missing
    from a box.
    """
    rail.add_box((x - 0.075, y - 0.075, z0), (x + 0.075, y + 0.075,
                                              z0 + 0.09))
    rail.add_lathe(x, y, [(0.075, z0 + 0.09), (0.082, z0 + 0.115),
                          (0.062, z0 + 0.165)], 12)
    rail.add_box((x - 0.058, y - 0.058, z0 + 0.165),
                 (x + 0.058, y + 0.058, top - 0.135))
    rail.add_lathe(x, y, [(0.058, top - 0.135), (0.079, top - 0.100),
                          (0.070, top - 0.062), (0.050, top - 0.040)], 12)
    rail.add_box((x - 0.085, y - 0.085, top - 0.040),
                 (x + 0.085, y + 0.085, top))
    # brass ball finial and its neck
    brass.add_lathe(x, y, [(0.030, top), (0.050, top + 0.036),
                           (0.030, top + 0.070), (0.010, top + 0.082)], 12)
    # the fixing: square washer and hex nut, two sides of the plinth
    for sx_, sy_ in ((1, 0), (0, 1)):
        metal.add_box((x + sx_ * 0.070 - 0.016, y + sy_ * 0.070 - 0.016,
                       z0 + 0.030),
                      (x + sx_ * 0.078 + 0.016, y + sy_ * 0.078 + 0.016,
                       z0 + 0.062))
        metal.add_cyl(x + sx_ * 0.081, y + sy_ * 0.081, z0 + 0.038,
                      z0 + 0.054, 0.011, 0.011, 6)


def _rail_bolt_plug(brass, x, y, z, axis):
    """The plugged access hole of a handrail bolt.

    Every joint between a rail length and a newel is drawn together by a
    bolt through a pocket cut in the underside, then plugged. The plug is
    the visible evidence that the rail is jointed rather than extruded -
    a small disc, and the whole reason the assembly reads as built.
    """
    if axis == "y":
        brass.add_cyl(x, y, z - 0.004, z + 0.004, 0.011, 0.011, 8)
    else:
        brass.add_cyl(x, y, z - 0.004, z + 0.004, 0.011, 0.011, 8)


def _wall_bracket(metal, brass, x, y, z, facing):
    """Cast wall bracket for the far-side rail, with its two screws."""
    metal.add_box((x - 0.028, y - 0.010, z - 0.048),
                  (x + 0.028, y + 0.010, z + 0.010))
    metal.add_cyl(x, y + facing * 0.030, z - 0.020, z + 0.006,
                  0.016, 0.022, 10)
    for dz in (-0.036, 0.000):
        brass.add_cyl(x, y - 0.004, z + dz, z + dz + 0.006, 0.006, 0.006, 6)


def _rail_line(buf, fid, gx0, gx1, yc, z):
    """Level balustrade along X: handrail, newels, balusters + fall guard."""
    rail = buf(fid, "stairs_rail", "handrail_wood")
    bal = buf(fid, "stairs_bal", "baluster")
    brass = buf(fid, "stairs_brass", "brass")
    metal = buf(fid, "stairs_iron", "metal")
    guard = buf(fid, "stairs_guard-colonly", "stair")
    top = z + 0.92
    # shoe rail: the moulded base the balusters are mortised into
    rail.add_box((gx0 - 0.02, yc - 0.030, z),
                 (gx1 + 0.02, yc + 0.030, z + SHOE_H))
    _handrail_section(rail, gx0 - 0.06, gx1 + 0.06, top, top, yc, "x")
    _newel(rail, brass, metal, gx0 - 0.075, yc, z, top)
    _newel(rail, brass, metal, gx1 + 0.075, yc, z, top)
    # the plugged handrail bolt at each newel joint
    for nx in (gx0 - 0.02, gx1 + 0.02):
        _rail_bolt_plug(brass, nx, yc + 0.031, top + 0.026, "x")
    span = gx1 - gx0
    k = max(4, int(span / BAL_PITCH))
    for j in range(k):
        xj = gx0 + (j + 0.5) * span / k
        _baluster(bal, brass, xj, yc, z + SHOE_H, top)
    guard.add_box((gx0 - 0.13, yc - 0.03, z), (gx1 + 0.13, yc + 0.03, z + 1.0))


# The tread sheet is six treads stacked top to bottom in one image;
# each tread takes one band. EPS keeps a hair of margin so a band never
# bleeds the neighbouring tread's grime line into its own nosing.
TREAD_BANDS = 6
TREAD_EPS = 0.0016
# Set True if a render shows the grime band along the FRONT edge of the
# treads instead of the back. Verified False.
TREAD_V_FLIP = False

# Which end of the tread map faces down-flight. VERIFIED IN ENGINE at
# 0.0 - do not "correct" it by reading the source, read this first.
#
# The source's grimy banded edge is NOT the nosing, which is the trap
# here. It is the back corner where the tread meets the riser above it:
# the band feathers forward into the tread field with drip streaks, the
# way filth packs into a corner and gets swept onward. A nosing is the
# one strip of a stair that feet scuff CLEAN - it never cakes like that.
# So the image's top edge is the riser junction and its clean, lightly
# scuffed bottom edge is the nose.
#
# Blender's UV origin is bottom-left and the glTF exporter flips v, so
# which end that lands on is not something to reason out - it was
# checked on a render. Flip to 1.0 only if a render shows the grime
# band along the front edge of the treads.
NOSING_V = 0.0


def _flight(buf, part):
    """One dog-leg flight along Y: thin waist slab + treads, walk ramp, raked
    balustrade on the well side, wall rail on the other, fall guard."""
    fid = floor_for_z(part["z0"] + 0.01)
    vis = buf(fid, "stairs", "stair")
    ramp = buf(fid, "stairs_ramp-colonly", "stair")
    rail = buf(fid, "stairs_rail", "handrail_wood")
    bal = buf(fid, "stairs_bal", "baluster")
    brass = buf(fid, "stairs_brass", "brass")
    metal = buf(fid, "stairs_iron", "metal")
    guard = buf(fid, "stairs_guard-colonly", "stair")
    treads = buf(fid, "stairs_treads", "stair_treads")
    n, rise, tread = part["n"], part["rise"], part["tread"]
    s, d = part["start"], part["dir"]
    flight_seed = zlib.crc32(
        ("%s|%.3f|%.3f" % (fid, part["z0"], part["start"])).encode()) % 97
    b0, b1, z0 = part["b0"], part["b1"], part["z0"]
    # Visible construction is a constant-depth inclined waist slab, matching
    # the 180 mm landing fascia.  The old boxes all extended down to z0,
    # producing a giant wedge that intruded into the landing below.
    a_end = s + d * (n - 1) * tread
    vis.add_ramp(s, z0 - 0.01, a_end, z0 + (n - 1) * rise - 0.01,
                 b0, b1, thickness=0.18, axis="y")
    # The waist's underside runs 0.19 below the flight's own start height,
    # so the foot of every flight buried itself in the floor it lands on —
    # the bottom treads read as sinking into the ground rather than
    # standing on it. A closer fills that wedge back up to floor level, the
    # way a real bottom riser sits on the slab.
    foot_a0 = min(s, s + d * 1.6 * tread)
    foot_a1 = max(s, s + d * 1.6 * tread)
    vis.add_box((b0, foot_a0, z0 - 0.19), (b1, foot_a1, z0))
    for i in range(1, n):
        a0 = s + d * (i - 1) * tread
        a1 = s + d * i * tread
        top = z0 + i * rise
        # Thin tread plates overlap the waist slab just enough to close the
        # saw-tooth silhouette without rebuilding a solid triangular mass.
        vis.add_box((b0, min(a0, a1), top - 0.065),
                    (b1, max(a0, a1), top))
        # The tread top gets its OWN 0..1 map.
        #
        # The stair source is a composition, not a tiling swatch: it is
        # one tread, with the grimed riser junction along one edge and
        # the dish that a century of feet wore into the middle of it.
        # Under the scalar world projection every tread sampled whatever
        # slice of that image its world position happened to land on, so
        # the grime band ran across the middle of some treads and missed
        # others entirely. Mapped per tread it lands in the corner it
        # came from, and the dish lands where people actually walk.
        ya, yb = min(a0, a1), max(a0, a1)
        # Which of the six treads on the sheet this one wears. The flight
        # seed decorrelates one flight from the next, so the same
        # sequence does not march up the whole building; +i then walks
        # the sheet so no two treads in a row match.
        k = (flight_seed + i) % TREAD_BANDS
        v_front = 1.0 - float(k + 1) / TREAD_BANDS + TREAD_EPS
        v_back = 1.0 - float(k) / TREAD_BANDS - TREAD_EPS
        if TREAD_V_FLIP:
            v_front, v_back = v_back, v_front
        # a0 is the down-flight (nosing) edge whichever way the flight
        # runs, so orient off it rather than off min/max.
        v_ya, v_yb = ((v_front, v_back) if a0 <= a1
                      else (v_back, v_front))
        tz = top + 0.002
        treads.add_quad_uv((b0, ya, tz), (b1, ya, tz),
                           (b1, yb, tz), (b0, yb, tz),
                           (0.0, v_ya), (1.0, v_ya),
                           (1.0, v_yb), (0.0, v_yb))
    ramp.add_ramp(s, z0, a_end, z0 + n * rise, b0, b1, axis="y")
    xr = b1 - 0.045 if part["rail_side"] == "hi" else b0 + 0.045
    xw = b0 + 0.055 if part["rail_side"] == "hi" else b1 - 0.055
    for i in range(1, n):
        for frac in (0.72, 0.28):   # two per tread, real balustrade rhythm
            am = s + d * (i - frac) * tread
            zb = z0 + i * rise
            _baluster(bal, brass, xr, am, zb + SHOE_H - 0.012,
                      zb + 0.92)
    # raked shoe rail under the balusters, and the moulded rail over them
    rail.add_ramp(s, z0 + 0.86, a_end, z0 + n * rise + 0.86,
                  xr - 0.030, xr + 0.030, thickness=SHOE_H, axis="y")
    _handrail_section(rail, s, a_end, z0 + 0.92, z0 + n * rise + 0.92,
                      xr, "y")
    # the wall-side rail is carried on cast brackets, not floating
    _handrail_section(rail, s, a_end, z0 + 0.87, z0 + n * rise + 0.87,
                      xw, "y")
    for bi in range(1, max(2, n // 3)):
        ba = s + d * bi * 3.0 * tread
        bz = z0 + bi * 3.0 * rise + 0.87
        if min(s, a_end) <= ba <= max(s, a_end):
            _wall_bracket(metal, brass, xw, ba, bz - 0.03,
                          1.0 if xw < xr else -1.0)
    guard.add_ramp(s, z0 + 0.95, a_end, z0 + n * rise + 0.95,
                   xr - 0.03, xr + 0.03, thickness=0.95, axis="y")
    na = s + d * 0.06  # starting newel; landing rails own the tops
    _newel(rail, brass, metal, xr, na, z0, z0 + 0.98)
    _rail_bolt_plug(brass, xr + 0.031, na + d * 0.09, z0 + 0.95, "y")


# The paving flag lives in the middle 66% of its source; the outer 17%
# on each edge is a sliver of the neighbouring stones, and sampling it
# would print a joint across the middle of a flag that has none.
FLAG_UV0, FLAG_UV1 = 0.17, 0.83


def build_sidewalk_flag(buf, fid, fu, r, z0):
    """One paving flag, wearing one stone.

    The walk was world-projected, so the source's own joint lines fell
    wherever the world grid happened to put them - across the middle of
    flags, missing the actual gaps between them. Two joint systems, one
    real and one printed, disagreeing.

    Now the GEOMETRY owns the joints (the gaps between these boxes are
    the joints, and the grout material shows through them) and the
    TEXTURE owns the stone: each flag samples the single complete flag
    out of the middle of the source.

    Each flag also takes one of four quarter turns, chosen by a stable
    hash of its id. A paving gang lays stones as they come off the
    pallet, and without this every flag in the street carries the same
    crack in the same corner.
    """
    body = buf(fid, "furniture_sidewalk_kerb-col", "concrete")
    body.add_box((r[0], r[1], z0), (r[2], r[3], z0 + fu["h"] - 0.004))
    top = buf(fid, "furniture_sidewalk_haunted", "sidewalk_haunted")
    zt = z0 + fu["h"]
    uv = [(FLAG_UV0, FLAG_UV0), (FLAG_UV1, FLAG_UV0),
          (FLAG_UV1, FLAG_UV1), (FLAG_UV0, FLAG_UV1)]
    turns = zlib.crc32(str(fu.get("id", "")).encode()) % 4
    uv = uv[turns:] + uv[:turns]
    top.add_quad_uv((r[0], r[1], zt), (r[2], r[1], zt),
                    (r[2], r[3], zt), (r[0], r[3], zt), *uv)


def build_framed_picture(buf, fid, fu, r, z0):
    """One picture off the nine-cell art sheet, not all nine at once.

    "art" is unit-mapped, so every framed picture in the building showed
    the WHOLE texture. With a single painting that meant the same
    painting sixty-seven times; with a nine-cell sheet it would have
    meant all nine crushed into every frame. Neither is a picture.

    So each frame takes one cell, chosen by a stable hash of its own id -
    stable because crc32 is not salted, so the painting in 3B does not
    move between builds. The panel is emitted as a dark frame box with
    the picture laid on BOTH thin faces: which way a frame points depends
    on its wall, and a second quad costs one draw against the certainty
    of never hanging a picture face-inwards.
    """
    frame = buf(fid, "furniture_wood_dark-col", "wood_dark")
    frame.add_box((r[0], r[1], z0), (r[2], r[3], z0 + fu["h"]))
    k = zlib.crc32(str(fu.get("id", "")).encode()) % 9
    col, row = k % 3, k // 3
    sp = 1.0 / 3.0
    u0, u1 = col * sp, (col + 1) * sp
    v0, v1 = 1.0 - (row + 1) * sp, 1.0 - row * sp
    pic = buf(fid, "furniture_art", "art")
    thin_y = (r[3] - r[1]) < (r[2] - r[0])
    e = 0.004
    for sgn in (1, -1):
        if thin_y:
            f = (r[3] + e) if sgn > 0 else (r[1] - e)
            pts = [(r[0], f, z0), (r[2], f, z0),
                   (r[2], f, z0 + fu["h"]), (r[0], f, z0 + fu["h"])]
        else:
            f = (r[2] + e) if sgn > 0 else (r[0] - e)
            pts = [(f, r[1], z0), (f, r[3], z0),
                   (f, r[3], z0 + fu["h"]), (f, r[1], z0 + fu["h"])]
        if sgn < 0:
            pts = [pts[1], pts[0], pts[3], pts[2]]
        pic.add_quad_uv(*pts, (u0, v0), (u1, v0), (u1, v1), (u0, v1))


def build_stair(buf, st):
    for part in st["parts"]:
        if part["kind"] == "flight":
            _flight(buf, part)
        elif part["kind"] == "landing":
            # decks (floor-level arrivals) carry no guard fields; the
            # per-level eye guard below covers their open edge
            is_deck = "guard_span" not in part
            fid = floor_for_z(part["z"] + (0.01 if is_deck else -0.5))
            r = part["rect"]
            # A landing is a floor, not a tread: it is laid, not
            # dished, and it wears differently because people turn on
            # it rather than climb it. Separate material so the two can
            # be textured apart.
            for b in (buf(fid, "stairs_landing", "landing"),
                      buf(fid, "stairs_ramp-colonly", "stair")):
                b.add_box((r[0], r[1], part["z"] - 0.18),
                          (r[2], r[3], part["z"]))
            if part.get("soffit_finish"):
                # Three millimetres below the structural landing: enough to
                # avoid z-fighting, far too shallow to read as the black cavity
                # made by the rejected failed-plaster pass. Unit UVs put the
                # unique scan across this one soffit exactly once.
                z_soffit = part["z"] - 0.183
                finish = buf(fid, "stairs_soffit_failed",
                             part["soffit_finish"])
                uv = ((1, 1), (0, 1), (0, 0), (1, 0)) \
                    if part.get("soffit_flip") else \
                    ((0, 1), (1, 1), (1, 0), (0, 0))
                finish.add_quad_uv(
                    (r[0], r[3], z_soffit), (r[2], r[3], z_soffit),
                    (r[2], r[1], z_soffit), (r[0], r[1], z_soffit), *uv)
            if not is_deck:
                gx0, gx1 = part["guard_span"]
                yc = r[1] + 0.055 if part["guard_edge"] == "s" \
                        else r[3] - 0.055
                _rail_line(buf, fid, gx0, gx1, yc, part["z"])
    # the open well's eye gets a guard at every floor it passes
    inward = -1 if st["entry_side"] == "s" else 1
    yc = st["entry_y"] + inward * 0.055
    gx0, gx1 = st["gap_span"]
    for name, z in st["levels"][1:]:
        _rail_line(buf, name, gx0, gx1, yc, z)


## Simulated wear, placed where life happens: threshold scuffs at every
## hinged door, traffic sheen down the corridor desire lines, drip
## staining under every radiator, grease halos behind every range, and
## the 5D burn fanning up its walls. These are positioned decal quads
## (unit UVs, alpha textures) — the spatial damage the tile-global
## overlay pass can't express.

def ceiling_at(fl, x, y):
    """Height of the plaster ceiling over a plan point.

    The sibling of finish_at, and it exists for the same reason: painted-on
    things should ask what they are painted on. Ceiling wear was authored
    against a hard-coded `z + 3.0` while ceiling_pass actually puts the
    plaster at `above - SLAB_T - 0.005`. On F01-F06 that is 3.015, so the
    decal hung 15 mm below its own ceiling. In B1 the ceiling is only 2.615
    above the floor, so `z + 3.0` put the decal 385 mm ABOVE the plaster --
    inside the slab, invisible, and not obviously broken from any station
    anyone ever shot.
    """
    if not fl:
        return 3.015
    best = None
    best_area = None
    for c in fl.get("ceilings", []):
        r = c.get("rect")
        if not r or len(r) < 4:
            continue
        if x < r[0] or x > r[2] or y < r[1] or y > r[3]:
            continue
        area = (r[2] - r[0]) * (r[3] - r[1])
        if best_area is None or area < best_area:
            best_area = area
            best = float(c.get("z", 0.0))
    if best is not None:
        return best - float(fl.get("z", 0.0))
    # No ceiling record over this point. The layout carries the generator's
    # own constants in its meta block, so read them rather than restate them
    # -- restating them is how three conventions came to exist.
    meta = LAYOUT.get("meta", {}) if isinstance(LAYOUT, dict) else {}
    f2f = float(meta.get("floor_to_floor", 3.20))
    slab = float(meta.get("slab_t", 0.18))
    return f2f - slab - 0.005


def build_wear_decals(buf, fl):
    fid = fl["id"]
    z = fl["z"]

    def floor_quad(mat, x0, y0, x1, y1):
        # 6 mm over the finish this quad lands on: clear of the wall AO
        # strip (2 mm) and the contact shadows (4 mm), but no longer a
        # step you can see across a threshold.
        zq = finish_at(fl, (x0 + x1) * 0.5, (y0 + y1) * 0.5) + 0.006
        buf(fid, "wear_" + mat, mat).add_quad(
            (x0, y0, z + zq), (x1, y0, z + zq),
            (x1, y1, z + zq), (x0, y1, z + zq))

    def _in_a_room(x, y):
        for r in fl.get("rooms", []):
            x0, y0, x1, y1 = r["rect"]
            if (min(x0, x1) <= x <= max(x0, x1)
                    and min(y0, y1) <= y <= max(y0, y1)):
                return True
        return False

    def wall_quad(mat, p0, p1, z0, z1):
        b = buf(fid, "wear_" + mat, mat)
        # Make the decal face the room.
        #
        # The winding came from whatever corner order each caller found
        # convenient, while the OFFSET was computed properly from the
        # wall's in_side. So on every wall whose interior face is on the
        # negative side, the stain sat in exactly the right place facing
        # backwards - and because fx_ materials are deliberately
        # double-sided, you saw its back face, lit from behind, which
        # renders BLACK with the texture's alpha still cutting the blob
        # shape. That is what the punchlist's "white decal quads" had
        # become: pure black holes punched in the plaster.
        #
        # Rather than thread a facing argument through six call sites and
        # rely on each staying correct, ask the geometry: step off the
        # quad along its own normal and see whether that lands in a room.
        nx, ny = (p1[1] - p0[1]), -(p1[0] - p0[0])
        ln = math.hypot(nx, ny) or 1.0
        nx, ny = nx / ln, ny / ln
        mx = (p0[0] + p1[0]) * 0.5
        my = (p0[1] + p1[1]) * 0.5
        if not _in_a_room(mx + nx * 0.30, my + ny * 0.30):
            p0, p1 = p1, p0
        b.add_quad((p0[0], p0[1], z + z0), (p1[0], p1[1], z + z0),
                   (p1[0], p1[1], z + z1), (p0[0], p0[1], z + z1))

    def ceiling_quad(mat, x0, y0, x1, y1, drop=0.018):
        """Down-facing translucent damage just below the plaster ceiling."""
        b = buf(fid, "wear_ceiling_" + mat, mat)
        zc = z + ceiling_at(fl, (x0 + x1) * 0.5, (y0 + y1) * 0.5) - drop
        b.add_quad((x0, y0, zc), (x0, y1, zc),
                   (x1, y1, zc), (x1, y0, zc))

    BEHIND = {90: (-1, 0), -90: (1, 0), 0: (0, -1), 180: (0, 1),
              45: (-0.7, -0.7), 135: (0.7, -0.7)}
    for m in fl["markers"]:
        if m["kind"] == "door" and m.get("leaf") != "none":
            px, py = m["pos"][0], m["pos"][1]
            w = m["w"]
            if m["yaw_deg"] == 0:
                floor_quad("fx_scuff", px - 0.1, py - 0.45,
                           px + w + 0.1, py + 0.45)
            else:
                floor_quad("fx_scuff", px - 0.45, py - 0.1 - w,
                           px + 0.45, py + 0.1)
        elif m["kind"] == "radiator":
            dx, dy = BEHIND.get(m["yaw_deg"], (0, -1))
            wx = m["pos"][0] + dx * 0.27
            wy = m["pos"][1] + dy * 0.27
            half = (abs(dy) * 0.5, abs(dx) * 0.5)
            wall_quad("fx_drip", (wx - half[0], wy - half[1]),
                      (wx + half[0], wy + half[1]), 0.08, 0.75)
    # Condensation and failed exterior seals leave vertical blooms below
    # windows.  Offset the quad just proud of one face to avoid z-fighting.
    for w in fl["walls"]:
        ax, ay = w["a"]
        bx, by = w["b"]
        horizontal = abs(by - ay) < 1e-6
        start = min(ax, bx) if horizontal else min(ay, by)
        cross = ay if horizontal else ax
        # Condensation blooms below a window form on the room side. This
        # always picked the + face, which is indoors for the south and
        # west runs and out on the street for the north and east ones.
        drip_side = w.get("in_side") or 1
        face = cross + drip_side * (w["t"] / 2.0 + 0.004)
        for o in w["openings"]:
            if o.get("type") != "window" or o.get("sill", 0.0) < 0.25 \
                    or o.get("decorative_alcove"):
                continue
            c = start + o["at"]
            hw = min(0.42, o["w"] * 0.34)
            if horizontal:
                wall_quad("fx_drip", (c - hw, face), (c + hw, face),
                          0.08, o["sill"] + 0.04)
            else:
                wall_quad("fx_drip", (face, c + hw), (face, c - hw),
                          0.08, o["sill"] + 0.04)
    # The complete range is marker-built now. Grease stays a Blender decal
    # because it belongs to the WALL behind the appliance, but its position
    # follows the same marker as the runtime shell instead of a deleted
    # furniture entry.
    for m in fl.get("markers", []):
        if m.get("kind") == "stove":
            import math as _m
            a = _m.radians(m.get("yaw_deg", 0))
            fx_, fy_ = -_m.sin(a), _m.cos(a)     # local +y in world
            wx = m["pos"][0] - fx_ * 0.36
            wy = m["pos"][1] - fy_ * 0.36
            half = (abs(fy_) * 0.45, abs(fx_) * 0.45)
            wall_quad("fx_grease", (wx - half[0], wy - half[1]),
                      (wx + half[0], wy + half[1]), 0.95, 1.90)
    # Old plumbing announces itself overhead. Wet rooms get small irregular
    # blooms; the top occupied floor carries broader roof-leak ghosts, while
    # basement service rooms collect darker condensation around pipe routes.
    wet_i = 0
    for r in fl["rooms"]:
        if r["kind"] not in ("bathroom", "kitchen", "laundry", "boiler"):
            continue
        x0, y0, x1, y1 = r["rect"]
        cx = (x0 + x1) * 0.5 + ((wet_i % 3) - 1) * 0.17
        cy = (y0 + y1) * 0.5 + ((wet_i % 2) * 2 - 1) * 0.13
        rx = min(0.72, max(0.32, (x1 - x0) * 0.22))
        ry = min(0.58, max(0.28, (y1 - y0) * 0.18))
        ceiling_quad("fx_drip", cx - rx, cy - ry, cx + rx, cy + ry)
        wet_i += 1
    if fid == "F06":
        for cx, cy, rx, ry in ((-10.8, -5.7, 1.15, 0.72),
                               (8.9, 4.4, 0.95, 0.62),
                               (0.8, 7.7, 0.82, 0.48)):
            ceiling_quad("fx_drip", cx - rx, cy - ry, cx + rx, cy + ry)
    elif fid == "B1":
        for cx, cy, rx, ry in ((-9.8, 1.4, 1.2, 0.58),
                               (8.5, -4.2, 1.0, 0.52),
                               (1.2, 5.8, 0.8, 0.42)):
            ceiling_quad("fx_grease", cx - rx, cy - ry, cx + rx, cy + ry)
    if fid != "B1":   # corridor ring traffic sheen
        for r in ((-4.83, -6.55, -3.93, 6.55), (3.93, -6.55, 4.83, 6.55),
                  (-4.4, -8.75, 4.4, -7.85), (-4.4, 7.85, 4.4, 8.75),
                  (-1.65, -6.7, -0.75, -3.35)):
            floor_quad("fx_traffic", *r)
        floor_quad("fx_traffic", -1.61, -3.11, 1.61, -1.51)  # deck lane
    if fid == "F05":  # the 5D fire: soot fans up the bedroom walls
        wall_quad("fx_burn", (13.44, -9.2), (13.44, -6.6), 0.15, 2.85)
        wall_quad("fx_burn", (10.9, -9.62), (13.4, -9.62), 0.15, 2.85)


def build_facade_details(buf):
    """Roof cornice band and the street entry portal."""
    cor = buf("F06", "cornice", "concrete")
    zc = 18.86
    cor.add_box((-14.12, -10.12, zc), (14.12, -9.70, zc + 0.38))
    cor.add_box((-14.12, 9.70, zc), (14.12, 10.12, zc + 0.38))
    cor.add_box((-14.12, -10.12, zc), (-13.70, 10.12, zc + 0.38))
    cor.add_box((13.70, -10.12, zc), (14.12, 10.12, zc + 0.38))
    # skylight cap over the atrium monitor: glass on steel ribs
    sky = buf("ROOF", "skylight-col", "glassish")
    sky.add_box((-3.40, -3.40, 21.77), (3.40, 3.40, 21.81))
    rib = buf("ROOF", "skyribs", "metal")
    for rx in (-2.2, 0.0, 2.2):
        rib.add_box((rx - 0.035, -3.40, 21.73), (rx + 0.035, 3.40, 21.77))
    rib.add_box((-3.46, -3.46, 21.70), (3.46, -3.34, 21.83))
    rib.add_box((-3.46, 3.34, 21.70), (3.46, 3.46, 21.83))
    rib.add_box((-3.46, -3.46, 21.70), (-3.34, 3.46, 21.83))
    rib.add_box((3.34, -3.46, 21.70), (3.46, 3.46, 21.83))
    # Rainwater goods and roof penetrations make the shell read as a working
    # building rather than a sealed model.  Downpipes stop just above grade;
    # roof vents vary in height and diameter but remain deliberately simple.
    pipes = buf("F01", "facade_rainwater", "metal")
    for x in (-13.58, 13.58):
        pipes.add_tube((x, -9.86, 0.18), (x, -9.86, 18.82), 0.055, 10)
        pipes.add_tube((x, 9.86, 0.18), (x, 9.86, 18.82), 0.055, 10)
    vents = buf("ROOF", "roof_vents", "metal")
    for x, y, r, h in ((-8.4, -2.8, 0.13, 0.85),
                       (7.6, 3.2, 0.11, 0.65),
                       (10.5, -5.5, 0.18, 1.05),
                       (-4.8, 6.1, 0.10, 0.55)):
        vents.add_cyl(x, y, 19.24, 19.24 + h, r, r, 12)
        vents.add_cyl(x, y, 19.22 + h, 19.30 + h, r * 1.35, r * 1.05, 12)


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
    # Blender 5.2's glTF operator currently ignores its public log-level
    # property unless the global debug level supplies the logger setting.
    # ERROR keeps actionable exporter failures while omitting the known,
    # harmless shared-sampler diagnostic for RGBA decal color/alpha sockets.
    bpy.app.debug_value = 2
    scene = bpy.context.scene
    root_col = bpy.data.collections.new("ORISON")
    scene.collection.children.link(root_col)

    floor_cols = {}
    bufs = {}

    # Alternate finishes up the building.
    #
    # Every storey drew from one texture per material, so the corridor on
    # F05 was the same wall as the corridor on F02 down to the crack, and
    # a player climbing the stair passed the same photograph six times.
    # Where a second generator's take exists it ingests as "<mat>_b";
    # hand it to every other storey. Keyed off the storey's index rather
    # than a hash of its name, because what actually reads as repetition
    # is two ADJACENT floors matching, and an index guarantees they never
    # do. UV mode is still resolved from the BASE material - an alt is
    # the same surface, so it projects the same way.
    STOREY_IDX = {lvl: i for i, (lvl, _z) in enumerate(LEVEL_ORDER)}

    def variant(fid, mat):
        # Cycle the whole synthesized family up the building, not just a
        # parity pick of _b: with up to four variants, adjacent storeys
        # never match and the repeat period is the building's height.
        fam = [mat] + [mat + sfx for sfx in ("_b", "_c", "_d")
                       if (mat + sfx) in CAT_TEX]
        if len(fam) == 1:
            return mat
        return fam[STOREY_IDX.get(fid, 0) % len(fam)]

    def buf(fid, cat, mat):
        key = (fid, cat)
        if key not in bufs:
            if mat.startswith("wallfinish_") or mat in EXPLICIT_MATS:
                mode = "explicit"
            elif mat.startswith("fx_") or UV_MODE_BY_MAT.get(mat) == "unit":
                mode = "unit"
            else:
                mode = "world"
            bufs[key] = MeshBuf("%s_%s" % (fid, cat),
                                variant(fid, mat), mode)
            bufs[key].rooms = ROOMS_BY_FLOOR.get(fid, [])
        return bufs[key]

    for fl in LAYOUT["floors"]:
        fid = fl["id"]
        col = bpy.data.collections.new(fid)
        root_col.children.link(col)
        floor_cols[fid] = col
        for s in fl["slabs"]:
            # inset slightly so flush facades hide the slab edge
            r_ = s["rect"]
            s = dict(s, rect=[r_[0] + 0.03, r_[1] + 0.03, r_[2] - 0.03,
                              r_[3] - 0.03])
            rects = [tuple(s["rect"])]
            for hole in s["holes"]:
                rects = subtract_rect(rects, tuple(hole))
            for (x0, y0, x1, y1) in rects:
                buf(fid, "slabs-col", "slab").add_box(
                    (x0, y0, s["z_top"] - s["t"]), (x1, y1, s["z_top"]))
        for w in fl["walls"]:
            cat = {"brick": "walls_brick-col",
                   "face_brick": "walls_fbrick-col",
                   "common_brick": "walls_cbrick-col",
                   "concrete": "walls_conc-col"}.get(w["mat"], "walls-col")
            # Construction and finish are no longer conflated: partitions
            # export as plaster/drywall; only true perimeter masonry can show
            # brick through a damaged room-facing finish.
            build_wall(buf(fid, cat, w["mat"]), w,
                       buf(fid, "trim", "trim"),
                       buf(fid, "glazing-col", "glassish"),
                       buf(fid, "wainscot_%s" % w.get("wains_mat",
                                                       "wainscot"),
                           w.get("wains_mat", "wainscot")),
                       buf(fid, "stone_trim-col", "limestone"),
                       buf(fid, "fx_ao_decal", "fx_ao"), fl)
            if w["mat"] in ("brick", "common_brick", "face_brick") \
                    and w.get("in_side") and w.get("finish_texture"):
                finish_id = w["finish_texture"]
                build_baked_wall_finish(
                    buf(fid, "finish_%s" % finish_id,
                        "wallfinish_%s" % finish_id),
                    w, w["in_side"])
        for r in fl["rooms"]:
            build_floor_overlay(buf, fid, fl, r)
        for face in fl.get("ceilings", []):
            build_ceiling_overlay(buf, fid, face)
        for register in fl.get("vent_registers", []):
            build_vent_register(buf, fid, register)
        for fu in fl.get("furniture", []):
            if "asm" in fu:
                fn = ASM.get(fu["asm"])
                if fn is None:
                    continue
                on_floor = abs(fu.get("z0", 0.0)) < 1e-6
                batch_key = str(fu.get("batch", ""))
                if batch_key:
                    asm_prefix = furniture_batch_prefix(batch_key)
                else:
                    asm_prefix = "furnish"
                F = Frame(
                    lambda m, _f=fid, _p=asm_prefix:
                        buf(_f, "%s_%s" % (_p, m), m),
                    lambda _f=fid, _p=asm_prefix:
                        buf(_f, "%s_hull-colonly" % _p, "slab"),
                    fu["at"][0], fu["at"][1],
                    fl["z"] + fu.get("z0", 0.0), fu.get("yaw", 0),
                    finish_at(fl, fu["at"][0], fu["at"][1])
                    if on_floor else 0.0)
                fn(F, fu)
                continue
            r = fu["rect"]
            z0 = fl["z"] + fu.get("z0", 0.0)
            fmat = fu.get("mat", "trim")
            if fmat == "sidewalk_haunted":
                build_sidewalk_flag(buf, fid, fu, r, z0)
                continue
            # Retail interiors get their OWN merged meshes, bucketed per
            # shop. In the floor-wide furniture buffers their walls
            # joined a mesh whose AABB spans the whole block, and on
            # gl_compatibility lights are assigned per object with a cap
            # of 16 - so the bodega's own bulbs lost the contest against
            # every fixture on the street and the shop went black. Same
            # failure as the masonry-under-fill mystery, prevented at
            # authoring time instead of debugged again.
            fu_id0 = str(fu.get("id", ""))
            cat_prefix = "furniture"
            batch_key = str(fu.get("batch", ""))
            if batch_key:
                # One local AABB per shop and material.  These boxes used to
                # join the 220 x 148 m F01 furniture buffers, so GL Compatibility
                # assigned distant street lights to the mesh before the bulbs
                # hanging directly over it.  Ownership is emitted by the layout
                # rather than reconstructed from an ambiguous id prefix.
                cat_prefix = furniture_batch_prefix(batch_key)
            elif fu_id0.startswith("retail_bod"):
                cat_prefix = "retail_bod"
            elif fu_id0.startswith("retail_bar"):
                cat_prefix = "retail_bar"
            elif fu_id0.startswith("retail_"):
                cat_prefix = "retail_site"
            if fmat == "art":
                fu_id = str(fu.get("id", ""))
                if fu_id.endswith("_art"):
                    build_framed_picture(buf, fid, fu, r, z0)
                    continue
                # Wayfinding sign faces were sharing the picture
                # material. Harmless while that was one abstract canvas;
                # with a sheet of nine paintings it would hang a
                # landscape on every stair sign. A sign face is enamel.
                fmat = "indicator_enamel"
            # one buffer per material: a shared buffer would weld every
            # piece on the floor into the first item's material.
            # nocol entries (floor inlays, flush borders) render without
            # a trimesh, the same contract as the wear decals: a 4 mm
            # terrazzo border must never be a thing a capsule can hit.
            col_suffix = "" if fu.get("nocol") else "-col"
            buf(fid, "%s_%s%s" % (cat_prefix, fmat, col_suffix),
                fmat).add_box(
                (r[0], r[1], z0), (r[2], r[3], z0 + fu["h"]))
        for m in fl["markers"]:
            e = bpy.data.objects.new("MK_%s" % m["id"], None)
            e.empty_display_size = 0.2
            e.location = (m["pos"][0], m["pos"][1], m["pos"][2])
            col.objects.link(e)

    # stairs: dog-leg flights along Y with balustrades, handrails and
    # invisible walk ramps / fall guards, filed under the lower floor
    for st in LAYOUT["stairs"]:
        build_stair(buf, st)
    for fl in LAYOUT["floors"]:
        build_wear_decals(buf, fl)
    build_facade_details(buf)

    for (fid, cat), b in bufs.items():
        b.realize(floor_cols[fid])

    os.makedirs(GLB_OUT, exist_ok=True)
    failed = []
    for fid, col in floor_cols.items():
        bpy.ops.object.select_all(action="DESELECT")
        for obj in col.objects:
            if obj.type == "MESH":
                obj.select_set(True)
        # GLTF_SEPARATE with one shared texture dir: every floor
        # references the same texture files (deterministic T_* names), so
        # ~20 PBR sets exist once on disk and once in VRAM instead of
        # being embedded eight times over (embedded GLBs ballooned past
        # 100 MB total; separate keeps the whole export ~a tenth of that).
        path = os.path.join(GLB_OUT, floor_key(fid) + ".gltf")
        # RGBA decals intentionally feed one image node to both Base Color
        # and Alpha. Blender's exporter reports that valid arrangement as a
        # sampler warning even though both sockets necessarily use the same
        # node/sampler. Keep production logs at ERROR so real export failures
        # remain visible without hundreds of false-positive decal messages.
        # Every floor rewrites the whole shared texture directory, so the
        # same ~20 multi-MB PBR sets get written eight times over. On
        # Windows that occasionally loses a race with the indexer or the
        # scanner and finalize_images() dies with EINVAL on a path that is
        # provably valid and writable a second later. Retry rather than
        # lose the floor.
        last_err = None
        for attempt in range(3):
            try:
                bpy.ops.export_scene.gltf(filepath=path, use_selection=True,
                                          export_apply=True,
                                          export_format="GLTF_SEPARATE",
                                          export_texture_dir="textures")
                last_err = None
                break
            except RuntimeError as exc:
                last_err = exc
                print("retrying %s after export error: %s" % (path, exc))
                time.sleep(1.5 * (attempt + 1))
        if last_err is None:
            # GLTF_SEPARATE keeps geometry in a sibling .bin.  Godot's import
            # cache fingerprints the .gltf source but not that external buffer,
            # so a position-only rebuild with an unchanged descriptor can keep
            # drawing stale geometry indefinitely.  Carry the buffer digest in
            # asset.extras: it is harmless glTF metadata, changes only when the
            # exported bytes change, and makes every consumer reimport the
            # descriptor and its actual buffer as one build product.
            bin_path = os.path.splitext(path)[0] + ".bin"
            with open(bin_path, "rb") as bin_file:
                bin_sha256 = hashlib.sha256(bin_file.read()).hexdigest()
            with open(path, "r", encoding="utf-8") as gltf_file:
                gltf_text = gltf_file.read()
            version_line = '\t\t"version":"2.0"'
            if gltf_text.count(version_line) != 1:
                raise RuntimeError("unexpected glTF asset header in %s" % path)
            digest_line = (version_line + ',\n\t\t"extras":{\n'
                           '\t\t\t"orison_bin_sha256":"%s"\n\t\t}'
                           % bin_sha256)
            with open(path, "w", encoding="utf-8", newline="\n") as gltf_file:
                gltf_file.write(gltf_text.replace(version_line, digest_line, 1))
            print("exported", path)
        else:
            failed.append((fid, str(last_err)))
            print("EXPORT FAILED", path)

    # Blender exits 0 on an unhandled script exception, so a partial build
    # used to look exactly like a good one: floors b1-04 rebuilt, 05/06 and
    # the roof left at whatever they were, and nothing in the exit code to
    # say so. Say it loudly instead - a building that is half old geometry
    # and half new is worse than one that did not build at all.
    if failed:
        for fid, err in failed:
            print("!! floor %s did not export: %s" % (fid, err))
        print("BUILD FAILED: %d of %d floors did not export; the building "
              "on disk is now a mix of old and new geometry"
              % (len(failed), len(floor_cols)))
        sys.exit(1)

    # Factory settings do not inherit the artist's "Compress File" checkbox.
    # Saving without it inflated this deterministic source artefact from about
    # 12 MB to 57 MB even though the scene only gained the switch surfaces.
    bpy.ops.wm.save_as_mainfile(filepath=BLEND_OUT, compress=True)
    print("saved", BLEND_OUT)


if __name__ == "__main__" or True:
    build()
