"""INERT segmented conformal cloth unwrap and native export candidate."""
from pathlib import Path
import bpy,bmesh,json,sys,math,numpy as np
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2];OUT=Path(__file__).parent/'hose_capacity_native6'
sys.path.insert(0,str(ROOT/'art/blender/scripts'))
from fabrication_native_batch import material,export
from fabrication_normals import stock_corner_normals
bpy.ops.wm.open_mainfile(filepath=str(OUT/'hose_capacity_study.blend'))
obj=bpy.data.objects['Capacity study hose'];mesh=obj.data
plan=json.loads((OUT/'capacity_plan.json').read_text());P=np.array(plan['points']);count=len(P);N=32;half=count*N
assert len(mesh.vertices)==2*half
segments=np.diff(P,axis=0);segments/=np.linalg.norm(segments,axis=1)[:,None]
angles=np.r_[0,np.arccos(np.clip(np.sum(segments[:-1]*segments[1:],axis=1),-1,1)),0]
curved=angles>.001
cuts={0,count-1}
for row in range(1,count):
    if curved[row]!=curved[row-1]:cuts.add(row)
for edge in mesh.edges:
    a,b=edge.vertices;ra=(a%half)//N;rb=(b%half)//N;ja=a%N;jb=b%N
    edge.use_seam=(ra==rb and ra in cuts) or (ra!=rb and ja==jb and ja in list(range(0,N,N//8)))
bpy.context.view_layer.objects.active=obj;bpy.ops.object.select_all(action='DESELECT');obj.select_set(True)
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.unwrap(method='ANGLE_BASED',margin=.001,correct_aspect=False)
bpy.ops.object.mode_set(mode='OBJECT');mesh.update()
# Source edge seams define the islands. Scale each one from measured physical
# surface area, and orient its longest longitudinal edge with the cloth warp.
bm=bmesh.new();bm.from_mesh(mesh);bm.faces.ensure_lookup_table();bm.verts.ensure_lookup_table()
uv=bm.loops.layers.uv.active;seen=set();islands=[]
for seed in bm.faces:
    if seed.index in seen:continue
    todo=[seed];seen.add(seed.index);island=[]
    while todo:
        face=todo.pop();island.append(face)
        for edge in face.edges:
            if edge.seam:continue
            for other in edge.link_faces:
                if other.index not in seen:seen.add(other.index);todo.append(other)
    area3=0.;area2=0.;longest=0.;warp=Vector((0,1))
    for face in island:
        loops=list(face.loops);base=loops[0][uv].uv
        for i in range(1,len(loops)-1):
            a=loops[i][uv].uv-base;b=loops[i+1][uv].uv-base
            area2+=abs(a.x*b.y-a.y*b.x)*.5
        area3+=face.calc_area()
        for loop in loops:
            other=loop.link_loop_next;a=loop.vert.index;b=other.vert.index
            if a%N!=b%N or (a%half)//N==(b%half)//N:continue
            distance=(loop.vert.co-other.vert.co).length
            if distance>longest:
                longest=distance;warp=(other[uv].uv-loop[uv].uv).copy()
                if (b%half)//N<(a%half)//N:warp=-warp
    assert area2>1e-15
    scale=math.sqrt(area3/area2);warp.normalize();cross=Vector((warp.y,-warp.x))
    anchor=island[0].loops[0][uv].uv.copy()
    for face in island:
        for loop in face.loops:
            q=loop[uv].uv-anchor;loop[uv].uv=(q.dot(cross)*scale,q.dot(warp)*scale)
    islands.append(len(island))
bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free();mesh.update()
uv=mesh.uv_layers.active;guide=mesh.attributes.new(name='_tangent_guide',type='FLOAT_VECTOR',domain='CORNER')
ratios=[];stretches=[];worst=[]
for face in mesh.polygons:
    ls=list(face.loop_indices)
    xyz=np.array([mesh.vertices[i].co[:] for i in face.vertices],dtype=np.float64)
    tex=np.array([uv.data[i].uv[:] for i in ls],dtype=np.float64)
    p0=xyz[0];e1=xyz[1]-p0;e2=xyz[2]-p0
    u=tex[1]-tex[0];v=tex[2]-tex[0];det=u[0]*v[1]-u[1]*v[0]
    assert abs(det)>1e-12,(face.index,'collapsed conformal chart',det)
    du=(e1*v[1]-e2*u[1])/det
    # All chart construction uses scalar64 geometry. Float32 cancellation
    # on narrow inner bend triangles must not distort the authored frame.
    normal=np.cross(e1,e2);area=np.linalg.norm(normal);normal/=area
    du-=normal*np.dot(du,normal);axis_u=du/np.linalg.norm(du);axis_v=np.cross(normal,axis_u)
    coords=tex[0]+np.column_stack(((xyz-p0)@axis_u,(xyz-p0)@axis_v))
    for loop,xy in zip(ls,coords):uv.data[loop].uv=xy
    tex=np.array([uv.data[i].uv[:] for i in ls],dtype=np.float64)
    u=tex[1]-tex[0];v=tex[2]-tex[0];det=u[0]*v[1]-u[1]*v[0]
    assert det>1e-12,(face.index,'collapsed metre chart',det)
    du=(e1*v[1]-e2*u[1])/det;dv=(e2*u[0]-e1*v[0])/det
    ratios.append(det/area)
    sv=np.linalg.svd(np.array([du,dv]),compute_uv=False);stretches.extend(sv.tolist())
    worst.append((float(max(sv.max(),1/sv.min())),face.index,xyz.mean(axis=0).tolist(),sv.tolist()))
    for loop in ls:guide.data[loop].vector=(du[0],du[2],-du[1])
mesh.normals_split_custom_set(stock_corner_normals(mesh))
for name in ['art/blender','game/assets/props']:(OUT/name).mkdir(parents=True,exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'art/blender/fire_capacity_candidate.blend'))
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
finish=dict(catalog_key='linen',tint=[.75,.71,.59,1],pigment=1.,normal=.08,roughness=.9,metallic=0.)
mesh.materials.clear();mesh.materials.append(material(ROOT,'linen',finish,catalog))
exports=bpy.data.collections.new('Single bank cloth candidate');bpy.context.scene.collection.children.link(exports);exports.objects.link(obj)
result=export(OUT,'fire_capacity_candidate',exports,material_names_only=True)
result.update(evidence_class='INERT',scope='Uninstalled segmented conformal native cloth candidate with physical metre charts. No loaded mip, mechanism, pose or appearance acceptance.',worst_triangles=sorted(worst,reverse=True)[:12],islands=len(islands),uv_area_quantiles=np.quantile(ratios,[0,.01,.5,.99,1]).tolist(),uv_stretch_quantiles=np.quantile(stretches,[0,.01,.5,.99,1]).tolist())
(OUT/'unwrap_export.json').write_text(json.dumps(result,indent=2)+'\n')
bpy.context.scene.render.filepath=str(OUT/'linen_conformal.png');bpy.ops.render.render(write_still=True)
print('SEGMENTED CLOTH CANDIDATE',json.dumps(result))
