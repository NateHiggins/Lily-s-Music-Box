"""Export metre charts and exact corner frames from selected native stock."""

import ast
import copy
from pathlib import Path

import bpy
import io_scene_gltf2
from io_scene_gltf2.io.com.constants import BufferViewTarget
from io_scene_gltf2.io.exp.binary_data import BinaryData
import numpy as np

from check_exported_tangents import validate


def export_metric_stocks(output, stocks, material_for, *, morph_tangents=False):
    recipe = (Path(__file__).resolve().parents[2] /
              "reviews/v2_radiator_native_20261017/native_recipe/export_mechanisms.py")
    tree = ast.parse(recipe.read_text(encoding="utf-8"))
    tangent_hook = next(node for node in tree.body if isinstance(node, ast.ClassDef)
                        and node.name == "ExactCornerTangents")
    namespace = {"np": np, "copy": copy, "export_errors": []}
    exec(compile(ast.Module(body=[tangent_hook], type_ignores=[]), str(recipe), "exec"),
         namespace)

    class MetricExport(namespace["ExactCornerTangents"]):
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
                    for index, target in enumerate(primitive.targets or []):
                        for prefix, semantic in (("_MORPHP", "POSITION"), ("_MORPHN", "NORMAL")):
                            authored = attributes.pop(f"{prefix}{index:02d}")
                            target[semantic].buffer_view = BinaryData(
                                authored.buffer_view.data, BufferViewTarget.ARRAY_BUFFER)
                if mesh.weights is not None and morph_tangents:
                    # Keep the installed GLB default. The runtime initializes each pose.
                    mesh.weights = [1] * len(mesh.weights)
                self.write_tangents(mesh, blender_object or blender_data)
            except Exception as exc:
                namespace["export_errors"].append(exc)
                raise

    io_scene_gltf2.glTF2ExportUserExtension = MetricExport
    bpy.ops.object.select_all(action="DESELECT")
    for stock in stocks:
        for index, preview in enumerate(stock.data.materials):
            stock.data.materials[index] = material_for(preview)
        stock.hide_set(False)
        stock.select_set(True)
    result = bpy.ops.export_scene.gltf(
        filepath=str(output), export_format="GLB", use_selection=True,
        export_yup=True, export_tangents=True, export_attributes=True,
        export_materials="EXPORT", export_animations=False,
        export_morph_tangent=morph_tangents)
    if "FINISHED" not in result or namespace["export_errors"]:
        raise RuntimeError(f"Metric stock export failed: {result}, {namespace['export_errors']}")
    print(validate(output))
