"""Export the editable 4B bath without embedding duplicate catalogue images.
Run with Blender 5.2: blender -b -t 2 --python-exit-code 1 -P this_file.
The native source owns geometry; this publisher preserves metric UVs and pivots.
"""
from pathlib import Path
import bpy, json, struct
import numpy as np
ROOT=Path(__file__).resolve().parents[3]
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/clawfoot_bath.blend'))
import sys
sys.path.insert(0,str(Path(__file__).resolve().parent))
from metric_gltf_export import CatalogueMetricUV



# Guide attributes force split chart tangents before the metric-UV hook computes
# their actual derivatives. Never relax the exported tangent checker instead.
exports=bpy.data.collections['02_TUB_EXPORT']
for obj in exports.objects:
    if obj.name in ['HotValve.001','ColdValve.001','CurtainDrawn.001']:
        obj.name=obj.name.removesuffix('.001')
    if obj.type!='MESH':continue
    mesh=obj.data;uv=mesh.uv_layers['Metres']
    old=mesh.attributes.get('_TANGENT_GUIDE')
    if old:mesh.attributes.remove(old)
    guide=mesh.attributes.new(name='_TANGENT_GUIDE',type='FLOAT_VECTOR',domain='CORNER')
    for face in mesh.polygons:
        assert len(face.vertices)==3,(obj.name,'nontriangular stock')
        p=[mesh.vertices[i].co for i in face.vertices]
        q=[uv.data[i].uv for i in face.loop_indices]
        for a,b in [(0,1),(1,2),(2,0)]:
            length=(p[b]-p[a]).length
            assert length>1e-10 and abs((q[b]-q[a]).length/length-1)<.005,(obj.name,'physical UV edge scale')
        a=q[1]-q[0];b=q[2]-q[0];det=a.x*b.y-b.x*a.y
        assert abs(det)>1e-14,(obj.name,'collapsed metric chart')
        tangent=((p[1]-p[0])*b.y-(p[2]-p[0])*a.y)/det;tangent.normalize()
        for index in face.loop_indices:guide.data[index].vector=(tangent.x,tangent.z,-tangent.y)
    assert mesh.attributes.get('_METRE_UV') is not None,obj.name
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=CatalogueMetricUV
bpy.ops.object.select_all(action='DESELECT')
for collection in [exports,bpy.data.collections['00_ATTACHMENT_DATUMS']]:
    for obj in collection.objects:obj.select_set(True)
path=ROOT/'game/assets/props/clawfoot_bath.glb'
bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,
    export_yup=True,export_tangents=True,export_attributes=True,
    export_materials='EXPORT',export_animations=False,export_morph=False)
raw=path.read_bytes();gltf=json.loads(raw[20:20+struct.unpack_from('<I',raw,12)[0]])
assert not gltf.get('images'),'Catalogue maps must not be duplicated in the GLB'
assert not gltf.get('animations') and not gltf.get('skins')
cloth=gltf['meshes'][next(node['mesh'] for node in gltf['nodes'] if node['name']=='TubMesh__CurtainDrawn')]
assert all('TEXCOORD_1' in primitive['attributes'] for primitive in cloth['primitives'])
import sys
sys.path.insert(0,str(ROOT/'art/blender/scripts'))
from check_exported_tangents import validate
print('CLAWFOOT_EXPORT',json.dumps(validate(path)),flush=True)
