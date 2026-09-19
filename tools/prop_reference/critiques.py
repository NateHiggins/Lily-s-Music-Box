"""Validate critique files against CRITIQUE_CONTRACT.md before they are scored."""

from __future__ import annotations

import json
from pathlib import Path

from .priority import AXES

REQUIRED = ("specimen", "axes", "effort_hours", "confidence", "summary", "modelling", "texturing")
CONFIDENCE = {"high", "medium", "low"}


def validate_critique(data: dict, known_ids: set[str] | None = None) -> list[str]:
    """Return the list of contract violations; empty means the file is usable."""
    errors: list[str] = []
    if not isinstance(data, dict):
        return ["not a JSON object"]
    for key in REQUIRED:
        if key not in data:
            errors.append(f"missing {key}")
    specimen = data.get("specimen")
    if known_ids is not None and specimen not in known_ids:
        errors.append(f"specimen {specimen!r} is not in the comparison index")
    axes = data.get("axes")
    if not isinstance(axes, dict):
        errors.append("axes must be an object")
    else:
        for axis in AXES:
            value = axes.get(axis)
            if not isinstance(value, (int, float)) or isinstance(value, bool) or not 0 <= value <= 5:
                errors.append(f"axis {axis} must be a number 0-5, got {value!r}")
        extra = set(axes) - set(AXES)
        if extra:
            errors.append(f"unknown axes: {sorted(extra)}")
    effort = data.get("effort_hours")
    if not isinstance(effort, (int, float)) or isinstance(effort, bool) or effort < 0:
        errors.append(f"effort_hours must be a non-negative number, got {effort!r}")
    if data.get("confidence") not in CONFIDENCE:
        errors.append(f"confidence must be one of {sorted(CONFIDENCE)}")
    if not isinstance(data.get("summary"), str) or not data.get("summary", "").strip():
        errors.append("summary must be a non-empty string")
    for key in ("modelling", "texturing"):
        value = data.get(key)
        if not isinstance(value, list) or not all(isinstance(v, str) for v in value):
            errors.append(f"{key} must be a list of strings")
    return errors


def validate_directory(directory: Path, known_ids: set[str]) -> dict[str, list[str]]:
    """Map every critique file to its violations (empty list = valid)."""
    report: dict[str, list[str]] = {}
    for path in sorted(Path(directory).glob("*.json")):
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as error:
            report[path.name] = [f"invalid JSON: {error}"]
            continue
        report[path.name] = validate_critique(data, known_ids)
        if data.get("specimen") != path.stem:
            report[path.name].append(f"file name {path.stem!r} does not match specimen {data.get('specimen')!r}")
    return report
