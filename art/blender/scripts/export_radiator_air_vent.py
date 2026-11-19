"""Export the installed vent from art/blender/radiator_air_vent.blend.

Open that blend in Blender, then run this script with an output GLB argument
after --. The export does not save changes to the blend.
"""

import argparse
import ast
import copy
from pathlib import Path
import sys

import bpy
import io_scene_gltf2
from io_scene_gltf2.io.com.constants import BufferViewTarget
from io_scene_gltf2.io.exp.binary_data import BinaryData
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from check_exported_tangents import validate


def export_vent(output):
    recipe = (Path(__file__).resolve().parents[2] /
              "reviews/v2_radiator_native_20261017/native_recipe/export_mechanisms.py")
    tree = ast.parse(recipe.read_text(encoding="utf-8"))
    tangent_hook = next(node for node in tree.body if isinstance(node, ast.ClassDef)
                        and node.name == "ExactCornerTangents")
    namespace = {"np": np, "copy": copy, "export_errors": []}
    exec(compile(ast.Module(body=[tangent_hook], type_ignores=[]), str(recipe), "exec"),
         namespace)

    class VentExport(namespace["ExactCornerTangents"]):
        def gather_mesh_hook(self, mesh, blender_data, blender_object, *_args):
            try:
                for primitive in mesh.primitives:
                    attributes = primitive.attributes
                    normal = attributes.pop("_AUTHORED_NORMAL")
                    attributes["NORMAL"].buffer_view = BinaryData(
                        normal.buffer_view.data, BufferViewTarget.ARRAY_BUFFER)
                    raw_uv = attributes.pop("_METRE_UV")
                    authored_uv = np.frombuffer(raw_uv.buffer_view.data, dtype="<f4").reshape(-1, 3)
                    # Export the metre UVs without Blender's unit-square offset.
                    uv = np.column_stack((authored_uv[:, 0], -authored_uv[:, 1])).astype("<f4")
                    attributes["TEXCOORD_0"].buffer_view = BinaryData(
                        uv.tobytes(), BufferViewTarget.ARRAY_BUFFER)
                self.write_tangents(mesh, blender_object or blender_data)
            except Exception as exc:
                namespace["export_errors"].append(exc)
                raise

    stocks = bpy.data.collections["01_AIR_VENT_EXPORT"].objects
    expected = {"FloatAndNeedle", "VentBody", "VentCap"}
    expected.update(f"VentOrificeInsert_{index}" for index in range(5))
    if set(stocks.keys()) != expected:
        raise ValueError(f"Unexpected vent stocks: {list(stocks.keys())}")
    material = bpy.data.materials.new("CATALOG_radiator_service_brass")
    if material.name != "CATALOG_radiator_service_brass":
        raise ValueError("Preview source already contains the export material name")
    io_scene_gltf2.glTF2ExportUserExtension = VentExport
    bpy.ops.object.select_all(action="DESELECT")
    for stock in stocks:
        stock.data.materials.clear()
        stock.data.materials.append(material)
        stock.select_set(True)
    result = bpy.ops.export_scene.gltf(
        filepath=str(output), export_format="GLB", use_selection=True,
        export_yup=True, export_tangents=True, export_attributes=True,
        export_materials="EXPORT", export_animations=False)
    if "FINISHED" not in result or namespace["export_errors"]:
        raise RuntimeError(f"Vent export failed: {result}, {namespace['export_errors']}")
    print(validate(output))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    export_vent(parser.parse_args(sys.argv[sys.argv.index("--") + 1:]).output.resolve())
