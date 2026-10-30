"""Queensboro engineering-frame source study; no world or gameplay authority.

ORISON_BRIDGE_OUTPUT selects an external prototype root until intake. Native
high-water zero, authored profiles and final game siting are separate contracts.
"""
from pathlib import Path
import collections, copy, hashlib, json, math, os, sys
import bpy, bmesh
from mathutils import Matrix, Vector

ROOT = next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
binding_paths=[ROOT/p for p in ['art/data/city_bridge/source_plan.json','art/blender/scripts/build_city_bridge.py',
    'art/blender/scripts/fabrication_native_batch.py','art/blender/scripts/fabrication_chart_batch.py',
    'art/blender/scripts/fabrication_grain.py','art/blender/scripts/fabrication_normals.py',
    'art/blender/scripts/fabrication_uvs.py','art/blender/scripts/check_exported_tangents.py',
    'art/blender/scripts/city_ground_apron_geometry.py','art/data/city_ground_apron/source_plan.json',
    'art/blender/city_ground_apron_construction.json','game/data/runtime_material_sets.json']]
def digest(path):
    raw=path.read_bytes()
    return hashlib.sha256(raw if path.suffix.lower() in ['.png','.jpg','.webp','.glb','.blend'] else raw.replace(b'\r\n',b'\n')).hexdigest()
sources_before={p.relative_to(ROOT).as_posix():digest(p) for p in binding_paths}
sys.path.insert(0, str(ROOT/'art/blender/scripts'))
from fabrication_native_batch import material, partition, export
from check_exported_tangents import validate as validate_export
from city_ground_apron_geometry import relief_height, relief_stock, water_stock

OUT = Path(os.environ.get('ORISON_BRIDGE_OUTPUT', str(ROOT)))
for name in ['art/blender', 'game/assets/props']:(OUT/name).mkdir(parents=True, exist_ok=True)
PLAN = ROOT/'art/data/city_bridge/source_plan.json'
plan = json.loads(PLAN.read_text(encoding='utf-8')); authored = plan['authored']
assert plan['schema']=='orison.city-bridge.v1' and len(plan['spans_m'])==5
stations=[0.]
for length in plan['spans_m']:stations.append(stations[-1]+float(length))
assert abs(stations[-1]-1135.2276)<1e-6
length=stations[-1]; half=float(plan['truss_centres_m'])/2
placement=plan['placement'];azimuth=math.radians(placement['eastbound_azimuth_deg'])
heading=Vector((math.sin(azimuth),math.cos(azimuth),0.))
transverse=Vector((-heading.y,heading.x,0.))
queens=Vector((*placement['queens_abutment_xy_m'],0.));source_origin=queens-heading*length
ground_plan_path=ROOT/'art/data/city_ground_apron/source_plan.json'
ground_native_path=ROOT/'art/blender/city_ground_apron_construction.json'
ground_plan=json.loads(ground_plan_path.read_text(encoding='utf-8'))
ground_top=float(json.loads(ground_native_path.read_text(encoding='utf-8'))['boxes'][0]['bounds'][4])
backing_relief=copy.deepcopy(ground_plan['relief'])
backing_relief['west_profile']=[p for p in backing_relief['west_profile'] if p[0]<500.]+authored['island_west_profile']
# Dutch Kills remains in its installed region. It is not extended across the
# newly authored island/Manhattan land outside the old kilometre patch.
backing_relief['canal']['x_start']=1e6;backing_relief['canal']['bank_end_x']=1e6+10.
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version=0
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
for spec in plan['finishes'].values():
    for name in catalog[spec['catalog_key']]['files']:
        p=ROOT/'game/assets/building/textures'/name
        sources_before[p.relative_to(ROOT).as_posix()]=digest(p)
finishes=plan['finishes']; mats={k:material(ROOT,'Bridge_'+k,v,catalog) for k,v in finishes.items()}
closed=[];exports=[];stocks=collections.defaultdict(list);records=[];nodes={};members=[]
for lod in range(2):
    c=bpy.data.collections.new('ClosedBridge_LOD'+str(lod));bpy.context.scene.collection.children.link(c);c.hide_render=True;closed.append(c)
    c=bpy.data.collections.new('BridgeExports_LOD'+str(lod));bpy.context.scene.collection.children.link(c);exports.append(c)
LOD=0

