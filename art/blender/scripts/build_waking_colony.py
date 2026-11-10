"""The waking organism's colony, authored in Blender (Lily, 2026-11-09).

Replaces the procedural SphereMesh/TorusMesh/CylinderMesh colony that V2's
waking style drew with: an irregular, lobed outer membrane open to the floor;
genuinely interior organelles of different kinds (a wrinkled nucleus with its
nucleolus, smooth vacuoles, ridged rod mitochondria, granule clusters and a
filament bundle), each a separate object so Godot can stream them around the
cell; and one jointed, tapered cilium, root at the origin, for instancing.

Deterministic: one seed, no randomness outside it. Blender Z-up metres; the
glTF exporter converts to Godot's Y-up once.

  blender -b --python-exit-code 1 -P art/blender/scripts/build_waking_colony.py -- <out_dir>
Writes <out_dir>/waking_colony.glb, waking_colony.blend, waking_colony.json and
review renders under <out_dir>/review/.
"""
import bpy, bmesh, json, math, sys
from mathutils import Vector, Matrix, noise
from pathlib import Path

SEED = 1929
OUT = Path(sys.argv[sys.argv.index("--") + 1]) if "--" in sys.argv else Path("waking_colony_out")
OUT.mkdir(parents=True, exist_ok=True)
REGIONS = {"membrane": 0, "nucleus": 1, "nucleolus": 2, "vacuole": 3,
           "mitochondrion": 4, "granule": 5, "filament": 6, "cilium": 7}
# The membrane's base half-extents (x, y) and dome height.
RX, RY, RZ = 0.27, 0.23, 0.16


def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def rng(i, salt=0):
    return (math.sin(i * 12.9898 + salt * 78.233 + SEED) * 43758.5453) % 1.0


def finish(obj, region, phase, uv="sphere"):
    mesh = obj.data
    if uv and not mesh.uv_layers:
        mesh.uv_layers.new(name="UVMap")
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        if uv == "sphere":
            bpy.ops.uv.sphere_project()
        else:
            bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.02)
        bpy.ops.object.mode_set(mode="OBJECT")
        obj.select_set(False)
    colors = mesh.color_attributes.new(name="Anatomy", type="FLOAT_COLOR", domain="POINT")
    for v in mesh.vertices:
        colors.data[v.index].color = (0.0, phase, REGIONS[region] / 255.0, 1.0)
    for p in mesh.polygons:
        p.use_smooth = True
    obj["region"] = region
    return obj


def inside(p, margin=0.82):
    """Is p inside the membrane's ellipsoid, with a margin?"""
    if p.z < 0.0:
        return False
    return (p.x / (RX * margin)) ** 2 + (p.y / (RY * margin)) ** 2 + (p.z / (RZ * margin)) ** 2 < 1.0


def membrane():
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=72, v_segments=36, radius=1.0)
    for v in bm.verts:
        d = v.co.normalized()
        # Lobes around the outline and a soft, uneven crown: an organism, not
        # a lens blank. Low frequencies only, so the refraction stays smooth.
        lobe = 1.0 + 0.11 * math.sin(3 * math.atan2(d.y, d.x) + 0.7) \
            + 0.07 * math.sin(5 * math.atan2(d.y, d.x) + 2.1) \
            + 0.05 * noise.noise(d * 2.3 + Vector((SEED % 7, 0, 0)))
        crown = 1.0 + 0.10 * noise.noise(d * 1.7 + Vector((0, SEED % 5, 0)))
        v.co = Vector((d.x * RX * lobe, d.y * RY * lobe, max(d.z, -0.02) * RZ * crown))
    # Open to the floor: drop everything below the skirt.
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -0.004], context="VERTS")
    mesh = bpy.data.meshes.new("Membrane")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("Membrane", mesh)
    bpy.context.collection.objects.link(obj)
    finish(obj, "membrane", 0.0, uv="smart")
    # Thickness proxy for the shader: thin at the crown, thick at the skirt.
    colors = obj.data.color_attributes["Anatomy"]
    for v in obj.data.vertices:
        colors.data[v.index].color = (min(1.0, v.co.z / RZ), 0.0, 0.0, 1.0)
    return obj


def blob(name, centre, radius, region, phase, wrinkle=0.0, stretch=(1, 1, 1), subdiv=4):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=radius)
    for v in bm.verts:
        d = v.co.normalized()
        w = 1.0 + wrinkle * noise.noise(d * 6.0 + Vector((phase * 13, 0, 0)))
        v.co = Vector((v.co.x * stretch[0], v.co.y * stretch[1], v.co.z * stretch[2])) * w
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    obj.location = centre
    bpy.context.collection.objects.link(obj)
    return finish(obj, region, phase)


