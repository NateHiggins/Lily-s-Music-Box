"""Editable native nozzle barrel and forged valve lever; no standard claim.
Candidate output is confined to tmp. Publication verifies original closure.
Godot coordinates in metres: nozzle +Y, spindle +Z, lever locally +X.
"""
from pathlib import Path
import hashlib, json, math, os, sys, shutil
import bpy, bmesh
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

ROOT=Path(__file__).resolve().parents[3]
OUT=Path(os.environ.get('ORISON_FIRE_NOZZLE_DETAIL_OUT',str(ROOT/'tmp/v2-fire-hand-20261019/nozzle_detail_native1'))).resolve()
assert OUT.is_relative_to(ROOT/'tmp'),OUT
for folder in ['art/blender','game/assets/props']:(OUT/folder).mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(Path(__file__).parent))
from fabrication_native_batch import material, partition, export
from check_exported_tangents import validate

if os.environ.get('ORISON_FIRE_NOZZLE_DETAIL_PUBLISH')=='1':
    report=json.loads((OUT/'construction.json').read_text())
    for path,digest in report['source_bindings'].items():
        p=ROOT/path;raw=p.read_bytes()
        if p.suffix in ['.py','.json']:raw=raw.replace(b'\r\n',b'\n')
        assert hashlib.sha256(raw).hexdigest()==digest,path
    for path,key in [('game/assets/props/fire_nozzle_detail.glb','glb_sha256'),('art/blender/fire_nozzle_detail.blend','blend_sha256')]:
        assert hashlib.sha256((OUT/path).read_bytes()).hexdigest()==report[key],path
    validate(OUT/'game/assets/props/fire_nozzle_detail.glb')
    bpy.ops.wm.open_mainfile(filepath=str(OUT/'art/blender/fire_nozzle_detail.blend'));bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/fire_nozzle_detail.blend'))
    bpy.ops.file.make_paths_relative();bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/fire_nozzle_detail.blend'))
    shutil.copy2(OUT/'game/assets/props/fire_nozzle_detail.glb',ROOT/'game/assets/props/fire_nozzle_detail.glb')
    shutil.copy2(OUT/'runtime_projection.json',ROOT/'game/data/orison_v2/fire_nozzle_detail.json')
    report['published_blend_sha256']=hashlib.sha256((ROOT/'art/blender/fire_nozzle_detail.blend').read_bytes()).hexdigest()
    (ROOT/'art/blender/fire_nozzle_detail_construction.json').write_text(json.dumps(report,indent=2)+'\n')
    print('FIRE NOZZLE DETAIL PUBLISH PASS');raise SystemExit(0)

bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
finishes={'brass':dict(catalog_key='radiator_service_brass',tint=[.90,.82,.63,1.],pigment=1.,normal=.12,roughness=1.,metallic=.92),
          'iron':dict(catalog_key='iron_neutral',tint=[.17,.18,.17,1.],pigment=1.,normal=.12,roughness=.95,metallic=.85)}
materials={k:material(ROOT,k,v,catalog) for k,v in finishes.items()}
native=bpy.data.collections.new('Editable nozzle fabricated stock');bpy.context.scene.collection.children.link(native)
exports=bpy.data.collections.new('FireNozzleDetail');bpy.context.scene.collection.children.link(exports)
objects={};metrics={};SIDES=96
def b(p):return Vector((p[0],-p[2],p[1]))
def make(name,vertices,faces,key,bevel=0.):
    mesh=bpy.data.meshes.new(name+'_EditableMesh');mesh.from_pydata([b(v) for v in vertices],[],faces);mesh.update()
    obj=bpy.data.objects.new(name+'_Editable',mesh);native.objects.link(obj)
    if bevel:
        bpy.context.view_layer.objects.active=obj;mod=obj.modifiers.new('Forged edge easing','BEVEL');mod.width=bevel;mod.segments=3
        bpy.ops.object.modifier_apply(modifier=mod.name)
    objects[name]=obj;return obj
def lathe(name,profile,key,axis='Y',center=(0,0,0),radius=None):
    vertices=[];faces=[]
    for height,r in profile:
        for j in range(SIDES):
            a=math.tau*j/SIDES;rr=radius(a,r) if radius else r
            h=height(a,rr) if callable(height) else height
            p=(rr*math.cos(a),h,rr*math.sin(a)) if axis=='Y' else (rr*math.cos(a),rr*math.sin(a),h)
            vertices.append(tuple(p[i]+center[i] for i in range(3)))
    for row in range(len(profile)):
        n=(row+1)%len(profile)
        for j in range(SIDES):faces.append((row*SIDES+j,n*SIDES+j,n*SIDES+(j+1)%SIDES,row*SIDES+(j+1)%SIDES))
    return make(name,vertices,faces,key)
def boolean(obj,other,operation):
    bpy.context.view_layer.objects.active=obj;mod=obj.modifiers.new('Fabricated '+operation,'BOOLEAN');mod.operation=operation;mod.solver='EXACT';mod.object=other
    bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(other,do_unlink=True)
