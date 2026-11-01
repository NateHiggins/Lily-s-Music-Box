"""Closed continuous road, sidewalk and curb bodies fitted to retained owners."""
from pathlib import Path
import collections,hashlib,json,math,sys
import bpy,bmesh
from mathutils import Vector,Matrix
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
sys.path.insert(0,str(Path(__file__).parent))
from city_street_geometry import area,bounds,rectangle,cut,intersection,triangles,topology,grade_at,district_topology
from fabrication_native_batch import material,partition,export
from check_exported_tangents import validate

def read(p):return json.loads((ROOT/p).read_text())
def sha(p):
    raw=(ROOT/p).read_bytes();return hashlib.sha256(raw if Path(p).suffix in ['.blend','.glb'] else raw.replace(b'\r\n',b'\n')).hexdigest()
plan_path='art/data/city_streets/source_plan.json';plan=read(plan_path)
assert plan['schema']=='orison.city-streets.v1' and plan['frame']=='CITY_ELEVATIONS_SOURCE'
traffic=read('game/data/orison_v2/exterior/street_traffic.json');frame=read('game/data/orison_v2/exterior/street_frame.json');transport=read('art/data/city_transport/source_plan.json')
shape=topology(plan,traffic,frame,transport)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
catalog=read('game/data/runtime_material_sets.json')['materials'];finishes=plan['finishes']
mats={k:material(ROOT,'Street_'+k,v,catalog) for k,v in finishes.items()}
closed=[];exports=[];groups=collections.defaultdict(list);records=[]
for lod in range(2):
    c=bpy.data.collections.new('StreetClosed_LOD'+str(lod));bpy.context.scene.collection.children.link(c);c.hide_render=True;closed.append(c)
    c=bpy.data.collections.new('StreetExports_LOD'+str(lod));bpy.context.scene.collection.children.link(c);exports.append(c)

# Existing full native slab envelopes remain authoritative, including joints.
# Current occupied F01 rooms and city footprints carve the added public strips.
retained=[plan['retained_front_walk_rect'],plan['retained_south_walk_rect']]
# The old curb ends at x20.8; the retained opposite pavement reaches x22.
# Read each physical provider independently so a coarse street/curb envelope
# cannot silently create another floor over an existing access authority.
provider_path='game/data/orison_v2/exterior/exterior_geometry.json'
provider_template=next(t for t in read(provider_path)['templates'] if t['id']=='TEMPLATE_STREET_SEGMENT_V1')
providers=[]
for row in provider_template['boxes']:
    x,y,z=row['position_m'];w,h,l=row['size_m']
    if not row.get('collision') or abs(y+h*.5)>1e-8:continue
    assert float(row['yaw_degrees'])==0 and min(w,h,l)>0,row['id']
    z+=float(frame['source_threshold_z'])
    rect=[x-w*.5,-z-l*.5,x+w*.5,-z+l*.5]
    retained.append(rect)
    providers.append(dict(id=row['id'],source_record=row,city_source_footprint=rect))
assert len(providers)==5 and {r['id'] for r in providers}=={'pavement_slab','passage_pavement_slab_west','passage_pavement_slab_east','passage_pavement_slab_street','passage_pavement_slab_arcade'}
for a,b in [transport['plaza']['y_ends_m'],transport['plaza']['south_y_ends_m']]:retained.append([transport['plaza']['x_ends_m'][0],a,transport['plaza']['x_ends_m'][1],b])
layout=read('game/data/orison_v2_blockout.json');door=next(r for r in layout['doors'] if r['id']=='F01_DOOR_06')
building_z=door['center'][1]+frame['source_threshold_z']
for room in layout['spaces']:
    if room['level']=='F01' and not room.get('open_shell') and not room.get('no_floor'):
        a,b,c,d=room['rect'];retained.append([-c,b-building_z,-a,d-building_z])
elevations=read('game/tests/fixtures/orison_city_elevations.json');offsets={r['id']:r.get('assembly_translation_m',[0,0,0]) for r in read('art/data/city_elevations/source_plan.json')['buildings']}
for row in elevations['buildings']:
    a,b,c,d=row['main_rect'];x,y,z=offsets[row['id']];retained.append([a+x,b+y,c+x,d+y])

