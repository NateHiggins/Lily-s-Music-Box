"""Replace the 48x72, 2.2mm/pixel paper sprite with the same native surface."""
from pathlib import Path
import os
import sys

import bpy
import numpy as np

ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from check_exported_tangents import validate
from metric_gltf_export import SignedMetricUV

bpy.ops.wm.read_factory_settings(use_empty=True)
width=48*.0022;height=72*.0022
bpy.ops.mesh.primitive_plane_add(size=1)
obj=bpy.context.object;obj.name='PaperTag';obj.rotation_euler.x=1.5707963267948966
obj.scale=(width,height,1)
bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
uv=obj.data.uv_layers.active
for loop in obj.data.loops:
    p=obj.data.vertices[loop.vertex_index].co
    uv.data[loop.index].uv=(p.x,p.z)
obj.data.materials.append(bpy.data.materials.new('paper'))

output = Path(os.environ.get('ORISON_RADIATOR_TAG_BUILD_OUT', str(ROOT))).resolve()
native = output / 'art/blender/radiator_paper_tag.blend'
asset = output / 'game/assets/props/radiator_paper_tag.glb'
for path in (native, asset):
    path.parent.mkdir(parents=True, exist_ok=True)
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(native))

# Keep the original exporter-rounded UV phase and derive tangents from the
# same final coordinates. The Blender mesh and its editable UVs stay intact.
encoded = np.zeros((len(uv.data), 3), dtype=np.float32)
for index, loop in enumerate(uv.data):
    encoded[index, :2] = (loop.uv.x, -(np.float32(1) - np.float32(loop.uv.y)))
attribute = obj.data.attributes.new('_METRE_UV', 'FLOAT_VECTOR', 'CORNER')
attribute.data.foreach_set('vector', encoded.ravel())
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension = SignedMetricUV
bpy.ops.export_scene.gltf(filepath=str(asset), export_format='GLB', use_selection=True,
    export_yup=True, export_apply=True, export_tangents=True, export_attributes=True,
    export_animations=False)
print('NATIVE PAPER TAG:', width, height, validate(asset))
