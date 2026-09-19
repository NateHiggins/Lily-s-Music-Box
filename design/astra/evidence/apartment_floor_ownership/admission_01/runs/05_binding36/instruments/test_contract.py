import copy
import unittest
import assess


def fixture(red=False):
    failed = set(assess.CONTRACT["expected_red_required_failed_labels"]) if red else set()
    rows = [{"label": label, "passed": label not in failed} for label in assess.CONTRACT["ordered_labels"]]
    probe = {"checks": rows, "failures": len(failed), "retired": True, "callbacks": 2,
             "observations": [{"phase": phase, "foreign_rows": {name: list(assess.CONTRACT["expected_red_exact_foreign_leaf_paths"]) if red else [] for name in assess.CONTRACT["expected_red_foreign_records"]}} for phase in ["normal", "queued"]]}
    raw = "\n".join("[WARDROBE FLOOR] " + ("PASS " if row["passed"] else "FAIL ") + row["label"] for row in rows)
    raw += "\nWARDROBE FLOOR ADMISSION: %s (%d/63)\n" % ("FAIL" if red else "PASS", 63 - len(failed))
    return [probe, raw, "", "", int(red), True, True, True, "red" if red else "green"]


class ContractTests(unittest.TestCase):
    def test_exact_green_and_selective_red_preserve_diagnostic_exit(self):
        for red in (False, True):
            result = assess.assess(*fixture(red))
            self.assertEqual(result["control_acceptance_exit"], 0, result)
            self.assertEqual(result["diagnostic_gate_exit"], int(red))

    def test_wrong_four_leaf_membership_and_incomplete_retirement_rejected(self):
        args = fixture(True); args[0]["observations"][0]["foreign_rows"]["3A_w0_wardrobe"].pop()
        self.assertEqual(assess.assess(*args)["control_acceptance_exit"], 1)
        args = fixture(True); args[0]["retired"] = False
        self.assertEqual(assess.assess(*args)["control_acceptance_exit"], 1)

    def test_truncated_raw_and_plausible_json_label_loss_rejected(self):
        args = fixture(); args[1] = "\n".join(args[1].splitlines()[1:])
        self.assertEqual(assess.assess(*args)["control_acceptance_exit"], 1)
        args = fixture(); args[0]["checks"].pop()
        self.assertEqual(assess.assess(*args)["control_acceptance_exit"], 1)

    def test_unknown_native_error_source_change_or_no_engine_never_expected(self):
        for index, value in [(2, "SCRIPT ERROR: wrong type"), (2, "WARNING: unrelated"), (5, False), (6, False), (7, False)]:
            args = fixture(True); args[index] = value
            self.assertEqual(assess.assess(*args)["control_acceptance_exit"], 1)

    def test_runner_timeout_is_not_a_completed_red(self):
        args = fixture(True); args[4] = 124
        result = assess.assess(*args)
        self.assertEqual(result["runner_condition"], "timeout_termination")
        self.assertIsNone(result["completed_fixture_exit"])
        self.assertEqual(result["control_acceptance_exit"], 1)


if __name__ == "__main__": unittest.main()
