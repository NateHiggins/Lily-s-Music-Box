"""Pure Python controls; importing the wrapper never starts an engine."""
import unittest
from run_case import assess


class MaterialGateTests(unittest.TestCase):
    green = '[BIND PASS] one\n[BIND PASS] two\nAPARTMENT MATERIAL BINDING: PASS (2/2)\n'
    red = '[BIND PASS] one\n[BIND FAIL] two\nAPARTMENT MATERIAL BINDING: FAIL (1/2)\n'

    def test_complete_green(self):
        self.assertEqual(assess(self.green, 0, True, 2, False)['gate_exit'], 0)

    def test_specific_native_red(self):
        self.assertTrue(assess(self.red, 1, True, 2, True)['intended_red'])

    def test_red_cannot_pass_green_gate(self):
        self.assertEqual(assess(self.red, 1, True, 2, False)['gate_exit'], 1)

    def test_native_exit_mismatch_is_not_intended_red(self):
        self.assertFalse(assess(self.red, 5, True, 2, True)['intended_red'])

    def test_missing_or_duplicate_footer(self):
        for raw in [self.green.split('APARTMENT')[0], self.green + self.green]:
            self.assertEqual(assess(raw, 0, True, 2, False)['gate_exit'], 1)

    def test_diagnostics_invalidate_both_paths(self):
        for diagnostic in ['ERROR: bad', 'SCRIPT ERROR: bad', 'ObjectDB instances leaked at exit']:
            self.assertEqual(assess(self.green + diagnostic, 0, True, 2, False)['gate_exit'], 1)
            self.assertFalse(assess(self.red + diagnostic, 1, True, 2, True)['intended_red'])

    def test_count_drift_and_source_mutation(self):
        self.assertEqual(assess(self.green, 0, True, 3, False)['gate_exit'], 1)
        self.assertEqual(assess(self.green, 0, False, 2, False)['gate_exit'], 1)

    def test_timeout_and_lane_refusal_are_not_test_reds(self):
        for code in [73, 78, 124]:
            self.assertFalse(assess(self.red, code, True, 2, True)['intended_red'])


if __name__ == '__main__':
    unittest.main()
