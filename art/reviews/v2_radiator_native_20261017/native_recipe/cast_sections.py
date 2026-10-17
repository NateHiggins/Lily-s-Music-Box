"""UNINSTALLED inferred three-column casting; preserves retained section envelope."""
from recipe_paths import repository_root, output_directory, primitive_source
from pathlib import Path
import bpy, bmesh, hashlib, json, math, sys
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
R = repository_root()
P = output_directory()
P.mkdir(exist_ok=True)
sys.path.insert(0, str(R / 'art/blender/scripts'))
from repair_surface_uvs import repair_scene
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0

def ellipsoid(name, at, scale):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, location=at)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj

def tube(name, a, b, radius, segments=24):
    a, b = (Vector(a), Vector(b))
    delta = b - a
    bpy.ops.mesh.primitive_cylinder_add(vertices=segments, radius=radius, depth=delta.length, location=(a + b) / 2)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler = delta.to_track_quat('Z', 'Y').to_euler()
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return obj

def boolean(body, other, operation):
    bpy.context.view_layer.objects.active = body
    mod = body.modifiers.new('Foundry ' + operation, 'BOOLEAN')
    mod.operation = operation
    mod.solver = 'EXACT'
    mod.object = other
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(other, do_unlink=True)
outer = []
inner = []
for index, depth in enumerate([-0.075, 0, 0.075]):
    outer.append(tube('OuterColumn%d' % index, (0, -depth, 0.055), (0, -depth, 0.615), 0.022))
    inner.append(tube('SteamColumn%d' % index, (0, -depth, 0.05), (0, -depth, 0.62), 0.017))
for index, height in enumerate([0.055, 0.615]):
    outer.append(ellipsoid('Header%d' % index, (0, 0, height), (0.04, 0.113, 0.055)))
    inner.append(ellipsoid('SteamGallery%d' % index, (0, 0, height), (0.034, 0.108, 0.05)))
for index, height in enumerate([0.085, 0.615]):
    outer.append(tube('ThreadBoss%d' % index, (-0.046, 0.055, height), (0.046, 0.055, height), 0.034))
    inner.append(tube('OpenPort%d' % index, (-0.06, 0.055, height), (0.06, 0.055, height), 0.027))
outer.append(tube('IntegralBearing', (0, 0, 0), (0, 0, 0.032), 0.028))
body = outer[0]
for other in outer[1:]:
    boolean(body, other, 'UNION')
cavity = inner[0]
for other in inner[1:]:
    boolean(cavity, other, 'UNION')
boolean(body, cavity, 'DIFFERENCE')
body.name = 'CastSectionThreeColumnCandidate'
bpy.context.view_layer.objects.active = body
bpy.ops.object.select_all(action='DESELECT')
body.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
bm = bmesh.new()
bm.from_mesh(body.data)
bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-06)
bmesh.ops.triangulate(bm, faces=list(bm.faces))
bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
bm.to_mesh(body.data)
bm.free()
for face in body.data.polygons:
    face.use_smooth = True
tile = 0.4
uv = body.data.uv_layers.active or body.data.uv_layers.new(name='Metres')
for face in body.data.polygons:
    normal = face.normal.normalized()
    seed = Vector((0, 0, 1))
    if abs(normal.dot(seed)) > 0.95:
        seed = Vector((1, 0, 0))
    u = seed.cross(normal).normalized()
    v = normal.cross(u).normalized()
    for loop in face.loop_indices:
        at = body.data.vertices[body.data.loops[loop].vertex_index].co
        uv.data[loop].uv = (at.dot(u) / tile, at.dot(v) / tile)
repair_scene()
with bpy.data.libraries.load(str(R / 'art/blender/heating_distribution.blend'), link=False) as (available, loaded):
    loaded.materials = ['iron_neutral']
material = loaded.materials[0]
body.data.materials.clear()
body.data.materials.append(material)
for polygon in body.data.polygons:
    polygon.material_index = 0
bm = bmesh.new()
bm.from_mesh(body.data)
bm.transform(body.matrix_world)
bm.normal_update()
tree = BVHTree.FromBMesh(bm)
closed = all((e.is_manifold for e in bm.edges))
volume = bm.calc_volume(signed=True)
bm.free()
checks = []

def check(label, passed, **detail):
    checks.append(dict(label=label, passed=bool(passed), **detail))
check('closed positive pressure-wall solid', closed and volume > 0, volume_m3=volume)
corners = [body.matrix_world @ Vector(v) for v in body.bound_box]
bounds = [min((v[i] for v in corners)) for i in range(3)] + [max((v[i] for v in corners)) for i in range(3)]
check('retained 92mm pitch and 230mm depth envelope', bounds[0] >= -0.046001 and bounds[3] <= 0.046001 and (bounds[1] >= -0.115001) and (bounds[4] <= 0.115001), bounds_blender=bounds)
check('retained BODY_BOTTOM and BODY_TOP relative height', abs(bounds[2]) < 1e-06 and abs(bounds[5] - 0.67) < 1e-06)
check('mesh-only installation keeps the retained prop origin', body.matrix_world == Matrix.Identity(4))
for height in [0.085, 0.615]:
    for index in range(8):
        angle = index * math.tau / 8
        y = 0.055 + math.cos(angle) * 0.018
        z = height + math.sin(angle) * 0.018
        check('open opposed pressure ports', tree.ray_cast(Vector((-0.07, y, z)), Vector((1, 0, 0)), 0.14)[0] is None, height=height, ray=index)
for depth in [-0.075, 0, 0.075]:
    check('continuous internal steam column', tree.ray_cast(Vector((0, -depth, 0.16)), Vector((0, 0, 1)), 0.34)[0] is None, depth=depth)
for depth in [-0.0375, 0.0375]:
    check('real outside convection slot between columns', tree.ray_cast(Vector((0, -depth, 0.16)), Vector((0, 0, 1)), 0.34)[0] is None, depth=depth)
body.data.calc_loop_triangles()
uv = body.data.uv_layers.active
bad = 0
for tri in body.data.loop_triangles:
    a, b, c = [uv.data[i].uv for i in tri.loops]
    if tri.area > 1e-12 and abs((b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)) < 1e-13:
        bad += 1
check('native metric charts have no collapsed visible triangles', bad == 0, bad=bad)
native = P / 'three_column_casting_candidate.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(native))
report = dict(evidence_class='INERT', scope='UNINSTALLED inferred geometry prototype, not period/human/runtime acceptance. End plugs, matching vent, feet, valve/union fit, strict GLB export and runtime integration remain pending.', source_bindings_lf={'game/scripts/props/radiator_prop.gd': hashlib.sha256((R / 'game/scripts/props/radiator_prop.gd').read_bytes().replace(b'\r\n', b'\n')).hexdigest()}, native_sha256=hashlib.sha256(native.read_bytes()).hexdigest(), checks=checks, failures=[c for c in checks if not c['passed']], triangles=len(body.data.loop_triangles))
(P / 'prototype_review.json').write_text(json.dumps(report, indent=2) + '\n')
print('THREE COLUMN PROTOTYPE', len(checks), 'checks', len(report['failures']), 'failures', report['triangles'], 'triangles', flush=True)
if report['failures']:
    raise RuntimeError(report['failures'])
