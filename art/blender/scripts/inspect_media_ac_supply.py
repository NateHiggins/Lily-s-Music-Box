"""Measured AC lead clearance and clip contact against native table stock."""
from pathlib import Path
import json,math,os,sys
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'tmp/v2-media-ac-20261012/review';OUT.mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(Path(__file__).parent))
from fabrication_native_batch import material
def read(path):return json.loads((ROOT/path).read_text(encoding='utf-8'))
def bp(p):return Vector((p[0],-p[2],p[1]))
def append(file,predicate):
    with bpy.data.libraries.load(str(ROOT/'art/blender'/file),link=False) as (src,dst):dst.objects=[n for n in src.objects if predicate(n)]
    for obj in dst.objects:bpy.context.scene.collection.objects.link(obj)
    return dst.objects
def tree(obj):return BVHTree.FromPolygons([obj.matrix_world@v.co for v in obj.data.vertices],[list(p.vertices) for p in obj.data.polygons])
plan=read('art/data/media_ac_supply/source_plan.json')
routes={r['id']:r for r in read('tmp/v2-media-ac-20261012/construction.json')['routes']}
variants={r['id']:r['variant'] for r in read('game/data/orison_v2/domestic_tables.json')['instances']}
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/media_ac_supply.blend'))
supplies=[o for o in bpy.context.scene.objects if o.type=='MESH']
tables=append('domestic_tables.blend',lambda n:any(n.startswith(v+'__') for v in set(variants[r['support']] for r in plan['installations'])))
outlets=append('task_lamp_supply.blend',lambda n:n=='SupplyOutlet')
assert len(outlets)==1
outlet=outlets[0]
bpy.context.view_layer.update()
results=[];failures=[]
for row in plan['installations']:
    chosen=[o for o in tables if o.name.startswith(variants[row['support']]+'__')]
    blockers=[(o.name,tree(o)) for o in chosen]
    route=routes[row['id']];points=[bp(p) for p in route['centerline']]
    nearest=1e9;crossings=[]
    for a,b in zip(points,points[1:]):
        count=max(2,math.ceil((b-a).length/.002))
        for i in range(count+1):
            p=a.lerp(b,i/count)
            for label,bvh in blockers:
                hit,normal,_,gap=bvh.find_nearest(p)
                if hit is None:continue
                nearest=min(nearest,gap)
                # Signed nearest-face distance catches stock interiors as well
                # as near-surface penetrations; table meshes are closed.
                if gap<route['radius']-.00004 or (p-hit).dot(normal)<-.00004:
                    crossings.append([label,list(p),gap])
    clip_x=row['entry'][0]
    hits=[b.ray_cast(bp([clip_x,.690,.200]),bp([0,1,0]),.02) for _,b in blockers]
    contact=any(p is not None and abs(p.z-.700)<.00003 and n.z<-.99 for p,n,_,_ in hits)
    outlet.location=bp(row['outlet']);bpy.context.view_layer.update()
    clashes=[label for label,bvh in blockers if tree(outlet).overlap(bvh)]
    if crossings or not contact or clashes:failures.append({'id':row['id'],'crossings':crossings[:8],'clip_contact':contact,'outlet_clashes':clashes})
    results.append({'id':row['id'],'minimum_clearance':nearest,'clip_contact':contact,'outlet_clashes':clashes,'crossing_samples':len(crossings)})
(OUT/'inspection.json').write_text(json.dumps({'evidence_class':'INERT','routes':results,'failures':failures,'scope':'Native table clearance, underside bearing and outlet clearance only; appliance bore and installed authority remain separate checks.'},indent=2)+'\n',encoding='utf-8',newline='\n')
assert not failures,failures
print('TEN AC ROUTES: native furniture clearance and clip bearing passed')
if os.environ.get('MEDIA_AC_RENDER','0')!='1':raise SystemExit(0)
catalog=read('game/data/runtime_material_sets.json')['materials']
mapped={}
for obj in supplies:
    key=obj.data.materials[0].name.split('.')[0]
    if key not in mapped:
        mapped[key]=material(ROOT,key,dict(catalog_key=key,tint=([.40,.32,.23,1] if key=='linen' else [1,1,1,1]),pigment=1,normal=.08,roughness=catalog[key]['roughness_multiplier']),catalog)
    obj.data.materials.clear();obj.data.materials.append(mapped[key])
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=16;scene.cycles.use_denoising=True
scene.render.resolution_x=1100;scene.render.resolution_y=950;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Neutral AC review');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[1].default_value=.6
bpy.ops.object.light_add(type='AREA',location=(.5,-1.5,1.7));light=bpy.context.object;light.data.energy=300;light.data.size=2
bpy.ops.object.camera_add();camera=bpy.context.object;scene.camera=camera;camera.data.lens=48;camera.data.clip_start=.001
for identity in ['DomesticRadio_2A','DomesticRadio_5B','2A_tv']:
    row=next(r for r in plan['installations'] if r['id']==identity)
    for obj in supplies:obj.hide_render=not obj.name.startswith(identity+'_')
    for obj in tables:obj.hide_render=not obj.name.startswith(variants[row['support']]+'__')
    outlet.location=bp(row['outlet'])
    target=bp([.03,.43,.12]);camera.location=target+Vector((.75,-1.3,.05));camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(OUT/(identity+'_underside.png'));bpy.ops.render.render(write_still=True)
