"""Native local bend coupons cut from the actual skinned cloth.
Not deployed poses: the rest of the hose is deliberately outside this local
material-resolution study. Closed annular cut ends retain real wall thickness.
"""
from pathlib import Path
import bpy,bmesh,json,os,sys,math,hashlib
from mathutils import Vector,Matrix,Quaternion
ROOT=Path(__file__).resolve().parents[3]
SOURCE=Path(os.environ.get('ORISON_FIRE_CAPACITY_SOURCE',str(ROOT/'tmp/v2-fire-hand-20261019/capacity_rig_dense1'))).resolve()
OUT=Path(os.environ.get('ORISON_FIRE_FOLD_REVIEW_OUT',str(SOURCE/'new_fold_review'))).resolve()
assert SOURCE.is_relative_to(ROOT/'tmp') and OUT.is_relative_to(ROOT/'tmp')
OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(SOURCE/'art/blender/fire_capacity_candidate.blend'))
sys.path.insert(0,str(ROOT/'art/blender/scripts'))
from fabrication_normals import stock_corner_normals
source=bpy.data.objects['Capacity study hose'];rig=source.parent;mesh=source.data
data=json.loads((SOURCE/'rig_projection.json').read_text());points=[Vector(p) for p in data['points']];count=len(points);N=32;half=count*N
def b(p):return Vector((p.x,-p.z,p.y))
def y(p):return Vector((p.x,p.z,-p.y))
start=next(i for i,p in enumerate(points[:-23]) if abs(p.x+.274)<1e-6 and .25<p.y<.30 and points[i+1].y-p.y>.003)
spacing=(points[start+1]-points[start]).length
for obj in list(bpy.context.scene.objects):
    if obj.type=='MESH':obj.hide_render=True
proofs=[]
for name,target_radius in [('tight',.016),('loose',.065)]:
    steps=max(4,roundi if False else round(math.pi*target_radius/spacing))
    radius=spacing/(2*math.sin(math.pi/(2*steps)))
    assert start+steps+3<count
    moved=[p.copy() for p in points];origin=points[start]
    for j in range(steps+1):
        angle=math.pi*j/steps;moved[start+j]=origin+Vector((radius*(1-math.cos(angle)),radius*math.sin(angle),0))
    end=points[start+steps];rotation=Matrix.Rotation(math.pi,3,'Z')
    for i in range(start+steps+1,count):moved[i]=moved[start+steps]+rotation@(points[i]-end)
    frames=[]
    for i in range(count):
        before=(points[min(i+1,count-1)]-points[max(i-1,0)]).normalized()
        after=(moved[min(i+1,count-1)]-moved[max(i-1,0)]).normalized()
        q=before.rotation_difference(after)
        rest=rig.data.bones[data['bone_names'][i]].matrix_local
        at=(b(before)).rotation_difference(b(after)).to_matrix().to_4x4()@rest
        at.translation=b(moved[i]);frames.append(at@rest.inverted())
    lo=start-2;hi=start+steps+2;ids=[*range(lo*N,(hi+1)*N),*range(half+lo*N,half+(hi+1)*N)]
    remap={v:i for i,v in enumerate(ids)}
    vertices=[frames[(v%half)//N]@mesh.vertices[v].co for v in ids];faces=[];charts=[]
    for face in mesh.polygons:
        if not all(v in remap for v in face.vertices):continue
        faces.append(tuple(remap[v] for v in face.vertices));charts.append([tuple(mesh.uv_layers.active.data[l].uv) for l in face.loop_indices])
    for row in [lo,hi]:
        rest=rig.data.bones[data['bone_names'][row]].matrix_local.inverted()
        for j in range(N):
            corners=[row*N+j,row*N+(j+1)%N,half+row*N+(j+1)%N,half+row*N+j]
            faces.append(tuple(remap[v] for v in corners));charts.append([(rest@mesh.vertices[v].co).xz if False else ((rest@mesh.vertices[v].co).x,(rest@mesh.vertices[v].co).z) for v in corners])
    own=bpy.data.meshes.new(name+' native bend');own.from_pydata(vertices,[],faces);own.update()
    uv=own.uv_layers.new(name='Source cloth metres')
    for face,chart in zip(own.polygons,charts):
        for loop,xy in zip(face.loop_indices,chart):uv.data[loop].uv=xy
    bm=bmesh.new();bm.from_mesh(own);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    assert all(e.is_manifold for e in bm.edges);volume=bm.calc_volume(signed=True);assert volume>0
    bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(own);bm.free();own.update()
    own.normals_split_custom_set(stock_corner_normals(own))
    own.materials.append(mesh.materials[0]);obj=bpy.data.objects.new(name+' new crease coupon',own);bpy.context.collection.objects.link(obj)
    target=origin+Vector((radius,radius*.5,0));distance=max(.12,radius*4.)
    camera=bpy.context.scene.camera;camera.location=b(target+Vector((distance*.4,distance*.3,distance)))
    camera.rotation_euler=(b(target)-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.lens=58
    bpy.context.scene.render.filepath=str(OUT/(name+'_new_fold.png'));bpy.ops.render.render(write_still=True)
    proofs.append({'kind':name,'bend_intervals':steps,'actual_radius_m':radius,'closed_volume_m3':volume,'source_interval_m':spacing,
                   'maximum_full_length_change_m':abs(sum((c-a).length for a,c in zip(points,points[1:]))-sum((c-a).length for a,c in zip(moved,moved[1:])))})
    obj.hide_render=True
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'native_bend_coupons.blend'))
(OUT/'review.json').write_text(json.dumps({'evidence_class':'INERT','scope':'Local closed bend coupons, not deployed/contact-qualified full hose poses.','coupons':proofs,'source_glb_sha256':hashlib.sha256((SOURCE/'game/assets/props/fire_capacity_candidate.glb').read_bytes()).hexdigest()},indent=2)+'\n')
print('NATIVE NEW-FOLD REVIEW',proofs)