def road(s):
    excess=max(0.,abs(s-length/2)-float(plan['central_level_length_m'])/2)
    return float(authored['road_mid_crown_m'])-excess*float(plan['end_grade'])

def approach_road(s):
    return road(length)-(s-length)*float(plan['end_grade'])

def source_to_native(point):
    x,y,z=point;offset=Vector((x,y,0.))-source_origin
    return Vector((offset.dot(heading),offset.dot(transverse),z-float(placement['water_scene_y_m'])))

def ground_at_native(point):
    source=source_origin+heading*point[0]+transverse*point[1]
    x,z=-source.x,source.y-float(placement['building_to_city_y_m'])
    relief=ground_plan['relief'] if -500.<=x<=500. and -500.<=z<=500. else backing_relief
    return relief_height(x,z,ground_top,relief)-float(placement['water_scene_y_m'])

def depth(s):
    for i,(a,b) in enumerate(zip(stations,stations[1:])):
        if s<=b+1e-7:
            t=max(0.,min(1.,(s-a)/(b-a))); tower=float(plan['tower_chord_depth_m'])
            if i==0:return float(authored['anchor_chord_depth_m'])+(tower-float(authored['anchor_chord_depth_m']))*t
            if i==4:return tower+(float(authored['anchor_chord_depth_m'])-tower)*t
            trough=float(authored['island_meeting_depth_m'] if i==2 else authored['channel_meeting_depth_m'])
            return trough+(tower-trough)*abs(2*t-1)**.8
    raise AssertionError(s)

def node(identity,point):
    point=Vector(point)
    if identity in nodes:assert (nodes[identity]-point).length<1e-7
    else:nodes[identity]=point
    return point

def stock(name,key,vertices,faces,role):
    bm=bmesh.new();vv=[bm.verts.new(v) for v in vertices]
    for face in faces:bm.faces.new([vv[i] for i in face])
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    assert all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>1e-10,(name,'closed positive stock')
    mesh=bpy.data.meshes.new(name);bm.to_mesh(mesh);bm.free()
    obj=bpy.data.objects.new(name,mesh);closed[LOD].objects.link(obj)
    bounds=[min(v[i] for v in vertices) for i in range(3)]+[max(v[i] for v in vertices) for i in range(3)]
    cell=math.floor((bounds[0]+bounds[3])*.5/float(authored['chunk_length_m']))
    stocks[(LOD,cell,key)].append(obj)
    records.append(dict(id=name,lod=LOD,finish=key,role=role,bounds=bounds,chunk=cell))
    return obj

def extrusion(name,key,a,b,profile,role):
    a=Vector(a);b=Vector(b);axis=(b-a).normalized()
    side=(Vector((0,0,1)) if abs(axis.z)<.98 else Vector((1,0,0))).cross(axis).normalized()
    up=axis.cross(side);n=len(profile)
    vv=[tuple(p+side*w+up*d) for p in [a,b] for w,d in profile]
    faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return stock(name,key,vv,faces,role)

def beam(name,a,b,width,thick,role='primary_web',key='painted_steel'):
    w=width/2;h=thick/2;p=min(.12,width*.45,thick*.45)
    profile=[(-w,-h),(w,-h),(w,-h+p),(p/2,-h+p),(p/2,h-p),(w,h-p),(w,h),(-w,h),(-w,h-p),(-p/2,h-p),(-p/2,-h+p),(-w,-h+p)] if LOD==0 and key=='painted_steel' else [(-w,-h),(w,-h),(w,h),(-w,h)]
    if isinstance(a,str) and isinstance(b,str):
        if LOD==0:members.append(dict(id=name,a=a,b=b,role=role))
        a,b=nodes[a],nodes[b]
    return extrusion(name,key,a,b,profile,role)

def box(name,key,lo,hi,role):
    x,y,z=lo;X,Y,Z=hi;assert X>x and Y>y and Z>z
    return stock(name,key,[(x,y,z),(X,y,z),(X,Y,z),(x,Y,z),(x,y,Z),(X,y,Z),(X,Y,Z),(x,Y,Z)],[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],role)

panel_stations=[0.]
for a,b in zip(stations,stations[1:]):
    count=math.ceil((b-a)/float(authored['panel_target_m']));count+=count%2
    panel_stations.extend(a+(b-a)*i/count for i in range(1,count+1))

