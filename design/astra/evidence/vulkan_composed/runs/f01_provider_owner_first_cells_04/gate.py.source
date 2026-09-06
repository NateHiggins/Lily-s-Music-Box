"""Fail-closed composed-root diagnostics. Engine zero alone never passes."""
from collections import Counter
from pathlib import Path
import re

UNPAIR = "BUG, indexing did not unpair geometries from light."
SOFT_SHADOW = re.compile(r"geom->softshadow_count\s*==\s*0\s*-\s*BUG!")


def classify(engine_exit, stdout, stderr, probe, source_unchanged, engine_bound):
    text = stdout + "\n" + stderr
    lines = text.splitlines()
    unpair = text.count(UNPAIR)
    soft_shadow = len(SOFT_SHADOW.findall(text))
    inherited, errors, warnings, retention = [], [], [], []
    for i, line in enumerate(lines):
        if line.startswith("WARNING:"):
            warnings.append(line)
        if any(token in line for token in ("ObjectDB instances leaked", "resources still in use at exit", "Unreferenced static string")):
            retention.append(line)
        if not line.startswith(("ERROR:", "SCRIPT ERROR:")):
            continue
        following = lines[i + 1].strip() if i + 1 < len(lines) else ""
        manifest = (line == "ERROR: GENERAL - Message Id Number: 0 | Message Id Name: Loader Message"
                    and following.startswith("loader_get_json: Failed to open JSON file ")
                    and any(x in following for x in ("TikTok LIVE Studio", "Epic Games\\Launcher\\Portal\\Extras\\Overlay")))
        if manifest:
            inherited.append({"header": line, "detail": following})
        else:
            errors.append(line)
    reasons = []
    if engine_exit != 0: reasons.append(f"actual engine/runner exit {engine_exit}")
    if not source_unchanged: reasons.append("source/assets or runner changed")
    if not engine_bound: reasons.append("installed launcher/GUI binding incomplete or changed")
    if "Godot Engine v4.7.1.stable.official.a13da4feb" not in stdout or "Forward+" not in stdout or "Vulkan " not in stdout:
        reasons.append("required installed engine and Vulkan Forward+ identity absent")
    if errors: reasons.append(f"{len(errors)} non-inherited error headers")
    if unpair: reasons.append(f"{unpair} geometry-light unpair errors")
    if soft_shadow: reasons.append(f"{soft_shadow} independent soft-shadow underflow errors")
    if retention: reasons.append(f"{len(retention)} retention diagnostics")
    meaningful = bool(probe and probe.get("checks") and probe.get("functional_failures") == 0
                      and all(row.get("passed") is True for row in probe["checks"]))
    if not meaningful: reasons.append("functional checks failed or missing")
    if probe:
        scope = probe.get('execution_scope')
        if probe.get('root') not in {'v1', 'v2'} or probe.get('variant') not in {'raw', 'candidate', 'omission', 'viewport_omission'} or probe.get('renderer') != 'forward_plus' or not probe.get('pid'):
            reasons.append('invalid actual probe identity')
        if scope not in {'full', 'root_retirement'} or (scope == 'root_retirement' and probe.get('root') != 'v1'):
            reasons.append('invalid or missing explicit execution scope')
        required = ({"initial_street", "initial_passage", "initial_orison", "initial_f04", "initial_harukiya",
                     "before_retirement_passage", "return_harukiya", "actual_f04_mirror", "actual_f04_reflection",
                     "separate_world_initial", "separate_world_restored", "separate_world_blocked",
                     "initial_street_phone", "initial_passage_phone", "initial_orison_phone", "before_retirement_passage_phone",
                     "actual_arcade_before_passage", "actual_arcade_after_passage"}
                    if probe.get("root") == "v1" else {"v2_actual_f04_semantic_stance", "v2_actual_f04_phone"})
        if scope == 'root_retirement':
            required -= {'separate_world_initial', 'separate_world_restored', 'separate_world_blocked'}
            if probe.get('separate_world_case_executed') is not False or '[VULKAN COMPOSED PHASE] separate_world_case_explicitly_excluded' not in stdout:
                reasons.append('root-retirement scope exclusion not explicitly recorded')
        elif probe.get('root') == 'v1' and probe.get('separate_world_case_executed') is not True:
            reasons.append('full V1 did not execute separate-world case')
        captures = probe.get("captures", [])
        names = {c.get("name") for c in captures if c.get("written") and Path(c.get("file", "")).is_file()}
        if names != required or len(captures) != len(required): reasons.append("required composed/ownership captures missing or duplicated")
        if probe.get("root") == "v1" and len([t for t in probe.get("transitions", []) if 0 <= t.get("cycle", -1) < 6]) != 36:
            reasons.append("matched measured transition set incomplete")
    if "[VULKAN COMPOSED PHASE] after_retirement" not in stdout:
        reasons.append("post-retirement phase absent")
    native_reasons = {f"{len(errors)} non-inherited error headers", f"{unpair} geometry-light unpair errors",
                      f"{soft_shadow} independent soft-shadow underflow errors"}
    only_native_errors = all(UNPAIR in line or SOFT_SHADOW.search(line) for line in errors)
    valid_unpair_red = bool(probe and probe.get("variant") in {"raw", "omission"} and meaningful and unpair and soft_shadow == 0
                            and only_native_errors and set(reasons) <= native_reasons)
    failed_checks = [row for row in (probe or {}).get('checks', []) if row.get('passed') is not True]
    live_mask_corruption = any(
        issue.get('kind') == 'still_live_baseline_geometry_corrupted'
        and issue.get('expected_mask') != issue.get('actual_mask') and issue.get('same_own_scenario') is True
        and issue.get('owner_state', {}).get('booted') is True
        for observation in (probe or {}).get('arcade_observations', []) for issue in observation.get('issues', []))
    valid_viewport_red = bool(probe and probe.get('root') == 'v1' and probe.get('variant') == 'viewport_omission' and engine_exit == 1
        and failed_checks and all(row.get('label', '').startswith('arcade ') or row.get('label', '').startswith('return reactivates actual nearby arcade owner ') for row in failed_checks)
        and len(failed_checks) == probe.get('functional_failures') and live_mask_corruption
        and set(reasons) == {'actual engine/runner exit 1', 'functional checks failed or missing'})
    return {"diagnostic_gate_exit": int(bool(reasons)), "reasons": reasons,
            "unpair_errors": unpair, "soft_shadow_underflows": soft_shadow,
            "non_inherited_error_headers": dict(Counter(errors)), "inherited_manifest_errors": inherited,
            "warnings": dict(Counter(warnings)), "retention": retention,
            "functional_checks_meaningful": meaningful,
            "expected_unpair_red_observed": valid_unpair_red,
            "expected_viewport_guard_red_observed": valid_viewport_red,
            "execution_scope": (probe or {}).get('execution_scope', 'missing'),
            "full_candidate_scope_completed": bool(probe and probe.get('variant') == 'candidate' and probe.get('execution_scope') == 'full' and not reasons),
            "native_phase_attribution": "stdout phase markers retained; separate stdout/stderr buffering does not establish exact native-error phase or causal ownership"}
