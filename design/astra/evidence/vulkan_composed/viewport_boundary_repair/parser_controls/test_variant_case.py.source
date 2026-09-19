"""Pure in-memory variant controls; never mutate production or start Godot."""
import unittest
from variant_case import select_variant, GUARD, OPERATION, LIVE


class VariantControls(unittest.TestCase):
    def setUp(self):
        self.source = LIVE.read_bytes()
        self.normal = self.source.replace(b'\r\n', b'\n')

    def test_candidate_exact_bytes(self):
        self.assertEqual(select_variant(self.source, 'candidate'), self.source)

    def test_viewport_control_only_guard(self):
        selected = select_variant(self.source, 'viewport_omission').replace(b'\r\n', b'\n')
        self.assertEqual(selected, self.normal.replace(GUARD, b'\t\t# Negative control: omit only the SubViewport ownership boundary.\n'))
        self.assertEqual(selected.count(OPERATION), 1)

    def test_helper_control_keeps_guard(self):
        selected = select_variant(self.source, 'omission').replace(b'\r\n', b'\n')
        self.assertEqual(selected.count(GUARD), 1)
        self.assertNotIn(OPERATION, selected)
        self.assertEqual(selected, self.normal.replace(OPERATION, b'pass # Negative control: omit only pre-change same-scenario rebind.'))

    def test_raw_keeps_guard_and_unrelated_bytes(self):
        marker = b'# UNRELATED FUTURE FIX MUST SURVIVE\n'
        selected = select_variant(self.source + marker, 'raw').replace(b'\r\n', b'\n')
        self.assertTrue(selected.endswith(marker))
        self.assertIn(GUARD, selected)
        self.assertNotIn(b'_set_zone_layer_mask', selected)
        self.assertNotIn(OPERATION, selected)

    def test_mutated_guard_fails_closed(self):
        with self.assertRaises(ValueError): select_variant(self.source.replace(b'cursor is SubViewport', b'cursor is Viewport'), 'raw')

    def test_duplicate_operation_fails_closed(self):
        with self.assertRaises(ValueError): select_variant(self.source + OPERATION, 'omission')


if __name__ == '__main__': unittest.main()
