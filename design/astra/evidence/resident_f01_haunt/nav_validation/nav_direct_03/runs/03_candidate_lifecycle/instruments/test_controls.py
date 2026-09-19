"""Offline structural, artifact and actual CmdletBinding bridge controls."""
import copy
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock

import assess
import run_case


def specimen(expected="green"):
    failed = set(assess.CONTRACT["direct_old_failed"] if expected == "old_direct" else [])
    rows = [{"label": label, "passed": label not in failed} for label in assess.CONTRACT["direct_labels"]]
    scene = {"checks": rows, "failures": len(failed)}
    raw = "\n".join("[RESIDENT DIRECT] " + ("PASS " if r["passed"] else "FAIL ") + r["label"] for r in rows)
    raw += "\n[RESIDENT DIRECT] %d/%d passed\n" % (len(rows) - len(failed), len(rows))
    return scene, raw


class Contracts(unittest.TestCase):
    def result(self, scene=None, stdout=None, **changes):
        default_scene, default_stdout = specimen()
        args = dict(mode="direct", expected="green", scene=scene if scene is not None else default_scene,
            stdout=stdout if stdout is not None else default_stdout, stderr="", runner_text="", code=0,
            stable=True, pid_ok=True, engine_ok=True)
        args.update(changes)
        return assess.assess(**args)

    def test_green_and_exact_original_red(self):
        self.assertEqual(self.result()["control_acceptance_exit"], 0)
        scene, raw = specimen("old_direct")
        red = self.result(scene, raw, expected="old_direct", code=8)
        self.assertEqual(red["control_acceptance_exit"], 0)
        self.assertEqual(red["diagnostic_gate_exit"], 1)

    def test_missing_readable_json_refused(self):
        self.assertFalse(assess.suite("direct", "green", None, specimen()[1])["complete"])

    def test_deleted_row_refused_even_with_matching_footer(self):
        scene, raw = specimen(); scene["checks"].pop()
        raw = "\n".join("[RESIDENT DIRECT] PASS " + r["label"] for r in scene["checks"]) + "\n[RESIDENT DIRECT] 32/32 passed\n"
        self.assertEqual(self.result(scene, raw)["control_acceptance_exit"], 1)

    def test_duplicate_and_reordered_rows_refused(self):
        scene, raw = specimen(); scene["checks"][1] = copy.deepcopy(scene["checks"][0])
        self.assertEqual(self.result(scene, raw)["control_acceptance_exit"], 1)
        scene, raw = specimen(); scene["checks"][1:3] = list(reversed(scene["checks"][1:3]))
        self.assertEqual(self.result(scene, raw)["control_acceptance_exit"], 1)

    def test_false_retirement_and_repeated_footer_refused(self):
        scene, raw = specimen()
        next(r for r in scene["checks"] if r["label"] == "navigation does not retain retired World3D")["passed"] = False
        self.assertEqual(self.result(scene, raw)["control_acceptance_exit"], 1)
        self.assertEqual(self.result(stdout=raw + "[RESIDENT DIRECT] 33/33 passed\n")["control_acceptance_exit"], 1)

    def test_unknown_error_warning_and_retention_refused(self):
        for stderr in ["ERROR: unrelated", "WARNING: unknown", "ObjectDB instances leaked at exit", "ERROR: geom->softshadow_count==0 - BUG!"]:
            self.assertEqual(self.result(stderr=stderr)["control_acceptance_exit"], 1)

    def test_exact_warning_kept_as_debt(self):
        stderr = "WARNING: Image format RGB8 not supported by hardware, converting to RGBA8.\n   at: _validate_texture_format (servers/rendering/renderer_rd/storage_rd/texture_storage.cpp:2855)\n"
        result = self.result(stderr=stderr)
        self.assertEqual(result["control_acceptance_exit"], 0)
        self.assertEqual(result["known_warning_debt"], {"known RGB8 conversion debt": 1})

    def test_source_pid_and_engine_refused_independently(self):
        for key in ["stable", "pid_ok", "engine_ok"]:
            self.assertEqual(self.result(**{key: False})["control_acceptance_exit"], 1)

    def test_timeout_and_lane_refusal_are_not_scene_exits(self):
        for code, condition in [(124, "timeout_termination"), (73, "lane_refusal"), (78, "cannot_run")]:
            result = self.result(code=code)
            self.assertEqual(result["runner_condition"], condition)
            self.assertIsNone(result["completed_fixture_exit"])
            self.assertEqual(result["control_acceptance_exit"], 1)


def artifact_fixture(folder):
    scene, raw = specimen()
    raw = run_case.support.parser_module.EXPECTED_ENGINE + "\nVulkan 1.4 Forward+\n" + raw
    paths = {"godot.stdout.log": raw, "godot.stdout.log.stderr": "", "runner.stdout.log": "", "runner.stderr.log": "",
             "invocation.json": "{}", "command.json": "[]", "shots/resident_nav_direct_segment.json": json.dumps(scene),
             "instruments/tool.py": "tool", "process_observations.json": json.dumps([{"processes": [
                 {"pid": 2, "parent_pid": 1, "executable": "Godot_v4.7.1-stable_win64_console.exe"},
                 {"pid": 3, "parent_pid": 2, "executable": "Godot_v4.7.1-stable_win64.exe"}]}])}
    for name, body in paths.items():
        p = folder / name; p.parent.mkdir(parents=True, exist_ok=True); p.write_text(body, encoding="utf-8")
    source_hash = __import__("hashlib").sha256(b"source").hexdigest()
    rows = [["game/scripts/a.gd", source_hash]]
    binding = {"tool.py": assess.sha(folder / "instruments/tool.py")}
    snapshot = {"all_game_files_sha256": run_case.support.digest(rows), "runtime_inputs_sha256": run_case.support.digest(rows),
                "instruments": binding, "engine_binaries": [{"sha256": "a"}, {"sha256": "b"}]}
    for label in ["before", "after"]:
        for kind in ["all_game_files", "runtime_inputs"]:
            (folder / (label + "." + kind + ".json")).write_text(json.dumps(rows), encoding="utf-8")
        p = folder / label / "source/game/scripts/a.gd"; p.parent.mkdir(parents=True); p.write_bytes(b"source")
    result = {"mode": "direct", "before": copy.deepcopy(snapshot), "after": copy.deepcopy(snapshot), "instrument_binding": binding,
              "runner_pid": 1, "pid_ancestry_verified": True, "engine_identity_verified": True,
              "artifacts": {p.relative_to(folder).as_posix(): assess.sha(p) for p in folder.rglob("*") if p.is_file()}}
    (folder / "result.json").write_text(json.dumps(result), encoding="utf-8")
    return result


