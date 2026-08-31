#!/usr/bin/env python3
"""Materialize the M11C1 owner-first runtime rehearsal outside the repo.

The owner-first exporter deliberately writes ordinary glTF files outside the
Godot project.  This tool creates the equally disposable Godot side of that
transaction.  It refuses mixed/stale receipts before copying anything, copies
the exact seventeen transaction-bound cells and texture library into an
external ``res://`` root, derives the runtime configuration from authoritative
records, and runs Godot's importer only in that external project.

Only ``--export-root`` and ``--scratch-root`` are caller supplied.  Repository
inputs, protected assets, semantic sources, seam records, and Godot discovery
are intentionally not overrideable from the command line.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path, PurePosixPath
from typing import Any, Iterable, Mapping, Sequence


REPO_ROOT = Path(__file__).resolve().parents[2]
GAME_ROOT = REPO_ROOT / "game"
M11C0_MANIFEST = (
    REPO_ROOT
    / "design"
    / "ORISON_V2_M11C0_FLOOR01_PARTITION_MANIFEST_2026-08-31.json"
)
CONFIG_SCHEMA_PATH = (
    REPO_ROOT
    / "tools"
    / "m11c1_floor01_rehearsal"
    / "m11c1_runtime_config.schema.json"
)
LAYOUT_PATH = GAME_ROOT / "data" / "building_layout.json"
EXTERIOR_REGIONS_PATH = (
    GAME_ROOT / "data" / "orison_v2" / "exterior" / "regions.json"
)
PROTECTED_GLTF = GAME_ROOT / "assets" / "building" / "floor_01.gltf"
PROTECTED_BIN = GAME_ROOT / "assets" / "building" / "floor_01.bin"

PARTITION_NAME = "owner_first_partition_manifest.json"
PARTITION_SCHEMA = "orison.floor01.owner-first-partition.v1"
LINEAGE_SCHEMA = "orison.floor01.owner-first-lineage.v1"
EQUIVALENCE_SCHEMA = "orison.floor01.owner-first-equivalence.v1"
RECOMPOSITION_SCHEMA = "orison.m11c0.floor01-recomposition.v1"
EXPORT_SCHEMA = "orison.floor01.owner-first-export.v1"
TRANSACTION_SCHEMA = "orison.floor01.owner-first-transaction.v1"
BLENDER_PROCESS_SCHEMA = "orison.floor01.owner-first-blender-process.v1"
PROTECTION_SCHEMA = "orison.floor01.owner-first-protection.v1"
CONFIG_SCHEMA = "orison.m11c1.target-cell-runtime-config.v1"
MATERIALIZATION_SCHEMA = "orison.m11c1.runtime-rehearsal-materialization.v1"
AUTHORITATIVE_RESOURCE_PATHS = {
    "layout": "res://data/building_layout.json",
    "exterior_regions": "res://data/orison_v2/exterior/regions.json",
}

TARGET_CELL_IDS = (
    "CELL_ORISON_F01_INTERIOR",
    "CELL_ORISON_FACADE_SHELL",
    "CELL_SITE_STREET_COMMON",
    "CELL_PASSAGE",
    "CELL_SHOP_BAR",
    "CELL_SHOP_BODEGA",
    "CELL_SHOP_MODEL_LAUNDRY",
    "CELL_SHOP_SHOE_REBUILDING",
    "CELL_SHOP_KEYS_CUT",
    "CELL_SHOP_HARDWARE_PAINT",
    "CELL_SHOP_FUNERAL_PARLOUR",
    "CELL_SHOP_PHOTO_SUPPLIES",
    "CELL_SHOP_RADIO_SERVICE",
    "CELL_SHOP_PAWNBROKER",
    "CELL_SHOP_NEWS_CIGARS",
    "CELL_SHOP_OTIS_SON",
    "CELL_SHOP_LUNCHEONETTE",
)

PASSAGE_SHOPS = (
    ("MODEL_LAUNDRY", "CELL_SHOP_MODEL_LAUNDRY"),
    ("SHOE_REBUILDING", "CELL_SHOP_SHOE_REBUILDING"),
    ("KEYS_CUT", "CELL_SHOP_KEYS_CUT"),
    ("HARDWARE_PAINT", "CELL_SHOP_HARDWARE_PAINT"),
    ("FUNERAL_PARLOUR", "CELL_SHOP_FUNERAL_PARLOUR"),
    ("PHOTO_SUPPLIES", "CELL_SHOP_PHOTO_SUPPLIES"),
    ("RADIO_SERVICE", "CELL_SHOP_RADIO_SERVICE"),
    ("PAWNBROKER", "CELL_SHOP_PAWNBROKER"),
    ("NEWS_CIGARS", "CELL_SHOP_NEWS_CIGARS"),
    ("OTIS___SON", "CELL_SHOP_OTIS_SON"),
    ("LUNCHEONETTE", "CELL_SHOP_LUNCHEONETTE"),
)

REQUIRED_SEMANTICS = {
    "F01_DOOR_06",
    "F01_BODEGA_DOOR",
    "F01_BAR_DOOR",
    "PASSAGE_PORTAL_LT_W",
    "PASSAGE_PORTAL_LT_E",
    "THRESHOLD_SHOP_BODEGA_FRONT",
    *(f"SITE_SHOP_DOOR_{suffix}" for suffix, _cell in PASSAGE_SHOPS),
}

PROJECT_COPY_DIRS = ("scripts", "scenes", "data", "shaders", "tests")
REQUIRED_DYNAMIC_RUNTIME_ASSETS = (
    "assets/building/textures/atmospheric_decals/institutional_wear_atlas.png",
    "assets/building/textures/atmospheric_decals/domestic_residue_atlas.png",
    "assets/building/textures/atmospheric_decals/uncanny_trace_atlas.png",
    "assets/building/textures/found_art/fine_art_01.webp",
    "assets/building/textures/found_art/posters_01.webp",
    "assets/building/textures/found_art/editorial_01.webp",
    "assets/building/textures/found_art/editorial_02.webp",
    "assets/building/textures/found_art/billboards_01.webp",
    "assets/arcade/arcade_cabinets.json",
    "assets/building/textures/mailbank/T_mailbank_brass_albedo.png",
    "assets/building/textures/mailbank/T_mailbank_brass_rough.png",
    "assets/building/textures/mailbank/T_mailbank_header.png",
    "assets/building/textures/mailbank/T_mailbank_cards.png",
)
REQUIRED_DYNAMIC_RUNTIME_ASSET_DIRS = (
    "assets/building/textures/height",
    "assets/building/textures/masks",
)
ASSET_LITERAL_RE = re.compile(
    r"res://assets/[A-Za-z0-9_./() +\-]+\.(?:png|jpe?g|webp|ogg|wav|ttf|otf|"
    r"gltf|glb|bin|json|ogv)",
    re.IGNORECASE,
)
MATERIAL_TEXTURE_RE = re.compile(r"[\"']([^\"']+\.(?:png|jpe?g|webp))[\"']")
F01_LOCATOR_RE = re.compile(r"^floors\[F01\]\.markers\[(\d+)\]$")


class PreparationError(RuntimeError):
    """A fail-closed provenance, destination, or import error."""


@dataclass(frozen=True)
class ExportBundle:
    root: Path
    partition_path: Path
    partition: dict[str, Any]
    transaction_path: Path
    transaction: dict[str, Any]
    lineage_path: Path
    lineage: dict[str, Any]
    equivalence_path: Path
    equivalence: dict[str, Any]
    recomposition_path: Path
    recomposition: dict[str, Any]
    export_receipt_path: Path
    export_receipt: dict[str, Any]
    cells: tuple[dict[str, Any], ...]
    textures: tuple[dict[str, Any], ...]
    source_hashes: dict[str, str]


def canonical_bytes(value: Any) -> bytes:
    try:
        return json.dumps(
            value,
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
            allow_nan=False,
        ).encode("utf-8")
    except (TypeError, ValueError) as exc:
        raise PreparationError(f"value is not canonical JSON: {exc}") from exc


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    try:
        with path.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                digest.update(chunk)
    except OSError as exc:
        raise PreparationError(f"cannot hash {path}: {exc}") from exc
    return digest.hexdigest()


def load_json(path: Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise PreparationError(f"cannot read {label} {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise PreparationError(f"{label} is not a JSON object: {path}")
    return value


def write_json(path: Path, value: Mapping[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + "\n",
        encoding="utf-8",
        newline="\n",
    )


def _same_or_within(path: Path, parent: Path) -> bool:
    path = path.resolve()
    parent = parent.resolve()
    return path == parent or path.is_relative_to(parent)


def _safe_relative_path(root: Path, raw: str, label: str) -> Path:
    if not raw or "\\" in raw:
        raise PreparationError(f"{label} is not a canonical relative path: {raw!r}")
    relative = PurePosixPath(raw)
    if relative.is_absolute() or ".." in relative.parts or "." in relative.parts:
        raise PreparationError(f"{label} escapes its root: {raw!r}")
    result = root.joinpath(*relative.parts).resolve()
    if not _same_or_within(result, root):
        raise PreparationError(f"{label} resolves outside its root: {raw!r}")
    return result


def _scratch_resource_path(scratch_root: Path, raw: str, label: str) -> Path:
    if not raw.startswith("res://"):
        raise PreparationError(f"{label} must be an explicit scratch res:// path")
    return _safe_relative_path(scratch_root, raw.removeprefix("res://"), label)


def validate_scratch_authoritative_sources(
    config: Mapping[str, Any], scratch_root: Path
) -> dict[str, dict[str, str]]:
    raw = config.get("authoritative_sources")
    if not isinstance(raw, dict):
        raise PreparationError("runtime config authoritative_sources is absent")
    expected_keys = {
        "layout_path",
        "layout_sha256",
        "exterior_regions_path",
        "exterior_regions_sha256",
    }
    if set(raw) != expected_keys:
        raise PreparationError("runtime config authoritative_sources shape differs")
    receipt: dict[str, dict[str, str]] = {}
    for identity, resource_path in AUTHORITATIVE_RESOURCE_PATHS.items():
        configured_path = str(raw.get(f"{identity}_path", ""))
        configured_hash = str(raw.get(f"{identity}_sha256", ""))
        if configured_path != resource_path or len(configured_hash) != 64:
            raise PreparationError(f"authoritative scratch {identity} pin differs")
        path = _scratch_resource_path(scratch_root, configured_path, identity)
        actual_hash = sha256_file(path)
        if actual_hash != configured_hash:
            raise PreparationError(f"authoritative scratch {identity} hash differs")
        receipt[identity] = {
            "path": configured_path,
            "expected_sha256": configured_hash,
            "actual_sha256": actual_hash,
        }
    return receipt


def _bound_absolute_path(root: Path, raw: str, label: str) -> Path:
    """Resolve a transaction's absolute artifact path and keep it in its run root."""

    if not raw:
        raise PreparationError(f"{label} path is absent")
    path = Path(raw).resolve()
    if not path.is_file() or not _same_or_within(path, root):
        raise PreparationError(f"{label} is missing or outside the export root: {path}")
    return path


