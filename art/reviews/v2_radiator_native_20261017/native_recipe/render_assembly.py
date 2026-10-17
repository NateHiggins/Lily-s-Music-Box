"""Native assembled and cutaway review; uninstalled diagnostic only."""
from recipe_paths import repository_root, output_directory, primitive_source
from pathlib import Path
import bpy, bmesh, json, math, hashlib, os
from mathutils import Vector, Matrix
P = output_directory()
suffix = '_finished' if os.environ.get('RADIATOR_FINISHED_REVIEW') == '1' else ''
native = P / ('articulated_union' + suffix + '_candidate.blend')
bpy.ops.wm.open_mainfile(filepath=str(native))
objects = {o.name: o for o in bpy.data.objects if o.type == 'MESH'}
poses = json.loads((P / 'pitch_kinematics_review.json').read_text())['poses']
with bpy.data.libraries.load(str(P / 'pitch_shims_candidate.blend'), link=False) as (available, loaded):
    loaded.objects = [n for n in available.objects if n.startswith('Shim_')]
for obj in loaded.objects:
    bpy.context.collection.objects.link(obj)
    obj.hide_render = True
    objects[obj.name] = obj
vent_native = P / ('automatic_vent' + suffix + '_candidate.blend')
with bpy.data.libraries.load(str(vent_native), link=False) as (available, loaded):
    loaded.objects = available.objects
for obj in loaded.objects:
    if obj.type == 'MESH':
        bpy.context.collection.objects.link(obj)
        obj.hide_render = True
        objects[obj.name] = obj
brass = next((mat for mat in bpy.data.materials if mat.name.startswith('door_brass' if suffix else 'brass_dull') and mat.use_nodes))
for name in ['ValveSphericalRetainer', 'HeaderSphericalRetainer', 'FloatingMetalBearingRing']:
    objects[name].data.materials.clear()
    objects[name].data.materials.append(brass)

