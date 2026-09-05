"""Fail-closed assessment of the named old-haunt omission and restored run.

No expected route-error allowance exists before observation/review. Raw scene
completion and named failures are required independently of native/gate exits.
"""
import re

ROUTINES = "game/scripts/characters/resident_routines.gd"
PREFIX = "[RESIDENT F01 HAUNT] "
RETIRED = "actual V1 root retired"
ARRIVED = "actual F01 readiness alone releases the rider at its public landing"
OLD_REQUIRED_PASS = {
    RETIRED, ARRIVED, "real lift arrival installs the authored destination path",
    "actual home departure reaches and boards the lift",
    "outbound boarding occurs only at the actually ready F04 landing",
    "F01 landing really closed while car departed to F04",
}
OLD_REQUIRED_FAIL = {
    "whole destination body footprint fits the public F01 lobby",
    "whole destination body footprint is outside the lift shaft",
    "public destination route and swept actual Body clear the closed lift landing",
}
OLD_ALLOWED_FAIL = OLD_REQUIRED_FAIL | {
    "destination has real F01 slab support at the authored floor height",
    "actual Body shape clears all current destination colliders",
    "actual destination Body still clears after real car arrival",
}
NEW_REQUIRED_PASS = OLD_REQUIRED_PASS | OLD_ALLOWED_FAIL | {
    "resident actually dwells visibly at its reached public destination",
    "unmodified dwell expiry starts the normal return elevator intent",
    "return boarding requires the actually ready F01 cabin",
    "actual F04 return arrival releases resident at public landing",
    "real return ride completes without fallback or forced readiness",
    "returned owner follows its production route back to the same 4D home",
    "complete normal lifecycle records no unreachable routes",
}
STOPPED = "Real arrival observed; unsafe destination prevents dependent dwell/return proof"
HOST_HEADER = "ERROR: GENERAL - Message Id Number: 0 | Message Id Name: Loader Message"


def clean_environment(environ):
    env = dict(environ)
    cleared = sorted(set([
        "ORISON_BUILDING_ROOT", "SHOT_DIR", "REALITY_TIME_OVERRIDE", "REALITY_TIME",
        "CAMPAIGN_TIME_FREEZE", "DAYNIGHT_FORCE", "SCHEDULE", "VULKAN_PAIRING_CASE",
        "PERF_STREET_CORE_GEOMETRY_ON", "PERF_STREET_HARUKIYA_GEOMETRY_ON",
        "PERF_NEON_LETTER_BATCHING_OFF",
    ] + [key for key in env if key.startswith("SURFACE_")]))
    present = [key for key in cleared if key in env]
    for key in cleared:
        env.pop(key, None)
    return env, cleared, present


def _scene_checks(scene, stdout, tag, reasons):
    checks = scene.get("checks", [])
    if not isinstance(checks, list) or not checks or any(
            not isinstance(row, dict) or not isinstance(row.get("label"), str)
            or type(row.get("passed")) is not bool for row in checks):
        reasons.append(tag + ": malformed or absent named checks")
        return {}
    named = {row["label"]: row["passed"] for row in checks}
    if len(named) != len(checks):
        reasons.append(tag + ": duplicate check label")
    failed = sum(not row["passed"] for row in checks)
    if type(scene.get("failures")) is not int or scene["failures"] != failed:
        reasons.append(tag + ": JSON failure count mismatch")
    actual_lines = [line for line in stdout.splitlines()
                    if line.startswith((PREFIX + "PASS ", PREFIX + "FAIL "))]
    expected_lines = [PREFIX + ("PASS " if row["passed"] else "FAIL ") + row["label"] for row in checks]
    if actual_lines != expected_lines:
        reasons.append(tag + ": raw named assertions differ from JSON/order")
    summaries = [line for line in stdout.splitlines() if line.startswith(PREFIX + "RESULT ")]
    if summaries != [PREFIX + f"RESULT {len(checks) - failed} passed, {failed} failed"]:
        reasons.append(tag + ": absent, repeated or inconsistent final completion")
    return named