def capsule(name, centre, length, radius, axis, region, phase):
    """A rod mitochondrion with ridged cristae, oriented along `axis`."""
    bm = bmesh.new()
    rings, seg = 18, 12
    verts = []
    for i in range(rings + 1):
        t = i / rings
        z = (t - 0.5) * length
        cap = math.sqrt(max(0.0, 1.0 - ((abs(z) - (length * 0.5 - radius)) / radius) ** 2)) \
            if abs(z) > length * 0.5 - radius else 1.0
        ridge = 1.0 + 0.12 * math.sin(t * math.pi * 9)
        row = []
        for j in range(seg):
            a = j / seg * math.tau
            row.append(bm.verts.new((math.cos(a) * radius * cap * ridge, math.sin(a) * radius * cap * ridge, z)))
        verts.append(row)
    for i in range(rings):
        for j in range(seg):
            bm.faces.new((verts[i][j], verts[i][(j + 1) % seg], verts[i + 1][(j + 1) % seg], verts[i + 1][j]))
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    obj.location = centre
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(Vector(axis).normalized())
    bpy.context.collection.objects.link(obj)
    return finish(obj, region, phase, uv="smart")


def tube_mesh(name, points, radius, region, phase):
    bm = bmesh.new()
    seg = 6
    rows = []
    for i, p in enumerate(points):
        t = points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)]
        t.normalize()
        a = t.orthogonal().normalized()
        b = t.cross(a)
        r = radius * (0.6 + 0.4 * math.sin(i / (len(points) - 1) * math.pi))
        rows.append([bm.verts.new(p + (a * math.cos(k / seg * math.tau) + b * math.sin(k / seg * math.tau)) * r)
                     for k in range(seg)])
    for i in range(len(rows) - 1):
        for k in range(seg):
            bm.faces.new((rows[i][k], rows[i][(k + 1) % seg], rows[i + 1][(k + 1) % seg], rows[i + 1][k]))
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def cilium():
    """One jointed, tapered cilium: three segments with knuckles, root at the
    origin pointing +Z. Anatomy R = along (0 root, 1 tip), G = joint index
    (0, .5, 1 for the three segments), B = region."""
    lengths = [0.050, 0.044, 0.034]
    total = sum(lengths)
    bm = bmesh.new()
    seg, rings_per = 8, 8
    rows, alongs, joints = [], [], []
    z = 0.0
    for s, length in enumerate(lengths):
        for i in range(rings_per + (1 if s == len(lengths) - 1 else 0)):
            t = i / rings_per
            zz = z + t * length
            along = zz / total
            knuckle = 1.0 + 0.35 * math.exp(-((t) / 0.12) ** 2) if s > 0 else 1.0
            r = (0.0042 - 0.0032 * along) * knuckle
            rows.append([bm.verts.new((math.cos(k / seg * math.tau) * r, math.sin(k / seg * math.tau) * r, zz))
                         for k in range(seg)])
            alongs.append(along)
            joints.append(s / 2.0)
        z += length
    for i in range(len(rows) - 1):
        for k in range(seg):
            bm.faces.new((rows[i][k], rows[i][(k + 1) % seg], rows[i + 1][(k + 1) % seg], rows[i + 1][k]))
    tip = bm.verts.new((0, 0, total + 0.002))
    # Rest pose: a limb, not a stick. Each joint turns a little further, so
    # the cilium arches outward and down like a resting leg.
    pivots = [lengths[0], lengths[0] + lengths[1]]
    turns = [0.55, 0.75]
    for v in list(bm.verts):
        p = v.co.copy()
        for pz, ang in reversed(list(zip(pivots, turns))):
            if p.z > pz:
                rel = Vector((p.x, p.y, p.z - pz))
                rel.rotate(Matrix.Rotation(ang, 3, "X"))
                p = Vector((rel.x, rel.y, rel.z + pz))
        v.co = p
    for k in range(seg):
        bm.faces.new((rows[-1][k], rows[-1][(k + 1) % seg], tip))
    alongs.append(1.0)
    joints.append(1.0)
    bm.verts.index_update()
    mesh = bpy.data.meshes.new("Cilium")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("Cilium", mesh)
    bpy.context.collection.objects.link(obj)
    uv = mesh.uv_layers.new(name="UVMap")
    colors = mesh.color_attributes.new(name="Anatomy", type="FLOAT_COLOR", domain="POINT")
    ring_of = {}
    for ri, row in enumerate(rows):
        for k in range(seg):
            ring_of[ri * seg + k] = (ri, k)
    for v in mesh.vertices:
        if v.index < len(rows) * seg:
            ri, k = ring_of[v.index]
            colors.data[v.index].color = (alongs[ri], joints[ri], REGIONS["cilium"] / 255.0, 1.0)
        else:
            colors.data[v.index].color = (1.0, 1.0, REGIONS["cilium"] / 255.0, 1.0)
    for loop in mesh.loops:
        v = mesh.vertices[loop.vertex_index]
        a = math.atan2(v.co.y, v.co.x) / math.tau % 1.0
        uv.data[loop.index].uv = (a, v.co.z / total)
    for p in mesh.polygons:
        p.use_smooth = True
    obj["region"] = "cilium"
    return obj


