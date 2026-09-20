import unittest
from marker_omission import BASE, BASE_SHA, is_exact_omission, omit_build_marker, sha


class MarkerSourceControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.original = BASE.read_bytes()

    def test_bound_source_and_single_line_omission(self):
        self.assertEqual(sha(self.original), BASE_SHA)
        changed = omit_build_marker(self.original)
        self.assertTrue(is_exact_omission(self.original, changed))
        line = b'\t\t\t\tmaterial.set_meta("living_storey", floor_id)\r\n'
        self.assertEqual(len(self.original) - len(changed), len(line))
        self.assertEqual(self.original.count(line) - changed.count(line), 1)

    def test_registry_and_prop_markers_remain(self):
        changed = omit_build_marker(self.original)
        self.assertIn(b'material.set_meta("living_storey", floor_id)', changed)
        self.assertIn(b'own.set_meta("living_storey", _floor_of(case_id))', changed)
        self.assertEqual(self.original.split(b"func _bind_storey(", 1)[1], changed.split(b"func _bind_storey(", 1)[1])

    def test_other_changes_or_wrong_baseline_rejected(self):
        changed = omit_build_marker(self.original)
        self.assertFalse(is_exact_omission(self.original, changed + b"\n"))
        self.assertFalse(is_exact_omission(self.original + b"\n", changed))
        self.assertFalse(is_exact_omission(self.original, changed.replace(b"_living_candidate", b"_missing_guard", 1)))


if __name__ == "__main__":
    unittest.main()
