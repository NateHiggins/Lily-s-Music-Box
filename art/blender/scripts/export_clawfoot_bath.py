"""Export the editable 4B bath without embedding duplicate catalogue images.
Run with Blender 5.2: blender -b -t 2 --python-exit-code 1 -P this_file.
The native source owns geometry; this publisher preserves metric UVs and pivots.
"""
from pathlib import Path
import bpy, json, struct
import numpy as np
ROOT=Path(__file__).resolve().parents[3]
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/clawfoot_bath.blend'))
class SignedMetricUV:
    def gather_mesh_hook(self,mesh,*args):
        from io_scene_gltf2.io.exp.binary_data import BinaryData
        from io_scene_gltf2.io.com.constants import BufferViewTarget
        for p in mesh.primitives:
            raw=p.attributes.pop('_METRE_UV');q=np.frombuffer(raw.buffer_view.data,dtype='<f4').reshape(-1,3)
            uv=np.column_stack((q[:,0],-q[:,1])).astype('<f4');p.attributes['TEXCOORD_0'].buffer_view=BinaryData(uv.tobytes(),BufferViewTarget.ARRAY_BUFFER)
            def values(key):return np.frombuffer(p.attributes[key].buffer_view.data,dtype='<f4').reshape(-1,3).astype(float)
            pos=values('POSITION');n=values('NORMAL');n/=np.linalg.norm(n,axis=1)[:,None]
            idx=np.frombuffer(p.indices.buffer_view.data,dtype={5125:'<u4',5123:'<u2',5121:'u1'}[p.indices.component_type]).reshape(-1,3)
            a=pos[idx];b=uv[idx].astype(float);e=a[:,1]-a[:,0];f=a[:,2]-a[:,0];s=b[:,1]-b[:,0];t=b[:,2]-b[:,0];d=s[:,0]*t[:,1]-s[:,1]*t[:,0]
            U=(e*t[:,1,None]-f*s[:,1,None])/d[:,None];V=(-e*t[:,0,None]+f*s[:,0,None])/d[:,None]
            tan=np.zeros_like(pos);bit=np.zeros_like(pos)
            for c in range(3):np.add.at(tan,idx[:,c],U);np.add.at(bit,idx[:,c],V)
            tan-=n*np.sum(n*tan,axis=1)[:,None]
            lengths=np.linalg.norm(tan,axis=1)
            # Opposing UV charts can cancel at a shared cusp. Retain a valid
            # incident chart's projected tangent there instead of NaN.
            for vertex in np.flatnonzero(lengths<1e-12):
                incident=np.flatnonzero(np.any(idx==vertex,axis=1))
                for face in incident:
                    candidate=U[face]-n[vertex]*np.dot(n[vertex],U[face])
                    if np.linalg.norm(candidate)>1e-12:tan[vertex]=candidate;break
            tan/=np.linalg.norm(tan,axis=1)[:,None]
            w=np.where(np.sum(np.cross(n,tan)*bit,axis=1)<0,-1.,1.)
            p.attributes['TANGENT'].buffer_view=BinaryData(np.column_stack((tan,w)).astype('<f4').tobytes(),BufferViewTarget.ARRAY_BUFFER)
    def gather_material_hook(self,m,*args):
        tex=[m.normal_texture,m.emissive_texture,m.occlusion_texture]
        if m.pbr_metallic_roughness:tex.extend([m.pbr_metallic_roughness.base_color_texture,m.pbr_metallic_roughness.metallic_roughness_texture])
        for t in tex:
            if t and t.extensions and 'KHR_texture_transform' in t.extensions:
                e=t.extensions['KHR_texture_transform'].extension;e['offset']=e.get('offset',[0,0]);e['offset'][1]+=e.get('scale',[1,1])[1]

class CatalogueNames(SignedMetricUV):
    def gather_mesh_hook(self, mesh, *args):
        super().gather_mesh_hook(mesh, *args)
        for primitive in mesh.primitives:
            primitive.attributes.pop('_TANGENT_GUIDE')
    def gather_material_hook(self, material, *args):
        material.pbr_metallic_roughness=None
        material.normal_texture=None;material.occlusion_texture=None
        material.emissive_texture=None;material.emissive_factor=None
        material.extensions=None

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
        a=q[1]-q[0];b=q[2]-q[0];det=a.x*b.y-b.x*a.y
        assert abs(det)>1e-14,(obj.name,'collapsed metric chart')
        tangent=((p[1]-p[0])*b.y-(p[2]-p[0])*a.y)/det;tangent.normalize()
        for index in face.loop_indices:guide.data[index].vector=(tangent.x,tangent.z,-tangent.y)
    assert mesh.attributes.get('_METRE_UV') is not None,obj.name
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=CatalogueNames
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
