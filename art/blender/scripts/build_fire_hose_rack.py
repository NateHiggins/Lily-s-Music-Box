"""Native fitted hose rack: sliding pivot fingers on a retained common shaft.
Form informed by US1150075; authored dimensions fit the actual retained folds.
Reference drawing is never baked/projected. Candidate output only below tmp.
"""
from pathlib import Path
import bpy,bmesh,math,json,hashlib,os,sys,shutil
from mathutils import Matrix,Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[3]
OUT=Path(os.environ.get('ORISON_FIRE_RACK_OUT',str(ROOT/'tmp/v2-fire-hand-20261019/rack_native1'))).resolve()
assert OUT.is_relative_to(ROOT/'tmp')
for path in ['art/blender','game/assets/props']:(OUT/path).mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(Path(__file__).parent))
from fabrication_native_batch import material,partition,export
from check_exported_tangents import validate
if os.environ.get('ORISON_FIRE_RACK_PUBLISH')=='1':
    report=json.loads((OUT/'construction.json').read_text())
    for path,digest in report['source_bindings'].items():
        source=ROOT/path;raw=source.read_bytes()
        if source.suffix in ['.py','.json']:raw=raw.replace(b'\r\n',b'\n')
        assert hashlib.sha256(raw).hexdigest()==digest,path
    source=OUT/'game/assets/props/fire_hose_rack.glb';blend=OUT/'art/blender/fire_hose_rack.blend'
    assert hashlib.sha256(source.read_bytes()).hexdigest()==report['glb_sha256']
    assert hashlib.sha256(blend.read_bytes()).hexdigest()==report['blend_sha256'];validate(source)
    bpy.ops.wm.open_mainfile(filepath=str(blend));bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/fire_hose_rack.blend'))
    bpy.ops.file.make_paths_relative();bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/fire_hose_rack.blend'))
    report['candidate_blend_sha256']=report['blend_sha256']
    report['blend_sha256']=hashlib.sha256((ROOT/'art/blender/fire_hose_rack.blend').read_bytes()).hexdigest()
    shutil.copyfile(source,ROOT/'game/assets/props/fire_hose_rack.glb')
    shutil.copyfile(OUT/'runtime_projection.json',ROOT/'game/data/orison_v2/fire_hose_rack.json')
    (ROOT/'art/blender/fire_hose_rack_construction.json').write_text(json.dumps(report,indent=2)+'\n')
    print('FIRE RACK PUBLISH PASS');raise SystemExit(0)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
def b(p):return Vector((p[0],-p[2],p[1]))
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
finishes={
 'iron':dict(catalog_key='fire_hardware_steel',tint=[1,1,1,1],pigment=1.,normal=1.,roughness=1.,metallic=.88),
 'brass':dict(catalog_key='radiator_service_brass',tint=[1,1,1,1],pigment=1.,normal=1.,roughness=1.,metallic=.92)}
mats={key:material(ROOT,key,spec,catalog) for key,spec in finishes.items()}
native=bpy.data.collections.new('Editable fitted rack');bpy.context.scene.collection.children.link(native)
exports=bpy.data.collections.new('FireHoseRack');bpy.context.scene.collection.children.link(exports)
objects={};draws={};proofs={}
def edge_round(obj,width):
    bpy.context.view_layer.objects.active=obj
    for v in obj.data.vertices:v.co*=1000.
    mod=obj.modifiers.new('Native edge radius','BEVEL');mod.width=width*1000.;mod.segments=3
    bpy.ops.object.modifier_apply(modifier=mod.name)
    for v in obj.data.vertices:v.co/=1000.
    return obj
def cube(size,at):
    bpy.ops.mesh.primitive_cube_add(size=1,location=b(at));obj=bpy.context.object
    obj.dimensions=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);return edge_round(obj,min(.00025,min(size)*.08))
