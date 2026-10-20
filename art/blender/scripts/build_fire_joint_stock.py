"""Candidate matched fire-union stock; custom dimensions, no standard claim.
Builds only below tmp until native/loaded and original apparatus review pass.
"""
from pathlib import Path
import hashlib,json,math,os,shutil,sys
import bpy,bmesh
from mathutils import Matrix,Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[3]
OUT=Path(os.environ.get('ORISON_FIRE_JOINT_OUT',str(ROOT/'tmp/v2-fire-hand-20261019/joint_native1'))).resolve()
assert OUT.is_relative_to(ROOT/'tmp'),OUT
for folder in ['art/blender','game/assets/props']: (OUT/folder).mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(Path(__file__).parent))
from fabrication_native_batch import material,partition,export
if os.environ.get('ORISON_FIRE_JOINT_PUBLISH')=='1':
    from check_exported_tangents import validate
    report=json.loads((OUT/'construction.json').read_text())
    for relative,digest in report['source_bindings'].items():
        assert hashlib.sha256((ROOT/relative).read_bytes().replace(b'\r\n',b'\n')).hexdigest()==digest,relative
    source=OUT/'game/assets/props/fire_joint_stock.glb'
    blend=OUT/'art/blender/fire_joint_stock.blend'
    assert hashlib.sha256(source.read_bytes()).hexdigest()==report['glb_sha256']
    assert hashlib.sha256(blend.read_bytes()).hexdigest()==report['blend_sha256']
    validate(source)
    bpy.ops.wm.open_mainfile(filepath=str(blend));bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/fire_joint_stock.blend'))
    bpy.ops.file.make_paths_relative();bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/fire_joint_stock.blend'))
    report['candidate_blend_sha256']=report['blend_sha256']
    report['blend_sha256']=hashlib.sha256((ROOT/'art/blender/fire_joint_stock.blend').read_bytes()).hexdigest()
    shutil.copyfile(source,ROOT/'game/assets/props/fire_joint_stock.glb')
    shutil.copyfile(OUT/'runtime_projection.json',ROOT/'game/data/orison_v2/fire_joint_stock.json')
    (ROOT/'art/blender/fire_joint_stock_construction.json').write_text(json.dumps(report,indent=2)+'\n')
    print('FIRE JOINT PUBLISH PASS: original stock validated; no geometry rebuild')
    raise SystemExit(0)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version=0
PITCH=.0028;ROOT_R=.023;CREST=.024;CLEAR=.00025;BORE=.01905;SIDES=96
MALE_ORIGIN=.556;UNION_ORIGIN=.513;TIP=.533;GASKET=.0015
def profile(y,angle):
    phase=((y-TIP)/PITCH-angle/math.tau)%1.
    return max(0.,min(1.,(.42-abs(phase-.5))/.30))
def male_r(y,angle):
    y+=MALE_ORIGIN
    fade=min(1.,max(0.,(y-TIP)/(PITCH*.5)),max(0.,(.548-y)/(PITCH*.5)))
    return ROOT_R+(CREST-ROOT_R)*profile(y,angle)*fade
def female_r(y,angle):
    # Same phase, ample lead chamfer, real annular sealing shelf beneath.
    return ROOT_R+CLEAR+(CREST-ROOT_R)*max(profile(y+UNION_ORIGIN,angle),max(0.,(y-.026)/.001))
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
finishes={
 'brass':dict(catalog_key='radiator_service_brass',tint=[.90,.82,.63,1],pigment=1.,normal=.15,roughness=.8,metallic=.92),
 'linen':dict(catalog_key='linen',tint=[.75,.71,.59,1],pigment=1.,normal=.08,roughness=.9,metallic=0.),
 'rubber':dict(catalog_key='washer_rubber',tint=[.50,.40,.34,1],pigment=1.,normal=.15,roughness=.9,metallic=0.)}
# Resolve only already-registered catalogue keys; never invent fallback maps.
for spec in finishes.values():assert spec['catalog_key'] in catalog,spec
mats={key:material(ROOT,key,spec,catalog) for key,spec in finishes.items()}
native=bpy.data.collections.new('Editable joint profiles');bpy.context.scene.collection.children.link(native)
exports=bpy.data.collections.new('FireJointStock');bpy.context.scene.collection.children.link(exports)
metrics={};objects={}
def stock(name,rings,key):
    vertices=[]
    for y,radius in rings:
        for i in range(SIDES):
            angle=math.tau*i/SIDES;r=radius(y,angle) if callable(radius) else radius
            vertices.append((r*math.cos(angle),-r*math.sin(angle),y))
    faces=[]
    for row in range(len(rings)):
        next_row=(row+1)%len(rings)
        for i in range(SIDES):
            j=(i+1)%SIDES
            faces.append((row*SIDES+i,next_row*SIDES+i,next_row*SIDES+j,row*SIDES+j))
    mesh=bpy.data.meshes.new(name+'_EditableMesh');mesh.from_pydata(vertices,[],faces);mesh.update()
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bad=sum(not edge.is_manifold for edge in bm.edges);volume=bm.calc_volume(signed=True)
    assert bad==0 and volume>0,(name,bad,volume)
    bm.to_mesh(mesh);bm.free()
    obj=bpy.data.objects.new(name+'_Editable',mesh);native.objects.link(obj)
    objects[name]=obj
    result=partition(exports,name,[obj],finishes[key],mats[key],Matrix.Identity(4),catalog)
    metrics[name]=dict(nonmanifold_edges=bad,volume_m3=volume,triangles=len(result.data.polygons))
    return result
