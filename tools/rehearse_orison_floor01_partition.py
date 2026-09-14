#!/usr/bin/env python3
"""Build and verify a disposable, whole-node floor_01 partition.

This is deliberately a rehearsal instrument.  It consumes only
``safe_current_partition`` from the supplied manifest and never evaluates a
triangle, centroid, bounding-box, or desired/target partition rule.  A source
node, its one source mesh, and every primitive in that mesh stay together.

The production floor assets are opened read-only.  Generated compact glTF/BIN
cells, a shared texture library, and machine receipts are written only below
the explicit output directory.
"""

from __future__ import annotations

import argparse
import base64
import copy
import hashlib
import json
import math
from collections import Counter
from dataclasses import dataclass, field
from pathlib import Path, PurePosixPath
import sys
from typing import Any
from urllib.parse import unquote


REPO_ROOT = Path(__file__).resolve().parents[1]
INDEXED_ARRAYS = {
    "nodes", "meshes", "accessors", "bufferViews", "buffers",
    "materials", "textures", "images", "samplers", "scenes",
    "animations", "skins", "cameras",
}
SPATIAL_RULE_KEYS = {
    "bounds", "bounding_box", "centroid", "triangle", "triangles",
    "primitive_bounds", "spatial", "plane", "inside", "outside",
}
TRANSFORM_KEYS = ("matrix", "translation", "rotation", "scale")
WELDED_PREFIXES = ("F01_furnish_", "F01_furniture_")
HARNESS_TEMPLATE_FILES = (
    "project.godot",
    "harness_main.gd",
    "harness_main.tscn",
    "m11c0_capture.gd",
    "m11c0_cell_composition.gd",
    "m11c0_harness_support.gd",
    "m11c0_runtime_validation.gd",
)


class RehearsalError(RuntimeError):
    """A fail-closed source, manifest, or recomposition violation."""


def _sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _canonical_bytes(value: Any) -> bytes:
    return json.dumps(
        value, sort_keys=True, separators=(",", ":"), ensure_ascii=False,
    ).encode("utf-8")


def _canonical_hash(value: Any) -> str:
    return _sha256_bytes(_canonical_bytes(value))


def _json_bytes(value: Any) -> bytes:
    return (json.dumps(value, indent=2, ensure_ascii=False)
            + "\n").encode("utf-8")


def _write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(_json_bytes(value))


def _as_index(value: Any, label: str, size: int) -> int:
    if not isinstance(value, int) or isinstance(value, bool):
        raise RehearsalError(f"{label} must be an integer index")
    if value < 0 or value >= size:
        raise RehearsalError(
            f"{label} index {value} is outside 0..{size - 1}")
    return value


def _safe_relative_uri(uri: str, label: str) -> PurePosixPath:
    decoded = unquote(uri).replace("\\", "/")
    path = PurePosixPath(decoded)
    if (not decoded or path.is_absolute() or ".." in path.parts
            or ":" in path.parts[0]):
        raise RehearsalError(f"{label} is not a safe relative URI: {uri!r}")
    return path


def _deep_spatial_keys(value: Any) -> set[str]:
    found: set[str] = set()
    if isinstance(value, dict):
        for key, child in value.items():
            if str(key).lower() in SPATIAL_RULE_KEYS:
                found.add(str(key))
            found.update(_deep_spatial_keys(child))
    elif isinstance(value, list):
        for child in value:
            found.update(_deep_spatial_keys(child))
    return found


@dataclass
class AssetView:
    path: Path
    document: dict[str, Any]
    bin_bytes: bytes
    external_images: dict[str, bytes] = field(default_factory=dict)

    def view_bytes(self, view_index: int) -> bytes:
        views = self.document.get("bufferViews", [])
        index = _as_index(view_index, "bufferView", len(views))
        view = views[index]
        if int(view.get("buffer", 0)) != 0:
            raise RehearsalError("only the ruled single geometry buffer is supported")
        offset = int(view.get("byteOffset", 0))
        length = int(view.get("byteLength", -1))
        if offset < 0 or length < 0 or offset + length > len(self.bin_bytes):
            raise RehearsalError(
                f"bufferView {index} span {offset}+{length} is invalid")
        return self.bin_bytes[offset:offset + length]

    def image_bytes(self, image_index: int) -> bytes:
        images = self.document.get("images", [])
        index = _as_index(image_index, "image", len(images))
        image = images[index]
        if "uri" in image:
            uri = str(image["uri"])
            if uri.startswith("data:"):
                try:
                    return base64.b64decode(uri.split(",", 1)[1], validate=True)
                except (IndexError, ValueError) as error:
                    raise RehearsalError(
                        f"image {index} has an invalid data URI") from error
            if uri not in self.external_images:
                raise RehearsalError(
                    f"image {index} external bytes were not resolved: {uri}")
            return self.external_images[uri]
        if "bufferView" in image:
            return self.view_bytes(int(image["bufferView"]))
        raise RehearsalError(f"image {index} has neither uri nor bufferView")


