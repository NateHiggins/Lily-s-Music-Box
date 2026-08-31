#!/usr/bin/env python3
"""Strict reader for the inert M11C1 F01 source-ownership catalog.

The catalog is authored separately from ``building_layout.json`` so the
protected layout remains byte-identical.  It materializes a durable
``source_id`` and explicit ``owner_cell`` for every F01 source record before
any geometry is emitted.  This module never invents an owner: it only binds
catalog rows to exact canonical source records and refuses drift.

No position, extent, centroid, connected component, or exported primitive is
examined.  ``source_locator`` is the authored collection/index lineage; the
record SHA-256 makes a stale or reordered locator fail closed.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from collections import Counter
from collections.abc import Mapping
from pathlib import Path
from typing import Any


SCHEMA = "orison.floor01.source-ownership"
SCHEMA_VERSION = 1
FLOOR_ID = "F01"

DEFAULT_LAYOUT = Path("art/data/building_layout.json")
DEFAULT_SIDECAR = Path("art/data/m11c1/floor01_source_ownership.json")

SOURCE_COLLECTIONS = (
    "furniture",
    "markers",
    "walls",
    "rooms",
    "ceilings",
    "vent_registers",
    "sockets",
    "site_lights",
    "slabs",
)

EXPECTED_SOURCE_COUNTS = {
    "furniture": 4415,
    "markers": 188,
    "walls": 42,
    "rooms": 16,
    "ceilings": 26,
    "vent_registers": 3,
    "sockets": 30,
    "site_lights": 565,
    "slabs": 1,
}
EXPECTED_RECORD_COUNT = sum(EXPECTED_SOURCE_COUNTS.values())

OWNER_CELLS = (
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

PASSAGE_OVERLAP_LOCATORS = (
    "floors[F01].site_lights[89]",
    "floors[F01].site_lights[90]",
    "floors[F01].site_lights[91]",
)

_SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
_SOURCE_ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.:-]*$")
_REQUIRED_ROW_KEYS = {
    "source_id",
    "source_locator",
    "collection",
    "source_record_sha256",
    "owner_cell",
    "identity_origin",
    "authoring_context",
}


class SourceOwnershipError(ValueError):
    """The source catalog is malformed, incomplete, duplicate, or stale."""


def canonical_json(value: Any) -> str:
    """Return the deterministic JSON representation used by all receipts."""

    try:
        return json.dumps(
            value,
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
            allow_nan=False,
        )
    except (TypeError, ValueError) as exc:
        raise SourceOwnershipError(f"value is not canonical JSON: {exc}") from exc


def sha256_value(value: Any) -> str:
    return hashlib.sha256(canonical_json(value).encode("utf-8")).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    try:
        with path.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                digest.update(chunk)
    except OSError as exc:
        raise SourceOwnershipError(f"cannot read {path}: {exc}") from exc
    return digest.hexdigest()


def source_record_sha256(collection: str, record: Mapping[str, Any]) -> str:
    """Hash one record with its authored floor and collection namespace."""

    return sha256_value(
        {
            "schema": "orison.floor01.source-record",
            "schema_version": 1,
            "floor_id": FLOOR_ID,
            "collection": collection,
            "record": record,
        }
    )


def source_locator(collection: str, index: int) -> str:
    return f"floors[{FLOOR_ID}].{collection}[{index}]"


def _load_json(path: Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise SourceOwnershipError(f"cannot read {label} {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise SourceOwnershipError(f"{label} root must be an object")
    return value


def _floor(layout: Mapping[str, Any]) -> Mapping[str, Any]:
    floors = layout.get("floors")
    if not isinstance(floors, list):
        raise SourceOwnershipError("layout floors must be an array")
    matches = [row for row in floors if isinstance(row, Mapping)
               and row.get("id") == FLOOR_ID]
    if len(matches) != 1:
        raise SourceOwnershipError(
            f"expected exactly one {FLOOR_ID} floor, found {len(matches)}")
    return matches[0]


def enumerate_floor_records(
    layout: Mapping[str, Any],
) -> list[dict[str, Any]]:
    """Enumerate authored F01 records without assigning any ownership."""

    floor = _floor(layout)
    rows: list[dict[str, Any]] = []
    actual_counts: dict[str, int] = {}
    for collection in SOURCE_COLLECTIONS:
        records = floor.get(collection)
        if not isinstance(records, list):
            raise SourceOwnershipError(
                f"{FLOOR_ID} {collection} must be an array")
        actual_counts[collection] = len(records)
        for index, record in enumerate(records):
            if not isinstance(record, Mapping):
                raise SourceOwnershipError(
                    f"{source_locator(collection, index)} must be an object")
            rows.append(
                {
                    "source_locator": source_locator(collection, index),
                    "collection": collection,
                    "source_record_sha256": source_record_sha256(
                        collection, record),
                    "record": record,
                }
            )
    if actual_counts != EXPECTED_SOURCE_COUNTS:
        raise SourceOwnershipError(
            "F01 source count drift: "
            f"expected={EXPECTED_SOURCE_COUNTS} actual={actual_counts}")
    return rows


def floor_recordset_sha256(layout: Mapping[str, Any]) -> str:
    """Canonical receipt for the exact ordered source record set."""

    return sha256_value(
        [
            {
                "source_locator": row["source_locator"],
                "collection": row["collection"],
                "source_record_sha256": row["source_record_sha256"],
            }
            for row in enumerate_floor_records(layout)
        ]
    )


def _required_string(row: Mapping[str, Any], key: str, where: str) -> str:
    value = row.get(key)
    if not isinstance(value, str) or not value:
        raise SourceOwnershipError(f"{where} has missing/malformed {key}")
    return value


def _validate_header(sidecar: Mapping[str, Any], layout: Mapping[str, Any]) -> None:
    if sidecar.get("schema") != SCHEMA:
        raise SourceOwnershipError(
            f"unknown source ownership schema {sidecar.get('schema')!r}")
    if sidecar.get("schema_version") != SCHEMA_VERSION:
        raise SourceOwnershipError(
            f"unsupported source ownership schema version "
            f"{sidecar.get('schema_version')!r}")
    if sidecar.get("milestone") != "ORISON-V2-M11C1":
        raise SourceOwnershipError("source ownership milestone must be ORISON-V2-M11C1")
    if sidecar.get("floor_id") != FLOOR_ID:
        raise SourceOwnershipError(f"source ownership floor must be {FLOOR_ID}")
    if sidecar.get("authority") != "AUTHORING_CONTEXT_EXPLICIT":
        raise SourceOwnershipError(
            "source ownership authority must be AUTHORING_CONTEXT_EXPLICIT")
    if sidecar.get("spatial_inference_used") is not False:
        raise SourceOwnershipError("source ownership must explicitly forbid spatial inference")
    if sidecar.get("record_count") != EXPECTED_RECORD_COUNT:
        raise SourceOwnershipError(
            f"source ownership record_count must be {EXPECTED_RECORD_COUNT}")
    if sidecar.get("expected_counts") != EXPECTED_SOURCE_COUNTS:
        raise SourceOwnershipError("source ownership expected_counts are malformed")
    if sidecar.get("owner_cells") != list(OWNER_CELLS):
        raise SourceOwnershipError("source ownership owner_cells vocabulary drift")
    if sidecar.get("source_collections") != list(SOURCE_COLLECTIONS):
        raise SourceOwnershipError("source ownership collection order drift")

    binding = sidecar.get("source_layout")
    if not isinstance(binding, Mapping):
        raise SourceOwnershipError("source_layout binding must be an object")
    if binding.get("path") != DEFAULT_LAYOUT.as_posix():
        raise SourceOwnershipError("source_layout path is not the protected layout")
    floor_digest = binding.get("floor_recordset_sha256")
    if not isinstance(floor_digest, str) or not _SHA256_RE.fullmatch(floor_digest):
        raise SourceOwnershipError("source_layout floor_recordset_sha256 is malformed")
    actual_floor_digest = floor_recordset_sha256(layout)
    if floor_digest != actual_floor_digest:
        raise SourceOwnershipError(
            "protected F01 record set does not match source ownership sidecar: "
            f"expected={floor_digest} actual={actual_floor_digest}")
    layout_digest = binding.get("sha256")
    if not isinstance(layout_digest, str) or not _SHA256_RE.fullmatch(layout_digest):
        raise SourceOwnershipError("source_layout sha256 is malformed")


def _validate_rulings(
    sidecar: Mapping[str, Any], resolved: Mapping[str, Mapping[str, Any]],
) -> None:
    rulings = sidecar.get("explicit_owner_rulings")
    if not isinstance(rulings, list):
        raise SourceOwnershipError("explicit_owner_rulings must be an array")
    if len(rulings) != len(PASSAGE_OVERLAP_LOCATORS):
        raise SourceOwnershipError(
            "the three Passage-overlapping site lights must be explicitly ruled")
    by_locator: dict[str, Mapping[str, Any]] = {}
    ruling_ids: set[str] = set()
    for index, ruling in enumerate(rulings):
        where = f"explicit_owner_rulings[{index}]"
        if not isinstance(ruling, Mapping):
            raise SourceOwnershipError(f"{where} must be an object")
        ruling_id = _required_string(ruling, "ruling_id", where)
        if ruling_id in ruling_ids:
            raise SourceOwnershipError(f"duplicate explicit ruling id {ruling_id!r}")
        ruling_ids.add(ruling_id)
        locator = _required_string(ruling, "source_locator", where)
        if locator in by_locator:
            raise SourceOwnershipError(f"duplicate explicit ruling locator {locator!r}")
        by_locator[locator] = ruling
        if ruling.get("spatial_inference_used") is not False:
            raise SourceOwnershipError(f"{where} must reject spatial inference")
        if ruling.get("owner_cell") != "CELL_SITE_STREET_COMMON":
            raise SourceOwnershipError(f"{where} must explicitly retain street ownership")
        context = _required_string(ruling, "authoring_context", where)
        if not context.startswith("SITE_PASS_"):
            raise SourceOwnershipError(f"{where} lacks site authoring context")
        decision = _required_string(ruling, "decision", where)
        if decision != "SITE_STREET_COMMON_BY_AUTHORING_CONTEXT":
            raise SourceOwnershipError(f"{where} has malformed decision")
        row = resolved.get(locator)
        if row is None:
            raise SourceOwnershipError(f"{where} references unknown source {locator!r}")
        for key in ("source_id", "source_record_sha256", "owner_cell"):
            if ruling.get(key) != row.get(key):
                raise SourceOwnershipError(
                    f"{where} {key} disagrees with source catalog")
    if tuple(sorted(by_locator)) != tuple(sorted(PASSAGE_OVERLAP_LOCATORS)):
        raise SourceOwnershipError(
            "explicit rulings do not name the three reviewed Passage-overlap locators")


def resolve_floor_records(
    layout: Mapping[str, Any], sidecar: Mapping[str, Any],
) -> dict[str, dict[str, Any]]:
    """Bind every F01 source locator to an explicit durable identity/owner.

    The returned dictionary has exactly 5,286 entries.  Ownership never falls
    back to a classifier; any missing, duplicate, malformed, stale, or unknown
    catalog value raises :class:`SourceOwnershipError`.
    """

    if not isinstance(layout, Mapping):
        raise SourceOwnershipError("layout root must be an object")
    if not isinstance(sidecar, Mapping):
        raise SourceOwnershipError("source ownership root must be an object")
    _validate_header(sidecar, layout)

    actual_rows = enumerate_floor_records(layout)
    actual_by_locator = {row["source_locator"]: row for row in actual_rows}
    catalog_rows = sidecar.get("records")
    if not isinstance(catalog_rows, list):
        raise SourceOwnershipError("source ownership records must be an array")
    if len(catalog_rows) != EXPECTED_RECORD_COUNT:
        raise SourceOwnershipError(
            "source ownership records are not exact-once: "
            f"expected={EXPECTED_RECORD_COUNT} actual={len(catalog_rows)}")

    claimed_records_digest = sidecar.get("records_sha256")
    if not isinstance(claimed_records_digest, str) or not _SHA256_RE.fullmatch(
            claimed_records_digest):
        raise SourceOwnershipError("records_sha256 is malformed")
    actual_records_digest = sha256_value(catalog_rows)
    if claimed_records_digest != actual_records_digest:
        raise SourceOwnershipError(
            "source ownership records receipt mismatch: "
            f"expected={claimed_records_digest} actual={actual_records_digest}")

    resolved: dict[str, dict[str, Any]] = {}
    seen_source_ids: dict[str, str] = {}
    seen_record_hashes: dict[str, str] = {}
    counts: Counter[str] = Counter()
    identity_counts: Counter[str] = Counter()

    for index, row in enumerate(catalog_rows):
        where = f"records[{index}]"
        if not isinstance(row, Mapping):
            raise SourceOwnershipError(f"{where} must be an object")
        missing_keys = sorted(_REQUIRED_ROW_KEYS - set(row))
        if missing_keys:
            raise SourceOwnershipError(f"{where} is missing fields {missing_keys}")
        unexpected_keys = sorted(set(row) - _REQUIRED_ROW_KEYS)
        if unexpected_keys:
            raise SourceOwnershipError(
                f"{where} has unexpected fields {unexpected_keys}; source "
                "ownership rows are a closed schema and may not carry "
                "position, bounds, centroid, or inferred geometry")

        source_id = _required_string(row, "source_id", where)
        if not _SOURCE_ID_RE.fullmatch(source_id):
            raise SourceOwnershipError(f"{where} has malformed source_id {source_id!r}")
        locator = _required_string(row, "source_locator", where)
        collection = _required_string(row, "collection", where)
        digest = _required_string(row, "source_record_sha256", where)
        owner = _required_string(row, "owner_cell", where)
        identity_origin = _required_string(row, "identity_origin", where)
        _required_string(row, "authoring_context", where)

        if collection not in SOURCE_COLLECTIONS:
            raise SourceOwnershipError(f"{where} has unknown collection {collection!r}")
        if owner not in OWNER_CELLS:
            raise SourceOwnershipError(f"{where} has unknown owner_cell {owner!r}")
        if identity_origin not in {
                "AUTHORED_RECORD_ID", "M11C1_EXPLICIT_SIDECAR_ID"}:
            raise SourceOwnershipError(
                f"{where} has unknown identity_origin {identity_origin!r}")
        if not _SHA256_RE.fullmatch(digest):
            raise SourceOwnershipError(f"{where} has malformed source_record_sha256")
        if locator in resolved:
            raise SourceOwnershipError(f"duplicate source locator {locator!r}")
        previous = seen_source_ids.get(source_id)
        if previous is not None:
            raise SourceOwnershipError(
                f"duplicate source_id {source_id!r}: {previous} and {locator}")
        previous_hash = seen_record_hashes.get(digest)
        if previous_hash is not None:
            raise SourceOwnershipError(
                f"duplicate source record hash {digest}: {previous_hash} and {locator}")

        actual = actual_by_locator.get(locator)
        if actual is None:
            raise SourceOwnershipError(f"catalog references unknown source {locator!r}")
        if actual["collection"] != collection:
            raise SourceOwnershipError(
                f"{where} collection does not match locator {locator!r}")
        if actual["source_record_sha256"] != digest:
            raise SourceOwnershipError(
                f"{where} record hash does not match protected source {locator!r}")
        record = actual["record"]
        authored_id = record.get("id")
        if identity_origin == "AUTHORED_RECORD_ID":
            if not isinstance(authored_id, str) or not authored_id:
                raise SourceOwnershipError(
                    f"{where} claims an authored id that is absent in the source")
            if source_id != authored_id:
                raise SourceOwnershipError(
                    f"{where} does not preserve authored id {authored_id!r}")
        elif collection not in {"walls", "site_lights", "slabs"}:
            raise SourceOwnershipError(
                f"{where} assigns a sidecar id to named collection {collection!r}")

        public_row = dict(row)
        resolved[locator] = public_row
        seen_source_ids[source_id] = locator
        seen_record_hashes[digest] = locator
        counts[collection] += 1
        identity_counts[identity_origin] += 1

    missing = sorted(set(actual_by_locator) - set(resolved))
    unknown = sorted(set(resolved) - set(actual_by_locator))
    if missing or unknown or counts != Counter(EXPECTED_SOURCE_COUNTS):
        raise SourceOwnershipError(
            "source ownership is not exact-once: "
            f"missing={missing} unknown={unknown} counts={dict(counts)}")
    if identity_counts != Counter({
            "AUTHORED_RECORD_ID": 4678,
            "M11C1_EXPLICIT_SIDECAR_ID": 608,
    }):
        raise SourceOwnershipError(
            f"source identity migration counts drift: {dict(identity_counts)}")

    _validate_rulings(sidecar, resolved)
    return resolved


def load_source_catalog(
    layout_path: Path, sidecar_path: Path,
) -> dict[str, dict[str, Any]]:
    """Load files, verify protected descriptor bytes, and resolve the catalog."""

    layout_path = Path(layout_path)
    sidecar_path = Path(sidecar_path)
    layout = _load_json(layout_path, "layout")
    sidecar = _load_json(sidecar_path, "source ownership sidecar")
    binding = sidecar.get("source_layout")
    if not isinstance(binding, Mapping):
        raise SourceOwnershipError("source_layout binding must be an object")
    expected_digest = binding.get("sha256")
    actual_digest = sha256_file(layout_path)
    if expected_digest != actual_digest:
        raise SourceOwnershipError(
            "protected layout byte hash does not match source ownership sidecar: "
            f"expected={expected_digest} actual={actual_digest}")
    return resolve_floor_records(layout, sidecar)


# Stable exporter-facing spelling.  Keep the plain-dict return so disposable
# launchers can serialize it without depending on a Python class definition.
load_source_ownership = load_source_catalog


def _parse_args(argv: list[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--layout", type=Path, default=DEFAULT_LAYOUT)
    parser.add_argument("--sidecar", type=Path, default=DEFAULT_SIDECAR)
    parser.add_argument("--json", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv)
    root = args.root.resolve()
    layout_path = args.layout if args.layout.is_absolute() else root / args.layout
    sidecar_path = (
        args.sidecar if args.sidecar.is_absolute() else root / args.sidecar)
    try:
        rows = load_source_catalog(layout_path, sidecar_path)
    except SourceOwnershipError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2
    by_collection = Counter(row["collection"] for row in rows.values())
    by_owner = Counter(row["owner_cell"] for row in rows.values())
    report = {
        "status": "PASS",
        "schema": SCHEMA,
        "schema_version": SCHEMA_VERSION,
        "record_count": len(rows),
        "counts_by_collection": dict(sorted(by_collection.items())),
        "counts_by_owner_cell": dict(sorted(by_owner.items())),
        "formerly_anonymous_records": sum(
            row["identity_origin"] == "M11C1_EXPLICIT_SIDECAR_ID"
            for row in rows.values()),
        "passage_overlap_rulings": len(PASSAGE_OVERLAP_LOCATORS),
        "spatial_inference_used": False,
    }
    if args.json:
        print(json.dumps(report, indent=2, sort_keys=True))
    else:
        print("ORISON F01 M11C1 SOURCE OWNERSHIP: PASS")
        print(f"  exact-once source records: {len(rows)}")
        print("  new durable sidecar identities: "
              f"{report['formerly_anonymous_records']}")
        print("  Passage-overlap lights explicitly ruled: "
              f"{report['passage_overlap_rulings']}")
        print("  spatial inference used: false")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
