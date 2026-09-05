#!/usr/bin/env python3
"""Partition a provenance-bearing candidate and prove protected equivalence.

The protected ``floor_01.gltf`` is comparison-only.  This module never tries
to infer ownership from its node names, bounds, positions, centroids, or
connected components.  Ownership is accepted only from a generation-time
lineage document whose sources were resolved against the authoritative
all-source ownership catalog before geometry was emitted.

The candidate is already batched by ``owner_cell`` before material.  This
module validates that invariant, compacts whole candidate nodes into the 17
declared cells, emits deterministic source/primitive/triangle lineage, and
compares referenced vertex and triangle payloads against the protected legacy
monolith.  Descriptor-byte identity is deliberately not required because
node, accessor, and index ordinals legitimately change during rebatching.
"""

from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import copy
import hashlib
import json
import math
from pathlib import Path, PurePosixPath
import struct
import sys
from typing import Any, Iterable


REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tools.rehearse_orison_floor01_partition import (  # noqa: E402
    AssetView,
    Canonicalizer,
    GeneratedCell,
    RehearsalError,
    _copy_shared_textures,
    _node_matrix,
    _safe_relative_uri,
    _sha256_file,
    _transform_point,
    build_cells,
    load_asset,
    node_world_bounds,
    validate_source,
    verify_recomposition,
)
from tools.m11c1_floor01_owner_first.source_ownership import (  # noqa: E402
    OWNER_CELLS,
    load_source_ownership,
    source_record_sha256,
)


SCHEMA_CANDIDATE_LINEAGE = "orison.floor01.generated-owner-lineage.v1"
SCHEMA_LINEAGE = "orison.floor01.owner-first-lineage.v1"
SCHEMA_PARTITION = "orison.floor01.owner-first-partition.v1"
SCHEMA_EQUIVALENCE = "orison.floor01.owner-first-equivalence.v1"
SCHEMA_EXPORT = "orison.floor01.owner-first-export.v1"
SCHEMA_TRANSACTION = "orison.floor01.owner-first-transaction.v1"

ORCHESTRATOR_RECEIPT_SCHEMAS = {
    "candidate/blender_generation_process.json": (
        "orison.floor01.owner-first-blender-process.v1"),
    "receipts/protected_assets.json": (
        "orison.floor01.owner-first-protection.v1"),
}

CELL_IDS = tuple(OWNER_CELLS)
INTERIOR = "CELL_ORISON_F01_INTERIOR"
FACADE = "CELL_ORISON_FACADE_SHELL"
STREET = "CELL_SITE_STREET_COMMON"
PASSAGE = "CELL_PASSAGE"
BAR = "CELL_SHOP_BAR"
BODEGA = "CELL_SHOP_BODEGA"
CELL_SLUGS = {
    cell_id: cell_id.lower().removeprefix("cell_")
    for cell_id in CELL_IDS
}

COLLISION_NONE = "NONE"
COLLISION_VISIBLE = "VISIBLE_TRIMESH"
COLLISION_ONLY = "COLLISION_ONLY_TRIMESH"
COLLISION_CLASSES = {
    COLLISION_NONE, COLLISION_VISIBLE, COLLISION_ONLY,
}

EXPECTED_SUPPLEMENTAL_GENERATED_SOURCES = (
    {
        "source_id": "F01_GENERATED_STAIR_ATRIUM",
        "source_locator": "stairs[atrium]",
        "owner_cell": INTERIOR,
        "identity_origin": "AUTHORED_STAIR_ID",
        "authoring_context": "F01_ATRIUM_VERTICAL_CIRCULATION",
    },
    {
        "source_id": "F01_GENERATED_FACADE_RAINWATER",
        "source_locator": "generator[build_facade_details].facade_rainwater",
        "owner_cell": FACADE,
        "identity_origin": "GENERATOR_SEMANTIC_ID",
        "authoring_context": "F01_FACADE_RAINWATER_GOODS",
    },
    {
        "source_id": "F01_GENERATED_TRAFFIC_WEAR",
        "source_locator": "generator[build_wear_decals].F01_traffic",
        "owner_cell": INTERIOR,
        "identity_origin": "GENERATOR_SEMANTIC_ID",
        "authoring_context": "F01_COMMON_CIRCULATION_TRAFFIC_WEAR",
    },
)

# This authored record is intentionally inert in the protected generator: its
# Y endpoints are reversed, so MeshBuf.add_box rejects it before adding any
# vertex or face.  Bind the exact source identity/hash so this cannot become a
# general zero-emission escape hatch.
EXPECTED_AUTHORED_ZERO_GEOMETRY = {
    "floors[F01].furniture[2802]": {
        "source_id": "retail_bar_darts_door-1",
        "source_record_sha256": (
            "7d57328baefada5850414ff24386b0b0702039a585e631b4fd0373dc51ae3cc0"),
        "reason": "AUTHORED_DEGENERATE_BOX_REJECTED_BY_GENERATOR",
    },
}

COMPONENTS = {
    5120: ("b", 1),
    5121: ("B", 1),
    5122: ("h", 2),
    5123: ("H", 2),
    5125: ("I", 4),
    5126: ("f", 4),
}
TYPE_COMPONENTS = {
    "SCALAR": 1,
    "VEC2": 2,
    "VEC3": 3,
    "VEC4": 4,
    "MAT2": 4,
    "MAT3": 9,
    "MAT4": 16,
}


class OwnerFirstError(RuntimeError):
    """Fail-closed provenance, batching, or equivalence violation."""


def canonical_bytes(value: Any) -> bytes:
    return json.dumps(
        value, sort_keys=True, separators=(",", ":"), ensure_ascii=False,
        allow_nan=False,
    ).encode("utf-8")


def canonical_hash(value: Any) -> str:
    return hashlib.sha256(canonical_bytes(value)).hexdigest()


def bytes_hash(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(value, indent=2, ensure_ascii=False, allow_nan=False) + "\n",
        encoding="utf-8",
    )


