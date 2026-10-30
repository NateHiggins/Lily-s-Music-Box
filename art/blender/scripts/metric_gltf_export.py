"""Metric UV and tangent export hook shared by native movable fixtures."""
import numpy as np

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

class CatalogueMetricUV(SignedMetricUV):
    def gather_mesh_hook(self, mesh, *args):
        super().gather_mesh_hook(mesh, *args)
        for primitive in mesh.primitives:
            primitive.attributes.pop('_TANGENT_GUIDE',None)
    def gather_material_hook(self, material, *args):
        material.pbr_metallic_roughness=None
        material.normal_texture=None;material.occlusion_texture=None
        material.emissive_texture=None;material.emissive_factor=None
        material.extensions=None
