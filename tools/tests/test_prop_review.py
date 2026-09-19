#!/usr/bin/env python3
"""Family review kit: pixel change, census deltas, flags and run diffs."""
from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from tools.prop_reference import review  # noqa: E402


def frame(path: Path, shade: int) -> None:
    from PIL import Image
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.new("RGB", (64, 48), (shade, shade, shade)).save(path)


def shoot(root: Path, specimens: list[tuple[str, str, int, int]]) -> Path:
    """specimens: (kind, label, shade, triangles)."""
    records = []
    for index, (kind, label, shade, tris) in enumerate(specimens):
        node = f"WH_{kind}_{index:02d}"
        frames = {}
        for bearing in ("three_quarter", "front"):
            frame(root / node / f"{bearing}.png", shade)
            frames[bearing] = f"{node}/{bearing}.png"
        records.append({"kind": kind, "label": label, "node": node, "frames": frames,
                        "materials": {"triangles": tris, "surfaces": 3, "textured_surfaces": 1,
                                      "flat_colour_share": 0.5}})
    root.mkdir(parents=True, exist_ok=True)
    (root / "warehouse_manifest.json").write_text(json.dumps({"specimens": records}),
                                                  encoding="utf-8")
    return root


class PairTests(unittest.TestCase):
    def setUp(self):
        self.td = tempfile.TemporaryDirectory()
        self.root = Path(self.td.name)

    def tearDown(self):
        self.td.cleanup()

    def test_unchanged_changed_and_invisible_census_change(self):
        before = shoot(self.root / "a", [("stove", "stove", 100, 500), ("kettle", "copper", 100, 200),
                                         ("toaster", "toaster", 100, 300)])
        after = shoot(self.root / "b", [("stove", "stove", 100, 500), ("kettle", "copper", 180, 900),
                                        ("toaster", "toaster", 100, 800)])
        report = review.pair(before, after, self.root / "out")
        rows = {r["id"]: r for r in report["specimens"]}
        self.assertEqual(rows["stove"]["flags"], ["unchanged"])
        self.assertEqual(rows["kettle__copper"]["flags"], [])
        self.assertGreater(rows["kettle__copper"]["max_change"], review.DEFAULT_THRESHOLD)
        self.assertEqual(rows["toaster"]["flags"], ["census changed but no bearing shows it"])
        self.assertTrue(Path(rows["stove"]["sheet"]).is_file())
        self.assertTrue((self.root / "out" / "pair_report.md").is_file())

    def test_new_and_gone_specimens(self):
        before = shoot(self.root / "a", [("stove", "stove", 100, 500)])
        after = shoot(self.root / "b", [("boiler", "boiler", 100, 500)])
        rows = {r["id"]: r for r in review.pair(before, after, self.root / "out")["specimens"]}
        self.assertEqual(rows["stove"]["flags"], ["specimen gone"])
        self.assertEqual(rows["boiler"]["flags"], ["new specimen"])

    def test_bearings_follow_the_harness_order(self):
        self.assertEqual(review._ordered({"back", "front", "three_quarter", "extra"}),
                         ["three_quarter", "front", "back", "extra"])


class DiffTests(unittest.TestCase):
    def test_axes_gap_and_rank_are_paired(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            for name, gap, axis in (("a", 2.0, 1), ("b", 1.1, 4)):
                (root / name).mkdir()
                (root / name / "ranking.json").write_text(json.dumps({"ranked": [{
                    "id": "stove", "kind": "stove", "rank": 1 if name == "a" else 9,
                    "score": {"priority": 5.0 if name == "a" else 2.0, "gap": gap},
                    "critique": {"axes": {"detail": axis}, "confidence": "high"},
                    "triangles": 100}]}), encoding="utf-8")
            report = review.diff_runs(root / "a", root / "b")
            row = report["specimens"][0]
            self.assertEqual(row["gap"], [2.0, 1.1])
            self.assertEqual(row["axes"]["detail"], [1, 4])
            self.assertEqual(row["rank"], [1, 9])
            self.assertIn("2.00 -> 1.10", review.render_diff(report))


if __name__ == "__main__":
    unittest.main(verbosity=2)
