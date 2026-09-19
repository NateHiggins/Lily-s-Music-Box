"""Strict offline contracts for the prepared nav sequence; no engine launch."""
from __future__ import annotations
import hashlib
import json
from pathlib import Path
import re

from haunt_control import _diagnostics, warning_debt, STOPPED

HERE = Path(__file__).resolve().parent
CONTRACT = json.loads((HERE / "contracts.json").read_text(encoding="utf-8"))
MODES = {
    "direct": {"scene": "ResidentNavDirectSegmentTest", "test": "resident_nav_direct_segment_test",
               "prefix": "[RESIDENT DIRECT] ", "json": "resident_nav_direct_segment.json"},
    "haunt": {"scene": "ResidentF01HauntTest", "test": "resident_f01_haunt_test",
              "prefix": "[RESIDENT F01 HAUNT] ", "json": "resident_f01_haunt.json"},
    "waiting": {"scene": "ResidentLiftWaitingTest", "test": "resident_lift_waiting_test",
                "prefix": "[RESIDENT LIFT WAIT] ", "json": "resident_lift_waiting.json"},
    "passage": {"scene": "PassageNavTest", "test": "passage_nav_test", "prefix": "", "json": None},
}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def runner_condition(code, text, completed):
    for marker, name in [("LANE BUSY:", "lane_refusal"), ("TIMEOUT:", "timeout_termination"),
                         ("CANNOT RUN:", "cannot_run")]:
        if marker in text:
            return name
    if code in {73, 124, 78, 125}:
        return {73: "lane_refusal", 124: "timeout_termination", 78: "cannot_run", 125: "bridge_refusal"}[code]
    if not completed:
        return "uncompleted_or_launch_refused"
    return None


def suite(mode, expected, scene, stdout):
    """Return exact structural completion independently of source/native exit."""
    errors = []
    if mode == "passage":
        found = re.findall(r"^  \[(ok|FAIL)\] (.+)$", stdout, re.M)
        rows = [{"label": label, "passed": status == "ok"} for status, label in found]
    else:
        if not isinstance(scene, dict) or not isinstance(scene.get("checks"), list):
            return {"complete": False, "errors": ["required readable JSON scene receipt absent"], "failed": []}
        rows = scene["checks"]
    if not rows or any(not isinstance(r, dict) or not isinstance(r.get("label"), str)
                       or type(r.get("passed")) is not bool for r in rows):
        return {"complete": False, "errors": ["malformed named checks"], "failed": []}
    labels = [r["label"] for r in rows]
    failed = [r["label"] for r in rows if not r["passed"]]
    key = "haunt_red_labels" if mode == "haunt" and expected != "green" else mode + "_labels"
    if mode == "haunt" and expected == "green": key = "haunt_green_labels"
    if len(set(labels)) != len(labels) or labels != CONTRACT[key]:
        errors.append("missing, duplicate, reordered or extra named checks")
    if mode == "passage":
        summaries = [line for line in stdout.splitlines() if line.startswith("[PASSAGE NAV] RESULT:")]
        wanted = "[PASSAGE NAV] RESULT: %s (%d failures)" % ("FAIL" if failed else "PASS", len(failed))
    else:
        prefix = MODES[mode]["prefix"]
        raw = [line for line in stdout.splitlines() if line.startswith((prefix + "PASS ", prefix + "FAIL "))]
        wanted_raw = [prefix + ("PASS " if r["passed"] else "FAIL ") + r["label"] for r in rows]
        if raw != wanted_raw: errors.append("raw assertion order/content differs from JSON")
        if type(scene.get("failures")) is not int or scene["failures"] != len(failed):
            errors.append("JSON count differs from named failures")
        if mode == "direct":
            summaries = [line for line in stdout.splitlines() if line.startswith(prefix) and re.match(r"\d+/", line[len(prefix):])]
            wanted = prefix + "%d/%d passed" % (len(rows) - len(failed), len(rows))
        else:
            summaries = [line for line in stdout.splitlines() if line.startswith(prefix + "RESULT ")]
            wanted = prefix + "RESULT %d passed, %d failed" % (len(rows) - len(failed), len(failed))
        required = "navigation does not retain retired World3D" if mode == "direct" else "actual V1 root retired"
        # The waiting fixture's exact historical labels own its retirement scope.
        if mode != "waiting" and not any(r["label"] == required and r["passed"] for r in rows):
            errors.append("required actual world/root retirement absent or false")
        if mode == "haunt" and ((expected == "green" and scene.get("stopped"))
                                or (expected != "green" and scene.get("stopped") != STOPPED)):
            errors.append("lifecycle stop/completion scope is inconsistent")
    if summaries != [wanted]: errors.append("missing, repeated or inconsistent completion footer")
    return {"complete": not errors, "errors": errors, "failed": failed, "checks": len(rows)}


