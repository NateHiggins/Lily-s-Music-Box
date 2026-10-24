"""Native 15.24m hose capacity candidate, not a production replacement.

Run in Blender. ORISON_FIRE_CAPACITY_OUT may name a directory under repo tmp.
Original nozzle and upper-hose port datums are retained. This recipe authors
closed cloth stock and physical-metre UVs using the registered custom linen.
No maintenance, input, save, deployment or mechanical authority is changed.
Review the exported shape/UVs and fit all poses before any game installation.
"""
import os
"""INERT native capacity study. No game publication or mechanical acceptance."""
from pathlib import Path
import json,math,hashlib,sys
ROOT=Path(__file__).resolve().parents[3]
OUT=Path(os.environ.get('ORISON_FIRE_CAPACITY_OUT',str(ROOT/'tmp/v2-fire-hand-20261019/capacity_stock_native1'))).resolve()
assert OUT.is_relative_to(ROOT/'tmp'),'Candidate outputs must remain under repository tmp'
OUT.mkdir(parents=True,exist_ok=True)
# Keep the previous dense study reproducible by default. A separate, uninstalled
# real-time candidate can choose fewer curved samples and longer straight spans;
# it must repeat its native bearing, UV, deformation and contact checks.
CURVE_STEPS=int(os.environ.get('ORISON_FIRE_CAPACITY_CURVE_STEPS','16'))
TRANSITION_STEPS=int(os.environ.get('ORISON_FIRE_CAPACITY_TRANSITION_STEPS','64'))
assert CURVE_STEPS in [8,16,32] and TRANSITION_STEPS in [16,32,64]
def add(a,b):return tuple(x+y for x,y in zip(a,b))
def sub(a,b):return tuple(x-y for x,y in zip(a,b))
def mul(a,s):return tuple(x*s for x in a)
def norm(a):return math.sqrt(sum(x*x for x in a))
def unit(a):return mul(a,1/norm(a))
def bezier(a,b,c,d,n):
    return [add(add(mul(a,(1-t)**3),mul(b,3*(1-t)**2*t)),add(mul(c,3*(1-t)*t*t),mul(d,t**3))) for t in [i/n for i in range(n+1)]]
