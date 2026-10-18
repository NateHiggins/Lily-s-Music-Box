"""Render calibrated terrazzo prototypes; retain an optional mirrored control."""
from pathlib import Path
import argparse
import json
import sys
import bpy
from mathutils import Vector

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--work-dir', type=Path, required=True)
parser.add_argument('--mirrored-control', action='store_true')
args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
work = args.work_dir.resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

for side, key in enumerate(['arcade_terrazzo', 'arcade_terrazzo_dark']):
    folder = work / 'materials' / key
    meta = json.loads((folder / 'material.json').read_text())
    tile = meta['meters_per_tile']
    vertices, faces, charts = [], [], []
    for i in range(4):
        for j in range(4):
            start = len(vertices)
            vertices.extend([(side * 1.6 + (i + a) * tile, (j + b) * tile, 0) for a, b in [(0, 0), (1, 0), (1, 1), (0, 1)]])
            faces.append(tuple(start + k for k in range(4)))
            charts.extend([(1 - a if i % 2 else a, 1 - b if j % 2 else b) if args.mirrored_control else (a, b) for a, b in [(0, 0), (1, 0), (1, 1), (0, 1)]])
    mesh = bpy.data.meshes.new(key)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    uv = mesh.uv_layers.new(name='MirroredMetreCharts')
    for loop, value in zip(uv.data, charts):
        loop.uv = value
    obj = bpy.data.objects.new(key, mesh)
    scene.collection.objects.link(obj)
    mat = bpy.data.materials.new(key)
    mat.use_nodes = True
    node = mat.node_tree.nodes['Principled BSDF']
    node.inputs['Metallic'].default_value = 0
    for name, target in [('albedo', 'Base Color'), ('roughness', 'Roughness'), ('normal', 'Normal')]:
        image = bpy.data.images.load(str(folder / (name + '.png')))
        if name != 'albedo':
            image.colorspace_settings.name = 'Non-Color'
        texture = mat.node_tree.nodes.new('ShaderNodeTexImage')
        texture.image = image
        texture.extension = 'EXTEND' if args.mirrored_control else 'REPEAT'
        if name == 'normal':
            normal = mat.node_tree.nodes.new('ShaderNodeNormalMap')
            normal.inputs['Strength'].default_value = 1
            mat.node_tree.links.new(texture.outputs['Color'], normal.inputs['Color'])
            mat.node_tree.links.new(normal.outputs['Normal'], node.inputs[target])
        else:
            mat.node_tree.links.new(texture.outputs['Color'], node.inputs[target])
    mesh.materials.append(mat)

scene.world = bpy.data.worlds.new('NeutralRoom')
scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs[0].default_value = (.32, .32, .32, 1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value = .3
camera_data = bpy.data.cameras.new('FloorReview')
camera = bpy.data.objects.new('FloorReview', camera_data)
scene.collection.objects.link(camera)
scene.camera = camera


def aim(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat('-Z', 'Y').to_euler()


camera.location = (1.6, -1.3, 1.65)
aim(camera, (1.6, .8, 0))
camera_data.lens = 38
lamp_data = bpy.data.lights.new('SoftRoomLight', 'AREA')
lamp_data.energy = 240
lamp_data.size = 1.5
lamp = bpy.data.objects.new('SoftRoomLight', lamp_data)
scene.collection.objects.link(lamp)
scene.render.engine = 'CYCLES'
scene.cycles.samples = 32
scene.cycles.use_denoising = True
scene.render.resolution_x = 1200
scene.render.resolution_y = 800
scene.render.resolution_percentage = 100
scene.view_settings.view_transform = 'AgX'
for name, position, power, size in [('diffuse', (1.6, .8, 2.5), 240, 1.5),
                                     ('grazing', (1.6, 2., .4), 100, .3)]:
    lamp.location = position
    aim(lamp, (1.6, .8, 0))
    lamp_data.energy = power
    lamp_data.size = size
    scene.render.filepath = str(work / ('terrazzo_' + ('mirrored_control_' if args.mirrored_control else 'repeat_') + name + '.png'))
    bpy.ops.render.render(write_still=True)
for image in bpy.data.images:
    if image.source == 'FILE':
        image.filepath = bpy.path.relpath(image.filepath, start=str(work))
bpy.ops.wm.save_as_mainfile(filepath=str(work / ('terrazzo_stock_mirrored_control.blend' if args.mirrored_control else 'terrazzo_stock_repeat_review.blend')))
