"""Reopen a source-owned district, both replacement bodies and actual soil.

CITY_STREET_REVIEW is the output directory; CITY_STREET_DISTRICT defaults to
Western. CPU native diagnostic only. No runtime or artistic acceptance.
"""
from pathlib import Path
import hashlib,json,os,sys
import bpy,bmesh,numpy as np
from mathutils import Matrix,Vector
from mathutils.bvhtree import BVHTree
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
OUT=Path(os.environ['CITY_STREET_REVIEW']);OUT.mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(Path(__file__).parent))
from city_street_geometry import grade_at
from fabrication_native_batch import material
def read(rel):return json.loads((ROOT/rel).read_bytes())
hashes={};checks=[];failures=[]
def bind(rel):
    raw=(ROOT/rel).read_bytes();hashes[rel]=hashlib.sha256(raw if rel.endswith(('.blend','.glb')) else raw.replace(b'\r\n',b'\n')).hexdigest()
    return ROOT/rel
def check(ok,label,**details):
    row=dict(passed=bool(ok),label=label,**details);checks.append(row)
    if not ok:failures.append(row)
plan=read('art/data/city_streets/source_plan.json');meta=read('art/blender/city_streets_construction.json')
identity=os.environ.get('CITY_STREET_DISTRICT','Western')
district=next(d for d in plan['districts'] if d['id']==identity)
for rel in ['art/data/city_streets/source_plan.json','art/blender/city_streets_construction.json','art/blender/scripts/review_city_street_district.py','art/blender/scripts/city_street_geometry.py','game/data/runtime_material_sets.json']:bind(rel)
bpy.ops.wm.read_factory_settings(use_empty=True)
def load(rel,names,label,transform=Matrix.Identity(4)):
    bind(rel)
    with bpy.data.libraries.load(str(ROOT/rel),link=False) as (available,loaded):
        assert set(names)<=set(available.objects),(rel,set(names)-set(available.objects))
        loaded.objects=list(names)
    col=bpy.data.collections.new(label);bpy.context.scene.collection.children.link(col)
    for obj in loaded.objects:col.objects.link(obj)
    bpy.context.view_layer.update()
    for obj in loaded.objects:
        assert obj.parent is None,(rel,obj.name)
        obj.matrix_world=transform@obj.matrix_world;obj.hide_render=False;obj.hide_set(False)
    bpy.context.view_layer.update()
    return loaded.objects
with bpy.data.libraries.load(str(bind('art/blender/city_streets.blend')),link=False) as (a,b):
    b.collections=['StreetClosed_LOD0','StreetClosed_LOD1','StreetExports_LOD0','StreetExports_LOD1']
for col in b.collections:
    bpy.context.scene.collection.children.link(col);col.hide_viewport=False
bpy.context.view_layer.update()
bodies=[]
for lod in range(2):
    closed=bpy.data.collections['StreetClosed_LOD'+str(lod)];closed.hide_render=True
    stocks=[o for o in closed.objects if '_'+identity+'_' in o.name]
    check(bool(stocks),'nonempty district closed-stock roster',lod=lod,stocks=len(stocks))
    for obj in stocks:
        bm=bmesh.new();bm.from_mesh(obj.data)
        check(all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>0,'closed positive native stock',id=obj.name,lod=lod)
        bm.free()
    col=bpy.data.collections['StreetExports_LOD'+str(lod)];col.hide_render=bool(lod)
    bodies.append(list(col.objects))
layout=read('game/data/orison_v2_blockout.json');frame=read('game/data/orison_v2/exterior/street_frame.json')
shift=-(next(d for d in layout['doors'] if d['id']=='F01_DOOR_06')['center'][1]+frame['source_threshold_z'])
root_to_city=Matrix.Translation((0,shift,0))@Matrix.Diagonal((-1,-1,1,1))
catalog=read('game/data/runtime_material_sets.json')['materials']
ground_meta=read('art/blender/orison_ground_construction.json')
soil=load('art/blender/orison_ground.blend',[r['id'] for r in ground_meta['parts']],'RetainedSoil',root_to_city)
ground_mats={key:material(ROOT,'ReviewGround_'+key,dict(catalog_key=key,tint=[1,1,1,1],pigment=1.,normal=.35,roughness=1.),catalog) for key in ['soil','asphalt','concrete']}
for obj,row in zip(soil,ground_meta['parts']):obj.data.materials.clear();obj.data.materials.append(ground_mats[row['material']])
apron=read('art/blender/city_ground_apron_construction.json')
soil+=load('art/blender/city_ground_apron.blend',[r['name'] for r in apron['parts']],'OuterSoil',root_to_city)
foundation=read('art/blender/city_foundations_construction.json')
found=load('art/blender/city_foundations.blend',[r['id'] for r in foundation['parts']],'FoundationContext',root_to_city)
for obj in found:obj.data.materials.clear();obj.data.materials.append(ground_mats['concrete'])
def tree(objects):
    verts=[];faces=[];names=[]
    for obj in objects:
        if obj.type!='MESH':continue
        offset=len(verts);verts.extend(obj.matrix_world@v.co for v in obj.data.vertices)
        faces.extend(tuple(offset+i for i in p.vertices) for p in obj.data.polygons);names.extend([obj.name]*len(obj.data.polygons))
    return BVHTree.FromPolygons(verts,faces),names