def assert_external_roots(export_root: Path, scratch_root: Path) -> None:
    export_root = export_root.resolve()
    scratch_root = scratch_root.resolve()
    if not export_root.is_dir():
        raise PreparationError(f"export root is not a directory: {export_root}")
    for label, path in (("export", export_root), ("scratch", scratch_root)):
        if _same_or_within(path, REPO_ROOT) or _same_or_within(REPO_ROOT, path):
            raise PreparationError(f"{label} root must be external to the repository: {path}")
    if _same_or_within(scratch_root, export_root) or _same_or_within(
        export_root, scratch_root
    ):
        raise PreparationError("scratch and export roots may not contain one another")
    if scratch_root.exists():
        if not scratch_root.is_dir():
            raise PreparationError(f"scratch destination is not a directory: {scratch_root}")
        try:
            next(scratch_root.iterdir())
        except StopIteration:
            pass
        else:
            raise PreparationError(f"scratch destination must be empty: {scratch_root}")


def _require_header(
    receipt: Mapping[str, Any], schema: str, run_id: str, label: str
) -> None:
    if receipt.get("schema") != schema:
        raise PreparationError(f"{label} schema differs: {receipt.get('schema')!r}")
    if receipt.get("status") != "PASS":
        raise PreparationError(f"{label} status is not exact PASS")
    if receipt.get("run_id") != run_id:
        raise PreparationError(f"{label} run_id is stale or mixed")


def _load_partition_receipt(
    export_root: Path, partition: Mapping[str, Any], key: str, label: str
) -> tuple[Path, dict[str, Any]]:
    path = _safe_relative_path(export_root, str(partition.get(key, "")), label)
    return path, load_json(path, label)


def _validate_transaction_artifacts(
    export_root: Path,
    transaction: Mapping[str, Any],
    receipts: Mapping[str, tuple[Path, Mapping[str, Any]]],
) -> None:
    artifacts = transaction.get("artifacts")
    if not isinstance(artifacts, dict):
        raise PreparationError("transaction artifacts map is absent")
    expected_names = set(receipts)
    if set(artifacts) != expected_names:
        raise PreparationError("transaction artifact set is incomplete or contains mixed rows")
    for relative, (path, receipt) in receipts.items():
        row = artifacts.get(relative)
        if not isinstance(row, dict):
            raise PreparationError(f"transaction artifact row is malformed: {relative}")
        if path != _safe_relative_path(export_root, relative, "transaction artifact"):
            raise PreparationError(f"transaction artifact path differs: {relative}")
        expected = {
            "relative_path": relative,
            "sha256": sha256_file(path),
            "schema": str(receipt.get("schema", "")),
            "status": str(receipt.get("status", "")),
        }
        if row != expected:
            raise PreparationError(f"transaction artifact hash/header differs: {relative}")


def _validate_transaction_closure(
    export_root: Path,
    transaction_path: Path,
    transaction: Mapping[str, Any],
    receipts: Mapping[str, tuple[Path, Mapping[str, Any]]],
) -> tuple[Path, Path, Path]:
    for key in ("generated_last", "all_artifacts_bound", "json_artifact_closure_verified"):
        if transaction.get(key) is not True:
            raise PreparationError(f"transaction closure fact is not true: {key}")

    candidate = transaction.get("candidate")
    if not isinstance(candidate, dict):
        raise PreparationError("transaction candidate binding is absent")
    bindings = (
        ("descriptor", "descriptor_path", "descriptor_sha256"),
        ("binary", "binary_path", "binary_sha256"),
        ("generated lineage", "generated_lineage_path", "generated_lineage_sha256"),
    )
    paths: list[Path] = []
    for label, path_key, hash_key in bindings:
        path = _bound_absolute_path(export_root, str(candidate.get(path_key, "")), label)
        digest = str(candidate.get(hash_key, ""))
        if len(digest) != 64 or sha256_file(path) != digest:
            raise PreparationError(f"transaction candidate {label} hash differs")
        paths.append(path)

    bound_json = {Path(relative).as_posix() for relative in receipts}
    bound_json.add(paths[2].relative_to(export_root).as_posix())
    actual_json = {
        path.relative_to(export_root).as_posix()
        for path in export_root.rglob("*.json")
        if path.resolve() != transaction_path.resolve()
    }
    if actual_json != bound_json:
        missing = sorted(actual_json - bound_json)
        stale = sorted(bound_json - actual_json)
        raise PreparationError(
            "transaction JSON closure differs "
            f"(unbound={missing[:4]}, missing={stale[:4]})"
        )

    transaction_mtime = transaction_path.stat().st_mtime_ns
    earlier = [
        path.relative_to(export_root).as_posix()
        for path, _receipt in receipts.values()
        if path.stat().st_mtime_ns > transaction_mtime
    ]
    earlier.extend(
        path.relative_to(export_root).as_posix()
        for path in paths
        if path.stat().st_mtime_ns > transaction_mtime
    )
    if earlier:
        raise PreparationError(
            f"transaction is not generated after its bound artifacts: {earlier[:4]}"
        )
    return paths[0], paths[1], paths[2]


def _validate_cells(
    export_root: Path,
    partition: Mapping[str, Any],
    transaction: Mapping[str, Any],
) -> tuple[dict[str, Any], ...]:
    raw_cells = partition.get("cells")
    transaction_cells = transaction.get("cells")
    if not isinstance(raw_cells, list) or not isinstance(transaction_cells, list):
        raise PreparationError("partition/transaction cell arrays are absent")
    by_transaction = {
        str(row.get("id", "")): row for row in transaction_cells if isinstance(row, dict)
    }
    if len(by_transaction) != len(transaction_cells):
        raise PreparationError("transaction cell IDs are empty or duplicated")
    result: list[dict[str, Any]] = []
    seen: set[str] = set()
    for row in raw_cells:
        if not isinstance(row, dict):
            raise PreparationError("partition cell row is not an object")
        cell_id = str(row.get("id", ""))
        if cell_id in seen or cell_id not in TARGET_CELL_IDS:
            raise PreparationError(f"partition cell ID is duplicated or unknown: {cell_id}")
        seen.add(cell_id)
        transaction_row = by_transaction.get(cell_id)
        if transaction_row is None:
            raise PreparationError(f"transaction omits cell {cell_id}")
        for key in ("gltf_path", "bin_path", "gltf_sha256", "bin_sha256"):
            if transaction_row.get(key) != row.get(key):
                raise PreparationError(f"transaction/partition {cell_id} {key} differs")
        gltf = _safe_relative_path(export_root, str(row.get("gltf_path", "")), "cell glTF")
        binary = _safe_relative_path(export_root, str(row.get("bin_path", "")), "cell BIN")
        for path, key in ((gltf, "gltf_sha256"), (binary, "bin_sha256")):
            digest = str(row.get(key, ""))
            if len(digest) != 64 or sha256_file(path) != digest:
                raise PreparationError(f"{cell_id} {key} is stale or swapped")
        descriptor = load_json(gltf, f"{cell_id} glTF")
        extras = descriptor.get("asset", {}).get("extras", {})
        owner = extras.get("orison_m11c1_owner_first", {}).get("cell")
        if owner != cell_id:
            raise PreparationError(f"{cell_id} glTF embedded owner differs: {owner!r}")
        buffers = descriptor.get("buffers", [])
        if len(buffers) != 1 or buffers[0].get("uri") != binary.name:
            raise PreparationError(f"{cell_id} glTF buffer URI is not its bound BIN")
        copied = dict(row)
        copied["_gltf_absolute"] = gltf
        copied["_bin_absolute"] = binary
        copied["_descriptor"] = descriptor
        result.append(copied)
    if seen != set(TARGET_CELL_IDS):
        raise PreparationError("partition does not contain the canonical seventeen cells")
    result.sort(key=lambda item: TARGET_CELL_IDS.index(str(item["id"])))
    return tuple(result)


