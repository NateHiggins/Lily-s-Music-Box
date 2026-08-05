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

# ------------------------------------------------------------- textures
# art/textures/catalog_mapping.json is the single mapping authority:
# every semantic catalog material maps to a texture set (or null for the
# specialized shader-only materials: glassish, screen, fx_ao, fx_shadow).
# The build validates coverage in both directions and fails early if a
# mapped set is missing files, so a stale mapping can't ship silently.
TEX_ROOT = os.path.join(ROOT, "art", "textures")
with open(os.path.join(TEX_ROOT, "catalog_mapping.json")) as _f:
    CAT_TEX = json.load(_f)

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
        inv = 1.0 / tex_mpt(self.material)
        vgrain = self.material in VGRAIN
        for poly in me.polygons:
            n = poly.normal
            ax, ay, az = abs(n.x), abs(n.y), abs(n.z)
            for li in poly.loop_indices:
                co = me.vertices[me.loops[li].vertex_index].co
                if az >= ax and az >= ay:      # floor / ceiling
                    u, v = co.x, co.y
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
        _mat_cache[key] = mat
        return mat
    if key == "glassish":
        # Actual architectural glass: transmissive and lightly tinted,
        # rather than the opaque blue-gray panel used by the blockout.
        bsdf.inputs["Base Color"].default_value = (0.72, 0.84, 0.88, 1.0)
        bsdf.inputs["Roughness"].default_value = 0.08
        if "Transmission Weight" in bsdf.inputs:
            bsdf.inputs["Transmission Weight"].default_value = 0.72
        bsdf.inputs["IOR"].default_value = 1.46
        bsdf.inputs["Alpha"].default_value = 0.32
        if hasattr(mat, "surface_render_method"):
            mat.surface_render_method = "DITHERED"
        elif hasattr(mat, "blend_method"):
            mat.blend_method = "BLEND"
        if hasattr(mat, "use_transparency_overlap"):
            mat.use_transparency_overlap = False
    if key in FX_TEX:
        # baked-GI decal: albedo alpha does all the work, no reflections
        img = _image(os.path.join(TEX_ROOT, *FX_TEX[key].split("/")),
                     "fx", key, True)
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = img
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        nt.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
        bsdf.inputs["Roughness"].default_value = 1.0
        bsdf.inputs["Specular IOR Level"].default_value = 0.0
        mat.blend_method = "BLEND"
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
    _mat_cache[key] = mat
    return mat


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

    def __init__(self, get_buf, hull_buf, ox, oy, oz, yaw_deg):
        self.g = get_buf
        self.hb = hull_buf
        self.o = (ox, oy, oz)
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
        zq = 0.027  # above floor finishes (0.020) and wall AO (0.024)
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
    wood = p.get("mat", "wood_dark")
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
    wood = p.get("mat", "wood_dark")
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
        F.lathe("wood_dark", sx_ * (W / 2 - 0.05), -L / 2 + 0.05, post, 10)
        F.lathe("wood_dark", sx_ * (W / 2 - 0.05), L / 2 - 0.05, foot, 10)
        F.box("wood_dark", sx_ * (W / 2 - 0.03) - 0.012, -L / 2 + 0.05,
              0.24, sx_ * (W / 2 - 0.03) + 0.012, L / 2 - 0.05, 0.33)
    F.box("wood_dark", -W / 2 + 0.05, -L / 2 + 0.028, 0.78, W / 2 - 0.05,
          -L / 2 + 0.072, 0.86)             # head rail
    for i in range(5):
        sxp = -W / 2 + 0.16 + i * (W - 0.32) / 4.0
        F.cyl("wood_dark", sxp, -L / 2 + 0.05, 0.33, 0.78, 0.014, 0.014, 8)
    F.box("wood_dark", -W / 2 + 0.05, L / 2 - 0.068, 0.40, W / 2 - 0.05,
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


def asm_wardrobe(F, p):
    """Armoire spirit: plinth, framed doors, cornice, turned knobs."""
    W, d = p.get("W", 1.30), 0.62
    F.box("wood_dark", -W / 2, -d / 2, 0.0, W / 2, d / 2, 0.07)
    F.box("wood_dark", -W / 2 + 0.02, -d / 2 + 0.02, 0.07, W / 2 - 0.02,
          d / 2 - 0.03, 1.86)
    F.box("wood_dark", -W / 2 - 0.03, -d / 2 - 0.01, 1.86, W / 2 + 0.03,
          d / 2 + 0.03, 1.91)
    F.box("wood_dark", -W / 2 - 0.015, -d / 2, 1.91, W / 2 + 0.015,
          d / 2 + 0.015, 1.945)
    for sx_ in (-1, 1):
        x0 = 0.012 if sx_ > 0 else -W / 2 + 0.035
        x1 = W / 2 - 0.035 if sx_ > 0 else -0.012
        F.box("wood_dark", x0, d / 2 - 0.03, 0.10, x1, d / 2 - 0.005, 1.82)
        F.box("floor_oak", x0 + 0.05, d / 2 - 0.012, 0.22, x1 - 0.05,
              d / 2 + 0.002, 1.68)          # raised door panel
        F.lathe("brass", sx_ * 0.075, d / 2 + 0.012,
                [(0.006, 0.92), (0.016, 0.945), (0.010, 0.97)], 8)
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
    """Potted ficus remade for close viewing: unglazed terracotta pot
    with a thrown body, rolled rim and drip saucer, mounded potting
    soil, and a real crown — arched woody canes each carrying its own
    drooping elliptical leaves instead of three canopy blobs."""
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


def asm_kitchen(F, p):
    """Frankfurt-kitchen spirit: flat fronts, groove pulls, real sink."""
    L = p.get("L", 2.5)
    cw = L - 0.75
    # carcass centered on the origin
    F.box("soot", -cw / 2 + 0.02, -0.28, 0.0, -cw / 2 + cw - 0.02, 0.26, 0.07)
    F.box("trim", -cw / 2, -0.30, 0.07, -cw / 2 + cw, 0.28, 0.86)
    # counter, segmented around a real sink cutout (no booleans in the
    # box world: the hole is the four boards that don't cover it)
    sx0 = -cw / 2 + cw * 0.30
    bx0, bx1 = sx0 - 0.22, sx0 + 0.22      # basin cutout in x
    by0, by1 = -0.20, 0.12                 # basin cutout in y
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
    # the basin itself: chrome rim lip over brushed-steel walls falling
    # to a true bottom with a drain — a sink you can look down into
    for rx0, ry0, rx1, ry1 in (
            (bx0 - 0.018, by0 - 0.018, bx1 + 0.018, by0),
            (bx0 - 0.018, by1, bx1 + 0.018, by1 + 0.018),
            (bx0 - 0.018, by0, bx0, by1),
            (bx1, by0, bx1 + 0.018, by1)):
        F.box("chrome", rx0, ry0, 0.895, rx1, ry1, 0.906)
    for wx0, wy0, wx1, wy1 in (
            (bx0, by0, bx1, by0 + 0.012),
            (bx0, by1 - 0.012, bx1, by1),
            (bx0, by0, bx0 + 0.012, by1),
            (bx1 - 0.012, by0, bx1, by1)):
        F.box("metal", wx0, wy0, 0.70, wx1, wy1, 0.898)
    F.box("metal", bx0, by0, 0.695, bx1, by1, 0.715)
    F.cyl("soot", sx0, (by0 + by1) / 2.0, 0.715, 0.722, 0.030, 0.030, 10)
    F.lathe("chrome", sx0, (by0 + by1) / 2.0,
            [(0.030, 0.722), (0.040, 0.726), (0.032, 0.729)], 10)
    F.tube("chrome", (sx0, -0.245, 0.895), (sx0, -0.245, 1.10), 0.014, 8)
    F.tube("chrome", (sx0, -0.245, 1.10), (sx0, -0.05, 1.06), 0.013, 8)
    for tx in (-0.12, 0.12):
        F.tube("chrome", (sx0 + tx, -0.24, 0.895),
               (sx0 + tx, -0.24, 0.955), 0.010, 8)
        F.tube("chrome", (sx0 + tx - 0.03, -0.24, 0.965),
               (sx0 + tx + 0.03, -0.24, 0.965), 0.008, 6)
    F.box("trim", -cw / 2, -0.30, 1.46, -cw / 2 + cw, 0.05, 2.16)
    for i in range(nd):
        x0 = -cw / 2 + 0.02 + i * (dw + 0.02)
        F.box("trim", x0, 0.051, 1.50, x0 + dw, 0.071, 2.12)
        F.box("soot", x0 + 0.02, 0.053, 1.52, x0 + dw - 0.02, 0.073, 1.555)
    F.hull(-cw / 2, -0.32, 0.0, -cw / 2 + cw, 0.32, 0.92)


def asm_stove(F, p):
    """1940s enamel-range spirit: clock panel, towel-rail door, knob row."""
    F.box("enamel", -0.31, -0.30, 0.06, 0.31, 0.30, 0.86)
    for fx, fy in ((-0.27, -0.26), (0.27, -0.26), (-0.27, 0.26),
                   (0.27, 0.26)):
        F.cyl("metal", fx, fy, 0.0, 0.06, 0.024, 0.030, 8)
    F.box("appliance", -0.31, -0.30, 0.86, 0.31, 0.30, 0.895)
    for bx, by in ((-0.15, -0.12), (0.15, -0.12), (-0.15, 0.14),
                   (0.15, 0.14)):
        F.cyl("soot", bx, by, 0.895, 0.905, 0.085, 0.085, 12)
        F.lathe("metal", bx, by, [(0.088, 0.905), (0.095, 0.915),
                                  (0.088, 0.92)], 12)
    F.box("enamel", -0.31, 0.24, 0.895, 0.31, 0.30, 1.24)
    F.cyl("appliance", 0.0, 0.268, 1.06, 1.075, 0.065, 0.065, 12)
    F.lathe("brass", 0.0, 0.268, [(0.068, 1.055), (0.072, 1.075),
                                  (0.065, 1.08)], 12)
    for kx in (-0.24, -0.12, 0.0, 0.12, 0.24):
        F.lathe("bakelite", kx, -0.315,
                [(0.010, 0.80), (0.022, 0.82), (0.016, 0.835)], 8)
    # oven door at real range proportions: door sits between the broiler
    # drawer and the burner deck, window high, towel rail at the top edge
    F.box("enamel", -0.275, -0.322, 0.30, 0.275, -0.298, 0.72)
    F.box("soot", -0.15, -0.328, 0.50, 0.15, -0.320, 0.64)      # window
    F.tube("chrome", (-0.24, -0.356, 0.685), (0.24, -0.356, 0.685),
           0.012, 8)
    for hx in (-0.23, 0.23):
        F.tbox("chrome", (hx, -0.322, 0.672), (hx, -0.356, 0.685),
               0.020, 0.012)
    # broiler drawer with a recessed pull
    F.box("enamel", -0.275, -0.318, 0.115, 0.275, -0.300, 0.275)
    F.box("soot", -0.10, -0.321, 0.175, 0.10, -0.316, 0.215)
    F.hull(-0.31, -0.36, 0.0, 0.31, 0.30, 1.24)


def asm_fridge50(F, p):
    """Rounded-shoulder 1950s refrigerator spirit, latch and badge."""
    F.box("soot", -0.30, -0.29, 0.0, 0.30, 0.29, 0.06)
    F.box("appliance", -0.33, -0.32, 0.06, 0.33, 0.32, 1.52)
    F.box("appliance", -0.315, -0.305, 1.52, 0.315, 0.305, 1.60)
    F.box("appliance", -0.285, -0.275, 1.60, 0.285, 0.275, 1.66)
    F.box("appliance", -0.23, -0.22, 1.66, 0.23, 0.22, 1.70)
    F.box("appliance", -0.31, 0.321, 0.10, 0.31, 0.345, 1.50)
    F.box("appliance", -0.28, 0.345, 0.14, 0.28, 0.357, 1.46)
    F.tube("chrome", (0.24, 0.395, 0.72), (0.24, 0.395, 1.18), 0.016, 10)
    for hz in (0.74, 1.16):
        F.tbox("chrome", (0.24, 0.357, hz), (0.24, 0.40, hz), 0.03, 0.02)
    F.box("chrome", 0.20, 0.35, 0.93, 0.28, 0.40, 0.99)
    F.box("brass", -0.09, 0.357, 1.30, 0.09, 0.363, 1.36)
    for hz in (0.22, 1.34):
        F.cyl("chrome", -0.315, 0.335, hz, hz + 0.05, 0.018, 0.018, 8)
    F.hull(-0.33, -0.32, 0.0, 0.33, 0.40, 1.70)


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
    F.box("glassish", -0.22, -0.245, 1.05, 0.22, -0.235, 1.55)
    F.box("trim", -0.24, -0.248, 1.03, 0.24, -0.232, 1.05)
    F.box("trim", -0.24, -0.248, 1.55, 0.24, -0.232, 1.57)
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
    """Bakelite toggle on a two-step molded plate; the smallest identity."""
    F.box("trim", -0.044, 0.0, -0.066, 0.044, 0.007, 0.066)
    F.box("trim", -0.030, 0.007, -0.048, 0.030, 0.0125, 0.048)
    F.box("bakelite", -0.017, 0.0125, -0.028, 0.017, 0.016, 0.028)
    F.tbox("bakelite", (0.0, 0.014, -0.004), (0.0, 0.034, 0.020),
           0.011, 0.011)
    for sz in (-0.054, 0.054):
        F.box("chrome", -0.0035, 0.007, sz - 0.0035, 0.0035, 0.0095,
              sz + 0.0035)


def asm_pipe(F, p):
    """Raw endpoints are world-space by default (the basement services
    are authored that way); `local: true` routes them through the frame
    so a run can anchor to a marker's position and yaw."""
    a, b = tuple(p["p0"]), tuple(p["p1"])
    if p.get("local"):
        a, b = F.pt(*a), F.pt(*b)
    F.g(p.get("mat", "metal")).add_tube(a, b, p.get("r", 0.045), 10)


def asm_bench(F, p):
    """Hall settle: slat seat, turned legs, spindle back."""
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


ASM = {
    "sofa": asm_sofa, "chair": asm_chair, "table_round": asm_table_round,
    "table_rect": asm_table_rect, "coffee": asm_coffee,
    "nightstand": asm_nightstand, "bed": asm_bed, "wardrobe": asm_wardrobe,
    "shelf": asm_shelf, "tv": asm_tv, "plant": asm_plant,
    "kitchen": asm_kitchen, "stove": asm_stove, "fridge50": asm_fridge50,
    "desk": asm_desk, "plantable": asm_plantable,
    "workbench": asm_workbench, "toilet": asm_toilet,
    "sink_ped": asm_sink_ped, "shower": asm_shower, "switch": asm_switch,
    "sink_basin": asm_sink_basin,
    "pipe": asm_pipe, "bench": asm_bench, "mailbank": asm_mailbank,
    "amp": asm_amp, "guitar": asm_guitar, "pedalboard": asm_pedalboard,
    "micstand": asm_micstand, "reeldeck": asm_reeldeck,
    "headphones": asm_headphones, "mug": asm_mug, "papers": asm_papers,
    "bookpile": asm_bookpile, "pinboard": asm_pinboard,
    "toolboard": asm_toolboard, "partstray": asm_partstray,
    "jarrow": asm_jarrow, "tripod": asm_tripod, "softbox": asm_softbox,
    "cablecoil": asm_cablecoil, "crate": asm_crate, "radio": asm_radio,
    "sitemodel": asm_sitemodel, "bottles": asm_bottles,
    "safety_barrier": asm_safety_barrier, "reno_gear": asm_reno_gear,
    "fire_escape": asm_fire_escape,
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
               stone_buf=None, ao_buf=None):
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
            # A tiled dado belongs to the wet room only: bathroom walls
            # record which face is the bath, and the band goes on that
            # side alone so the bedroom next door keeps its plaster.
            dado_side = w.get("wains_side")
            if dado_side:
                side_box(wains_buf, d0, d1, 0.11, 1.32, dado_side, 0.024)
            else:
                box(wains_buf, d0, d1, 0.11, 1.32, t + 0.022)
            box(trim_buf, d0, d1, 1.32, 1.36, t + 0.040)
            # A small bullnose bead catches a soft highlight and makes the
            # dado read as installed millwork instead of a razor-edged box.
            # Run it on both wall faces so corridor and room views agree.
            a0, a1 = start + d0, start + d1
            for sgn in (-1, 1):
                face = cross + sgn * (t / 2.0 + 0.031)
                if horizontal:
                    trim_buf.add_tube((a0, face, z + 1.355),
                                      (a1, face, z + 1.355), 0.024, 8)
                else:
                    trim_buf.add_tube((face, a0, z + 1.355),
                                      (face, a1, z + 1.355), 0.024, 8)
        if ao_buf is None:
            return
        zq = z + 0.024
        for sgn in (1, -1):
            face = cross + sgn * (t / 2.0 + 0.02)
            outer = face + sgn * 0.14
            a0, a1 = start + d0, start + d1
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
    "alcove": ("floor_oak", 0.012), "kitchen": ("floor_oak", 0.012),
    "closet": ("floor_oak", 0.012), "vestibule": ("floor_oak", 0.012),
    "common": ("floor_oak", 0.012),
    "office": ("floor_oak", 0.016),
    "bathroom": ("ceramic", 0.020),
}


