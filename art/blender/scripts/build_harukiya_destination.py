"""Native Harukiya destination architecture, authored from one metric layout.

Blender --background --python-exit-code 1 --python this.py -- --report DIR [--render]
No world, actor, interaction, time, light or acoustic authority is exported.
Closed editable stocks, metre UVs and the shared tangent-qualified export path.
"""
from pathlib import Path
import argparse, collections, hashlib, json, math, shutil, struct, sys, time
import bpy, bmesh, numpy as np
from mathutils import Matrix, Quaternion, Vector
from mathutils.bvhtree import BVHTree

ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
sys.path.insert(0,str(ROOT/'art/blender/scripts'))
from fabrication_native_batch import material,partition,export

FAMILY='harukiya_destination'
parser=argparse.ArgumentParser();parser.add_argument('--report',required=True,type=Path)
parser.add_argument('--render',action='store_true')
parser.add_argument('--view',default='all',choices=['all','overview','seating','services'])
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
args.report.mkdir(parents=True,exist_ok=True); started=time.time()
layout_path=ROOT/'game/data/orison_v2/harukiya_destination_layout.json'
data=json.loads(layout_path.read_text()); arch=data['architecture']
# This ground-floor corridor serves both the stair and darts. Include the
# actual outward stringer, not only the 1.10m clear flight datum.
assert arch['stair']['x0']-.07-arch['darts_backstop']['rect'][2]>=.76,'Darts partition closes the real west stair approach'
catalog_path=ROOT/'game/data/runtime_material_sets.json'
catalog=json.loads(catalog_path.read_text())['materials']

def sha(p):
    p=Path(p);raw=p.read_bytes()
    return hashlib.sha256(raw if p.suffix in ['.blend','.glb','.png'] else raw.replace(b'\r\n',b'\n')).hexdigest()

outputs=[ROOT/'art/blender'/f'{FAMILY}.blend',ROOT/'game/assets/props'/f'{FAMILY}.glb',ROOT/'art/blender'/f'{FAMILY}_inventory.json']
prior=[]
for p in outputs+[layout_path]:
    if p.exists():
        keep=args.report/'prior'/p.name;keep.parent.mkdir(exist_ok=True)
        if keep.exists():raise FileExistsError('Use a fresh report folder: '+str(keep))
        shutil.copy2(p,keep);assert sha(p)==sha(keep)
        prior.append({'source':str(p),'preserved':str(keep),'sha256':sha(p)})
(args.report/'PRIOR_CUSTODY.json').write_text(json.dumps(prior,indent=2))

bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
scene=bpy.context.scene;scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
stock=bpy.data.collections.new('Closed editable destination stocks');scene.collection.children.link(stock)
draws=bpy.data.collections.new('Runtime metric material partitions');scene.collection.children.link(draws)
finishes=data['materials'];mats={k:material(ROOT,'Destination_'+k,f,catalog) for k,f in finishes.items()}
pieces=[];checks=[];seat_contacts=[];support_contacts=[]

def solid(name,verts,faces,key,group):
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    assert all(e.is_manifold for e in bm.edges),(name,'open stock')
    volume=bm.calc_volume(signed=True);assert volume>1e-12,(name,'nonpositive volume',volume)
    bm.to_mesh(mesh);bm.free();mesh.materials.append(mats[key])
    obj=bpy.data.objects.new(name,mesh);stock.objects.link(obj);pieces.append((obj,key,group))
    checks.append({'name':name,'material':key,'assembly':group,'volume_m3':volume,'closed':True})
    return obj

def box(name,at,size,key='oak',group='Architecture',yaw=0):
    rot=Matrix.Rotation(math.radians(yaw),3,'Z'); at=Vector(at);half=Vector(size)/2
    verts=[at+rot@Vector((x*half.x,y*half.y,z*half.z)) for z in [-1,1] for y in [-1,1] for x in [-1,1]]
    return solid(name,verts,[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)],key,group)

def slab(name,rect,bottom,top,key='floor',group='Architecture'):
    x0,y0,x1,y1=rect;assert x1>x0 and y1>y0 and top>bottom
    return box(name,((x0+x1)/2,(y0+y1)/2,(bottom+top)/2),(x1-x0,y1-y0,top-bottom),key,group)

def rod(name,a,b,r,key='metal',group='Architecture',n=12):
    a,b=Vector(a),Vector(b);w=(b-a).normalized()
    seed=Vector((0,0,1)) if abs(w.z)<.9 else Vector((0,1,0))
    u=seed.cross(w).normalized();v=w.cross(u)
    verts=[p+(u*math.cos(i*math.tau/n)+v*math.sin(i*math.tau/n))*r for p in [a,b] for i in range(n)]
    faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]
    faces.extend((i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n))
    return solid(name,verts,faces,key,group)

def beam(name,a,b,width,depth,key='oak',group='Architecture'):
    a,b=Vector(a),Vector(b);axis=(b-a).normalized()
    # A closed rectangular timber whose local Z follows its actual bearings.
    q=axis.to_track_quat('Z','Y');half=Vector((width/2,depth/2,(b-a).length/2));at=(a+b)/2
    verts=[at+q@Vector((x*half.x,y*half.y,z*half.z)) for z in [-1,1] for y in [-1,1] for x in [-1,1]]
    return solid(name,verts,[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)],key,group)

