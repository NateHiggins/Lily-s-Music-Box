#!/usr/bin/env python3
"""Focused tests for audit_orison_floor01_source_ownership.py."""

from __future__ import annotations

import copy
import hashlib
import json
import sys
import unittest
from pathlib import Path


TOOLS_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = TOOLS_DIR.parent
sys.path.insert(0, str(TOOLS_DIR))

import audit_orison_floor01_source_ownership as audit  # noqa: E402


LAYOUT_PATH = REPO_ROOT / audit.DEFAULT_LAYOUT
GLTF_PATH = REPO_ROOT / audit.DEFAULT_GLTF


class CanonicalIdentityTests(unittest.TestCase):
    def test_anonymous_hash_is_key_order_independent(self):
        left = {"pos": [1.25, -2.0, 3], "warm": True, "energy": 0.7}
        right = {"energy": 0.7, "warm": True, "pos": [1.25, -2.0, 3]}
        self.assertEqual(
            audit.anonymous_identity("F01", "site_lights", left),
            audit.anonymous_identity("F01", "site_lights", right))
        expected_payload = (
            '{"collection":"site_lights","floor_id":"F01",'
            '"record":{"energy":0.7,"pos":[1.25,-2.0,3],"warm":true},'
            '"schema":"orison-floor-source-anonymous-v1"}')
        expected = hashlib.sha256(expected_payload.encode("utf-8")).hexdigest()
        identity = audit.anonymous_identity("F01", "site_lights", left)
        self.assertEqual(identity["canonical_hash_sha256"], expected)
        self.assertTrue(identity["canonical_id"].endswith(expected.upper()))

    def test_duplicate_named_identity_is_refused(self):
        layout = json.loads(LAYOUT_PATH.read_text(encoding="utf-8"))
        floor = next(row for row in layout["floors"] if row["id"] == "F01")
        floor["markers"].append(copy.deepcopy(floor["markers"][0]))
        with self.assertRaisesRegex(audit.CensusError, "duplicate source identity"):
            audit.classify_layout(layout)

    def test_duplicate_anonymous_content_is_refused(self):
        layout = json.loads(LAYOUT_PATH.read_text(encoding="utf-8"))
        floor = next(row for row in layout["floors"] if row["id"] == "F01")
        floor["site_lights"].append(copy.deepcopy(floor["site_lights"][0]))
        with self.assertRaisesRegex(audit.CensusError, "duplicate source identity"):
            audit.classify_layout(layout)

    def test_duplicate_assignment_is_refused(self):
        rows = [
            {"source_locator": "a", "cell_id": audit.INTERIOR},
            {"source_locator": "a", "cell_id": audit.FACADE},
        ]
        with self.assertRaisesRegex(audit.CensusError, "not exact-once"):
            audit.validate_assignments(["a"], rows)


class RealSourceCensusTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.report = audit.build_report(LAYOUT_PATH, GLTF_PATH)
        cls.partition = cls.report["partition"]

    def test_report_passes_without_mutating_inputs(self):
        self.assertEqual(self.report["status"], "PASS")
        self.assertTrue(self.report["read_only"])
        self.assertTrue(self.partition["exact_once"])
        self.assertEqual(len(self.partition["cells"]), 17)
        self.assertEqual(len(set(self.partition["cells"])), 17)

    def test_expected_real_layout_totals(self):
        self.assertEqual(
            self.partition["source_totals"], audit.EXPECTED_SOURCE_TOTALS)
        self.assertEqual(self.partition["assignment_count"], 5286)

    def test_every_source_record_is_classified_exactly_once(self):
        assignments = self.partition["assignments"]
        locators = [row["source_locator"] for row in assignments]
        self.assertEqual(len(locators), len(set(locators)))
        self.assertTrue(all(row["cell_id"] in audit.CELLS for row in assignments))
        self.assertEqual(
            sum(self.partition["counts_by_cell"].values()), len(assignments))

    def test_cell_furniture_and_marker_totals(self):
        furniture = self.partition["counts_by_collection_and_cell"]["furniture"]
        markers = self.partition["counts_by_collection_and_cell"]["markers"]
        expected = {
            audit.INTERIOR: (297, 61),
            audit.FACADE: (26, 5),
            audit.STREET: (1620, 7),
            audit.PASSAGE: (486, 8),
            audit.BAR: (345, 29),
            audit.BODEGA: (155, 6),
            "SHOP_MODEL_LAUNDRY": (159, 7),
            "SHOP_SHOE_REBUILDING": (103, 6),
            "SHOP_KEYS_CUT": (182, 6),
            "SHOP_HARDWARE_PAINT": (224, 7),
            "SHOP_FUNERAL_PARLOUR": (115, 7),
            "SHOP_PHOTO_SUPPLIES": (120, 7),
            "SHOP_RADIO_SERVICE": (95, 6),
            "SHOP_PAWNBROKER": (117, 6),
            "SHOP_NEWS_CIGARS": (79, 6),
            "SHOP_OTIS___SON": (183, 7),
            "SHOP_LUNCHEONETTE": (109, 7),
        }
        for cell, (furniture_count, marker_count) in expected.items():
            self.assertEqual(furniture.get(cell, 0), furniture_count, cell)
            self.assertEqual(markers.get(cell, 0), marker_count, cell)

    def test_anonymous_identity_debt_is_complete_and_unique(self):
        receipt = self.partition["identity_debt_receipt"]
        self.assertEqual(receipt["status"], "UNRESOLVED_SOURCE_IDENTITY_DEBT")
        self.assertFalse(receipt["durable_source_identity"])
        self.assertEqual(
            receipt["counts"], {"site_lights": 565, "slabs": 1, "walls": 42})
        self.assertEqual(receipt["anonymous_record_count"], 608)
        rows = [row for values in receipt["records"].values() for row in values]
        self.assertEqual(len({row["canonical_id"] for row in rows}), 608)
        self.assertEqual(len({row["canonical_hash_sha256"] for row in rows}), 608)

    def test_anonymous_lights_overlap_broad_passage_shell_envelope(self):
        finding = self.partition["ambiguities"][0]
        self.assertEqual(
            finding["code"], "SITE_LIGHTS_OVERLAP_PASSAGE_SHELL_ENVELOPE")
        self.assertEqual(len(finding["records"]), 3)
        self.assertIn("does not prove Passage ownership", finding["finding"])

    def test_legacy_emission_keeps_mixed_assembly_debt_visible(self):
        categories = self.partition["expected_emitted_legacy_categories"]
        self.assertEqual(categories["LEGACY_FURNISH_ASM_MIXED"]["count"], 625)
        self.assertGreater(
            categories["LEGACY_FURNITURE_BOX_MIXED"]["count"], 1000)
        by_cell = categories["LEGACY_FURNISH_ASM_MIXED"]["counts_by_cell"]
        self.assertEqual(by_cell[audit.BAR], 133)
        self.assertEqual(by_cell[audit.BODEGA], 3)

    def test_runtime_passage_proxy_ruling_is_preserved(self):
        categories = self.partition["expected_emitted_legacy_categories"]
        self.assertEqual(categories["EXPLICIT_PASSAGE_BATCH"]["count"], 486)
        proxy = categories["EXPLICIT_STREET_PASSAGE_PROXY_BATCH"]
        self.assertEqual(proxy["count"], 322)
        self.assertEqual(proxy["counts_by_cell"], {audit.STREET: 322})
        finding = self.partition["ambiguities"][0]
        ruling = finding["production_runtime_ruling"]
        self.assertEqual(ruling["portal_plane_source_y"], -28.316)
        self.assertEqual(ruling["portal_plane_owner"], audit.STREET)

    def test_protected_gltf_reports_unresolved_mixed_provenance(self):
        protected = self.report["protected_legacy_gltf"]
        self.assertEqual(protected["topology"], audit.EXPECTED_GLTF)
        self.assertFalse(protected["legacy_mixed_provenance_resolved"])
        self.assertEqual(len(protected["legacy_mixed_node_names"]), 134)
        self.assertEqual(protected["scene_root_node_count"], 531)
        self.assertEqual(protected["nodes_with_authored_transform"], 0)
        self.assertEqual(protected["node_mesh_name_mismatches"], 0)
        self.assertEqual(protected["explicit_counts_by_cell"][audit.PASSAGE], 20)
        self.assertEqual(protected["explicit_counts_by_cell"][audit.STREET], 20)


if __name__ == "__main__":
    unittest.main()
