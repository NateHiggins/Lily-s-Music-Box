"""Connected folded linen and a real flat-to-round outlet transition.
Authored stock only. Existing mechanism/save owners remain in Godot.
"""
from pathlib import Path
import bpy,bmesh,hashlib,json,math,os,shutil,sys
from mathutils import Matrix,Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[3]
OUT=Path(os.environ.get('ORISON_FIRE_FOLD_OUT',str(ROOT/'tmp/v2-fire-hand-20261019/fold_native1'))).resolve()
assert OUT.is_relative_to(ROOT/'tmp')
for folder in ['art/blender','game/assets/props']:(OUT/folder).mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(Path(__file__).parent))
from fabrication_native_batch import material,partition,export
from check_exported_tangents import validate
if os.environ.get('ORISON_FIRE_FOLD_PUBLISH')=='1':
    report=json.loads((OUT/'construction.json').read_text())
    for path,digest in report['source_bindings'].items():
        p=ROOT/path;raw=p.read_bytes()
        if p.suffix in ['.py','.json']:raw=raw.replace(b'\r\n',b'\n')
        assert hashlib.sha256(raw).hexdigest()==digest,path
    glb=OUT/'game/assets/props/fire_fold_stock.glb';blend=OUT/'art/blender/fire_fold_stock.blend'
    assert hashlib.sha256(glb.read_bytes()).hexdigest()==report['glb_sha256']
    assert hashlib.sha256(blend.read_bytes()).hexdigest()==report['blend_sha256'];validate(glb)
    bpy.ops.wm.open_mainfile(filepath=str(blend));bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/fire_fold_stock.blend'))
    bpy.ops.file.make_paths_relative();bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/fire_fold_stock.blend'))
    report['candidate_blend_sha256']=report['blend_sha256']
    report['blend_sha256']=hashlib.sha256((ROOT/'art/blender/fire_fold_stock.blend').read_bytes()).hexdigest()
    shutil.copyfile(glb,ROOT/'game/assets/props/fire_fold_stock.glb')
    shutil.copyfile(OUT/'runtime_projection.json',ROOT/'game/data/orison_v2/fire_fold_stock.json')
    (ROOT/'art/blender/fire_fold_stock_construction.json').write_text(json.dumps(report,indent=2)+'\n')
    print('FIRE FOLD PUBLISH PASS');raise SystemExit(0)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
def b(p):return Vector((p[0],-p[2],p[1]))
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
finish=dict(catalog_key='linen',tint=[.75,.71,.59,1],pigment=1.,normal=.08,roughness=.9,metallic=0.)
mat=material(ROOT,'linen',finish,catalog)
native=bpy.data.collections.new('Editable continuous folded stock');bpy.context.scene.collection.children.link(native)
exports=bpy.data.collections.new('FireFoldStock');bpy.context.scene.collection.children.link(exports)
sources={};draws={};proofs={};N=64;THICK=.00195;FLAT=.0315
def tube(points,axes,radii):
    vertices=[];faces=[];count=len(points)
    for inner in [False,True]:
        for point,axis,(r,w) in zip(points,axes,radii):
            normal=axis.cross(Vector((0,0,1))).normalized()
            for j in range(N):
                a=math.tau*j/N
                vertices.append(b(point+normal*(r-inner*THICK)*math.cos(a)+Vector((0,0,1))*(w-inner*THICK)*math.sin(a)))
    for inner in range(2):
        off=inner*count*N
        for row in range(count-1):
            for j in range(N):
                face=(off+row*N+j,off+(row+1)*N+j,off+(row+1)*N+(j+1)%N,off+row*N+(j+1)%N)
                faces.append(tuple(reversed(face)) if inner else face)
    for row in [0,count-1]:
        for j in range(N):faces.append((row*N+j,row*N+(j+1)%N,count*N+row*N+(j+1)%N,count*N+row*N+j))
    return vertices,faces
def stock(name,pieces):
    vertices=[];faces=[]
    for p,f in pieces:
        off=len(vertices);vertices.extend(p);faces.extend(tuple(off+i for i in row) for row in f)
    mesh=bpy.data.meshes.new(name+'_Editable');mesh.from_pydata(vertices,[],faces);mesh.update()
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bad=sum(not e.is_manifold for e in bm.edges);volume=bm.calc_volume(signed=True)
    assert bad==0 and volume>0,(name,bad,volume)
    bm.to_mesh(mesh);bm.free();obj=bpy.data.objects.new(name+'_Editable',mesh);native.objects.link(obj);sources[name]=obj
    draws[name]=partition(exports,name,[obj],finish,mat,Matrix.Identity(4),catalog)
    proofs[name]=dict(nonmanifold_edges=bad,volume_m3=volume)
