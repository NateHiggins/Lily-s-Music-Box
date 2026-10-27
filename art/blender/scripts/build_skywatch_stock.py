"""Period-informed Skywatch refractor; native stock, no gameplay authority.

Reuse the established grain/metric-chart/normal/export pipeline. Real hollow
tubes, fork bearings, saddle straps and captive fasteners establish manufacture.
The Cooke museum instrument informs form; no reference pixels enter the asset.
"""
from pathlib import Path
import ast, json, hashlib, math, sys, os
import bpy, bmesh, numpy as np
from mathutils import Vector, Matrix

ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
sys.path.insert(0,str(ROOT/'art/blender/scripts'))
from fabrication_chart_batch import triangle_charts, revolved_charts
from fabrication_grain import stock_grain_frame
from fabrication_normals import stock_corner_normals
from check_exported_tangents import validate
PLAN=ROOT/'art/data/skywatch/source_plan.json'
plan=json.loads(PLAN.read_text());scope=plan['telescope']
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version=0
C=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))
stock=bpy.data.collections.new('Closed construction');bpy.context.scene.collection.children.link(stock);stock.hide_render=True
exports=bpy.data.collections.new('Runtime partitions');bpy.context.scene.collection.children.link(exports)
mats={};specs={};pieces=[];checks=[];current='Skywatch';partitions=[]
source=ROOT/'art/blender/scripts/build_service_instruments.py'
tree=ast.parse(source.read_text(encoding='utf-8'))
names={'material','solid','box','tube','rod','screw','mesh_partition'}
nodes=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in names or isinstance(n,ast.ClassDef) and n.name=='ExportUVHandedness']
# These submillimetre arrises need one bevel segment; the hero's silhouette
# comes from its turned profiles, not three invisible bevel subdivisions.
for node in nodes:
    if isinstance(node,ast.FunctionDef) and node.name=='solid':
        for child in ast.walk(node):
            if isinstance(child,ast.Assign) and any(isinstance(t,ast.Attribute) and t.attr=='segments' for t in child.targets):child.value=ast.Constant(1)
ast.fix_missing_locations(tree)
exec(compile(ast.Module(body=nodes,type_ignores=[]),str(source),'exec'))
material('glassish',{'color':[.70,.82,.88,1.],'roughness':.06,'metallic':0.})
glass=mats['glassish'].node_tree.nodes['Principled BSDF']
glass.inputs['Transmission Weight'].default_value=1.
glass.inputs['IOR'].default_value=1.52
specs['glassish']={'registered_clear_finish':'res://scripts/building/v2_clear_glass_finish.gd','optical_role':'refractor lens; no diffuse painted image'}

def move(obj,origin=(0,0,0),basis=None):
    matrix=C.to_3x3();inverse=matrix.inverted();basis=basis or Matrix.Identity(3)
    for vertex in obj.data.vertices:vertex.co=matrix@(basis@(inverse@vertex.co)+Vector(origin))
    return obj

def between(label,a,b,width,depth,key):
    a,b=Vector(a),Vector(b);axis=(b-a).normalized()
    obj=box(label,(width,(b-a).length,depth),(0,0,0),key,.001)
    return move(obj,(a+b)/2,Vector((0,1,0)).rotation_difference(axis).to_matrix())

def pin(label,radius,length,at,key,axis='z',n=32):
    obj=rod(label,radius,length,(0,0,0),key,n=n)
    basis=Vector((0,0,1)).rotation_difference(Vector({'x':(1,0,0),'y':(0,1,0),'z':(0,0,1)}[axis])).to_matrix()
    move(obj,at,basis)
    obj['uv_axis']=C.to_3x3()@(basis@Vector((0,0,1)));obj['uv_center']=C.to_3x3()@Vector(at)
    return obj

def annulus(label,outer,inner,length,at,key,axis='z'):
    obj=tube(label,outer,inner,length,(0,0,0),key,n=48)
    basis=Vector((0,0,1)).rotation_difference(Vector({'x':(1,0,0),'y':(0,1,0),'z':(0,0,1)}[axis])).to_matrix()
    move(obj,at,basis)
    obj['uv_axis']=C.to_3x3()@(basis@Vector((0,0,1)));obj['uv_center']=C.to_3x3()@Vector(at)
    return obj

