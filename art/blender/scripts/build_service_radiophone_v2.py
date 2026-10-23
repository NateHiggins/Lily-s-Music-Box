"""Three editable radio/printer concepts and a publishable hero candidate.

No runtime authority is authored here. Godot owns lettering, radio, lamp,
work orders, paper history and constrained hand controls. Native renders are
design review only. Use -- --concept A|B|C --out tmp/handheld-CONCEPT.
"""
from pathlib import Path
import argparse, collections, hashlib, json, math, sys
import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(Path(__file__).parent))
from fabrication_native_batch import material, partition, export

p = argparse.ArgumentParser()
p.add_argument('--concept', choices=['A', 'B', 'C'], default='C')
p.add_argument('--out', required=True)
p.add_argument('--view', choices=['front', 'service', 'back'], default='front')
p.add_argument('--publish', action='store_true')
p.add_argument('--all-views', action='store_true')
args = p.parse_args(sys.argv[sys.argv.index('--')+1:])
OUT = (ROOT / args.out).resolve()
assert OUT.is_relative_to((ROOT/'tmp').resolve()) or (args.publish and OUT==ROOT), 'Review candidates stay in tmp/; publishing requires --publish --out .'
for folder in ['art/blender', 'game/assets/props', 'review']:
    (OUT/folder).mkdir(parents=True, exist_ok=True)
REVIEW = OUT/'art/reviews/v2_handheld_20261023/native' if args.publish else OUT/'review'
REVIEW.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
catalog = json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
stocks = bpy.data.collections.new('EditableIndividualStock')
exports = bpy.data.collections.new('ServiceRadiophoneV2')
review = bpy.data.collections.new('ReviewOnlyLetteringAndStage')
for coll in [stocks, exports, review]: bpy.context.scene.collection.children.link(coll)
groups = collections.defaultdict(list)
pivots = {}
finishes = {
    'Case': dict(catalog_key='bakelite_black', tint=[.58,.67,.63,1], normal=.22, roughness=.85, pigment=.4),
    'Brass': dict(catalog_key='brass_dull', tint=[.86,.82,.67,1], normal=.25, roughness=.85, pigment=.6),
    'Steel': dict(catalog_key='fire_hardware_steel', tint=[.32,.37,.38,1], normal=.28, roughness=.75, pigment=.5),
    'Paper': dict(catalog_key='paper', tint=[1.,.96,.84,1], normal=.12, roughness=1., pigment=.65),
    'Rubber': dict(catalog_key='washer_rubber', tint=[.6,.6,.58,1], normal=.3, roughness=1., pigment=.7),
    'Leather': dict(catalog_key='leather_worn', tint=[.60,.44,.30,1], normal=.5, roughness=1., pigment=.65),
    'Porcelain': dict(catalog_key='porcelain_fixture', tint=[.88,.83,.67,1], normal=.12, roughness=.65, pigment=.4),
}

def coords(v): return Vector((v[0],-v[2],v[1]))

def finish(obj, name, group, surface):
    obj.name = 'Stock__'+name
    obj.data.transform(obj.matrix_world)
    obj.matrix_world = Matrix.Identity(4)
    for c in list(obj.users_collection): c.objects.unlink(obj)
    stocks.objects.link(obj)
    groups[(group, surface)].append(obj)
    return obj

def box(name, at, size, surface='Brass', group='Fixed', bevel=.0007):
    bpy.ops.mesh.primitive_cube_add(size=1, location=coords(at))
    o=bpy.context.object; o.scale=(size[0],size[2],size[1])
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=o.modifiers.new('Worked edge','BEVEL'); mod.width=min(bevel,min(size)*.22); mod.segments=2
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish(o,name,group,surface)

def cylinder(name, at, radius, depth, surface='Brass', group='Fixed', axis='z', sides=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=sides,radius=radius,depth=depth,location=coords(at))
    o=bpy.context.object
    if axis=='x': o.rotation_euler[1]=math.pi/2
    elif axis=='z': o.rotation_euler[0]=math.pi/2
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    return finish(o,name,group,surface)

def pivot(name, at): pivots[name]=coords(at)

def screw(at, axis='z'):
    cylinder('Captive screw',at,.0021,.0015,'Steel',axis=axis,sides=12)
    if axis=='z': box('Slot',tuple(at[i]+([0,0,.0008][i]) for i in range(3)),(.0028,.00045,.00035),'Brass',bevel=0)

