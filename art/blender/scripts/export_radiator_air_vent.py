"""Export the installed vent from art/blender/radiator_air_vent.blend.

Open that blend in Blender, then run this script with an output GLB argument
after --. The export does not save changes to the blend.
"""

import argparse
from pathlib import Path
import sys

import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))
from radiator_metric_export import export_metric_stocks


def export_vent(output):
    stocks = bpy.data.collections["01_AIR_VENT_EXPORT"].objects
    expected = {"FloatAndNeedle", "VentBody", "VentCap"}
    expected.update(f"VentOrificeInsert_{index}" for index in range(5))
    if set(stocks.keys()) != expected:
        raise ValueError(f"Unexpected vent stocks: {list(stocks.keys())}")
    material = bpy.data.materials.new("CATALOG_radiator_service_brass")
    if material.name != "CATALOG_radiator_service_brass":
        raise ValueError("Preview source already contains the export material name")
    export_metric_stocks(output, stocks, lambda _preview: material)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    export_vent(parser.parse_args(sys.argv[sys.argv.index("--") + 1:]).output.resolve())
