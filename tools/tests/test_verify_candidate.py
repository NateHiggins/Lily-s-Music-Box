#!/usr/bin/env python3
"""Candidate verifier: the claim comparison and the gate-path rule.

The end-to-end path (fresh worktrees, gate boards, Godot) is exercised by
running the tool; these tests pin the pure decisions it makes.
"""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS))
import verify_candidate as vc  # noqa: E402

CAND = "c" * 40
BASE = "b" * 40


def observed(**over):
    data = {
        "candidate": CAND, "merge_base": BASE,
        "selector": {"value": "v1", "status": "PASS"},
        "protected": {"matched": 17, "expected": 17, "status": "PASS"},
        "ledger_before": {"FIRST_SLICE_TECHNICAL": 0}, "ledger_after": {"FIRST_SLICE_TECHNICAL": 0},
        "comparison": {"requirements_changed": [], "regressions": [], "improvements": []},
        "candidate_board": {"gates": [{"id": "ledger", "exit": 2}, {"id": "spatial", "exit": 0}]},
        "godot": [{"scene": "res://tests/A.tscn", "exit": 0}],
    }
    data.update(over)
    return data


def report(**over):
    data = {"schema": vc.REPORT_SCHEMA, "head": CAND, "merge_base": BASE, "selector": "v1",
            "protected": "17/17", "ledger_before": {"FIRST_SLICE_TECHNICAL": 0},
            "ledger_after": {"FIRST_SLICE_TECHNICAL": 0}, "requirements_changed": [],
            "gates": {"ledger": 2, "spatial": 0}, "suites": {"res://tests/A.tscn": 0},
            "last_line": f"MERGE-CANDIDATE {CAND[:7]}"}
    data.update(over)
    return data


class CompareReportTests(unittest.TestCase):
    def test_a_true_report_has_no_mismatches(self):
        self.assertEqual(vc.compare_report(report(), observed()), [])

    def test_wrong_schema_is_one_mismatch(self):
        self.assertEqual(len(vc.compare_report({"schema": "x"}, observed())), 1)

    def test_claimed_exit_code_that_differs_is_named(self):
        found = vc.compare_report(report(gates={"spatial": 0, "ledger": 0}), observed())
        self.assertEqual(found, ["gate ledger: report says exit 0, observed 2"])

    def test_claimed_zero_movement_that_moved(self):
        found = vc.compare_report(report(), observed(comparison={
            "requirements_changed": ["f01.lobby"], "regressions": [], "improvements": []}))
        self.assertTrue(any("requirements_changed" in m for m in found))

    def test_claimed_ledger_counts_must_match(self):
        found = vc.compare_report(report(ledger_after={"FIRST_SLICE_TECHNICAL": 0}),
                                  observed(ledger_after={"FIRST_SLICE_TECHNICAL": 7}))
        self.assertTrue(any(m.startswith("ledger_after") for m in found))

    def test_suite_not_run_here_is_named(self):
        found = vc.compare_report(report(suites={"res://tests/B.tscn": 0}), observed())
        self.assertTrue(any("not run here" in m for m in found))

    def test_last_line_naming_another_commit(self):
        found = vc.compare_report(report(last_line="MERGE-CANDIDATE deadbee"), observed())
        self.assertTrue(any("different commit" in m for m in found))

    def test_protected_claim(self):
        found = vc.compare_report(report(), observed(protected={"matched": 16, "expected": 17}))
        self.assertTrue(any(m.startswith("protected") for m in found))


class GatePathTests(unittest.TestCase):
    def test_gate_files_are_flagged(self):
        for path in ("tools/audit_orison_v2_completeness.py", "tools/data_consumption_baseline.json",
                     "tools/orison_spatial_dependency_manifest.json", "tools/tests/test_x.py",
                     "tools/run_godot_serial.ps1", "tools/data_consumption_exceptions.json"):
            self.assertTrue(vc.GATE_PATH_RE.match(path), path)

    def test_ordinary_files_are_not(self):
        for path in ("game/scripts/props/door_prop.gd", "design/ORISON_V2_X_CHECKPOINT.md",
                     "tools/prop_reference/cli.py"):
            self.assertFalse(vc.GATE_PATH_RE.match(path), path)


class RepoChecks(unittest.TestCase):
    """Read-only checks against this repository's history."""

    def test_selector_and_protected_at_head(self):
        head = vc.git("rev-parse", "HEAD")
        self.assertEqual(vc.selector_check(head)["value"], "v1")
        protected = vc.protected_check(head, head)
        self.assertEqual((protected["matched"], protected["expected"]), (17, 17))


if __name__ == "__main__":
    unittest.main(verbosity=2)