def _validate_textures(
    export_root: Path,
    export_receipt: Mapping[str, Any],
    cells: Sequence[Mapping[str, Any]],
) -> tuple[dict[str, Any], ...]:
    library = export_receipt.get("texture_library")
    if not isinstance(library, dict) or not isinstance(library.get("files"), list):
        raise PreparationError("export texture library is absent")
    result: list[dict[str, Any]] = []
    by_source: dict[str, dict[str, Any]] = {}
    total_bytes = 0
    for raw in library["files"]:
        if not isinstance(raw, dict):
            raise PreparationError("texture library row is malformed")
        source_uri = str(raw.get("source_uri", ""))
        output = str(raw.get("output", ""))
        if source_uri in by_source:
            raise PreparationError(f"duplicate texture source URI: {source_uri}")
        path = _safe_relative_path(export_root, output, "shared texture")
        digest = str(raw.get("sha256", ""))
        byte_count = int(raw.get("bytes", -1))
        if len(digest) != 64 or sha256_file(path) != digest or path.stat().st_size != byte_count:
            raise PreparationError(f"texture library hash/size differs: {output}")
        row = dict(raw)
        row["_absolute"] = path
        result.append(row)
        by_source[source_uri] = row
        total_bytes += byte_count
    if int(library.get("file_count", -1)) != len(result) or int(
        library.get("bytes", -1)
    ) != total_bytes:
        raise PreparationError("texture library aggregate differs")
    referenced: set[str] = set()
    for cell in cells:
        descriptor = cell["_descriptor"]
        for image in descriptor.get("images", []):
            uri = str(image.get("uri", ""))
            prefix = "../shared_textures/"
            if not uri.startswith(prefix):
                raise PreparationError(f"{cell['id']} image URI leaves shared texture contract: {uri}")
            source_uri = uri[len(prefix) :]
            if source_uri not in by_source:
                raise PreparationError(f"{cell['id']} references unreceipted texture: {uri}")
            referenced.add(source_uri)
    if referenced != set(by_source):
        missing = sorted(set(by_source) - referenced)
        raise PreparationError(f"texture receipt contains unreferenced files: {missing[:4]}")
    result.sort(key=lambda item: str(item["source_uri"]))
    return tuple(result)


def _validate_semantic_sources(
    lineage: Mapping[str, Any], layout: Mapping[str, Any], regions: Mapping[str, Any]
) -> None:
    rows = lineage.get("semantic_owners")
    if not isinstance(rows, list) or not rows:
        raise PreparationError("lineage semantic_owners is absent")
    identities: dict[str, Mapping[str, Any]] = {}
    f01 = next(
        (
            floor
            for floor in layout.get("floors", [])
            if isinstance(floor, dict) and floor.get("id") == "F01"
        ),
        None,
    )
    if not isinstance(f01, dict):
        raise PreparationError("authoritative layout has no F01 record")
    markers = f01.get("markers")
    if not isinstance(markers, list):
        raise PreparationError("authoritative F01 markers are absent")
    thresholds = {
        str(row.get("id", "")): row
        for row in regions.get("thresholds", [])
        if isinstance(row, dict)
    }
    for row in rows:
        if not isinstance(row, dict):
            raise PreparationError("semantic owner row is malformed")
        identity = str(row.get("identity", ""))
        if not identity or identity in identities:
            raise PreparationError(f"semantic identity is empty or duplicated: {identity}")
        identities[identity] = row
        kind = str(row.get("semantic_kind", ""))
        if kind == "layout_marker":
            match = F01_LOCATOR_RE.match(str(row.get("source_locator", "")))
            if match is None:
                raise PreparationError(f"layout semantic locator is malformed: {identity}")
            index = int(match.group(1))
            if index >= len(markers) or markers[index].get("id") != identity:
                raise PreparationError(f"layout semantic source is stale/missing: {identity}")
        elif kind == "m11a_exterior_threshold":
            threshold = thresholds.get(identity)
            if threshold is None:
                raise PreparationError(f"M11A semantic threshold is missing: {identity}")
            if sha256_bytes(canonical_bytes(threshold)) != row.get("source_record_sha256"):
                raise PreparationError(f"M11A semantic threshold record differs: {identity}")
            if sha256_file(EXTERIOR_REGIONS_PATH) != row.get("source_file_sha256"):
                raise PreparationError("M11A region file differs from threshold lineage")
        else:
            raise PreparationError(f"unknown semantic source kind for {identity}: {kind}")
    missing = sorted(REQUIRED_SEMANTICS - set(identities))
    if missing:
        raise PreparationError(f"required semantic owners are missing: {missing}")


def validate_export(export_root: Path, repo_root: Path = REPO_ROOT) -> ExportBundle:
    export_root = export_root.resolve()
    partition_path = export_root / PARTITION_NAME
    partition = load_json(partition_path, "owner-first partition")
    run_id = str(partition.get("run_id", ""))
    _require_header(partition, PARTITION_SCHEMA, run_id, "partition")
    if not run_id.startswith("M11C1-"):
        raise PreparationError("partition run_id is malformed")
    if Path(str(partition.get("disposable_root", ""))).resolve() != export_root:
        raise PreparationError("partition disposable_root differs from selected export root")
    for key in (
        "owner_before_material",
        "canonical_equivalence_passed",
        "lineage_complete",
        "protected_unchanged",
        "cell_hashes_bound",
    ):
        if partition.get(key) is not True:
            raise PreparationError(f"partition critical fact is not true: {key}")
    for key in ("production_asset", "spatial_inference_used", "legacy_mixed_cell_present"):
        if partition.get(key) is not False:
            raise PreparationError(f"partition critical fact is not false: {key}")
    if partition.get("forbidden_cell_absent") != "CELL_LEGACY_MIXED":
        raise PreparationError("partition does not refuse CELL_LEGACY_MIXED")

    lineage_path, lineage = _load_partition_receipt(
        export_root, partition, "lineage_manifest", "lineage"
    )
    equivalence_path, equivalence = _load_partition_receipt(
        export_root, partition, "equivalence_receipt", "equivalence"
    )
    recomposition_path, recomposition = _load_partition_receipt(
        export_root, partition, "recomposition_receipt", "recomposition"
    )
    export_receipt_path, export_receipt = _load_partition_receipt(
        export_root, partition, "export_receipt", "export receipt"
    )
    transaction_path, transaction = _load_partition_receipt(
        export_root, partition, "transaction_manifest", "transaction"
    )
    _require_header(lineage, LINEAGE_SCHEMA, run_id, "lineage")
    _require_header(equivalence, EQUIVALENCE_SCHEMA, run_id, "equivalence")
    _require_header(recomposition, RECOMPOSITION_SCHEMA, run_id, "recomposition")
    _require_header(export_receipt, EXPORT_SCHEMA, run_id, "export receipt")
    _require_header(transaction, TRANSACTION_SCHEMA, run_id, "transaction")

    # These two source/process receipts are intentionally not partition routing
    # fields, but the final transaction binds them into the same run closure.
    blender_process_path = export_root / "candidate" / "blender_generation_process.json"
    protection_path = export_root / "receipts" / "protected_assets.json"
    blender_process = load_json(blender_process_path, "Blender generation process")
    protection = load_json(protection_path, "protected-assets receipt")
    _require_header(
        blender_process, BLENDER_PROCESS_SCHEMA, run_id, "Blender generation process"
    )
    _require_header(protection, PROTECTION_SCHEMA, run_id, "protected-assets receipt")
    for label, receipt in (
        ("lineage", lineage),
        ("equivalence", equivalence),
        ("recomposition", recomposition),
        ("export receipt", export_receipt),
        ("transaction", transaction),
        ("Blender generation process", blender_process),
        ("protected-assets receipt", protection),
    ):
        if Path(str(receipt.get("disposable_root", export_root))).resolve() != export_root:
            raise PreparationError(f"{label} disposable_root is stale or mixed")

    relative_receipts = {
        str(partition["lineage_manifest"]): (lineage_path, lineage),
        str(partition["equivalence_receipt"]): (equivalence_path, equivalence),
        str(partition["recomposition_receipt"]): (recomposition_path, recomposition),
        str(partition["export_receipt"]): (export_receipt_path, export_receipt),
        PARTITION_NAME: (partition_path, partition),
        "candidate/blender_generation_process.json": (
            blender_process_path,
            blender_process,
        ),
        "receipts/protected_assets.json": (protection_path, protection),
    }
    _validate_transaction_artifacts(export_root, transaction, relative_receipts)
    candidate_paths = _validate_transaction_closure(
        export_root, transaction_path, transaction, relative_receipts
    )

    protected_hashes = {
        "gltf": sha256_file(repo_root / PROTECTED_GLTF.relative_to(REPO_ROOT)),
        "bin": sha256_file(repo_root / PROTECTED_BIN.relative_to(REPO_ROOT)),
    }
    if partition.get("source", {}).get("protected_hashes") != protected_hashes:
        raise PreparationError("actual protected floor_01 hashes differ from transaction")
    if export_receipt.get("protected_hashes_before") != protected_hashes or export_receipt.get(
        "protected_hashes_after"
    ) != protected_hashes:
        raise PreparationError("export receipt protected hash boundary differs")
    authoritative = export_receipt.get("authoritative_input_hashes", {})
    if authoritative.get("layout") != sha256_file(repo_root / LAYOUT_PATH.relative_to(REPO_ROOT)):
        raise PreparationError("authoritative layout hash differs from export transaction")
    if authoritative.get("exterior_regions") != sha256_file(
        repo_root / EXTERIOR_REGIONS_PATH.relative_to(REPO_ROOT)
    ):
        raise PreparationError("M11A regions hash differs from export transaction")

    cells = _validate_cells(export_root, partition, transaction)
    textures = _validate_textures(export_root, export_receipt, cells)
    layout = load_json(repo_root / LAYOUT_PATH.relative_to(REPO_ROOT), "authoritative layout")
    regions = load_json(
        repo_root / EXTERIOR_REGIONS_PATH.relative_to(REPO_ROOT), "M11A regions"
    )
    _validate_semantic_sources(lineage, layout, regions)

    source_paths: list[Path] = [transaction_path]
    source_paths.extend(path for path, _receipt in relative_receipts.values())
    source_paths.extend(candidate_paths)
    for cell in cells:
        source_paths.extend((cell["_gltf_absolute"], cell["_bin_absolute"]))
    source_paths.extend(texture["_absolute"] for texture in textures)
    source_hashes = {
        path.relative_to(export_root).as_posix(): sha256_file(path)
        for path in sorted(set(source_paths))
    }
    return ExportBundle(
        root=export_root,
        partition_path=partition_path,
        partition=partition,
        transaction_path=transaction_path,
        transaction=transaction,
        lineage_path=lineage_path,
        lineage=lineage,
        equivalence_path=equivalence_path,
        equivalence=equivalence,
        recomposition_path=recomposition_path,
        recomposition=recomposition,
        export_receipt_path=export_receipt_path,
        export_receipt=export_receipt,
        cells=cells,
        textures=textures,
        source_hashes=source_hashes,
    )


