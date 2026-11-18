"""Original four-string upright bass: closed native stocks, metric UV/PBR export.

Blender --background --python-exit-code 1 --python this.py -- --report FRESH_DIR
No rendering, downloads, gameplay, actor or sound authority. Coordinates below
are Godot metres, Y up, soundboard/front +Z. The endpin floor point is the origin.
"""
from pathlib import Path
import argparse, collections, hashlib, json, math, shutil, sys, time

ROOT = next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
FAMILY = 'harukiya_bass'


def contact_contract():
    strings = []
    for i, (name, midi, hz) in enumerate([('E1', 28, 41.2034446), ('A1', 33, 55.0),
                                         ('D2', 38, 73.416192), ('G2', 43, 97.998859)]):
        nut = [[-.018, -.006, .006, .018][i], 1.665, [.157, .161, .161, .157][i]]
        bridge = [[-.069, -.023, .023, .069][i], .620, [.245, .265, .265, .245][i]]
        def point(t):
            return [nut[k] + (bridge[k]-nut[k])*t for k in range(3)]
        strings.append(dict(id=name, open_midi=midi, open_hz=hz, nut=nut, bridge=bridge,
                            speaking_length_m=math.dist(nut, bridge), radius_m=[.00125,.0011,.00095,.0008][i],
                            mesh='Bass_String_'+name, pluck_t=.76, pluck_default=point(.76), pluck_t_range=[.70,.82],
                            stopping_positions=[dict(semitones=n,t=1-2**(-n/12),string_center=point(1-2**(-n/12))) for n in range(13)]))
    return dict(schema_version=1, asset='res://assets/props/harukiya_bass.glb',
                coordinates='Godot metres; Y up; front/soundboard +Z; origin at endpin floor contact; apply assembly transform once',
                front=[0,0,1], floor_contact=[0,0,0], strings=strings,
                stopping_rule='t = 1 - pow(2, -semitones/12); lerp(nut,bridge,t). These are open-string centerline datums; a stopped string bends onto the measured fingerboard support.',
                fingerboard=dict(y_range=[.755,1.665],half_width_at_nut_m=.027,half_width_at_end_m=.066,
                                 front_normal=[0,0,1], contact_note='support_at_string entries give the actual tessellated board support beneath each stopped string; no fingertip may use the string centerline as wood support'),
                model_status='construction pending', integration='No collisions, audio, gameplay controller or cast skeleton. Native markers are redundant with these source datums.')


AUTHORING = ROOT / 'art/blender' / f'{FAMILY}_source.json'
APPEARANCE = ROOT / 'game/data/orison_v2' / f'{FAMILY}_visual.json'


def write_appearance(document):
    appearance = {key: document[key] for key in ('schema_version', 'asset')}
    appearance['materials'] = []
    for row in document['materials']:
        finish = {key: row[key] for key in ('key', 'catalog_key', 'tint', 'roughness', 'meters_per_tile')}
        # The calibrated site softwood uses the live catalogue normal strength.
        if row['catalog_key'] != 'site_softwood':
            finish['normal'] = row['normal']
        appearance['materials'].append(finish)
    appearance['partitions'] = [
        {key: row[key] for key in ('mesh', 'materials')} for row in document['partitions']
    ]
    APPEARANCE.write_text(json.dumps(appearance, indent=2) + '\n', encoding='utf-8', newline='\n')


if __name__ == '__main__' and '--appearance-only' in sys.argv:
    write_appearance(json.loads(AUTHORING.read_bytes()))
    raise SystemExit(0)


if __name__ == '__main__' and '--contract-only' in sys.argv:
    target=ROOT/'art/blender'/f'{FAMILY}_contacts.json'
    target.write_text(json.dumps(contact_contract(),indent=2)+'\n',encoding='utf-8',newline='\n')
    print(str(target))
    raise SystemExit(0)

import bpy, bmesh, numpy as np
from mathutils import Matrix, Vector
sys.path.insert(0,str(ROOT/'art/blender/scripts'))
from fabrication_native_batch import material, partition, export
from fabrication_chart_batch import triangle_charts

parser=argparse.ArgumentParser();parser.add_argument('--report',required=True,type=Path)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
args.report.mkdir(parents=True,exist_ok=True);started=time.time()
C=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))


def sha(p):
    p=Path(p);raw=p.read_bytes()
    return hashlib.sha256(raw if p.suffix in ['.blend','.glb','.png'] else raw.replace(b'\r\n',b'\n')).hexdigest()


outputs=[ROOT/'art/blender'/f'{FAMILY}.blend',ROOT/'art/blender'/f'{FAMILY}_inventory.json',
         ROOT/'game/assets/props'/f'{FAMILY}.glb', AUTHORING, APPEARANCE]
prior=[]
for p in outputs+list((ROOT/'art/blender').glob(FAMILY+'.blend[0-9]*')):
    if p.exists():
        keep=args.report/'prior'/p.name;keep.parent.mkdir(exist_ok=True)
        if keep.exists():raise FileExistsError('Use fresh report directory: '+str(keep))
        shutil.copy2(p,keep);assert sha(p)==sha(keep)
        prior.append(dict(source=str(p),preserved=str(keep),sha256=sha(p)))
