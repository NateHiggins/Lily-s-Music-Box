"""Scratch-only seven-batch export with explicit per-triangle UV derivatives."""
from pathlib import Path
import bpy,bmesh,json,hashlib,math,sys,numpy as np
from mathutils import Vector
from heating_refit_context import ROOT as R, OUT as P, PLAN
OUT=P/'export';OUT.mkdir(exist_ok=True)
sys.path.insert(0,str(R/'art/blender/scripts'))
from check_exported_tangents import validate
r=json.loads((P/'native_review.json').read_text());source=P/r['native_file'];assert not r['failures'] and hashlib.sha256(source.read_bytes()).hexdigest()==r['native_sha256']
bpy.ops.wm.open_mainfile(filepath=str(source));groups={};stocks=[]
for obj in list(bpy.context.scene.objects):
    if obj.type!='MESH' or obj.get('level')=='BOILER':bpy.data.objects.remove(obj,do_unlink=True);continue
    assert obj.get('level'),obj.name
    bm=bmesh.new();bm.from_mesh(obj.data);assert all(edge.is_manifold for edge in bm.edges) and bm.calc_volume(signed=True)>0,obj.name;bm.free()
    assert obj.data.uv_layers.active is not None,obj.name
    stocks.append(obj.name)
    active=obj.data.uv_layers.active.name
    for layer in list(obj.data.uv_layers):
        if layer.name!=active:obj.data.uv_layers.remove(layer)
    obj.data.uv_layers.active.name='UVMap';groups.setdefault(obj['level'],[]).append(obj)
counts={}
for level,parts in sorted(groups.items()):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in parts:obj.hide_set(False);obj.select_set(True)
    bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();obj=bpy.context.object;obj.name='Heating_'+level;bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    original=obj.data;original.calc_loop_triangles();uv=original.uv_layers.active.data;normals=original.corner_normals
    # Give every triangle its own corners so tangent discontinuities do not
    # alter the original metric UVs or original native shading normals.
    positions=[];charts=[];shading=[];faces=[]
    for tri in original.loop_triangles:
        first=len(positions);positions.extend(tuple(original.vertices[index].co) for index in tri.vertices);charts.extend(tuple(uv[index].uv) for index in tri.loops);shading.extend(tuple(normals[index].vector) for index in tri.loops);faces.append((first,first+1,first+2))
    mesh=bpy.data.meshes.new(obj.name+'_StrictCorners');mesh.from_pydata(positions,[],faces);mesh.update();mesh.materials.clear()
    for mat in original.materials:mesh.materials.append(mat)
    layer=mesh.uv_layers.new(name='UVMap')
    for index,value in enumerate(charts):layer.data[index].uv=value
    for polygon in mesh.polygons:polygon.use_smooth=True
    mesh.normals_split_custom_set(shading);obj.data=mesh
    guide=mesh.attributes.new(name='_TANGENT_GUIDE',type='FLOAT_VECTOR',domain='CORNER');bitangent=mesh.attributes.new(name='_BITANGENT_GUIDE',type='FLOAT_VECTOR',domain='CORNER')
    triangle_id=mesh.attributes.new(name='_TRIANGLE_ID',type='FLOAT',domain='CORNER')
    for face in mesh.polygons:
        indices=list(face.loop_indices);points=[mesh.vertices[mesh.loops[i].vertex_index].co for i in indices];tex=[layer.data[i].uv for i in indices];a,b=tex[1]-tex[0],tex[2]-tex[0];det=a.x*b.y-a.y*b.x
        assert abs(det)>1e-12,(obj.name,face.index,'collapsed native UV')
        du=((points[1]-points[0])*b.y-(points[2]-points[0])*a.y)/det
        dv=((points[2]-points[0])*a.x-(points[1]-points[0])*b.x)/det
        du.normalize();dv.normalize()
        for index in indices:guide.data[index].vector=(du.x,du.z,-du.y);bitangent.data[index].vector=(-dv.x,-dv.z,dv.y);triangle_id.data[index].value=face.index
    counts[obj.name]=dict(source_parts=len(parts),triangles=len(faces),bounds_blender=[min(p[i] for p in positions) for i in range(3)]+[max(p[i] for p in positions) for i in range(3)])

