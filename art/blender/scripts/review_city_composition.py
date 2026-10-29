"""Reopen the city composition; native checks and renders, no runtime acceptance."""
from pathlib import Path
import hashlib,json,os,sys
import bpy,bmesh,numpy as np
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
ROOT=Path(os.environ.get('CITY_COMPOSITION_ROOT',str(next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file()))))
OUT=Path(os.environ['CITY_COMPOSITION_REVIEW']);OUT.mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(ROOT/'art/blender/scripts'))
from fabrication_native_batch import material
plan=json.loads((ROOT/'art/data/city_elevations/source_plan.json').read_text())
placements={r['id']:Vector(r.get('assembly_translation_m',[0,0,0])) for r in plan['buildings']}
def owner(name):return next((k for k in placements if name==k or name.startswith(k+'_')),None)
layout=json.loads((ROOT/'game/data/orison_v2_blockout.json').read_text());frame=json.loads((ROOT/'game/data/orison_v2/exterior/street_frame.json').read_text())
delta=next(d for d in layout['doors'] if d['id']=='F01_DOOR_06')['center'][1]+frame['source_threshold_z']
registered=Matrix.Diagonal((-1.,-1.,1.,1.));registered.translation.y=-delta
bpy.ops.wm.read_factory_settings(use_empty=True)
objects=[];family_objects={};hashes={};foundation_sources=[]
def load_objects(path,names,transform=Matrix.Identity(4)):
    hashes[path.relative_to(ROOT).as_posix()]=hashlib.sha256(path.read_bytes()).hexdigest()
    with bpy.data.libraries.load(str(path),link=False) as (a,b):
        assert set(names)<=set(a.objects),str(path)
        b.objects=names
    for obj in b.objects:bpy.context.scene.collection.objects.link(obj)
    bpy.context.view_layer.update()
    for obj in b.objects:
        obj.matrix_world=transform@obj.matrix_world;obj.hide_render=False;obj.hide_set(False)
    return b.objects
for family in ['elevations','masts','aerials','tanks','beacons']:
    data=json.loads((ROOT/f'game/tests/fixtures/orison_city_{family}.json').read_text())
    draws=load_objects(ROOT/f'art/blender/city_{family}.blend',[r['name'] for r in data['parts']])
    for obj in draws:obj.location+=placements[owner(obj.name)]
    family_objects[family]=draws;objects.extend(draws)
frontage_meta=json.loads((ROOT/'art/blender/city_frontage_construction.json').read_text())
frontage_parts=load_objects(ROOT/'art/blender/city_frontage.blend',['WestNorthWorks__'+k for k in frontage_meta['finishes']])
# Retained source only: the owner's open-exploration direction unmounted this
# former street-end barricade. Keep its independent stock checks below, but do
# not render it or let it obstruct installed-composition rays.
for obj in frontage_parts:obj.hide_render=True
frontage_closed=load_objects(ROOT/'art/blender/city_frontage.blend',[r['id'] for r in frontage_meta['stocks']])
for obj in frontage_closed:
    bm=bmesh.new();bm.from_mesh(obj.data);assert all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>0,obj.name;bm.free();obj.hide_render=True
assert len(frontage_closed)==frontage_meta['closed_stocks'] and not frontage_meta['failures']
foundation=json.loads((ROOT/'art/blender/city_foundations_construction.json').read_text())
found=load_objects(ROOT/'art/blender/city_foundations.blend',[r['id'] for r in foundation['parts']],registered)
# Independent closed source stocks, retained separately from the open buried
# interfaces of the runtime export. Check actual manifold geometry and volume.
closed=load_objects(ROOT/'art/blender/city_foundations.blend',[r['owner']+'_ClosedUnion' for r in foundation['closed_volumes']],registered)
volumes=[]
for obj,row in zip(closed,foundation['closed_volumes']):
    bm=bmesh.new();bm.from_mesh(obj.data);volume=bm.calc_volume(signed=True)
    assert all(e.is_manifold for e in bm.edges) and volume>0,obj.name
    assert abs(volume-row['volume_m3'])<1e-7 and abs(volume-row['grid_volume_m3'])<.001,obj.name
    bm.free();volumes.append({'owner':row['owner'],'volume_m3':volume});obj.hide_render=True
objects.extend(found)
grade=json.loads((ROOT/'art/blender/orison_ground_construction.json').read_text())
ground=load_objects(ROOT/'art/blender/orison_ground.blend',[r['id'] for r in grade['parts']],registered)
objects.extend(ground)
transport_meta=json.loads((ROOT/'art/blender/city_transport_construction.json').read_text())
transport_runtime=json.loads((ROOT/'game/data/orison_v2/exterior/city_transport.json').read_text())
transport=load_objects(ROOT/'art/blender/city_transport.blend',transport_runtime['parts'])
objects.extend(transport)
hashes['game/data/orison_v2/exterior/construction_shed.json']=hashlib.sha256((ROOT/'game/data/orison_v2/exterior/construction_shed.json').read_bytes()).hexdigest()
with bpy.data.libraries.load(str(ROOT/'art/blender/construction_shed.blend'),link=False) as (available,unused):
    shed_names=[name for name in available.objects if name.startswith('Shed_')]
