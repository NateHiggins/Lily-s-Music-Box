"""Native throat masonry: chosen courses, recessed lime joints and eased clay.

The two original wall envelopes own replacement and collision. All brick
fronts stay at the original public face; joint relief is recessed into that
envelope. Backing and clipped end stock close the wall at every boundary.
"""
from pathlib import Path
import collections
import hashlib
import json
import math
import sys
import bpy
import bmesh
from mathutils import Matrix, Vector

ROOT = next(p for p in Path(__file__).resolve().parents if (p / 'game/project.godot').is_file())
sys.path.insert(0, str(ROOT / 'art/blender/scripts'))
from fabrication_native_batch import partition, material, export

source = ROOT / 'art/data/building_layout.json'
layout = json.loads(source.read_text(encoding='utf8'))
rows = [row for floor in layout['floors'] if floor['id'] == 'F01' for row in floor['furniture']
        if row['id'] in ['site_passage_throat_w', 'site_passage_throat_e']]
if len(rows) != 2 or any(row.get('mat') != 'common_brick' for row in rows):
    raise ValueError('Source throat requires a new masonry fit')
catalog = json.loads((ROOT / 'game/data/runtime_material_sets.json').read_text())['materials']
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
scene = bpy.context.scene
stock = bpy.data.collections.new('EditableMasonryStock')
scene.collection.children.link(stock)
stock.hide_render = True
exports = bpy.data.collections.new('SourceFittedMasonry')
scene.collection.children.link(exports)
groups = collections.defaultdict(list)
retired, blocks = [], []


def point(p):
    return (p[0], -p[2], p[1])


