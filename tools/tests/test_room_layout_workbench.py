#!/usr/bin/env python3
"""Focused self-tests for tools/room_layout_workbench.py.

Runs against a synthetic mini layout fixture only; never reads or writes
production data.  Execute with:

    python -m unittest discover -s tools/tests -p "test_room_layout_workbench.py"
or simply:
    python tools/tests/test_room_layout_workbench.py
"""

from __future__ import annotations

import copy
import json
import math
import sys
import tempfile
import unittest
from pathlib import Path

TOOLS_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS_DIR))

import room_layout_workbench as wb  # noqa: E402

FIXTURE = Path(__file__).resolve().parent / "fixtures" / "mini_layout.json"

# Synthetic tables so the tests do not depend on production ASM_FOOT values.
TABLES = {
    "ok": True, "note": "synthetic test tables",
    "asm_foot": {"chair": (0.24, 0.25), "table_rect": (0.62, 0.42)},
    "fridge_foot": {False: (0.35, 0.31), True: (0.36, 0.34)},
    "stove_foot": (0.32, 0.30),
    "bath_sink_foot": (0.305, 0.28),
    "shower_foot": (0.36, 0.36),
    "boxfan_foot": (0.25, 0.25),
}


def load_fixture():
    return json.loads(FIXTURE.read_text(encoding="utf-8"))


class AsmFootprintTests(unittest.TestCase):
    def test_yaw_90_swaps_half_extents(self):
        bb, _ = wb.asm_aabb({"asm": "chair", "at": [1.0, 2.0], "yaw": 90}, TABLES)
        self.assertAlmostEqual(bb[2] - bb[0], 0.50)   # hy doubled
        self.assertAlmostEqual(bb[3] - bb[1], 0.48)   # hx doubled

    def test_free_rotation_uses_safe_square(self):
        bb, note = wb.asm_aabb({"asm": "chair", "at": [0.0, 0.0], "yaw": 45}, TABLES)
        self.assertAlmostEqual(bb[2] - bb[0], 0.50)
        self.assertAlmostEqual(bb[3] - bb[1], 0.50)
        self.assertIn("safe square", note)

    def test_table_rect_uses_declared_dims(self):
        bb, _ = wb.asm_aabb({"asm": "table_rect", "at": [0.0, 0.0], "yaw": 0,
                             "L": 2.0, "W": 1.0}, TABLES)
        self.assertAlmostEqual(bb[2] - bb[0], 2.10)
        self.assertAlmostEqual(bb[3] - bb[1], 1.10)

    def test_unknown_assembly_reports_no_geometry(self):
        bb, note = wb.asm_aabb({"asm": "gizmometer", "at": [0, 0]}, TABLES)
        self.assertIsNone(bb)
        self.assertIn("gizmometer", note)