def rail(name,a,b,z,height=1.1,group='Balcony'):
    a,b=Vector((*a,z)),Vector((*b,z));length=(b-a).length
    count=max(2,math.ceil(length/1.2)+1)
    for i in range(count):
        p=a.lerp(b,i/(count-1));box(name+' post '+str(i),p+Vector((0,0,height/2)),(.055,.055,height),'oak',group)
        box(name+' foot plate '+str(i),p+Vector((0,0,.008)),(.095,.095,.016),'brass',group)
    rod(name+' top handrail',a+Vector((0,0,height)),b+Vector((0,0,height)),.029,'oak',group,16)
    rod(name+' bottom rail',a+Vector((0,0,.10)),b+Vector((0,0,.10)),.011,'metal',group)
    n=max(2,math.ceil(length/.13))
    for i in range(1,n):
        p=a.lerp(b,i/n);rod(name+' iron baluster '+str(i),p+Vector((0,0,.10)),p+Vector((0,0,height-.04)),.008,'metal',group,8)

def seat(row):
    if row['kind']=='retained_stool':return
    name=row['id'];x,y,top=row['at'];floor=row['floor_z'];yaw=row['yaw_deg'];group='SeatingBalcony' if name.startswith('balcony') else 'SeatingFloor'
    rot=Matrix.Rotation(math.radians(yaw),3,'Z');origin=Vector((x,y,floor));height=top-floor
    def p(local):return origin+rot@Vector(local)
    def b(suffix,at,size,key='oak'):return box(name+' '+suffix,p(at),size,key,group,yaw)
    # All 19 new supports are independently editable; the native output batches
    # their common finishes. Local +Y is the sitter's forward direction.
    b('seat bearing',(0,0,height-.075),(.48,.50,.055))
    b('upholstered seat',(0,.005,height-.025),(.46,.48,.05),'cloth')
    for sx in [-1,1]:
        for sy in [-1,1]:
            b('leg '+str((sx,sy)),(sx*.192,sy*.194,(height-.10)/2),(.045,.045,height-.10))
        b('side seat apron '+str(sx),(sx*.20,0,height-.12),(.035,.43,.075))
        b('stretcher '+str(sx),(sx*.192,0,.15),(.024,.40,.026))
        b('back post '+str(sx),(sx*.198,-.225,.53),(.042,.042,.68))
    b('back top rail',(0,-.225,.87),(.45,.045,.065))
    b('lower back rail',(0,-.225,.53),(.43,.04,.055))
    if row['kind']=='bench':
        b('upholstered back',(0,-.208,.69),(.41,.05,.27),'cloth')
    else:
        for sx in [-.11,0,.11]:b('back spindle '+str(sx),(sx,-.225,.70),(.026,.022,.30))
    # Brass end caps add small material contrast without an oversized silhouette.
    for sx in [-1,1]:b('back cap '+str(sx),(sx*.198,-.225,.887),(.045,.045,.018),'brass')
    seat_contacts.append({'id':name,'at':row['at'],'floor_z':floor,'width_m':.46,'depth_m':.48,'yaw_deg':yaw,'support':row['support'],'native_stock':name+' upholstered seat'})

# Low raised stage, fitted plank floor and visible frontal fascia.
s=arch['stage'];x0,y0,x1,y1=s['rect'];z=s['floor_z']
slab('DestinationStage',s['rect'],s['base_z'],z-.018,'oak','Stage')
n=math.ceil((x1-x0)/.19);width=(x1-x0)/n
for i in range(n):slab('Stage oak board '+str(i),[x0+i*width+.001,y0,x0+(i+1)*width-.001,y1],z-.018,z,'floor','Stage')
box('Stage front nosing',((x0+x1)/2,y1-.02,z-.04),(x1-x0,.04,.08),'oak','Stage')
for x in [x0+.04,x1-.04]:box('Stage front brass corner '+str(x),(x,y1-.022,z-.035),(.08,.045,.07),'brass','Stage')
# Public step kept at the unoccupied stage-right edge, outside the microphone.
slab('Stage public intermediate step',[.25,-34.5,1.2,-34.20],-2.8,-2.69,'oak','Stage')

# Backstage openings are genuine gaps, not painted panels or collision holes.
b=arch['backstage'];bx0,by0,bx1,by1=b['rect'];bottom=b['floor_z'];top=b['partition_top_z'];oy0,oy1=b['stage_opening_y'];ox0,ox1=b['public_opening_x']
for n,r in [('south west wing',[1.2,by0,1.35,oy0]),('north west wing',[1.2,oy1,1.35,by1]),('north left',[1.35,by1-.10,ox0,by1]),('north right',[ox1,by1-.10,bx1,by1])]:
    slab('Backstage '+n,r,bottom,top,'partition','Backstage')
    slab('Backstage skirting '+n,r,bottom,bottom+.16,'oak','Backstage')
slab('Backstage west lintel',[1.2,oy0,1.35,oy1],top-.18,top,'oak','Backstage')
slab('Backstage north lintel',[ox0,by1-.1,ox1,by1],top-.18,top,'oak','Backstage')
for y in [oy0,oy1]:box('Backstage stage jamb '+str(y),(1.275,y,(top+bottom)/2),(.17,.065,top-bottom),'oak','Backstage')
for x in [ox0,ox1]:box('Backstage public jamb '+str(x),(x,by1-.05,(top+bottom)/2),(.065,.13,top-bottom),'oak','Backstage')
slab('Backstage stage intermediate step',[1.35,oy0,1.63,oy1],bottom,bottom+.11,'oak','Stage')
slab('Backstage stage upper threshold',[1.2,oy0,1.35,oy1],bottom,-2.58,'oak','Stage')
# Simple connected case shelf and dressing bench, away from the entrance paths.
box('Backstage bench top',(2.62,-37.28,-2.32),(1.75,.42,.08),'oak','Backstage')
for x in [1.89,3.35]:box('Backstage bench leg '+str(x),(x,-37.28,-2.58),(.07,.33,.44),'oak','Backstage')
box('Backstage lower case shelf',(2.62,-37.28,-2.62),(1.62,.35,.05),'oak','Backstage')
for i,x in enumerate([2.10,2.75,3.28]):box('Backstage luggage case '+str(i),(x,-37.28,-2.47),(.42,.29,.25),'cloth','Backstage')
box('Backstage dressing shelf',(3.75,-36.05,-1.85),(.28,1.55,.055),'oak','Backstage')
for y in [-36.7,-35.4]:
    beam('Dressing shelf diagonal bracket '+str(y),(3.92,y,-2.18),(3.62,y,-1.88),.035,.035,'metal','Backstage')
    box('Dressing shelf wall plate '+str(y),(3.94,y,-2.03),(.025,.10,.36),'metal','Backstage')