def cylinder(radius,depth,at):
    bpy.ops.mesh.primitive_cylinder_add(vertices=SIDES,radius=radius,depth=depth,location=b(at),rotation=(math.pi/2,0,0));return bpy.context.object
barrel=lathe('Barrel',[(0.,.021),(.0006,.0215),(.008,.0215),(.010,.024),(.012,.024),(.014,.0225),
    (.023,.0225),(.025,.0255),(.027,.026),(.061,.026),(.063,.024),(.065,.021),(.142,.0108),(.151,.0104),
    (.152,.0122),(.156,.0122),(.157,.0105),(.167,.0101),(.168,.0118),(.170,.0118),
    (.170,.0079),(.168,.0079),(.065,.012),(0.,.012)],'brass')
boolean(barrel,cylinder(.00305,.026,(0,.044,.021)),'DIFFERENCE')
back=lambda a,r:math.sqrt(.026**2-(r*math.cos(a))**2)
lathe('ValveGland',[(back,.009),(.0298,.009),(.0305,.0083),(.0305,.00305)]+
    [(back,.00305+(.009-.00305)*i/16) for i in range(16)],'brass','Z',(0,.044,0))
lathe('ThrustWasher',[(.0305,.007),(.031,.007),(.031,.00305),(.0305,.00305)],'brass','Z',(0,.044,0))
spindle=cylinder(.003,.030,(0,.044,.025))
spindle.data.transform(spindle.matrix_world);spindle.matrix_world=Matrix.Identity(4)
for collection in list(spindle.users_collection):collection.objects.unlink(spindle)
native.objects.link(spindle);spindle.name='Spindle_Editable';objects['Spindle']=spindle
hexagon=lambda a,r:r*math.cos(math.pi/6)/math.cos((a+math.pi/6)%(math.pi/3)-math.pi/6) if r>.004 else r
lathe('SpindleNut',[(.037,.0055),(.039,.0055),(.0395,.005),(.0395,.00305),(.037,.00305)],'brass','Z',(0,.044,0),hexagon)
# One continuous forged piece, including the bored eye; no cylinder through
# the valve chamber and no disconnected rectangular handle glued to a ring.
lever=lathe('ForgedLever',[(-.003,.009),(.003,.009),(.003,.00305),(-.003,.00305)],'iron','Z')
outline=[(.004,.006),(.018,.005),(.045,.009),(.070,.013),(.086,.012),(.092,.008),(.092,0.),(.086,-.004),(.070,-.004),(.045,-.002),(.017,-.004),(.004,-.006)]
vertices=[(x,y,z) for z in [-.003,.003] for x,y in outline];n=len(outline)
faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
shank=make('TemporaryShank',vertices,faces,'iron');boolean(lever,shank,'UNION');objects.pop('TemporaryShank')
bpy.context.view_layer.objects.active=lever;mod=lever.modifiers.new('Rounded forged grip edges','BEVEL');mod.width=.00065;mod.segments=3;bpy.ops.object.modifier_apply(modifier=mod.name)
parts={}
for name,obj in objects.items():
    bm=bmesh.new();bm.from_mesh(obj.data)
    # Exact booleans can duplicate a trigonometric seam by 1e-18 m. Weld
    # only sub-nanometre coincidences before charts, retaining fitted bores.
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-9)
    bmesh.ops.dissolve_limit(bm,angle_limit=1e-4,use_dissolve_boundaries=True,verts=list(bm.verts),edges=list(bm.edges))
    bmesh.ops.triangulate(bm,faces=list(bm.faces))
    bmesh.ops.dissolve_degenerate(bm,dist=1e-8,edges=list(bm.edges))
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bad=sum(not e.is_manifold for e in bm.edges);volume=bm.calc_volume(signed=True)
    assert bad==0 and volume>0,(name,bad,volume)
    bm.to_mesh(obj.data);bm.free();key='iron' if name=='ForgedLever' else 'brass'
    parts[name]=partition(exports,name,[obj],finishes[key],materials[key],Matrix.Identity(4),catalog)
    metrics[name]=dict(nonmanifold_edges=bad,volume_m3=volume,triangles=len(parts[name].data.polygons))
def tree(name,frame=Matrix.Identity(4)):
    obj=objects[name];return BVHTree.FromPolygons([frame@v.co for v in obj.data.vertices],[list(p.vertices) for p in obj.data.polygons])
