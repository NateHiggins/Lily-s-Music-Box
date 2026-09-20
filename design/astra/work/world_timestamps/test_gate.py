import unittest
from gate import diagnostic_gate


class DiagnosticGateTests(unittest.TestCase):
    def test_success_requires_footer_exit_and_stable_inputs(self):
        self.assertEqual(diagnostic_gate('timestamps', 0, True, 'WORLD TIMESTAMPS: PASS 2/2')['exit'], 0)
        for native, stable, raw in [(1, True, 'WORLD TIMESTAMPS: FAIL 1/2'),
                                    (0, False, 'WORLD TIMESTAMPS: PASS 2/2'),
                                    (0, True, ''), (0, True, 'WORLD TIMESTAMPS: FAIL 1/2')]:
            self.assertEqual(diagnostic_gate('timestamps', native, stable, raw)['exit'], 1)

    def test_zero_exit_does_not_hide_native_errors_or_retention(self):
        for line in ['ERROR: renderer fault', 'SCRIPT ERROR: Invalid call', 'Parse Error: invalid type',
                     'WARNING: ObjectDB instances leaked at exit', 'resources still in use at exit',
                     'RID allocations of type X were leaked', 'Unreferenced static string']:
            self.assertEqual(diagnostic_gate('timestamps', 0, True, 'WORLD TIMESTAMPS: PASS 2/2\n' + line)['exit'], 1)

    def test_wrong_suite_footer_cannot_pass(self):
        self.assertEqual(diagnostic_gate('timestamps', 0, True, 'CAMPAIGN CALENDAR: PASS 2/2')['exit'], 1)


if __name__ == '__main__':
    unittest.main(verbosity=2)
