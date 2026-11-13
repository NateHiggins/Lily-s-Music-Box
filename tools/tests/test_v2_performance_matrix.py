"""The V2 performance matrix judges honestly and fails closed."""
from pathlib import Path
import copy
import json
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
import v2_performance_matrix as matrix  # noqa: E402


def station(name: str, median: float = 9.0, p95: float = 12.0) -> dict:
    heading = {"yaw_degrees": 0.0, "frames": 120, "wall_ms_median": median, "wall_ms_p95": p95,
               "wall_ms_max": p95 + 3.0, "render_cpu_ms_median": 2.0, "render_gpu_ms_median": 5.0,
               "draw_calls": 2400, "primitives": 900000, "objects": 3000}
    return {"name": name, "valid": True, "frame": "building", "position": [0, 0, 0], "drift_m": 0.02,
            "room": "ROOM", "passage_residency": "DORMANT", "worst_heading": heading,
            "headings": [heading], "memory": {"video_bytes": 3_000_000_000}}


def samples() -> dict:
    return {"schema": matrix.SAMPLES_SCHEMA, "display_server": "windows", "vsync": False,
            "resolution": [1920, 1080], "failures": [],
            "startup": {"startup_ms": 21000.0, "startup_wall_ms": 21500.0},
            "stations": [station(name) for name in matrix.REQUIRED_STATIONS]}


def run_receipt() -> dict:
    return {"scene": "res://tests/V2PerformanceMatrix.tscn", "runner": "long", "windowed": True,
            "execution": {"exit_code": 0, "completed": True, "timed_out": False, "elapsed_s": 200.0},
            "source": {"repository_head": "a" * 40, "repository_tree": "b" * 40, "dirty_paths": 0}}


class Judge(unittest.TestCase):
    def test_a_measurement_within_budget_has_no_defects(self):
        verdict = matrix.judge(samples())
        self.assertEqual(verdict["defects"], [])
        self.assertEqual(len(verdict["rows"]), len(matrix.REQUIRED_STATIONS))
        self.assertEqual(verdict["worst"]["frame_ms_median"], 9.0)

    def test_a_station_over_the_frame_budget_is_a_defect(self):
        data = samples()
        data["stations"][1] = station(matrix.REQUIRED_STATIONS[1], median=36.4, p95=44.0)
        verdict = matrix.judge(data)
        self.assertEqual(len(verdict["defects"]), 1)
        self.assertIn("over budget: " + matrix.REQUIRED_STATIONS[1], verdict["defects"][0])
        self.assertTrue([row for row in verdict["rows"] if row["over_budget"]])

    def test_an_unruled_mark_is_a_note_and_never_a_defect(self):
        data = samples()
        data["stations"][0] = station(matrix.REQUIRED_STATIONS[0], median=12.0, p95=60.0)
        verdict = matrix.judge(data)
        self.assertEqual(verdict["defects"], [])
        self.assertEqual(len(verdict["notes"]), 1)

    def test_the_ruled_budget_is_thirty_and_sixty_is_only_noted(self):
        self.assertEqual(matrix.BUDGETS["frame_ms_median"]["limit"], 33.3)
        self.assertIn("v2_frame_target_20261113", matrix.BUDGETS["frame_ms_median"]["source"])
        data = samples()
        data["stations"][0] = station(matrix.REQUIRED_STATIONS[0], median=24.0, p95=30.0)
        verdict = matrix.judge(data)
        self.assertEqual(verdict["defects"], [])
        self.assertIn("short of the later target", verdict["notes"][0])

    def test_what_cannot_be_trusted_fails_closed(self):
        cases = {
            "headless": lambda d: d.update(display_server="headless"),
            "vsync": lambda d: d.update(vsync=True),
            "missing station": lambda d: d["stations"].pop(),
            "invalid station": lambda d: d["stations"][0].update(valid=False),
            "few frames": lambda d: d["stations"][0]["worst_heading"].update(frames=10),
            "drifted": lambda d: d["stations"][0].update(drift_m=4.0),
            "test failure": lambda d: d["failures"].append("the V2 world did not start"),
            "no startup": lambda d: d["startup"].update(startup_ms=0.0),
            "schema": lambda d: d.update(schema="something else"),
        }
        for label, damage in cases.items():
            with self.subTest(label):
                data = copy.deepcopy(samples())
                damage(data)
                self.assertTrue(matrix.judge(data)["defects"], label)


