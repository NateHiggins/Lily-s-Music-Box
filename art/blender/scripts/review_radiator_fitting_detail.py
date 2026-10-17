"""Render fitted edge breaks and exposed cloth in neutral/grazing light.

Blender --python-exit-code 1 --python this_file -- --native FILE --out DIR
Render-only diagnostic; never modifies the source native file.
"""
import argparse
import json
from pathlib import Path
import sys
import bpy
from mathutils import Vector

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--native',type=Path,required=True)
p.add_argument('--out',type=Path,required=True)
args=p.parse_args(sys.argv[sys.argv.index('--')+1:])
out=args.out.resolve();out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(args.native.resolve()))
scene=bpy.context.scene
for obj in scene.objects:obj.hide_render=True
scene.render.engine='CYCLES'
scene.cycles.samples=32
scene.cycles.use_denoising=True
scene.render.resolution_x=1000
scene.render.resolution_y=800
scene.render.resolution_percentage=100
world=bpy.data.worlds.new('Neutral fitting review');world.use_nodes=True
world.node_tree.nodes['Background'].inputs['Color'].default_value=(.17,.17,.17,1)
world.node_tree.nodes['Background'].inputs['Strength'].default_value=.45
scene.world=world
bpy.ops.object.camera_add()
camera=bpy.context.object;camera.data.type='ORTHO';scene.camera=camera
bpy.ops.object.light_add(type='AREA')
light=bpy.context.object;light.data.shape='DISK';light.data.energy=12;light.data.size=.12
for stock,scale,target in [
    ('HeaderSphericalRetainer',.12,Vector((.01,0,0))),
    ('RemovableFibrousUnionPacking',.09,Vector((.012,0,0)))]:
    draw=bpy.data.objects[stock];draw.hide_render=False
    if draw.data.shape_keys:
        draw.data.shape_keys.key_blocks['SpreadForRemoval'].value=1.0
    camera.location=target+Vector((.12,-.16,.12))
    camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.ortho_scale=scale
    for label,offset in [('diffuse',(.12,-.20,.22)),('grazing',(.02,.17,.03))]:
        light.location=target+Vector(offset)
        light.rotation_euler=(target-light.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(out/(stock+'_'+label+'.png'))
        bpy.ops.render.render(write_still=True)
    draw.hide_render=True
print('FITTING DETAIL: four native render diagnostics written; appearance review required')