(args.report/'PRIOR_CUSTODY.json').write_text(json.dumps(prior,indent=2))
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
scene=bpy.context.scene;scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
stock=bpy.data.collections.new('Editable closed instrument stocks');scene.collection.children.link(stock)
draws=bpy.data.collections.new('Runtime material partitions and measured markers');scene.collection.children.link(draws)
catalog_path=ROOT/'game/data/runtime_material_sets.json';catalog=json.loads(catalog_path.read_text())['materials']


def finish(key,tint=(1,1,1,1),normal=.08,roughness=.7,pigment=.8):
    return dict(catalog_key=key,tint=list(tint),normal=normal,roughness=roughness,pigment=pigment)


finishes={'BassVarnish':finish('site_softwood',(.80,.50,.25,1),.035,.70,.68),
          'BassRibs':finish('wood_dark',(1.1,.76,.47,1),.06,.78,.7),
          'BassEbony':finish('wood_dark',(.16,.15,.14,1),.025,.58,.50),
          'BassBridge':finish('timber',(1.30,1.10,.79,1),.045,.90,.7),
          'BassBrass':finish('brass',normal=.08,roughness=.65),
          'BassString':finish('nickel_plated',(.82,.78,.69,1),.025,.6,.5),
          'BassRubber':finish('rubber_aged',(.20,.20,.20,1),.08,.9,.6)}
mats={k:material(ROOT,k,f,catalog) for k,f in finishes.items()}
pieces=[];checks=[];runtime=contact_contract()


def validate_stock(obj):
    bm=bmesh.new();bm.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    assert all(e.is_manifold for e in bm.edges),(obj.name,'open stock')
    volume=bm.calc_volume(signed=True);assert volume>1e-14,(obj.name,'nonpositive volume',volume)
    bm.to_mesh(obj.data);bm.free();return volume


def solid(name,verts,faces,key,group='static'):
    mesh=bpy.data.meshes.new(name);mesh.from_pydata([C.to_3x3()@Vector(v) for v in verts],[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);stock.objects.link(obj);mesh.materials.append(mats[key])
    validate_stock(obj);pieces.append((obj,key,group));return obj


def basis(axis):
    w=Vector(axis).normalized();seed=Vector((0,0,1)) if abs(w.z)<.9 else Vector((0,1,0))
    u=seed.cross(w).normalized();return u,w.cross(u),w


def lathe(name,profile,at,key,axis=(0,1,0),n=16,group='static'):
    u,v,w=basis(axis);at=Vector(at)
    verts=[at+w*h+(u*math.cos(i*math.tau/n)+v*math.sin(i*math.tau/n))*r for h,r in profile for i in range(n)]
    faces=[tuple(reversed(range(n)))]
    faces.extend((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i) for j in range(len(profile)-1) for i in range(n))
    faces.append(tuple(range((len(profile)-1)*n,len(profile)*n)))
    return solid(name,verts,faces,key,group)


def rod(name,a,b,r,key,n=10,group='static'):
    a,b=Vector(a),Vector(b);return lathe(name,[(0,r),((b-a).length,r)],a,key,b-a,n,group)


def extrusion(name,outline,z0,z1,key,group='static'):
    n=len(outline);verts=[(x,y,z) for z in [z0,z1] for x,y in outline]
    faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]
    faces.extend((i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n))
    return solid(name,verts,faces,key,group)


def box(name,at,size,key):
    x,y,z=at;a,b,c=[v*.5 for v in size]
    return extrusion(name,[(x-a,y-b),(x+a,y-b),(x+a,y+b),(x-a,y+b)],z-c,z+c,key)


def smooth_closed(points,steps=3):
    out=[];p=[Vector(v) for v in points]
    for i in range(len(p)):
        a,b,c,d=p[(i-1)%len(p)],p[i],p[(i+1)%len(p)],p[(i+2)%len(p)]
        for j in range(steps):
            t=j/steps
            out.append(.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t))
    return out


half=[(0,1.25),(.060,1.245),(.150,1.20),(.220,1.13),(.247,1.045),(.238,.988),
      (.195,.948),(.160,.900),(.163,.852),(.187,.807),(.235,.792),(.266,.748),
      (.311,.638),(.326,.505),(.312,.388),(.257,.289),(.151,.222),(0,.20)]
outline=smooth_closed(half+[(-x,y) for x,y in reversed(half[1:-1])],3)
center=Vector((0,.72));n=len(outline)


