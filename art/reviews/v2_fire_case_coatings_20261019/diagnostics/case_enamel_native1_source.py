"""Native case coatings on retained steel; no authority or texture key.
The old ten-millimetre visual slab stood above the physical supporting steel.
Author a closed coating, with the fixed tin's paint-free bearing footprint.
"""
from pathlib import Path
import bpy,bmesh,json,math,hashlib,os,sys,shutil
from mathutils import Matrix,Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[3]
OUT=Path(os.environ.get('ORISON_FIRE_FLOOR_OUT',str(ROOT/'tmp/v2-fire-hand-20261019/case_enamel_native1'))).resolve()
assert OUT.is_relative_to(ROOT/'tmp')
for name in ['art/blender','game/assets/props']:(OUT/name).mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(Path(__file__).parent))
from fabrication_native_batch import material,partition,export
from check_exported_tangents import validate
if os.environ.get('ORISON_FIRE_FLOOR_PUBLISH')=='1':
    report=json.loads((OUT/'construction.json').read_text())
    for name,digest in report['source_bindings'].items():
        raw=(ROOT/name).read_bytes()
        if Path(name).suffix in ['.py','.json']:raw=raw.replace(b'\r\n',b'\n')
        assert hashlib.sha256(raw).hexdigest()==digest,name
    for name,digest in report['outputs'].items():assert hashlib.sha256((OUT/name).read_bytes()).hexdigest()==digest,name
    bpy.ops.wm.open_mainfile(filepath=str(OUT/'art/blender/fire_floor_enamel.blend'))
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/fire_floor_enamel.blend'))
    bpy.ops.file.make_paths_relative();bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/fire_floor_enamel.blend'))
    report['published_blend_sha256']=hashlib.sha256((ROOT/'art/blender/fire_floor_enamel.blend').read_bytes()).hexdigest()
    shutil.copy2(OUT/'game/assets/props/fire_floor_enamel.glb',ROOT/'game/assets/props/fire_floor_enamel.glb')
    (ROOT/'art/blender/fire_floor_enamel_construction.json').write_text(json.dumps(report,indent=2)+'\n')
    print('FIRE FLOOR ENAMEL PUBLISH PASS');raise SystemExit(0)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
def b(x,y,z):return Vector((x,-z,y))
def frame(at):return Matrix.Translation(b(*at))
def tree(obj,at=Matrix.Identity(4)):
    return BVHTree.FromPolygons([at@v.co for v in obj.data.vertices],[list(p.vertices) for p in obj.data.polygons])
data=json.loads((ROOT/'game/data/orison_v2/fire_service.json').read_text())
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
def finish(key):
    s=next(x for x in data['materials'] if x['key']==key)
    return dict(catalog_key=s['catalog'],tint=s['tint'],pigment=1.,normal=s['normal'],roughness=s['roughness'],metallic=s['metallic'])
spec=finish('Lining');mat=material(ROOT,'Lining',spec,catalog)
native=bpy.data.collections.new('Editable case enamel');bpy.context.scene.collection.children.link(native)
exports=bpy.data.collections.new('FireFloorEnamel');bpy.context.scene.collection.children.link(exports)
plans={
 'FloorEnamel':dict(origin=(0,.027,.108),center=(0,-.004975,.0025),size=(.576,.00005,.185),source='F015',steel='F011'),
 'LeftEnamel':dict(origin=(-.283,.390,.108),center=(-.004975,0,.0025),size=(.00005,.7359,.185),source='F012',steel='F008'),
 'RightEnamel':dict(origin=(.283,.390,.108),center=(.004975,0,.0025),size=(.00005,.7359,.185),source='F013',steel='F009'),
 'TopEnamel':dict(origin=(0,.753,.108),center=(0,.004975,.0025),size=(.576,.00005,.185),source='F014',steel='F010')}
