"""Rebuild passive V2 city elevations against retained base and roof authorities."""
from pathlib import Path
import collections, hashlib, json, math, re, sys, os
import bpy, bmesh
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').exists())
sys.path.insert(0,str(ROOT/'art/blender/scripts'))
from fabrication_native_batch import material,partition,export
from city_horizon_geometry import cornice_ring
OUT=Path(os.environ.get('CITY_ELEVATIONS_REVIEW_DIR',str(ROOT/'tmp/v2-city-rework-20261018')));OUT.mkdir(exist_ok=True,parents=True)
profiles=json.loads((ROOT/'art/data/city_elevations/source_plan.json').read_text())
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
report=json.loads((ROOT/'art/blender/city_closure_construction.json').read_text())
rows=report['original_records'];groups={p['id']:p for p in profiles['buildings']}
source_rows=json.loads((ROOT/'art/blender/city_shells_consumed_layout.json').read_text())['source_records']
def group(n):return '_'.join(n.split('_')[:3]) if n.startswith(('site_nbr_','site_back_','site_far_')) else '_'.join(n.split('_')[:2])
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/city_closure.blend'))
original={o.name.removesuffix('__RetainedStock'):o for o in bpy.data.collections['ClosedConstruction'].objects}
rings={o.name.removesuffix('__JoinedParapet'):o for o in bpy.data.collections['ClosedParapets'].objects}
assert len(original)==335 and len(rings)==25
for o in bpy.context.scene.objects:
    o.hide_render=True;o.hide_set(True)
    # Blender must not silently suffix the new portable material ABI with .001.
    if o.library is None:o.name='RetainedReference_'+o.name
exports=bpy.data.collections.new('V2CityElevations');bpy.context.scene.collection.children.link(exports)
buffers=collections.defaultdict(lambda:([],[]));stats=[];window_rows=[]
hand_origins={};clock_hands=[];architecture_checks=[];portal_rows=[];townhouse_details=[];court_details=[]
def add(name,key,verts,faces):
    vv,ff=buffers[(name,key)];start=len(vv);vv.extend(verts);ff.extend(tuple(start+i for i in f) for f in faces)
def box(name,key,lo,hi):
    assert all(b>a for a,b in zip(lo,hi)),(name,key,lo,hi)
    x,y,z=lo;X,Y,Z=hi
    add(name,key,[(x,y,z),(X,y,z),(X,Y,z),(x,Y,z),(x,y,Z),(X,y,Z),(X,Y,Z),(x,Y,Z)],[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)])
def copied(name,key,obj):
    add(name,key,[tuple(obj.matrix_world@v.co) for v in obj.data.vertices],[tuple(p.vertices) for p in obj.data.polygons])
def local_box(name,key,origin,tangent,out,lo,hi):
    x,y,z=lo;X,Y,Z=hi
    vv=[origin+tangent*a+out*b+Vector((0,0,c)) for a,b,c in [(x,y,z),(X,y,z),(X,Y,z),(x,Y,z),(x,y,Z),(X,y,Z),(X,Y,Z),(x,Y,Z)]]
    # tangent x out = +Z for a right-handed cell. All four facades use it.
    add(name,key,[tuple(p) for p in vv],[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)])
def curtain_panel(name,origin,tangent,out,left,right,low,high,depth,seed):
    """Closed thin cloth with a continuous pleated silhouette, behind the pane."""
    steps=max(12,math.ceil((right-left)/.035));verts=[];faces=[]
    for i in range(steps+1):
        x=left+(right-left)*i/steps
        front=-depth+.025+.010*math.sin(i/steps*math.tau*3+seed)
        for y,z in [(front,low),(front,high),(front-.004,low),(front-.004,high)]:
            verts.append(tuple(origin+tangent*x+out*y+Vector((0,0,z))))
    for i in range(steps):
        a=i*4;b=(i+1)*4
        faces.extend([(a,a+1,b+1,b),(a+2,b+2,b+3,a+3),(a,b,b+2,a+2),(a+1,a+3,b+3,b+1)])
    faces.extend([(0,2,3,1),(steps*4,steps*4+1,steps*4+3,steps*4+2)])
    add(name,'linen',verts,faces)

def profile_stock(name,key,origin,tangent,out,points,back,front):
    """Closed metric planar stock; front faces outward on all four elevations."""
    assert front>back and len(points)>=3
    points=list(points)
    area=sum(x*Z-X*z for (x,z),(X,Z) in zip(points,points[1:]+points[:1]))
    if area<0:points.reverse()
    if tangent.cross(Vector((0,0,1))).dot(out)>0:points.reverse()
    n=len(points)
    vv=[tuple(origin+tangent*x+out*y+Vector((0,0,z))) for y in [back,front] for x,z in points]
    ff=[tuple(range(n)),tuple(range(2*n-1,n-1,-1))]
    ff += [(i,i+n,j+n,j) for i,j in zip(range(n),list(range(1,n))+[0])]
    add(name,key,vv,ff)

def arch_stock(name,key,origin,tangent,out,cx,spring,half,rise,width,back,front,steps=6):
    inner=[(cx-half*math.cos(i*math.pi/steps),spring+rise*math.sin(i*math.pi/steps)) for i in range(steps+1)]
    outer=[(cx-(half+width)*math.cos(i*math.pi/steps),spring+(rise+width)*math.sin(i*math.pi/steps)) for i in range(steps+1)]
    for i in range(steps):profile_stock(name,key,origin,tangent,out,[inner[i],inner[i+1],outer[i+1],outer[i]],back,front)

