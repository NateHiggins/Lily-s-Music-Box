"""V2 bridge faucet and bearing saddles. Godot coordinates, metres, native solids."""
from pathlib import Path
import ast, hashlib, json, math, sys
import bpy, bmesh, numpy as np
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(Path(__file__).parent))
from fabrication_uvs import chart_for_triangle
from check_exported_tangents import validate
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version=0
OUT=ROOT/'tmp/v2-kitchen-sinks-20261012';OUT.mkdir(parents=True,exist_ok=True)
def p(v):return Vector((v[0],-v[2],v[1]))
def group(name,at=(0,0,0)):
    o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.location=p(at);return o
def mat(name,color,metal,rough):
    m=bpy.data.materials.new(name);m.use_nodes=True;s=m.node_tree.nodes['Principled BSDF']
    s.inputs['Base Color'].default_value=(*color,1);s.inputs['Metallic'].default_value=metal;s.inputs['Roughness'].default_value=rough;return m
nickel=mat('faucet_nickel',(.72,.71,.67),.85,.24)
enamel=mat('porcelain_fixture',(.9,.88,.82),0,.23)
iron=mat('cast_iron',(.16,.16,.15),.7,.6)
native=[]
def finish(obj,name,material,parent,bevel=0):
    obj.name=name;obj.data.materials.append(material)
    bpy.context.view_layer.objects.active=obj
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        m=obj.modifiers.new('Manufactured edge','BEVEL');m.width=bevel;m.segments=3;bpy.ops.object.modifier_apply(modifier=m.name)
    bpy.context.view_layer.update()
    world=obj.matrix_world.copy();obj.parent=parent;obj.matrix_world=world
    return obj
def cylinder(name,at,radius,length,material,parent,axis=(0,1,0),sides=32):
    bpy.ops.mesh.primitive_cylinder_add(vertices=sides,radius=radius,depth=length,location=p(at));o=bpy.context.object
    o.rotation_mode='QUATERNION';o.rotation_quaternion=Vector((0,0,1)).rotation_difference(p(axis))
    return finish(o,name,material,parent,.0007)
def box(name,at,size,material,parent):
    bpy.ops.mesh.primitive_cube_add(size=1,location=p(at));o=bpy.context.object;o.dimensions=(size[0],size[2],size[1]);return finish(o,name,material,parent,.001)
def tube(name,points,outer,inner,material,parent):
    # Continuous hollow swept casting, including annular ends. Outlet has a
    # real 16 mm water passage; no dark disc or capped cylinder conceals it.
    verts=[];n=32
    for i,q in enumerate(points):
        tangent=p(np.array(points[min(i+1,len(points)-1)])-np.array(points[max(0,i-1)]));tangent.normalize()
        u=Vector((1,0,0));v=tangent.cross(u).normalized()
        for r in [outer,inner]:
            verts.extend(p(q)+r*(u*math.cos(j*math.tau/n)+v*math.sin(j*math.tau/n)) for j in range(n))
    faces=[]
    for i in range(len(points)-1):
        for layer in [0,1]:
            for j in range(n):
                a=i*n*2+layer*n+j;b=i*n*2+layer*n+(j+1)%n;faces.append((a,b,b+n*2,a+n*2))
    for i in [0,len(points)-1]:
        for j in range(n):
            a=i*n*2+j;b=i*n*2+(j+1)%n;faces.append((a,b,b+n,a+n))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update();o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o)
    return finish(o,name,material,parent)

for compact in [False,True]:
    family=group('Compact' if compact else 'Standard');top=.9175 if compact else .9;depth=.38 if compact else .46
    # Same valve centers as the retained water controls, seated into the splash.
    y=top+.11;z=depth*.5-.035
    fixed=group(family.name+'Fixed');fixed.parent=family
    for i,x in enumerate([-.095,.095]):
        cylinder('Escutcheon',(x,y,z+.006),.033,.018,nickel,fixed,(0,0,1))
        cylinder('HexGland',(x,y,z-.015),.024,.031,nickel,fixed,(0,0,1),6)
        cylinder('ValveStem',(x,y,z-.038),.011,.04,nickel,fixed,(0,0,1))
        handle=group(('Hot' if i==0 else 'Cold')+'Valve'+family.name,(x,y,z));handle.parent=family
        for axis in [(1,0,0),(0,1,0)]:
            cylinder('RoundedCross',(x,y,z-.052),.007,.081,nickel,handle,axis)
        cylinder('PorcelainIndex',(x,y,z-.061),.013,.009,enamel,handle,(0,0,1))
    cylinder('Bridge',(0,y,z-.02),.012,.19,nickel,fixed,(1,0,0))
    cylinder('SwivelUnion',(0,y+.015,z-.02),.019,.033,nickel,fixed)
    basez=z-.02;endz=.015;radius=(basez-endz)/2;centerz=(basez+endz)/2
    neck_y=y+.13
    points=[(0,y,basez),(0,neck_y,basez)]
    points.extend((0,neck_y+radius*math.sin(a),centerz+radius*math.cos(a)) for a in np.linspace(0,math.pi,41)[1:])
    points.append((0,top+.13,endz))
    tube('HollowGooseneck',points,.012,.008,nickel,fixed)
    tube('OutletLip',[(0,top+.15,endz),(0,top+.126,endz)],.016,.008,nickel,fixed)

