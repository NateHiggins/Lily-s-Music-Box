"""INERT native capacity study. No game publication or mechanical acceptance."""
from pathlib import Path
import json,math,hashlib,sys
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'tmp/v2-fire-hand-20261019/hose_capacity_native4'
OUT.mkdir(parents=True,exist_ok=True)
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
    def arc(center,r,a,c,n=32):
        append([(center[0]+r*math.cos(t),center[1]+r*math.sin(t),center[2]) for t in [a+(c-a)*i/n for i in range(n+1)]])
    old=1.5708;angle=old+math.pi
    port=(-.060+.012*math.sin(old),.068-.012*math.cos(old),.112)
    axis=(-math.sin(angle),math.cos(angle),0)
    mouth=(-.265,.119,.100);entry=sub(port,mul(axis,.025))
    tail=bezier(mouth,add(mouth,(0,-.09,.02)),sub(entry,mul(axis,.05)),entry,64)
    tail += [add(entry,mul(sub(port,entry),i/8)) for i in range(1,9)]
    append(list(reversed(tail)),(.021,.021))
    throat_axis=json.loads((ROOT/'game/data/orison_v2/fire_fold_stock.json').read_text())['nozzle_mouth_axes'][0]
    def transition(t):
        s=min(1.,t*1.5);s=s*s*(3-2*s)
        return (.021+(.004-.021)*s,.021+(.0315-.021)*s)
    append(bezier(mouth,add(mouth,mul(throat_axis,.025)),(-.278,.164,.100),(-.278,.189,.100),64),transition)
    xs=[-.278+(j//2)*.0295+(.020 if j%2 else 0) for j in range(26)]
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
    append(bezier((.170,.300,.100),(.170,.350,.100),(.170,.395,.098),(.170,.445,.098),64),lambda t:(.004+(.021-.004)*t*t*(3-2*t),.0315+(.021-.0315)*t*t*(3-2*t)))
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
report={'evidence_class':'INERT','scope':'Uninstalled single-bank capacity clay study; no UV/PBR, support, deployment or contact acceptance.',
'centreline_polyline_m':actual,'long_leg_length_m':depth,'long_leg_bottom_y_m':.680-depth,
'legs':26,'crowns':13,'crown_centre_y_m':.680,'single_bank_depth_m':.100,
'points':points,'radii':radii,'sides':sides,
'source_bindings':{p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest() for p in [Path(__file__).resolve(),ROOT/'game/data/orison_v2/fire_fold_stock.json']}}
(OUT/'capacity_plan.json').write_text(json.dumps(report,indent=2)+'\n')
print('CAPACITY STUDY',json.dumps({k:v for k,v in report.items() if k not in ['points','radii','sides','source_bindings']}))
try:import bpy,bmesh
except ImportError:sys.exit(0)
from mathutils import Vector
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
def b(p):return Vector((p[0],-p[2],p[1]))
centres=[b(p) for p in points];N=64;vertices=[];faces=[]
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
