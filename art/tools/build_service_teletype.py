"""Editable Blender teletype attachment. Dimensions are metres in Godot axes.
Run with blender --background --python art/tools/build_service_teletype.py.
No lettering is baked: production Label3D owns every printed character.
"""
import math
from pathlib import Path
import bpy
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

def material(name, color, metal, rough):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Metallic'].default_value = metal
    p.inputs['Roughness'].default_value = rough
    # Deterministic, original PBR surfaces; no photographic bytes or lettering.
    # UV textures are embedded in both the editable blend and exported GLB.
    rng=np.random.default_rng(sum(name.encode()))
    n=512
    grain=rng.random((n,n)).astype('float32')
    brushed=np.repeat(rng.random((n,1)),n,axis=1)
    wear=np.clip(.88+.09*grain+.04*brushed,0,1)
    for channel in ['color','roughness','normal']:
        pixels=np.ones((n,n,4),dtype='float32')
        if channel=='color': pixels[:,:,:3]=wear[:,:,None]*np.array(color)
        elif channel=='roughness': pixels[:,:,:3]=np.clip(rough+(grain-.5)*.13,0,1)[:,:,None]
        else:
            pixels[:,:,:2]=.5+(grain[:,:,None]-.5)*.12
            pixels[:,:,2]=1.0
        im=bpy.data.images.new(name+' '+channel,width=n,height=n)
        if channel!='color': im.colorspace_settings.name='Non-Color'
        im.pixels.foreach_set(pixels.ravel()); im.pack()
        tex=m.node_tree.nodes.new('ShaderNodeTexImage'); tex.image=im
        if channel=='normal':
            normal=m.node_tree.nodes.new('ShaderNodeNormalMap')
            normal.inputs['Strength'].default_value=.18
            m.node_tree.links.new(tex.outputs['Color'],normal.inputs['Color'])
            m.node_tree.links.new(normal.outputs['Normal'],p.inputs['Normal'])
        else: m.node_tree.links.new(tex.outputs['Color'],p.inputs['Base Color' if channel=='color' else 'Roughness'])
    return m

brass = material('Aged machined brass', (.32,.22,.09), .82,.32)
steel = material('Blued tool steel', (.035,.045,.052), .8,.28)
rubber = material('Platen rubber', (.028,.022,.018), 0,.83)
ivory = material('Ceramic guide rollers', (.72,.64,.45), .05,.38)
ribbon = material('Carbon ink ribbon', (.032,.012,.016), 0,.92)
paper = material('Uncoated rag paper', (.88,.79,.60), 0,.92)
static = []

def finish(obj,name,at,mat,moving=False):
    obj.name = name
    obj.location = (at[0],-at[2],at[1])
    obj.data.materials.append(mat)
    bevel = obj.modifiers.new('Machined softened edges','BEVEL')
    bevel.width = .00055
    bevel.segments = 3
    obj.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL')
    if not moving: static.append(obj)
    return obj

def box(name,at,size,mat,moving=False):
    bpy.ops.mesh.primitive_cube_add()
    o=bpy.context.object
    o.scale=(size[0]/2,size[2]/2,size[1]/2)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(o,name,at,mat,moving)

def cylinder(name,at,radius,length,mat,axis='x',moving=False):
    bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=radius,depth=length)
    o=bpy.context.object
    if axis=='x': o.rotation_euler[1]=math.pi/2
    elif axis=='z': o.rotation_euler[0]=math.pi/2
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    for p in o.data.polygons: p.use_smooth=True
    return finish(o,name,at,mat,moving)

box('Printer frame',(0,.012,.062),(.202,.184,.014),steel)
box('Paper bed',(0,.025,.075),(.174,.157,.006),brass)
box('Paper',(0,.034,.080),(.163,.145,.0007),paper,True)
for x in [-.097,.097]:
    box('Folded brass cheek',(x,.01,.083),(.009,.181,.025),brass)
    for y in [-.068,.086]:
        cylinder('Slotted screw',(x,y,.098),.0032,.003,steel,'z')
        box('Screw slot',(x,y,.0996),(.004,.0006,.0005),brass)
    for y in [-.04,.06]:
        cylinder('Paper edge guide',(x*.86,y,.085),.004,.018,ivory,'y')
