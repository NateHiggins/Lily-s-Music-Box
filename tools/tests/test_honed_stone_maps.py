"""Independent pigment, physical normal scale and unchanged shipped height units."""
import contextlib
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import numpy as np
from PIL import Image

ART_TOOLS = Path(__file__).resolve().parents[2] / "art/tools"
sys.path.insert(0, str(ART_TOOLS))
import ingest_material_sources as ingest
import ship_surface_tables as ship


class HonedStoneMapsTests(unittest.TestCase):
    def test_vein_pigment_cannot_carve_the_stone(self):
        plain = np.full((64, 64, 3), .72)
        veined = plain.copy()
        veined[::8] -= .15
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            maps = []
            for index, pigment in enumerate((plain, veined)):
                out = root / str(index)
                with patch.object(ingest, "OUT", str(out)):
                    ingest.write_set("stair", pigment, 1.2, .448, .016, .16, "stair_marble_honed")
                maps.append({name: (out / "stair" / (name + ".png")).read_bytes()
                             for name in ("albedo", "height", "normal", "roughness")})
            self.assertNotEqual(maps[0]["albedo"], maps[1]["albedo"])
            for name in ("height", "normal", "roughness"):
                self.assertEqual(maps[0][name], maps[1][name], name)

    def test_physical_normal_slope_follows_metres_per_tile(self):
        height, normal, rough = ingest.independent_surface_maps("stair", 1.2, 64, .448)
        wide_height, wide_normal, wide_rough = ingest.independent_surface_maps("stair", 2.4, 64, .448)
        np.testing.assert_array_equal(height, wide_height)
        np.testing.assert_array_equal(rough, wide_rough)
        n, wide_n = normal * 2 - 1, wide_normal * 2 - 1
        np.testing.assert_allclose(n[..., :2] / n[..., 2:3],
                                   2 * wide_n[..., :2] / wide_n[..., 2:3], atol=1e-12)

    def test_shipping_preserves_authored_physical_height(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "ai_materials/stair"
            source.mkdir(parents=True)
            pixels = np.tile(np.arange(130, 154, dtype=np.uint8), (24, 1))
            Image.fromarray(pixels).save(source / "height.png", optimize=True)
            (source / "material.json").write_text(json.dumps({
                "meters_per_tile": 1.2, "relief_mm": .16,
                "height_model": ingest.INDEPENDENT_SURFACES["stair"]["model"]}), encoding="utf-8")
            mapping = root / "mapping.json"
            mapping.write_text(json.dumps({"stair": "ai_materials/stair"}), encoding="utf-8")
            with patch.object(ship, "MAPPING", str(mapping)), \
                    patch.object(ship, "TEX_ROOT", str(root)), \
                    patch.object(ship, "HEIGHT_OUT", str(root / "shipped")), \
                    contextlib.redirect_stdout(io.StringIO()):
                table = ship.ship_heights({"stair"})
            np.testing.assert_array_equal(np.asarray(Image.open(root / "shipped/stair.png")), pixels)
            self.assertEqual(table["stair"], {"relief_mm": .16, "tile_m": 1.2, "source_range": [0., 1.]})


if __name__ == "__main__":
    unittest.main()