def main_bridge():
    for j,s in enumerate(panel_stations):
        low=road(s)-2.
        for side,y in enumerate([-half,half]):
            node(f'B{side}_{j}',(s,y,low));node(f'T{side}_{j}',(s,y,low+depth(s)))
            beam(f'Vertical_{side}_{j}',f'B{side}_{j}',f'T{side}_{j}',.38,.58)
            for z,label in [(low,'Bottom'),(low+depth(s),'Top')]:
                for face in [-1,1]:
                    # Plates seat on the common120mm primary web. Selected
                    # through-bolts visibly explain the joint, not floating trim.
                    box(f'NodePlate_{side}_{j}_{label}_{face}','painted_steel',(s-.48,y+face*.095-.035,z-.72),(s+.48,y+face*.095+.035,z+.72),'gusset_connection')
                    for dx,dz in [(-.30,-.35),(.30,-.35),(-.30,.35),(.30,.35)]:
                        n=6 if LOD==0 else 4
                        profile=[(.035*math.cos(k*math.tau/n),.035*math.sin(k*math.tau/n)) for k in range(n)]
                        extrusion(f'NodeBolt_{side}_{j}_{label}_{face}_{dx}_{dz}','painted_steel',(s+dx,y+face*.13,z+dz),(s+dx,y+face*.155,z+dz),profile,'connection_head')
        beam(f'FloorBeam_{j}',(s,-half-3.95,road(s)-1.48),(s,half+3.95,road(s)-1.48),.40,2.0,'lower_floor_beam')
        rail=road(s)+float(plan['upper_base_rail_offset_m'])
        beam(f'UpperFloorBeam_{j}',(s,-half-3.95,rail-.945),(s,half+3.95,rail-.945),.32,1.05,'upper_floor_beam')
        if j==0:continue
        a=panel_stations[j-1];b=s
        for side in range(2):
            beam(f'LowerChord_{side}_{j}',f'B{side}_{j-1}',f'B{side}_{j}',.95,1.12,'lower_chord')
            beam(f'UpperChord_{side}_{j}',f'T{side}_{j-1}',f'T{side}_{j}',.95,1.12,'upper_chord')
            ends=(f'B{side}_{j-1}',f'T{side}_{j}') if j%2 else (f'T{side}_{j-1}',f'B{side}_{j}')
            beam(f'Diagonal_{side}_{j}',*ends,.42,.64)
        for high in [False,True]:
            prefix='T' if high else 'B'
            # At the low cantilever tips/anchor ends the top chord is below
            # an elevated car roof. Seat cross-bracing beneath the upper
            # floor there instead of drawing bars through its loading gauge.
            if high and min(depth(a),depth(b))<float(plan['upper_base_rail_offset_m'])+6.8:
                z=float(plan['upper_base_rail_offset_m'])-.8
                beam(f'LateralX_{high}_{j}_A',(a,-half,road(a)+z),(b,half,road(b)+z),.16,.20,'upper_deck_lateral_brace')
                beam(f'LateralX_{high}_{j}_B',(a,half,road(a)+z),(b,-half,road(b)+z),.16,.20,'upper_deck_lateral_brace')
            else:
                beam(f'LateralX_{high}_{j}_A',f'{prefix}0_{j-1}',f'{prefix}1_{j}',.16,.20,'lateral_brace')
                beam(f'LateralX_{high}_{j}_B',f'{prefix}1_{j-1}',f'{prefix}0_{j}',.16,.20,'lateral_brace')
        beam(f'Road_{j}',(a,0,road(a)-.09),(b,0,road(b)-.09),float(plan['road_width_m']),.18,'motor_road','paving')
        # Nominal deck/stringer/bearing datums explain the support chain;
        # final tilted-stock contacts still need the native seating review.
        for yy in [-7.,-3.5,0.,3.5,7.,-10.45,10.45]:
            beam(f'RoadStringer_{j}_{yy}',(a,yy,road(a)-.33),(b,yy,road(b)-.33),.20,.30,'deck_stringer')
        for yy in [-10.45,10.45]:
            beam(f'SurfaceCarDeck_{j}_{yy}',(a,yy,road(a)-.09),(b,yy,road(b)-.09),2.8,.18,'surface_car_deck','paving')
            for offset in [-float(plan['rail_gauge_m'])/2,float(plan['rail_gauge_m'])/2]:
                beam(f'TrolleyRail_{j}_{yy}_{offset}',(a,yy+offset,road(a)+.06),(b,yy+offset,road(b)+.06),.075,.12,'surface_car_rail','rail')
        for yy in [-3.,3.]:
            beam(f'UpperTrackBed_{j}_{yy}',(a,yy,road(a)+float(plan['upper_base_rail_offset_m'])-.12),(b,yy,road(b)+float(plan['upper_base_rail_offset_m'])-.12),2.7,.24,'track_bed','timber')
            for edge in [-1,1]:
                beam(f'TrackStringer_{j}_{yy}_{edge}',(a,yy+edge*.9,road(a)+float(plan['upper_base_rail_offset_m'])-.33),(b,yy+edge*.9,road(b)+float(plan['upper_base_rail_offset_m'])-.33),.20,.18,'track_stringer')
            for offset in [-float(plan['rail_gauge_m'])/2,float(plan['rail_gauge_m'])/2]:
                beam(f'ElevatedRail_{j}_{yy}_{offset}',(a,yy+offset,road(a)+float(plan['upper_base_rail_offset_m'])+.06),(b,yy+offset,road(b)+float(plan['upper_base_rail_offset_m'])+.06),.075,.12,'elevated_rail','rail')
        for yy in [-11.45,11.45]:
            beam(f'UpperWalk_{j}_{yy}',(a,yy,road(a)+float(plan['upper_base_rail_offset_m'])-.1),(b,yy,road(b)+float(plan['upper_base_rail_offset_m'])-.1),3.30,.20,'upper_walk','timber')
            for edge in [-1,1]:beam(f'WalkStringer_{j}_{yy}_{edge}',(a,yy+edge*1.35,road(a)+float(plan['upper_base_rail_offset_m'])-.31),(b,yy+edge*1.35,road(b)+float(plan['upper_base_rail_offset_m'])-.31),.18,.22,'walk_stringer')
            for edge in [-1,1]:beam(f'WalkRail_{j}_{yy}_{edge}',(a,yy+edge*1.56,road(a)+float(plan['upper_base_rail_offset_m'])+1.1),(b,yy+edge*1.56,road(b)+float(plan['upper_base_rail_offset_m'])+1.1),.07,.09,'walk_guard')
    for i,s in enumerate(stations):
        top=road(s)-2.58
        for side,y in enumerate([-half,half]):
            box(f'Pier_{i}_{side}','stone',(s-2.6,y-3.2,float(authored['pier_bottom_m'])),(s+2.6,y+3.2,top-.5),'masonry_pier')
            box(f'PierCap_{i}_{side}','stone',(s-2.95,y-3.55,top-.5),(s+2.95,y+3.55,top-.20),'pier_cap')
            box(f'Bearing_{i}_{side}','painted_steel',(s-1.1,y-1.1,top-.20),(s+1.1,y+1.1,top+.60),'chord_bearing')
        if i in [0,5]:continue
        peak=road(s)-2.+float(plan['tower_chord_depth_m'])
        for side,y in enumerate([-half,half]):
            beam(f'TowerLeg_{i}_{side}',(s,y,top),(s,y,peak),1.15,1.30,'tower_leg')
            # Tiered cornice and tapered lattice crown, guided by drawing4357.
            # Section sizes remain authored; no historical dimensional claim.
            for tier,width,z in [(0,2.1,peak+.25),(1,2.5,peak+.65),(2,2.8,peak+1.0)]:
                box(f'Capital_{i}_{side}_{tier}','painted_steel',(s-width/2,y-width/2,z-.12),(s+width/2,y+width/2,z+.12),'tower_capital')
            crown=peak+float(authored['crest_height_m'])
            for edge in [-1,1]:
                beam(f'PinnacleRail_{i}_{side}_{edge}',(s,y+edge*.65,peak+1.12),(s,y+edge*.17,crown),.10,.10,'tower_pinnacle')
            for row in range(4):
                z0=peak+1.12+(crown-peak-1.12)*row/4
                z1=peak+1.12+(crown-peak-1.12)*(row+1)/4
                w0=.65+(.17-.65)*row/4;w1=.65+(.17-.65)*(row+1)/4
                for edge in [-1,1]:beam(f'PinnacleLattice_{i}_{side}_{row}_{edge}',(s,y+edge*w0,z0),(s,y-edge*w1,z1),.055,.055,'tower_pinnacle_lattice')
            beam(f'PinnacleNeedle_{i}_{side}',(s,y,crown),(s,y,crown+4.),.065,.065,'tower_needle')
        for tier,(z,w,h) in enumerate([(peak-.35,.60,.95),(peak+.35,.85,.25),(peak+.7,1.05,.22)]):
            beam(f'TowerCrest_{i}_{tier}',(s,-half-.9,z),(s,half+.9,z),w,h,'tower_crest')
        clear=road(s)+float(plan['upper_base_rail_offset_m'])+5.0
        beam(f'TowerPortal_{i}',(s,-half,clear),(s,half,clear),.45,.85,'tower_portal')
        arch_base=peak-8.
        for j in range(12):
            y0=-half+2*half*j/12;y1=-half+2*half*(j+1)/12
            z0=arch_base+3.6*math.sqrt(max(0.,1-(y0/half)**2))
            z1=arch_base+3.6*math.sqrt(max(0.,1-(y1/half)**2))
            beam(f'UpperPortalArch_{i}_{j}',(s,y0,z0),(s,y1,z1),.32,.45,'upper_portal_arch')
        for row in range(4):
            z0=clear+(arch_base-clear)*row/4;z1=clear+(arch_base-clear)*(row+1)/4
            beam(f'TowerX_{i}_{row}_A',(s,-half,z0),(s,half,z1),.22,.30,'tower_portal_brace')
            beam(f'TowerX_{i}_{row}_B',(s,half,z0),(s,-half,z1),.22,.30,'tower_portal_brace')