box('Backstage mirror backing',(3.955,-36.05,-1.17),(.04,.84,.98),'oak','Backstage')
box('Backstage aged mirror',(3.930,-36.05,-1.17),(.012,.74,.88),'mirror','Backstage')
for y in [-36.50,-35.60]:box('Backstage mirror side '+str(y),(3.912,y,-1.17),(.04,.055,1.0),'oak','Backstage')
for z in [-1.64,-.70]:box('Backstage mirror rail '+str(z),(3.912,-36.05,z),(.04,.94,.055),'oak','Backstage')
rod('Backstage coat rail',(1.65,-37.49,-.85),(3.1,-37.49,-.85),.016,'brass','Backstage',16)
for x in [1.65,3.1]:
    rod('Backstage coat bracket '+str(x),(x,-37.49,-.85),(x,-37.82,-.85),.011,'metal','Backstage')
    box('Backstage coat bearing '+str(x),(x,-37.84,-.85),(.12,.04,.14),'metal','Backstage')
for x in [1.85,2.15,2.45,2.75]:
    rod('Coat hook neck '+str(x),(x,-37.49,-.85),(x,-37.41,-.91),.006,'brass','Backstage',8)
    rod('Coat hook tip '+str(x),(x,-37.41,-.91),(x,-37.39,-.85),.006,'brass','Backstage',8)

# The existing well remains the only tall room. Gallery slab is 24cm deep.
bal=arch['balcony'];floor=bal['floor_z'];under=floor-bal['slab_depth']
for name,rect in [('DestinationBalconyNorth',bal['north_rect']),('DestinationBalconyReturn',bal['return_rect'])]:
    slab(name,rect,under,floor-.018,'oak','Balcony')
    x0,y0,x1,y1=rect;n=math.ceil((x1-x0)/.18);w=(x1-x0)/n
    for i in range(n):slab(name+' floorboard '+str(i),[x0+i*w+.001,y0,x0+(i+1)*w-.001,y1],floor-.018,floor,'floor','Balcony')
for i,(x,y,ground) in enumerate(bal['support_columns']):
    box('Balcony column '+str(i),(x,y,(ground+under)/2),(.12,.12,under-ground),'oak','Balcony')
    box('Balcony column base '+str(i),(x,y,ground+.035),(.18,.18,.07),'metal','Balcony')
    box('Balcony column capital '+str(i),(x,y,under-.045),(.24,.24,.09),'oak','Balcony')
    support_contacts.append({'id':'Balcony column '+str(i),'foot':[x,y,ground],'head':[x,y,under]})
rail('North gallery front',(-4.36,-33.20),(-1.69,-33.20),0,1.1)
rail('Gallery inner return',(-1.61,-33.25),(-1.61,-35.85),0,1.1)
rail('Gallery south return',(-1.61,-35.85),(.565,-35.85),0,1.1)
rail('Gallery east',(.565,-35.85),(.565,-31.045),0,1.1)
rail('Gallery north',(-5.54,-31.045),(.565,-31.045),0,1.1)
rail('Gallery stair side',(-4.36,-33.20),(-4.36,-32.12),0,1.1)
# Narrow bar ledges turn the gallery from an auditorium row into useful
# social seating. They stay wholly on the viewing side, outside rear aisles.
box('North viewing drinks ledge',(-3.025,-33.08,1.045),(2.67,.20,.045),'oak','Balcony')
box('Return viewing drinks ledge',(-1.49,-34.55,1.045),(.20,2.60,.045),'oak','Balcony')
for x in [-4.20,-3.02,-1.85]:
    beam('North drinks ledge bracket '+str(x),(x,-33.20,.85),(x,-33.02,1.02),.022,.022,'brass','Balcony')
for y in [-33.45,-34.55,-35.65]:
    beam('Return drinks ledge bracket '+str(y),(-1.61,y,.85),(-1.43,y,1.02),.022,.022,'brass','Balcony')

# Closed treads/risers and two bearing stringers leave a real open underside.
st=arch['stair'];sx0,sx1=st['x0'],st['x1'];sy0,sy1=st['flight_y'];z0=st['bottom_z'];going=st['going'];rise=st['rise']
for i in range(st['goings']):
    a=sy0+i*going;b=a+going;ztop=z0+(i+1)*rise
    slab('Stair tread '+str(i+1),[sx0-.035,a-.014,sx1+.035,b],ztop-.045,ztop,'floor','Stair')
    box('Stair riser '+str(i+1),((sx0+sx1)/2,a+.012,ztop-rise/2),(sx1-sx0,.024,rise),'oak','Stair')
    box('Stair nosing '+str(i+1),((sx0+sx1)/2,a-.008,ztop-.017),(sx1-sx0+.07,.025,.034),'oak','Stair')
for x in [sx0-.035,sx1+.035]:
    beam('Stair side stringer '+str(x),(x,sy0,z0+.05),(x,sy1,-.13),.07,.20,'oak','Stair')
    rod('Stair handrail '+str(x),(x,sy0-.05,z0+rise+1.0),(x,sy1,1.0),.028,'oak','Stair',16)
    for i in [0,3,6,9,12,15]:
        y=sy0+min(i,14)*going+.03;bottom=z0+(i+1)*rise if i<15 else 0
        top=z0+rise+1.0+(y-sy0)/(sy1-sy0)*(2.8-rise)
        box('Stair newel '+str((x,i)),(x,y,(bottom+top)/2),(.055,.055,top-bottom),'oak','Stair')
    for i in range(15):
        y=sy0+(i+.6)*going;bottom=z0+(i+1)*rise
        top=z0+rise+1.0+(y-sy0)/(sy1-sy0)*(2.8-rise)
        rod('Stair baluster '+str((x,i)),(x,y,bottom),(x,y,top),.008,'metal','Stair',8)
