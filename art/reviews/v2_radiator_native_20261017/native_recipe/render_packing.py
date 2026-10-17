"""Render actual seam opening and removal poses, never a runtime receipt."""
from recipe_paths import repository_root, output_directory, primitive_source
from pathlib import Path
import bpy, json, hashlib
from mathutils import Vector, Matrix
P = output_directory()
native = P / 'packed_union_candidate.blend'
bpy.ops.wm.open_mainfile(filepath=str(native))
objects = {o.name: o for o in bpy.data.objects if o.type == 'MESH'}
row = next((r for r in json.loads((P / 'pitch_kinematics_review.json').read_text())['poses'] if r['sections'] == 10 and r['pitch'] == 0.35))
a = Vector(row['fixed_joint'])
b = Vector(row['header_joint'])
beta = row['feed_angle_radians']
theta = row['body_angle_radians']
up = Matrix.Translation(a) @ Matrix.Rotation(-beta, 4, 'Y')
down = Matrix.Translation(b) @ Matrix.Rotation(-theta, 4, 'Y')
bearing = Matrix.Translation(b) @ Matrix.Rotation(-beta, 4, 'Y')
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 24
scene.cycles.use_denoising = True
scene.render.resolution_x = 1200
scene.render.resolution_y = 900
scene.render.resolution_percentage = 100
world = bpy.data.worlds.new('Packing diagnostic')
world.use_nodes = True
world.node_tree.nodes['Background'].inputs[1].default_value = 0.65
scene.world = world
bpy.ops.object.camera_add(location=(-0.2, 0.8, 0.5))
camera = bpy.context.object
camera.data.type = 'ORTHO'
camera.data.ortho_scale = 0.37
scene.camera = camera
target = Vector((-0.4, 0.11, 0.215))
camera.rotation_euler = (target - camera.location).to_track_quat('-Z', 'Y').to_euler()
bpy.ops.object.light_add(type='AREA', location=(-0.3, 0.4, 0.65))
light = bpy.context.object
light.data.energy = 35
light.data.size = 0.35
light.rotation_euler = (target - light.location).to_track_quat('-Z', 'Y').to_euler()
images = []
for label, opening, spread, offset in [('seated', 0, 0, 0), ('exposed', 0.04, 0, 0), ('unbending', 0.04, 0.5, 0), ('spread', 0.04, 1, 0), ('removed', 0.04, 1, 0.12)]:
    shown = []
    for name, xf in [('ArticulatedValveHousing', Matrix.Identity(4)), ('SphericalNeck_10', up), ('FloatingMetalBearingRing', Matrix.Translation(a)), ('ValveSphericalRetainer', up), ('PackedHeaderSocket', Matrix.Translation((opening, 0, 0)) @ down), ('FloatingMetalBearingRing', bearing), ('HeaderSphericalRetainer', Matrix.Translation((opening, 0, 0)) @ down @ Matrix.Translation((0.001 if opening else 0, 0, 0))), ('RemovableFibrousUnionPacking', Matrix.Translation((0, offset, 0)) @ down)]:
        source = objects[name]
        obj = source.copy()
        obj.data = source.data.copy()
        obj.hide_render = False
        obj.matrix_world = xf
        bpy.context.collection.objects.link(obj)
        shown.append(obj)
        if name == 'RemovableFibrousUnionPacking':
            obj.data.shape_keys.key_blocks['SpreadForRemoval'].value = spread
    path = P / ('packing_' + label + '.png')
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    images.append(dict(file=path.name, sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
    for obj in shown:
        bpy.data.objects.remove(obj, do_unlink=True)
(P / 'union_packing_captures.json').write_text(json.dumps(dict(evidence_class='INERT', scope='Uninstalled native packing diagnostic, unregistered material, no production pressure, inventory or human acceptance.', native_sha256=hashlib.sha256(native.read_bytes()).hexdigest(), images=images), indent=2) + '\n')