def _diagnostics(result, stdout, stderr, tag, reasons):
    gate = result.get("diagnostic_gate", {})
    if gate.get("light_unpair_count") != 0 or gate.get("softshadow_underflow_count") != 0:
        reasons.append(tag + ": pairing diagnostic")
    if gate.get("retention") or gate.get("non_inherited_errors"):
        reasons.append(tag + ": retention or non-inherited error")
    lines = (stdout + "\n" + stderr).splitlines()
    for i, line in enumerate(lines):
        stripped = line.strip()
        if re.search(r"softshadow_count\s*==\s*0|indexing did not unpair geometries|"
                     r"ObjectDB instances leaked|resources still in use at exit|"
                     r"Unreferenced static string|RID allocations", line, re.I):
            reasons.append(tag + ": raw pairing or retention diagnostic")
        if stripped.startswith(("ERROR:", "SCRIPT ERROR:")):
            following = lines[i + 1].strip() if i + 1 < len(lines) else ""
            inherited = (stripped == HOST_HEADER
                         and following.startswith("loader_get_json: Failed to open JSON file ")
                         and any(owner in following for owner in ["TikTok LIVE Studio", "Epic Games\\Launcher\\Portal\\Extras\\Overlay"]))
            if not inherited:
                reasons.append(tag + ": unknown raw error (no route error allowance declared)")
        if re.search(r"Parse Error|Invalid call|Invalid access", stripped, re.I):
            reasons.append(tag + ": raw script failure")
        if stripped.startswith("WARNING:") and stripped != "WARNING: no legal wall for found piece cam_noel_witches":
            reasons.append(tag + ": unreviewed warning")


def assess_pair(old, restored, old_scene, new_scene, old_stdout, old_stderr,
                new_stdout, new_stderr, changed_paths, restoration):
    reasons = []
    old_checks = _scene_checks(old_scene, old_stdout, "omission", reasons)
    new_checks = _scene_checks(new_scene, new_stdout, "restored", reasons)
    for label in OLD_REQUIRED_PASS:
        if old_checks.get(label) is not True:
            reasons.append("omission: missing actual lifecycle/retirement " + label)
    for label in OLD_REQUIRED_FAIL:
        if old_checks.get(label) is not False:
            reasons.append("omission: named old-haunt failure missing " + label)
    if any(not passed and label not in OLD_ALLOWED_FAIL for label, passed in old_checks.items()):
        reasons.append("omission: unrelated functional failure")
    if old_scene.get("stopped") != STOPPED:
        reasons.append("omission: missing explicit dependent-proof stop")
    for label in NEW_REQUIRED_PASS:
        if new_checks.get(label) is not True:
            reasons.append("restored: incomplete actual lifecycle/clearance " + label)
    if not new_checks or not all(new_checks.values()) or new_scene.get("stopped"):
        reasons.append("restored: failed or partial lifecycle")
    if (old.get("native_exit") != 1 or old.get("suite_completion") is not False
            or old.get("diagnostic_gate", {}).get("exit") != 1):
        reasons.append("omission: native/gate/completion mismatch")
    expected_old_reasons = {"native/runner exit 1", "expected suite/capture completion absent or failed"}
    if set(old.get("diagnostic_gate", {}).get("reasons", [])) != expected_old_reasons:
        reasons.append("omission: gate has unrelated or missing failure reason")
    if (restored.get("native_exit") != 0 or restored.get("suite_completion") is not True
            or restored.get("diagnostic_gate", {}).get("exit") != 0
            or restored.get("diagnostic_gate", {}).get("reasons")):
        reasons.append("restored: native/gate/completion is not clean")
    _diagnostics(old, old_stdout, old_stderr, "omission", reasons)
    _diagnostics(restored, new_stdout, new_stderr, "restored", reasons)
    for tag, result in [("omission", old), ("restored", restored)]:
        if result.get("source_unchanged") is not True:
            reasons.append(tag + ": source changed during run")
        engines = result.get("before", {}).get("engine_binaries")
        if not engines or len(engines) != 2 or engines != result.get("after", {}).get("engine_binaries"):
            reasons.append(tag + ": incomplete or changing engine binding")
    if old.get("before", {}).get("engine_binaries") != restored.get("before", {}).get("engine_binaries"):
        reasons.append("engine differs across pair")
    if not old.get("test_sha256") or old.get("test_sha256") != restored.get("test_sha256"):
        reasons.append("fixture differs across pair")
    for key in ["runner_sha256", "parser_sha256", "wrapper_sha256", "control_sha256"]:
        expected = old.get("before", {}).get(key)
        if not expected or any(row.get(label, {}).get(key) != expected
                               for row in [old, restored] for label in ["before", "after"]):
            reasons.append("execution input differs across pair: " + key)
    if changed_paths != [ROUTINES]:
        reasons.append("source/assets differ beyond the one authored coordinate")
    if (restoration.get("exact_bytes_restored") is not True
            or not restoration.get("expected_candidate_sha256")
            or restoration.get("candidate_restored_sha256") != restoration.get("expected_candidate_sha256")):
        reasons.append("exact candidate restoration not proven")
    return {"expected_control_pattern": not reasons, "reasons": reasons,
            "scope": "Exact old-haunt failure after actual arrival and retirement, then complete restored lifecycle; no accepted route-error exemption"}