slab('DestinationStairUpperLanding',[sx0-.035,*[st['upper_landing_y'][0]],sx1+.035,st['upper_landing_y'][1]],under,0,'floor','Stair')
box('Stair final riser',((sx0+sx1)/2,sy1+.012,-rise/2),(sx1-sx0,.024,rise),'oak','Stair')
for x in [sx0-.035,sx1+.035]:
    box('Upper landing column '+str(x),(x,-31.09,(under-2.8)/2),(.09,.09,under+2.8),'oak','Stair')
rail('Stair landing west',(sx0-.035,-32.10),(sx0-.035,-31.045),0,1.1,'Stair')

# Retained counter stools stay in the cell. New seats are real closed stock.
l=arch['lounge'];slab('DestinationLoungeDeck',l['rect'],l['base_z'],l['floor_z'],'floor','Lounge')
slab('Lounge intermediate step',[2.1,-33.46,3.25,-33.20],-2.8,-2.71,'oak','Lounge')
for row in data['seats']:
    if not row['id'].startswith('floor_bench_'):seat(row)
# Continuous audience banquette, with individual cushions matching declared
# sitter contacts, shared base/back and compact arms. No new route obstruction.
audience=[s for s in data['seats'] if s['id'].startswith('floor_bench_')]
left=audience[0]['at'][0]-.41;right=audience[-1]['at'][0]+.41
box('DestinationAudienceBench seat bearing',((left+right)/2,-32.62,-2.405),(right-left,.50,.10),'oak','SeatingFloor')
box('DestinationAudienceBench front apron',((left+right)/2,-32.855,-2.48),(right-left,.045,.19),'oak','SeatingFloor')
box('DestinationAudienceBench continuous back',((left+right)/2,-32.385,-2.10),(right-left,.065,.60),'oak','SeatingFloor')
for row in audience:
    x,y,top=row['at'];name=row['id'];floor=row['floor_z']
    box(name+' upholstered seat',(x,y,top-.035),(.80,.48,.07),'cloth','SeatingFloor')
    box(name+' upholstered back',(x,-32.425,-2.105),(.80,.055,.45),'cloth','SeatingFloor')
    for dy in [-.185,.185]:box(name+' shared base leg '+str(dy),(x,y+dy,-2.615),(.065,.065,.37),'oak','SeatingFloor')
    seat_contacts.append({'id':name,'at':row['at'],'floor_z':floor,'width_m':.80,'depth_m':.48,'yaw_deg':row['yaw_deg'],'support':row['support'],'native_stock':name+' upholstered seat'})
for x in [left-.02,right+.02]:
    box('Banquette arm '+str(x),(x,-32.60,-2.17),(.07,.49,.055),'oak','SeatingFloor')
    box('Banquette end panel '+str(x),(x,-32.60,-2.39),(.055,.46,.43),'oak','SeatingFloor')
# Narrow drink shelves are deliberately beside seats, not in front of access.
for i,x in enumerate([-2.9,-2.0,-1.1]):
    box('Audience drink ledge '+str(i),(x,-32.65,-2.16),(.14,.28,.035),'oak','SeatingFloor')
    box('Audience drink ledge support '+str(i),(x,-32.65,-2.48),(.045,.045,.61),'oak','SeatingFloor')
for i,y in enumerate([-32.25,-31.55]):
    box('Lounge drink ledge '+str(i),(3.54,y,-1.98),(.28,.13,.035),'oak','Lounge')
    box('Lounge drink ledge support '+str(i),(3.54,y,-2.29),(.045,.045,.60),'oak','Lounge')
# Piano bench is fitted to the new keyboard's normal performer position.
p=s['piano_bench'];x,y,fz=p['at'];box('Piano bench seat',(x,y,fz+p['height']-.035),(p['width'],p['depth'],.07),'cloth','Stage')
for dx in [-.36,.36]:
    for dy in [-.13,.13]:box('Piano bench leg '+str((dx,dy)),(x+dx,y+dy,fz+.205),(.048,.048,.41),'oak','Stage')
# Two conventional timber PA cabinets bear on visible rear-wall brackets.
for i,x in enumerate([-4.04,.92]):
    box('Stage PA cabinet '+str(i),(x,-37.65,-1.08),(.36,.25,.72),'oak','Stage')
    box('Stage PA grille field '+str(i),(x,-37.518,-1.08),(.29,.016,.63),'cloth','Stage')
    for j in range(8):box('Stage PA grille louvre '+str((i,j)),(x,-37.505,-1.35+j*.075),(.30,.018,.014),'metal','Stage')
    box('Stage PA bracket shelf '+str(i),(x,-37.69,-1.465),(.40,.40,.045),'metal','Stage')
    for dx in [-.12,.12]:
        beam('Stage PA bracket brace '+str((i,dx)),(x+dx,-37.88,-1.78),(x+dx,-37.52,-1.49),.026,.026,'metal','Stage')
        box('Stage PA wall bearing '+str((i,dx)),(x+dx,-37.885,-1.63),(.07,.025,.38),'metal','Stage')