def build():
    clear()
    objs = [membrane()]
    objs.append(blob("Nucleus", (0.035, -0.018, 0.068), 0.068, "nucleus", 0.11, wrinkle=0.16, stretch=(1.1, 0.95, 0.8)))
    objs.append(blob("Nucleolus", (0.05, -0.026, 0.074), 0.024, "nucleolus", 0.23, wrinkle=0.08, subdiv=3))
    for i, (c, r) in enumerate([((-0.10, 0.05, 0.045), 0.040), ((-0.03, 0.10, 0.04), 0.028),
                                ((0.13, 0.06, 0.035), 0.026), ((-0.14, -0.07, 0.035), 0.033)]):
        objs.append(blob("Vacuole_%d" % i, c, r, "vacuole", 0.3 + 0.1 * i, wrinkle=0.03, stretch=(1, 1, 0.82)))
    for i in range(11):
        a = rng(i, 1) * math.tau
        d = 0.08 + rng(i, 2) * 0.11
        c = Vector((math.cos(a) * d, math.sin(a) * d * 0.85, 0.03 + rng(i, 3) * 0.05))
        if not inside(c, 0.78):
            c *= 0.7
        axis = (math.cos(a + 1.3 + rng(i, 4)), math.sin(a + 1.3), 0.35 * (rng(i, 5) - 0.5))
        objs.append(capsule("Mito_%d" % i, c, 0.05 + rng(i, 6) * 0.03, 0.011, axis, "mitochondrion", rng(i, 7)))
    # Granule clusters: one object per cluster, many small grains.
    for cl in range(3):
        a = cl / 3 * math.tau + 0.4
        centre = Vector((math.cos(a) * 0.12, math.sin(a) * 0.10, 0.03))
        bm = bmesh.new()
        for g in range(26):
            off = Vector(((rng(g, cl * 3 + 8) - 0.5) * 0.06, (rng(g, cl * 3 + 9) - 0.5) * 0.05, rng(g, cl * 3 + 10) * 0.035))
            m = Matrix.Translation(off)
            bmesh.ops.create_icosphere(bm, subdivisions=1, radius=0.0035 + 0.003 * rng(g, cl), matrix=m)
        mesh = bpy.data.meshes.new("Granules_%d" % cl)
        bm.to_mesh(mesh)
        bm.free()
        obj = bpy.data.objects.new("Granules_%d" % cl, mesh)
        obj.location = centre
        bpy.context.collection.objects.link(obj)
        objs.append(finish(obj, "granule", 0.5 + cl * 0.15, uv="smart"))
    # A filament bundle arcing over the nucleus.
    fil = []
    for f in range(6):
        pts = []
        for i in range(24):
            t = i / 23
            ang = -1.2 + t * 2.4 + f * 0.05
            pts.append(Vector((math.cos(ang) * (0.09 + 0.006 * f), math.sin(ang) * (0.07 + 0.005 * f),
                               0.035 + 0.045 * math.sin(t * math.pi) + 0.004 * math.sin(t * 9 + f))))
        fil.append(tube_mesh("Filament_%d" % f, pts, 0.0022, "filament", f / 6))
    bpy.ops.object.select_all(action="DESELECT")
    for o in fil:
        o.select_set(True)
    bpy.context.view_layer.objects.active = fil[0]
    bpy.ops.object.join()
    fil[0].name = "Filaments"
    fil[0].data.name = "Filaments"
    objs.append(finish(fil[0], "filament", 0.8, uv="smart"))
    objs.append(cilium())
    for o in objs:
        if o.name == "Cilium":
            continue
        if o.name != "Membrane":
            worst = max(((o.matrix_world @ v.co).x / RX) ** 2 + ((o.matrix_world @ v.co).y / RY) ** 2
                        + ((o.matrix_world @ v.co).z / RZ) ** 2 for v in o.data.vertices)
            low = min((o.matrix_world @ v.co).z for v in o.data.vertices)
            if worst > 0.92 or low < 0.0:
                raise RuntimeError("organelle %s pokes out of the membrane (%.2f, floor %.3f)" % (o.name, worst, low))
    return objs