def emit_stock(name,key,p,low,high,lod,physical_name,physical_polygon,graded=True,district=None,profile=None):
    assert high>low and area(p)>1e-10
    profile=plan['grade_profile_m'] if profile is None else profile
    n=len(p);verts=[(x,y,z+(grade_at(x,profile) if graded else 0.)) for z in [low,high] for x,y in p]
    faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    bm=bmesh.new();vv=[bm.verts.new(v) for v in verts]
    for face in faces:bm.faces.new([vv[i] for i in face])
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    assert all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>1e-10,name
    mesh=bpy.data.meshes.new(name);bm.to_mesh(mesh);bm.free();obj=bpy.data.objects.new(name,mesh);closed[lod].objects.link(obj)
    b=bounds(p);cell=math.floor((b[0]+b[2])*.5/plan['chunk_length_m'])
    group=(lod,cell,key)+((district,) if district else ())
    groups[group].append(obj)
    grade_low=min(grade_at(x,profile) for x,y in p) if graded else 0.;grade_high=max(grade_at(x,profile) for x,y in p) if graded else 0.
    records.append(dict(id=name,physical_id=physical_name,physical_polygon=physical_polygon,lod=lod,chunk=cell,finish=key,polygon=p,bottom_m=low,top_m=high,surface_low_m=high+grade_low,surface_high_m=high+grade_high,bounds=[b[0],b[1],low+grade_low,b[2],b[3],high+grade_high]))

def emit(name,key,p,low,high,lod,district=None,profile=None,graded=True):
    # Both replacement bodies use identical spatial chunk boundaries. A long
    # far curb must not collapse several near chunk identities into one part.
    a,b,c,d=bounds(p);pitch=plan['chunk_length_m']
    for cell in range(math.floor(a/pitch),math.ceil(c/pitch)):
        q=intersection(p,rectangle([cell*pitch,b,(cell+1)*pitch,d]))
        if not q:continue
        grade_profile=plan['grade_profile_m'] if profile is None else profile
        breaks=[max(a,cell*pitch)]+[x for x,h in grade_profile if max(a,cell*pitch)<x<min(c,(cell+1)*pitch)]+[min(c,(cell+1)*pitch)]
        for i,(left,right) in enumerate(zip(breaks,breaks[1:])):
            piece=intersection(q,rectangle([left,b,right,d]))
            if piece:emit_stock(name+'_C'+str(cell)+'_G'+str(i),key,piece,low,high,lod,name,p,graded=graded,district=district,profile=profile)

def cells(rect,pitch):
    a,b,c,d=rect;xs=[a]+[i*pitch for i in range(math.floor(a/pitch)+1,math.ceil(c/pitch))]+[c];ys=[b]+[i*pitch for i in range(math.floor(b/pitch)+1,math.ceil(d/pitch))]+[d]
    return [(x,y,X,Y) for x,X in zip(xs,xs[1:]) for y,Y in zip(ys,ys[1:])]

road_old=rectangle([-20.3,shape['south'],20.8,shape['north']])
walk_envelopes=[[plan['main_x_m'][0],shape['north'],plan['main_x_m'][1],plan['north_walk_edge_m']], [plan['main_x_m'][0],plan['south_walk_edge_m'],plan['main_x_m'][1],shape['south']]]
half=traffic['junctions']['cross_half_width'];width=plan['cross_walk_width_m']
for left,right in shape['cross_x_bounds']:
    for a,b in [(left-width,left),(right,right+width)]:
        walk_envelopes.extend([[a,plan['cross_south_end_m'],b,plan['south_walk_edge_m']],[a,plan['north_walk_edge_m'],b,plan['cross_north_end_m']]])
