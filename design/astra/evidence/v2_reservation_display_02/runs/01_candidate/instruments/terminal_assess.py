"""Terminal receipt contract; known native debt is bounded by preserved raw pairs."""
from pathlib import Path
from collections import Counter
import json
import math
import re

HERE = Path(__file__).resolve().parent
PLAN = json.loads((HERE.parent / "preparation.json").read_text(encoding="utf-8"))
KNOWN = json.loads((HERE / "known_diagnostics.json").read_text(encoding="utf-8"))
PREFIX = "[V2 TERMINAL ACCESS]"


def finite_vec(value):
    if not isinstance(value, list) or len(value) != 3 or any(type(v) not in (int, float) or not math.isfinite(v) for v in value):
        raise ValueError("invalid coordinate payload")
    return value


def close_vec(value, expected):
    return all(abs(a-b) <= 1e-4 for a,b in zip(finite_vec(value), expected))


def require_arrival_and_operator_origins(diag, flags):
    arrival = diag["arrival"]
    if not isinstance(arrival, dict): raise ValueError("missing arrival witness")
    curb = [-3.6, 0.1, 24.72]
    eye = [-3.6, 1.51, 24.72]
    if close_vec(arrival["before_position"], curb) or not close_vec(arrival["position"], curb) or not close_vec(arrival["camera_position"], eye):
        raise ValueError("actual deferred arrival transition not observed")
    for key in ("observed", "settled", "director_owns_world", "intro_complete"):
        if arrival[key] is not True: raise ValueError("arrival completion witness missing")
    if flags.get("deferred first-shift arrival settles before controlled placement") is not True:
        raise ValueError("arrival check failed")
    if type(arrival["waited_process_frames"]) is not int or not 1 <= arrival["waited_process_frames"] <= 120 or arrival["stable_process_frames"] != 2:
        raise ValueError("arrival wait not witnessed")
    if arrival["phase_before"] != "complete" or arrival["phase_after"] != "complete": raise ValueError("arrival changed seeded ritual")
    if not close_vec(arrival["velocity"], [0,0,0]) or not close_vec(arrival["camera_local_rotation"], [0,0,0]): raise ValueError("arrival pose incomplete")
    yaw = arrival["yaw"]
    if type(yaw) not in (int, float) or not math.isfinite(yaw) or abs(yaw - math.atan2(-3.6, 14.9)) > 1e-4: raise ValueError("arrival yaw differs")
    if arrival["noclip"] is not False or arrival["call_locked"] is not False or arrival["collision_layer"] != 1 or arrival["collision_mask"] != 1: raise ValueError("arrival actor flags differ")
    operator = [-9.9, 9.6, 1.25]
    operator_eye = [-9.9, 11.01, 1.25]
    if not close_vec(diag["operator_position"], operator): raise ValueError("operator anchor changed")
    for key, label in [("first_ray", "first ray starts from the authored operator and eye"), ("second_ray", "second ray starts from the authored operator and eye")]:
        ray = diag[key]
        if not close_vec(ray["from"], operator_eye) or not close_vec(ray["camera_position"], operator_eye) or not close_vec(ray["actor_position"], operator):
            raise ValueError(key + " origin is not the authored operator")
        if ray["physics_processing"] is not False or flags.get(label) is not True: raise ValueError("operator stance precondition failed")
        delta = [a-b for a,b in zip(finite_vec(ray["to"]), ray["from"])]
        toward = [a-b for a,b in zip(finite_vec(diag["scope_position"]), ray["from"])]
        length = math.sqrt(sum(v*v for v in delta)); distance = math.sqrt(sum(v*v for v in toward))
        if abs(length-2.1) > 1e-4 or distance == 0 or sum(a*b for a,b in zip(delta,toward))/(length*distance) < 0.9999:
            raise ValueError("actual ordinary ray range or aim differs")


