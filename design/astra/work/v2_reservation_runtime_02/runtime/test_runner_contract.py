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
        good = {"status": "EXACT_OWNED_SOURCES_RESTORED", "process_census": [], "restored_paths": list(expected),
            **{key:expected for key in ("hashes", "expected_hashes", "restoration_input_hashes", "observed_final_hashes")}}
        run.require_restoration(good, expected)
        for key, value in [("status", "FAILED"), ("process_census", [{"pid": 77}]), ("hashes", {"game/a.gd": "wrong"})]:
            bad = {**good, key: value}
            with self.subTest(key=key), self.assertRaises(ValueError): run.require_restoration(bad, expected)
        with self.assertRaises(ValueError): run.require_restoration({}, expected)

    def test_180_second_cap_is_exact_in_actual_and_all_requests(self):
        for phase in run.assess.PLAN["sequence"]:
            request = json.loads((run.BASE / phase["request"]).read_text())
            self.assertEqual(request["parameters"]["TimeoutSeconds"], 180)
            self.assertEqual(run.parameters_for(run.EVIDENCE / "runs" / phase["run_name"], run.assess.PLAN)["TimeoutSeconds"], 180)

    def test_owned_launcher_and_child_are_admitted(self):
        samples = [{"processes":[{"pid":2,"parent_pid":1,"executable":"launcher.exe"},
            {"pid":3,"parent_pid":2,"executable":run.core.ENGINE_NAME}]}]
        result = run.classify_lane(samples, 3, 1)
        self.assertTrue(result["actual_child_ancestry_verified"])
        self.assertEqual(result["owned_pids"], [2,3])
        self.assertEqual(result["lane_contract_exit"], 0)

    def test_foreign_engine_that_disappears_still_blocks_progression(self):
        owned = {"pid":3,"parent_pid":1,"executable":run.core.ENGINE_NAME}
        foreign = {"pid":7,"parent_pid":99,"executable":run.core.ENGINE_NAME}
        samples = [{"processes":[owned,foreign]}, {"processes":[owned]}, {"processes":[]}]
        result = run.classify_lane(samples, 3, 1)
        self.assertTrue(result["actual_child_ancestry_verified"])
        self.assertEqual(result["foreign_processes"], [foreign])
        self.assertEqual(result["lane_contract_exit"], 1)

    def transition_control(self, fault):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder); evidence = root / "evidence"; evidence.mkdir()
            desired, backups, pre = {}, {}, {}
            for index, rel in enumerate(run.OWNERS):
                live = root / rel; live.parent.mkdir(parents=True, exist_ok=True); live.write_bytes(f"old{index}".encode())
                pre[rel] = run.sha(live)
                backup = root / "backup" / rel; backup.parent.mkdir(parents=True, exist_ok=True); backup.write_bytes(live.read_bytes()); backups[rel] = backup
                candidate = root / "candidate" / rel; candidate.parent.mkdir(parents=True, exist_ok=True); candidate.write_bytes(f"candidate{index}".encode()); desired[rel] = candidate
            expected_candidate = {rel:run.sha(path) for rel,path in desired.items()}
            original_copy = run.atomic_owner_copy; calls = []
            def copy_owner(source, target):
                calls.append((source,target))
                if fault == "second_copy" and len(calls) == 2: raise OSError("injected second copy failure")
                if fault == "restore_write" and len(calls) == 3: raise OSError("injected restoration write failure")
                original_copy(source,target)
                if fault == "restore_hash" and len(calls) == 3: target.write_bytes(b"unexpected restored bytes")
            def action():
                if fault == "foreign_edit": (root/run.OWNERS[0]).write_bytes(b"foreign edit: preserve")
                return 0 if fault == "success" else 1
            if fault == "backup": backups[run.OWNERS[0]].write_bytes(b"corrupt backup")
            census = [[],[{"pid":909}]] if fault == "active" else [[],[]]
            with patch.object(run,"ROOT",root), patch.object(run,"EVIDENCE",evidence), patch.object(run,"atomic_owner_copy",side_effect=copy_owner), patch.object(run.core,"godot_processes",side_effect=census):
                if fault == "success":
                    self.assertEqual(run.transition_and_run("fixture",desired,pre,("01_candidate",desired,expected_candidate),("preinstall",backups,pre),action),0)
                else:
                    with self.assertRaises((ValueError,OSError)):
                        run.transition_and_run("fixture",desired,pre,("01_candidate",desired,expected_candidate),("preinstall",backups,pre),action)
            receipt = json.loads((evidence/"fixture.restoration.json").read_text())
            if fault in ("success","second_copy"):
                expected = expected_candidate if fault == "success" else pre
                run.require_restoration(receipt,expected)
                self.assertEqual({rel:run.sha(root/rel) for rel in run.OWNERS},expected)
            else:
                self.assertNotEqual(receipt["status"],"EXACT_OWNED_SOURCES_RESTORED")
                self.assertIn("restoration_failure",receipt)
            if fault == "second_copy": self.assertEqual(len(receipt["copied_paths"]),1)
            if fault == "foreign_edit": self.assertEqual((root/run.OWNERS[0]).read_bytes(),b"foreign edit: preserve")
            if fault == "active": self.assertEqual(receipt["status"],"RESTORATION_REFUSED_ACTIVE_PROCESS")

    def test_success_restores_exact_candidate_and_receipt(self): self.transition_control("success")
    def test_second_copy_failure_restores_both_originals_and_retains_receipt(self): self.transition_control("second_copy")
    def test_foreign_owned_edit_is_preserved_with_refusal_receipt(self): self.transition_control("foreign_edit")
    def test_corrupt_preinstall_backup_is_rejected_with_receipt(self): self.transition_control("backup")
    def test_restoration_write_failure_retains_receipt(self): self.transition_control("restore_write")
    def test_restoration_hash_failure_retains_receipt(self): self.transition_control("restore_hash")
    def test_active_process_refuses_restoration_with_receipt(self): self.transition_control("active")

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
