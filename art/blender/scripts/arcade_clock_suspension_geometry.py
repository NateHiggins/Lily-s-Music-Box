"""Pure source-owned clock suspension stocks, LOCAL GODOT about clock.origin.

Two original pipes only. One common rigid translation also moves the clock.
The upper stem is coped to the actual two nearest transverse-rib undersides.
No clock state, mesh scaling, runtime admission or source disposal is supplied.
"""
import copy
import hashlib
import json
import math
import arcade_roof_geometry as Roof

SIDES=32
STEM='site_crossing_clock_stem'
DROP='site_crossing_clock_drop'


def need(ok,message):
    if not ok:raise ValueError(message)

def finite(values,length):
    need(isinstance(values,list) and len(values)==length and all(type(x) in (int,float) and math.isfinite(x) for x in values),'malformed/nonfinite source coordinate')
    return values

def sub(a,b):return [x-y for x,y in zip(a,b)]
def cross(a,b):return [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]
def dot(a,b):return sum(x*y for x,y in zip(a,b))
def digest(value):return hashlib.sha256(json.dumps(value,sort_keys=True,separators=(',',':'),allow_nan=False).encode()).hexdigest()

def _underside(stock,origin):
    vertices=[[origin[0]+p[0],origin[2]+p[2],-origin[1]+p[1]] for p in stock['vertices']]
    for p in vertices:finite(p,3)
    faces=[list(reversed(f)) for f in stock['faces']]
    downward=[]
    for f in faces:
        need(len(f)==3 and all(type(i) is int and 0<=i<len(vertices) for i in f),'receiver triangle indices')
        a,b,c=[vertices[i] for i in f];n=cross(sub(b,a),sub(c,a));need(dot(n,n)>1e-20,'degenerate receiver triangle')
        if n[1]<-1e-10:
            # The planar height is a*x+b*z+c, extracted from real geometry.
            plane=[-n[0]/n[1],-n[2]/n[1],dot(n,a)/n[1]]
            downward.append(plane)
    need(len(downward)==2,'two actual underside triangles required per receiver')
    need(all(abs(a-b)<1e-10 for a,b in zip(*downward)),'receiver underside must be planar')
    return dict(source_stock=copy.deepcopy(stock),godot_vertices=vertices,godot_faces=faces,plane_y_from_xz=downward[0],
                low=[min(p[k] for p in vertices) for k in range(3)],high=[max(p[k] for p in vertices) for k in range(3)])

def _height(receiver,x,z):
    a,b,c=receiver['plane_y_from_xz'];return a*x+b*z+c


def _pipe(record,origin,cap_heights=None):
    low=min(record['p0'][2],record['p1'][2])-origin[1];high=max(record['p0'][2],record['p1'][2])-origin[1]
    radius=record['r'];vertices=[]
    for upper in [False,True]:
        for j in range(SIDES):
            angle=math.tau*j/SIDES
            x=0. if j in (8,24) else radius*math.cos(angle)
            z=0. if j in (0,16) else radius*math.sin(angle)
            vertices.append([x,(cap_heights[j]-origin[1] if cap_heights is not None else high) if upper else low,z])
    centre=len(vertices);vertices.append([0.,high,0.])
    faces=[list(range(SIDES))]
    for j in range(SIDES):
        nxt=(j+1)%SIDES
        faces.append([j,SIDES+j,SIDES+nxt,nxt])
        faces.append([centre,SIDES+nxt,SIDES+j])
    return dict(name=record['id'],source_record_id=record['id'],source_record=copy.deepcopy(record),
        material=record['mat'],material_family=record['mat'],owner='passage',role='clock_suspension' if cap_heights else 'clock_finial',
        coordinate_frame='LOCAL_GODOT_RELATIVE_CLOCK_ORIGIN',vertices=vertices,faces=faces,sides=SIDES,
        source_disposal_authorized=False)


