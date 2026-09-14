#!/usr/bin/env python3
"""Objective refusal and config tests for the disposable M11C1 rehearsal."""

from __future__ import annotations

import copy
import json
import math
import sys
import tempfile
import unittest
from pathlib import Path

REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
if str(REPOSITORY_ROOT) not in sys.path:
    sys.path.insert(0, str(REPOSITORY_ROOT))

from tools.m11c1_floor01_rehearsal.prepare_runtime_rehearsal import (
    CONFIG_SCHEMA,
    CONFIG_SCHEMA_PATH,
    GAME_ROOT,
    M11C0_MANIFEST,
    PASSAGE_SHOPS,
    REQUIRED_DYNAMIC_RUNTIME_ASSETS,
    REQUIRED_DYNAMIC_RUNTIME_ASSET_DIRS,
    REPO_ROOT,
    TARGET_CELL_IDS,
    PreparationError,
    _require_header,
    _marker_aperture_center,
    _literal_asset_paths,
    _validate_cells,
    _validate_semantic_sources,
    _validate_transaction_artifacts,
    assert_external_roots,
    build_runtime_config,
    load_json,
    sha256_file,
    validate_export,
    validate_runtime_config_cross_bindings,
    validate_scratch_authoritative_sources,
    write_json,
)


FINAL_EXPORT = Path(r"C:\PleaseRemainOnTheLine-v2-m11c1-export-eighth-attempt")


