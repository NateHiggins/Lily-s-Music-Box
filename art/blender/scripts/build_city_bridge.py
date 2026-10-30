"""Queensboro engineering-frame source study; no world or gameplay authority.

ORISON_BRIDGE_OUTPUT selects an external prototype root until intake. Native
high-water zero, authored profiles and final game siting are separate contracts.
"""
from pathlib import Path
import collections, hashlib, json, math, os, sys
import bpy, bmesh
from mathutils import Matrix, Vector

ROOT = next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
sys.path.insert(0, str(ROOT/'art/blender/scripts'))
from fabrication_native_batch import material, partition, export
from check_exported_tangents import validate as validate_export

OUT = Path(os.environ.get('ORISON_BRIDGE_OUTPUT', str(ROOT)))
for name in ['art/blender', 'game/assets/props']:(OUT/name).mkdir(parents=True, exist_ok=True)
PLAN = ROOT/'art/data/city_bridge/source_plan.json'
plan = json.loads(PLAN.read_text(encoding='utf-8')); authored = plan['authored']
assert plan['schema']=='orison.city-bridge.v1' and len(plan['spans_m'])==5
stations=[0.]
for length in plan['spans_m']:stations.append(stations[-1]+float(length))
assert abs(stations[-1]-1135.2276)<1e-6
length=stations[-1]; half=float(plan['truss_centres_m'])/2
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version=0
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
finishes=plan['finishes']; mats={k:material(ROOT,'Bridge_'+k,v,catalog) for k,v in finishes.items()}
closed=[];exports=[];stocks=collections.defaultdict(list);records=[];nodes={};members=[]
for lod in range(2):
    c=bpy.data.collections.new('ClosedBridge_LOD'+str(lod));bpy.context.scene.collection.children.link(c);c.hide_render=True;closed.append(c)
    c=bpy.data.collections.new('BridgeExports_LOD'+str(lod));bpy.context.scene.collection.children.link(c);exports.append(c)
LOD=0

def road(s):
    excess=max(0.,abs(s-length/2)-float(plan['central_level_length_m'])/2)
    return float(authored['road_mid_crown_m'])-excess*float(plan['end_grade'])

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

for LOD in range(2):main_bridge()
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
report=dict(evidence_class='INERT',scope=plan['scope'],frame=plan['frame'],stations_m=stations,paired_truss_centres_m=2*half,tower_frames=4,piers=6,panel_count=len(panel_stations)-1,stocks=records,nodes={k:list(v) for k,v in nodes.items()},members=members,exports=[near,low],failures=[],remaining=['Queens approach sheet assembly','native optical review','roundtrip and loaded precision','authored siting/high-water relation','shore/island backing','actual roof/street/telescope sightlines','composed performance and acceptance'])
report['source_bindings']={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest() for p in [PLAN,Path(__file__)]}
(OUT/'art/blender/city_bridge_construction.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
print('BRIDGE NATIVE:',len(records),'stocks;',near['triangles'],low['triangles'],'triangles; engineering-frame study only',flush=True)