def plate(name,front=True):
    # A hollow instrument: each arched plate is a thin closed solid, not a full body plug.
    sign=1 if front else -1;lift=.042 if front else .030;edge=.107
    rings=[.20,.40,.60,.80,1.0];verts=[]
    for inside in [False,True]:
        thickness=-.006 if inside else 0
        verts.append((0,.72,sign*(edge+lift+thickness)))
        for r in rings:
            for p in outline:
                v=center+(p-center)*r
                verts.append((v.x,v.y,sign*(edge+lift*(1-r*r)+thickness)))
    total=1+n*len(rings);faces=[]
    for layer in [0,total]:
        faces.extend((layer,layer+1+i,layer+1+(i+1)%n) for i in range(n))
        for j in range(len(rings)-1):
            a=layer+1+j*n;b=a+n
            faces.extend((a+i,a+(i+1)%n,b+(i+1)%n,b+i) for i in range(n))
    end=1+(len(rings)-1)*n
    faces.extend((end+i,end+(i+1)%n,end+(i+1)%n+total,end+i+total) for i in range(n))
    return solid(name,verts,faces,'BassVarnish' if front else 'BassRibs')


front=plate('Arched spruce top with true cut-through sound holes');plate('Arched maple back',False)
# Curved ribs: wall thickness 4mm; open cavity bounded by the actual plates.
verts=[]
for inset,z in [(0,-.107),(0,.107),(.004,.107),(.004,-.107)]:
    for p in outline:
        radial=(p-center).normalized();q=p-radial*inset;verts.append((q.x,q.y,z))
faces=[]
for j in range(4):
    k=(j+1)%4
    faces.extend((j*n+i,j*n+(i+1)%n,k*n+(i+1)%n,k*n+i) for i in range(n))
solid('Bent maple rib assembly',verts,faces,'BassRibs')


def subtract(obj,cutter,operation='DIFFERENCE'):
    # Boolean operands must be evaluated after linking. Triangulated manifold
    # operands avoid the exact solver's reproduced empty thin-plate result.
    for operand in [obj,cutter]:
        bm=bmesh.new();bm.from_mesh(operand.data)
        bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(operand.data);bm.free()
        operand.data.update()
    bpy.context.view_layer.update()
    bpy.context.view_layer.objects.active=obj;obj.select_set(True)
    mod=obj.modifiers.new('Native closed stock '+operation,'BOOLEAN');mod.operation=operation;mod.solver='MANIFOLD';mod.object=cutter
    bpy.ops.object.modifier_apply(modifier=mod.name)
    pieces.remove(next(row for row in pieces if row[0]==cutter));bpy.data.objects.remove(cutter,do_unlink=True)
    validate_stock(obj)


sound_holes=[]
for side in [-1,1]:
    # Long serpentine slot with rounded eyes. These are acoustic apertures, not a decal.
    line=[Vector((side*x,y)) for x,y in [(.144,.945),(.130,.927),(.133,.898),(.149,.864),(.164,.827),(.168,.794),(.155,.767),(.140,.754)]]
    poly=[]
    for direction in [1,-1]:
        sequence=range(len(line)) if direction==1 else reversed(range(len(line)))
        for j in sequence:
            tangent=(line[min(j+1,len(line)-1)]-line[max(j-1,0)]).normalized()
            normal=Vector((-tangent.y,tangent.x));poly.append(line[j]+normal*.0055*direction)
    subtract(front,extrusion('Sound hole slot cutter',poly,.08,.21,'BassVarnish'))
    for j in [0,len(line)-1]:
        x,y=line[j];r=.0125
        circle=[(x+math.cos(t*math.tau/20)*r,y+math.sin(t*math.tau/20)*r) for t in range(20)]
        subtract(front,extrusion('Sound hole eye cutter',circle,.08,.21,'BassVarnish'))
    sound_holes.append(dict(side=side,through=True,centers=[[float(p.x),float(p.y)] for p in line]))

# Thin inlaid purfling follows both plate rims; no floating painted outline.
for sign in [-1,1]:
    points=[center+(p-center)*.978 for p in outline]
    vv=[]
    for inset,z in [(-.001,sign*.112),(.001,sign*.112),(.001,sign*.110),(-.001,sign*.110)]:
        for p in points:
            q=p+(p-center).normalized()*inset;vv.append((q.x,q.y,z))
    ff=[(j*n+i,j*n+(i+1)%n,((j+1)%4)*n+(i+1)%n,((j+1)%4)*n+i) for j in range(4) for i in range(n)]
    solid('Inlaid edge purfling '+str(sign),vv,ff,'BassEbony')

# Carved neck heel and rounded shaft support the ebony board along its upper half.
neck_sections=[(1.175,.048,.020,.075),(1.25,.034,.038,.095),(1.38,.027,.063,.115),(1.52,.023,.080,.132),(1.665,.022,.096,.149)]
verts=[]
for y,w,back,top in neck_sections:
    for i in range(12):
        angle=i*math.tau/12;verts.append((w*math.cos(angle),y,(back+top)/2+(top-back)/2*math.sin(angle)))
faces=[tuple(reversed(range(12))),tuple(range((len(neck_sections)-1)*12,len(neck_sections)*12))]
faces.extend((j*12+i,j*12+(i+1)%12,(j+1)*12+(i+1)%12,(j+1)*12+i) for j in range(len(neck_sections)-1) for i in range(12))
solid('Carved maple neck and heel',verts,faces,'BassRibs')


def board_shape(y):
    t=(1.665-y)/1.045
    width=.027+(.066-.027)*(1.665-y)/(1.665-.755)
    # Arch follows the four measured string lanes with increasing radius toward the bridge.
    # End relief remains 7mm below strings, with 3mm clearance at the nut.
    z=.162+(.265-.162)*t-(.003+.004*t)
    return width,z