assert len(shed_names)==5,shed_names
shed_transform=Matrix.Identity(4);shed_transform.translation=Vector((22.25,-frame['source_threshold_z'],0))
shed=load_objects(ROOT/'art/blender/construction_shed.blend',shed_names,shed_transform)
objects.extend(shed)
# Include retained owners around the real entrance; their genuine cutouts in
# the new grade are not ground holes. Do not invent a proxy floor over them.
paving=json.loads((ROOT/'art/blender/front_pavement_construction.json').read_text())
front=load_objects(ROOT/'art/blender/front_pavement.blend',[r['id'] for r in paving['parts']],registered)
# The preserved masonry native stores pre-join components; use its actual
# installed, unmodified float32 export for retained context instead of guessing
# which intermediate native objects survive the final join.
context_path=ROOT/'game/assets/props/exterior_masonry.glb'
hashes[context_path.relative_to(ROOT).as_posix()]=hashlib.sha256(context_path.read_bytes()).hexdigest()
existing=set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(context_path))
context_objects=[o for o in bpy.data.objects if o not in existing]
for obj in context_objects:
    if obj.parent not in context_objects:obj.matrix_world=registered@obj.matrix_world
bpy.context.view_layer.update()
masonry=[o for o in context_objects if o.type=='MESH']
assert masonry

objects.extend(front+masonry)
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
recipe=json.loads((ROOT/'game/data/orison_v2/ground_finish.json').read_text())
finishes={'asphalt':dict(recipe,catalog_key='asphalt',pigment=1.),'soil':dict(catalog_key='soil',tint=[1,1,1,1],normal=.35,roughness=1.,pigment=1.),'brick':dict(catalog_key='brick',tint=[1,1,1,1],normal=.35,roughness=1.,pigment=1.),'concrete':dict(catalog_key='concrete',tint=[1,1,1,1],normal=.35,roughness=1.,pigment=1.)}
mats={k:material(ROOT,'Composition_'+k,v,catalog) for k,v in finishes.items()}
for obj,row in zip(ground,grade['parts']):obj.data.materials.clear();obj.data.materials.append(mats[row['material']])
for obj in found+front:obj.data.materials.clear();obj.data.materials.append(mats['concrete'])
for obj in masonry:
    obj.data.materials.clear();obj.data.materials.append(mats['brick'])
    for face in obj.data.polygons:face.material_index=0
bpy.context.view_layer.update()
def tree(draws):
    vs=[];fs=[];names=[]
    for obj in draws:
        offset=len(vs);vs.extend(obj.matrix_world@v.co for v in obj.data.vertices)
        fs.extend(tuple(offset+i for i in face.vertices) for face in obj.data.polygons);names.extend([obj.name]*len(obj.data.polygons))
    return BVHTree.FromPolygons(vs,fs),names
city_bvh,city_names=tree(family_objects['elevations']+shed);ground_bvh,_=tree(ground)
failures=[];bearings=0
for family in ['masts','aerials','tanks']:
    fixture=json.loads((ROOT/f'game/tests/fixtures/orison_city_{family}.json').read_text())
    for row in fixture['contacts']:
        move=placements[owner(row['id'])];normal=Vector(row['normal'])
        for sample in [row['point']]+row['footprint']:
            point=Vector(sample)+move;hit,n,index,distance=city_bvh.ray_cast(point+normal*.03,-normal,.06);bearings+=1
            if hit is None or (hit-point).length>=.0001:failures.append({'kind':'bearing','id':row['id'],'point':list(point)})
visibility=[]
for y in [-11.,-12.,-13.,-14.]:
    eye=Vector((0,y,1.41));target=Vector((-130,y,4));hit,n,index,distance=city_bvh.ray_cast(eye,(target-eye).normalized(),(target-eye).length)
    visibility.append({'eye':list(eye),'target':list(target),'clear':hit is None})
    if hit is not None:failures.append({'kind':'west_view','eye':list(eye),'hit':list(hit)})
filled=[]
for x,y in [(-20.6,-10),(-26.5,-10),(-35.2,-10),(-45.25,-10),(-56.25,-10),(-21,20),(-93,-1)]:
    hit,n,index,distance=ground_bvh.ray_cast(Vector((x,y,.3)),Vector((0,0,-1)),.6)
    ok=hit is not None and abs(hit.z+.02)<.0001;filled.append({'point':[x,y],'height':hit.z if hit is not None else None,'passed':ok})
    if not ok:failures.append({'kind':'vacated_grade','point':[x,y]})
surface,surface_names=tree(ground+transport)
for x,y in [(30,-4),(40,-4),(55,-4),(64,18),(87,-3)]:
    # Vacated eastern sites now have public paving at zero or grade at -20 mm.
    hit,n,index,distance=surface.ray_cast(Vector((x,y,.3)),Vector((0,0,-1)),.6)
    ok=hit is not None and -.0201<=hit.z<=.0001
    filled.append({'point':[x,y],'height':hit.z if hit is not None else None,'passed':ok})
    if not ok:failures.append({'kind':'eastern_public_grade','point':[x,y]})
