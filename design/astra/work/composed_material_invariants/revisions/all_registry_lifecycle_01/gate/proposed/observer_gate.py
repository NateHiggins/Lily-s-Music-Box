"""Require independently evaluated rows and the complete lifecycle write set."""
from collections import Counter
import math

CONTRACT = "independent_rows_and_all_registry_lifecycle_v2"


def instance_id(value):
    return type(value) is int and -(1 << 63) <= value < (1 << 63) and value != 0


def number(value):
    return type(value) in (int, float) and math.isfinite(value)


def same_number(actual, expected):
    return number(actual) and number(expected) and math.isclose(actual, expected, rel_tol=1e-5, abs_tol=1e-6)


def same_state(actual, expected):
    if isinstance(actual, list) and isinstance(expected, list):
        return len(actual) == len(expected) == 4 and all(same_number(a, b) for a, b in zip(actual, expected))
    return same_number(actual, expected)


def count_matches(payload, key, value):
    return type(payload.get(key)) is int and payload[key] == value


def unique_rows(rows, expected_ids):
    return isinstance(rows, list) and all(isinstance(row, dict) and instance_id(row.get("material_id")) for row in rows) \
        and len(rows) == len(expected_ids) and {row["material_id"] for row in rows} == expected_ids


def validate_v2_refresh(refresh, cases, registries):
    reasons = []
    if refresh.get("comparison_contract") != CONTRACT:
        return ["independent comparison contract v2 missing"]
    expected_rows = []
    case_ids = set()
    for case, data in cases.items():
        for plural, kind in (("finishes", "finish"), ("props", "prop")):
            for row in data.get(plural, []):
                mid = row.get("material_id")
                if not instance_id(mid):
                    return ["case census contains an invalid signed instance ID"]
                expected_rows.append((case, kind, row.get("path"), row.get("slot") if kind == "finish" else None, mid))
                case_ids.add(mid)
    comparisons = refresh.get("case_comparisons")
    actual_rows = []
    rows_ok = isinstance(comparisons, list) and bool(expected_rows)
    if rows_ok:
        for row in comparisons:
            if not isinstance(row, dict):
                rows_ok = False
                continue
            mid = row.get("material_id")
            if not instance_id(mid) or not isinstance(row.get("case_id"), str) or row.get("kind") not in {"finish", "prop"} \
                    or not isinstance(row.get("path"), str) or not row["path"] \
                    or (row["kind"] == "finish" and (type(row.get("slot")) is not int or row["slot"] < 0)):
                rows_ok = False
                continue
            actual_rows.append((row.get("case_id"), row.get("kind"), row.get("path"), row.get("slot") if row.get("kind") == "finish" else None, mid))
            state_ok = same_number(row.get("actual_state"), row.get("expected_state")) if row["kind"] == "finish" \
                else isinstance(row.get("actual_state"), list) and isinstance(row.get("expected_state"), list) \
                and same_state(row["actual_state"], row["expected_state"])
            if not instance_id(mid) or any(row.get(key) is not True for key in ("evaluated", "passed", "identity_matches", "state_matches")) \
                    or not state_ok:
                rows_ok = False
        if Counter(actual_rows) != Counter(expected_rows):
            rows_ok = False
    if not rows_ok or not all(count_matches(refresh, key, value) for key, value in (
            ("case_rows_planned", len(expected_rows)), ("case_rows_evaluated", len(expected_rows)),
            ("case_comparisons_evaluated", len(expected_rows) * 2), ("case_materials_touched", len(case_ids)))):
        reasons.append("independent case comparison payload missing, mismatched or unexecuted")

    case_lifecycle = refresh.get("case_lifecycle_comparisons")
    case_lifecycle_ok = unique_rows(case_lifecycle, case_ids)
    if case_lifecycle_ok:
        case_lifecycle_ok = all(row.get("evaluated") is True and row.get("passed") is True and row.get("floor") in registries
                                and same_number(row.get("actual"), row.get("expected")) for row in case_lifecycle)
    if not case_lifecycle_ok or not count_matches(refresh, "case_lifecycle_materials_evaluated", len(case_ids)):
        reasons.append("case lifecycle comparison payload missing, mismatched or unexecuted")

    memberships = {}
    slots = 0
    for floor, data in registries.items():
        values = data.get("material_ids", [])
        slots += len(values)
        for mid in values:
            if not instance_id(mid):
                return reasons + ["registry census contains an invalid signed instance ID"]
            memberships.setdefault(mid, []).append(floor)
    registry_ids = set(memberships)
    registry_comparisons = refresh.get("registry_lifecycle_comparisons")
    registry_ok = bool(registry_ids) and unique_rows(registry_comparisons, registry_ids)
    if registry_ok:
        for row in registry_comparisons:
            floors = row.get("write_floors")
            if not isinstance(floors, list) or not all(isinstance(floor, str) for floor in floors) \
                    or Counter(floors) != Counter(memberships[row["material_id"]]) \
                    or row.get("evaluated") is not True or row.get("passed") is not True \
                    or not same_number(row.get("actual"), row.get("expected")):
                registry_ok = False
    before, after = refresh.get("registry_lifecycle_before"), refresh.get("registry_lifecycle_after")
    snapshots_ok = isinstance(before, dict) and isinstance(after, dict) and before == after \
        and set(before) == {str(mid) for mid in registry_ids}
    if snapshots_ok:
        for key, row in before.items():
            if not isinstance(row, dict) or not instance_id(row.get("material_id")) or str(row["material_id"]) != key:
                snapshots_ok = False
                continue
            floors = row.get("write_floors")
            if not isinstance(floors, list) or not all(isinstance(floor, str) for floor in floors) \
                    or Counter(floors) != Counter(memberships[row["material_id"]]) or "value" not in row \
                    or (row.get("value") is not None and not number(row.get("value"))):
                snapshots_ok = False
    if not registry_ok or not snapshots_ok or refresh.get("registry_types_valid") is not True \
            or refresh.get("registry_lifecycle_restored") is not True or refresh.get("registry_restore_failures") != [] \
            or not all(count_matches(refresh, key, value) for key, value in (
                ("registry_live_slots", slots), ("registry_unique_materials", len(registry_ids)),
                ("registry_lifecycle_materials_evaluated", len(registry_ids)),
                ("lifecycle_restore_union_size", len(case_ids | registry_ids)))):
        reasons.append("complete registry lifecycle write-set/comparison/restoration payload missing or inconsistent")
    return reasons