# Four adjustable cast bearers seat on the existing .75 m frame, under the
# standard sink rim and drainboard. No furniture identity/collision is replaced.
bearing=group('StandardBearers')
for x in [-.335,.775]:
    for z in [-.215,.215]:
        box('BearingFoot',(x,.754,z),(.046,.012,.048),iron,bearing)
        cylinder('Adjuster',(x,.804,z),.009,.094,iron,bearing)
        cylinder('LockNut',(x,.765,z),.016,.012,nickel,bearing,sides=6)
        box('Carrier',(x,.850,z),(.05,.044,.035),iron,bearing)
for z in [-.215,.215]:
    box('BearingRail',(.22,.878,z),(1.16,.012,.034),iron,bearing)
    box('RimSeat',(-.285,.88575,z),(.035,.0035,.034),iron,bearing)

frame=group('IndependentFrame')
for x in [-.335,.775]:
    for z in [-.215,.215]:
        box('FrameLeg',(x,.34,z),(.045,.68,.045),iron,frame)
for z in [-.215,.215]:box('FrameRail',(.22,.715,z),(1.16,.07,.035),iron,frame)
for x in [-.335,.775]:box('FrameEnd',(x,.715,0),(.035,.07,.43),iron,frame)

# Retain each source solid; assign metre UVs to final triangulated geometry.
for obj in list(bpy.context.scene.objects):
    if obj.type!='MESH':continue
    bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    assert all(e.is_manifold for e in bm.edges),obj.name
    assert bm.calc_volume(signed=True)>0,obj.name
    native.append({'part':obj.name,'closed':True,'volume_m3':bm.calc_volume(signed=True)})
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
    bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-6)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bmesh.ops.triangulate(bm,faces=list(bm.faces))
    bm.to_mesh(obj.data);bm.free()
    for face in obj.data.polygons:face.use_smooth=True
    obj.data.set_sharp_from_angle(angle=.5)
    obj.data.update()
    corners=[n.vector[:] for n in obj.data.corner_normals]
    verts=[];faces=[];charts=[];normals=[]
    for face in obj.data.polygons:
        points=np.array([obj.data.vertices[v].co[:] for v in face.vertices]);_,_,chart,_=chart_for_triangle(points,np.zeros(3),.18)
        start=len(verts);verts.extend(points);faces.append((start,start+1,start+2));charts.extend(chart);normals.extend(corners[i] for i in face.loop_indices)
    mesh=bpy.data.meshes.new(obj.name+'Surface');mesh.from_pydata(verts,[],faces);mesh.update()
    mesh.materials.append(obj.data.materials[0]);obj.data=mesh
    for face in mesh.polygons:face.use_smooth=True
    mesh.normals_split_custom_set(normals)
    uv=mesh.uv_layers.new(name='MetreSurface')
    for loop,val in zip(uv.data,charts):loop.uv=val
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/kitchen_faucet.blend'),compress=True)
source=Path(__file__).with_name('build_media_battery_supply.py');tree=ast.parse(source.read_text(encoding='utf-8'))
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.ClassDef) and n.name=='ExportDerivatives'],type_ignores=[]),str(source),'exec'))
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExportDerivatives
asset=ROOT/'game/assets/props/kitchen_faucet.glb'
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',export_tangents=True,export_lights=False,export_cameras=False)
proof={'evidence_class':'INERT','native':native,'export':validate(asset),'asset_sha256':hashlib.sha256(asset.read_bytes()).hexdigest()}
(OUT/'construction.json').write_text(json.dumps(proof,indent=2)+'\n',encoding='utf-8',newline='\n')
print('KITCHEN FAUCET:',len(native),'closed stocks',proof['export'])
