"""Source-owned elevated plaza stock; native geometry, not runtime acceptance."""
from pathlib import Path
import collections, hashlib, json, math, os, sys
import bpy, bmesh
from mathutils import Vector, Matrix

ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
sys.path.insert(0,str(ROOT/'art/blender/scripts'))
from fabrication_native_batch import material, partition, export
from check_exported_tangents import validate as validate_export
from city_street_geometry import topology,rectangle,cut,bounds
PLAN=ROOT/'art/data/city_transport/source_plan.json'
plan=json.loads(PLAN.read_text(encoding='utf-8'));s=plan['station'];plaza=plan['plaza']
street_plan_path=ROOT/'art/data/city_streets/source_plan.json'
street_plan=json.loads(street_plan_path.read_text())
street_shape=topology(street_plan,json.loads((ROOT/'game/data/orison_v2/exterior/street_traffic.json').read_text()),json.loads((ROOT/'game/data/orison_v2/exterior/street_frame.json').read_text()),plan)
assert plan['schema']=='orison.city-transport.v1' and plan['frame']=='CITY_ELEVATIONS_SOURCE'
assert len(s['track_y_m'])==4 and len(s['platform_top_m'])==2
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
finishes=plan['finishes'];mats={k:material(ROOT,'Transport_'+k,v,catalog) for k,v in finishes.items()}
closed=[];exports=[]
for lod in range(2):
    c=bpy.data.collections.new('ClosedConstruction_LOD'+str(lod));bpy.context.scene.collection.children.link(c);c.hide_render=True;closed.append(c)
    c=bpy.data.collections.new('TransportExports_LOD'+str(lod));bpy.context.scene.collection.children.link(c);exports.append(c)
stocks=collections.defaultdict(list);records=[];contacts=[];stair_routes=[];holes=collections.defaultdict(list)
LOD=0
def chunk(x):return max(0,min(4,int((x-s['x_ends_m'][0])/s['chunk_length_m'])))
def mesh_stock(name,key,verts,faces,role,bevel=0.):
    bm=bmesh.new();vv=[bm.verts.new(v) for v in verts]
    for face in faces:bm.faces.new([vv[i] for i in face])
    if bevel and LOD==0:bmesh.ops.bevel(bm,geom=list(bm.edges),offset=bevel,segments=1,affect='EDGES')
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    assert all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>1e-12,name
    mesh=bpy.data.meshes.new(name);bm.to_mesh(mesh);bm.free()
    obj=bpy.data.objects.new(name,mesh);closed[LOD].objects.link(obj)
    points=[v.co for v in mesh.vertices];bounds=[min(p[i] for p in points) for i in range(3)]+[max(p[i] for p in points) for i in range(3)]
    cell=chunk((bounds[0]+bounds[3])*.5);stocks[(LOD,cell,key)].append(obj)
    records.append(dict(id=name,lod=LOD,chunk=cell,finish=key,role=role,bounds=bounds))
    return obj
def box(name,key,lo,hi,role,bevel=.002):
    assert all(b>a for a,b in zip(lo,hi)),name
    x,y,z=lo;X,Y,Z=hi
    return mesh_stock(name,key,[(x,y,z),(X,y,z),(X,Y,z),(x,Y,z),(x,y,Z),(X,y,Z),(X,Y,Z),(x,Y,Z)],[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],role,bevel)

def paving_polygon(name,p,low,high):
    n=len(p);verts=[(x,y,z) for z in [low,high] for x,y in p]
    return mesh_stock(name,'paving',verts,[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],'public_paving',0)
def extrude(name,key,profile,a,b,role,bevel=.002):
    a=Vector(a);b=Vector(b);axis=(b-a).normalized()
    side=Vector((-axis.y,axis.x,0)).normalized() if abs(axis.z)<.99 else Vector((1,0,0))
    up=axis.cross(side);n=len(profile)
    verts=[p+side*w+up*d for p in [a,b] for w,d in profile]
    faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return mesh_stock(name,key,verts,faces,role,bevel)
def ibeam(name,a,b,width,depth,plate,role='rolled_structure'):
    w=width/2;d=depth/2;p=plate
    profile=[(-w,-d),(w,-d),(w,-d+p),(p/2,-d+p),(p/2,d-p),(w,d-p),(w,d),(-w,d),(-w,d-p),(-p/2,d-p),(-p/2,-d+p),(-w,-d+p)]
    return extrude(name,'structure',profile,a,b,role)