# Buried interfaces are deliberately omitted from the render mesh. Query the
# actual constructed soil cells, rather than demanding an invisible contact face.
cells_path=ROOT/'tmp/orison-ground/orison-ground-cells.npz'
hashes[cells_path.relative_to(ROOT).as_posix()]=hashlib.sha256(cells_path.read_bytes()).hexdigest()
cells=np.load(cells_path);solid=cells['solid'];axes=[cells[k] for k in ['xs','ys','zs']]
inverse=registered.inverted();station_support=[]
for stock in transport_meta['stocks']:
    if stock['lod']!=0 or stock['role']!='footing':continue
    a,b,z,c,d,Z=stock['bounds']
    for u,v in [(.1,.1),(.1,.9),(.5,.5),(.9,.1),(.9,.9)]:
        native=Vector((a+(c-a)*u,b+(d-b)*v,z-.0001));local=inverse@native
        point=[local.x,local.z,-local.y]
        index=tuple(int(np.searchsorted(axis,p,side='right')-1) for axis,p in zip(axes,point))
        ok=all(0<=i<solid.shape[k] for k,i in enumerate(index)) and bool(solid[index])
        station_support.append({'id':stock['id'],'point':list(native),'soil_below':ok})
        if not ok:failures.append({'kind':'station_footing_soil','id':stock['id'],'point':list(native)})
(OUT/'geometry_checks.json').write_text(json.dumps(dict(evidence_class='INERT',failures=failures,station_support=station_support),indent=2)+'\n',encoding='utf-8',newline='\n')
assert not failures,failures[:12]
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=12
scene.render.resolution_x=1600;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('CompositionReview');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.55,.65,.8,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.7
sun=bpy.data.objects.new('ReviewSun',bpy.data.lights.new('ReviewSun','SUN'));scene.collection.objects.link(sun);sun.data.energy=3;sun.rotation_euler=(.45,-.35,-.7)
cam=bpy.data.objects.new('ReviewCamera',bpy.data.cameras.new('ReviewCamera'));scene.collection.objects.link(cam);scene.camera=cam;cam.data.lens=25
views=[('front_west',(0,-12.795,1.41),(-130,-12.795,4)),('row_grazing',(-13,-14,1.8),(-56,0,6)),('roof_west',(0,-11,21),(-100,18,12)),('new_pocket',(-47,55,9),(-55.6,35,7)),('new_cambridge',(-85,110,23),(-121,54,8)),('open_west_frontage',(-16,-12.1,1.5),(-35,-12.1,1.5)),('open_scaffold',(17,-12.795,1.41),(27,-12.795,1.8))]
views.extend([('plaza_east',(24,-12.8,1.41),(65,-10,11)),('public_entry_ground',(29,9,1.41),(36,5,4)),('platform_lower',(45,-20,12.79),(86,-20,12.38)),('east_factory',(94,6,1.41),(115,13,13))])
for label,eye,target in views:
    if label in ['new_pocket','new_cambridge']:
        start=Vector(eye);end=Vector(target);hit,n,index,distance=city_bvh.ray_cast(start,(end-start).normalized(),(end-start).length)
        expected='site_nbr_w__' if label=='new_pocket' else 'site_far_w__'
        assert hit is not None and city_names[index].startswith(expected),(label,city_names[index] if hit else None)
    cam.location=eye;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(OUT/(label+'.png'));bpy.ops.render.render(write_still=True)
for relative in ['art/data/city_elevations/source_plan.json','art/blender/city_foundations_construction.json','art/blender/orison_ground_construction.json','art/blender/city_frontage_construction.json','art/data/city_frontage/source_plan.json',Path(__file__).relative_to(ROOT).as_posix()]:
    hashes[relative]=hashlib.sha256((ROOT/relative).read_bytes()).hexdigest()
report={'evidence_class':'INERT','scope':'Reopened native composition, original hardware contacts, manifold foundations and filled vacated plots. No runtime, new playable lot, structural capacity, weather or artistic acceptance. Native previews use registered maps; runtime optical effects remain with the runtime.','source_hashes':hashes,'bearings':bearings,'frontage_closed_stocks':len(frontage_closed),'frontage_pavement_contacts':len(frontage_meta['pavement_contacts']),'frontage_carrier_contacts':frontage_meta['board_carrier_contacts'],'closed_foundations':volumes,'west_views':visibility,'vacated_grade':filled,'failures':failures,'renders':[v[0]+'.png' for v in views]}
for relative in ['art/blender/city_transport_construction.json','game/data/orison_v2/exterior/city_transport.json']:
    hashes[relative]=hashlib.sha256((ROOT/relative).read_bytes()).hexdigest()
report['station_footing_support']=station_support
(OUT/'native_review.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
for relative,digest in hashes.items():assert hashlib.sha256((ROOT/relative).read_bytes()).hexdigest()==digest,relative
print('CITY COMPOSITION NATIVE:',bearings,'bearings;',len(volumes),'closed foundations;',len(filled),'filled plots;',len(failures),'failures')
