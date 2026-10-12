"""Native 16mm machine stock, retaining the existing lens/reel pivots and size."""
from pathlib import Path
import ast,collections,hashlib,json,math
import bpy,bmesh
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parents[3];OUT=ROOT/'tmp/v2-active-media-20261012';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
materials={k:bpy.data.materials.new(k) for k in ['iron_blackened','brass_dull','bakelite_black','rubber_aged','milk_glass']}
for m in materials.values():m.use_nodes=True
helper=ROOT/'art/blender/scripts/build_electrical_service.py';tree=ast.parse(helper.read_text(encoding='utf-8'))
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in {'point','cube','cylinder','cut','ring','finish'}],type_ignores=[]),str(helper),'exec'))
stock_finish=finish
def finish(name,objects,key,bevel=.0005):
    obj=stock_finish(name,objects,key,bevel)
    bpy.context.view_layer.objects.active=obj
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    return obj
fixed=[];dynamic=[]
def part(name,objects,key,bevel=.0005):
    obj=finish(name,objects,key,bevel);fixed.append(obj);return obj
def box(name,size,at,key):return part(name,[cube(size,at)],key)
def tube(name,r,inside,h,at,key,axis='z'):
    obj=ring(r,inside,h,at)
    if axis=='z':obj.rotation_euler.x=math.pi/2
    elif axis=='x':obj.rotation_euler.y=math.pi/2
    return part(name,[obj],key,.00015)
def cyl(name,r,h,at,key,axis='y'):
    obj=cylinder(r,h,at)
    if axis=='z':obj.rotation_euler.x=math.pi/2
    elif axis=='x':obj.rotation_euler.y=math.pi/2
    return part(name,[obj],key,.0003)
def spinner(name,obj,key,at):
    obj=finish(name,[obj],key,.0002)
    # Rebase vertices without changing their installed position; +Y in Godot
    # remains the original reel shaft axis used by ProjectorProp._process.
    frame=Matrix.Translation(Vector(point(at)))@Matrix.Rotation(-math.pi/2,4,'Y')
    for v in obj.data.vertices:v.co=frame.inverted()@v.co
    obj.matrix_world=frame;dynamic.append((obj,'Reel'))
    return obj
box('CastFoot',(.27,.026,.185),(0,.027,.02),'iron_blackened')
for x in [-.105,.105]:box('Pad'+str(x),(.042,.014,.15),(x,.007,.02),'rubber_aged')
box('CastPillar',(.09,.115,.095),(0,.072,.045),'iron_blackened')
front=cube((.115,.155,.115),(0,.195,-.02))
cut(front,cube((.105,.145,.105),(0,.195,-.02)))
bore=cylinder(.027,.05,(0,.205,-.0775));bore.rotation_euler.x=math.pi/2;cut(front,bore)
part('MechanismCasting',[front],'iron_blackened')
rear=cube((.135,.175,.130),(0,.205,.080));cut(rear,cube((.125,.165,.120),(0,.205,.080)))
for i in range(6):cut(rear,cube((.10,.008,.03),(0,.145+i*.024,.146)))
cut(rear,cylinder(.018,.035,(0,.305,.080)))
part('VentedLamphouse',[rear],'iron_blackened')
tube('Chimney',.023,.018,.030,(0,.305,.080),'iron_blackened',axis='y')
tube('LensBarrel',.032,.027,.075,(0,.205,-.115),'iron_blackened')
tube('FocusCollar',.037,.032,.020,(0,.205,-.096),'brass_dull')
tube('FrontBezel',.034,.030,.014,(0,.205,-.157),'iron_blackened')
box('Gate',(.014,.055,.030),(.062,.205,-.030),'brass_dull')
for i,y in enumerate([.255,.150]):cyl('FilmRoller'+str(i),.020,.014,(.07,y,-.01),'iron_blackened',axis='x')
cyl('SpeedKnob',.022,.016,(-.072,.230,-.010),'bakelite_black',axis='x')
box('Switch',(.012,.026,.010),(-.070,.160,-.030),'bakelite_black')
cyl('CrankShaft',.010,.030,(-.082,.195,.050),'iron_blackened',axis='x')
box('CrankArm',(.008,.032,.008),(-.100,.207,.050),'iron_blackened')
cyl('CrankGrip',.006,.020,(-.111,.223,.050),'bakelite_black',axis='x')
tube('SupplyInlet',.010,.006,.010,(.030,.085,.150),'bakelite_black')
for index,(at,r) in enumerate([((0,.400,.045),.098),((0,.132,.152),.086)]):
    a=Vector((0,.275,.070));b=Vector(at);direction=b-a
    obj=cylinder(.011,direction.length,(a+b)/2)
    obj.rotation_euler=Vector(point(direction)).to_track_quat('Z','Y').to_euler()
    part('ReelArm'+str(index),[obj],'iron_blackened')
    cyl('Spindle'+str(index),.010,.050,at,'iron_blackened',axis='x')
    for side in [-1,1]:
        p=(side*.018,at[1],at[2]);flange=ring(r,.010,.004,p);flange.rotation_euler.y=math.pi/2
        # Six real lightening holes leave the hub and outer rim connected.
        for i in range(6):
            theta=i*math.pi/3
            cutter=cylinder(r*.20,.02,(p[0],p[1]+r*.58*math.cos(theta),p[2]+r*.58*math.sin(theta)))
            cutter.rotation_euler.y=math.pi/2;cut(flange,cutter)
        spinner('Reel'+str(index)+'Flange'+str(side),flange,'iron_blackened',p)
    film=cylinder(r*.80,.030,at);film.rotation_euler.y=math.pi/2
    spinner('Reel'+str(index)+'Film',film,'rubber_aged',at)
    hub=cylinder(.020,.040,at);hub.rotation_euler.y=math.pi/2
    spinner('Reel'+str(index)+'Hub',hub,'brass_dull',at)
