"""Reopen street, station and retained context; inspect physical supports."""
from pathlib import Path
import hashlib,json,math,os,sys
import bpy,bmesh
from mathutils import Matrix,Vector
from mathutils.bvhtree import BVHTree
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file());OUT=Path(os.environ['CITY_STREET_REVIEW']);OUT.mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(Path(__file__).parent))
from city_street_geometry import area,bounds,intersection,rectangle,grade_at

def read(p):return json.loads((ROOT/p).read_text())
def sha(p):
    raw=(ROOT/p).read_bytes();return hashlib.sha256(raw if Path(p).suffix in ['.blend','.glb'] else raw.replace(b'\r\n',b'\n')).hexdigest()
paths=['art/blender/city_streets.blend','art/blender/city_streets_construction.json','art/data/city_streets/source_plan.json','art/blender/city_transport.blend','art/blender/city_transport_construction.json','art/blender/scripts/review_city_streets.py','art/blender/scripts/city_street_geometry.py']
hashes={p:sha(p) for p in paths};meta=read(paths[1]);plan=read(paths[2]);station=read(paths[4]);checks=[];failures=[]
def check(ok,label,**detail):
    row=dict(passed=bool(ok),label=label,**detail);checks.append(row)
    if not ok:failures.append(row)
bpy.ops.wm.open_mainfile(filepath=str(ROOT/paths[0]))
for lod in range(2):
    source=bpy.data.collections['StreetClosed_LOD'+str(lod)];source.hide_render=True
    for obj in source.objects:
        bm=bmesh.new();bm.from_mesh(obj.data);check(all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>0,'closed native street stock',id=obj.name);bm.free()
    bpy.data.collections['StreetExports_LOD'+str(lod)].hide_render=bool(lod)
near=list(bpy.data.collections['StreetExports_LOD0'].objects)

def load(relative,names,label,transform=Matrix.Identity(4)):
    with bpy.data.libraries.load(str(ROOT/relative),link=False) as (available,loaded):
        assert set(names)<=set(available.objects),(relative,set(names)-set(available.objects));loaded.objects=names
    col=bpy.data.collections.new(label);bpy.context.scene.collection.children.link(col)
    saved={obj.name:obj.location.copy() for obj in loaded.objects}
    for obj in loaded.objects:col.objects.link(obj)
    bpy.context.view_layer.update()
    for obj in loaded.objects:
        assert obj.parent is None and (obj.matrix_world.translation-saved[obj.name]).length<1e-7,(relative,obj.name)
        obj.matrix_world=transform@obj.matrix_world;obj.hide_render=False;obj.hide_set(False)
    bpy.context.view_layer.update();hashes[relative]=sha(relative)
    return list(col.objects)
# The separately reopened station geometry review owns closed-stock/stair
# checks. Its actual saved export partitions supply this composed PBR/BVH view.
station_exports=load('art/blender/city_transport.blend',list(read('game/data/orison_v2/exterior/city_transport.json')['parts']),'StationExportsContext')
layout=read('game/data/orison_v2_blockout.json');door=next(r for r in layout['doors'] if r['id']=='F01_DOOR_06');frame=read('game/data/orison_v2/exterior/street_frame.json');shift=-(door['center'][1]+frame['source_threshold_z'])
root_to_city=Matrix.Translation((0,shift,0))@Matrix.Diagonal((-1,-1,1,1))
front=read('game/tests/fixtures/orison_front_pavement_construction.json')
front_objects=load('art/blender/front_pavement.blend',[r['id'] for r in front['parts']],'RetainedFrontPaving',root_to_city)
paving_path='game/tests/fixtures/orison_street_paving_details.json'
paving=read(paving_path);hashes[paving_path]=sha(paving_path)
opposite_objects=load('art/blender/street_paving_details.blend',[r['id'] for r in paving['parts'] if r['kind']=='panel'],'RetainedOppositePaving',Matrix.Translation((0,-float(frame['source_threshold_z']),0)))

def tree(objects):
    verts=[];faces=[];names=[]
    for obj in objects:
        n=len(verts);verts.extend(obj.matrix_world@v.co for v in obj.data.vertices);faces.extend(tuple(n+i for i in p.vertices) for p in obj.data.polygons);names.extend([obj.name]*len(obj.data.polygons))
    return BVHTree.FromPolygons(verts,faces),names
