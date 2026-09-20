import copy
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import assess
import execute
from support import sha, dump
from test_gate import fixture


def sample(mode="candidate"):
    probe, footer, code = fixture(mode)
    good, bad = [], []
    for row in probe["results"]:
        (good if row["ok"] else bad).append(("[SWEEP PASS] " if row["ok"] else "[SWEEP FAIL] ") + row["context"] + " " + row["label"])
    return probe, "\n".join(good) + "\n" + footer, "\n".join(bad), "", code, True, True, True, mode


class RuntimePlanControls(unittest.TestCase):
    def test_candidate_and_declared_reds_keep_native_gate_separate(self):
        for mode in ("candidate", "priority", "drop_late"):
            result = assess.assess(*sample(mode))
            self.assertEqual(result["control_acceptance_exit"], 0, result)
            self.assertEqual(result["diagnostic_gate_exit"], int(mode != "candidate"))
            self.assertEqual(result["actual_runner_exit"], int(mode != "candidate"))

    def test_missing_and_malformed_receipt_rejected(self):
        for bad in (None, {}, {"checks": 171, "failures": 0, "results": [None], "comparisons": []}):
            values = list(sample()); values[0] = bad
            self.assertEqual(assess.assess(*values)["control_acceptance_exit"], 1)

    def test_removed_or_reordered_raw_assertion_rejected(self):
        for change in ("remove", "reorder"):
            values = list(sample()); lines = values[1].splitlines()
            if change == "remove": lines.pop(7)
            else: lines[7], lines[8] = lines[8], lines[7]
            values[1] = "\n".join(lines)
            self.assertEqual(assess.assess(*values)["control_acceptance_exit"], 1)

    def test_source_pid_engine_and_selected_variant_rejected(self):
        for index, value in ((5, False), (6, False), (7, False), (8, "priority")):
            values = list(sample()); values[index] = value
            self.assertEqual(assess.assess(*values)["control_acceptance_exit"], 1)

    def test_native_warning_error_retention_and_runner_refusal_rejected(self):
        for line in ("WARNING: unrelated", "  ERROR: unrelated", "RID allocations remain", "SCRIPT ERROR: parse"):
            values = list(sample("priority")); values[2] += "\n" + line
            self.assertEqual(assess.assess(*values)["control_acceptance_exit"], 1)
        for code, label in ((73, "lane_refusal"), (78, "cannot_run"), (124, "timeout_termination")):
            values = list(sample()); values[4] = code
            result = assess.assess(*values)
            self.assertEqual(result["runner_condition"], label)
            self.assertIsNone(result["completed_fixture_exit"])
            self.assertEqual(result["control_acceptance_exit"], 1)

    def test_retirement_and_label_count_remain_exact(self):
        values = list(sample()); values[0]["retired"] = False
        self.assertEqual(assess.assess(*values)["control_acceptance_exit"], 1)
        values = list(sample()); values[0]["checks"] = 150
        self.assertEqual(assess.assess(*values)["control_acceptance_exit"], 1)

    def test_raw_pass_cannot_substitute_for_named_failure(self):
        values = list(sample("priority")); values[2] = ""
        self.assertEqual(assess.assess(*values)["control_acceptance_exit"], 1)

    def test_scoped_environment_reset_is_process_local(self):
        incoming = {"APPDATA": "old", "SURFACE_DISABLE": "1", "PERF_STREET_CORE_GEOMETRY_ON": "1", "ENCROACH_SWEEP_VARIANT": "bad", "PATH": "kept"}
        env, removed = execute.clean_environment(incoming, "priority", Path("fresh"))
        self.assertEqual(incoming["APPDATA"], "old")
        self.assertEqual(env["ENCROACH_SWEEP_VARIANT"], "priority")
        self.assertEqual(env["PATH"], "kept")
        self.assertNotIn("SURFACE_DISABLE", env)
        self.assertIn("PERF_STREET_CORE_GEOMETRY_ON", removed)

    def test_exact_install_restore_and_foreign_edit_refusal(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder); out = root / "evidence"; out.mkdir()
            expected = {}
            for number in range(6):
                relative = "game/tests/fixture%d.gd" % number; target = root / relative
                target.parent.mkdir(parents=True, exist_ok=True); target.write_text("candidate")
                expected[relative] = sha(target)
            state = {"installed": expected, "original": dict.fromkeys(expected)}
            execute.verify_install(root, state, expected)
            changed = root / list(expected)[-1]; changed.write_text("foreign")
            with self.assertRaises(ValueError): execute.restore_preinstall(root, out, state)
            self.assertTrue((root / list(expected)[0]).is_file())
            changed.write_text("candidate"); execute.restore_preinstall(root, out, state)
            self.assertTrue(all(not (root / p).exists() for p in expected))

    def test_corrupt_backup_refuses_before_any_restore(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder); out = root / "evidence"; out.mkdir()
            relative = "game/tests/existing.gd"; target = root / relative
            target.parent.mkdir(parents=True); target.write_text("candidate")
            backup = out / "preinstall" / relative; backup.parent.mkdir(parents=True); backup.write_text("original")
            state = {"installed": {relative: sha(target)}, "original": {relative: sha(backup)}}
            backup.write_text("damaged")
            with self.assertRaises(ValueError): execute.restore_preinstall(root, out, state)
            self.assertEqual(target.read_text(), "candidate")

    def test_missing_required_artifact_entry_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            state = {"artifacts": {}, "before": {"instruments": {}, "copied_sources": {}}, "after": {"copied_sources": {}}}
            self.assertIn("required_artifact_entry_missing", execute.artifact_errors(Path(folder), state))

    def test_changed_raw_log_rejected_before_reassessment(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            names = ["godot.stdout.log", "godot.stdout.log.stderr", "runner.stdout.log", "runner.stderr.log",
                     "shots/equivalence.json", "command.json", "invocation.json", "run_config.json", "process_observations.json", "prelaunch_processes.json",
                     "before.all_game_files.json", "after.all_game_files.json", "before.runtime_text.json", "after.runtime_text.json", "before.game.diff", "after.game.diff"]
            for name in names:
                target = root / name; target.parent.mkdir(parents=True, exist_ok=True); target.write_text("[]")
            state = {"artifacts": {name: sha(root / name) for name in names},
                     "before": {"instruments": {}, "copied_sources": {}}, "after": {"copied_sources": {}}}
            (root / "godot.stdout.log").write_text("damaged raw output")
            self.assertEqual(execute.artifact_errors(root, state), ["artifact_missing_or_changed:godot.stdout.log"])

    def test_bridge_cmdletbinding_array_and_write_error_exit124(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder); stub = root / "stub.ps1"
            stub.write_text('[CmdletBinding()]\nparam([string[]]$ExtraArgs)\nif ($ExtraArgs.Count -ne 2 -or $ExtraArgs[0] -ne "--verbose" -or $ExtraArgs[1] -ne "two words") { exit 99 }\nWrite-Error "TIMEOUT: stub only, no engine"\nexit 124\n')
            invocation = root / "invocation.json"; dump(invocation, {"runner": str(stub), "parameters": {"ExtraArgs": ["--verbose", "two words"]}})
            command = [str(execute.PWSH), "-NoProfile", "-File", str(execute.BRIDGE), "-InvocationPath", str(invocation)]
            result = subprocess.run(command, capture_output=True)
            self.assertEqual(result.returncode, 124, result.stderr)
            self.assertIn(b"TIMEOUT: stub only", result.stderr)


if __name__ == "__main__": unittest.main()