def gear(label,at,radius,axis='y',teeth=48):
    orientation=Vector((0,0,1)).rotation_difference(Vector({'x':(1,0,0),'y':(0,1,0)}[axis])).to_matrix()
    annulus(label+' web',radius-.003,.014,.012,at,'brass',axis)
    for i in range(teeth):
        angle=math.tau*i/teeth
        tooth=box(label+' tooth',(.005,radius*math.tau/teeth*.52,.012),(radius-.001,0,0),'brass',.00015)
        move(tooth,at,orientation@Matrix.Rotation(angle,3,'Z'))

def worm(label,at,axis='z'):
    # A continuous six-turn helical crest actually meets the wheel teeth.
    orientation=Vector((0,0,1)).rotation_difference(Vector({'x':(1,0,0),'z':(0,0,1)}[axis])).to_matrix()
    vertices=[];count=145;n=6
    for i in range(count):
        angle=i*math.tau*6/(count-1);z=-.027+i*.054/(count-1)
        for j in range(n):
            b=j*math.tau/n;r=.0065+.0015*math.cos(b)
            vertices.append(orientation@Vector((r*math.cos(angle),r*math.sin(angle),z+.0015*math.sin(b)))+Vector(at))
    faces=[tuple(reversed(range(n))),tuple(range((count-1)*n,count*n))]
    faces.extend((i*n+j,i*n+(j+1)%n,(i+1)*n+(j+1)%n,(i+1)*n+j) for i in range(count-1) for j in range(n))
    solid(label+' threaded worm',vertices,faces,'brass_bright')

def partition(name,start,pivot=(0,0,0),parent='root'):
    items=pieces[start:];obj,keys=mesh_partition(name,items)
    # Continuous developed cylinder charts remove the per-facet texture mosaic
    # seen in the first actual brass render. Keep the existing flat-stock grain
    # charts and its explicit, validated tangent export convention.
    axes=[];centers=[]
    for part,key in items:
        axes.extend([part.get('uv_axis',(0,0,0))]*len(part.data.vertices))
        centers.extend([part.get('uv_center',(0,0,0))]*len(part.data.vertices))
    mesh=obj.data;coords=np.array([v.co[:] for v in mesh.vertices]);indices=np.array([l.vertex_index for l in mesh.loops]).reshape((-1,3))
    points=coords[indices];normal=np.cross(points[:,1]-points[:,0],points[:,2]-points[:,0]);normal/=np.linalg.norm(normal,axis=1)[:,None]
    guide=mesh.attributes['_tangent_guide'];g=np.array([a.vector[:] for a in guide.data])[::3]
    tangents=g[:,[0,2,1]].copy();tangents[:,1]*=-1
    values=np.array([a.uv[:] for a in mesh.uv_layers.active.data]).reshape((-1,3,2))
    axis=np.array(axes)[indices[:,0]];center=np.array(centers)[indices[:,0]]
    for material_index,key in enumerate(keys):
        selected=np.array([i for i,p in enumerate(mesh.polygons) if p.material_index==material_index]);u=tangents[selected].copy();uv=values[selected].copy()
        revolved_charts(points[selected],normal[selected],u,uv,axis[selected],center[selected],float(catalog[key]['meters_per_tile']) if key in catalog else 1.)
        tangents[selected]=u;values[selected]=uv
    mesh.uv_layers.active.data.foreach_set('uv',values.astype(np.float32).ravel())
    g=np.repeat(tangents[:,[0,2,1]],3,axis=0);g[:,2]*=-1;guide.data.foreach_set('vector',g.astype(np.float32).ravel())
    offset=C.to_3x3()@Vector(pivot)
    for vertex in obj.data.vertices:vertex.co-=offset
    obj.location=offset
    partitions.append({'mesh':name,'materials':keys,'parent':parent,'pivot':list(pivot)})
    return obj

height=float(scope['axis_height_m']);radius=float(scope['tripod_radius_m'])
start=len(pieces)
for i in range(3):
    angle=math.tau*i/3+.3
    low=Vector((radius*math.cos(angle),.055,radius*math.sin(angle)))
    high=Vector((.095*math.cos(angle),height-.16,.095*math.sin(angle)))
    # Paired upper rails enclose the brass hinge tongue. Their lower ends
    # enter the actual split shoe, with cross-braces bolted to the rails.
    side=Vector((-math.sin(angle),0,math.cos(angle)))*.027
    for sign in [-1,1]:between('Mahogany leg rail',low+side*sign,high+side*sign,.032,.028,'wood_dark')
    between('Leg lower bridge',low+side,low-side,.045,.035,'wood_dark')
    mid=low.lerp(high,.42)
    between('Spread restraint',mid,Vector((0,.42,0)),.012,.012,'brass')