def swept_slab(name,key,a,b,side_a,side_b,width,thickness,role):
    a,b,side_a,side_b=map(Vector,(a,b,side_a,side_b));up=Vector((0,0,thickness))
    corners=[a-side_a*width/2,a+side_a*width/2,b+side_b*width/2,b-side_b*width/2]
    stock(name,key,[tuple(p-up) for p in corners]+[tuple(p) for p in corners],
          [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],role)

def deck_span(name,a,b,side_a,side_b):
    a,b,side_a,side_b=map(Vector,(a,b,side_a,side_b));up=Vector((0,0,1))
    swept_slab(name+'_Road','paving',a,b,side_a,side_b,float(plan['road_width_m']),.18,'motor_road')
    for yy in [-7.,-3.5,0.,3.5,7.,-10.45,10.45]:
        beam(name+f'_Stringer_{yy}',a+side_a*yy-up*.33,b+side_b*yy-up*.33,.20,.30,'deck_stringer')
    for yy in [-10.45,10.45]:
        swept_slab(name+f'_TramDeck_{yy}','paving',a+side_a*yy,b+side_b*yy,side_a,side_b,2.8,.18,'surface_car_deck')
        for edge in [-1,1]:
            y=yy+edge*float(plan['rail_gauge_m'])/2
            beam(name+f'_TramRail_{yy}_{edge}',a+side_a*y+up*.06,b+side_b*y+up*.06,.075,.12,'surface_car_rail','rail')
    raised=float(plan['upper_base_rail_offset_m'])
    for yy in [-3.,3.]:
        swept_slab(name+f'_UpperBed_{yy}','timber',a+side_a*yy+up*raised,b+side_b*yy+up*raised,side_a,side_b,2.7,.24,'track_bed')
        for edge in [-1,1]:
            y=yy+edge*.9
            beam(name+f'_TrackStringer_{yy}_{edge}',a+side_a*y+up*(raised-.33),b+side_b*y+up*(raised-.33),.20,.18,'track_stringer')
            y=yy+edge*float(plan['rail_gauge_m'])/2
            beam(name+f'_Rail_{yy}_{edge}',a+side_a*y+up*(raised+.06),b+side_b*y+up*(raised+.06),.075,.12,'elevated_rail','rail')
    for yy in [-11.45,11.45]:
        swept_slab(name+f'_Walk_{yy}','timber',a+side_a*yy+up*raised,b+side_b*yy+up*raised,side_a,side_b,3.3,.2,'upper_walk')
        for edge in [-1,1]:
            y=yy+edge*1.35
            beam(name+f'_WalkStringer_{yy}_{edge}',a+side_a*y+up*(raised-.31),b+side_b*y+up*(raised-.31),.18,.22,'walk_stringer')
            y=yy+edge*1.56
            beam(name+f'_Guard_{yy}_{edge}',a+side_a*y+up*(raised+1.1),b+side_b*y+up*(raised+1.1),.07,.09,'walk_guard')

