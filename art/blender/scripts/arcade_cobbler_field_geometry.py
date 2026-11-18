"""Pure source-bound Cobbler supporting mat islands.

Stocks use PLAN(u,v,height); contact/protected bounds use Godot source X/Y/Z.

No files/meshes are read or moved here. Root binds the actual input bytes and
exports these closed stocks. The old donor receives no disposal authorization.
"""
import copy
import hashlib
import itertools
import json
import math

CELL='shop_shoe_rebuilding'
FELT='storm_shop_shoe_rebuilding_dust_felt'
FLOOR='storm_shop_shoe_rebuilding_floor'
MARGIN=.06
OWNERS=frozenset('storm_shop_shoe_rebuilding_'+s for s in ('bench','finisher','outsole_stand','patcher_treadle','last_rack','rack0','waiting_seat','sole_stack'))
FACES=[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]


def _need(ok,message):
    if not ok:raise ValueError(message)


def _finite(values,length):
    _need(isinstance(values,list) and len(values)==length and all(type(v) in (int,float) and math.isfinite(v) for v in values),'nonfinite or malformed source datum')
    return values


def _rect(r):
    _finite(r,4);_need(r[2]>r[0] and r[3]>r[1],'nonpositive rectangle');return r


def _matrix(m):
    _need(isinstance(m,list) and len(m)==4,'malformed group matrix')
    for row in m:_finite(row,4)
    _need(m[3]==[0,0,0,1],'nonaffine group matrix')
    for i in range(3):
        for j in range(3):_need(abs(sum(m[k][i]*m[k][j] for k in range(3))-(1 if i==j else 0))<1e-10,'nonrigid group matrix')
    # Only horizontal rigid placements preserve the existing support heights.
    _need(all(abs(m[i][j]-(1 if i==j else 0))<1e-10 for i,j in [(0,1),(1,0),(1,1),(1,2),(2,1)]),'tilted group support frame')
    _need(abs(m[0][0]*m[2][2]-m[0][2]*m[2][0]-1)<1e-10,'reflected support frame')
    return m


def _point(m,p):return [sum(m[i][j]*p[j] for j in range(3))+m[i][3] for i in range(3)]
def _inside(r,p):return r[0]<=p[0]<=r[2] and r[1]<=p[2]<=r[3]
def _overlap(a,b):return min(a[2],b[2])>max(a[0],b[0]) and min(a[3],b[3])>max(a[1],b[1])
def _clip(a,b):
    r=[max(a[0],b[0]),max(a[1],b[1]),min(a[2],b[2]),min(a[3],b[3])]
    _need(r[2]>r[0] and r[3]>r[1],'empty room-clipped island');return r

def _digest(value):return hashlib.sha256(json.dumps(value,sort_keys=True,separators=(',',':'),allow_nan=False).encode()).hexdigest()


def _subtract(rect,cut):
    if not _overlap(rect,cut):return [rect]
    a,b,c,d=rect;x0,z0,x1,z1=max(a,cut[0]),max(b,cut[1]),min(c,cut[2]),min(d,cut[3])
    return [r for r in [[a,b,x0,d],[x1,b,c,d],[x0,b,x1,z0],[x0,z1,x1,d]] if r[2]>r[0] and r[3]>r[1]]


def _union(rectangles):
    """Exact rectilinear union as disjoint row strips merged vertically."""
    xs=sorted({r[k] for r in rectangles for k in [0,2]});zs=sorted({r[k] for r in rectangles for k in [1,3]})
    result=[];active={}
    for z0,z1 in zip(zs,zs[1:]):
        runs=[];start=None
        for index,(x0,x1) in enumerate(zip(xs,xs[1:])):
            covered=any(r[0]<=(x0+x1)/2<=r[2] and r[1]<=(z0+z1)/2<=r[3] for r in rectangles)
            if covered and start is None:start=x0
            if start is not None and (not covered or index==len(xs)-2):
                runs.append((start,x0 if not covered else x1));start=None
        next_active={}
        for x0,x1 in runs:
            key=(x0,x1)
            if key in active:
                r=active[key];r[3]=z1
            else:
                r=[x0,z0,x1,z1];result.append(r)
            next_active[key]=r
        active=next_active
    return result