for lod in range(2):
    for i,p in enumerate(shape['road']):
        for j,q in enumerate(cut(p,[road_old])):emit(f'Road_L{lod}_{i}_{j}','road',q,plan['body_bottom_m'],traffic['site']['road_y'],lod)
    occupied=[rectangle(r) for r in retained]+shape['road']
    previous=[]
    for e,rect in enumerate(walk_envelopes):
        for i,cell in enumerate(cells(rect,plan['joint_pitch_m'] if not lod else 8.0)):
            # Fine joint opening only at the regular cell grid; replacement
            # bodies preserve the complete slab at distance.
            inset=plan['joint_m']/2 if not lod else 0.
            a,b,c,d=cell
            p=rectangle([a+(inset if a>rect[0]+1e-8 else 0),b+(inset if b>rect[1]+1e-8 else 0),c-(inset if c<rect[2]-1e-8 else 0),d-(inset if d<rect[3]-1e-8 else 0)])
            for j,q in enumerate(cut(p,occupied+previous)):
                emit(f'Walk_L{lod}_{e}_{i}_{j}','walk',q,plan['body_bottom_m'],plan['walk_top_m'],lod)
        previous.append(rectangle(rect))
    for role,polygons,key,low,high in [('Bed',shape['curbs'],'walk',plan['body_bottom_m'],plan['curb_buried_bottom_m']),('Curb',shape['curbs'],'curb',plan['curb_buried_bottom_m'],plan['curb_top_m']),('Cap',shape['curb_caps'],'cap',plan['curb_top_m'],plan['curb_cap_top_m'])]:
      for i,p in enumerate(polygons):
        a,b,c,d=bounds(p);axis=0 if c-a>d-b else 1;lo,hi=(a,c) if axis==0 else (b,d)
        cuts=[lo]+([v*plan['joint_pitch_m'] for v in range(math.floor(lo/plan['joint_pitch_m'])+1,math.ceil(hi/plan['joint_pitch_m']))] if not lod and hi-lo>plan['joint_pitch_m'] else [])+[hi]
        for j,(u,v) in enumerate(zip(cuts,cuts[1:])):
            gap=plan['joint_m']/2 if not lod else 0.
            u+=gap if j else 0;v-=gap if j<len(cuts)-2 else 0
            q=intersection(p,rectangle([u,b,v,d] if axis==0 else [a,u,c,v]))
            if not q:continue
            outside=cut(q,[rectangle(r) for r in retained]) if role in ['Bed','Curb'] else [q]
            for k,piece in enumerate(outside):emit(f'{role}_L{lod}_{i}_{j}_Outside{k}',key,piece,low,high,lod)
            if role=='Curb':
                # Existing retained slab is already the concrete bearing.
                # Do not add another bed or bury overlapping curb stock in it.
                for k,piece in enumerate(cut(q,outside)):
                    emit(f'{role}_L{lod}_{i}_{j}_Retained{k}',key,piece,plan['walk_top_m'],high,lod)

# Additions use distinct export groups: all pre-existing chunk arrays and
# indices remain untouched. Public paving is clipped against every retained
# owner and against the closed, level-tread stoop, never another hidden floor.
for footway in plan.get('public_footways',[]):
    identity=footway['id'];rects=footway['walk_rects_m']
    a,b,c,d=footway['stoop_rect_m'];risers=int(footway['stoop_risers'])
    landing=float(footway['stoop_landing_m']);top=float(footway['stoop_top_m'])
    assert identity.isalnum() and risers>=2 and 0.<landing<d-b
    tread=(d-b-landing)/(risers-1)
    assert tread>=.25 and c-a>=1.8
    start=grade_at((a+c)/2,plan['grade_profile_m'])
    rise=(top-start)/risers
    assert .10<=rise<=.18 and rise+abs(grade_at(a,plan['grade_profile_m'])-start)<=.20
    base=min(grade_at(x,plan['grade_profile_m']) for x in [a,c])+plan['body_bottom_m']
    stoop=rectangle([a,b,c,d])
    assert all(not intersection(stoop,rectangle(mask)) for mask in retained),'Stoop enters retained ownership'
    for lod in range(2):
        previous=[]
        masks=[rectangle(r) for r in retained]+shape['road']+[stoop]
        for j,rect in enumerate(rects):
            for i,cell in enumerate(cells(rect,plan['joint_pitch_m'] if not lod else 8.)):
                x,y,X,Y=cell;gap=plan['joint_m']/2 if not lod else 0.
                p=rectangle([x+(gap if x>rect[0]+1e-8 else 0.),y+(gap if y>rect[1]+1e-8 else 0.),X-(gap if X<rect[2]-1e-8 else 0.),Y-(gap if Y<rect[3]-1e-8 else 0.)])
                for k,q in enumerate(cut(p,masks+previous)):
                    emit(f'Walk_{identity}_L{lod}_{j}_{i}_{k}','walk',q,plan['body_bottom_m'],plan['walk_top_m'],lod,identity)
            previous.append(rectangle(rect))
        for step in range(risers):
            front=b+step*tread
            back=d if step==risers-1 else front+tread
            p=rectangle([a,front,c,back]);height=start+(step+1)*rise
            emit_stock(f'Stoop_{identity}_L{lod}_{step}','curb',p,base,height,lod,f'Stoop_{identity}_{step}',p,graded=False,district=identity)

