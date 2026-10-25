"""Native full-depth mitred linings for every V2 building door opening.

The moulded face casings already have mitres. This repairs the separate
square-ended deep linings, including the two entrances omitted by that pass.
No opening, leaf, collision, key or saved mechanism is changed.
"""
from pathlib import Path
import hashlib, json, re, sys
import bpy, bmesh, numpy as np

ROOT = next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
sys.path.insert(0, str(ROOT/'art/blender/scripts'))
from frame_mitre_geometry import frame_parts, interface_points
from fabrication_chart_batch import triangle_charts
from check_exported_tangents import validate

layout_path = ROOT/'game/data/orison_v2_blockout.json'
span_path = ROOT/'game/scripts/generated/v2_exterior_masonry.gd'
catalog_path = ROOT/'game/data/runtime_material_sets.json'
layout = json.loads(layout_path.read_text(encoding='utf8'))
section = span_path.read_text(encoding='utf8').split('const DOOR_SPANS := {', 1)[1].split('}', 1)[0]
spans = {name: (float(a), float(b)) for name, a, b in re.findall(
    r'"([^"]+)": Vector2\(([-\d.]+),([-\d.]+)\)', section)}
catalog = json.loads(catalog_path.read_text(encoding='utf8'))['materials']
partition = float(layout['dimensions']['partition_wall'])
variants = {}; doors = []
for door in layout['doors']:
    lo, hi = spans.get(door['id'], (-partition/2, partition/2))
    width, height, depth = float(door['width']), float(door['height']), hi-lo
    key = 'L%04d_%04d_%04d' % tuple(round(v*1000) for v in (width, height, depth))
    variants[key] = (width, height, depth)
    doors.append({'id': door['id'], 'variant': key, 'span': [lo, hi]})

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
parts_collection = bpy.data.collections.new('EditableJoinedMembers')
bpy.context.scene.collection.children.link(parts_collection)
frames_collection = bpy.data.collections.new('RuntimeWholeFrames')
bpy.context.scene.collection.children.link(frames_collection)
material = bpy.data.materials.new('door_paint'); material.use_nodes = True
bsdf = material.node_tree.nodes['Principled BSDF']
spec = catalog['door_paint']
bsdf.inputs['Metallic'].default_value = float(spec['metallic'])
coordinates = material.node_tree.nodes.new('ShaderNodeTexCoord')
scale = material.node_tree.nodes.new('ShaderNodeVectorMath'); scale.operation = 'SCALE'
scale.inputs[3].default_value = 1. / float(spec['meters_per_tile'])
material.node_tree.links.new(coordinates.outputs['UV'], scale.inputs[0])
for index, socket in [(0, 'Base Color'), (1, 'Roughness'), (2, 'Normal')]:
    image_path = next((ROOT/'game/assets').rglob(spec['files'][index]))
    image = bpy.data.images.load(str(image_path), check_existing=True)
    texture = material.node_tree.nodes.new('ShaderNodeTexImage'); texture.image = image
    material.node_tree.links.new(scale.outputs[0], texture.inputs['Vector'])
    if index: image.colorspace_settings.name = 'Non-Color'
    if index == 2:
        normal = material.node_tree.nodes.new('ShaderNodeNormalMap')
        normal.inputs['Strength'].default_value = .6
        material.node_tree.links.new(texture.outputs['Color'], normal.inputs['Color'])
        material.node_tree.links.new(normal.outputs['Normal'], bsdf.inputs[socket])
    else: material.node_tree.links.new(texture.outputs['Color'], bsdf.inputs[socket])