def build(plan,original_layout,retained_equipment,construction):
    shops=[s for s in plan['shops'] if s['id']==CELL];_need(len(shops)==1,'unique Cobbler shop required')
    shop=shops[0];r=_rect(shop['rect_m']);partition=_rect(shop['partition_rect_m']);stock=_rect(shop['stock_rect_m'])
    t=plan['wall_thickness_m'];_need(type(t) in (int,float) and math.isfinite(t) and t>0,'invalid wall depth')
    _need(shop['front']=='east','Cobbler sales-side authority changed')
    origin=_finite(plan['source_origin_blender_m'],3)
    rooms_plan=[[partition[2],r[1]+t,r[2]-t,r[3]-t],stock]
    rooms=[_rect([origin[0]+a, -origin[1]+b,origin[0]+c,-origin[1]+d]) for a,b,c,d in rooms_plan]
    floors=[f for f in original_layout['floors'] if f['id']=='F01'];_need(len(floors)==1,'unique F01 required')
    records={}
    for record in floors[0]['furniture']:records.setdefault(record['id'],[]).append(record)
    for identity in [FELT,FLOOR,*OWNERS]:_need(len(records.get(identity,[]))==1,'missing or duplicate source record: '+identity)
    felt=records[FELT][0];_need(abs(felt['z0']+felt['h']-.018)<1e-10,'original felt top changed')
    _need(felt['mat']=='soot','original mat material changed')
    groups={}
    for group in retained_equipment['groups']:
        if group['cell']!=CELL:continue
        for assembly in group['native_assemblies']:
            identity=assembly['id'];_need(identity not in groups,'duplicate retained assembly group')
            groups[identity]=dict(id=group['id'],matrix=_matrix(group['delta_transform']))
    selected=construction.get('contacts');_need(isinstance(selected,list) and selected,'missing original contact records')
    bindings=construction.get('source_bindings');_need(isinstance(bindings,dict) and bindings,'missing native source bindings')
    _need(all(isinstance(h,str) and len(h)==64 and all(c in '0123456789abcdef' for c in h) for h in bindings.values()),'malformed native source bindings')
    _need(isinstance(construction.get('asset_sha256'),str) and len(construction['asset_sha256'])==64,'missing native payload binding')
    felt_contacts=[];floor_contacts=[];seen=set()
    for index,contact in enumerate(selected):
        _need(contact.get('owner') in [FELT,FLOOR],'foreign support owner')
        identity=contact['assembly'];_need(identity in groups,'missing retained support assembly group')
        _need(len(records.get(identity,[]))==1,'missing or duplicate assembly source record')
        point=_finite(contact['point'],3);direction=_finite(contact['direction'],3)
        _need(direction==[0,1,0],'unexpected source support normal')
        token=_digest(contact);_need(token not in seen,'duplicate original contact');seen.add(token)
        target=_point(groups[identity]['matrix'],point)
        expected=.008 if contact['owner']==FELT else 0.
        _need(abs(target[1]-expected)<1e-10,'transformed foot height changed')
        row=dict(id=identity+':contact:'+str(index),source_index=index,source_record=copy.deepcopy(contact),assembly=identity,group=groups[identity]['id'],delta_transform=copy.deepcopy(groups[identity]['matrix']),target_point=target)
        (felt_contacts if contact['owner']==FELT else floor_contacts).append(row)
    _need({c['assembly'] for c in felt_contacts}==OWNERS,'eight exact felt-supported owners required')
    _need(len(felt_contacts)==25 and len(floor_contacts)==12,'original support contact census changed')
    protected=[[c['target_point'][0]-MARGIN,c['target_point'][2]-MARGIN,c['target_point'][0]+MARGIN,c['target_point'][2]+MARGIN] for c in floor_contacts]
    islands=[]
    for identity in sorted(OWNERS):
        contacts=[c for c in felt_contacts if c['assembly']==identity];points=[c['target_point'] for c in contacts]
        room_matches=[room for room in rooms if all(_inside(room,p) for p in points)]
        _need(len(room_matches)==1,'felt support outside or across room walls')
        if len(points)==1:
            source=records[identity][0];a,b,c,d=_rect(source['rect']);m=groups[identity]['matrix']
            corners=[_point(m,[x,.018,-y]) for x,y in itertools.product([a,c],[b,d])]
            rect=[min(p[0] for p in corners),min(p[2] for p in corners),max(p[0] for p in corners),max(p[2] for p in corners)]
            # Retain the complete actual stock-base footprint, with contact margin too.
            rect=[min(rect[0],points[0][0]-MARGIN),min(rect[1],points[0][2]-MARGIN),max(rect[2],points[0][0]+MARGIN),max(rect[3],points[0][2]+MARGIN)]
        else:rect=[min(p[0] for p in points)-MARGIN,min(p[2] for p in points)-MARGIN,max(p[0] for p in points)+MARGIN,max(p[2] for p in points)+MARGIN]
        clipped=_clip(rect,room_matches[0])
        required=[_clip([p[0]-MARGIN,p[2]-MARGIN,p[0]+MARGIN,p[2]+MARGIN],room_matches[0]) for p in points]
        if len(points)==1:required=[clipped]
        _need(not any(_overlap(need,p) for need in required for p in protected),'protected floor foot conflicts with required felt support: '+identity)
        islands.append(dict(assembly=identity,rect=clipped,unclipped_rect=rect,room_bounds=room_matches[0],contacts=[c['id'] for c in contacts],source_base_record=copy.deepcopy(records[identity][0]) if len(points)==1 else None,required_support_rectangles=required))
    pieces=[]
    for island in islands:
        remaining=[island['rect']]
        for cut in protected:remaining=[piece for rect in remaining for piece in _subtract(rect,cut)]
        pieces.extend(remaining)
    union=_union(pieces);stocks=[]
    for index,rect in enumerate(union):
        a,b,c,d=rect
        plan_rect=[a-origin[0],b+origin[1],c-origin[0],d+origin[1]]
        u0,v0,u1,v1=plan_rect
        vertices=[(x,y,z) for z in [0.,.008] for y in [v0,v1] for x in [u0,u1]]
        stocks.append(dict(name='CobblerFeltIsland_%02d'%index,owner=CELL,role='supporting_felt_field',material_family='soot',source_record_id=FELT,vertices=vertices,faces=list(FACES),plan_rect_m=plan_rect,godot_rect_m=rect,bottom_m=0.,top_m=.008,closed_volume_m3=(c-a)*(d-b)*.008,disposal_authorized=False))
    return dict(stocks=stocks,proof=dict(source_felt_record=copy.deepcopy(felt),source_felt_record_sha256=_digest(felt),native_source_bindings=copy.deepcopy(bindings),native_asset_sha256=construction['asset_sha256'],input_canonical_hashes=dict(plan=_digest(plan),original_layout=_digest(original_layout),retained_equipment=_digest(retained_equipment),construction=_digest(construction)),required_contact_edge_m=MARGIN,protected_floor_halfwidth_m=MARGIN,felt_contacts=felt_contacts,floor_contacts=floor_contacts,protected_floor_rectangles=protected,assembly_islands=islands,rooms_godot=rooms,field_bottom_y=0.,field_top_y=.008,source_read_scope='Declared actual native/source inputs; caller pins supplied bytes before export',disposal_authorized=False,admission='SOURCE_SUPPORT_GEOMETRY_ONLY_NOT_RUNTIME_OR_ART_ACCEPTANCE'))


def stocks(plan,original_layout,retained_equipment,construction):
    return build(plan,original_layout,retained_equipment,construction)['stocks']