CLEAN = {"head": "a" * 40, "content_changed": [], "untracked_game_paths": []}


class Receipt(unittest.TestCase):
    def write(self, folder: Path, data: dict, run: dict, checkout: dict | None = None) -> Path:
        (folder / "samples.json").write_text(json.dumps(data), encoding="utf-8")
        (folder / "run.json").write_text(json.dumps(run), encoding="utf-8")
        out = folder / "receipt.json"
        with patch.object(matrix, "checkout_facts", return_value=checkout or CLEAN):
            self.code = matrix.admit(folder / "samples.json", folder / "run.json", out, folder)
        return out

    def test_admit_then_check_agree(self):
        with tempfile.TemporaryDirectory() as temp:
            out = self.write(Path(temp), samples(), run_receipt())
            self.assertEqual(self.code, 0)
            receipt = json.loads(out.read_text(encoding="utf-8"))
            self.assertEqual(receipt["result"], "PASS")
            self.assertEqual(receipt["commit"], "a" * 40)
            self.assertNotIn("computer_name", json.dumps(receipt))
            self.assertEqual(matrix.check(out, True), 0)

    def test_a_checkout_that_is_not_its_commit_is_not_admitted_clean(self):
        for label, checkout in {
            "changed": dict(CLEAN, content_changed=["game/scripts/a.gd"]),
            "untracked": dict(CLEAN, untracked_game_paths=["game/scripts/b.gd"]),
            "another commit": dict(CLEAN, head="c" * 40),
        }.items():
            with self.subTest(label), tempfile.TemporaryDirectory() as temp:
                out = self.write(Path(temp), samples(), run_receipt(), checkout)
                self.assertEqual(self.code, 1)
                self.assertEqual(matrix.check(out, True), 1)

    def test_an_unexamined_checkout_is_a_defect(self):
        with tempfile.TemporaryDirectory() as temp:
            folder = Path(temp)
            (folder / "samples.json").write_text(json.dumps(samples()), encoding="utf-8")
            (folder / "run.json").write_text(json.dumps(run_receipt()), encoding="utf-8")
            self.assertEqual(matrix.admit(folder / "samples.json", folder / "run.json", folder / "r.json"), 1)

    def test_line_ending_noise_in_the_lane_count_does_not_fail_a_clean_checkout(self):
        with tempfile.TemporaryDirectory() as temp:
            run = run_receipt()
            run["source"]["dirty_paths"] = 2000
            self.write(Path(temp), samples(), run)
            self.assertEqual(self.code, 0)

    def test_a_failed_run_is_not_admitted_clean(self):
        for label, damage in {
            "failed": lambda r: r["execution"].update(exit_code=1),
            "timed out": lambda r: r["execution"].update(timed_out=True),
            "another scene": lambda r: r.update(scene="res://tests/Other.tscn"),
        }.items():
            with self.subTest(label), tempfile.TemporaryDirectory() as temp:
                run = run_receipt()
                damage(run)
                out = self.write(Path(temp), samples(), run)
                self.assertEqual(self.code, 1)
                self.assertEqual(matrix.check(out, True), 1)

    def test_no_receipt_is_incomplete_not_a_pass(self):
        with tempfile.TemporaryDirectory() as temp:
            self.assertEqual(matrix.check(Path(temp) / "absent.json", True), 2)

    def test_the_station_table_in_the_test_covers_the_required_set(self):
        source = (ROOT / "game/tests/v2_performance_matrix.gd").read_text(encoding="utf-8")
        for name in matrix.REQUIRED_STATIONS:
            self.assertIn('"name": "%s"' % name, source)


if __name__ == "__main__":
    unittest.main()
