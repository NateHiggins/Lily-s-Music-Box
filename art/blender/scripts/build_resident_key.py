"""Period warded key, in metres, for resident originals and permitted spares."""
from pathlib import Path
import json
import os
import sys

import bmesh
import bpy
import numpy as np

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from check_exported_tangents import validate
from fabrication_native_batch import material
from fabrication_normals import stock_corner_normals
from fabrication_uvs import chart_for_triangle
from metric_gltf_export import CatalogueMetricUV

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
bpy.context.scene.unit_settings.system = 'METRIC'
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

# Preserve the original stock as a hidden reference and forge one closed body.
scene = bpy.context.scene
reference = bpy.data.collections.new('Original stock reference')
export = bpy.data.collections.new('Export key')
scene.collection.children.link(reference)
scene.collection.children.link(export)
stocks = {}
for original in parts:
    for collection in list(original.users_collection):
        collection.objects.unlink(original)
    reference.objects.link(original)
    stock = original.copy()
    stock.data = original.data.copy()
    export.objects.link(stock)
    stocks[original.name] = stock
bpy.context.view_layer.update()
for name in ('WardA', 'WardB'):
    for vertex in stocks[name].data.vertices:
        if vertex.co.y > 0:
            vertex.co.y += .0002
key = stocks['KeyBow']
bpy.ops.object.select_all(action='DESELECT')
bpy.context.view_layer.objects.active = key
key.select_set(True)
for name in ('KeyStem', 'KeyBit', 'WardA', 'WardB'):
    stock = stocks[name]
    weld = key.modifiers.new('Continuous forged body', 'BOOLEAN')
    weld.operation = 'UNION'
    weld.solver = 'EXACT'
    weld.object = stock
    bpy.ops.object.modifier_apply(modifier=weld.name)
    bpy.data.objects.remove(stock, do_unlink=True)
key.name = 'ResidentKey__brass_dull'
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
joined = key.data
surface = bmesh.new()
surface.from_mesh(joined)
bmesh.ops.remove_doubles(surface, verts=list(surface.verts), dist=1e-9)
bmesh.ops.dissolve_degenerate(surface, edges=list(surface.edges), dist=1e-9)
bmesh.ops.triangulate(surface, faces=list(surface.faces))
bmesh.ops.recalc_face_normals(surface, faces=list(surface.faces))
assert all(edge.is_manifold and edge.is_contiguous for edge in surface.edges)
surface.to_mesh(joined)
surface.free()
joined.update()
joined.calc_loop_triangles()
mesh = bpy.data.meshes.new('ResidentKey_MetricStock')
mesh.from_pydata([v.co[:] for v in joined.vertices], [],
                 [t.vertices[:] for t in joined.loop_triangles])
mesh.update()
key.data = mesh

catalogue = json.loads((ROOT / 'game/data/runtime_material_sets.json').read_text())['materials']
brass = catalogue['brass_dull']
finish = dict(catalog_key='brass_dull', normal=.35, roughness=brass['roughness_multiplier'],
              pigment=1., tint=[1, 1, 1])
preview = material(ROOT, 'brass_dull_preview', finish, catalogue)
normals = stock_corner_normals(mesh, planar_axes=np.eye(3))
mesh.normals_split_custom_set(normals)


def gltf_axes(vector):
    return (vector[0], vector[2], -vector[1])


charts, tangents = [], []
for face in mesh.polygons:
    points = np.asarray([mesh.vertices[index].co[:] for index in face.vertices])
    _, tangent, chart, _ = chart_for_triangle(points, np.zeros(3), brass['meters_per_tile'])
    charts.extend(chart)
    tangents.extend([gltf_axes(tangent)] * 3)
charts = np.asarray(charts, dtype=np.float32)
mesh.uv_layers.new(name='Metres').data.foreach_set('uv', charts.ravel())
for name, values in (
    ('_METRE_UV', np.column_stack((charts, np.zeros(len(charts))))),
    ('_TANGENT_GUIDE', tangents),
    ('_SOURCE_NORMAL', [gltf_axes(normal) for normal in normals]),
):
    attribute = mesh.attributes.new(name, 'FLOAT_VECTOR', 'CORNER')
    attribute.data.foreach_set('vector', np.asarray(values, dtype=np.float32).ravel())


class KeyStockExport(CatalogueMetricUV):
    def gather_mesh_hook(self, exported, *args):
        from io_scene_gltf2.io.exp.binary_data import BinaryData
        from io_scene_gltf2.io.com.constants import BufferViewTarget
        for primitive in exported.primitives:
            source = primitive.attributes.pop('_SOURCE_NORMAL')
            primitive.attributes['NORMAL'].buffer_view = BinaryData(
                source.buffer_view.data, BufferViewTarget.ARRAY_BUFFER)
        super().gather_mesh_hook(exported, *args)


output = Path(os.environ.get('ORISON_RESIDENT_KEY_BUILD_OUT', str(ROOT))).resolve()
asset = output / 'game/assets/props/resident_key.glb'
native = output / 'art/blender/resident_key.blend'
for path in (asset, native):
    path.parent.mkdir(parents=True, exist_ok=True)
mat.name = 'OriginalDiffuseReference'
mesh.materials.append(bpy.data.materials.new('brass_dull'))
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension = KeyStockExport
bpy.ops.export_scene.gltf(filepath=str(asset), export_format='GLB', use_selection=True,
    export_yup=True, export_tangents=True, export_attributes=True, export_animations=False)
print('RESIDENT KEY:', validate(asset))
mesh.materials[0] = preview
reference.hide_render = True
reference.hide_viewport = True
for image in bpy.data.images:
    if image.source == 'FILE':
        image.filepath = bpy.path.relpath(image.filepath, start=str(native.parent))
bpy.ops.wm.save_as_mainfile(filepath=str(native), relative_remap=False)