def assess(probe, stdout, stderr, wrapper, native, source_ok, pid_ok, engine_ok, phase):
    spec = next(row for row in PLAN["sequence"] if row["run_name"] == phase)
    expected = spec["predicted_failure_labels_not_runtime_results"]
    reasons = []
    if not source_ok: reasons.append("source_binding_failed")
    if not pid_ok: reasons.append("actual_engine_pid_ancestry_missing")
    if not engine_ok: reasons.append("installed_engine_binding_failed")
    if native not in (0, 1): reasons.append("runner_refusal_timeout_or_unexpected_exit")
    if "Godot Engine v4.7.1.stable.official.a13da4feb" not in stdout or "Vulkan " not in stdout or "Forward+" not in stdout:
        reasons.append("actual_windowed_engine_identity_missing")
    debt, unknown, retention = [], [], []
    allowed_errors = {tuple(row) for row in KNOWN["errors"]}
    allowed_warnings = {tuple(row) for row in KNOWN["warnings"]}
    lines = (stdout + "\n" + stderr + "\n" + wrapper).splitlines()
    for i, line in enumerate(lines):
        if any(x in line for x in ("ObjectDB instances leaked", "resources still in use at exit", "Unreferenced static string")):
            retention.append(line)
        if not line.startswith(("ERROR:", "SCRIPT ERROR:", "WARNING:")): continue
        pair = (line, lines[i + 1].strip() if i + 1 < len(lines) else "")
        if pair in (allowed_warnings if line.startswith("WARNING:") else allowed_errors): debt.append(pair)
        else: unknown.append(pair)
    if unknown: reasons.append("unknown_native_diagnostic")
    if retention: reasons.append("retention_diagnostic")
    if not isinstance(probe, dict):
        reasons.append("missing_or_unreadable_probe")
        probe = {}
    rows = probe.get("checks", [])
    if not isinstance(rows, list) or any(not isinstance(row, dict) for row in rows):
        reasons.append("malformed_check_rows")
        rows = []
    labels = [row.get("label") for row in rows if isinstance(row, dict)]
    if labels != PLAN["full_unique_ordered_labels"] or len(rows) != 39 or len(set(labels)) != 39:
        reasons.append("exact_unique_39_label_contract_failed")
    if any(type(row.get("passed")) is not bool for row in rows if isinstance(row, dict)):
        reasons.append("non_boolean_check")
    failed = [row.get("label") for row in rows if isinstance(row, dict) and row.get("passed") is not True]
    if probe.get("schema") != "astra.v2-terminal-access.probe.v2" or probe.get("root") != "v2" or probe.get("renderer") != "forward_plus" or type(probe.get("pid")) is not int or probe.get("pid", 0) <= 0:
        reasons.append("probe_identity_invalid")
    if type(probe.get("failures")) is not int or probe.get("failures") != len(failed): reasons.append("failure_count_inconsistent")
    raw = re.findall(r"^\[V2 TERMINAL ACCESS\] (PASS|FAIL) (.+)$", stdout, re.M)
    wanted_raw = [("PASS" if row.get("passed") is True else "FAIL", row.get("label")) for row in rows if isinstance(row, dict)]
    if raw != wanted_raw: reasons.append("raw_check_rows_do_not_match_probe")
    if re.findall(r"^\[V2 TERMINAL ACCESS\] checks=(\d+) failures=(\d+)$", stdout, re.M) != [("39", str(len(failed)))]:
        reasons.append("completion_footer_missing_or_inconsistent")
    if len(rows) < 3 or any(row.get("passed") is not True for row in rows[-3:]): reasons.append("actual_retirement_or_acoustic_restore_failed")
    diag = probe.get("diagnostics", {})
    required = {"complete", "arrival", "operator_position", "scope_front", "operator_direction", "front_dot", "terminal_position", "terminal_basis", "semantic_position", "semantic_basis", "scope_position", "scope_basis", "desk_count", "call_count", "desk_size", "first_ray", "second_ray", "world_events", "case_open_delay_factor", "first_interact_action_dispatched", "seated_E_action_dispatched", "reentry_action_dispatched", "escape_key_dispatched", "scope"}
    if not isinstance(diag, dict) or not required.issubset(diag) or diag.get("complete") is not True:
        reasons.append("complete_input_geometry_payload_missing")
    else:
        flags = {row["label"]: row["passed"] for row in rows if isinstance(row, dict) and "label" in row and "passed" in row}
        try:
            require_arrival_and_operator_origins(diag, flags)
        except (TypeError, ValueError, KeyError, ZeroDivisionError):
            reasons.append("arrival_or_authored_operator_ray_origin_invalid")
        try:
            front, direction = diag["scope_front"], diag["operator_direction"]
            values = [*front, *direction, diag["front_dot"]]
            if len(front) != 3 or len(direction) != 3 or any(type(v) not in (int, float) or not math.isfinite(v) for v in values): raise ValueError()
            dot = sum(a*b for a,b in zip(front, direction)) / math.sqrt(sum(a*a for a in front)*sum(a*a for a in direction))
            if abs(dot - diag["front_dot"]) > 1e-5 or flags.get("actual scope front faces the operator") != (dot >= 0.99): raise ValueError()
            if flags.get("V2 owns exactly one actual DeskZone") != (diag["desk_count"] == 1): raise ValueError()
            for key, label in [("first_ray", "ordinary player ray acquires the actual desk Area"), ("second_ray", "standing player can reacquire the same physical desk")]:
                ray = diag[key]
                if not isinstance(ray, dict) or type(ray.get("target_is_desk")) is not bool or ray.get("hit_from_inside") is not False or flags.get(label) != ray["target_is_desk"]: raise ValueError()
            if diag["first_interact_action_dispatched"] is not True: raise ValueError()
        except (TypeError, ValueError, KeyError, ZeroDivisionError): reasons.append("payload_and_check_geometry_inconsistent")
    if failed != expected: reasons.append("failure_set_differs_from_exact_planned_variant")
    if native != spec["expected_native_exit"]: reasons.append("native_exit_differs_from_planned_variant")
    ordinary_red = bool(reasons or native != 0 or failed)
    return {"diagnostic_gate_exit": int(ordinary_red), "control_contract_exit": int(bool(reasons)),
        "ordinary_product_status": "FAILED" if ordinary_red else "PASSED_IN_FOCUSED_SCOPE",
        "reasons": reasons, "failed_labels": failed, "passed": len(rows)-len(failed), "total": len(rows),
        "known_diagnostic_debt": [{"header": pair[0], "detail": pair[1], "count": count} for pair,count in Counter(debt).items()],
        "unknown_diagnostics": unknown, "retention": retention,
        "negative_control_scope_only": bool(expected and not reasons)}
