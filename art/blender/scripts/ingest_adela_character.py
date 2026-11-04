"""Owner-supplied Adela: unchanged skin, grounded personal clips and atlas.

External native intake only. The original ZIP and four maps remain untouched.
"""
from pathlib import Path
import json,math,hashlib,sys,os,argparse,shutil
import bpy
import numpy as np
from mathutils import Vector,Quaternion

ROOT=Path(__file__).resolve().parents[3]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--fbx',required=True,type=Path)
parser.add_argument('--out-dir',required=True,type=Path)
parser.add_argument('--atlas-dir',type=Path,default=ROOT/'art/textures/library/resident_adela_voss')
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
assert hashlib.sha256(args.fbx.read_bytes()).hexdigest()=='64fe90e1e34ea024b10782dcf2fa4c2981a3c6a92afa35834ac1131aaa76caa1', 'Unexpected owner source FBX'
OUT=args.out_dir.resolve();OUT.mkdir(parents=True,exist_ok=True)
RUNTIME=OUT/'runtime';RUNTIME.mkdir(exist_ok=True)
for channel in ['albedo','roughness','normal']:
    original=args.atlas_dir/(channel+'.png');target=RUNTIME/(channel+'.png')
    if original.resolve()!=target.resolve():shutil.copyfile(original,target)
