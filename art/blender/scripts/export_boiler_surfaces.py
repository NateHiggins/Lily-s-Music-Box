"""Export both fixed boiler families from art/blender/boiler_surface_refit.blend.

Open that blend in Blender and pass an output directory after --. Exported
assets have the production GLB names. The script does not save the blend.
"""

import argparse
from pathlib import Path
import sys

import bpy
import io_scene_gltf2
from io_scene_gltf2.io.com.constants import BufferViewTarget
from io_scene_gltf2.io.exp.binary_data import BinaryData
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from check_exported_tangents import validate
from metric_gltf_export import CatalogueMetricUV


class PreserveSecondary(CatalogueMetricUV):
    def gather_mesh_hook(self, mesh, *args):
        for primitive in mesh.primitives:
            attributes = primitive.attributes
            normal = attributes.pop("_SOURCE_NORMAL")
            attributes["NORMAL"].buffer_view = BinaryData(
                normal.buffer_view.data, BufferViewTarget.ARRAY_BUFFER)
            secondary = attributes.pop("_SOURCE_UV1")
            uv = np.frombuffer(secondary.buffer_view.data, dtype="<f4").reshape(-1, 3)[:, :2]
            attributes["TEXCOORD_1"].buffer_view = BinaryData(
                uv.tobytes(), BufferViewTarget.ARRAY_BUFFER)
        super().gather_mesh_hook(mesh, *args)


def export_stock(output, collection, roles):
    if {stock["fabrication_role"] for stock in collection.objects} != roles:
        raise ValueError(f"Unexpected fixed boiler roles in {collection.name}")
    collection.hide_viewport = False
    bpy.context.view_layer.update()
    bpy.ops.object.select_all(action="DESELECT")
    renamed = []
    try:
        for stock in collection.objects:
            role = stock["fabrication_role"]
            conflict = bpy.data.objects.get(role)
            if conflict and conflict != stock:
                renamed.append((conflict, conflict.name))
                conflict.name = "TEMP_OTHER_" + conflict.name
            renamed.append((stock, stock.name))
            stock.name = role
            stock.data.name = role
            stock.select_set(True)
        result = bpy.ops.export_scene.gltf(
            filepath=str(output), export_format="GLB", use_selection=True,
            export_yup=True, export_tangents=True, export_attributes=True,
            export_materials="EXPORT", export_animations=False, export_extras=True)
        if "FINISHED" not in result:
            raise RuntimeError(f"Fixed boiler export failed: {result}")
        print(validate(output))
    finally:
        for stock, name in reversed(renamed):
            stock.name = name


def export_boiler_surfaces(directory):
    directory.mkdir(parents=True, exist_ok=True)
    io_scene_gltf2.glTF2ExportUserExtension = PreserveSecondary
    families = {
        "boiler_body": {"Hearth", "Iron", "Jacket", "Lining", "LiveCoal", "Soot", "Steel"},
        "boiler_instruments": {"Iron", "Steel", "Brass"},
    }
    for family, roles in families.items():
        collection = bpy.data.collections["02_EXPORT_" + family.upper()]
        export_stock(directory / (family + ".glb"), collection, roles)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output_dir", type=Path)
    export_boiler_surfaces(parser.parse_args(sys.argv[sys.argv.index("--") + 1:]).output_dir.resolve())
