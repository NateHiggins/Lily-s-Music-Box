"""Export the selected original static pet from its authoritative saved blend.
CPU geometry/export only. Never renders or writes the source blend.
Blender5.2 -b --python-exit-code 1 -P this.py -- --repo ROOT --source BLEND --out GLB
"""
from pathlib import Path
import argparse,sys,hashlib,json
import bpy
p=argparse.ArgumentParser();p.add_argument('--repo',type=Path,required=True);p.add_argument('--source',type=Path,required=True);p.add_argument('--out',type=Path,required=True)
a=p.parse_args(sys.argv[sys.argv.index('--')+1:]);before=hashlib.sha256(a.source.read_bytes()).hexdigest();sys.path.insert(0,str(a.repo/'art/blender/scripts'))
from export_character_hair import prepare_static_hair_mesh,HairDerivativeExportExtension
from check_exported_tangents import validate
bpy.ops.wm.open_mainfile(filepath=str(a.source))
objects=[o for o in bpy.data.objects if o.type=='MESH' and o.name.endswith('_StaticFirstPass')]
assert len(objects)==1
asset=objects[0];assert not asset.modifiers and not asset.parent and asset.data.shape_keys is None
bpy.ops.object.select_all(action='DESELECT');asset.hide_set(False);asset.select_set(True);bpy.context.view_layer.objects.active=asset
row,fields=prepare_static_hair_mesh(asset)
import io_scene_gltf2
HairDerivativeExportExtension.corrected=0;io_scene_gltf2.glTF2ExportUserExtension=HairDerivativeExportExtension
a.out.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(a.out),export_format='GLB',use_selection=True,export_skins=False,export_animations=False,export_tangents=True,export_attributes=True)
assert HairDerivativeExportExtension.corrected==row['triangles']
result=validate(a.out);assert result['triangles']==row['triangles'];assert hashlib.sha256(a.source.read_bytes()).hexdigest()==before
result['source_sha256']=before;result['scope']='Saved native static export and strict derivatives only; no rendered/runtime acceptance'
a.out.with_suffix('.export_report.json').write_text(json.dumps(result,indent=2)+'\n');print('PET_SAVED_SOURCE_EXPORT',json.dumps(result))