def cylinder(radius,length,at=(0,0,0),axis=(0,0,1),sides=64):
    bpy.ops.mesh.primitive_cylinder_add(vertices=sides,radius=radius,depth=length,location=b(at))
    obj=bpy.context.object;obj.rotation_euler=b(axis).to_track_quat('Z','Y').to_euler()
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True);return edge_round(obj,min(.0002,radius*.08,length*.05))
def ball(radius,at):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=64,ring_count=32,radius=radius,location=b(at));return bpy.context.object
def boolean(obj,other,operation):
    for source in [obj,other]:
        source.location*=1000.
        for v in source.data.vertices:v.co*=1000.
    bpy.context.view_layer.objects.active=obj
    mod=obj.modifiers.new('Machined/cast stock','BOOLEAN');mod.operation=operation;mod.solver='EXACT';mod.object=other
    bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(other,do_unlink=True)
    obj.location/=1000.
    for v in obj.data.vertices:v.co/=1000.
def finish(name,obj,key,bevel=0):
    bpy.ops.object.select_all(action='DESELECT');obj.select_set(True)
    bpy.context.scene.cursor.location=(0,0,0);bpy.context.view_layer.objects.active=obj
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    bm=bmesh.new();bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=5e-9)
    bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=5e-9)
    bmesh.ops.triangulate(bm,faces=list(bm.faces))
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bad=sum(not e.is_manifold for e in bm.edges);volume=bm.calc_volume(signed=True)
    assert bad==0 and volume>0,(name,bad,volume)
    bm.to_mesh(obj.data);bm.free()
    for old in list(obj.users_collection):old.objects.unlink(obj)
    native.objects.link(obj);obj.name=name+'_Editable';objects[name]=obj
    draw=partition(exports,name,[obj],finishes[key],mats[key],Matrix.Identity(4),catalog);draws[name]=draw
    proofs[name]=dict(nonmanifold_edges=bad,volume_m3=volume,triangles=len(draw.data.polygons),material=key)
    return draw

def join_parts(parts):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in parts:obj.select_set(True)
    bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();return parts[0]
def eye(radius,bore,width,flat=None):
    n=96;verts=[];faces=[]
    for x,r in [(-width/2,radius),(width/2,radius),(width/2,bore),(-width/2,bore)]:
        for i in range(n):
            a=math.tau*i/n;y=r*math.cos(a);z=r*math.sin(a)
            if r==radius and flat is not None:z=max(z,flat) if flat<0 else (flat if z>.0055 else z)
            verts.append(b((x,y,z)))
    for row in range(4):
        for i in range(n):faces.append((row*n+i,((row+1)%4)*n+i,((row+1)%4)*n+(i+1)%n,row*n+(i+1)%n))
    mesh=bpy.data.meshes.new('Machined eye');mesh.from_pydata(verts,[],faces);mesh.update()
    obj=bpy.data.objects.new('Eye',mesh);bpy.context.collection.objects.link(obj);return obj
# Separate fabricated pieces meet on actual flat seats, rather than overlapping
# primitive unions. The mounting plate rear is the native case face at Z18mm.
plate=cube((.014,.056,.004),(0,0,-.012))
for y in [-.021,.021]:boolean(plate,cylinder(.0023,.024,(0,y,-.012)),'DIFFERENCE')
web=cube((.012,.0088,.004),(0,0,-.008))
boss=eye(.0075,.00305,.012,-.006)
finish('MountBracket',join_parts([plate,web,boss]),'iron')

pivot=eye(.0065,.00305,.006,.0065)
# Blind socket for the carrier stem; its rear plane is a real bearing.
boolean(pivot,cylinder(.00285,.010,(0,0,.0095)),'DIFFERENCE')
# Swept stem and spherical end are a single explicit closed native surface.
r=.00595;stem=.0028;end=Vector((0,.014,.068))
back=-math.sqrt(r*r-stem*stem);entry=end+Vector((0,0,back))
a=Vector((0,0,.0045));c1=a+Vector((0,0,.014));c2=entry-Vector((0,0,.020))
centers=[];radii=[];tangents=[]
for i in range(49):
    t=i/48;centers.append((1-t)**3*a+3*(1-t)**2*t*c1+3*(1-t)*t*t*c2+t**3*entry)
    tangents.append((3*(1-t)**2*(c1-a)+6*(1-t)*t*(c2-c1)+3*t*t*(entry-c2)).normalized());radii.append(stem)