# A framed target partition, exact 2.37m oche and physically supported ledge.
d=arch['darts_backstop'];r=d['rect'];slab('Darts structural backstop',r,d['floor_z'],d['top_z'],'partition','Darts')
for x in [r[0]+.04,r[2]-.04]:box('Darts backstop upright '+str(x),(x,(r[1]+r[3])/2,(d['floor_z']+d['top_z'])/2),(.08,.13,d['top_z']-d['floor_z']),'oak','Darts')
box('Darts backstop top',((r[0]+r[2])/2,(r[1]+r[3])/2,d['top_z']-.03),(r[2]-r[0],.13,.06),'oak','Darts')
box('Darts brass oche',(data['relocations']['darts']['at'][0],d['oche_y'],-2.796),(.80,.035,.008),'brass','Darts')
ledge=arch['darts_ledge'];r=ledge['rect'];slab('Darts ledge',r,ledge['top_z']-.05,ledge['top_z'],'oak','Darts')
for x in [r[0]+.055,r[2]-.055]:
    for y in [r[1]+.055,r[3]-.055]:box('Darts ledge leg '+str((x,y)),(x,y,(ledge['floor_z']+ledge['top_z']-.05)/2),(.045,.045,ledge['top_z']-.05-ledge['floor_z']),'oak','Darts')
cue=data['relocations']['pool']['cue'];rod('Relocated pool cue',cue['p0'],cue['p1'],cue['radius'],'cue','PoolCue',16)

# Existing practical-light actors keep their power/flicker/audio. These stocks
# only close their newly measured ceiling contacts, with no duplicated shades.
for m in data['fixture_relocations']:
    a=Vector(m['at']);b=Vector(m['support_anchor']);span=(b-a).length
    assert span>=.009,(m['id'],'no physical fixture attachment')
    rod(m['id']+' fitted stem',a,b-Vector((0,0,.004)),.008,'metal','LightSupports')
    box(m['id']+' bearing plate',b-Vector((0,0,.002)),(.09,.09,.004),'metal','LightSupports')
    rod(m['id']+' lower collar',a,a+Vector((0,0,min(.015,span/2))),.013,'brass','LightSupports',12)
    for dx in [-.03,.03]:
        for dy in [-.03,.03]:rod(m['id']+' bearing screw '+str((dx,dy)),b+Vector((dx,dy,-.008)),b+Vector((dx,dy,-.004)),.003,'brass','LightSupports',8)
    support_contacts.append({'id':m['id'],'foot':m['at'],'head':m['support_anchor'],'kind':'fixture bearing'})

# Retain the original, head-fitted split clamp stocks exactly. Only the obsolete
# long stems/ceiling bearings are replaced; one clamp follows the raised offset.
service_source=ROOT/'art/blender/bar_pipe_supports_construction.json'
service=json.loads(service_source.read_text())
discard=['_Stem','_UpperCollar','_BearingPlate','_Fixing']
for change in data.get('pipe_support_adaptations',[]):
    identity=change['id'];shift=Vector(change['translation'])
    rows=[r for r in service['closed_stocks'] if r['assembly']==identity and not any(r['name'].startswith(identity+s) for s in discard)]
    names=[r['name'] for r in rows];lookup={r['name']:r for r in rows}
    with bpy.data.libraries.load(str(ROOT/change['source_blend']),link=False) as (available,loaded):
        assert all(n in available.objects for n in names),(identity,'missing original clamp stock')
        loaded.objects=names
    for original in loaded.objects:
        stock.objects.link(original);bpy.context.view_layer.update()
        source=lookup[original.name];key='pipe_brass' if source['key']=='brass_dull' else 'pipe_iron'
        vertices=[original.matrix_world@v.co+shift for v in original.data.vertices]
        solid('Rebound '+source['name'],vertices,[tuple(f.vertices) for f in original.data.polygons],key,'PipeSupports')
        bpy.data.objects.remove(original,do_unlink=True)
    contact=next(c for c in service['contacts'] if c['id']==identity)
    foot=Vector((contact['fixture_endpoint'][0],-contact['fixture_endpoint'][2],contact['fixture_endpoint'][1]))+shift
    bearing=Vector((foot.x,foot.y,change['bearing_z']))
    assert bearing.z-foot.z>.035,(identity,'short support fit')
    rod(identity+' shortened stem',foot+Vector((0,0,.012)),bearing-Vector((0,0,.004)),.006,'pipe_iron','PipeSupports',24)
    rod(identity+' new bearing collar',bearing-Vector((0,0,.016)),bearing-Vector((0,0,.004)),.016,'pipe_iron','PipeSupports',24)
    box(identity+' new bearing plate',bearing-Vector((0,0,.002)),(.09,.09,.004),'pipe_iron','PipeSupports')
    for i in range(4):
        a=math.pi*.25+i*math.pi*.5;at=bearing+Vector((.037*math.cos(a),.037*math.sin(a),0))
        rod(identity+' new fixing '+str(i),at-Vector((0,0,.007)),at-Vector((0,0,.004)),.003,'pipe_brass','PipeSupports',12)
    support_contacts.append({'id':identity,'foot':list(foot),'head':list(bearing),'kind':'original split clamp, new real bearing','source_stock_count':len(rows)})

def rounded_path(points,radius):
    pts=[Vector(p) for p in points];path=[pts[0]]
    for a,b,c in zip(pts,pts[1:],pts[2:]):
        u=(b-a).normalized();v=(c-b).normalized();angle=math.acos(max(-1,min(1,u.dot(v))))
        if angle<1e-5:continue
        trim=min(radius*math.tan(angle/2),(b-a).length*.35,(c-b).length*.35)
        r=trim/math.tan(angle/2);start=b-u*trim
        centre=start+(v-u*math.cos(angle)).normalized()*r;axis=u.cross(v).normalized()
        path.append(start)
        for j in range(1,9):path.append(centre+Matrix.Rotation(angle*j/8,3,axis)@(start-centre))
    path.append(pts[-1]);return path