def leg(x):return tube([Vector((x,y,0)) for y in [-.131,.131]],[Vector((0,1,0))]*2,[(.004,FLAT)]*2)
stock('FoldPair',[leg(-.010),leg(.010)])
stock('LastLeg',[leg(-.010)])
def crown(stop=0.):
    angles=[math.pi+(stop-math.pi)*j/64 for j in range(65)]
    return ([Vector((.010*math.cos(a),.010*math.sin(a),0)) for a in angles],
            [Vector((math.sin(a),-math.cos(a),0)) for a in angles])
p,t=crown();stock('Crown',[tube(p,t,[(.004,FLAT)]*len(p))])
# Keep the actual rack bearing arch, then turn the flattened cloth into the
# circular stock. Its annular end is exactly the live S-bend's first ring.
p,t=crown(math.acos(.3));radii=[(.004,FLAT)]*len(p)
start=p[-1];c1=start+t[-1]*.018;end=Vector((.050,.045,0));c2=end-Vector((0,.030,0))
for i in range(1,65):
    a=i/64;s=a*a*(3-2*a)
    p.append((1-a)**3*start+3*(1-a)**2*a*c1+3*(1-a)*a*a*c2+a**3*end)
    t.append((3*(1-a)**2*(c1-start)+6*(1-a)*a*(c2-c1)+3*a*a*(end-c2)).normalized())
    radii.append((.004+(.021-.004)*s,FLAT+(.021-FLAT)*s))
stock('OutletThroat',[tube(p,t,radii)])
# Adjacent hanging lengths are one hose, with nine bottom returns. The old
# ten individual closed loops were not a continuous hose.
gap=.0295-.020;radius=gap/2
for name,delta in [('ReturnFlat',0.),('ReturnRise',.012),('ReturnDrop',-.012)]:
    points=[];axes=[];low=min(0.,delta)
    if low<0:points.append(Vector((0,0,0)));axes.append(Vector((0,-1,0)))
    for i in range(65):
        a=math.pi*i/64
        points.append(Vector((-radius*(1-math.cos(a)),low-radius*math.sin(a),0)))
        axes.append(Vector((-math.sin(a),-math.cos(a),0)))
    if delta>low:points.append(Vector((-gap,delta,0)));axes.append(Vector((0,1,0)))
    stock(name,[tube(points,axes,[(.004,FLAT)]*len(points))])
def tree(obj,frame=Matrix.Identity(4)):
    return BVHTree.FromPolygons([frame@v.co for v in obj.data.vertices],[list(p.vertices) for p in obj.data.polygons])
def frame(at):return Matrix.Translation(b(at))
for name,obj in sources.items():
    own=tree(obj);polygons=[set(p.vertices) for p in obj.data.polygons]
    crossings=[(i,j) for i,j in own.overlap(own) if i<j and not polygons[i].intersection(polygons[j])]
    assert not crossings,(name,'self-intersecting cloth',crossings[:8])

with bpy.data.libraries.load(str(ROOT/'art/blender/fire_hose_rack.blend'),link=False) as (_,loaded):loaded.objects=['CarrierArm_Editable']
arm=loaded.objects[0];assert arm is not None
native.objects.link(arm)
contacts=0;previews=[]
for fresh in [False,True]:
    rows=[]
    for i in range(10):
        drop=(.016 if i%2 else .004) if fresh else 0.
        at=Vector((-.255+i*.0295+(.01475 if fresh else 0),.280-drop,.100))
        key='LastLeg' if i==9 else 'FoldPair';rows.append((key,frame(at)))
        key='OutletThroat' if i==9 else 'Crown';cf=frame(at+Vector((0,.131,0)));rows.append((key,cf))
        height=at.y+.131-.397
        angle=math.atan2(.014,.068)-math.asin(height/math.hypot(.014,.068))
        af=frame((at.x,.397,.032))@Matrix.Rotation(angle,4,'X')
        assert not tree(arm,af).overlap(tree(sources[key],cf)),('rack cloth crossing',fresh,i)
        tip=af@b((0,.014,.068))
        for offset in [-.002,-.001,0.,.001,.002]:
            origin=tip+Vector((offset,0,0))
            a=tree(arm,af).ray_cast(origin,Vector((0,0,1)),.02)[0]
            c=tree(sources[key],cf).ray_cast(origin,Vector((0,0,1)),.02)[0]
            assert a is not None and c is not None and abs(a.z-c.z)<.0001,('rack bearing',fresh,i,offset,a,c)
            contacts+=1
        if i>0:
            prev_drop=(.016 if (i-1)%2 else .004) if fresh else 0.
            delta=drop-prev_drop
            key='ReturnRise' if delta>.001 else ('ReturnDrop' if delta<-.001 else 'ReturnFlat')
            rows.append((key,frame(at+Vector((-.010,-.131,0)))))
    if not fresh:previews=rows