class DoorGeometryTests(unittest.TestCase):
    def test_default_swing_sweeps_counterclockwise_in_plan(self):
        marker = {"kind": "door", "id": "D", "pos": [0.0, 0.0, 0.0],
                  "yaw_deg": 0, "w": 1.0, "leaf": "closed"}
        d = wb.door_view(marker, [])
        self.assertAlmostEqual(d["latch"][0], 1.0)
        self.assertAlmostEqual(d["latch"][1], 0.0)
        end = d["arc"][-1]
        self.assertAlmostEqual(end[0], math.cos(math.radians(-100.0)), places=6)
        self.assertAlmostEqual(end[1], -math.sin(math.radians(-100.0)), places=6)
        self.assertGreater(end[1], 0.9)   # sweeps toward +y

    def test_swing_out_reverses_the_arc(self):
        marker = {"kind": "door", "id": "D", "pos": [0.0, 0.0, 0.0],
                  "yaw_deg": 0, "w": 1.0, "leaf": "closed", "swing": "out"}
        d = wb.door_view(marker, [])
        end = d["arc"][-1]
        self.assertLess(end[1], -0.9)     # sweeps toward -y instead
        self.assertEqual(d["swing"], "out")

    def test_vertical_door_latch_direction(self):
        marker = {"kind": "door", "id": "D", "pos": [4.0, 1.05, 0.0],
                  "yaw_deg": -90, "w": 0.9, "leaf": "closed"}
        d = wb.door_view(marker, [])
        self.assertAlmostEqual(d["latch"][0], 4.0, places=6)
        self.assertAlmostEqual(d["latch"][1], 1.95, places=6)

    def test_adjacent_room_probe(self):
        layout = load_fixture()
        rooms = layout["floors"][0]["rooms"]
        marker = next(m for m in layout["floors"][0]["markers"]
                      if m["id"] == "T1_DOOR_01")
        d = wb.door_view(marker, rooms)
        # The probe mirrors classify_door_markers: the SMALLEST containing room
        # wins each side.  T1_AMB deliberately overlaps T1_A's east edge and is
        # smaller than T1_A, so the west probe resolves to T1_AMB.
        self.assertEqual(set(d["adjacent_rooms"]), {"T1_AMB", "T1_B"})
        # The door still associates with T1_A geometrically (hinge on its edge).
        view = wb.collect_room_view(layout, "T1_A", TABLES)
        self.assertIn("T1_DOOR_01", [dd["id"] for dd in view["doors"]])

    def test_cabinet_door_is_content_not_room_entrance(self):
        layout = load_fixture()
        view = wb.collect_room_view(layout, "T1_A", TABLES)
        self.assertNotIn("T1_CAB_UPPER_1", [dd["id"] for dd in view["doors"]])
        cabinet = next(o for o in view["objects"]
                       if o["id"] == "T1_CAB_UPPER_1")
        self.assertEqual(cabinet["category"], "markers")
        self.assertEqual(cabinet["tier"], wb.EXACT)
        self.assertFalse(cabinet["blocking"])


class RoomViewTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.layout = load_fixture()
        cls.view_a = wb.collect_room_view(cls.layout, "T1_A", TABLES)
        cls.view_b = wb.collect_room_view(cls.layout, "T1_B", TABLES)

    def obj(self, view, rid):
        return next(o for o in view["objects"] if o["id"] == rid)

    def test_unknown_footprint_is_reported_not_drawn(self):
        gizmo = self.obj(self.view_a, "a_gizmo")
        self.assertEqual(gizmo["tier"], wb.UNKNOWN)
        self.assertIsNone(gizmo["geom"] if gizmo["shape"] not in
                          ("point",) else None)
        self.assertFalse(gizmo["blocking"])

    def test_rug_and_overhead_are_not_blocking(self):
        self.assertFalse(self.obj(self.view_a, "a_rug")["blocking"])
        self.assertFalse(self.obj(self.view_a, "a_beam")["blocking"])
        self.assertTrue(self.obj(self.view_a, "a_counter")["blocking"])

    def test_overlap_detection(self):
        findings = wb.find_intersections(self.view_a)
        pair = [f for f in findings
                if {f["a"], f["b"]} == {"a_box1", "a_box2"}]
        self.assertEqual(len(pair), 1)
        self.assertEqual(pair[0]["kind"], "intersection")
        self.assertAlmostEqual(pair[0]["overlap_m2"], 0.08, places=2)
        self.assertIn("exact", pair[0]["basis"])

    def test_boundary_crossing_and_ambiguity(self):
        cross = self.obj(self.view_b, "b_cross")
        self.assertTrue(cross["ownership"]["crosses_room_boundary"])
        self.assertTrue(cross["ownership"]["ambiguous"])
        self.assertIn("T1_AMB", cross["ownership"]["containing_rooms"])

    def test_envelope_room_is_not_ambiguous(self):
        counter = self.obj(self.view_a, "a_counter")
        self.assertFalse(counter["ownership"]["ambiguous"])
        self.assertIn("T1_ENV", counter["ownership"]["containing_rooms"])

    def test_wall_near_miss_detected(self):
        pairs = {(n[0], n[1]) for n in self.view_a["near_misses"]}
        self.assertIn((1, 2), pairs)

    def test_no_position_record_reported(self):
        self.assertIn(("sockets", "lost_socket"), self.view_a["no_position"])

    def test_art_frame_pairing(self):
        frames = {f["stem"]: f for f in self.view_b["frames"]}
        self.assertIn("b", frames)
        self.assertEqual(frames["b"]["status"], "paired")

    def test_pipe_projected_as_segment(self):
        pipe = self.obj(self.view_b, "pipe_riser")
        self.assertEqual(pipe["shape"], "segment")
        a, b, r = pipe["geom"]
        self.assertAlmostEqual(a[0], 6.6)
        self.assertAlmostEqual(b[1], 0.4)
        self.assertFalse(pipe["blocking"])


class AnalysisTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.layout = load_fixture()
        cls.view = wb.collect_room_view(cls.layout, "T1_A", TABLES)
        cls.analysis = wb.analyze_room(cls.view)

    def test_occupancy_ratio_sane(self):
        ratio = self.analysis["occupied_ratio"]
        self.assertGreater(ratio, 0.03)
        self.assertLess(ratio, 0.40)
        self.assertGreater(self.analysis["furnished_ratio"], ratio)

    def test_routes_reach_anchor(self):
        reachable = [r for r in self.analysis["routes"]
                     if r["to"] == "room_anchor" and r["reachable"]]
        self.assertTrue(reachable)
        for r in reachable:
            self.assertIsNotNone(r["min_passage_width"])
            self.assertGreater(r["min_passage_width"], 0.0)


class DetritusTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.layout = load_fixture()
        cls.view = wb.collect_room_view(cls.layout, "T1_A", TABLES)
        cls.analysis = wb.analyze_room(cls.view)
        cls.det = wb.detritus_zones(cls.view, cls.analysis)

    def test_zones_avoid_door_sweeps(self):
        sweeps = [d["sweep_rect"] for d in self.view["doors"]]
        for z in self.det["zones"]:
            for (i, j) in z["cells"]:
                x, y = self.analysis["grid"].cell_center(i, j)
                for s in sweeps:
                    self.assertFalse(
                        s[0] <= x <= s[2] and s[1] <= y <= s[3],
                        f"zone cell ({x:.2f},{y:.2f}) inside a door sweep")

    def test_each_zone_states_eligibility_and_protection(self):
        self.assertTrue(self.det["zones"])
        for z in self.det["zones"]:
            for c in z["categories"]:
                self.assertTrue(c["eligibility"])
            self.assertEqual(z["tier"], wb.HEURISTIC)

    def test_office_gets_swept_clean_not_resident_accumulation(self):
        cats = {c["category"] for z in self.det["zones"]
                for c in z["categories"]}
        self.assertIn("swept-clean", cats)
        self.assertNotIn("resident-specific personal accumulation", cats)


class DeterminismTests(unittest.TestCase):
    def test_emitted_files_are_byte_identical_across_runs(self):
        layout = load_fixture()
        with tempfile.TemporaryDirectory() as tmp:
            d1, d2 = Path(tmp) / "one", Path(tmp) / "two"
            d1.mkdir(), d2.mkdir()
            wb.emit_room(layout, "T1_A", d1, TABLES, detritus_on=True)
            wb.emit_room(layout, "T1_A", d2, TABLES, detritus_on=True)
            for name in ("T1_A.packet.json", "T1_A.packet.md", "T1_A.plan.html"):
                self.assertEqual((d1 / name).read_bytes(),
                                 (d2 / name).read_bytes(), name)

    def test_packet_json_sorted_and_loadable(self):
        layout = load_fixture()
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp)
            wb.emit_room(layout, "T1_B", out, TABLES)
            packet = json.loads((out / "T1_B.packet.json").read_text("utf-8"))
            self.assertEqual(packet["room"]["id"], "T1_B")
            self.assertIsNone(packet["objects"][0]["verdict"])
            ids = [o["id"] for o in packet["objects"]]
            cats = [o["category"] for o in packet["objects"]]
            self.assertEqual(list(zip(cats, ids)), sorted(zip(cats, ids)))

    def test_unresolved_facts_include_unknown_footprints(self):
        layout = load_fixture()
        view = wb.collect_room_view(layout, "T1_A", TABLES)
        packet = wb.build_packet(view, wb.analyze_room(view))
        joined = "\n".join(packet["unresolved"])
        self.assertIn("a_gizmo", joined)
        self.assertIn("radiator", joined)