def build(depth):
    points=[];radii=[];sides=[]
    def append(path,r=(.004,.0315),side=(0,0,1)):
        for i,p in enumerate(path):
            radius=r(i/(len(path)-1)) if callable(r) else r
            if points and norm(sub(p,points[-1]))<1e-10:continue
            points.append(p);radii.append(radius);sides.append(side)
    def line(p):append([points[-1],p])
    def arc(center,r,a,c,n=CURVE_STEPS):
        # Keep the original bearing profiles on every supported crown and the
        # larger visible return. Eight samples on a supported crown intersect
        # the rounded carrier between the original bearing-ray locations.
        if r>.02 or c==0:n=max(n,16)
        append([(center[0]+r*math.cos(t),center[1]+r*math.sin(t),center[2]) for t in [a+(c-a)*i/n for i in range(n+1)]])
    old=1.5708;angle=old+math.pi
    port=(-.060+.012*math.sin(old),.068-.012*math.cos(old),.112)
    axis=(-math.sin(angle),math.cos(angle),0)
    mouth=(-.265,.119,.100);entry=sub(port,mul(axis,.025))
    tail=bezier(mouth,add(mouth,(0,-.09,.02)),sub(entry,mul(axis,.05)),entry,TRANSITION_STEPS)
    tail += [add(entry,mul(sub(port,entry),i/8)) for i in range(1,9)]
    append(list(reversed(tail)),(.021,.021))
    throat_axis=json.loads((ROOT/'game/data/orison_v2/fire_fold_stock.json').read_text())['nozzle_mouth_axes'][0]
    def transition(t):
        s=min(1.,t*1.5);s=s*s*(3-2*s)
        return (.021+(.004-.021)*s,.021+(.0315-.021)*s)
    append(bezier(mouth,add(mouth,mul(throat_axis,.025)),(-.274,.164,.100),(-.274,.189,.100),TRANSITION_STEPS),transition)
    xs=[-.274+(j//2)*.0295+(.020 if j%2 else 0) for j in range(26)]
    for j,x in enumerate(xs):
        end_y=.680 if j%2==0 else (.180 if j==1 else .680-depth)
        line((x,end_y,.100))
        if j==25:break
        other=xs[j+1];radius=(other-x)/2
        arc(((x+other)/2,end_y,.100),radius,math.pi,0 if j%2==0 else math.tau)
    # The last leg returns under the stock, then rises directly to the
    # retained valve port; no second depth bank or high crossover is needed.
    radius=(.170-xs[-1])/2
    arc(((xs[-1]+.170)/2,.680-depth,.100),radius,math.pi,math.tau)
    line((.170,.300,.100))
    append(bezier((.170,.300,.100),(.170,.350,.100),(.170,.395,.098),(.170,.445,.098),TRANSITION_STEPS),lambda t:(.004+(.021-.004)*t*t*(3-2*t),.0315+(.021-.0315)*t*t*(3-2*t)))
    return points,radii,sides
def length(points):return sum(norm(sub(b,a)) for a,b in zip(points,points[1:]))
lo=.35;hi=.62
for _ in range(64):
    mid=(lo+hi)*.5
    if length(build(mid)[0])<15.24:lo=mid
    else:hi=mid
depth=(lo+hi)*.5
points,radii,sides=build(depth);actual=length(points)
assert abs(actual-15.24)<1e-9,(depth,actual)
max_span=float(os.environ.get('ORISON_FIRE_CAPACITY_MAX_SPAN','.005'))
assert math.isfinite(max_span) and .001<=max_span<=.10
# Preserve every authored curved sample and both ports. Subdivide only long
# intervals, carrying the original radial stock and side direction with them.
old_points,old_radii,old_sides=points,radii,sides
points=[old_points[0]];radii=[old_radii[0]];sides=[old_sides[0]]
for i in range(len(old_points)-1):
    steps=max(1,math.ceil(norm(sub(old_points[i+1],old_points[i]))/max_span))
    for step in range(1,steps+1):
        t=step/steps
        points.append(add(mul(old_points[i],1-t),mul(old_points[i+1],t)))
        radii.append(tuple(a*(1-t)+c*t for a,c in zip(old_radii[i],old_radii[i+1])))
        sides.append(unit(add(mul(old_sides[i],1-t),mul(old_sides[i+1],t))))
assert norm(sub(points[0],old_points[0]))<1e-12 and norm(sub(points[-1],old_points[-1]))<1e-12
assert abs(length(points)-actual)<1e-9
assert max(norm(sub(c,a)) for a,c in zip(points,points[1:]))<=max_span+1e-12
report={'evidence_class':'INERT','scope':'Uninstalled single-bank capacity clay study; no UV/PBR, support, deployment or contact acceptance.',
'centreline_polyline_m':actual,'long_leg_length_m':depth,'long_leg_bottom_y_m':.680-depth,
'legs':26,'crowns':13,'crown_centre_y_m':.680,'single_bank_depth_m':.100,
'points':points,'radii':radii,'sides':sides,
'maximum_segment_m':max_span,'original_ring_count':len(old_points),'ring_count':len(points),
'curve_steps':CURVE_STEPS,'transition_steps':TRANSITION_STEPS,
'source_bindings':{p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest() for p in [Path(__file__).resolve(),ROOT/'game/data/orison_v2/fire_fold_stock.json']}}
(OUT/'capacity_plan.json').write_text(json.dumps(report,indent=2)+'\n')
print('CAPACITY STUDY',json.dumps({k:v for k,v in report.items() if k not in ['points','radii','sides','source_bindings']}))
try:import bpy,bmesh
except ImportError:sys.exit(0)
from mathutils import Vector
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
def b(p):return Vector((p[0],-p[2],p[1]))
centres=[b(p) for p in points];N=32;vertices=[];faces=[]
for inside in [False,True]:
    for i,(p,(r,w)) in enumerate(zip(points,radii)):
        tangent=unit(sub(points[min(i+1,len(points)-1)],points[max(0,i-1)]))
        hint=sides[i]
        dot=sum(x*y for x,y in zip(tangent,hint))
        side=unit(sub(hint,mul(tangent,dot)))
        normal=(tangent[1]*side[2]-tangent[2]*side[1],tangent[2]*side[0]-tangent[0]*side[2],tangent[0]*side[1]-tangent[1]*side[0])
        for j in range(N):
            theta=math.tau*j/N
            vertices.append(b(add(p,add(mul(normal,(r-.00195*inside)*math.cos(theta)),mul(side,(w-.00195*inside)*math.sin(theta))))))
count=len(points);half=count*N
for inside in [False,True]:
    off=inside*half
    for i in range(count-1):
        for j in range(N):
            face=(off+i*N+j,off+(i+1)*N+j,off+(i+1)*N+(j+1)%N,off+i*N+(j+1)%N)
            faces.append(tuple(reversed(face)) if inside else face)
for i in [0,count-1]:
    for j in range(N):faces.append((i*N+j,i*N+(j+1)%N,half+i*N+(j+1)%N,half+i*N+j))
mesh=bpy.data.meshes.new('Editable 15.24m hose');mesh.from_pydata(vertices,[],faces);mesh.update()
hose=bpy.data.objects.new('Capacity study hose',mesh);bpy.context.collection.objects.link(hose)
bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
assert all(e.is_manifold for e in bm.edges);volume=bm.calc_volume(signed=True);assert volume>0
bm.to_mesh(mesh);bm.free()
mat=bpy.data.materials.new('Unqualified clay geometry study');mat.diffuse_color=(.55,.46,.29,1);mat.use_nodes=True
mat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.55,.46,.29,1)
mat.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.8
mesh.materials.append(mat)
for polygon in mesh.polygons:polygon.use_smooth=True
# Thin case outlines give the retained physical envelope; no game publication.
def bar(name,a,c,r=.002):
    a=b(a);c=b(c);bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=r,depth=(c-a).length,location=(a+c)*.5)
    obj=bpy.context.object;obj.name=name;obj.rotation_euler=(c-a).to_track_quat('Z','Y').to_euler()