lens_at=(0,.205,-.165);lens=cylinder(.029,.001,lens_at);lens.rotation_euler.x=math.pi/2
lens=finish('NativeLens',[lens],'milk_glass',0)
origin=Vector(point(lens_at))
for v in lens.data.vertices:v.co-=origin
lens.location=origin;dynamic.append((lens,'Lens'))
buckets=collections.defaultdict(list)
for obj in fixed:buckets[obj.data.materials[0].name].append(obj)
parts=[]
for key,objects in buckets.items():parts.append((finish('ProjectorBody_'+key,objects,key,0),'Body'))
parts+=dynamic;report=[];rows=[]
for obj,component in parts:
    layer=obj.data.uv_layers.active
    for face in obj.data.polygons:
        p=[obj.data.vertices[i].co for i in face.vertices];normal=(p[1]-p[0]).cross(p[2]-p[0])
        axis=max(range(3),key=lambda i:abs(normal[i]));a,b=[(1,2),(0,2),(0,1)][axis]
        for loop in face.loop_indices:
            q=obj.data.vertices[obj.data.loops[loop].vertex_index].co;layer.data[loop].uv=(q[a],q[b])
    bm=bmesh.new();bm.from_mesh(obj.data);closed=all(e.is_manifold for e in bm.edges);volume=bm.calc_volume(signed=True);bm.free()
    bad=sum(abs((Vector(layer.data[f.loop_indices[1]].uv)-Vector(layer.data[f.loop_indices[0]].uv)).cross(Vector(layer.data[f.loop_indices[2]].uv)-Vector(layer.data[f.loop_indices[0]].uv)))<=1e-12 for f in obj.data.polygons)
    assert closed and volume>0 and bad==0,(obj.name,closed,volume,bad)
    rows.append({'name':obj.name,'component':component,'material':obj.data.materials[0].name})
    report.append({'name':obj.name,'closed':closed,'volume':volume,'triangles':len(obj.data.polygons),'collapsed_uv':bad})
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/active_household_projector.blend'))
asset=ROOT/'game/assets/props/active_household_projector.glb'
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',export_apply=True,export_tangents=True,export_lights=False,export_cameras=False)
(ROOT/'game/data/orison_v2/active_household_projector.json').write_text(json.dumps({'schema_version':1,'asset':'res://assets/props/active_household_projector.glb','parts':rows},indent=2)+'\n',encoding='utf-8',newline='\n')
(OUT/'projector-construction.json').write_text(json.dumps({'evidence_class':'INERT','asset_sha256':hashlib.sha256(asset.read_bytes()).hexdigest(),'parts':report,'scope':'Native machine stock only; installed/control/decoder/lifetime proof and power-lead routes remain required.'},indent=2)+'\n',encoding='utf-8',newline='\n')
print('NATIVE PROJECTOR:',len(rows),'draws including original eight reel motions and lens')
