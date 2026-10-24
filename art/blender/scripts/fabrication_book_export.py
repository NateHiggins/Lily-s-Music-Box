"""Book-local glTF authoring with differential morph normals and tangents.

Leaves the shared static-stock exporter unchanged. Target frames are derived
from the same native deformation as positions, before the exporter writes GLB.
"""
import copy
from pathlib import Path
import bpy,numpy as np
from check_exported_tangents import validate as validate_export
from book_flex_math import frame_at

def export_books(root,family,collection,deformers):
    pose_checks=[]
    for name,functions in deformers.items():
        obj=collection.objects[name];mesh=obj.data
        base=np.asarray([v.co[:] for v in mesh.vertices])[:,[0,2,1]];base[:,2]*=-1
        faces=np.asarray([p.vertices[:] for p in mesh.polygons])
        for index,function in enumerate(functions,1):
            key=mesh.shape_keys.key_blocks[index]
            assert key.value==0. and key.relative_key.name=='Basis',(name,key.name,key.value)
            expected=np.asarray([function(p) for p in base]);actual=np.asarray([v.co[:] for v in key.data])[:,[0,2,1]];actual[:,2]*=-1
            assert np.max(np.abs(expected-actual))<5e-8,(name,key.name,'accumulated deformation')
            triangles=actual[faces]
            volume=np.sum(np.einsum('ij,ij->i',triangles[:,0],np.cross(triangles[:,1],triangles[:,2])))/6.
            # b() preserves handedness. Native stock has consistent winding.
            assert volume>1e-14 and np.isfinite(volume),(name,key.name,volume)
            pose_checks.append({'part':name,'key':key.name,'volume_m3':float(volume)})
    for image in bpy.data.images:
        if image.source=='FILE':image.filepath=bpy.path.relpath(image.filepath,start=str(root/'art/blender'))
    bpy.ops.wm.save_as_mainfile(filepath=str(root/'art/blender'/f'{family}.blend'))
    bpy.ops.object.select_all(action='DESELECT')
    for obj in collection.objects:obj.select_set(True)
    by_mesh={collection.objects[name].data.name:functions for name,functions in deformers.items()}
    completed=set()
    class BookFrames:
        def gather_mesh_hook(self,mesh,blender_data,blender_object,vertex_groups,modifiers,materials,export_settings):
            from io_scene_gltf2.io.exp.binary_data import BinaryData
            from io_scene_gltf2.io.com.constants import BufferViewTarget
            def values(accessor):return np.frombuffer(accessor.buffer_view.data,dtype='<f4').reshape((-1,3)).astype(float)
            def accessor(template,array):
                result=copy.deepcopy(template);result.buffer_view=BinaryData(np.asarray(array,dtype='<f4').tobytes(),BufferViewTarget.ARRAY_BUFFER)
                result.min=None;result.max=None;result.sparse=None
                return result
            for primitive in mesh.primitives:
                normal=values(primitive.attributes['NORMAL']);normal/=np.linalg.norm(normal,axis=1)[:,None]
                guide=values(primitive.attributes['_TANGENT_GUIDE'])
                tangent=guide-normal*np.sum(guide*normal,axis=1)[:,None];tangent/=np.linalg.norm(tangent,axis=1)[:,None]
                primitive.attributes['TANGENT'].buffer_view=BinaryData(np.column_stack((tangent,-np.ones(len(tangent)))).astype('<f4').tobytes(),BufferViewTarget.ARRAY_BUFFER)
                del primitive.attributes['_TANGENT_GUIDE']
                if blender_data.name not in by_mesh:continue
                functions=by_mesh[blender_data.name]
                assert len(primitive.targets)==len(functions),(blender_data.name,len(primitive.targets),len(functions))
                positions=values(primitive.attributes['POSITION'])
                for target,deform in zip(primitive.targets,functions):
                    frames=[frame_at(deform,p,n,t) for p,n,t in zip(positions,normal,tangent)]
                    nn=np.asarray([f[0] for f in frames]);tt=np.asarray([f[1] for f in frames])
                    assert np.isfinite(nn).all() and np.isfinite(tt).all()
                    target['NORMAL']=accessor(primitive.attributes['NORMAL'],nn-normal)
                    target['TANGENT']=accessor(primitive.attributes['NORMAL'],tt-tangent)
                completed.add(blender_data.name)
    import io_scene_gltf2
    previous=getattr(io_scene_gltf2,'glTF2ExportUserExtension',None)
    io_scene_gltf2.glTF2ExportUserExtension=BookFrames
    path=root/'game/assets/props'/f'{family}.glb'
    kwargs=dict(filepath=str(path),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_attributes=True,export_materials='PLACEHOLDER')
    supported=bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
    for key in ['export_morph','export_morph_normal','export_morph_tangent']:
        if key in supported:kwargs[key]=True
    try:bpy.ops.export_scene.gltf(**kwargs)
    finally:
        if previous is None:del io_scene_gltf2.glTF2ExportUserExtension
        else:io_scene_gltf2.glTF2ExportUserExtension=previous
    assert completed==set(by_mesh),('Incomplete morph export',set(by_mesh)-completed)
    proof=validate_export(path);proof['native_pose_checks']=pose_checks
    return proof
