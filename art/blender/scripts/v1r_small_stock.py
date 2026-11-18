"""Shared stock helper for the small V1-to-V2 imports (commensals, the airmail
biplane, the memory-art frames).

Geometry is authored in the runtime frame (Godot axes: +X right, +Y up, +Z
toward the viewer; metres) and converted to Blender's Z-up once, at `finish`,
so the glTF exporter's Y-up conversion lands every part where it was drawn.

UVs are physical: each face is charted in its own plane in metres, with U
along the face's grain direction (the stock's length), so a catalogue finish
keeps its own metres-per-tile at runtime.
"""
import bpy, bmesh, math
from mathutils import Vector, Matrix

TAU = math.tau
# runtime (x, y, z) -> Blender (x, -z, y)
TO_BLENDER = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def box_geo(sx, sy, sz):
    x, y, z = sx / 2, sy / 2, sz / 2
    v = [(-x, -y, -z), (x, -y, -z), (x, y, -z), (-x, y, -z), (-x, -y, z), (x, -y, z), (x, y, z), (-x, y, z)]
    return v, [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]


def spindle_geo(profile, segs):
    """Revolve an open (r, z) profile about Z; the first and last points sit
    on the axis. Faces wind outward."""
    v, rows, f = [], [], []
    for r, z in profile:
        if r < 1e-9:
            v.append((0.0, 0.0, z))
            rows.append([len(v) - 1] * segs)
        else:
            row = []
            for k in range(segs):
                a = TAU * k / segs
                v.append((r * math.cos(a), r * math.sin(a), z))
                row.append(len(v) - 1)
            rows.append(row)
    for i in range(len(profile) - 1):
        a, b = rows[i], rows[i + 1]
        for k in range(segs):
            k2 = (k + 1) % segs
            q = []
            for t in (a[k2], a[k], b[k], b[k2]):
                if t not in q:
                    q.append(t)
            if len(q) >= 3:
                f.append(tuple(q))
    return v, f


def loft_geo(sections, cap=True):
    """Join rings of equal vertex count (lists of xyz) into a skin."""
    v, f = [], []
    n = len(sections[0])
    for ring in sections:
        v.extend(ring)
    for i in range(len(sections) - 1):
        for k in range(n):
            k2 = (k + 1) % n
            f.append((i * n + k, i * n + k2, (i + 1) * n + k2, (i + 1) * n + k))
    if cap:
        f.append(tuple(range(n - 1, -1, -1)))
        f.append(tuple((len(sections) - 1) * n + k for k in range(n)))
    return v, f


class Stock:
    """One mesh object in the making."""

    def __init__(self):
        self.bm = bmesh.new()
        self.grain = self.bm.faces.layers.float_vector.new("grain")

    def emit(self, geo, m=None, grain=(1, 0, 0), flip=False):
        verts, faces = geo
        rot = m.to_3x3() if m is not None else None
        g = Vector(grain)
        if rot is not None:
            g = (rot @ g).normalized()
        bv = [self.bm.verts.new(m @ Vector(p) if m is not None else Vector(p)) for p in verts]
        for face in faces:
            idx = list(reversed(face)) if flip else list(face)
            try:
                made = self.bm.faces.new([bv[i] for i in idx])
            except ValueError:
                continue
            made[self.grain] = g
        return self

    def box(self, at, size, grain=None, m=None):
        if grain is None:
            grain = [(1, 0, 0), (0, 1, 0), (0, 0, 1)][max(range(3), key=lambda i: size[i])]
        mm = Matrix.Translation(at)
        return self.emit(box_geo(*size), (m @ mm) if m is not None else mm, grain)

    def poly(self, pts, grain=(1, 0, 0), m=None):
        """One flat face from 3D points, wound as given."""
        return self.emit((list(pts), [tuple(range(len(pts)))]), m, grain)

    def triangles(self):
        self.bm.normal_update()
        return sum(len(f.verts) - 2 for f in self.bm.faces)

    def finish(self, name, pivot=(0.0, 0.0, 0.0), smooth=False, tile=1.0, outward=True, grain_v=False):
        """Make the object, origin on `pivot` (runtime frame), charted in metres.
        `outward` welds coincident corners and turns every shell's faces out.
        `grain_v` lays the grain along the map's V (walnut) instead of its U."""
        bm = self.bm
        if outward:
            bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-6)
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        bmesh.ops.triangulate(bm, faces=bm.faces[:])
        bm.normal_update()
        uv = bm.loops.layers.uv.new("UVMap")
        for face in bm.faces:
            n = face.normal
            g = Vector(face[self.grain])
            u = g - n * g.dot(n)
            if u.length < 1e-5:
                u = n.orthogonal()
            u.normalize()
            w = n.cross(u)
            if grain_v:
                u, w = u.cross(n), u
            for loop in face.loops:
                p = loop.vert.co
                loop[uv].uv = (p.dot(u) / tile, p.dot(w) / tile)
            face.smooth = smooth
        pv = Vector(pivot)
        for vert in bm.verts:
            vert.co = TO_BLENDER.to_3x3() @ (vert.co - pv)
        mesh = bpy.data.meshes.new(name)
        bm.to_mesh(mesh)
        bm.free()
        obj = bpy.data.objects.new(name, mesh)
        obj.location = TO_BLENDER.to_3x3() @ pv
        bpy.context.collection.objects.link(obj)
        return obj


def preview_material(obj, key, colour, alpha=1.0):
    mat = bpy.data.materials.get(key)
    if mat is None:
        mat = bpy.data.materials.new(key)
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = (*colour, 1)
        bsdf.inputs["Roughness"].default_value = 0.7
        bsdf.inputs["Alpha"].default_value = alpha
    obj.data.materials.append(mat)


def tri_count(obj):
    obj.data.calc_loop_triangles()
    return len(obj.data.loop_triangles)


def export(objs, glb, blend):
    bpy.ops.wm.save_as_mainfile(filepath=str(blend), check_existing=False)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(glb), export_format="GLB", use_selection=True,
                              export_yup=True, export_apply=True, export_normals=True, export_tangents=True,
                              export_texcoords=True, export_materials="EXPORT", export_animations=False)


def review(path, objs_at, camera_at, look_at, lens=50, size=(960, 640), sun=3.0, floor_z=None):
    """A plain daylight render of the scene as it stands. Blender coordinates."""
    scene = bpy.context.scene
    try:
        scene.render.engine = "BLENDER_EEVEE"
    except TypeError:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x, scene.render.resolution_y = size
    if scene.world is None:
        scene.world = bpy.data.worlds.new("review")
        scene.world.use_nodes = True
        scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.6, 0.68, 1)
        scene.world.node_tree.nodes["Background"].inputs[1].default_value = 0.9
    made = []
    light = bpy.data.objects.new("review_sun", bpy.data.lights.new("review_sun", "SUN"))
    light.data.energy = sun
    light.rotation_euler = (math.radians(50), 0, math.radians(35))
    bpy.context.collection.objects.link(light)
    made.append(light)
    cam = bpy.data.objects.new("review_cam", bpy.data.cameras.new("review_cam"))
    cam.data.lens = lens
    cam.data.clip_start = 0.002
    cam.location = camera_at
    direction = Vector(look_at) - Vector(camera_at)
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    bpy.context.collection.objects.link(cam)
    made.append(cam)
    if floor_z is not None:
        bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, floor_z))
        made.append(bpy.context.object)
    scene.camera = cam
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    for o in made:
        bpy.data.objects.remove(o)
