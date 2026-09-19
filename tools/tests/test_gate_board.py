#!/usr/bin/env python3
"""The gate board's comparison is the verdict; pin every rule it applies."""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS))
import gate_board as gb  # noqa: E402


def row(gid, severity="PASS", exit_code=0, counts=None, defects=None, states=None, info=None):
    return {"id": gid, "severity": severity, "exit": exit_code, "timed_out": False,
            "elapsed_s": 0.1, "counts": counts or {}, "defects": defects or [],
            "states": states or {}, "info": info or {}}


def board(*rows, commit="a" * 40, version=None):
    return {"schema": gb.BOARD_SCHEMA, "commit": commit, "tree": "t", "gates": list(rows),
            "tool_version": gb.TOOL_VERSION if version is None else version,
            "status_order": gb._FALLBACK_STATUS_ORDER, "created_utc": "x", "dirty_paths": []}


class CompareTests(unittest.TestCase):
    def test_identical_boards_have_no_regressions(self):
        b = board(row("ledger", "INCOMPLETE", 2, {"blockers.X": 3}, states={"r1": "PROGRAMMED"}))
        result = gb.compare(b, b)
        self.assertEqual(result["regressions"], [])
        self.assertEqual(result["requirements_changed"], [])

    def test_known_red_that_stays_red_is_not_a_regression(self):
        old = board(row("carriers", "FAIL", 1, {"forbidden": 2}, ["a.gd:1:Hold E"]))
        self.assertEqual(gb.compare(old, old)["regressions"], [])

    def test_severity_rise_is_a_regression(self):
        old = board(row("spatial"))
        new = board(row("spatial", "FAIL", 1))
        self.assertTrue(any("PASS -> FAIL" in r for r in gb.compare(old, new)["regressions"]))

    def test_count_rise_and_new_named_defect_are_regressions(self):
        old = board(row("reader", counts={"unread": 0}))
        new = board(row("reader", "FAIL", 1, {"unread": 1}, ["FIELD_UNREAD|game/data/x.json|f"]))
        regs = gb.compare(old, new)["regressions"]
        self.assertIn("reader: unread 0 -> 1", regs)
        self.assertIn("reader: new defect FIELD_UNREAD|game/data/x.json|f", regs)

    def test_resolved_defect_is_an_improvement(self):
        old = board(row("carriers", "FAIL", 1, {"forbidden": 1}, ["clock:297:Hold E"]))
        new = board(row("carriers", counts={"forbidden": 0}))
        result = gb.compare(old, new)
        self.assertEqual(result["regressions"], [])
        self.assertIn("carriers: resolved clock:297:Hold E", result["improvements"])

    def test_ledger_status_fall_regresses_and_rise_improves(self):
        old = board(row("ledger", "INCOMPLETE", 2, states={"a": "RUNTIME_PROVEN", "b": "ABSENT"}))
        new = board(row("ledger", "INCOMPLETE", 2, states={"a": "PROGRAMMED", "b": "SHELL_ONLY"}))
        result = gb.compare(old, new)
        self.assertIn("ledger: a RUNTIME_PROVEN -> PROGRAMMED", result["regressions"])
        self.assertIn("ledger: b ABSENT -> SHELL_ONLY", result["improvements"])
        self.assertEqual(sorted(result["requirements_changed"]), ["a", "b"])

    def test_disappeared_requirement_regresses_and_added_is_a_change(self):
        old = board(row("ledger", "INCOMPLETE", 2, states={"gone": "ABSENT"}))
        new = board(row("ledger", "INCOMPLETE", 2, states={"fresh": "ABSENT"}))
        result = gb.compare(old, new)
        self.assertTrue(any("gone disappeared" in r for r in result["regressions"]))
        self.assertTrue(any("fresh added" in c for c in result["changes"]))
        self.assertEqual(sorted(result["requirements_changed"]), ["fresh", "gone"])

    def test_fewer_tests_run_is_a_regression_even_when_green(self):
        old = board(row("test:test_x", info={"ran": 10}))
        new = board(row("test:test_x", info={"ran": 7}))
        self.assertIn("test:test_x: ran 10 -> 7 tests", gb.compare(old, new)["regressions"])

    def test_boards_from_different_versions_are_not_compared(self):
        result = gb.compare(board(version=1), board())
        self.assertFalse(result["comparable"])
        self.assertEqual(len(result["regressions"]), 1)
        self.assertIn("different gate_board versions", result["regressions"][0])

    def test_new_gate_that_fails_regresses(self):
        new = board(row("test:test_new", "FAIL", 1))
        self.assertTrue(gb.compare(board(), new)["regressions"])


class ParserTests(unittest.TestCase):
    def test_reader_names_every_unexcepted_finding_with_or_without_baseline(self):
        import json as _json
        out = _json.dumps({"records": [
            {"kind": "FIELD_UNREAD", "file": "game/data/a.json", "field": "x", "excepted": False},
            {"kind": "FILE_UNREAD", "file": "game/data/b.json", "excepted": False},
            {"kind": "FIELD_UNREAD", "file": "game/data/a.json", "field": "y", "excepted": True}]})
        parsed = gb.parse_reader(1, out, "")
        self.assertEqual(parsed["defects"], ["FIELD_UNREAD|game/data/a.json|x",
                                             "FILE_UNREAD|game/data/b.json|"])
        self.assertEqual(parsed["counts"]["unread"], 2)
        self.assertFalse(parsed["info"]["baseline_used"])

    def test_unittest_parser_reads_failures_and_names(self):
        err = ("FAIL: test_a (mod.Case.test_a)\n----\nRan 5 tests in 0.1s\n\n"
               "FAILED (failures=1, errors=2)\n")
        parsed = gb.parse_unittest(1, "", err)
        self.assertEqual(parsed["counts"]["failed"], 3)
        self.assertEqual(parsed["info"]["ran"], 5)
        self.assertEqual(parsed["defects"], ["test_a (mod.Case.test_a)"])

    def test_unittest_parser_counts_a_crash_before_any_test_ran(self):
        parsed = gb.parse_unittest(1, "", "SyntaxError: bad\n")
        self.assertEqual(parsed["counts"]["failed"], 1)
        self.assertIsNone(parsed["info"]["ran"])

    def test_period_parser(self):
        out = "PERIOD DATE INFO x\nPERIOD DATE AUDIT: PASS (10 classified findings)\n"
        parsed = gb.parse_period(0, out, "")
        self.assertEqual(parsed["info"]["classified"], 10)
        self.assertEqual(parsed["counts"]["fail_lines"], 0)

    def test_unparseable_json_output_is_an_error_not_a_pass(self):
        gate = {"id": "fake", "argv": ["-c", "print('not json')"], "parse": gb.parse_ledger,
                "incomplete": set(), "error": set()}
        result = gb.run_gate(TOOLS.parent, gate, 30)
        self.assertEqual(result["exit"], 0)
        self.assertEqual(result["severity"], "ERROR")


if __name__ == "__main__":
    unittest.main(verbosity=2)
