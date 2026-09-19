import unittest
from wrong_storey_control import BASE, corrupt_build_storey, is_exact_corruption


class WrongStoreySourceControls(unittest.TestCase):
    def test_exact_single_foreign_owner_seed(self):
        original = BASE.read_bytes()
        changed = corrupt_build_storey(original)
        self.assertTrue(is_exact_corruption(original, changed))
        self.assertEqual(changed.count(b'material.set_meta("living_storey", "F00")'), 1)
        self.assertEqual(original.split(b"func _bind_storey(", 1)[1], changed.split(b"func _bind_storey(", 1)[1])

    def test_second_change_or_missing_seed_not_accepted(self):
        original = BASE.read_bytes()
        changed = corrupt_build_storey(original)
        self.assertFalse(is_exact_corruption(original, changed + b"\n"))
        self.assertFalse(is_exact_corruption(original, changed.replace(b'"F00"', b'floor_id')))


if __name__ == "__main__":
    unittest.main()
