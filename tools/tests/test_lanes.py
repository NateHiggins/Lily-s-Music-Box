#!/usr/bin/env python3
"""Lane ledger dispositions: a suggestion for a person, pinned here."""
from __future__ import annotations

import datetime as dt
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import lanes  # noqa: E402

NOW = dt.datetime(2026, 9, 18, tzinfo=dt.timezone.utc)


def row(**kw):
    base = {"kind": "worktree", "exists": True, "merged": False, "dirty": 0,
            "last_commit": "2026-09-17T00:00:00+00:00"}
    base.update(kw)
    return base


class DispositionTests(unittest.TestCase):
    def test_merged_clean_worktree_is_removable(self):
        self.assertEqual(lanes.disposition(row(merged=True), 14, NOW), "merged-clean")

    def test_merged_with_uncommitted_work_is_not(self):
        self.assertEqual(lanes.disposition(row(merged=True, dirty=3), 14, NOW), "merged-dirty")

    def test_unmerged_recent_and_stale(self):
        self.assertEqual(lanes.disposition(row(), 14, NOW), "unmerged-active")
        old = row(last_commit="2026-08-01T00:00:00+00:00")
        self.assertEqual(lanes.disposition(old, 14, NOW), "unmerged-stale")

    def test_missing_directory(self):
        self.assertEqual(lanes.disposition(row(exists=False), 14, NOW), "missing")

    def test_remote_branch_merged(self):
        self.assertEqual(lanes.disposition(row(kind="remote", merged=True, dirty=None), 14, NOW),
                         "merged")

    def test_live_repository_report_has_main(self):
        report = lanes.collect("origin/main", False, 14)
        self.assertEqual(report["schema"], lanes.SCHEMA)
        self.assertTrue(report["rows"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