pipe=data['pipe_adaptation'];assert pipe['path'][0]==pipe['source_record']['p0'] and pipe['path'][-1]==pipe['source_record']['p1']
path=rounded_path(pipe['path'],pipe['elbow_radius'])
profile=next(p['native_profile_yz'] for p in service['profiles'] if p['original']['id']==pipe['source_id'])
verts=[]
for i,at in enumerate(path):
    axis=(path[min(i+1,len(path)-1)]-path[max(i-1,0)]).normalized()
    q=Vector((1,0,0)).rotation_difference(axis)
    verts.extend(at+q@Vector((0,y,z)) for y,z in profile)
n=len(profile);faces=[tuple(reversed(range(n))),tuple(range((len(path)-1)*n,len(path)*n))]
for j in range(len(path)-1):
    for i in range(n):faces.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
offset_pipe=solid('Retained pipe1 with local raised stair offset',verts,faces,'pipe_metal','PipeOffset')
assert all(verts[i]==Vector(pipe['path'][0])+Vector((0,*profile[i])) for i in range(n)),'Original first endpoint profile changed'
assert all(verts[-n+i]==Vector(pipe['path'][-1])+Vector((0,*profile[i])) for i in range(n)),'Original last endpoint profile changed'
# A genuine low ceiling remains outside the well; tube stock cannot escape it.
well=arch['balcony']['well_rect'];outside=[v.z for v in verts if not (well[0]<=v.x<=well[2] and well[1]<=v.y<=well[3])]
assert not outside or max(outside)<=-.155,('Raised pipe enters original low ceiling',max(outside))

def glb_service_meshes(path,excluded):
    raw=path.read_bytes();length=struct.unpack_from('<I',raw,12)[0];g=json.loads(raw[20:20+length]);start=20+length
    size=struct.unpack_from('<I',raw,start)[0];binary=raw[start+8:start+8+size]
    def accessor(i):
        a=g['accessors'][i];v=g['bufferViews'][a['bufferView']];kind={5126:'<f4',5125:'<u4',5123:'<u2',5121:'u1'}[a['componentType']];width={'SCALAR':1,'VEC3':3}[a['type']]
        stride=v.get('byteStride',np.dtype(kind).itemsize*width);at=v.get('byteOffset',0)+a.get('byteOffset',0)
        return np.ndarray((a['count'],width),dtype=kind,buffer=binary,offset=at,strides=(stride,np.dtype(kind).itemsize)).copy()
    found=[]
    def visit(index,parent):
        node=g['nodes'][index]
        if 'matrix' in node:local=Matrix(np.array(node['matrix']).reshape((4,4)).T.tolist())
        else:
            r=node.get('rotation',[0,0,0,1]);local=Matrix.Translation(Vector(node.get('translation',[0,0,0])))@Quaternion((r[3],r[0],r[1],r[2])).to_matrix().to_4x4()@Matrix.Diagonal(Vector(node.get('scale',[1,1,1])+[1]))
        transform=parent@local;name=node.get('name','')
        if 'mesh' in node and name not in excluded:
            for primitive in g['meshes'][node['mesh']]['primitives']:
                points=[transform@Vector(v) for v in accessor(primitive['attributes']['POSITION'])]
                points=[Vector((v.x,-v.z,v.y)) for v in points]
                if name.startswith('F01_BAR_LT_POOL__'):points=[v+Vector((-1,0,0)) for v in points]
                indices=accessor(primitive['indices']).reshape((-1,3));found.append((name,points,indices))
        for child in node.get('children',[]):visit(child,transform)
    for index in g['scenes'][g.get('scene',0)]['nodes']:visit(index,Matrix.Identity(4))
    return found

# Include the intact cabinet's open leaves, not just its structural backstop.
# runtime_05 demonstrated that the old placement closes the stair approach.
cabinet_source=ROOT/'game/assets/props/bar_furniture.glb'
cabinet_rows=[row for row in glb_service_meshes(cabinet_source,set()) if row[0].startswith('DartsCabinet__')]
assert cabinet_rows,'Native darts cabinet partitions are missing'
move=data['relocations']['darts'];turn=Matrix.Rotation(math.radians(move['source_yaw_delta_deg']),3,'Z')
anchor=Vector(move['source_anchor']);target=Vector(move['at'])
cabinet_vertices=[];cabinet_faces=[]
for name,points,faces in cabinet_rows:
    offset=len(cabinet_vertices);cabinet_vertices.extend(target+turn@(point-anchor) for point in points)
    cabinet_faces.extend(tuple(offset+int(i) for i in face) for face in faces)
cabinet_tree=BVHTree.FromPolygons(cabinet_vertices,cabinet_faces,all_triangles=True)
nodes={row['id']:Vector(row['at']) for row in data['navigation']['nodes']}
a,b=nodes['west_bypass'],nodes['stair_approach'];cabinet_samples=[];cabinet_min=1e9;old_min=1e9
for t in np.linspace(0,1,math.ceil((b-a).length/.03)+1):
    feet=a.lerp(b,float(t))
    for z in np.linspace(feet.z+.345,feet.z+1.524-.33+.015,45):
        at=Vector((feet.x,feet.y,z));distance=cabinet_tree.find_nearest(at)[3]
        # Translating the query left reproduces the rejected cabinet .5m right.
        old_distance=cabinet_tree.find_nearest(at-Vector((.5,0,0)))[3]
        cabinet_min=min(cabinet_min,distance);old_min=min(old_min,old_distance)
    cabinet_samples.append(list(feet))
assert cabinet_min>.335,('Native cabinet obstructs west stair approach',cabinet_min)
assert old_min<.33,('Negative control no longer reproduces runtime_05 obstruction',old_min)
(args.report/'DARTS_CLEARANCE_PREFLIGHT.json').write_text(json.dumps({'evidence_class':'INERT','method':'Actual exported intact cabinet faces transformed independently in source metres; sampled player capsule axis; rejected pre-fix translation is the negative control. Actual motor remains required.','native_source_sha256':sha(cabinet_source),'minimum_distance_m':cabinet_min,'negative_control_distance_m':old_min,'radius_m':.33,'feet_samples':cabinet_samples},indent=2))