def build(layout,clock,plaza,roof):
    origin=finite(clock.get('origin'),3);source_frame=finite(plaza.get('source_origin_blender_m'),3)
    need(clock.get('presentation',{}).get('time_owner')=='CampaignClock.minute_of_day','clock authority changed')
    floors=[f for f in layout['floors'] if f['id']=='F01'];need(len(floors)==1,'unique original F01 required')
    bodies=[r for r in floors[0]['furniture'] if r['id']=='site_passage_crossing_clock_body']
    need(len(bodies)==1,'unique source clock body anchor required')
    body=bodies[0];rect=finite(body.get('rect'),4)
    body_origin=[(rect[0]+rect[2])/2,body['z0']+body['h']/2,-(rect[1]+rect[3])/2]
    need(all(abs(a-b)<1e-10 for a,b in zip(origin,body_origin)),'clock source origin changed')
    sources={}
    for r in floors[0]['furniture']:
        if r['id'] in [STEM,DROP]:
            need(r['id'] not in sources,'duplicate original suspension source');sources[r['id']]=r
    need(set(sources)=={STEM,DROP},'missing original suspension source')
    for identity,mat,radius,ends in [(STEM,'cast_iron',.03,[6.52,10.9]),(DROP,'brass_dull',.05,[5.66,5.84])]:
        r=sources[identity]
        need(r.get('asm')=='pipe' and r.get('mat')==mat and r.get('r')==radius and r.get('batch')=='passage_shell','source pipe profile/material changed')
        for key in ['p0','p1']:
            p=finite(r.get(key),3);need(abs(p[0]-origin[0])<1e-10 and abs(-p[1]-origin[2])<1e-10,'source suspension axis changed')
        need(all(abs(a-b)<1e-10 for a,b in zip(sorted([r['p0'][2],r['p1'][2]]),ends)),'original axial endpoints changed')
    need(abs(origin[0]-(source_frame[0]+sum(roof['nave']['u_span_m'])/2))<1e-10,'clock axis must remain at nave crown')
    actual=Roof.stocks(plaza,roof)
    ribs=[s for s in actual if s['name'].startswith('Nave_rib') and s['role']=='arch_rib']
    names=[s['name'] for s in ribs];need(len(names)==len(set(names)),'duplicate roof receiver source')
    groups={}
    for s in ribs:groups.setdefault(s['name'].rsplit('_',1)[0],[]).append(s)
    candidates=[]
    for station,pieces in groups.items():
        axis=origin[0]-source_frame[0]
        left=[p for p in pieces if abs(max(v[0] for v in p['vertices'])-axis)<1e-10]
        right=[p for p in pieces if abs(min(v[0] for v in p['vertices'])-axis)<1e-10]
        need(len(left)==len(right)==1,'missing or ambiguous crown rib receivers')
        pair=[_underside(p,source_frame) for p in [left[0],right[0]]]
        zlow,zhi=pair[0]['low'][2],pair[0]['high'][2]
        need(all(abs(r['low'][2]-zlow)<1e-10 and abs(r['high'][2]-zhi)<1e-10 for r in pair),'receiver station frames differ')
        need(abs(zhi-zlow-roof['rib_width_m'])<1e-10 and zhi-zlow>=.08-1e-10,'receiver width changed')
        z=(zlow+zhi)/2
        expected=roof['nave']['crown_m']-roof['rib_depth_below_m']
        need(all(abs(_height(r,origin[0],z)-expected)<1e-10 for r in pair),'receiver crown height changed')
        need(pair[0]['plane_y_from_xz'][0]>0 and pair[1]['plane_y_from_xz'][0]<0,'receiver slope/side mismatch')
        candidates.append((abs(z-origin[2]),station,z,pair))
    need(bool(candidates),'missing actual transverse roof ribs')
    _,station,target_z,receivers=min(candidates,key=lambda c:(c[0],c[1]))
    target_top=_height(receivers[0],origin[0],target_z)
    delta=[0.,target_top-10.9,target_z-origin[2]]
    cap=[];source_caps=[]
    for j in range(SIDES):
        angle=math.tau*j/SIDES;x=origin[0]+(0 if j in (8,24) else .03*math.cos(angle));z=target_z+(0 if j in (0,16) else .03*math.sin(angle))
        receiver=receivers[0 if x<=origin[0] else 1]
        y=_height(receiver,x,z)
        need(receiver['low'][0]-1e-10<=x<=receiver['high'][0]+1e-10 and receiver['low'][2]-1e-10<=z<=receiver['high'][2]+1e-10,'cap outside receiver footprint')
        source_y=y-delta[1];need(0<=10.9-source_y<.0022,'unexpected coping depth')
        source_caps.append(source_y)
        cap.append(dict(index=j,receiver_stock=receiver['source_stock']['name'],target_point=[x,y,z],expected_plane_height=y,source_point=[x,source_y,z-delta[2]],cope_trim_m=10.9-source_y))
    stocks=[_pipe(sources[STEM],origin,source_caps),_pipe(sources[DROP],origin)]
    matrix=[[1,0,0,delta[0]],[0,1,0,delta[1]],[0,0,1,delta[2]],[0,0,0,1]]
    finial_bottom=5.66+delta[1]
    need(finial_bottom>3.3,'clock/finial must clear shop roof and ordinary player headroom')
    proof=dict(origin=list(origin),delta=delta,delta_transform=matrix,whole_clock_translation_only=True,
        source_rows=copy.deepcopy(sources),source_clock_body_anchor=copy.deepcopy(body),receiver_station=station,receiver_stocks=receivers,cap_contacts=cap,
        cap_centre_target=[origin[0],target_top,target_z],receiver_edge_margin_m=(receivers[0]['high'][2]-receivers[0]['low'][2])/2-.03,
        maximum_cope_trim_m=max(r['cope_trim_m'] for r in cap),finial_bottom_y=finial_bottom,
        standing_player_height_reference_m=1.524,standing_player_overhead_clearance_m=finial_bottom-1.524,
        input_hashes=dict(layout=digest(layout),clock=digest(clock),plaza=digest(plaza),roof=digest(roof)),
        source_disposal_authorized=False,scope='Actual receiver-plane geometry only; no structural strength/loaded/art acceptance or new clock state')
    return dict(stocks=stocks,proof=proof)
