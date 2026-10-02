"""Four shared roof ventilators: formed sheet hood, motor, guard and live parts."""
from pathlib import Path
import math
import bpy, bmesh
ROOT=Path(__file__).resolve().parents[3]
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
def material(name,color,metal,rough):
    m=bpy.data.materials.new(name); m.use_nodes=True
    s=m.node_tree.nodes['Principled BSDF']; s.inputs['Base Color'].default_value=(*color,1)
    s.inputs['Metallic'].default_value=metal; s.inputs['Roughness'].default_value=rough
    return m
paint=material('trim',(.39,.40,.38),0,.55)
iron=material('cast_iron',(.18,.19,.17),.5,.6)
panel=material('enamel',(.44,.44,.40),0,.4)
brass=material('brass_dull',(.48,.35,.16),.7,.5)
rubber=material('rubber_aged',(.1,.095,.085),0,.8)
groups={k:[] for k in ['Paint','Iron','Panel','Brass','Rubber','Rotor','Shutter']}
def keep(o,name,mat,group):
    o.name=name; o.data.materials.append(mat); groups[group].append(o); return o
def box(name,at,size,mat,group,bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1,location=(at[0],-at[2],at[1]))
    o=bpy.context.object; o.dimensions=(size[0],size[2],size[1])
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=o.modifiers.new('Formed edge','BEVEL'); mod.width=bevel; mod.segments=3
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return keep(o,name,mat,group)
def cylinder(name,at,radius,depth,mat,group,axis='y'):
    rotation=(0,math.pi/2,0) if axis=='x' else ((math.pi/2,0,0) if axis=='z' else (0,0,0))
    bpy.ops.mesh.primitive_cylinder_add(vertices=64,radius=radius,depth=depth,location=(at[0],-at[2],at[1]),rotation=rotation)
    return keep(bpy.context.object,name,mat,group)
def lathe(name,profile,mat,group):
    n=96; v=[(r*math.cos(i*math.tau/n),-r*math.sin(i*math.tau/n),y) for r,y in profile for i in range(n)]
    f=[]
    for j in range(len(profile)):
        for i in range(n): f.append((j*n+i,j*n+(i+1)%n,((j+1)%len(profile))*n+(i+1)%n,((j+1)%len(profile))*n+i))
    mesh=bpy.data.meshes.new(name); mesh.from_pydata(v,[],f); mesh.update()
    o=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(o); return keep(o,name,mat,group)
def square_ring(name,outer,inner,low,high,bevel):
    vertices=[]; faces=[]
    for half,y in [(outer*.5,low),(outer*.5,high),(inner*.5,high),(inner*.5,low)]:
        for x,z in [(-half,-half),(half,-half),(half,half),(-half,half)]:
            vertices.append((x,-z,y))
    for row in range(4):
        for side in range(4):
            faces.append((row*4+side,row*4+(side+1)%4,((row+1)%4)*4+(side+1)%4,((row+1)%4)*4+side))
    mesh=bpy.data.meshes.new(name); mesh.from_pydata(vertices,[],faces); mesh.update()
    obj=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active=obj; obj.select_set(True)
    modifier=obj.modifiers.new('Formed ring edges','BEVEL'); modifier.width=bevel; modifier.segments=3
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    return keep(obj,name,paint,'Paint')

# The 200 mm curb throat clears the 180 mm duct; flashing laps its 2 mm wall.
square_ring('RoofCurb',.72,.20,0,.16,.008)
square_ring('CurbFlashing',.66,.176,.157,.169,.003)
# Actual formed walls leave the rotor throat hollow.
for x in [-.286,.286]: box('SideWall',(x,.398,0),(.008,.458,.58),paint,'Paint',.002)
for z in [-.286,.286]: box('EndWall',(0,.398,z),(.564,.458,.008),paint,'Paint',.002)
# Square-to-round top apron closes the housing corners around the bell mouth.
n=96; vertices=[]; faces=[]
for outer,y in [(True,.627),(True,.631),(False,.631),(False,.627)]:
    for i in range(n):
        a=i*math.tau/n; c=math.cos(a); s=math.sin(a)
        r=.294/max(abs(c),abs(s)) if outer else .291
        vertices.append((r*c,-r*s,y))