def assess(mode, expected, scene, stdout, stderr, runner_text, code, stable, pid_ok, engine_ok):
    structure = suite(mode, expected, scene, stdout)
    reasons = list(structure["errors"])
    condition = runner_condition(code, runner_text, structure["complete"])
    if condition: reasons.append("runner condition: " + condition)
    if not stable: reasons.append("source/engine/instrument changed")
    if not pid_ok: reasons.append("actual child-engine PID ancestry unproved")
    if not engine_ok: reasons.append("installed engine / Vulkan Forward+ identity absent")
    diagnostic_reasons = []
    # Independently parse all raw headers; counters are not accepted as a substitute.
    _diagnostics({"diagnostic_gate": {"light_unpair_count": 0, "softshadow_underflow_count": 0,
                  "retention": [], "non_inherited_errors": {}}}, stdout, stderr, "run", diagnostic_reasons)
    reasons.extend(diagnostic_reasons)
    failed = structure["failed"]
    declared = [] if expected == "green" else CONTRACT[{
        "old_direct": "direct_old_failed", "nav_omission": "nav_omission_failed",
        "coordinate_omission": "coordinate_omission_failed"}[expected]]
    expected_native = len(declared) if mode == "direct" else (1 if declared else 0)
    if set(failed) != set(declared) or len(failed) != len(declared):
        reasons.append("functional failures differ from declared exact control")
    if code != expected_native: reasons.append("runner/completed-scene exit differs from declared control")
    return {"expected": expected, "structure": structure, "runner_condition": condition,
            "completed_fixture_exit": code if structure["complete"] and condition is None and pid_ok else None,
            "diagnostic_gate_exit": int(bool(reasons) or code != 0 or bool(failed)),
            "control_acceptance_exit": int(bool(reasons)), "reasons": reasons,
            "known_warning_debt": warning_debt(stdout, stderr),
            "native_error_scope": "Expected reds retain nonzero diagnostic exit; only their exact declared control can be admissible."}


def verify_artifacts(folder):
    folder = Path(folder)
    result = json.loads((folder / "result.json").read_text(encoding="utf-8"))
    artifacts = result.get("artifacts")
    if not isinstance(artifacts, dict): raise ValueError("artifact map missing")
    required = {"godot.stdout.log", "godot.stdout.log.stderr", "runner.stdout.log", "runner.stderr.log",
                "before.all_game_files.json", "after.all_game_files.json", "before.runtime_inputs.json",
                "after.runtime_inputs.json", "invocation.json", "command.json", "process_observations.json"}
    scene_name = MODES[result["mode"]]["json"]
    if scene_name: required.add("shots/" + scene_name)
    if not required.issubset(artifacts): raise ValueError("consumed artifact binding omitted")
    for name, fingerprint in artifacts.items():
        p = Path(name)
        if p.is_absolute() or ".." in p.parts or ":" in name: raise ValueError("unsafe artifact path")
        if not (folder / p).is_file() or sha(folder / p) != fingerprint:
            raise ValueError("artifact changed: " + name)
    for label in ["before", "after"]:
        rows = json.loads((folder / (label + ".all_game_files.json")).read_text(encoding="utf-8"))
        runtime = json.loads((folder / (label + ".runtime_inputs.json")).read_text(encoding="utf-8"))
        if rows != sorted(rows) or len(dict(rows)) != len(rows): raise ValueError("noncanonical source manifest")
        expected_runtime = [[p, digest] for p, digest in rows if p == "game/project.godot"
            or p.startswith("game/scripts/") and p.endswith(".gd")
            or p.startswith("game/scenes/") and p.endswith((".tscn", ".tres"))
            or p.startswith("game/data/") and p.endswith(".json")]
        if runtime != expected_runtime: raise ValueError("runtime source coverage differs from full source census")
        if result[label].get("instruments") != result["instrument_binding"]:
            raise ValueError("instrument source binding changed")
        if result[label].get("engine_binaries") != result["before"].get("engine_binaries") or len(result[label].get("engine_binaries", [])) != 2:
            raise ValueError("engine binding changed or missing")
        digest = hashlib.sha256(json.dumps(rows, separators=(",", ":"), ensure_ascii=True).encode()).hexdigest()
        if digest != result[label]["all_game_files_sha256"]: raise ValueError("source digest mismatch")
        digest = hashlib.sha256(json.dumps(runtime, separators=(",", ":"), ensure_ascii=True).encode()).hexdigest()
        if digest != result[label]["runtime_inputs_sha256"]: raise ValueError("runtime digest mismatch")
        for relative, fingerprint in runtime:
            artifact = label + "/source/" + relative
            if artifacts.get(artifact) != fingerprint: raise ValueError("raw runtime source missing or inconsistent")
    for name, fingerprint in result["instrument_binding"].items():
        if artifacts.get("instruments/" + name) != fingerprint:
            raise ValueError("instrument copy absent or inconsistent")
    observations = json.loads((folder / "process_observations.json").read_text(encoding="utf-8"))
    # Recompute the observed ancestry rather than trusting its result boolean.
    from run_case import child_engine_seen
    if result.get("pid_ancestry_verified") != child_engine_seen(observations, result["runner_pid"]):
        raise ValueError("PID ancestry claim differs from bound observation")
    stdout = (folder / "godot.stdout.log").read_text(encoding="utf-8-sig")
    from support import parser_module
    engine_seen = parser_module.EXPECTED_ENGINE in stdout and "Vulkan " in stdout and "Forward+" in stdout
    if result.get("engine_identity_verified") != engine_seen:
        raise ValueError("engine identity claim differs from raw stdout")
    return result