fixture = []; runtime_variants = []
for key, (width, height, depth) in sorted(variants.items()):
    stock = frame_parts(width, height, .09, depth)
    interfaces = interface_points(stock)
    objects = []
    for name, recipe in stock.items():
        mesh = bpy.data.meshes.new(key+'_'+name)
        mesh.from_pydata(recipe['vertices'], [], recipe['faces']); mesh.update()
        bm = bmesh.new(); bm.from_mesh(mesh)
        bmesh.ops.triangulate(bm, faces=list(bm.faces))
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces)); bm.to_mesh(mesh); bm.free()
        mesh.calc_loop_triangles()
        triangles = np.array([[mesh.vertices[v].co[:] for v in face.vertices]
                              for face in mesh.loop_triangles])
        _, _, charts, _ = triangle_charts(triangles, np.zeros(3), 1.)
        uv = mesh.uv_layers.new(name='Metres')
        for face, chart in zip(mesh.loop_triangles, charts):
            for loop, pair in zip(face.loops, chart): uv.data[loop].uv = pair
        mesh.materials.append(material)
        obj = bpy.data.objects.new(key+'_'+name, mesh); parts_collection.objects.link(obj)
        objects.append(obj)
    # Keep independently editable members and a one-draw assembled stock.
    copies = []
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:
        copy = obj.copy(); copy.data = obj.data.copy(); frames_collection.objects.link(copy)
        copy.select_set(True); copies.append(copy)
    bpy.context.view_layer.objects.active = copies[0]
    bpy.ops.object.join(); bpy.context.object.name = key
    runtime_variants.append({'id': key, 'width': width, 'height': height, 'depth': depth})
    fixture.append({'id': key, 'members': [key+'_'+s for s in ['left', 'right', 'head']],
                    'interfaces_blender': interfaces, 'triangles': 36})

target = ROOT/'art/blender/door_lining_mitres.blend'
for image in bpy.data.images:
    if image.source == 'FILE' and image.filepath:
        image.filepath = bpy.path.relpath(bpy.path.abspath(image.filepath), start=str(target.parent))
bpy.ops.wm.save_as_mainfile(filepath=str(target))
class ExportUVHandedness:
    def gather_attribute_change(self, attribute, data, normalized, export_settings):
        if attribute == 'TANGENT': data['data'][:, 3] *= -1
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension = ExportUVHandedness
asset = ROOT/'game/assets/props/door_lining_mitres.glb'
bpy.ops.export_scene.gltf(filepath=str(asset), export_format='GLB', export_apply=True,
                        export_tangents=True, export_image_format='NONE')
export = validate(asset)
assert export['status'] == 'PASS', export
runtime = {'schema_version': 1, 'asset': 'res://assets/props/door_lining_mitres.glb',
           'board_width': .09, 'variants': runtime_variants, 'doors': doors}
(ROOT/'game/data/orison_v2/door_lining_mitres.json').write_bytes(
    (json.dumps(runtime, indent=2)+'\n').encode('utf8'))
inputs = [layout_path, span_path, catalog_path, Path(__file__).resolve(),
          ROOT/'art/blender/scripts/frame_mitre_geometry.py']
for name in spec['files']:
    if name: inputs.append(next((ROOT/'game/assets').rglob(name)))
bindings = {p.relative_to(ROOT).as_posix(): hashlib.sha256(
    p.read_bytes() if p.suffix in ['.png', '.glb', '.blend'] else p.read_bytes().replace(b'\r\n', b'\n')
).hexdigest() for p in inputs}
report = {'evidence_class': 'INERT', 'scope': 'Native lining stock only, not installed or runtime-qualified.',
          'source_bindings': bindings, 'asset_sha256': hashlib.sha256(asset.read_bytes()).hexdigest(),
          'variants': fixture, 'door_count': len(doors), 'exported_tangents': export}
for path in ['art/blender/door_lining_mitres_construction.json',
             'game/tests/fixtures/v2_door_lining_mitres.json']:
    (ROOT/path).write_bytes((json.dumps(report, indent=2)+'\n').encode('utf8'))
print('NATIVE LININGS', len(doors), 'openings;', len(variants), 'exact unscaled stocks;36 triangles/frame')