def board_z(x,y):
    width,z=board_shape(y);return z-.014*(x/width)**2


ys=[.755+(1.665-.755)*j/14 for j in range(15)];columns=13;verts=[]
for bottom in [False,True]:
    for y in ys:
        width,_=board_shape(y)
        for i in range(columns):
            x=width*(2*i/(columns-1)-1);verts.append((x,y,board_z(x,y)-(.013 if bottom else 0)))
layer=len(ys)*columns;faces=[]
for start in [0,layer]:
    for j in range(len(ys)-1):
        for i in range(columns-1):
            a=start+j*columns+i;faces.append((a,a+1,a+columns+1,a+columns))
boundary=list(range(columns))+[j*columns+columns-1 for j in range(1,len(ys))]+list(reversed(range((len(ys)-1)*columns,(len(ys))*columns-1)))+[j*columns for j in reversed(range(1,len(ys)-1))]
faces.extend((boundary[i],boundary[(i+1)%len(boundary)],boundary[(i+1)%len(boundary)]+layer,boundary[i]+layer) for i in range(len(boundary)))
board=solid('Curved ebony fingerboard',verts,faces,'BassEbony')

# Nut is a narrow curved stock carrying all four string centers, with shallow string grooves.
nut_cross=[(-.027,.143),(.027,.143)]+[(x,.162-.005*(x/.018)**2) for x in [.027,.018,.009,0,-.009,-.018,-.027]]
nn=len(nut_cross)
nut=solid('Curved ebony nut',[(x,y,z) for y in [1.663,1.670] for x,z in nut_cross],
          [tuple(reversed(range(nn))),tuple(range(nn,2*nn))]+[(i,(i+1)%nn,(i+1)%nn+nn,i+nn) for i in range(nn)],'BassEbony')
for s in runtime['strings']:
    x,y,z=s['nut'];subtract(nut,lathe('Nut string slot',[(0,s['radius_m']*1.2),(.015,s['radius_m']*1.2)],(x,1.659,z+.0004),'BassEbony',(0,1,0),8))

# Mechanically legible original open geared bass machines. Four shafts occupy
# distinct heights; each has two drilled cheek bearings and one owning wheel.
# Geometry follows the construction class in Rubner's manufacturer catalogue,
# not its ornament, dimensions, engraving or pixels.
def side_extrusion(name,profile,x0,x1,key):
    count=len(profile);verts=[(x,y,z) for x in [x0,x1] for y,z in profile]
    faces=[tuple(reversed(range(count))),tuple(range(count,2*count))]
    faces.extend((i,(i+1)%count,(i+1)%count+count,i+count) for i in range(count))
    return solid(name,verts,faces,key)


def tube_path(name,points,r,key,group='static',sides=6):
    points=[Vector(p) for p in points];verts=[]
    for i,point in enumerate(points):
        axis=points[min(i+1,len(points)-1)]-points[max(0,i-1)]
        u,v,_=basis(axis)
        verts.extend(point+(u*math.cos(j*math.tau/sides)+v*math.sin(j*math.tau/sides))*r for j in range(sides))
    faces=[tuple(reversed(range(sides))),tuple(range((len(points)-1)*sides,len(points)*sides))]
    faces.extend((j*sides+i,j*sides+(i+1)%sides,(j+1)*sides+(i+1)%sides,(j+1)*sides+i) for j in range(len(points)-1) for i in range(sides))
    return solid(name,verts,faces,key,group)


def bearing(name,center,r,inside,depth,axis=(1,0,0)):
    # True annular bearing, not a shaft obscured by a solid brass block.
    u,v,w=basis(axis);at=Vector(center);count=8
    rings=[(-depth/2,r),(depth/2,r),(depth/2,inside),(-depth/2,inside)]
    verts=[at+w*h+(u*math.cos(j*math.tau/count)+v*math.sin(j*math.tau/count))*rr for h,rr in rings for j in range(count)]
    faces=[(k*count+j,k*count+(j+1)%count,((k+1)%4)*count+(j+1)%count,((k+1)%4)*count+j) for k in range(4) for j in range(count)]
    return solid(name,verts,faces,'BassBrass')


