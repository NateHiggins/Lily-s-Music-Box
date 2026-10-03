"""Open sheet-metal flue library, in metres; Godot owns installed lengths.

Elbow: incoming +Y, outgoing +X, virtual corner at origin in Godot.
Pipe: one metre along Godot Y; slip band: 45 mm along the same axis.
"""
from pathlib import Path
import math
import bpy

ROOT = Path(__file__).resolve().parents[3]
RADIUS, BEND, THICKNESS, SIDES = .17, .27, .003, 48
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
materials = {}
for key, color, rough in [('cast_iron', (.12, .105, .09, 1), .78),
                         ('metal', (.28, .26, .23, 1), .62)]:
    mat = bpy.data.materials.new(key)
    mat.use_nodes = True
    shader = mat.node_tree.nodes['Principled BSDF']
    shader.inputs['Base Color'].default_value = color
    shader.inputs['Roughness'].default_value = rough
    materials[key] = mat

def shell(name, stations, outer, inner, material):
    # Each station is (Godot x,y, tangent_x,tangent_y, arc distance).
    verts, faces, tex = [], [], []
    for radius in [outer, inner]:
        for x,y,tx,ty,d in stations:
            for j in range(SIDES):
                angle = j*math.tau/SIDES
                gx = x+ty*radius*math.cos(angle)
                gy = y-tx*radius*math.cos(angle)
                gz = radius*math.sin(angle)
                verts.append((gx,-gz,gy))
                tex.append((j/SIDES*math.tau*RADIUS,d))
    n = len(stations); layer=n*SIDES
    for side in range(2):
        for i in range(n-1):
            for j in range(SIDES):
                a=side*layer+i*SIDES+j; b=side*layer+i*SIDES+(j+1)%SIDES
                face=(a,b,b+SIDES,a+SIDES)
                faces.append(face if side==0 else tuple(reversed(face)))
    for end in [0,n-1]:
        for j in range(SIDES):
            a=end*SIDES+j; b=end*SIDES+(j+1)%SIDES
            faces.append((a,a+layer,b+layer,b))
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(verts,[],faces); mesh.update()
    obj=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(obj)
    mesh.materials.append(materials[material])
    uv=mesh.uv_layers.new(name='UVMap')
    for polygon in mesh.polygons:
        vals=[tex[mesh.loops[i].vertex_index] for i in polygon.loop_indices]
        seam=max(v[0] for v in vals)-min(v[0] for v in vals)>.5
        for loop in polygon.loop_indices:
            u,v=tex[mesh.loops[loop].vertex_index]
            if seam and u==0: u=math.tau*RADIUS
            uv.data[loop].uv=(u,v)
    bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True)
    bpy.context.view_layer.objects.active=obj
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.object.mode_set(mode='OBJECT')
    return obj

def station(angle):
    return (BEND-BEND*math.cos(angle), -BEND+BEND*math.sin(angle),
            math.sin(angle),math.cos(angle),BEND*angle)

# Six shallow gores preserve a fabricated silhouette instead of a bulb.
shell('Elbow', [station(i*math.pi/12) for i in range(7)], RADIUS,RADIUS-THICKNESS,'cast_iron')
shell('Pipe', [(0,-.5,0,1,0),(0,.5,0,1,1)],RADIUS,RADIUS-THICKNESS,'cast_iron')
shell('SlipBand', [(0,-.0225,0,1,0),(0,.0225,0,1,.045)],RADIUS+.006,RADIUS,'metal')
# Narrow rolled seams follow the same bend and remain separate editable parts.
for index in range(1,6):
    angle=index*math.pi/12
    shell('GoreSeam', [station(angle-.008),station(angle),station(angle+.008)],
          RADIUS+.0025,RADIUS,'metal')
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/breeching.blend'))
# Merge the elbow's five seams to one mesh while keeping material boundaries.
bpy.ops.object.select_all(action='DESELECT')
for obj in bpy.context.scene.objects:
    if obj.name.startswith('GoreSeam') or obj.name=='Elbow': obj.select_set(True)
bpy.context.view_layer.objects.active=bpy.data.objects['Elbow']; bpy.ops.object.join()
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/breeching.glb'),
                         export_format='GLB',export_yup=True,export_apply=True)