class OverwriteSafetyTests(unittest.TestCase):
    def test_refuses_to_overwrite_without_force(self):
        layout = load_fixture()
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp)
            wb.emit_room(layout, "T1_A", out, TABLES)
            before = {p.name: p.read_bytes() for p in out.iterdir()}
            with self.assertRaises(FileExistsError):
                wb.emit_room(layout, "T1_A", out, TABLES)
            after = {p.name: p.read_bytes() for p in out.iterdir()}
            self.assertEqual(before, after)   # nothing touched

    def test_preflight_is_atomic_one_existing_file_blocks_all(self):
        layout = load_fixture()
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp)
            (out / "T1_A.plan.html").write_text("stale", encoding="utf-8")
            with self.assertRaises(FileExistsError):
                wb.emit_room(layout, "T1_A", out, TABLES)
            # The packet files were NOT partially written around the block.
            self.assertFalse((out / "T1_A.packet.json").exists())
            self.assertFalse((out / "T1_A.packet.md").exists())
            self.assertEqual((out / "T1_A.plan.html").read_text("utf-8"),
                             "stale")

    def test_force_overwrites_stale_files(self):
        layout = load_fixture()
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp)
            (out / "T1_A.packet.json").write_text("stale", encoding="utf-8")
            wb.emit_room(layout, "T1_A", out, TABLES, force=True)
            packet = json.loads((out / "T1_A.packet.json").read_text("utf-8"))
            self.assertEqual(packet["room"]["id"], "T1_A")

    def test_json_only_mode_ignores_unrelated_existing_html(self):
        layout = load_fixture()
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp)
            (out / "T1_A.plan.html").write_text("stale", encoding="utf-8")
            wb.emit_room(layout, "T1_A", out, TABLES, json_only=True)
            self.assertTrue((out / "T1_A.packet.json").exists())
            self.assertEqual((out / "T1_A.plan.html").read_text("utf-8"),
                             "stale")

    def test_cli_refusal_returns_exit_code_3(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp)
            (out / "T1_A.packet.md").write_text("stale", encoding="utf-8")
            code = wb.main(["--layout", str(FIXTURE), "--room", "T1_A",
                            "--output", str(out)])
            self.assertEqual(code, 3)
            self.assertFalse((out / "T1_A.packet.json").exists())
            code = wb.main(["--layout", str(FIXTURE), "--room", "T1_A",
                            "--output", str(out), "--force"])
            self.assertEqual(code, 0)
            self.assertTrue((out / "T1_A.packet.json").exists())


class CompareTests(unittest.TestCase):
    def test_moved_and_added_objects_reported(self):
        a = load_fixture()
        b = copy.deepcopy(a)
        for f in b["floors"][0]["furniture"]:
            if f["id"] == "a_chair_90":
                f["at"] = [3.4, 1.0]
        b["floors"][0]["furniture"].append(
            {"id": "a_new_box", "rect": [0.5, 0.5, 1.0, 1.0], "h": 0.5,
             "z0": 0.0, "mat": "crate"})
        report = wb.compare_room(a, b, "T1_A", TABLES)
        self.assertIn("MOVED   `a_chair_90`", report)
        self.assertIn("ADDED   `a_new_box`", report)

    def test_identical_layouts_report_no_differences(self):
        a = load_fixture()
        report = wb.compare_room(a, load_fixture(), "T1_B", TABLES)
        self.assertIn("no per-room differences", report)


class ProductionTableMirrorTests(unittest.TestCase):
    """The real gen_layout.py should still expose the mirrored tables.  If it
    stops doing so the workbench must degrade to `unknown`, not crash."""

    def test_tables_load_from_generator_source(self):
        tables = wb.load_footprint_tables()
        if not tables["ok"]:
            self.skipTest(f"generator tables unavailable: {tables['note']}")
        self.assertIn("chair", tables["asm_foot"])
        self.assertIn(False, tables["fridge_foot"])

    def test_missing_generator_degrades_gracefully(self):
        tables = wb.load_footprint_tables(Path("does_not_exist_gen.py"))
        self.assertFalse(tables["ok"])
        bb, note = wb.asm_aabb({"asm": "chair", "at": [0, 0]}, tables)
        self.assertIsNone(bb)


if __name__ == "__main__":
    unittest.main(verbosity=2)