def floor_frame(name,center,side):
    center,side=map(Vector,(center,side));up=Vector((0,0,1))
    for z,w,h,role in [(-1.48,.40,2.,'lower_floor_beam'),(float(plan['upper_base_rail_offset_m'])-.945,.32,1.05,'upper_floor_beam')]:
        beam(name+role,center-side*(half+3.95)+up*z,center+side*(half+3.95)+up*z,w,h,role)

support_rows=[];approach_stations=[length]
for span in plan['approach_spans_m']:approach_stations.append(approach_stations[-1]+float(span))
assert abs(approach_stations[-1]-length-float(plan['approach_length_m']))<1e-7

def supported_bent(name,center,side):
    center,side=map(Vector,(center,side));up=Vector((0,0,1))
    for edge in [-1,1]:
        p=center+side*(edge*half);ground=ground_at_native(p)
        assert center.z-3.12>ground+1.,(name,'column too short')
        pad=Vector((p.x,p.y,ground))
        box(name+f'_Footing_{edge}','stone',pad-Vector((1.1,1.1,1.0)),pad+Vector((1.1,1.1,.2)),'approach_footing')
        box(name+f'_Base_{edge}','painted_steel',pad-Vector((.55,.55,-.2)),pad+Vector((.55,.55,.35)),'column_base')
        beam(name+f'_Column_{edge}',pad+up*.35,Vector((p.x,p.y,center.z-3.12)),float(authored['approach_column_width_m']),float(authored['approach_column_depth_m']),'approach_column')
        if LOD==0:support_rows.append(dict(id=name+f'_{edge}',native_xy=[p.x,p.y],ground_hwm_m=ground,footing_bottom_m=ground-1.,column_top_m=center.z-3.12))
    beam(name+'_Header',center-side*half-up*2.8,center+side*half-up*2.8,.65,.64,'support_header')
    for edge in [-1,1]:
        beam(name+f'_Knee_{edge}',center+side*(edge*half)-up*5.2,center+side*(edge*(half-2.4))-up*3.12,.24,.32,'support_knee')

