"""Build and render the source-fitted barrel-roof candidate, without installation.

Blender --background --python <this file> -- --work-dir <review directory>
Editable pieces and a four-draw GLB remain in the review directory. Existing
shipping assets, collision and runtime material registrations are untouched.
"""
from pathlib import Path
import argparse
import collections
import hashlib
import json
import math
import sys
import bpy
import bmesh
import numpy as np
from mathutils import Matrix, Vector

ROOT = next(p for p in Path(__file__).resolve().parents if (p / 'game/project.godot').is_file())
sys.path.insert(0, str(ROOT / 'tools'))
sys.path.insert(0, str(ROOT / 'art/blender/scripts'))
from plan_v2_arcade_canopy import build
from fabrication_native_batch import material, partition
from check_exported_tangents import validate

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--work-dir', type=Path, required=True)
parser.add_argument('--publish-native', action='store_true')
args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
work = args.work_dir.resolve()
work.mkdir(parents=True, exist_ok=True)
plan = build()
catalog = json.loads((ROOT / 'game/data/runtime_material_sets.json').read_text(encoding='utf8'))['materials']
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
scene = bpy.context.scene
stock = bpy.data.collections.new('EditableGlazingStock')
scene.collection.children.link(stock)
stock.hide_render = True
exports = bpy.data.collections.new('CandidateExports')
scene.collection.children.link(exports)


def point(p):
    return (p[0], -p[2], p[1])


groups = collections.defaultdict(list)
for row in plan['parts']:
    if row.get('kind') == 'gable_prism':
        profile = row['profile_xy']
        count = len(profile)
        vertices = [point((x, y, z)) for z in row['z_interval'] for x, y in profile]
        faces = [tuple(reversed(range(count))), tuple(range(count, count * 2))]
        faces += [(i, (i + 1) % count, (i + 1) % count + count, i + count) for i in range(count)]
    else:
        center = np.array(row['center_m'])
        axes = np.array(row['axes'])
        size = np.array(row['size_m'])
        vertices = [point(center + (np.array(signs) * size / 2) @ axes)
                    for signs in [(-1, -1, -1), (1, -1, -1), (1, 1, -1), (-1, 1, -1),
                                  (-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)]]
        faces = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4),
                 (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    mesh = bpy.data.meshes.new(row['id'])
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    if row['bevel_m']:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=row['bevel_m'], segments=2,
                        affect='EDGES', clamp_overlap=True)
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    # Every stock piece must remain closed, including the glass underside.
    if not all(e.is_manifold for e in bm.edges) or bm.calc_volume() <= 0:
        raise ValueError('Open or inverted stock: ' + row['id'])
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(row['id'], mesh)
    stock.objects.link(obj)
    groups[row['material']].append(obj)

finished = []
for key, objects in groups.items():
    # Glass uses the existing optical stock for preview. Runtime installation
    # must bind the architectural glass shader instead of embedding it here.
    if key == 'glassish':
        mat = bpy.data.materials.new('glassish')
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes['Principled BSDF']
        bsdf.inputs['Base Color'].default_value = (.97, .99, 1, 1)
        bsdf.inputs['Transmission Weight'].default_value = 1
        bsdf.inputs['IOR'].default_value = 1.5
        bsdf.inputs['Roughness'].default_value = .06
        finish = dict(catalog_key='water_clear')
    else:
        finish = dict(catalog_key=key, pigment=1., normal=1., roughness=1.,
                      tint=[.12, .50, .42, 1.] if key == 'enamel_appliance' else [1., 1., 1., 1.])
        mat = material(ROOT, key, finish, catalog)
    # Anchor each genuine stock plane before bevel interpolation. Distinct
    # facet directions remain separate; a curved roof is not smoothed flat.
    finish['planar_axes'] = [point(axis) for row in plan['parts'] if row['material'] == key for axis in row['axes']]
    finish['planar_axes'] = np.unique(np.round(finish['planar_axes'], 10), axis=0)
    obj = partition(exports, 'canopy__' + key, objects, finish, mat, Matrix.Identity(4), catalog)
    finished.append(obj)

# Retained source structure is a review guide only, excluded from export.
# This shows the actual bearing rather than judging a floating glass shell.
layout = json.loads((ROOT / plan['source']).read_text(encoding='utf8'))
reference = bpy.data.collections.new('RetainedSourceRibsReviewOnly')
scene.collection.children.link(reference)
iron = bpy.data.materials['iron_blackened']
for floor in layout['floors']:
    if floor['id'] != 'F01':
        continue
    for row in floor['furniture']:
        if not row['id'].startswith(('site_passage_rib_', 'site_passage_ridge_')):
            continue
        a, b = Vector(point(row['p0'])), Vector(point(row['p1']))
        bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=row['r'], depth=(b - a).length, location=(a + b) / 2)
        obj = bpy.context.object
        obj.name = 'RETAINED_' + row['id']
        obj.rotation_euler = (b - a).to_track_quat('Z', 'Y').to_euler()
        for collection in list(obj.users_collection):
            collection.objects.unlink(obj)
        reference.objects.link(obj)
        obj.data.materials.append(iron)


