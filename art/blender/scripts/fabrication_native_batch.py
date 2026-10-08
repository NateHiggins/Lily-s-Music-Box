"""Small native-stock exporter for source-fitted passive batches.

Inputs are Blender meshes, metre frames and existing catalogue finishes.
No gameplay data, cameras, lights or material images are exported.
"""
from pathlib import Path
import bpy,bmesh,numpy as np
from mathutils import Vector
from fabrication_chart_batch import triangle_charts
from fabrication_grain import stock_grain_frame
from fabrication_normals import stock_corner_normals
from check_exported_tangents import validate as validate_export

def material(root,key,finish,catalog):
    mat=bpy.data.materials.new(key);mat.use_nodes=True
    node=mat.node_tree.nodes['Principled BSDF'];spec=catalog[finish['catalog_key']]
    node.inputs['Metallic'].default_value=finish.get('metallic',spec['metallic'])
    uv=mat.node_tree.nodes.new('ShaderNodeTexCoord');scale=mat.node_tree.nodes.new('ShaderNodeVectorMath');scale.operation='SCALE';scale.inputs['Scale'].default_value=1/spec['meters_per_tile'];mat.node_tree.links.new(uv.outputs['UV'],scale.inputs[0])
    for i,target in [(0,'Base Color'),(1,'Roughness'),(2,'Normal')]:
        image=bpy.data.images.load(str(root/'game/assets/building/textures'/spec['files'][i]),check_existing=True)
        if i:image.colorspace_settings.name='Non-Color'
        texture=mat.node_tree.nodes.new('ShaderNodeTexImage');texture.image=image;mat.node_tree.links.new(scale.outputs[0],texture.inputs[0])
        if i==2:
            normal=mat.node_tree.nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=finish['normal'];mat.node_tree.links.new(texture.outputs[0],normal.inputs['Color']);mat.node_tree.links.new(normal.outputs[0],node.inputs[target])
        elif i==1:
            mul=mat.node_tree.nodes.new('ShaderNodeMath');mul.operation='MULTIPLY';mul.inputs[1].default_value=finish['roughness'];mat.node_tree.links.new(texture.outputs[0],mul.inputs[0]);mat.node_tree.links.new(mul.outputs[0],node.inputs[target])
        else:
            values=np.empty(len(image.pixels),dtype=np.float32);image.pixels.foreach_get(values)
            sample=values.reshape((image.size[1],image.size[0],4))[::max(1,image.size[1]//32),::max(1,image.size[0]//32),:3]
            sample=np.where(sample<=.04045,sample/12.92,((sample+.055)/1.055)**2.4);mean=sample.mean(axis=(0,1));assert np.isfinite(mean).all()
            pigment=mat.node_tree.nodes.new('ShaderNodeMixRGB');pigment.inputs[0].default_value=finish['pigment'];pigment.inputs[1].default_value=(*mean,1.)
            mat.node_tree.links.new(texture.outputs[0],pigment.inputs[2])
            tint=mat.node_tree.nodes.new('ShaderNodeMixRGB');tint.blend_type='MULTIPLY';tint.inputs[0].default_value=1.
            tint.inputs[2].default_value=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in finish['tint'][:3]]+[1.]
            mat.node_tree.links.new(pigment.outputs[0],tint.inputs[1]);mat.node_tree.links.new(tint.outputs[0],node.inputs[target])
    return mat

def partition(collection,name,objects,finish,mat,frame,catalog):
    vertices=[];faces=[];frames=[]
    for obj in objects:
        points=[v.co[:] for v in obj.data.vertices];offset=len(vertices);vertices.extend(points)
        spec=catalog[finish['catalog_key']]
        grain=stock_grain_frame(points,spec['files'][0]) if finish['catalog_key'] in ['wood_dark','timber'] else None
        frames.extend([grain]*len(points));faces.extend(tuple(offset+i for i in f.vertices) for f in obj.data.polygons)
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update();mesh.materials.append(mat)
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
    coords=np.array([v.co[:] for v in mesh.vertices]);indices=np.array([l.vertex_index for l in mesh.loops]).reshape((-1,3));f=[frames[i] for i in indices[:,0]]
    assert np.all(np.linalg.norm(np.cross(coords[indices[:,1]]-coords[indices[:,0]],coords[indices[:,2]]-coords[indices[:,0]]),axis=1)>0),name
    rotations=np.stack([x[0] if x is not None else np.eye(3) for x in f]);grain=np.array([x is not None and x[1]==0 for x in f])
    ns,us,charts,_=triangle_charts(coords[indices],np.zeros(3),1.,rotations,grain)
    uv=mesh.uv_layers.new(name='Metres');uv.data.foreach_set('uv',charts.astype(np.float32).ravel())
    guide=mesh.attributes.new(name='_tangent_guide',type='FLOAT_VECTOR',domain='CORNER');g=np.repeat(us[:,[0,2,1]],3,axis=0);g[:,2]*=-1;guide.data.foreach_set('vector',g.astype(np.float32).ravel())
    mesh.normals_split_custom_set(stock_corner_normals(mesh))
    obj=bpy.data.objects.new(name,mesh);collection.objects.link(obj);obj.matrix_world=frame
    return obj

def export(root,family,exports):
    for image in bpy.data.images:
        if image.source=='FILE':image.filepath=bpy.path.relpath(image.filepath,start=str(root/'art/blender'))
    bpy.ops.wm.save_as_mainfile(filepath=str(root/'art/blender'/f'{family}.blend'))
    bpy.ops.object.select_all(action='DESELECT')
    for obj in exports.objects:obj.select_set(True)
    class ExportUVHandedness:
        def gather_mesh_hook(self,mesh,blender_data,blender_object,vertex_groups,modifiers,materials,export_settings):
            from io_scene_gltf2.io.exp.binary_data import BinaryData
            from io_scene_gltf2.io.com.constants import BufferViewTarget
            for primitive in mesh.primitives:
                def values(key):return np.frombuffer(primitive.attributes[key].buffer_view.data,dtype='<f4').reshape((-1,3)).astype(float)
                n=values('NORMAL');n/=np.linalg.norm(n,axis=1)[:,None];g=values('_TANGENT_GUIDE');t=g-n*np.sum(g*n,axis=1)[:,None];t/=np.linalg.norm(t,axis=1)[:,None]
                primitive.attributes['TANGENT'].buffer_view=BinaryData(np.column_stack((t,-np.ones(len(t)))).astype('<f4').tobytes(),BufferViewTarget.ARRAY_BUFFER)
                del primitive.attributes['_TANGENT_GUIDE']
    import io_scene_gltf2
    io_scene_gltf2.glTF2ExportUserExtension=ExportUVHandedness
    path=root/'game/assets/props'/f'{family}.glb'
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_attributes=True,export_materials='PLACEHOLDER')
    return validate_export(path)