def show(name, pose=Matrix.Identity(4), cut=False):
    source = objects[name]
    obj = source.copy()
    obj.data = source.data.copy() if cut else source.data
    obj.matrix_world = pose
    obj.hide_render = False
    bpy.context.collection.objects.link(obj)
    if cut:
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bm.transform(pose)
        section_depth = 0.03 if name in ['ArticulatedValveHousing', 'ThreadedMovingValveCore'] else 0.085
        bmesh.ops.bisect_plane(bm, geom=list(bm.verts) + list(bm.edges) + list(bm.faces), plane_co=(0, section_depth, 0), plane_no=(0, 1, 0), clear_inner=True, dist=1e-07)
        bm.to_mesh(obj.data)
        bm.free()
        obj.matrix_world = Matrix.Identity(4)
    return obj
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
scene.cycles.samples = 16
scene.cycles.use_denoising = True
scene.render.resolution_x = 1400
scene.render.resolution_y = 1050
scene.render.resolution_percentage = 100
world = bpy.data.worlds.new('Articulated mechanism review')
world.use_nodes = True
world.node_tree.nodes['Background'].inputs[1].default_value = 0.8
scene.world = world
bpy.ops.mesh.primitive_plane_add(size=3)
floor = bpy.context.object
floor.name = 'DIAGNOSTIC_Floor'
mat = bpy.data.materials.new('Diagnostic gray')
mat.diffuse_color = (0.12, 0.12, 0.12, 1)
floor.data.materials.append(mat)
bpy.ops.object.camera_add()
camera = bpy.context.object
camera.data.type = 'ORTHO'
scene.camera = camera
bpy.ops.object.light_add(type='AREA', location=(-0.5, -1, 1.5))
light = bpy.context.object
light.data.energy = 140
light.data.size = 1.2
images = []
for pitch, cut, service in [(-1, False, False), (0.35, False, False), (1, False, False), (-1, True, False), (0.35, False, True), (0.35, True, True)]:
    row = next((p for p in poses if p['sections'] == 10 and p['pitch'] == pitch))
    a = Vector(row['fixed_joint'])
    b = Vector(row['header_joint'])
    body = Matrix(row['body_matrix'])
    beta = row['feed_angle_radians']
    theta = row['body_angle_radians']
    up = Matrix.Translation(a) @ Matrix.Rotation(-beta, 4, 'Y')
    down = Matrix.Translation(b) @ Matrix.Rotation(-theta, 4, 'Y')
    bearing = Matrix.Translation(b) @ Matrix.Rotation(-beta, 4, 'Y')
    withdraw = Matrix.Translation((0.04 if service else 0, 0, 0))
    body = withdraw @ body
    shown = [show('ArticulatedValveHousing', cut=cut), show('SphericalNeck_10', up, cut), show('FloatingMetalBearingRing', Matrix.Translation(a), cut), show('ValveSphericalRetainer', up, cut), show('HeaderSphericalSocket', withdraw @ down, cut), show('FloatingMetalBearingRing', bearing, cut), show('HeaderSphericalRetainer', withdraw @ down @ Matrix.Translation((0.001 if service else 0, 0, 0)), cut)]
    shown += [show('ThreadedMovingValveCore', Matrix.Translation((-0.53, 0.03, 0.396)), cut), show('SixSpokeHandwheel', Matrix.Translation((-0.53, 0.03, 0.396))), show('SweptSupplyElbow')]
    if not cut:
        for index in range(10):
            shown.append(show('CastSectionThreeColumnCandidate', body @ Matrix.Translation(((index - 4.5) * 0.092 + 0.092, 0.03, 0.105))))
        for x in [-0.414, 0.414]:
            shown.append(show('CastShoeFoot', body @ Matrix.Translation((x + 0.092, 0.03, 0))))
        shown.append(show('Shim_10_%s_%s' % (str(pitch).replace('-', 'minus'), 'supply' if pitch < 0 else 'far'), withdraw))
        for name, point, rotation in [('BlindHeaderPlug', (-0.368, 0.085, 0.72), math.pi), ('BlindHeaderPlug', (0.552, 0.085, 0.19), 0), ('VentHeaderReducer', (0.552, 0.085, 0.72), 0)]:
            pose = body @ Matrix.Translation(point) @ Matrix.Rotation(rotation, 4, 'Z')
            shown.extend([show(name, pose), show('HeaderSealWasher', pose)])
        vent_pose = body @ Matrix.Translation((0.552, 0.085, 0.72))
        for name in ['VentBody', 'VentCap', 'FloatAndNeedle', 'VentOrificeInsert_2']:
            shown.append(show(name, vent_pose))
        target = Vector((0, 0, 0.38))
        camera.location = (1.1, -1.8, 1.15)
        camera.data.ortho_scale = 1.65
    else:
        target = Vector((-0.41, 0.085, 0.23))
        camera.location = (-0.27, -0.65, 0.52)
        camera.data.ortho_scale = 0.55
    camera.rotation_euler = (target - camera.location).to_track_quat('-Z', 'Y').to_euler()
    light.rotation_euler = (target - light.location).to_track_quat('-Z', 'Y').to_euler()
    file = 'articulated%s_%s%s%s.png' % (suffix, str(pitch).replace('-', 'minus'), '_service' if service else '', '_cutaway' if cut else '')
    scene.render.filepath = str(P / file)
    bpy.ops.render.render(write_still=True)
    images.append(dict(file=file, sha256=hashlib.sha256((P / file).read_bytes()).hexdigest()))
    for obj in shown:
        bpy.data.objects.remove(obj, do_unlink=True)
(P / ('articulated' + suffix + '_captures.json')).write_text(json.dumps(dict(evidence_class='INERT', scope='Uninstalled native diagnostic assembled/cutaway views, not production finish, pressure/flow or human acceptance.', native_sha256=hashlib.sha256(native.read_bytes()).hexdigest(), vent_native_sha256=hashlib.sha256(vent_native.read_bytes()).hexdigest(), images=images), indent=2) + '\n')