class ExportUV:
    def gather_material_hook(self, material, source, settings):
        material.pbr_metallic_roughness = None
        material.normal_texture = None
        material.occlusion_texture = None
        material.emissive_texture = None
        material.emissive_factor = None
        material.extensions = None

    def gather_mesh_hook(self, mesh, data, obj, groups, modifiers, materials, settings):
        from io_scene_gltf2.io.exp.binary_data import BinaryData
        from io_scene_gltf2.io.com.constants import BufferViewTarget
        for primitive in mesh.primitives:
            def values(key):
                return np.frombuffer(primitive.attributes[key].buffer_view.data, dtype='<f4').reshape((-1, 3)).astype(float)
            n = values('NORMAL')
            n /= np.linalg.norm(n, axis=1)[:, None]
            g = values('_TANGENT_GUIDE')
            t = g - n * np.sum(g * n, axis=1)[:, None]
            t /= np.linalg.norm(t, axis=1)[:, None]
            primitive.attributes['TANGENT'].buffer_view = BinaryData(np.column_stack((t, -np.ones(len(t)))).astype('<f4').tobytes(), BufferViewTarget.ARRAY_BUFFER)
            del primitive.attributes['_TANGENT_GUIDE']


import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension = ExportUV
bpy.ops.object.select_all(action='DESELECT')
for obj in finished:
    obj.select_set(True)
asset = work / 'arcade_canopy.glb'
bpy.ops.export_scene.gltf(filepath=str(asset), export_format='GLB', use_selection=True,
                          export_yup=True, export_tangents=True, export_attributes=True,
                          export_materials='EXPORT')
proof = validate(asset)


def aim(obj, target):
    obj.rotation_euler = (Vector(point(target)) - obj.location).to_track_quat('-Z', 'Y').to_euler()


scene.world = bpy.data.worlds.new('ReviewSky')
scene.world.use_nodes = True
world = scene.world.node_tree
sky = world.nodes.new('ShaderNodeTexSky')
sky.sky_type = 'MULTIPLE_SCATTERING'
sky.sun_elevation = math.radians(24)
sky.sun_rotation = math.radians(135)
world.links.new(sky.outputs['Color'], world.nodes['Background'].inputs['Color'])
world.nodes['Background'].inputs['Strength'].default_value = .4
light_data = bpy.data.lights.new('InteriorReviewFill', 'AREA')
light_data.energy = 1400
light_data.size = 10
light = bpy.data.objects.new('InteriorReviewFill', light_data)
scene.collection.objects.link(light)
light.location = point((14, 5.5, 44))
aim(light, (14, 8.5, 43))
camera_data = bpy.data.cameras.new('ReviewCamera')
camera = bpy.data.objects.new('ReviewCamera', camera_data)
scene.collection.objects.link(camera)
scene.camera = camera
scene.render.engine = 'CYCLES'
scene.cycles.samples = 24
scene.cycles.use_denoising = True
scene.render.resolution_x = 1100
scene.render.resolution_y = 800
scene.render.resolution_percentage = 100
scene.view_settings.view_transform = 'AgX'
camera_data.lens = 24
for name, eye, target in [
    ('under_barrel', (14, 4.8, 38.9), (14, 8.2, 45)),
    ('roof_joint', (11.7, 8.5, 41.7), (11.5, 8.4, 43)),
    ('over_roof', (8, 12, 34), (14, 8.5, 45)),
    ('lantern_shoulders', (14, 8.5, 52), (11.4, 9.4, 48.6)),
]:
    camera.location = point(eye)
    aim(camera, target)
    scene.render.filepath = str(work / (name + '.png'))
    bpy.ops.render.render(write_still=True)
for image in bpy.data.images:
    if image.source == 'FILE':
        image.filepath = bpy.path.relpath(image.filepath, start=str(work))
bpy.ops.wm.save_as_mainfile(filepath=str(work / 'arcade_canopy.blend'))
published_native = ROOT / 'art/blender/arcade_canopy.blend'
if args.publish_native:
    for image in bpy.data.images:
        if image.source == 'FILE':
            absolute = bpy.path.abspath(image.filepath)
            image.filepath = bpy.path.relpath(absolute, start=str(published_native.parent))
    bpy.ops.wm.save_as_mainfile(filepath=str(published_native))
(work / 'canopy_plan.json').write_text(json.dumps(plan, indent=2) + '\n', encoding='utf8', newline='\n')
proof.update(evidence_class='INERT', scope='Blender candidate only; no loaded-world, collision or runtime acceptance.',
             stock_count=len(plan['parts']), closed_glass_panes=plan['pane_count'],
             asset_sha256=hashlib.sha256(asset.read_bytes()).hexdigest())
proof['source_bindings'] = {}
for relative in [plan['source'], 'tools/plan_v2_arcade_canopy.py',
                 'art/blender/arcade_fabric_candidate/build_arcade_canopy.py',
                 'art/blender/scripts/fabrication_native_batch.py',
                 'art/blender/scripts/fabrication_chart_batch.py',
                 'art/blender/scripts/fabrication_uvs.py',
                 'art/blender/scripts/fabrication_normals.py',
                 'art/blender/scripts/check_exported_tangents.py',
                 'game/data/runtime_material_sets.json']:
    proof['source_bindings'][relative] = hashlib.sha256((ROOT / relative).read_bytes().replace(b'\r\n', b'\n')).hexdigest()
proof['retained_source_guides_excluded_from_export'] = len(reference.objects)
proof['lantern_closed_glass_panes'] = plan['lantern_closed_panes']
proof['native_sha256'] = hashlib.sha256((work / 'arcade_canopy.blend').read_bytes()).hexdigest()
if args.publish_native:
    proof['published_native'] = published_native.relative_to(ROOT).as_posix()
    proof['published_native_sha256'] = hashlib.sha256(published_native.read_bytes()).hexdigest()
(work / 'native_review.json').write_text(json.dumps(proof, indent=2) + '\n', encoding='utf8', newline='\n')
print('ARCADE CANOPY CANDIDATE', json.dumps(proof))