# Original cabinet and score-panel backs must bear on the front face, not
# disappear inside the new backstop. Keep original contacts/meshes immutable.
furniture_fixture=ROOT/'game/tests/fixtures/orison_bar_furniture.json'
original_furniture=json.loads(furniture_fixture.read_text())
assert sha(cabinet_source)==original_furniture['asset_sha256']
backstop=arch['darts_backstop'];front_y=backstop['rect'][1];support_rows=[];assembly_extents={}
all_furniture=glb_service_meshes(cabinet_source,set())
for assembly,identity in [('DartsCabinet','darts'),('ScorePanel','score_panel')]:
    row=data['relocations'][identity];rotation=Matrix.Rotation(math.radians(row['source_yaw_delta_deg']),3,'Z')
    transform=lambda p:Vector(row['at'])+rotation@(p-Vector(row['source_anchor']))
    points=[transform(p) for name,vertices,faces in all_furniture if name.startswith(assembly+'__') for p in vertices]
    assert points and max(p.y for p in points)<=front_y+.00003,(assembly,'buried behind backstop front')
    assembly_extents[identity]={'min_x':min(p.x for p in points),'max_x':max(p.x for p in points)}
    contacts=[c for c in original_furniture['contacts'] if c['id'].startswith(assembly+'_')]
    assert len(contacts)==4,(assembly,'original bearing count')
    for contact in contacts:
        p=contact['point'];at=transform(Vector((p[0],-p[2],p[1])))
        assert abs(at.y-front_y)<.00003 and backstop['rect'][0]<=at.x<=backstop['rect'][2] and backstop['floor_z']<=at.z<=backstop['top_z'],(contact['id'],list(at))
        support_rows.append({'id':contact['id'],'at_source_m':list(at),'front_plane_gap_m':abs(at.y-front_y)})
case_separation=assembly_extents['darts']['min_x']-assembly_extents['score_panel']['max_x']
backing_margin=assembly_extents['score_panel']['min_x']-backstop['rect'][0]
assert case_separation>0 and backing_margin>=0,('Original cabinet/panel must be separate and supported',case_separation,backing_margin)
(args.report/'DARTS_SUPPORT_PREFLIGHT.json').write_text(json.dumps({'evidence_class':'INERT','native_sha256':sha(cabinet_source),'original_fixture_sha256':sha(furniture_fixture),'front_source_y':front_y,'contacts':support_rows,'complete_assembly_x_separation_m':case_separation,'west_backing_margin_m':backing_margin,'scope':'Independent original native bearings and all vertices; actual loaded bearing rays and visual review remain required.'},indent=2))

# Include the imported retained support/fixture draws: those were the reason
# a new-geometry-only plan missed the obstruction in the first runtime proof.
retired={r['name'] for r in data['retire_native_parts']}
service_meshes=[]
for name in ['bar_pipe_supports','bar_fixture_mounts']:
    service_meshes+=glb_service_meshes(ROOT/'game/assets/props'/f'{name}.glb',retired)
service_meshes += [(obj.name,[v.co.copy() for v in obj.data.vertices],[tuple(p.vertices) for p in obj.data.polygons]) for obj,key,group in pieces if group in ['PipeSupports','PipeOffset','LightSupports']]
vertices=[];polys=[];owners=[]
for name,points,faces in service_meshes:
    offset=len(vertices);vertices.extend(points)
    for face in faces:polys.append(tuple(offset+int(i) for i in face));owners.append(name)
tree=BVHTree.FromPolygons(vertices,polys,all_triangles=False)
samples=[];minimum=1e9;nearest=None
def probe(feet,label):
    global minimum,nearest
    # Sample the vertical centre segment densely; .33m is the actual player
    # radius, and exact 1.524m standing height comes from PlayerController.
    local_min=1e9;obstacle=''
    for z in np.linspace(feet.z+.345,feet.z+1.524-.33+.015,45):
        hit=tree.find_nearest(Vector((feet.x,feet.y,z)))
        if hit[0] is not None and hit[3]<local_min:local_min=hit[3];obstacle=owners[hit[2]]
    if local_min<minimum:minimum=local_min;nearest={'label':label,'at':list(feet),'service':obstacle}
    assert local_min>.335,('Service intersects standing capsule',label,list(feet),local_min,obstacle)
    samples.append({'label':label,'feet':list(feet),'service_distance_m':local_min,'nearest':obstacle})
for y in np.linspace(-36.45,-31.55,100):
    if y<st['flight_y'][0]:z=-2.8
    elif y>=st['flight_y'][1]:z=0
    else:z=-2.8+(min(14,int((y-st['flight_y'][0])/st['going']))+1)*st['rise']
    probe(Vector((-4.95,y,z)),'ascending_stair')
chain=[(-4.95,-31.55,0),(-3.85,-31.55,0),(.2,-31.55,0),(.2,-34.5,0)]
for a,b in zip(chain,chain[1:]):
    a,b=Vector(a),Vector(b)
    for t in np.linspace(0,1,math.ceil((b-a).length/.06)+1):probe(a.lerp(b,float(t)),'upper_landing_gallery_return')
service_proof={'evidence_class':'INERT','method':'CPU BVH sampled real standing-capsule centre segment against new service geometry and retained imported pipe/fixture supports; independent actual motor remains required','radius_m':.33,'standing_height_m':1.524,'sample_count':len(samples),'minimum_service_distance_m':minimum,'nearest':nearest,'low_ceiling_outside_well_max_tube_z':max(outside),'original_endpoints_preserved':True,'original_profile_sides':n,'samples':samples}
(args.report/'SERVICE_CLEARANCE_PREFLIGHT.json').write_text(json.dumps(service_proof,indent=2))