ground_objects=[o for o in near if o.name.endswith(('__road','__walk'))]+[o for o in station_exports if o.name.endswith('__paving')]+front_objects+opposite_objects
ground,names=tree(ground_objects);road,_=tree([o for o in near if o.name.endswith('__road')]);all_geometry,all_names=tree(near+station_exports)
curb_tree,curb_names=tree([o for o in near if o.name.endswith('__curb')])
provider_samples=0
for row in paving['contacts']:
    if not str(row['owner']).startswith('passage_pavement_slab_'):continue
    p=row['point'];at=Vector((p[0],-p[2]-float(frame['source_threshold_z']),p[1]))
    hit,n,index,d=ground.ray_cast(at+Vector((0,0,.03)),Vector((0,0,-1)),.06)
    check(hit is not None and abs(hit.z-at.z)<.00003 and n.z>.99 and names[index]==row['owner'],'retained native pavement owns its original bearing sample',id=row['id'],point=list(at),actual_owner=names[index] if hit is not None else None)
    provider_samples+=1
check(provider_samples>0,'nonempty independent retained pavement contact roster',samples=provider_samples)
physical_seen=set()
stoop_samples=0
for row in meta['stocks']:
    if row['lod']!=0 or row['finish'] not in ['curb','cap']:continue
    if row['physical_id'] in physical_seen:continue
    physical_seen.add(row['physical_id'])
    p=row['physical_polygon'];center=Vector((sum(x for x,y in p)/len(p),sum(y for x,y in p)/len(p),0))
    if row['physical_id'].startswith('Stoop_'):
        # These are level stair stocks using the registered limestone finish,
        # not grade-relative curb courses seated on paving slabs.
        center.z=row['top_m']
        hit,n,index,d=all_geometry.ray_cast(center+Vector((0,0,.03)),Vector((0,0,-1)),.06)
        check(hit is not None and abs(hit.z-center.z)<.0001 and n.z>.999 and all_names[index].endswith('__curb'),'actual level public stair tread or landing',id=row['id'],point=list(center),owner=all_names[index] if hit is not None else None)
        stoop_samples+=1
        continue
    # A stone can bridge the authored four-millimetre slab joints. Test
    # distributed actual bearing points, not its outside rectangular AABB.
    probes=[center]+[center.lerp(Vector((x,y,0)),.55) for x,y in p]
    hits=[]
    for at in probes:
        at.z=row['bottom_m']+grade_at(at.x,plan['grade_profile_m'])
        support_tree,support_names=(ground,names) if row['finish']=='curb' else (curb_tree,curb_names)
        hit,n,index,d=support_tree.ray_cast(at+Vector((0,0,.015)),Vector((0,0,-1)),.04)
        if hit is not None and abs(hit.z-at.z)<.0001 and n.z>.99:hits.append(support_names[index])
    check(len(hits)>=min(3,len(probes)),'actual buried curb or cap bearing',id=row['id'],supports=sorted(set(hits)),samples=len(probes),supported=len(hits))
check(stoop_samples==sum(int(r['stoop_risers']) for r in plan.get('public_footways',[])),'complete public stair tread and landing roster',samples=stoop_samples)
for x in [-85,-76,-60,-44,-24,24,40,60,80,100,112]:
    for y in [-22.0,-19.3,-17.0]:
        grade=grade_at(x,plan['grade_profile_m'])
        hit,n,index,d=road.ray_cast(Vector((x,y,grade+.03)),Vector((0,0,-1)),.2)
        check(hit is not None and abs(hit.z+.1-grade)<.0001 and n.z>.99,'actual graded main road surface',x=x,y=y)
for x in meta['topology']['junction_x']:
    for y in [-35,-30,-26,-12,-6,0,8,16,23]:
        for dx in [-1.5,1.5]:
            grade=grade_at(x+dx,plan['grade_profile_m'])
            hit,n,index,d=road.ray_cast(Vector((x+dx,y,grade+.03)),Vector((0,0,-1)),.2)
            check(hit is not None and abs(hit.z+.1-grade)<.0001,'retained traffic lane supported through graded junction',x=x+dx,y=y)
for rect in meta['topology']['islands']:
    a,b,c,d=rect
    overlap_area=sum(area(intersection(p,rectangle(rect))) for p in meta['topology']['road'])
    check(overlap_area<1e-8,'road does not cut through protected pier footprint',rect=rect,overlap_m2=overlap_area)
# Independent source reservation checks: the entire near street body must
# have no positive polygon overlap with the fixed road or retained slab masks.
for row in meta['stocks']:
    if row['lod']==0 and row['finish']=='walk':
        overlaps=sum(area(intersection(row['polygon'],rectangle(r))) for r in meta['retained_footprints'])
        check(overlaps<1e-7,'new sidewalk respects retained occupied/paving footprint',id=row['id'],overlap_m2=overlaps)
    if row['lod']==0 and row['physical_id'].startswith(('Road_','Walk_')):
        variation=row['surface_high_m']-row['surface_low_m']
        check(row['top_m']-row['bottom_m']>variation+.02,'native paving body bridges bounded soil-air clearance with embedment',id=row['id'],grade_variation_m=variation,body_depth_m=row['top_m']-row['bottom_m'])
