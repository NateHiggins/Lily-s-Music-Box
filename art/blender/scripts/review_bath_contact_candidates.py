"""Render hidden collision stock for review, without rewriting any native asset."""
import bpy
import math
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'art/reviews/v2_bath_contact_20261023'
for family in ['bath_lavatory','bath_water_closet']:
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/f'art/blender/{family}_contact.blend'))
    scene=bpy.context.scene
    finish=bpy.data.materials.new('Diagnostic clay');finish.diffuse_color=(.35,.55,.62,1)
    for obj in scene.objects:
        if obj.type=='MESH':obj.data.materials.clear();obj.data.materials.append(finish)
    bpy.ops.object.camera_add(location=(1.25,1.75,1.7))
    camera=bpy.context.object;camera.rotation_euler=(Vector((0,.1,.5))-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.type='ORTHO';camera.data.ortho_scale=1.2;scene.camera=camera
    for position,energy,size in [((2,-3,4),350,3),((-2,1,3),220,3)]:
        bpy.ops.object.light_add(type='AREA',location=position)
        light=bpy.context.object;light.data.energy=energy;light.data.shape='DISK';light.data.size=size
        light.rotation_euler=(Vector((0,0,.5))-light.location).to_track_quat('-Z','Y').to_euler()
    if scene.world is None:scene.world=bpy.data.worlds.new('Diagnostic world')
    scene.world.color=(.16,.16,.16)
    scene.render.engine='CYCLES';scene.cycles.samples=16
    scene.render.resolution_x=768;scene.render.resolution_y=768;scene.render.resolution_percentage=100
    scene.render.filepath=str(OUT/(family+'_contact_final.png'))
    bpy.ops.render.render(write_still=True)