for z in [.018,.2065]:
    for x in [-.283,.283]:bar('Case outline',(x,.02205,z),(x,.753,z))
    for y in [.02205,.753]:bar('Case outline',(-.283,y,z),(.283,y,z))
for x in [-.283,.283]:
    for y in [.02205,.753]:bar('Case outline',(x,y,.018),(x,y,.2065))
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.render.threads_mode='FIXED';scene.render.threads=4
scene.render.resolution_x=1200;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Capacity neutral');scene.world.color=(.18,.18,.18)
for position,energy in [((.4,.65,.6),55),((-.5,.45,.25),30)]:
    bpy.ops.object.light_add(type='AREA',location=b(position));light=bpy.context.object;light.data.energy=energy;light.data.size=.6;light.rotation_euler=(b((0,.38,.1))-light.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=b((.92,.78,1.20)));camera=bpy.context.object;camera.data.lens=58;camera.data.clip_start=.001;camera.rotation_euler=(b((0,.38,.10))-camera.location).to_track_quat('-Z','Y').to_euler();scene.camera=camera
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'hose_capacity_study.blend'))
scene.render.filepath=str(OUT/'capacity_study.png');bpy.ops.render.render(write_still=True)
report['mesh']={'vertices':len(vertices),'quads':len(faces),'closed':True,'volume_m3':volume,'minimum_y_m':min(v.z for v in vertices),'maximum_depth_m':max(-v.y for v in vertices),'maximum_x_m':max(v.x for v in vertices),'minimum_x_m':min(v.x for v in vertices)}
(OUT/'capacity_plan.json').write_text(json.dumps(report,indent=2)+'\n')
print('CAPACITY NATIVE STUDY SAVED',report['mesh'])

