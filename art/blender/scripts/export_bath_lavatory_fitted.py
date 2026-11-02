"""Publish the edited V2 lavatory plus six selectable native service profiles.

The original lavatory source/export remain the explicit V1 rollback. Run in
Blender with two CPU threads; this publishes geometry, never runtime state.
"""
from pathlib import Path
import json
import struct
import sys
import bpy

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from metric_gltf_export import CatalogueMetricUV
from check_exported_tangents import validate

bpy.ops.wm.open_mainfile(filepath=str(ROOT / 'art/blender/bath_lavatory_fitted.blend'))


class SourceNormalUV(CatalogueMetricUV):
    def gather_mesh_hook(self, mesh, *args):
        from io_scene_gltf2.io.exp.binary_data import BinaryData
        from io_scene_gltf2.io.com.constants import BufferViewTarget
        for primitive in mesh.primitives:
            if '_SOURCE_NORMAL' in primitive.attributes:
                original = primitive.attributes.pop('_SOURCE_NORMAL')
                primitive.attributes['NORMAL'].buffer_view = BinaryData(
                    original.buffer_view.data, BufferViewTarget.ARRAY_BUFFER)
        super().gather_mesh_hook(mesh, *args)


import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension = SourceNormalUV
excluded = set()
for name in ('00_RETAINED_NATIVE_CONSTRUCTION', '02_CPU_REVIEW', '03_EDITABLE_REAR_ADAPTERS'):
    excluded.update(bpy.data.collections[name].all_objects)
services = bpy.data.collections['01_FITTED_SERVICE_PROFILES']
profiles = {obj.name for obj in services.objects if obj.type == 'EMPTY'}
assert profiles == {'WallService_2555', 'WallService_2755', 'WallService_2855',
                    'WallService_2955', 'WallService_3455', 'WallService_4455'}
bpy.ops.object.select_all(action='DESELECT')
for obj in bpy.context.scene.objects:
    if obj not in excluded:
        obj.hide_set(False)
        obj.select_set(True)
bpy.context.view_layer.update()
path = ROOT / 'game/assets/props/bath_lavatory_fitted.glb'
bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLB', use_selection=True,
    export_yup=True, export_tangents=True, export_attributes=True,
    export_materials='EXPORT', export_animations=False, export_extras=True)
raw = path.read_bytes()
document = json.loads(raw[20:20 + struct.unpack_from('<I', raw, 12)[0]])
assert not document.get('images') and not document.get('animations') and not document.get('skins')
assert profiles <= {node.get('name') for node in document['nodes']}
print('FITTED_LAVATORY_EXPORT', json.dumps(validate(path)), flush=True)
