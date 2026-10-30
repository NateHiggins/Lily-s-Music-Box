"""Publish the editable phone-scale arm, keeping its demonstration animation.
Shared catalogue maps remain external; no copied companion/reference is shipped.
Run using Blender --python-exit-code 1 -P this_file.
"""
from pathlib import Path
import bpy,json,struct,sys
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(Path(__file__).resolve().parent))
from metric_gltf_export import CatalogueMetricUV
from check_exported_tangents import validate
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/companion_typing_arm.blend'))
scene=bpy.context.scene
scene.frame_start=1;scene.frame_end=432;scene.render.fps=24;scene.frame_set(1)
assert bpy.data.objects['TypingArmAssembly']['baked_reference_scale']==.42
assert not any(image.packed_file for image in bpy.data.images)
assert all(Path(bpy.path.abspath(i.filepath)).is_file() for i in bpy.data.images if i.source=='FILE')
bpy.ops.object.select_all(action='DESELECT')
for name in ['02_ARM_ONLY_EXPORT','00_INTEGRATION_MARKERS']:
    for obj in bpy.data.collections[name].all_objects:
        if obj.name.startswith('KeyTarget_'):obj['key_character']=obj.name.removeprefix('KeyTarget_')
        obj.select_set(True)
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=CatalogueMetricUV
asset=ROOT/'game/assets/props/companion_typing_arm.glb'
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',use_selection=True,
    export_yup=True,export_tangents=True,export_attributes=True,export_extras=True,
    export_materials='EXPORT',export_animations=True,export_animation_mode='SCENE',
    export_anim_scene_split_object=False,export_anim_slide_to_zero=True,
    export_frame_range=True,export_force_sampling=True)
raw=asset.read_bytes();doc=json.loads(raw[20:20+struct.unpack_from('<I',raw,12)[0]])
assert not doc.get('images') and len(doc.get('animations',[]))==1
assert all(node['name'].startswith('TypingArmMesh__') for node in doc['nodes'] if 'mesh' in node)
assert sum(node['name'].startswith('KeyTarget_') for node in doc['nodes'])==43
print('ARM_EXPORT',json.dumps(validate(asset)),flush=True)
