#!/usr/bin/env python3
"""Merge process-isolated M11C2 Forward+ capture receipts.

Godot 4.7's production Forward+ root has a historical light/geometry unpair
diagnostic during visibility changes and process retirement.  Visual
equivalence therefore uses one complete production root per process.  This
merger rejects mismatched cameras, simulation facts, files, dimensions, phases,
route schemas, or new error signatures; the headless production matrix remains
the lifecycle ownership gate.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any

from PIL import Image, ImageChops, ImageStat


EXPECTED_SIZE = [1600, 900]
EXPECTED_PAIR_COUNT = 5
EXPECTED_ROUTE_COUNT = 9
MIN_ROUTE_GROUNDED_FRACTION = 0.90
KNOWN_RENDER_ERRORS = {
    "softshadow_unpair": "geom->softshadow_count==0 - BUG!",
    "light_geometry_index": "BUG, indexing did not unpair geometries from light.",
}
KNOWN_RUNTIME_ERRORS = {
    "resident_nav_wall_safe_route": "No wall-safe resident route on F01:",
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"{path} is not a JSON object")
    return value


def canonical(value: Any) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"))


def exact_simulation_facts(
    first_facts: Any,
    first_hash: str,
    second_facts: Any,
    second_hash: str,
) -> bool:
    """Require both a non-empty producer hash and exact canonical fact parity."""
    return bool(first_hash) \
        and first_hash == second_hash \
        and canonical(first_facts) == canonical(second_facts)


def resolve_image(raw: str, repo_root: Path) -> Path:
    path = Path(raw)
    return path if path.is_absolute() else (repo_root / path).resolve()


def image_difference(legacy: Path, cells: Path) -> dict[str, Any]:
    with Image.open(legacy).convert("RGB") as first, Image.open(cells).convert(
        "RGB"
    ) as second:
        if first.size != second.size:
            return {"dimensions_equal": False}
        difference = ImageChops.difference(first, second)
        statistics = ImageStat.Stat(difference)
        extrema = difference.getextrema()
        changed_bbox = difference.getbbox()
        pixels = first.width * first.height
        changed = 0
        if changed_bbox is not None:
            changed = sum(1 for pixel in difference.getdata() if pixel != (0, 0, 0))
        return {
            "dimensions_equal": True,
            "mean_absolute_rgb": [round(value, 6) for value in statistics.mean],
            "maximum_absolute_rgb": [int(value[1]) for value in extrema],
            "changed_pixel_fraction": round(changed / max(1, pixels), 9),
            "pixel_identical": changed == 0,
        }


def log_diagnostics(path: Path) -> dict[str, Any]:
    """Classify diagnostics from both streams emitted by the serial runner.

    ``run_godot_serial.ps1`` deliberately keeps stdout and stderr separate.
    Treating only the requested stdout path as the process log would silently
    omit renderer and script errors, because Godot normally writes them to the
    adjacent ``.stderr`` sidecar.
    """

    paths = [path]
    stderr_path = Path(f"{path}.stderr")
    if stderr_path.is_file():
        paths.append(stderr_path)
    texts = [item.read_text(encoding="utf-8", errors="replace") for item in paths]
    text = "\n".join(texts)
    counts = {key: text.count(token) for key, token in KNOWN_RENDER_ERRORS.items()}
    runtime_counts = {
        key: text.count(token) for key, token in KNOWN_RUNTIME_ERRORS.items()
    }
    diagnostic_lines = []
    for line in text.splitlines():
        stripped = line.strip()
        if re.match(r"^(?:ERROR|SCRIPT ERROR|FATAL):", stripped) \
                or "Parse Error" in stripped \
                or re.search(r"\b(?:Segmentation fault|CrashHandler|program crashed|unhandled exception)\b", stripped, re.IGNORECASE):
            diagnostic_lines.append(stripped)
    unknown = [
        line
        for line in diagnostic_lines
        if not any(
            token in line
            for token in (*KNOWN_RENDER_ERRORS.values(), *KNOWN_RUNTIME_ERRORS.values())
        )
    ]
    return {
        "path": path.as_posix(),
        "sha256": sha256(path),
        "streams": [
            {"path": item.as_posix(), "sha256": sha256(item)} for item in paths
        ],
        "stderr_sidecar_consumed": stderr_path in paths,
        "known_signature_counts": counts,
        "known_signature_set": sorted(key for key, count in counts.items() if count),
        "known_runtime_debt_counts": runtime_counts,
        "unknown_error_count": len(unknown),
        "unknown_errors": sorted(set(unknown)),
        "diagnostic_line_count": len(diagnostic_lines),
        "historical_forward_plus_visibility_and_process_retirement_diagnostic": bool(
            sum(counts.values())
        ),
    }


def route_contract(route: dict[str, Any]) -> dict[str, Any]:
    """Return the provider-independent route contract, rejecting partial evidence."""

    def required(row: dict[str, Any], keys: tuple[str, ...], context: str) -> None:
        missing = [key for key in keys if key not in row]
        if missing:
            raise ValueError(f"{context} missing required fields: {', '.join(missing)}")

    def dictionary(row: Any, context: str) -> dict[str, Any]:
        if not isinstance(row, dict):
            raise ValueError(f"{context} is not an object")
        return row

    def array(row: Any, context: str) -> list[Any]:
        if not isinstance(row, list):
            raise ValueError(f"{context} is not an array")
        return row

    def movement(row: Any, context: str) -> dict[str, Any]:
        row = dictionary(row, context)
        required(
            row,
            (
                "id",
                "reached",
                "expected_blocked",
                "noclip",
                "collision_layer",
                "collision_mask",
                "grounded_fraction",
                "waypoints",
            ),
            context,
        )
        waypoints = array(row["waypoints"], f"{context}.waypoints")
        return {
            "id": row["id"],
            "reached": row["reached"],
            "expected_blocked": row["expected_blocked"],
            "correctly_blocked": row.get("correctly_blocked"),
            "noclip": row["noclip"],
            "collision_layer": row["collision_layer"],
            "collision_mask": row["collision_mask"],
            "grounded_fraction": row["grounded_fraction"],
            "waypoint_count": len(waypoints),
            "slide_collision_count": len(row.get("slide_collisions", [])),
        }

    def semantic_chain_movement(row: Any, context: str) -> dict[str, Any]:
        row = dictionary(row, context)
        required(
            row,
            (
                "reached",
                "physics_frames",
                "grounded_fraction",
                "noclip",
                "collision_layer",
                "collision_mask",
                "coordinate_fields_omitted",
            ),
            context,
        )
        if row["coordinate_fields_omitted"] is not True:
            raise ValueError(f"{context} is not coordinate-free")
        forbidden_coordinates = {"finish", "target", "waypoints", "position"}
        leaked = sorted(forbidden_coordinates.intersection(row))
        if leaked:
            raise ValueError(f"{context} leaked coordinate fields: {', '.join(leaked)}")
        return {
            "reached": row["reached"],
            "grounded_fraction": row["grounded_fraction"],
            "noclip": row["noclip"],
            "collision_layer": row["collision_layer"],
            "collision_mask": row["collision_mask"],
            "coordinate_fields_omitted": row["coordinate_fields_omitted"],
        }

    def semantic_chain(row: Any, context: str) -> dict[str, Any]:
        row = dictionary(row, context)
        required(
            row,
            (
                "id",
                "reached",
                "authority",
                "source_contract",
                "source_contract_sha256",
                "endpoint_coordinates_recorded",
                "subleg_count",
                "sublegs",
            ),
            context,
        )
        raw_sublegs = array(row["sublegs"], f"{context}.sublegs")
        if row["subleg_count"] != len(raw_sublegs):
            raise ValueError(f"{context}.subleg_count does not match sublegs")
        if row["endpoint_coordinates_recorded"] is not False:
            raise ValueError(f"{context} recorded endpoint coordinates")
        if not row["authority"] or not row["source_contract_sha256"]:
            raise ValueError(f"{context} has empty authority provenance")
        sublegs = []
        for index, raw_subleg in enumerate(raw_sublegs):
            subleg_context = f"{context}.sublegs[{index}]"
            raw_subleg = dictionary(raw_subleg, subleg_context)
            required(
                raw_subleg,
                (
                    "index",
                    "reached",
                    "authority_id",
                    "traversal_id",
                    "endpoint_role",
                    "relationship",
                    "authority_sha256",
                    "endpoint_sha256",
                    "source_contract_sha256",
                    "endpoint_coordinates_recorded",
                    "movement",
                ),
                subleg_context,
            )
            if raw_subleg["index"] != index:
                raise ValueError(f"{subleg_context}.index is not contiguous")
            if raw_subleg["endpoint_coordinates_recorded"] is not False:
                raise ValueError(f"{subleg_context} recorded endpoint coordinates")
            if raw_subleg["source_contract_sha256"] != row["source_contract_sha256"]:
                raise ValueError(f"{subleg_context} source contract hash differs")
            for hash_key in ("authority_sha256", "endpoint_sha256"):
                if not raw_subleg[hash_key]:
                    raise ValueError(f"{subleg_context}.{hash_key} is empty")
            sublegs.append(
                {
                    "index": raw_subleg["index"],
                    "reached": raw_subleg["reached"],
                    "authority_id": raw_subleg["authority_id"],
                    "traversal_id": raw_subleg["traversal_id"],
                    "endpoint_role": raw_subleg["endpoint_role"],
                    "relationship": raw_subleg["relationship"],
                    "authority_sha256": raw_subleg["authority_sha256"],
                    "endpoint_sha256": raw_subleg["endpoint_sha256"],
                    "source_contract_sha256": raw_subleg[
                        "source_contract_sha256"
                    ],
                    "endpoint_coordinates_recorded": raw_subleg[
                        "endpoint_coordinates_recorded"
                    ],
                    "movement": semantic_chain_movement(
                        raw_subleg["movement"], f"{subleg_context}.movement"
                    ),
                }
            )
        return {
            "shape": "semantic_chain",
            "id": row["id"],
            "reached": row["reached"],
            "authority": row["authority"],
            "source_contract": row["source_contract"],
            "source_contract_sha256": row["source_contract_sha256"],
            "endpoint_coordinates_recorded": row["endpoint_coordinates_recorded"],
            "subleg_count": row["subleg_count"],
            "sublegs": sublegs,
        }

    def route_leg(row: Any, context: str) -> dict[str, Any]:
        row = dictionary(row, context)
        semantic_shape = "authority" in row or "sublegs" in row
        movement_shape = "waypoints" in row
        if semantic_shape == movement_shape:
            raise ValueError(f"{context} has ambiguous or unknown route-leg shape")
        if semantic_shape:
            return semantic_chain(row, context)
        normalized = movement(row, context)
        normalized["shape"] = "movement"
        return normalized

    def interaction(row: Any, context: str) -> dict[str, Any]:
        row = dictionary(row, context)
        required(
            row,
            (
                "identity",
                "ok",
                "expected_locked",
                "open_after",
                "leaf_state_after",
                "public_interact",
                "matching_interactable_count",
            ),
            context,
        )
        return {
            "identity": row["identity"],
            "ok": row["ok"],
            "expected_locked": row["expected_locked"],
            "open_after": row["open_after"],
            "leaf_state_after": row["leaf_state_after"],
            "public_interact": row["public_interact"],
            "matching_interactable_count": row["matching_interactable_count"],
        }

    def derived_crossing(row: Any, context: str) -> dict[str, Any]:
        row = dictionary(row, context)
        required(row, ("applicable",), context)
        if row["applicable"] is False:
            required(row, ("reason",), context)
            return {"applicable": False, "reason": row["reason"]}
        if row["applicable"] is not True:
            raise ValueError(f"{context}.applicable is not boolean")
        required(
            row,
            (
                "authority",
                "door_identity",
                "source_traversal_id",
                "source_record_sha256",
                "hinge_jamb",
                "capsule_radius_m",
                "half_width_m",
                "minimum_side_clearance_m",
                "lateral_offset_m",
                "retained_clearance_fraction",
                "provider_identity_read",
                "shop_identity_branch",
                "coordinate_fields_omitted",
            ),
            context,
        )
        return {key: row[key] for key in (
            "applicable",
            "authority",
            "door_identity",
            "source_traversal_id",
            "source_record_sha256",
            "hinge_jamb",
            "capsule_radius_m",
            "half_width_m",
            "minimum_side_clearance_m",
            "lateral_offset_m",
            "retained_clearance_fraction",
            "provider_identity_read",
            "shop_identity_branch",
            "coordinate_fields_omitted",
        )}

    required(
        route,
        (
            "status",
            "frame_count",
            "literal_route_sequence",
            "initial_placement_count",
            "intermediate_transform_writes",
            "teleports",
            "noclip",
            "legs",
            "interactions",
            "shop_results",
            "vertical_core",
        ),
        "route",
    )
    shops = []
    for index, raw in enumerate(array(route["shop_results"], "route.shop_results")):
        raw = dictionary(raw, f"route.shop_results[{index}]")
        required(
            raw,
            ("cell_id", "approach", "interaction", "crossing", "derived_crossing"),
            f"route.shop_results[{index}]",
        )
        interaction_row = dictionary(
            raw["interaction"], f"route.shop_results[{index}].interaction"
        )
        crossing = dictionary(raw["crossing"], f"route.shop_results[{index}].crossing")
        crossing_contract = movement(crossing, f"route.shop_results[{index}].crossing")
        required(
            interaction_row,
            ("expected_locked",),
            f"route.shop_results[{index}].interaction",
        )
        if not bool(interaction_row["expected_locked"]):
            required(crossing, ("return",), f"route.shop_results[{index}].crossing")
            return_contract: dict[str, Any] | None = movement(
                crossing["return"], f"route.shop_results[{index}].crossing.return"
            )
        else:
            return_contract = None
        shops.append(
            {
                "cell_id": raw["cell_id"],
                "approach": movement(raw["approach"], f"route.shop_results[{index}].approach"),
                "interaction": interaction(interaction_row, f"route.shop_results[{index}].interaction"),
                "derived_crossing": derived_crossing(
                    raw["derived_crossing"], f"route.shop_results[{index}].derived_crossing"
                ),
                "crossing": crossing_contract,
                "return": return_contract,
            }
        )
    vertical = dictionary(route["vertical_core"], "route.vertical_core")
    required(
        vertical,
        (
            "status",
            "derived_without_embedded_coordinates",
            "elevator_f01_f02_contract",
            "connector",
            "ascent",
            "descent",
            "return_to_hall",
        ),
        "route.vertical_core",
    )
    return {
        "status": route["status"],
        "frame_count": route["frame_count"],
        "literal_route_sequence": route["literal_route_sequence"],
        "initial_placement_count": route["initial_placement_count"],
        "intermediate_transform_writes": route["intermediate_transform_writes"],
        "teleports": route["teleports"],
        "noclip": route["noclip"],
        "legs": [
            route_leg(row, f"route.legs[{index}]")
            for index, row in enumerate(array(route["legs"], "route.legs"))
        ],
        "interactions": [
            interaction(row, f"route.interactions[{index}]")
            for index, row in enumerate(
                array(route["interactions"], "route.interactions")
            )
        ],
        "shops": shops,
        "vertical": {
            "status": vertical["status"],
            "derived_without_embedded_coordinates": vertical[
                "derived_without_embedded_coordinates"
            ],
            "elevator_f01_f02_contract": vertical["elevator_f01_f02_contract"],
            "connector": movement(vertical["connector"], "route.vertical_core.connector"),
            "ascent": movement(vertical["ascent"], "route.vertical_core.ascent"),
            "descent": movement(vertical["descent"], "route.vertical_core.descent"),
            "return_to_hall": movement(
                vertical["return_to_hall"], "route.vertical_core.return_to_hall"
            ),
        },
    }


def compare_route_contracts(
    cells: dict[str, Any], legacy: dict[str, Any]
) -> dict[str, Any]:
    """Compare route semantics while preserving honest physics-frame variance.

    ``grounded_fraction`` is a ratio over process-timed physics frames, so an
    otherwise identical collision-bearing traversal can differ by a few frames
    between isolated renderer processes. Every other normalized value remains
    exact, and both measured fractions must retain at least 90% ground contact.
    """

    differences: list[dict[str, Any]] = []
    grounded: list[dict[str, Any]] = []

    def walk(first: Any, second: Any, path: str) -> None:
        if type(first) is not type(second):
            differences.append(
                {"path": path, "cells": first, "legacy": second, "kind": "type"}
            )
            return
        if isinstance(first, dict):
            first_keys = set(first)
            second_keys = set(second)
            if first_keys != second_keys:
                differences.append(
                    {
                        "path": path,
                        "cells_only": sorted(first_keys - second_keys),
                        "legacy_only": sorted(second_keys - first_keys),
                        "kind": "keys",
                    }
                )
                return
            for key in sorted(first_keys):
                child_path = f"{path}.{key}"
                if key == "grounded_fraction":
                    cells_value = float(first[key])
                    legacy_value = float(second[key])
                    grounded.append(
                        {
                            "path": child_path,
                            "cells": cells_value,
                            "legacy": legacy_value,
                            "absolute_delta": abs(cells_value - legacy_value),
                            "cells_meets_minimum": cells_value
                            >= MIN_ROUTE_GROUNDED_FRACTION,
                            "legacy_meets_minimum": legacy_value
                            >= MIN_ROUTE_GROUNDED_FRACTION,
                        }
                    )
                else:
                    walk(first[key], second[key], child_path)
            return
        if isinstance(first, list):
            if len(first) != len(second):
                differences.append(
                    {
                        "path": path,
                        "cells_length": len(first),
                        "legacy_length": len(second),
                        "kind": "length",
                    }
                )
                return
            for index, (first_item, second_item) in enumerate(zip(first, second)):
                walk(first_item, second_item, f"{path}[{index}]")
            return
        if first != second:
            differences.append(
                {"path": path, "cells": first, "legacy": second, "kind": "value"}
            )

    walk(cells, legacy, "route")
    grounded_pass = bool(grounded) and all(
        row["cells_meets_minimum"] and row["legacy_meets_minimum"]
        for row in grounded
    )
    return {
        "semantic_match": not differences and grounded_pass,
        "all_non_timing_fields_exact": not differences,
        "minimum_grounded_fraction": MIN_ROUTE_GROUNDED_FRACTION,
        "grounded_fraction_pass": grounded_pass,
        "grounded_fraction_comparisons": grounded,
        "differences": differences,
    }


def require(condition: bool, message: str, failures: list[str]) -> None:
    if not condition:
        failures.append(message)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", type=Path, default=Path(__file__).parents[1])
    parser.add_argument(
        "--packet-root",
        type=Path,
        default=Path("art/renders/orison_v2/m11c2_floor01_production_cut_01"),
    )
    args = parser.parse_args()
    repo_root = args.repo_root.resolve()
    packet = args.packet_root
    if not packet.is_absolute():
        packet = (repo_root / packet).resolve()
    receipts = packet / "receipts"
    runtime = packet / "runtime"
    inputs = {
        "legacy": receipts / "m11c2_capture_legacy_part.json",
        "cells": receipts / "m11c2_capture_cells_part.json",
        "route": receipts / "m11c2_capture_route_part.json",
        "route_control": runtime / "m11c2_capture_legacy_route_control_part.json",
        "matrix": runtime / "m11c2_production_matrix_receipt.json",
    }
    logs = {
        "legacy": runtime / "m11c2_capture_legacy_stdout.log",
        "cells": runtime / "m11c2_capture_cells_stdout.log",
        "route": runtime / "m11c2_capture_route_stdout.log",
        "route_control": runtime / "m11c2_capture_legacy_route_control_stdout.log",
    }
    failures: list[str] = []
    for path in [*inputs.values(), *logs.values()]:
        require(path.is_file(), f"missing input: {path}", failures)
    if failures:
        print("\n".join(failures))
        return 2

    parts = {key: load_json(path) for key, path in inputs.items()}
    expected_phases = {
        "legacy": "legacy_monolith",
        "cells": "owner_first_cells",
        "route": "owner_first_route",
        "route_control": "legacy_route_control",
    }
    for key, phase in expected_phases.items():
        require(parts[key].get("status") == "PASS", f"{key} part did not PASS", failures)
        require(parts[key].get("capture_phase") == phase, f"{key} phase mismatch", failures)
    harness_path = repo_root / "game/tests/orison_v2_m11c2_production_capture.gd"
    harness_sha256 = sha256(harness_path)
    for key in expected_phases:
        require(
            parts[key].get("capture_harness_sha256") == harness_sha256,
            f"{key} part was not produced by the frozen capture harness",
            failures,
        )
    matrix = parts["matrix"]
    require(matrix.get("status") == "PASS", "production matrix did not PASS", failures)
    require(matrix.get("failures") in ([], None), "production matrix has failures", failures)
    matrix_harness = repo_root / "game/tests/orison_v2_m11c2_production_matrix.gd"
    matrix_harness_sha256 = sha256(matrix_harness)
    require(
        matrix.get("matrix_harness_sha256") == matrix_harness_sha256,
        "production matrix receipt is stale for the current matrix harness",
        failures,
    )

    legacy = parts["legacy"].get("matched_modes", {}).get("legacy_monolith", {})
    cells = parts["cells"].get("matched_modes", {}).get("owner_first_cells", {})
    route = parts["route"].get("owner_first_route", {})
    route_control = parts["route_control"].get("legacy_route_control", {})
    for key, packet_row in (
        ("legacy", legacy),
        ("cells", cells),
        ("route", route),
        ("route_control", route_control),
    ):
        require(packet_row.get("status") == "PASS", f"{key} packet did not PASS", failures)

    legacy_frames = legacy.get("frames", [])
    cells_frames = cells.get("frames", [])
    route_frames = route.get("frames", [])
    require(len(legacy_frames) == EXPECTED_PAIR_COUNT, "legacy frame count is not five", failures)
    require(len(cells_frames) == EXPECTED_PAIR_COUNT, "cell frame count is not five", failures)
    require(len(route_frames) == EXPECTED_ROUTE_COUNT, "route frame count is not nine", failures)
    require(route.get("initial_placement_count") == 1, "route initial placement count changed", failures)
    require(route.get("intermediate_transform_writes") == 0, "route has transform writes", failures)
    require(route.get("teleports") == 0, "route used teleports", failures)
    require(route.get("noclip") is False, "route used noclip", failures)
    require(route_control.get("frame_count") == EXPECTED_ROUTE_COUNT, "legacy route control frame count differs", failures)
    require(route_control.get("initial_placement_count") == 1, "legacy route control placement count changed", failures)
    require(route_control.get("intermediate_transform_writes") == 0, "legacy route control has transform writes", failures)
    require(route_control.get("teleports") == 0, "legacy route control used teleports", failures)
    require(route_control.get("noclip") is False, "legacy route control used noclip", failures)
    route_facts = route.get("initial_simulation_facts", {})
    control_facts = route_control.get("initial_simulation_facts", {})
    route_fact_hash = route.get("initial_simulation_facts_sha256", "")
    control_fact_hash = route_control.get("initial_simulation_facts_sha256", "")
    require(bool(route_fact_hash), "cell route initial simulation hash is empty", failures)
    require(route_fact_hash == control_fact_hash, "legacy/cell route initial simulation hashes differ", failures)
    require(canonical(route_facts) == canonical(control_facts), "legacy/cell route initial simulation facts differ", failures)
    require(route_fact_hash == legacy.get("simulation_facts_sha256", ""), "route and matched captures did not start from the same facts", failures)
    normalized_route: dict[str, Any] = {"schema_valid": False}
    normalized_control: dict[str, Any] = {"schema_valid": False}
    try:
        normalized_route = route_contract(route)
    except ValueError as error:
        failures.append(f"cell route contract schema is invalid: {error}")
    try:
        normalized_control = route_contract(route_control)
    except ValueError as error:
        failures.append(f"legacy route contract schema is invalid: {error}")
    route_comparison = compare_route_contracts(normalized_route, normalized_control)
    require(
        route_comparison["semantic_match"],
        "legacy/cell normalized route contracts differ",
        failures,
    )

    route_end_facts = route.get("route_end_simulation_facts", {})
    control_end_facts = route_control.get("route_end_simulation_facts", {})
    route_end_hash = route.get("route_end_simulation_facts_sha256", "")
    control_end_hash = route_control.get("route_end_simulation_facts_sha256", "")
    require(bool(route_end_hash), "cell route end simulation hash is empty", failures)
    require(
        route_end_hash == control_end_hash,
        "legacy/cell route end simulation hashes differ",
        failures,
    )
    require(
        canonical(route_end_facts) == canonical(control_end_facts),
        "legacy/cell route end simulation facts differ",
        failures,
    )

    legacy_facts = legacy.get("simulation_facts", {})
    cells_facts = cells.get("simulation_facts", {})
    legacy_fact_hash = legacy.get("simulation_facts_sha256", "")
    cells_fact_hash = cells.get("simulation_facts_sha256", "")
    require(bool(legacy_fact_hash), "legacy simulation hash is empty", failures)
    require(legacy_fact_hash == cells_fact_hash, "matched simulation hashes differ", failures)
    require(canonical(legacy_facts) == canonical(cells_facts), "matched simulation facts differ", failures)
    legacy_end_facts = legacy.get("capture_end_simulation_facts", {})
    cells_end_facts = cells.get("capture_end_simulation_facts", {})
    legacy_end_hash = legacy.get("capture_end_simulation_facts_sha256", "")
    cells_end_hash = cells.get("capture_end_simulation_facts_sha256", "")
    require(bool(legacy_end_hash), "legacy capture end simulation hash is empty", failures)
    require(
        legacy_end_hash == cells_end_hash,
        "matched capture end simulation hashes differ",
        failures,
    )
    require(
        canonical(legacy_end_facts) == canonical(cells_end_facts),
        "matched capture end simulation facts differ",
        failures,
    )

    pairs: list[dict[str, Any]] = []
    for index, (first, second) in enumerate(zip(legacy_frames, cells_frames)):
        pair_id = str(first.get("id", f"pair_{index + 1}"))
        require(first.get("status") == "PASS", f"legacy {pair_id} failed", failures)
        require(second.get("status") == "PASS", f"cells {pair_id} failed", failures)
        require(first.get("id") == second.get("id"), f"pair {index + 1} id differs", failures)
        require(first.get("seam_id") == second.get("seam_id"), f"{pair_id} seam differs", failures)
        camera_exact = canonical(first.get("camera", {})) == canonical(second.get("camera", {}))
        dimensions_exact = first.get("dimensions") == second.get("dimensions") == EXPECTED_SIZE
        require(camera_exact, f"{pair_id} camera differs", failures)
        require(dimensions_exact, f"{pair_id} dimensions differ", failures)
        first_path = resolve_image(str(first.get("png", "")), repo_root)
        second_path = resolve_image(str(second.get("png", "")), repo_root)
        for label, frame, path in (("legacy", first, first_path), ("cells", second, second_path)):
            require(path.is_file(), f"{pair_id} {label} PNG missing", failures)
            if path.is_file():
                require(sha256(path) == frame.get("png_sha256"), f"{pair_id} {label} hash differs", failures)
        difference = image_difference(first_path, second_path) if first_path.is_file() and second_path.is_file() else {}
        pairs.append(
            {
                "id": pair_id,
                "seam_id": first.get("seam_id", ""),
                "legacy_png": first_path.as_posix(),
                "legacy_sha256": first.get("png_sha256", ""),
                "cells_png": second_path.as_posix(),
                "cells_sha256": second.get("png_sha256", ""),
                "camera_exact": camera_exact,
                "dimensions_exact": dimensions_exact,
                "pixel_difference": difference,
                "human_review_required": True,
            }
        )

    for frame in route_frames:
        path = resolve_image(str(frame.get("png", "")), repo_root)
        require(frame.get("status") == "PASS", f"route frame {frame.get('label')} failed", failures)
        require(frame.get("dimensions") == EXPECTED_SIZE, f"route frame {frame.get('label')} size differs", failures)
        require(path.is_file(), f"route frame {frame.get('label')} missing", failures)
        if path.is_file():
            require(sha256(path) == frame.get("png_sha256"), f"route frame {frame.get('label')} hash differs", failures)

    diagnostics = {key: log_diagnostics(path) for key, path in logs.items()}
    for key, row in diagnostics.items():
        require(row["unknown_error_count"] == 0, f"{key} log has unknown errors", failures)
    legacy_signatures = diagnostics["legacy"]["known_signature_set"]
    cells_signatures = diagnostics["cells"]["known_signature_set"]
    require(legacy_signatures == cells_signatures, "legacy/cell renderer error signatures differ", failures)
    route_signatures = diagnostics["route"]["known_signature_set"]
    control_signatures = diagnostics["route_control"]["known_signature_set"]
    require(route_signatures == control_signatures, "legacy/cell route renderer error signatures differ", failures)
    for key in KNOWN_RUNTIME_ERRORS:
        require(
            diagnostics["legacy"]["known_runtime_debt_counts"].get(key, 0)
            == diagnostics["cells"]["known_runtime_debt_counts"].get(key, 0),
            f"legacy/cell matched {key} debt count differs",
            failures,
        )
        require(
            diagnostics["route_control"]["known_runtime_debt_counts"].get(key, 0)
            == diagnostics["route"]["known_runtime_debt_counts"].get(key, 0),
            f"legacy/cell route {key} debt count differs",
            failures,
        )
    count_delta = {
        key: diagnostics["cells"]["known_signature_counts"].get(key, 0)
        - diagnostics["legacy"]["known_signature_counts"].get(key, 0)
        for key in KNOWN_RENDER_ERRORS
    }
    route_count_delta = {
        key: diagnostics["route"]["known_signature_counts"].get(key, 0)
        - diagnostics["route_control"]["known_signature_counts"].get(key, 0)
        for key in KNOWN_RENDER_ERRORS
    }

    result = {
        "schema": "orison.m11c2.production-matched-capture.v2",
        "task": "ORISON-V2-M11C2",
        "status": "PASS" if not failures else "FAIL",
        "failures": failures,
        "process_isolation": {
            "one_complete_production_root_per_process": True,
            "phases": expected_phases,
            "reason": "avoid replacing a fully lit Forward+ production root inside one renderer process",
            "provider_is_session_only_and_absent_from_save": True,
        },
        "capture_harness": {
            "path": harness_path.as_posix(),
            "sha256": harness_sha256,
            "all_parts_exact": all(
                parts[key].get("capture_harness_sha256") == harness_sha256
                for key in expected_phases
            ),
        },
        "inputs": {
            key: {"path": path.as_posix(), "sha256": sha256(path)}
            for key, path in inputs.items()
        },
        "matched_modes": {"legacy_monolith": legacy, "owner_first_cells": cells},
        "matched_simulation_state": {
            "initial_exact": exact_simulation_facts(
                legacy_facts, legacy_fact_hash, cells_facts, cells_fact_hash
            ),
            "initial_sha256": legacy_fact_hash,
            "initial_facts": legacy_facts,
            "capture_end_exact": exact_simulation_facts(
                legacy_end_facts, legacy_end_hash, cells_end_facts, cells_end_hash
            ),
            "capture_end_sha256": legacy_end_hash,
            "capture_end_facts": legacy_end_facts,
            "fixed_through_public_campaign_clock": True,
        },
        "matched_pairs": pairs,
        "owner_first_route": route,
        "legacy_route_control": {
            "receipt": inputs["route_control"].as_posix(),
            "normalized_contract": normalized_control,
            "exact_contract_match": canonical(normalized_route)
            == canonical(normalized_control),
            "semantic_contract_match": route_comparison["semantic_match"],
            "contract_comparison": route_comparison,
            "initial_simulation_facts_match": exact_simulation_facts(
                route_facts, route_fact_hash, control_facts, control_fact_hash
            ),
            "end_simulation_facts_match": exact_simulation_facts(
                route_end_facts, route_end_hash, control_end_facts, control_end_hash
            ),
            "end_simulation_facts_sha256": route_end_hash,
            "human_packet": False,
        },
        "capture_counts": {"matched_frames": 10, "route_frames": len(route_frames), "total": 10 + len(route_frames)},
        "renderer_diagnostics": {
            "classification": "historical Godot 4.7 Forward+ visibility and process-retirement light/geometry unpair diagnostic",
            "technical_lifecycle_gate": False,
            "new_error_signatures": [],
            "legacy_cell_signature_sets_equal": legacy_signatures == cells_signatures,
            "cell_minus_legacy_known_signature_counts": count_delta,
            "legacy_cell_route_signature_sets_equal": route_signatures == control_signatures,
            "cell_route_minus_legacy_route_known_signature_counts": route_count_delta,
            "parts": diagnostics,
            "resident_nav_debt": {
                "classification": "open pre-existing production navigation debt",
                "identity": KNOWN_RUNTIME_ERRORS["resident_nav_wall_safe_route"],
                "provider_count_parity_required": True,
                "technical_cut_gate": False,
            },
        },
        "lifecycle_authority": {
            "receipt": inputs["matrix"].as_posix(),
            "sha256": sha256(inputs["matrix"]),
            "status": matrix.get("status"),
            "tracked_production_cut_owner_retention_gate": True,
            "capture_process_is_not_used_as_teardown_proof": True,
            "matrix_harness": matrix_harness.as_posix(),
            "matrix_harness_sha256": matrix_harness_sha256,
            "matrix_receipt_source_bound": matrix.get("matrix_harness_sha256")
            == matrix_harness_sha256,
        },
        "capture_boundary": {
            "production_root_through_selector": True,
            "production_player_and_camera": True,
            "harness_added_geometry": False,
            "harness_added_collision": False,
            "harness_added_lights": False,
            "harness_added_world_environment": False,
            "harness_added_labels_arrows_or_seam_covers": False,
            "capture_collision_changes": False,
            "render_node_mutation": False,
            "provider_teardown_during_capture": False,
        },
        "human_review": {
            "status": "PENDING",
            "question": "Do the matched legacy/cell seams and the complete owner-first player route preserve the same world without cracks, doubled surfaces, missing detail, material or lighting discontinuities, or incorrect facade/interior ownership?",
        },
    }
    output = receipts / "m11c2_production_capture_receipt.json"
    output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"M11C2 capture merge: {result['status']} pairs={len(pairs)} route={len(route_frames)}")
    print(f"receipt: {output}")
    if failures:
        for failure in failures:
            print(f"FAIL: {failure}")
    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
