"""Thin native enamel on the retained case floor; no authority or texture key.
The old ten-millimetre visual slab stood above the physical supporting steel.
Author a closed coating, with the fixed tin's paint-free bearing footprint.
"""
from pathlib import Path
import bpy,bmesh,json,math,hashlib,os,sys,shutil
from mathutils import Matrix,Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[3]
OUT=Path(os.environ.get('ORISON_FIRE_FLOOR_OUT',str(ROOT/'tmp/v2-fire-hand-20261019/floor_enamel_native1'))).resolve()
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
data=json.loads((ROOT/'game/data/orison_v2/fire_service.json').read_text())
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
def finish(key):
    s=next(x for x in data['materials'] if x['key']==key)
    return dict(catalog_key=s['catalog'],tint=s['tint'],pigment=1.,normal=s['normal'],roughness=s['roughness'],metallic=s['metallic'])
spec=finish('Lining');mat=material(ROOT,'Lining',spec,catalog)
native=bpy.data.collections.new('Editable case enamel');bpy.context.scene.collection.children.link(native)
exports=bpy.data.collections.new('FireFloorEnamel');bpy.context.scene.collection.children.link(exports)
bpy.ops.mesh.primitive_cube_add(size=1,location=b(0,-.004975,0))
coat=bpy.context.object;coat.name='FloorEnamel_Editable';coat.dimensions=(.566,.190,.00005)
bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
bpy.ops.mesh.primitive_cube_add(size=1,location=b(.245,-.00485,.042))
mask=bpy.context.object;mask.dimensions=(.0682,.0682,.004)
bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
bpy.context.view_layer.objects.active=coat
modifier=coat.modifiers.new('Unpainted fixed tin footprint','BOOLEAN');modifier.operation='DIFFERENCE';modifier.solver='EXACT';modifier.object=mask
bpy.ops.object.modifier_apply(modifier=modifier.name);bpy.data.objects.remove(mask,do_unlink=True)
bpy.ops.object.select_all(action='DESELECT');coat.select_set(True);bpy.context.view_layer.objects.active=coat
bpy.context.scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
for c in list(coat.users_collection):c.objects.unlink(coat)
native.objects.link(coat)
bm=bmesh.new();bm.from_mesh(coat.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
bad=sum(not e.is_manifold for e in bm.edges);volume=bm.calc_volume(signed=True);assert bad==0 and volume>0,(bad,volume)
bm.to_mesh(coat.data);bm.free()
draw=partition(exports,'FloorEnamel',[coat],spec,mat,Matrix.Identity(4),catalog)
with bpy.data.libraries.load(str(ROOT/'art/blender/fire_service.blend'),link=False) as (_,loaded):loaded.objects=['F011','F062']
steel,tin=loaded.objects;assert steel is not None and tin is not None
def tree(obj,frame):
    return BVHTree.FromPolygons([frame@v.co for v in obj.data.vertices],[list(p.vertices) for p in obj.data.polygons])
floor_at=Matrix.Translation(b(0,.027,.108));steel_at=Matrix.Translation(b(0,.011,.110));tin_at=Matrix.Translation(b(.245,.033,.150))
paint_tree,steel_tree,tin_tree=tree(coat,floor_at),tree(steel,steel_at),tree(tin,tin_at)
assert not paint_tree.overlap(tin_tree),'paint intrudes into retained fixed tin'
contacts=0
for i in range(8):
    for z in [.03,.08,.13,.18]:
        at=b(-.26+i*.46/7,.022025,z)
        a=paint_tree.ray_cast(at,b(0,-1,0),.001)[0];c=steel_tree.ray_cast(at,b(0,-1,0),.001)[0]
        assert a is not None and c is not None and (a-c).length<.0001,(i,z,a,c)
        contacts+=1
assert paint_tree.ray_cast(b(.245,.023,.150),b(0,-1,0),.003)[0] is None
assert steel_tree.ray_cast(b(.245,.023,.150),b(0,-1,0),.003)[0] is not None
top=paint_tree.ray_cast(b(0,.023,.1),b(0,-1,0),.003)[0]
assert top is not None and abs(top.z-.02205)<.000001
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.render.threads_mode='FIXED';scene.render.threads=4
scene.render.resolution_x=1200;scene.render.resolution_y=850;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Neutral enamel review');scene.world.color=(.15,.15,.15)
coat.hide_render=True
preview=[]
for source,frame,key in [(draw,floor_at,'Lining'),(steel,steel_at,'Paint'),(tin,tin_at,'Brass')]:
    obj=source.copy();obj.data=source.data.copy();obj.matrix_world=frame;bpy.context.collection.objects.link(obj)
    obj.data.materials.clear();obj.data.materials.append(material(ROOT,key,finish(key),catalog));preview.append(obj)
for at,power in [((.2,.40,.30),20),((-.35,.16,.20),10)]:
    bpy.ops.object.light_add(type='AREA',location=b(*at));light=bpy.context.object;light.data.energy=power;light.data.size=.45;light.rotation_euler=(b(0,.025,.1)-light.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=b(.65,.45,.55));scene.camera=bpy.context.object;scene.camera.data.lens=55;scene.camera.data.clip_start=.001
scene.camera.rotation_euler=(b(.02,.025,.1)-scene.camera.location).to_track_quat('-Z','Y').to_euler()
scene.render.filepath=str(OUT/'floor_enamel_assembled.png');bpy.ops.render.render(write_still=True)
preview[0].location.z+=.02;scene.render.filepath=str(OUT/'floor_enamel_layer.png');bpy.ops.render.render(write_still=True)
for obj in preview:bpy.data.objects.remove(obj,do_unlink=True)
draw.hide_render=False
result=export(OUT,'fire_floor_enamel',exports,material_names_only=True)
glb=OUT/'game/assets/props/fire_floor_enamel.glb';validate(glb)
paths=[Path(__file__).resolve(),ROOT/'art/blender/fire_service.blend',ROOT/'game/data/orison_v2/fire_service.json',ROOT/'game/data/runtime_material_sets.json']
paths += [ROOT/'art/blender/scripts'/name for name in ['fabrication_native_batch.py','fabrication_chart_batch.py','fabrication_normals.py']]
bindings={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n') if p.suffix in ['.py','.json'] else p.read_bytes()).hexdigest() for p in paths}
report=dict(evidence_class='INERT',scope='Native enamel refit, no runtime or human acceptance. Engineered 50um cosmetic coating on retained structural collision, within100um contact tolerance; no manufacturing standard claim.',source_bindings=bindings,thickness_m=.00005,nonmanifold_edges=bad,volume_m3=volume,bearing_rays=contacts,tin_footprint_clear=True,export=result,outputs={p.relative_to(OUT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in [glb,OUT/'art/blender/fire_floor_enamel.blend']})
(OUT/'construction.json').write_text(json.dumps(report,indent=2)+'\n')
print('FIRE FLOOR ENAMEL NATIVE PASS',json.dumps(report))