def _copy_file_exact(source: Path, destination: Path) -> dict[str, Any]:
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, destination)
    source_hash = sha256_file(source)
    if sha256_file(destination) != source_hash:
        raise PreparationError(f"copy hash differs: {source} -> {destination}")
    return {
        "source": str(source),
        "destination": str(destination),
        "bytes": destination.stat().st_size,
        "sha256": source_hash,
    }


def _assert_copy_sources_unchanged(rows: Sequence[Mapping[str, Any]]) -> None:
    changed: list[str] = []
    for row in rows:
        source = Path(str(row.get("source", "")))
        expected = str(row.get("sha256", ""))
        if not source.is_file() or sha256_file(source) != expected:
            changed.append(str(source))
    if changed:
        raise PreparationError(
            f"repository runtime inputs changed during scratch import: {changed[:4]}"
        )


def _copy_manifest(
    rows: Sequence[Mapping[str, Any]], scratch_root: Path
) -> dict[str, Any]:
    files: list[dict[str, Any]] = []
    for row in rows:
        source = Path(str(row["source"])).resolve()
        destination = Path(str(row["destination"])).resolve()
        if not _same_or_within(source, GAME_ROOT) or not _same_or_within(
            destination, scratch_root
        ):
            raise PreparationError("materialized source/destination leaves its governed root")
        source_hash = str(row["sha256"])
        destination_hash = sha256_file(destination)
        files.append(
            {
                "source": source.relative_to(GAME_ROOT).as_posix(),
                "destination": destination.relative_to(scratch_root).as_posix(),
                "bytes": int(row["bytes"]),
                "source_sha256": source_hash,
                "destination_sha256": destination_hash,
                "exact_copy": source_hash == destination_hash,
            }
        )
    files.sort(key=lambda item: (str(item["source"]), str(item["destination"])))
    return {
        "file_count": len(files),
        "source_bytes": sum(int(item["bytes"]) for item in files),
        "files_sha256": sha256_bytes(canonical_bytes(files)),
        "files": files,
    }


def _copy_project_sources(scratch_root: Path) -> list[dict[str, Any]]:
    copied: list[dict[str, Any]] = []
    copied.append(_copy_file_exact(GAME_ROOT / "project.godot", scratch_root / "project.godot"))
    for name in PROJECT_COPY_DIRS:
        source_root = GAME_ROOT / name
        destination_root = scratch_root / name
        for source in sorted(path for path in source_root.rglob("*") if path.is_file()):
            copied.append(
                _copy_file_exact(source, destination_root / source.relative_to(source_root))
            )
    project_path = scratch_root / "project.godot"
    project_text = project_path.read_text(encoding="utf-8")
    isolated_name = "PleaseRemainOnTheLine_M11C1_%s" % "scratch"
    project_text, count = re.subn(
        r'^config/custom_user_dir_name="[^"]*"$',
        f'config/custom_user_dir_name="{isolated_name}"',
        project_text,
        flags=re.MULTILINE,
    )
    if count != 1:
        raise PreparationError("scratch project could not isolate custom user directory")
    project_text = re.sub(
        r"^driver/enable_input=true$",
        "driver/enable_input=false",
        project_text,
        flags=re.MULTILINE,
    )
    project_path.write_text(project_text, encoding="utf-8", newline="\n")
    return copied


def _literal_asset_paths() -> set[Path]:
    result: set[Path] = {PROTECTED_GLTF, PROTECTED_BIN}
    for relative in REQUIRED_DYNAMIC_RUNTIME_ASSETS:
        path = GAME_ROOT.joinpath(*PurePosixPath(relative).parts)
        if not path.is_file():
            raise PreparationError(f"required dynamic runtime asset is absent: {path}")
        result.add(path)
    for relative in REQUIRED_DYNAMIC_RUNTIME_ASSET_DIRS:
        directory = GAME_ROOT.joinpath(*PurePosixPath(relative).parts)
        files = sorted(directory.glob("*.png")) if directory.is_dir() else []
        if not files:
            raise PreparationError(
                f"required dynamic runtime asset directory is absent/empty: {directory}"
            )
        result.update(files)
    for root_name in PROJECT_COPY_DIRS:
        root = GAME_ROOT / root_name
        for source in root.rglob("*"):
            if not source.is_file() or source.suffix.lower() not in {
                ".gd",
                ".tscn",
                ".tres",
                ".json",
            }:
                continue
            try:
                text = source.read_text(encoding="utf-8")
            except UnicodeDecodeError:
                continue
            for match in ASSET_LITERAL_RE.finditer(text):
                raw = match.group(0)
                if "%" in raw:
                    continue
                path = GAME_ROOT / raw.removeprefix("res://")
                if path.is_file():
                    result.add(path)
    material_sets = GAME_ROOT / "scripts" / "generated" / "material_sets.gd"
    for relative in MATERIAL_TEXTURE_RE.findall(material_sets.read_text(encoding="utf-8")):
        path = GAME_ROOT / "assets" / "building" / "textures" / relative
        if not path.is_file():
            raise PreparationError(f"runtime material texture is absent: {path}")
        result.add(path)
    for filename in ("mask_clean.png", "mask_cracked.png", "mask_haze.png"):
        path = GAME_ROOT / "assets" / "ui" / "phone" / filename
        if not path.is_file():
            raise PreparationError(f"PlayerController mask is absent: {path}")
        result.add(path)
    return result


def _copy_gltf_dependencies(source: Path, scratch_root: Path) -> list[dict[str, Any]]:
    if source.suffix.lower() != ".gltf":
        return []
    descriptor = load_json(source, "project glTF")
    copied: list[dict[str, Any]] = []
    uris: list[str] = []
    uris.extend(str(row.get("uri", "")) for row in descriptor.get("buffers", []))
    uris.extend(str(row.get("uri", "")) for row in descriptor.get("images", []))
    for uri in uris:
        if not uri or uri.startswith("data:"):
            continue
        relative = PurePosixPath(uri)
        if relative.is_absolute() or ".." in relative.parts:
            raise PreparationError(f"project glTF has unsafe dependency URI: {source}: {uri}")
        dependency = source.parent.joinpath(*relative.parts)
        if not dependency.is_file():
            raise PreparationError(f"project glTF dependency is absent: {dependency}")
        destination = scratch_root / dependency.relative_to(GAME_ROOT)
        if not destination.exists():
            copied.append(_copy_file_exact(dependency, destination))
    return copied


def _copy_runtime_assets(scratch_root: Path) -> list[dict[str, Any]]:
    copied: list[dict[str, Any]] = []
    for source in sorted(_literal_asset_paths()):
        destination = scratch_root / source.relative_to(GAME_ROOT)
        if not destination.exists():
            copied.append(_copy_file_exact(source, destination))
        copied.extend(_copy_gltf_dependencies(source, scratch_root))
    return copied


