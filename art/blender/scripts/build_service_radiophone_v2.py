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
p.add_argument('--view', choices=['front', 'service', 'back', 'printer', 'lamp', 'section'], default='front')
p.add_argument('--publish', action='store_true')
p.add_argument('--all-views', action='store_true')
p.add_argument('--hot-preview', action='store_true')
p.add_argument('--review-name', default='native', help='Separate retained native review packet')
args = p.parse_args(sys.argv[sys.argv.index('--')+1:])
OUT = (ROOT / args.out).resolve()
assert OUT.is_relative_to((ROOT/'tmp').resolve()) or (args.publish and OUT==ROOT), 'Review candidates stay in tmp/; publishing requires --publish --out .'
for folder in ['art/blender', 'game/assets/props', 'review']:
    (OUT/folder).mkdir(parents=True, exist_ok=True)
assert Path(args.review_name).name==args.review_name
REVIEW = OUT/'art/reviews/v2_handheld_20261023'/args.review_name if args.publish else OUT/'review'
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
    'Lens': dict(catalog_key='milk_glass', tint=[.98,.98,.94,1], normal=.10, roughness=.35, pigment=.15),
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

def tube(name, at, outer, inner, depth, surface='Brass', group='Fixed', axis='z', sides=24):
    """Closed bored bearing, rolled lip or spool rim; never a solid axle plug."""
    assert 0 < inner < outer
    vertices=[]
    for r,h in [(outer,-depth/2),(outer,depth/2),(inner,depth/2),(inner,-depth/2)]:
        for i in range(sides):
            a=i*math.tau/sides;v=[r*math.cos(a),r*math.sin(a),h]
            if axis=='x':v=[h,v[0],v[1]]
            elif axis=='y':v=[v[0],h,v[1]]
            vertices.append(coords([at[j]+v[j] for j in range(3)]))
    faces=[(k*sides+i,k*sides+(i+1)%sides,((k+1)%4)*sides+(i+1)%sides,((k+1)%4)*sides+i)
           for k in range(4) for i in range(sides)]
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update()
    import bmesh
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
    obj=bpy.data.objects.new(name,mesh);stocks.objects.link(obj)
    return finish(obj,name,group,surface)

def rod(name,a,b,radius=.001,surface='Steel',group='Fixed',sides=12):
    a,b=coords(a),coords(b)
    bpy.ops.mesh.primitive_cylinder_add(vertices=sides,radius=radius,depth=(b-a).length,location=(a+b)/2)
    obj=bpy.context.object;obj.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    return finish(obj,name,group,surface)

def strip(name, sections, surface='Paper', group='Fixed', thickness=.00025):
    """Static formed sheet from centre/half-width vectors; no cloth solver."""
    vertices=[]
    for i,(center,width) in enumerate(sections):
        c,w=coords(center),coords(width)
        tangent=coords(sections[min(i+1,len(sections)-1)][0])-coords(sections[max(0,i-1)][0])
        normal=tangent.cross(w).normalized()
        vertices.extend([c-w-normal*thickness/2,c+w-normal*thickness/2,c-w+normal*thickness/2,c+w+normal*thickness/2])
    faces=[(0,2,3,1),(len(vertices)-4,len(vertices)-3,len(vertices)-1,len(vertices)-2)]
    for i in range(len(sections)-1):
        a=i*4;b=a+4
        faces.extend([(a,a+1,b+1,b),(a+2,b+2,b+3,a+3),(a,b,b+2,a+2),(a+1,a+3,b+3,b+1)])
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update()
    import bmesh
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
    obj=bpy.data.objects.new(name,mesh);stocks.objects.link(obj);return finish(obj,name,group,surface)

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

# The printer is one datum-driven cartridge, including bored carrying frames.
from radiophone_printer_cartridge import build
W,H,PW,PH,PX,PY,paper_z,door_y,cover_w,lx,ly,cy=build(globals())
from writer_type_native import stock as type_stock,finish as finish_type,row_keys
finishes['TypeEmboss']=dict(finishes['Steel'])
type_stock(globals())

