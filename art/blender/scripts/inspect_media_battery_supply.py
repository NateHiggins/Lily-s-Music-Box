"""Battery native fit and PBR review in source-owned furniture/cabinet frames."""
from pathlib import Path
import bpy,json,math,sys,os
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[3];OUT=ROOT/'tmp/v2-media-battery-20261012/review';OUT.mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(Path(__file__).parent))
from fabrication_native_batch import material
def read(p):return json.loads((ROOT/p).read_text(encoding='utf-8'))
def bp(p):return Vector((p[0],-p[2],p[1]))
def append(file,predicate):
    with bpy.data.libraries.load(str(ROOT/'art/blender'/file),link=False) as (src,dst):dst.objects=[n for n in src.objects if predicate(n)]
    for o in dst.objects:bpy.context.scene.collection.objects.link(o)
    return dst.objects
def tree(o):return BVHTree.FromPolygons([o.matrix_world@v.co for v in o.data.vertices],[list(p.vertices) for p in o.data.polygons])
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/media_battery_supply.blend'))
supplies={o.name:o for o in bpy.context.scene.objects if o.type=='MESH'}
plan=read('art/data/media_battery_supply/source_plan.json');data=read('game/data/orison_v2/media_battery_supply.json')
routes=read('tmp/v2-media-battery-20261012/construction.json')['routes']
tables=append('domestic_tables.blend',lambda n:n.startswith('TableRect07__'))
families={r['id']:r['parts'] for r in read('game/data/orison_v2/active_household_radios.json')['families']}
body=append('active_household_radios.blend',lambda n:any(n==p['name'] for r in plan['installations'] for p in families[r['family']]))
original={o.name:o.matrix_world.copy() for o in body};results=[];failures=[]
catalog=read('game/data/runtime_material_sets.json')['materials'];mapped={}
for o in list(supplies.values())+body:
    key=o.data.materials[0].name.split('.')[0]
    if key=='glassish':continue
    if key not in mapped:
        tint=[.40,.32,.23,1] if key=='linen' else [.53,.36,.17,1] if key=='paper' else [1,1,1,1]
        mapped[key]=material(ROOT,key,dict(catalog_key=key,tint=tint,pigment=1,normal=.08,roughness=catalog[key]['roughness_multiplier']),catalog)
    o.data.materials.clear();o.data.materials.append(mapped[key])
for row in plan['installations']:
    names={p['name'] for p in families[row['family']] if p['component'] not in ['Tuning','Tag','Repair'] and not (row['unit']=='3B' and p['component']=='Back')}
    selected=[]
    for o in body:
        o.hide_render=o.name not in names
        if o.hide_render:continue
        o.matrix_world=original[o.name].copy();o.location+=bp(row['position']);selected.append(o)
    chosen=[o for name,o in supplies.items() if name.startswith('Battery') or name.startswith(('Filament','Plate')) or name.startswith(row['id']+'_')]
    for o in supplies.values():o.hide_render=o not in chosen
    bpy.context.view_layer.update();blockers=[(o.name,tree(o)) for o in tables+selected]
    clashes=[];minimum=1e9
    for route in [r for r in routes if r['id']==row['id']]:
        points=[bp(p) for p in route['centerline']];distance=0
        for a,b in zip(points,points[1:]):
            count=max(2,math.ceil((b-a).length/.002))
            for i in range(count+1):
                p=a.lerp(b,i/count)
                for name,bvh in blockers:
                    hit,n,_,gap=bvh.find_nearest(p)
                    if hit is None:continue
                    minimum=min(minimum,gap)
                    if gap<route['radius']-.00004 or (p-hit).dot(n)<-.00004:clashes.append([name,list(p),gap])
            distance+=(b-a).length
    table_bvhs=[tree(o) for o in tables]
    pack_clashes=[o.name for o in chosen if not o.name.startswith(row['id']+'_') and any(tree(o).overlap(b) for b in table_bvhs)]
    x=row['position'][0];contact=any(hit is not None and abs(hit.z-.700)<.00003 and n.z<-.99 for hit,n,_,_ in [b.ray_cast(bp([x,.690,.206]),bp([0,1,0]),.02) for b in table_bvhs])
    if clashes or pack_clashes or not contact:failures.append({'id':row['id'],'crossings':clashes[:10],'pack_clashes':pack_clashes,'clip_contact':contact})
    results.append({'id':row['id'],'wire_crossings':len(clashes),'minimum_clearance':minimum,'pack_clashes':pack_clashes,'clip_contact':contact})
(OUT/'inspection.json').write_text(json.dumps({'evidence_class':'INERT','results':results,'failures':failures},indent=2)+'\n',encoding='utf-8',newline='\n')
assert not failures,failures
print('BATTERY FIT: eight cabinet/table/tray/clip installations pass')
if os.environ.get('BATTERY_RENDER','0')!='1':raise SystemExit(0)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=16;scene.cycles.use_denoising=True
scene.render.resolution_x=1100;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Battery review');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[1].default_value=.6
bpy.ops.object.light_add(type='AREA',location=(.5,-1.5,1.7));light=bpy.context.object;light.data.energy=400;light.data.size=2
bpy.ops.object.camera_add();camera=bpy.context.object;camera.data.lens=48;scene.camera=camera
bpy.ops.mesh.primitive_plane_add(size=4);floor=bpy.context.object
# Every source is fitted above; render four distinct cabinets and the shared pack.
for row in [r for r in plan['installations'] if r['unit'] in ['1D','2B','2C','6B']]:
    names={p['name'] for p in families[row['family']] if p['component'] not in ['Tuning','Tag','Repair']}
    for o in body:
        o.hide_render=o.name not in names
        if not o.hide_render:o.matrix_world=original[o.name].copy();o.location+=bp(row['position'])
    for name,o in supplies.items():o.hide_render=not (name.startswith(('Battery','Filament','Plate')) or name.startswith(row['id']+'_'))
    target=bp([0,.48,0]);camera.location=target+Vector((1.1,-1.65,.7));camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(OUT/(row['unit']+'_supply.png'));bpy.ops.render.render(write_still=True)