sys.path.insert(0,str(ROOT/'art/blender/scripts'))
from metric_gltf_export import CatalogueMetricUV
from check_exported_tangents import validate as validate_tangents
frame_export=[]
class SkinAtlasFrames(CatalogueMetricUV):
    """Reuse native UV frames; split only corners with incompatible frames.

    This runs inside Blender's exporter, including every skin attribute. It
    does not edit a generated GLB or alter positions, normals, UVs or weights.
    """
    def gather_mesh_hook(self,mesh,*args):
        super().gather_mesh_hook(mesh,*args)
        from io_scene_gltf2.io.exp.binary_data import BinaryData
        from io_scene_gltf2.io.com.constants import BufferViewTarget
        dtypes={5120:'i1',5121:'u1',5122:'<i2',5123:'<u2',5125:'<u4',5126:'<f4'}
        widths={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}
        for primitive in mesh.primitives:
            assert not primitive.targets,'Morph targets require a separate frame export review'
            arrays={key:np.frombuffer(value.buffer_view.data,dtype=dtypes[value.component_type]).reshape(-1,widths[value.type]).copy() for key,value in primitive.attributes.items()}
            indices=np.frombuffer(primitive.indices.buffer_view.data,dtype=dtypes[primitive.indices.component_type]).reshape(-1,3).astype(np.int64)
            positions=arrays['POSITION'].astype(float);normals=arrays['NORMAL'].astype(float);uv=arrays['TEXCOORD_0'].astype(float);tangent=arrays['TANGENT'].astype(float)
            p=positions[indices];q=uv[indices];a=q[:,1]-q[:,0];b=q[:,2]-q[:,0];det=a[:,0]*b[:,1]-a[:,1]*b[:,0]
            assert np.all(abs(det)>1e-12),'Collapsed exported atlas chart'
            du=((p[:,1]-p[:,0])*b[:,1,None]-(p[:,2]-p[:,0])*a[:,1,None])/det[:,None]
            dv=((p[:,2]-p[:,0])*a[:,0,None]-(p[:,1]-p[:,0])*b[:,0,None])/det[:,None]
            n=normals[indices];expected=du[:,None,:]-n*np.sum(du[:,None,:]*n,axis=2)[:,:,None]
            expected/=np.linalg.norm(expected,axis=2)[:,:,None]
            actual=tangent[indices,:3];agreement=np.sum(expected*actual,axis=2)
            handed=np.sum(np.cross(n,actual)*dv[:,None,:],axis=2)*tangent[indices,3]
            bad=np.any((agreement<=.9995)|(handed<=0),axis=1)
            old_count=len(positions);extra=indices[bad].reshape(-1)
            indices[bad]=np.arange(old_count,old_count+len(extra)).reshape(-1,3)
            used,remapped=np.unique(indices,return_inverse=True)
            for key,accessor in primitive.attributes.items():
                values=np.concatenate((arrays[key],arrays[key][extra]))
                if key=='TANGENT':
                    e=expected[bad].reshape(-1,3).astype(np.float32)
                    sign=np.where(np.sum(np.cross(n[bad],e.reshape(-1,3,3).astype(float))*dv[bad,None,:],axis=2)<0,-1.,1.).reshape(-1)
                    values[old_count:]=np.column_stack((e,sign))
                values=values[used]
                accessor.count=len(values);accessor.byte_offset=None
                if key!='POSITION':accessor.min=None;accessor.max=None
                accessor.buffer_view=BinaryData(values.tobytes(),BufferViewTarget.ARRAY_BUFFER)
            final_indices=remapped.reshape(-1).astype('<u4')
            primitive.indices.component_type=5125;primitive.indices.count=len(final_indices)
            primitive.indices.byte_offset=None;primitive.indices.min=[int(final_indices.min())];primitive.indices.max=[int(final_indices.max())]
            primitive.indices.buffer_view=BinaryData(final_indices.tobytes(),BufferViewTarget.ELEMENT_ARRAY_BUFFER)
            frame_export.append({'source_export_vertices':old_count,'final_export_vertices':len(used),'split_faces':int(bad.sum()),'triangles':len(indices),'skin_attributes_retained':[key for key in arrays if key.startswith(('JOINTS','WEIGHTS'))]})
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(args.fbx.resolve()),use_image_search=False)
scene=bpy.context.scene;scene.render.fps=30
bpy.context.preferences.filepaths.save_version=0
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
meshes=[o for o in bpy.data.objects if o.type=='MESH']
repairs=[]
for obj in meshes:
    original_vertices=len(obj.data.vertices)
    bpy.context.view_layer.objects.active=obj
    modifier=obj.modifiers.new('RuntimeTriangleTopology','TRIANGULATE')
    if hasattr(modifier,'keep_custom_normals'):modifier.keep_custom_normals=True
    bpy.ops.object.modifier_move_to_index(modifier=modifier.name,index=0)
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    assert len(obj.data.vertices)==original_vertices,'Triangulation changed source vertex/skin count'
    obj.data.calc_tangents(uvmap=obj.data.uv_layers.active.name)
    mesh=obj.data
    before_positions=[v.co.copy() for v in mesh.vertices]
    for attempt in range(8):
        bad=[face for face in mesh.polygons if any(mesh.loops[i].tangent.length<.999 for i in face.loop_indices)]
        if not bad:break
        normals=np.empty(len(mesh.loops)*3,dtype=np.float32)
        mesh.corner_normals.foreach_get('vector',normals);normals=normals.reshape(-1,3)
        fix_normals=False
        for face in bad:
            indices=list(face.loop_indices);assert len(indices)==3
            points=[mesh.vertices[mesh.loops[i].vertex_index].co.copy() for i in indices]
            edges=[(0,1,2),(1,2,0),(2,0,1)]
            a,b,c=max(edges,key=lambda e:(points[e[0]]-points[e[1]]).length_squared)
            moved=0.
            if face.area<1e-8:
                direction=face.normal.cross(points[b]-points[a]).normalized()
                if direction.dot(points[c]-(points[a]+points[b])*.5)<0:direction=-direction
                mesh.vertices[mesh.loops[indices[c]].vertex_index].co+=direction*.00001;moved=.00001
            uv=mesh.uv_layers.active;old=uv.data[indices[c]].uv.copy()
            edge=uv.data[indices[b]].uv-uv.data[indices[a]].uv
            uv.data[indices[c]].uv+=Vector((-edge.y,edge.x)).normalized()*.00002
            agreement=max(abs(float(Vector(normals[i]).dot(face.normal))) for i in indices)
            normal_repair=agreement<.25
            if normal_repair:
                for i in indices:normals[i]=face.normal
                fix_normals=True
            repairs.append({'face':face.index,'attempt':attempt,'geometry_motion_m':moved,'uv_motion':list(uv.data[indices[c]].uv-old),'source_normal_face_agreement':agreement,'repaired_invalid_near_tangential_normals':normal_repair})
        if fix_normals:mesh.normals_split_custom_set(normals.tolist())
        mesh.free_tangents();mesh.update();mesh.calc_tangents(uvmap=mesh.uv_layers.active.name)
    remaining=[face.index for face in mesh.polygons if any(mesh.loops[i].tangent.length<.999 for i in face.loop_indices)]
    details=[{'face':index,'area':mesh.polygons[index].area,'normal':list(mesh.polygons[index].normal),'uv':[list(mesh.uv_layers.active.data[i].uv) for i in mesh.polygons[index].loop_indices],'corner_normals':[list(mesh.corner_normals[i].vector) for i in mesh.polygons[index].loop_indices],'tangent':[list(mesh.loops[i].tangent) for i in mesh.polygons[index].loop_indices]} for index in remaining]
    (OUT/'SLIVER_REPAIR_REVIEW.json').write_text(json.dumps({'evidence_class':'INERT','repairs':repairs,'remaining_faces':remaining,'details':details},indent=2),encoding='utf8')
    assert not remaining,'Native Mikk tangent remains invalid'
    maximum_motion=max((v.co-before_positions[v.index]).length for v in mesh.vertices)
    assert maximum_motion<.0001,'Unexpected visible source geometry change'
    values=np.empty(len(mesh.loops)*2,dtype=np.float32);mesh.uv_layers.active.data.foreach_get('uv',values)
    coordinates=np.zeros((len(mesh.loops),3),dtype=np.float32);coordinates[:,:2]=values.reshape(-1,2)
    coordinates[:,1]-=1. # Shared exporter writes -V: preserve ordinary atlas1-V exactly.
    attribute=mesh.attributes.new('_METRE_UV','FLOAT_VECTOR','CORNER')
    attribute.data.foreach_set('vector',coordinates.reshape(-1))