def factory_tower(name,p,seat):
    tower=p['architecture']['tower'];x,y,X,Y=tower['rect'];cx=(x+X)/2;cy=(y+Y)/2
    width=X-x;assert abs(width-(Y-y))<1e-6
    base=seat;wall=base+float(tower['wall_height_m']);height=float(tower['roof_height_m']);half=width/2+.15
    box(name,p['wall_key'],(x,y,base),(X,Y,wall))
    # A closed roof volume with a curved profile, four raised hip seams and a cap.
    levels=[(wall+height*i/10,half*(.28+.72*math.cos(i*math.pi/20))) for i in range(11)]
    vv=[(cx+a*r,cy+b*r,z) for z,r in levels for a,b in [(-1,-1),(1,-1),(1,1),(-1,1)]]
    ff=[(3,2,1,0),tuple(range(40,44))]
    for i in range(10):
        for j in range(4):ff.append((i*4+j,i*4+(j+1)%4,(i+1)*4+(j+1)%4,(i+1)*4+j))
    add(name,'copper_aged',vv,ff)
    for a,b in [(-1,-1),(1,-1),(1,1),(-1,1)]:
        points=[Vector((cx+a*r,cy+b*r,z)) for z,r in levels]
        vertices=[]
        for i,at in enumerate(points):
            along=(points[min(i+1,10)]-points[max(i-1,0)]).normalized()
            across=Vector((-b,a,0)).normalized();other=along.cross(across).normalized()
            vertices.extend(tuple(at+.055*(across*math.cos(k*math.tau/6)+other*math.sin(k*math.tau/6))) for k in range(6))
        faces=[tuple(reversed(range(6))),tuple(range(60,66))]
        faces += [(i*6+j,i*6+(j+1)%6,(i+1)*6+(j+1)%6,(i+1)*6+j) for i in range(10) for j in range(6)]
        add(name,'copper_aged',vertices,faces)
    cap=levels[-1][1]+.12
    box(name,'copper_aged',(cx-cap,cy-cap,wall+height),(cx+cap,cy+cap,wall+height+.18))
    faces=[('south',Vector((cx,y,0)),Vector((1,0,0)),Vector((0,-1,0))),('east',Vector((X,cy,0)),Vector((0,1,0)),Vector((1,0,0))),('north',Vector((cx,Y,0)),Vector((-1,0,0)),Vector((0,1,0))),('west',Vector((x,cy,0)),Vector((0,-1,0)),Vector((-1,0,0)))]
    for face,origin,u,out in faces:
        center=base+1.8
        profile_stock(name,p['wall_key'],origin,u,out,[(-width/2,wall),(-width/2,wall+.06),(0,wall+1.05),(width/2,wall+.06),(width/2,wall)],-.10,.14)
        circle=[(math.cos(i*math.tau/48)*1.06,center+math.sin(i*math.tau/48)*1.06) for i in range(48)]
        profile_stock(name,'enamel',origin,u,out,circle,.15,.20)
        for i in range(48):
            a=i*math.tau/48;b=(i+1)*math.tau/48
            profile_stock(name,'copper_aged',origin,u,out,[(math.cos(a)*1.07,center+math.sin(a)*1.07),(math.cos(b)*1.07,center+math.sin(b)*1.07),(math.cos(b)*1.18,center+math.sin(b)*1.18),(math.cos(a)*1.18,center+math.sin(a)*1.18)],.13,.25)
        for tick in range(12):
            angle=tick*math.tau/12
            points=[(r*math.sin(angle)+w*math.cos(angle),center+r*math.cos(angle)-w*math.sin(angle)) for r,w in [(.84,-.025),(.97,-.025),(.97,.025),(.84,.025)]]
            profile_stock(name,'iron_blackened',origin,u,out,points,.205,.23)
        for kind,length,width_hand,period in [('hour',.62,.09,720),('minute',.88,.055,60)]:
            identity=name+'__clock_'+face+'_'+kind
            layer=.048 if kind=='minute' else 0.
            profile_stock(identity,'iron_blackened',origin,u,out,[(-width_hand,-.13+center),(width_hand,-.13+center),(width_hand,center+length*.75),(0,center+length),(-width_hand,center+length*.75)],.24+layer,.28+layer)
            pivot=origin+out*(.26+layer)+Vector((0,0,center));hand_origins[identity]=pivot
            clock_hands.append(dict(part=identity+'__iron_blackened',pivot=[pivot.x,pivot.z,-pivot.y],normal=[out.x,out.z,-out.y],period_minutes=period))
        profile_stock(name,'copper_aged',origin,u,out,[(math.cos(i*math.tau/16)*.12,center+math.sin(i*math.tau/16)*.12) for i in range(16)],.27,.36)
    architecture_checks.append(dict(building=name,tower_rect=[x,y,X,Y],tower_seat=seat,tower_top=wall+height+.18,arch_windows=0))

def facade_frames(rect,depth):
    x,y,X,Y=rect
    return [
        (Vector((X,y,0)),Vector((-1,0,0)),Vector((0,-1,0)),X-x),
        (Vector((X,Y-depth,0)),Vector((0,-1,0)),Vector((1,0,0)),Y-y-2*depth),
        (Vector((x,Y,0)),Vector((1,0,0)),Vector((0,1,0)),X-x),
        (Vector((x,y+depth,0)),Vector((0,1,0)),Vector((-1,0,0)),Y-y-2*depth)]

def townhouse_cornice(name,p,rect,roof):
    origin,u,out,width=facade_frames(rect,float(p['reveal_depth']))[int(p['architecture']['front_side'])]
    # The neighboring sash/sills project into this narrow reservation gap.
    # Scale decorative depth only; retain the seated back faces and stock width.
    projection=.78
    def stock(key,lo,hi):
        lo=(lo[0],lo[1]*projection if lo[1]>0 else lo[1],lo[2])
        hi=(hi[0],hi[1]*projection if hi[1]>0 else hi[1],hi[2])
        local_box(name,key,origin,u,out,lo,hi)
    bottom=roof-.20
    # Four shaped bearing consoles join the timber fascia, with dentils and
    # raised panels between them. Closed stocks, not surface decals.
    terraces=int(p['architecture']['terraces']);unit=width/terraces
    positions=[k*unit+.40+i*(unit-.80)/3 for k in range(terraces) for i in range(4)]
    for at in positions:
        profile_stock(name,'wood_dark',origin+u*at,out,u,[(d*projection if d>0 else d,z) for d,z in [(-.03,bottom-.54),(.14,bottom-.54),(.18,bottom-.28),(.32,bottom-.09),(.42,bottom),(-.03,bottom)]],-.095,.095)
    stock('wood_dark',(0,-.03,bottom),(width,.43,roof+.27))
    stock('wood_dark',(-.12,-.04,roof+.27),(width+.12,.52,roof+.41))
    for left,right in zip(positions,positions[1:]):
        if right-left<.9:continue
        stock('wood_dark',(left+.22,.43,bottom+.09),(right-.22,.48,roof+.17))
    for i in range(28*terraces):
        at=(i+.5)*width/(28*terraces)
        stock('wood_dark',(at-.05,.30,bottom-.06),(at+.05,.45,bottom))
    # A low, physically mapped masonry plinth; no six-metre concrete podium.
    pitch=width/(3*terraces);door_width=1.45
    cursor=0.
    for k in range(terraces):
        center=(k*3+.5)*pitch
        left=center-door_width*.5;right=center+door_width*.5
        stock('limestone',(cursor,-.04,0),(left,.025,.53))
        for z in [.18,.36]:stock('limestone',(cursor,.025,z),(left,.042,z+.025))
        cursor=right
    stock('limestone',(cursor,-.04,0),(width,.025,.53))
    for z in [.18,.36]:stock('limestone',(cursor,.025,z),(width,.042,z+.025))
    point=origin+u*(width*.5)+out*(.52*projection)+Vector((0,0,roof+.34))
    townhouse_details.append(dict(building=name,brackets=4*terraces,terraces=terraces,storeys=3,probe=list(point),normal=list(out),finish='wood_dark'))


