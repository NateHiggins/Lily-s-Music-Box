"""Close native mortise inspection; no scene or authority changes are saved."""
from pathlib import Path
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'tmp/v2-door-polish-20261012'
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/door_keyway.blend'))
bpy.data.objects.remove(bpy.data.objects['Keyway52'],do_unlink=True)
wood=bpy.data.objects['Keyway44'];wood.location.z=-.116
mat=bpy.data.materials.new('InspectionPaint');mat.use_nodes=True
node=mat.node_tree.nodes['Principled BSDF'];node.inputs['Base Color'].default_value=(.21,.26,.20,1);node.inputs['Roughness'].default_value=.48
wood.data.materials.append(mat)
with bpy.data.libraries.load(str(ROOT/'art/blender/door_knob_set.blend'),link=False) as (source,target):
    target.objects=list(source.objects)
for obj in target.objects:
    bpy.context.scene.collection.objects.link(obj);obj.location.y-=.022
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32
scene.render.resolution_x=1000;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('InspectionWorld');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.5,.65,.8,1)
scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.5
data=bpy.data.lights.new('RakingSoftbox','AREA');data.energy=12;data.size=.14
lamp=bpy.data.objects.new(data.name,data);scene.collection.objects.link(lamp);lamp.location=(-.16,-.25,.17)
lamp.rotation_euler=(Vector((0,-.02,-.07))-lamp.location).to_track_quat('-Z','Y').to_euler()
data=bpy.data.cameras.new('InspectionCamera');camera=bpy.data.objects.new(data.name,data)
scene.collection.objects.link(camera);scene.camera=camera;data.lens=60;data.clip_start=.001
for name,at,target in [('keyway_oblique',(.035,-.19,-.10),(0,-.02,-.11)),
                       ('keyway_front',(0,-.21,-.113),(0,-.02,-.113))]:
    camera.location=at;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(OUT/(name+'.png'));bpy.ops.render.render(write_still=True)
