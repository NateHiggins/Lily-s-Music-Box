#!/usr/bin/env python3
"""Build and verify the production owner-first F01 cell set.

The reviewed M11C1 generator remains the only geometry/provenance
implementation.  This command runs that strict exporter in an external
temporary directory, converts only deployment metadata and texture URIs, and
then either installs or byte-checks the exact production artifact allowlist.

The protected ``floor_01.gltf``/``.bin`` monolith is comparison and rollback
input.  It is never an output of this command.  The F01 ownership sidecar is
also input-only; no second ownership table is authored here.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import sys
import tempfile
from typing import Any, Iterable, Mapping


REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tools.m11c1_floor01_owner_first.owner_first_export import (  # noqa: E402
    CELL_IDS,
    CELL_SLUGS,
    OwnerFirstError,
)
from tools.m11c1_floor01_owner_first.run_disposable_export import (  # noqa: E402
    run_disposable_export,
)


SCHEMA_LINEAGE = "orison.floor01.production-owner-lineage.v1"
SCHEMA_ALIASES = "orison.floor01.production-compatibility-aliases.v1"
SCHEMA_ASSETS = "orison.floor01.production-cell-assets.v1"
SCHEMA_REGISTRY = "orison.floor01.cell-registry.v1"
STATUS_PASS = "PASS"
DEFAULT_MODE = "owner_first_cells"
LEGACY_MODE = "legacy_monolith"
LEGACY_MONOLITH = "res://assets/building/floor_01.gltf"

ASSET_ROOT_REL = PurePosixPath("game/assets/building/floor_01_cells")
REGISTRY_REL = PurePosixPath("game/data/floor_01_cell_registry.json")
LINEAGE_NAME = "floor01_owner_first_lineage.json"
ALIASES_NAME = "floor01_compatibility_aliases.json"
ASSET_MANIFEST_NAME = "floor01_asset_manifest.json"

OWNERSHIP_REL = PurePosixPath("art/data/m11c1/floor01_source_ownership.json")
LAYOUT_REL = PurePosixPath("art/data/building_layout.json")
LAYOUT_MIRROR_REL = PurePosixPath("game/data/building_layout.json")
GENERATOR_REL = PurePosixPath("art/blender/scripts/build_orison.py")
ADAPTER_REL = PurePosixPath(
    "tools/m11c1_floor01_owner_first/generate_owner_first_candidate.py")
PRODUCTION_EXPORTER_REL = PurePosixPath(
    "tools/m11c2_floor01_production/export_floor01_cells.py")
EXTERIOR_REGIONS_REL = PurePosixPath(
    "game/data/orison_v2/exterior/regions.json")

PROTECTED_RELATIVE_PATHS = (
    LAYOUT_REL,
    LAYOUT_MIRROR_REL,
    PurePosixPath("game/scripts/building/building_root_selector.gd"),
    *(PurePosixPath(f"game/assets/building/{stem}.{suffix}")
      for stem in (
          "floor_01", "floor_02", "floor_03", "floor_04", "floor_05",
          "floor_06", "floor_b1", "roof")
      for suffix in ("gltf", "bin")),
)

INTERIOR = "CELL_ORISON_F01_INTERIOR"
FACADE = "CELL_ORISON_FACADE_SHELL"
STREET = "CELL_SITE_STREET_COMMON"
PASSAGE = "CELL_PASSAGE"

FACADE_SHARING = (
    {
        "id": "F01_ORISON_INTERIOR_FACADE",
        "cell_ids": [INTERIOR, FACADE],
        "rule": "facade remains independently owned and co-resident for the "
                "interior envelope view",
    },
    {
        "id": "F01_STREET_FACADE",
        "cell_ids": [STREET, FACADE],
        "rule": "the same facade cell is shared by the street-side envelope "
                "without geometry duplication",
    },
)

_HOST_PATH_RE = re.compile(r"^[A-Za-z]:[\\/]")
_HASH_RE = re.compile(r"^[0-9a-f]{64}$")
_REHEARSAL_TEXTURE_PREFIX = "../shared_textures/textures/"
_PRODUCTION_TEXTURE_PREFIX = "../textures/"


class ProductionExportError(RuntimeError):
    """Fail-closed production generation or installation error."""


def _repo_path(root: Path, relative: PurePosixPath) -> Path:
    result = root.resolve().joinpath(*relative.parts).resolve()
    if not result.is_relative_to(root.resolve()):
        raise ProductionExportError(f"path leaves repository root: {relative}")
    return result


def _sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _json_bytes(value: Any) -> bytes:
    return (json.dumps(
        value, ensure_ascii=False, sort_keys=True, indent=2, allow_nan=False,
    ) + "\n").encode("utf-8")


def _load_json(path: Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise ProductionExportError(f"could not read {label} {path}: {error}") from error
    if not isinstance(value, dict):
        raise ProductionExportError(f"{label} must be a JSON object")
    return value


def _assert_no_host_paths(value: Any, label: str = "root") -> None:
    if isinstance(value, Mapping):
        for key, child in value.items():
            _assert_no_host_paths(child, f"{label}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            _assert_no_host_paths(child, f"{label}[{index}]")
    elif isinstance(value, str):
        if _HOST_PATH_RE.match(value) or (value.startswith("/") and not value.startswith("//")):
            raise ProductionExportError(
                f"production manifest contains a host-absolute path at {label}: {value}")


def collect_protected_hashes(repo_root: Path = REPO_ROOT) -> dict[str, str]:
    """Hash every production input that this bounded cut must not rewrite."""

    result: dict[str, str] = {}
    for relative in PROTECTED_RELATIVE_PATHS:
        path = _repo_path(repo_root, relative)
        if not path.is_file():
            raise ProductionExportError(f"protected input is absent: {relative}")
        result[relative.as_posix()] = _sha256_file(path)
    return result


def _require_rehearsal_receipt(
        root: Path, relative: str, schema: str) -> dict[str, Any]:
    value = _load_json(root.joinpath(*PurePosixPath(relative).parts), relative)
    if value.get("schema") != schema or value.get("status") != STATUS_PASS:
        raise ProductionExportError(f"rehearsal receipt is not a bound PASS: {relative}")
    return value


def _production_resource(slug: str) -> str:
    return f"res://assets/building/floor_01_cells/{slug}.gltf"


def _production_bin_resource(slug: str) -> str:
    return f"res://assets/building/floor_01_cells/{slug}.bin"


def _canonicalize_cell(
        *, export_root: Path, repo_root: Path, row: Mapping[str, Any],
) -> tuple[bytes, bytes, list[dict[str, Any]]]:
    cell_id = str(row.get("id", ""))
    slug = str(row.get("slug", ""))
    if cell_id not in CELL_IDS or CELL_SLUGS.get(cell_id) != slug:
        raise ProductionExportError(f"unknown or noncanonical cell row: {cell_id}/{slug}")
    source_gltf = export_root.joinpath(*PurePosixPath(
        str(row.get("gltf_path", ""))).parts)
    source_bin = export_root.joinpath(*PurePosixPath(
        str(row.get("bin_path", ""))).parts)
    if not source_gltf.is_file() or not source_bin.is_file():
        raise ProductionExportError(f"rehearsal cell files are absent for {cell_id}")
    if (_sha256_file(source_gltf) != row.get("gltf_sha256")
            or _sha256_file(source_bin) != row.get("bin_sha256")):
        raise ProductionExportError(f"rehearsal cell hash differs for {cell_id}")

    document = _load_json(source_gltf, f"rehearsal cell {cell_id}")
    asset = document.get("asset")
    if not isinstance(asset, dict):
        raise ProductionExportError(f"cell {cell_id} has no glTF asset block")
    extras = asset.get("extras")
    if not isinstance(extras, dict):
        raise ProductionExportError(f"cell {cell_id} has no provenance extras")
    candidate = extras.pop("orison_m11c1_candidate", None)
    owner_first = extras.pop("orison_m11c1_owner_first", None)
    extras.pop("m11c0_rehearsal", None)
    if (not isinstance(candidate, dict)
            or candidate.get("production_asset") is not False
            or candidate.get("owner_before_material") is not True
            or candidate.get("spatial_inference_used") is not False):
        raise ProductionExportError(f"cell {cell_id} candidate provenance drifted")
    if (not isinstance(owner_first, dict)
            or owner_first.get("cell") != cell_id
            or owner_first.get("production_asset") is not False
            or owner_first.get("owner_before_material") is not True
            or owner_first.get("spatial_inference_used") is not False):
        raise ProductionExportError(f"cell {cell_id} owner provenance drifted")
    binary = source_bin.read_bytes()
    binary_hash = _sha256_bytes(binary)
    if extras.get("orison_bin_sha256") != binary_hash:
        raise ProductionExportError(f"cell {cell_id} embedded BIN hash differs")
    extras["orison_floor01_owner_first"] = {
        "schema": "orison.floor01.production-cell.v1",
        "cell_id": cell_id,
        "production_asset": True,
        "owner_before_material": True,
        "spatial_inference_used": False,
        "collision_name_contract": ["-col", "-colonly"],
        "rollback_monolith_loaded_simultaneously": False,
    }
    asset["extras"] = extras

    buffers = document.get("buffers")
    if (not isinstance(buffers, list) or len(buffers) != 1
            or buffers[0].get("uri") != f"{slug}.bin"
            or int(buffers[0].get("byteLength", -1)) != len(binary)):
        raise ProductionExportError(f"cell {cell_id} external BIN contract drifted")

    bindings: list[dict[str, Any]] = []
    seen_resources: set[str] = set()
    for index, image in enumerate(document.get("images", [])):
        if not isinstance(image, dict) or "uri" not in image:
            continue
        old_uri = str(image["uri"])
        if old_uri.startswith("data:"):
            continue
        if not old_uri.startswith(_REHEARSAL_TEXTURE_PREFIX):
            raise ProductionExportError(
                f"cell {cell_id} image {index} has an unruled URI: {old_uri}")
        suffix = PurePosixPath(old_uri[len(_REHEARSAL_TEXTURE_PREFIX):])
        if (not suffix.parts or suffix.is_absolute()
                or any(part in {"", ".", ".."} for part in suffix.parts)):
            raise ProductionExportError(f"cell {cell_id} image URI is unsafe: {old_uri}")
        source_texture = export_root / "shared_textures" / "textures"
        production_texture = repo_root / "game" / "assets" / "building" / "textures"
        for part in suffix.parts:
            source_texture /= part
            production_texture /= part
        if not source_texture.is_file() or not production_texture.is_file():
            raise ProductionExportError(
                f"cell {cell_id} production texture binding is absent: {suffix}")
        source_hash = _sha256_file(source_texture)
        if source_hash != _sha256_file(production_texture):
            raise ProductionExportError(
                f"cell {cell_id} production texture differs: {suffix}")
        new_uri = (_PRODUCTION_TEXTURE_PREFIX + suffix.as_posix())
        image["uri"] = new_uri
        resource_path = "res://assets/building/textures/" + suffix.as_posix()
        if resource_path not in seen_resources:
            seen_resources.add(resource_path)
            bindings.append({
                "resource_path": resource_path,
                "sha256": source_hash,
                "bytes": production_texture.stat().st_size,
            })
    bindings.sort(key=lambda value: str(value["resource_path"]))
    rendered = _json_bytes(document)
    if b"orison_m11c1" in rendered or b"production_asset\": false" in rendered:
        raise ProductionExportError(f"cell {cell_id} retained rehearsal metadata")
    return rendered, binary, bindings


def _stable_lineage(
        *, rehearsal: Mapping[str, Any], input_hashes: Mapping[str, str],
        cell_resources: Mapping[str, str], protected_hashes: Mapping[str, str],
) -> dict[str, Any]:
    if (rehearsal.get("lineage_complete") is not True
            or rehearsal.get("legacy_aliases_complete") is not True
            or rehearsal.get("semantic_owners_unique") is not True
            or rehearsal.get("owner_before_material") is not True
            or rehearsal.get("spatial_inference_used") is not False
            or rehearsal.get("unresolved_lineage_records") != []):
        raise ProductionExportError("reviewed lineage invariants are not all proven")
    value = {
        key: copy.deepcopy(rehearsal[key])
        for key in (
            "authority", "source_records", "generated_sources", "contributions",
            "legacy_aliases", "semantic_owners", "semantic_owner_count", "counts",
            "unresolved_lineage_records",
        )
    }
    value.update({
        "schema": SCHEMA_LINEAGE,
        "status": STATUS_PASS,
        "floor_id": "F01",
        "production_asset": True,
        "lineage_complete": True,
        "legacy_aliases_complete": True,
        "semantic_owners_unique": True,
        "owner_before_material": True,
        "spatial_inference_used": False,
        "authoritative_inputs": dict(sorted(input_hashes.items())),
        "rollback_monolith": {
            "gltf_path": "game/assets/building/floor_01.gltf",
            "gltf_sha256": protected_hashes[
                "game/assets/building/floor_01.gltf"],
            "bin_path": "game/assets/building/floor_01.bin",
            "bin_sha256": protected_hashes[
                "game/assets/building/floor_01.bin"],
            "production_geometry_provider": False,
            "retained_for_rollback": True,
        },
        "cell_resources": dict(sorted(cell_resources.items())),
    })
    _assert_no_host_paths(value, "production lineage")
    return value


def _alias_manifest(
        lineage: Mapping[str, Any], cell_resources: Mapping[str, str],
) -> dict[str, Any]:
    raw = lineage.get("legacy_aliases")
    if not isinstance(raw, dict) or not raw:
        raise ProductionExportError("production lineage has no compatibility aliases")
    aliases: dict[str, list[dict[str, Any]]] = {}
    for alias in sorted(raw):
        rows = raw[alias]
        if not isinstance(rows, list) or not rows:
            raise ProductionExportError(f"compatibility alias has no targets: {alias}")
        targets: list[dict[str, Any]] = []
        seen: set[tuple[str, int, int]] = set()
        for row in rows:
            if not isinstance(row, dict):
                raise ProductionExportError(f"compatibility alias row is malformed: {alias}")
            cell_id = str(row.get("cell_id", ""))
            key = (cell_id, int(row.get("node_index", -1)),
                   int(row.get("mesh_index", -1)))
            if cell_id not in cell_resources or min(key[1:]) < 0 or key in seen:
                raise ProductionExportError(f"compatibility alias target is invalid: {alias}")
            seen.add(key)
            targets.append({
                "cell_id": cell_id,
                "resource_path": cell_resources[cell_id],
                "node_index": key[1],
                "mesh_index": key[2],
            })
        targets.sort(key=lambda row: (
            CELL_IDS.index(str(row["cell_id"])), int(row["node_index"]),
            int(row["mesh_index"])))
        aliases[str(alias)] = targets
    split_aliases = [alias for alias, targets in aliases.items() if len(targets) > 1]
    value = {
        "schema": SCHEMA_ALIASES,
        "status": STATUS_PASS,
        "floor_id": "F01",
        "production_asset": True,
        "identity_count": len(aliases),
        "split_identity_count": len(split_aliases),
        "split_identities": split_aliases,
        "aliases": aliases,
        "incompatible_aliases": [],
    }
    _assert_no_host_paths(value, "compatibility aliases")
    return value


def _residency_sets() -> list[dict[str, Any]]:
    values: list[dict[str, Any]] = [
        {"id": "FULL_RECOMPOSITION", "cell_ids": list(CELL_IDS)},
        {"id": "ORISON_INTERIOR_PLUS_FACADE",
         "cell_ids": [INTERIOR, FACADE]},
        {"id": "STREET_PLUS_FACADE", "cell_ids": [STREET, FACADE]},
        {"id": "PASSAGE_ONLY", "cell_ids": [PASSAGE]},
    ]
    for cell_id in CELL_IDS:
        if cell_id in {INTERIOR, FACADE, STREET, PASSAGE}:
            continue
        values.append({
            "id": cell_id.removeprefix("CELL_") + "_ONLY",
            "cell_ids": [cell_id],
        })
    return values


def _detect_dependency_cycle(cells: Mapping[str, Mapping[str, Any]]) -> None:
    visiting: set[str] = set()
    visited: set[str] = set()

    def visit(cell_id: str) -> None:
        if cell_id in visiting:
            raise ProductionExportError(f"cell dependency cycle reaches {cell_id}")
        if cell_id in visited:
            return
        visiting.add(cell_id)
        for dependency in cells[cell_id].get("dependencies", []):
            visit(str(dependency))
        visiting.remove(cell_id)
        visited.add(cell_id)

    for identity in cells:
        visit(identity)


def validate_registry(value: Mapping[str, Any]) -> None:
    """Validate the source/runtime registry contract without loading Godot."""

    if (value.get("schema") != SCHEMA_REGISTRY
            or value.get("status") != STATUS_PASS
            or value.get("floor_id") != "F01"
            or value.get("default_mode") != DEFAULT_MODE
            or value.get("legacy_monolith_path") != LEGACY_MONOLITH
            or value.get("supported_session_modes")
            != [DEFAULT_MODE, LEGACY_MODE]
            or value.get("session_mode_is_save_authority") is not False
            or value.get("simultaneous_monolith_and_cells_allowed") is not False):
        raise ProductionExportError("registry header or mode contract is invalid")
    host = value.get("persistent_host")
    if (not isinstance(host, dict) or host.get("id") != "F01"
            or host.get("geometry_free") is not True
            or host.get("gameplay_authority_survives_cell_unload") is not True):
        raise ProductionExportError("registry persistent-host contract is invalid")
    expected_manifest_paths = {
        "asset_manifest_path": (
            "res://assets/building/floor_01_cells/" + ASSET_MANIFEST_NAME),
        "lineage_manifest_path": (
            "res://assets/building/floor_01_cells/" + LINEAGE_NAME),
        "compatibility_alias_manifest_path": (
            "res://assets/building/floor_01_cells/" + ALIASES_NAME),
    }
    for key, expected in expected_manifest_paths.items():
        if value.get(key) != expected:
            raise ProductionExportError(f"registry manifest binding differs: {key}")
    if not _HASH_RE.fullmatch(str(value.get("asset_manifest_sha256", ""))):
        raise ProductionExportError("registry asset-manifest hash is malformed")
    rows = value.get("cells")
    if not isinstance(rows, list) or len(rows) != len(CELL_IDS):
        raise ProductionExportError("registry does not contain exactly 17 cells")
    cells: dict[str, Mapping[str, Any]] = {}
    resources: set[str] = set()
    for row in rows:
        if not isinstance(row, dict):
            raise ProductionExportError("registry cell row is malformed")
        cell_id = str(row.get("id", ""))
        resource = str(row.get("resource_path", ""))
        if cell_id in cells or cell_id not in CELL_IDS or resource in resources:
            raise ProductionExportError(f"registry cell is duplicate/unknown: {cell_id}")
        expected_resource = _production_resource(CELL_SLUGS[cell_id])
        if (resource != expected_resource
                or row.get("bin_resource_path")
                != _production_bin_resource(CELL_SLUGS[cell_id])):
            raise ProductionExportError(f"registry resource differs for {cell_id}")
        if (not _HASH_RE.fullmatch(str(row.get("gltf_sha256", "")))
                or not _HASH_RE.fullmatch(str(row.get("bin_sha256", "")))):
            raise ProductionExportError(f"registry asset hash malformed for {cell_id}")
        dependencies = row.get("dependencies")
        if not isinstance(dependencies, list) or len(dependencies) != len(set(dependencies)):
            raise ProductionExportError(f"registry dependencies malformed for {cell_id}")
        if any(str(dep) not in CELL_IDS or str(dep) == cell_id for dep in dependencies):
            raise ProductionExportError(f"registry dependency invalid for {cell_id}")
        if not isinstance(row.get("semantic_owners"), list) \
                or not isinstance(row.get("compatibility_aliases"), list):
            raise ProductionExportError(f"registry owner indexes malformed for {cell_id}")
        if row.get("independently_addressable") is not True:
            raise ProductionExportError(f"registry addressability differs for {cell_id}")
        lifecycle = row.get("lifecycle")
        if (not isinstance(lifecycle, dict)
                or lifecycle.get("initial_state") != "UNLOADED"
                or lifecycle.get("allowed_transitions") != [
                    "UNLOADED_TO_LOADING", "LOADING_TO_RESIDENT",
                    "RESIDENT_TO_UNLOADING", "UNLOADING_TO_UNLOADED"]
                or lifecycle.get("persistent_gameplay_authority") is not False
                or lifecycle.get("unload_destroys_durable_authority") is not False
                or lifecycle.get("teardown_api_required") is not True):
            raise ProductionExportError(f"registry lifecycle differs for {cell_id}")
        cells[cell_id] = row
        resources.add(resource)
    if set(cells) != set(CELL_IDS):
        raise ProductionExportError("registry cell identity set differs")
    _detect_dependency_cycle(cells)

    semantic_index = value.get("semantic_owner_index")
    if not isinstance(semantic_index, dict) or not semantic_index:
        raise ProductionExportError("registry semantic owner index is absent")
    seen_semantics: set[str] = set()
    for cell_id, row in cells.items():
        for identity in row["semantic_owners"]:
            identity = str(identity)
            if identity in seen_semantics or semantic_index.get(identity) != cell_id:
                raise ProductionExportError(f"semantic owner is duplicate/incompatible: {identity}")
            seen_semantics.add(identity)
    if seen_semantics != set(semantic_index):
        raise ProductionExportError("semantic owner cell/index coverage differs")

    alias_index = value.get("compatibility_alias_index")
    if not isinstance(alias_index, dict) or not alias_index:
        raise ProductionExportError("registry compatibility alias index is absent")
    aliases_by_cell: dict[str, set[str]] = {cell_id: set() for cell_id in CELL_IDS}
    for alias, targets in alias_index.items():
        if not isinstance(targets, list) or not targets:
            raise ProductionExportError(f"compatibility alias has no target: {alias}")
        seen_targets: set[tuple[str, int, int]] = set()
        for target in targets:
            if not isinstance(target, dict):
                raise ProductionExportError(f"compatibility alias target malformed: {alias}")
            key = (str(target.get("cell_id", "")),
                   int(target.get("node_index", -1)),
                   int(target.get("mesh_index", -1)))
            if key[0] not in cells or min(key[1:]) < 0 or key in seen_targets:
                raise ProductionExportError(f"compatibility alias is incompatible: {alias}")
            seen_targets.add(key)
            aliases_by_cell[key[0]].add(str(alias))
    for cell_id, row in cells.items():
        if set(str(value) for value in row["compatibility_aliases"]) \
                != aliases_by_cell[cell_id]:
            raise ProductionExportError(f"cell alias projection differs for {cell_id}")

    residency = value.get("residency_sets")
    if not isinstance(residency, list) or not residency:
        raise ProductionExportError("registry residency sets are absent")
    by_set: dict[str, list[str]] = {}
    for row in residency:
        if not isinstance(row, dict):
            raise ProductionExportError("registry residency row is malformed")
        identity = str(row.get("id", ""))
        members = [str(member) for member in row.get("cell_ids", [])]
        if (not identity or identity in by_set or len(members) != len(set(members))
                or any(member not in cells for member in members)):
            raise ProductionExportError(f"registry residency set is invalid: {identity}")
        by_set[identity] = members
    if by_set.get("FULL_RECOMPOSITION") != list(CELL_IDS):
        raise ProductionExportError(
            "FULL_RECOMPOSITION residency differs from canonical order")

    facade = value.get("facade_sharing")
    if not isinstance(facade, list) or len(facade) != len(FACADE_SHARING):
        raise ProductionExportError("registry facade-sharing rules differ")
    expected_facade = {str(row["id"]): row for row in FACADE_SHARING}
    seen_facade: set[str] = set()
    for rule in facade:
        identity = str(rule.get("id", "")) if isinstance(rule, dict) else ""
        expected = expected_facade.get(identity)
        if (expected is None or identity in seen_facade
                or rule.get("cell_ids") != expected["cell_ids"]
                or rule.get("rule") != expected["rule"]
                or len(rule.get("cell_ids", [])) != 2
                or FACADE not in rule.get("cell_ids", [])):
            raise ProductionExportError("registry facade-sharing rule is invalid")
        seen_facade.add(identity)
    if seen_facade != set(expected_facade):
        raise ProductionExportError("registry facade-sharing IDs are incomplete")
    refusals = value.get("refusals")
    expected_refusals = {
        "unknown_cell", "duplicate_semantic_owner", "dependency_cycle",
        "incompatible_alias", "simultaneous_monolith_and_cells",
    }
    if (not isinstance(refusals, dict) or set(refusals) != expected_refusals
            or any(refusals[key] is not True for key in expected_refusals)):
        raise ProductionExportError("registry refusal contract is incomplete")
    _assert_no_host_paths(value, "runtime registry")


def _build_registry(
        *, cells: list[dict[str, Any]], semantic_owners: Iterable[Mapping[str, Any]],
        alias_manifest: Mapping[str, Any], asset_manifest_sha256: str,
) -> dict[str, Any]:
    semantic_index: dict[str, str] = {}
    semantics_by_cell: dict[str, list[str]] = {cell_id: [] for cell_id in CELL_IDS}
    for row in semantic_owners:
        identity = str(row.get("identity", ""))
        owner = str(row.get("owner_cell", ""))
        if not identity or identity in semantic_index or owner not in semantics_by_cell:
            raise ProductionExportError(f"semantic owner is empty/duplicate: {identity}")
        semantic_index[identity] = owner
        semantics_by_cell[owner].append(identity)
    for values in semantics_by_cell.values():
        values.sort()

    raw_aliases = alias_manifest["aliases"]
    aliases_by_cell: dict[str, set[str]] = {cell_id: set() for cell_id in CELL_IDS}
    alias_index: dict[str, list[dict[str, Any]]] = {}
    for alias in sorted(raw_aliases):
        targets = []
        for source in raw_aliases[alias]:
            cell_id = str(source["cell_id"])
            aliases_by_cell[cell_id].add(alias)
            targets.append({
                "cell_id": cell_id,
                "node_index": int(source["node_index"]),
                "mesh_index": int(source["mesh_index"]),
            })
        alias_index[alias] = targets

    cell_rows = []
    by_id = {str(row["id"]): row for row in cells}
    for cell_id in CELL_IDS:
        source = by_id[cell_id]
        cell_rows.append({
            "id": cell_id,
            "resource_path": str(source["resource_path"]),
            "bin_resource_path": str(source["bin_resource_path"]),
            "gltf_sha256": str(source["gltf_sha256"]),
            "bin_sha256": str(source["bin_sha256"]),
            "dependencies": [],
            "independently_addressable": True,
            "semantic_owners": semantics_by_cell[cell_id],
            "compatibility_aliases": sorted(aliases_by_cell[cell_id]),
            "lifecycle": {
                "initial_state": "UNLOADED",
                "allowed_transitions": [
                    "UNLOADED_TO_LOADING", "LOADING_TO_RESIDENT",
                    "RESIDENT_TO_UNLOADING", "UNLOADING_TO_UNLOADED",
                ],
                "persistent_gameplay_authority": False,
                "unload_destroys_durable_authority": False,
                "teardown_api_required": True,
            },
        })
    value = {
        "schema": SCHEMA_REGISTRY,
        "status": STATUS_PASS,
        "floor_id": "F01",
        "default_mode": DEFAULT_MODE,
        "supported_session_modes": [DEFAULT_MODE, LEGACY_MODE],
        "legacy_monolith_path": LEGACY_MONOLITH,
        "simultaneous_monolith_and_cells_allowed": False,
        "session_mode_is_save_authority": False,
        "persistent_host": {
            "id": "F01",
            "geometry_free": True,
            "gameplay_authority_survives_cell_unload": True,
        },
        "asset_manifest_path": (
            "res://assets/building/floor_01_cells/" + ASSET_MANIFEST_NAME),
        "asset_manifest_sha256": asset_manifest_sha256,
        "lineage_manifest_path": (
            "res://assets/building/floor_01_cells/" + LINEAGE_NAME),
        "compatibility_alias_manifest_path": (
            "res://assets/building/floor_01_cells/" + ALIASES_NAME),
        "cells": cell_rows,
        "residency_sets": _residency_sets(),
        "facade_sharing": copy.deepcopy(list(FACADE_SHARING)),
        "semantic_owner_index": dict(sorted(semantic_index.items())),
        "compatibility_alias_index": alias_index,
        "refusals": {
            "unknown_cell": True,
            "duplicate_semantic_owner": True,
            "dependency_cycle": True,
            "incompatible_alias": True,
            "simultaneous_monolith_and_cells": True,
        },
    }
    validate_registry(value)
    return value


def build_production_artifacts(
        export_root: Path, repo_root: Path = REPO_ROOT,
) -> dict[PurePosixPath, bytes]:
    """Convert one fully proven disposable export into stable production bytes."""

    export_root = export_root.resolve()
    repo_root = repo_root.resolve()
    partition = _require_rehearsal_receipt(
        export_root, "owner_first_partition_manifest.json",
        "orison.floor01.owner-first-partition.v1")
    lineage = _require_rehearsal_receipt(
        export_root, "receipts/floor01_owner_first_lineage.json",
        "orison.floor01.owner-first-lineage.v1")
    equivalence = _require_rehearsal_receipt(
        export_root, "receipts/floor01_owner_first_equivalence.json",
        "orison.floor01.owner-first-equivalence.v1")
    export_receipt = _require_rehearsal_receipt(
        export_root, "receipts/floor01_owner_first_export.json",
        "orison.floor01.owner-first-export.v1")
    if (partition.get("target_cell_count") != len(CELL_IDS)
            or partition.get("legacy_mixed_cell_present") is not False
            or partition.get("canonical_equivalence_passed") is not True
            or equivalence.get("unexplained_differences") != []
            or export_receipt.get("unresolved_lineage_records") != []):
        raise ProductionExportError("reviewed export proof is incomplete")

    protected = collect_protected_hashes(repo_root)
    artifacts: dict[PurePosixPath, bytes] = {}
    cells: list[dict[str, Any]] = []
    texture_bindings: dict[str, dict[str, Any]] = {}
    raw_cells = partition.get("cells")
    if not isinstance(raw_cells, list) or len(raw_cells) != len(CELL_IDS):
        raise ProductionExportError("partition cell set is not exactly 17")
    rows_by_id = {str(row.get("id", "")): row
                  for row in raw_cells if isinstance(row, dict)}
    if set(rows_by_id) != set(CELL_IDS):
        raise ProductionExportError("partition cell identities differ")
    cell_resources = {
        cell_id: _production_resource(CELL_SLUGS[cell_id]) for cell_id in CELL_IDS
    }
    for cell_id in CELL_IDS:
        row = rows_by_id[cell_id]
        gltf_bytes, bin_bytes, bindings = _canonicalize_cell(
            export_root=export_root, repo_root=repo_root, row=row)
        slug = CELL_SLUGS[cell_id]
        gltf_rel = ASSET_ROOT_REL / f"{slug}.gltf"
        bin_rel = ASSET_ROOT_REL / f"{slug}.bin"
        if gltf_rel in artifacts or bin_rel in artifacts:
            raise ProductionExportError(f"duplicate production cell path for {cell_id}")
        artifacts[gltf_rel] = gltf_bytes
        artifacts[bin_rel] = bin_bytes
        for binding in bindings:
            key = str(binding["resource_path"])
            if key in texture_bindings and texture_bindings[key] != binding:
                raise ProductionExportError(f"texture binding is incompatible: {key}")
            texture_bindings[key] = binding
        cells.append({
            "id": cell_id,
            "slug": slug,
            "resource_path": _production_resource(slug),
            "bin_resource_path": _production_bin_resource(slug),
            "gltf_path": gltf_rel.as_posix(),
            "bin_path": bin_rel.as_posix(),
            "gltf_sha256": _sha256_bytes(gltf_bytes),
            "bin_sha256": _sha256_bytes(bin_bytes),
            "gltf_bytes": len(gltf_bytes),
            "bin_bytes": len(bin_bytes),
            "node_count": int(row["node_count"]),
            "mesh_count": int(row["mesh_count"]),
            "primitive_count": int(row["primitive_count"]),
            "triangle_count": int(row["triangle_count"]),
            "vertex_count": int(row["vertex_count"]),
            "collision_object_count": int(row["collision_object_count"]),
            "bounds_union": copy.deepcopy(row["bounds_union"]),
        })

    input_hashes = {
        "layout": protected[LAYOUT_REL.as_posix()],
        "runtime_layout_mirror": protected[LAYOUT_MIRROR_REL.as_posix()],
        "ownership": _sha256_file(_repo_path(repo_root, OWNERSHIP_REL)),
        "generator": _sha256_file(_repo_path(repo_root, GENERATOR_REL)),
        "generator_adapter": _sha256_file(_repo_path(repo_root, ADAPTER_REL)),
        "production_exporter": _sha256_file(
            _repo_path(repo_root, PRODUCTION_EXPORTER_REL)),
        "exterior_regions": _sha256_file(_repo_path(repo_root, EXTERIOR_REGIONS_REL)),
    }
    stable_lineage = _stable_lineage(
        rehearsal=lineage, input_hashes=input_hashes,
        cell_resources=cell_resources, protected_hashes=protected)
    stable_aliases = _alias_manifest(stable_lineage, cell_resources)
    lineage_bytes = _json_bytes(stable_lineage)
    aliases_bytes = _json_bytes(stable_aliases)
    lineage_rel = ASSET_ROOT_REL / LINEAGE_NAME
    aliases_rel = ASSET_ROOT_REL / ALIASES_NAME
    artifacts[lineage_rel] = lineage_bytes
    artifacts[aliases_rel] = aliases_bytes

    texture_rows = [texture_bindings[key] for key in sorted(texture_bindings)]
    if len(texture_rows) != 304:
        raise ProductionExportError(
            f"production texture binding count is {len(texture_rows)}, expected 304")
    asset_manifest = {
        "schema": SCHEMA_ASSETS,
        "status": STATUS_PASS,
        "floor_id": "F01",
        "production_asset": True,
        "owner_before_material": True,
        "spatial_inference_used": False,
        "cell_count": len(cells),
        "cells": cells,
        "texture_bindings": texture_rows,
        "texture_binding_count": len(texture_rows),
        "generated_manifests": {
            "lineage": {
                "path": lineage_rel.as_posix(),
                "sha256": _sha256_bytes(lineage_bytes),
            },
            "compatibility_aliases": {
                "path": aliases_rel.as_posix(),
                "sha256": _sha256_bytes(aliases_bytes),
            },
        },
        "authoritative_inputs": dict(sorted(input_hashes.items())),
        "protected_hashes": dict(sorted(protected.items())),
        "rollback_monolith_retained": True,
        "rollback_monolith_loaded_simultaneously": False,
        "canonical_equivalence": {
            "status": STATUS_PASS,
            "unexplained_differences": [],
            "source_records": int(stable_lineage["counts"]["source_records"]),
            "generated_sources": int(stable_lineage["counts"]["generated_sources"]),
            "generated_contributions": int(
                stable_lineage["counts"]["generated_contributions"]),
            "output_primitives": int(stable_lineage["counts"]["output_primitives"]),
            "output_triangles": int(stable_lineage["counts"]["output_triangles"]),
        },
        "legacy_mixed_cell_present": False,
        "unresolved_lineage_records": [],
    }
    _assert_no_host_paths(asset_manifest, "asset manifest")
    asset_manifest_bytes = _json_bytes(asset_manifest)
    asset_manifest_rel = ASSET_ROOT_REL / ASSET_MANIFEST_NAME
    artifacts[asset_manifest_rel] = asset_manifest_bytes

    registry = _build_registry(
        cells=cells, semantic_owners=stable_lineage["semantic_owners"],
        alias_manifest=stable_aliases,
        asset_manifest_sha256=_sha256_bytes(asset_manifest_bytes))
    artifacts[REGISTRY_REL] = _json_bytes(registry)
    expected_count = len(CELL_IDS) * 2 + 4
    if len(artifacts) != expected_count:
        raise ProductionExportError(
            f"production artifact allowlist has {len(artifacts)}, expected {expected_count}")
    return artifacts


def _allowed_asset_names() -> set[str]:
    names = {
        LINEAGE_NAME, ALIASES_NAME, ASSET_MANIFEST_NAME,
    }
    for cell_id in CELL_IDS:
        slug = CELL_SLUGS[cell_id]
        names.update({f"{slug}.gltf", f"{slug}.bin"})
    return names


def _assert_exact_destinations(
        artifacts: Mapping[PurePosixPath, bytes], repo_root: Path) -> None:
    expected = {
        *(ASSET_ROOT_REL / name for name in _allowed_asset_names()),
        REGISTRY_REL,
    }
    if set(artifacts) != expected:
        missing = sorted(path.as_posix() for path in expected - set(artifacts))
        extra = sorted(path.as_posix() for path in set(artifacts) - expected)
        raise ProductionExportError(
            f"production destination allowlist differs: missing={missing} extra={extra}")
    asset_root = _repo_path(repo_root, ASSET_ROOT_REL)
    if asset_root.exists():
        unknown = sorted(
            path.relative_to(asset_root).as_posix()
            for path in asset_root.rglob("*")
            if path.is_file() and path.suffix != ".import"
            and path.name not in _allowed_asset_names()
        )
        if unknown:
            raise ProductionExportError(
                f"production asset root contains unowned files: {unknown}")


def install_artifacts(
        artifacts: Mapping[PurePosixPath, bytes], repo_root: Path = REPO_ROOT,
) -> dict[str, Any]:
    """Write only the exact production allowlist using sibling atomic replaces."""

    repo_root = repo_root.resolve()
    _assert_exact_destinations(artifacts, repo_root)
    changed: list[str] = []
    for relative in sorted(artifacts, key=lambda value: value.as_posix()):
        destination = _repo_path(repo_root, relative)
        data = artifacts[relative]
        if destination.is_file() and destination.read_bytes() == data:
            continue
        destination.parent.mkdir(parents=True, exist_ok=True)
        temporary = destination.with_name(destination.name + ".m11c2-new")
        if temporary.exists():
            raise ProductionExportError(f"staging path already exists: {temporary}")
        temporary.write_bytes(data)
        if _sha256_file(temporary) != _sha256_bytes(data):
            raise ProductionExportError(f"staged artifact hash differs: {relative}")
        os.replace(temporary, destination)
        changed.append(relative.as_posix())
    return {"changed": changed, "changed_count": len(changed)}


def check_artifacts(
        artifacts: Mapping[PurePosixPath, bytes], repo_root: Path = REPO_ROOT,
) -> dict[str, Any]:
    """Byte-check a generated allowlist against the committed production tree."""

    repo_root = repo_root.resolve()
    _assert_exact_destinations(artifacts, repo_root)
    missing: list[str] = []
    different: list[str] = []
    hashes: dict[str, str] = {}
    for relative in sorted(artifacts, key=lambda value: value.as_posix()):
        destination = _repo_path(repo_root, relative)
        if not destination.is_file():
            missing.append(relative.as_posix())
            continue
        actual = destination.read_bytes()
        hashes[relative.as_posix()] = _sha256_bytes(actual)
        if actual != artifacts[relative]:
            different.append(relative.as_posix())
    if missing or different:
        raise ProductionExportError(
            f"committed production artifacts differ: missing={missing} different={different}")
    registry = _load_json(_repo_path(repo_root, REGISTRY_REL), "production registry")
    validate_registry(registry)
    return {
        "matched": len(artifacts),
        "missing": [],
        "different": [],
        "hashes": hashes,
    }


def run_production_export(
        *, mode: str, repo_root: Path = REPO_ROOT,
        blender: Path = Path(
            r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"),
) -> dict[str, Any]:
    if mode not in {"write", "check"}:
        raise ProductionExportError(f"unsupported production export mode: {mode}")
    repo_root = repo_root.resolve()
    if not (repo_root / ".git").exists():
        # Worktrees use a .git file; ordinary clones use a directory.
        if not (repo_root / ".git").is_file():
            raise ProductionExportError(f"repository root has no .git binding: {repo_root}")
    protected_before = collect_protected_hashes(repo_root)
    with tempfile.TemporaryDirectory(prefix="orison_m11c2_owner_first_") as raw:
        export_root = Path(raw) / "reviewed_export"
        generation = run_disposable_export(
            output_root=export_root,
            blender=blender,
            protected_gltf=_repo_path(
                repo_root, PurePosixPath("game/assets/building/floor_01.gltf")),
            layout=_repo_path(repo_root, LAYOUT_REL),
            ownership=_repo_path(repo_root, OWNERSHIP_REL),
            generator=_repo_path(repo_root, GENERATOR_REL),
            adapter=_repo_path(repo_root, ADAPTER_REL),
            exterior_regions=_repo_path(repo_root, EXTERIOR_REGIONS_REL),
        )
        artifacts = build_production_artifacts(export_root, repo_root)
        artifact_hashes = {
            path.as_posix(): _sha256_bytes(data)
            for path, data in sorted(
                artifacts.items(), key=lambda item: item[0].as_posix())
        }
        operation = (install_artifacts(artifacts, repo_root)
                     if mode == "write" else check_artifacts(artifacts, repo_root))
    protected_after = collect_protected_hashes(repo_root)
    if protected_after != protected_before:
        raise ProductionExportError("protected production inputs changed during export")
    return {
        "schema": "orison.floor01.production-export-operation.v1",
        "status": STATUS_PASS,
        "mode": mode,
        "cell_count": len(CELL_IDS),
        "artifact_count": len(artifact_hashes),
        "artifact_hashes": artifact_hashes,
        "protected_hashes_before": protected_before,
        "protected_hashes_after": protected_after,
        "protected_unchanged": True,
        "reviewed_generation": generation,
        "operation": operation,
    }


def _parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--write", action="store_true")
    mode.add_argument("--check", action="store_true")
    parser.add_argument("--repo-root", type=Path, default=REPO_ROOT)
    parser.add_argument(
        "--blender", type=Path,
        default=Path(
            r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"))
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv)
    try:
        result = run_production_export(
            mode="write" if args.write else "check",
            repo_root=args.repo_root,
            blender=args.blender,
        )
    except (OSError, ValueError, OwnerFirstError, ProductionExportError) as error:
        print(f"M11C2 PRODUCTION FLOOR01 EXPORT FAIL: {error}", file=sys.stderr)
        return 2
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
