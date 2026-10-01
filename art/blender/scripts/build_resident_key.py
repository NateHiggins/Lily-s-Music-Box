"""Period warded key, in metres, for resident originals and permitted spares."""
from pathlib import Path
import math
import bpy

ROOT = Path(__file__).resolve().parents[3]
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
mat = bpy.data.materials.new('brass_dull')
mat.diffuse_color = (.58, .44, .19, 1)
parts = []

def box(name, size, location):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    bevel = obj.modifiers.new('Filed edge', 'BEVEL')
    bevel.width = .00035
    bevel.segments = 1
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    parts.append(obj)

# A pierced bow, solid stem and restrained wards. No engraving or baked lettering.
bpy.ops.mesh.primitive_torus_add(major_radius=.009, minor_radius=.0018,
                               major_segments=16, minor_segments=6,
                               location=(-.025, 0, .002))
bow = bpy.context.object
bow.name = 'KeyBow'
bow.data.materials.append(mat)
parts.append(bow)
box('KeyStem', (.038, .004, .004), (.004, 0, .002))
box('KeyBit', (.012, .009, .004), (.017, -.0045, .002))
box('WardA', (.003, .003, .004), (.0135, -.0105, .002))
box('WardB', (.003, .003, .004), (.0205, -.0105, .002))
for obj in parts:
    for layer in list(obj.data.uv_layers): obj.data.uv_layers.remove(layer)
    uv = obj.data.uv_layers.new(name='Metres')
    uv.active_render = True
    for face in obj.data.polygons:
        axis = max(range(3), key=lambda i: abs(face.normal[i]))
        axes = ((1, 2), (0, 2), (0, 1))[axis]
        for loop in face.loop_indices:
            point = obj.matrix_world @ obj.data.vertices[obj.data.loops[loop].vertex_index].co
            uv.data[loop].uv = (point[axes[0]], point[axes[1]])
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/resident_key.blend'))
bpy.ops.object.select_all(action='SELECT')
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
bpy.context.object.name = 'ResidentKey__brass_dull'
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/resident_key.glb'),
                         export_format='GLB', export_yup=True, export_tangents=True)
print('RESIDENT KEY: warded 60 mm key; active metre UVs; one brass partition')