def rod(name,a,b,r=.025,role='guardrail'):
    return extrude(name,'structure',[(math.cos(i*math.tau/8)*r,math.sin(i*math.tau/8)*r) for i in range(8)],a,b,role,0)
def bolt(name,at,axis=(0,0,1)):
    if LOD: return
    a=Vector(at);n=Vector(axis).normalized()
    return extrude(name,'structure',[(math.cos(i*math.tau/6)*.014,math.sin(i*math.tau/6)*.014) for i in range(6)],a-n*.004,a+n*.009,'connection_head',0)

def stringer_connection(name,end,sign,yy,deck):
    # A closed seat angle receives the stringer flange. A web tongue meets
    # the transverse girder's actual web face; flange ends stop at its outside
    # arris, rather than passing through the transverse flange and sleepers.
    top=deck-s['sleeper_depth_m'];bottom=top-s['track_stringer_depth_m']
    profile=[(.0175,bottom-.24),(.0395,bottom-.24),(.0395,bottom-.022),(.35,bottom-.022),(.35,bottom),(.0175,bottom)]
    n=len(profile);verts=[(end+sign*x,yy+v,z) for v in [-.15,.15] for x,z in profile]
    faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    mesh_stock(name+'_SeatAngle','structure',verts,faces,'stringer_seat_angle',.001)
    lo,hi=sorted([end+sign*.0175,end+sign*.21])
    box(name+'_WebTongue','structure',(lo,yy-.011,bottom+.022),(hi,yy+.011,top-.022),'stringer_web_connection',0)
    for dy in [-.10,.10]:
        for dz in [-.08,-.18]:bolt(name+f'_Rivet_{dy}_{dz}',(end+sign*.0395,yy+dy,bottom+dz),(sign,0,0))
def rect_cells(rect,masks,pitch,split_rects=()):
    a,b,c,d=rect;xs={a,c};ys={b,d}
    px,py=pitch if isinstance(pitch,tuple) else (pitch,pitch)
    xs.update(a+i*px for i in range(1,math.ceil((c-a)/px)))
    ys.update(b+i*py for i in range(1,math.ceil((d-b)/py)))
    for e,f,g,h in list(masks)+list(split_rects):xs.update(v for v in [e,g] if a<v<c);ys.update(v for v in [f,h] if b<v<d)
    xs=sorted(xs);ys=sorted(ys)
    for x,X in zip(xs,xs[1:]):
        for y,Y in zip(ys,ys[1:]):
            if any(e<(x+X)/2<g and f<(y+Y)/2<h for e,f,g,h in masks):continue
            yield x,y,X,Y
