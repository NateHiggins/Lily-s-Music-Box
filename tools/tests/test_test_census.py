"""The test census reads real receipt files and a real test folder."""
from __future__ import annotations

import datetime as dt
import json
import pathlib
import sys
import tempfile
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
import test_census  # noqa: E402


class TestCensusTests(unittest.TestCase):
    def setUp(self):
        self._dir = tempfile.TemporaryDirectory()
        base = pathlib.Path(self._dir.name)
        self.root = base / "repo"
        (self.root / "game" / "tests").mkdir(parents=True)
        for name in ("AlphaRouteTest", "BetaShot", "GammaBench"):
            (self.root / "game" / "tests" / f"{name}.tscn").write_text("[gd_scene]\n", encoding="utf-8")
        self.reports = base / "reports"
        self.reports.mkdir()

    def tearDown(self):
        self._dir.cleanup()

    def receipt(self, name: str, scene: str, started: str, elapsed: float, code=0, timed_out=False,
                fails=0, log_text: str = "") -> None:
        log = self.reports / f"{name}.log"
        log.write_text(log_text, encoding="utf-8")
        (self.reports / f"{name}.log.receipt.json").write_text(json.dumps({
            "schema": "orison.run-receipt.v1", "scene": scene,
            "execution": {"started_utc": started, "elapsed_s": elapsed, "exit_code": code,
                          "timed_out": timed_out},
            "log": {"fail_count": fails, "script_error_count": 0, "stdout": str(log)},
        }), encoding="utf-8")

    def test_counts_costs_outcomes_and_startup(self):
        ready = "[ORISON V2 RUNTIME] ready startup_ms=%s\n"
        self.receipt("a1", "res://tests/AlphaRouteTest.tscn", "2026-11-02T10:00:00Z", 200, log_text=ready % "125000.5")
        self.receipt("a2", "res://tests/AlphaRouteTest.tscn", "2026-11-09T10:00:00Z", 160, fails=2, log_text=ready % "94000")
        self.receipt("g1", "res://tests/GammaBench.tscn", "2026-11-03T10:00:00Z", 30, code=None, timed_out=True)
        self.receipt("x1", "res://tests/RemovedTest.tscn", "2026-11-01T10:00:00Z", 10)
        board = test_census.census(self.root, self.reports, dt.date(2026, 11, 9))
        rows = {r["scene"].removeprefix("res://tests/"): r for r in board["scenes"]}
        alpha = rows["AlphaRouteTest.tscn"]
        self.assertEqual((alpha["runs"], alpha["lane_s"], alpha["median_s"]), (2, 360.0, 180.0))
        self.assertEqual((alpha["last_outcome"], alpha["idle_days"]), ("failed", 0))
        self.assertEqual((rows["BetaShot.tscn"]["last_outcome"], rows["BetaShot.tscn"]["kind"]), ("never", "Shot"))
        self.assertEqual(rows["GammaBench.tscn"]["last_outcome"], "timeout")
        self.assertFalse(rows["RemovedTest.tscn"]["in_tree"])
        totals = board["totals"]
        self.assertEqual((totals["scenes"], totals["ever_run"], totals["never_run"]), (3, 2, 1))
        self.assertEqual(totals["receipts_for_removed_scenes"], 1)
        self.assertEqual(board["startup_by_week"], {
            "2026-11-02": {"runs": 1, "median_ms": 125000, "min_ms": 125000},
            "2026-11-09": {"runs": 1, "median_ms": 94000, "min_ms": 94000}})
        self.assertIn("never did", test_census.markdown(board))

    def test_ignores_unreadable_and_foreign_receipts(self):
        (self.reports / "junk.receipt.json").write_text("{not json", encoding="utf-8")
        (self.reports / "other.receipt.json").write_text(json.dumps({"schema": "x", "scene": "s"}), encoding="utf-8")
        self.receipt("i1", "", "2026-11-09T10:00:00Z", 900)  # an --import run has no scene
        board = test_census.census(self.root, self.reports, dt.date(2026, 11, 9))
        self.assertEqual(board["totals"]["runs"], 0)


if __name__ == "__main__":
    unittest.main()