# Parent parts share actual pivots, not one mesh instance per screw or tooth.
nodes={}
for name,at in pivots.items():
    node=bpy.data.objects.new(name,None);exports.objects.link(node);node.location=at;nodes[name]=node
for (group,surface),objects in groups.items():
    spec=finishes[surface];mat=bpy.data.materials.get(surface) or material(ROOT,surface,spec,catalog)
    if surface=='Lens':
        bsdf=mat.node_tree.nodes['Principled BSDF'];bsdf.inputs['Transmission Weight'].default_value=.85
        bsdf.inputs['IOR'].default_value=1.48
    for obj in objects:obj.data.materials.append(mat)
    name=group if group in ['Paper','TorchLens','OrderJewel','NetJewel','LampJewel'] else group+'__'+surface
    obj=partition(exports,name,objects,spec,mat,Matrix.Identity(4),catalog)
    if surface=='TypeEmboss':finish_type(obj,ROOT)
    if group=='TypeSelector' and surface in ['Steel','TypeEmboss']:row_keys(obj,objects,pivots['TypeSelector'])
    if group in nodes:
        obj.data.transform(Matrix.Translation(-nodes[group].location),shape_keys=True)
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
selector=nodes['TypeSelector'];selector.parent=hammer;selector.location=pivots['TypeSelector']-pivots['Type_hammer']
# Authored flexure, driven only during an impression. No resting solver.
leaf=next(o for o in exports.objects if o.name=='Carriage__Steel')
leaf.shape_key_add(name='Basis');impression=leaf.shape_key_add(name='Impression')
for vertex in impression.data:
    y=vertex.co.z+pivots['Carriage'].z
    weight=max(0.,min(1.,(y+.064)/.018))
    vertex.co.y+=.00155*weight*weight
stocks.hide_render=True;stocks.hide_viewport=True
proof=export(OUT,'service_radiophone_v2',exports,material_names_only=True,staged_output=True)
mesh_nodes=sum(o.type=='MESH' for o in exports.objects)
assert mesh_nodes<=36,(mesh_nodes,'draw partitions budget')
assert proof['triangles']<35000,proof
(OUT/'game/data/device').mkdir(parents=True,exist_ok=True)
(OUT/'game/data/device/service_radiophone_v2.json').write_text(json.dumps(dict(
    schema_version=1,asset='res://assets/props/service_radiophone_v2.glb',
    asset_sha256=hashlib.sha256((OUT/'game/assets/props/service_radiophone_v2.glb').read_bytes()).hexdigest(),
    finishes=finishes,paper=dict(center=[PX,PY,paper_z],width=PW,height=PH)),indent=2)+'\n',newline='\n')
