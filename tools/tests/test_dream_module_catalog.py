"""The dream's rooms are V2's rooms (order wc0265c4a2ba0): the committed catalog is exactly what the generator makes
from the V2 blockout, every module names real blockout spaces, and every door and hazard fits its room."""
import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import generate_dream_module_catalog as gen


class DreamModuleCatalogTests(unittest.TestCase):
    def setUp(self):
        self.blockout = json.loads(gen.BLOCKOUT.read_text(encoding="utf-8"))
        self.catalog = json.loads(gen.CATALOG.read_text(encoding="utf-8"))

    def test_committed_catalog_is_the_generated_one(self):
        expected = gen.render(gen.build_all())
        self.assertEqual(gen.CATALOG.read_text(encoding="utf-8").replace("\r\n", "\n"), expected,
                         "run python tools/generate_dream_module_catalog.py")

    def test_every_module_is_made_of_real_v2_spaces(self):
        ids = {row["id"] for key in ("spaces", "platforms", "envelopes") for row in self.blockout.get(key, [])}
        for module_id, module in self.catalog["modules"].items():
            for record in module["source"]["records"]:
                self.assertIn(record["id"], ids, module_id)

    def test_doors_and_hazards_fit_their_rooms(self):
        for module_id, module in self.catalog["modules"].items():
            length, depth = module["footprint_m"]
            span = {"north": length, "south": length, "east": depth, "west": depth}
            for door in module["connectors"]:
                half = door["width_m"] * 0.5
                self.assertGreaterEqual(door["offset_m"] - half, gen.MARGIN - 1e-6, (module_id, door["id"]))
                self.assertLessEqual(door["offset_m"] + half, span[door["side"]] - gen.MARGIN + 1e-6, (module_id, door["id"]))
            for socket in module.get("hazard_sockets", []):
                x, z = socket["position_m"]
                r = socket["clearance_radius_m"]
                self.assertTrue(r <= x <= length - r and r <= z <= depth - r, (module_id, socket["id"]))

    def test_each_subject_lends_a_folded_day_of_real_rooms(self):
        ids = {row["id"] for row in self.blockout["spaces"]}
        profiles = json.loads(gen.PROFILES.read_text(encoding="utf-8"))["profiles"]
        subjects = {p["pursuit"]["silhouette_resident"] for p in profiles.values()}
        days = {}
        for row in self.catalog["days"]:
            self.assertNotIn(row["id"], self.catalog["modules"], "a day room never shadows a base module")
            self.assertIn(row["source"]["records"][0]["id"], ids)
            self.assertIn(row["furnish_as"], self.catalog["modules"])
            days.setdefault(row["day_of"], []).append(row)
        self.assertEqual(set(days), subjects)
        for subject, rows in days.items():
            order = [r["day_order"] for r in rows]
            self.assertEqual(order, list(range(len(rows))), subject)
            spaces = [r["source"]["records"][0]["id"] for r in rows]
            self.assertTrue(all(a != b for a, b in zip(spaces, spaces[1:])), (subject, "consecutive stops differ"))
            self.assertNotEqual(spaces[0], spaces[-1], (subject, "the day folds: its last stop is not its first"))

    def test_same_ten_modules_and_topology_as_the_fractal_expects(self):
        self.assertEqual(len(self.catalog["modules"]), 10)
        self.assertIn("D00_4B_THRESHOLD", self.catalog["modules"])
        for edge in self.catalog["topology"]:
            for module_id, connector in (edge["from"], edge["to"]):
                self.assertIn(connector, {c["id"] for c in self.catalog["modules"][module_id]["connectors"]}, edge["id"])


if __name__ == "__main__":
    unittest.main()
