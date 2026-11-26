"""Source geometry, topology and appointment checks for the Price brothers."""
import importlib.util
import json
import math
import unittest
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "game/data"

def load(name):
    return json.loads((DATA / name).read_text(encoding="utf-8"))

def geometry(r):
    return {row[0]: row[1:] for path in r["paths"] for row in path}

class PriceDoorwayTests(unittest.TestCase):
    def setUp(self):
        self.host = load("orison_v2/noel_price_routine.json")
        self.guest = load("orison_v2/jonah_price_routine.json")
        self.chain = next(p for p in self.guest["paths"] if p[-1][0] == "price_4c_visitor")

    def test_reproducible_public_branch(self):
        spec = importlib.util.spec_from_file_location("build_routes", ROOT / "tools/build_resident_routes.py")
        builder = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(builder)
        generated = {"paths": [], "places": {}}
        builder._price_doorway(generated, self.host)
        self.assertEqual(generated["paths"], [self.chain])
        self.assertEqual(self.chain[0][0], "f04_stair_clear")
        self.assertNotIn("F04_C_ENTRY_DOOR", self.guest["doors"])
        self.assertTrue(all(row[3] < 3.85 for row in self.chain))
        adjacency = defaultdict(set)
        for path in self.guest["paths"]:
            for a, b in zip(path, path[1:]):
                adjacency[a[0]].add(b[0])
                adjacency[b[0]].add(a[0])
        frontier = [self.guest["places"]["unit"]]
        seen = set(frontier)
        while frontier:
            for node in adjacency[frontier.pop()] - seen:
                seen.add(node)
                frontier.append(node)
        self.assertIn(self.guest["places"]["visit:4C_doorway"], seen)
        # Every reused point identity must retain the same world coordinates.
        points = geometry(self.guest)
        for path in self.guest["paths"]:
            for ident, x, y, z in path:
                self.assertEqual([x,y,z], points[ident])

    def test_stances_and_sightline_fit(self):
        layout = load("orison_v2_blockout.json")
        door = next(d for d in layout["doors"] if d["id"] == "F04_C_ENTRY_DOOR")
        cx, cz = door["center"]
        half = door["width"] / 2
        hx, hy, hz = geometry(self.host)[self.host["places"]["unit:doorway"]]
        gx, gy, gz = self.chain[-1][1:]
        self.assertEqual(hy, gy)
        self.assertGreater(hz - cz, door["width"] + .28)
        self.assertGreater(cz - gz, door["width"] + .28)
        distance = math.hypot(hx - gx, hz - gz)
        self.assertTrue(.65 < distance < 2.8)
        crossing = gx + (hx-gx)*(cz-gz)/(hz-gz)
        self.assertGreater(half - abs(crossing-cx), .28)
        platforms = [p["rect"] for p in layout["platforms"] if p["id"] == "F04_PUBLIC_LANDING_W_SHAFT_1"]
        self.assertTrue(any(x0+.28 < gx < x1-.28 and z0+.28 < gz < z1-.28 for x0,z0,x1,z1 in platforms))

    def test_sunday_window_and_admission(self):
        schedules = load("resident_schedules.json")["residents"]
        encounter = next(e for e in load("temporal/ordinary_performances.json")["encounters"] if e["id"]=="OY07")
        blocks = []
        for resident, place in (("noel_price", "unit:doorway"), ("jonah_price", "visit:4C_doorway")):
            record = schedules[resident]
            block = next(row for row in record["blocks"] if row.get("place") == place)
            self.assertEqual(block["days"], ["sun"])
            self.assertIn(place, encounter["places"])
            blocks.append(block)
        self.assertEqual(max(b["start_min"] for b in blocks),720)
        self.assertEqual(min(b["end_min"] for b in blocks),750)
        self.assertIn("notebook",encounter["excluded_anchors"])


if __name__ == "__main__":
    unittest.main()