# Annular endpoint correspondence, not just centerline proximity.
joins=0
for key in ['ReturnFlat','ReturnRise','ReturnDrop']:
    for x,y in [(0,0),(-gap,{'ReturnFlat':0.,'ReturnRise':.012,'ReturnDrop':-.012}[key])]:
        for j in range(16):
            a=math.tau*j/16;r=.004-THICK*.5;w=FLAT-THICK*.5
            at=Vector((x+r*math.cos(a),y+.00002,w*math.sin(a)))
            hit=tree(sources[key]).ray_cast(b(at),b((0,-1,0)),.00004)[0]
            assert hit is not None and abs(hit.z-y)<.0001,(key,'open seam',j,hit)
            joins+=1
native.hide_render=True;native.hide_viewport=True
for obj in exports.objects:obj.hide_render=True
copies=[]
for key,pose in previews:
    obj=draws[key].copy();obj.hide_render=False;obj.matrix_world=pose;bpy.context.collection.objects.link(obj);copies.append(obj)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=20
scene.render.threads_mode='FIXED';scene.render.threads=4
scene.render.resolution_x=1400;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Neutral folded hose');scene.world.color=(.18,.18,.18)
for at,power in [((.2,-.4,.75),12),((-.35,.15,.6),8)]:
    bpy.ops.object.light_add(type='AREA',location=at);light=bpy.context.object;light.data.energy=power;light.data.size=.3
    light.rotation_euler=(b((-.10,.31,.1))-light.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(.28,-.45,.6));scene.camera=bpy.context.object;scene.camera.data.lens=55
scene.camera.rotation_euler=(b((-.10,.31,.1))-scene.camera.location).to_track_quat('-Z','Y').to_euler()
scene.render.filepath=str(OUT/'native_connected_folds.png');bpy.ops.render.render(write_still=True)
for obj in copies:bpy.data.objects.remove(obj,do_unlink=True)
for obj in exports.objects:obj.hide_render=False
result=export(OUT,'fire_fold_stock',exports,material_names_only=True)
glb=OUT/'game/assets/props/fire_fold_stock.glb';validate(glb)
paths=[Path(__file__).resolve(),ROOT/'art/blender/scripts/fabrication_native_batch.py',ROOT/'art/blender/scripts/fabrication_chart_batch.py',ROOT/'art/blender/scripts/fabrication_normals.py',ROOT/'art/blender/fire_hose_rack.blend',ROOT/'game/data/runtime_material_sets.json']
bindings={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n') if p.suffix in ['.py','.json'] else p.read_bytes()).hexdigest() for p in paths}
report=dict(evidence_class='INERT',scope='Continuous fold/outlet candidate; full 50-foot audit and nozzle transition remain open.',source_bindings=bindings,stocks=proofs,rack_bearings=contacts,return_bearings=joins,export=result,glb_sha256=hashlib.sha256(glb.read_bytes()).hexdigest(),blend_sha256=hashlib.sha256((OUT/'art/blender/fire_fold_stock.blend').read_bytes()).hexdigest())
(OUT/'construction.json').write_text(json.dumps(report,indent=2)+'\n')
(OUT/'runtime_projection.json').write_text(json.dumps(dict(schema_version=1,asset='res://assets/props/fire_fold_stock.glb',material=finish,parts=list(sources),outlet_from_crown_m=[.050,.045,0]),indent=2)+'\n')
print('FIRE FOLD NATIVE PASS',contacts,joins)
