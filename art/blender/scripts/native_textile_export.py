"""Export continuous two-sided textile charts with their actual tangent sign.

The older flat-stock exporter assumes the same chart handedness on every face.
Solidified cloth keeps its continuous front/back rest charts and needs both.
"""
import os
import bpy, numpy as np
from check_exported_tangents import validate

def export_textile(root,family,exports,material_names_only=True,staged_output=True):
    for image in bpy.data.images:
        if image.source=='FILE':image.filepath=bpy.path.relpath(image.filepath,start=str(root/'art/blender'))
    bpy.ops.wm.save_as_mainfile(filepath=str(root/'art/blender'/f'{family}.blend'))
    bpy.ops.object.select_all(action='DESELECT')
    for obj in exports.objects:obj.select_set(True)
    class TextileTangents:
        def gather_material_hook(self,mat,source,settings):
            mat.pbr_metallic_roughness=None;mat.normal_texture=None;mat.occlusion_texture=None
            mat.emissive_texture=None;mat.emissive_factor=None;mat.extensions=None
        def gather_mesh_hook(self,mesh,*args):
            from io_scene_gltf2.io.exp.binary_data import BinaryData
            from io_scene_gltf2.io.com.constants import BufferViewTarget
            for p in mesh.primitives:
                def vec(key):return np.frombuffer(p.attributes[key].buffer_view.data,dtype='<f4').reshape((-1,3)).astype(float)
                n=vec('NORMAL');n/=np.linalg.norm(n,axis=1)[:,None]
                g=vec('_TANGENT_GUIDE');t=g-n*np.sum(g*n,axis=1)[:,None];t/=np.linalg.norm(t,axis=1)[:,None]
                signs=-np.ones(len(t))
                if '_TANGENT_SIGN' in p.attributes:
                    signs=np.frombuffer(p.attributes['_TANGENT_SIGN'].buffer_view.data,dtype='<f4').astype(float)
                    del p.attributes['_TANGENT_SIGN']
                p.attributes['TANGENT'].buffer_view=BinaryData(np.column_stack((t,signs)).astype('<f4').tobytes(),BufferViewTarget.ARRAY_BUFFER)
                del p.attributes['_TANGENT_GUIDE']
    import io_scene_gltf2
    io_scene_gltf2.glTF2ExportUserExtension=TextileTangents
    destination=root/'tmp/native_exports'/f'{family}_{os.getpid()}.glb'
    destination.parent.mkdir(parents=True,exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(destination),export_format='GLB',use_selection=True,export_yup=True,
                             export_tangents=True,export_attributes=True,export_materials='EXPORT')
    proof=validate(destination)
    path=root/'game/assets/props'/f'{family}.glb'
    os.replace(destination,path);proof['asset']=str(path)
    return proof
