#!/usr/bin/env python3
"""Read-only M11C0 ownership census for the protected floor-one source.

The current ``floor_01.gltf`` is a legacy, material-batched artifact.  It does
not contain a durable source-record-to-primitive map, so spatial bounds cannot
safely recover ownership after export.  This audit instead classifies every
relevant F01 record in ``art/data/building_layout.json`` into the smallest
defensible 17-cell partition, then reports what the protected glTF can and
cannot prove.

No file is written.  Anonymous walls, slabs, and site lights receive
rehearsal-only identities derived from canonical source content.  Those hashes
make exact-once accounting deterministic; they do not pretend the source has
finished its durable-identity migration.

Exit status:

* 0 - census complete; known provenance/identity debt is reported explicitly.
* 1 - source totals or protected glTF topology no longer match the rehearsal.
* 2 - malformed input, duplicate identity, or non-exact assignment.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any, Iterable


TOOL_VERSION = 1
DEFAULT_LAYOUT = "art/data/building_layout.json"
DEFAULT_GLTF = "game/assets/building/floor_01.gltf"

INTERIOR = "ORISON_F01_INTERIOR"
FACADE = "ORISON_F01_FACADE_SHELL"
STREET = "SITE_STREET_COMMON"
PASSAGE = "PASSAGE"
BAR = "SHOP_BAR"
BODEGA = "SHOP_BODEGA"

SHOP_SLUGS = (
    "MODEL_LAUNDRY",
    "SHOE_REBUILDING",
    "KEYS_CUT",
    "HARDWARE_PAINT",
    "FUNERAL_PARLOUR",
    "PHOTO_SUPPLIES",
    "RADIO_SERVICE",
    "PAWNBROKER",
    "NEWS_CIGARS",
    "OTIS___SON",
    "LUNCHEONETTE",
)
SHOP_CELLS = {slug: f"SHOP_{slug}" for slug in SHOP_SLUGS}
CELLS = (
    INTERIOR,
    FACADE,
    STREET,
    PASSAGE,
    BAR,
    BODEGA,
    *(SHOP_CELLS[slug] for slug in SHOP_SLUGS),
)

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
ANONYMOUS_COLLECTIONS = {"walls", "site_lights", "slabs"}

EXPECTED_SOURCE_TOTALS = {
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
EXPECTED_GLTF = {
    "nodes": 531,
    "meshes": 531,
    "primitives": 531,
    "accessors": 1740,
    "buffer_views": 1740,
    "materials": 104,
    "explicit_cell_nodes": 397,
    "legacy_mixed_nodes": 134,
}

PASSAGE_BATCHES = {"passage_shell"}
STREET_BATCHES = {"passage_proxy", "passage_proxy_gateway"}
FACADE_FURNITURE_PREFIXES = (
    "entry_", "water_table_", "age_", "ops_")
STREET_FURNITURE_PREFIXES = (
    "site_", "storm_", "walk_", "retail_")


class CensusError(Exception):
    """Malformed input or a source identity/assignment invariant failure."""


def canonical_json(value: Any) -> str:
    """Return the cross-run canonical representation used by this audit."""

    return json.dumps(
        value, ensure_ascii=False, sort_keys=True, separators=(",", ":"),
        allow_nan=False)


def content_hash(value: Any) -> str:
    return hashlib.sha256(canonical_json(value).encode("utf-8")).hexdigest()


def file_hash(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def anonymous_identity(
        floor_id: str, collection: str, record: dict[str, Any]) -> dict[str, str]:
    """Build an order-independent, index-independent rehearsal identity."""

    payload = {
        "schema": "orison-floor-source-anonymous-v1",
        "floor_id": floor_id,
        "collection": collection,
        "record": record,
    }
    digest = content_hash(payload)
    singular = {
        "walls": "WALL", "slabs": "SLAB", "site_lights": "SITE_LIGHT"
    }.get(collection, collection.rstrip("s").upper())
    return {
        "canonical_id": f"{floor_id}_{singular}_SHA256_{digest.upper()}",
        "canonical_hash_sha256": digest,
    }


def _shop_slug_from_batch(batch: str) -> str | None:
    if not batch.startswith("shop_"):
        return None
    slug = batch[len("shop_"):].upper()
    if slug not in SHOP_CELLS:
        raise CensusError(f"unknown shop batch {batch!r}")
    return slug


def _shop_slug_from_marker(marker_id: str) -> str | None:
    if not marker_id.startswith("SITE_SHOP_"):
        return None
    for slug in sorted(SHOP_SLUGS, key=len, reverse=True):
        if marker_id.endswith("_" + slug):
            return slug
    raise CensusError(f"unknown SITE_SHOP marker identity {marker_id!r}")


def classify_record(collection: str, record: dict[str, Any]) -> str:
    """Classify one source record without using a world-space centroid."""

    if collection == "furniture":
        identity = str(record.get("id", ""))
        batch = str(record.get("batch", ""))
        if batch:
            shop_slug = _shop_slug_from_batch(batch)
            if shop_slug:
                return SHOP_CELLS[shop_slug]
            if batch in PASSAGE_BATCHES:
                return PASSAGE
            if batch in STREET_BATCHES:
                return STREET
            if batch == "transit_shelter":
                return STREET
            raise CensusError(
                f"furniture {identity!r} uses unclassified batch {batch!r}")
        if identity.startswith("retail_bod"):
            return BODEGA
        if identity.startswith("retail_bar"):
            return BAR
        if identity.startswith(FACADE_FURNITURE_PREFIXES):
            return FACADE
        if identity.startswith(STREET_FURNITURE_PREFIXES):
            return STREET
        return INTERIOR

    if collection == "markers":
        identity = str(record.get("id", ""))
        shop_slug = _shop_slug_from_marker(identity)
        if shop_slug:
            return SHOP_CELLS[shop_slug]
        if identity.startswith("PASSAGE_PORTAL_"):
            # building_root.gd's ruled portal plane belongs to STREET; only
            # crossing north of it enters Passage.
            return STREET
        if identity.startswith("PASSAGE_"):
            return PASSAGE
        if identity.startswith("F01_BODEGA_"):
            return BODEGA
        if identity.startswith(("F01_BAR_", "F01_KARAOKE_")):
            return BAR
        if identity == "F01_DOOR_06" or identity.startswith(
                ("F01_NEON_", "F01_MARQUEE_")):
            return FACADE
        if identity.startswith("F01_STREETLAMP_"):
            return STREET
        return INTERIOR

    if collection == "walls":
        # ``in_side`` exists only on the ten authored perimeter walls.  Its
        # presence, unlike the current list ordinal, is stable source intent.
        return FACADE if "in_side" in record else INTERIOR
    if collection in {"rooms", "ceilings", "vent_registers", "slabs"}:
        return INTERIOR
    if collection == "sockets":
        return BAR if str(record.get("unit", "")) == "BAR" else INTERIOR
    if collection == "site_lights":
        # Collection authority remains site/street.  Spatial overlap with the
        # Passage envelope is separately reported as unresolved identity debt.
        return STREET
    raise CensusError(f"unsupported source collection {collection!r}")


def expected_legacy_emission(
        collection: str, record: dict[str, Any]) -> str:
    """Describe known legacy batching, without claiming primitive lineage."""

    if collection == "furniture":
        identity = str(record.get("id", ""))
        batch = str(record.get("batch", ""))
        if batch == "transit_shelter":
            return "EXPLICIT_TRANSIT_BATCH"
        if batch in PASSAGE_BATCHES:
            return "EXPLICIT_PASSAGE_BATCH"
        if batch in STREET_BATCHES:
            return "EXPLICIT_STREET_PASSAGE_PROXY_BATCH"
        if batch.startswith("shop_"):
            return "EXPLICIT_SHOP_BATCH"
        # The old exporter checks assembly before retail identity.  These are
        # the most important mixed-owner records in the protected artifact.
        if record.get("asm"):
            return "LEGACY_FURNISH_ASM_MIXED"
        if identity.startswith("retail_bar"):
            return "EXPLICIT_BAR_BOX_BATCH"
        if identity.startswith("retail_bod"):
            return "EXPLICIT_BODEGA_BOX_BATCH"
        return "LEGACY_FURNITURE_BOX_MIXED"
    return {
        "markers": "MARKER_DRIVEN_PROCEDURAL_OR_RUNTIME",
        "walls": "LEGACY_WALL_PROCEDURAL_MIXED",
        "rooms": "LEGACY_ROOM_FLOOR_BATCH",
        "ceilings": "LEGACY_CEILING_BATCH",
        "vent_registers": "LEGACY_VENT_BATCH",
        "sockets": "SOURCE_ONLY_SOCKET_AUTHORITY",
        "site_lights": "SOURCE_ONLY_SITE_LIGHT_AUTHORITY",
        "slabs": "LEGACY_SLAB_BATCH",
    }[collection]


def validate_assignments(
        source_locators: Iterable[str], assignments: Iterable[dict[str, Any]]) -> None:
    """Refuse missing or multiply assigned source records."""

    expected = list(source_locators)
    actual = [str(row.get("source_locator", "")) for row in assignments]
    duplicate_sources = sorted(
        key for key, count in Counter(actual).items() if count > 1)
    missing = sorted(set(expected) - set(actual))
    unknown = sorted(set(actual) - set(expected))
    if len(actual) != len(expected) or duplicate_sources or missing or unknown:
        raise CensusError(
            "source assignment is not exact-once: "
            f"expected={len(expected)} actual={len(actual)} "
            f"duplicates={duplicate_sources} missing={missing} unknown={unknown}")
    invalid_cells = sorted({
        str(row.get("cell_id", "")) for row in assignments
        if str(row.get("cell_id", "")) not in CELLS})
    if invalid_cells:
        raise CensusError(f"assignments reference unknown cells {invalid_cells}")


def _xy_extent(records: Iterable[dict[str, Any]]) -> list[float] | None:
    xs: list[float] = []
    ys: list[float] = []
    for record in records:
        rect = record.get("rect")
        if isinstance(rect, list) and len(rect) >= 4:
            xs.extend((float(rect[0]), float(rect[2])))
            ys.extend((float(rect[1]), float(rect[3])))
        at = record.get("at")
        if isinstance(at, list) and len(at) >= 2:
            xs.append(float(at[0]))
            ys.append(float(at[1]))
    if not xs:
        return None
    return [min(xs), min(ys), max(xs), max(ys)]


def classify_layout(
        layout: dict[str, Any], floor_id: str = "F01") -> dict[str, Any]:
    floors = layout.get("floors")
    if not isinstance(floors, list):
        raise CensusError("layout floors must be an array")
    matches = [floor for floor in floors if floor.get("id") == floor_id]
    if len(matches) != 1:
        raise CensusError(
            f"expected one {floor_id} floor record, found {len(matches)}")
    floor = matches[0]

    assignments: list[dict[str, Any]] = []
    source_locators: list[str] = []
    identities: dict[str, str] = {}
    anonymous: dict[str, list[dict[str, Any]]] = {
        collection: [] for collection in sorted(ANONYMOUS_COLLECTIONS)}

    for collection in SOURCE_COLLECTIONS:
        records = floor.get(collection)
        if not isinstance(records, list):
            raise CensusError(f"F01 {collection} must be an array")
        for index, record in enumerate(records):
            if not isinstance(record, dict):
                raise CensusError(f"F01 {collection}[{index}] is not an object")
            locator = f"floors[{floor_id}].{collection}[{index}]"
            source_locators.append(locator)
            if collection in ANONYMOUS_COLLECTIONS:
                identity = anonymous_identity(floor_id, collection, record)
                canonical_id = identity["canonical_id"]
                canonical_hash = identity["canonical_hash_sha256"]
                identity_kind = "REHEARSAL_CONTENT_HASH"
                anonymous[collection].append({
                    "source_locator": locator,
                    "canonical_id": canonical_id,
                    "canonical_hash_sha256": canonical_hash,
                })
            else:
                canonical_id = record.get("id")
                if not isinstance(canonical_id, str) or not canonical_id:
                    raise CensusError(
                        f"named F01 {collection}[{index}] has no non-empty id")
                canonical_hash = content_hash({
                    "floor_id": floor_id,
                    "collection": collection,
                    "id": canonical_id,
                    "record": record,
                })
                identity_kind = "AUTHORED_ID"

            previous = identities.get(canonical_id)
            if previous is not None:
                raise CensusError(
                    f"duplicate source identity {canonical_id!r}: "
                    f"{previous} and {locator}")
            identities[canonical_id] = locator
            assignments.append({
                "source_locator": locator,
                "collection": collection,
                "canonical_id": canonical_id,
                "canonical_hash_sha256": canonical_hash,
                "identity_kind": identity_kind,
                "cell_id": classify_record(collection, record),
                "expected_legacy_emission": expected_legacy_emission(
                    collection, record),
            })

    validate_assignments(source_locators, assignments)

    collection_cell: dict[str, Counter[str]] = defaultdict(Counter)
    cell_totals: Counter[str] = Counter()
    legacy_cell: dict[str, Counter[str]] = defaultdict(Counter)
    for row in assignments:
        collection_cell[row["collection"]][row["cell_id"]] += 1
        cell_totals[row["cell_id"]] += 1
        legacy_cell[row["expected_legacy_emission"]][row["cell_id"]] += 1

    passage_records = [
        row for row in floor["furniture"]
        if str(row.get("batch", "")) in PASSAGE_BATCHES]
    passage_envelope = _xy_extent(passage_records)
    overlapping_lights: list[dict[str, Any]] = []
    if passage_envelope is not None:
        x0, y0, x1, y1 = passage_envelope
        for index, light in enumerate(floor["site_lights"]):
            pos = light.get("pos")
            if isinstance(pos, list) and len(pos) >= 2 \
                    and x0 <= float(pos[0]) <= x1 \
                    and y0 <= float(pos[1]) <= y1:
                identity = anonymous_identity(floor_id, "site_lights", light)
                overlapping_lights.append({
                    "source_locator": f"floors[{floor_id}].site_lights[{index}]",
                    **identity,
                    "position": pos,
                })

    anonymous_rows = [row for rows in anonymous.values() for row in rows]
    anonymous_digest = content_hash([
        {"canonical_id": row["canonical_id"],
         "canonical_hash_sha256": row["canonical_hash_sha256"]}
        for row in sorted(anonymous_rows, key=lambda item: item["canonical_id"])
    ])

    return {
        "floor_id": floor_id,
        "cells": list(CELLS),
        "source_totals": {
            collection: len(floor[collection])
            for collection in SOURCE_COLLECTIONS
        },
        "assignment_count": len(assignments),
        "exact_once": True,
        "counts_by_collection_and_cell": {
            collection: dict(sorted(collection_cell[collection].items()))
            for collection in SOURCE_COLLECTIONS
        },
        "counts_by_cell": {
            cell: cell_totals.get(cell, 0) for cell in CELLS
        },
        "assignments": assignments,
        "identity_debt_receipt": {
            "status": "UNRESOLVED_SOURCE_IDENTITY_DEBT",
            "durable_source_identity": False,
            "anonymous_record_count": len(anonymous_rows),
            "counts": {
                collection: len(rows)
                for collection, rows in sorted(anonymous.items())
            },
            "canonical_receipt_sha256": anonymous_digest,
            "records": anonymous,
            "note": "Canonical hashes are rehearsal locators, not authored IDs.",
        },
        "expected_emitted_legacy_categories": {
            category: {
                "count": sum(by_cell.values()),
                "counts_by_cell": dict(sorted(by_cell.items())),
            }
            for category, by_cell in sorted(legacy_cell.items())
        },
        "ambiguities": [{
            "code": "SITE_LIGHTS_OVERLAP_PASSAGE_SHELL_ENVELOPE",
            "status": "UNRESOLVED",
            "passage_source_envelope_xy": passage_envelope,
            "production_runtime_ruling": {
                "portal_plane_source_y": -28.316,
                "portal_plane_owner": STREET,
                "passage_throat_source_x": [11.0, 17.0],
                "note": (
                    "building_root.gd excludes passage_proxy batches from "
                    "Passage indexing and assigns the portal plane to STREET."),
            },
            "records": overlapping_lights,
            "finding": (
                "Collection authority assigns these anonymous lights to "
                "SITE_STREET_COMMON. The broad shell envelope overlaps the "
                "street-owned portal/flank structure; overlap does not prove "
                "Passage ownership and durable IDs/lineage remain required."),
        }],
    }


def _explicit_gltf_cell(name: str) -> str | None:
    if name.startswith("F01_transit_") or name.startswith("F01_retail_site_"):
        return STREET
    if name.startswith("F01_retail_bar_"):
        return BAR
    if name.startswith("F01_retail_bod_"):
        return BODEGA
    if name.startswith(("F01_retail_passage_proxy_",
                        "F01_retail_passage_proxy_gateway_")):
        return STREET
    if name.startswith("F01_retail_passage_shell_"):
        return PASSAGE
    for slug in sorted(SHOP_SLUGS, key=len, reverse=True):
        if name.startswith("F01_retail_shop_" + slug.lower() + "_"):
            return SHOP_CELLS[slug]
    return None


def analyze_gltf(gltf: dict[str, Any]) -> dict[str, Any]:
    nodes = gltf.get("nodes", [])
    meshes = gltf.get("meshes", [])
    if not isinstance(nodes, list) or not isinstance(meshes, list):
        raise CensusError("glTF nodes and meshes must be arrays")
    node_names = [str(node.get("name", "")) for node in nodes]
    mesh_names = [str(mesh.get("name", "")) for mesh in meshes]
    for label, names in (("node", node_names), ("mesh", mesh_names)):
        duplicates = sorted(
            name for name, count in Counter(names).items() if count > 1)
        if "" in names or duplicates:
            raise CensusError(
                f"glTF {label} identity failure: blank={'' in names} "
                f"duplicates={duplicates}")

    explicit: Counter[str] = Counter()
    legacy_mixed: list[str] = []
    legacy_name_categories: Counter[str] = Counter()
    for name in node_names:
        cell = _explicit_gltf_cell(name)
        if cell is None:
            legacy_mixed.append(name)
            parts = name.split("_")
            category = "_".join(parts[:2]) if len(parts) > 1 else name
            legacy_name_categories[category] += 1
        else:
            explicit[cell] += 1

    primitive_count = 0
    for mesh in meshes:
        primitives = mesh.get("primitives", [])
        if not isinstance(primitives, list):
            raise CensusError("glTF mesh primitives must be arrays")
        primitive_count += len(primitives)

    scene_roots: list[int] = []
    scene_index = gltf.get("scene")
    scenes = gltf.get("scenes", [])
    if isinstance(scene_index, int) and isinstance(scenes, list) \
            and 0 <= scene_index < len(scenes):
        scene_roots = list(scenes[scene_index].get("nodes", []))

    transformed = sum(
        any(key in node for key in ("matrix", "translation", "rotation", "scale"))
        for node in nodes)
    mesh_name_mismatches = sum(
        1 for index, node in enumerate(nodes)
        if isinstance(node.get("mesh"), int)
        and 0 <= int(node["mesh"]) < len(meshes)
        and node_names[index] != mesh_names[int(node["mesh"])])

    topology = {
        "nodes": len(nodes),
        "meshes": len(meshes),
        "primitives": primitive_count,
        "accessors": len(gltf.get("accessors", [])),
        "buffer_views": len(gltf.get("bufferViews", [])),
        "materials": len(gltf.get("materials", [])),
        "explicit_cell_nodes": sum(explicit.values()),
        "legacy_mixed_nodes": len(legacy_mixed),
    }
    return {
        "topology": topology,
        "scene_root_node_count": len(scene_roots),
        "nodes_with_authored_transform": transformed,
        "node_mesh_name_mismatches": mesh_name_mismatches,
        "explicit_counts_by_cell": dict(sorted(explicit.items())),
        "legacy_mixed_name_categories": dict(
            sorted(legacy_name_categories.items())),
        "legacy_mixed_node_names": legacy_mixed,
        "legacy_mixed_provenance_resolved": False,
        "finding": (
            "The 134 legacy material/procedural batches have no durable "
            "source-record-to-primitive lineage. The source census is an "
            "exact ownership plan, not proof that the protected mixed glTF "
            "can already be split exactly."),
    }


def build_report(
        layout_path: Path, gltf_path: Path,
        *, enforce_expected: bool = True) -> dict[str, Any]:
    try:
        layout = json.loads(layout_path.read_text(encoding="utf-8"))
        gltf = json.loads(gltf_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise CensusError(str(exc)) from exc

    source = classify_layout(layout)
    protected = analyze_gltf(gltf)
    source_drift = {
        key: {"expected": expected, "actual": source["source_totals"].get(key)}
        for key, expected in EXPECTED_SOURCE_TOTALS.items()
        if source["source_totals"].get(key) != expected
    }
    gltf_drift = {
        key: {"expected": expected,
              "actual": protected["topology"].get(key)}
        for key, expected in EXPECTED_GLTF.items()
        if protected["topology"].get(key) != expected
    }
    status = "PASS" if not source_drift and not gltf_drift else "DRIFT"
    if enforce_expected and status != "PASS":
        # The report remains useful and main() returns 1.  Structural identity
        # and exact-once failures raise CensusError earlier and return 2.
        pass
    return {
        "tool": "audit_orison_floor01_source_ownership",
        "tool_version": TOOL_VERSION,
        "status": status,
        "read_only": True,
        "inputs": {
            "layout": str(layout_path),
            "layout_sha256": file_hash(layout_path),
            "gltf": str(gltf_path),
            "gltf_sha256": file_hash(gltf_path),
        },
        "partition": source,
        "protected_legacy_gltf": protected,
        "drift": {
            "source_totals": source_drift,
            "gltf_topology": gltf_drift,
        },
        "unresolved_findings": [
            {
                "code": "ANONYMOUS_SOURCE_IDENTITIES",
                "classification": "IDENTITY_DEBT",
                "blocking_for_exact_production_split": True,
                "count": source["identity_debt_receipt"][
                    "anonymous_record_count"],
            },
            {
                "code": "LEGACY_MIXED_GLTF_PROVENANCE",
                "classification": "UNRESOLVED",
                "blocking_for_exact_protected_gltf_partition": True,
                "count": protected["topology"]["legacy_mixed_nodes"],
            },
            *source["ambiguities"],
        ],
    }


def _parse_args(argv: list[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--layout", default=DEFAULT_LAYOUT)
    parser.add_argument("--gltf", default=DEFAULT_GLTF)
    parser.add_argument(
        "--json", action="store_true",
        help="print the full machine-readable receipt instead of a summary")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv)
    root = args.root.resolve()
    layout_path = Path(args.layout)
    gltf_path = Path(args.gltf)
    if not layout_path.is_absolute():
        layout_path = root / layout_path
    if not gltf_path.is_absolute():
        gltf_path = root / gltf_path
    try:
        report = build_report(layout_path, gltf_path)
    except CensusError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2

    if not args.json:
        partition = report["partition"]
        topology = report["protected_legacy_gltf"]["topology"]
        print(f"ORISON F01 SOURCE OWNERSHIP: {report['status']}")
        print(f"  cells: {len(partition['cells'])}")
        print(f"  exact-once source records: {partition['assignment_count']}")
        print("  anonymous source identities: "
              f"{partition['identity_debt_receipt']['anonymous_record_count']}")
        print(f"  protected glTF nodes: {topology['nodes']}")
        print(f"  explicit owner nodes: {topology['explicit_cell_nodes']}")
        print(f"  unresolved legacy-mixed nodes: {topology['legacy_mixed_nodes']}")
        print("  legacy mixed provenance resolved: false")
    else:
        print(json.dumps(report, ensure_ascii=False, sort_keys=True, indent=2))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
