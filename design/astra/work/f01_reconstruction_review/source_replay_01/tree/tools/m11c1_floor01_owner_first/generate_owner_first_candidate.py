#!/usr/bin/env python3
"""Blender-side disposable F01 generator with generation-time provenance.

Run only through Blender.  The script loads the authoritative generator's
definitions but suppresses its unconditional production ``build()`` entry,
then replays the F01 authoring loops with an explicit source scope around
every emission.  Geometry helpers, material construction, UV projection, and
Blender export remain authoritative; only buffer identity changes from
``(floor, category)`` to ``(owner_cell, material, category)``.

All descriptor, BIN, texture staging, and lineage writes stay below the
explicit disposable output root.
"""

from __future__ import annotations

import argparse
from collections import Counter
from contextlib import contextmanager
import copy
import hashlib
import json
import os
from pathlib import Path
import shutil
import sys
import traceback
from typing import Any, Callable

import bpy


REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tools.m11c1_floor01_owner_first.owner_first_export import (  # noqa: E402
    CELL_IDS,
    COLLISION_NONE,
    EXPECTED_SUPPLEMENTAL_GENERATED_SOURCES,
    FACADE,
    INTERIOR,
    OwnerFirstError,
    SCHEMA_CANDIDATE_LINEAGE,
    bind_candidate_triangle_slices,
    bytes_hash,
    canonical_hash,
    collision_class_for_name,
    write_json,
)
from tools.m11c1_floor01_owner_first.source_ownership import (  # noqa: E402
    load_source_ownership,
)


