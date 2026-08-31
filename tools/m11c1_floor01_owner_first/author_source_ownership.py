#!/usr/bin/env python3
"""Materialize the inert M11C1 F01 ownership catalog from authoring context.

This is an authoring operation for the new sidecar only.  It never writes the
protected layout, glTF/BIN, production layouts, selector, or imported assets.
Ownership rules read semantic authoring fields (collection, authored ID,
batch, zone-family identity, ``unit``, and the perimeter-wall ``in_side``
flag).  Coordinates and exported geometry are deliberately unavailable to the
classifier.
"""

from __future__ import annotations

import argparse
import json
import sys
from collections.abc import Mapping
from pathlib import Path
from typing import Any


if __package__:
    from . import source_ownership as contract
else:
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import source_ownership as contract  # type: ignore[no-redef]


INTERIOR = "CELL_ORISON_F01_INTERIOR"
FACADE = "CELL_ORISON_FACADE_SHELL"
STREET = "CELL_SITE_STREET_COMMON"
PASSAGE = "CELL_PASSAGE"
BAR = "CELL_SHOP_BAR"
BODEGA = "CELL_SHOP_BODEGA"

SHOP_OWNER_BY_SLUG = {
    "MODEL_LAUNDRY": "CELL_SHOP_MODEL_LAUNDRY",
    "SHOE_REBUILDING": "CELL_SHOP_SHOE_REBUILDING",
    "KEYS_CUT": "CELL_SHOP_KEYS_CUT",
    "HARDWARE_PAINT": "CELL_SHOP_HARDWARE_PAINT",
    "FUNERAL_PARLOUR": "CELL_SHOP_FUNERAL_PARLOUR",
    "PHOTO_SUPPLIES": "CELL_SHOP_PHOTO_SUPPLIES",
    "RADIO_SERVICE": "CELL_SHOP_RADIO_SERVICE",
    "PAWNBROKER": "CELL_SHOP_PAWNBROKER",
    "NEWS_CIGARS": "CELL_SHOP_NEWS_CIGARS",
    "OTIS___SON": "CELL_SHOP_OTIS_SON",
    "LUNCHEONETTE": "CELL_SHOP_LUNCHEONETTE",
}

FACADE_FURNITURE_PREFIXES = ("entry_", "water_table_", "age_", "ops_")
STREET_FURNITURE_PREFIXES = ("site_", "storm_", "walk_", "retail_")
PASSAGE_BATCHES = {"passage_shell"}
STREET_BATCHES = {"passage_proxy", "passage_proxy_gateway"}

# These eleven source-authored ``storm_sf_*_stall*`` records are the shared
# stallboards under the Passage shopfronts.  Their shop batch describes the
# finish family that emitted them; it is not their residency owner.  The
# authored ID family is the durable source context that distinguishes the
# common arcade boundary from the fixtures behind it.  This explicit rule is
# intentionally evaluated before the broader shop-batch rule and never reads
# coordinates, bounds, or exported geometry.
PASSAGE_SHARED_STALLBOARD_IDS = {
    "storm_sf_model_laundry_stall0",
    "storm_sf_shoe_rebuilding_stall0",
    "storm_sf_keys_cut_stall0",
    "storm_sf_hardware_paint_stall0",
    "storm_sf_funeral_parlour_stall0",
    "storm_sf_photo_supplies_stall1",
    "storm_sf_radio_service_stall0",
    "storm_sf_pawnbroker_stall0",
    "storm_sf_news_cigars_stall1",
    "storm_sf_otis___son_stall0",
    "storm_sf_luncheonette_stall1",
}

ANONYMOUS_ID_FORMAT = {
    "walls": "F01_WALL_{number:03d}",
    "site_lights": "F01_SITE_LIGHT_{number:04d}",
    "slabs": "F01_SLAB_{number:03d}",
}


def _shop_from_batch(batch: str) -> str | None:
    if not batch.startswith("shop_"):
        return None
    slug = batch[len("shop_"):].upper()
    if slug not in SHOP_OWNER_BY_SLUG:
        raise contract.SourceOwnershipError(
            f"unknown authored shop batch {batch!r}")
    return slug