def knurl(name, at, radius, depth, group, axis='z', count=18):
    cylinder(name,at,radius,depth,'Brass',group,axis)
    for i in range(count):
        a=i*math.tau/count
        point=list(at)
        plane=[0,1] if axis=='z' else [1,2]
        point[plane[0]]+=radius*math.cos(a); point[plane[1]]+=radius*math.sin(a)
        cylinder('Knurl',point,.00065,depth*.92,'Steel',group,axis,sides=6)

# A: upright field ledger; B: broad folio; C: clipped asymmetric service set.
W,H = {'A':(.166,.228),'B':(.236,.157),'C':(.214,.193)}[args.concept]
PW = W-.038 if args.concept!='C' else .164
PH = .116 if args.concept=='C' else H-.065
PX = -.004 if args.concept=='C' else 0.
PY = .032 if args.concept=='C' else .019
paper_z = .042
# Hollow case, with separate walls. Opening the access door must expose cells,
# not a solid cube dressed with disconnected interior props.
for x in [-W/2+.0045,W/2-.0045]:
    box('Chassis side wall',(x,0,0),(.009,H,.055),'Case',bevel=.002)
for y in [-H/2+.0045,H/2-.0045]:
    box('Chassis cross wall',(0,y,0),(W-.018,.009,.055),'Case',bevel=.002)
box('Rear steel pan',(0,0,-.029),(W-.010,H-.010,.005),'Steel',bevel=.003)
for x in [-W/2+.009,W/2-.009]:
    box('Front mounting ledge',(x,0,.029),(.009,H-.014,.009),'Brass',bevel=.001)
for y in [-H/2+.008,H/2-.008]:
    box('Front cross ledge',(0,y,.029),(W-.018,.006,.009),'Brass',bevel=.001)
box('Paper recess',(PX,PY,.035),(PW+.010,PH+.010,.006),'Steel')
box('Paper',(PX,PY,paper_z),(PW,PH,.0008),'Paper','Paper')
pivot('Paper',(PX,PY,paper_z))
for x in [PX-PW/2-.004,PX+PW/2+.004]:
    box('Spring paper guide',(x,PY,.045),(.004,PH+.006,.005))
    for y in [PY-PH*.38,PY+PH*.38]: screw((x,y,.048))
top=PY+PH/2+.004
bottom=PY-PH/2-.006
box('Tear bar',(PX,top,.046),(PW+.010,.004,.006))
for i in range(40):
    box('Tear tooth',(PX-PW/2+(i+.5)*PW/40,top-.0025,.047),(PW/90,.002,.001),'Steel',bevel=0)
cylinder('Platen',(PX,bottom,.045),.008,PW+.009,'Rubber','Platen',axis='x',sides=32)
pivot('Platen',(PX,bottom,.045))
for i,x in enumerate([PX-PW/2-.011,PX+PW/2+.011]):
    name='FeedWheel'+str(i);pivot(name,(x,bottom,.045))
    knurl(name,(x,bottom,.045),.010,.006,name,'x')
    cylinder('Platen bearing',(x,bottom,.045),.004,.012,'Steel',axis='x')
# The paper is supported by a real bed. Ribbon and carriage sit below its edge.
cy=bottom-.012
for dy in [-.0035,.0035]: cylinder('Carriage rail',(PX,cy+dy,.047),.0015,PW,'Steel',axis='x')
for side in [-1,1]:
    x=PX+side*(PW/2-.012)
    name='SupplySpool' if side<0 else 'TakeupSpool';pivot(name,(x,cy-.009,.048))
    cylinder('Ribbon core',(x,cy-.009,.048),.008,.008,'Rubber',name)
    for z in [.044,.053]:
        cylinder('Ribbon flange',(x,cy-.009,z),.011,.0015,'Brass',name)
    cylinder('Spool screw',(x,cy-.009,.054),.003,.002,'Steel',name,sides=12)
