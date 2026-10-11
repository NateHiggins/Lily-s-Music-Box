"""Replace the 48x72, 2.2mm/pixel paper sprite with the same native surface."""
from pathlib import Path
import bpy
ROOT=Path(__file__).resolve().parents[3]
bpy.ops.wm.read_factory_settings(use_empty=True)
width=48*.0022;height=72*.0022
bpy.ops.mesh.primitive_plane_add(size=1)
obj=bpy.context.object;obj.name='PaperTag';obj.rotation_euler.x=1.5707963267948966
obj.scale=(width,height,1)
bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
uv=obj.data.uv_layers.active
for loop in obj.data.loops:
    p=obj.data.vertices[loop.vertex_index].co
    uv.data[loop.index].uv=(p.x,p.z)
obj.data.materials.append(bpy.data.materials.new('paper'))
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/radiator_paper_tag.blend'))
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/radiator_paper_tag.glb'),export_format='GLB',export_yup=True,export_apply=True)
print('NATIVE PAPER TAG:',width,height,'; same position and visibility owner')