start=TIP-MALE_ORIGIN;end=.548-MALE_ORIGIN
steps=math.ceil((end-start)/PITCH*32)
male=stock('MaleOutlet',[(start+(end-start)*i/steps,male_r) for i in range(steps+1)]+
    [(.023,ROOT_R),(.023,BORE),(start,BORE)],'brass')
start=.020;end=.027;steps=math.ceil((end-start)/PITCH*32)
female=stock('FemaleUnion',[(-.025,.0315),(-.0245,.032),(.0265,.032),(.027,.0315)]+
    [(end-(end-start)*i/steps,female_r) for i in range(steps+1)]+
    [(.017,ROOT_R+CLEAR),(.017,.02125),(-.025,.02125)],'brass')
tail=stock('SwivelTail',[(-.035,.0195),(.017,.0195),(.017,.02275),(.020,.02275),(.020,BORE),(-.035,BORE)],'brass')
neck=stock('HoseNeck',[(-.068,.021),(-.025,.021),(-.025,.0195),(-.035,.0195),(-.068,BORE)],'linen')
cuff=stock('HoseRetainer',[(-.034,.023),(-.025,.023),(-.025,.021),(-.034,.021)],'brass')
gasket=stock('UnionGasket',[(0.,.02275),(GASKET,.02275),(GASKET,BORE),(0.,BORE)],'rubber')
def tree(obj,offset,angle=0.):
    # Godot (x,y,z) -> Blender (x,-z,y): positive Y maps to positive Z.
    frame=Matrix.Translation((0,0,offset))@Matrix.Rotation(angle,4,'Z')
    return BVHTree.FromPolygons([frame@v.co for v in obj.data.vertices],
        [list(face.vertices) for face in obj.data.polygons],all_triangles=False,epsilon=0.)
male_tree=tree(objects['MaleOutlet'],MALE_ORIGIN)
poses=[]
# Includes the actual gasket stop, not only the empty hard stop.
for step,withdrawal in enumerate(sorted(set([GASKET]+[.008*i/12 for i in range(13)]))):
    angle=withdrawal/PITCH*math.tau
    y=UNION_ORIGIN-withdrawal
    female_tree=tree(objects['FemaleUnion'],y,angle)
    overlap=male_tree.overlap(female_tree)
    assert not overlap,('male crosses swivel nut',step,len(overlap))
    # The nut rotates around the stationary tail. Its retaining lip bears
    # against the underside of the tail flange at every screw position.
    # Admit only contact at that measured plane, never crossing thread stock.
    contact=0
    tail_tree=tree(objects['SwivelTail'],y)
    for a,b in tail_tree.overlap(female_tree):
        am=objects['SwivelTail'];bf=objects['FemaleUnion']
        az=[am.data.vertices[i].co.z+y for i in am.data.polygons[a].vertices]
        bz=[bf.data.vertices[i].co.z+y for i in bf.data.polygons[b].vertices]
        plane=y+.017
        assert min(az)>=plane-1e-7 and max(bz)<=plane+1e-7 and min(az)<=plane+1e-7 and max(bz)>=plane-1e-7,('swivel stock crosses retaining lip',step,a,b,az,bz)
        contact+=1
    poses.append(dict(angle_rad=angle,origin_y_m=y,intersecting_triangles=0,swivel_bearing_contact_pairs=contact))
# Actual triangle bore rays and actual end/seat triangle bearings, not bounds.
for name,origin in [('MaleOutlet',MALE_ORIGIN),('FemaleUnion',UNION_ORIGIN),('SwivelTail',UNION_ORIGIN),('HoseNeck',UNION_ORIGIN),('HoseRetainer',UNION_ORIGIN),('UnionGasket',TIP-GASKET)]:
    bvh=tree(objects[name],origin);clear=0
    for i in range(17):
        angle=math.tau*i/16;radius=0. if i==16 else BORE-.0001
        assert bvh.ray_cast(Vector((radius*math.cos(angle),radius*math.sin(angle),.45)),Vector((0,0,1)),.2)[0] is None,(name,'blocked bore')
        clear+=1
    metrics[name]['clear_bore_rays']=clear
