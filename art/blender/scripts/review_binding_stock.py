"""Compare installed native book geometry with candidate construction finishes.

Only renders below tmp are written. Native source and runtime files are not
modified; this is a visual diagnostic, never a runtime acceptance receipt.
"""
from pathlib import Path
import json
import math
import bmesh
import bpy
from mathutils import Vector

ROOT = next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
OUT = ROOT/'tmp/v2-binding-20261020/native'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'tmp/v2-binding-20261020/before/art/blender/domestic_storage.blend'))
for image in bpy.data.images:
    path=ROOT/'game/assets/building/textures'/Path(image.filepath).name
    if path.is_file(): image.filepath=str(path);image.reload()
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 40
scene.render.resolution_x = 1400
scene.render.resolution_y = 1000
scene.render.resolution_percentage = 100
scene.world = bpy.data.worlds.new('Binding review world')
scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs[0].default_value = (.6, .65, .7, 1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value = .3
draws = [o for o in scene.objects if o.type == 'MESH' and '__' in o.name and not o.hide_render]
selected = [o for o in draws if o.name.startswith('Shelf02__')]
bindings = [o for o in selected if o.name.startswith('Shelf02__book_')]
assert len(bindings) == 6
for obj in draws:
    obj.hide_render = obj not in selected
points = [o.matrix_world@v.co for o in selected for v in o.data.vertices]
low = Vector(tuple(min(p[i] for p in points) for i in range(3)))
high = Vector(tuple(max(p[i] for p in points) for i in range(3)))
centre = (low+high)*.5
span = max(high-low)
for offset, power, size in [((.3, .6, .5), 30, .4), ((-.5, .08, .12), 12, .18)]:
    bpy.ops.object.light_add(type='AREA', location=centre+Vector(offset))
    light = bpy.context.object
    light.data.energy = power
    light.data.shape = 'DISK'
    light.data.size = size
    light.rotation_euler = (centre-light.location).to_track_quat('-Z', 'Y').to_euler()
bpy.ops.object.camera_add()
camera = bpy.context.object
camera.data.lens = 55
radius=(high-low).length*.5
vertical_fov=2*math.atan(camera.data.sensor_width*scene.render.resolution_y/scene.render.resolution_x/(2*camera.data.lens))
camera.location=centre+Vector((1.2,2.,1.3)).normalized()*radius/math.sin(vertical_fov*.5)*1.05
camera.rotation_euler = (centre-camera.location).to_track_quat('-Z', 'Y').to_euler()
scene.camera = camera

def capture(name):
    scene.render.filepath = str(OUT/(name+'.png'))
    bpy.ops.render.render(write_still=True)

capture('legacy_bindings')
for obj in bindings:
    key = obj.name.split('__')[1]
    material = obj.data.materials[0]
    candidates = ROOT/'tmp/v2-binding-20261020/candidates'/key
    for node in material.node_tree.nodes:
        if node.type == 'TEX_IMAGE':
            old = node.image.name.lower()
            channel = 'normal' if 'normal' in old else ('roughness' if 'rough' in old else 'albedo')
            node.image = bpy.data.images.load(str(candidates/(channel+'.png')), check_existing=True)
            if channel != 'albedo':
                node.image.colorspace_settings.name = 'Non-Color'
        elif node.type == 'NORMAL_MAP':
            node.inputs['Strength'].default_value = 1.
capture('construction_bindings')
# Isolate one real cover's triangles, retaining its imported chart and normal.
# This is a material close-up, not proof of a complete book or its placement.
for obj in selected: obj.hide_render=True
for key, label in [('book_navy','cloth'),('book_brown','leather')]:
    stock=bpy.data.objects['Shelf02_'+key+'0UpperCover']
    points=[stock.matrix_world@v.co for v in stock.data.vertices]
    low=Vector(tuple(min(p[i] for p in points) for i in range(3)))
    high=Vector(tuple(max(p[i] for p in points) for i in range(3)))
    original=next(o for o in bindings if o.name.endswith('__'+key))
    cover=original.copy();cover.data=original.data.copy();scene.collection.objects.link(cover)
    mesh=bmesh.new();mesh.from_mesh(cover.data)
    outside=[v for v in mesh.verts if any((cover.matrix_world@v.co)[i]<low[i]-.00001 or (cover.matrix_world@v.co)[i]>high[i]+.00001 for i in range(3))]
    bmesh.ops.delete(mesh,geom=outside,context='VERTS');assert mesh.faces
    mesh.to_mesh(cover.data);mesh.free();cover.hide_render=False
    centre=(low+high)*.5;dimension=high-low
    axis=min(range(3),key=lambda i:dimension[i]);direction=Vector((.25,.25,.25));direction[axis]=1.
    camera.location=centre+direction.normalized()*max(dimension)*2.4
    camera.rotation_euler=(centre-camera.location).to_track_quat('-Z','Y').to_euler()
    for light in [o for o in scene.objects if o.type=='LIGHT']:
        light.data.energy = 1.5
        light.location=centre+direction.normalized()*.4+Vector((.1,-.15,.1))
        light.rotation_euler=(centre-light.location).to_track_quat('-Z','Y').to_euler()
    capture(label+'_close')
    cover.hide_render=True
(OUT/'scope.json').write_text(json.dumps(dict(evidence_class='INERT',
    source='art/blender/domestic_storage.blend', assembly='Shelf02',
    scope='Uninstalled candidate materials on unchanged native book geometry; no runtime proof.'), indent=2)+'\n', encoding='utf8', newline='\n')