(OUT/'native_geometry_checks.json').write_text(json.dumps(dict(evidence_class='INERT',source_hashes=hashes,checks=checks,failures=failures),indent=2)+'\n')
assert not failures,failures[:12]

elevation=read('game/tests/fixtures/orison_city_elevations.json');offsets={r['id']:Vector(r.get('assembly_translation_m',[0,0,0])) for r in read('art/data/city_elevations/source_plan.json')['buildings']}
context=load('art/blender/city_elevations.blend',[r['name'] for r in elevation['parts']],'RetainedCityContext')
for obj in context:
    key=next(k for k in offsets if obj.name.startswith(k+'__'));obj.matrix_world=Matrix.Translation(offsets[key])@obj.matrix_world
ground_context=os.environ.get('CITY_STREET_GROUND_CONTEXT')=='1'
if ground_context:
    from fabrication_native_batch import material
    catalog=read('game/data/runtime_material_sets.json')['materials']
    recipe=read('game/data/orison_v2/ground_finish.json')
    finishes={}
    for key in ['soil','asphalt','concrete']:
        finish=dict(catalog_key=key,tint=[1,1,1,1],pigment=1.,normal=.35,roughness=1.)
        if key=='asphalt':finish.update(recipe)
        finishes[key]=material(ROOT,'GroundContext_'+key,finish,catalog)
    ground=load('art/blender/orison_ground.blend',[r['id'] for r in read('game/tests/fixtures/orison_ground_construction.json')['parts']],'GroundContext',root_to_city)
    for obj in ground:
        obj.data.materials.clear();obj.data.materials.append(finishes['asphalt' if 'asphalt' in obj.name else 'soil'])
    foundations=load('art/blender/city_foundations.blend',[r['id'] for r in read('game/tests/fixtures/orison_city_foundations_construction.json')['parts']],'FoundationContext',root_to_city)
    for obj in foundations:obj.data.materials.clear();obj.data.materials.append(finishes['concrete'])
    load('art/blender/city_ground_apron.blend',[r['name'] for r in read('game/tests/fixtures/orison_city_ground_apron.json')['parts']],'OuterGroundContext',root_to_city)
    horizon=read('game/tests/fixtures/orison_city_horizon.json')
    for family in ['near','far']:
        load('art/blender/city_horizon_'+family+'.blend',[r['name'] for r in horizon['assets'][family]['parts']],'HorizonContext_'+family,root_to_city)
bpy.context.view_layer.update();scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=12
scene.render.resolution_x=1600;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('DiagnosticNativeWorld');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.55,.65,.8,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.7
sun=bpy.data.objects.new('DiagnosticSun',bpy.data.lights.new('DiagnosticSun','SUN'));scene.collection.objects.link(sun);sun.data.energy=3;sun.rotation_euler=(.45,-.35,-.7)
camera=bpy.data.objects.new('NativeStreetCamera',bpy.data.cameras.new('NativeStreetCamera'));scene.collection.objects.link(camera);scene.camera=camera;camera.data.lens=25
views=[('block_overview',(-115,-75,72),(10,-10,0)),('east_intersection',(60,-32,5.5),(72,-9,0)),('east_north_walk',(64.3,18,1.41),(65.5,-13,0)),('west_corner',(-63,-10,1.41),(-72,-25,0)),('curb_grazing',(-55,-16,0.45),(-65,-14.7,0))]
views += [('retained_arcade_east_seam',(26,-26,1.41),(19.5,-26,0))]
if ground_context:
    views += [('west_walk_end',(-98,-26.5,grade_at(-98,plan['grade_profile_m'])+1.41),(-83,-26.5,-.8)),
              ('retained_west_foundation',(-86,25,grade_at(-86,plan['grade_profile_m'])+1.41),(-86,31,-.2))]
for name,at,target in views:
    camera.location=at;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(OUT/(name+'.png'));bpy.ops.render.render(write_still=True)
bpy.data.collections['StreetExports_LOD0'].hide_render=True
bpy.data.collections['StreetExports_LOD1'].hide_render=False
far_views=[('replacement_overview',(-115,-75,72),(10,-10,0)),('replacement_curb',(-55,-16,.45),(-65,-14.7,0))]
for name,at,target in far_views:
    camera.location=at;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(OUT/(name+'.png'));bpy.ops.render.render(write_still=True)
for p,h in hashes.items():assert sha(p)==h,p
(OUT/'native_review.json').write_text(json.dumps(dict(evidence_class='INERT',scope='Actual reopened native near/replacement bodies and catalogue materials under diagnostic lighting; no runtime, historical survey, save, performance or artistic acceptance.',ground_and_horizon_context=ground_context,source_hashes=hashes,checks=len(checks),failures=failures,renders=[v[0]+'.png' for v in views+far_views]),indent=2)+'\n')
print('CITY STREETS NATIVE REVIEW:',len(checks),'checks;',len(failures),'failures')