def _copy_disposable_bundle(
    bundle: ExportBundle, scratch_root: Path
) -> tuple[list[dict[str, Any]], list[dict[str, Any]], dict[str, str]]:
    disposable_root = scratch_root / "m11c1_disposable"
    cell_rows: list[dict[str, Any]] = []
    resources: dict[str, str] = {}
    for cell in bundle.cells:
        gltf_destination = disposable_root / "cells" / Path(str(cell["gltf_path"])).name
        bin_destination = disposable_root / "cells" / Path(str(cell["bin_path"])).name
        _copy_file_exact(cell["_gltf_absolute"], gltf_destination)
        _copy_file_exact(cell["_bin_absolute"], bin_destination)
        resource_path = "res://" + gltf_destination.relative_to(scratch_root).as_posix()
        resources[str(cell["id"])] = resource_path
        cell_rows.append(
            {
                "id": cell["id"],
                "source_gltf": str(cell["_gltf_absolute"]),
                "source_bin": str(cell["_bin_absolute"]),
                "resource_path": resource_path,
                "scratch_gltf": str(gltf_destination),
                "scratch_bin": str(bin_destination),
                "gltf_sha256": cell["gltf_sha256"],
                "bin_sha256": cell["bin_sha256"],
            }
        )
    texture_rows: list[dict[str, Any]] = []
    for texture in bundle.textures:
        relative = PurePosixPath(str(texture["output"]))
        destination = disposable_root.joinpath(*relative.parts)
        _copy_file_exact(texture["_absolute"], destination)
        # The protected monolith uses the original source URI relative to
        # assets/building.  Reuse the same scratch inode where possible so the
        # protected comparison resource imports without a second 200 MB copy.
        legacy_destination = scratch_root / "assets" / "building"
        for part in PurePosixPath(str(texture["source_uri"])).parts:
            legacy_destination /= part
        legacy_destination.parent.mkdir(parents=True, exist_ok=True)
        if not legacy_destination.exists():
            try:
                os.link(destination, legacy_destination)
                link_mode = "scratch_hardlink"
            except OSError:
                shutil.copy2(destination, legacy_destination)
                link_mode = "scratch_copy"
        elif sha256_file(legacy_destination) != texture["sha256"]:
            raise PreparationError(f"scratch legacy texture collision: {legacy_destination}")
        else:
            link_mode = "existing_exact"
        texture_rows.append(
            {
                "source_uri": texture["source_uri"],
                "source": str(texture["_absolute"]),
                "scratch": str(destination),
                "protected_import_path": str(legacy_destination),
                "link_mode": link_mode,
                "bytes": texture["bytes"],
                "sha256": texture["sha256"],
            }
        )
    return cell_rows, texture_rows, resources


def _marker_index(layout: Mapping[str, Any]) -> dict[str, dict[str, Any]]:
    result: dict[str, dict[str, Any]] = {}
    for floor in layout.get("floors", []):
        if not isinstance(floor, dict) or floor.get("id") != "F01":
            continue
        for marker in floor.get("markers", []):
            if not isinstance(marker, dict):
                continue
            identity = str(marker.get("id", ""))
            if not identity or identity in result:
                raise PreparationError(f"F01 marker identity is empty or duplicated: {identity}")
            result[identity] = marker
    return result


def _b2g(position: Sequence[Any]) -> list[float]:
    if len(position) != 3:
        raise PreparationError(f"Blender position is not length three: {position}")
    return [float(position[0]), float(position[2]), -float(position[1])]


def _marker_aperture_center(marker: Mapping[str, Any]) -> list[float]:
    """Return the source-authored leaf centre, whose marker position is its hinge."""

    import math

    position = marker.get("pos", [])
    if not isinstance(position, list) or len(position) != 3:
        raise PreparationError("door marker hinge position is malformed")
    yaw = math.radians(float(marker.get("yaw_deg", 0.0)))
    width = float(marker.get("w", 0.0))
    if width <= 0.0:
        raise PreparationError("door marker width is not positive")
    # DoorProp and ResidentNav both define local +X in Blender XY as
    # (cos(yaw), -sin(yaw)); preserve that source convention exactly.
    center_blender = [
        float(position[0]) + math.cos(yaw) * width * 0.5,
        float(position[1]) - math.sin(yaw) * width * 0.5,
        float(position[2]),
    ]
    return _b2g(center_blender)


def _opening(
    center: Sequence[float],
    right_axis: Sequence[float],
    width: float,
    height: float,
) -> dict[str, Any]:
    return {
        "center": list(map(float, center)),
        "right_axis": list(map(float, right_axis)),
        "half_width_m": float(width) * 0.5,
        "bottom_y_m": 0.0,
        "top_y_m": float(height),
        "minimum_side_clearance_m": 0.04,
        "minimum_head_clearance_m": 0.04,
    }


def _traversal(
    identity: str,
    start: Sequence[float],
    forward: Sequence[Sequence[float]],
    back: Sequence[Sequence[float]],
    plane_point: Sequence[float],
    plane_normal: Sequence[float],
    opening: Mapping[str, Any],
    expected_owners: Sequence[str],
    *,
    door_identity: str = "",
    door_action: str = "none",
    expectation: str = "crossable",
    shop_cell_id: str = "",
) -> dict[str, Any]:
    row: dict[str, Any] = {
        "id": identity,
        "start": list(map(float, start)),
        "forward_waypoints": [list(map(float, value)) for value in forward],
        "return_waypoints": [list(map(float, value)) for value in back],
        "plane": {
            "point": list(map(float, plane_point)),
            "normal": list(map(float, plane_normal)),
        },
        "opening_bounds": dict(opening),
        "expected_collision_owner_cells": list(expected_owners),
        "door_identity": door_identity,
        "door_action": door_action,
        "expectation": expectation,
        "waypoint_tolerance_m": 0.13,
        "vertical_tolerance_m": 0.16,
        "max_frames_per_waypoint": 420,
        "minimum_grounded_fraction": 0.92,
    }
    if shop_cell_id:
        row["shop_cell_id"] = shop_cell_id
    return row


def _passage_shop_traversals(
    markers: Mapping[str, Mapping[str, Any]]
) -> tuple[list[dict[str, Any]], list[str]]:
    traversals: list[dict[str, Any]] = []
    identities: list[str] = []
    for suffix, cell_id in PASSAGE_SHOPS:
        identity = f"SITE_SHOP_DOOR_{suffix}"
        marker = markers.get(identity)
        if marker is None:
            raise PreparationError(f"Passage source door is missing: {identity}")
        identities.append(identity)
        center = _marker_aperture_center(marker)
        yaw = float(marker.get("yaw_deg", 0.0)) % 360.0
        if yaw not in (90.0, 270.0):
            raise PreparationError(f"Passage door has unsupported authored yaw: {identity}={yaw}")
        west = yaw == 90.0
        passage_x = center[0] + (0.90 if west else -0.90)
        shop_x = center[0] + (-1.10 if west else 1.10)
        start = [passage_x, 0.08, center[2]]
        inside = [shop_x, 0.08, center[2]]
        expectation = "locked_non_crossable" if suffix == "NEWS_CIGARS" else "crossable"
        door_action = (
            "interact_locked_refusal"
            if expectation == "locked_non_crossable"
            else "interact_open"
        )
        traversals.append(
            _traversal(
                f"PASSAGE_{suffix}_{'LOCKED_SERVICE_FRONTAGE' if expectation != 'crossable' else 'BIDIRECTIONAL'}",
                start,
                [inside],
                [start],
                center,
                [1.0, 0.0, 0.0],
                _opening(center, [0.0, 0.0, 1.0], float(marker["w"]), float(marker["h"])),
                ["CELL_PASSAGE", cell_id],
                door_identity=identity,
                door_action=door_action,
                expectation=expectation,
                shop_cell_id=cell_id,
            )
        )
    return traversals, identities