angle=math.acos(back/r)
for i in range(1,65):
    theta=angle*(1-i/64);centers.append(end+Vector((0,0,r*math.cos(theta))))
    tangents.append(Vector((0,0,1)));radii.append(r*math.sin(theta))
n=64;verts=[];faces=[]
for center,radius,tangent in zip(centers,radii,tangents):
    u=Vector((1,0,0));v=tangent.cross(u).normalized()
    for i in range(n):verts.append(b(center+radius*(u*math.cos(math.tau*i/n)+v*math.sin(math.tau*i/n))))
for row in range(len(centers)-1):
    for i in range(n):faces.append((row*n+i,(row+1)*n+i,(row+1)*n+(i+1)%n,row*n+(i+1)%n))
faces.append(tuple(reversed(range(n))))
# Weld the final pole before verification; no coincident zero-area faces export.
mesh=bpy.data.meshes.new('Continuous rounded carrier');mesh.from_pydata(verts,[],faces);mesh.update()
bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-9)
bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-9);bm.to_mesh(mesh);bm.free()
rod=bpy.data.objects.new('Carrier stem',mesh);bpy.context.collection.objects.link(rod)
finish('CarrierArm',join_parts([pivot,rod]),'brass')

def screw(name,radius,length,head_radius,head_height,slot,key):
    # Local Z is insertion/face normal; shaft ends at the head's bearing plane.
    obj=cylinder(radius,length+.0003,(0,0,-length*.5+.00015))
    boolean(obj,cylinder(head_radius,head_height,(0,0,head_height*.5)),'UNION')
    boolean(obj,cube((head_radius*2.2,slot,head_height),(0,0,head_height)),'DIFFERENCE')
    return finish(name,obj,key,min(.0001,slot*.15))
screw('MountScrew',.0022,.008,.0042,.002,.001,'iron')

def radial_stock(name,rings,key):
    verts=[];faces=[];n=96
    for x,radius in rings:
        for i in range(n):
            angle=math.tau*i/n;r=radius(x,angle) if callable(radius) else radius
            verts.append(b((x,r*math.cos(angle),r*math.sin(angle))))
    for row in range(len(rings)):
        following=(row+1)%len(rings)
        for i in range(n):faces.append((row*n+i,following*n+i,following*n+(i+1)%n,row*n+(i+1)%n))
    mesh=bpy.data.meshes.new(name+'_Profile');mesh.from_pydata(verts,[],faces);mesh.update()
    bm=bmesh.new();bm.from_mesh(mesh)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-10)
    bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-10)
    bmesh.ops.delete(bm,geom=[e for e in bm.edges if e.is_wire],context='EDGES')
    bm.to_mesh(mesh);bm.free()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
    return finish(name,obj,key)
def thread(x,angle):
    phase=((x-.050)/.0008-angle/math.tau)%1.
    return max(0,min(1,(.42-abs(phase-.5))/.3))
def male(x,angle):return .0027+.0003*thread(x,angle)*min(1,max(0,(x-.050)/.0004),max(0,(.055-x)/.0004))
def female(x,angle):return .00275+.0003*thread(x,angle)
radial_stock('Shaft',[(-.2779,.0043),(-.2777,.0045),(-.2762,.0045),(-.276,.0043),(-.276,.003),(.050,.003)]+
    [(.050+.005*i/160,male) for i in range(1,161)]+[(.055,0),(-.2779,0)],'iron')
