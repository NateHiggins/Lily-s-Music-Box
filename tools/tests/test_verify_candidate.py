#!/usr/bin/env python3
"""Candidate verifier: the claim comparison and the gate-path rule.

The end-to-end path (fresh worktrees, gate boards, Godot) is exercised by
running the tool; these tests pin the pure decisions it makes.
"""
from __future__ import annotations

import sys
import contextlib
import io
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

TOOLS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS))
import verify_candidate as vc  # noqa: E402

CAND = "c" * 40
BASE = "b" * 40


def observed(**over):
    data = {
        "candidate": CAND, "merge_base": BASE,
        "selector": {"value": "v2", "status": "PASS"},
        "protected": {"matched": 17, "expected": 17, "status": "PASS"},
        "ledger_before": {"FIRST_SLICE_TECHNICAL": 0}, "ledger_after": {"FIRST_SLICE_TECHNICAL": 0},
        "comparison": {"requirements_changed": [], "regressions": [], "improvements": []},
        "candidate_board": {"gates": [{"id": "ledger", "exit": 2}, {"id": "spatial", "exit": 0}]},
        "godot": [{"scene": "res://tests/A.tscn", "exit": 0}],
    }
    data.update(over)
    return data


def report(**over):
    data = {"schema": vc.REPORT_SCHEMA, "head": CAND, "merge_base": BASE, "selector": "v2",
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

    def test_sidecar_written_in_the_candidate_may_name_the_parent(self):
        parent = "p" * 40
        claim = report(head=parent, last_line=f"MERGE-CANDIDATE {parent[:7]}")
        self.assertEqual(len(vc.compare_report(claim, observed())), 2)
        self.assertEqual(vc.compare_report(claim, observed(candidate_aliases=[parent])), [])

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
        self.assertEqual(vc.EXPECTED_SELECTOR, "v2")
        with patch.object(vc, "git_bytes", return_value=(vc.REPO / vc.SELECTOR_PATH).read_bytes()):
            self.assertEqual(vc.selector_check(head), {"value": "v2", "status": "PASS"})
        protected = vc.protected_check(head, head)
        self.assertEqual((protected["matched"], protected["expected"]), (17, 17))


class AuthorizedCutoverTests(unittest.TestCase):
    def test_only_default_literal_may_change(self):
        before = b'const DEFAULT_ID := "v1" # rollback\nconst PATHS := {"v1": "old"}\n'
        after = before.replace(b'"v1" #', b'"v2" #')
        self.assertTrue(vc.selector_default_cutover(before, after))
        self.assertFalse(vc.selector_default_cutover(before, after + b"# other change\n"))
        self.assertFalse(vc.selector_default_cutover(before, after.replace(b'"old"', b'"lost"')))
        self.assertFalse(vc.selector_default_cutover(None, after))
        self.assertFalse(vc.selector_default_cutover(before, None))
        self.assertFalse(vc.selector_default_cutover(after, before))

    def test_v1_is_no_longer_a_valid_default(self):
        with patch.object(vc, "git_bytes", return_value=b'const DEFAULT_ID := "v1"\n'):
            self.assertEqual(vc.selector_check(CAND), {"value": "v1", "status": "FAIL"})

    def test_protected_check_records_only_the_authorized_selector_exception(self):
        selector = b'const DEFAULT_ID := "v1"\n'
        asset = "game/data/building_layout.json"
        receipt = json.dumps({"files": [
            {"path": vc.SELECTOR_PATH}, {"path": asset}]}).encode()

        def blobs(*args):
            spec = args[-1]
            if spec.endswith(vc.PROTECTED_RECEIPT):
                return receipt
            if spec == f"{BASE}:{vc.SELECTOR_PATH}":
                return selector
            if spec == f"{CAND}:{vc.SELECTOR_PATH}":
                return selector.replace(b'"v1"', b'"v2"')
            return b"protected asset"

        def oids(*args, **kwargs):
            return "same" if args[-1].endswith(asset) else args[-1]

        with patch.object(vc, "git_bytes", side_effect=blobs), patch.object(vc, "git", side_effect=oids):
            result = vc.protected_check(BASE, CAND)
            self.assertEqual((result["status"], result["matched"],
                              result["authorized_selector_changes"]), ("PASS", 1, 1))
        with patch.object(vc, "git_bytes", side_effect=blobs), \
                patch.object(vc, "git", side_effect=lambda *a, **k: a[-1]):
            self.assertEqual(vc.protected_check(BASE, CAND)["status"], "FAIL")


class InPlaceVerificationTests(unittest.TestCase):
    def board(self, **over):
        data = {"schema": vc.gate_board.BOARD_SCHEMA,
                "tool_version": vc.gate_board.TOOL_VERSION, "commit": BASE,
                "tree": "tree", "dirty_paths": [],
                "gates": [{"id": g["id"]} for g in vc.gate_board.GATES]
                + [{"id": "test:test_a"}]}
        data.update(over)
        return data

    def fake_git(self, *args, **kwargs):
        if args[:2] == ("ls-tree", "-r"):
            return "tools/check_rulings.py\ntools/tests/test_a.py"
        if args == ("rev-parse", f"{BASE}^{{tree}}"):
            return "tree"
        if args == ("rev-parse", "HEAD") or args[:2] == ("rev-parse", "--verify"):
            return BASE if args[-1] == f"{BASE}^{{commit}}" else CAND
        if args[0] == "merge-base":
            return BASE
        return ""

    def test_baseline_rejects_dirty_wrong_commit_and_missing_gates(self):
        with patch.object(vc, "git", side_effect=self.fake_git):
            self.assertEqual(vc.validate_baseline_board(self.board(), BASE), [])
            for board in (self.board(dirty_paths=[" M game/foo.gd"]),
                          self.board(commit=CAND), self.board(tree="other"),
                          self.board(gates=[{"id": "ledger"}]),
                          self.board(tool_version=-1)):
                self.assertTrue(vc.validate_baseline_board(board, BASE), board)

    def test_in_place_never_creates_or_removes_a_worktree(self):
        with tempfile.TemporaryDirectory() as directory:
            baseline = Path(directory) / "baseline.json"
            baseline.write_text(json.dumps(self.board()), encoding="utf-8")
            with patch.object(vc, "git", side_effect=self.fake_git), \
                    patch.object(vc, "fresh_worktree") as create, \
                    patch.object(vc, "remove_worktree") as remove, \
                    patch.object(vc.gate_board, "build_board", return_value=self.board(commit=CAND)) as build, \
                    patch.object(vc.gate_board, "compare", return_value={
                        "regressions": [], "improvements": [], "requirements_changed": []}), \
                    patch.object(vc, "changed_files", return_value=[]), \
                    patch.object(vc, "protected_check", return_value={
                        "matched": 16, "expected": 17, "status": "PASS",
                        "authorized_selector_changes": 1}), \
                    patch.object(vc, "selector_check", return_value={"value": "v2", "status": "PASS"}), \
                    contextlib.redirect_stdout(io.StringIO()):
                result = vc.main([CAND, "--base", BASE, "--in-place", "--baseline-board",
                                  str(baseline), "--out", str(Path(directory) / "out"),
                                  "--no-fetch", "--no-godot"])
                self.assertEqual(result, 0)
                create.assert_not_called()
                remove.assert_not_called()
                self.assertEqual(build.call_count, 1)
                self.assertEqual(build.call_args.args[0], vc.REPO)

    def test_in_place_rejects_dirty_checkout_before_any_worktree_or_board(self):
        def dirty_git(*args, **kwargs):
            return " M game/player.gd" if args[0] == "status" else self.fake_git(*args, **kwargs)

        with patch.object(vc, "git", side_effect=dirty_git), \
                patch.object(vc, "fresh_worktree") as create, \
                patch.object(vc, "remove_worktree") as remove, \
                patch.object(vc.gate_board, "build_board") as build, \
                contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(vc.main([CAND, "--in-place", "--baseline-board", "unused.json",
                                      "--no-fetch", "--no-godot"]), 3)
            create.assert_not_called()
            remove.assert_not_called()
            build.assert_not_called()


if __name__ == "__main__":
    unittest.main(verbosity=2)