class HeaderAndDestinationRefusalTests(unittest.TestCase):
    def test_stale_and_mixed_run_is_refused(self) -> None:
        receipt = {"schema": "schema.v1", "status": "PASS", "run_id": "RUN-A"}
        _require_header(receipt, "schema.v1", "RUN-A", "fixture")
        with self.assertRaisesRegex(PreparationError, "stale or mixed"):
            _require_header(receipt, "schema.v1", "RUN-B", "fixture")
        stale = dict(receipt, status="PENDING")
        with self.assertRaisesRegex(PreparationError, "exact PASS"):
            _require_header(stale, "schema.v1", "RUN-A", "fixture")

    def test_repo_export_or_scratch_destination_is_refused(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            export = Path(temporary) / "export"
            export.mkdir()
            with self.assertRaisesRegex(PreparationError, "external to the repository"):
                assert_external_roots(export, REPO_ROOT / "forbidden-m11c1-output")
            with self.assertRaisesRegex(PreparationError, "contain one another"):
                assert_external_roots(export, export / "scratch")

    def test_nonempty_destination_is_refused_before_copy(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            export = root / "export"
            scratch = root / "scratch"
            export.mkdir()
            scratch.mkdir()
            (scratch / "sentinel.txt").write_text("preserve", encoding="utf-8")
            with self.assertRaisesRegex(PreparationError, "must be empty"):
                assert_external_roots(export, scratch)
            self.assertEqual((scratch / "sentinel.txt").read_text(), "preserve")


class TransactionRefusalTests(unittest.TestCase):
    def test_transaction_artifact_hash_cannot_be_stale(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            path = root / "receipt.json"
            receipt = {"schema": "receipt.v1", "status": "PASS", "run_id": "RUN"}
            write_json(path, receipt)
            transaction = {
                "artifacts": {
                    "receipt.json": {
                        "relative_path": "receipt.json",
                        "sha256": "0" * 64,
                        "schema": "receipt.v1",
                        "status": "PASS",
                    }
                }
            }
            with self.assertRaisesRegex(PreparationError, "hash/header differs"):
                _validate_transaction_artifacts(
                    root, transaction, {"receipt.json": (path, receipt)}
                )

    @staticmethod
    def _cell_fixture(root: Path) -> tuple[dict, dict]:
        cells: list[dict] = []
        transactions: list[dict] = []
        for index, cell_id in enumerate(TARGET_CELL_IDS):
            gltf_path = root / "cells" / f"cell_{index:02d}.gltf"
            bin_path = root / "cells" / f"cell_{index:02d}.bin"
            bin_path.parent.mkdir(parents=True, exist_ok=True)
            bin_path.write_bytes(bytes([index + 1]))
            write_json(
                gltf_path,
                {
                    "asset": {
                        "version": "2.0",
                        "extras": {"orison_m11c1_owner_first": {"cell": cell_id}},
                    },
                    "buffers": [{"uri": bin_path.name, "byteLength": 1}],
                },
            )
            row = {
                "id": cell_id,
                "gltf_path": gltf_path.relative_to(root).as_posix(),
                "bin_path": bin_path.relative_to(root).as_posix(),
                "gltf_sha256": sha256_file(gltf_path),
                "bin_sha256": sha256_file(bin_path),
            }
            cells.append(row)
            transactions.append(dict(row))
        return {"cells": cells}, {"cells": transactions}

    def test_swapped_cell_binding_is_refused(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            partition, transaction = self._cell_fixture(root)
            first = transaction["cells"][0]
            second = transaction["cells"][1]
            for key in ("gltf_path", "bin_path", "gltf_sha256", "bin_sha256"):
                first[key], second[key] = second[key], first[key]
            with self.assertRaisesRegex(PreparationError, "transaction/partition"):
                _validate_cells(root, partition, transaction)


class SemanticRefusalTests(unittest.TestCase):
    def test_missing_mandatory_semantics_are_refused(self) -> None:
        layout = {"floors": [{"id": "F01", "markers": [{"id": "UNRELATED"}]}]}
        with self.assertRaisesRegex(PreparationError, "required semantic owners"):
            _validate_semantic_sources(
                {"semantic_owners": [
                    {
                        "identity": "UNRELATED",
                        "semantic_kind": "layout_marker",
                        "source_locator": "floors[F01].markers[0]",
                    }
                ]},
                layout,
                {"thresholds": []},
            )


@unittest.skipUnless(FINAL_EXPORT.is_dir(), "final external M11C1 export unavailable")
class FinalTransactionAndConfigTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.bundle = validate_export(FINAL_EXPORT)
        cls.resources = {
            cell_id: "res://m11c1_disposable/cells/%s.gltf" % cell_id.lower()
            for cell_id in TARGET_CELL_IDS
        }
        cls.config = build_runtime_config(cls.bundle, Path("scratch"), cls.resources)
        cls.schema = load_json(CONFIG_SCHEMA_PATH, "runtime config schema")

    def test_final_eighth_transaction_is_exact_and_complete(self) -> None:
        self.assertEqual(self.bundle.partition["run_id"], "M11C1-12b0189ee7fe5afb6190447a")
        self.assertEqual(len(self.bundle.cells), 17)
        self.assertEqual(len(self.bundle.textures), 304)
        self.assertEqual(len(self.bundle.transaction["artifacts"]), 7)
        self.assertTrue(self.bundle.transaction["json_artifact_closure_verified"])

    def test_config_topology_matches_closed_runtime_schema(self) -> None:
        allowed = set(self.schema["properties"])
        self.assertEqual(set(self.config) - allowed, set())
        self.assertEqual(self.config["schema"], CONFIG_SCHEMA)
        self.assertEqual(set(self.config["cell_resources"]), set(TARGET_CELL_IDS))
        self.assertEqual(len(self.config["residency_sets"]), 17)
        self.assertEqual(len(self.config["seams"]), 5)
        self.assertEqual(len(self.config["capture_views"]), 5)
        self.assertEqual(len(self.config["resident_nav_queries"]), 15)

    def test_passage_is_ten_crossable_plus_news_locked_service_frontage(self) -> None:
        passage = next(
            seam
            for seam in self.config["seams"]
            if seam["id"] == "SEAM_PASSAGE_SHOP_AISLES"
        )
        rows = passage["traversals"]
        self.assertEqual(len(rows), len(PASSAGE_SHOPS))
        crossable = [row for row in rows if row["expectation"] == "crossable"]
        locked = [row for row in rows if row["expectation"] == "locked_non_crossable"]
        self.assertEqual(len(crossable), 10)
        self.assertTrue(all(row["door_action"] == "interact_open" for row in crossable))
        self.assertEqual(len(locked), 1)
        self.assertEqual(locked[0]["shop_cell_id"], "CELL_SHOP_NEWS_CIGARS")
        self.assertEqual(locked[0]["door_action"], "interact_locked_refusal")
        shoe_probe = passage["collision_probes"][0]
        self.assertEqual(shoe_probe["id"], "M11C0_PASSAGE_AISLE_WEST_055")
        self.assertEqual(shoe_probe["legacy_hit_elevation_m"], 0.55)
        self.assertEqual(shoe_probe["expected_owner_cell"], "CELL_PASSAGE")
        self.assertEqual(
            shoe_probe["forbidden_owner_cell"], "CELL_SHOP_SHOE_REBUILDING"
        )

    def test_traversal_plane_uses_leaf_center_not_marker_hinge(self) -> None:
        layout = load_json(REPO_ROOT / "game/data/building_layout.json", "layout")
        markers = {
            marker["id"]: marker
            for floor in layout["floors"]
            if floor["id"] == "F01"
            for marker in floor["markers"]
        }
        passage = next(
            seam
            for seam in self.config["seams"]
            if seam["id"] == "SEAM_PASSAGE_SHOP_AISLES"
        )
        shoe = next(
            row
            for row in passage["traversals"]
            if row["shop_cell_id"] == "CELL_SHOP_SHOE_REBUILDING"
        )
        marker = markers["SITE_SHOP_DOOR_SHOE_REBUILDING"]
        expected = _marker_aperture_center(marker)
        hinge = [float(marker["pos"][0]), float(marker["pos"][2]),
                 -float(marker["pos"][1])]
        self.assertEqual(shoe["plane"]["point"], expected)
        self.assertEqual(shoe["opening_bounds"]["center"], expected)
        self.assertNotEqual(expected, hinge)

    def test_passage_capture_targets_authored_shoe_aperture(self) -> None:
        layout = load_json(REPO_ROOT / "game/data/building_layout.json", "layout")
        markers = {
            marker["id"]: marker
            for floor in layout["floors"]
            if floor["id"] == "F01"
            for marker in floor["markers"]
        }
        shoe = markers["SITE_SHOP_DOOR_SHOE_REBUILDING"]
        shoe_center = _marker_aperture_center(shoe)
        view = next(
            row
            for row in self.config["capture_views"]
            if row["seam_id"] == "SEAM_PASSAGE_SHOP_AISLES"
        )
        source_view = next(
            row
            for row in load_json(M11C0_MANIFEST, "M11C0 manifest")["capture_views"]
            if row["seam_id"] == "SEAM_PASSAGE_SHOP_AISLES"
        )
        self.assertEqual(
            view["target"],
            [shoe_center[0], shoe_center[1] + float(shoe["h"]) * 0.5,
             shoe_center[2]],
        )
        self.assertEqual(view["eye"][:2], source_view["eye"][:2])
        self.assertEqual(view["eye"][2], shoe_center[2])

    def test_capture_views_cross_bind_exact_unique_seams_and_cells(self) -> None:
        validate_runtime_config_cross_bindings(self.config)
        wrong_cells = copy.deepcopy(self.config)
        wrong_cells["capture_views"][0]["cell_ids"] = ["CELL_PASSAGE"]
        with self.assertRaisesRegex(PreparationError, "cells differ"):
            validate_runtime_config_cross_bindings(wrong_cells)
        duplicate = copy.deepcopy(self.config)
        duplicate["capture_views"][1]["seam_id"] = duplicate["capture_views"][0][
            "seam_id"
        ]
        with self.assertRaisesRegex(PreparationError, "duplicated"):
            validate_runtime_config_cross_bindings(duplicate)

    def test_shell_interior_uses_exact_m11c0_facade_supported_floor_point(self) -> None:
        source = load_json(M11C0_MANIFEST, "M11C0 manifest")
        floor_probe = next(
            row for row in source["collision_probes"] if row["id"] == "street_south_floor"
        )
        seam = next(
            row for row in self.config["seams"] if row["id"] == "SEAM_SHELL_INTERIOR"
        )
        traversal = seam["traversals"][0]
        self.assertEqual(traversal["start"][2], floor_probe["from"][2])
        self.assertEqual(traversal["return_waypoints"][-1][2], floor_probe["from"][2])
        self.assertGreaterEqual(
            traversal["start"][2] - traversal["plane"]["point"][2], 0.15
        )
        self.assertEqual(
            seam["cell_ids"],
            ["CELL_ORISON_FACADE_SHELL", "CELL_ORISON_F01_INTERIOR"],
        )
        self.assertEqual(
            traversal["expected_collision_owner_cells"],
            ["CELL_ORISON_FACADE_SHELL", "CELL_ORISON_F01_INTERIOR"],
        )
        self.assertLessEqual(traversal["waypoint_tolerance_m"], 0.05)
        self.assertGreaterEqual(
            traversal["start"][2]
            - traversal["plane"]["point"][2]
            - traversal["waypoint_tolerance_m"],
            0.15,
        )

    def test_crossable_passage_nav_targets_real_inside_waypoints(self) -> None:
        seam = next(
            row
            for row in self.config["seams"]
            if row["id"] == "SEAM_PASSAGE_SHOP_AISLES"
        )
        traversals = {row["shop_cell_id"]: row for row in seam["traversals"]}
        queries = {
            row["shop_cell_id"]: row
            for row in self.config["resident_nav_queries"]
            if row["seam_id"] == "SEAM_PASSAGE_SHOP_AISLES"
        }
        self.assertEqual(set(queries), set(traversals))
        for cell_id, traversal in traversals.items():
            query = queries[cell_id]
            if cell_id == "CELL_SHOP_NEWS_CIGARS":
                self.assertEqual(query["passage_place"], "news_cigars")
                self.assertNotEqual(query["to"], traversal["forward_waypoints"][-1])
                continue
            self.assertEqual(query["to"], traversal["forward_waypoints"][-1])
            plane = traversal["plane"]["point"]
            horizontal_distance = math.hypot(
                query["to"][0] - plane[0], query["to"][2] - plane[2]
            )
            self.assertAlmostEqual(horizontal_distance, 1.10, places=6)

    def test_dynamic_scanner_assets_are_mandatory_hashable_inputs(self) -> None:
        resolved = _literal_asset_paths()
        for relative in REQUIRED_DYNAMIC_RUNTIME_ASSETS:
            path = GAME_ROOT.joinpath(*Path(relative).parts)
            self.assertIn(path, resolved)
            self.assertTrue(path.is_file())
            self.assertEqual(len(sha256_file(path)), 64)
        for relative in REQUIRED_DYNAMIC_RUNTIME_ASSET_DIRS:
            directory = GAME_ROOT.joinpath(*Path(relative).parts)
            expected = set(directory.glob("*.png"))
            self.assertTrue(expected)
            self.assertTrue(expected.issubset(resolved))
            self.assertTrue(all(len(sha256_file(path)) == 64 for path in expected))

    def test_scratch_authoritative_source_mutation_is_refused(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            scratch = Path(temporary)
            layout = scratch / "data/building_layout.json"
            regions = scratch / "data/orison_v2/exterior/regions.json"
            layout.parent.mkdir(parents=True)
            regions.parent.mkdir(parents=True)
            layout.write_bytes((GAME_ROOT / "data/building_layout.json").read_bytes())
            regions.write_bytes(
                (GAME_ROOT / "data/orison_v2/exterior/regions.json").read_bytes()
            )
            receipt = validate_scratch_authoritative_sources(self.config, scratch)
            self.assertEqual(receipt["layout"]["actual_sha256"], sha256_file(layout))
            layout.write_text("{}\n", encoding="utf-8")
            with self.assertRaisesRegex(PreparationError, "layout hash differs"):
                validate_scratch_authoritative_sources(self.config, scratch)

    def test_save_fixture_is_semantic_and_requires_all_cells(self) -> None:
        fixture = self.config["save_reconstruction"]
        self.assertEqual(fixture["state_id"], "PLAYER_EXTERIOR_ROUTE")
        self.assertEqual(fixture["route_id"], "ROUTE_ORISON_TO_SHOP_BODEGA")
        self.assertEqual(fixture["waypoint_id"], "PAVEMENT_TURN")
        self.assertEqual(fixture["threshold_id"], "THRESHOLD_SHOP_BODEGA_FRONT")
        self.assertEqual(set(fixture["required_cell_ids"]), set(TARGET_CELL_IDS))
        self.assertNotIn("position", json.dumps(fixture).lower())


if __name__ == "__main__":
    unittest.main()
