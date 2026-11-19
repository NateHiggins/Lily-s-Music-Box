"""Export one checked-in electrical stock blend to an output GLB passed after --."""

import argparse
from pathlib import Path
import sys

import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))
from exact_metric_stock_export import export_metric_stocks


def export_electrical(output):
    collection = bpy.data.collections["01_EXPORT_STOCK"]
    collection.hide_viewport = False
    bpy.context.view_layer.update()

    def material_for(preview):
        key = preview.name.removeprefix("Review_").split(".")[0]
        material = bpy.data.materials[key]
        if any(node.type == "TEX_IMAGE" for node in material.node_tree.nodes):
            raise ValueError(f"Stock material {key} contains preview images")
        return material

    export_metric_stocks(output, collection.objects, material_for)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    export_electrical(parser.parse_args(sys.argv[sys.argv.index("--") + 1:]).output.resolve())