def build_floor_overlay(buf, fid, fl, r):
    spec = KIND_FLOOR.get(r["kind"])
    if spec is None:
        return
    mat, th = spec
    z = fl["z"]
    rects = [tuple(r["rect"])]
    if r["kind"] == "corridor":  # ring only: the whole core column is
        rects = subtract_rect(rects, (-3.43, -6.93, 3.43, 6.93))
        for hole in fl["slabs"][0]["holes"]:  # handled by its own rooms
            rects = subtract_rect(rects, tuple(hole))
    elif r["kind"] == "hall":    # keep clear of the elevator shaft pit
        for hole in fl["slabs"][0]["holes"]:
            rects = subtract_rect(rects, tuple(hole))
    for (x0, y0, x1, y1) in rects:
        # A floor finish is one upward face. The old box also drew an
        # underside (buried in the slab, free to z-fight) and four edge
        # walls, six faces where the eye can only ever see one.
        buf(fid, "floors_%s" % mat, mat).add_quad(
            (x0, y0, z + th), (x1, y0, z + th),
            (x1, y1, z + th), (x0, y1, z + th))


# room kind -> ceiling finish. A down-facing quad just under the slab
# soffit: the ceiling is the one surface a torch rakes across all night.
KIND_CEILING = {
    "corridor": "tin_ceiling", "hall": "tin_ceiling",
    "lobby": "tin_ceiling", "atrium": "tin_ceiling",
}


