#!/usr/bin/env python3
"""Focused contract tests for the inert M11C1 F01 ownership catalog."""

from __future__ import annotations

import copy
import json
import sys
import tempfile
import unittest
from collections import Counter
from pathlib import Path


TOOLS_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = TOOLS_DIR.parent
sys.path.insert(0, str(TOOLS_DIR))

from m11c1_floor01_owner_first import author_source_ownership as author  # noqa: E402
from m11c1_floor01_owner_first import source_ownership as ownership  # noqa: E402


LAYOUT_PATH = REPO_ROOT / ownership.DEFAULT_LAYOUT
SIDECAR_PATH = REPO_ROOT / ownership.DEFAULT_SIDECAR
PROTECTED_LAYOUT_SHA256 = (
    "68838c933c0954092c63403f36ec7fb26d6c0956c01c23109465c680608b399d"
)


def load_json(path: Path) -> dict:
    value = json.loads(path.read_text(encoding="utf-8"))
    assert isinstance(value, dict)
    return value


def receipt_copy(sidecar: dict) -> dict:
    result = copy.deepcopy(sidecar)
    result["records_sha256"] = ownership.sha256_value(result["records"])
    return result


class RealCatalogTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.layout = load_json(LAYOUT_PATH)
        cls.sidecar = load_json(SIDECAR_PATH)
        cls.resolved = ownership.resolve_floor_records(cls.layout, cls.sidecar)

    def test_protected_layout_hash_is_pinned(self):
        self.assertEqual(ownership.sha256_file(LAYOUT_PATH), PROTECTED_LAYOUT_SHA256)
        self.assertEqual(
            self.sidecar["source_layout"]["sha256"], PROTECTED_LAYOUT_SHA256)

    def test_catalog_resolves_all_source_records_exactly_once(self):
        self.assertEqual(len(self.resolved), 5286)
        self.assertEqual(
            Counter(row["collection"] for row in self.resolved.values()),
            Counter(ownership.EXPECTED_SOURCE_COUNTS),
        )
        self.assertEqual(len({row["source_id"] for row in self.resolved.values()}), 5286)
        self.assertEqual(
            len({row["source_record_sha256"] for row in self.resolved.values()}),
            5286,
        )

    def test_catalog_uses_exact_17_cell_vocabulary(self):
        self.assertEqual(self.sidecar["owner_cells"], list(ownership.OWNER_CELLS))
        owners = Counter(row["owner_cell"] for row in self.resolved.values())
        self.assertEqual(
            owners,
            Counter(
                {
                    "CELL_ORISON_F01_INTERIOR": 465,
                    "CELL_ORISON_FACADE_SHELL": 41,
                    "CELL_SITE_STREET_COMMON": 2192,
                    "CELL_PASSAGE": 494,
                    "CELL_SHOP_BAR": 375,
                    "CELL_SHOP_BODEGA": 161,
                    "CELL_SHOP_MODEL_LAUNDRY": 166,
                    "CELL_SHOP_SHOE_REBUILDING": 109,
                    "CELL_SHOP_KEYS_CUT": 188,
                    "CELL_SHOP_HARDWARE_PAINT": 231,
                    "CELL_SHOP_FUNERAL_PARLOUR": 122,
                    "CELL_SHOP_PHOTO_SUPPLIES": 127,
                    "CELL_SHOP_RADIO_SERVICE": 101,
                    "CELL_SHOP_PAWNBROKER": 123,
                    "CELL_SHOP_NEWS_CIGARS": 85,
                    "CELL_SHOP_OTIS_SON": 190,
                    "CELL_SHOP_LUNCHEONETTE": 116,
                }
            ),
        )

    def test_previously_named_records_preserve_authored_ids(self):
        named = [
            row for row in self.resolved.values()
            if row["identity_origin"] == "AUTHORED_RECORD_ID"
        ]
        self.assertEqual(len(named), 4678)
        floor = next(row for row in self.layout["floors"] if row["id"] == "F01")
        for row in named:
            collection = row["collection"]
            index = int(row["source_locator"].rsplit("[", 1)[1][:-1])
            self.assertEqual(row["source_id"], floor[collection][index]["id"])

    def test_walls_have_durable_ids_and_explicit_authored_owners(self):
        rows = [row for row in self.resolved.values() if row["collection"] == "walls"]
        self.assertEqual([row["source_id"] for row in rows], [
            f"F01_WALL_{number:03d}" for number in range(1, 43)
        ])
        self.assertEqual(
            Counter(row["owner_cell"] for row in rows),
            Counter({
                "CELL_ORISON_F01_INTERIOR": 32,
                "CELL_ORISON_FACADE_SHELL": 10,
            }),
        )
        self.assertTrue(all(
            row["identity_origin"] == "M11C1_EXPLICIT_SIDECAR_ID"
            for row in rows
        ))
        self.assertEqual(
            Counter(row["authoring_context"] for row in rows),
            Counter({
                "F01_AUTHORED_INTERIOR_WALL_CONTEXT": 32,
                "F01_AUTHORED_PERIMETER_WALL_CONTEXT": 10,
            }),
        )

    def test_site_lights_have_durable_ids_and_site_authority(self):
        rows = [
            row for row in self.resolved.values()
            if row["collection"] == "site_lights"
        ]
        self.assertEqual(len(rows), 565)
        self.assertEqual(rows[0]["source_id"], "F01_SITE_LIGHT_0001")
        self.assertEqual(rows[-1]["source_id"], "F01_SITE_LIGHT_0565")
        self.assertEqual(
            {row["owner_cell"] for row in rows}, {"CELL_SITE_STREET_COMMON"})
        self.assertEqual(
            {row["authoring_context"] for row in rows},
            {"SITE_PASS_SITE_LIGHT_COLLECTION"},
        )

    def test_slab_has_durable_id_and_building_authority(self):
        row = self.resolved["floors[F01].slabs[0]"]
        self.assertEqual(row["source_id"], "F01_SLAB_001")
        self.assertEqual(row["owner_cell"], "CELL_ORISON_F01_INTERIOR")
        self.assertEqual(row["identity_origin"], "M11C1_EXPLICIT_SIDECAR_ID")
        self.assertEqual(
            row["authoring_context"], "F01_BUILDING_INTERIOR_COLLECTION_CONTEXT")

    def test_exactly_608_anonymous_records_receive_explicit_non_hash_ids(self):
        migrated = [
            row for row in self.resolved.values()
            if row["identity_origin"] == "M11C1_EXPLICIT_SIDECAR_ID"
        ]
        self.assertEqual(len(migrated), 608)
        self.assertEqual(
            Counter(row["collection"] for row in migrated),
            Counter({"walls": 42, "site_lights": 565, "slabs": 1}),
        )
        self.assertFalse(any("SHA" in row["source_id"] for row in migrated))

    def test_three_passage_overlap_lights_are_explicit_non_spatial_rulings(self):
        rulings = self.sidecar["explicit_owner_rulings"]
        self.assertEqual(
            [row["source_locator"] for row in rulings],
            list(ownership.PASSAGE_OVERLAP_LOCATORS),
        )
        self.assertEqual(
            [row["source_id"] for row in rulings],
            ["F01_SITE_LIGHT_0090", "F01_SITE_LIGHT_0091", "F01_SITE_LIGHT_0092"],
        )
        for row in rulings:
            self.assertEqual(row["owner_cell"], "CELL_SITE_STREET_COMMON")
            self.assertEqual(
                row["decision"], "SITE_STREET_COMMON_BY_AUTHORING_CONTEXT")
            self.assertEqual(
                row["authoring_context"], "SITE_PASS_CITY_WINDOW_CARD_CONTEXT")
            self.assertIs(row["spatial_inference_used"], False)
        self.assertIs(self.sidecar["spatial_inference_used"], False)
        forbidden = self.sidecar["ownership_basis"]["forbidden_inputs"]
        self.assertIn("position", forbidden)
        self.assertIn("bounds", forbidden)
        self.assertIn("centroid", forbidden)
        self.assertIn("connected components", forbidden)

    def test_records_contain_no_geometry_or_position_ownership_inputs(self):
        expected_keys = {
            "source_id",
            "source_locator",
            "collection",
            "source_record_sha256",
            "owner_cell",
            "identity_origin",
            "authoring_context",
        }
        self.assertTrue(all(set(row) == expected_keys for row in self.sidecar["records"]))

    def test_checked_in_sidecar_is_deterministic(self):
        rebuilt = author.build_sidecar(self.layout, ownership.sha256_file(LAYOUT_PATH))
        self.assertEqual(rebuilt, self.sidecar)

    def test_stable_exporter_api_returns_plain_locator_dictionary(self):
        catalog = ownership.load_source_ownership(LAYOUT_PATH, SIDECAR_PATH)
        self.assertIsInstance(catalog, dict)
        self.assertEqual(catalog, self.resolved)

    def test_author_tool_refuses_to_remap_existing_durable_ids(self):
        changed_layout = copy.deepcopy(self.layout)
        floor = next(row for row in changed_layout["floors"] if row["id"] == "F01")
        floor["walls"][0], floor["walls"][1] = floor["walls"][1], floor["walls"][0]
        with tempfile.TemporaryDirectory() as temporary:
            temporary_root = Path(temporary)
            layout_path = temporary_root / "layout.json"
            output_path = temporary_root / "ownership.json"
            layout_path.write_text(json.dumps(changed_layout), encoding="utf-8")
            original = SIDECAR_PATH.read_bytes()
            output_path.write_bytes(original)
            result = author.main([
                "--layout", str(layout_path),
                "--output", str(output_path),
                "--write",
            ])
            self.assertEqual(result, 2)
            self.assertEqual(output_path.read_bytes(), original)


class RefusalTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.layout = load_json(LAYOUT_PATH)
        cls.sidecar = load_json(SIDECAR_PATH)

    def test_missing_record_is_refused(self):
        changed = copy.deepcopy(self.sidecar)
        changed["records"].pop()
        changed["records_sha256"] = ownership.sha256_value(changed["records"])
        with self.assertRaisesRegex(ownership.SourceOwnershipError, "not exact-once"):
            ownership.resolve_floor_records(self.layout, changed)

    def test_duplicate_source_id_is_refused(self):
        changed = copy.deepcopy(self.sidecar)
        changed["records"][1]["source_id"] = changed["records"][0]["source_id"]
        changed = receipt_copy(changed)
        with self.assertRaisesRegex(ownership.SourceOwnershipError, "duplicate source_id"):
            ownership.resolve_floor_records(self.layout, changed)

    def test_duplicate_record_hash_is_refused(self):
        changed = copy.deepcopy(self.sidecar)
        changed["records"][1]["source_record_sha256"] = (
            changed["records"][0]["source_record_sha256"])
        changed = receipt_copy(changed)
        with self.assertRaisesRegex(ownership.SourceOwnershipError, "duplicate source record hash"):
            ownership.resolve_floor_records(self.layout, changed)

    def test_missing_owner_is_refused(self):
        changed = copy.deepcopy(self.sidecar)
        del changed["records"][0]["owner_cell"]
        changed = receipt_copy(changed)
        with self.assertRaisesRegex(ownership.SourceOwnershipError, "missing fields"):
            ownership.resolve_floor_records(self.layout, changed)

    def test_malformed_owner_is_refused(self):
        changed = copy.deepcopy(self.sidecar)
        changed["records"][0]["owner_cell"] = 17
        changed = receipt_copy(changed)
        with self.assertRaisesRegex(ownership.SourceOwnershipError, "malformed owner_cell"):
            ownership.resolve_floor_records(self.layout, changed)

    def test_unknown_owner_is_refused(self):
        changed = copy.deepcopy(self.sidecar)
        changed["records"][0]["owner_cell"] = "CELL_LEGACY_MIXED"
        changed = receipt_copy(changed)
        with self.assertRaisesRegex(ownership.SourceOwnershipError, "unknown owner_cell"):
            ownership.resolve_floor_records(self.layout, changed)

    def test_malformed_source_id_is_refused(self):
        changed = copy.deepcopy(self.sidecar)
        changed["records"][0]["source_id"] = "invalid source id"
        changed = receipt_copy(changed)
        with self.assertRaisesRegex(ownership.SourceOwnershipError, "malformed source_id"):
            ownership.resolve_floor_records(self.layout, changed)

    def test_spatial_or_other_extra_row_field_is_refused(self):
        changed = copy.deepcopy(self.sidecar)
        changed["records"][0]["centroid"] = [999.0, 999.0]
        changed = receipt_copy(changed)
        with self.assertRaisesRegex(
                ownership.SourceOwnershipError, "unexpected fields"):
            ownership.resolve_floor_records(self.layout, changed)

    def test_stale_or_reordered_source_record_is_refused(self):
        changed_layout = copy.deepcopy(self.layout)
        floor = next(row for row in changed_layout["floors"] if row["id"] == "F01")
        floor["walls"][0], floor["walls"][1] = floor["walls"][1], floor["walls"][0]
        with self.assertRaisesRegex(ownership.SourceOwnershipError, "does not match"):
            ownership.resolve_floor_records(changed_layout, self.sidecar)

    def test_missing_passage_overlap_ruling_is_refused(self):
        changed = copy.deepcopy(self.sidecar)
        changed["explicit_owner_rulings"].pop()
        with self.assertRaisesRegex(
                ownership.SourceOwnershipError,
                "three Passage-overlapping site lights"):
            ownership.resolve_floor_records(self.layout, changed)

    def test_passage_overlap_spatial_ruling_is_refused(self):
        changed = copy.deepcopy(self.sidecar)
        changed["explicit_owner_rulings"][0]["spatial_inference_used"] = True
        with self.assertRaisesRegex(ownership.SourceOwnershipError, "reject spatial inference"):
            ownership.resolve_floor_records(self.layout, changed)


if __name__ == "__main__":
    unittest.main()