def _shop_from_marker(identity: str) -> str | None:
    if not identity.startswith("SITE_SHOP_"):
        return None
    for slug in sorted(SHOP_OWNER_BY_SLUG, key=len, reverse=True):
        if identity.endswith("_" + slug):
            return slug
    raise contract.SourceOwnershipError(
        f"unknown authored SITE_SHOP marker {identity!r}")


def authored_owner(
    collection: str, record: Mapping[str, Any],
) -> tuple[str, str]:
    """Return explicit owner/context using semantic authoring data only."""

    if collection == "furniture":
        identity = str(record.get("id", ""))
        batch = str(record.get("batch", ""))
        if identity in PASSAGE_SHARED_STALLBOARD_IDS:
            if record.get("zone") != "PASSAGE" or _shop_from_batch(batch) is None:
                raise contract.SourceOwnershipError(
                    f"shared Passage stallboard {identity!r} lost its authored "
                    "Passage/shopfront context")
            return PASSAGE, "PASSAGE_SHARED_SHOPFRONT_STALLBOARD_ID_FAMILY"
        if batch:
            slug = _shop_from_batch(batch)
            if slug is not None:
                return SHOP_OWNER_BY_SLUG[slug], f"SHOP_BATCH_{slug}"
            if batch in PASSAGE_BATCHES:
                return PASSAGE, "PASSAGE_SHELL_AUTHORED_BATCH"
            if batch in STREET_BATCHES:
                return STREET, "SITE_PASS_PASSAGE_PROXY_STREET_BATCH"
            if batch == "transit_shelter":
                return STREET, "SITE_PASS_TRANSIT_SHELTER_BATCH"
            raise contract.SourceOwnershipError(
                f"furniture {identity!r} uses unknown authored batch {batch!r}")
        if identity.startswith("retail_bod"):
            return BODEGA, "RETAIL_BODEGA_AUTHORED_ID_FAMILY"
        if identity.startswith("retail_bar"):
            return BAR, "RETAIL_BAR_AUTHORED_ID_FAMILY"
        if identity.startswith(FACADE_FURNITURE_PREFIXES):
            return FACADE, "F01_FACADE_AUTHORED_ID_FAMILY"
        if identity.startswith(STREET_FURNITURE_PREFIXES):
            return STREET, "SITE_PASS_AUTHORED_ID_FAMILY"
        return INTERIOR, "F01_BUILDING_INTERIOR_FURNITURE_CONTEXT"

    if collection == "markers":
        identity = str(record.get("id", ""))
        slug = _shop_from_marker(identity)
        if slug is not None:
            return SHOP_OWNER_BY_SLUG[slug], f"SHOP_MARKER_{slug}"
        if identity.startswith("PASSAGE_PORTAL_"):
            return STREET, "SITE_PASS_PASSAGE_PORTAL_MARKER_CONTEXT"
        if identity.startswith("PASSAGE_"):
            return PASSAGE, "PASSAGE_MARKER_CONTEXT"
        if identity.startswith("F01_BODEGA_"):
            return BODEGA, "RETAIL_BODEGA_MARKER_CONTEXT"
        if identity.startswith(("F01_BAR_", "F01_KARAOKE_")):
            return BAR, "RETAIL_BAR_MARKER_CONTEXT"
        if identity == "F01_DOOR_06" or identity.startswith(
                ("F01_NEON_", "F01_MARQUEE_")):
            return FACADE, "F01_FACADE_MARKER_CONTEXT"
        if identity.startswith("F01_STREETLAMP_"):
            return STREET, "SITE_PASS_STREET_MARKER_CONTEXT"
        return INTERIOR, "F01_BUILDING_INTERIOR_MARKER_CONTEXT"

    if collection == "walls":
        # ``in_side`` is authored by normalize_wall_construction for masonry
        # envelope records.  It is semantic construction context, not a test
        # of the wall's coordinates or bounds.
        if "in_side" in record:
            return FACADE, "F01_AUTHORED_PERIMETER_WALL_CONTEXT"
        return INTERIOR, "F01_AUTHORED_INTERIOR_WALL_CONTEXT"

    if collection in {"rooms", "ceilings", "vent_registers", "slabs"}:
        return INTERIOR, "F01_BUILDING_INTERIOR_COLLECTION_CONTEXT"

    if collection == "sockets":
        if record.get("unit") == "BAR":
            return BAR, "RETAIL_BAR_SOCKET_UNIT_CONTEXT"
        return INTERIOR, "F01_BUILDING_INTERIOR_SOCKET_CONTEXT"

    if collection == "site_lights":
        # These are unshaded window-card data created and attached by
        # site_pass. Passage aisle/shop lamps are authored marker records and
        # never enter this collection.
        return STREET, "SITE_PASS_SITE_LIGHT_COLLECTION"

    raise contract.SourceOwnershipError(
        f"unsupported source collection {collection!r}")