partition('TripodWoodAndBraces',start)
start=len(pieces)
pin('Tripod crown',.125,.050,(0,height-.16,0),'cast_iron','y',64)
pin('Azimuth spindle',.038,.11,(0,height-.10,0),'brass','y')
annulus('Spreader central hub',.032,.010,.040,(0,.42,0),'brass','y')
for i in range(3):
    angle=math.tau*i/3+.3;x,z=radius*math.cos(angle),radius*math.sin(angle)
    box('Shoe backing',(.10,.10,.045),(x,.055,z),'brass',.002)
    pin('Levelling screw',.008,.065,(x,.025,z),'brass','y')
    pin('Broad roof pad',.043,.012,(x,.006,z),'rubber_aged','y')
    x,z=.095*math.cos(angle),.095*math.sin(angle)
    box('Crown hinge tongue',(.035,.08,.035),(x,height-.18,z),'brass')
    pin('Crown hinge bolt',.012,.10,(x,height-.18,z),'brass','x',6)
partition('TripodHardware',start)
start=len(pieces)
annulus('Rotating azimuth cup',.083,.039,.065,(0,height-.06,0),'brass','y')
box('Fork crosshead',(.235,.034,.075),(0,height-.02,0),'cast_iron',.004)
for x in [-.108,.108]:
    box('Fork cheek',(.025,.16,.075),(x,height+.045,0),'cast_iron',.007)
    annulus('Bushed altitude journal',.030,.0125,.030,(x,height+.09,0),'brass','x')
    pin('Captive axle nut',.020,.012,(x+math.copysign(.023,x),height+.09,0),'brass','x',6)
partition('AzimuthFork',start,parent='azimuth')
axis=height+.09
start=len(pieces)
pin('Altitude trunnion',.012,.245,(0,axis,0),'brass','x')
box('Tube saddle bridge',(.09,.035,.27),(0,axis+.025,0),'brass',.003)
for z in [-.105,.105]:
    annulus('Split saddle strap',.049,.044,.025,(0,axis+.085,z),'brass')
    annulus('Saddle packing liner',.044,.043,.024,(0,axis+.085,z),'rubber_aged')
    for x in [-.055,.055]:
        box('Strap clamp ear',(.022,.022,.022),(x,axis+.064,z),'brass')
        pin('Clamp screw',.005,.032,(x,axis+.067,z),'brass','y',12)
partition('AltitudeSaddle',start,pivot=(0,axis,0),parent='altitude')
start=len(pieces)
cy=axis+.085
annulus('Continuous optical tube',.043,.0405,scope['tube_length_m'],(0,cy,-.12),'brass')
annulus('Objective threaded cell',.048,.0375,.062,(0,cy,-.70),'brass_bright')
annulus('Dew shield',.053,.050,.14,(0,cy,-.805),'brass')
for z in [-.742,-.67,.435]:annulus('Turned tube shoulder',.046,.043,.012,(0,cy,z),'brass_bright')
annulus('Rear stepped reducer',.043,.018,.040,(0,cy,.46),'brass')
annulus('Sliding eyepiece drawtube',.018,.014,.19,(0,cy,.55),'brass_bright')
annulus('Eyepiece retaining collar',.025,.014,.038,(0,cy,.65),'brass')
annulus('Eye cup',.026,.013,.023,(0,cy,.677),'bakelite')
box('Pinion bearing housing',(.068,.025,.048),(0,cy-.049,.52),'brass',.004)
box('Drawtube rack',(.010,.008,.12),(0,cy-.023,.56),'brass',.0005)
pin('Focus shaft',.005,.112,(0,cy-.055,.52),'brass_bright','x')
for x in [-.062,.062]:
    pin('Milled focus knob',.020,.014,(x,cy-.055,.52),'brass','x',48)
    for i in range(12):
        a=i*math.tau/12
        pin('Knob knurl',.0012,.014,(x,cy-.055+.019*math.sin(a),.52+.019*math.cos(a)),'brass_bright','x',8)
for z in [-.35,.12]:
    box('Finder shoe',(.035,.012,.04),(.066,cy+.033,z),'brass')
    between('Finder bracket',(.04,cy+.02,z),(.081,cy+.10,z),.012,.016,'brass')
    annulus('Finder retaining ring',.014,.011,.018,(.081,cy+.10,z),'brass')