def _build_seams(
    layout: Mapping[str, Any], m11c0: Mapping[str, Any]
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    markers = _marker_index(layout)
    entrance = markers.get("F01_DOOR_06")
    bodega = markers.get("F01_BODEGA_DOOR")
    shoe = markers.get("SITE_SHOP_DOOR_SHOE_REBUILDING")
    if entrance is None or bodega is None or shoe is None:
        raise PreparationError("authoritative entrance/bodega/shoe marker is missing")
    entrance_center = _marker_aperture_center(entrance)
    bodega_center = _marker_aperture_center(bodega)
    passage_traversals, passage_doors = _passage_shop_traversals(markers)
    shop_cells = [cell for _suffix, cell in PASSAGE_SHOPS]
    m11c0_collision_probes = {
        str(row.get("id", "")): row
        for row in m11c0.get("collision_probes", [])
        if isinstance(row, dict)
    }
    orison_floor_probe = m11c0_collision_probes.get("orison_north_floor")
    if (
        not isinstance(orison_floor_probe, dict)
        or orison_floor_probe.get("expect") != "hit"
        or orison_floor_probe.get("seam_id") != "SEAM_ORISON_SOUTH_SHELL_STREET"
        or not isinstance(orison_floor_probe.get("from"), list)
        or len(orison_floor_probe["from"]) != 3
    ):
        raise PreparationError("M11C0 Orison interior floor probe is missing/malformed")
    orison_floor_z = float(orison_floor_probe["from"][2])
    if orison_floor_z - entrance_center[2] < 0.15:
        raise PreparationError("M11C0 Orison floor point lacks a meaningful plane overshoot")

    entrance_opening = _opening(
        entrance_center, [1.0, 0.0, 0.0], float(entrance["w"]), float(entrance["h"])
    )
    bodega_opening = _opening(
        bodega_center, [1.0, 0.0, 0.0], float(bodega["w"]), float(bodega["h"])
    )
    seams = [
        {
            "id": "SEAM_ORISON_SOUTH_SHELL_STREET",
            "cell_ids": [
                "CELL_ORISON_F01_INTERIOR",
                "CELL_ORISON_FACADE_SHELL",
                "CELL_SITE_STREET_COMMON",
            ],
            "door_identities": ["F01_DOOR_06"],
            "expected_collision_owner_cells": [
                "CELL_ORISON_F01_INTERIOR",
                "CELL_ORISON_FACADE_SHELL",
                "CELL_SITE_STREET_COMMON",
            ],
            "traversals": [
                _traversal(
                    "ORISON_STREET_BIDIRECTIONAL",
                    [entrance_center[0], 0.08, 11.25],
                    [[entrance_center[0], 0.08, 8.95]],
                    [[entrance_center[0], 0.08, 11.25]],
                    entrance_center,
                    [0.0, 0.0, 1.0],
                    entrance_opening,
                    [
                        "CELL_ORISON_F01_INTERIOR",
                        "CELL_ORISON_FACADE_SHELL",
                        "CELL_SITE_STREET_COMMON",
                    ],
                    door_identity="F01_DOOR_06",
                    door_action="interact_open",
                )
            ],
        },
        {
            "id": "SEAM_STREET_PASSAGE_PORTAL",
            "cell_ids": ["CELL_SITE_STREET_COMMON", "CELL_PASSAGE"],
            "door_identities": [],
            "expected_collision_owner_cells": ["CELL_SITE_STREET_COMMON", "CELL_PASSAGE"],
            "traversals": [
                _traversal(
                    "STREET_PASSAGE_BIDIRECTIONAL",
                    [14.0, 0.08, 27.20],
                    [[14.0, 0.08, 30.10]],
                    [[14.0, 0.08, 27.20]],
                    [14.0, 0.0, 28.316],
                    [0.0, 0.0, 1.0],
                    _opening([14.0, 0.0, 28.316], [1.0, 0.0, 0.0], 5.6, 3.0),
                    ["CELL_SITE_STREET_COMMON", "CELL_PASSAGE"],
                )
            ],
        },
        {
            "id": "SEAM_PASSAGE_SHOP_AISLES",
            "cell_ids": ["CELL_PASSAGE", *shop_cells],
            "coverage_cells": shop_cells,
            "door_identities": passage_doors,
            "expected_collision_owner_cells": ["CELL_PASSAGE", *shop_cells],
            "collision_probes": [
                {
                    "id": "M11C0_PASSAGE_AISLE_WEST_055",
                    "from": [11.02, 2.0, 45.0],
                    "to": [11.02, -1.0, 45.0],
                    "expected_owner_cell": "CELL_PASSAGE",
                    "forbidden_owner_cell": "CELL_SHOP_SHOE_REBUILDING",
                    "legacy_hit_elevation_m": 0.55,
                }
            ],
            "traversals": passage_traversals,
        },
        {
            "id": "SEAM_BODEGA_STREET",
            "cell_ids": ["CELL_SITE_STREET_COMMON", "CELL_SHOP_BODEGA"],
            "door_identities": ["F01_BODEGA_DOOR"],
            "expected_collision_owner_cells": ["CELL_SITE_STREET_COMMON", "CELL_SHOP_BODEGA"],
            "traversals": [
                _traversal(
                    "BODEGA_STREET_BIDIRECTIONAL",
                    [bodega_center[0], 0.08, 13.10],
                    [[bodega_center[0], 0.08, 10.65]],
                    [[bodega_center[0], 0.08, 13.10]],
                    bodega_center,
                    [0.0, 0.0, 1.0],
                    bodega_opening,
                    ["CELL_SITE_STREET_COMMON", "CELL_SHOP_BODEGA"],
                    door_identity="F01_BODEGA_DOOR",
                    door_action="interact_open",
                )
            ],
        },
        {
            "id": "SEAM_SHELL_INTERIOR",
            "cell_ids": ["CELL_ORISON_FACADE_SHELL", "CELL_ORISON_F01_INTERIOR"],
            "door_identities": ["F01_DOOR_06"],
            "expected_collision_owner_cells": [
                "CELL_ORISON_FACADE_SHELL",
                "CELL_ORISON_F01_INTERIOR",
            ],
            "traversals": [
                _traversal(
                    "FACADE_INTERIOR_BIDIRECTIONAL",
                    [entrance_center[0], 0.08, orison_floor_z],
                    [[entrance_center[0], 0.08, 8.90]],
                    [[entrance_center[0], 0.08, orison_floor_z]],
                    entrance_center,
                    [0.0, 0.0, 1.0],
                    entrance_opening,
                    ["CELL_ORISON_FACADE_SHELL", "CELL_ORISON_F01_INTERIOR"],
                    door_identity="F01_DOOR_06",
                    door_action="interact_open",
                )
            ],
        },
    ]

    m11c0_views = {
        str(row.get("seam_id", "")): dict(row)
        for row in m11c0.get("capture_views", [])
        if isinstance(row, dict)
    }
    views: list[dict[str, Any]] = []
    cell_sets = {str(row["id"]): row["cell_ids"] for row in seams}
    for seam_id in (
        "SEAM_ORISON_SOUTH_SHELL_STREET",
        "SEAM_STREET_PASSAGE_PORTAL",
        "SEAM_PASSAGE_SHOP_AISLES",
        "SEAM_BODEGA_STREET",
    ):
        source = m11c0_views.get(seam_id)
        if source is None:
            raise PreparationError(f"M11C0 capture source is missing: {seam_id}")
        source["cell_ids"] = cell_sets[seam_id]
        if seam_id == "SEAM_PASSAGE_SHOP_AISLES":
            # Keep the M11C0 Passage station's authored aisle X and eye height,
            # but station it opposite the actual shoe leaf centre. The visual
            # packet therefore shows the source-owned aperture implicated by
            # the 0.55 m regression, without inspecting generated geometry.
            shoe_center = _marker_aperture_center(shoe)
            source_eye = source.get("eye", [])
            if not isinstance(source_eye, list) or len(source_eye) != 3:
                raise PreparationError("M11C0 Passage capture eye is malformed")
            source["eye"] = [
                float(source_eye[0]),
                float(source_eye[1]),
                shoe_center[2],
            ]
            source["target"] = [
                shoe_center[0],
                shoe_center[1] + float(shoe["h"]) * 0.5,
                shoe_center[2],
            ]
        views.append(source)
    views.append(
        {
            "id": "facade_shell_interior",
            "seam_id": "SEAM_SHELL_INTERIOR",
            "cell_ids": cell_sets["SEAM_SHELL_INTERIOR"],
            "eye": [entrance_center[0], 1.41, 8.25],
            "target": [entrance_center[0], 1.20, entrance_center[2]],
            "fov_degrees": 64.0,
        }
    )
    return seams, views


def _passage_service_point(marker: Mapping[str, Any]) -> list[float]:
    """Match ResidentNav.passage_spots for the locked NEWS customer frontage."""

    import math

    p = marker.get("pos", [])
    if not isinstance(p, list) or len(p) != 3:
        raise PreparationError("Passage service marker position is malformed")
    yaw = math.radians(float(marker.get("yaw_deg", 0.0)))
    width = float(marker.get("w", 0.95))
    along = [math.cos(yaw), -math.sin(yaw)]
    outward = [math.sin(yaw), -math.cos(yaw)]
    service = [
        float(p[0]) + along[0] * (width + 0.34),
        float(p[1]) + along[1] * (width + 0.34),
    ]
    venue = [
        service[0] + outward[0] * 0.40,
        service[1] + outward[1] * 0.40,
        0.06,
    ]
    return _b2g(venue)


def _resident_nav_queries(
    layout: Mapping[str, Any], seams: Sequence[Mapping[str, Any]]
) -> list[dict[str, Any]]:
    markers = _marker_index(layout)
    queries: list[dict[str, Any]] = []
    seam_by_id = {str(row["id"]): row for row in seams}
    passage_traversal_by_cell = {
        str(row["shop_cell_id"]): row
        for row in seam_by_id["SEAM_PASSAGE_SHOP_AISLES"]["traversals"]
    }

    # Every dangerous seam gets a route query over the same authored endpoints
    # used by collision traversal. Passage expands to all eleven source-owned
    # frontages. NEWS terminates at ResidentNav's real customer-side service
    # point rather than pretending the proprietor's locked leaf is crossable.
    for seam_id in (
        "SEAM_ORISON_SOUTH_SHELL_STREET",
        "SEAM_STREET_PASSAGE_PORTAL",
        "SEAM_BODEGA_STREET",
        "SEAM_SHELL_INTERIOR",
    ):
        seam = seam_by_id[seam_id]
        traversal = seam["traversals"][0]
        queries.append(
            {
                "id": f"NAV_{seam_id.removeprefix('SEAM_')}",
                "seam_id": seam_id,
                "cell_ids": list(seam["cell_ids"]),
                "from": list(traversal["start"]),
                "to": list(traversal["forward_waypoints"][-1]),
                "expected_reachable": True,
                "terminal_tolerance_m": 0.20,
            }
        )

    for suffix, cell_id in PASSAGE_SHOPS:
        marker = markers[f"SITE_SHOP_DOOR_{suffix}"]
        traversal = passage_traversal_by_cell[cell_id]
        query: dict[str, Any] = {
            "id": f"PASSAGE_NAV_{suffix}",
            "seam_id": "SEAM_PASSAGE_SHOP_AISLES",
            "cell_ids": ["CELL_PASSAGE", cell_id],
            "shop_cell_id": cell_id,
            "from": [14.0, 0.06, 28.70],
            "to": list(traversal["forward_waypoints"][-1]),
            "expected_reachable": True,
            "terminal_tolerance_m": 0.20,
        }
        if suffix == "NEWS_CIGARS":
            query["to"] = _passage_service_point(marker)
            query["passage_place"] = "news_cigars"
        queries.append(query)
    return queries


def build_runtime_config(
    bundle: ExportBundle, scratch_root: Path, resources: Mapping[str, str]
) -> dict[str, Any]:
    layout = load_json(LAYOUT_PATH, "authoritative layout")
    m11c0 = load_json(M11C0_MANIFEST, "M11C0 seam/capture manifest")
    seams, capture_views = _build_seams(layout, m11c0)
    semantic_expectations = [
        {
            "identity": row["identity"],
            "owner_cell": row["owner_cell"],
            "role": row["semantic_kind"],
        }
        for row in bundle.lineage["semantic_owners"]
    ]
    semantic_expectations.sort(key=lambda row: str(row["identity"]))
    residency_sets = [
        {"id": "ORISON_INTERIOR_PLUS_FACADE", "cell_ids": [
            "CELL_ORISON_F01_INTERIOR", "CELL_ORISON_FACADE_SHELL"]},
        {"id": "STREET_PLUS_FACADE", "cell_ids": [
            "CELL_SITE_STREET_COMMON", "CELL_ORISON_FACADE_SHELL"]},
        {"id": "PASSAGE_ONLY", "cell_ids": ["CELL_PASSAGE"]},
        {"id": "SHOP_BAR_ONLY", "cell_ids": ["CELL_SHOP_BAR"]},
        {"id": "SHOP_BODEGA_ONLY", "cell_ids": ["CELL_SHOP_BODEGA"]},
        {"id": "SHOP_MODEL_LAUNDRY_ONLY", "cell_ids": ["CELL_SHOP_MODEL_LAUNDRY"]},
        {"id": "SHOP_SHOE_REBUILDING_ONLY", "cell_ids": ["CELL_SHOP_SHOE_REBUILDING"]},
        {"id": "SHOP_KEYS_CUT_ONLY", "cell_ids": ["CELL_SHOP_KEYS_CUT"]},
        {"id": "SHOP_HARDWARE_PAINT_ONLY", "cell_ids": ["CELL_SHOP_HARDWARE_PAINT"]},
        {"id": "SHOP_FUNERAL_PARLOUR_ONLY", "cell_ids": ["CELL_SHOP_FUNERAL_PARLOUR"]},
        {"id": "SHOP_PHOTO_SUPPLIES_ONLY", "cell_ids": ["CELL_SHOP_PHOTO_SUPPLIES"]},
        {"id": "SHOP_RADIO_SERVICE_ONLY", "cell_ids": ["CELL_SHOP_RADIO_SERVICE"]},
        {"id": "SHOP_PAWNBROKER_ONLY", "cell_ids": ["CELL_SHOP_PAWNBROKER"]},
        {"id": "SHOP_NEWS_CIGARS_ONLY", "cell_ids": ["CELL_SHOP_NEWS_CIGARS"]},
        {"id": "SHOP_OTIS_SON_ONLY", "cell_ids": ["CELL_SHOP_OTIS_SON"]},
        {"id": "SHOP_LUNCHEONETTE_ONLY", "cell_ids": ["CELL_SHOP_LUNCHEONETTE"]},
        {"id": "FULL_RECOMPOSITION", "cell_ids": list(TARGET_CELL_IDS)},
    ]
    protected = bundle.partition["source"]["protected_hashes"]
    return {
        "schema": CONFIG_SCHEMA,
        "authority": "disposable_harness_only",
        "partition_manifest": bundle.partition_path.as_posix(),
        "lineage_manifest": bundle.lineage_path.as_posix(),
        "equivalence_receipt": bundle.equivalence_path.as_posix(),
        "protected_source": {
            "gltf_path": "res://assets/building/floor_01.gltf",
            "bin_path": "res://assets/building/floor_01.bin",
            "gltf_sha256": protected["gltf"],
            "bin_sha256": protected["bin"],
        },
        "authoritative_sources": {
            "layout_path": AUTHORITATIVE_RESOURCE_PATHS["layout"],
            "layout_sha256": sha256_file(LAYOUT_PATH),
            "exterior_regions_path": AUTHORITATIVE_RESOURCE_PATHS[
                "exterior_regions"
            ],
            "exterior_regions_sha256": sha256_file(EXTERIOR_REGIONS_PATH),
        },
        "cell_resources": dict(sorted(resources.items())),
        "residency_sets": residency_sets,
        "semantic_expectations": semantic_expectations,
        "semantic_family_contract": {
            "prefix": "SITE_SHOP_",
            "required_subprefixes": [
                "SITE_SHOP_DOOR_",
                "SITE_SHOP_HOURS_",
                "SITE_SHOP_SIGN_",
                "SITE_SHOP_LT_",
                "SITE_SHOP_IN",
            ],
            "coverage": "exact_lineage_identity_set",
        },
        "seams": seams,
        "capture_views": capture_views,
        "resident_nav_queries": _resident_nav_queries(layout, seams),
        "save_reconstruction": {
            "state_id": "PLAYER_EXTERIOR_ROUTE",
            "route_id": "ROUTE_ORISON_TO_SHOP_BODEGA",
            "waypoint_id": "PAVEMENT_TURN",
            "threshold_id": "THRESHOLD_SHOP_BODEGA_FRONT",
            "required_cell_ids": list(TARGET_CELL_IDS),
        },
    }


def validate_runtime_config_cross_bindings(config: Mapping[str, Any]) -> None:
    raw_seams = config.get("seams")
    raw_views = config.get("capture_views")
    if not isinstance(raw_seams, list) or not isinstance(raw_views, list):
        raise PreparationError("runtime seam/capture arrays are absent")
    seams: dict[str, Mapping[str, Any]] = {}
    for row in raw_seams:
        if not isinstance(row, dict):
            raise PreparationError("runtime seam row is malformed")
        identity = str(row.get("id", ""))
        if not identity or identity in seams:
            raise PreparationError(f"runtime seam ID is empty/duplicated: {identity}")
        seams[identity] = row
    views: dict[str, Mapping[str, Any]] = {}
    for row in raw_views:
        if not isinstance(row, dict):
            raise PreparationError("runtime capture view is malformed")
        seam_id = str(row.get("seam_id", ""))
        if not seam_id or seam_id in views:
            raise PreparationError(
                f"runtime capture seam is empty/duplicated: {seam_id}"
            )
        views[seam_id] = row
    if set(views) != set(seams):
        raise PreparationError("runtime capture views do not cover seams exactly once")
    for seam_id, seam in seams.items():
        if views[seam_id].get("cell_ids") != seam.get("cell_ids"):
            raise PreparationError(
                f"runtime capture cells differ from seam membership: {seam_id}"
            )


def _discover_godot() -> Path:
    def usable(path: Path) -> bool:
        if not path.is_file():
            return False
        if path.name.lower().endswith("_console.exe"):
            main_name = path.name[: -len("_console.exe")] + ".exe"
            return path.with_name(main_name).is_file()
        return True

    for name in (
        "Godot_v4.7.1-stable_win64_console.exe",
        "godot4",
        "godot",
    ):
        found = shutil.which(name)
        if found and usable(Path(found).resolve()):
            return Path(found).resolve()
    if os.name == "nt":
        local = Path(os.environ.get("LOCALAPPDATA", ""))
        pattern = (
            "Microsoft/WinGet/Packages/GodotEngine.GodotEngine_*"
            "/Godot_v4.7.1-stable_win64_console.exe"
        )
        matches = sorted(local.glob(pattern)) if local else []
        for match in reversed(matches):
            if usable(match.resolve()):
                return match.resolve()
    raise PreparationError("Godot 4.7.1 console executable was not found automatically")


def _run_godot_import(scratch_root: Path) -> dict[str, Any]:
    godot = _discover_godot()
    receipt_root = scratch_root / "m11c1_receipts"
    receipt_root.mkdir(parents=True, exist_ok=True)
    command = [str(godot), "--headless", "--editor", "--path", str(scratch_root), "--import"]
    completed = subprocess.run(
        command,
        cwd=scratch_root,
        text=True,
        encoding="utf-8",
        errors="replace",
        capture_output=True,
        timeout=1200,
        check=False,
        env={**os.environ, "GODOT_AUDIO_DRIVER": "Dummy"},
    )
    stdout_path = receipt_root / "godot_import_stdout.log"
    stderr_path = receipt_root / "godot_import_stderr.log"
    stdout_path.write_text(completed.stdout, encoding="utf-8", newline="\n")
    stderr_path.write_text(completed.stderr, encoding="utf-8", newline="\n")
    combined = completed.stdout + "\n" + completed.stderr
    hard_errors = [
        line
        for line in combined.splitlines()
        if "SCRIPT ERROR:" in line or line.lstrip().startswith("ERROR:")
    ]
    if completed.returncode != 0 or hard_errors:
        raise PreparationError(
            "scratch Godot import failed: exit %d; errors=%s"
            % (completed.returncode, hard_errors[:8])
        )
    version = subprocess.run(
        [str(godot), "--version"],
        text=True,
        encoding="utf-8",
        errors="replace",
        capture_output=True,
        timeout=30,
        check=False,
    )
    return {
        "status": "PASS",
        "godot": str(godot),
        "version": version.stdout.strip(),
        "command": command,
        "cwd": str(scratch_root),
        "exit_code": completed.returncode,
        "stdout": str(stdout_path),
        "stdout_sha256": sha256_file(stdout_path),
        "stderr": str(stderr_path),
        "stderr_sha256": sha256_file(stderr_path),
        "hard_error_lines": [],
        "import_root": str(scratch_root / ".godot" / "imported"),
    }


def _import_mapping(
    scratch_root: Path, cell_rows: Sequence[Mapping[str, Any]]
) -> list[dict[str, Any]]:
    imported_root = scratch_root / ".godot" / "imported"
    rows: list[dict[str, Any]] = []
    for cell in cell_rows:
        basename = Path(str(cell["scratch_gltf"])).name
        artifacts = sorted(imported_root.glob(f"{basename}-*"))
        scene_artifacts = [path for path in artifacts if path.suffix == ".scn"]
        if len(scene_artifacts) != 1:
            raise PreparationError(
                f"Godot import did not emit exactly one scene for {cell['id']}: {scene_artifacts}"
            )
        rows.append(
            {
                "id": cell["id"],
                "resource_path": cell["resource_path"],
                "source_gltf_sha256": cell["gltf_sha256"],
                "source_bin_sha256": cell["bin_sha256"],
                "imported_artifacts": [
                    {
                        "path": str(path),
                        "bytes": path.stat().st_size,
                        "sha256": sha256_file(path),
                    }
                    for path in artifacts
                    if path.is_file()
                ],
            }
        )
    return rows


def prepare(export_root: Path, scratch_root: Path) -> dict[str, Any]:
    export_root = export_root.resolve()
    scratch_root = scratch_root.resolve()
    assert_external_roots(export_root, scratch_root)
    bundle = validate_export(export_root)
    scratch_root.mkdir(parents=True, exist_ok=False) if not scratch_root.exists() else None
    project_files = _copy_project_sources(scratch_root)
    asset_files = _copy_runtime_assets(scratch_root)
    cell_rows, texture_rows, resources = _copy_disposable_bundle(bundle, scratch_root)
    config = build_runtime_config(bundle, scratch_root, resources)
    validate_runtime_config_cross_bindings(config)
    config_path = scratch_root / "m11c1_runtime_config.json"
    write_json(config_path, config)
    config_source_hashes_before = {
        "m11c0_seam_capture_manifest": sha256_file(M11C0_MANIFEST),
        "runtime_config_schema": sha256_file(CONFIG_SCHEMA_PATH),
    }
    authoritative_scratch_before = validate_scratch_authoritative_sources(
        config, scratch_root
    )
    import_receipt = _run_godot_import(scratch_root)
    import_mapping = _import_mapping(scratch_root, cell_rows)

    _assert_copy_sources_unchanged(project_files)
    _assert_copy_sources_unchanged(asset_files)
    authoritative_scratch_after = validate_scratch_authoritative_sources(
        config, scratch_root
    )
    if authoritative_scratch_after != authoritative_scratch_before:
        raise PreparationError("scratch authoritative inputs changed during import")
    config_source_hashes_after = {
        "m11c0_seam_capture_manifest": sha256_file(M11C0_MANIFEST),
        "runtime_config_schema": sha256_file(CONFIG_SCHEMA_PATH),
    }
    if config_source_hashes_after != config_source_hashes_before:
        raise PreparationError("runtime config source contract changed during import")
    project_source_manifest = _copy_manifest(project_files, scratch_root)
    runtime_asset_manifest = _copy_manifest(asset_files, scratch_root)

    after_source_hashes = {
        relative: sha256_file(export_root.joinpath(*PurePosixPath(relative).parts))
        for relative in bundle.source_hashes
    }
    if after_source_hashes != bundle.source_hashes:
        raise PreparationError("read-only export transaction changed during materialization/import")
    protected_after = {
        "gltf": sha256_file(PROTECTED_GLTF),
        "bin": sha256_file(PROTECTED_BIN),
        "layout": sha256_file(LAYOUT_PATH),
        "exterior_regions": sha256_file(EXTERIOR_REGIONS_PATH),
    }
    expected_protected = {
        "gltf": bundle.partition["source"]["protected_hashes"]["gltf"],
        "bin": bundle.partition["source"]["protected_hashes"]["bin"],
        "layout": bundle.export_receipt["authoritative_input_hashes"]["layout"],
        "exterior_regions": bundle.export_receipt["authoritative_input_hashes"][
            "exterior_regions"
        ],
    }
    if protected_after != expected_protected:
        raise PreparationError("repository protected/authoritative files changed")

    receipt = {
        "schema": MATERIALIZATION_SCHEMA,
        "status": "PASS",
        "authority": "disposable_harness_only",
        "production_mutation": False,
        "run_id": bundle.partition["run_id"],
        "repo_root": str(REPO_ROOT),
        "export_root": str(export_root),
        "scratch_root": str(scratch_root),
        "input_binding": {
            "partition": str(bundle.partition_path),
            "partition_sha256": sha256_file(bundle.partition_path),
            "lineage": str(bundle.lineage_path),
            "lineage_sha256": sha256_file(bundle.lineage_path),
            "equivalence": str(bundle.equivalence_path),
            "equivalence_sha256": sha256_file(bundle.equivalence_path),
            "transaction": str(bundle.transaction_path),
            "transaction_sha256": sha256_file(bundle.transaction_path),
            "transaction_artifacts": bundle.transaction["artifacts"],
            "candidate": bundle.transaction["candidate"],
            "cell_hashes_bound": True,
            "all_receipts_same_run": True,
            "authoritative_layout": str(LAYOUT_PATH),
            "authoritative_layout_sha256": sha256_file(LAYOUT_PATH),
            "m11a_exterior_regions": str(EXTERIOR_REGIONS_PATH),
            "m11a_exterior_regions_sha256": sha256_file(EXTERIOR_REGIONS_PATH),
            "m11c0_seam_capture_manifest": str(M11C0_MANIFEST),
            "m11c0_seam_capture_manifest_sha256": config_source_hashes_after[
                "m11c0_seam_capture_manifest"
            ],
            "runtime_config_schema": str(CONFIG_SCHEMA_PATH),
            "runtime_config_schema_sha256": config_source_hashes_after[
                "runtime_config_schema"
            ],
        },
        "protected_hashes": protected_after,
        "scratch_authoritative_sources": authoritative_scratch_after,
        "export_source_unchanged": True,
        "export_source_file_count": len(bundle.source_hashes),
        "project_materialization": {
            "mode": "minimal_real_project_copy",
            "source_dirs": list(PROJECT_COPY_DIRS),
            "project_file_count": len(project_files),
            "runtime_asset_file_count": len(asset_files),
            "project_source_manifest": project_source_manifest,
            "runtime_asset_manifest": runtime_asset_manifest,
            "isolated_user_directory": True,
            "audio_input_disabled_in_scratch_only": True,
        },
        "cells": cell_rows,
        "cell_count": len(cell_rows),
        "textures": texture_rows,
        "texture_count": len(texture_rows),
        "runtime_config": {
            "path": str(config_path),
            "sha256": sha256_file(config_path),
            "resource_mapping_count": len(resources),
            "semantic_expectation_count": len(config["semantic_expectations"]),
            "seam_count": len(config["seams"]),
            "passage_traversal_count": len(
                next(
                    seam["traversals"]
                    for seam in config["seams"]
                    if seam["id"] == "SEAM_PASSAGE_SHOP_AISLES"
                )
            ),
            "passage_crossable_count": 10,
            "news_cigars_locked_service_frontage_count": 1,
            "capture_view_count": len(config["capture_views"]),
        },
        "godot_import": import_receipt,
        "import_mapping": import_mapping,
    }
    receipt_path = scratch_root / "m11c1_receipts" / "materialization_receipt.json"
    write_json(receipt_path, receipt)
    receipt["receipt_path"] = str(receipt_path)
    receipt["receipt_sha256"] = sha256_file(receipt_path)
    return receipt


def _parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--export-root", type=Path, required=True)
    parser.add_argument("--scratch-root", type=Path, required=True)
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = _parse_args(argv)
    try:
        receipt = prepare(args.export_root, args.scratch_root)
    except PreparationError as exc:
        print(f"M11C1 runtime rehearsal preparation refused: {exc}", file=sys.stderr)
        return 2
    print(
        json.dumps(
            {
                "status": receipt["status"],
                "run_id": receipt["run_id"],
                "scratch_root": receipt["scratch_root"],
                "runtime_config": receipt["runtime_config"]["path"],
                "receipt": receipt["receipt_path"],
            },
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
