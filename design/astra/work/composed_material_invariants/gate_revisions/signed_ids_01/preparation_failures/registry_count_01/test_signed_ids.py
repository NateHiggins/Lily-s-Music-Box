from pathlib import Path
import importlib.util
import json
import unittest
from material_gate import classify_materials, valid_instance_id
from test_material_gate import fixture

HERE = Path(__file__).resolve().parent.parent
ROOT = HERE.parents[5]


class SignedIDControls(unittest.TestCase):
    def test_actual_negative_row_exposes_original_false_rejection(self):
        spec = importlib.util.spec_from_file_location("old_positive_id_gate", HERE / "originals/material_gate.py")
        old = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(old)
        captured = json.loads((HERE / "fixtures/actual_negative_finish_id.json").read_text())
        value = captured["row"]["material_id"]
        probe = fixture()
        probe["material_observations"][0]["cases"]["cal_memory_radio"]["finishes"][0]["material_id"] = value
        before, after = old.classify_materials(probe, "expected"), classify_materials(probe, "expected")
        self.assertEqual(before["reasons"], ["before_measured/cal_memory_radio: missing real draw/material identity"])
        self.assertEqual(after["material_gate_exit"], 0)

    def test_exact_signed64_nonzero_domain(self):
        for value in (-(1 << 63), -9223370061119417423, -1, 1, (1 << 63) - 1):
            with self.subTest(value=value):
                self.assertTrue(valid_instance_id(value))
        for value in (0, True, False, -(1 << 63) - 1, 1 << 63, -1.0, 1.0, None, "-1"):
            with self.subTest(value=value):
                self.assertFalse(valid_instance_id(value))

    def test_gate_rejects_zero_bool_and_out_of_range(self):
        for value in (0, True, False, -(1 << 63) - 1, 1 << 63):
            probe = fixture()
            probe["material_observations"][0]["cases"]["cal_memory_radio"]["finishes"][0]["material_id"] = value
            result = classify_materials(probe, "expected")
            self.assertEqual(result["material_gate_exit"], 1)
            self.assertTrue(any("missing real draw/material identity" in reason for reason in result["reasons"]))

    def test_actual_composition_red_is_not_cleared(self):
        captured = json.loads((HERE / "fixtures/actual_negative_finish_id.json").read_text())
        probe_path = ROOT / captured["source_probe"]
        probe = json.loads(probe_path.read_text())
        result = classify_materials(probe, "7c54c18154ccf8de8c3bce13a356329344dec19411adb2f1237425ae99eb90db")
        self.assertEqual(result["material_gate_exit"], 1)
        self.assertEqual(len([row for row in probe["checks"] if row["passed"] is not True]), 8)
        self.assertFalse(any("missing real draw/material identity" in reason for reason in result["reasons"]))
        self.assertEqual(sum("registry differs from unique active installed resources" in reason for reason in result["reasons"]), 24)
        self.assertEqual(sum("material issues or timing scope failure" in reason for reason in result["reasons"]), 8)


if __name__ == "__main__":
    unittest.main()
