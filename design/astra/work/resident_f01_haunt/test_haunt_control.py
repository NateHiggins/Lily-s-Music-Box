"""Synthetic receipt controls only; never runs Godot or mutates live files."""
import copy
import unittest

from haunt_control import (ARRIVED, NEW_REQUIRED_PASS, OLD_REQUIRED_FAIL,
                           OLD_REQUIRED_PASS, PREFIX, RETIRED, ROUTINES,
                           STOPPED, assess_pair, clean_environment)


def stdout_for(scene):
    checks = scene["checks"]
    failed = sum(not row["passed"] for row in checks)
    scene["failures"] = failed
    return "\n".join([PREFIX + ("PASS " if row["passed"] else "FAIL ") + row["label"] for row in checks]
                     + [PREFIX + f"RESULT {len(checks) - failed} passed, {failed} failed"]) + "\n"


def fixture():
    engines = {"launcher": "a" * 64, "engine": "b" * 64}
    old = {"native_exit": 1, "source_unchanged": True, "suite_completion": False,
           "test_sha256": "c" * 64, "before": {"engine_binaries": engines},
           "after": {"engine_binaries": engines}, "diagnostic_gate": {
               "exit": 1, "reasons": ["native/runner exit 1", "expected suite/capture completion absent or failed"],
               "light_unpair_count": 0, "softshadow_underflow_count": 0,
               "retention": [], "non_inherited_errors": {}}}
    new = copy.deepcopy(old)
    for result in [old, new]:
        for label in ["before", "after"]:
            result[label].update({key: "e" * 64 for key in ["runner_sha256", "parser_sha256", "wrapper_sha256", "control_sha256"]})
    new.update(native_exit=0, suite_completion=True)
    new["diagnostic_gate"].update(exit=0, reasons=[])
    old_scene = {"checks": [{"label": label, "passed": True} for label in sorted(OLD_REQUIRED_PASS)]
                 + [{"label": label, "passed": False} for label in sorted(OLD_REQUIRED_FAIL)], "stopped": STOPPED}
    new_scene = {"checks": [{"label": label, "passed": True} for label in sorted(NEW_REQUIRED_PASS)]}
    return dict(old=old, restored=new, old_scene=old_scene, new_scene=new_scene,
                old_stdout=stdout_for(old_scene), old_stderr="", new_stdout=stdout_for(new_scene), new_stderr="",
                changed_paths=[ROUTINES], restoration={"exact_bytes_restored": True,
                    "candidate_restored_sha256": "d" * 64, "expected_candidate_sha256": "d" * 64})


class HauntControlTests(unittest.TestCase):
    def rejected(self, inputs, reason):
        result = assess_pair(**inputs)
        self.assertFalse(result["expected_control_pattern"], result)
        self.assertTrue(any(reason in text for text in result["reasons"]), result)

    def test_complete_named_pair_is_admitted(self):
        self.assertTrue(assess_pair(**fixture())["expected_control_pattern"])

    def test_partial_actual_arrival_rejected(self):
        f = fixture()
        f["old_scene"]["checks"] = [row for row in f["old_scene"]["checks"] if row["label"] != ARRIVED]
        f["old_stdout"] = stdout_for(f["old_scene"])
        self.rejected(f, "missing actual lifecycle/retirement " + ARRIVED)

    def test_retirement_omission_rejected_even_with_consistent_counts(self):
        f = fixture()
        f["old_scene"]["checks"] = [row for row in f["old_scene"]["checks"] if row["label"] != RETIRED]
        f["old_stdout"] = stdout_for(f["old_scene"])
        self.rejected(f, "missing actual lifecycle/retirement " + RETIRED)

    def test_raw_unknown_error_rejected_even_if_gate_metadata_omits_it(self):
        f = fixture(); f["old_stderr"] = "  ERROR: unrelated production failure\n"
        self.rejected(f, "unknown raw error")

    def test_unreviewed_route_error_rejected(self):
        f = fixture(); f["old_stderr"] = "ERROR: No wall-safe resident route on F01: old shaft\n"
        self.rejected(f, "no route error allowance declared")

    def test_unreviewed_warning_rejected(self):
        f = fixture(); f["old_stderr"] = "WARNING: unexplained engine warning\n"
        self.rejected(f, "unreviewed warning")

    def test_raw_compact_pairing_signature_rejected(self):
        f = fixture(); f["old_stderr"] = "ERROR: geom->softshadow_count==0 - BUG!\n"
        self.rejected(f, "raw pairing or retention")

    def test_retention_rejected(self):
        f = fixture(); f["old_stderr"] = "WARNING: ObjectDB instances leaked at exit\n"
        self.rejected(f, "raw pairing or retention")

    def test_changed_runtime_source_rejected(self):
        f = fixture(); f["old"]["source_unchanged"] = False
        self.rejected(f, "source changed during run")

    def test_extra_cross_run_source_change_rejected(self):
        f = fixture(); f["changed_paths"].append("game/scripts/other.gd")
        self.rejected(f, "source/assets differ")

    def test_failed_restore_rejected(self):
        f = fixture(); f["restoration"]["candidate_restored_sha256"] = "bad"
        self.rejected(f, "exact candidate restoration")

    def test_partial_restored_return_rejected(self):
        f = fixture()
        f["new_scene"]["checks"] = [row for row in f["new_scene"]["checks"] if row["label"] != "real return ride completes without fallback or forced readiness"]
        f["new_stdout"] = stdout_for(f["new_scene"])
        self.rejected(f, "incomplete actual lifecycle/clearance")

    def test_unrelated_named_failure_rejected(self):
        f = fixture(); f["old_scene"]["checks"].append({"label": "unrelated", "passed": False})
        f["old_stdout"] = stdout_for(f["old_scene"])
        self.rejected(f, "unrelated functional failure")

    def test_missing_completion_rejected(self):
        f = fixture(); f["old_stdout"] = "\n".join(f["old_stdout"].splitlines()[:-1])
        self.rejected(f, "final completion")

    def test_failure_count_mismatch_rejected(self):
        f = fixture(); f["old_scene"]["failures"] = 0
        self.rejected(f, "JSON failure count mismatch")

    def test_changed_fixture_rejected(self):
        f = fixture(); f["restored"]["test_sha256"] = "changed"
        self.rejected(f, "fixture differs")

    def test_changed_assessor_between_runs_rejected(self):
        f = fixture(); f["restored"]["before"]["control_sha256"] = "changed"
        self.rejected(f, "execution input differs across pair: control_sha256")

    def test_render_overrides_cleared_and_recorded(self):
        overrides = {"SURFACE_MODE": "anything", "SURFACE_FUTURE_FLAG": "1",
                     "PERF_STREET_CORE_GEOMETRY_ON": "0", "PERF_STREET_HARUKIYA_GEOMETRY_ON": "0",
                     "PERF_NEON_LETTER_BATCHING_OFF": "1"}
        env, cleared, present = clean_environment({**overrides, "PATH": "unchanged", "UNRELATED": "keep"})
        self.assertEqual(env, {"PATH": "unchanged", "UNRELATED": "keep"})
        self.assertTrue(set(overrides).issubset(cleared))
        self.assertEqual(set(present), set(overrides))


if __name__ == "__main__":
    unittest.main(verbosity=2)