lever_at=Matrix.Translation(b((0,.044,.034)))
poses=[]
for i in range(65):
    angle=math.pi-.95*i/64;frame=lever_at@Matrix.Rotation(angle,4,b((0,0,1)))
    moving=tree('ForgedLever',frame)
    for fixed in ['Barrel','ValveGland','Spindle']:
        assert not moving.overlap(tree(fixed)),('lever collision',i,fixed)
    for fixed,plane in [('ThrustWasher',.031),('SpindleNut',.037)]:
        contacts=moving.overlap(tree(fixed))
        for left,right in contacts:
            points=[frame@objects['ForgedLever'].data.vertices[v].co for v in objects['ForgedLever'].data.polygons[left].vertices]
            other=[objects[fixed].data.vertices[v].co for v in objects[fixed].data.polygons[right].vertices]
            a=[-p.y-plane for p in points];c=[-p.y-plane for p in other]
            separated=(min(a)>-1e-7 and max(c)<1e-7) if fixed=='ThrustWasher' else (max(a)<1e-7 and min(c)>-1e-7)
            assert separated,(i,fixed,'nonbearing contact',a,c)
    poses.append(dict(angle_rad=angle,clearance_to_gland_m=.0005))
# Positive stock and open bores: native source geometry, not envelope labels.
bores=0
for name,start,direction,length in [('Barrel',(0,-.005,0),(0,1,0),.18),('ForgedLever',(0,0,-.01),(0,0,1),.02)]:
    assert tree(name).ray_cast(b(start),b(direction),length)[0] is None,name
    bores+=1
assert tree('ForgedLever').ray_cast(b((.075,.004,-.01)),b((0,0,1)),.02)[0] is not None
assert tree('Barrel').ray_cast(b((.017,-.005,0)),b((0,1,0)),.02)[0] is not None
bearings=0
for i in range(16):
    angle=math.tau*i/16;x=.006*math.cos(angle);y=.044+.006*math.sin(angle)
    z=math.sqrt(.026**2-x*x)
    start=b((x,y,z+.0001));direction=b((0,0,-1))
    a=tree('Barrel').ray_cast(start,direction,.001)[0]
    c=tree('ValveGland').ray_cast(start,direction,.001)[0]
    assert a is not None and c is not None and (a-c).length<.0001,('gland bearing',i,a,c)
    bearings+=1
native.hide_render=True;native.hide_viewport=True
for obj in exports.objects:obj.hide_render=True
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32;scene.render.threads_mode='FIXED';scene.render.threads=4
scene.render.resolution_x=1400;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Neutral native nozzle review');scene.world.color=(.14,.14,.14)
for at,power,size in [((.18,.17,.27),5,.18),((-.14,-.18,.16),3,.14)]:
    bpy.ops.object.light_add(type='AREA',location=b(at));light=bpy.context.object;light.data.energy=power;light.data.size=size;light.rotation_euler=(b((0,.08,.02))-light.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=b((.34,.29,.36)));scene.camera=bpy.context.object;scene.camera.data.lens=50
scene.camera.rotation_euler=(b((-.018,.080,.012))-scene.camera.location).to_track_quat('-Z','Y').to_euler()
copies=[]
for name,obj in parts.items():
    copy=obj.copy();copy.hide_render=False;bpy.context.collection.objects.link(copy);copies.append(copy)
    if name=='ForgedLever':copy.matrix_world=lever_at@Matrix.Rotation(math.pi-.55,4,b((0,0,1)))
scene.render.filepath=str(OUT/'detailed_nozzle_assembled.png');bpy.ops.render.render(write_still=True)
for copy in copies:
    if copy.name.startswith('ForgedLever'):copy.matrix_world=Matrix.Translation(b((-.02,.044,.068)))@Matrix.Rotation(math.pi-.55,4,b((0,0,1)))
scene.render.filepath=str(OUT/'detailed_nozzle_pivot.png');bpy.ops.render.render(write_still=True)
for copy in copies:bpy.data.objects.remove(copy,do_unlink=True)
for obj in exports.objects:obj.hide_render=False
result=export(OUT,'fire_nozzle_detail',exports,material_names_only=True)
glb=OUT/'game/assets/props/fire_nozzle_detail.glb';validate(glb)
paths=[Path(__file__).resolve(),ROOT/'art/blender/scripts/fabrication_native_batch.py',ROOT/'art/blender/scripts/fabrication_chart_batch.py',ROOT/'art/blender/scripts/fabrication_normals.py',ROOT/'game/data/runtime_material_sets.json']
bindings={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n') if p.suffix in ['.py','.json'] else p.read_bytes()).hexdigest() for p in paths}
report=dict(evidence_class='INERT',scope='Native candidate; not installed or accepted in game.',source_bindings=bindings,stocks=metrics,lever_travel=poses,clear_bores=bores,gland_body_bearings=bearings,export=result,glb_sha256=hashlib.sha256(glb.read_bytes()).hexdigest(),blend_sha256=hashlib.sha256((OUT/'art/blender/fire_nozzle_detail.blend').read_bytes()).hexdigest())
(OUT/'construction.json').write_text(json.dumps(report,indent=2)+'\n')
(OUT/'runtime_projection.json').write_text(json.dumps(dict(schema_version=1,asset='res://assets/props/fire_nozzle_detail.glb',materials=finishes,parts={name:'iron' if name=='ForgedLever' else 'brass' for name in objects},lever_pivot_m=[0,.044,.034]),indent=2)+'\n')
print('FIRE NOZZLE DETAIL NATIVE PASS',json.dumps(metrics))
