"""Pure Python controls; importing the wrapper never starts an engine."""
import unittest
import argparse
from pathlib import Path
import tempfile
import subprocess
from run_case import assess, runtime_files, shader_files, timeout_seconds, powershell_file_command


class MaterialGateTests(unittest.TestCase):
    green = '[BIND PASS] one\n[BIND PASS] two\nAPARTMENT MATERIAL BINDING: PASS (2/2)\n'
    red = '[BIND PASS] one\n[BIND FAIL] two\nAPARTMENT MATERIAL BINDING: FAIL (1/2)\n'

    def test_complete_green(self):
        result = assess(self.green, 0, True, 2, False)
        self.assertEqual(result['diagnostic_gate_exit'], 0)
        self.assertEqual(result['control_acceptance_exit'], 0)

    def test_specific_native_red(self):
        result = assess(self.red, 1, True, 2, True)
        self.assertTrue(result['intended_red'])
        self.assertEqual(result['diagnostic_gate_exit'], 1)
        self.assertEqual(result['control_acceptance_exit'], 0)

    def test_red_cannot_pass_green_gate(self):
        result = assess(self.red, 1, True, 2, False)
        self.assertEqual(result['diagnostic_gate_exit'], 1)
        self.assertEqual(result['control_acceptance_exit'], 1)

    def test_native_exit_mismatch_is_not_intended_red(self):
        self.assertFalse(assess(self.red, 5, True, 2, True)['intended_red'])

    def test_missing_or_duplicate_footer(self):
        for raw in [self.green.split('APARTMENT')[0], self.green + self.green]:
            self.assertEqual(assess(raw, 0, True, 2, False)['diagnostic_gate_exit'], 1)

    def test_diagnostics_invalidate_both_paths(self):
        for diagnostic in ['ERROR: bad', 'SCRIPT ERROR: bad', 'ObjectDB instances leaked at exit']:
            self.assertEqual(assess(self.green + diagnostic, 0, True, 2, False)['diagnostic_gate_exit'], 1)
            self.assertFalse(assess(self.red + diagnostic, 1, True, 2, True)['intended_red'])

    def test_count_drift_and_source_mutation(self):
        self.assertEqual(assess(self.green, 0, True, 3, False)['diagnostic_gate_exit'], 1)
        self.assertEqual(assess(self.green, 0, False, 2, False)['diagnostic_gate_exit'], 1)

    def test_timeout_and_lane_refusal_are_not_test_reds(self):
        for code in [73, 78, 124]:
            self.assertFalse(assess(self.red, code, True, 2, True)['intended_red'])

    def test_green_is_not_an_accepted_expected_red(self):
        result = assess(self.green, 0, True, 2, True)
        self.assertEqual(result['diagnostic_gate_exit'], 0)
        self.assertEqual(result['control_acceptance_exit'], 1)

    def test_expectation_cannot_change_diagnostic_result(self):
        for raw, code in [(self.green, 0), (self.red, 1), (self.red + 'ERROR: broken', 1)]:
            self.assertEqual(assess(raw, code, True, 2, True)['diagnostic_gate_exit'],
                             assess(raw, code, True, 2, False)['diagnostic_gate_exit'])

    def test_runner_timeout_bounds(self):
        self.assertEqual(timeout_seconds('1'), 1)
        self.assertEqual(timeout_seconds('180'), 180)
        for invalid in ['0', '181', '-1', '1.5', 'invalid']:
            with self.assertRaises(argparse.ArgumentTypeError):
                timeout_seconds(invalid)

    def test_shader_and_nested_include_sources_are_bound(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            names = ['game/shaders/orison_surface.gdshader',
                     'game/shaders/sub/living.gdshaderinc', 'game/shaders/sub/ignored.txt']
            for name in names:
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text('shader source', encoding='utf-8')
            expected = {root / names[0], root / names[1]}
            self.assertEqual(set(shader_files(root)), expected)
            self.assertEqual(set(runtime_files(root)), expected)

    def test_child_runner_preserves_write_error_then_timeout_exit(self):
        with tempfile.TemporaryDirectory() as temp:
            script = Path(temp) / 'runner stub.ps1'
            script.write_text("Write-Error 'intentional non-Godot timeout stub'\nexit 124\n", encoding='utf-8')
            result = subprocess.run(powershell_file_command(script, []), capture_output=True)
            self.assertEqual(result.returncode, 124)
            self.assertIn(b'intentional non-Godot timeout stub', result.stderr)

    def test_child_runner_preserves_regular_nonzero_exit(self):
        with tempfile.TemporaryDirectory() as temp:
            script = Path(temp) / 'runner stub.ps1'
            script.write_text("Write-Output 'intentional non-Godot assertion stub'\nexit 5\n", encoding='utf-8')
            result = subprocess.run(powershell_file_command(script, []), capture_output=True)
            self.assertEqual(result.returncode, 5)

    def test_invalid_child_invocation_stays_nonzero(self):
        with tempfile.TemporaryDirectory() as temp:
            result = subprocess.run(powershell_file_command(Path(temp) / 'missing.ps1', []), capture_output=True)
            self.assertNotEqual(result.returncode, 0)

    def test_child_argument_boundaries_and_verbose_value(self):
        with tempfile.TemporaryDirectory() as temp:
            script = Path(temp) / 'argument stub.ps1'
            script.write_text('param([string]$Scene, [string[]]$ExtraArgs)\n'
                "if ($Scene -ne 'res://tests/a folder/test.tscn' -or $ExtraArgs.Count -ne 1 -or $ExtraArgs[0] -ne '--verbose') { exit 9 }\n"
                'exit 0\n', encoding='utf-8')
            result = subprocess.run(powershell_file_command(script,
                ['-Scene', 'res://tests/a folder/test.tscn', '-ExtraArgs', '--verbose']), capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr.decode(errors='replace'))


if __name__ == '__main__':
    unittest.main()
