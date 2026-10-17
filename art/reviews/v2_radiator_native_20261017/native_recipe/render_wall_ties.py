"""Native cutaway views of actual fixed/captive bracket poses; wall omitted."""
from recipe_paths import repository_root, output_directory, primitive_source
from pathlib import Path
import json, hashlib
import bpy
from mathutils import Matrix, Vector
P = output_directory()
B = output_directory()
native = P / 'sliding_wall_ties_candidate.blend'
family = B / 'packed_union_candidate.blend'
bpy.ops.wm.open_mainfile(filepath=str(native))
stocks = {o.name: o for o in bpy.data.objects if o.type == 'MESH'}
with bpy.data.libraries.load(str(family), link=False) as (available, loaded):
    loaded.objects = ['CastSectionThreeColumnCandidate']
casting = loaded.objects[0]
bpy.context.collection.objects.link(casting)
casting.hide_render = True
plan = json.loads((P / 'wall_tie_mount_plan.json').read_text())['ties']
mounts = json.loads((P / 'sliding_wall_ties_review.json').read_text())['mounts']
tie = next((t for t in plan if t['actor'] == 'F01_LOBBY_RADIATOR_01' and t['side'] == 'right'))
mount = next((t for t in mounts if t['actor'] == tie['actor'] and t['side'] == tie['side']))
count = tie['sections']
x, y, z = tie['column_local_blender']
half = (count - 1) * 0.092 / 2
shift = max(0, half - 0.322)
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 24
scene.cycles.use_denoising = True
scene.render.resolution_x = 1200
scene.render.resolution_y = 1000
scene.render.resolution_percentage = 100
world = bpy.data.worlds.new('Wall-tie diagnostic')
world.use_nodes = True
world.node_tree.nodes['Background'].inputs[1].default_value = 0.7
scene.world = world
bpy.ops.object.camera_add()
camera = bpy.context.object
camera.data.type = 'ORTHO'
camera.data.ortho_scale = 0.32
scene.camera = camera
target = Vector((x + 0.02, tie['bracket_front_y'] - 0.005, 0.59))
bpy.ops.object.light_add(type='AREA', location=(x - 0.25, -0.35, 0.95))
light = bpy.context.object
light.data.energy = 45
light.data.size = 0.4
light.rotation_euler = (target - light.location).to_track_quat('-Z', 'Y').to_euler()
poses = json.loads((B / 'pitch_kinematics_review.json').read_text())['poses']
images = []
for label, pitch, opening, front in [('seated_rear', 0.35, 0, False), ('withdrawn_rear', 0.35, 0.04, False), ('wrong_pitch_rear', -1, 0, False), ('seated_front', 0.35, 0, True)]:
    row = next((p for p in poses if p['sections'] == count and p['pitch'] == pitch))
    body = Matrix.Translation((opening, 0, 0)) @ Matrix(row['body_matrix'])
    fixed = Matrix.Translation((x, tie['bracket_front_y'], z))
    shown = []

    def show(source, xf):
        obj = source.copy()
        obj.data = source.data
        obj.hide_render = False
        obj.matrix_world = xf
        bpy.context.collection.objects.link(obj)
        shown.append(obj)
    show(stocks['SlottedWallBracket'], fixed)
    show(stocks[mount['hardware']], fixed)
    show(stocks[mount['rod']], body @ Matrix.Translation((x, y, z)))
    for index in [tie['column_index'] - 1, tie['column_index']]:
        show(casting, body @ Matrix.Translation(((index - (count - 1) / 2) * 0.092 + shift, 0.03, 0.105)))
    camera.location = (x + 0.24, 0.22 if front else tie['bracket_front_y'] - 0.32, 0.8)
    camera.rotation_euler = (target - camera.location).to_track_quat('-Z', 'Y').to_euler()
    file = P / ('wall_tie_' + label + '.png')
    scene.render.filepath = str(file)
    bpy.ops.render.render(write_still=True)
    images.append(dict(file=file.name, sha256=hashlib.sha256(file.read_bytes()).hexdigest()))
    for obj in shown:
        bpy.data.objects.remove(obj, do_unlink=True)
(P / 'sliding_wall_ties_captures.json').write_text(json.dumps(dict(evidence_class='INERT', scope='Uninstalled native diagnostic, backing wall intentionally omitted to expose captive T-head and anchor embedment. No runtime/human acceptance.', support_sha256=hashlib.sha256(native.read_bytes()).hexdigest(), family_sha256=hashlib.sha256(family.read_bytes()).hexdigest(), images=images), indent=2) + '\n')
