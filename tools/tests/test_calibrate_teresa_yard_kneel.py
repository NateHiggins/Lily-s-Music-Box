import copy
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from tools.calibrate_teresa_yard_kneel import Calibration, Gltf, PRESENTATION, read_fit


class TeresaKneelCalibrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.calibration = Calibration(ROOT)
        cls.profile = cls.calibration.generate()

    def test_current_bake_matches_sources_and_full_source_contact_sweep(self):
        _, _, baked = read_fit(ROOT / PRESENTATION)
        self.assertEqual(baked, {"a_feet": self.profile})
        result = self.calibration.verify_contact(baked["a_feet"])
        self.assertEqual(result["samples"], 129)
        self.assertGreater(result["minimum_y_m"]["shoe"], .0008)
        self.assertGreater(result["minimum_y_m"]["skirt"], .07)
        self.assertLess(result["maximum_individual_ankle_horizontal_drift_m"], .000001)

    def test_corrupted_lift_is_rejected_by_actual_source_skin(self):
        damaged = copy.deepcopy(self.profile)
        damaged["lifts"][16] -= .02
        with self.assertRaisesRegex(ValueError, "penetrates source floor"):
            self.calibration.verify_contact(damaged)

    def test_changed_out_angle_cannot_hide_individual_foot_sliding(self):
        damaged = copy.deepcopy(self.profile)
        damaged["out"]["Left"]["thigh"] += 4
        with self.assertRaises(ValueError):
            self.calibration.verify_contact(damaged)

    def test_formal_skirt_failure_is_not_promoted_by_calibrated_shoes(self):
        formal = Calibration(ROOT, "b_feet", "b_bottom")
        profile = formal.generate()
        with self.assertRaisesRegex(ValueError, "skirt penetrates source floor"):
            formal.verify_contact(profile)

    def test_portable_default_cli_is_read_only_from_another_directory(self):
        before = (ROOT / PRESENTATION).read_bytes()
        with tempfile.TemporaryDirectory() as temporary:
            result = subprocess.run(
                [sys.executable, "-B", str(ROOT / "tools/calibrate_teresa_yard_kneel.py")],
                cwd=temporary, capture_output=True, text=True,
            )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("PASS_SOURCE_ONLY", result.stdout)
        self.assertEqual((ROOT / PRESENTATION).read_bytes(), before)

    def test_accessor_honors_stride_and_rejects_unhandled_sparse(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            data = np.array([[1, 2, 3, 99], [4, 5, 6, 99]], dtype="<f4").tobytes()
            (folder / "mesh.bin").write_bytes(data)
            document = {
                "buffers": [{"uri": "mesh.bin", "byteLength": len(data)}],
                "bufferViews": [{"buffer": 0, "byteLength": len(data), "byteStride": 16}],
                "accessors": [{"bufferView": 0, "componentType": 5126, "type": "VEC3", "count": 2}],
            }
            path = folder / "mesh.gltf"
            path.write_text(json.dumps(document), encoding="utf-8")
            np.testing.assert_array_equal(Gltf(path).accessor(0), [[1, 2, 3], [4, 5, 6]])
            document["accessors"][0]["sparse"] = {"count": 1}
            path.write_text(json.dumps(document), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "sparse/normalized"):
                Gltf(path).accessor(0)


if __name__ == "__main__":
    unittest.main()