class ExactDerivativeExport:
    def gather_mesh_hook(self,mesh,blender_data,blender_object,vertex_groups,modifiers,materials,export_settings):
        from io_scene_gltf2.io.exp.binary_data import BinaryData
        from io_scene_gltf2.io.com.constants import BufferViewTarget
        for primitive in mesh.primitives:
            def array(key,width):return np.frombuffer(primitive.attributes[key].buffer_view.data,dtype='<f4').reshape((-1,width)).astype(float)
            normal_raw=array('NORMAL',3);n=normal_raw.copy();n/=np.linalg.norm(n,axis=1)[:,None];positions=array('POSITION',3);uv=array('TEXCOORD_0',2)
            index_dtype={5121:'u1',5123:'<u2',5125:'<u4'}[primitive.indices.component_type];indices=np.frombuffer(primitive.indices.buffer_view.data,dtype=index_dtype).astype(int).reshape((-1,3))
            assert len(np.unique(indices))==indices.size,'Triangle ids did not preserve tangent discontinuities'
            points=positions[indices];tex=uv[indices];a=tex[:,1]-tex[:,0];b=tex[:,2]-tex[:,0];det=a[:,0]*b[:,1]-a[:,1]*b[:,0]
            assert np.all(abs(det)>1e-12),'Final flipped UVs collapsed before serialization'
            # Derive from the ACTUAL float32 exported UV/position fields.
            # For millimetre charts, float32(1-v) rounding is enough to alter
            # a tangent; source-space guides alone cannot guarantee agreement.
            du=((points[:,1]-points[:,0])*b[:,1,None]-(points[:,2]-points[:,0])*a[:,1,None])/det[:,None]
            dv=((points[:,2]-points[:,0])*a[:,0,None]-(points[:,1]-points[:,0])*b[:,0,None])/det[:,None]
            normals=n[indices];t=du[:,None,:]-normals*np.sum(du[:,None,:]*normals,axis=2)[:,:,None];t/=np.linalg.norm(t,axis=2)[:,:,None]
            w=np.sign(np.sum(np.cross(normals,t)*dv[:,None,:],axis=2));assert np.all(w!=0),'Degenerate exported tangent basis'
            values=np.zeros((len(n),4));values[indices,:3]=t;values[indices,3]=w
            primitive.attributes['TANGENT'].buffer_view=BinaryData(values.astype('<f4').tobytes(),BufferViewTarget.ARRAY_BUFFER)
            del primitive.attributes['_TANGENT_GUIDE'];del primitive.attributes['_BITANGENT_GUIDE'];del primitive.attributes['_TRIANGLE_ID']
            # Weld only byte-identical COMPLETE final vertex records inside
            # the exporter hook. Geometry/UV/normal/tangent discontinuities
            # remain exact; no generated GLB patching or lossy quantization.
            assert set(primitive.attributes)=={'POSITION','NORMAL','TEXCOORD_0','TANGENT'}
            records=np.ascontiguousarray(np.column_stack((positions,normal_raw,uv,values)).astype('<f4'))
            _,first,inverse=np.unique(records.view('V48').reshape(-1),return_index=True,return_inverse=True)
            unique=records[first]
            for key,start,end in [('POSITION',0,3),('NORMAL',3,6),('TEXCOORD_0',6,8),('TANGENT',8,12)]:
                accessor=primitive.attributes[key];accessor.buffer_view=BinaryData(np.ascontiguousarray(unique[:,start:end]).tobytes(),BufferViewTarget.ARRAY_BUFFER);accessor.count=len(first);accessor.byte_offset=None
            remapped=inverse[indices].reshape(-1);dtype='<u2' if len(first)<=65535 else '<u4';primitive.indices.component_type=5123 if dtype=='<u2' else 5125
            primitive.indices.buffer_view=BinaryData(remapped.astype(dtype).tobytes(),BufferViewTarget.ELEMENT_ARRAY_BUFFER);primitive.indices.byte_offset=None;primitive.indices.count=len(remapped);primitive.indices.min=[int(remapped.min())];primitive.indices.max=[int(remapped.max())]
            label=blender_object.name if blender_object is not None else mesh.name.removesuffix('_StrictCorners')
            if label in counts:counts[label]['exported_vertices_before_weld']=len(records);counts[label]['exported_vertices_after_exact_weld']=len(first)
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExactDerivativeExport
path=OUT/'heating_distribution.glb';bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',export_yup=True,export_apply=True,export_materials='PLACEHOLDER',export_texcoords=True,export_tangents=True,export_attributes=True,export_lights=False,export_cameras=False)
tangents=validate(path)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(path));roundtrip=[]
for obj in bpy.context.scene.objects:
    if obj.type!='MESH':continue
    assert obj.name in counts,obj.name
    mesh=obj.data;mesh.calc_loop_triangles();points=[obj.matrix_world@v.co for v in mesh.vertices];bounds=[min(p[i] for p in points) for i in range(3)]+[max(p[i] for p in points) for i in range(3)]
    assert len(mesh.loop_triangles)==counts[obj.name]['triangles'] and all(abs(a-b)<1e-5 for a,b in zip(bounds,counts[obj.name]['bounds_blender'])),obj.name
    roundtrip.append(obj.name)
assert set(roundtrip)==set(counts)
(OUT/'export_review.json').write_text(json.dumps(dict(evidence_class='INERT',scope='Scratch export of inspected native geometry only. Per-triangle original metric UVs and native corner normals retained; explicit exported tangent/bitangent handedness passes strict final buffer derivative checks. Godot imported precision/mips/materials, installed collision/control/save and human acceptance are unverified.',native_sha256=r['native_sha256'],asset_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),bytes=path.stat().st_size,closed_native_stocks=len(stocks),batches=counts,roundtrip=roundtrip,exported_tangents=tangents),indent=2)+'\n')
print('STRICT REFIT EXPORT',path.stat().st_size,'bytes',len(counts),'batches',tangents,flush=True)