def _source_id(
    collection: str, index: int, record: Mapping[str, Any],
) -> tuple[str, str]:
    if collection in ANONYMOUS_ID_FORMAT:
        authored_id = record.get("id")
        if authored_id not in (None, ""):
            raise contract.SourceOwnershipError(
                f"{contract.source_locator(collection, index)} unexpectedly "
                "already has an authored id; revise the identity migration")
        return (
            ANONYMOUS_ID_FORMAT[collection].format(number=index + 1),
            "M11C1_EXPLICIT_SIDECAR_ID",
        )
    authored_id = record.get("id")
    if not isinstance(authored_id, str) or not authored_id:
        raise contract.SourceOwnershipError(
            f"{contract.source_locator(collection, index)} lacks an authored id")
    return authored_id, "AUTHORED_RECORD_ID"


def build_sidecar(
    layout: Mapping[str, Any], protected_layout_sha256: str,
) -> dict[str, Any]:
    """Build a deterministic all-source catalog; do not write any file."""

    source_rows = contract.enumerate_floor_records(layout)
    records: list[dict[str, Any]] = []
    index_by_locator: dict[str, int] = {}
    for raw in source_rows:
        locator = raw["source_locator"]
        collection = raw["collection"]
        index = int(locator.rsplit("[", 1)[1][:-1])
        record = raw["record"]
        owner, context = authored_owner(collection, record)
        source_id, identity_origin = _source_id(collection, index, record)
        index_by_locator[locator] = len(records)
        records.append(
            {
                "source_id": source_id,
                "source_locator": locator,
                "collection": collection,
                "source_record_sha256": raw["source_record_sha256"],
                "owner_cell": owner,
                "identity_origin": identity_origin,
                "authoring_context": context,
            }
        )

    rulings: list[dict[str, Any]] = []
    for ordinal, locator in enumerate(contract.PASSAGE_OVERLAP_LOCATORS, 1):
        try:
            row = records[index_by_locator[locator]]
        except KeyError as exc:
            raise contract.SourceOwnershipError(
                f"reviewed Passage-overlap locator is absent: {locator}") from exc
        rulings.append(
            {
                "ruling_id": f"M11C1_PASSAGE_OVERLAP_SITE_LIGHT_{ordinal:02d}",
                "source_id": row["source_id"],
                "source_locator": locator,
                "source_record_sha256": row["source_record_sha256"],
                "owner_cell": STREET,
                "authoring_context": "SITE_PASS_CITY_WINDOW_CARD_CONTEXT",
                "decision": "SITE_STREET_COMMON_BY_AUTHORING_CONTEXT",
                "spatial_inference_used": False,
                "note": (
                    "M11C0 flagged overlap for review. The record remains a "
                    "site_pass city-window card; overlap with the Passage "
                    "envelope is not ownership evidence."
                ),
            }
        )

    sidecar: dict[str, Any] = {
        "schema": contract.SCHEMA,
        "schema_version": contract.SCHEMA_VERSION,
        "milestone": "ORISON-V2-M11C1",
        "authority": "AUTHORING_CONTEXT_EXPLICIT",
        "floor_id": contract.FLOOR_ID,
        "source_layout": {
            "path": contract.DEFAULT_LAYOUT.as_posix(),
            "sha256": protected_layout_sha256,
            "floor_recordset_sha256": contract.floor_recordset_sha256(layout),
        },
        "source_collections": list(contract.SOURCE_COLLECTIONS),
        "expected_counts": dict(contract.EXPECTED_SOURCE_COUNTS),
        "record_count": contract.EXPECTED_RECORD_COUNT,
        "owner_cells": list(contract.OWNER_CELLS),
        "identity_migration": {
            "authored_record_ids_preserved": 4678,
            "m11c1_explicit_sidecar_ids": {
                "walls": 42,
                "site_lights": 565,
                "slabs": 1,
                "total": 608,
            },
            "content_hash_ids_forbidden": True,
        },
        "ownership_basis": {
            "source": "art/data/gen_layout.py and materialized building layout fields",
            "method": "semantic authoring context",
            "allowed_inputs": [
                "source collection",
                "authored source id",
                "authored batch",
                "authored shared-shopfront stallboard id family",
                "authored unit",
                "authored perimeter in_side flag",
            ],
            "forbidden_inputs": [
                "position",
                "bounds",
                "centroid",
                "connected components",
                "post-export primitive inspection",
            ],
        },
        "spatial_inference_used": False,
        "records": records,
        "records_sha256": contract.sha256_value(records),
        "explicit_owner_rulings": rulings,
        "invariants": {
            "every_f01_source_record_exactly_once": True,
            "missing_owner_refused": True,
            "duplicate_owner_refused": True,
            "unknown_owner_refused": True,
            "protected_layout_mutated": False,
            "export_or_runtime_redirect_performed": False,
        },
    }
    contract.resolve_floor_records(layout, sidecar)
    return sidecar


