"""Companion admission checks; sealed selective-red gate remains byte-identical."""
from collections import Counter
import re
import gate


def assess(probe, stdout, stderr, runner_text, actual_exit, stable, pid_ok, engine_ok, mode):
    reasons = []
    condition = {73: "lane_refusal", 78: "cannot_run", 124: "timeout_termination"}.get(actual_exit)
    for marker, label in (("LANE BUSY:", "lane_refusal"), ("CANNOT RUN:", "cannot_run"), ("TIMEOUT:", "timeout_termination")):
        if marker in runner_text:
            condition = label
    if condition: reasons.append(condition)
    if not pid_ok: reasons.append("actual_child_engine_not_observed")
    if not engine_ok: reasons.append("engine_identity_not_bound")
    if not stable: reasons.append("source_engine_or_instruments_changed")
    raw = stdout + "\n" + stderr
    valid = isinstance(probe, dict) and type(probe.get("checks")) is int and type(probe.get("failures")) is int \
        and isinstance(probe.get("results"), list) and isinstance(probe.get("comparisons"), list) \
        and all(isinstance(row, dict) and type(row.get("ok")) is bool
                and isinstance(row.get("context"), str) and isinstance(row.get("label"), str) for row in probe.get("results", [])) \
        and all(isinstance(row, dict) and type(row.get("equal")) is bool
                and type(row.get("reverse_order")) is bool and isinstance(row.get("phase"), str)
                and isinstance(row.get("baseline"), dict) and isinstance(row.get("selected"), dict)
                for row in probe.get("comparisons", []))
    verdict = None
    if not valid:
        reasons.append("missing_or_malformed_readable_scene_receipt")
    else:
        if probe.get("variant") != mode: reasons.append("selected_variant_mismatch")
        # stdout/stderr are separate files: preserve exact order within each stream.
        for passed, stream in ((True, stdout), (False, stderr)):
            tag = "[SWEEP PASS] " if passed else "[SWEEP FAIL] "
            expected = [tag + row["context"] + " " + row["label"] for row in probe["results"] if row["ok"] == passed]
            observed = [line for line in stream.splitlines() if line.startswith(tag)]
            if observed != expected: reasons.append("raw_assertions_disagree_with_receipt_" + str(passed))
        if "[SWEEP FAIL] " in stdout or "[SWEEP PASS] " in stderr:
            reasons.append("assertions_in_unexpected_stream")
        if Counter(gate.FOOTER.findall(raw)) != Counter(gate.FOOTER.findall(stdout)):
            reasons.append("footer_in_wrong_stream")
        if probe.get("variant") in ("candidate", "priority", "drop_late"):
            try:
                verdict = gate.classify(probe, raw, actual_exit, stable)
                reasons.extend(verdict["reasons"])
            except (TypeError, ValueError, KeyError, AssertionError):
                reasons.append("malformed_contract_payload")
        else:
            reasons.append("undeclared_variant")
    # No header allowlist: headless focused evidence has no reviewed warning exception.
    if re.search(r"(?im)^\s*(?:SCRIPT ERROR:|ERROR:|WARNING:|ERROR |FATAL:)|parse error|RID allocations|Unreferenced static string|access violation|crash handler|still in use at exit|leaked", raw):
        reasons.append("strict_native_diagnostic")
    accepted = not reasons and verdict is not None and (
        verdict["clean_equivalence"] if mode == "candidate" else verdict["expected_selective_red_observed"])
    completed = valid and probe.get("variant") == mode and probe["checks"] == 171 \
        and [(row["context"], row["label"]) for row in probe["results"]] == gate.expected_rows(mode) \
        and probe.get("retired") is True and len(gate.FOOTER.findall(raw)) == 1 and condition is None
    return {"actual_runner_exit": actual_exit, "runner_condition": condition,
            "completed_fixture_exit": actual_exit if completed else None,
            "diagnostic_gate_exit": 0 if accepted and mode == "candidate" else 1,
            "control_acceptance_exit": int(not accepted), "reasons": sorted(set(reasons)), "sealed_gate": verdict}