# Meter-scale UV charts and per-corner handed tangents; no procedural runtime mesh.
groups=collections.defaultdict(list)
for obj,key,group in pieces:groups[(group,key)].append(obj)
parts=[]
for (group,key),objects in sorted(groups.items()):
    name='Destination_'+group+'_'+key
    obj=partition(draws,name,objects,finishes[key],mats[key],Matrix.Identity(4),catalog)
    xyz=np.array([v.co[:] for v in obj.data.vertices]);low=xyz.min(axis=0);high=xyz.max(axis=0)
    parts.append({'name':name,'material':key,'assembly':group,'triangles':len(obj.data.polygons),'aabb_source':{'min':low.tolist(),'max':high.tolist()}})
stock.hide_render=True;stock.hide_viewport=True;bpy.context.view_layer.update()
proof=export(ROOT,FAMILY,draws,material_names_only=True)
assert proof['status']=='PASS' and proof['triangles']<50000 and proof['primitives']<40,proof
assert sum(p['triangles'] for p in parts)==proof['triangles']
data['native_parts']=parts;data['seat_contacts']=seat_contacts;data['support_contacts']=support_contacts
data['status']='native export complete; Godot import, actual-body routes, sightlines and artistic acceptance pending'
layout_path.write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8',newline='\n')
bindings=[Path(__file__).resolve(),catalog_path]+[ROOT/'art/blender/scripts'/n for n in ['fabrication_native_batch.py','fabrication_chart_batch.py','fabrication_uvs.py','fabrication_normals.py','fabrication_grain.py','check_exported_tangents.py']]
bindings+=list({ROOT/'game/assets/building/textures'/p for f in finishes.values() for p in catalog[f['catalog_key']]['files']})
bindings += [service_source,ROOT/'art/blender/bar_pipe_supports.blend',ROOT/'game/assets/props/bar_pipe_supports.glb',ROOT/'game/assets/props/bar_fixture_mounts.glb']
bindings += [cabinet_source,furniture_fixture]
inventory={'evidence_class':'INERT','status':'native_export_pass','original_modeling':True,'blender_version':bpy.app.version_string,'closed_stock_count':len(checks),'closed_stocks':checks,'runtime_triangles':proof['triangles'],'draw_surfaces':proof['primitives'],'tangent_check':proof,'asset_sha256':sha(outputs[1]),'blend_sha256':sha(outputs[0]),'layout_sha256':sha(layout_path),'source_bindings':{p.relative_to(ROOT).as_posix():sha(p) for p in bindings},'no_new_images':True,'native_review':'pending','runtime_import_and_actual_body_clearance':'pending root integration','seat_count':len(data['seats']),'new_native_seats':len(seat_contacts),'retained_counter_stools':5,'known_limit':'Return-gallery far seats need actual stage sightline review; no original ceiling relief assumed.'}
outputs[2].write_text(json.dumps(inventory,indent=2)+'\n',encoding='utf-8',newline='\n')
(args.report/'NATIVE_BUILD.json').write_text(json.dumps(inventory,indent=2))
print('DESTINATION_NATIVE_PASS',json.dumps({k:inventory[k] for k in ['closed_stock_count','runtime_triangles','draw_surfaces','seat_count']}),flush=True)

if args.render:
    bpy.ops.wm.open_mainfile(filepath=str(outputs[0]));scene=bpy.context.scene
    scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True;scene.cycles.device='CPU'
    scene.render.threads_mode='FIXED';scene.render.threads=8
    scene.render.resolution_x=1440;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
    scene.view_settings.view_transform='AgX';scene.world=bpy.data.worlds.new('Neutral destination review');scene.world.use_nodes=True
    scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.38,.4,.43,1)
    scene.world.node_tree.nodes['Background'].inputs[1].default_value=.6
    # Only diagnostic environment, never saved in source or exported.
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,-33,-2.805));g=bpy.context.object
    m=bpy.data.materials.new('Review neutral floor');m.diffuse_color=(.19,.19,.19,1);g.data.materials.append(m)
    aim=Vector((-2,-34,-.65))
    for at,power,size in [((-3,-31,6),1300,7),((5,-35,3),950,5),((-9,-38,2),900,5)]:
        bpy.ops.object.light_add(type='AREA',location=at);light=bpy.context.object;light.data.energy=power;light.data.size=size
        light.rotation_euler=(aim-light.location).to_track_quat('-Z','Y').to_euler()
    views=[]
    cameras=[('overview',(10,-43,7),(-2.5,-34,-.5),42),('audience',(-7,-39,1.9),(-1,-32.8,-.4),34),('balcony',(2,-35,1.65),(-3.2,-32,0.45),24),('stair',(-9,-34,1.3),(-4.7,-33.5,-.7),30)] if args.view in ['all','overview'] else ([('seating',(-7,-38,1.7),(-1,-32.8,-.6),30)] if args.view=='seating' else [('services',(-8,-36.5,2.2),(-3.5,-33.5,.1),32)])
    if args.view=='overview':cameras=cameras[:1]
    for name,at,target,lens in cameras:
        bpy.ops.object.camera_add(location=at);cam=bpy.context.object;cam.data.lens=lens;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();scene.camera=cam
        path=args.report/(name+'.png');scene.render.filepath=str(path);bpy.ops.render.render(write_still=True)
        views.append({'id':name,'file':str(path),'sha256':sha(path),'position_source_m':at})
        bpy.data.objects.remove(cam,do_unlink=True)
    (args.report/'NATIVE_VIEWS.json').write_text(json.dumps({'status':'captured_not_yet_reviewed','blend_sha256':sha(outputs[0]),'views':views},indent=2))
print('DESTINATION_COMPLETE_SECONDS',round(time.time()-started,2),flush=True)
