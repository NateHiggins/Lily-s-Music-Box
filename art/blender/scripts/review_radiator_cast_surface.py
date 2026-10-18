"""Render identical native castings with old/new finishes under two lights.

Blender --python-exit-code 1 --python this_file -- --native FILE --out DIR
Diagnostic only: never writes the source blend or any shipping geometry.
"""
import argparse
import json
from pathlib import Path
import sys

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(Path(__file__).parent))
from fabrication_native_batch import material

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--native', type=Path, required=True)
parser.add_argument('--out', type=Path, required=True)
parser.add_argument('--target-height', type=float, default=.35)
parser.add_argument('--view-height', type=float, default=.52)
parser.add_argument('--cast-only', action='store_true')
parser.add_argument('--from-port-side',action='store_true',help='Match the installed player-facing joining-port side')
parser.add_argument('--stock', choices=['CastSectionThreeColumnCandidate','CastShoeFoot'],
                    default='CastSectionThreeColumnCandidate')
args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
out = args.out.resolve()
out.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(args.native.resolve()))
scene = bpy.context.scene
for obj in list(scene.objects):
    obj.hide_render = True
source = bpy.data.objects[args.stock]
draws = []
for x in ([-.092, 0, .092] if args.stock=='CastSectionThreeColumnCandidate' else [0]):
    draw = source.copy()
    draw.data = source.data.copy()
    scene.collection.objects.link(draw)
    draw.hide_render = False
    draw.location.x += x
    draws.append(draw)
catalog = json.loads((ROOT / 'game/data/runtime_material_sets.json').read_text())['materials']
old = material(ROOT, 'Review_worked_iron', dict(catalog_key='iron_neutral', normal=.35,
               roughness=1, tint=[1, 1, 1], pigment=1), catalog)
new = source.data.materials[0]
assert new.name.startswith('radiator_cast_iron')
scene.render.engine = 'CYCLES'
scene.cycles.samples = 24
scene.cycles.use_denoising = True
scene.render.resolution_x, scene.render.resolution_y = 1000, 900
scene.render.resolution_percentage = 100
scene.world = bpy.data.worlds.new('Neutral_cast_review')
scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs['Color'].default_value = (.16, .16, .16, 1)
scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value = .4
bpy.ops.object.camera_add(location=(.10, .60, args.target_height + .12) if args.from_port_side else (.30, -.60, args.target_height + .18))
camera = bpy.context.object
target = Vector((0, .055 if args.from_port_side else .05, args.target_height))
camera.rotation_euler = (target - camera.location).to_track_quat('-Z', 'Y').to_euler()
camera.data.type = 'ORTHO'
camera.data.ortho_scale = args.view_height
scene.camera = camera
bpy.ops.object.light_add(type='AREA')
light = bpy.context.object
light.data.energy = 35
light.data.shape = 'DISK'
light.data.size = .20
for identity, at in [('diffuse', (.25, -.55, args.target_height + .35)),
                     ('grazing', (-.45, .0, args.target_height + .11))]:
    if args.from_port_side:at=(at[0],abs(at[1])+.05,at[2])
    light.location = at
    light.rotation_euler = (target - light.location).to_track_quat('-Z', 'Y').to_euler()
    for finish, mat in [('worked_before', old), ('cast_after', new)]:
        if args.cast_only and finish == 'worked_before':
            continue
        for draw in draws:
            draw.data.materials[0] = mat
        scene.render.filepath = str(out / (identity + '_' + finish + '.png'))
        bpy.ops.render.render(write_still=True)
print('CAST SURFACE NATIVE REVIEW: four comparison frames written; human review required')