"""INERT segmented conformal cloth unwrap and native export candidate."""
from pathlib import Path
import bpy,bmesh,json,sys,math,numpy as np
from mathutils import Vector
# ROOT and OUT belong to this candidate recipe above.
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
tile=float(json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']['linen']['meters_per_tile'])
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
    phase=tex[0]-np.round(tex[0]/tile)*tile
    coords=phase+np.column_stack(((xyz-p0)@axis_u,(xyz-p0)@axis_v))
    for loop,xy in zip(ls,coords):uv.data[loop].uv=xy
    tex=np.array([uv.data[i].uv[:] for i in ls],dtype=np.float64)
    u=tex[1]-tex[0];v=tex[2]-tex[0];det=u[0]*v[1]-u[1]*v[0]
    assert det>1e-12,(face.index,'collapsed metre chart',det)
    du=(e1*v[1]-e2*u[1])/det;dv=(e2*u[0]-e1*v[0])/det
    ratios.append(det/area)
    sv=np.linalg.svd(np.array([du,dv]),compute_uv=False);stretches.extend(sv.tolist())
    worst.append((float(max(sv.max(),1/sv.min())),face.index,xyz.mean(axis=0).tolist(),sv.tolist()))
    for loop in ls:guide.data[loop].vector=(du[0],du[2],-du[1])
# Equivalent submicrometre chart values and submillidegree directions should
# share a vertex. These authored precisions are independently checked again
# in the exported GLB and loaded Godot mesh; no import tolerance is relaxed.
charts=np.empty(len(mesh.loops)*2,dtype=np.float32);uv.data.foreach_get('uv',charts)
charts=np.round(charts.astype(np.float64).reshape((-1,2)),7)
uv.data.foreach_set('uv',charts.astype(np.float32).ravel())
guides=np.empty(len(mesh.loops)*3,dtype=np.float32);guide.data.foreach_get('vector',guides)
guides=guides.astype(np.float64).reshape((-1,3));guides/=np.linalg.norm(guides,axis=1)[:,None]
guides=np.round(guides,5);guides/=np.linalg.norm(guides,axis=1)[:,None]
guide.data.foreach_set('vector',guides.astype(np.float32).ravel())
normals=np.round(np.asarray(stock_corner_normals(mesh),dtype=np.float64),5)
normals/=np.linalg.norm(normals,axis=1)[:,None]
mesh.normals_split_custom_set(normals.tolist())
# Measure the stored, rounded UVs rather than reporting the earlier charts.
ids=np.array([loop.vertex_index for loop in mesh.loops]).reshape((-1,3))
xyz=np.array([v.co[:] for v in mesh.vertices])[ids]
stored=np.empty(len(mesh.loops)*2,dtype=np.float32);uv.data.foreach_get('uv',stored)
tex=stored.astype(np.float64).reshape((-1,3,2));u=tex[:,1]-tex[:,0];v=tex[:,2]-tex[:,0]
det=u[:,0]*v[:,1]-u[:,1]*v[:,0];assert np.all(det>1e-12)
e1=xyz[:,1]-xyz[:,0];e2=xyz[:,2]-xyz[:,0]
du=(e1*v[:,1,None]-e2*u[:,1,None])/det[:,None]
dv=(e2*u[:,0,None]-e1*v[:,0,None])/det[:,None]
ratios=det/np.linalg.norm(np.cross(e1,e2),axis=1)
stretches=np.linalg.svd(np.stack((du,dv),axis=1),compute_uv=False).ravel()
for name in ['art/blender','game/assets/props']:(OUT/name).mkdir(parents=True,exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'art/blender/fire_capacity_candidate.blend'))
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
finish=dict(catalog_key='linen',tint=[.75,.71,.59,1],pigment=1.,normal=.08,roughness=.9,metallic=0.)
mesh.materials.clear();mesh.materials.append(material(ROOT,'linen',finish,catalog))
# The editable source is also the rig builder's input. Save after binding the
# actual linen maps, not merely the earlier clay preview.
bpy.ops.file.make_paths_relative()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'art/blender/fire_capacity_candidate.blend'))
exports=bpy.data.collections.new('Single bank cloth candidate');bpy.context.scene.collection.children.link(exports);exports.objects.link(obj)
result=export(OUT,'fire_capacity_candidate',exports,material_names_only=True)
result.update(evidence_class='INERT',scope='Uninstalled segmented conformal native cloth candidate with physical metre charts. No loaded mip, mechanism, pose or appearance acceptance.',worst_triangles=sorted(worst,reverse=True)[:12],islands=len(islands),uv_area_quantiles=np.quantile(ratios,[0,.01,.5,.99,1]).tolist(),uv_stretch_quantiles=np.quantile(stretches,[0,.01,.5,.99,1]).tolist())
(OUT/'unwrap_export.json').write_text(json.dumps(result,indent=2)+'\n')
bpy.context.scene.render.filepath=str(OUT/'linen_conformal.png');bpy.ops.render.render(write_still=True)
print('SEGMENTED CLOTH CANDIDATE',json.dumps(result))


# Bind the finished candidate to its actual owning recipe and surface inputs.
# Publication is intentionally absent: this is still missing deployed poses,
# loaded Godot UV/mips and complete mechanism qualification.
paths=[Path(__file__).resolve(),ROOT/'game/data/orison_v2/fire_fold_stock.json',ROOT/'game/data/runtime_material_sets.json']
paths += [ROOT/'art/blender/scripts'/name for name in ['fabrication_native_batch.py','fabrication_chart_batch.py','fabrication_grain.py','fabrication_normals.py','check_exported_tangents.py']]
paths += [ROOT/'game/assets/building/textures'/name for name in catalog['linen']['files']]
def digest(path):
    raw=path.read_bytes()
    if path.suffix in ['.py','.json']:raw=raw.replace(b'\r\n',b'\n')
    return hashlib.sha256(raw).hexdigest()
summary={k:v for k,v in plan.items() if k not in ['points','radii','sides']}
proof={'evidence_class':'INERT','scope':'Uninstalled full-length cloth candidate only. No runtime, deployment, support-strength, loaded-mipmap or human acceptance.',
       'construction':summary,'export':result,'catalog_tile_m':tile,
       'source_bindings':{q.relative_to(ROOT).as_posix():digest(q) for q in paths},
       'outputs':{q.relative_to(OUT).as_posix():digest(q) for q in [OUT/'art/blender/fire_capacity_candidate.blend',OUT/'game/assets/props/fire_capacity_candidate.glb']}}
(OUT/'candidate_construction.json').write_text(json.dumps(proof,indent=2)+'\n')
print('FIRE CAPACITY NATIVE CANDIDATE COMPLETE')