def stair_well(name,x,y,low,high,steps,width,gap,tread,landing):
    """Two actual flights with closed cut stringers, supported treads and landing."""
    rise=(high-low)/(steps*2);run=steps*tread;lane=width+gap
    for flight in range(2):
        sign=1 if flight==0 else -1;start=x if flight==0 else x+run
        cy=y if flight==0 else y+lane;base=low+flight*(high-low)/2
        for i in range(steps):
            xa=start+sign*i*tread;xb=start+sign*(i+1)*tread;z=base+(i+1)*rise
            box(f'{name}_F{flight}_Tread_{i}','timber',(min(xa,xb),cy-width/2,z-.055),(max(xa,xb),cy+width/2,z),'stair_tread')
            if LOD==0:
                for side in [-1,1]:bolt(f'{name}_F{flight}_TreadFastener_{i}_{side}',((xa+xb)*.5,cy+side*(width/2-.07),z))
        # A flat cut foot bears on the starting floor. Then the lower edge
        # follows the flight pitch: it must never cross a horizontal tread seat.
        foot=min(run*.8,.35*tread/rise)
        outline=[(0,base),(foot,base),(run,base+steps*rise-.35),(run,base+steps*rise-.055)]
        for i in range(steps):
            for u in [i*tread,(i+1)*tread]:
                bottom=max(base,base+u*rise/tread-.35)
                assert bottom<base+(i+1)*rise-.055,'stringer profile crosses its actual tread bearing'
        for i in range(steps-1,-1,-1):
            z=base+(i+1)*rise-.055;outline.extend([((i+1)*tread,z),(i*tread,z)])
        clean=[]
        for p in outline:
            if not clean or p!=clean[-1]:clean.append(p)
        for side in [-1,1]:
            yy=cy+side*(width/2-.06);verts=[Vector((start+sign*u,yy+v,z)) for v in [-.05,.05] for u,z in clean];n=len(clean)
            faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
            mesh_stock(f'{name}_F{flight}_Stringer_{side}','timber',verts,faces,'cut_stair_stringer',0)
            topa=(start,cy+side*width/2,base+s['handrail_height_m']);topb=(start+sign*run,cy+side*width/2,base+steps*rise+s['handrail_height_m'])
            rod(f'{name}_F{flight}_Handrail_{side}',topa,topb)
            for i in range(0,steps+1,3):
                px=start+sign*i*tread;pz=base+i*rise
                rod(f'{name}_F{flight}_Post_{side}_{i}',(px,cy+side*width/2,pz),(px,cy+side*width/2,pz+s['handrail_height_m']),.018)
    mid=(low+high)/2;ya=y-width/2;yb=y+lane+width/2
    box(name+'_Landing','timber',(x+run,ya,mid-.10),(x+run+landing,yb,mid),'stair_landing')
    for yy in [ya+.08,yb-.08]:ibeam(name+'_LandingSeat_'+str(yy),(x+run,yy,mid-.22),(x+run+landing,yy,mid-.22),.10,.24,.015,'landing_bearer')
    for yy in [ya+.08,yb-.08]:
        if name=='PublicEntry':
            ibeam(name+'_LandingLeg_'+str(yy),(x+run+landing-.08,yy,low),(x+run+landing-.08,yy,mid-.34),.12,.12,.014,'landing_leg')
        else:
            # Suspend platform stair landings from their framed opening; no
            # column may descend through the live carriageway underneath.
            box(name+'_LandingHanger_'+str(yy),'structure',(x+run+landing-.13,yy-.04,mid-.34),(x+run+landing-.03,yy+.04,high-.22),'landing_hanger',.001)
    rod(name+'_LandingGuard',(x+run+landing,ya,mid+s['handrail_height_m']),(x+run+landing,yb,mid+s['handrail_height_m']))
    if LOD==0:stair_routes.append(dict(id=name,from_m=[x,y,low],half_m=[x+run+tread,y,mid],to_m=[x,y+lane,high],riser_m=rise,tread_m=tread))

def guarded_run(name,a,b,openings=()):
    a=Vector(a);b=Vector(b);delta=b-a;length=delta.length;direction=delta/length
    intervals=[];start=0.
    for lo,hi in sorted(openings):
        lo=max(0.,lo);hi=min(length,hi)
        if lo>start:intervals.append((start,lo))
        start=max(start,hi)
    if start<length:intervals.append((start,length))
    for index,(lo,hi) in enumerate(intervals):
        if hi-lo<.05:continue
        rod(f'{name}_Rail_{index}',a+direction*lo+Vector((0,0,s['handrail_height_m'])),a+direction*hi+Vector((0,0,s['handrail_height_m'])))
        count=max(1,math.ceil((hi-lo)/1.5))
        for i in range(count+1):
            p=a+direction*(lo+(hi-lo)*i/count)
            rod(f'{name}_Post_{index}_{i}',p,p+Vector((0,0,s['handrail_height_m'])),.018)

# Declare all openings first; floors are cut around the real stair volumes.
entry=s['entry_stair'];ps=s['platform_stairs']
for level,top in enumerate(s['platform_top_m']):
    for island,(a,b) in enumerate(s['islands_y_m']):
        x=ps['lower_x_m'] if level==0 else ps['upper_x_m'];count=ps['lower_steps_per_flight'] if level==0 else ps['upper_steps_per_flight']
        cy=(a+b)/2-(ps['flight_width_m']+ps['well_gap_m'])/2
        holes[(level,island)].append([x,cy-ps['flight_width_m']/2-.10,x+count*ps['tread_m']+ps['landing_m']+.10,cy+ps['flight_width_m']*1.5+ps['well_gap_m']+.10])