for j in range(4):
    for i in range(n): faces.append((j*n+i,j*n+(i+1)%n,((j+1)%4)*n+(i+1)%n,((j+1)%4)*n+i))
data=bpy.data.meshes.new('ThroatApron'); data.from_pydata(vertices,[],faces); data.update()
o=bpy.data.objects.new('ThroatApron',data); bpy.context.collection.objects.link(o); keep(o,'ThroatApron',paint,'Paint')
lathe('BellMouth',[(.282,.60),(.287,.61),(.338,.78),(.344,.795),(.344,.805),(.333,.805),(.330,.792),(.279,.615)],paint,'Paint')
# Solid centre and underside, with rolled drip edge. Four braces carry the hood.
lathe('RainHood',[(0,.944),(.12,.942),(.32,.925),(.425,.902),(.436,.894),(.436,.882),(.429,.878),(.420,.883),(.420,.894),(.318,.917),(.12,.934),(0,.936)],paint,'Paint')
for a in [0,math.pi/2,math.pi,3*math.pi/2]:
    box('HoodBrace',(.255*math.cos(a),.845,.255*math.sin(a)),(.024,.153,.024),iron,'Iron',.002)
    cylinder('BraceBolt',(.255*math.cos(a),.925,.255*math.sin(a)),.009,.006,brass,'Brass')
cylinder('MotorHousing',(.25,.46,.03),.105,.29,iron,'Iron','x')
cylinder('MotorEndBell',(.401,.46,.03),.098,.012,iron,'Iron','x')
for x in [.15,.18,.21,.24,.27,.30,.33,.36]: cylinder('CoolingRib',(x,.46,.03),.112,.007,iron,'Iron','x')
box('MotorFoot',(.28,.333,.03),(.26,.025,.22),iron,'Iron',.004)
box('BeltGuard',(.305,.42,-.32),(.15,.38,.07),iron,'Iron',.025)
box('ServicePanel',(-.10,.42,-.298),(.31,.30,.012),panel,'Panel',.006)
box('BlankMakerPlate',(-.10,.47,-.306),(.13,.055,.004),brass,'Brass',.003)
for x,y in [(-.235,.29),(-.235,.55),(.035,.29),(.035,.55),(.305,.26),(.305,.58)]:
    cylinder('PanelFastener',(x,y,-.31 if x<.1 else -.359),.008,.006,brass,'Brass','z')
for x in [-.27,.27]:
    for z in [-.27,.27]: cylinder('CurbPad',(x,.012,z),.035,.024,rubber,'Rubber')
# Meshes remain local to the original animated pivots in Godot.
cylinder('RotorHub',(0,0,0),.045,.055,iron,'Rotor')
for i in range(4):
    a=i*math.pi/2
    o=box('RotorBlade',(.12*math.sin(a),0,-.12*math.cos(a)),(.10,.008,.24),panel,'Rotor',.003)
    o.rotation_euler.z=-a-math.radians(18)
for i in range(4):
    o=box('GravitySlat',(0,-.075+i*.05,0),(.26,.042,.006),panel,'Shutter',.002)
for o in list(bpy.context.scene.objects):
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active=o
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    mesh=bmesh.new(); mesh.from_mesh(o.data)
    bmesh.ops.remove_doubles(mesh,verts=list(mesh.verts),dist=.0000001)
    bmesh.ops.triangulate(mesh,faces=list(mesh.faces))
    bmesh.ops.recalc_face_normals(mesh,faces=list(mesh.faces))
    mesh.to_mesh(o.data); mesh.free(); o.data.update()
    for layer in list(o.data.uv_layers): o.data.uv_layers.remove(layer)
    uv=o.data.uv_layers.new(name='Metres'); uv.active_render=True
    for face in o.data.polygons:
        axis=max(range(3),key=lambda i:abs(face.normal[i])); axes=((1,2),(0,2),(0,1))[axis]
        for loop in face.loop_indices:
            v=o.data.vertices[o.data.loops[loop].vertex_index].co
            uv.data[loop].uv=(v[axes[0]],v[axes[1]])
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/roof_ventilator.blend'))
for name,parts in groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for o in parts: o.select_set(True)
    bpy.context.view_layer.objects.active=parts[0]; bpy.ops.object.join(); bpy.context.object.name=name
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/roof_ventilator.glb'),export_format='GLB',export_yup=True,export_apply=True,export_tangents=True)