def load_json(path: Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise OwnerFirstError(f"could not read {label} {path}: {error}") from error
    if not isinstance(value, dict):
        raise OwnerFirstError(f"{label} root must be an object")
    return value


def collision_class_for_name(name: str) -> str:
    if name.endswith("-colonly"):
        return COLLISION_ONLY
    if name.endswith("-col"):
        return COLLISION_VISIBLE
    return COLLISION_NONE


def _safe_slug(value: str) -> bool:
    return bool(value) and all(
        character in "abcdefghijklmnopqrstuvwxyz0123456789_-"
        for character in value
    )


def validate_catalog_rows(
        records_by_locator: dict[str, dict[str, Any]]) -> dict[str, dict[str, Any]]:
    """Validate the normalized result of ``load_source_ownership``.

    The source-ownership reader remains the authority for record hashes and
    the protected layout digest.  This second boundary check makes it
    impossible for an accidental partial/differently-shaped mapping to enter
    the Blender process or the lineage receipt.
    """

    if not isinstance(records_by_locator, dict) or not records_by_locator:
        raise OwnerFirstError("source ownership catalog is empty or not a mapping")
    by_id: dict[str, dict[str, Any]] = {}
    normalized: dict[str, dict[str, Any]] = {}
    for locator, source in records_by_locator.items():
        if not isinstance(locator, str) or not locator:
            raise OwnerFirstError("source ownership locator must be non-empty")
        if not isinstance(source, dict):
            raise OwnerFirstError(f"ownership row {locator!r} must be an object")
        if str(source.get("source_locator", "")) != locator:
            raise OwnerFirstError(
                f"ownership mapping key disagrees with row locator {locator!r}")
        source_id = str(source.get("source_id", ""))
        owner = str(source.get("owner_cell", ""))
        collection = str(source.get("collection", ""))
        digest = str(source.get("source_record_sha256", ""))
        if not source_id or source_id in by_id:
            raise OwnerFirstError(
                f"source ID is missing or duplicated at {locator}: {source_id!r}")
        if owner not in CELL_IDS:
            raise OwnerFirstError(
                f"source {source_id} names undeclared owner_cell {owner!r}")
        if not collection:
            raise OwnerFirstError(f"source {source_id} has no collection")
        if len(digest) != 64 or any(c not in "0123456789abcdef" for c in digest):
            raise OwnerFirstError(
                f"source {source_id} has malformed source_record_sha256")
        if not str(source.get("identity_origin", "")):
            raise OwnerFirstError(f"source {source_id} has no identity_origin")
        if not source.get("authoring_context"):
            raise OwnerFirstError(f"source {source_id} has no authoring_context")
        row = copy.deepcopy(source)
        normalized[locator] = row
        by_id[source_id] = row
    return normalized


def _primitive_triangle_count(asset: AssetView, mesh: int, primitive: int) -> int:
    value = asset.document["meshes"][mesh]["primitives"][primitive]
    mode = int(value.get("mode", 4))
    if mode != 4:
        raise OwnerFirstError(
            f"mesh {mesh} primitive {primitive} mode {mode} is not TRIANGLES")
    if "indices" in value:
        count = int(asset.document["accessors"][int(value["indices"])]["count"])
    else:
        position = int(value["attributes"]["POSITION"])
        count = int(asset.document["accessors"][position]["count"])
    if count % 3:
        raise OwnerFirstError(
            f"mesh {mesh} primitive {primitive} has non-triangular count {count}")
    return count // 3


def _require_range(
        value: Any, label: str, expected_start: int) -> tuple[int, int]:
    if not isinstance(value, dict):
        raise OwnerFirstError(f"{label} must be an object")
    try:
        start = int(value["start"])
        count = int(value["count"])
    except (KeyError, TypeError, ValueError) as error:
        raise OwnerFirstError(f"{label} requires integer start/count") from error
    if start != expected_start or count <= 0:
        raise OwnerFirstError(
            f"{label} is not contiguous/non-empty: expected start "
            f"{expected_start}, got {start}+{count}")
    return start, count


def _validate_expected_input_bindings(
        inputs: dict[str, Any], producer: dict[str, Any],
        expected_input_bindings: dict[str, dict[str, str]]) -> None:
    """Validate exact nested path/hash bindings, including the producer adapter."""

    for label, expected in expected_input_bindings.items():
        actual = producer.get("adapter") if label == "adapter" else inputs.get(label)
        if not isinstance(actual, dict):
            raise OwnerFirstError(f"generated lineage lacks {label} input binding")
        if (str(actual.get("path", "")) != str(expected["path"])
                or str(actual.get("sha256", "")) != str(expected["sha256"])):
            raise OwnerFirstError(f"generated lineage {label} binding drifted")


def validate_generation_lineage(
        candidate: AssetView,
        lineage: dict[str, Any],
        catalog_by_locator: dict[str, dict[str, Any]],
        authoritative_layout: dict[str, Any],
        expected_input_bindings: dict[str, dict[str, str]],
) -> dict[str, Any]:
    """Validate owner/material batches and every generation-time range."""

    if lineage.get("schema") != SCHEMA_CANDIDATE_LINEAGE:
        raise OwnerFirstError(
            f"generated lineage schema must be {SCHEMA_CANDIDATE_LINEAGE}")
    if lineage.get("spatial_inference_used") is not False:
        raise OwnerFirstError("generated lineage must assert spatial_inference_used=false")
    if lineage.get("status") != "PASS":
        raise OwnerFirstError("generated lineage is not slice-bound PASS")
    declared = lineage.get("declared_owner_cells")
    if declared != list(CELL_IDS):
        raise OwnerFirstError("generated lineage does not declare canonical 17 cells")

    catalog = validate_catalog_rows(catalog_by_locator)
    catalog_by_id = {row["source_id"]: row for row in catalog.values()}
    generated_sources = lineage.get("generated_sources", [])
    if not isinstance(generated_sources, list):
        raise OwnerFirstError("generated_sources must be an array")
    if generated_sources != [copy.deepcopy(row)
                             for row in EXPECTED_SUPPLEMENTAL_GENERATED_SOURCES]:
        raise OwnerFirstError(
            "generated_sources differs from fixed audited supplemental vocabulary")

    inputs = lineage.get("authoritative_inputs")
    producer = lineage.get("producer")
    if not isinstance(inputs, dict) or not isinstance(producer, dict):
        raise OwnerFirstError("generated lineage lacks authoritative input/producer binding")
    if producer.get("mode") != "BLENDER_AUTHORITATIVE_HELPER_REPLAY":
        raise OwnerFirstError("generated lineage producer mode is not audited")
    if producer.get("protected_gltf_input") is not False:
        raise OwnerFirstError("candidate producer must assert protected_gltf_input=false")
    if (producer.get("protected_bin_input") is not False
            or producer.get("runtime_layout_mirror_input") is not False
            or producer.get("authoritative_layout_input") is not True):
        raise OwnerFirstError("candidate producer protected/read input policy drifted")
    if producer.get("output_policy") != "DISPOSABLE_ROOT_ONLY":
        raise OwnerFirstError("candidate producer output policy is not disposable-only")
    command = producer.get("command_contract")
    if (not isinstance(command, list)
            or any("protected" in str(value).lower() and "ownership" not in str(value).lower()
                   for value in command)):
        raise OwnerFirstError("candidate producer command admits a protected asset input")
    _validate_expected_input_bindings(inputs, producer, expected_input_bindings)
    compatibility_inputs = producer.get("compatibility_texture_inputs")
    if not isinstance(compatibility_inputs, list) or len(compatibility_inputs) != 30:
        raise OwnerFirstError(
            "candidate must bind exactly 30 F01 legacy compatibility texture maps")
    expected_compatibility = {
        (
            (REPO_ROOT / "art/textures/wall_finishes" / f"f01_w{index:02d}" /
             f"{kind}.png").resolve(),
            (REPO_ROOT / "game/assets/building/textures" /
             f"T_wallfinish_f01_w{index:02d}_{kind}.png").resolve(),
        )
        for index in range(10)
        for kind in ("albedo", "roughness", "normal")
    }
    seen_compatibility: set[tuple[Path, Path]] = set()
    for row in compatibility_inputs:
        if not isinstance(row, dict):
            raise OwnerFirstError("compatibility texture input must be an object")
        requested = Path(str(row.get("requested_authoring_path", ""))).resolve()
        source = Path(str(row.get("compatibility_source_path", ""))).resolve()
        staged = Path(str(row.get("staged_path", ""))).resolve()
        key = (requested, source)
        if key not in expected_compatibility or key in seen_compatibility:
            raise OwnerFirstError(
                f"unruled/duplicated compatibility texture input {key}")
        if row.get("identity") != "LEGACY_COMPATIBILITY_TEXTURE_INPUT" \
                or row.get("read_only") is not True:
            raise OwnerFirstError("compatibility texture identity/policy drifted")
        if requested.is_file() and _sha256_file(requested) != _sha256_file(source):
            raise OwnerFirstError(
                f"authoring wall finish differs from compatibility source {requested}")
        if not source.is_file() or not staged.is_file():
            raise OwnerFirstError("compatibility source/staged file is missing")
        source_hash = _sha256_file(source)
        staged_hash = _sha256_file(staged)
        if (str(row.get("source_sha256", "")) != source_hash
                or str(row.get("staged_sha256", "")) != staged_hash
                or source_hash != staged_hash):
            raise OwnerFirstError("compatibility source/staged texture hash drifted")
        seen_compatibility.add(key)
    if seen_compatibility != expected_compatibility:
        raise OwnerFirstError("compatibility texture vocabulary is incomplete")
    source_debt = producer.get("open_rebuild_source_debt")
    if (not isinstance(source_debt, list) or len(source_debt) != 1
            or source_debt[0].get("code")
            != "F01_WALL_FINISH_AUTHORING_ID_SCHEME_MISMATCH"
            or source_debt[0].get("status") != "OPEN"):
        raise OwnerFirstError("wall-finish rebuild-source debt is not explicit")
    supplemental_by_id: dict[str, dict[str, Any]] = {}
    for index, source in enumerate(generated_sources):
        if not isinstance(source, dict):
            raise OwnerFirstError(f"generated source {index} must be an object")
        source_id = str(source.get("source_id", ""))
        owner = str(source.get("owner_cell", ""))
        if not source_id or source_id in supplemental_by_id or source_id in catalog_by_id:
            raise OwnerFirstError(
                f"generated source ID is missing/duplicated: {source_id!r}")
        if owner not in CELL_IDS:
            raise OwnerFirstError(
                f"generated source {source_id} has unknown owner {owner!r}")
        if not source.get("authoring_context"):
            raise OwnerFirstError(
                f"generated source {source_id} lacks authoring_context")
        supplemental_by_id[source_id] = copy.deepcopy(source)
    all_sources = dict(catalog_by_id)
    all_sources.update(supplemental_by_id)

    buffers = lineage.get("buffers")
    if not isinstance(buffers, list) or not buffers:
        raise OwnerFirstError("generated lineage buffers must be a non-empty array")
    nodes = candidate.document.get("nodes", [])
    meshes = candidate.document.get("meshes", [])
    node_by_name: dict[str, int] = {}
    for node_index, node in enumerate(nodes):
        name = str(node.get("name", ""))
        if not name or name in node_by_name:
            raise OwnerFirstError(f"candidate node name missing/duplicated: {name!r}")
        node_by_name[name] = node_index

    seen_names: set[str] = set()
    seen_buffer_ids: set[str] = set()
    assignments: list[dict[str, Any]] = []
    contributions: list[dict[str, Any]] = []
    batch_keys: list[tuple[int, str, str, str]] = []
    emission_counts: Counter[str] = Counter()
    triangle_payload_cache: dict[tuple[int, int], list[str]] = {}
    for buffer_order, buffer in enumerate(buffers):
        if not isinstance(buffer, dict):
            raise OwnerFirstError(f"generated buffer {buffer_order} must be an object")
        buffer_id = str(buffer.get("buffer_id", ""))
        object_name = str(buffer.get("object_name", ""))
        owner = str(buffer.get("owner_cell", ""))
        material = str(buffer.get("material", ""))
        collision = str(buffer.get("collision_class", ""))
        legacy_identity = str(buffer.get("legacy_compatibility_identity", ""))
        if not buffer_id or buffer_id in seen_buffer_ids:
            raise OwnerFirstError(f"buffer ID missing/duplicated: {buffer_id!r}")
        if not object_name or object_name in seen_names or object_name not in node_by_name:
            raise OwnerFirstError(
                f"buffer object missing/duplicated/not exported: {object_name!r}")
        if owner not in CELL_IDS:
            raise OwnerFirstError(f"buffer {buffer_id} has unknown owner {owner!r}")
        if not material or not legacy_identity:
            raise OwnerFirstError(
                f"buffer {buffer_id} lacks material or legacy identity")
        if collision not in COLLISION_CLASSES:
            raise OwnerFirstError(
                f"buffer {buffer_id} has unknown collision class {collision!r}")
        if collision_class_for_name(object_name) != collision:
            raise OwnerFirstError(
                f"buffer {buffer_id} breaks -col/-colonly importer contract")
        if collision_class_for_name(legacy_identity) != collision:
            raise OwnerFirstError(
                f"buffer {buffer_id} collision differs from legacy identity")

        node_index = node_by_name[object_name]
        mesh_index = int(nodes[node_index]["mesh"])
        primitives = meshes[mesh_index].get("primitives", [])
        if len(primitives) != 1:
            raise OwnerFirstError(
                f"owner/material buffer {buffer_id} must export one primitive")
        primitive = primitives[0]
        if "material" not in primitive:
            raise OwnerFirstError(f"buffer {buffer_id} primitive has no material")
        material_name = str(candidate.document["materials"][
            int(primitive["material"])].get("name", ""))
        if material_name not in {material, f"M_{material}"}:
            raise OwnerFirstError(
                f"buffer {buffer_id} material {material_name!r} != {material!r}")

        buffer_contributions = buffer.get("contributions")
        if not isinstance(buffer_contributions, list) or not buffer_contributions:
            raise OwnerFirstError(f"buffer {buffer_id} has no contributions")
        vertex_cursor = polygon_cursor = triangle_cursor = 0
        for contribution_order, contribution in enumerate(buffer_contributions):
            if not isinstance(contribution, dict):
                raise OwnerFirstError(
                    f"buffer {buffer_id} contribution {contribution_order} is invalid")
            source_id = str(contribution.get("source_id", ""))
            source_locator = str(contribution.get("source_locator", ""))
            emission_kind = str(contribution.get("emission_kind", ""))
            if source_id not in all_sources:
                raise OwnerFirstError(
                    f"contribution names unknown source ID {source_id!r}")
            authority = all_sources[source_id]
            if source_id in catalog_by_id:
                if source_locator != str(authority.get("source_locator", "")):
                    raise OwnerFirstError(
                        f"source locator mismatch for {source_id}: {source_locator!r}")
            elif source_locator != str(authority.get("source_locator", "")):
                raise OwnerFirstError(
                    f"generated source locator mismatch for {source_id}")
            if owner != str(authority.get("owner_cell", "")):
                raise OwnerFirstError(
                    f"contribution {source_id} owner differs from authoring authority")
            for field, expected in (
                    ("owner_cell", owner),
                    ("material", material),
                    ("collision_class", collision),
                    ("legacy_compatibility_identity", legacy_identity)):
                if str(contribution.get(field, "")) != expected:
                    raise OwnerFirstError(
                        f"contribution {source_id} {field} differs from buffer")
            if not emission_kind:
                raise OwnerFirstError(
                    f"contribution {source_id} lacks emission_kind")
            generated_range = contribution.get("generated_range")
            if not isinstance(generated_range, dict):
                raise OwnerFirstError(
                    f"contribution {source_id} lacks generated_range")
            _, vertex_count = _require_range(
                generated_range.get("vertices"),
                f"{buffer_id}/{source_id} vertex range", vertex_cursor)
            _, polygon_count = _require_range(
                generated_range.get("polygons"),
                f"{buffer_id}/{source_id} polygon range", polygon_cursor)
            _, triangle_count = _require_range(
                generated_range.get("triangles"),
                f"{buffer_id}/{source_id} triangle range", triangle_cursor)
            primitive_key = (mesh_index, 0)
            if primitive_key not in triangle_payload_cache:
                triangle_payload_cache[primitive_key] = (
                    primitive_triangle_payload_hashes(candidate, mesh_index, 0))
            triangle_end = triangle_cursor + triangle_count
            expected_slice_hash = canonical_hash(
                triangle_payload_cache[primitive_key][triangle_cursor:triangle_end])
            if str(contribution.get(
                    "post_export_triangle_payload_sha256", "")) \
                    != expected_slice_hash:
                raise OwnerFirstError(
                    f"contribution {source_id} triangle range does not match "
                    "its decoded post-export slice")
            row = copy.deepcopy(contribution)
            row.update({
                "candidate": {
                    "buffer_id": buffer_id,
                    "node_index": node_index,
                    "mesh_index": mesh_index,
                    "primitive_index": 0,
                    "triangle_start": triangle_cursor,
                    "triangle_count": triangle_count,
                },
                "generation_order": len(contributions),
            })
            row["lineage_id"] = "LINEAGE_" + canonical_hash({
                "buffer_id": buffer_id,
                "source_id": source_id,
                "emission_kind": emission_kind,
                "generated_range": generated_range,
            }).upper()
            contributions.append(row)
            emission_counts[source_id] += 1
            vertex_cursor += vertex_count
            polygon_cursor += polygon_count
            triangle_cursor += triangle_count
        actual_triangles = _primitive_triangle_count(candidate, mesh_index, 0)
        if triangle_cursor != actual_triangles:
            raise OwnerFirstError(
                f"buffer {buffer_id} lineage triangles={triangle_cursor} "
                f"but primitive has {actual_triangles}")
        declared_totals = buffer.get("generated_totals", {})
        expected_totals = {
            "vertices": vertex_cursor,
            "polygons": polygon_cursor,
            "triangles": triangle_cursor,
        }
        if declared_totals != expected_totals:
            raise OwnerFirstError(
                f"buffer {buffer_id} declared totals differ from ranges")

        cell_order = CELL_IDS.index(owner)
        batch_keys.append((cell_order, material, legacy_identity, buffer_id))
        assignments.append({
            "buffer_id": buffer_id,
            "node_index": node_index,
            "mesh_index": mesh_index,
            "primitive_indices": [0],
            "cell": owner,
            "material": material,
            "legacy_compatibility_identity": legacy_identity,
        })
        seen_names.add(object_name)
        seen_buffer_ids.add(buffer_id)

    if seen_names != set(node_by_name):
        missing = sorted(set(node_by_name) - seen_names)
        raise OwnerFirstError(
            f"candidate has nodes outside generated lineage: {missing[:8]}")
    if batch_keys != sorted(batch_keys):
        raise OwnerFirstError(
            "generated buffers are not ordered by owner_cell before material")
    if len(assignments) != len(nodes):
        raise OwnerFirstError("candidate node assignment is not exact-once")
    if len({row["mesh_index"] for row in assignments}) != len(meshes):
        raise OwnerFirstError("candidate mesh assignment is not exact-once")

    by_cell: dict[str, list[int]] = {cell_id: [] for cell_id in CELL_IDS}
    for row in assignments:
        by_cell[row["cell"]].append(row["node_index"])
    empty = [cell_id for cell_id, values in by_cell.items() if not values]
    if empty:
        raise OwnerFirstError(f"declared target cells own no candidate nodes: {empty}")

    source_records = []
    for locator, source in sorted(catalog.items()):
        row = copy.deepcopy(source)
        row["emitted_contribution_count"] = emission_counts[str(source["source_id"])]
        source_records.append(row)
    supplemental_records = []
    for source_id, source in sorted(supplemental_by_id.items()):
        row = copy.deepcopy(source)
        row["emitted_contribution_count"] = emission_counts[source_id]
        supplemental_records.append(row)
    unresolved = sorted(
        source_id for source_id in emission_counts if source_id not in all_sources)
    if unresolved:
        raise OwnerFirstError(f"unresolved generated lineage sources: {unresolved}")

    floors = authoritative_layout.get("floors")
    if not isinstance(floors, list):
        raise OwnerFirstError("authoritative layout floors must be an array")
    f01 = [floor for floor in floors
           if isinstance(floor, dict) and floor.get("id") == "F01"]
    if len(f01) != 1:
        raise OwnerFirstError("authoritative layout must contain exactly one F01")
    floor = f01[0]
    record_by_locator = catalog
    expected_emitting: set[str] = set()
    expected_zero: dict[str, str] = {}
    for collection in ("walls", "slabs", "rooms", "ceilings",
                       "vent_registers", "furniture"):
        records = floor.get(collection)
        if not isinstance(records, list):
            raise OwnerFirstError(f"F01 {collection} is not an array")
        for index, record in enumerate(records):
            locator = f"floors[F01].{collection}[{index}]"
            zero_rule = EXPECTED_AUTHORED_ZERO_GEOMETRY.get(locator)
            if zero_rule is None:
                expected_emitting.add(locator)
                continue
            catalog_row = record_by_locator[locator]
            if (collection != "furniture"
                    or catalog_row["source_id"] != zero_rule["source_id"]
                    or catalog_row["source_record_sha256"]
                    != zero_rule["source_record_sha256"]
                    or source_record_sha256(collection, record)
                    != zero_rule["source_record_sha256"]):
                raise OwnerFirstError(
                    f"authored zero-geometry rule identity drifted: {locator}")
            rectangle = record.get("rect") if isinstance(record, dict) else None
            if (not isinstance(rectangle, list) or len(rectangle) != 4
                    or not isinstance(record.get("h"), (int, float))
                    or min(float(rectangle[2]) - float(rectangle[0]),
                           float(rectangle[3]) - float(rectangle[1]),
                           float(record["h"])) >= 1e-4):
                raise OwnerFirstError(
                    f"authored zero-geometry record is no longer rejected: {locator}")
            expected_zero[locator] = str(zero_rule["reason"])
    for collection in ("site_lights", "sockets"):
        records = floor.get(collection)
        if not isinstance(records, list):
            raise OwnerFirstError(f"F01 {collection} is not an array")
        for index, _record in enumerate(records):
            expected_zero[f"floors[F01].{collection}[{index}]"] = (
                "SOURCE_ONLY_NO_FLOOR01_MESH_EMISSION")
    if not set(EXPECTED_AUTHORED_ZERO_GEOMETRY).issubset(expected_zero):
        raise OwnerFirstError("audited authored zero-geometry vocabulary is incomplete")
    markers = floor.get("markers")
    if not isinstance(markers, list):
        raise OwnerFirstError("F01 markers is not an array")
    for index, marker in enumerate(markers):
        locator = f"floors[F01].markers[{index}]"
        if (marker.get("kind") == "door" and marker.get("leaf") != "none") \
                or marker.get("kind") in {"radiator", "stove"}:
            expected_emitting.add(locator)
        else:
            expected_zero[locator] = "MARKER_HAS_NO_GENERATED_WEAR_OR_MESH"
    if set(record_by_locator) != expected_emitting | set(expected_zero):
        missing_policy = sorted(
            set(record_by_locator) - expected_emitting - set(expected_zero))
        unknown_policy = sorted(
            (expected_emitting | set(expected_zero)) - set(record_by_locator))
        raise OwnerFirstError(
            "emission coverage policy is not exact over source catalog: "
            f"missing={missing_policy[:8]} unknown={unknown_policy[:8]}")
    for row in source_records:
        locator = str(row["source_locator"])
        if locator in expected_emitting:
            row["emission_expectation"] = "REQUIRED_NONZERO"
        else:
            row["emission_expectation"] = "EXPLICIT_ZERO"
            row["zero_emission_reason"] = expected_zero[locator]
    coverage_failures = []
    for locator in sorted(expected_emitting):
        source_id = str(record_by_locator[locator]["source_id"])
        if emission_counts[source_id] <= 0:
            coverage_failures.append(f"{locator}: expected emission")
    for locator in sorted(expected_zero):
        source_id = str(record_by_locator[locator]["source_id"])
        if emission_counts[source_id] != 0:
            coverage_failures.append(f"{locator}: forbidden source-only emission")
    for source_id in supplemental_by_id:
        if emission_counts[source_id] <= 0:
            coverage_failures.append(f"{source_id}: supplemental source did not emit")
    if coverage_failures:
        raise OwnerFirstError(
            "source emission coverage failed: " + "; ".join(coverage_failures[:12]))

    cells = [{"id": cell_id, "slug": CELL_SLUGS[cell_id]}
             for cell_id in CELL_IDS]
    return {
        "cells": cells,
        "by_cell": by_cell,
        "assignments": assignments,
        "contributions": contributions,
        "source_records": source_records,
        "generated_sources": supplemental_records,
        "source_record_count": len(source_records),
        "generated_source_count": len(supplemental_records),
        "unresolved_lineage_records": unresolved,
        "batch_keys": [list(key) for key in batch_keys],
        "emission_coverage": {
            "status": "PASS",
            "required_emitting_records": len(expected_emitting),
            "explicit_zero_emission_records": len(expected_zero),
            "zero_emission_reasons": dict(Counter(expected_zero.values())),
            "supplemental_emitting_sources": len(supplemental_by_id),
            "failures": [],
        },
    }


class AccessorReader:
    """Read logical glTF accessor elements independent of buffer packing."""

    def __init__(self, asset: AssetView):
        self.asset = asset
        self.doc = asset.document
        self._cache: dict[int, tuple[dict[str, Any], list[bytes]]] = {}

    def read(self, accessor_index: int) -> tuple[dict[str, Any], list[bytes]]:
        if accessor_index in self._cache:
            return self._cache[accessor_index]
        try:
            accessor = self.doc["accessors"][accessor_index]
        except (KeyError, IndexError) as error:
            raise OwnerFirstError(f"invalid accessor index {accessor_index}") from error
        if accessor.get("sparse"):
            raise OwnerFirstError("sparse accessors require an audited payload reader")
        component_type = int(accessor.get("componentType", -1))
        accessor_type = str(accessor.get("type", ""))
        if component_type not in COMPONENTS or accessor_type not in TYPE_COMPONENTS:
            raise OwnerFirstError(
                f"unsupported accessor descriptor {component_type}/{accessor_type}")
        _format, component_size = COMPONENTS[component_type]
        component_count = TYPE_COMPONENTS[accessor_type]
        element_size = component_size * component_count
        view_index = int(accessor.get("bufferView", -1))
        if view_index < 0:
            raise OwnerFirstError(f"accessor {accessor_index} lacks bufferView")
        view = self.doc["bufferViews"][view_index]
        view_bytes = self.asset.view_bytes(view_index)
        start = int(accessor.get("byteOffset", 0))
        stride = int(view.get("byteStride", element_size))
        count = int(accessor.get("count", -1))
        if start < 0 or stride < element_size or count < 0:
            raise OwnerFirstError(f"invalid accessor {accessor_index} span")
        if count and start + (count - 1) * stride + element_size > len(view_bytes):
            raise OwnerFirstError(f"accessor {accessor_index} exceeds bufferView")
        elements = [
            view_bytes[start + index * stride:
                       start + index * stride + element_size]
            for index in range(count)
        ]
        schema = {
            "component_type": component_type,
            "type": accessor_type,
            "normalized": bool(accessor.get("normalized", False)),
            "element_bytes": element_size,
        }
        self._cache[accessor_index] = (schema, elements)
        return schema, elements

    def integers(self, accessor_index: int) -> list[int]:
        schema, elements = self.read(accessor_index)
        if schema["type"] != "SCALAR" or schema["component_type"] not in {
                5121, 5123, 5125}:
            raise OwnerFirstError(
                f"indices accessor {accessor_index} is not unsigned scalar")
        fmt = "<" + COMPONENTS[int(schema["component_type"])][0]
        return [int(struct.unpack(fmt, value)[0]) for value in elements]

    def floats(self, accessor_index: int) -> list[tuple[float, ...]]:
        schema, elements = self.read(accessor_index)
        if schema["component_type"] != 5126:
            raise OwnerFirstError(
                f"accessor {accessor_index} is not float payload")
        count = TYPE_COMPONENTS[str(schema["type"])]
        fmt = "<" + "f" * count
        return [tuple(map(float, struct.unpack(fmt, value))) for value in elements]


def primitive_triangle_payload_hashes(
        asset: AssetView, mesh_index: int, primitive_index: int) -> list[str]:
    """Return ordered, dereferenced per-corner hashes for one primitive."""

    reader = AccessorReader(asset)
    try:
        primitive = asset.document["meshes"][mesh_index]["primitives"][
            primitive_index]
    except (KeyError, IndexError) as error:
        raise OwnerFirstError(
            f"invalid primitive {mesh_index}/{primitive_index}") from error
    if int(primitive.get("mode", 4)) != 4:
        raise OwnerFirstError("triangle slice binding supports TRIANGLES only")
    attributes: dict[str, tuple[dict[str, Any], list[bytes]]] = {}
    vertex_count = None
    for semantic, accessor_index in sorted(primitive["attributes"].items()):
        schema, elements = reader.read(int(accessor_index))
        attributes[str(semantic)] = (schema, elements)
        if vertex_count is None:
            vertex_count = len(elements)
        elif vertex_count != len(elements):
            raise OwnerFirstError("primitive attribute counts differ")
    if vertex_count is None:
        raise OwnerFirstError("primitive has no vertex attributes")
    if "indices" in primitive:
        indices = reader.integers(int(primitive["indices"]))
    else:
        indices = list(range(vertex_count))
    if len(indices) % 3 or any(index < 0 or index >= vertex_count
                               for index in indices):
        raise OwnerFirstError("primitive indices are not valid triangles")
    canonicalizer = Canonicalizer(asset)
    material_hash = (
        canonicalizer.material(int(primitive["material"]))
        if "material" in primitive else "NO_MATERIAL"
    )
    vertex_hashes = []
    for vertex_index in range(vertex_count):
        vertex_hashes.append(canonical_hash({
            "material": material_hash,
            "attributes": {
                semantic: {
                    "schema": schema,
                    "payload_hex": elements[vertex_index].hex(),
                }
                for semantic, (schema, elements) in attributes.items()
            },
        }))
    return [
        canonical_hash({
            "material": material_hash,
            "ordered_vertices": [
                vertex_hashes[indices[offset + corner]] for corner in range(3)
            ],
        })
        for offset in range(0, len(indices), 3)
    ]


def _node_payload(asset: AssetView, node_index: int) -> dict[str, Any]:
    node = asset.document["nodes"][node_index]
    mesh_index = int(node["mesh"])
    matrix = _node_matrix(node)
    raw: Counter[str] = Counter()
    world: Counter[str] = Counter()
    reader = AccessorReader(asset)
    for primitive_index, primitive in enumerate(
            asset.document["meshes"][mesh_index]["primitives"]):
        triangle_hashes = primitive_triangle_payload_hashes(
            asset, mesh_index, primitive_index)
        position_index = int(primitive["attributes"]["POSITION"])
        positions = reader.floats(position_index)
        world_positions = [
            _transform_point(matrix, (value[0], value[1], value[2]))
            for value in positions
        ]
        if "indices" in primitive:
            indices = reader.integers(int(primitive["indices"]))
        else:
            indices = list(range(len(positions)))
        for triangle_index, offset in enumerate(range(0, len(indices), 3)):
            raw_hash = triangle_hashes[triangle_index]
            raw[raw_hash] += 1
            world[canonical_hash({
                "triangle_payload": raw_hash,
                "ordered_world_positions": [
                    world_positions[indices[offset + corner]] for corner in range(3)
                ],
            })] += 1
    return {
        "triangles": raw,
        "world_triangles": world,
        "transform": matrix,
        "bounds": node_world_bounds(asset, node_index),
        "collision_class": collision_class_for_name(str(node.get("name", ""))),
    }


def prove_legacy_alias_equivalence(
        protected: AssetView,
        candidate: AssetView,
        validated: dict[str, Any],
) -> dict[str, Any]:
    """Prove each protected batch equals its one-to-many owned alias union."""

    protected_by_name = {
        str(node.get("name", "")): index
        for index, node in enumerate(protected.document.get("nodes", []))
    }
    assignments_by_alias: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for assignment in validated["assignments"]:
        assignments_by_alias[str(
            assignment["legacy_compatibility_identity"])].append(assignment)
    protected_names = set(protected_by_name)
    candidate_aliases = set(assignments_by_alias)
    if protected_names != candidate_aliases:
        raise OwnerFirstError(
            "legacy alias vocabulary differs from protected nodes: "
            f"missing={sorted(protected_names - candidate_aliases)[:8]} "
            f"unknown={sorted(candidate_aliases - protected_names)[:8]}")

    rows = []
    split_aliases = 0
    for alias in sorted(protected_names):
        protected_payload = _node_payload(protected, protected_by_name[alias])
        candidate_rows = sorted(
            assignments_by_alias[alias],
            key=lambda row: (CELL_IDS.index(str(row["cell"])),
                             int(row["node_index"])),
        )
        candidate_payloads = [
            _node_payload(candidate, int(row["node_index"]))
            for row in candidate_rows
        ]
        triangle_union: Counter[str] = Counter()
        world_union: Counter[str] = Counter()
        for payload in candidate_payloads:
            triangle_union.update(payload["triangles"])
            world_union.update(payload["world_triangles"])
        checks = {
            "triangle_material_attribute_union": (
                triangle_union == protected_payload["triangles"]),
            "world_triangle_union": (
                world_union == protected_payload["world_triangles"]),
            "collision_class": all(
                payload["collision_class"] == protected_payload["collision_class"]
                for payload in candidate_payloads),
            "transform_exact": all(
                payload["transform"] == protected_payload["transform"]
                for payload in candidate_payloads),
            "world_bounds_union": (
                _union_bounds(payload["bounds"] for payload in candidate_payloads)
                == protected_payload["bounds"]),
        }
        if not all(checks.values()):
            failed = sorted(key for key, value in checks.items() if not value)
            raise OwnerFirstError(
                f"legacy alias {alias} differs after owner split: {failed}")
        if len(candidate_rows) > 1:
            split_aliases += 1
        rows.append({
            "legacy_identity": alias,
            "protected_node_index": protected_by_name[alias],
            "protected_triangle_count": sum(
                protected_payload["triangles"].values()),
            "candidate_batches": [{
                "buffer_id": str(row["buffer_id"]),
                "owner_cell": str(row["cell"]),
                "node_index": int(row["node_index"]),
                "triangle_count": sum(payload["triangles"].values()),
            } for row, payload in zip(candidate_rows, candidate_payloads)],
            "one_to_many_split": len(candidate_rows) > 1,
            "checks": checks,
        })
    return {
        "status": "PASS",
        "protected_legacy_identities": len(protected_names),
        "candidate_legacy_identities": len(candidate_aliases),
        "one_to_many_split_identities": split_aliases,
        "identity_sets_exact": True,
        "rows": rows,
        "failures": [],
    }


def bind_candidate_triangle_slices(
        candidate_gltf: Path, generated_lineage_path: Path) -> dict[str, Any]:
    """Bind generation ranges to decoded post-export triangle payloads.

    This operation does not classify anything.  The owner and source ranges
    already exist before export; binding simply proves that Blender retained
    their declared face order in the exported primitive.
    """

    candidate_gltf = candidate_gltf.resolve()
    generated_lineage_path = generated_lineage_path.resolve()
    if (candidate_gltf.is_relative_to(REPO_ROOT)
            or generated_lineage_path.is_relative_to(REPO_ROOT)):
        raise OwnerFirstError("triangle binding is restricted to an external root")
    if candidate_gltf.parent != generated_lineage_path.parent:
        raise OwnerFirstError(
            "candidate glTF and generated lineage must share one disposable root")
    asset = load_asset(candidate_gltf)
    lineage = load_json(generated_lineage_path, "generated lineage")
    nodes_by_name = {
        str(node.get("name", "")): node for node in asset.document.get("nodes", [])
    }
    for buffer in lineage.get("buffers", []):
        name = str(buffer.get("object_name", ""))
        if name not in nodes_by_name:
            raise OwnerFirstError(
                f"cannot bind unexported lineage buffer {name!r}")
        mesh_index = int(nodes_by_name[name]["mesh"])
        hashes = primitive_triangle_payload_hashes(asset, mesh_index, 0)
        cursor = 0
        for contribution in buffer.get("contributions", []):
            triangles = contribution.get("generated_range", {}).get(
                "triangles", {})
            start = int(triangles.get("start", -1))
            count = int(triangles.get("count", -1))
            if start != cursor or count <= 0 or start + count > len(hashes):
                raise OwnerFirstError(
                    f"cannot bind invalid triangle range in {name}")
            contribution["post_export_triangle_payload_sha256"] = canonical_hash(
                hashes[start:start + count])
            cursor += count
        if cursor != len(hashes):
            raise OwnerFirstError(
                f"lineage ranges do not cover exported triangles for {name}")
    write_json(generated_lineage_path, lineage)
    return lineage


def _counter_receipt(counter: Counter[str]) -> dict[str, Any]:
    rows = [[key, counter[key]] for key in sorted(counter)]
    return {
        "unique_payloads": len(rows),
        "payload_instances": sum(counter.values()),
        "multiset_sha256": canonical_hash(rows),
    }


def _union_bounds(bounds: Iterable[list[list[float]]]) -> list[list[float]]:
    values = list(bounds)
    if not values:
        raise OwnerFirstError("cannot compute bounds of empty node set")
    return [
        [min(value[0][axis] for value in values) for axis in range(3)],
        [max(value[1][axis] for value in values) for axis in range(3)],
    ]


def payload_census(asset: AssetView) -> dict[str, Any]:
    """Canonicalize geometry below the batch/descriptor boundary.

    Local index values are intentionally dereferenced.  Each triangle hash
    contains its ordered vertex attribute payloads and canonical material,
    so a legitimate index-base change cannot hide any payload difference.
    """

    reader = AccessorReader(asset)
    materials = Canonicalizer(asset)
    vertices: Counter[str] = Counter()
    triangles: Counter[str] = Counter()
    world_triangles: Counter[str] = Counter()
    collision_triangles: dict[str, Counter[str]] = {
        value: Counter() for value in COLLISION_CLASSES
    }
    material_triangles: Counter[str] = Counter()
    attribute_schemas: Counter[str] = Counter()
    transforms: Counter[str] = Counter()
    node_bounds = []
    primitive_count = 0
    index_component_types: Counter[str] = Counter()

    for node_index, node in enumerate(asset.document.get("nodes", [])):
        mesh_index = int(node["mesh"])
        matrix = _node_matrix(node)
        transforms[canonical_hash(matrix)] += 1
        node_bounds.append(node_world_bounds(asset, node_index))
        collision = collision_class_for_name(str(node.get("name", "")))
        for primitive_index, primitive in enumerate(
                asset.document["meshes"][mesh_index]["primitives"]):
            primitive_count += 1
            if int(primitive.get("mode", 4)) != 4:
                raise OwnerFirstError("equivalence supports TRIANGLES only")
            attributes: dict[str, tuple[dict[str, Any], list[bytes]]] = {}
            attribute_count = None
            for semantic, accessor_index in sorted(
                    primitive.get("attributes", {}).items()):
                schema, elements = reader.read(int(accessor_index))
                attributes[str(semantic)] = (schema, elements)
                attribute_schemas[canonical_hash({
                    "semantic": semantic, **schema,
                })] += len(elements)
                if attribute_count is None:
                    attribute_count = len(elements)
                elif attribute_count != len(elements):
                    raise OwnerFirstError(
                        f"mesh {mesh_index} primitive {primitive_index} "
                        "attribute counts differ")
            if "POSITION" not in attributes or attribute_count is None:
                raise OwnerFirstError("primitive has no POSITION attribute")
            if "indices" in primitive:
                index_accessor = int(primitive["indices"])
                indices = reader.integers(index_accessor)
                index_schema, _ = reader.read(index_accessor)
                index_component_types[str(index_schema["component_type"])] += 1
            else:
                indices = list(range(attribute_count))
                index_component_types["UNINDEXED"] += 1
            if len(indices) % 3:
                raise OwnerFirstError("primitive index payload is not triangular")
            if any(index < 0 or index >= attribute_count for index in indices):
                raise OwnerFirstError("primitive index references outside attributes")
            material_hash = (
                materials.material(int(primitive["material"]))
                if "material" in primitive else "NO_MATERIAL"
            )
            vertex_hashes: list[str] = []
            positions = reader.floats(int(primitive["attributes"]["POSITION"]))
            world_positions = [
                _transform_point(matrix, (value[0], value[1], value[2]))
                for value in positions
            ]
            for vertex_index in range(attribute_count):
                payload = {
                    semantic: {
                        "schema": schema,
                        "payload_hex": elements[vertex_index].hex(),
                    }
                    for semantic, (schema, elements) in attributes.items()
                }
                digest = canonical_hash({
                    "material": material_hash,
                    "attributes": payload,
                })
                vertex_hashes.append(digest)
                vertices[digest] += 1
            for offset in range(0, len(indices), 3):
                tri_indices = indices[offset:offset + 3]
                digest = canonical_hash({
                    "material": material_hash,
                    "ordered_vertices": [vertex_hashes[index]
                                         for index in tri_indices],
                })
                world_digest = canonical_hash({
                    "material": material_hash,
                    "ordered_world_positions": [world_positions[index]
                                                for index in tri_indices],
                    "ordered_vertices": [vertex_hashes[index]
                                         for index in tri_indices],
                })
                triangles[digest] += 1
                world_triangles[world_digest] += 1
                collision_triangles[collision][world_digest] += 1
                material_triangles[material_hash] += 1

    return {
        "counts": {
            "nodes": len(asset.document.get("nodes", [])),
            "meshes": len(asset.document.get("meshes", [])),
            "primitives": primitive_count,
            "vertices": sum(vertices.values()),
            "triangles": sum(triangles.values()),
            "materials": len(asset.document.get("materials", [])),
            "collision_objects": sum(
                collision_class_for_name(str(node.get("name", "")))
                != COLLISION_NONE
                for node in asset.document.get("nodes", [])
            ),
        },
        "vertices": _counter_receipt(vertices),
        "triangles": _counter_receipt(triangles),
        "world_triangles": _counter_receipt(world_triangles),
        "attribute_schemas": _counter_receipt(attribute_schemas),
        "material_triangles": _counter_receipt(material_triangles),
        "collision_triangles": {
            key: _counter_receipt(value)
            for key, value in sorted(collision_triangles.items())
        },
        "transforms": _counter_receipt(transforms),
        "world_bounds_union": _union_bounds(node_bounds),
        "index_component_types": dict(sorted(index_component_types.items())),
        "_counters": {
            "vertices": vertices,
            "triangles": triangles,
            "world_triangles": world_triangles,
            "attribute_schemas": attribute_schemas,
            "material_triangles": material_triangles,
            "collision_triangles": collision_triangles,
        },
    }


def prove_equivalence(
        protected: AssetView, candidate: AssetView,
        validated: dict[str, Any]) -> dict[str, Any]:
    before = payload_census(protected)
    after = payload_census(candidate)
    checks: dict[str, bool] = {
        "vertex_payload_multiset": (
            before["_counters"]["vertices"] == after["_counters"]["vertices"]),
        "triangle_payload_multiset": (
            before["_counters"]["triangles"] == after["_counters"]["triangles"]),
        "world_triangle_payload_multiset": (
            before["_counters"]["world_triangles"]
            == after["_counters"]["world_triangles"]),
        "attribute_schema_multiset": (
            before["_counters"]["attribute_schemas"]
            == after["_counters"]["attribute_schemas"]),
        "material_triangle_multiset": (
            before["_counters"]["material_triangles"]
            == after["_counters"]["material_triangles"]),
        "collision_shape_payloads": all(
            before["_counters"]["collision_triangles"][key]
            == after["_counters"]["collision_triangles"][key]
            for key in COLLISION_CLASSES
        ),
        "world_bounds_union": (
            before["world_bounds_union"] == after["world_bounds_union"]),
    }
    if not all(checks.values()):
        failed = sorted(key for key, value in checks.items() if not value)
        raise OwnerFirstError(
            "owner-first candidate is not canonically equivalent: "
            + ", ".join(failed))

    def public(census: dict[str, Any]) -> dict[str, Any]:
        return {key: value for key, value in census.items() if key != "_counters"}

    count_differences = []
    for key in sorted(set(before["counts"]) | set(after["counts"])):
        if before["counts"].get(key) != after["counts"].get(key):
            count_differences.append({
                "field": key,
                "protected": before["counts"].get(key),
                "candidate": after["counts"].get(key),
                "explanation": (
                    "owner-first rebatching changes object/descriptor topology; "
                    "referenced payload multisets remain exact"
                ),
            })
    if before["index_component_types"] != after["index_component_types"]:
        count_differences.append({
            "field": "index_component_types",
            "protected": before["index_component_types"],
            "candidate": after["index_component_types"],
            "explanation": (
                "owner-local vertex bases permit different unsigned index widths; "
                "indices were dereferenced before exact triangle comparison"
            ),
        })
    alias_equivalence = prove_legacy_alias_equivalence(
        protected, candidate, validated)
    checks["legacy_alias_payload_unions"] = (
        alias_equivalence["status"] == "PASS")
    checks["per_alias_transforms"] = all(
        row["checks"]["transform_exact"] for row in alias_equivalence["rows"])
    if not all(checks.values()):
        raise OwnerFirstError("equivalence receipt contains a failed check")
    return {
        "schema": SCHEMA_EQUIVALENCE,
        "status": "PASS",
        "all_checks_passed": True,
        "unexplained_differences_empty": True,
        "comparison_boundary": (
            "dereferenced ordered triangle/vertex payload, canonical material, "
            "collision class, transform-applied geometry, and world-bounds union"
        ),
        "raw_descriptor_byte_identity_required": False,
        "protected": public(before),
        "owner_first_candidate": public(after),
        "checks": checks,
        "legacy_alias_equivalence": alias_equivalence,
        "structurally_explained_differences": count_differences,
        "unexplained_differences": [],
    }


def _assignment_for_cells(validated: dict[str, Any]) -> dict[str, Any]:
    return {
        "cells": copy.deepcopy(validated["cells"]),
        "by_cell": copy.deepcopy(validated["by_cell"]),
        "assignments": copy.deepcopy(validated["assignments"]),
    }


def _patch_cell_metadata(cell: GeneratedCell) -> None:
    extras = cell.document.setdefault("asset", {}).setdefault("extras", {})
    extras.pop("m11c0_rehearsal", None)
    extras["orison_m11c1_owner_first"] = {
        "cell": cell.cell_id,
        "production_asset": False,
        "owner_before_material": True,
        "spatial_inference_used": False,
    }
    extras["orison_bin_sha256"] = bytes_hash(cell.bin_bytes)


def _cell_measurement(cell: GeneratedCell, output_root: Path) -> dict[str, Any]:
    asset = cell.as_asset(output_root)
    triangles = sum(
        _primitive_triangle_count(asset, mesh_index, primitive_index)
        for mesh_index, mesh in enumerate(cell.document["meshes"])
        for primitive_index, _primitive in enumerate(mesh["primitives"])
    )
    vertices = sum(
        int(cell.document["accessors"][int(primitive["attributes"]["POSITION"])][
            "count"])
        for mesh in cell.document["meshes"]
        for primitive in mesh["primitives"]
    )
    bounds = [node_world_bounds(asset, index)
              for index in range(len(cell.document["nodes"]))]
    return {
        "id": cell.cell_id,
        "slug": cell.slug,
        "gltf_path": f"cells/{cell.slug}.gltf",
        "bin_path": f"cells/{cell.slug}.bin",
        "resource_path": f"res://cells/{cell.slug}.gltf",
        "gltf_sha256": bytes_hash(cell.gltf_bytes),
        "bin_sha256": bytes_hash(cell.bin_bytes),
        "node_count": len(cell.document["nodes"]),
        "mesh_count": len(cell.document["meshes"]),
        "primitive_count": sum(len(mesh["primitives"])
                               for mesh in cell.document["meshes"]),
        "triangle_count": triangles,
        "vertex_count": vertices,
        "collision_object_count": sum(
            collision_class_for_name(str(node.get("name", "")))
            != COLLISION_NONE for node in cell.document["nodes"]),
        "bounds_union": _union_bounds(bounds),
        "gltf_bytes": len(cell.gltf_bytes),
        "bin_bytes": len(cell.bin_bytes),
    }


def _verify_written_cell_hashes(
        measurements: list[dict[str, Any]], output_root: Path) -> None:
    """Refuse a partition whose on-disk cell bytes differ from its manifest."""

    for row in measurements:
        gltf_path = output_root / str(row["gltf_path"])
        bin_path = output_root / str(row["bin_path"])
        if (not gltf_path.is_file() or not bin_path.is_file()
                or _sha256_file(gltf_path) != row["gltf_sha256"]
                or _sha256_file(bin_path) != row["bin_sha256"]):
            raise OwnerFirstError(
                f"written cell hash drifted for {row.get('id', '<unknown>')}")


def verify_transaction_artifact_closure(
        output_root: Path, transaction: dict[str, Any],
        transaction_path: Path) -> None:
    """Prove no disposable JSON receipt/manifest escapes transaction binding."""

    output_root = output_root.resolve()
    transaction_path = transaction_path.resolve()
    if transaction_path != (
            output_root / "receipts/floor01_owner_first_transaction.json"):
        raise OwnerFirstError("transaction path is not the canonical output path")
    artifacts = transaction.get("artifacts")
    candidate = transaction.get("candidate")
    if not isinstance(artifacts, dict) or not isinstance(candidate, dict):
        raise OwnerFirstError("transaction lacks artifact/candidate bindings")
    expected_json_paths: set[Path] = set()
    for relative_path, row in artifacts.items():
        if not isinstance(row, dict) or row.get("relative_path") != relative_path:
            raise OwnerFirstError("transaction artifact path binding is malformed")
        relative = PurePosixPath(str(relative_path))
        if relative.is_absolute() or ".." in relative.parts:
            raise OwnerFirstError("transaction artifact path escapes output root")
        path = output_root.joinpath(*relative.parts).resolve()
        if not path.is_relative_to(output_root) or not path.is_file():
            raise OwnerFirstError(f"transaction artifact is missing: {relative_path}")
        if _sha256_file(path) != row.get("sha256"):
            raise OwnerFirstError(f"transaction artifact hash drifted: {relative_path}")
        receipt = load_json(path, f"transaction artifact {relative_path}")
        if (receipt.get("schema") != row.get("schema")
                or receipt.get("status") != "PASS"
                or row.get("status") != "PASS"
                or receipt.get("run_id") != transaction.get("run_id")
                or receipt.get("disposable_root") != str(output_root)):
            raise OwnerFirstError(
                f"transaction artifact run/root/schema drifted: {relative_path}")
        expected_json_paths.add(path)

    generated_lineage = Path(str(
        candidate.get("generated_lineage_path", ""))).resolve()
    if (not generated_lineage.is_file()
            or _sha256_file(generated_lineage)
            != candidate.get("generated_lineage_sha256")):
        raise OwnerFirstError("transaction candidate lineage binding drifted")
    actual_json_paths = {
        path.resolve() for path in output_root.rglob("*.json") if path.is_file()
    }
    allowed = expected_json_paths | {generated_lineage, transaction_path}
    extras = sorted(str(path) for path in actual_json_paths - allowed)
    missing = sorted(str(path) for path in expected_json_paths - actual_json_paths)
    if extras or missing:
        raise OwnerFirstError(
            "transaction JSON artifact closure failed: "
            f"unbound={extras[:8]} missing={missing[:8]}")


def _final_lineage(
        validated: dict[str, Any], generated: list[GeneratedCell],
        exterior_regions_path: Path) -> dict[str, Any]:
    cell_by_id = {cell.cell_id: cell for cell in generated}
    assignment_by_buffer = {
        row["buffer_id"]: row for row in validated["assignments"]
    }
    rows = []
    aliases: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for contribution in validated["contributions"]:
        candidate = contribution["candidate"]
        assignment = assignment_by_buffer[candidate["buffer_id"]]
        cell = cell_by_id[assignment["cell"]]
        old_node = int(candidate["node_index"])
        old_mesh = int(candidate["mesh_index"])
        output = {
            "cell_id": cell.cell_id,
            "cell_slug": cell.slug,
            "node_index": cell.node_map[old_node],
            "mesh_index": cell.mesh_map[old_mesh],
            "primitive_index": int(candidate["primitive_index"]),
            "triangle_start": int(candidate["triangle_start"]),
            "triangle_count": int(candidate["triangle_count"]),
        }
        row = {
            key: copy.deepcopy(value)
            for key, value in contribution.items()
            if key not in {"candidate", "generation_order"}
        }
        row["source_range"] = row.pop("generated_range")
        row["candidate"] = copy.deepcopy(candidate)
        row["output"] = output
        rows.append(row)
        alias = str(row["legacy_compatibility_identity"])
        alias_record = {
            "cell_id": cell.cell_id,
            "node_index": output["node_index"],
            "mesh_index": output["mesh_index"],
        }
        if alias_record not in aliases[alias]:
            aliases[alias].append(alias_record)
    rows.sort(key=lambda value: int(value["generation_order"]) if
              "generation_order" in value else str(value["lineage_id"]))
    for values in aliases.values():
        values.sort(key=lambda value: (
            CELL_IDS.index(value["cell_id"]), value["node_index"]))
    semantic_owners = []
    for source in validated["source_records"]:
        if str(source.get("collection", "")) != "markers":
            continue
        identity = str(source["source_id"])
        semantic_owners.append({
            "identity": identity,
            "source_id": identity,
            "source_locator": str(source["source_locator"]),
            "owner_cell": str(source["owner_cell"]),
            "semantic_kind": "layout_marker",
            "identity_origin": str(source["identity_origin"]),
            "authoring_context": copy.deepcopy(source["authoring_context"]),
            "compatibility_aliases": [identity],
        })
    # M11A's v2 bodega threshold is an exterior-composition semantic, not a
    # v1 layout marker. Resolve and hash its actual authored threshold record;
    # a route's threshold_ids reference is not a source record.
    exterior_regions_path = exterior_regions_path.resolve()
    regions = load_json(exterior_regions_path, "M11A exterior regions")
    thresholds = regions.get("thresholds")
    if not isinstance(thresholds, list):
        raise OwnerFirstError("M11A exterior regions thresholds must be an array")
    threshold_matches = [
        row for row in thresholds
        if isinstance(row, dict)
        and row.get("id") == "THRESHOLD_SHOP_BODEGA_FRONT"
    ]
    if len(threshold_matches) != 1:
        raise OwnerFirstError(
            "expected one authored THRESHOLD_SHOP_BODEGA_FRONT record")
    threshold_record = threshold_matches[0]
    if (threshold_record.get("shop_id") != "SHOP_BODEGA"
            or threshold_record.get("owner_instance_id") != "SHOP_BODEGA"
            or threshold_record.get("owner_surface_id") != "threshold"):
        raise OwnerFirstError("M11A bodega threshold authoring context drifted")
    semantic_owners.append({
        "identity": "THRESHOLD_SHOP_BODEGA_FRONT",
        "source_id": "M11A_THRESHOLD_SHOP_BODEGA_FRONT",
        "source_locator": (
            "game/data/orison_v2/exterior/regions.json#"
            "thresholds[id=THRESHOLD_SHOP_BODEGA_FRONT]"
        ),
        "source_record_sha256": canonical_hash(threshold_record),
        "source_file_sha256": _sha256_file(exterior_regions_path),
        "owner_cell": BODEGA,
        "semantic_kind": "m11a_exterior_threshold",
        "identity_origin": "M11A_AUTHORED_THRESHOLD_ID",
        "authoring_context": "M11A_EXTERIOR_REGION_SHOP_BODEGA",
        "compatibility_aliases": [],
    })
    semantic_owners.sort(key=lambda row: str(row["identity"]))
    semantic_ids = [str(row["identity"]) for row in semantic_owners]
    semantic_source_ids = [str(row["source_id"]) for row in semantic_owners]
    if (len(semantic_ids) != len(set(semantic_ids))
            or len(semantic_source_ids) != len(set(semantic_source_ids))):
        raise OwnerFirstError("semantic owner identities/source IDs are not unique")
    required_semantics = {
        "F01_DOOR_06", "F01_BODEGA_DOOR", "F01_BAR_DOOR",
        "PASSAGE_PORTAL_LT_W", "PASSAGE_PORTAL_LT_E",
        "THRESHOLD_SHOP_BODEGA_FRONT",
    }
    missing_semantics = sorted(required_semantics - set(semantic_ids))
    if missing_semantics:
        raise OwnerFirstError(
            f"required semantic owner identities are missing: {missing_semantics}")
    if not any(identity.startswith("SITE_SHOP_") for identity in semantic_ids):
        raise OwnerFirstError("semantic owners contain no SITE_SHOP_* family")
    bodega_v1 = next(row for row in semantic_owners
                     if row["identity"] == "F01_BODEGA_DOOR")
    bodega_v2 = next(row for row in semantic_owners
                     if row["identity"] == "THRESHOLD_SHOP_BODEGA_FRONT")
    if (bodega_v1["source_id"] == bodega_v2["source_id"]
            or bodega_v1["semantic_kind"] == bodega_v2["semantic_kind"]):
        raise OwnerFirstError("v1 bodega door is conflated with v2 threshold")
    return {
        "schema": SCHEMA_LINEAGE,
        "status": "PASS",
        "lineage_complete": True,
        "legacy_aliases_complete": True,
        "semantic_owners_unique": True,
        "authority": "authoritative source catalog plus generation-time ranges",
        "spatial_inference_used": False,
        "owner_before_material": True,
        "source_records": validated["source_records"],
        "generated_sources": validated["generated_sources"],
        "contributions": rows,
        "legacy_aliases": dict(sorted(aliases.items())),
        "semantic_owners": semantic_owners,
        "semantic_owner_count": len(semantic_owners),
        "counts": {
            "source_records": validated["source_record_count"],
            "generated_sources": validated["generated_source_count"],
            "generated_contributions": len(rows),
            "output_primitives": sum(
                len(cell.document["meshes"][mesh]["primitives"])
                for cell in generated for mesh in range(len(cell.document["meshes"]))),
            "output_triangles": sum(
                int(row["output"]["triangle_count"]) for row in rows),
            "semantic_owners": len(semantic_owners),
        },
        "unresolved_lineage_records": validated["unresolved_lineage_records"],
    }


def _assert_disposable_output(output_root: Path, protected_gltf: Path) -> None:
    output = output_root.resolve()
    protected = protected_gltf.resolve()
    protected_dir = protected.parent
    if output == protected_dir or output.is_relative_to(protected_dir):
        raise OwnerFirstError(
            "owner-first output may not be inside protected asset directory")
    if protected.is_relative_to(output):
        raise OwnerFirstError("owner-first output may not contain protected source")
    if output == REPO_ROOT or output.is_relative_to(REPO_ROOT) \
            or REPO_ROOT.is_relative_to(output):
        raise OwnerFirstError("owner-first output must be an external disposable root")


def _prepare_empty_output(output_root: Path) -> None:
    output_root = output_root.resolve()
    if output_root.exists() and any(output_root.iterdir()):
        raise OwnerFirstError(
            f"output is not empty; refusing to overwrite {output_root}")
    output_root.mkdir(parents=True, exist_ok=True)


def run_owner_first_export(
        protected_gltf: Path,
        candidate_gltf: Path,
        generated_lineage_path: Path,
        layout_path: Path,
        ownership_sidecar_path: Path,
        generator_path: Path,
        adapter_path: Path,
        exterior_regions_path: Path,
        output_root: Path,
        *,
        prepare_output: bool = True,
        require_orchestrator_receipts: bool = False,
) -> dict[str, Any]:
    """Validate, split, receipt, and equivalence-check one candidate."""

    protected_gltf = protected_gltf.resolve()
    candidate_gltf = candidate_gltf.resolve()
    generated_lineage_path = generated_lineage_path.resolve()
    layout_path = layout_path.resolve()
    ownership_sidecar_path = ownership_sidecar_path.resolve()
    generator_path = generator_path.resolve()
    adapter_path = adapter_path.resolve()
    exterior_regions_path = exterior_regions_path.resolve()
    output_root = output_root.resolve()
    _assert_disposable_output(output_root, protected_gltf)
    if prepare_output:
        _prepare_empty_output(output_root)
    else:
        output_root.mkdir(parents=True, exist_ok=True)
    supporting_receipts: dict[str, dict[str, Any]] = {}
    if require_orchestrator_receipts:
        for relative_path, schema in ORCHESTRATOR_RECEIPT_SCHEMAS.items():
            path = output_root.joinpath(*PurePosixPath(relative_path).parts)
            receipt = load_json(path, f"orchestrator receipt {relative_path}")
            if receipt.get("schema") != schema or receipt.get("status") != "PASS":
                raise OwnerFirstError(
                    f"orchestrator receipt is not schema-bound PASS: {relative_path}")
            if relative_path.endswith("protected_assets.json"):
                if (receipt.get("unchanged") is not True
                        or receipt.get("hashes_before") != receipt.get("hashes_after")):
                    raise OwnerFirstError("protected-assets receipt does not prove unchanged")
            elif (receipt.get("exit_code") != 0
                  or not isinstance(receipt.get("command"), list)):
                raise OwnerFirstError("Blender process receipt is not a successful command")
            supporting_receipts[relative_path] = receipt
    protected = load_asset(protected_gltf)
    candidate = load_asset(candidate_gltf)
    authoritative_layout = load_json(layout_path, "authoritative layout")
    catalog_by_locator = load_source_ownership(
        layout_path, ownership_sidecar_path)
    exterior_regions_before = _sha256_file(exterior_regions_path)
    try:
        protected_counts = validate_source(protected)
        candidate_counts = validate_source(candidate)
    except RehearsalError as error:
        raise OwnerFirstError(str(error)) from error
    protected_buffer_uri = _safe_relative_uri(
        str(protected.document["buffers"][0]["uri"]), "protected buffer URI")
    protected_bin = protected_gltf.parent.joinpath(*protected_buffer_uri.parts)
    candidate_buffer_uri = _safe_relative_uri(
        str(candidate.document["buffers"][0]["uri"]), "candidate buffer URI")
    candidate_bin = candidate_gltf.parent.joinpath(*candidate_buffer_uri.parts)
    protected_before = {
        "gltf": _sha256_file(protected_gltf),
        "bin": _sha256_file(protected_bin),
    }
    candidate_lineage = load_json(
        generated_lineage_path, "generated lineage")
    expected_input_bindings = {
        "generator": {
            "path": str(generator_path), "sha256": _sha256_file(generator_path)},
        "layout": {
            "path": str(layout_path), "sha256": _sha256_file(layout_path)},
        "ownership": {
            "path": str(ownership_sidecar_path),
            "sha256": _sha256_file(ownership_sidecar_path),
        },
        "adapter": {
            "path": str(adapter_path), "sha256": _sha256_file(adapter_path)},
    }
    validated = validate_generation_lineage(
        candidate, candidate_lineage, catalog_by_locator,
        authoritative_layout, expected_input_bindings)
    equivalence = prove_equivalence(protected, candidate, validated)

    assignment = _assignment_for_cells(validated)
    try:
        generated = build_cells(candidate, assignment, output_root)
        for cell in generated:
            _patch_cell_metadata(cell)
        recomposition = verify_recomposition(candidate, generated, output_root)
    except RehearsalError as error:
        raise OwnerFirstError(str(error)) from error

    cells_dir = output_root / "cells"
    cells_dir.mkdir(parents=True, exist_ok=True)
    for cell in generated:
        (cells_dir / f"{cell.slug}.gltf").write_bytes(cell.gltf_bytes)
        (cells_dir / f"{cell.slug}.bin").write_bytes(cell.bin_bytes)
    try:
        textures = _copy_shared_textures(candidate, output_root)
    except RehearsalError as error:
        raise OwnerFirstError(str(error)) from error

    lineage = _final_lineage(validated, generated, exterior_regions_path)
    if lineage["unresolved_lineage_records"]:
        raise OwnerFirstError("lineage has unresolved records after cell export")
    measurements = [_cell_measurement(cell, output_root) for cell in generated]
    _verify_written_cell_hashes(measurements, output_root)
    source_contribution_cells: dict[str, set[str]] = defaultdict(set)
    for row in lineage["contributions"]:
        source_contribution_cells[str(row["source_id"])].add(
            str(row["owner_cell"]))
    multi_owner = sorted(
        source_id for source_id, owners in source_contribution_cells.items()
        if len(owners) != 1)
    if multi_owner:
        raise OwnerFirstError(
            f"sources emitted into multiple owner cells: {multi_owner[:8]}")

    source_counts_by_cell = Counter(
        str(row["owner_cell"]) for row in validated["source_records"])
    for measurement in measurements:
        measurement["source_record_count"] = source_counts_by_cell[
            measurement["id"]]

    lineage_rel = "receipts/floor01_owner_first_lineage.json"
    equivalence_rel = "receipts/floor01_owner_first_equivalence.json"
    recomposition_rel = "receipts/floor01_owner_first_recomposition.json"
    export_rel = "receipts/floor01_owner_first_export.json"
    transaction_rel = "receipts/floor01_owner_first_transaction.json"
    candidate_hashes = {
        "gltf": _sha256_file(candidate_gltf),
        "bin": _sha256_file(candidate_bin),
        "generated_lineage": _sha256_file(generated_lineage_path),
    }
    authoritative_input_hashes = {
        "layout": _sha256_file(layout_path),
        "ownership": _sha256_file(ownership_sidecar_path),
        "generator": _sha256_file(generator_path),
        "adapter": _sha256_file(adapter_path),
        "exterior_regions": _sha256_file(exterior_regions_path),
    }
    run_id = "M11C1-" + canonical_hash({
        "schema": SCHEMA_TRANSACTION,
        "disposable_root": str(output_root),
        "protected_hashes": protected_before,
        "candidate_hashes": candidate_hashes,
        "authoritative_input_hashes": authoritative_input_hashes,
        "orchestrator_receipts": {
            relative_path: canonical_hash(receipt)
            for relative_path, receipt in sorted(supporting_receipts.items())
        },
        "cells": [{
            "id": row["id"],
            "gltf_sha256": row["gltf_sha256"],
            "bin_sha256": row["bin_sha256"],
        } for row in measurements],
    })[:24]
    for receipt in (lineage, equivalence, recomposition):
        receipt["run_id"] = run_id
        receipt["disposable_root"] = str(output_root)
    for relative_path, receipt in supporting_receipts.items():
        receipt["run_id"] = run_id
        receipt["disposable_root"] = str(output_root)
        write_json(
            output_root.joinpath(*PurePosixPath(relative_path).parts), receipt)
    partition = {
        "schema": SCHEMA_PARTITION,
        "status": "PASS",
        "run_id": run_id,
        "production_asset": False,
        "owner_before_material": True,
        "canonical_equivalence_passed": True,
        "lineage_complete": True,
        "protected_unchanged": True,
        "cell_hashes_bound": True,
        "disposable_root": str(output_root),
        "authority": "explicit owner_cell retained before material batching",
        "spatial_inference_used": False,
        "persistent_hosts": [{
            "id": "F01",
            "geometry_free": True,
            "purpose": "persistent composition/director host",
        }],
        "source": {
            "protected_gltf": str(protected_gltf),
            "protected_hashes": protected_before,
            "candidate_gltf": str(candidate_gltf),
            "candidate_bin": str(candidate_bin),
            "generated_lineage": str(generated_lineage_path),
            "candidate_hashes": candidate_hashes,
        },
        "cells": measurements,
        "lineage_manifest": lineage_rel,
        "equivalence_receipt": equivalence_rel,
        "recomposition_receipt": recomposition_rel,
        "export_receipt": export_rel,
        "transaction_manifest": transaction_rel,
        "forbidden_cell_absent": "CELL_LEGACY_MIXED",
        "legacy_mixed_cell_present": False,
        "target_cell_count": len(measurements),
    }
    export_receipt = {
        "schema": SCHEMA_EXPORT,
        "status": "PASS",
        "run_id": run_id,
        "disposable_root": str(output_root),
        "production_mutation": False,
        "protected_hashes_before": protected_before,
        "protected_hashes_after": {
            "gltf": _sha256_file(protected_gltf),
            "bin": _sha256_file(protected_bin),
        },
        "protected_unchanged": True,
        "source_counts": {
            "catalog_records": validated["source_record_count"],
            "supplemental_generated_sources": validated["generated_source_count"],
            "generated_contributions": len(validated["contributions"]),
        },
        "candidate_counts": candidate_counts,
        "protected_counts": protected_counts,
        "cell_count": len(generated),
        "owner_before_material": True,
        "spatial_inference_used": False,
        "unresolved_lineage_records": [],
        "emission_coverage": validated["emission_coverage"],
        "candidate_hashes": candidate_hashes,
        "cell_hashes_bound": True,
        "authoritative_input_hashes": authoritative_input_hashes,
        "texture_library": textures,
        "candidate_recomposition": recomposition,
    }
    if export_receipt["protected_hashes_after"] != protected_before:
        raise OwnerFirstError("protected floor asset changed during disposable export")
    authoritative_after = export_receipt["authoritative_input_hashes"]
    expected_authoritative = {
        "layout": expected_input_bindings["layout"]["sha256"],
        "ownership": expected_input_bindings["ownership"]["sha256"],
        "generator": expected_input_bindings["generator"]["sha256"],
        "adapter": expected_input_bindings["adapter"]["sha256"],
        "exterior_regions": exterior_regions_before,
    }
    if authoritative_after != expected_authoritative:
        raise OwnerFirstError("authoritative inputs changed during disposable export")

    write_json(output_root / lineage_rel, lineage)
    write_json(output_root / equivalence_rel, equivalence)
    write_json(output_root / recomposition_rel, recomposition)
    write_json(output_root / export_rel, export_receipt)
    write_json(output_root / "owner_first_partition_manifest.json", partition)
    receipt_values = {
        lineage_rel: lineage,
        equivalence_rel: equivalence,
        recomposition_rel: recomposition,
        export_rel: export_receipt,
        "owner_first_partition_manifest.json": partition,
    }
    receipt_values.update(supporting_receipts)
    transaction_artifacts = {}
    for relative_path, receipt in receipt_values.items():
        artifact_path = output_root / relative_path
        transaction_artifacts[relative_path] = {
            "relative_path": relative_path,
            "sha256": _sha256_file(artifact_path),
            "schema": str(receipt.get("schema", "")),
            "status": str(receipt.get("status", "")),
        }
    transaction = {
        "schema": SCHEMA_TRANSACTION,
        "status": "PASS",
        "run_id": run_id,
        "disposable_root": str(output_root),
        "generated_last": True,
        "all_artifacts_bound": True,
        "json_artifact_closure_verified": True,
        "candidate": {
            "descriptor_path": str(candidate_gltf),
            "descriptor_sha256": candidate_hashes["gltf"],
            "binary_path": str(candidate_bin),
            "binary_sha256": candidate_hashes["bin"],
            "generated_lineage_path": str(generated_lineage_path),
            "generated_lineage_sha256": candidate_hashes["generated_lineage"],
        },
        "artifacts": transaction_artifacts,
        "cells": [{
            "id": row["id"],
            "gltf_path": row["gltf_path"],
            "gltf_sha256": row["gltf_sha256"],
            "bin_path": row["bin_path"],
            "bin_sha256": row["bin_sha256"],
        } for row in measurements],
    }
    transaction_path = output_root / transaction_rel
    verify_transaction_artifact_closure(
        output_root, transaction, transaction_path)
    write_json(transaction_path, transaction)
    return {
        "status": "PASS",
        "run_id": run_id,
        "output_root": str(output_root),
        "source_records": validated["source_record_count"],
        "generated_contributions": len(validated["contributions"]),
        "cells": len(generated),
        "triangles": equivalence["owner_first_candidate"]["counts"]["triangles"],
        "vertices": equivalence["owner_first_candidate"]["counts"]["vertices"],
        "unresolved_lineage_records": 0,
        "protected_hashes": protected_before,
    }


def _parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--protected-gltf", type=Path, required=True)
    parser.add_argument("--candidate-gltf", type=Path, required=True)
    parser.add_argument("--generated-lineage", type=Path, required=True)
    parser.add_argument("--layout", type=Path, required=True)
    parser.add_argument("--ownership", type=Path, required=True)
    parser.add_argument("--generator", type=Path, required=True)
    parser.add_argument("--adapter", type=Path, required=True)
    parser.add_argument("--exterior-regions", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv)
    try:
        summary = run_owner_first_export(
            args.protected_gltf,
            args.candidate_gltf,
            args.generated_lineage,
            args.layout,
            args.ownership,
            args.generator,
            args.adapter,
            args.exterior_regions,
            args.output,
        )
    except (OwnerFirstError, OSError, ValueError) as error:
        print(f"M11C1 OWNER-FIRST EXPORT FAIL: {error}", file=sys.stderr)
        return 2
    print(json.dumps(summary, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
