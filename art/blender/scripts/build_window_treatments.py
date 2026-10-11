"""Fabricate shared crowned blind stock, hardware and sewn pleated cloth.
Blender meters: X width, Y depth, Z height; Godot imports Y up.
"""
from pathlib import Path
import math
import bpy

ROOT = Path(__file__).resolve().parents[3]
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
materials = {}
for key in ['blind_slat', 'linen', 'fabric_warm', 'brass_dull']:
    mat = bpy.data.materials.new(key); mat.use_nodes = True
    mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = .6
    materials[key] = mat

def finish(obj, name, key, bevel=0):
    obj.name = name; obj.data.materials.clear(); obj.data.materials.append(materials[key])
    if bevel:
        mod = obj.modifiers.new('Stock edge radius', 'BEVEL'); mod.width = bevel; mod.segments = 3
        bpy.context.view_layer.objects.active = obj; bpy.ops.object.modifier_apply(modifier=mod.name)
    # Meter charts. Large sheets have continuous sewn-cloth UV below.
    for previous in list(obj.data.uv_layers): obj.data.uv_layers.remove(previous)
    uv = obj.data.uv_layers.new(name='StockMetres')
    for face in obj.data.polygons:
        n = face.normal; axis = max(range(3), key=lambda i: abs(n[i]))
        axes = [(1, 2), (0, 2), (0, 1)][axis]
        for loop in face.loop_indices:
            v = obj.data.vertices[obj.data.loops[loop].vertex_index].co
            uv.data[loop].uv = (v[axes[0]], v[axes[1]])
    return obj

def box(name, size, key, bevel):
    bpy.ops.mesh.primitive_cube_add(size=1)
    obj = bpy.context.object; obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, name, key, bevel)

# A fixed 50 mm chord rotates; never reshape a box to fake tilt.
section = []
for side in [1, -1]:
    indices = range(13) if side == 1 else range(12, -1, -1)
    for i in indices:
        depth = -.025 + .05*i/12
        crown = .0015*(1-(depth/.025)**2)
        section.append((depth, crown+side*.00125))
n = len(section)
vertices = [(x, y, z) for x in [-.5,.5] for y,z in section]
faces = [tuple(reversed(range(n))),tuple(range(n,n*2))]
faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
mesh = bpy.data.meshes.new('CrownedWoodSlat'); mesh.from_pydata(vertices,[],faces); mesh.update()
slat = bpy.data.objects.new('CrownedWoodSlat',mesh); bpy.context.collection.objects.link(slat)
finish(slat,'CrownedWoodSlat','blind_slat')
uv = slat.data.uv_layers.active
perimeter = [0.0]
for i in range(n-1): perimeter.append(perimeter[-1]+math.dist(section[i],section[i+1]))
for face in mesh.polygons:
    for loop in face.loop_indices:
        index = mesh.loops[loop].vertex_index
        uv.data[loop].uv = (vertices[index][0]+.5, perimeter[index%n]) if len(face.vertices)==4 else (vertices[index][1],vertices[index][2])
for face in mesh.polygons: face.use_smooth = len(face.vertices)==4
box('HeadRail',(1,.065,.052),'blind_slat',.004)
box('BottomRail',(1,.05,.024),'blind_slat',.003)
box('MountBracket',(.032,.07,.055),'brass_dull',.001)
box('CurtainRod',(1,.014,.014),'brass_dull',.003)
box('CurtainBracket',(.018,.18,.04),'brass_dull',.002)
box('SewnTab',(.012,.012,.040),'linen',.001)
box('CordStock',(.003,.003,1),'linen',.0005)
box('LadderRung',(1,.0025,.0025),'linen',.0004)
box('CordTassel',(.018,.018,.045),'blind_slat',.005)
box('TiltWand',(.009,.009,.42),'blind_slat',.002)

# Closed, double-sided cloth with a shallow gathered crown and generous folds.
# Top is Z=0; normalized length descends to Z=-1.
nx, ny = 64, 24
vertices = []
for side in [-1,1]:
    for j in range(ny+1):
        v=j/ny
        for i in range(nx+1):
            u=i/nx
            wave=math.sin(u*math.tau*8+.08*math.sin(v*math.pi))
            depth=.042*wave*(.78+.22*v)+.006*math.sin(v*math.pi*3+u*8)
            # Sewn lower hem has physical thickness, not a painted shadow.
            thickness=.0015 if v<.95 else .003
            vertices.append((u-.5,depth+side*thickness/2,-v))
row=nx+1; layer=row*(ny+1); faces=[]
for side in range(2):
    for j in range(ny):
        for i in range(nx):
            a=side*layer+j*row+i; face=(a,a+1,a+1+row,a+row)
            faces.append(face if side else tuple(reversed(face)))
for j in range(ny):
    for i in [0,nx]:
        a=j*row+i;faces.append((a,a+row,a+row+layer,a+layer))
for i in range(nx):
    for j in [0,ny]:
        a=j*row+i;faces.append((a,a+layer,a+layer+1,a+1))
mesh=bpy.data.meshes.new('PleatedSewnPanel');mesh.from_pydata(vertices,[],faces);mesh.update()
obj=bpy.data.objects.new('PleatedSewnPanel',mesh);bpy.context.collection.objects.link(obj)
finish(obj,'PleatedSewnPanel','linen')
for face in mesh.polygons:
    face.use_smooth=True
    if face.index>=2*nx*ny:continue
    for loop in face.loop_indices:
        v=mesh.vertices[mesh.loops[loop].vertex_index].co
        obj.data.uv_layers.active.data[loop].uv=(v.x+.5,-v.z)

for obj in bpy.context.scene.objects:
    if obj.type!='MESH':continue
    bpy.context.view_layer.objects.active=obj;obj.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.object.mode_set(mode='OBJECT');obj.select_set(False)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/window_treatments.blend'))
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/window_treatments.glb'),export_format='GLB',export_yup=True,export_apply=True)