def load_asset(gltf_path: Path) -> AssetView:
    gltf_path = gltf_path.resolve()
    try:
        document = json.loads(gltf_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise RehearsalError(f"could not read glTF {gltf_path}: {error}") from error
    if not isinstance(document, dict):
        raise RehearsalError("glTF root must be an object")
    buffers = document.get("buffers", [])
    if not isinstance(buffers, list) or len(buffers) != 1:
        raise RehearsalError("rehearsal requires exactly one external BIN buffer")
    buffer_uri = str(buffers[0].get("uri", ""))
    if buffer_uri.startswith("data:"):
        raise RehearsalError("embedded geometry buffers are outside floor_01 scope")
    rel_buffer = _safe_relative_uri(buffer_uri, "buffer URI")
    bin_path = gltf_path.parent.joinpath(*rel_buffer.parts).resolve()
    if not bin_path.is_file():
        raise RehearsalError(f"missing geometry buffer: {bin_path}")
    bin_bytes = bin_path.read_bytes()
    declared = int(buffers[0].get("byteLength", -1))
    if declared != len(bin_bytes):
        raise RehearsalError(
            f"buffer length {len(bin_bytes)} != declared {declared}")

    external_images: dict[str, bytes] = {}
    for image_index, image in enumerate(document.get("images", [])):
        if not isinstance(image, dict) or "uri" not in image:
            continue
        uri = str(image["uri"])
        if uri.startswith("data:"):
            continue
        rel_image = _safe_relative_uri(uri, f"image {image_index} URI")
        image_path = gltf_path.parent.joinpath(*rel_image.parts).resolve()
        if not image_path.is_file():
            raise RehearsalError(f"missing image dependency: {image_path}")
        external_images[uri] = image_path.read_bytes()
    return AssetView(gltf_path, document, bin_bytes, external_images)


def _accessors_in_primitive(primitive: dict[str, Any]) -> set[int]:
    indices: set[int] = set()
    attributes = primitive.get("attributes", {})
    if not isinstance(attributes, dict):
        raise RehearsalError("primitive attributes must be an object")
    for value in attributes.values():
        if not isinstance(value, int):
            raise RehearsalError("primitive attribute accessor must be an index")
        indices.add(value)
    if "indices" in primitive:
        if not isinstance(primitive["indices"], int):
            raise RehearsalError("primitive indices accessor must be an index")
        indices.add(primitive["indices"])
    for target in primitive.get("targets", []):
        if not isinstance(target, dict):
            raise RehearsalError("morph target must be an object")
        for value in target.values():
            if not isinstance(value, int):
                raise RehearsalError("morph target accessor must be an index")
            indices.add(value)
    return indices


def _texture_refs(value: Any, path: tuple[str, ...] = ()) -> set[int]:
    found: set[int] = set()
    if isinstance(value, dict):
        if (path and path[-1].lower().endswith("texture")
                and "index" in value):
            if not isinstance(value["index"], int):
                raise RehearsalError("material texture index must be an integer")
            found.add(value["index"])
        for key, child in value.items():
            found.update(_texture_refs(child, path + (str(key),)))
    elif isinstance(value, list):
        for child in value:
            found.update(_texture_refs(child, path))
    return found


def _remap_texture_refs(
        value: Any, remap: dict[int, int], path: tuple[str, ...] = ()) -> Any:
    if isinstance(value, dict):
        result = {}
        for key, child in value.items():
            if (key == "index" and path
                    and path[-1].lower().endswith("texture")):
                old = int(child)
                if old not in remap:
                    raise RehearsalError(f"missing texture dependency {old}")
                result[key] = remap[old]
            else:
                result[key] = _remap_texture_refs(
                    child, remap, path + (str(key),))
        return result
    if isinstance(value, list):
        return [_remap_texture_refs(child, remap, path) for child in value]
    return copy.deepcopy(value)


def _image_refs_in_texture(value: Any) -> set[int]:
    found: set[int] = set()
    if isinstance(value, dict):
        for key, child in value.items():
            if key == "source":
                if not isinstance(child, int):
                    raise RehearsalError("texture image source must be an index")
                found.add(child)
            else:
                found.update(_image_refs_in_texture(child))
    elif isinstance(value, list):
        for child in value:
            found.update(_image_refs_in_texture(child))
    return found


def _remap_image_refs_in_texture(value: Any, remap: dict[int, int]) -> Any:
    if isinstance(value, dict):
        result = {}
        for key, child in value.items():
            if key == "source":
                old = int(child)
                if old not in remap:
                    raise RehearsalError(f"missing image dependency {old}")
                result[key] = remap[old]
            else:
                result[key] = _remap_image_refs_in_texture(child, remap)
        return result
    if isinstance(value, list):
        return [_remap_image_refs_in_texture(child, remap) for child in value]
    return copy.deepcopy(value)


def validate_source(asset: AssetView) -> dict[str, Any]:
    doc = asset.document
    if str(doc.get("asset", {}).get("version", "")) != "2.0":
        raise RehearsalError("source is not glTF 2.0")
    unsupported = [key for key in ("animations", "skins", "cameras")
                   if doc.get(key)]
    if unsupported:
        raise RehearsalError(
            "whole-node floor rehearsal does not support: "
            + ", ".join(unsupported))
    nodes = doc.get("nodes", [])
    meshes = doc.get("meshes", [])
    scenes = doc.get("scenes", [])
    if not isinstance(nodes, list) or not isinstance(meshes, list):
        raise RehearsalError("nodes and meshes must be arrays")
    scene_index = _as_index(doc.get("scene", 0), "scene", len(scenes))
    roots = scenes[scene_index].get("nodes", [])
    if roots != list(range(len(nodes))):
        raise RehearsalError(
            "source must expose every floor node once as an active-scene root")
    names: set[str] = set()
    mesh_users: Counter[int] = Counter()
    primitive_count = 0
    used_accessors: set[int] = set()
    used_materials: set[int] = set()
    for node_index, node in enumerate(nodes):
        if not isinstance(node, dict):
            raise RehearsalError(f"node {node_index} must be an object")
        if node.get("children"):
            raise RehearsalError(
                f"node {node_index} has children; floor_01 is flat by contract")
        name = str(node.get("name", ""))
        if not name or name in names:
            raise RehearsalError(f"node name is missing or duplicated: {name!r}")
        names.add(name)
        mesh_index = _as_index(node.get("mesh"),
                               f"node {node_index} mesh", len(meshes))
        mesh_users[mesh_index] += 1
        mesh = meshes[mesh_index]
        primitives = mesh.get("primitives", [])
        if not isinstance(primitives, list) or not primitives:
            raise RehearsalError(f"mesh {mesh_index} has no primitives")
        for primitive_index, primitive in enumerate(primitives):
            if not isinstance(primitive, dict):
                raise RehearsalError(
                    f"mesh {mesh_index} primitive {primitive_index} is invalid")
            if "extensions" in primitive:
                raise RehearsalError(
                    "primitive extensions require a separately audited remapper")
            primitive_count += 1
            used_accessors.update(_accessors_in_primitive(primitive))
            if "material" in primitive:
                used_materials.add(_as_index(
                    primitive["material"], "primitive material",
                    len(doc.get("materials", []))))
    if set(mesh_users) != set(range(len(meshes))):
        raise RehearsalError("one or more meshes are not owned by a scene node")
    duplicated_meshes = [index for index, count in mesh_users.items()
                         if count != 1]
    if duplicated_meshes:
        raise RehearsalError(
            "source mesh ownership is not one-to-one: "
            + ", ".join(map(str, duplicated_meshes)))

    accessors = doc.get("accessors", [])
    for index in used_accessors:
        _as_index(index, "primitive accessor", len(accessors))
    if used_accessors != set(range(len(accessors))):
        raise RehearsalError("source has accessors outside primitive ownership")
    materials = doc.get("materials", [])
    if used_materials != set(range(len(materials))):
        raise RehearsalError("source has materials outside primitive ownership")

    used_textures: set[int] = set()
    for material_index in used_materials:
        used_textures.update(_texture_refs(materials[material_index]))
    textures = doc.get("textures", [])
    for index in used_textures:
        _as_index(index, "material texture", len(textures))
    if used_textures != set(range(len(textures))):
        raise RehearsalError("source has textures outside material ownership")
    used_images: set[int] = set()
    used_samplers: set[int] = set()
    for texture_index in used_textures:
        texture = textures[texture_index]
        used_images.update(_image_refs_in_texture(texture))
        if "sampler" in texture:
            used_samplers.add(_as_index(
                texture["sampler"], "texture sampler",
                len(doc.get("samplers", []))))
    images = doc.get("images", [])
    for index in used_images:
        _as_index(index, "texture image", len(images))
    if used_images != set(range(len(images))):
        raise RehearsalError("source has images outside texture ownership")
    samplers = doc.get("samplers", [])
    if used_samplers != set(range(len(samplers))):
        raise RehearsalError("source has samplers outside texture ownership")

    views = doc.get("bufferViews", [])
    used_views: set[int] = set()
    for accessor_index, accessor in enumerate(accessors):
        if "bufferView" not in accessor:
            raise RehearsalError(
                f"accessor {accessor_index} has no ruled bufferView")
        used_views.add(_as_index(accessor["bufferView"],
                                 "accessor bufferView", len(views)))
        sparse = accessor.get("sparse")
        if sparse:
            for part in ("indices", "values"):
                used_views.add(_as_index(
                    sparse[part]["bufferView"],
                    f"sparse accessor {part} bufferView", len(views)))
    for image_index in used_images:
        if "bufferView" in images[image_index]:
            used_views.add(_as_index(
                images[image_index]["bufferView"],
                f"image {image_index} bufferView", len(views)))
    if used_views != set(range(len(views))):
        raise RehearsalError("source has bufferViews outside owned dependencies")

    spans = []
    for index, view in enumerate(views):
        if int(view.get("buffer", 0)) != 0:
            raise RehearsalError("source bufferView references a second buffer")
        offset = int(view.get("byteOffset", 0))
        length = int(view.get("byteLength", -1))
        if offset < 0 or length < 0 or offset + length > len(asset.bin_bytes):
            raise RehearsalError(f"source bufferView {index} is out of range")
        if offset % 4:
            raise RehearsalError(f"source bufferView {index} is not 4-byte aligned")
        spans.append((offset, offset + length, index))
    spans.sort()
    overlap = []
    gaps = []
    cursor = 0
    for start, end, index in spans:
        if start < cursor:
            overlap.append(index)
        elif start > cursor:
            gaps.append([cursor, start])
        cursor = max(cursor, end)
    if overlap:
        raise RehearsalError(
            "source bufferViews overlap: " + ", ".join(map(str, overlap)))
    if cursor < len(asset.bin_bytes):
        gaps.append([cursor, len(asset.bin_bytes)])

    return {
        "nodes": len(nodes),
        "meshes": len(meshes),
        "primitives": primitive_count,
        "accessors": len(accessors),
        "buffer_views": len(views),
        "materials": len(materials),
        "textures": len(textures),
        "images": len(images),
        "samplers": len(samplers),
        "collision_tagged_nodes": sum(
            str(node.get("name", "")).endswith(("-col", "-colonly"))
            for node in nodes),
        "bin_bytes": len(asset.bin_bytes),
        "buffer_gaps": gaps,
        "buffer_gap_bytes": sum(end - start for start, end in gaps),
    }


def _manifest_cells_and_rules(
        manifest: dict[str, Any]) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    safe = manifest.get("safe_current_partition")
    if not isinstance(safe, dict):
        raise RehearsalError(
            "manifest lacks safe_current_partition; target_partition and "
            "spatial/welded rules are never executable by this rehearsal")
    cells = safe.get("cells")
    rules = safe.get("ordered_node_rules")
    if not isinstance(cells, list) or not cells:
        raise RehearsalError("safe_current_partition.cells must be nonempty")
    if not isinstance(rules, list) or not rules:
        raise RehearsalError(
            "safe_current_partition.ordered_node_rules must be nonempty")
    return cells, rules


def assign_nodes(
        document: dict[str, Any], manifest: dict[str, Any]) -> dict[str, Any]:
    cells, rules = _manifest_cells_and_rules(manifest)
    cell_by_id: dict[str, dict[str, Any]] = {}
    slug_set: set[str] = set()
    for index, cell in enumerate(cells):
        if not isinstance(cell, dict):
            raise RehearsalError(f"safe-current cell {index} must be an object")
        cell_id = str(cell.get("id", ""))
        slug = str(cell.get("slug", ""))
        if not cell_id or cell_id in cell_by_id:
            raise RehearsalError(f"safe-current cell id is missing/duplicated: {cell_id}")
        if (not slug or slug in slug_set
                or any(char not in "abcdefghijklmnopqrstuvwxyz0123456789_-"
                       for char in slug)):
            raise RehearsalError(f"unsafe or duplicated cell slug: {slug!r}")
        cell_by_id[cell_id] = copy.deepcopy(cell)
        slug_set.add(slug)

    parsed_rules = []
    fallback_rules = []
    rule_ids: set[str] = set()
    for index, rule in enumerate(rules):
        if not isinstance(rule, dict):
            raise RehearsalError(f"safe-current rule {index} must be an object")
        forbidden = _deep_spatial_keys(rule)
        if forbidden:
            raise RehearsalError(
                f"safe-current rule {index} attempts spatial/primitive "
                f"classification: {sorted(forbidden)}")
        rule_id = str(rule.get("id", ""))
        cell_id = str(rule.get("cell", ""))
        match = rule.get("match")
        if not rule_id or rule_id in rule_ids:
            raise RehearsalError(f"safe-current rule id is missing/duplicated: {rule_id}")
        if cell_id not in cell_by_id:
            raise RehearsalError(f"rule {rule_id} names unknown cell {cell_id}")
        if not isinstance(match, dict) or len(match) != 1:
            raise RehearsalError(
                f"rule {rule_id} match must contain exactly one mode")
        mode, value = next(iter(match.items()))
        if mode not in ("prefix", "exact", "fallback"):
            raise RehearsalError(f"rule {rule_id} has unsupported match mode {mode}")
        if mode in ("prefix", "exact") and (not isinstance(value, str) or not value):
            raise RehearsalError(f"rule {rule_id} {mode} must be a nonempty string")
        if mode == "fallback" and value is not True:
            raise RehearsalError(f"rule {rule_id} fallback must be true")
        record = {
            "id": rule_id, "cell": cell_id, "mode": mode, "value": value,
            "order": index,
        }
        if mode == "fallback":
            fallback_rules.append(record)
        else:
            parsed_rules.append(record)
        rule_ids.add(rule_id)
    if len(fallback_rules) > 1:
        raise RehearsalError("safe-current partition may declare at most one fallback")

    assignments = []
    ambiguous = []
    unassigned = []
    by_cell: dict[str, list[int]] = {cell_id: [] for cell_id in cell_by_id}
    for node_index, node in enumerate(document.get("nodes", [])):
        name = str(node.get("name", ""))
        matched = []
        for rule in parsed_rules:
            if ((rule["mode"] == "prefix" and name.startswith(rule["value"]))
                    or (rule["mode"] == "exact" and name == rule["value"])):
                matched.append(rule)
        if len(matched) > 1:
            ambiguous.append({
                "node_index": node_index,
                "node": name,
                "rules": [rule["id"] for rule in matched],
            })
            continue
        if not matched and fallback_rules:
            matched = fallback_rules
        if not matched:
            unassigned.append({"node_index": node_index, "node": name})
            continue
        rule = matched[0]
        mesh_index = int(node["mesh"])
        primitive_count = len(document["meshes"][mesh_index]["primitives"])
        record = {
            "node_index": node_index,
            "node": name,
            "mesh_index": mesh_index,
            "primitive_indices": list(range(primitive_count)),
            "cell": rule["cell"],
            "rule": rule["id"],
        }
        assignments.append(record)
        by_cell[rule["cell"]].append(node_index)
    if ambiguous:
        labels = "; ".join(
            f"{row['node']} -> {','.join(row['rules'])}" for row in ambiguous)
        raise RehearsalError(f"ambiguous safe-current assignment: {labels}")
    if unassigned:
        raise RehearsalError(
            "unassigned safe-current nodes: "
            + ", ".join(row["node"] for row in unassigned))
    if len(assignments) != len(document.get("nodes", [])):
        raise RehearsalError("assignment cardinality does not equal source nodes")

    node_counts = Counter(row["node_index"] for row in assignments)
    mesh_counts = Counter(row["mesh_index"] for row in assignments)
    primitive_counts = Counter(
        (row["mesh_index"], primitive_index)
        for row in assignments
        for primitive_index in row["primitive_indices"]
    )
    expected_nodes = set(range(len(document.get("nodes", []))))
    expected_meshes = set(range(len(document.get("meshes", []))))
    expected_primitives = {
        (mesh_index, primitive_index)
        for mesh_index, mesh in enumerate(document.get("meshes", []))
        for primitive_index in range(len(mesh.get("primitives", [])))
    }
    duplicates = {
        "nodes": sorted(index for index, count in node_counts.items() if count != 1),
        "meshes": sorted(index for index, count in mesh_counts.items() if count != 1),
        "primitives": sorted([list(key) for key, count in primitive_counts.items()
                              if count != 1]),
    }
    if (set(node_counts) != expected_nodes
            or set(mesh_counts) != expected_meshes
            or set(primitive_counts) != expected_primitives
            or any(duplicates.values())):
        raise RehearsalError(
            "node/mesh/primitive ownership is not exactly once: "
            + json.dumps(duplicates, sort_keys=True))

    safe = manifest["safe_current_partition"]
    invariants = safe.get("invariants", {})
    if invariants is not None and not isinstance(invariants, dict):
        raise RehearsalError("safe_current_partition.invariants must be an object")
    expected_total = (invariants or {}).get("expected_total_nodes")
    if expected_total is not None and int(expected_total) != len(assignments):
        raise RehearsalError(
            f"safe-current expected_total_nodes={expected_total} but assigned "
            f"{len(assignments)}")
    for cell_id, cell in cell_by_id.items():
        expected = cell.get("expected_nodes")
        if expected is not None and int(expected) != len(by_cell[cell_id]):
            raise RehearsalError(
                f"safe-current cell {cell_id} expected_nodes={expected} but "
                f"assigned {len(by_cell[cell_id])}")

    welded = [row for row in assignments
              if str(row["node"]).startswith(WELDED_PREFIXES)]
    welded_cells = sorted({str(row["cell"]) for row in welded})
    if welded and (len(welded_cells) != 1
                   or "LEGACY_MIXED" not in welded_cells[0].upper()):
        raise RehearsalError(
            "unsafe F01_furnish_/F01_furniture_ primitives must remain whole "
            "in one explicitly named LEGACY_MIXED safe-current cell")

    legacy_cell = welded_cells[0] if welded_cells else None
    legacy_assignments = [row for row in assignments
                          if row["cell"] == legacy_cell]
    return {
        "cells": list(cell_by_id.values()),
        "rules": parsed_rules + fallback_rules,
        "assignments": assignments,
        "by_cell": by_cell,
        "ambiguous": [],
        "unassigned": [],
        "duplicate_assignments": [],
        "ownership_totals": {
            "source_nodes": len(expected_nodes),
            "assigned_nodes": len(node_counts),
            "source_meshes": len(expected_meshes),
            "assigned_meshes": len(mesh_counts),
            "source_primitives": len(expected_primitives),
            "assigned_primitives": len(primitive_counts),
            "all_exactly_once": True,
        },
        "legacy_mixed": {
            "required": bool(welded),
            "cell": legacy_cell,
            "node_count": len(legacy_assignments),
            "node_names": [row["node"] for row in legacy_assignments],
            "welded_prefix_node_count": len(welded),
            "welded_prefix_node_names": [row["node"] for row in welded],
            "reason": "whole-node rehearsal refuses spatial primitive splitting",
        },
    }


class Canonicalizer:
    def __init__(self, asset: AssetView):
        self.asset = asset
        self.doc = asset.document
        self._view: dict[int, str] = {}
        self._accessor: dict[int, str] = {}
        self._image: dict[int, str] = {}
        self._sampler: dict[int, str] = {}
        self._texture: dict[int, str] = {}
        self._material: dict[int, str] = {}
        self._primitive: dict[tuple[int, int], str] = {}

    def view(self, index: int) -> str:
        if index not in self._view:
            source = copy.deepcopy(self.doc["bufferViews"][index])
            source.pop("buffer", None)
            source.pop("byteOffset", None)
            source["payload_sha256"] = _sha256_bytes(self.asset.view_bytes(index))
            self._view[index] = _canonical_hash(source)
        return self._view[index]

    def accessor(self, index: int) -> str:
        if index not in self._accessor:
            value = copy.deepcopy(self.doc["accessors"][index])
            value["bufferView"] = self.view(int(value["bufferView"]))
            if value.get("sparse"):
                for part in ("indices", "values"):
                    old = int(value["sparse"][part]["bufferView"])
                    value["sparse"][part]["bufferView"] = self.view(old)
            self._accessor[index] = _canonical_hash(value)
        return self._accessor[index]

    def image(self, index: int) -> str:
        if index not in self._image:
            value = copy.deepcopy(self.doc["images"][index])
            value.pop("uri", None)
            value.pop("bufferView", None)
            value["payload_sha256"] = _sha256_bytes(self.asset.image_bytes(index))
            self._image[index] = _canonical_hash(value)
        return self._image[index]

    def sampler(self, index: int) -> str:
        if index not in self._sampler:
            self._sampler[index] = _canonical_hash(self.doc["samplers"][index])
        return self._sampler[index]

    def texture(self, index: int) -> str:
        if index not in self._texture:
            value = copy.deepcopy(self.doc["textures"][index])

            def replace_sources(child: Any) -> Any:
                if isinstance(child, dict):
                    return {
                        key: (self.image(int(item)) if key == "source"
                              else replace_sources(item))
                        for key, item in child.items()
                    }
                if isinstance(child, list):
                    return [replace_sources(item) for item in child]
                return copy.deepcopy(child)

            value = replace_sources(value)
            if "sampler" in value:
                value["sampler"] = self.sampler(int(value["sampler"]))
            self._texture[index] = _canonical_hash(value)
        return self._texture[index]

    def material(self, index: int) -> str:
        if index not in self._material:
            value = copy.deepcopy(self.doc["materials"][index])

            def replace(child: Any, path: tuple[str, ...] = ()) -> Any:
                if isinstance(child, dict):
                    result = {}
                    for key, item in child.items():
                        if (key == "index" and path
                                and path[-1].lower().endswith("texture")):
                            result[key] = self.texture(int(item))
                        else:
                            result[key] = replace(item, path + (str(key),))
                    return result
                if isinstance(child, list):
                    return [replace(item, path) for item in child]
                return copy.deepcopy(child)

            self._material[index] = _canonical_hash(replace(value))
        return self._material[index]

    def primitive(self, mesh_index: int, primitive_index: int) -> str:
        key = (mesh_index, primitive_index)
        if key not in self._primitive:
            value = copy.deepcopy(
                self.doc["meshes"][mesh_index]["primitives"][primitive_index])
            value["attributes"] = {
                semantic: self.accessor(int(accessor))
                for semantic, accessor in sorted(value.get("attributes", {}).items())
            }
            if "indices" in value:
                value["indices"] = self.accessor(int(value["indices"]))
            if "material" in value:
                value["material"] = self.material(int(value["material"]))
            if "targets" in value:
                value["targets"] = [{
                    semantic: self.accessor(int(accessor))
                    for semantic, accessor in sorted(target.items())
                } for target in value["targets"]]
            self._primitive[key] = _canonical_hash(value)
        return self._primitive[key]


def _matrix_multiply(left: list[float], right: list[float]) -> list[float]:
    # glTF matrices are column-major.
    out = [0.0] * 16
    for column in range(4):
        for row in range(4):
            out[column * 4 + row] = sum(
                left[k * 4 + row] * right[column * 4 + k]
                for k in range(4))
    return out


def _node_matrix(node: dict[str, Any]) -> list[float]:
    if "matrix" in node:
        matrix = [float(value) for value in node["matrix"]]
        if len(matrix) != 16:
            raise RehearsalError("node matrix must contain 16 values")
        return matrix
    tx, ty, tz = map(float, node.get("translation", [0.0, 0.0, 0.0]))
    sx, sy, sz = map(float, node.get("scale", [1.0, 1.0, 1.0]))
    x, y, z, w = map(float, node.get("rotation", [0.0, 0.0, 0.0, 1.0]))
    norm = math.sqrt(x * x + y * y + z * z + w * w)
    if norm <= 0.0:
        raise RehearsalError("node rotation quaternion has zero length")
    x, y, z, w = x / norm, y / norm, z / norm, w / norm
    rotation = [
        1 - 2 * y * y - 2 * z * z,
        2 * x * y + 2 * w * z,
        2 * x * z - 2 * w * y,
        0.0,
        2 * x * y - 2 * w * z,
        1 - 2 * x * x - 2 * z * z,
        2 * y * z + 2 * w * x,
        0.0,
        2 * x * z + 2 * w * y,
        2 * y * z - 2 * w * x,
        1 - 2 * x * x - 2 * y * y,
        0.0,
        0.0, 0.0, 0.0, 1.0,
    ]
    scale = [
        sx, 0.0, 0.0, 0.0,
        0.0, sy, 0.0, 0.0,
        0.0, 0.0, sz, 0.0,
        0.0, 0.0, 0.0, 1.0,
    ]
    transform = _matrix_multiply(rotation, scale)
    transform[12], transform[13], transform[14] = tx, ty, tz
    return transform


def _transform_point(matrix: list[float], point: tuple[float, float, float]) -> list[float]:
    x, y, z = point
    return [
        matrix[0] * x + matrix[4] * y + matrix[8] * z + matrix[12],
        matrix[1] * x + matrix[5] * y + matrix[9] * z + matrix[13],
        matrix[2] * x + matrix[6] * y + matrix[10] * z + matrix[14],
    ]


def node_world_bounds(asset: AssetView, node_index: int) -> list[list[float]]:
    doc = asset.document
    node = doc["nodes"][node_index]
    matrix = _node_matrix(node)
    points = []
    for primitive in doc["meshes"][int(node["mesh"])]["primitives"]:
        position_index = primitive.get("attributes", {}).get("POSITION")
        if position_index is None:
            raise RehearsalError("primitive has no POSITION accessor")
        accessor = doc["accessors"][int(position_index)]
        minimum = accessor.get("min")
        maximum = accessor.get("max")
        if (not isinstance(minimum, list) or not isinstance(maximum, list)
                or len(minimum) != 3 or len(maximum) != 3):
            raise RehearsalError("POSITION accessor lacks exact three-axis bounds")
        for x in (float(minimum[0]), float(maximum[0])):
            for y in (float(minimum[1]), float(maximum[1])):
                for z in (float(minimum[2]), float(maximum[2])):
                    points.append(_transform_point(matrix, (x, y, z)))
    return [
        [min(point[axis] for point in points) for axis in range(3)],
        [max(point[axis] for point in points) for axis in range(3)],
    ]


@dataclass
class GeneratedCell:
    cell_id: str
    slug: str
    document: dict[str, Any]
    bin_bytes: bytes
    node_map: dict[int, int]
    mesh_map: dict[int, int]
    accessor_map: dict[int, int]
    material_map: dict[int, int]
    image_source_bytes: dict[str, bytes]

    @property
    def gltf_bytes(self) -> bytes:
        return _json_bytes(self.document)

    def as_asset(self, output_root: Path) -> AssetView:
        return AssetView(
            output_root / "cells" / f"{self.slug}.gltf",
            self.document,
            self.bin_bytes,
            self.image_source_bytes,
        )


def _collect_cell_dependencies(
        doc: dict[str, Any], node_indices: list[int]) -> dict[str, set[int]]:
    meshes = {int(doc["nodes"][index]["mesh"]) for index in node_indices}
    accessors: set[int] = set()
    materials: set[int] = set()
    for mesh_index in meshes:
        for primitive in doc["meshes"][mesh_index]["primitives"]:
            accessors.update(_accessors_in_primitive(primitive))
            if "material" in primitive:
                materials.add(int(primitive["material"]))
    textures: set[int] = set()
    for material_index in materials:
        textures.update(_texture_refs(doc["materials"][material_index]))
    images: set[int] = set()
    samplers: set[int] = set()
    for texture_index in textures:
        texture = doc["textures"][texture_index]
        images.update(_image_refs_in_texture(texture))
        if "sampler" in texture:
            samplers.add(int(texture["sampler"]))
    views: set[int] = set()
    for accessor_index in accessors:
        accessor = doc["accessors"][accessor_index]
        views.add(int(accessor["bufferView"]))
        if accessor.get("sparse"):
            for part in ("indices", "values"):
                views.add(int(accessor["sparse"][part]["bufferView"]))
    for image_index in images:
        if "bufferView" in doc["images"][image_index]:
            views.add(int(doc["images"][image_index]["bufferView"]))
    return {
        "meshes": meshes,
        "accessors": accessors,
        "materials": materials,
        "textures": textures,
        "images": images,
        "samplers": samplers,
        "bufferViews": views,
    }


def build_cells(
        asset: AssetView, assignment: dict[str, Any],
        output_root: Path) -> list[GeneratedCell]:
    doc = asset.document
    cells = []
    by_id = {str(cell["id"]): cell for cell in assignment["cells"]}
    for cell_id in [str(cell["id"]) for cell in assignment["cells"]]:
        node_indices = assignment["by_cell"][cell_id]
        if not node_indices:
            raise RehearsalError(f"safe-current cell {cell_id} owns zero nodes")
        cell = by_id[cell_id]
        slug = str(cell["slug"])
        deps = _collect_cell_dependencies(doc, node_indices)
        node_order = sorted(node_indices)
        mesh_order = sorted(deps["meshes"])
        accessor_order = sorted(deps["accessors"])
        material_order = sorted(deps["materials"])
        texture_order = sorted(deps["textures"])
        image_order = sorted(deps["images"])
        sampler_order = sorted(deps["samplers"])
        view_order = sorted(deps["bufferViews"])
        node_map = {old: new for new, old in enumerate(node_order)}
        mesh_map = {old: new for new, old in enumerate(mesh_order)}
        accessor_map = {old: new for new, old in enumerate(accessor_order)}
        material_map = {old: new for new, old in enumerate(material_order)}
        texture_map = {old: new for new, old in enumerate(texture_order)}
        image_map = {old: new for new, old in enumerate(image_order)}
        sampler_map = {old: new for new, old in enumerate(sampler_order)}
        view_map = {old: new for new, old in enumerate(view_order)}

        packed = bytearray()
        new_views = []
        for old_index in view_order:
            while len(packed) % 4:
                packed.append(0)
            value = copy.deepcopy(doc["bufferViews"][old_index])
            value["buffer"] = 0
            value["byteOffset"] = len(packed)
            raw = asset.view_bytes(old_index)
            value["byteLength"] = len(raw)
            new_views.append(value)
            packed.extend(raw)
        while len(packed) % 4:
            packed.append(0)

        new_accessors = []
        for old_index in accessor_order:
            value = copy.deepcopy(doc["accessors"][old_index])
            value["bufferView"] = view_map[int(value["bufferView"])]
            if value.get("sparse"):
                for part in ("indices", "values"):
                    old_view = int(value["sparse"][part]["bufferView"])
                    value["sparse"][part]["bufferView"] = view_map[old_view]
            new_accessors.append(value)

        new_materials = [
            _remap_texture_refs(doc["materials"][old], texture_map)
            for old in material_order
        ]
        new_textures = []
        for old_index in texture_order:
            value = _remap_image_refs_in_texture(
                doc["textures"][old_index], image_map)
            if "sampler" in value:
                value["sampler"] = sampler_map[int(value["sampler"])]
            new_textures.append(value)

        output_image_bytes: dict[str, bytes] = {}
        new_images = []
        for old_index in image_order:
            value = copy.deepcopy(doc["images"][old_index])
            if "bufferView" in value:
                value["bufferView"] = view_map[int(value["bufferView"])]
            elif "uri" in value and not str(value["uri"]).startswith("data:"):
                old_uri = str(value["uri"])
                safe = _safe_relative_uri(old_uri, f"image {old_index} URI")
                new_uri = PurePosixPath("..", "shared_textures", *safe.parts).as_posix()
                value["uri"] = new_uri
                output_image_bytes[new_uri] = asset.external_images[old_uri]
            new_images.append(value)

        new_meshes = []
        for old_index in mesh_order:
            value = copy.deepcopy(doc["meshes"][old_index])
            for primitive in value["primitives"]:
                primitive["attributes"] = {
                    semantic: accessor_map[int(accessor)]
                    for semantic, accessor in primitive["attributes"].items()
                }
                if "indices" in primitive:
                    primitive["indices"] = accessor_map[int(primitive["indices"])]
                if "material" in primitive:
                    primitive["material"] = material_map[int(primitive["material"])]
                if "targets" in primitive:
                    primitive["targets"] = [{
                        semantic: accessor_map[int(accessor)]
                        for semantic, accessor in target.items()
                    } for target in primitive["targets"]]
            new_meshes.append(value)

        new_nodes = []
        for old_index in node_order:
            value = copy.deepcopy(doc["nodes"][old_index])
            value["mesh"] = mesh_map[int(value["mesh"])]
            new_nodes.append(value)

        cell_doc = {
            key: copy.deepcopy(value)
            for key, value in doc.items()
            if key not in INDEXED_ARRAYS and key != "scene"
        }
        cell_doc["asset"] = copy.deepcopy(doc.get("asset", {"version": "2.0"}))
        extras = cell_doc["asset"].setdefault("extras", {})
        extras["orison_bin_sha256"] = _sha256_bytes(bytes(packed))
        extras["m11c0_rehearsal"] = {
            "cell": cell_id,
            "whole_node_only": True,
            "production_asset": False,
        }
        cell_doc.update({
            "scene": 0,
            "scenes": [{"name": f"Scene_{slug}",
                        "nodes": list(range(len(new_nodes)))}],
            "nodes": new_nodes,
            "meshes": new_meshes,
            "accessors": new_accessors,
            "bufferViews": new_views,
            "buffers": [{
                "byteLength": len(packed),
                "uri": f"{slug}.bin",
            }],
            "materials": new_materials,
            "textures": new_textures,
            "images": new_images,
            "samplers": [copy.deepcopy(doc["samplers"][old])
                         for old in sampler_order],
        })
        cells.append(GeneratedCell(
            cell_id, slug, cell_doc, bytes(packed), node_map, mesh_map,
            accessor_map, material_map, output_image_bytes,
        ))
    return cells


def verify_recomposition(
        source: AssetView, generated: list[GeneratedCell],
        output_root: Path) -> dict[str, Any]:
    source_canonical = Canonicalizer(source)
    primitive_copies = []
    accessor_copies = []
    material_copies = []
    node_copies = []
    source_primitive_hashes = []
    output_primitive_hashes = []
    source_node_names = []
    output_node_names = []
    for cell in generated:
        output = cell.as_asset(output_root)
        validate_source(output)
        canonical = Canonicalizer(output)
        for old_node, new_node in sorted(cell.node_map.items()):
            old_value = source.document["nodes"][old_node]
            new_value = output.document["nodes"][new_node]
            old_transform = {key: old_value[key] for key in TRANSFORM_KEYS
                             if key in old_value}
            new_transform = {key: new_value[key] for key in TRANSFORM_KEYS
                             if key in new_value}
            old_bounds = node_world_bounds(source, old_node)
            new_bounds = node_world_bounds(output, new_node)
            match = (old_transform == new_transform and old_bounds == new_bounds
                     and str(old_value.get("name", ""))
                     == str(new_value.get("name", "")))
            node_copies.append({
                "cell": cell.cell_id,
                "source_node": old_node,
                "output_node": new_node,
                "name": str(old_value.get("name", "")),
                "transform_sha256": _canonical_hash(old_transform),
                "world_bounds": old_bounds,
                "match": match,
            })
            source_node_names.append(str(old_value.get("name", "")))
            output_node_names.append(str(new_value.get("name", "")))
        for old_mesh, new_mesh in sorted(cell.mesh_map.items()):
            old_primitives = source.document["meshes"][old_mesh]["primitives"]
            new_primitives = output.document["meshes"][new_mesh]["primitives"]
            if len(old_primitives) != len(new_primitives):
                raise RehearsalError("primitive count changed during compaction")
            for primitive_index in range(len(old_primitives)):
                before = source_canonical.primitive(old_mesh, primitive_index)
                after = canonical.primitive(new_mesh, primitive_index)
                source_primitive_hashes.append(before)
                output_primitive_hashes.append(after)
                primitive_copies.append({
                    "cell": cell.cell_id,
                    "source_mesh": old_mesh,
                    "source_primitive": primitive_index,
                    "output_mesh": new_mesh,
                    "output_primitive": primitive_index,
                    "canonical_sha256": before,
                    "match": before == after,
                })
        for old_accessor, new_accessor in sorted(cell.accessor_map.items()):
            before = source_canonical.accessor(old_accessor)
            after = canonical.accessor(new_accessor)
            accessor_copies.append({
                "cell": cell.cell_id,
                "source_accessor": old_accessor,
                "output_accessor": new_accessor,
                "canonical_sha256": before,
                "match": before == after,
            })
        for old_material, new_material in sorted(cell.material_map.items()):
            before = source_canonical.material(old_material)
            after = canonical.material(new_material)
            material_copies.append({
                "cell": cell.cell_id,
                "source_material": old_material,
                "output_material": new_material,
                "canonical_sha256": before,
                "match": before == after,
            })

    failures = []
    for label, rows in (("primitive", primitive_copies),
                        ("accessor", accessor_copies),
                        ("material", material_copies),
                        ("node", node_copies)):
        mismatches = [row for row in rows if not row["match"]]
        if mismatches:
            failures.append(f"{len(mismatches)} canonical {label} copies differ")
    if Counter(source_primitive_hashes) != Counter(output_primitive_hashes):
        failures.append("recomposed primitive multiset differs from source")
    if Counter(source_node_names) != Counter(output_node_names):
        failures.append("recomposed node-name multiset differs from source")
    if len(source_node_names) != len(source.document["nodes"]):
        failures.append("recomposition does not contain every source node once")
    if failures:
        raise RehearsalError("; ".join(failures))

    accessor_source_counts = Counter(
        row["source_accessor"] for row in accessor_copies)
    material_source_counts = Counter(
        row["source_material"] for row in material_copies)
    return {
        "schema": "orison.m11c0.floor01-recomposition.v1",
        "status": "PASS",
        "whole_node_only": True,
        "spatial_primitive_splitting": False,
        "source_node_count": len(source.document["nodes"]),
        "recomposed_node_count": len(source_node_names),
        "source_primitive_count": len(source_primitive_hashes),
        "recomposed_primitive_count": len(output_primitive_hashes),
        "primitive_multiset_sha256": _canonical_hash(
            sorted(source_primitive_hashes)),
        "node_name_multiset_sha256": _canonical_hash(sorted(source_node_names)),
        "canonical_copies": {
            "primitives": primitive_copies,
            "accessors": accessor_copies,
            "materials": material_copies,
            "nodes_and_world_bounds": node_copies,
        },
        "dependency_duplication": {
            "source_accessors": len(source.document.get("accessors", [])),
            "cell_accessor_copies": len(accessor_copies),
            "cross_cell_accessor_copies": sum(
                count - 1 for count in accessor_source_counts.values()),
            "source_materials": len(source.document.get("materials", [])),
            "cell_material_copies": len(material_copies),
            "cross_cell_material_copies": sum(
                count - 1 for count in material_source_counts.values()),
        },
        "failures": [],
    }


def _copy_shared_textures(asset: AssetView, output_root: Path) -> dict[str, Any]:
    files = []
    seen: dict[str, str] = {}
    for uri, data in sorted(asset.external_images.items()):
        safe = _safe_relative_uri(uri, "image URI")
        relative = PurePosixPath(*safe.parts)
        destination = output_root / "shared_textures"
        for part in relative.parts:
            destination = destination / part
        digest = _sha256_bytes(data)
        key = relative.as_posix().lower()
        if key in seen and seen[key] != digest:
            raise RehearsalError(
                f"shared texture destination collision: {relative.as_posix()}")
        seen[key] = digest
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(data)
        if _sha256_file(destination) != digest:
            raise RehearsalError(f"shared texture copy hash mismatch: {destination}")
        files.append({
            "source_uri": uri,
            "output": (PurePosixPath("shared_textures") / relative).as_posix(),
            "bytes": len(data),
            "sha256": digest,
        })
    return {
        "files": files,
        "file_count": len(files),
        "bytes": sum(row["bytes"] for row in files),
    }


def _materialize_harness(
        asset: AssetView, manifest: dict[str, Any], manifest_path: Path,
        output_root: Path, cells: list[GeneratedCell],
        protected_hashes: dict[str, str]) -> dict[str, Any]:
    """Copy only inert harness sources and emit its root-relative contract."""
    template_root = REPO_ROOT / "tools" / "m11c0_floor01_rehearsal" / "templates"
    template_files = []
    for name in HARNESS_TEMPLATE_FILES:
        source = template_root / name
        if not source.is_file():
            raise RehearsalError(f"required M11C0 harness template is absent: {source}")
        destination = output_root / name
        destination.write_bytes(source.read_bytes())
        template_files.append({
            "path": name,
            "bytes": destination.stat().st_size,
            "sha256": _sha256_file(destination),
        })

    original_root = output_root / "original"
    original_root.mkdir(parents=True, exist_ok=True)
    original_gltf = original_root / asset.path.name
    original_gltf.write_bytes(asset.path.read_bytes())
    buffer_uri = _safe_relative_uri(
        str(asset.document["buffers"][0]["uri"]), "buffer URI")
    original_bin = original_root.joinpath(*buffer_uri.parts)
    original_bin.parent.mkdir(parents=True, exist_ok=True)
    original_bin.write_bytes(asset.bin_bytes)
    original_images = []
    for uri, data in sorted(asset.external_images.items()):
        relative = _safe_relative_uri(uri, "image URI")
        destination = original_root.joinpath(*relative.parts)
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(data)
        original_images.append({
            "uri": uri,
            "path": PurePosixPath("original", *relative.parts).as_posix(),
            "bytes": len(data),
            "sha256": _sha256_bytes(data),
        })
    if (_sha256_file(original_gltf) != protected_hashes["gltf"]
            or _sha256_file(original_bin) != protected_hashes["bin"]):
        raise RehearsalError("disposable original control copy is not byte exact")

    (output_root / "partition_manifest.json").write_bytes(
        _json_bytes(manifest))
    passthrough = {}
    for key in ("collision_probes", "capture_views"):
        value = manifest.get(key, [])
        if not isinstance(value, list):
            raise RehearsalError(f"manifest {key} must be an array when present")
        passthrough[key] = copy.deepcopy(value)
    split_receipt = {
        "schema": "orison.m11c0.floor01-split-input.v1",
        "status": "PASS",
        "authority": "disposable safe_current_partition rehearsal",
        "production_asset": False,
        "whole_node_only": True,
        "spatial_primitive_splitting": False,
        "manifest_path": "res://partition_manifest.json",
        "input_manifest_sha256": _sha256_file(manifest_path),
        "source": {
            "gltf_path": f"res://original/{asset.path.name}",
            "bin_path": "res://" + PurePosixPath(
                "original", *buffer_uri.parts).as_posix(),
            "gltf_sha256": protected_hashes["gltf"],
            "bin_sha256": protected_hashes["bin"],
            "external_images": original_images,
        },
        "cells": [{
            "id": cell.cell_id,
            "slug": cell.slug,
            "gltf_path": f"res://cells/{cell.slug}.gltf",
            "bin_path": f"res://cells/{cell.slug}.bin",
        } for cell in cells],
        "collision_probes": passthrough["collision_probes"],
        "capture_views": passthrough["capture_views"],
        "harness_templates": template_files,
    }
    _write_json(output_root / "split_receipt.json", split_receipt)
    return {
        "split_receipt": "split_receipt.json",
        "partition_manifest": "partition_manifest.json",
        "template_files": len(template_files),
        "original_external_images": len(original_images),
        "source_gltf_path": split_receipt["source"]["gltf_path"],
        "cells": len(split_receipt["cells"]),
    }


def _validate_manifest_source(
        manifest: dict[str, Any], gltf_path: Path, bin_path: Path) -> None:
    source = manifest.get("source", {})
    if not isinstance(source, dict):
        return
    expected_gltf = str(source.get("gltf_sha256", ""))
    expected_bin = str(source.get("bin_sha256", ""))
    if expected_gltf and _sha256_file(gltf_path) != expected_gltf:
        raise RehearsalError("protected source glTF hash disagrees with manifest")
    if expected_bin and _sha256_file(bin_path) != expected_bin:
        raise RehearsalError("protected source BIN hash disagrees with manifest")


def _resolve_source(
        manifest: dict[str, Any], explicit: Path | None) -> Path:
    if explicit is not None:
        return explicit.resolve()
    source = manifest.get("source", {})
    if not isinstance(source, dict) or not source.get("gltf"):
        raise RehearsalError("manifest source.gltf is absent; pass --source-gltf")
    value = Path(str(source["gltf"]))
    return (value if value.is_absolute() else REPO_ROOT / value).resolve()


def _prepare_output(output_root: Path) -> None:
    output_root = output_root.resolve()
    if output_root.exists() and any(output_root.iterdir()):
        raise RehearsalError(
            f"output is not empty; refusing to overwrite rehearsal: {output_root}")
    output_root.mkdir(parents=True, exist_ok=True)


def _assert_output_is_disposable(output_root: Path, source: Path) -> None:
    output = output_root.resolve()
    source = source.resolve()
    if output == source.parent or source.is_relative_to(output):
        raise RehearsalError("output may not contain protected source assets")
    if output.is_relative_to(source.parent):
        raise RehearsalError("output may not be inside the protected asset directory")


def run_rehearsal(
        manifest_path: Path, output_root: Path,
        source_gltf: Path | None = None, analyze_only: bool = False,
        prepare_output: bool = True) -> dict[str, Any]:
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise RehearsalError(f"could not read manifest: {error}") from error
    if not isinstance(manifest, dict):
        raise RehearsalError("partition manifest root must be an object")
    gltf_path = _resolve_source(manifest, source_gltf)
    _assert_output_is_disposable(output_root, gltf_path)
    if prepare_output:
        _prepare_output(output_root)
    asset = load_asset(gltf_path)
    buffer_uri = _safe_relative_uri(
        str(asset.document["buffers"][0]["uri"]), "buffer URI")
    bin_path = gltf_path.parent.joinpath(*buffer_uri.parts).resolve()
    protected_before = {
        "gltf": _sha256_file(gltf_path),
        "bin": _sha256_file(bin_path),
    }
    _validate_manifest_source(manifest, gltf_path, bin_path)
    census_counts = validate_source(asset)
    assignment = assign_nodes(asset.document, manifest)
    generated = build_cells(asset, assignment, output_root)
    recomposition = verify_recomposition(asset, generated, output_root)

    texture_measurement = {
        "file_count": len(asset.external_images),
        "bytes": sum(len(data) for data in asset.external_images.values()),
        "copied": False,
    }
    harness_measurement = {
        "materialized": False,
        "split_receipt": None,
        "template_files": 0,
        "cells": 0,
    }
    if not analyze_only:
        cells_dir = output_root / "cells"
        cells_dir.mkdir(parents=True, exist_ok=True)
        for cell in generated:
            (cells_dir / f"{cell.slug}.gltf").write_bytes(cell.gltf_bytes)
            (cells_dir / f"{cell.slug}.bin").write_bytes(cell.bin_bytes)
        texture_measurement = _copy_shared_textures(asset, output_root)
        texture_measurement["copied"] = True
        harness_measurement = _materialize_harness(
            asset, manifest, manifest_path, output_root, generated,
            protected_before)
        harness_measurement["materialized"] = True

    cell_measurements = []
    for cell in generated:
        doc = cell.document
        bounds = [node_world_bounds(cell.as_asset(output_root), index)
                  for index in range(len(doc["nodes"]))]
        cell_measurements.append({
            "id": cell.cell_id,
            "slug": cell.slug,
            "nodes": len(doc["nodes"]),
            "meshes": len(doc["meshes"]),
            "primitives": sum(len(mesh["primitives"])
                              for mesh in doc["meshes"]),
            "accessors": len(doc["accessors"]),
            "buffer_views": len(doc["bufferViews"]),
            "materials": len(doc["materials"]),
            "textures": len(doc["textures"]),
            "images": len(doc["images"]),
            "collision_tagged_nodes": sum(
                str(node.get("name", "")).endswith(("-col", "-colonly"))
                for node in doc["nodes"]),
            "gltf_bytes": len(cell.gltf_bytes),
            "bin_bytes": len(cell.bin_bytes),
            "bounds_union": [
                [min(bound[0][axis] for bound in bounds) for axis in range(3)],
                [max(bound[1][axis] for bound in bounds) for axis in range(3)],
            ],
        })

    protected_after = {
        "gltf": _sha256_file(gltf_path),
        "bin": _sha256_file(bin_path),
    }
    if protected_after != protected_before:
        raise RehearsalError("protected source changed during rehearsal")

    census = {
        "schema": "orison.m11c0.floor01-census.v1",
        "status": "PASS",
        "source": {
            "gltf": str(gltf_path),
            "bin": str(bin_path),
            "gltf_bytes": gltf_path.stat().st_size,
            "bin_bytes": bin_path.stat().st_size,
            "hashes_before": protected_before,
            "hashes_after": protected_after,
            "protected_unchanged": True,
        },
        "counts": census_counts,
    }
    assignment_receipt = {
        "schema": "orison.m11c0.floor01-assignment.v1",
        "status": "PASS",
        "authority": "safe_current_partition only",
        "target_partition_consumed": False,
        "whole_node_only": True,
        "spatial_primitive_splitting": False,
        "cells": [{
            "id": cell["id"],
            "slug": cell["slug"],
            "node_count": len(assignment["by_cell"][cell["id"]]),
            "node_indices": assignment["by_cell"][cell["id"]],
        } for cell in assignment["cells"]],
        "rules": assignment["rules"],
        "assignments": assignment["assignments"],
        "ambiguous": [],
        "unassigned": [],
        "duplicate_assignments": [],
        "ownership_totals": assignment["ownership_totals"],
        "legacy_mixed": assignment["legacy_mixed"],
    }
    measurements = {
        "schema": "orison.m11c0.floor01-measurements.v1",
        "status": "PASS",
        "context": {
            "root": "disposable whole-node glTF cells",
            "quality_profile": "static descriptor/BIN measurement",
            "cell_set": "safe_current_partition",
            "simulation_state": "not instantiated; runtime receipt is separate",
            "analyze_only": analyze_only,
        },
        "source": {
            "gltf_bytes": gltf_path.stat().st_size,
            "bin_bytes": len(asset.bin_bytes),
            "descriptor_plus_bin_bytes": gltf_path.stat().st_size
                + len(asset.bin_bytes),
        },
        "cells": cell_measurements,
        "recomposed": {
            "gltf_bytes": sum(row["gltf_bytes"] for row in cell_measurements),
            "bin_bytes": sum(row["bin_bytes"] for row in cell_measurements),
            "accessor_dependency_duplication": recomposition[
                "dependency_duplication"],
        },
        "shared_texture_library": texture_measurement,
        "disposable_harness": harness_measurement,
    }
    summary = {
        "schema": "orison.m11c0.floor01-rehearsal-summary.v1",
        "status": "PASS",
        "analyze_only": analyze_only,
        "production_assets_written": False,
        "safe_current_cells": len(generated),
        "source_nodes": census_counts["nodes"],
        "assigned_nodes": len(assignment["assignments"]),
        "source_primitives": census_counts["primitives"],
        "recomposed_primitives": recomposition["recomposed_primitive_count"],
        "legacy_mixed": assignment["legacy_mixed"],
        "protected_hashes": {
            "before": protected_before,
            "after": protected_after,
            "unchanged": True,
        },
        "disposable_harness": harness_measurement,
        "receipts": {
            "census": "receipts/floor01_census.json",
            "assignment": "receipts/floor01_assignment.json",
            "measurements": "receipts/floor01_measurements.json",
            "recomposition": "receipts/floor01_recomposition.json",
        },
        "limitation": (
            "LEGACY_MIXED remains a lineage-unresolved whole-node payload "
            "including welded subsets; this rehearsal does not prove the "
            "target source-owned production cut."),
    }
    receipts = output_root / "receipts"
    _write_json(receipts / "floor01_census.json", census)
    _write_json(receipts / "floor01_assignment.json", assignment_receipt)
    _write_json(receipts / "floor01_measurements.json", measurements)
    _write_json(receipts / "floor01_recomposition.json", recomposition)
    _write_json(receipts / "floor01_rehearsal_summary.json", summary)
    return summary


def _parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--source-gltf", type=Path)
    parser.add_argument(
        "--analyze-only", action="store_true",
        help="write receipts but do not materialize cell or texture files")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv)
    try:
        summary = run_rehearsal(
            args.manifest.resolve(), args.output.resolve(),
            args.source_gltf.resolve() if args.source_gltf else None,
            args.analyze_only,
        )
    except RehearsalError as error:
        print(f"[M11C0 FLOOR01 REHEARSAL] FAIL: {error}", file=sys.stderr)
        return 2
    print("[M11C0 FLOOR01 REHEARSAL] PASS "
          f"cells={summary['safe_current_cells']} "
          f"nodes={summary['assigned_nodes']}/{summary['source_nodes']} "
          f"legacy_mixed={summary['legacy_mixed']['node_count']} "
          f"analyze_only={str(summary['analyze_only']).lower()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