cylinder('Platen',(0,-.055,.086),.009,.176,rubber,moving=True)
cylinder('Guide rail',(0,-.070,.105),.0022,.194,steel)
cylinder('Return rail',(0,-.078,.100),.0016,.188,brass)
box('Carriage',(0,-.068,.109),(.023,.020,.014),brass,True)
box('Type hammer',(0,-.052,.100),(.005,.013,.008),steel,True)
box('Ink ribbon',(0,-.048,.097),(.176,.006,.001),ribbon)
for x,name in [(-.075,'SupplySpool'),(.075,'TakeupSpool')]:
    cylinder(name,(x,-.091,.096),.016,.006,steel,'z',True)
    cylinder('Ribbon winding',(x,-.091,.100),.012,.004,ribbon,'z')
    cylinder('Spool hub',(x,-.091,.104),.003,.005,brass,'z')
    for i in range(8):
        a=i*math.tau/8
        cylinder('Spool spoke rivet',(x+math.cos(a)*.013,-.091+math.sin(a)*.013,.101),.001,.002,brass,'z')
for x in [-.105,.105]:
    cylinder('Feed thumbwheel',(x,-.055,.086),.014,.012,brass)
    for i in range(32):
        a=i*math.tau/32
        cylinder('Knurl',(x,-.055+math.cos(a)*.014,.086+math.sin(a)*.014),.0007,.012,steel)
for i in range(24):
    box('Escapement rack tooth',(-.086+i*.0075,-.079,.112),(.003,.003,.003),brass)
for i in range(39):
    box('Serrated tear edge',(-.078+i*.004,.108,.084),(.002,.004,.0015),steel)
for i in range(16):
    cylinder('Return spring winding',(.104,-.01+i*.003,.080),.005,.001,steel,'y')

# Rebuildable outer fabrication: folded shell, separate seams, a gripped dry-cell
# compartment and inspectable transmission. The original 28-R remains the core.
case=material('Worn black japanned steel',(.075,.068,.055),.52,.39)
grip=material('Brown vulcanised grip',(.10,.055,.033),0,.78)
nickel=material('Turned nickel',(.52,.50,.45),.93,.27)
box('Folded back shell',(0,-.035,.047),(.228,.285,.014),case)
for x in [-.113,.113]:
    box('Rolled housing flange',(x,-.035,.067),(.006,.285,.038),brass)
    for y in [-.165,-.116,.014,.097]:
        cylinder('Captive housing screw',(x,y,.090),.003,.003,nickel,'z')
        box('Housing screw slot',(x,y,.0918),(.004,.0006,.0004),steel)
box('Battery grip body',(0,-.146,.068),(.185,.062,.031),grip)
for i in range(19):
    box('Moulded grip rib',(-.081+i*.009,-.146,.085),(.003,.049,.002),rubber)
for y in [-.113,-.178]: box('Battery seam',(0,y,.084),(.200,.003,.005),brass)

def pivot(name,at):
    obj=bpy.data.objects.new(name,None); bpy.context.collection.objects.link(obj)
    obj.location=(at[0],-at[2],at[1]); return obj

def attach(obj,parent):
    if obj in static: static.remove(obj)
    bpy.context.view_layer.update()
    transform=obj.matrix_world.copy(); obj.parent=parent; obj.matrix_world=transform
    return obj

cover=pivot('ServiceCover',(0,-.116,.096))
attach(box('Hinged inspection cover',(0,-.142,.101),(.132,.048,.003),case),cover)
for x in [-.067,.067]:
    attach(cylinder('Hinge knuckle',(x,-.116,.096),.0035,.012,nickel),cover)
    attach(cylinder('Quarter turn latch',(x*.84,-.158,.105),.004,.004,brass,'z'),cover)
    attach(box('Latch blade',(x*.84,-.158,.108),(.005,.001,.001),steel),cover)