cheek_profile=[(1.665,.060),(1.695,.044),(1.824,.034),(1.832,.089),(1.795,.125),(1.665,.147)]
headstock=side_extrusion('Continuous carved pegbox cheeks back and bottom',cheek_profile,-.034,.034,'BassRibs')
# Cut the front-open cavity from ONE stock. Separate coplanar back/side/bottom
# boxes produced false black seams in native06's render despite closed pieces.
cavity=[(1.680,.067),(1.701,.055),(1.814,.048),(1.825,.080),(1.825,.220),(1.680,.220)]
subtract(headstock,side_extrusion('Pegbox open cavity cutter',cavity,-.024,.024,'BassRibs'))
cheeks=[headstock]
machines=[];lead_paths=[];roller_radius=.0055
for i,s in enumerate(runtime['strings']):
    identity=s['id'];side=-1 if i<2 else 1
    y=[1.700,1.770,1.805,1.735][i];z=.120-.26*(y-1.700)
    for cheek in cheeks:
        subtract(cheek,lathe('Roller bore cutter',[(0,.0057),(.09,.0057)],(-.045,y,z),'BassBrass',(1,0,0),12))
    shaft_a=[-.044,y,z];shaft_b=[.044,y,z]
    rod('Unique winding roller '+identity,shaft_a,shaft_b,roller_radius,'BassString',10)
    for side_bearing in [-1,1]:
        bearing('Roller cheek bearing '+identity+' '+str(side_bearing),(side_bearing*.034,y,z),.009,.0056,.004)
    gear_x=side*.045;gear_radius=.014
    plate=box('Bolted machine backing '+identity,(side*.036,y+.004,z),(.004,.048,.048),'BassBrass')
    # Drill the mounting plate around the spindle as well.
    subtract(plate,lathe('Plate spindle cutter',[(0,.0057),(.10,.0057)],(-.05,y,z),'BassBrass',(1,0,0),12))
    for sy in [-1,1]:
        for sz in [sy]:
            rod('Machine mounting screw '+identity+str((sy,sz)),(side*.034,y+sy*.017,z+sz*.017),(side*.040,y+sy*.017,z+sz*.017),.002,'BassString',8)
    # Toothed wheel lies in Y/Z, spindle runs X. No duplicate full-width roller.
    teeth=[]
    for j in range(16*4):
        a=j*math.tau/(16*4);r=gear_radius if j%4 in [1,2] else gear_radius-.0018
        teeth.append((y+r*math.cos(a),z+r*math.sin(a)))
    side_extrusion('Worm wheel '+identity,teeth,gear_x-.003,gear_x+.003,'BassBrass')
    rod('Wheel hub '+identity,(side*.039,y,z),(side*.051,y,z),.007,'BassBrass',12)
    rod('Spindle retaining screw '+identity,(side*.050,y,z),(side*.054,y,z),.003,'BassString',10)
    # Worm tangent is +Z at the wheel's upper Y rim. The handle is on this SAME
    # straight axis, supported by two bearing ears fixed to the backing plate.
    worm_y=y+.0172;worm_x=gear_x;worm_begin=z-.022;worm_end=z+.058
    rod('Worm and coaxial key shaft '+identity,(worm_x,worm_y,worm_begin),(worm_x,worm_y,worm_end),.0028,'BassString',10)
    for bz in [z-.016,z+.016]:
        pedestal=box('Worm bearing pedestal '+identity+str(bz),(side*.041,worm_y,bz),(.010,.014,.007),'BassBrass')
        subtract(pedestal,lathe('Worm bearing bore',[(0,.0031),(.020,.0031)],(worm_x,worm_y,bz-.010),'BassBrass',(0,0,1),8))
        bearing('Worm bearing sleeve '+identity+str(bz),(worm_x,worm_y,bz),.005,.003,.008,(0,0,1))
    worm=[]
    for j in range(25):
        t=j/24;a=t*math.tau*3
        worm.append((worm_x+.0036*math.cos(a),worm_y+.0036*math.sin(a),z-.011+t*.022))
    tube_path('Continuous worm thread '+identity,worm,.00125,'BassBrass',sides=4)
    # Forged oval paddle is an ellipsoidal plate on the end of the worm shaft.
    # Its long transverse grip is visible from the front; there is no bent link.
    paddle=[]
    for j in range(16):
        a=j*math.tau/16;paddle.append((worm_x+.015*math.cos(a),worm_y+.007*math.sin(a)))
    extrusion('Oval tuning paddle '+identity,paddle,worm_end-.002,worm_end+.002,'BassBrass')
    # Select the front-facing analytic tangent to this roller. Nut X is retained
    # through the open box, so no two strings converge/cross at the centre.
    nut2=Vector((s['nut'][1]-y,s['nut'][2]-z));dist2=nut2.length_squared
    radius=roller_radius+s['radius_m'];perp=Vector((-nut2.y,nut2.x))
    options=[nut2*(radius/dist2)+perp*(sign*math.sqrt(dist2-radius*radius)/dist2) for sign in [-1,1]]
    normal=max(options,key=lambda p:p.y)
    tangent=[s['nut'][0],y+normal.x*radius,z+normal.y*radius]
    rod('Individual nut lead '+identity,s['nut'],tangent,s['radius_m'],'BassString',6,group='String_'+identity)
    theta=math.atan2(normal.y,normal.x);wind=[];pitch=2.15*s['radius_m']
    for j in range(25):
        turns=2*j/24;a=theta+turns*math.tau
        wind.append([s['nut'][0]-side*pitch*turns,y+math.cos(a)*radius,z+math.sin(a)*radius])
    tube_path('Two attached string windings '+identity,wind,s['radius_m'],'BassString',group='String_'+identity,sides=4)
    # The final short end is anchored through the roller, never floating in air.
    anchor=[wind[-1][0],y,z]
    rod('String roller anchor '+identity,wind[-1],anchor,s['radius_m'],'BassString',6,group='String_'+identity)
    s['tuner']=tangent;s['winding_center']=[0,y,z];s['winding_turns']=2;s['winding_anchor']=anchor
    lead_paths.append((identity,Vector(s['nut']),Vector(tangent),s['radius_m']))
    machines.append(dict(string=identity,side=side,roller_axis=[1,0,0],roller_center=[0,y,z],roller_radius_m=roller_radius,
                         shaft_endpoints=[shaft_a,shaft_b],gear_center=[gear_x,y,z],worm_axis=[0,0,1],
                         worm_axis_endpoints=[[worm_x,worm_y,worm_begin],[worm_x,worm_y,worm_end]],
                         handle_center=[worm_x,worm_y,worm_end],coaxial_handle=True,lead_tangent=tangent))

