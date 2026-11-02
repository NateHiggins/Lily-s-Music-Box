"""Publish the additive closet-kit library from its editable native source.
Source/export preparation only; this never installs a toilet or changes gameplay.
"""
import argparse,json,struct,sys
from pathlib import Path
import bpy

arguments=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
p=argparse.ArgumentParser();p.add_argument('--project-root',required=True);p.add_argument('--source',required=True);p.add_argument('--out',required=True);args=p.parse_args(arguments)
root=Path(args.project_root).resolve();source=Path(args.source).resolve();out=Path(args.out).resolve()
sys.path.insert(0,str(root/'art/blender/scripts'))
from metric_gltf_export import CatalogueMetricUV
from check_exported_tangents import validate
bpy.ops.wm.open_mainfile(filepath=str(source))
collection=bpy.data.collections['02_SERVICE_KIT_EXPORTS']
profiles={'WCService_3755','WCService_4155','WCService_4255','WCService_4755','WCService_5255','WCService_4255_Bypass'}
assert {o.name for o in collection.objects if o.type=='EMPTY'}==profiles
bpy.ops.object.select_all(action='DESELECT')
for obj in collection.objects:
 obj.hide_set(False);obj.hide_render=False;obj.select_set(True)
bpy.context.view_layer.update()
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=CatalogueMetricUV
out.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(out),export_format='GLB',use_selection=True,
 export_yup=True,export_tangents=True,export_attributes=True,export_materials='EXPORT',
 export_animations=False,export_extras=True)
raw=out.read_bytes();length=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+length])
assert not doc.get('images') and not doc.get('animations') and not doc.get('skins')
assert profiles<={node.get('name') for node in doc['nodes']}
assert len(doc['meshes'])==18
triangles=sum(doc['accessors'][part['indices']]['count']//3 for mesh in doc['meshes'] for part in mesh['primitives'])
assert triangles==36752,triangles
assert {m['name'] for m in doc['materials']}=={'nickel_plated','porcelain_fixture','iron_blackened'}
result=validate(out)
print('CLOSET_LIBRARY_PUBLICATION',json.dumps({'triangles':triangles,'surfaces':18,'profiles':sorted(profiles),'tangents':result}),flush=True)