(REVIEW/'build.json').write_text(json.dumps(dict(evidence_class='INERT',concept=args.concept,
    export=proof,mesh_nodes=mesh_nodes,editable_parts=len(stocks.objects),finishes=finishes,
    paper=dict(center=[PX,PY,paper_z],width=PW,height=PH),
    dimensions=[W,H,.055],view=args.view,
    cartridge_sha256=hashlib.sha256((Path(__file__).parent/'radiophone_printer_cartridge.py').read_bytes().replace(b'\r\n',b'\n')).hexdigest(),
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
text('VANTRY / SERVICE WIRE  0041',(PX-PW/2+.005,PY+PH/2-.010,paper_z+.0004),.005)
copy='HOT WATER / FIELD REPORT\n\nThe hot valve turns freely.\nWater warms steadily; the\ndrain clears without backing\nup.\n\nListen again after midnight.'
text(copy,(PX-PW/2+.005,PY+PH/2-.024,paper_z+.0004),min(.0078,(PW-.01)/18.))
text('02 / 04    FILE 0041',(PX-PW/2+.005,PY-PH/2+.004,paper_z+.0004),.0045)
plate=text('VANTRY  /  TYPE 28-R',(-cover_w/2+.010,door_y,.0412),.004)
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
for view in (['front','service','back','printer','lamp','selection','impression','section'] if args.all_views else [args.view]):
    nodes['ServiceCover'].rotation_euler.x=-1.85 if view=='service' else 0.
    cam.ortho_scale=.33;target=(0,.023,0)
    eye=(.19,.13,.59) if view!='back' else (-.21,.10,-.58)
    if view=='printer':eye=(.12,.012,.33);target=(0,cy,.044);cam.ortho_scale=.235
    if view=='lamp':eye=(-.21,.17,-.28);target=(lx,ly,-.045);cam.ortho_scale=.130
    if view in ['selection','impression']:
        carriage.location.x=0
        selector.rotation_euler.z=math.tau*5/16
        selector.location.z=.0045
        impression.value=1. if view=='impression' else 0.
        hammer.location.y=(pivots['Type_hammer']-pivots['Carriage']).y+(.00125 if view=='impression' else 0.)
        eye=(.13,.015,.32);target=(0,-.038,.066);cam.ortho_scale=.15
    if view=='section':
        exports.hide_render=True;stocks.hide_render=False;stocks.hide_viewport=False
        for stock in stocks.objects:
            stock.hide_render=not stock.name.startswith(('Stock__Paper','Stock__Unbroken paper','Stock__Unprinted paper','Stock__Platen','Stock__Type selector','Stock__Replaceable type','Stock__Copy support','Stock__Ink ribbon','Stock__Feed pressure roller')) or stock.name.startswith('Stock__Platen finger')
        for stage in review.objects:
            if stage.type=='FONT':stage.hide_render=True
        eye=(.4,0,.04);target=(0,0,.04);cam.ortho_scale=.22
    o.location=coords(eye);aim(o,target)
    scene.render.filepath=str(REVIEW/f'{view}.png');bpy.ops.render.render(write_still=True)
    print('HANDHELD NATIVE REVIEW',args.concept,view,mesh_nodes,proof['triangles'])
if args.hot_preview:
    # Separate preview animation: emitted only after the canonical resting
    # asset is saved/exported. Actual runtime effects use printer events.
    exports.hide_render=False;stocks.hide_render=True
    for stage in review.objects:
        if stage.type=='FONT':stage.hide_render=False
    carriage.location.x=0;selector.location.z=0
    hammer.location.y=(pivots['Type_hammer']-pivots['Carriage']).y
    eye=(.12,.006,.27);target=(0,-.030,.068);cam.ortho_scale=.078
    o.location=coords(eye);aim(o,target)
    heat=bpy.data.materials['TypeEmboss'].node_tree.nodes['ImpressionHeat'].inputs[1]
    heat.default_value=.65
    scene.render.resolution_x=640;scene.render.resolution_y=480;scene.cycles.samples=20
    selector.rotation_euler.z=0.;scene.render.filepath=str(REVIEW/'hot_type_sharp.png');bpy.ops.render.render(write_still=True)
    scene.render.fps=240
    for frame in [0,60]:
        selector.rotation_euler.z=frame/240*math.tau*36
        selector.keyframe_insert('rotation_euler',frame=frame)
    if selector.animation_data and selector.animation_data.action:
        # Blender 5 actions use layered channels; defaults are suitable for a
        # short preview, while the runtime uses bounded analytic interpolation.
        pass
    scene.render.use_motion_blur=True;scene.render.motion_blur_shutter=1.0
    for frame in range(4,40,3):
        scene.frame_set(frame)
        scene.render.filepath=str(REVIEW/f'spin_{frame:03d}.png');bpy.ops.render.render(write_still=True)
    scene.render.use_motion_blur=False
    selector.animation_data_clear();selector.rotation_euler.z=0
    for bank,label in [(-1,'lower'),(0,'middle'),(1,'upper')]:
        selector.location.z=-bank*.0045
        for part in selector.children:
            if part.type=='MESH' and part.data.shape_keys:
                part.data.shape_keys.key_blocks['LowerSeat'].value=1. if bank==-1 else 0.
                part.data.shape_keys.key_blocks['UpperSeat'].value=1. if bank==1 else 0.
        scene.render.filepath=str(REVIEW/f'{label}_row_seated.png');bpy.ops.render.render(write_still=True)
    print('HOT TYPE NATIVE ANIMATION: 12 frames, local type-cylinder motion blur')