def queens_approach():
    side=Vector((0,1,0));last=None;last_top=None;index=0
    for bay,(a,b) in enumerate(zip(approach_stations,approach_stations[1:])):
        count=math.ceil((b-a)/float(authored['approach_panel_target_m']))
        for k in range(count+1):
            if bay and k==0:continue
            s=a+(b-a)*k/count;center=Vector((s,0,approach_road(s)))
            top=float(authored['approach_chord_top_above_road_m'])
            top=7.+(top-7.)*min(1.,(s-length)/12.)
            if index:floor_frame(f'Approach_{index}_',center,side)
            for edge in [-1,1]:
                bottom=center+side*(edge*half)-Vector((0,0,2.));upper=center+side*(edge*half)+Vector((0,0,top))
                if index:beam(f'ApproachVertical_{index}_{edge}',bottom,upper,.25,.36,'approach_truss_vertical')
                if last is not None:
                    previous=last+side*(edge*half)-Vector((0,0,2.));previous_top=last+side*(edge*half)+Vector((0,0,last_top))
                    beam(f'ApproachLower_{index}_{edge}',previous,bottom,.55,.70,'approach_lower_chord')
                    beam(f'ApproachUpper_{index}_{edge}',previous_top,upper,.45,.60,'approach_upper_chord')
                    beam(f'ApproachWeb_{index}_{edge}',previous if index%2 else previous_top,upper if index%2 else bottom,.22,.32,'approach_web')
            if last is not None:deck_span(f'ApproachDeck_{index}',last,center,side,side)
            last=center;last_top=top;index+=1
    for j,s in enumerate(approach_stations[1:]):supported_bent(f'ApproachBent_{j}',(s,0,approach_road(s)),side)
    for bay in [3,7]:
        a,b=approach_stations[bay:bay+2]
        for edge in [-1,1]:
            y=edge*half;spring=min(ground_at_native((a,y,0)),ground_at_native((b,y,0)))+3.
            crown=min(approach_road(a),approach_road(b))-3.12
            for k in range(16):
                aa=a+(b-a)*k/16;bb=a+(b-a)*(k+1)/16
                def arch_z(s):return spring+(crown-spring)*math.sqrt(max(0.,1.-((2*s-a-b)/(b-a))**2))
                beam(f'StreetOpeningArch_{bay}_{edge}_{k}',(aa,y,arch_z(aa)),(bb,y,arch_z(bb)),.45,.6,'street_opening_arch')