for LOD in range(2):
    # Near floors retain individual boards; replacement bodies use longer
    # closed stock with the SAME stair voids, silhouette, levels and supports.
    for x in s['bent_x_m']:
        for y in s['column_y_m']:
            tag=f'Bent_{x}_{y}'
            box(tag+'_Footing','paving',(x-.65,y-.65,s['footing_bottom_m']),(x+.65,y+.65,s['footing_top_m']),'footing',0)
            box(tag+'_Pedestal','paving',(x-.40,y-.40,s['footing_top_m']),(x+.40,y+.40,.01),'pedestal')
            box(tag+'_BasePlate','structure',(x-.34,y-.34,.01),(x+.34,y+.34,s['base_plate_top_m']),'base_plate',.001)
            top_plate=.035;cap_tops=[deck-s['sleeper_depth_m'] for deck in s['deck_top_m']]
            starts=[s['base_plate_top_m']]+[top+top_plate for top in cap_tops]
            ends=[top-s['girder_depth_m']-top_plate for top in cap_tops]+[s['roof_eave_m']-.30-top_plate]
            for segment,(low,high) in enumerate(zip(starts,ends)):
                ibeam(tag+f'_Column{segment}',(x,y,low),(x,y,high),s['column_flange_m'],s['column_flange_m'],s['column_plate_m'],'column')
            box(tag+'_CrownSeat','structure',(x-.30,y-.32,ends[-1]),(x+.30,y+.32,s['roof_eave_m']-.30),'column_crown_seat',.001)
            for dx in [-.27,.27]:
                for dy in [-.27,.27]:bolt(tag+f'_Anchor_{dx}_{dy}',(x+dx,y+dy,s['base_plate_top_m']))
            if LOD==0:contacts.append(dict(id=tag,point=[x,y,s['base_plate_top_m']],normal=[0,0,1],kind='column_on_base_plate'))
        for level,deck in enumerate(s['deck_top_m']):
            cap_top=deck-s['sleeper_depth_m'];cap_bottom=cap_top-s['girder_depth_m'];z=(cap_top+cap_bottom)/2
            ibeam(f'Bent_{x}_Cap_{level}',(x,s['column_y_m'][0]-.5,z),(x,s['column_y_m'][-1]+.5,z),.42,s['girder_depth_m'],.035,'transverse_girder')
            for y in s['column_y_m']:
                box(f'Bent_{x}_{y}_Seat_{level}','structure',(x-.30,y-.32,cap_bottom-.035),(x+.30,y+.32,cap_bottom),'girder_seat',.001)
                box(f'Bent_{x}_{y}_UpperSeat_{level}','structure',(x-.30,y-.32,cap_top),(x+.30,y+.32,cap_top+.035),'upper_column_seat',.001)
                for dy in [-.24,.24]:bolt(f'Bent_{x}_{y}_SeatBolt_{level}_{dy}',(x,y+dy,cap_bottom+.035))
                for dx in [-.27,.27]:bolt(f'Bent_{x}_{y}_UpperSeatBolt_{level}_{dx}',(x+dx,y,cap_top+.035))
        ibeam(f'Bent_{x}_UpperTie',(x,s['column_y_m'][0]-.35,s['roof_eave_m']-.15),(x,s['column_y_m'][-1]+.35,s['roof_eave_m']-.15),.24,.30,.022,'upper_bent_tie')
    for bay,(a,b) in enumerate(zip(s['bent_x_m'],s['bent_x_m'][1:])):
        for level,deck in enumerate(s['deck_top_m']):
            for track,y in enumerate(s['track_y_m']):
                for rail in [-1,1]:
                    yy=y+rail*s['track_gauge_m']/2
                    z=deck-s['sleeper_depth_m']-s['track_stringer_depth_m']/2
                    tag=f'Bay{bay}_Stringer{level}_{track}_{rail}'
                    ibeam(tag,(a+.21,yy,z),(b-.21,yy,z),.24,s['track_stringer_depth_m'],.022,'track_stringer')
                    stringer_connection(tag+'_West',a,1,yy,deck)
                    stringer_connection(tag+'_East',b,-1,yy,deck)
                    # Rolled rail has a wide foot and narrower running head.
                    profile=[(-.07,0),(.07,0),(.07,.025),(.009,.04),(.009,.105),(.033,.12),(.033,.15),(-.033,.15),(-.033,.12),(-.009,.105),(-.009,.04),(-.07,.025)]
                    extrude(f'Bay{bay}_Rail{level}_{track}_{rail}','rail',profile,(a,yy,deck),(b,yy,deck),'running_rail',.001)
                for tie in range(math.ceil((b-a)/s['sleeper_pitch_m'])):
                    x=a+(tie+.5)*(b-a)/math.ceil((b-a)/s['sleeper_pitch_m'])
                    box(f'Bay{bay}_Tie{level}_{track}_{tie}','sleeper',(x-.12,y-1.30,deck-s['sleeper_depth_m']),(x+.12,y+1.30,deck),'rail_sleeper')
        for y in s['column_y_m']:
            # Longitudinal sway braces keep the carriageway free of diagonal stock.
            for low,high in [(5.0,s['deck_top_m'][0]-1.12),(s['deck_top_m'][0]+.45,s['deck_top_m'][1]-1.12)]:
                ibeam(f'Bay{bay}_Sway_{y}_{low}',(a+.26,y,low),(b-.26,y,high),.10,.12,.012,'sway_brace')
                ibeam(f'Bay{bay}_SwayCross_{y}_{low}',(a+.26,y,high),(b-.26,y,low),.10,.12,.012,'sway_brace')
    for level,top in enumerate(s['platform_top_m']):
        for island,(y,Y) in enumerate(s['islands_y_m']):
            rect=[s['x_ends_m'][0],y,s['x_ends_m'][1],Y];voids=holes[(level,island)]
            pitch=(2.5,s['platform_plank_pitch_m']) if LOD==0 else (s['chunk_length_m'],Y-y)
            for index,(x,a,X,b) in enumerate(rect_cells(rect,voids,pitch)):
                joint=s['platform_plank_joint_m'] if LOD==0 else 0.
                if X-x<=joint or b-a<=joint:continue
                box(f'Platform{level}_{island}_Stock{index}','timber',(x+joint/2,a,top-s['platform_stock_depth_m']),(X-joint/2,b,top),'platform_body')
            for bay,(x,X) in enumerate(zip(s['bent_x_m'],s['bent_x_m'][1:])):
                for yy in [y+.22,Y-.22]:
                    ibeam(f'Platform{level}_{island}_Girder{bay}_{yy}',(x,yy,top-.44),(X,yy,top-.44),.20,.44,.025,'platform_girder')
                for j in range(12):
                    xx=x+(j+.5)*(X-x)/12
                    cuts=sorted([(b,d) for a,b,c,d in voids if a<xx<c]);intervals=[];start=y
                    for b,d in cuts:
                        if b>start:intervals.append((start,b))
                        start=max(start,d)
                    if start<Y:intervals.append((start,Y))
                    for segment,(lo,hi) in enumerate(intervals):ibeam(f'Platform{level}_{island}_Joist{bay}_{j}_{segment}',(xx,lo,top-.16),(xx,hi,top-.16),.08,.12,.012,'platform_joist')
            for a,b,c,d in voids:
                for yy in [b,d]:ibeam(f'Platform{level}_{island}_WellTrimmer_{yy}',(a,yy,top-.22),(c,yy,top-.22),.16,.24,.018,'stair_well_trimmer')
                for xx in [a,c-.1]:ibeam(f'Platform{level}_{island}_WellHeader_{xx}',(xx,y,top-.16),(xx,Y,top-.16),.24,.12,.014,'stair_well_header')
                guarded_run(f'Platform{level}_{island}_WellSideA',(a,b,top),(c,b,top))
                guarded_run(f'Platform{level}_{island}_WellSideB',(a,d,top),(c,d,top))
                guarded_run(f'Platform{level}_{island}_WellEnd',(c,b,top),(c,d,top))
            for xx in s['x_ends_m']:guarded_run(f'PlatformEnd_{level}_{island}_{xx}',(xx,y,top),(xx,Y,top))
            for x in s['bent_x_m']:
                for yy in [y+.22,Y-.22]:ibeam(f'Platform{level}_{island}_Stub{x}_{yy}',(x,yy,s['deck_top_m'][level]),(x,yy,top-.66),.16,.16,.02,'platform_stanchion')
            count=ps['lower_steps_per_flight'] if level==0 else ps['upper_steps_per_flight'];x=ps['lower_x_m'] if level==0 else ps['upper_x_m']
            cy=(y+Y)/2-(ps['flight_width_m']+ps['well_gap_m'])/2
            stair_well(f'PlatformStair_{level}_{island}',x,cy,s['mezzanine_top_m'] if level==0 else s['platform_top_m'][0],top,count,ps['flight_width_m'],ps['well_gap_m'],ps['tread_m'],ps['landing_m'])
    stair_well('PublicEntry',entry['x_start_m'],entry['y_start_m'],0,s['mezzanine_top_m'],entry['steps_per_flight'],entry['flight_width_m'],entry['well_gap_m'],entry['tread_m'],entry['landing_m'])
    x,X=s['mezzanine_x_m'];y,Y=s['mezzanine_y_m'];z=s['mezzanine_top_m']
    box('MezzanineBody','timber',(x,y,z-.10),(X,Y,z),'mezzanine_body')
    for xx in [x+.1,X-.1]:ibeam('MezzanineGirder_'+str(xx),(xx,y,z-.25),(xx,Y,z-.25),.16,.30,.02,'mezzanine_girder')
    guarded_run('MezzanineWestGuard',(x,y,z),(x,Y,z))
    openings=[(entry['y_start_m']+entry['flight_width_m']+entry['well_gap_m']-entry['flight_width_m']/2-y-.08,entry['y_start_m']+entry['flight_width_m']+entry['well_gap_m']+entry['flight_width_m']/2-y+.08)]
    for a,b in s['islands_y_m']:
        cy=(a+b)/2-(ps['flight_width_m']+ps['well_gap_m'])/2
        openings.append((cy-ps['flight_width_m']/2-y-.08,cy+ps['flight_width_m']/2-y+.08))
    guarded_run('MezzanineEastGuard',(X,y,z),(X,Y,z),openings)
    for cy in s['column_y_m']:
        for xx in [x+.1,X-.1]:
            box(f'MezzanineFooting_{xx}_{cy}','paving',(xx-.35,cy-.35,-.50),(xx+.35,cy+.35,.01),'footing',0)
            box(f'MezzanineBasePlate_{xx}_{cy}','structure',(xx-.20,cy-.20,.01),(xx+.20,cy+.20,s['base_plate_top_m']),'base_plate')
            ibeam(f'MezzaninePier_{xx}_{cy}',(xx,cy,s['base_plate_top_m']),(xx,cy,z-.40),.18,.18,.02,'mezzanine_pier')
    for island,(y,Y) in enumerate(s['islands_y_m']):
        center=(y+Y)/2
        for a,b in zip(s['bent_x_m'],s['bent_x_m'][1:]):
            for side in [-1,1]:
                edge=center+side*((Y-y)/2+.35)
                # Closed pitched sheets, not single-sided or floating planes.
                profile=[(center,s['roof_ridge_m']),(edge,s['roof_eave_m']),(edge,s['roof_eave_m']-.035),(center,s['roof_ridge_m']-.035)]
                verts=[(x,yy,zz) for x in [a,b] for yy,zz in profile]
                mesh_stock(f'Roof_{island}_{a}_{side}','roof',verts,[(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],'replacement_roof_body',0)
        for x in s['bent_x_m']:
            for yy in [y+.5,Y-.5]:ibeam(f'CanopyPost_{island}_{x}_{yy}',(x,yy,s['platform_top_m'][1]),(x,yy,s['roof_eave_m']),.12,.14,.014,'canopy_post')
            for yy in [y-.35,Y+.35]:ibeam(f'CanopyRafter_{island}_{x}_{yy}',(x,yy,s['roof_eave_m']-.06),(x,center,s['roof_ridge_m']-.06),.10,.12,.012,'canopy_rafter')
    pads=[[x-.40,y-.40,x+.40,y+.40] for x in s['bent_x_m'] for y in s['column_y_m']]
    pads += [[xx-.35,yy-.35,xx+.35,yy+.35] for xx in [s['mezzanine_x_m'][0]+.1,s['mezzanine_x_m'][1]-.1] for yy in s['column_y_m']]
    footings=[[x-.65,y-.65,x+.65,y+.65] for x in s['bent_x_m'] for y in s['column_y_m']]
    for side,(y,Y) in enumerate([plaza['y_ends_m'],plaza.get('south_y_ends_m',[-28.316,-23.894])]):
        rect=[plaza['x_ends_m'][0],y,plaza['x_ends_m'][1],Y]
        for i,(a,b,c,d) in enumerate(rect_cells(rect,pads,plaza['joint_pitch_m'] if not LOD else s['chunk_length_m'],footings)):
            over_footing=any(e<=(a+c)/2<=g and f<=(b+d)/2<=h for e,f,g,h in footings)
            bottom=s['footing_top_m'] if over_footing else plaza['slab_bottom_m']
            joint=plaza['joint_m'] if LOD==0 else 0.
            if min(c-a,d-b)>joint:
                p=rectangle([a+joint/2,b+joint/2,c-joint/2,d-joint/2])
                for j,q in enumerate(cut(p,street_shape['road'])):
                    paving_polygon(f'Plaza_{side}_{i}_{j}',q,bottom,plaza['surface_top_m'])
        # The continuous street family owns the curb courses and curved
        # intersection returns. Retain this family's public slabs and piers.

# Each LOD is a replacement body, sharing a material/chunk ABI. Local origins
# keep exported floats and metre charts bounded; closed source stocks remain.
for (lod,cell,key),objects in stocks.items():
    origin=Vector((s['x_ends_m'][0]+cell*s['chunk_length_m'],0,0))
    for obj in objects:
        for v in obj.data.vertices:v.co-=origin
        obj.location=origin
    partition(exports[lod],f'Transport_{cell}_L{lod}__{key}',objects,finishes[key],mats[key],Matrix.Translation(origin),catalog)
bpy.context.view_layer.update()
proof0=export(ROOT,'city_transport',exports[0],staged_output=True)
bpy.ops.object.select_all(action='DESELECT')
for obj in exports[1].objects:obj.select_set(True)
low_path=ROOT/'game/assets/props/city_transport_lod1.glb'
bpy.ops.export_scene.gltf(filepath=str(low_path),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_attributes=True,export_materials='PLACEHOLDER')
proof1=validate_export(low_path)
assert proof1['triangles']<proof0['triangles']
def sha(p):
    raw=p.read_bytes();return hashlib.sha256(raw if p.suffix in ['.blend','.glb','.png'] else raw.replace(b'\r\n',b'\n')).hexdigest()
bindings=[PLAN,Path(__file__),street_plan_path,ROOT/'art/blender/scripts/city_street_geometry.py',ROOT/'game/data/orison_v2/exterior/street_traffic.json',ROOT/'game/data/orison_v2/exterior/street_frame.json',ROOT/'game/data/runtime_material_sets.json',ROOT/'art/blender/city_transport.blend']+[ROOT/'art/blender/scripts'/n for n in ['fabrication_native_batch.py','fabrication_chart_batch.py','fabrication_grain.py','fabrication_normals.py','check_exported_tangents.py']]
report=dict(evidence_class='INERT',scope=plan['scope'],source_bindings={p.relative_to(ROOT).as_posix():sha(p) for p in bindings},asset_sha256={p.relative_to(ROOT).as_posix():sha(p) for p in [ROOT/'game/assets/props/city_transport.glb',low_path]},exports=[proof0,proof1],stocks=records,contacts=contacts,stair_routes=stair_routes,platform_voids={str(k):v for k,v in holes.items()},failures=[])
for p in ['art/blender/city_transport_construction.json','game/tests/fixtures/orison_city_transport.json']:(ROOT/p).write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
runtime=dict(schema=1,finishes=[dict(alias=k,**v) for k,v in finishes.items()],lod_error_m=s['lod_error_m'],parts=[o.name for o in exports[0].objects])
(ROOT/'game/data/orison_v2/exterior/city_transport.json').write_text(json.dumps(runtime,indent=2)+'\n',encoding='utf-8',newline='\n')
print('CITY TRANSPORT NATIVE:',len(records),'closed stocks; near/far triangles',proof0['triangles'],proof1['triangles'])
