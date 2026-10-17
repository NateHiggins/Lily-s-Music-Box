"""Matched neutral-light vent exterior/open-chamber views; render only."""
import argparse
from pathlib import Path
import sys
import bpy
from mathutils import Vector

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--native',required=True,type=Path)
p.add_argument('--out',required=True,type=Path)
args=p.parse_args(sys.argv[sys.argv.index('--')+1:])
args.out=args.out.resolve()
args.out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(args.native.resolve()))
scene=bpy.context.scene
for obj in scene.objects:obj.hide_render=True
for name in ('VentBody','VentCap','FloatAndNeedle','VentOrificeInsert_2'):
    bpy.data.objects[name].hide_render=False
scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True
scene.render.resolution_x=1000;scene.render.resolution_y=800;scene.render.resolution_percentage=100
world=bpy.data.worlds.new('Neutral service brass');world.use_nodes=True
world.node_tree.nodes['Background'].inputs['Color'].default_value=(.17,.17,.17,1)
world.node_tree.nodes['Background'].inputs['Strength'].default_value=.45;scene.world=world
bpy.ops.object.camera_add();camera=bpy.context.object;camera.data.type='ORTHO'
camera.data.ortho_scale=.11;scene.camera=camera
bpy.ops.object.light_add(type='AREA');light=bpy.context.object
light.data.energy=12;light.data.size=.12
target=Vector((.034,0,.028))
for label,offset in [('diffuse',(.12,-.20,.22)),('grazing',(.02,.17,.03))]:
    light.location=target+Vector(offset)
    light.rotation_euler=(target-light.location).to_track_quat('-Z','Y').to_euler()
    for state in ('assembled','open'):
        for name in ('VentCap','VentOrificeInsert_2'):
            bpy.data.objects[name].hide_render=(state=='open')
        camera.location=target+Vector((.10,-.22,.15) if state=='assembled' else (.015,-.04,.19))
        camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(args.out/(state+'_'+label+'.png'))
        bpy.ops.render.render(write_still=True)
print('VENT DETAIL: four neutral diagnostic frames; no source geometry changed')
