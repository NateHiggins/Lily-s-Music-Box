"""Strict functional contract. A selective red remains an engine/diagnostic red."""
from __future__ import annotations

import re
import json
from pathlib import Path

CONTRACT = json.loads(Path(__file__).with_name("expected_check_contract.json").read_text())


def expected_rows(mode):
    result = [("setup", "declared variant"), ("setup", "selected production copy loads")]
    for order in ("false", "true"):
        for label in ("baseline", mode):
            result.extend((f"{label}/reversed={order}", item) for item in CONTRACT["exercise_labels_in_order"])
        result.extend(("equivalence", f"{phase} order={order} installed graph") for phase in CONTRACT["phase_order"])
    result += [("scope", "material seam leaves persisted facts unchanged"),
               ("retirement", "all four specimen roots and owners are released"),
               ("receipt", "explicit receipt directory supplied"),
               ("receipt", "receipt directory available"), ("receipt", "receipt writable")]
    assert len(result) == CONTRACT["expected_check_count"] == 171
    return result

PRIORITY_FAILURES = {"overlap obeys authored priority"}
LATE_FAILURES = {
    "late and moved census membership count is ten",
    "new draw is discovered on the next sweep",
    "known metadata survives moved bounds and live sharing",
    "new case draws receive the same immediate state",
}
PHASES = {"initial", "repeated", "late_moved_replaced", "stain", "exchange", "detached"}
FOOTER = re.compile(r"^ENCROACHMENT SWEEP EQUIVALENCE: (PASS|FAIL) \((\d+)/(\d+)\)$", re.M)


def classify(probe: dict, combined: str, engine_exit: int, source_unchanged: bool) -> dict:
    reasons = []
    mode = probe.get("variant")
    checks = probe.get("checks")
    failures = probe.get("failures")
    rows = probe.get("results", [])
    comparisons = probe.get("comparisons", [])
    footer = FOOTER.findall(combined)
    if not source_unchanged:
        reasons.append("source_changed")
    if mode not in ("candidate", "priority", "drop_late"):
        reasons.append("undeclared_variant")
    valid_counts = isinstance(checks, int) and isinstance(failures, int) and 0 <= failures <= checks
    if not valid_counts or checks != len(rows) or checks != CONTRACT["expected_check_count"]:
        reasons.append("incomplete_check_receipt")
    if [(row.get("context"), row.get("label")) for row in rows] != expected_rows(mode):
        reasons.append("declared_check_order_or_labels_changed")
    observed_failures = [row for row in rows if row.get("ok") is not True]
    if failures != len(observed_failures):
        reasons.append("failure_count_mismatch")
    if probe.get("retired") is not True:
        reasons.append("incomplete_retirement")
    if not valid_counts or len(footer) != 1 or footer[0] != ("PASS" if failures == 0 else "FAIL", str(checks - failures), str(checks)):
        reasons.append("footer_mismatch")
    # The engine version banner is not a diagnostic. Everything else here
    # requires separate investigation; there are no native-error exceptions.
    diagnostics = [line for line in combined.splitlines()
                   if re.match(r"^(SCRIPT ERROR:|ERROR:|WARNING:|ERROR |FATAL:)", line)]
    if diagnostics or re.search(r"(?i)(leaked|still in use at exit|access violation|crash handler)", combined):
        reasons.append("engine_diagnostic")
    expected_pairs = {(phase, order) for phase in PHASES for order in (False, True)}
    actual_pairs = {(row.get("phase"), row.get("reverse_order")) for row in comparisons}
    if len(comparisons) != 12 or actual_pairs != expected_pairs:
        reasons.append("incomplete_phase_comparison")
    for comparison in comparisons:
        if "baseline" not in comparison or "selected" not in comparison:
            reasons.append("missing_comparison_payload")
        elif comparison.get("equal") != (comparison["baseline"] == comparison["selected"]):
            reasons.append("comparison_flag_disagrees_with_payload")
    if engine_exit != (0 if mode == "candidate" else 1):
        reasons.append("engine_exit_mismatch")
    if any(row.get("context", "").startswith("baseline/") for row in observed_failures):
        reasons.append("baseline_failed")
    if mode == "candidate":
        if failures != 0 or any(row.get("equal") is not True for row in comparisons):
            reasons.append("candidate_not_equivalent")
    else:
        allowed = PRIORITY_FAILURES if mode == "priority" else LATE_FAILURES
        required = "overlap obeys authored priority" if mode == "priority" else "new draw is discovered on the next sweep"
        for order in ("false", "true"):
            expected_context = f"{mode}/reversed={order}"
            if not any(row.get("context") == expected_context and row.get("label") == required for row in observed_failures):
                reasons.append("missing_selective_failure_" + order)
        for row in observed_failures:
            context = row.get("context", "")
            if context == "equivalence":
                continue
            if not context.startswith(mode + "/") or row.get("label") not in allowed:
                reasons.append("unrelated_functional_failure")
        if not any(row.get("equal") is False for row in comparisons):
            reasons.append("missing_equivalence_red")
        if mode == "drop_late" and any(row.get("equal") is not True for row in comparisons
                                       if row.get("phase") in ("initial", "repeated")):
            reasons.append("late_control_changes_first_census")
    return {"engine_exit": engine_exit, "diagnostic_gate_exit": 0 if not reasons and mode == "candidate" else 1,
            "clean_equivalence": not reasons and mode == "candidate",
            "expected_selective_red_observed": not reasons and mode in ("priority", "drop_late"),
            "reasons": reasons, "native_diagnostics": diagnostics}