soil_tree,_=tree(soil)
for lod,objects in enumerate(bodies):
    paving,names=tree(objects)
    rows=[r for r in meta['stocks'] if r['lod']==lod and '_'+identity+'_' in r['physical_id'] and r['finish'] in ['road','walk']]
    check(bool(rows),'nonempty surface probe roster',lod=lod,samples=len(rows))
    for row in rows:
        p=row['polygon'];x=sum(v[0] for v in p)/len(p);y=sum(v[1] for v in p)/len(p)
        profile=district['road_profile_m'] if row['finish']=='road' else district.get('walk_profile_m')
        expected=row['top_m']+(grade_at(x,profile) if profile else 0.)
        at=Vector((x,y,expected+.04));hit,n,index,d=paving.ray_cast(at,Vector((0,0,-1)),.08)
        check(hit is not None and abs(hit.z-expected)<.0001 and n.z>.99,'native district surface in actual frame',lod=lod,id=row['id'],expected_z=expected,actual_z=hit.z if hit is not None else None)
        dirt,_,_,_=soil_tree.ray_cast(at,Vector((0,0,-1)),8.)
        check(dirt is not None and dirt.z<=expected+.0001,'actual soil does not bury paving',lod=lod,id=row['id'],surface_z=expected,soil_z=dirt.z if dirt is not None else None)
    # Off-site negative control confirms this query is not an invented floor.
    empty=paving.ray_cast(Vector((-460,-460,5)),Vector((0,0,-1)),20.)[0]
    check(empty is None,'off-site native negative control',lod=lod)
elev=read('game/tests/fixtures/orison_city_elevations.json')
placements={r['id']:Vector(r.get('assembly_translation_m',[0,0,0])) for r in read('art/data/city_elevations/source_plan.json')['buildings']}
context=load('art/blender/city_elevations.blend',[r['name'] for r in elev['parts']],'InstalledCityContext')
for obj in context:
    owner=next(k for k in placements if obj.name.startswith(k+'__'));obj.location+=placements[owner]
horizon=read('game/tests/fixtures/orison_city_horizon.json')
for native in sorted({a['native'] for a in horizon['assets'].values() if a['role']=='base'}):
    names=[r['name'] for a in horizon['assets'].values() if a['role']=='base' and a['native']==native for r in a['parts']]
    load(native,names,'HorizonContext',root_to_city)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=12
scene.render.resolution_x=1600;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('DiagnosticNativeWorld');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.55,.65,.8,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.7
sun=bpy.data.objects.new('DiagnosticSun',bpy.data.lights.new('DiagnosticSun','SUN'));scene.collection.objects.link(sun);sun.data.energy=3;sun.rotation_euler=(.45,-.35,-.7)
camera=bpy.data.objects.new('NativeDistrictCamera',bpy.data.cameras.new('NativeDistrictCamera'));scene.collection.objects.link(camera);scene.camera=camera;camera.data.lens=25
assert identity=='Western','Register actual-frame review views for another district'
views=[('western_overview',(-198,-173,122),(-120,-8,0)),('avenue_join',(-93,-10,.44),(-129,-12,-1.5)),('t_junction',(-134,-10,-.2),(-147,-25,-1.8)),('cambridge_footway',(-136.8,28,-.25),(-136.8,55,-.25)),('north_open_end',(-146,120,-.39),(-146,135,-1.8)),('south_open_end',(-146,-120,-.39),(-146,-135,-1.8))]
for label,at,target in views:
    camera.location=at;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(OUT/(label+'.png'));bpy.ops.render.render(write_still=True)
bpy.data.collections['StreetExports_LOD0'].hide_render=True;bpy.data.collections['StreetExports_LOD1'].hide_render=False
label,at,target=views[0];camera.location=at;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler()
scene.render.filepath=str(OUT/'western_lower_overview.png');bpy.ops.render.render(write_still=True)
for rel,h in hashes.items():
    raw=(ROOT/rel).read_bytes();assert hashlib.sha256(raw if rel.endswith(('.blend','.glb')) else raw.replace(b'\r\n',b'\n')).hexdigest()==h,rel
report=dict(evidence_class='INERT',scope='Reopened actual native near/lower street and soil support probes plus CPU catalogue renders; not runtime, uninterrupted player route, performance or artistic acceptance.',district=identity,checks=len(checks),failures=failures,source_hashes=hashes,views=[v[0]+'.png' for v in views]+['western_lower_overview.png'],detail=checks)
(OUT/'native_review.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
print('NATIVE DISTRICT REVIEW',len(checks),'checks',len(failures),'failures')
assert not failures,failures[:8]