def build_ceiling_overlay(buf, fid, fl, r):
    mat = KIND_CEILING.get(r["kind"])
    if mat is None:
        return
    # The soffit is where the walls stop, which the floor dict does not
    # state directly: read it off the walls themselves rather than
    # guessing a storey height and hanging the ceiling inside the slab.
    heights = [float(w["h"]) for w in fl["walls"]
               if w.get("cat", "walls") == "walls"]
    ztop = fl["z"] + (max(heights) if heights else 3.02) - 0.015
    rects = [tuple(r["rect"])]
    if r["kind"] == "corridor":
        rects = subtract_rect(rects, (-3.43, -6.93, 3.43, 6.93))
    for hole in fl["slabs"][0]["holes"]:
        rects = subtract_rect(rects, tuple(hole))
    for (x0, y0, x1, y1) in rects:
        # reversed winding: this face looks DOWN into the room
        buf(fid, "ceiling_%s" % mat, mat).add_quad(
            (x0, y1, ztop), (x1, y1, ztop),
            (x1, y0, ztop), (x0, y0, ztop))


def _rail_line(buf, fid, gx0, gx1, yc, z):
    """Level balustrade along X: handrail, newels, balusters + fall guard."""
    rail = buf(fid, "stairs_rail", "handrail_wood")
    bal = buf(fid, "stairs_bal", "baluster")
    guard = buf(fid, "stairs_guard-colonly", "stair")
    rail.add_box((gx0 - 0.06, yc - 0.045, z + 0.86),
                 (gx1 + 0.06, yc + 0.045, z + 0.96))
    rail.add_box((gx0 - 0.13, yc - 0.06, z), (gx0 - 0.02, yc + 0.06, z + 1.02))
    rail.add_box((gx1 + 0.02, yc - 0.06, z), (gx1 + 0.13, yc + 0.06, z + 1.02))
    k = max(4, int((gx1 - gx0) / 0.16))
    for j in range(k):
        xj = gx0 + (j + 0.5) * (gx1 - gx0) / k
        bal.add_box((xj - 0.018, yc - 0.018, z), (xj + 0.018, yc + 0.018,
                                                  z + 0.86))
    guard.add_box((gx0 - 0.13, yc - 0.03, z), (gx1 + 0.13, yc + 0.03, z + 1.0))


