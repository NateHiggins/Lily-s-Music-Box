"""INERT longitudinal-UV native candidate; no canonical publication."""
from pathlib import Path
import bpy,bmesh,json,sys,math,hashlib,numpy as np
ROOT=Path(__file__).resolve().parents[2];OUT=Path(__file__).parent/'hose_capacity_native5'
sys.path.insert(0,str(ROOT/'art/blender/scripts'))
from fabrication_native_batch import material,export
from fabrication_normals import stock_corner_normals
bpy.ops.wm.open_mainfile(filepath=str(OUT/'hose_capacity_study.blend'))
obj=bpy.data.objects['Capacity study hose'];mesh=obj.data
plan=json.loads((OUT/'capacity_plan.json').read_text());count=len(plan['points']);N=64;half=count*N
assert len(mesh.vertices)==2*half
centres=np.array(plan['points']);lengths=np.r_[0,np.cumsum(np.linalg.norm(np.diff(centres,axis=0),axis=1))]
coords=np.array([v.co[:] for v in mesh.vertices]);circum=[];longitudinal=[]
for inner in [0,1]:
    ring=coords[inner*half:(inner+1)*half].reshape((count,N,3))
    circum.append(np.concatenate((np.zeros((count,1)),np.cumsum(np.linalg.norm(np.diff(np.concatenate((ring,ring[:,:1,:]),axis=1),axis=1),axis=2),axis=1)),axis=1))
    longitudinal.append(np.concatenate((np.zeros((1,N)),np.cumsum(np.linalg.norm(np.diff(ring,axis=0),axis=2),axis=0)),axis=0))
uv=mesh.uv_layers.new(name='Longitudinal cloth metres')
for face in mesh.polygons:
    ids=list(face.vertices);rows=[(v%half)//N for v in ids]
    if len(set(rows))==1:
        # Annular exposed cut edges use the physical end-plane stock.
        row=rows[0];tangent=centres[min(row+1,count-1)]-centres[max(row-1,0)];tangent/=np.linalg.norm(tangent)
        side=np.array(plan['sides'][row],dtype=float);side-=tangent*np.dot(tangent,side);side/=np.linalg.norm(side)
        normal=np.cross(tangent,side)
        for loop in face.loop_indices:
            point=coords[mesh.loops[loop].vertex_index];world=np.array([point[0],point[2],-point[1]])
            uv.data[loop].uv=(np.dot(world-centres[row],normal),np.dot(world-centres[row],side))
    else:
        js=[v%N for v in ids];seam=0 in js and N-1 in js
        for loop in face.loop_indices:
            v=mesh.loops[loop].vertex_index;inside=int(v>=half);row=(v%half)//N;j=v%N
            if seam and j==0:j=N
            uv.data[loop].uv=(circum[inside][row,j],longitudinal[inside][row,j%N])
    # Orient charts to the actual outward face; inner cloth has its own seam.
    a,b,c=[mesh.vertices[v].co for v in ids[:3]]
    ta,tb,tc=[uv.data[i].uv.copy() for i in list(face.loop_indices)[:3]]
    det=(tb.x-ta.x)*(tc.y-ta.y)-(tb.y-ta.y)*(tc.x-ta.x)
    assert abs(det)>1e-12,(face.index,'collapsed cloth chart')
    if det<0:
        for loop in face.loop_indices:uv.data[loop].uv.x*=-1
bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free();mesh.update()
guide=mesh.attributes.new(name='_tangent_guide',type='FLOAT_VECTOR',domain='CORNER')
uv=mesh.uv_layers.active;ratios=[]
for face in mesh.polygons:
    ids=list(face.vertices);ls=list(face.loop_indices)
    p,q,r=[mesh.vertices[i].co for i in ids];a,c,d=[uv.data[i].uv for i in ls]
    u=c-a;v=d-a;det=u.x*v.y-u.y*v.x
    assert det>1e-12,(face.index,'invalid triangle chart',det)
    du=((q-p)*v.y-(r-p)*u.y)/det
    ratios.append(det/max(1e-30,(q-p).cross(r-p).length))
    for loop in ls:guide.data[loop].vector=(du.x,du.z,-du.y)
mesh.normals_split_custom_set(stock_corner_normals(mesh))
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
finish=dict(catalog_key='linen',tint=[.75,.71,.59,1],pigment=1.,normal=.08,roughness=.9,metallic=0.)
for name in ['art/blender','game/assets/props']:(OUT/name).mkdir(parents=True,exist_ok=True)
# Establish the candidate's final file directory before assigning relative
# catalogue images. Saving from the earlier study directory remaps them wrong.
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'art/blender/fire_capacity_candidate.blend'))
mesh.materials.clear();mesh.materials.append(material(ROOT,'linen',finish,catalog))
exports=bpy.data.collections.new('Single bank hose candidate');bpy.context.scene.collection.children.link(exports);exports.objects.link(obj)
for name in ['art/blender','game/assets/props']:(OUT/name).mkdir(parents=True,exist_ok=True)
result=export(OUT,'fire_capacity_candidate',exports,material_names_only=True)
result.update(evidence_class='INERT',scope='Uninstalled native longitudinal-UV candidate. Loaded Godot mips, mechanisms, supports and full production poses remain unqualified.',centreline_m=float(lengths[-1]),uv_area_to_surface_area_quantiles=np.quantile(ratios,[0,.01,.5,.99,1]).tolist())
(OUT/'uv_export.json').write_text(json.dumps(result,indent=2)+'\n')
scene=bpy.context.scene;scene.render.filepath=str(OUT/'linen_candidate.png');bpy.ops.render.render(write_still=True)
print('LONGITUDINAL CLOTH UV CANDIDATE',json.dumps(result))