district_records=[]
if plan.get('districts'):
    connection=read('game/data/orison_v2/world_connection.json')
    regions=read('game/data/orison_v2/exterior/regions.json')
    street_instance=next(r for r in regions['instances'] if r['id']==connection['instance_id'])
    threshold_surface=next(s for t in regions['surface_templates'] if t['id']==connection['template_id'] for s in t['surfaces'] if s['id']==connection['surface_id'])
    assert street_instance['offset_uvn_m']==[0,0,0] and street_instance['local_yaw_degrees']==0
    assert threshold_surface['point_m']==[0,0,0] and threshold_surface['normal']==[0,0,1] and door['center'][0]==0
for district in plan.get('districts',[]):
    identity=district['id'];assert identity.isalnum()
    def emit_district(name,key,p,low,high,lod,profile=None,graded=True):
        # New north/south streets get the same16m spatial bounds in both axes.
        # Legacy groups/arrays keep their original identities and construction.
        a,b,c,d=bounds(p);pitch=plan['chunk_length_m']
        for cell in range(math.floor(b/pitch),math.ceil(d/pitch)):
            piece=intersection(p,rectangle([a,cell*pitch,c,(cell+1)*pitch]))
            if piece:emit(name+'_Y'+str(cell),key,piece,low,high,lod,identity+'Y'+str(cell),profile,graded)
    for lod in range(2):
        result=district_topology(district,[12,8][lod],plan['curb_width_m'],plan['curb_cap_overhang_m'])
        assert result['maximum_curve_sagitta_m']<plan['lod_error_m']
        for i,p in enumerate(result['road']):
            for j,q in enumerate(cut(p,[rectangle(r) for r in retained]+shape['road'])):
                emit_district(f'Road_{identity}_L{lod}_{i}_{j}','road',q,district['road_bottom_m'],district['road_top_m'],lod,district['road_profile_m'])
        for role,polygons,key,low,high in [
            ('Curb',result['curbs'],'curb',district['curb_bottom_m'],district['curb_top_m']),
            ('Cap',result['curb_caps'],'cap',district['curb_top_m'],district['cap_top_m'])]:
            for i,p in enumerate(polygons):
                # Actual small construction joints disappear in replacement
                # bodies; every curb/cap course and rounded return remains.
                envelope=bounds(p)
                for j,cell in enumerate(cells(envelope,plan['joint_pitch_m'] if not lod else 8.)):
                    a,b,c,d=cell;gap=plan['joint_m']*.5 if not lod else 0.
                    gx=min(gap,(c-a)*.25);gy=min(gap,(d-b)*.25)
                    q=intersection(p,rectangle([a+(gx if a>envelope[0]+1e-8 else 0.),b+(gy if b>envelope[1]+1e-8 else 0.),c-(gx if c<envelope[2]-1e-8 else 0.),d-(gy if d<envelope[3]-1e-8 else 0.)]))
                    if not q:continue
                    for k,piece in enumerate(cut(q,[rectangle(r) for r in retained]+result['reserved'])):
                        emit_district(f'{role}_{identity}_L{lod}_{i}_{j}_{k}',key,piece,low,high,lod,district['curb_profile_m'])
        for i,p in enumerate(result['walk']):
            envelope=bounds(p)
            for j,cell in enumerate(cells(envelope,plan['joint_pitch_m'] if not lod else 8.)):
                a,b,c,d=cell;gap=plan['joint_m']*.5 if not lod else 0.
                gx=min(gap,(c-a)*.25);gy=min(gap,(d-b)*.25)
                q=intersection(p,rectangle([a+(gx if a>envelope[0]+1e-8 else 0.),b+(gy if b>envelope[1]+1e-8 else 0.),c-(gx if c<envelope[2]-1e-8 else 0.),d-(gy if d<envelope[3]-1e-8 else 0.)]))
                if not q:continue
                for k,piece in enumerate(cut(q,[rectangle(r) for r in retained])):
                    walk_profile=district.get('walk_profile_m')
                    emit_district(f'Walk_{identity}_L{lod}_{i}_{j}_{k}','walk',piece,district['walk_bottom_m'],district['walk_top_m'],lod,profile=walk_profile,graded=walk_profile is not None)
        district_records.append(dict(id=identity,lod=lod,curve_sagitta_m=result['maximum_curve_sagitta_m'],
            required_ground_cut_polygons=result['road']+result['curb_caps'],required_ground_cut_profile_m=district['ground_cut_profile_m'],
            required_ground_frame_cut_polygons=[[[-x,y+building_z] for x,y in p] for p in result['road']+result['curb_caps']],
            required_ground_frame_cut_profile_m=sorted([[-x,h] for x,h in district['ground_cut_profile_m']]),
            required_ground_cut_padding_m=plan['lod_error_m']+plan['joint_m'],
            ground_cut_implemented=False,reserved_rects_m=district['reserved_rects_m']))

