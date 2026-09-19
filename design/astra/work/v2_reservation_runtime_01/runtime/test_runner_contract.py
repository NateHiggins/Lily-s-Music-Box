"""Non-engine controls for exact requests, restoration and raw artifact admission."""
from pathlib import Path
from unittest.mock import patch
import copy
import json
import tempfile
import unittest
import run


class RunnerControls(unittest.TestCase):
    def test_capture_binding_uses_reviewed_candidate_and_existing_fixture(self):
        binding = json.loads((run.BASE / "capture_binding.json").read_text())
        for rel in run.OWNERS:
            self.assertEqual(binding["expected_sources_sha256"][rel],run.sha(run.BASE / "proposed" / rel))
        self.assertEqual(binding["fixture_candidate_sha256"],run.sha(run.ROOT / binding["fixture_source"]))
        self.assertEqual(binding["expected_camera_origin"],[-9.9,11.01,1.25])
        self.assertEqual(binding["expected_checks"],21)
        self.assertEqual(binding["requires_completed_phase"],"04_terminal_regression")

    def test_all_four_requests_match_actual_windowed_parameters(self):
        plan = run.assess.PLAN
        for phase in plan["sequence"]:
            with self.subTest(phase=phase["run_name"]):
                request = json.loads((run.BASE / phase["request"]).read_text())
                run.require_prepared_request(request, run.EVIDENCE / "runs" / phase["run_name"], plan)

    def test_old_paths_headless_and_array_damage_refuse(self):
        plan = run.assess.PLAN
        out = run.EVIDENCE / "runs" / "01_candidate"
        good = {"runner": str(run.core.RUNNER), "parameters": run.parameters_for(out, plan)}
        for key, value in [("ShotDir", str(out / "frames")), ("LogPath", str(out / "stdout.log")), ("Windowed", False), ("ExtraArgs", "--verbose")]:
            bad = copy.deepcopy(good); bad["parameters"][key] = value
            with self.subTest(key=key), self.assertRaises(ValueError): run.require_prepared_request(bad, out, plan)

    def test_failed_missing_and_active_process_restoration_refuse(self):
        expected = {"game/a.gd": "abcd"}
        good = {"status": "EXACT_OWNED_SOURCES_RESTORED", "process_census": [], "hashes": expected}
        run.require_restoration(good, expected)
        for key, value in [("status", "FAILED"), ("process_census", [{"pid": 77}]), ("hashes", {"game/a.gd": "wrong"})]:
            bad = {**good, key: value}
            with self.subTest(key=key), self.assertRaises(ValueError): run.require_restoration(bad, expected)
        with self.assertRaises(ValueError): run.require_restoration({}, expected)

    def test_artifact_map_omission_and_mutated_log_refuse(self):
        with tempfile.TemporaryDirectory() as folder:
            out = Path(folder)
            required = {"godot.stdout.log", "godot.stdout.log.stderr", "runner.stdout.log", "runner.stderr.log", "shots/reservation_display.json", "command.json", "invocation.json", "run_config.json", "process_observations.json", "prelaunch_processes.json", "before.all_game_files.json", "after.all_game_files.json", "before.runtime_text.json", "after.runtime_text.json", "before.game.diff", "after.game.diff"}
            for relative in required:
                path = out / relative; path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("[]" if "files.json" in relative or "text.json" in relative else "fixture bytes", encoding="utf-8")
            snapshot = {"copied_sources": {}, "instruments": {}, "all_game_files_sha256": run.core.digest([]), "runtime_text_sha256": run.core.digest([])}
            receipt = {"phase": "synthetic", "before": copy.deepcopy(snapshot), "after": copy.deepcopy(snapshot), "artifacts": {relative: run.sha(out / relative) for relative in required}}
            with patch.object(run, "package", return_value=({}, {"production_bindings": {}, "install": {}})), patch.object(run, "owner_sources", return_value=({"receipt_name":"reservation_display.json"}, {})):
                run.verify_artifacts(out, receipt)
                damaged = copy.deepcopy(receipt); damaged["artifacts"].pop("godot.stdout.log")
                with self.assertRaises(ValueError): run.verify_artifacts(out, damaged)
                (out / "godot.stdout.log").write_text("mutated actual log", encoding="utf-8")
                with self.assertRaises(ValueError): run.verify_artifacts(out, receipt)


if __name__ == "__main__": unittest.main()