seat_tree=tree(objects['SwivelTail'],UNION_ORIGIN-GASKET)
gasket_tree=tree(objects['UnionGasket'],TIP-GASKET)
for i in range(16):
    angle=math.tau*i/16;radius=(BORE+.02275)*.5
    p=Vector((radius*math.cos(angle),radius*math.sin(angle),TIP+.0005))
    gasket_hit=gasket_tree.ray_cast(p,Vector((0,0,-1)),.005)[0]
    seat_hit=seat_tree.ray_cast(p,Vector((0,0,-1)),.005)[0]
    assert gasket_hit is not None and abs(gasket_hit.z-TIP)<.0001
    assert seat_hit is not None and abs(seat_hit.z-(TIP-GASKET))<.0001
metrics['sealing_bearing_rays']=16
metrics['retaining_lip_bearing_rays']=0
support_tree=tree(objects['FemaleUnion'],UNION_ORIGIN)
tail_tree=tree(objects['SwivelTail'],UNION_ORIGIN)
for i in range(16):
    angle=math.tau*i/16;radius=.022
    origin=Vector((radius*math.cos(angle),radius*math.sin(angle),UNION_ORIGIN+.016))
    tail_hit=tail_tree.ray_cast(origin,Vector((0,0,1)),.01)[0]
    # The nut lip is an upper face, the tail flange a lower bearing face.
    nut_hit=support_tree.ray_cast(origin+Vector((0,0,.008)),Vector((0,0,-1)),.01)[0]
    assert tail_hit is not None and nut_hit is not None and abs(tail_hit.z-(UNION_ORIGIN+.017))<.0001 and abs(nut_hit.z-tail_hit.z)<.0001
    metrics['retaining_lip_bearing_rays']+=1
native.hide_render=True;native.hide_viewport=True
# Exploded native comparison; original local stock/exports stay untransformed.
copies=[]
parts=[male,female,tail,neck,cuff,gasket]
for obj,at in [(male,(-.13,0,MALE_ORIGIN)),(female,(-.045,0,UNION_ORIGIN)),(tail,(.045,0,UNION_ORIGIN)),(neck,(.13,0,UNION_ORIGIN)),(cuff,(.20,0,UNION_ORIGIN)),(gasket,(.20,0,.57))]:
    obj.hide_render=True;copy=obj.copy();copy.hide_render=False;copy.location=at
    bpy.context.collection.objects.link(copy);copies.append(copy)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
scene.render.threads_mode='FIXED';scene.render.threads=4
scene.render.resolution_x=1100;scene.render.resolution_y=850;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Neutral fitting review');scene.world.color=(.18,.18,.18)
for position,power in [((.1,-.3,.85),4),((-.2,.15,.68),3)]:
    bpy.ops.object.light_add(type='AREA',location=position);light=bpy.context.object;light.data.energy=power;light.data.size=.25
    light.rotation_euler=(Vector((.08,0,.54))-light.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(.35,-.52,.86));scene.camera=bpy.context.object;scene.camera.data.lens=50
scene.camera.rotation_euler=(Vector((.035,0,.53))-scene.camera.location).to_track_quat('-Z','Y').to_euler()
scene.render.filepath=str(OUT/'native_joint.png');bpy.ops.render.render(write_still=True)
for copy in copies:bpy.data.objects.remove(copy,do_unlink=True)
for obj in parts:obj.hide_render=False
proof=export(OUT,'fire_joint_stock',exports,material_names_only=True)
bindings={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest() for p in
 [Path(__file__).resolve(),ROOT/'art/blender/scripts/fabrication_native_batch.py',ROOT/'art/blender/scripts/fabrication_chart_batch.py',ROOT/'art/blender/scripts/fabrication_normals.py',ROOT/'game/data/runtime_material_sets.json']}
report=dict(evidence_class='INERT',scope='Uninstalled native candidate, not runtime/human acceptance.',source_bindings=bindings,
 dimensions=dict(pitch_m=PITCH,radial_clearance_m=CLEAR,bore_radius_m=BORE,male_origin_y_m=MALE_ORIGIN,empty_union_origin_y_m=UNION_ORIGIN,gasket_thickness_m=GASKET),
 stocks=metrics,thread_motion=poses,export=proof,
 blend_sha256=hashlib.sha256((OUT/'art/blender/fire_joint_stock.blend').read_bytes()).hexdigest(),
 glb_sha256=hashlib.sha256((OUT/'game/assets/props/fire_joint_stock.glb').read_bytes()).hexdigest())
(OUT/'construction.json').write_text(json.dumps(report,indent=2)+'\n')
projection=dict(schema_version=1,asset='res://assets/props/fire_joint_stock.glb',dimensions=report['dimensions'],
    materials=finishes,parts={'MaleOutlet':'brass','FemaleUnion':'brass','SwivelTail':'brass','HoseNeck':'linen','HoseRetainer':'brass','UnionGasket':'rubber'})
(OUT/'runtime_projection.json').write_text(json.dumps(projection,indent=2)+'\n')
print('FIRE JOINT STOCK PASS',json.dumps(report['stocks']))