box('Ink ribbon',(PX,cy+.002,.053),(PW-.023,.004,.0007),'Rubber')
box('Mechanism bearing plate',(PX,cy-.006,.031),(PW+.008,.029,.004),'Steel')
pivot('Carriage',(PX-PW/2+.010,cy,.054))
box('Rail truck',(PX-PW/2+.010,cy,.052),(.014,.013,.009),'Steel','Carriage')
box('Strike shoe',(PX-PW/2+.010,cy+.008,.055),(.006,.008,.006),'Brass','Type_hammer')
pivot('Type_hammer',(PX-PW/2+.010,cy+.008,.055))
# Service door has a hinge axis supported by fixed ears at both ends.
door_y=-H/2+.020
cover_w=W-.066
pivot('ServiceCover',(0,-H/2+.005,.034))
box('Battery access door',(0,door_y,.041),(cover_w,.027,.008),'Case','ServiceCover',bevel=.002)
box('Access plate',(0,door_y+.002,.046),(cover_w-.014,.013,.0015),'Brass','ServiceCover')
for x in [-cover_w/2+.008,cover_w/2-.008]:
    cylinder('Door captive latch',(x,door_y,.047),.002,.002,'Steel','ServiceCover',sides=12)
for x in [-cover_w/2,0,cover_w/2]:
    cylinder('Hinge knuckle',(x,-H/2+.005,.034),.0038,.012,'Brass','ServiceCover' if x==0 else 'Fixed',axis='x',sides=16)
cylinder('Hinge pin',(0,-H/2+.005,.034),.0015,cover_w+.017,'Steel',axis='x',sides=12)
for x in [-.028,.028]:
    cylinder('Dry cell',(x,door_y,-.005),.012,.041,'Rubber',axis='y',sides=20)
    cylinder('Battery terminal',(x,door_y+.022,-.005),.004,.004,'Brass',axis='y',sides=12)
    box('Cell spring clip',(x,door_y-.022,-.005),(.011,.003,.012),'Brass')
    box('Terminal strap',(x,door_y+.023,.004),(.006,.003,.019),'Brass')
box('Battery retaining bridge',(0,door_y,-.022),(.089,.008,.003),'Leather')
# No invented meter states: the three jewels report exactly their owners.
for x,name in [(-.028,'OrderJewel'),(0,'NetJewel'),(.028,'LampJewel')]:
    at=(x,-H/2+.035,.043)
    cylinder('Jewel bezel',at,.0044,.003,'Brass',sides=20)
    cylinder(name,(x,at[1],.045),.003,.002,'Porcelain',name,sides=20)
for x,name in [(-W/2+.014,'LampSwitch'),(W/2-.014,'RadioSwitch')]:
    at=(x,-H/2+.023,.047);pivot(name,at)
    cylinder('Switch mounting nut',at,.006,.003,'Brass',sides=8)
    box('Switch lever',(x,at[1]+.006,.052),(.004,.013,.004),'Steel',name)
    cylinder('Switch grip',(x,at[1]+.012,.053),.004,.004,'Case',name,sides=16)
box('Jewel mounting rail',(0,-H/2+.035,.037),(.081,.014,.006),'Case')
# Shouldered inspection lamp is aimed into the world (-Z), not at the owner.
lx=-W/2+.015; ly=H/2-.016
box('Lamp saddle',(lx,ly,-.004),(.037,.019,.018),'Steel')
cylinder('Lamp can',(lx,ly,-.022),.017,.044,'Brass',sides=32)
cylinder('TorchLens',(lx,ly,-.045),.014,.002,'Porcelain','TorchLens',sides=32)
for x in [lx-.010,lx+.010]:box('Lamp guard',(x,ly,-.048),(.002,.028,.002),'Steel')
# Telescoping aerial has a bottom socket and a retained sliding stem.
ax=W/2-.012; ay=H/2-.014
cylinder('Aerial insulator',(ax,ay,.006),.006,.019,'Case',axis='y',sides=16)
pivot('Aerial',(ax,ay+.007,.006))
cylinder('Aerial sleeve',(ax,ay+.019,.006),.0026,.027,'Brass','Aerial',axis='y',sides=12)
cylinder('Aerial stem',(ax,ay+.043,.006),.0015,.027,'Steel','Aerial',axis='y',sides=12)
cylinder('Aerial tip',(ax,ay+.057,.006),.0022,.003,'Brass','Aerial',axis='y',sides=12)
# Tactile focus/feed control at right; speaker & mic are acoustic apertures.
fx=W/2+.001;fy=PY+.016
pivot('FocusWheel',(fx,fy,.006))
knurl('Reading wheel',(fx,fy,.006),.012,.009,'FocusWheel','x',24)
for x in [-W/2+.010,W/2-.010]:
    for y in [-H/2+.009,H/2-.009]:screw((x,y,.035))