def materials(objs):
    def mat(name, color, alpha=1.0):
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        b = m.node_tree.nodes["Principled BSDF"]
        b.inputs["Base Color"].default_value = (*color, 1)
        b.inputs["Roughness"].default_value = 0.25
        if alpha < 1.0:
            b.inputs["Transmission Weight"].default_value = 1.0
            b.inputs["IOR"].default_value = 1.38
            b.inputs["Coat Weight"].default_value = 0.6
            b.inputs["Thin Film Thickness"].default_value = 420.0
        return m
    table = {"membrane": mat("membrane", (0.85, 0.9, 0.95), 0.2),
             "nucleus": mat("nucleus", (0.55, 0.18, 0.42)), "nucleolus": mat("nucleolus", (0.3, 0.05, 0.25)),
             "vacuole": mat("vacuole", (0.6, 0.8, 0.85), 0.5), "mitochondrion": mat("mitochondrion", (0.85, 0.45, 0.2)),
             "granule": mat("granule", (0.95, 0.85, 0.4)), "filament": mat("filament", (0.6, 0.3, 0.75)),
             "cilium": mat("cilium", (0.7, 0.55, 0.8))}
    for o in objs:
        o.data.materials.append(table[o["region"]])


def review(objs):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 48
    scene.render.resolution_x, scene.render.resolution_y = 960, 640
    world = bpy.data.worlds.new("w")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.05, 0.04, 0.05, 1)
    bpy.ops.mesh.primitive_plane_add(size=3)
    floor = bpy.context.object
    fm = bpy.data.materials.new("floor")
    fm.use_nodes = True
    fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.35, 0.16, 0.07, 1)
    floor.data.materials.append(fm)
    # A ring of instanced cilia at the skirt, for the review only.
    cil = bpy.data.objects["Cilium"]
    for i in range(40):
        a = rng(i, 40) * math.tau
        d = 1.0 + rng(i, 41) * 0.5
        inst = cil.copy()
        inst.location = (math.cos(a) * RX * d, math.sin(a) * RY * d, 0)
        inst.rotation_euler = (0.25 + rng(i, 42) * 0.4, 0, a - math.pi / 2)
        inst.scale = [0.7 + rng(i, 43) * 0.6] * 3
        bpy.context.collection.objects.link(inst)
    bpy.ops.object.light_add(type="SPOT", location=(0.6, -0.5, 0.8))
    spot = bpy.context.object
    spot.data.energy = 120
    spot.data.color = (1.0, 0.8, 0.55)
    spot.rotation_euler = (math.radians(50), 0, math.radians(50))
    bpy.ops.object.light_add(type="AREA", location=(-0.6, 0.6, 0.7))
    bpy.context.object.data.energy = 25
    bpy.context.object.rotation_euler = (math.radians(-45), math.radians(-30), 0)
    bpy.ops.object.camera_add(location=(0.62, -0.62, 0.42))
    camera = bpy.context.object
    camera.rotation_euler = (math.radians(66), 0, math.radians(45))
    camera.data.lens = 42
    scene.camera = camera
    (OUT / "review").mkdir(exist_ok=True)
    scene.render.filepath = str(OUT / "review" / "colony_three_quarter.png")
    bpy.ops.render.render(write_still=True)
    camera.location = (0.05, -0.62, 0.10)
    camera.rotation_euler = (math.radians(84), 0, math.radians(4))
    scene.render.filepath = str(OUT / "review" / "colony_low.png")
    bpy.ops.render.render(write_still=True)
    # Review-only objects stay out of the export.
    for o in list(bpy.data.objects):
        if o.name.startswith("Cilium.") or o.type in ("LIGHT", "CAMERA") or o == floor:
            bpy.data.objects.remove(o)


def export(objs):
    tris = {}
    for o in objs:
        o.data.calc_loop_triangles()
        tris[o.name] = len(o.data.loop_triangles)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "waking_colony.blend"), check_existing=False)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUT / "waking_colony.glb"), export_format="GLB", use_selection=True,
                              export_yup=True, export_apply=True, export_normals=True, export_tangents=True,
                              export_texcoords=True, export_materials="EXPORT",
                              export_vertex_color="NAME", export_vertex_color_name="Anatomy",
                              export_animations=False)
    manifest = {"schema_version": 1, "seed": SEED, "membrane_half_extents_m": [RX, RY, RZ],
                "regions": REGIONS, "objects": [{"name": o.name, "region": o["region"], "triangles": tris[o.name],
                                                 "location": list(o.matrix_world.translation)} for o in objs],
                "triangles_total": sum(tris.values())}
    (OUT / "waking_colony.json").write_text(json.dumps(manifest, indent=1))
    print("[WAKING COLONY] %d objects, %d triangles" % (len(objs), manifest["triangles_total"]))


objs = build()
materials(objs)
review(objs)
export(objs)
