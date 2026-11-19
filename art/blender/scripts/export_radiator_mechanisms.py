"""Export the installed mechanisms from art/blender/radiator_mechanisms.blend.

Open that blend in Blender, then run this script with an output GLB argument
after --. The export does not save changes to the blend.
"""

import argparse
import json
from pathlib import Path
import sys

import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))
from radiator_metric_export import export_metric_stocks


def export_mechanisms(output):
    root = Path(__file__).resolve().parents[3]
    catalog = json.loads((root / "game/data/runtime_material_sets.json").read_text())["materials"]
    collection = bpy.data.collections["01_MECHANISM_EXPORT"]
    collection.hide_viewport = False
    bpy.context.view_layer.update()
    stocks = collection.objects
    if len(stocks) != 19:
        raise ValueError(f"Expected 19 mechanism stocks, got {len(stocks)}")
    packing = stocks["RemovableFibrousUnionPacking"]
    expected = ["Seated", *(f"Spread_{index:02d}" for index in range(1, 21))]
    if list(packing.data.shape_keys.key_blocks.keys()) != expected:
        raise ValueError("Packing must provide all twenty deformation anchors")

    materials = {}

    def material_for(preview):
        key = preview.name.removeprefix("Review_catalogue_")
        if key not in materials:
            name = "CATALOG_" + key
            material = bpy.data.materials.new(name)
            if material.name != name:
                raise ValueError(f"Preview source already contains {name}")
            material.use_nodes = True
            shader = material.node_tree.nodes["Principled BSDF"]
            shader.inputs["Base Color"].default_value = (1, 1, 1, 1)
            shader.inputs["Metallic"].default_value = catalog[key]["metallic"]
            shader.inputs["Roughness"].default_value = 0.5
            materials[key] = material
        return materials[key]

    export_metric_stocks(output, stocks, material_for, morph_tangents=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    export_mechanisms(parser.parse_args(sys.argv[sys.argv.index("--") + 1:]).output.resolve())