for row in range(9):
    y=-.018+row*.004
    box('Receiver grille',(W/2+.0007,y,-.006),(.001,.0015,.030),'Rubber',bevel=0)
box('Hand strap',(0,0,-.039),(W-.040,.024,.005),'Leather',bevel=.002)
for x in [-W/2+.022,W/2-.022]:
    box('Strap keeper',(x,0,-.039),(.006,.032,.006),'Brass')
    cylinder('Strap rivet',(x,0,-.043),.002,.001,'Steel',sides=12)
# Rounded reel bonnet and its end bearings explain where the continuous slip
# comes from. Only the exposed paper tongue is animated; no sheet simulation.
if args.concept=='C':
    cylinder('Paper roll core',(PX,H/2-.009,.010),.012,PW-.012,'Paper',axis='x',sides=32)
    for x in [PX-PW/2,PX+PW/2]:
        cylinder('Reel end bearing',(x,H/2-.009,.010),.014,.003,'Brass',axis='x',sides=24)
        screw((x,H/2-.009,.026))
    box('Reel protective bonnet',(PX,H/2+.001,-.001),(PW-.010,.009,.023),'Case',bevel=.003)
    # Exposed return spring and crank are on a separate service frame. They
    # move only during carriage return, and can be omitted at carry scale.
    for x in [PX-PW/2+.018,PX+PW/2-.018]:
        box('Return-frame standoff',(x,cy-.004,.037),(.004,.012,.018),'Steel')
    for j in range(20):
        cylinder('Return spring turn',(PX-.025+j*.0025,cy-.007,.043),.003,.00065,'Steel',axis='x',sides=12)
    box('Return drawbar',(PX,cy-.007,.043),(.062,.0014,.0014),'Brass')
    # Rear radio coils and a protected carbon microphone remain reachable
    # beside the battery drawer when the set is turned over for inspection.
    cylinder('Carbon mouthpiece',(W/2-.028,.039,-.034),.016,.009,'Case',sides=32)
    for row in range(-3,4):
        for col in range(-3,4):
            if row*row+col*col<=10:
                cylinder('Microphone aperture',(W/2-.028+col*.003,.039+row*.003,-.039),.00075,.001,'Rubber',sides=8)
# Parent parts share actual pivots, not one mesh instance per screw or tooth.
nodes={}
for name,at in pivots.items():
    node=bpy.data.objects.new(name,None);exports.objects.link(node);node.location=at;nodes[name]=node
for (group,surface),objects in groups.items():
    spec=finishes[surface];mat=bpy.data.materials.get(surface) or material(ROOT,surface,spec,catalog)
    for obj in objects:obj.data.materials.append(mat)
    name=group if group in ['Paper','TorchLens','OrderJewel','NetJewel','LampJewel'] else group+'__'+surface
    obj=partition(exports,name,objects,spec,mat,Matrix.Identity(4),catalog)
    if group in nodes:
        obj.data.transform(Matrix.Translation(-nodes[group].location))
        obj.parent=nodes[group];obj.location=(0,0,0)
for name in ['Paper','TorchLens']:
    # Exact mesh names are the existing teletype's lookup ABI.
    if name in nodes:
        node=nodes.pop(name);mesh=next(x for x in exports.objects if x.type=='MESH' and x.parent==node)
        world=Matrix.Translation(node.location) @ mesh.matrix_basis
        mesh.parent=None;mesh.matrix_world=world
        bpy.data.objects.remove(node,do_unlink=True);mesh.name=name
hammer=nodes['Type_hammer'];carriage=nodes['Carriage']
hammer.parent=carriage;hammer.location=pivots['Type_hammer']-pivots['Carriage']
stocks.hide_render=True;stocks.hide_viewport=True
proof=export(OUT,'service_radiophone_v2',exports,material_names_only=True)
mesh_nodes=sum(o.type=='MESH' for o in exports.objects)
assert mesh_nodes<=36,(mesh_nodes,'draw partitions budget')
assert proof['triangles']<35000,proof
(REVIEW/'build.json').write_text(json.dumps(dict(evidence_class='INERT',concept=args.concept,
    export=proof,mesh_nodes=mesh_nodes,editable_parts=len(stocks.objects),finishes=finishes,
    paper=dict(center=[PX,PY,paper_z],width=PW,height=PH),
    dimensions=[W,H,.055],view=args.view,
    source_sha256=hashlib.sha256(Path(__file__).read_bytes().replace(b'\r\n',b'\n')).hexdigest()),indent=2)+'\n')