root=next(b.name for b in rig.data.bones if b.parent is None)
root_inverse=rig.data.bones[root].matrix_local.to_3x3().inverted()
originals=list(bpy.data.actions)
source_actions={name:next(a for a in originals if a.name.endswith('|'+name)) for name in ['Walking','Running']}
saved={};travel={}
for label,action in source_actions.items():
    rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
    first,last=(round(x) for x in action.frame_range)
    frames=[];roots=[]
    for frame in range(first,last+1):
        scene.frame_set(frame);bpy.context.view_layer.update()
        frames.append({b.name:(b.location.copy(),b.matrix_basis.to_quaternion(),b.scale.copy()) for b in rig.pose.bones})
        roots.append((rig.matrix_world@rig.pose.bones[root].matrix.translation).copy())
    saved[label]=frames
    travel[label]={'seconds':(last-first)/30,'source_horizontal_root_travel_m':Vector((roots[-1].x-roots[0].x,roots[-1].y-roots[0].y,0)).length}
rig.animation_data.action=None
for action in originals:bpy.data.actions.remove(action)

for material in bpy.data.materials:
    material.name='resident_adela_voss'
    if not material.use_nodes:continue
    for node in material.node_tree.nodes:
        if node.type=='TEX_IMAGE' and node.image:
            kind=next((k for k in ['normal','roughness','metallic'] if k in node.image.name.lower()),'albedo')
            if kind=='metallic':continue
            node.image=bpy.data.images.load(str(RUNTIME/(kind+'.png')),check_existing=True)
            node.image.colorspace_settings.name='sRGB' if kind=='albedo' else 'Non-Color'
        if node.type=='BSDF_PRINCIPLED':
            for name in ['Emission Color','Emission Strength','Metallic']:
                socket=node.inputs.get(name)
                if socket:
                    for link in list(socket.links):material.node_tree.links.remove(link)
            node.inputs['Emission Strength'].default_value=0
            node.inputs['Metallic'].default_value=0
            node.inputs['Specular IOR Level'].default_value=.35

def floor_z():
    bpy.context.view_layer.update();deps=bpy.context.evaluated_depsgraph_get();floor=math.inf
    for obj in meshes:
        evaluated=obj.evaluated_get(deps);mesh=evaluated.to_mesh()
        coords=np.empty(len(mesh.vertices)*3,dtype=np.float32);mesh.vertices.foreach_get('co',coords)
        matrix=np.asarray(evaluated.matrix_world,dtype=float)
        floor=min(floor,float((coords.reshape(-1,3)@matrix[2,:3]+matrix[2,3]).min()))
        evaluated.to_mesh_clear()
    return floor

def ground():
    bpy.context.view_layer.update()
    point=rig.matrix_world@rig.pose.bones[root].matrix.translation
    correction=rig.matrix_world.to_3x3().inverted()@Vector((-point.x,-point.y,-floor_z()))
    rig.pose.bones[root].location+=root_inverse@correction
    bpy.context.view_layer.update()
    error=floor_z();assert abs(error)<.00001,('floor',error)
    return error