def continuation():
    spec=authored['continuation_source_path'];p0=queens+heading*float(plan['approach_length_m'])
    p1=p0+heading*float(spec['first_control_distance_m']);p2=Vector((*spec['second_control_xy_m'],0.));p3=Vector((*spec['curve_end_xy_m'],0.));end=Vector((*spec['end_xy_m'],0.))
    curve=[]
    for k in range(31):
        t=k/30;point=(1-t)**3*p0+3*(1-t)**2*t*p1+3*(1-t)*t*t*p2+t**3*p3
        tangent=(3*(1-t)**2*(p1-p0)+6*(1-t)*t*(p2-p1)+3*t*t*(p3-p2)).normalized();curve.append((point,tangent))
    direction=(end-p3).normalized()
    for k in range(1,29):curve.append((p3+(end-p3)*k/28,direction))
    distances=[0.]
    for (a,_),(b,_) in zip(curve,curve[1:]):distances.append(distances[-1]+(b-a).length)
    extent=distances[-1];start_h=approach_road(approach_stations[-1]);end_h=ground_at_native(source_to_native((*end[:2],0.)))+.02
    previous=None;before_side=None;up=Vector((0,0,1))
    for k,((point,tangent),distance) in enumerate(zip(curve,distances)):
        t=distance/extent
        h=(2*t**3-3*t*t+1)*start_h+(t**3-2*t*t+t)*extent*(-float(plan['end_grade']))+(-2*t**3+3*t*t)*end_h
        center=source_to_native((point.x,point.y,h+float(placement['water_scene_y_m'])))
        native_tangent=Vector((tangent.dot(heading),tangent.dot(transverse),0.));side=Vector((-native_tangent.y,native_tangent.x,0.))
        floor_frame(f'Continuation_{k}_',center,side)
        if previous is not None:deck_span(f'ContinuationDeck_{k}',previous,center,before_side,side)
        low_road=center.z-3.12<=max(ground_at_native(center+side*half),ground_at_native(center-side*half))+1.
        if k:
            if not low_road and k%3==0:supported_bent(f'ContinuationBent_{k}',center,side)
            elif low_road:
                # The final low road is an actual solid fill, not stilts that
                # shrink through their bases as the road meets the ground.
                depth=max(1.,center.z-min(ground_at_native(center+side*half),ground_at_native(center-side*half)))
                swept_slab(f'ContinuationFill_{k}','stone',previous-up*.18,center-up*.18,before_side,side,float(plan['road_width_m']),depth,'approach_fill')
        # The two deck levels require an actual attachment chain throughout
        # the curve, including where the motor road reaches soil grade.
        raised=float(plan['upper_base_rail_offset_m'])
        for edge in [-1,1]:
            foot=center+side*(edge*half);bottom=foot-up*2.;top=foot+up*(raised-.42)
            beam(f'ContinuationRiser_{k}_{edge}',bottom,top,.30,.45,'continuation_riser')
            if low_road:
                g=ground_at_native(foot)
                box(f'ContinuationBase_{k}_{edge}','stone',(foot.x-.5,foot.y-.5,g-.5),(foot.x+.5,foot.y+.5,g+.1),'continuation_riser_base')
            if previous is not None:
                prior=previous+before_side*(edge*half)
                beam(f'ContinuationLowerChord_{k}_{edge}',prior-up*2.,bottom,.50,.70,'continuation_lower_chord')
                beam(f'ContinuationUpperChord_{k}_{edge}',prior+up*(raised-.42),top,.32,.45,'continuation_upper_chord')
                beam(f'ContinuationWeb_{k}_{edge}',prior-up*2. if k%2 else prior+up*(raised-.42),top if k%2 else bottom,.18,.24,'continuation_side_web')
        previous=center;before_side=side
    tangent=native_tangent
    # Explicit headshunt stops make the finite upper/surface-car track ends
    # intentional. They introduce no rail-service or interaction authority.
    for raised,centres,label in [(float(plan['upper_base_rail_offset_m']),[-3.,3.],'upper'),(0.,[-10.45,10.45],'surface')]:
        for yy in centres:
            cap=center+side*yy+up*(raised+1.0)
            beam(f'EndBuffer_{label}_{yy}',cap-side*1.15,cap+side*1.15,.22,.28,'rail_stop')
            for edge in [-1,1]:
                toe=center+side*(yy+edge*.85)-tangent*1.6+up*(raised-.24)
                beam(f'EndBufferBrace_{label}_{yy}_{edge}',toe,cap+side*(edge*.85),.15,.20,'rail_stop_brace')
    for yy in [-11.45,11.45]:
        cap=center+side*yy+up*(float(plan['upper_base_rail_offset_m'])+1.1)
        beam(f'EndWalkGuard_{yy}',cap-side*1.56,cap+side*1.56,.07,.09,'end_walk_guard')
    if LOD==0:plan['derived_continuation']={'length_m':extent,'road_start_hwm_m':start_h,'road_end_hwm_m':end_h,'source_end_xy':list(end[:2])}