annulus('Finder optical tube',.0105,.0085,.55,(.081,cy+.10,-.15),'brass')
annulus('Finder eyecup',.013,.006,.025,(.081,cy+.10,.135),'bakelite')
partition('OpticalTubeAssembly',start,pivot=(0,axis,0),parent='altitude')
start=len(pieces)
pin('Objective optical glass',.0374,.004,(0,cy,-.718),'glassish','z',96)
pin('Eyepiece optical glass',.0125,.003,(0,cy,.674),'glassish','z',64)
pin('Finder glass',.008,.002,(.081,cy+.10,-.42),'glassish','z',48)
partition('OpticalGlass',start,pivot=(0,axis,0),parent='altitude')
start=len(pieces)
gear('Altitude wheel',(.15,axis,0),.060,'x')
annulus('Altitude keyed boss',.023,.012,.060,(.137,axis,0),'brass','x')
pin('Altitude retaining nut',.017,.014,(.174,axis,0),'brass_bright','x',6)
partition('AltitudeGear',start,pivot=(0,axis,0),parent='altitude')
start=len(pieces)
gear('Azimuth wheel',(0,height-.075,0),.090,'y',64)
partition('AzimuthGear',start,parent='azimuth')
for name,at,axis_name,parent in [('Altitude',(.15,axis-.067,0),'z','azimuth'),('Azimuth',(0,height-.075,.099),'x','root')]:
    start=len(pieces);worm(name,at,axis_name)
    step=Vector((1,0,0) if axis_name=='x' else (0,0,1));centre=Vector(at)
    pin(name+' spindle',.0035,.145,centre+step*.035,'brass_bright',axis_name)
    for side in [-1,1]:
        bearing=centre+step*side*.035
        box(name+' bearing housing',(.025,.022,.025),bearing,'cast_iron',.002)
        annulus(name+' bearing bush',.008,.0035,.028,bearing,'brass',axis_name)
    # Rigid bridge seats against the fixed fork/base instead of floating.
    if name=='Altitude':
        box('Upper bearing carrier',(.027,.010,.105),centre-Vector((0,.017,0)),'cast_iron',.002)
        between('Fork carrier attachment',(.107,axis-.025,0),centre-Vector((0,.018,0)),.018,.02,'cast_iron')
    else:
        box('Lower bearing carrier',(.105,.010,.027),centre-Vector((0,.017,0)),'cast_iron',.002)
        between('Crown carrier attachment',(0,height-.16,0),centre-Vector((0,.02,0)),.02,.025,'cast_iron')
    wheel=centre+step*.10
    pin(name+' handwheel',.028,.013,wheel,'brass',axis_name,48)
    pin(name+' wheel hub',.010,.025,wheel,'brass_bright',axis_name)
    partition(name+'SlowMotion',start,parent=parent)

# Final closed-stock proof and the same explicit UV-tangent export contract
# used by the installed service instruments. No generated GLB patching.
for obj in stock.objects:
    bm=bmesh.new();bm.from_mesh(obj.data)
    assert all(e.is_manifold for e in bm.edges),obj.name
    assert bm.calc_volume(signed=True)>1e-13,obj.name
    bm.free()
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/skywatch_telescope.blend'))
bpy.ops.object.select_all(action='DESELECT')
for obj in exports.objects:obj.select_set(True)
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExportUVHandedness
asset=ROOT/'game/assets/props/skywatch_telescope.glb'
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_attributes=True,export_materials='PLACEHOLDER')
proof=validate(asset)
def digest(p):
    b=p.read_bytes();return hashlib.sha256(b if p.suffix in ['.glb','.blend'] else b.replace(b'\r\n',b'\n')).hexdigest()
report={'evidence_class':'INERT','scope':'native telescope stock, not installed interaction or surface qualification','asset_sha256':digest(asset),'partitions':partitions,'closed_stocks':checks,'export_validation':proof,'axis_height':axis,'materials':specs,'source_bindings':{p.relative_to(ROOT).as_posix():digest(p) for p in [PLAN,Path(__file__),source,*[ROOT/'art/blender/scripts'/n for n in ['fabrication_chart_batch.py','fabrication_uvs.py','fabrication_grain.py','fabrication_normals.py']],ROOT/'game/data/runtime_material_sets.json']}}
(ROOT/'art/blender/skywatch_telescope_construction.json').write_text(json.dumps(report,indent=2)+'\n',newline='\n')
print('SKYWATCH NATIVE STOCK',len(checks),'closed pieces;',len(partitions),'runtime partitions;',proof)