for x,r in [(-.043,.015),(-.014,.020),(.023,.017),(.054,.011)]:
    gear=pivot('FeedGear',(x,-.141,.089))
    attach(cylinder('Gear web',(x,-.141,.089),r,.003,brass,'z'),gear)
    for tooth in range(24):
        a=tooth*math.tau/24
        ob=box('Cut gear tooth',(x+math.cos(a)*r,-.141+math.sin(a)*r,.089),(.003,.003,.004),nickel)
        attach(ob,gear)
    cylinder('Gear bearing',(x,-.141,.094),.003,.002,steel,'z')

# Separate pivots are actuated from the existing light, radio and paper owners.
for name,x in [('LampSwitch',-.087),('RadioSwitch',.087)]:
    cylinder('Switch escutcheon',(x,-.105,.100),.010,.003,brass,'z')
    lever=pivot(name,(x,-.105,.103))
    attach(box('Switch contact lever',(x,-.098,.107),(.003,.016,.004),nickel),lever)
    attach(cylinder('Phenolic switch tip',(x,-.090,.107),.003,.007,grip),lever)
wheel=pivot('FocusWheel',(.117,.057,.083))
attach(cylinder('Reading rack handwheel',(.117,.057,.083),.014,.012,brass),wheel)
for i in range(36):
    a=i*math.tau/36
    attach(cylinder('Reading wheel knurl',(.117,.057+math.cos(a)*.014,.083+math.sin(a)*.014),.0006,.012,nickel),wheel)
for name,x in [('OrderJewel',-.056),('NetJewel',0),('LampJewel',.056)]:
    cylinder('Jewel bezel',(x,-.105,.101),.005,.004,nickel,'z')
    cylinder(name,(x,-.105,.104),.0037,.002,ivory,'z',True)

# Capped expansion fittings are physical preparation, not fictional abilities.
for name,x in [('ProbeSocket',-.107),('AudioSocket',.107)]:
    cylinder(name,(x,-.055,.047),.006,.009,nickel,'x',True)
for name,at in [('CameraAccessoryMount',(0,.119,.045)),('FilmCassetteMount',(0,-.155,.030)),('ServiceProbeMount',(-.119,-.024,.051))]:
    pivot(name,at)
for x in [-.075,.075]:
    box('Canvas strap anchor',(x,-.176,.053),(.018,.005,.018),nickel)

# Ordinary tungsten torch on a bolted shoulder saddle. Ring profiles leave the
# reflector open; the optical scene light remains PlayerController's authority.
box('Torch shoulder saddle',(-.054,.112,.020),(.066,.018,.043),brass)
cylinder('Torch barrel',(-.054,.133,.004),.026,.050,case,'z')
for z in [-.025,-.019,.026]:
    bpy.ops.mesh.primitive_torus_add(major_radius=.026,minor_radius=.0022,major_segments=64,minor_segments=12)
    obj=bpy.context.object; obj.rotation_euler[0]=math.pi/2
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    finish(obj,'Turned torch retaining ring',(-.054,.133,z),nickel)
for i in range(40):
    a=i*math.tau/40
    cylinder('Torch grip flute',(-.054+math.cos(a)*.026,.133+math.sin(a)*.026,.008),.00065,.023,brass,'z')
cylinder('TorchLens',(-.054,.133,-.026),.023,.002,ivory,'z',True)
cylinder('Rear bulb access cap',(-.054,.133,.031),.020,.006,brass,'z')
box('Bulb cap coin slot',(-.054,.133,.035),(.026,.002,.001),steel)

# Merge fixed hardware; named moving assemblies remain independently addressable.
bpy.ops.object.select_all(action='DESELECT')
for o in static: o.select_set(True)
bpy.context.view_layer.objects.active=static[0]
bpy.ops.object.convert(target='MESH')
bpy.ops.object.join()
bpy.context.object.name='PrinterFixedHardware'
source=ROOT/'art/models/service_teletype'
target=ROOT/'game/assets/device/service_teletype'
source.mkdir(parents=True,exist_ok=True); target.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(source/'service_teletype.blend'))
bpy.ops.export_scene.gltf(filepath=str(target/'service_teletype.glb'),export_format='GLB',export_apply=True)