def background_support():
    def convert(p):x,h,z=p;return source_to_native((-x,z+float(placement['building_to_city_y_m']),h))
    for j,(x,z,X,Z) in enumerate(authored['background_rects_building_m']):
        v,f,_=relief_stock([x,-10.,z,X,ground_top,Z],backing_relief)
        stock(f'BridgeBacking_{j}','soil',[convert(p) for p in v],f,'background_support')
        w,g=water_stock(v,f,float(placement['water_scene_y_m']))
        if g:stock(f'BridgeWater_{j}','water_clear',[convert(p) for p in w],g,'background_water')

for LOD in range(2):
    main_bridge();queens_approach();continuation();background_support()
assert {r['id'] for r in records if r['lod']==0}=={r['id'] for r in records if r['lod']==1}
for (lod,cell,key),objects in stocks.items():
    points=[v.co for obj in objects for v in obj.data.vertices]
    origin=Vector(((cell+.5)*float(authored['chunk_length_m']),0,(min(p.z for p in points)+max(p.z for p in points))*.5))
    for obj in objects:
        for vertex in obj.data.vertices:vertex.co-=origin
        obj.location=origin
    partition(exports[lod],f'Bridge_{cell}_L{lod}__{key}',objects,finishes[key],mats[key],Matrix.Translation(origin),catalog)
bpy.context.view_layer.update()
near=export(OUT,'city_bridge',exports[0],staged_output=True)
bpy.ops.object.select_all(action='DESELECT')
for obj in exports[1].objects:obj.select_set(True)
low_path=OUT/'game/assets/props/city_bridge_lod1.glb'
bpy.ops.export_scene.gltf(filepath=str(low_path),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_attributes=True,export_materials='PLACEHOLDER')
low=validate_export(low_path);assert low['triangles']<near['triangles']
for s in stations[1:-1]:assert abs(depth(s)-float(plan['tower_chord_depth_m']))<1e-6
report=dict(evidence_class='INERT',scope=plan['scope'],frame=plan['frame'],stations_m=stations,paired_truss_centres_m=2*half,tower_frames=4,piers=6,panel_count=len(panel_stations)-1,approach_stations_m=approach_stations,supports=support_rows,placement=placement,continuation=plan['derived_continuation'],background_rects_building_m=authored['background_rects_building_m'],stocks=records,nodes={k:list(v) for k,v in nodes.items()},members=members,exports=[near,low],failures=[],remaining=['native support/context optical review','roundtrip and loaded precision','actual roof/street/telescope sightlines','composed performance and acceptance'])
report['source_bindings']=sources_before
assert all(digest(ROOT/p)==h for p,h in sources_before.items()),'Bridge source changed during native construction'
(OUT/'art/blender/city_bridge_construction.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
part_names=[obj.name for obj in exports[0].objects]
projection=dict(schema=1,frame=plan['frame'],queens_source_xy_m=placement['queens_abutment_xy_m'],eastbound_azimuth_deg=placement['eastbound_azimuth_deg'],water_scene_y_m=placement['water_scene_y_m'],main_length_m=length,lod_error_m=.28,parts=part_names,finishes=[dict(alias=key,**value) for key,value in finishes.items()])
projected=OUT/'game/data/orison_v2/exterior/city_bridge.json';projected.parent.mkdir(parents=True,exist_ok=True);projected.write_text(json.dumps(projection,indent=2)+'\n',encoding='utf-8',newline='\n')
print('BRIDGE NATIVE:',len(records),'stocks;',near['triangles'],low['triangles'],'triangles; engineering-frame study only',flush=True)
