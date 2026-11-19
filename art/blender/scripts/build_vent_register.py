"""Export the fitted ventilation register from its editable Blender source."""

import json
from pathlib import Path
import sys

import bpy
import numpy as np

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(HERE))

from lift_gate_export import ExactCornerTangents
from check_exported_tangents import validate

FINISHES = json.loads((ROOT / "game/data/runtime_material_sets.json").read_text())["materials"]


class RegisterExport(ExactCornerTangents):
    def gather_material_hook(self, material, blender_material, settings):
        key = material.name.removeprefix("Export__")
        spec = FINISHES[key]
        material.name = key
        material.extras = {
            "catalog_key": key,
            "meters_per_tile": spec["meters_per_tile"],
            "normal_scale": spec.get("normal_scale", .35),
            "roughness": spec["roughness_multiplier"],
            "external_maps": spec["files"],
            "uv_units": "metres",
        }

    def gather_mesh_hook(self, mesh, data, obj, *args):
        from io_scene_gltf2.io.exp.binary_data import BinaryData
        from io_scene_gltf2.io.com.constants import BufferViewTarget

        for primitive in mesh.primitives:
            attributes = primitive.attributes
            normal = attributes.pop("_AUTHORED_NORMAL")
            uv = attributes.pop("_EXACT_UV")
            exact_uv = np.frombuffer(uv.buffer_view.data, dtype="<f4").reshape(-1, 3)
            attributes["NORMAL"].buffer_view = BinaryData(normal.buffer_view.data, BufferViewTarget.ARRAY_BUFFER)
            attributes["TEXCOORD_0"].buffer_view = BinaryData(
                exact_uv[:, :2].astype("<f4").tobytes(), BufferViewTarget.ARRAY_BUFFER
            )
        self.write_tangents(mesh, obj or data)


def export(output):
    import io_scene_gltf2

    bpy.ops.wm.open_mainfile(filepath=str(ROOT / "art/blender/vent_register.blend"))
    io_scene_gltf2.glTF2ExportUserExtension = RegisterExport
    for obj in bpy.context.scene.objects:
        obj.select_set(False)
    collection = bpy.data.collections["01_REGISTER_EXPORT"]
    collection.hide_viewport = False
    for obj in collection.objects:
        obj.hide_set(False)
        obj.select_set(True)
        obj.data.materials.clear()
        obj.data.materials.append(bpy.data.materials["Export__" + obj["catalog_key"]])
    bpy.context.view_layer.update()
    result = bpy.ops.export_scene.gltf(
        filepath=str(output), export_format="GLB", use_selection=True, export_yup=True,
        export_tangents=True, export_attributes=True, export_extras=True,
        export_materials="EXPORT", export_animations=False,
    )
    if "FINISHED" not in result:
        raise RuntimeError("Vent register export did not finish")
    validate(output)


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    export(Path(args[0]).resolve() if args else ROOT / "game/assets/props/vent_register.glb")
