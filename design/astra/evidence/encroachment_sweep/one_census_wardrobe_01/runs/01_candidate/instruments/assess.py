"""Exact producer receipt contract; native/diagnostic reds stay red."""
import json
from pathlib import Path
import re

CONTRACT = json.loads((Path(__file__).resolve().parents[1] / "expected_contract.json").read_text())
FOOTER = re.compile(r"^WARDROBE FLOOR ADMISSION: (PASS|FAIL) \((\d+)/(\d+)\)$", re.M)


def assess(probe, stdout, stderr, runner, code, stable, pid_ok, engine_ok, expected):
    reasons = []
    condition = {73: "lane_refusal", 78: "cannot_run", 124: "timeout_termination"}.get(code)
    if condition: reasons.append(condition)
    if not stable: reasons.append("source_changed")
    if not pid_ok or not engine_ok: reasons.append("engine_or_pid_binding_missing")
    raw = stdout + "\n" + stderr
    diagnostics = [line for line in raw.splitlines() if re.search(r"(?i)^\s*(?:SCRIPT ERROR:|ERROR:|WARNING:|FATAL:)|Parse Error|leaked|still in use at exit|RID allocations|Unreferenced static string|access violation|crash handler", line)]
    if diagnostics: reasons.append("native_diagnostic")
    if expected == "binding36":
        passed = re.findall(r"^\[BIND PASS\] (.+)$", stdout, re.M)
        failed = re.findall(r"^\[BIND FAIL\] (.+)$", raw, re.M)
        footer = re.findall(r"^APARTMENT MATERIAL BINDING: (PASS|FAIL) \((\d+)/(\d+)\)$", raw, re.M)
        if len(passed) != 36 or len(set(passed)) != 36 or failed or footer != [("PASS", "36", "36")]: reasons.append("existing_36_contract_failed")
        if code != 0: reasons.append("native_exit_mismatch")
        return {"diagnostic_gate_exit": int(bool(reasons)), "control_acceptance_exit": int(bool(reasons)), "reasons": reasons, "native_diagnostics": diagnostics, "runner_condition": condition, "completed_fixture_exit": code if footer == [("PASS", "36", "36")] and condition is None else None}
    valid = isinstance(probe, dict) and isinstance(probe.get("checks"), list) and type(probe.get("failures")) is int \
        and all(isinstance(row, dict) and isinstance(row.get("label"), str) and type(row.get("passed")) is bool for row in probe.get("checks", []))
    if not valid:
        reasons.append("missing_or_malformed_scene_receipt")
        return {"diagnostic_gate_exit": 1, "control_acceptance_exit": 1, "reasons": reasons, "native_diagnostics": diagnostics, "runner_condition": condition, "completed_fixture_exit": None}
    rows = probe["checks"]; labels = [row["label"] for row in rows]
    failed = [row["label"] for row in rows if not row["passed"]]
    if labels != CONTRACT["ordered_labels"]: reasons.append("exact_63_labels_changed_or_incomplete")
    if probe["failures"] != len(failed): reasons.append("failure_count_mismatch")
    lines = [line for line in stdout.splitlines() if line.startswith("[WARDROBE FLOOR] ")]
    expected_lines = ["[WARDROBE FLOOR] " + ("PASS " if row["passed"] else "FAIL ") + row["label"] for row in rows]
    if lines != expected_lines or "[WARDROBE FLOOR] " in stderr: reasons.append("raw_assertions_differ_from_receipt")
    expected_footer = ("PASS" if not failed else "FAIL", str(63 - len(failed)), "63")
    complete = FOOTER.findall(raw) == [expected_footer] and labels == CONTRACT["ordered_labels"]
    if not complete: reasons.append("footer_incomplete")
    if probe.get("retired") is not True or probe.get("callbacks") != 2: reasons.append("retirement_or_real_callbacks_incomplete")
    observations = probe.get("observations", [])
    if not isinstance(observations, list) or len(observations) != 2 or [row.get("phase") for row in observations] != ["normal", "queued"]:
        reasons.append("producer_phases_incomplete")
    else:
        for observation in observations:
            foreign = observation.get("foreign_rows", {})
            if set(foreign) != set(CONTRACT["expected_red_foreign_records"]): reasons.append("foreign_record_census_incomplete")
            for paths in foreign.values():
                if expected == "red":
                    if sorted(paths) != sorted(CONTRACT["expected_red_exact_foreign_leaf_paths"]): reasons.append("red_is_not_exact_four_leaf_admission")
                elif paths != []: reasons.append("candidate_has_foreign_floor_rows")
    if expected == "red":
        if code != 1: reasons.append("native_red_exit_mismatch")
        if not set(CONTRACT["expected_red_required_failed_labels"]).issubset(failed): reasons.append("required_original_admission_red_missing")
        if not set(failed).issubset(CONTRACT["expected_red_allowed_failed_labels"]): reasons.append("unrelated_functional_failure")
    elif code != 0 or failed: reasons.append("candidate_not_green")
    accepted = not reasons
    return {"diagnostic_gate_exit": 0 if accepted and expected == "green" else 1, "control_acceptance_exit": int(not accepted), "reasons": reasons, "native_diagnostics": diagnostics, "runner_condition": condition, "completed_fixture_exit": code if complete and condition is None else None, "passed": 63 - len(failed), "failures": len(failed), "failed_labels": failed}