def box(name, low, high, group, bevel=0):
    vertices = [point((x, y, z)) for x, y, z in [
        (low[0], low[1], low[2]), (high[0], low[1], low[2]),
        (high[0], high[1], low[2]), (low[0], high[1], low[2]),
        (low[0], low[1], high[2]), (high[0], low[1], high[2]),
        (high[0], high[1], high[2]), (low[0], high[1], high[2])]]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4),
                                  (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)])
    mesh.update()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    if bevel:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=2, affect='EDGES', clamp_overlap=True)
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    if not all(edge.is_manifold for edge in bm.edges) or bm.calc_volume() <= 0:
        raise ValueError('Unclosed masonry stock: ' + name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    stock.objects.link(obj)
    groups[group].append(obj)


for wall in rows:
    r = wall['rect']
    low = [r[0], wall['z0'], -r[3]]
    high = [r[2], wall['z0'] + wall['h'], -r[1]]
    retired.append(dict(id=wall['id'], key='common_brick', low=low, high=high, expected_triangles=12))
    west = wall['id'].endswith('_w')
    mortar_low, mortar_high = low.copy(), high.copy()
    if west:
        mortar_high[0] -= .0054
        face_x = [high[0] - .006, high[0]]
    else:
        mortar_low[0] += .0054
        face_x = [low[0], low[0] + .006]
    box(wall['id'] + '_lime_backing', mortar_low, mortar_high, 'mortar')
    for row in range(math.floor(low[1] / .075), math.ceil(high[1] / .075)):
        bottom, top = max(low[1], row * .075 + .0045), min(high[1], (row + 1) * .075 - .0045)
        if top <= bottom:
            continue
        shift = (row % 2) * .1
        for column in range(math.floor((low[2] + shift) / .2), math.ceil((high[2] + shift) / .2)):
            start = max(low[2], column * .2 - shift + .0045)
            end = min(high[2], (column + 1) * .2 - shift - .0045)
            if end - start < .001:
                continue
            variant = (row * 73856093 ^ column * 19349663) % 3
            name = f'{wall["id"]}_brick_{row}_{column}'
            a, b = [face_x[0], bottom, start], [face_x[1], top, end]
            box(name, a, b, 'face_' + str(variant), .0012)
            blocks.append(dict(id=name, low=a, high=b, variant=variant, bevel_m=.0012))

parts, finished = [], []
for group, objects in groups.items():
    key = 'arcade_lime_mortar' if group == 'mortar' else 'arcade_brick_face'
    tint = [1., 1., 1., 1.] if group == 'mortar' else [[1., 1., 1., 1.], [.98, .96, .94, 1.], [.95, .96, .98, 1.]][int(group[-1])]
    finish = dict(catalog_key=key, normal=1., roughness=1., pigment=1., tint=tint,
                  planar_axes=[(1, 0, 0), (0, 1, 0), (0, 0, 1)])
    mat = material(ROOT, group, finish, catalog)
    name = 'throat_' + group + '__common_brick'
    finished.append(partition(exports, name, objects, finish, mat, Matrix.Identity(4), catalog))
    parts.append(dict(name=name, key='common_brick', catalog_key=key, tile=.25, tint=tint))
proof = export(ROOT, 'arcade_throat', exports, material_names_only=True)
runtime = dict(schema_version=1, asset='res://assets/props/arcade_throat.glb', tolerance=.00001,
               cells=[dict(id='passage', replace=retired, parts=parts)])
path = ROOT / 'game/data/orison_v2/arcade_throat.json'
path.write_text(json.dumps(runtime, indent=2) + '\n', encoding='utf8', newline='\n')
record = dict(evidence_class='INERT', scope='Native throat masonry construction; composed verification pending.',
              chosen_course_m=[.2, .075], joint_m=.009, face_depth_m=.006,
              body_recess_m=.0054, bricks=blocks, source_boxes=retired,
              asset_sha256=hashlib.sha256((ROOT / 'game/assets/props/arcade_throat.glb').read_bytes()).hexdigest(),
              export_checks=proof, source_bindings={})
for relative in ['art/data/building_layout.json', 'art/blender/arcade_fabric_candidate/build_arcade_throat.py',
                 'game/data/runtime_material_sets.json', 'game/data/orison_v2/arcade_throat.json',
                 'art/tools/build_arcade_masonry.py']:
    record['source_bindings'][relative] = hashlib.sha256((ROOT / relative).read_bytes().replace(b'\r\n', b'\n')).hexdigest()
(ROOT / 'art/blender/arcade_throat_construction.json').write_text(json.dumps(record, indent=2) + '\n', encoding='utf8', newline='\n')

scene.world = bpy.data.worlds.new('NeutralReviewRoom')
scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs[0].default_value = (.4, .4, .4, 1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value = .35
camera_data = bpy.data.cameras.new('ReviewCamera')
camera = bpy.data.objects.new('ReviewCamera', camera_data)
scene.collection.objects.link(camera)
scene.camera = camera
lamp_data = bpy.data.lights.new('ReviewLight', 'AREA')
lamp = bpy.data.objects.new('ReviewLight', lamp_data)
scene.collection.objects.link(lamp)
lamp_data.energy, lamp_data.size = 220, 1.2
lamp.location = point((13, 2.4, 31.8))
lamp.rotation_euler = (Vector(point((11, 1.5, 33))) - lamp.location).to_track_quat('-Z', 'Y').to_euler()
scene.render.engine = 'CYCLES'
scene.cycles.samples = 24
scene.cycles.use_denoising = True
scene.render.resolution_x, scene.render.resolution_y = 1100, 800
scene.render.resolution_percentage = 100
scene.view_settings.view_transform = 'AgX'
camera_data.lens = 35
review = ROOT / 'art/reviews/v2_arcade_install_20261018'
review.mkdir(parents=True, exist_ok=True)
for name, eye, target in [('throat_wall', (14, 1.65, 32), (11, 1.5, 33)),
                          ('throat_joint', (11.4, 1.5, 33.2), (11, 1.4, 33.8))]:
    camera.location = point(eye)
    camera.rotation_euler = (Vector(point(target)) - camera.location).to_track_quat('-Z', 'Y').to_euler()
    scene.render.filepath = str(review / (name + '.png'))
    bpy.ops.render.render(write_still=True)
print('NATIVE THROAT', len(blocks), 'bricks;', proof)