EXPECTED_COLLECTIONS = {
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


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _load_json(path: Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise OwnerFirstError(f"could not read {label} {path}: {error}") from error
    if not isinstance(value, dict):
        raise OwnerFirstError(f"{label} must be an object")
    return value


def _load_authoritative_definitions(generator_path: Path) -> dict[str, Any]:
    """Execute helper definitions without running the production build."""

    source = generator_path.read_text(encoding="utf-8")
    sentinel = 'if __name__ == "__main__" or True:\n    build()'
    if source.count(sentinel) != 1:
        raise OwnerFirstError(
            "authoritative generator entry sentinel changed; refusing unsafe import")
    source = source.replace(sentinel, "if False:\n    build()")
    namespace: dict[str, Any] = {
        "__file__": str(generator_path.resolve()),
        "__name__": "orison_m11c1_authoritative_definitions",
    }
    exec(compile(source, str(generator_path), "exec"), namespace)
    required = {
        "MeshBuf", "Frame", "ASM", "build_wall", "build_baked_wall_finish",
        "build_floor_overlay", "build_ceiling_overlay", "build_vent_register",
        "build_blind_slat", "build_sidewalk_flag", "build_framed_picture",
        "build_stair", "build_wear_decals", "build_facade_details",
        "subtract_rect", "furniture_batch_prefix", "finish_at",
    }
    missing = sorted(required - set(namespace))
    if missing:
        raise OwnerFirstError(
            f"authoritative generator definitions are missing: {missing}")
    return namespace


def _owner_token(owner: str) -> str:
    aliases = {
        "CELL_ORISON_F01_INTERIOR": "INTERIOR",
        "CELL_ORISON_FACADE_SHELL": "FACADE",
        "CELL_SITE_STREET_COMMON": "STREET",
        "CELL_PASSAGE": "PASSAGE",
    }
    return aliases.get(owner, owner.removeprefix("CELL_").replace("SHOP_", "SHOP_"))


class NullBuffer:
    """No-op target for non-F01 and filtered wear categories."""

    def __getattr__(self, name: str) -> Callable[..., None]:
        if name.startswith("add_"):
            return lambda *args, **kwargs: None
        raise AttributeError(name)


NULL_BUFFER = NullBuffer()


def _scope_record(source: dict[str, Any], emission_prefix: str) -> dict[str, Any]:
    return {
        "source_id": str(source["source_id"]),
        "source_locator": str(source["source_locator"]),
        "owner_cell": str(source["owner_cell"]),
        "emission_prefix": emission_prefix,
    }


class ScopedBuffer:
    def __init__(self, target: "TrackedBuffer", scope: dict[str, Any]):
        self.target = target
        self.scope = copy.deepcopy(scope)

    def __getattr__(self, name: str) -> Any:
        attribute = getattr(self.target.mesh, name)
        if not name.startswith("add_") or not callable(attribute):
            return attribute

        def emit(*args: Any, **kwargs: Any) -> Any:
            vertex_start = len(self.target.mesh.verts)
            polygon_start = len(self.target.mesh.faces)
            result = attribute(*args, **kwargs)
            vertex_end = len(self.target.mesh.verts)
            polygon_end = len(self.target.mesh.faces)
            if vertex_end == vertex_start and polygon_end == polygon_start:
                return result
            if vertex_end <= vertex_start or polygon_end <= polygon_start:
                raise OwnerFirstError(
                    f"partial geometry mutation in {self.target.buffer_id}/{name}")
            triangle_start = self.target.triangle_count
            triangle_count = sum(
                len(face) - 2
                for face in self.target.mesh.faces[polygon_start:polygon_end]
            )
            if triangle_count <= 0:
                raise OwnerFirstError(
                    f"non-triangular contribution in {self.target.buffer_id}/{name}")
            emission_kind = ".".join((
                str(self.scope["emission_prefix"]),
                self.target.category.replace("-", "_"),
                name.removeprefix("add_"),
            ))
            self.target.contributions.append({
                "source_id": str(self.scope["source_id"]),
                "source_locator": str(self.scope["source_locator"]),
                "owner_cell": self.target.owner_cell,
                "emission_kind": emission_kind,
                "material": self.target.material,
                "collision_class": self.target.collision_class,
                "legacy_compatibility_identity": self.target.legacy_identity,
                "generated_range": {
                    "vertices": {
                        "start": vertex_start,
                        "count": vertex_end - vertex_start,
                    },
                    "polygons": {
                        "start": polygon_start,
                        "count": polygon_end - polygon_start,
                    },
                    "triangles": {
                        "start": triangle_start,
                        "count": triangle_count,
                    },
                },
            })
            self.target.triangle_count += triangle_count
            return result

        return emit


class TrackedBuffer:
    def __init__(
            self, mesh: Any, owner_cell: str, category: str, material: str,
            object_name: str):
        self.mesh = mesh
        self.owner_cell = owner_cell
        self.category = category
        self.material = material
        self.object_name = object_name
        self.legacy_identity = f"F01_{category}"
        self.collision_class = collision_class_for_name(object_name)
        if collision_class_for_name(self.legacy_identity) != self.collision_class:
            raise OwnerFirstError(
                f"owned name broke collision suffix for {self.legacy_identity}")
        self.buffer_id = "BUFFER_" + canonical_hash({
            "owner_cell": owner_cell,
            "category": category,
            "material": material,
        })[:24].upper()
        self.contributions: list[dict[str, Any]] = []
        self.triangle_count = 0

    def scoped(self, scope: dict[str, Any]) -> ScopedBuffer:
        if str(scope["owner_cell"]) != self.owner_cell:
            raise OwnerFirstError(
                f"scope owner differs from buffer owner {self.object_name}")
        return ScopedBuffer(self, scope)

    def realize(self, collection: Any) -> Any:
        if not self.contributions:
            raise OwnerFirstError(f"buffer {self.buffer_id} has no contributions")
        obj = self.mesh.realize(collection)
        if obj is None:
            raise OwnerFirstError(f"buffer {self.buffer_id} did not realize")
        if len(obj.data.vertices) != len(self.mesh.verts):
            raise OwnerFirstError(
                f"Blender validation changed vertices in {self.buffer_id}")
        if len(obj.data.polygons) != len(self.mesh.faces):
            raise OwnerFirstError(
                f"Blender validation changed polygons in {self.buffer_id}")
        obj.data.calc_loop_triangles()
        if len(obj.data.loop_triangles) != self.triangle_count:
            raise OwnerFirstError(
                f"realized triangle count changed in {self.buffer_id}")
        for contribution in self.contributions:
            polygons = contribution["generated_range"]["polygons"]
            start = int(polygons["start"])
            count = int(polygons["count"])
            actual = sum(
                len(obj.data.polygons[index].vertices) - 2
                for index in range(start, start + count)
            )
            if actual != int(contribution["generated_range"]["triangles"]["count"]):
                raise OwnerFirstError(
                    f"polygon/triangle range changed in {self.buffer_id}")
        return obj

    def manifest(self) -> dict[str, Any]:
        return {
            "buffer_id": self.buffer_id,
            "object_name": self.object_name,
            "owner_cell": self.owner_cell,
            "material": self.material,
            "collision_class": self.collision_class,
            "legacy_compatibility_identity": self.legacy_identity,
            "generated_totals": {
                "vertices": len(self.mesh.verts),
                "polygons": len(self.mesh.faces),
                "triangles": self.triangle_count,
            },
            "contributions": copy.deepcopy(self.contributions),
        }


def generate_candidate(
        generator_path: Path,
        layout_path: Path,
        ownership_sidecar_path: Path,
        output_root: Path,
) -> dict[str, Any]:
    output_root = output_root.resolve()
    if output_root == REPO_ROOT or output_root.is_relative_to(REPO_ROOT) \
            or REPO_ROOT.is_relative_to(output_root):
        raise OwnerFirstError(
            "candidate output must be an external disposable root")
    if output_root.exists() and any(output_root.iterdir()):
        raise OwnerFirstError(
            f"candidate output is not empty; refusing overwrite: {output_root}")
    candidate_root = output_root / "candidate"
    candidate_root.mkdir(parents=True, exist_ok=True)
    generator = _load_authoritative_definitions(generator_path.resolve())
    layout = _load_json(layout_path.resolve(), "authoritative layout")
    if generator["LAYOUT"] != layout:
        raise OwnerFirstError(
            "generator's authoritative layout differs from explicit layout input")
    catalog = load_source_ownership(
        layout_path.resolve(), ownership_sidecar_path.resolve())
    if len(catalog) != sum(EXPECTED_COLLECTIONS.values()):
        raise OwnerFirstError(
            f"normalized catalog has {len(catalog)} rows, expected "
            f"{sum(EXPECTED_COLLECTIONS.values())}")
    collections = Counter()
    source_ids: set[str] = set()
    for locator, row in catalog.items():
        if not isinstance(row, dict) or str(row.get("source_locator", "")) != locator:
            raise OwnerFirstError(f"malformed normalized ownership row {locator!r}")
        owner = str(row.get("owner_cell", ""))
        source_id = str(row.get("source_id", ""))
        if owner not in CELL_IDS or not source_id or source_id in source_ids:
            raise OwnerFirstError(f"invalid normalized ownership row {locator!r}")
        collections[str(row.get("collection", ""))] += 1
        source_ids.add(source_id)
    if dict(collections) != EXPECTED_COLLECTIONS:
        raise OwnerFirstError(
            f"normalized catalog collection totals differ: {dict(collections)}")

    # The authoritative material loader stages basename-safe files.  Redirect
    # that staging to the disposable root while retaining original read paths.
    stage_root = candidate_root / "texture_staging"
    stage_root.mkdir(parents=True, exist_ok=True)
    compatibility_texture_inputs: dict[str, dict[str, Any]] = {}

    def disposable_image(path: str, slug: str, kind: str, srgb: bool) -> Any:
        requested_source = Path(path).resolve()
        source = requested_source
        wall_root = (Path(str(generator["TEX_ROOT"])) / "wall_finishes").resolve()
        try:
            relative = requested_source.relative_to(wall_root)
        except ValueError:
            relative = None
        ruled_wall_ids = {f"f01_w{index:02d}" for index in range(10)}
        ruled = (
            relative is not None and len(relative.parts) == 2
            and relative.parts[0] in ruled_wall_ids
            and relative.parts[1] in {
                "albedo.png", "roughness.png", "normal.png"}
        )
        compatibility_row = None
        if ruled:
            wall_id = relative.parts[0]
            map_kind = Path(relative.parts[1]).stem
            fallback = (REPO_ROOT / "game/assets/building/textures" /
                        f"T_wallfinish_{wall_id}_{map_kind}.png").resolve()
            if not fallback.is_file():
                raise OwnerFirstError(
                    "ruled wall-finish compatibility input is absent: "
                    f"requested={requested_source} fallback={fallback}")
            if requested_source.is_file() \
                    and _sha256_file(requested_source) != _sha256_file(fallback):
                raise OwnerFirstError(
                    "wall-finish authoring map differs from protected "
                    f"compatibility input: {requested_source}")
            if not requested_source.is_file():
                source = fallback
            compatibility_row = {
                "identity": "LEGACY_COMPATIBILITY_TEXTURE_INPUT",
                "requested_authoring_path": str(requested_source),
                "compatibility_source_path": str(source),
                "source_sha256": _sha256_file(source),
                "source_bytes": source.stat().st_size,
                "read_only": True,
                "reason": "MISSING_WALL_FINISH_AUTHORING_MAP_USE_TRACKED_EXPORT_INPUT",
            }
            compatibility_texture_inputs[str(requested_source)] = compatibility_row
        elif not source.is_file():
            raise OwnerFirstError(
                f"material image source is absent: source={source} "
                f"slug={slug!r} kind={kind!r}")
        staged = stage_root / f"T_{slug}_{kind}{source.suffix.lower()}"
        staged.parent.mkdir(parents=True, exist_ok=True)
        if not staged.exists() or _sha256_file(staged) != _sha256_file(source):
            try:
                shutil.copy2(source, staged)
            except OSError as error:
                raise OwnerFirstError(
                    "could not stage material image: "
                    f"source={source} source_exists={source.exists()} "
                    f"staged={staged} parent_exists={staged.parent.exists()} "
                    f"slug={slug!r} kind={kind!r}: {error}") from error
        if compatibility_row is not None:
            compatibility_row["staged_path"] = str(staged.resolve())
            compatibility_row["staged_sha256"] = _sha256_file(staged)
            if compatibility_row["staged_sha256"] \
                    != compatibility_row["source_sha256"]:
                raise OwnerFirstError(
                    f"wall-finish staged hash differs: {staged}")
        image = bpy.data.images.load(str(staged), check_existing=True)
        image.name = f"T_{slug}_{kind}"
        image.colorspace_settings.name = "sRGB" if srgb else "Non-Color"
        return image

    generator["_image"] = disposable_image
    generator["LAYOUT"] = layout
    generator["ROOMS_BY_FLOOR"] = {
        floor["id"]: floor.get("rooms", []) for floor in layout["floors"]
    }
    generator["LEVELS"] = layout["meta"]["levels"]
    generator["LEVEL_ORDER"] = sorted(
        generator["LEVELS"].items(), key=lambda item: item[1])

    floors = [floor for floor in layout["floors"] if floor.get("id") == "F01"]
    if len(floors) != 1:
        raise OwnerFirstError(f"expected one F01 floor, found {len(floors)}")
    floor = floors[0]

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.app.debug_value = 2
    root_collection = bpy.data.collections.new("ORISON_M11C1_DISPOSABLE")
    bpy.context.scene.collection.children.link(root_collection)
    floor_collection = bpy.data.collections.new("F01_OWNER_FIRST")
    root_collection.children.link(floor_collection)

    active_scope: dict[str, Any] | None = None
    tracked: dict[tuple[str, str, str], TrackedBuffer] = {}
    object_names: set[str] = set()
    storey_index = {
        level: index for index, (level, _z) in enumerate(generator["LEVEL_ORDER"])
    }

    def variant(fid: str, material: str) -> str:
        family = [material] + [
            material + suffix for suffix in ("_b", "_c", "_d")
            if material + suffix in generator["CAT_TEX"]
        ]
        return family[storey_index.get(fid, 0) % len(family)]

    @contextmanager
    def activate(scope: dict[str, Any]):
        nonlocal active_scope
        if active_scope is not None:
            raise OwnerFirstError("nested emission scopes are forbidden")
        if str(scope.get("owner_cell", "")) not in CELL_IDS:
            raise OwnerFirstError("emission scope has unknown owner_cell")
        active_scope = copy.deepcopy(scope)
        try:
            yield
        finally:
            active_scope = None

    def buffer_for_scope(
            fid: str, category: str, material: str,
            scope: dict[str, Any]) -> Any:
        if fid != "F01":
            return NULL_BUFFER
        owner = str(scope["owner_cell"])
        actual_material = variant(fid, material)
        key = (owner, category, actual_material)
        if key not in tracked:
            # Match the authoritative buf() ordering exactly: UV policy is
            # selected from the authored base material, then the storey
            # material variant is chosen.  Variant slots such as rug_warm_b
            # deliberately inherit rug_warm's unit mapping.
            if material.startswith("wallfinish_") \
                    or material in generator["EXPLICIT_MATS"]:
                uv_mode = "explicit"
            elif material.startswith("fx_") \
                    or generator["UV_MODE_BY_MAT"].get(material) == "unit":
                uv_mode = "unit"
            else:
                uv_mode = "world"
            object_name = f"F01_OWN_{_owner_token(owner)}_{category}"
            if object_name in object_names:
                raise OwnerFirstError(f"owned object name collision {object_name!r}")
            mesh = generator["MeshBuf"](
                object_name, actual_material, uv_mode)
            mesh.rooms = floor.get("rooms", [])
            tracked[key] = TrackedBuffer(
                mesh, owner, category, actual_material, object_name)
            object_names.add(object_name)
        return tracked[key].scoped(scope)

    def buf(fid: str, category: str, material: str) -> Any:
        if fid != "F01":
            return NULL_BUFFER
        if active_scope is None:
            raise OwnerFirstError(
                f"F01 buffer {category!r} requested outside an active source scope")
        return buffer_for_scope(fid, category, material, active_scope)

    def source_scope(collection: str, index: int, prefix: str) -> dict[str, Any]:
        locator = f"floors[F01].{collection}[{index}]"
        if locator not in catalog:
            raise OwnerFirstError(
                f"authoritative source has no ownership row: {locator}")
        row = catalog[locator]
        if str(row.get("collection", "")) != collection:
            raise OwnerFirstError(f"ownership collection mismatch at {locator}")
        return _scope_record(row, prefix)

    supplemental_sources = [
        copy.deepcopy(row) for row in EXPECTED_SUPPLEMENTAL_GENERATED_SOURCES
    ]

    # Slab, wall, room, ceiling, register, and furnishing scopes mirror the
    # authoritative build loop.  No owner is selected by geometry.
    for slab_index, slab_record in enumerate(floor["slabs"]):
        with activate(source_scope("slabs", slab_index, "slab")):
            rectangle = slab_record["rect"]
            slab = dict(
                slab_record,
                rect=[rectangle[0] + 0.03, rectangle[1] + 0.03,
                      rectangle[2] - 0.03, rectangle[3] - 0.03],
            )
            rectangles = [tuple(slab["rect"])]
            for hole in slab["holes"]:
                rectangles = generator["subtract_rect"](rectangles, tuple(hole))
            for x0, y0, x1, y1 in rectangles:
                buf("F01", "slabs-col", "slab").add_box(
                    (x0, y0, slab["z_top"] - slab["t"]),
                    (x1, y1, slab["z_top"]),
                )

    for wall_index, wall in enumerate(floor["walls"]):
        with activate(source_scope("walls", wall_index, "wall")):
            category = {
                "brick": "walls_brick-col",
                "face_brick": "walls_fbrick-col",
                "common_brick": "walls_cbrick-col",
                "concrete": "walls_conc-col",
            }.get(wall["mat"], "walls-col")
            generator["build_wall"](
                buf("F01", category, wall["mat"]), wall,
                buf("F01", "trim", "trim"),
                buf("F01", "glazing-col", "glassish"),
                buf("F01", "wainscot_%s" % wall.get("wains_mat", "wainscot"),
                    wall.get("wains_mat", "wainscot")),
                buf("F01", "stone_trim-col", "limestone"),
                buf("F01", "fx_ao_decal", "fx_ao"), floor,
                buf("F01", "sash-col", "sash"),
            )
            if wall["mat"] in ("brick", "common_brick", "face_brick") \
                    and wall.get("in_side") and wall.get("finish_texture"):
                finish_id = wall["finish_texture"]
                generator["build_baked_wall_finish"](
                    buf("F01", "finish_%s" % finish_id,
                        "wallfinish_%s" % finish_id),
                    wall, wall["in_side"],
                )

    for room_index, room in enumerate(floor["rooms"]):
        with activate(source_scope("rooms", room_index, "room_floor")):
            generator["build_floor_overlay"](buf, "F01", floor, room)

    for ceiling_index, ceiling in enumerate(floor.get("ceilings", [])):
        with activate(source_scope("ceilings", ceiling_index, "ceiling")):
            generator["build_ceiling_overlay"](buf, "F01", ceiling)

    for register_index, register in enumerate(floor.get("vent_registers", [])):
        with activate(source_scope(
                "vent_registers", register_index, "vent_register")):
            generator["build_vent_register"](buf, "F01", register)

    for furniture_index, furniture in enumerate(floor.get("furniture", [])):
        with activate(source_scope("furniture", furniture_index, "furniture")):
            if "asm" in furniture:
                function = generator["ASM"].get(furniture["asm"])
                if function is None:
                    continue
                on_floor = abs(furniture.get("z0", 0.0)) < 1e-6
                batch_key = str(furniture.get("batch", ""))
                prefix = (generator["furniture_batch_prefix"](batch_key)
                          if batch_key else "furnish")
                frame = generator["Frame"](
                    lambda material, p=prefix: buf(
                        "F01", "%s_%s" % (p, material), material),
                    lambda p=prefix: buf(
                        "F01", "%s_hull-colonly" % p, "slab"),
                    furniture["at"][0], furniture["at"][1],
                    floor["z"] + furniture.get("z0", 0.0),
                    furniture.get("yaw", 0),
                    generator["finish_at"](
                        floor, furniture["at"][0], furniture["at"][1])
                    if on_floor else 0.0,
                )
                function(frame, furniture)
                continue
            rectangle = furniture["rect"]
            z0 = floor["z"] + furniture.get("z0", 0.0)
            furniture_material = furniture.get("mat", "trim")
            if furniture_material == "sidewalk_haunted":
                generator["build_sidewalk_flag"](
                    buf, "F01", furniture, rectangle, z0)
                continue
            furniture_id = str(furniture.get("id", ""))
            category_prefix = "furniture"
            batch_key = str(furniture.get("batch", ""))
            if batch_key:
                category_prefix = generator["furniture_batch_prefix"](batch_key)
            elif furniture_id.startswith("retail_bod"):
                category_prefix = "retail_bod"
            elif furniture_id.startswith("retail_bar"):
                category_prefix = "retail_bar"
            elif furniture_id.startswith("retail_"):
                category_prefix = "retail_site"
            if "slat" in furniture:
                generator["build_blind_slat"](
                    buf("F01", "%s_%s" % (
                        category_prefix, furniture_material), furniture_material),
                    furniture, rectangle, z0,
                )
                continue
            if furniture_material == "art":
                if furniture_id.endswith("_art"):
                    generator["build_framed_picture"](
                        buf, "F01", furniture, rectangle, z0)
                    continue
                furniture_material = "indicator_enamel"
            collision_suffix = "" if furniture.get("nocol") else "-col"
            buf(
                "F01", "%s_%s%s" % (
                    category_prefix, furniture_material, collision_suffix),
                furniture_material,
            ).add_box(
                (rectangle[0], rectangle[1], z0),
                (rectangle[2], rectangle[3], z0 + furniture["h"]),
            )

    # Stairs are authored by the global `stairs[atrium]` record, outside the
    # F01 collection catalog, and therefore use an explicit supplemental ID.
    stair_source = supplemental_sources[0]
    for stair in layout.get("stairs", []):
        if str(stair.get("id", "")) != "atrium":
            raise OwnerFirstError(
                f"unruled supplemental stair source {stair.get('id')!r}")
        with activate(_scope_record(stair_source, "stair")):
            generator["build_stair"](buf, stair)

    def wear_view(
            *, markers: list[dict[str, Any]], walls: list[dict[str, Any]],
            rooms: list[dict[str, Any]]) -> dict[str, Any]:
        value = dict(floor)
        value["markers"] = markers
        value["walls"] = walls
        value["rooms"] = rooms
        return value

    def replay_wear(
            scope: dict[str, Any], floor_view: dict[str, Any],
            accepted_categories: set[str]) -> None:
        def filtered_buf(fid: str, category: str, material: str) -> Any:
            if fid != "F01" or category not in accepted_categories:
                return NULL_BUFFER
            return buf(fid, category, material)
        with activate(scope):
            generator["build_wear_decals"](filtered_buf, floor_view)

    full_rooms = list(floor.get("rooms", []))
    for marker_index, marker in enumerate(floor.get("markers", [])):
        accepted: set[str] = set()
        if marker.get("kind") == "door" and marker.get("leaf") != "none":
            accepted.add("wear_fx_scuff")
        elif marker.get("kind") == "radiator":
            accepted.add("wear_fx_drip")
        elif marker.get("kind") == "stove":
            accepted.add("wear_fx_grease")
        if accepted:
            replay_wear(
                source_scope("markers", marker_index, "marker_wear"),
                wear_view(markers=[marker], walls=[], rooms=full_rooms),
                accepted,
            )
    for wall_index, wall in enumerate(floor.get("walls", [])):
        replay_wear(
            source_scope("walls", wall_index, "wall_wear"),
            wear_view(markers=[], walls=[wall], rooms=full_rooms),
            {"wear_fx_drip"},
        )
    # Keep the authoritative function's cross-room wet_i ordinal intact.
    # Each ceiling buffer request is nevertheless handed the corresponding
    # room's already-resolved scope before its add_quad call.
    wet_kinds = {"bathroom", "kitchen", "laundry", "boiler"}
    wet_rooms = [
        (room_index, room)
        for room_index, room in enumerate(floor.get("rooms", []))
        if room.get("kind") in wet_kinds
    ]
    wet_call_index = 0

    def sequenced_wet_buf(fid: str, category: str, material: str) -> Any:
        nonlocal wet_call_index
        if fid != "F01" or category != "wear_ceiling_fx_drip":
            return NULL_BUFFER
        if wet_call_index >= len(wet_rooms):
            raise OwnerFirstError("wet-room wear emitted more calls than sources")
        room_index, _room = wet_rooms[wet_call_index]
        wet_call_index += 1
        return buffer_for_scope(
            fid, category, material,
            source_scope("rooms", room_index, "room_ceiling_wear"),
        )

    generator["build_wear_decals"](
        sequenced_wet_buf,
        wear_view(markers=[], walls=[], rooms=full_rooms),
    )
    if wet_call_index != len(wet_rooms):
        raise OwnerFirstError(
            "wet-room wear did not emit exactly once for every wet room")
    replay_wear(
        _scope_record(supplemental_sources[2], "common_traffic_wear"),
        wear_view(markers=[], walls=[], rooms=full_rooms),
        {"wear_fx_traffic"},
    )

    with activate(_scope_record(supplemental_sources[1], "facade_rainwater")):
        generator["build_facade_details"](buf)

    if active_scope is not None:
        raise OwnerFirstError("emission scope leaked after generation")
    empty_requested = [value for value in tracked.values()
                       if not value.contributions]
    for value in empty_requested:
        if value.mesh.verts or value.mesh.faces:
            raise OwnerFirstError(
                f"unreceipted geometry exists in empty buffer {value.buffer_id}")
    # Authoritative helpers request optional targets up front (for example an
    # interior wall requests glazing even when it has no window).  The legacy
    # MeshBuf.realize() skips those truly empty targets; do the same here.
    ordered = sorted(
        (value for value in tracked.values() if value.contributions),
        key=lambda value: (
            CELL_IDS.index(value.owner_cell), value.material,
            value.legacy_identity, value.buffer_id),
    )
    owners_with_geometry = {value.owner_cell for value in ordered}
    missing_cells = sorted(set(CELL_IDS) - owners_with_geometry)
    if missing_cells:
        raise OwnerFirstError(
            f"owner-first generation emitted no geometry for {missing_cells}")
    for tracked_buffer in ordered:
        tracked_buffer.realize(floor_collection)

    bpy.ops.object.select_all(action="DESELECT")
    for obj in floor_collection.objects:
        if obj.type == "MESH":
            obj.select_set(True)
    candidate_gltf = candidate_root / "floor_01_owner_first_candidate.gltf"
    bpy.ops.export_scene.gltf(
        filepath=str(candidate_gltf),
        use_selection=True,
        export_apply=True,
        export_format="GLTF_SEPARATE",
        export_texture_dir="textures",
    )
    candidate_bin = candidate_gltf.with_suffix(".bin")
    if not candidate_gltf.is_file() or not candidate_bin.is_file():
        raise OwnerFirstError("Blender did not emit candidate glTF/BIN")
    descriptor = _load_json(candidate_gltf, "candidate glTF")
    descriptor.setdefault("asset", {}).setdefault("extras", {})[
        "orison_bin_sha256"] = _sha256_file(candidate_bin)
    descriptor["asset"]["extras"]["orison_m11c1_candidate"] = {
        "production_asset": False,
        "owner_before_material": True,
        "spatial_inference_used": False,
    }
    write_json(candidate_gltf, descriptor)

    lineage_path = candidate_root / "generated_owner_lineage.json"
    lineage = {
        "schema": SCHEMA_CANDIDATE_LINEAGE,
        "status": "GENERATED_PENDING_SLICE_BINDING",
        "production_asset": False,
        "spatial_inference_used": False,
        "owner_before_material": True,
        "declared_owner_cells": list(CELL_IDS),
        "authoritative_inputs": {
            "generator": {
                "path": str(generator_path.resolve()),
                "sha256": _sha256_file(generator_path.resolve()),
            },
            "layout": {
                "path": str(layout_path.resolve()),
                "sha256": _sha256_file(layout_path.resolve()),
            },
            "ownership": {
                "path": str(ownership_sidecar_path.resolve()),
                "sha256": _sha256_file(ownership_sidecar_path.resolve()),
            },
            "source_catalog_record_count": len(catalog),
        },
        "producer": {
            "mode": "BLENDER_AUTHORITATIVE_HELPER_REPLAY",
            "adapter": {
                "path": str(Path(__file__).resolve()),
                "sha256": _sha256_file(Path(__file__).resolve()),
            },
            "blender_version": list(bpy.app.version),
            "protected_gltf_input": False,
            "protected_bin_input": False,
            "runtime_layout_mirror_input": False,
            "authoritative_layout_input": True,
            "output_policy": "DISPOSABLE_ROOT_ONLY",
            "command_contract": [
                "--generator", "--layout", "--ownership-sidecar",
                "--output",
            ],
            "compatibility_texture_inputs": [
                compatibility_texture_inputs[key]
                for key in sorted(compatibility_texture_inputs)
            ],
            "open_rebuild_source_debt": [{
                "code": "F01_WALL_FINISH_AUTHORING_ID_SCHEME_MISMATCH",
                "status": "OPEN",
                "layout_required_ids": "f01_w00..f01_w09",
                "current_bake_tool_ids": "f01_wall_00..f01_wall_09",
                "finding": (
                    "The checked-in layout names the legacy f01_w* set while "
                    "the current bake tool authors the newer f01_wall_* set; "
                    "neither missing authoring set is fabricated by M11C1."
                ),
            }],
        },
        "generated_sources": supplemental_sources,
        "buffers": [value.manifest() for value in ordered],
        "empty_requested_buffers": [{
            "buffer_id": value.buffer_id,
            "object_name": value.object_name,
            "owner_cell": value.owner_cell,
            "material": value.material,
            "legacy_compatibility_identity": value.legacy_identity,
            "reason": "AUTHORITATIVE_OPTIONAL_TARGET_REQUESTED_BUT_NOT_EMITTED",
        } for value in sorted(
            empty_requested,
            key=lambda item: (CELL_IDS.index(item.owner_cell), item.material,
                              item.legacy_identity, item.buffer_id))],
    }
    write_json(lineage_path, lineage)
    bound = bind_candidate_triangle_slices(candidate_gltf, lineage_path)
    bound["status"] = "PASS"
    write_json(lineage_path, bound)
    return {
        "status": "PASS",
        "candidate_gltf": str(candidate_gltf),
        "candidate_bin": str(candidate_bin),
        "generated_lineage": str(lineage_path),
        "buffers": len(ordered),
        "contributions": sum(len(value.contributions) for value in ordered),
        "triangles": sum(value.triangle_count for value in ordered),
        "source_catalog_records": len(catalog),
    }


def _parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--generator", type=Path, required=True)
    parser.add_argument("--layout", type=Path, required=True)
    parser.add_argument("--ownership-sidecar", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    return parser.parse_args(argv)


def main() -> int:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    args = _parse_args(argv)
    try:
        summary = generate_candidate(
            args.generator, args.layout, args.ownership_sidecar,
            args.output)
    except Exception as error:  # Blender otherwise reports some script errors as 0.
        traceback.print_exc()
        print(f"M11C1 CANDIDATE GENERATION FAIL: {error}", file=sys.stderr)
        return 2
    print("M11C1_OWNER_FIRST_GENERATION=" + json.dumps(
        summary, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