def turned_stock(name,key,center,profile,sides=12,flute=0.):
    """Closed seated column/baluster, including its base and capital profile."""
    vv=[]
    for z,r in profile:
        for i in range(sides):
            a=i*math.tau/sides;radius=r*(1.-flute*(i%2))
            vv.append(tuple(center+Vector((math.cos(a)*radius,math.sin(a)*radius,z))))
    ff=[tuple(reversed(range(sides))),tuple(range((len(profile)-1)*sides,len(profile)*sides))]
    ff += [(j*sides+i,j*sides+(i+1)%sides,(j+1)*sides+(i+1)%sides,(j+1)*sides+i) for j in range(len(profile)-1) for i in range(sides)]
    add(name,key,vv,ff)

def court_apartment(name,p,rect,top,cap_row):
    a=p['architecture'];front=int(a['front_side']);depth=float(p['reveal_depth'])
    frames=facade_frames(rect,depth);origin,u,out,length=frames[front]
    width=float(a['recess_width_m']);inset=float(a['recess_depth_m']);left=(length-width)/2;right=left+width
    # A genuine sky-open shallow court, wholly outside the retained roof field.
    x,y,X,Y=rect;cut_points=[origin+u*t-out*d for t,d in [(left,0),(right,0),(left,inset),(right,inset)]]
    cut=[min(v.x for v in cut_points),min(v.y for v in cut_points),max(v.x for v in cut_points),max(v.y for v in cut_points)]
    roof_rect=list(cap_row['rect']);dx=cap_row['registration_offset_x'];roof_rect[0]+=dx;roof_rect[2]+=dx
    assert cut[2]<=roof_rect[0] or cut[0]>=roof_rect[2] or cut[3]<=roof_rect[1] or cut[1]>=roof_rect[3],(name,'court cuts retained roof',cut,roof_rect)
    count=0
    for side,frame in enumerate(frames):
        if side==front:continue
        q=dict(p,_frames=[(side,frame)])
        count+=facade(name,q,rect,0.,top)
    for start,end,back,bays,entry in [(0,left,0,int(a['side_bays']),False),(left,right,inset,1,True),(right,length,0,int(a['side_bays']),False)]:
        at=origin+u*start-out*back
        q=dict(p,_frames=[(front,(at,u,out,end-start))],_bays=bays,_entry=entry,_entry_width=1.45,_entry_height=2.65,_entry_arch=entry,_arch_top=entry,_top_width=float(a['stair_window_width_m']),_palladian=entry and a['style']=='cambridge',_six_over_one=a['style']=='elm')
        count+=facade(name,q,rect,0.,top)
        local_box(name,'limestone',at,u,out,(0,-depth,0),(end-start,.035,.52))
    for at in [left,right]:
        # Full-height masonry returns close the recess without a hidden roof.
        local_box(name,p['wall_key'],origin,u,out,(at-depth,-inset,0),(at,0,top))
    # Complement the exact original top cap; subtract the court from each annulus strip.
    A,B,C,D=roof_rect
    panels=[(x,y,X,B),(x,D,X,Y),(x,B,A,D),(C,B,X,D)]
    for l,b,r,t in panels:
        if l>=r or b>=t:continue
        L=max(l,cut[0]);R=min(r,cut[2]);B0=max(b,cut[1]);T=min(t,cut[3])
        pieces=[(l,b,r,t)] if L>=R or B0>=T else [(l,b,r,B0),(l,T,r,t),(l,B0,L,T),(R,B0,r,T)]
        for l0,b0,r0,t0 in pieces:
            if r0>l0 and t0>b0:box(name,'roof_bitumen',(l0,b0,top),(r0,t0,top+.26))
    # Clockwise complete wall perimeter, including both court returns.
    outline=[(X,Y),(x,Y),(x,y),(X,y)]
    first=Vector((origin.x,origin.y));last=first+Vector((u.x,u.y))*length
    edge=next(i for i in range(4) if (Vector(outline[i])-Vector((last.x,last.y))).length<depth+.001 and (Vector(outline[(i+1)%4])-first).length<depth+.001)
    # Use exact wall corner endpoints rather than the reveal-trimmed side frame.
    corners=[(origin+u*t-out*d) for t,d in [(right,0),(right,inset),(left,inset),(left,0)]]
    outline[edge+1:edge+1]=[(v.x,v.y) for v in corners]
    if sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(outline,outline[1:]+outline[:1]))>0:outline.reverse()
    for projection,bottom,high in [(.10,top-.18,top+.05),(.24,top+.05,top+.22)]:
        vv,ff=cornice_ring(outline,projection,bottom,high);add(name,'wood_dark' if a['style']=='cambridge' else 'limestone',vv,ff)
    # Portico is a supported assembly: foundation, profiled columns/pilasters,
    # architrave, roof deck and railing. Door belongs to closed passive stock.
    center=length/2;roof=3.05;porch=width-.25
    local_box(name,'limestone',origin,u,out,(left+.08,-inset,.0),(right-.08,.02,.12))
    for side in [-1,1]:
        c=origin+u*(center+side*(porch*.5-.35))-out*.28
        if a['style']=='elm':
            turned_stock(name,'limestone',c,[(.12,.30),(.22,.30),(.28,.23),(.38,.20),(2.65,.17),(2.74,.25),(2.88,.25)],16,.035)
        else:
            local_box(name,'limestone',origin,u,out,(center+side*(porch*.5-.35)-.16,-.55,.12),(center+side*(porch*.5-.35)+.16,-.14,2.88))
            for delta in [-.075,0,.075]:
                local_box(name,'limestone',origin,u,out,(center+side*(porch*.5-.35)+delta-.01,-.14,.38),(center+side*(porch*.5-.35)+delta+.01,-.12,2.64))
    local_box(name,'limestone',origin,u,out,(left+.10,-inset-.02,2.88),(right-.10,.10,roof))
    local_box(name,'limestone',origin,u,out,(left+.03,-inset-.03,roof),(right-.03,.14,roof+.14))
    key='limestone' if a['style']=='elm' else 'iron_blackened'
    for i in range(13):
        t=left+.25+(width-.50)*i/12;c=origin+u*t-out*.015
        if key=='limestone':turned_stock(name,key,c,[(roof+.14,.065),(roof+.20,.065),(roof+.27,.035),(roof+.42,.060),(roof+.50,.035),(roof+.62,.060)],8)
        else:local_box(name,key,origin,u,out,(t-.014,-.03,roof+.14),(t+.014,0,roof+.63))
    local_box(name,key,origin,u,out,(left+.13,-.065,roof+.62),(right-.13,.035,roof+.70))
    if a['style']=='cambridge':
        for l,r,back in [(0,left,0),(left,right,inset),(right,length,0)]:
            local_box(name,'limestone',origin,u,out,(l,-back-.14,top+.22),(r,-back+.02,top+.32))
            local_box(name,'limestone',origin,u,out,(l,-back-.16,top+.82),(r,-back+.04,top+.93))
            for i in range(max(2,int((r-l)/.48))):
                t=l+.15+(r-l-.30)*i/(max(2,int((r-l)/.48))-1)
                turned_stock(name,'limestone',origin+u*t-out*(back+.06),[(top+.32,.060),(top+.39,.060),(top+.48,.038),(top+.65,.070),(top+.74,.035),(top+.82,.055)],8)
    # Modillions are seated under the front cornice; no per-brick geometry.
    for i in range(int(length/.55)):
        t=(i+.5)*length/int(length/.55)
        if left-.08<t<right+.08:continue
        local_box(name,'limestone',origin,u,out,(t-.045,-.03,top-.32),(t+.045,.16,top-.12))
    # Open court ray above the porch must reach its deck, never a roof slab.
    probe=origin+u*center-out*(inset*.5)+Vector((0,0,top+.8))
    court_details.append(dict(building=name,style=a['style'],front_side=front,recess_depth_m=inset,recess_width_m=width,outline=outline,void_probe=list(probe),porch_top=roof+.14,roof_height=top,entry_count=1))
    return count