# Every lead must clear the other winding cylinders; dense samples bound this
# simple line/cylinder separation while the source records exact endpoints.
clearances=[]
for identity,a,b,r in lead_paths:
    for other in machines:
        if identity==other['string']:continue
        yc,zc=other['roller_center'][1:]
        direction=b-a;t=max(0.,min(1.,((yc-a.y)*direction.y+(zc-a.z)*direction.z)/(direction.y**2+direction.z**2)))
        point=a+direction*t;gap=math.hypot(point.y-yc,point.z-zc)-roller_radius-r
        assert gap>.001,(identity,other['string'],'lead/other shaft conflict',gap)
        clearances.append(dict(string=identity,other_shaft=other['string'],minimum_clearance_m=gap))

# Rounded solid scroll core. A deliberately modeled continuous spiral relief
# follows below; an undersampled radial displacement formerly made a star.
scroll_center=Vector((1.858,.074));scroll_radii=Vector((.044,.037));sectors=40;radial=4
vv=[]
for side in [-1,1]:
    vv.append((side*.024,scroll_center.x,scroll_center.y))
    for j in range(1,radial+1):
        radius=j/radial
        for i in range(sectors):
            a=i*math.tau/sectors;p=Vector((math.cos(a)*radius,math.sin(a)*radius))
            halfwidth=.024-.004*radius**8
            vv.append((side*halfwidth,scroll_center.x+p.x*scroll_radii.x,scroll_center.y+p.y*scroll_radii.y))
layer=1+radial*sectors;ff=[]
for start in [0,layer]:
    ff.extend((start,start+1+i,start+1+(i+1)%sectors) for i in range(sectors))
    for j in range(radial-1):
        a=start+1+j*sectors;b=a+sectors
        ff.extend((a+i,a+(i+1)%sectors,b+(i+1)%sectors,b+i) for i in range(sectors))
edge=1+(radial-1)*sectors
ff.extend((edge+i,edge+(i+1)%sectors,edge+(i+1)%sectors+layer,edge+i+layer) for i in range(sectors))
scroll=solid('Rounded solid scroll core',vv,ff,'BassRibs')
# A rounded throat is a solid loft, embedded in both core and pegbox, without
# any coplanar exterior faces. Union it before attaching the solid volutes.
throat=[];levels=[(1.816,.062,.030,.026),(1.829,.064,.031,.027),(1.842,.069,.027,.029)]
for y,z,rx,rz in levels:
    throat.extend((rx*math.cos(j*math.tau/16),y,z+rz*math.sin(j*math.tau/16)) for j in range(16))
throat_faces=[tuple(reversed(range(16))),tuple(range(32,48))]
throat_faces.extend((j*16+i,j*16+(i+1)%16,(j+1)*16+(i+1)%16,(j+1)*16+i) for j in range(2) for i in range(16))
subtract(scroll,solid('Rounded throat connection',throat,throat_faces,'BassRibs'),'UNION')
for side in [-1,1]:
    path=[];steps=56
    for j in range(steps+1):
        t=j/steps;a=math.pi*1.20+t*math.tau*1.40;r=.85*(1-t)+.08
        path.append(Vector((scroll_center.x+math.cos(a)*scroll_radii.x*r,
                            scroll_center.y+math.sin(a)*scroll_radii.y*r)))
    verts=[];cross_section=[(-1,0),(-1,.45),(-.55,1),(.55,1),(1,.45),(1,0)]
    for j,p in enumerate(path):
        t=j/steps;tangent=(path[min(j+1,steps)]-path[max(j-1,0)]).normalized()
        normal=Vector((-tangent.y,tangent.x));width=.0035*(1-t)+.0013
        for spread,height in cross_section:
            q=p+normal*spread*width
            radius=math.sqrt(((q.x-scroll_center.x)/scroll_radii.x)**2+((q.y-scroll_center.y)/scroll_radii.y)**2)
            baseline=.024-.004*radius**8-.0010
            x=side*(baseline+height*(.0055-.0015*t))
            verts.append((x,q.x,q.y))
    count=len(cross_section);faces=[tuple(reversed(range(count))),tuple(range(steps*count,(steps+1)*count))]
    faces.extend((j*count+i,j*count+(i+1)%count,(j+1)*count+(i+1)%count,(j+1)*count+i) for j in range(steps) for i in range(count))
    relief=solid('Integrated spiral volute '+str(side),verts,faces,'BassRibs')
    subtract(scroll,relief,'UNION')
