"""Render the installed source into Mina's preview and sprite fallback."""
import bpy
from pathlib import Path
from mathutils import Vector

root=Path(__file__).resolve().parents[3]
bpy.ops.wm.open_mainfile(filepath=str(root/'art/blender/mina_resolve.blend'),load_ui=False,use_scripts=False)
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
for track in rig.animation_data.nla_tracks: track.mute=True
action=bpy.data.actions['mina_idle_calm']
rig.animation_data.action=action
rig.animation_data.action_slot=action.slots[0]
scene=bpy.context.scene
scene.frame_set(30)
scene.render.engine='BLENDER_EEVEE'
scene.render.resolution_x=512;scene.render.resolution_y=768
scene.render.resolution_percentage=100
scene.render.film_transparent=True
scene.render.image_settings.file_format='PNG'
scene.render.image_settings.color_mode='RGBA'
scene.view_settings.view_transform='Standard'
scene.world=bpy.data.worlds.new('MinaPreviewWorld');scene.world.color=(.25,.25,.25)
bpy.ops.object.camera_add(location=(.4,-4.5,.86))
camera=bpy.context.object;camera.data.type='ORTHO';camera.data.ortho_scale=1.72
camera.rotation_euler=(Vector((0,0,.86))-camera.location).to_track_quat('-Z','Y').to_euler()
scene.camera=camera
for position,energy in [((1,-3,4),350),((-2,1,3),250)]:
    bpy.ops.object.light_add(type='AREA',location=position)
    bpy.context.object.data.energy=energy;bpy.context.object.data.size=4
preview=root/'game/assets/characters/mina_vale/mina_vale_preview.png'
scene.render.filepath=str(preview)
bpy.ops.render.render(write_still=True)
# Both are rendered deliverables of the same new figure; no old art survives
# in the fallback that appears before a hero mesh is available.
bpy.data.images['Render Result'].save_render(str(root/'game/assets/npcs/mina_vale.png'),scene=scene)