class Artifacts(unittest.TestCase):
    def test_valid_then_omitted_consumed_binding_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            p = Path(temp); result = artifact_fixture(p); assess.verify_artifacts(p)
            del result["artifacts"]["godot.stdout.log.stderr"]
            (p / "result.json").write_text(json.dumps(result))
            with self.assertRaises(ValueError): assess.verify_artifacts(p)

    def test_changed_log_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            p = Path(temp); artifact_fixture(p); (p / "godot.stdout.log").write_text("changed")
            with self.assertRaises(ValueError): assess.verify_artifacts(p)

    def test_changed_source_rejected_even_with_rebound_artifact(self):
        with tempfile.TemporaryDirectory() as temp:
            p = Path(temp); result = artifact_fixture(p)
            source = "before/source/game/scripts/a.gd"; (p / source).write_text("changed")
            result["artifacts"][source] = assess.sha(p / source)
            (p / "result.json").write_text(json.dumps(result))
            with self.assertRaises(ValueError): assess.verify_artifacts(p)

    def test_false_pid_and_changed_engine_rejected(self):
        for change in ["pid", "engine"]:
            with tempfile.TemporaryDirectory() as temp:
                p = Path(temp); result = artifact_fixture(p)
                if change == "pid": result["pid_ancestry_verified"] = False
                else: result["after"]["engine_binaries"][0]["sha256"] = "changed"
                (p / "result.json").write_text(json.dumps(result))
                with self.assertRaises(ValueError): assess.verify_artifacts(p)


class Restoration(unittest.TestCase):
    def exercise(self, foreign_edit):
        import execute
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp); live = root / execute.NAV
            live.parent.mkdir(parents=True); candidate = execute.input_bytes("nav_candidate.gd")
            live.write_bytes(candidate)
            evidence = root / "evidence"; (evidence / "stub").mkdir(parents=True)
            def interrupted(*args, **kwargs):
                if foreign_edit: live.write_bytes(b"foreign owner edit")
                raise RuntimeError("synthetic run interruption; no Godot invoked")
            with mock.patch.object(execute, "ROOT", root), mock.patch.object(run_case, "EVIDENCE", evidence), \
                 mock.patch.object(run_case, "package_check", return_value={}), \
                 mock.patch.object(execute, "require_phase"), mock.patch.object(execute, "check_live"), \
                 mock.patch.object(execute, "run_one", side_effect=interrupted):
                with self.assertRaises((RuntimeError, ValueError)):
                    execute.execute("nav-control", "stub")
            record = json.loads((evidence / "stub/nav-control.json").read_text())
            self.assertEqual(record["status"], "STOPPED_REVIEW_REQUIRED")
            if foreign_edit:
                self.assertFalse(record["restoration"]["exact_bytes_restored"])
                self.assertEqual(live.read_bytes(), b"foreign owner edit")
            else:
                self.assertTrue(record["restoration"]["exact_bytes_restored"])
                self.assertEqual(live.read_bytes(), candidate)

    def test_interrupted_omission_restores_exact_candidate(self):
        self.exercise(False)

    def test_foreign_change_refuses_false_restore(self):
        self.exercise(True)


class Bridge(unittest.TestCase):
    def invoke(self, body):
        with tempfile.TemporaryDirectory() as temp:
            p = Path(temp); script = p / "cmdlet_stub.ps1"
            script.write_text("[CmdletBinding()]\nparam([string[]]$ExtraArgs)\n" + body, encoding="utf-8")
            (p / "invocation.json").write_text(json.dumps({"runner": str(script), "parameters": {"ExtraArgs": ["--verbose", "--audio-driver", "Dummy"]}}))
            return subprocess.run([str(run_case.PWSH), "-NoProfile", "-File", str(run_case.BRIDGE),
                                   "-InvocationPath", str(p / "invocation.json")], capture_output=True, timeout=15)

    def test_cmdlet_array_arguments_preserved(self):
        result = self.invoke("if (($ExtraArgs -join '|') -ne '--verbose|--audio-driver|Dummy') {exit 9}; exit 0")
        self.assertEqual(result.returncode, 0)

    def test_write_error_timeout_preserved(self):
        result = self.invoke("Write-Error 'retained stub timeout'; exit 124")
        self.assertEqual(result.returncode, 124)
        self.assertIn(b"retained stub timeout", result.stderr)

    def test_absent_exit_refused(self):
        result = self.invoke("Write-Output 'no exit supplied'")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(b"no process exit code", result.stderr)


if __name__ == "__main__": unittest.main(verbosity=2)
