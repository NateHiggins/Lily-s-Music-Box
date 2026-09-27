"""V2 enamel wayfinding hardware, metres. Lettering stays runtime Label3D.
Run: blender -b -P art/blender/scripts/build_wayfinding_plate.py
"""
from pathlib import Path
import math
import bpy

ROOT = Path(__file__).resolve().parents[3]
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for old in list(bpy.data.materials): bpy.data.materials.remove(old)

def point(x,y,z): return (x,-z,y)

def material(name,color,metal,rough):
    m=bpy.data.materials.new(name); m.use_nodes=True
    s=m.node_tree.nodes['Principled BSDF']
    s.inputs['Base Color'].default_value=(*color,1)
    s.inputs['Metallic'].default_value=metal
    s.inputs['Roughness'].default_value=rough
    return m

enamel=material('enamel_appliance',(.75,.71,.59),0,.35)
brass=material('brass',(.46,.30,.12),.8,.38)
dark=material('rubber_aged',(.03,.025,.02),0,.8)

def outline(w,h,r):
    result=[]
    for cx,cy,start in [(w/2-r,h/2-r,0),(-w/2+r,h/2-r,90),
                        (-w/2+r,-h/2+r,180),(w/2-r,-h/2+r,270)]:
        for i in range(9):
            a=math.radians(start+i*90/8)
            result.append((cx+r*math.cos(a),cy+r*math.sin(a)))
    return result

def mesh_part(name,vertices,faces,mat):
    mesh=bpy.data.meshes.new(name); mesh.from_pydata(vertices,[],faces); mesh.update()
    obj=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj

edge=outline(1.3,.48,.035); n=len(edge)
plate=mesh_part('EnamelPlate',[point(x,y,z) for z in [-.0125,.0125] for x,y in edge],
    [tuple(reversed(range(n))),tuple(range(n,2*n))]+
    [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],enamel)
inner=outline(1.282,.462,.026)
mesh_part('RolledBorder',[point(x,y,z) for z,loop in [(.009,edge),(.014,edge),(.014,inner),(.009,inner)] for x,y in loop],
    [(j*n+i,j*n+(i+1)%n,((j+1)%4)*n+(i+1)%n,((j+1)%4)*n+i) for j in range(4) for i in range(n)],brass)

def cylinder(name,x,y,z,r,depth,mat):
    bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=r,depth=depth,location=point(x,y,z))
    obj=bpy.context.object; obj.name=name; obj.rotation_euler.x=math.pi/2
    obj.data.materials.append(mat)
    return obj

for i,(x,y) in enumerate([(-.61,-.20),(.61,-.20),(-.61,.20),(.61,.20)]):
    cylinder('WallSpacer',x,y,-.01875,.014,.0125,dark)
    marker=bpy.data.objects.new('WallSeat_'+str(i),None)
    bpy.context.collection.objects.link(marker); marker.location=point(x,y,-.025)
    cylinder('ScrewWasher',x,y,.013,.0105,.001,brass)
    head=cylinder('SlottedScrew',x,y,.016,.0065,.005,brass)
    bpy.ops.mesh.primitive_cube_add(size=1,location=point(x,y,.0182))
    cutter=bpy.context.object; cutter.scale=(.010,.003,.0016)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    bpy.context.view_layer.objects.active=head
    mod=head.modifiers.new('Screw slot','BOOLEAN'); mod.operation='DIFFERENCE'; mod.object=cutter
    bpy.ops.object.modifier_apply(modifier=mod.name); bpy.data.objects.remove(cutter,do_unlink=True)

for obj in list(bpy.context.scene.objects):
    if obj.type!='MESH': continue
    bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True)
    bpy.context.view_layer.objects.active=obj
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.uv.smart_project(island_margin=.01)
    bpy.ops.object.mode_set(mode='OBJECT')
    bevel=obj.modifiers.new('Manufactured edges','BEVEL'); bevel.width=.0004; bevel.segments=3
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    normal=obj.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
    bpy.ops.object.modifier_apply(modifier=normal.name)

# Keep each fitting editable in Blender; ship three shared material meshes.
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/wayfinding_plate.blend'))
for mat in [enamel,brass,dark]:
    parts=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.data.materials[0]==mat]
    bpy.ops.object.select_all(action='DESELECT')
    for obj in parts: obj.select_set(True)
    bpy.context.view_layer.objects.active=parts[0]; bpy.ops.object.join()
    parts[0].name='Plate_'+mat.name
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/wayfinding_plate.glb'),export_format='GLB',export_yup=True,export_apply=True)