# Native review typography is geometry in a separate, unexported collection.
font=bpy.data.fonts.load(str(ROOT/'game/assets/fonts/courier_prime/CourierPrime-Regular.ttf'))
def text(body,at,size,color=(.055,.041,.028,1)):
    curve=bpy.data.curves.new('Review lettering','FONT');curve.body=body;curve.size=size
    if font:curve.font=font
    obj=bpy.data.objects.new('Review only: '+body[:18],curve);review.objects.link(obj)
    obj.location=coords(at);obj.rotation_euler=(math.pi/2,0,0)
    mat=bpy.data.materials.new('Review ink');mat.use_nodes=True
    mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=color
    mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.95
    curve.materials.append(mat)
    return obj
text('VANTRY / SERVICE WIRE  0041',(PX-PW/2+.005,PY+PH/2-.010,.0426),.005)
copy='HOT WATER / FIELD REPORT\n\nThe hot valve turns freely.\nWater warms steadily; the\ndrain clears without backing\nup.\n\nListen again after midnight.'
text(copy,(PX-PW/2+.005,PY+PH/2-.024,.0426),min(.0078,(PW-.01)/18.))
text('02 / 04    FILE 0041',(PX-PW/2+.005,PY-PH/2+.004,.0426),.0045)
plate=text('VANTRY  /  TYPE 28-R',(-cover_w/2+.010,door_y,.047),.004)
bpy.context.view_layer.update()
world=plate.matrix_world.copy();plate.parent=nodes['ServiceCover'];plate.matrix_world=world
for x,t in [(-.028,'ORDER'),(0,'NET'),(.028,'LAMP')]:text(t,(x-.007,-H/2+.041,.046),.0032)
# Review uses the normal powered resting state. Runtime duplicates and drives
# these catalogue materials from the existing authoritative control values.
for key,color in [('OrderJewel',(.07,.032,.004,1)),('NetJewel',(.12,.47,.22,1)),('LampJewel',(.6,.11,.055,1))]:
    obj=next(o for o in exports.objects if o.type=='MESH' and o.name==key)
    mat=obj.data.materials[0].copy();obj.data.materials.clear();obj.data.materials.append(mat)
    bsdf=mat.node_tree.nodes['Principled BSDF']
    for link in list(bsdf.inputs['Base Color'].links):mat.node_tree.links.remove(link)
    bsdf.inputs['Base Color'].default_value=color
    bsdf.inputs['Emission Color'].default_value=color;bsdf.inputs['Emission Strength'].default_value=.3 if key!='OrderJewel' else 0.
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32
scene.render.threads_mode='FIXED';scene.render.threads=6
scene.render.resolution_x=1100;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Neutral review');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.20,.23,.27,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.5
def aim(obj,at):obj.rotation_euler=(coords(at)-obj.location).to_track_quat('-Z','Y').to_euler()
for name,at,power,size in [('Softbox',(-.35,.42,.45),22,.30),('Rim',(.28,.18,-.24),18,.24),('Fill',(.3,-.14,.32),8,.30)]:
    light=bpy.data.lights.new(name,'AREA');light.energy=power;light.shape='DISK';light.size=size
    o=bpy.data.objects.new(name,light);review.objects.link(o);o.location=coords(at);aim(o,(0,0,0))
cam=bpy.data.cameras.new('Review camera');o=bpy.data.objects.new('Review camera',cam);review.objects.link(o)
o.location=coords((.19,.13,.59) if args.view!='back' else (-.21,.10,-.58));aim(o,(0,.008,0));cam.type='ORTHO';cam.ortho_scale=.295 if args.concept!='A' else .32;scene.camera=o
scene.render.image_settings.file_format='PNG'
for view in (['front','service','back'] if args.all_views else [args.view]):
    nodes['ServiceCover'].rotation_euler.x=-1.85 if view=='service' else 0.
    o.location=coords((.19,.13,.59) if view!='back' else (-.21,.10,-.58));aim(o,(0,.008,0))
    scene.render.filepath=str(REVIEW/f'{view}.png');bpy.ops.render.render(write_still=True)
    print('HANDHELD NATIVE REVIEW',args.concept,view,mesh_nodes,proof['triangles'])