# Axis rings are welded and degenerate cap faces dissolved by finish().
def hex_outer(x,a):return .004/math.cos((a+math.pi/6)%(math.pi/3)-math.pi/6)
def hex_edge(x,a):return .0038/math.cos((a+math.pi/6)%(math.pi/3)-math.pi/6)
radial_stock('EndNut',[(.051,hex_edge),(.0512,hex_outer),(.0548,hex_outer),(.055,hex_edge)]+
    [(.055-.004*i/128,female) for i in range(129)],'brass')

# Source stock loaded only for form/contact comparison. Original nodes/data stay.
with bpy.data.libraries.load(str(ROOT/'art/blender/fire_service.blend'),link=False) as (available,loaded):
    loaded.objects=['FoldCrown','F037','F007']
crown,legs,case=loaded.objects
for obj in [crown,legs,case]:bpy.context.collection.objects.link(obj);obj.hide_render=True
def tree(obj,frame=Matrix.Identity(4)):
    return BVHTree.FromPolygons([frame@v.co for v in obj.data.vertices],[list(p.vertices) for p in obj.data.polygons])
def frame(at,angle=0):return Matrix.Translation(b(at))@Matrix.Rotation(angle,4,'X')
PIVOT_Y=.397;PIVOT_Z=.032;TIP=(0,.014,.068)
fitted=[];bearing_count=0
for fresh in [False,True]:
    for index in range(10):
        x=-.255+index*.0295+(.01475 if fresh else 0.)
        drop=(.016 if index%2 else .004) if fresh else 0.
        angle=math.atan2(.014,.068)-math.asin((.014-drop)/math.hypot(.014,.068))
        pose=frame((x,PIVOT_Y,PIVOT_Z),angle)
        arm_tree=tree(objects['CarrierArm'],pose)
        crown_pose=frame((x,.411-drop,.100));leg_pose=frame((x,.280-drop,.100))
        assert not arm_tree.overlap(tree(crown,crown_pose)),('crown crossing',fresh,index)
        assert not arm_tree.overlap(tree(legs,leg_pose)),('leg crossing',fresh,index)
        tip=pose@b(TIP);crown_tree=tree(crown,crown_pose)
        for offset in [-.002,-.001,0,.001,.002]:
            at=tip+Vector((offset,0,0))
            a=arm_tree.ray_cast(at,Vector((0,0,1)),.015)[0]
            c=crown_tree.ray_cast(at,Vector((0,0,1)),.015)[0]
            assert a is not None and c is not None and abs(a.z-c.z)<.0001,('bearing',fresh,index,offset,a,c)
            bearing_count+=1
        fitted.append(dict(fresh=fresh,index=index,x_m=x,angle_rad=angle,drop_m=drop))
        assert not tree(objects['Shaft'],frame((0,PIVOT_Y,PIVOT_Z))).overlap(arm_tree),('shaft/eye crossing',fresh,index)
case_bearings=0
case_tree=tree(case,frame((0,.390,.009)))
for x in [-.270,.045]:
    bracket=tree(objects['MountBracket'],frame((x,PIVOT_Y,PIVOT_Z)))
    for y in [-.012,-.006,.006,.012]:
        at=b((x,PIVOT_Y+y,.019));direction=b((0,0,-1))
        a=case_tree.ray_cast(at,direction,.005)[0];c=bracket.ray_cast(at,direction,.005)[0]
        assert a is not None and c is not None and (a-c).length<.0001,('case bearing',x,y,a,c)
        case_bearings+=1
assert not tree(objects['Shaft']).overlap(tree(objects['EndNut'])), 'end thread crossing'
linen_spec=dict(catalog_key='linen',tint=[.75,.71,.59,1],pigment=1.,normal=.08,roughness=.9,metallic=0.)
for obj in [crown,legs]:
    obj.data.materials.clear();obj.data.materials.append(material(ROOT,'PreviewLinen',linen_spec,catalog))