subtract(headstock,scroll,'UNION')
# Native union can leave sub-micron triangles at the rounded throat contact.
# Weld only this new stock in source; strict UV/export checks stay unchanged.
from mathutils.kdtree import KDTree
before_points=[v.co.copy() for v in headstock.data.vertices]
bm=bmesh.new();bm.from_mesh(headstock.data)
bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.000001)
bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=.00000001)
bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(headstock.data);bm.free()
validate_stock(headstock)
tree=KDTree(len(headstock.data.vertices))
for i,v in enumerate(headstock.data.vertices):tree.insert(v.co,i)
tree.balance();max_weld=max(tree.find(p)[2] for p in before_points)
assert max_weld<.0000011,max_weld
runtime['headstock_native_cleanup']=dict(weld_tolerance_m=.000001,maximum_vertex_collapse_m=max_weld,
                                        vertices_before=len(before_points),vertices_after=len(headstock.data.vertices))
runtime['tuning_machines']=machines;runtime['tuning_clearance_checks']=clearances

# A shaped bridge lies in the transverse X/Z plane. Feet fit the actual arched top.
bridge_poly=[(-.087,.143),(-.050,.143),(-.046,.166),(-.029,.186),(0,.190),(.029,.186),(.046,.166),(.050,.143),(.087,.143),(.082,.205),(.069,.245),(.023,.265),(-.023,.265),(-.069,.245),(-.082,.205)]
verts=[(x,y,z) for y in [.613,.627] for x,z in bridge_poly];nbridge=len(bridge_poly)
faces=[tuple(reversed(range(nbridge))),tuple(range(nbridge,2*nbridge))]+[(i,(i+1)%nbridge,(i+1)%nbridge+nbridge,i+nbridge) for i in range(nbridge)]
bridge=solid('Carved maple bridge with two feet',verts,faces,'BassBridge')
# Two bridge kidneys and central heart are cut right through, leaving load-bearing webs.
for x,z,r in [(-.047,.202,.013),(.047,.202,.013),(0,.224,.010)]:
    subtract(bridge,lathe('Bridge piercing',[(0,r),(.030,r)],(x,.605,z),'BassBridge',(0,1,0),16))

tail_outline=[(-.014,.270),(.014,.270),(.041,.480),(.051,.511),(.043,.530),(-.043,.530),(-.051,.511),(-.041,.480)]
extrusion('Ebony tailpiece',tail_outline,.172,.192,'BassEbony')
lathe('Tail button',[(0,.012),(.025,.012)],(0,.193,0),'BassEbony',(0,-1,0),16)
for x in [-.011,.011]:rod('Tailgut '+str(x),(x,.275,.180),(x,.191,0),.0022,'BassString',8)
rod('Steel endpin',(0,.018,0),(0,.240,0),.006,'BassString',12)
lathe('Endpin socket',[(0,.013),(.055,.015)],(0,.183,0),'BassEbony',n=16)
lathe('Rubber floor tip',[(0,.008),(.008,.011),(.023,.009)],(0,0,0),'BassRubber',n=16)

# String meshes are independent for optional measured deflection; no simulated sound.
for i,s in enumerate(runtime['strings']):
    rod('Speaking string '+s['id'],s['nut'],s['bridge'],s['radius_m'],'BassString',8,group='String_'+s['id'])
    tail=[(i-1.5)*.022,.517,.193]
    rod('Afterlength '+s['id'],s['bridge'],tail,s['radius_m'],'BassString',8,group='String_'+s['id'])
    s['tailpiece_anchor']=tail
    # The actual tessellated support is evaluated against the final board mesh below.
    for stop in s['stopping_positions']:
        x,y,z=stop['string_center']
        origin=C.to_3x3()@Vector((x,y,z+.10));direction=C.to_3x3()@Vector((0,0,-1))
        support_stock=nut if stop['semitones']==0 else board
        hit,position,normal,index=support_stock.ray_cast(origin,direction)
        assert hit,(s['id'],stop,'missing fingerboard')
        support=C.inverted().to_3x3()@position
        stop['fingerboard_support']=list(support);stop['support_owner']='nut' if stop['semitones']==0 else 'fingerboard'
        stop['string_clearance_m']=z-support.z
        assert -.00005<stop['string_clearance_m']<.016,(s['id'],stop)

# Markers are empties, not visible spheres or runtime colliders.
markers={'FloorContact':[0,0,0],'FrontDatum':[0,.72,.149]}
for s in runtime['strings']:
    for key in ['nut','bridge','pluck_default']:markers[s['id']+'_'+key]=s[key]
for name,point in markers.items():
    obj=bpy.data.objects.new(name,None);draws.objects.link(obj);obj.location=C.to_3x3()@Vector(point);obj.empty_display_size=.012