sources={};draws={};proofs={};frames={key:frame(plan['origin']) for key,plan in plans.items()}
for key,plan in plans.items():
    bpy.ops.mesh.primitive_cube_add(size=1,location=b(*plan['center']))
    coat=bpy.context.object;coat.name=key+'_Editable';x,y,z=plan['size'];coat.dimensions=(x,z,y)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if key=='FloorEnamel':
        bpy.ops.mesh.primitive_cube_add(size=1,location=b(.245,-.004975,.042))
        mask=bpy.context.object;mask.dimensions=(.0682,.0682,.004)
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        bpy.context.view_layer.objects.active=coat
        modifier=coat.modifiers.new('Unpainted fixed tin footprint','BOOLEAN');modifier.operation='DIFFERENCE';modifier.solver='EXACT';modifier.object=mask
        bpy.ops.object.modifier_apply(modifier=modifier.name);bpy.data.objects.remove(mask,do_unlink=True)
    bpy.ops.object.select_all(action='DESELECT');coat.select_set(True);bpy.context.view_layer.objects.active=coat
    bpy.context.scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    for collection in list(coat.users_collection):collection.objects.unlink(coat)
    native.objects.link(coat)
    bm=bmesh.new();bm.from_mesh(coat.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bad=sum(not edge.is_manifold for edge in bm.edges);volume=bm.calc_volume(signed=True)
    assert bad==0 and volume>0,(key,bad,volume)
    bm.to_mesh(coat.data);bm.free()
    sources[key]=coat;draws[key]=partition(exports,key,[coat],spec,mat,Matrix.Identity(4),catalog)
    proofs[key]=dict(nonmanifold_edges=bad,volume_m3=volume,original_node=plan['source'],original_origin_m=plan['origin'])
names=['F007','F008','F009','F010','F011','F012','F013','F062']
with bpy.data.libraries.load(str(ROOT/'art/blender/fire_service.blend'),link=False) as (_,loaded):loaded.objects=names.copy()
steel=dict(zip(names,loaded.objects));assert all(steel.values())
steel_frames={key:frame(at) for key,at in {
 'F007':(0,.390,.009),'F008':(-.299,.390,.110),'F009':(.299,.390,.110),'F010':(0,.769,.110),'F011':(0,.011,.110),
 'F012':(-.283,.390,.108),'F013':(.283,.390,.108),'F062':(.245,.033,.150)}.items()}
paint={key:tree(sources[key],frames[key]) for key in plans};contacts=0
assert not paint['FloorEnamel'].overlap(tree(steel['F062'],steel_frames['F062']))
for key,coordinate,axis in [('FloorEnamel',.022025,(0,-1,0)),('LeftEnamel',-.287975,(-1,0,0)),('RightEnamel',.287975,(1,0,0)),('TopEnamel',.757975,(0,1,0))]:
    metal=tree(steel[plans[key]['steel']],steel_frames[plans[key]['steel']]);count=0
    for i in range(8):
        for z in [.03,.08,.13,.18]:
            at=b(coordinate,.045+i*.69/7,z) if key in ['LeftEnamel','RightEnamel'] else b(-.26+i*.52/7,coordinate,z)
            a=paint[key].ray_cast(at,b(*axis),.001)[0];c=metal.ray_cast(at,b(*axis),.001)[0]
            assert a is not None and c is not None and (a-c).length<.0001,(key,i,z,a,c)
            count+=1
    proofs[key]['steel_bearing_rays']=count;contacts+=count
assert paint['FloorEnamel'].ray_cast(b(.245,.023,.150),b(0,-1,0),.003)[0] is None
with bpy.data.libraries.load(str(ROOT/'art/blender/fire_nozzle_hose.blend'),link=False) as (_,loaded):loaded.objects=['HoseTail00','HoseTail10']
tails=loaded.objects;assert all(tails)
tail_clearances={}
for tail in tails:
    own=tree(tail,tail.matrix_world)
    for key,coating in paint.items():assert not own.overlap(coating),(tail.name,key,'cloth/paint crossing')
    tail_clearances[tail.name]=min((tail.matrix_world@v.co).x for v in tail.data.vertices)+.28795
old_crossings=len(tree(tails[0],tails[0].matrix_world).overlap(tree(steel['F012'],steel_frames['F012'])))
assert old_crossings>0,'old left lining must expose observed cloth crossing'
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.render.threads_mode='FIXED';scene.render.threads=4
scene.render.resolution_x=1200;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Native case enamel review');scene.world.color=(.15,.15,.15)
for obj in sources.values():obj.hide_render=True
rows=[(draws[key],frames[key],'Lining') for key in plans]
rows += [(steel[key],steel_frames[key],'Lining' if key=='F007' else ('Brass' if key=='F062' else 'Paint')) for key in ['F007','F008','F009','F010','F011','F062']]
rows += [(tails[0],tails[0].matrix_world,'Linen')]
preview=[]
for source,at,key in rows:
    obj=source.copy();obj.data=source.data.copy();obj.matrix_world=at;bpy.context.collection.objects.link(obj);obj.hide_render=False
    obj.data.materials.clear();obj.data.materials.append(material(ROOT,key,finish(key),catalog));preview.append(obj)
for at,power in [((.2,.65,.70),35),((-.4,.40,.50),20)]:
    bpy.ops.object.light_add(type='AREA',location=b(*at));light=bpy.context.object;light.data.energy=power;light.data.size=.6
    light.rotation_euler=(b(0,.35,.1)-light.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=b(.50,.60,1.20));scene.camera=bpy.context.object;scene.camera.data.lens=55;scene.camera.data.clip_start=.001
scene.camera.rotation_euler=(b(0,.37,.1)-scene.camera.location).to_track_quat('-Z','Y').to_euler()
scene.render.filepath=str(OUT/'floor_enamel_assembled.png');bpy.ops.render.render(write_still=True)
for obj,offset in zip(preview[:4],[(0,.02,0),(.02,0,0),(-.02,0,0),(0,-.02,0)]):obj.location+=b(*offset)
scene.render.filepath=str(OUT/'floor_enamel_layer.png');bpy.ops.render.render(write_still=True)
for obj in preview:bpy.data.objects.remove(obj,do_unlink=True)
for obj in draws.values():obj.hide_render=False
result=export(OUT,'fire_floor_enamel',exports,material_names_only=True)
glb=OUT/'game/assets/props/fire_floor_enamel.glb';validate(glb)
paths=[Path(__file__).resolve(),ROOT/'art/blender/fire_service.blend',ROOT/'art/blender/fire_nozzle_hose.blend',ROOT/'game/data/orison_v2/fire_service.json',ROOT/'game/data/runtime_material_sets.json']
paths += [ROOT/'art/blender/scripts'/name for name in ['fabrication_native_batch.py','fabrication_chart_batch.py','fabrication_normals.py']]
bindings={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n') if p.suffix in ['.py','.json'] else p.read_bytes()).hexdigest() for p in paths}
report=dict(evidence_class='INERT',scope='Four native50um cosmetic coatings on retained steel; no runtime, manufacturing-standard or human acceptance. Original source origins and single structural collision retained.',source_bindings=bindings,thickness_m=.00005,parts=proofs,bearing_rays=contacts,tin_footprint_clear=True,old_left_lining_cloth_intersection_pairs=old_crossings,new_coatings_cloth_intersection_pairs=0,tail_left_clearances_m=tail_clearances,export=result,outputs={p.relative_to(OUT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in [glb,OUT/'art/blender/fire_floor_enamel.blend']})
(OUT/'construction.json').write_text(json.dumps(report,indent=2)+'\n')
print('FIRE CASE ENAMEL NATIVE PASS',json.dumps(report))