provider_overlaps=[]
for row in records:
    if not row['id'].startswith('Walk_'):continue
    for provider in providers:
        overlap=intersection(row['polygon'],rectangle(provider['city_source_footprint']))
        if overlap and area(overlap)>1e-10:provider_overlaps.append([row['id'],provider['id'],area(overlap)])
assert not provider_overlaps,('New pavement overlaps retained physical floor authority',provider_overlaps)
assert {group[1:] for group in groups if group[0]==0}=={group[1:] for group in groups if group[0]==1},'Replacement material/chunk rosters must match'
for group,objects in groups.items():
    lod,cell,key=group[:3];district=group[3]+'_' if len(group)>3 else ''
    origin=Vector((cell*plan['chunk_length_m'],0,0))
    for obj in objects:
        for v in obj.data.vertices:v.co-=origin
        obj.location=origin
    partition(exports[lod],f'Street_{district}{cell}_L{lod}__{key}',objects,finishes[key],mats[key],Matrix.Translation(origin),catalog)
bpy.context.view_layer.update();proof0=export(ROOT,'city_streets',exports[0],staged_output=True)
bpy.ops.object.select_all(action='DESELECT')
for obj in exports[1].objects:obj.select_set(True)
low_path=ROOT/'game/assets/props/city_streets_lod1.glb'
bpy.ops.export_scene.gltf(filepath=str(low_path),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_attributes=True,export_materials='PLACEHOLDER')
proof1=validate(low_path);assert proof1['triangles']<proof0['triangles']
paths=[plan_path,provider_path,'art/blender/scripts/build_city_streets.py','art/blender/scripts/city_street_geometry.py','game/data/orison_v2/exterior/street_traffic.json','game/data/orison_v2/exterior/street_frame.json','art/data/city_transport/source_plan.json','game/data/orison_v2_blockout.json','game/tests/fixtures/orison_city_elevations.json','art/data/city_elevations/source_plan.json','game/data/runtime_material_sets.json','art/blender/city_streets.blend']+['art/blender/scripts/'+n for n in ['fabrication_native_batch.py','fabrication_chart_batch.py','fabrication_grain.py','fabrication_normals.py','check_exported_tangents.py']]
if district_records:
    paths += ['art/data/city_horizon/source_plan.json','art/blender/city_horizon_construction.json','art/blender/scripts/city_industrial_architecture.py','game/scripts/building/orison_v2_world_connection.gd','game/data/orison_v2/world_connection.json','game/data/orison_v2/exterior/regions.json']
report=dict(evidence_class='INERT',scope=plan['scope'],source_bindings={p:sha(p) for p in paths},asset_sha256={p:sha(p) for p in ['game/assets/props/city_streets.glb','game/assets/props/city_streets_lod1.glb']},exports=[proof0,proof1],stocks=records,topology=shape,retained_footprints=retained,retained_pavement_providers=providers,retained_provider_overlaps=provider_overlaps,walk_envelopes=walk_envelopes,districts=district_records,failures=[])
for p in ['art/blender/city_streets_construction.json','game/tests/fixtures/orison_city_streets.json']:(ROOT/p).write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
runtime=dict(schema=1,grade_profile_m=plan['grade_profile_m'],finishes=[dict(alias=k,**v) for k,v in finishes.items()],lod_error_m=plan['lod_error_m'],parts=[o.name for o in exports[0].objects])
(ROOT/'game/data/orison_v2/exterior/city_streets.json').write_text(json.dumps(runtime,indent=2)+'\n',encoding='utf-8',newline='\n')
print('CITY STREETS:',len(records),'closed stocks; triangles',proof0['triangles'],proof1['triangles'])
