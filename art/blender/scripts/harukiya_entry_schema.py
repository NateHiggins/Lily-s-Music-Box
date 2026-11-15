"""Project full native reports into the fields consumed by the shipped loaders.

Keep full authoring/construction receipts beside generated outputs. In particular,
source_records stay complete: runtime compares them with the authoritative layout.
This module never rewrites geometry, source rows, materials or retirement triangles.
"""
from copy import deepcopy


def _select(record, fields):
    return {field: deepcopy(record[field]) for field in fields}


def runtime_entry(full):
    if full.get("retire_components", []):
        raise ValueError("Entrance retirement supports complete source stocks only")
    result = _select(full, (
        "schema_version", "asset", "door_asset", "fixture_asset", "source_records",
        "retire_ids", "materials",
    ))
    for key in ("native_parts", "door_parts", "fixture_parts"):
        fields = ("name", "matkey", "triangles")
        if key == "fixture_parts":
            fields += ("fixture_id", "is_emitter")
        result[key] = [_select(row, fields) for row in full[key]]
    result["fixtures"] = [_select(row, (
        "id", "source_at", "source_yaw_deg", "emission_center_source",
        "emitter_local_source", "tint", "range_m", "energy_scale",
    )) for row in full["fixtures"]]
    result["door"] = _select(full["door"], ("identity", "width", "height"))
    return result


def runtime_retirement(full):
    result = _select(full, (
        "schema_version", "source_records", "source_cell_sha256",
        "source_buffer_sha256", "stock_counts",
    ))
    result["retirement"] = [_select(row, (
        "name", "source_name", "hull_only", "colliding", "source_triangles",
        "count", "owners", "triangles",
    )) for row in full["retirement"]]
    return result