native.hide_render=True;native.hide_viewport=True
for obj in exports.objects:obj.hide_render=True
copies=[]
def show(name,pose):
    obj=draws[name].copy();obj.hide_render=False;obj.matrix_world=pose;bpy.context.collection.objects.link(obj);copies.append(obj)
for x in [-.270,.045]:
    show('MountBracket',frame((x,PIVOT_Y,PIVOT_Z)))
    for y in [-.021,.021]:show('MountScrew',frame((x,PIVOT_Y+y,.022)))
show('Shaft',frame((0,PIVOT_Y,PIVOT_Z)));show('EndNut',frame((0,PIVOT_Y,PIVOT_Z)))
for row in fitted[:10]:
    pose=frame((row['x_m'],PIVOT_Y,PIVOT_Z),row['angle_rad'])
    show('CarrierArm',pose)
    obj=crown.copy();obj.hide_render=False;obj.matrix_world=frame((row['x_m'],.411,.100));bpy.context.collection.objects.link(obj);copies.append(obj)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.render.threads_mode='FIXED';scene.render.threads=4
scene.render.resolution_x=1400;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Neutral fitted rack review');scene.world.color=(.18,.18,.18)
for at,power in [((.10,-.30,.70),8),((-.35,.12,.55),5)]:
    bpy.ops.object.light_add(type='AREA',location=at);light=bpy.context.object;light.data.energy=power;light.data.size=.25
    light.rotation_euler=(b((-.11,.40,.06))-light.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(.21,-.46,.64));scene.camera=bpy.context.object;scene.camera.data.lens=55
scene.camera.rotation_euler=(b((-.11,.40,.06))-scene.camera.location).to_track_quat('-Z','Y').to_euler()
scene.render.filepath=str(OUT/'fitted_rack.png');bpy.ops.render.render(write_still=True)
for obj in copies:
    if obj.data==crown.data:obj.hide_render=True
scene.camera.location=(.17,-.42,.34)
scene.camera.rotation_euler=(b((-.11,.40,.06))-scene.camera.location).to_track_quat('-Z','Y').to_euler()
scene.render.filepath=str(OUT/'bare_rack.png');bpy.ops.render.render(write_still=True)

for obj in copies+[crown,legs,case]:bpy.data.objects.remove(obj,do_unlink=True)
for obj in exports.objects:obj.hide_render=False
result=export(OUT,'fire_hose_rack',exports,material_names_only=True)
glb=OUT/'game/assets/props/fire_hose_rack.glb';validate(glb)
paths=[Path(__file__).resolve(),ROOT/'art/blender/scripts/fabrication_native_batch.py',ROOT/'art/blender/scripts/fabrication_chart_batch.py',ROOT/'art/blender/scripts/fabrication_normals.py',ROOT/'art/blender/fire_service.blend',ROOT/'game/data/runtime_material_sets.json']
bindings={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n') if p.suffix in ['.py','.json'] else p.read_bytes()).hexdigest() for p in paths}
report=dict(evidence_class='INERT',scope='Native rack candidate; no runtime/human acceptance.',source_bindings=bindings,stocks=proofs,fold_poses=fitted,bearing_rays=bearing_count,case_mount_bearings=case_bearings,export=result,glb_sha256=hashlib.sha256(glb.read_bytes()).hexdigest(),blend_sha256=hashlib.sha256((OUT/'art/blender/fire_hose_rack.blend').read_bytes()).hexdigest())
(OUT/'construction.json').write_text(json.dumps(report,indent=2)+'\n')
(OUT/'runtime_projection.json').write_text(json.dumps(dict(schema_version=1,asset='res://assets/props/fire_hose_rack.glb',materials=finishes,parts={k:v['material'] for k,v in proofs.items()},pivot_y_m=PIVOT_Y,pivot_z_m=PIVOT_Z,tip_local_m=TIP),indent=2)+'\n')
print('FIRE HOSE RACK NATIVE PASS',bearing_count)
