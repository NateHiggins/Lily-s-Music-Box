"""Reusable period steel trapeze for the existing 180 mm ventilation branches."""
from pathlib import Path
import json
import bpy
import bmesh

ROOT = Path(__file__).resolve().parents[3]
layout = json.loads((ROOT/'game/data/orison_v2_blockout.json').read_text())
graph = json.loads((ROOT/'game/data/orison_v2/completion_interiors.json').read_text())['ventilation']
anchors = {row['id']: row for row in layout['anchors']}
register_y = {anchors[row['anchor']]['position'][1] for row in graph['registers']}
assert register_y == {2.6}, register_y
ceiling = layout['dimensions']['clear_height'] - 2.6 - .09
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
materials = {}
parts = []
for key, color in {'metal': (.32,.31,.28), 'cast_iron': (.19,.18,.16)}.items():
    mat = bpy.data.materials.new(key)
    mat.diffuse_color = (*color,1)
    materials[key] = mat

def finish(obj, name, material):
    obj.name = name
    obj.data.materials.append(materials[material])
    parts.append(obj)
    return obj

def box(name, size, location):
    # Author in the native Godot frame, converting Y-up to Blender Z-up.
    x,y,z = location
    sx,sy,sz = size
    bpy.ops.mesh.primitive_cube_add(size=1, location=(x,-z,y))
    obj = bpy.context.object
    obj.dimensions = (sx,sz,sy)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bevel = obj.modifiers.new('Filed steel arris', 'BEVEL')
    bevel.width = .0004
    bevel.segments = 1
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    return finish(obj,name,'metal')

def cylinder(name, radius, low, high, z, material='metal', sides=12):
    bpy.ops.mesh.primitive_cylinder_add(vertices=sides, radius=radius,
        depth=high-low, location=(0,-z,(low+high)*.5))
    return finish(bpy.context.object,name,material)

# A rolled L bears directly against the duct underside. Its web hangs
# below the bearing flange, leaving the existing sheet-metal box unchanged.
box('BearingFlange',(.034,.004,.292),(0,-.092,0))
box('AngleWeb',(.004,.025,.292),(.015,-.1025,0))
for z in [-.128,.128]:
    cylinder('ThreadedRod',.006,-.116,ceiling-.009,z)
    box('CeilingBearingPlate',(.09,.009,.068),(0,ceiling-.0045,z))
    for y in [-.109,ceiling-.018]:
        cylinder('HexNut',.012,y-.006,y+.006,z,'cast_iron',6)
        cylinder('Washer',.016,y-.008,y-.006,z)
    for x in [-.031,.031]:
        box('CeilingAnchorHead',(.011,.008,.011),(x,ceiling-.013,z))

for obj in parts:
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.select_set(False)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    # Explicit triangles let the exporter calculate a stable tangent basis
    # for the metre UVs on the small filed edges and cylinder end caps.
    bmesh.ops.triangulate(bm, faces=list(bm.faces))
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(obj.data)
    bm.free()
    for layer in list(obj.data.uv_layers): obj.data.uv_layers.remove(layer)
    uv = obj.data.uv_layers.new(name='Metres')
    uv.active_render = True
    for face in obj.data.polygons:
        axis = max(range(3),key=lambda i:abs(face.normal[i]))
        axes = ((1,2),(0,2),(0,1))[axis]
        for loop in face.loop_indices:
            point = obj.matrix_world @ obj.data.vertices[obj.data.loops[loop].vertex_index].co
            uv.data[loop].uv = (point[axes[0]],point[axes[1]])
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/duct_hanger.blend'))
for key in materials:
    selected = [obj for obj in bpy.context.scene.objects
                if obj.type == 'MESH' and obj.data.materials[0] == materials[key]]
    bpy.ops.object.select_all(action='DESELECT')
    for obj in selected: obj.select_set(True)
    bpy.context.view_layer.objects.active = selected[0]
    bpy.ops.object.join()
    bpy.context.object.name = key
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/duct_hanger.glb'),
    export_format='GLB', export_yup=True, export_tangents=True)
print('DUCT HANGER: 180 mm branch / 310 mm ceiling drop / 2 mapped partitions')