groups=collections.defaultdict(list)
for obj,key,group in pieces:groups[(group,key)].append(obj)
partitions=[]
for (group,key),objects in sorted(groups.items()):
    name='Bass_'+group if group.startswith('String_') else 'Bass_static_'+key
    obj=partition(draws,name,objects,finishes[key],mats[key],Matrix.Identity(4),catalog)
    if key=='BassVarnish':
        # Broad plates intentionally bypass the helper's slender-stock heuristic.
        # The registered softwood grain runs along texture U; align that U to
        # Blender +Z / Godot +Y with the same isometric, float32-checked charts.
        # This keeps the material's physical tile scale, normals and true holes.
        mesh=obj.data
        coords=np.array([v.co[:] for v in mesh.vertices]);indices=np.array([v.vertex_index for v in mesh.loops]).reshape((-1,3))
        _,tangents,charts,_=triangle_charts(coords[indices],np.zeros(3),1.,long_grain=np.ones(len(indices),dtype=bool))
        mesh.uv_layers.active.data.foreach_set('uv',charts.astype(np.float32).ravel())
        guide=np.repeat(tangents[:,[0,2,1]],3,axis=0);guide[:,2]*=-1
        mesh.attributes['_tangent_guide'].data.foreach_set('vector',guide.astype(np.float32).ravel())
    partitions.append(dict(mesh=name,materials=[key],group=group,triangles=len(obj.data.polygons)))
for obj,key,group in pieces:
    checks.append(dict(name=obj.name,finish=key,group=group,closed=True,volume_m3=validate_stock(obj)))
stock.hide_render=True;stock.hide_viewport=True;bpy.context.view_layer.update()
proof=export(ROOT,FAMILY,draws,material_names_only=True)
assert proof['status']=='PASS' and proof['triangles']<21000,proof
assert proof['triangles']==sum(r['triangles'] for r in partitions),'Export lost triangles'
points=np.array([C.inverted().to_3x3()@v.co for obj,_,_ in pieces for v in obj.data.vertices]);lo=points.min(axis=0);hi=points.max(axis=0)
assert lo[1]>=-1e-6 and 1.78<hi[1]<1.92 and hi[0]-lo[0]<.70,(lo,hi)
runtime.update(model_status='native_export_pass_pending_render',aabb=dict(min=lo.tolist(),max=hi.tolist(),size=(hi-lo).tolist()),
               partitions=partitions,materials=[dict(key=k,**f,meters_per_tile=catalog[f['catalog_key']]['meters_per_tile']) for k,f in finishes.items()],
               sound_holes=sound_holes,markers=markers,
               surface_note='Soundboard uses registered uninterrupted softwood with explicit metric longitudinal grain; rib/back roughness retains mapped response with .78 multiplier. Other stocks use shared stock-grain charts.')
outputs[3].write_text(json.dumps(runtime,indent=2)+'\n',encoding='utf-8',newline='\n')
write_appearance(runtime)
bindings=[Path(__file__),catalog_path]+[ROOT/'art/blender/scripts'/n for n in ['fabrication_native_batch.py','fabrication_chart_batch.py','fabrication_uvs.py','fabrication_normals.py','fabrication_grain.py','check_exported_tangents.py']]
bindings+=sorted({ROOT/'game/assets/building/textures'/p for f in finishes.values() for p in catalog[f['catalog_key']]['files']})
inventory=dict(evidence_class='INERT',status='native_export_pass',original_modeling=True,blender_version=bpy.app.version_string,
               closed_stock_count=len(checks),closed_stocks=checks,aabb=runtime['aabb'],runtime_triangles=proof['triangles'],
               draw_surfaces=proof['primitives'],tangent_check=proof,asset_sha256=sha(outputs[2]),blend_sha256=sha(outputs[0]),
               data_sha256=sha(outputs[3]),source_bindings={p.relative_to(ROOT).as_posix():sha(p) for p in bindings},
               no_new_images=True,native_review='pending root native render',runtime_import_and_loaded_mips='pending root',
               contact_status='Measured instrument support only; actual hand reach, standing support and performed contacts remain unqualified.',
               reference_sources=[dict(url='https://kolstein.com/products/1223',used='41 inch mensure and traditional bass construction; no pixels used'),
                                  dict(url='https://lemurmusic.com/product/ba114-shen-3-4-bass-sb88-laminated-bass-deluxe-oil-varnish/',used='41.25 inch speaking length and 43.75 inch body reference; compact original geometry, not a replica'),
                                  dict(url='https://www.rubner-markneukirchen.de/assets/rubner_katalog_klein.pdf',used='Manufacturer bass/cello catalogue: traditional open brass worm machines on plates, supported shafts and handles. Original assembly; no brand marks or reference pixels.')])
outputs[1].write_text(json.dumps(inventory,indent=2)+'\n',encoding='utf-8',newline='\n')
(args.report/'NATIVE_BUILD.json').write_text(json.dumps(inventory,indent=2))
(args.report/'CONTACTS.json').write_text(json.dumps(runtime,indent=2))
print('BASS_NATIVE_PASS',json.dumps({k:inventory[k] for k in ['closed_stock_count','runtime_triangles','draw_surfaces','aabb']}),flush=True)
print('BASS_COMPLETE_SECONDS',round(time.time()-started,2),flush=True)