def _flight(buf, part):
    """One dog-leg flight along Y: thin waist slab + treads, walk ramp, raked
    balustrade on the well side, wall rail on the other, fall guard."""
    fid = floor_for_z(part["z0"] + 0.01)
    vis = buf(fid, "stairs", "stair")
    ramp = buf(fid, "stairs_ramp-colonly", "stair")
    rail = buf(fid, "stairs_rail", "handrail_wood")
    bal = buf(fid, "stairs_bal", "baluster")
    guard = buf(fid, "stairs_guard-colonly", "stair")
    n, rise, tread = part["n"], part["rise"], part["tread"]
    s, d = part["start"], part["dir"]
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
    ramp.add_ramp(s, z0, a_end, z0 + n * rise, b0, b1, axis="y")
    xr = b1 - 0.045 if part["rail_side"] == "hi" else b0 + 0.045
    xw = b0 + 0.055 if part["rail_side"] == "hi" else b1 - 0.055
    for i in range(1, n):
        for frac in (0.72, 0.28):   # two per tread, real balustrade rhythm
            am = s + d * (i - frac) * tread
            bal.add_box((xr - 0.02, am - 0.02, z0 + i * rise),
                        (xr + 0.02, am + 0.02, z0 + i * rise + 0.84))
    rail.add_ramp(s, z0 + 0.92, a_end, z0 + n * rise + 0.92,
                  xr - 0.045, xr + 0.045, thickness=0.07, axis="y")
    rail.add_ramp(s, z0 + 0.87, a_end, z0 + n * rise + 0.87,
                  xw - 0.032, xw + 0.032, thickness=0.05, axis="y")
    guard.add_ramp(s, z0 + 0.95, a_end, z0 + n * rise + 0.95,
                   xr - 0.03, xr + 0.03, thickness=0.95, axis="y")
    na = s + d * 0.02  # base newel; the landing/floor rails own the tops
    rail.add_box((xr - 0.055, min(na, na + d * 0.11), z0),
                 (xr + 0.055, max(na, na + d * 0.11), z0 + 1.04))


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
            for b in (buf(fid, "stairs", "stair"),
                      buf(fid, "stairs_ramp-colonly", "stair")):
                b.add_box((r[0], r[1], part["z"] - 0.18),
                          (r[2], r[3], part["z"]))
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
def build_wear_decals(buf, fl):
    fid = fl["id"]
    z = fl["z"]
    zq = 0.0285   # above AO strips and contact shadows

    def floor_quad(mat, x0, y0, x1, y1):
        buf(fid, "wear_" + mat, mat).add_quad(
            (x0, y0, z + zq), (x1, y0, z + zq),
            (x1, y1, z + zq), (x0, y1, z + zq))

    def wall_quad(mat, p0, p1, z0, z1):
        b = buf(fid, "wear_" + mat, mat)
        b.add_quad((p0[0], p0[1], z + z0), (p1[0], p1[1], z + z0),
                   (p1[0], p1[1], z + z1), (p0[0], p0[1], z + z1))

    def ceiling_quad(mat, x0, y0, x1, y1, drop=0.018):
        """Down-facing translucent damage just below the plaster ceiling."""
        b = buf(fid, "wear_ceiling_" + mat, mat)
        zc = z + 3.0 - drop
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
        face = cross + w["t"] / 2.0 + 0.004
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
    for fu in fl.get("furniture", []):
        if fu.get("asm") == "stove":
            import math as _m
            a = _m.radians(fu.get("yaw", 0))
            fx_, fy_ = -_m.sin(a), _m.cos(a)     # local +y in world
            wx = fu["at"][0] - fx_ * 0.36
            wy = fu["at"][1] - fy_ * 0.36
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

    def buf(fid, cat, mat):
        key = (fid, cat)
        if key not in bufs:
            if mat.startswith("wallfinish_"):
                mode = "explicit"
            elif mat.startswith("fx_") or UV_MODE_BY_MAT.get(mat) == "unit":
                mode = "unit"
            else:
                mode = "world"
            bufs[key] = MeshBuf("%s_%s" % (fid, cat), mat, mode)
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
                       buf(fid, "fx_ao_decal", "fx_ao"))
            if w["mat"] in ("brick", "common_brick", "face_brick") \
                    and w.get("in_side") and w.get("finish_texture"):
                finish_id = w["finish_texture"]
                build_baked_wall_finish(
                    buf(fid, "finish_%s" % finish_id,
                        "wallfinish_%s" % finish_id),
                    w, w["in_side"])
        for r in fl["rooms"]:
            build_floor_overlay(buf, fid, fl, r)
            build_ceiling_overlay(buf, fid, fl, r)
        for fu in fl.get("furniture", []):
            if "asm" in fu:
                fn = ASM.get(fu["asm"])
                if fn is None:
                    continue
                F = Frame(
                    lambda m, _f=fid: buf(_f, "furnish_%s" % m, m),
                    lambda _f=fid: buf(_f, "furniture_hull-colonly", "slab"),
                    fu["at"][0], fu["at"][1],
                    fl["z"] + fu.get("z0", 0.0), fu.get("yaw", 0))
                fn(F, fu)
                continue
            r = fu["rect"]
            z0 = fl["z"] + fu.get("z0", 0.0)
            fmat = fu.get("mat", "trim")
            # one buffer per material: a shared buffer would weld every
            # piece on the floor into the first item's material
            buf(fid, "furniture_%s-col" % fmat, fmat).add_box(
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
        bpy.ops.export_scene.gltf(filepath=path, use_selection=True,
                                  export_apply=True,
                                  export_format="GLTF_SEPARATE",
                                  export_texture_dir="textures")
        print("exported", path)

    bpy.ops.wm.save_as_mainfile(filepath=BLEND_OUT)
    print("saved", BLEND_OUT)


if __name__ == "__main__" or True:
    build()
