"""Rebuild an external copy only. Never writes repository assets."""
from pathlib import Path
import bpy
import hashlib
import importlib.util
import json

HERE=Path(__file__).parent
SOURCE=Path('C:/ov/v2merge24/art/blender/bath_shower.blend')
OUT=HERE/'helper_v2'
OUT.mkdir(parents=True,exist_ok=True)
expected=json.loads((HERE/'rig_prototype.json').read_text(encoding='utf8'))['source_sha256']
assert hashlib.sha256(SOURCE.read_bytes()).hexdigest()==expected
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
spec=importlib.util.spec_from_file_location('curtain_skin_candidate',HERE/'native_curtain_skin_helper_candidate.py')
helper=importlib.util.module_from_spec(spec);spec.loader.exec_module(helper)
metadata=helper.install_curtain_skin()
class ExportUVHandedness:
    def gather_attribute_change(self,attribute,data,normalized,export_settings):
        if attribute=='TANGENT':data['data'][:,3]*=-1
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExportUVHandedness
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'bath_shower_skin.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'bath_shower_skin.glb'),export_format='GLB',export_yup=True,export_apply=False,export_tangents=True)
old=(HERE/'bath_shower_rig_candidate.glb').read_bytes()
new=(OUT/'bath_shower_skin.glb').read_bytes()
result={'evidence_class':'INERT','scope':'Refactored native helper versus previously reviewed external prototype; no Godot/input/performance acceptance.',
    'source_sha256':expected,'helper_sha256':hashlib.sha256((HERE/'native_curtain_skin_helper_candidate.py').read_bytes()).hexdigest(),
    'candidate_glb_sha256':hashlib.sha256(new).hexdigest(),'previous_candidate_glb_sha256':hashlib.sha256(old).hexdigest(),
    'glb_bytes_exact':new==old,'bones':metadata['bone_count'],'maximum_weights':metadata['maximum_weights'],
    'unchanged_mesh_uv_digests':metadata['unchanged_mesh_uv_digests']}
(OUT/'helper_review.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8')
assert new==old,'Refactored export differs; inspect before reusing the prototype views.'
print('NATIVE HELPER REBUILD: PASS exact previous candidate GLB',result['candidate_glb_sha256'])