def _load_layout(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise contract.SourceOwnershipError(f"cannot read layout {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise contract.SourceOwnershipError("layout root must be an object")
    return value


def _render(sidecar: Mapping[str, Any]) -> str:
    return json.dumps(sidecar, ensure_ascii=False, sort_keys=True, indent=2) + "\n"


def _parse_args(argv: list[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--layout", type=Path, default=contract.DEFAULT_LAYOUT)
    parser.add_argument("--output", type=Path, default=contract.DEFAULT_SIDECAR)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--write", action="store_true")
    mode.add_argument("--check", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv)
    root = args.root.resolve()
    layout_path = args.layout if args.layout.is_absolute() else root / args.layout
    output_path = args.output if args.output.is_absolute() else root / args.output
    if layout_path.resolve() == output_path.resolve():
        print("ERROR: sidecar output may not replace the protected layout", file=sys.stderr)
        return 2
    action = "CURRENT"
    try:
        layout = _load_layout(layout_path)
        sidecar = build_sidecar(layout, contract.sha256_file(layout_path))
        rendered = _render(sidecar)
        if args.check:
            current = output_path.read_text(encoding="utf-8")
            if current != rendered:
                print("ERROR: checked-in ownership sidecar is stale", file=sys.stderr)
                return 1
        else:
            # ``--write`` is an initial-authoring operation, not a migration
            # command.  The 608 new IDs are intentionally durable once the
            # sidecar exists.  Re-numbering after a source insertion/reorder
            # would silently move identity between records, so a differing
            # existing catalog requires an explicit reviewed migration tool.
            if output_path.exists():
                current = output_path.read_text(encoding="utf-8")
                if current != rendered:
                    print(
                        "ERROR: refusing to rewrite an existing ownership "
                        "sidecar; preserve durable IDs with an explicit "
                        "reviewed migration",
                        file=sys.stderr,
                    )
                    return 2
            else:
                output_path.parent.mkdir(parents=True, exist_ok=True)
                output_path.write_text(rendered, encoding="utf-8", newline="\n")
                action = "WROTE"
    except (OSError, contract.SourceOwnershipError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2
    print(
        "ORISON F01 M11C1 OWNERSHIP SIDECAR: "
        f"{action} {len(sidecar['records'])} records"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