def facade(name,p,rect,z0,z1):
    depth=float(p['reveal_depth']);recess=float(p['window_recess']);assert 0<recess<depth
    factory=p.get('architecture',{}).get('type')=='sohmer_factory'
    townhouse=p.get('architecture',{}).get('type')=='hunters_point_italianate'
    x,y,X,Y=rect;count=0;floor_count=max(1,round((z1-z0)/p['storey_height']));floor_h=(z1-z0)/floor_count
    intervals=[(z0+i*floor_h,z0+i*floor_h+floor_h) for i in range(floor_count)]
    if 'floor_heights' in p:
        levels=[0.]
        for h in p['floor_heights']:
            assert h>2.5
            levels.append(levels[-1]+h)
        assert any(abs(z0-v)<.00002 for v in levels) and any(abs(z1-v)<.00002 for v in levels),(name,z0,z1,levels)
        intervals=[(a,b) for a,b in zip(levels,levels[1:]) if a>=z0-.00002 and b<=z1+.00002]
    for side,(origin,tangent,out,length) in p.get('_frames',list(enumerate(facade_frames(rect,depth)))):
        if (townhouse and side not in [int(p['architecture']['front_side']),(int(p['architecture']['front_side'])+2)%4]) or (p['detail_faces']=='inward' and out.dot(-origin)<=0):
            # Secondary outward elevations retain closed mapped masonry;
            # concentrate physical window stock on the principal city-facing elevations.
            local_box(name,p['wall_key'],origin,tangent,out,(0,-depth,z0),(length,0,z1))
            continue
        bays=int(p.get('_bays',3*int(p['architecture']['terraces']) if townhouse else max(1,math.floor(length/p['bay_pitch']))));pitch=length/bays
        for floor,(a,b) in enumerate(intervals):
            floor_h=b-a
            for bay in range(bays):
                left=bay*pitch;right=left+pitch;cx=(left+right)/2;w=min(p['window_width'],pitch-.6);h=min(p['window_height'],floor_h-.7)
                # Very short retained crowns are solid masonry, never squashed windows.
                if h<.9 or w<.6:
                    local_box(name,p['wall_key'],origin,tangent,out,(left,-depth,a),(right,0,b));continue
                arched=factory or (townhouse and side==int(p['architecture']['front_side'])) or (p.get('_arch_top',False) and floor==len(intervals)-1 and bay==bays//2)
                portal=(factory and floor==0 and side in [0,3] and bay==bays//2) or (townhouse and floor==0 and side==int(p['architecture']['front_side']) and bay%3==0) or (p.get('_entry',False) and floor==0 and bay==bays//2)
                if p.get('_arch_top',False) and floor==len(intervals)-1 and bay==bays//2:w=float(p.get('_top_width',w))
                if portal:w=min(float(p.get('_entry_width',1.45 if townhouse else 2.0)),pitch-.35);h=float(p.get('_entry_height',3.2));arched=arched or bool(p.get('_entry_arch',False))
                low=a+(.10 if portal else .60);high=low+h;wl=cx-w/2;wr=cx+w/2
                # Four disjoint closed masonry stocks form a genuine 260 mm reveal.
                for lo,hi in [((left,-depth,a),(wl,0,b)),((wr,-depth,a),(right,0,b)),((wl,-depth,a),(wr,0,low)),((wl,-depth,high),(wr,0,b))]:local_box(name,p['wall_key'],origin,tangent,out,lo,hi)
                if arched:
                    rise=.28 if portal and p.get('_entry',False) else float(p['architecture']['arch_rise_m']);spring=high-rise
                    arch_width=w*.5 if p.get('_palladian',False) and floor==len(intervals)-1 else w
                    if arch_width<w:
                        for l,r in [(wl,cx-arch_width/2),(cx+arch_width/2,wr)]:
                            local_box(name,p['wall_key'],origin,tangent,out,(l,-depth,spring),(r,0,high+.04))
                            local_box(name,'limestone',origin,tangent,out,(l-.025,-.08,spring),(r+.025,.04,spring+.10))
                    # Closed spandrels cut the square opening to a true segmental head.
                    for step in range(6):
                        a0=step*math.pi/6;a1=(step+1)*math.pi/6
                        l=cx-arch_width*.5*math.cos(a0);r=cx-arch_width*.5*math.cos(a1)
                        z=spring+rise*math.sin(a0);Z=spring+rise*math.sin(a1)
                        profile_stock(name,p['wall_key'],origin,tangent,out,[(l,z),(r,Z),(r,high+.04),(l,high+.04)],-depth,0)
                    arch_stock(name,'limestone' if townhouse else p['wall_key'],origin,tangent,out,cx,spring,arch_width/2,rise,.12,-.08,.09 if townhouse else .035)
                    if townhouse and not portal:
                        # Projecting hood and two supporting corbels, with actual
                        # contact at the hood spring rather than floating blocks.
                        for edge in [wl-.10,wr+.10]:
                            local_box(name,'limestone',origin,tangent,out,(edge-.055,-.03,spring-.19),(edge+.055,.16,spring+.005))
                    arch_stock(name,p['sash'],origin,tangent,out,cx,spring,arch_width/2-.055,rise-.025,.055,-recess-.044,-recess)
                # Glazed, closed backing: these passive shells imply no accessible interior.
                local_box(name,'mirror_aged',origin,tangent,out,(wl+.045,-recess-.054,low+.045),(wr-.045,-recess-.044,high-.045))
                local_box(name,'wood_dark',origin,tangent,out,(wl+.045,-depth,low+.045),(wr-.045,-depth+.01,high-.045))
                seed=int(p['variation_seed']);pattern=floor*7+bay*3+side+seed
                treatment=p['window_treatment']
                assert treatment in ['roller','draped','mixed']
                if (pattern%5 == 0 if factory else pattern%5 != 0):
                    if treatment=='draped' or (treatment=='mixed' and pattern%3==0):
                        gather=w*[.23,.31,.42][(floor+bay+seed)%3]
                        curtain_panel(name,origin,tangent,out,wl+.05,wl+gather,low+.05,high-.05,depth,seed)
                        curtain_panel(name,origin,tangent,out,wr-gather,wr-.05,low+.05,high-.05,depth,seed+1)
                    else:
                        drop=[.29,.52,.76,1.][(floor+bay+side+seed)%4]
                        local_box(name,'linen',origin,tangent,out,(wl+.05,-depth+.012,high-h*drop),(wr-.05,-depth+.02,high-.045))
                frame_top=high-(.28 if portal and p.get('_entry',False) else float(p['architecture']['arch_rise_m'])) if arched else high
                for lo,hi in [((wl,-recess-.044,low),(wl+.055,-recess,frame_top)),((wr-.055,-recess-.044,low),(wr,-recess,frame_top)),((wl+.055,-recess-.044,low),(wr-.055,-recess,low+.055)),((wl+.055,-recess-.044,frame_top-.055),(wr-.055,-recess,frame_top)),((wl+.055,-recess-.038,(low+high)/2-.025),(wr-.055,-recess+.014,(low+high)/2+.025))]:local_box(name,p['sash'],origin,tangent,out,lo,hi)
                if p.get('_six_over_one',False) and not portal:
                    for division in [-1,1]:
                        at=cx+division*w/6
                        local_box(name,p['sash'],origin,tangent,out,(at-.014,-recess-.038,(low+high)/2),(at+.014,-recess+.008,frame_top-.055))
                    middle=(frame_top+(low+high)/2)/2
                    local_box(name,p['sash'],origin,tangent,out,(wl+.055,-recess-.038,middle-.014),(wr-.055,-recess+.008,middle+.014))
                if p.get('_palladian',False) and floor==len(intervals)-1 and bay==bays//2:
                    for direction in [-1,1]:
                        at=cx+direction*w*.25
                        local_box(name,p['sash'],origin,tangent,out,(at-.035,-recess-.044,low),(at+.035,-recess+.02,frame_top))
                if p['window_joinery']=='paired_sash':
                    local_box(name,p['sash'],origin,tangent,out,(cx-.025,-recess-.044,low+.055),(cx+.025,-recess+.014,high-.055))
                else:assert p['window_joinery']=='single_sash'
                local_box(name,'limestone',origin,tangent,out,(wl-.08,-.23,low-.07),(wr+.08,float(p['sill_projection']),low))
                if not arched:local_box(name,p['lintel_key'],origin,tangent,out,(wl-.09,-.08,high),(wr+.09,.025,high+float(p['lintel_height'])))
                if portal:
                    # Passive closed factory doors: solid leaves and raised fields,
                    # with an upper glazed transom, not another ground-floor sash.
                    for l,r in [(wl+.06,cx-.025),(cx+.025,wr-.06)]:
                        local_box(name,'door_paint',origin,tangent,out,(l,-recess-.01,low+.04),(r,-recess+.07,a+2.2))
                        for bottom,top_field in [(low+.18,a+.95),(a+1.10,a+2.0)]:
                            local_box(name,'door_paint',origin,tangent,out,(l+.08,-recess+.07,bottom),(r-.08,-recess+.10,top_field))
                    for direction in [-1,1]:
                        local_box(name,'bronze_sheet',origin,tangent,out,(cx+direction*.18-.025,-recess+.10,a+1.0),(cx+direction*.18+.025,-recess+.16,a+1.4))
                    point=origin+tangent*(cx-w*.25)+Vector((0,0,a+1.5))
                    portal_rows.append(dict(building=name,side=side,point=list(point),front=-recess+.10))
                    if townhouse:
                        # Seated pilasters, console capitals and a closed triangular
                        # pediment; the source's raised stoop is adapted to street level.
                        for edge in [wl-.17,wr+.17]:
                            local_box(name,'limestone',origin,tangent,out,(edge-.07,-.03,a),(edge+.07,.13,high+.12))
                            local_box(name,'limestone',origin,tangent,out,(edge-.11,-.03,high+.04),(edge+.11,.23,high+.16))
                        profile_stock(name,'limestone',origin,tangent,out,[(wl-.32,high+.16),(wr+.32,high+.16),(cx,high+.64)],-.03,.23)
                count+=1
                window_rows.append(dict(building=name,side=side,floor=floor,bay=bay,center=list(origin+tangent*cx+Vector((0,0,(low+high)/2))),width=w,height=h,recess_m=recess,
                    pane_sample=list(origin+tangent*(cx+w*.22)+Vector((0,0,high-.14 if portal and p.get('_entry',False) else (low+high)/2+h*.2)))))
    return count
for name,p in groups.items():
    assert p['massing'] in ['straight_eave','single_upper_setback']
    factory=p.get('architecture',{}).get('type')=='sohmer_factory'
    townhouse=p.get('architecture',{}).get('type')=='hunters_point_italianate'
    first_window=len(window_rows)
    rr=[r for r in rows if group(r['id'])==name];ss=sorted([r for r in rr if re.search(r'_s\d+$',r['id'])],key=lambda r:r['z0'])
    last=ss[-1];dx=last['registration_offset_x'];top=last['z0']+last['h'];rect0=list(ss[0]['rect']);rect0[0]+=dx;rect0[2]+=dx
    final_rect=list(last['rect']);final_rect[0]+=dx;final_rect[2]+=dx
    for r in rr:
        suffix=r['id'][len(name)+1:]
        if ('vertical_profile' in p or townhouse) and (suffix.startswith('base') or suffix=='bcorn'):continue
        if re.fullmatch('s[0-9]+',suffix) or suffix.startswith('par_'):continue
        if re.fullmatch('c[0-9]+',suffix) and r is not last and suffix!='c'+last['id'].rsplit('_s',1)[1]:continue
        key=r['key']
        if factory and (re.fullmatch('c[0-9]+',suffix) or suffix=='bulk_c'):key='roof_bitumen'
        if suffix.startswith('base') and key=='concrete':key='limestone'
        if suffix.startswith('base'):
            x,y,X,Y=r['rect'];x+=dx;X+=dx
            if min(X-x,Y-y)>1.5 and r['h']>2:
                box(name,'limestone',(x,y,r['z0']),(X,Y,r['z0']+.2))
                base_profile=dict(p,wall_key='limestone')
                facade(name,base_profile,[x,y,X,Y],r['z0']+.2,r['z0']+r['h'])
                continue
        if suffix=='bcorn':key='limestone'
        copied(name,key,original[r['id']])
    factory=p.get('architecture',{}).get('type')=='sohmer_factory'
    townhouse=p.get('architecture',{}).get('type')=='hunters_point_italianate'
    ring=rings[name];cap=max(v.co.z for v in ring.data.vertices)
    for face in ([] if factory else ring.data.polygons):
        key=next(r['key'] for r in rr if '_par_' in r['id']) if all(ring.data.vertices[i].co.z>=cap-.00002 for i in face.vertices) else p['wall_key']
        add(name,key,[tuple(ring.matrix_world@ring.data.vertices[i].co) for i in face.vertices],[tuple(range(len(face.vertices)))])
    # One continuous primary shaft and at most one upper setback, retaining all
    # final roof planes and original roof equipment bearing stock exactly.
    court=p.get('architecture',{}).get('type')=='court_apartment'
    split=top if factory or townhouse or court else last['z0'] if len(ss)>1 else top
    if court:
        cap_row=next(r for r in rr if r['id']==name+'_c'+last['id'].rsplit('_s',1)[1])
        n=court_apartment(name,p,rect0,top,cap_row)
    else:n=facade(name,p,rect0,0. if 'vertical_profile' in p or townhouse else ss[0]['z0'],split)
    if len(ss)>1 and not factory and not townhouse and not court:
        n+=facade(name,p,final_rect,split,top)
        # Closed 120 mm roof terrace course; never a stack of projecting cornices.
        x,y,X,Y=rect0;u,v,U,V=final_rect
        for lo,hi in [((x,y,split-.12),(X,v,split)),((x,V,split-.12),(X,Y,split)),((x,v,split-.12),(u,V,split)),((U,v,split-.12),(X,V,split))]:box(name,'roof_bitumen',lo,hi)
    if factory:
        cap_row=next(r for r in rr if r['id']==name+'_c'+last['id'].rsplit('_s',1)[1]);roof=cap_row['z0']+cap_row['h']
        a,b,c,d=rect0;u,v,U,V=cap_row['rect'];u+=dx;U+=dx
        for lo,hi in [((a-.16,b-.16,top),(c+.16,v,roof)),((a-.16,V,top),(c+.16,d+.16,roof)),((a-.16,v,top),(u,V,roof)),((U,v,top),(c+.16,V,roof))]:box(name,'roof_bitumen',lo,hi)
        outline=[(c,d),(a,d),(a,b),(c,b)]
        vv,ff=cornice_ring(outline,.16,roof,roof+.18);add(name,p['wall_key'],vv,ff)
        for floor in p['architecture']['belt_floors']:
            edge=sum(p['floor_heights'][:floor]);vv,ff=cornice_ring(outline,.11,edge-.07,edge+.07);add(name,p['wall_key'],vv,ff)
        tx,ty,tX,tY=p['architecture']['tower']['rect']
        for lo,hi in [((a-.07,ty,0),(a+.02,ty+.20,roof)),((a-.07,tY-.20,0),(a+.02,tY,roof)),((tx,d-.02,0),(tx+.20,d+.07,roof)),((tX-.20,d-.02,0),(tX,d+.07,roof))]:box(name,p['wall_key'],lo,hi)
        factory_tower(name,p,roof)
        architecture_checks[-1]['arch_windows']=n
    if townhouse:townhouse_cornice(name,p,rect0,top+.26)
    stats.append(dict(id=name,old_setbacks=len(ss)-1,new_setbacks=0 if factory or townhouse or court else min(1,len(ss)-1),windows=len(window_rows)-first_window,roof_height=top,shaft_bottom=0. if townhouse or court else ss[0]['z0'],setback_height=split,original_roof_rect=final_rect,main_rect=rect0))
    if 'vertical_profile' in p:
        old_last=next(r for r in source_rows if r['id']==last['id'])
        stats[-1].update(previous_roof_height=old_last['z0']+old_last['h'],floor_heights=p['floor_heights'])
# Retired continuous cornice bands can still carry original guy anchors.
# Retain only a local closed bearing saddle outside the new terrace boundary;
# adjoining top planes meet without coplanar overlap or a repeated facade band.
anchor_seats=[]
contact_sources={asset:json.loads((ROOT/f'game/tests/fixtures/orison_city_{asset}.json').read_text()) for asset in ['masts','aerials','tanks']}
source_by_id={row['id']:row for row in rows};stats_by_id={row['id']:row for row in stats}
for asset,data in contact_sources.items():
    for contact in data['contacts']:
        owner=source_by_id.get(contact['owner'])
        if owner is not None and '_par_' in owner['id'] and groups[group(owner['id'])].get('architecture',{}).get('type')=='sohmer_factory':
            # The former inset parapet retires. Keep a seated local anchor pier,
            # not a ghost wall running through the enlarged roof.
            identity=group(owner['id']);roof=stats_by_id[identity]['roof_height']+.26
            footprint=[contact['point']]+contact['footprint'];dx=owner['registration_offset_x']
            ox,oy,oX,oY=owner['rect'];ox+=dx;oX+=dx
            x=max(ox,min(p[0] for p in footprint)-.05);X=min(oX,max(p[0] for p in footprint)+.05)
            y=max(oy,min(p[1] for p in footprint)-.05);Y=min(oY,max(p[1] for p in footprint)+.05)
            assert X>x and Y>y
            box(identity,groups[identity]['wall_key'],(x,y,roof),(X,Y,owner['z0']+owner['h']))
            anchor_seats.append(dict(contact=contact['id'],source_owner=owner['id'],pieces=[[x,y,X,Y]],bottom=roof,top=owner['z0']+owner['h']))
            continue
        if owner is None or not re.search(r'_c[0-9]+$',owner['id']):continue
        identity=group(owner['id']);building=stats_by_id[identity]
        top=owner['z0']+owner['h']
        if abs(top-building['setback_height'])>.00002:continue
        footprint=[contact['point']]+contact['footprint'];dx=owner['registration_offset_x']
        ox,oy,oX,oY=owner['rect'];ox+=dx;oX+=dx
        x=max(ox,min(p[0] for p in footprint)-.02);X=min(oX,max(p[0] for p in footprint)+.02)
        y=max(oy,min(p[1] for p in footprint)-.02);Y=min(oY,max(p[1] for p in footprint)+.02)
        u,v,U,V=building['main_rect']
        pieces=[(x,y,X,min(Y,v)),(x,max(y,V),X,Y),(x,max(y,v),min(X,u),min(Y,V)),(max(x,U),max(y,v),X,min(Y,V))]
        built=[]
        for a,b,c,d in pieces:
            if c<=a or d<=b:continue
            box(identity,'limestone',(a,b,owner['z0']),(c,d,top));built.append([a,b,c,d])
        if built:anchor_seats.append(dict(contact=contact['id'],source_owner=owner['id'],pieces=built,bottom=owner['z0'],top=top))

materials={};draws=[]
for (name,key),(vv,ff) in sorted(buffers.items()):
    p=groups[name.split('__')[0]];tint=p['wall_tint'] if key==p['wall_key'] else p['frame_tint'] if key=='door_paint' else [.18,.23,.25,1] if key=='mirror_aged' else [1,1,1,1]
    finish=dict(catalog_key=key,tint=tint,pigment=1.,normal=.65,roughness=1.)
    if key=='mirror_aged':finish.update(metallic=.65,roughness=.45,normal=.12)
    cache_key=(key,tuple(tint))
    if cache_key not in materials:materials[cache_key]=material(ROOT,name+'__'+key,finish,catalog)
    mat=materials[cache_key]
    if key=='mirror_aged':
        bsdf=mat.node_tree.nodes['Principled BSDF'];bsdf.inputs['Metallic'].default_value=0;bsdf.inputs['Alpha'].default_value=.28;bsdf.inputs['Transmission Weight'].default_value=.5;bsdf.inputs['IOR'].default_value=1.52
    mesh=bpy.data.meshes.new(name+'__Raw');mesh.from_pydata(vv,[],ff);mesh.update();stock=bpy.data.objects.new(mesh.name,mesh)
    # A per-building local origin keeps even submillimetre UVs representable.
    center=Vector(((min(v[0] for v in vv)+max(v[0] for v in vv))/2,(min(v[1] for v in vv)+max(v[1] for v in vv))/2,0))
    if name in hand_origins:center=hand_origins[name]
    for v in mesh.vertices:v.co-=center
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.triangulate(bm,faces=list(bm.faces))
    zero=[f for f in bm.faces if (f.verts[1].co-f.verts[0].co).cross(f.verts[2].co-f.verts[0].co).length_squared==0]
    if zero:bmesh.ops.delete(bm,geom=zero,context='FACES_ONLY')
    bm.to_mesh(mesh);bm.free()
    obj=partition(exports,name+'__'+key,[stock],finish,mat,Matrix.Translation(center),catalog)
    assert obj.name==name+'__'+key,(name,key,obj.name)
    obj.hide_render=False;obj.hide_set(False);draws.append(obj)
    bpy.data.objects.remove(stock);bpy.data.meshes.remove(mesh)
# Every rebuild must pass actual native bearing and window-depth rays before
# exporting or opening Godot. These remain source checks, never runtime proof.
vertices=[];faces=[];face_owners=[]
for obj in draws:
    offset=len(vertices);vertices.extend(obj.matrix_world@v.co for v in obj.data.vertices)
    faces.extend(tuple(offset+i for i in f.vertices) for f in obj.data.polygons);face_owners.extend([obj.name]*len(obj.data.polygons))
bvh=BVHTree.FromPolygons(vertices,faces,all_triangles=True)
native_bearings=0;native_windows=0;native_failures=[]
for asset,data in contact_sources.items():
    for contact in data['contacts']:
        normal=Vector(contact['normal'])
        for sample in [contact['point']]+contact['footprint']:
            point=Vector(sample);hit,n,index,distance=bvh.ray_cast(point+normal*.03,-normal,.06);native_bearings+=1
            if hit is None or (hit-point).length>=.0001:native_failures.append(dict(kind='bearing',id=contact['id'],sample=sample))
for window in window_rows:
    # Sample inside an actual pane, clear of both sash rails and paired mullions.
    point=Vector(window['pane_sample'])
    normal=[Vector((0,-1,0)),Vector((1,0,0)),Vector((0,1,0)),Vector((-1,0,0))][window['side']]
    hit,n,index,distance=bvh.ray_cast(point+normal*.1,-normal,.4);expected=point-normal*(window['recess_m']+.044);native_windows+=1
    if hit is None or (hit-expected).length>=.0001 or not face_owners[index].endswith('__mirror_aged'):native_failures.append(dict(kind='pane',window=window))
for portal in portal_rows:
    normal=[Vector((0,-1,0)),Vector((1,0,0)),Vector((0,1,0)),Vector((-1,0,0))][portal['side']]
    point=Vector(portal['point']);expected=point+normal*portal['front']
    hit,n,index,distance=bvh.ray_cast(point+normal*.1,-normal,.4)
    if hit is None or (hit-expected).length>.0001 or not face_owners[index].endswith('__door_paint'):native_failures.append(dict(kind='closed_portal',portal=portal))
for study in architecture_checks:
    foundation_vertices=[];foundation_faces=[]
    for obj in draws:
        if not obj.name.startswith(study['building']+'__') or obj.name.split('__')[-1] not in ['roof_bitumen','bronze_sheet','concrete']:continue
        offset=len(foundation_vertices);foundation_vertices.extend(obj.matrix_world@v.co for v in obj.data.vertices)
        foundation_faces.extend(tuple(offset+i for i in f.vertices) for f in obj.data.polygons)
    foundation=BVHTree.FromPolygons(foundation_vertices,foundation_faces,all_triangles=True)
    x,y,X,Y=study['tower_rect'];study['tower_support_samples']=0;study['clock_face_normals']=0
    for a in [.05,.5,.95]:
        for b in [.05,.5,.95]:
            point=Vector((x+(X-x)*a,y+(Y-y)*b,study['tower_seat']))
            hit,n,index,distance=foundation.ray_cast(point+Vector((0,0,.03)),Vector((0,0,-1)),.06)
            if hit is None or (hit-point).length>.0001:native_failures.append(dict(kind='tower_support',point=list(point)))
            study['tower_support_samples']+=1
    for hand in [h for h in clock_hands if h['period_minutes']==720]:
        pivot=Vector((hand['pivot'][0],-hand['pivot'][2],hand['pivot'][1]));normal=Vector((hand['normal'][0],-hand['normal'][2],hand['normal'][1]));u=normal.cross(Vector((0,0,1)))
        point=pivot+u*.55+Vector((0,0,.2))
        hit,n,index,distance=bvh.ray_cast(point+normal*.15,-normal,.4)
        if hit is None or n.dot(normal)<.99 or not face_owners[index].endswith('__enamel'):native_failures.append(dict(kind='clock_dial_front',part=hand['part']))
        study['clock_face_normals']+=1
for detail in townhouse_details:
    point=Vector(detail['probe']);normal=Vector(detail['normal'])
    hit,n,index,distance=bvh.ray_cast(point+normal*.1,-normal,.4)
    if hit is None or (hit-point).length>.0001 or n.dot(normal)<.99 or not face_owners[index].endswith('__'+detail['finish']):native_failures.append(dict(kind='townhouse_cornice_front',detail=detail))
for detail in court_details:
    point=Vector(detail['void_probe'])
    hit,n,index,distance=bvh.ray_cast(point,Vector((0,0,-1)),detail['roof_height'])
    if hit is None or hit.z>detail['porch_top']+.0001:native_failures.append(dict(kind='court_void_obstructed',building=detail['building'],hit=list(hit) if hit is not None else None))
assert not native_failures,native_failures[:12]
native_checks=dict(bearing_samples=native_bearings,window_samples=native_windows,failures=native_failures,tolerance_m=.0001)
print('CITY NATIVE CONTACTS',native_checks,flush=True)

# Native source and portable export are rebuilt together, before review cameras.
proof=export(ROOT,'city_elevations',exports,staged_output=True)
def sha(path):
    raw=path.read_bytes()
    if path.suffix in {'.json','.py','.gd'}:raw=raw.replace(b'\r\n',b'\n')
    return hashlib.sha256(raw).hexdigest()
runtime={'schema':1,'buildings':[{k:p[k] for k in ['id','wall_key','wall_tint','frame_tint']} for p in profiles['buildings']], 'clock_hands':clock_hands}
projection=ROOT/'game/data/orison_v2/exterior/city_elevations.json'
projection.write_text(json.dumps(runtime,indent=2)+'\n',encoding='utf-8',newline='\n')
bindings=[ROOT/p for p in ['art/data/city_elevations/source_plan.json','art/blender/city_closure.blend','art/blender/city_closure_construction.json','art/blender/city_shells.blend','art/blender/city_shells_registration.json','game/data/runtime_material_sets.json','game/data/orison_v2/exterior/city_elevations.json','game/tests/fixtures/orison_city_masts.json','game/tests/fixtures/orison_city_aerials.json','game/tests/fixtures/orison_city_tanks.json','game/scripts/building/orison_v2_city_shells.gd','art/blender/scripts/city_horizon_geometry.py','art/blender/scripts/fabrication_native_batch.py','art/blender/scripts/fabrication_normals.py','art/blender/scripts/fabrication_uvs.py']]+[Path(__file__)]
for key in {key for name,key in buffers}:
    bindings.extend(ROOT/'game/assets/building/textures'/f for f in catalog[key]['files'])
construction={k:report[k] for k in ['original_records','source_parapet_stocks','closed_joined_parapets','corner_stations','capture_offsets_godot','skyline_views_godot']}
construction.update(portals=portal_rows,clock_hands=clock_hands,architecture_checks=architecture_checks,townhouse_details=townhouse_details,court_details=court_details,anchor_seats=anchor_seats,native_checks=native_checks,evidence_class='INERT',classification='ADAPTATION',scope='Passive physical city elevations. No occupied rooms or runtime acceptance inferred.',buildings=stats,windows=len(window_rows),window_rows=window_rows,parts=[dict(name=o.name,key=o.name.split('__')[-1],triangles=len(o.data.polygons)) for o in draws],triangles=sum(len(o.data.polygons) for o in draws),asset_sha256=sha(ROOT/'game/assets/props/city_elevations.glb'),source_bindings={p.relative_to(ROOT).as_posix():sha(p) for p in bindings},export_check=proof)
for dest in ['art/blender/city_elevations_construction.json','game/tests/fixtures/orison_city_elevations.json']:
    (ROOT/dest).write_text(json.dumps(construction,indent=2)+'\n',encoding='utf-8',newline='\n')
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=12
scene.render.resolution_x=1280;scene.render.resolution_y=800;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('NeutralReview');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.6,.7,.8,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.7
d=bpy.data.lights.new('ReviewSun','SUN');d.energy=3;d.angle=.08;sun=bpy.data.objects.new(d.name,d);scene.collection.objects.link(sun);sun.rotation_euler=(.45,-.35,-.7)
d=bpy.data.cameras.new('Review');cam=bpy.data.objects.new(d.name,d);scene.collection.objects.link(cam);scene.camera=cam;d.lens=32
for label,at,target in [('north_skyline',(3,-12,24),(0,40,29)),('west_neighbors',(-7,-23,8),(-28,-2,10)),('south_skyline',(5,10,25),(0,-55,25)),('near_elevation',(9,-20,9),(21,-1,9))]:
    cam.location=at;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(OUT/(label+'.png'));bpy.ops.render.render(write_still=True)
# Review cameras/lights remain disposable; the saved production native precedes them.
(OUT/'construction.json').write_text(json.dumps(dict(evidence_class='INERT',scope='Read-only native visual review of the rebuilt source; no runtime acceptance',buildings=stats,windows=len(window_rows),window_rows=window_rows,partitions=len(draws),triangles=sum(len(o.data.polygons) for o in draws)),indent=2)+'\n',encoding='utf-8')
print('CITY ELEVATIONS NATIVE',len(stats),'buildings',len(window_rows),'recessed windows',len(draws),'partitions',flush=True)
