"""The dream's rooms are V2's rooms (order wc0265c4a2ba0): the committed catalog is exactly what the generator makes
from the V2 blockout, every module names real blockout spaces, and every door and hazard fits its room."""
import copy
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
            days.setdefault((row["day_of"], row["weekday"]), []).append(row)
        self.assertEqual({k[0] for k in days}, subjects)
        self.assertTrue(set(gen.WEEKDAYS) <= {k[1] for k in days})
        self.assertTrue({k[1] for k in days} <= set(gen.WEEKDAYS) | {"extra"})
        for subject, rows in days.items():
            order = [r["day_order"] for r in rows]
            self.assertEqual(order, list(range(len(rows))), subject)
            spaces = [r["source"]["records"][0]["id"] for r in rows]
            self.assertTrue(all(a != b for a, b in zip(spaces, spaces[1:])), (subject, "consecutive stops differ"))
            if subject[1] != "extra":
                self.assertNotEqual(spaces[0], spaces[-1], (subject, "the day folds: its last stop is not its first"))

    def test_a_day_is_one_real_weekday(self):
        schedules = json.loads(gen.SCHEDULES.read_text(encoding="utf-8"))["residents"]
        for weekday in gen.WEEKDAYS:
            for start, block in gen.resolved_day(schedules["cal_dwyer"]["blocks"], weekday):
                self.assertTrue(not block.get("days") or weekday in block["days"], (weekday, start))
        monday = [r["source"]["records"][0]["id"] for r in self.catalog["days"] if r["day_of"] == "cal_dwyer" and r["weekday"] == "mon"]
        saturday = [r["source"]["records"][0]["id"] for r in self.catalog["days"] if r["day_of"] == "cal_dwyer" and r["weekday"] == "sat"]
        self.assertNotEqual(monday, saturday, "Cal's Monday bath is not his Saturday")

    def test_every_supported_schedule_place_has_exact_room_vocabulary(self):
        schedules = json.loads(gen.SCHEDULES.read_text(encoding="utf-8"))["residents"]
        ids = {row["id"] for row in self.blockout["spaces"]}
        for row in self.catalog["days"]:
            self.assertTrue(row["schedule_places"], row["id"])
            self.assertEqual(row["schedule_places"], sorted(set(row["schedule_places"])), row["id"])
            resident = schedules[row["day_of"]]
            record = row["source"]["records"][0]
            for place in row["schedule_places"]:
                self.assertEqual(gen.day_space(place, resident["unit"], ids),
                                 (record["id"], row["furnish_as"]), (row["id"], place))
            level, rect = gen.rect_of(self.blockout, record["id"])
            self.assertEqual(record["floor"], level)
            self.assertEqual(record["rect_m"], [gen.r3(v) for v in rect])
            self.assertEqual(row["footprint_m"], [gen.r3(rect[2] - rect[0]), gen.r3(rect[3] - rect[1])])
        for subject in {row["day_of"] for row in self.catalog["days"]}:
            resident = schedules[subject]
            blocks = list(resident["blocks"])
            for special in resident.get("special_days", []):
                blocks.extend(special.get("blocks", []))
            for block in blocks:
                found = gen.day_space(block["place"], resident["unit"], ids)
                if found is None:
                    continue
                matches = [r for r in self.catalog["days"]
                           if r["day_of"] == subject and block["place"] in r["schedule_places"]]
                self.assertTrue(matches, (subject, block["place"]))
                self.assertTrue(all((r["source"]["records"][0]["id"], r["furnish_as"]) == found
                                    for r in matches), (subject, block["place"]))

    def test_special_and_monthly_only_places_get_stable_extras(self):
        schedules = json.loads(gen.SCHEDULES.read_text(encoding="utf-8"))
        profiles = json.loads(gen.PROFILES.read_text(encoding="utf-8"))
        original = gen.day_modules(self.blockout, schedules, profiles)
        changed = copy.deepcopy(schedules)
        resident = changed["residents"]["mina_vale"]
        resident["blocks"].append({"start_min": 600, "end_min": 620, "place": "visit:5A", "monthly": "first"})
        resident.setdefault("special_days", []).append({"doy": 123, "blocks": [
            {"start_min": 600, "end_min": 620, "place": "visit:6A"}]})
        result = gen.day_modules(self.blockout, changed, profiles)
        self.assertTrue(all(result[k] == row for k, row in original.items()), "ordinary rows are unchanged")
        extras = [row for key, row in result.items() if key not in original]
        self.assertEqual([r["id"] for r in extras], ["DAY_mina_vale_extra_00", "DAY_mina_vale_extra_01"])
        self.assertEqual([r["source"]["records"][0]["id"] for r in extras], ["F05_A_MAIN", "F06_A_MAIN"])
        self.assertEqual([r["schedule_places"] for r in extras], [["visit:5A"], ["visit:6A"]])
        self.assertTrue(all(r["weekday"] == "extra" for r in extras))
        reordered = copy.deepcopy(changed)
        other = reordered["residents"]["mina_vale"]
        other["blocks"].insert(0, other["blocks"].pop())
        other["special_days"].reverse()
        self.assertEqual(gen.day_modules(self.blockout, reordered, profiles), result,
                         "extra ids and aliases are stable under conditional-block reordering")

    def test_same_ten_modules_and_topology_as_the_fractal_expects(self):
        self.assertEqual(len(self.catalog["modules"]), 10)
        self.assertIn("D00_4B_THRESHOLD", self.catalog["modules"])
        for edge in self.catalog["topology"]:
            for module_id, connector in (edge["from"], edge["to"]):
                self.assertIn(connector, {c["id"] for c in self.catalog["modules"][module_id]["connectors"]}, edge["id"])


if __name__ == "__main__":
    unittest.main()
