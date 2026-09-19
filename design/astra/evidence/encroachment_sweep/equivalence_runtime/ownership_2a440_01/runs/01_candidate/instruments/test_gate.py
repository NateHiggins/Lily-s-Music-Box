import copy
import unittest
from gate import classify, PHASES, expected_rows


def fixture(mode="candidate"):
    rows = [{"context": context, "label": label, "ok": True} for context, label in expected_rows(mode)]
    comparisons = [{"phase": phase, "reverse_order": order, "equal": True, "baseline": {"value": 1}, "selected": {"value": 1}}
                   for phase in sorted(PHASES) for order in (False, True)]
    if mode != "candidate":
        label = "overlap obeys authored priority" if mode == "priority" else "new draw is discovered on the next sweep"
        for row in rows:
            if row["context"].startswith(mode + "/") and row["label"] == label:
                row["ok"] = False
        for row in comparisons:
            if mode == "priority" or row["phase"] not in ("initial", "repeated"):
                row["equal"] = False
                row["selected"] = {"value": 2}
                label = f'{row["phase"]} order={str(row["reverse_order"]).lower()} installed graph'
                next(item for item in rows if item["context"] == "equivalence" and item["label"] == label)["ok"] = False
    failures = sum(not row["ok"] for row in rows)
    probe = {"variant": mode, "checks": len(rows), "failures": failures, "results": rows,
             "retired": True, "comparisons": comparisons}
    log = f"ENCROACHMENT SWEEP EQUIVALENCE: {'FAIL' if failures else 'PASS'} ({len(rows)-failures}/{len(rows)})\n"
    return probe, log, int(mode != "candidate")


class GateControls(unittest.TestCase):
    def test_clean_synthetic_candidate(self):
        self.assertTrue(classify(*fixture(), True)["clean_equivalence"])

    def test_two_synthetic_selective_reds(self):
        for mode in ("priority", "drop_late"):
            result = classify(*fixture(mode), True)
            self.assertTrue(result["expected_selective_red_observed"], result)
            self.assertEqual(result["diagnostic_gate_exit"], 1)

    def test_native_errors_never_expected(self):
        for error in ("ERROR: unrelated", "SCRIPT ERROR: wrong type", "WARNING: ObjectDB instances leaked at exit"):
            probe, log, code = fixture("priority")
            self.assertFalse(classify(probe, log + error, code, True)["expected_selective_red_observed"])

    def test_crash_incomplete_and_changed_source_rejected(self):
        probe, log, _ = fixture("drop_late")
        for code, stable in ((3221225477, True), (1, False), (124, True)):
            self.assertFalse(classify(probe, log, code, stable)["expected_selective_red_observed"])
        probe["retired"] = False
        self.assertFalse(classify(probe, log, 1, True)["expected_selective_red_observed"])

    def test_baseline_or_unrelated_failure_rejected(self):
        for context, label in (("baseline/reversed=false", "overlap obeys authored priority"),
                               ("priority/reversed=false", "field texture identity remains exact")):
            probe, log, code = fixture("priority")
            next(row for row in probe["results"] if row["context"] == context and row["label"] == label)["ok"] = False
            probe["failures"] += 1
            log = f'ENCROACHMENT SWEEP EQUIVALENCE: FAIL ({probe["checks"]-probe["failures"]}/{probe["checks"]})\n'
            result = classify(probe, log, code, True)
            self.assertFalse(result["expected_selective_red_observed"])
            self.assertIn("baseline_failed" if context.startswith("baseline") else "unrelated_functional_failure", result["reasons"])

    def test_late_control_must_preserve_first_census(self):
        probe, log, code = fixture("drop_late")
        probe["comparisons"][0].update(phase="initial", equal=False)
        self.assertFalse(classify(probe, log, code, True)["expected_selective_red_observed"])

    def test_phase_or_footer_omission_rejected(self):
        probe, log, code = fixture()
        damaged = copy.deepcopy(probe)
        damaged["comparisons"].pop()
        self.assertFalse(classify(damaged, log, code, True)["clean_equivalence"])
        self.assertFalse(classify(probe, "", code, True)["clean_equivalence"])

    def test_missing_one_order_failure_rejected(self):
        probe, log, code = fixture("priority")
        next(row for row in probe["results"] if row["context"] == "priority/reversed=true"
             and row["label"] == "overlap obeys authored priority")["ok"] = True
        probe["failures"] -= 1
        log = f'ENCROACHMENT SWEEP EQUIVALENCE: FAIL ({probe["checks"]-probe["failures"]}/{probe["checks"]})\n'
        result = classify(probe, log, code, True)
        self.assertFalse(result["expected_selective_red_observed"])
        self.assertIn("missing_selective_failure_true", result["reasons"])

    def test_changed_or_missing_payload_rejected(self):
        for damage in ("change", "omit"):
            probe, log, code = fixture()
            if damage == "change":
                probe["comparisons"][0]["selected"] = {"value": 42}
            else:
                del probe["comparisons"][0]["baseline"]
            self.assertFalse(classify(probe, log, code, True)["clean_equivalence"])

    def test_missing_counts_rejected_without_exception(self):
        probe, log, code = fixture()
        del probe["checks"]
        self.assertFalse(classify(probe, log, code, True)["clean_equivalence"])

    def test_plausible_truncated_full_footer_is_rejected(self):
        probe, _, code = fixture()
        probe["results"] = probe["results"][:150]
        probe["checks"] = 150
        result = classify(probe, "ENCROACHMENT SWEEP EQUIVALENCE: PASS (150/150)\n", code, True)
        self.assertFalse(result["clean_equivalence"])
        self.assertIn("declared_check_order_or_labels_changed", result["reasons"])

    def test_equal_count_with_repeated_or_reordered_label_rejected(self):
        for operation in ("repeat", "reorder"):
            probe, log, code = fixture()
            if operation == "repeat":
                probe["results"][-1] = probe["results"][-2].copy()
            else:
                probe["results"][2], probe["results"][3] = probe["results"][3], probe["results"][2]
            self.assertFalse(classify(probe, log, code, True)["clean_equivalence"])


if __name__ == "__main__":
    unittest.main()