clips=[]
for label,frames in saved.items():
    action=bpy.data.actions.new('adela_'+label.lower());action.use_fake_user=True
    rig.animation_data.action=action
    duration=len(frames)-1;tail=min(6,max(1,duration//5));floor_errors=[]
    for index,pose in enumerate(frames):
        scene.frame_set(index)
        weight=0. if index<duration-tail else (index-duration+tail)/tail
        weight=weight*weight*(3-2*weight)
        for bone in rig.pose.bones:
            loc,q,scale=pose[bone.name];opening=frames[0][bone.name]
            bone.rotation_mode='QUATERNION'
            bone.location=loc.lerp(opening[0],weight)
            bone.rotation_quaternion=q.slerp(opening[1],weight)
            bone.scale=scale.lerp(opening[2],weight)
        floor_errors.append(ground())
        for bone in rig.pose.bones:
            for prop in ['location','rotation_quaternion','scale']:bone.keyframe_insert(prop,frame=index)
    clips.append({'clip':action.name,'seconds':duration/30,'frames':len(frames),'maximum_sampled_floor_error_m':max(abs(v) for v in floor_errors),'loop_tail_frames':tail,**travel[label]})

action=bpy.data.actions.new('adela_idle');action.use_fake_user=True
rig.animation_data.action=action
for frame in [0,30,60,90,120]:
    scene.frame_set(frame)
    for bone in rig.pose.bones:
        bone.rotation_mode='QUATERNION';bone.location=(0,0,0);bone.rotation_quaternion=(1,0,0,0);bone.scale=(1,1,1)
    rig.pose.bones['spine.002'].rotation_quaternion=Quaternion(Vector((1,0,0)),.0035*math.sin(frame/120*math.tau))
    ground()
    for bone in rig.pose.bones:
        for prop in ['location','rotation_quaternion','scale']:bone.keyframe_insert(prop,frame=frame)
clips.append({'clip':'adela_idle','seconds':4.,'source':'original bind pose with authored restrained chest breathing; no donor skeleton or voice'})

for track in list(rig.animation_data.nla_tracks):rig.animation_data.nla_tracks.remove(track)
for action in bpy.data.actions:
    track=rig.animation_data.nla_tracks.new();track.name=action.name
    track.strips.new(action.name,0,action);track.mute=True
rig.animation_data.action=bpy.data.actions['adela_idle'];scene.frame_set(0);bpy.context.view_layer.update()
for collection in [bpy.data.images,bpy.data.materials]:
    for item in list(collection):
        if item.users==0:collection.remove(item)
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'adela_voss.blend'))
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
for obj in meshes:obj.select_set(True)
bpy.context.view_layer.objects.active=rig
for track in rig.animation_data.nla_tracks:track.mute=False
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=SkinAtlasFrames
candidate=RUNTIME/'adela_voss_candidate.glb'
bpy.ops.export_scene.gltf(filepath=str(candidate),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_skins=True,export_yup=True,export_force_sampling=True,export_frame_range=False,export_tangents=True,export_attributes=True,export_materials='PLACEHOLDER',export_cameras=False,export_lights=False)
frame_proof=validate_tangents(candidate)
for obj in meshes:obj.data.calc_loop_triangles()
assert frame_proof['triangles']==sum(len(obj.data.loop_triangles) for obj in meshes), 'Export lost source triangles'
os.replace(candidate,RUNTIME/'adela_voss.glb')
for obj in meshes:obj.data.calc_loop_triangles()
report={'evidence_class':'INERT','blender':bpy.app.version_string,'source_zip_sha256':'c2bef9d98c60097e18e9e7115cceb93fa0a0a2f60d9aeca2d656440747931333','triangles':sum(len(o.data.loop_triangles) for o in meshes),'vertices':sum(len(o.data.vertices) for o in meshes),'bones':len(rig.data.bones),'clips':clips,'motion_owner':'Runtime follower owns travel. Personal skeleton clips have horizontal root travel removed and sampled soles grounded.','geometry':'No decimation; original vertices/skin/scale preserved except measured microscopic tangent-sliver repairs. Native triangulation replaces FBX polygon tessellation.','tangent_repairs':repairs,'maximum_vertex_motion_m':maximum_motion,'material':'Runtime placeholder resident_adela_voss must bind registered original-UV atlas, with loaded mipmaps. No images or lights embedded in GLB.','runtime_bytes':(RUNTIME/'adela_voss.glb').stat().st_size,'runtime_sha256':hashlib.sha256((RUNTIME/'adela_voss.glb').read_bytes()).hexdigest(),'scope':'Native authoring only; GLB derivative/optical checks and Godot qualification still required.'}
(OUT/'BUILD_REPORT.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf8')
(OUT/'FRAME_EXPORT_REVIEW.json').write_text(json.dumps({'evidence_class':'INERT','frames':frame_export,'tangent_proof':frame_proof},indent=2)+'\n',encoding='utf8')
print('ADELA RUNTIME EXPORT',report['triangles'],'triangles',len(clips),'personal clips',report['runtime_bytes'],'bytes',flush=True)
