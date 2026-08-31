#!/usr/bin/env python3
"""Objective tests for the disposable M11C0 floor_01 partition rehearsal."""

from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import struct
import sys
import tempfile
import unittest


REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tools.rehearse_orison_floor01_partition import (  # noqa: E402
    RehearsalError,
    run_rehearsal,
)


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


class Floor01PartitionRehearsalTests(unittest.TestCase):
    """Exercise whole-node assignment, dependency remap, and refusal gates."""

    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.source_dir = self.root / "source"
        self.source_dir.mkdir()
        (self.source_dir / "textures").mkdir()

        position_a = struct.pack(
            "<9f", 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0)
        indices = struct.pack("<3H", 0, 1, 2)
        padding = b"\x00\x00"
        position_mixed = struct.pack(
            "<9f", -1.0, 0.0, -1.0, 0.0, 0.0, -1.0, -1.0, 1.0, -1.0)
        self.bin_bytes = position_a + indices + padding + position_mixed
        self.bin_path = self.source_dir / "floor_01.bin"
        self.bin_path.write_bytes(self.bin_bytes)
        self.texture_bytes = b"synthetic-rehearsal-image"
        (self.source_dir / "textures" / "shop.dat").write_bytes(
            self.texture_bytes)

        self.document = {
            "asset": {"version": "2.0", "generator": "M11C0 synthetic test"},
            "scene": 0,
            "scenes": [{"nodes": [0, 1, 2]}],
            "nodes": [
                {"name": "A_surface-col", "mesh": 0},
                {"name": "B_surface-col", "mesh": 1,
                 "translation": [2.0, 0.0, 0.0]},
                {"name": "F01_furnish_welded-col", "mesh": 2,
                 "translation": [0.0, 0.0, 3.0]},
            ],
            "meshes": [
                {"name": "mesh_a", "primitives": [{
                    "attributes": {"POSITION": 0}, "indices": 1,
                    "material": 0,
                }]},
                {"name": "mesh_b", "primitives": [{
                    "attributes": {"POSITION": 0}, "indices": 1,
                    "material": 1,
                }]},
                {"name": "mesh_mixed", "primitives": [{
                    "attributes": {"POSITION": 2}, "indices": 1,
                    "material": 0,
                }]},
            ],
            "accessors": [
                {"bufferView": 0, "componentType": 5126, "count": 3,
                 "type": "VEC3", "min": [0.0, 0.0, 0.0],
                 "max": [1.0, 1.0, 0.0]},
                {"bufferView": 1, "componentType": 5123, "count": 3,
                 "type": "SCALAR", "min": [0], "max": [2]},
                {"bufferView": 2, "componentType": 5126, "count": 3,
                 "type": "VEC3", "min": [-1.0, 0.0, -1.0],
                 "max": [0.0, 1.0, -1.0]},
            ],
            "bufferViews": [
                {"buffer": 0, "byteOffset": 0, "byteLength": 36,
                 "target": 34962},
                {"buffer": 0, "byteOffset": 36, "byteLength": 6,
                 "target": 34963},
                {"buffer": 0, "byteOffset": 44, "byteLength": 36,
                 "target": 34962},
            ],
            "buffers": [{"uri": "floor_01.bin", "byteLength": 80}],
            "materials": [
                {"name": "paint_a", "pbrMetallicRoughness": {
                    "baseColorTexture": {"index": 0},
                    "roughnessFactor": 0.8,
                }},
                {"name": "paint_b", "pbrMetallicRoughness": {
                    "baseColorTexture": {"index": 0},
                    "roughnessFactor": 0.5,
                }},
            ],
            "textures": [{"source": 0, "sampler": 0}],
            "images": [{"uri": "textures/shop.dat"}],
            "samplers": [{}],
        }
        self.gltf_path = self.source_dir / "floor_01.gltf"
        _write_json(self.gltf_path, self.document)
        self.source_hashes = (_sha256(self.gltf_path), _sha256(self.bin_path))

        self.manifest = {
            "schema_version": 2,
            "source": {
                "gltf": "ignored-because-test-passes-source.gltf",
                "gltf_sha256": self.source_hashes[0],
                "bin_sha256": self.source_hashes[1],
            },
            # Spatial target design is intentionally inert to this tool.
            "target_partition": {
                "cells": [{"id": "TARGET_ONLY"}],
                "rules": [{"bounds": [[0, 0, 0], [1, 1, 1]]}],
            },
            "safe_current_partition": {
                "cells": [
                    {"id": "CELL_A", "slug": "cell_a", "expected_nodes": 1},
                    {"id": "CELL_B", "slug": "cell_b", "expected_nodes": 1},
                    {"id": "CELL_LEGACY_MIXED", "slug": "legacy_mixed",
                     "expected_nodes": 1},
                ],
                "ordered_node_rules": [
                    {"id": "a", "match": {"prefix": "A_"},
                     "cell": "CELL_A"},
                    {"id": "b", "match": {"exact": "B_surface-col"},
                     "cell": "CELL_B"},
                    {"id": "mixed", "match": {"fallback": True},
                     "cell": "CELL_LEGACY_MIXED"},
                ],
                "invariants": {"expected_total_nodes": 3},
            },
        }
        self.manifest_path = self.root / "manifest.json"
        _write_json(self.manifest_path, self.manifest)

    def tearDown(self) -> None:
        self.temp.cleanup()

    def _assert_source_unchanged(self) -> None:
        self.assertEqual(
            self.source_hashes,
            (_sha256(self.gltf_path), _sha256(self.bin_path)),
        )

    def _run(self, name: str = "output", analyze_only: bool = False):
        return run_rehearsal(
            self.manifest_path,
            self.root / name,
            source_gltf=self.gltf_path,
            analyze_only=analyze_only,
        )

    def test_exact_partition_compacts_and_duplicates_shared_dependencies(self) -> None:
        summary = self._run()
        output = self.root / "output"

        self.assertEqual("PASS", summary["status"])
        self.assertEqual(3, summary["assigned_nodes"])
        self.assertEqual(3, summary["recomposed_primitives"])
        self.assertEqual(1, summary["legacy_mixed"]["node_count"])
        self.assertTrue(summary["protected_hashes"]["unchanged"])
        self._assert_source_unchanged()

        cell_a = json.loads(
            (output / "cells" / "cell_a.gltf").read_text(encoding="utf-8"))
        cell_b = json.loads(
            (output / "cells" / "cell_b.gltf").read_text(encoding="utf-8"))
        for cell in (cell_a, cell_b):
            self.assertEqual(2, len(cell["accessors"]))
            self.assertEqual({"POSITION": 0},
                             cell["meshes"][0]["primitives"][0]["attributes"])
            self.assertEqual(1, cell["meshes"][0]["primitives"][0]["indices"])
            self.assertTrue(all(
                int(view.get("byteOffset", 0)) % 4 == 0
                for view in cell["bufferViews"]
            ))
            self.assertEqual(
                "../shared_textures/textures/shop.dat",
                cell["images"][0]["uri"],
            )
        self.assertEqual(
            self.texture_bytes,
            (output / "shared_textures" / "textures" / "shop.dat").read_bytes(),
        )
        split_receipt = json.loads(
            (output / "split_receipt.json").read_text(encoding="utf-8"))
        self.assertEqual(
            "res://original/floor_01.gltf",
            split_receipt["source"]["gltf_path"],
        )
        self.assertEqual(3, len(split_receipt["cells"]))
        self.assertEqual(
            {"id", "slug", "gltf_path", "bin_path"},
            set(split_receipt["cells"][0]),
        )
        self.assertTrue(all(
            row["gltf_path"].startswith("res://cells/")
            and row["bin_path"].startswith("res://cells/")
            for row in split_receipt["cells"]
        ))
        self.assertEqual([], split_receipt["capture_views"])
        self.assertEqual([], split_receipt["collision_probes"])
        self.assertEqual(7, len(split_receipt["harness_templates"]))
        self.assertEqual(
            self.gltf_path.read_bytes(),
            (output / "original" / "floor_01.gltf").read_bytes(),
        )
        self.assertEqual(
            self.bin_path.read_bytes(),
            (output / "original" / "floor_01.bin").read_bytes(),
        )
        self.assertFalse((output / ".godot").exists())
        self.assertTrue((output / "project.godot").is_file())
        self.assertTrue((output / "partition_manifest.json").is_file())

        assignment = json.loads((
            output / "receipts" / "floor01_assignment.json"
        ).read_text(encoding="utf-8"))
        self.assertFalse(assignment["target_partition_consumed"])
        self.assertEqual([0, 1, 2], sorted(
            row["node_index"] for row in assignment["assignments"]))
        self.assertEqual([], assignment["ambiguous"])
        self.assertEqual([], assignment["unassigned"])
        self.assertEqual([], assignment["duplicate_assignments"])

        recomposition = json.loads((
            output / "receipts" / "floor01_recomposition.json"
        ).read_text(encoding="utf-8"))
        self.assertEqual("PASS", recomposition["status"])
        self.assertEqual(3, recomposition["source_node_count"])
        self.assertEqual(3, recomposition["recomposed_node_count"])
        self.assertEqual(3, recomposition["source_primitive_count"])
        self.assertEqual(3, recomposition["recomposed_primitive_count"])
        self.assertEqual(
            3,
            recomposition["dependency_duplication"]["cross_cell_accessor_copies"],
        )
        self.assertTrue(all(
            row["match"]
            for rows in recomposition["canonical_copies"].values()
            for row in rows
        ))

    def test_analyze_only_emits_receipts_without_cells_or_textures(self) -> None:
        summary = self._run("analysis", analyze_only=True)
        output = self.root / "analysis"
        self.assertTrue(summary["analyze_only"])
        self.assertTrue((output / "receipts" / "floor01_census.json").is_file())
        self.assertFalse((output / "cells").exists())
        self.assertFalse((output / "shared_textures").exists())
        self.assertFalse((output / "split_receipt.json").exists())
        self.assertFalse((output / "project.godot").exists())
        measurements = json.loads((
            output / "receipts" / "floor01_measurements.json"
        ).read_text(encoding="utf-8"))
        self.assertFalse(measurements["shared_texture_library"]["copied"])
        self._assert_source_unchanged()

    def test_ambiguous_rules_fail_closed_without_touching_source(self) -> None:
        value = copy.deepcopy(self.manifest)
        value["safe_current_partition"]["ordered_node_rules"].insert(1, {
            "id": "also_a", "match": {"prefix": "A_surface"},
            "cell": "CELL_B",
        })
        _write_json(self.manifest_path, value)
        with self.assertRaisesRegex(RehearsalError, "ambiguous"):
            self._run("ambiguous")
        self._assert_source_unchanged()

    def test_unassigned_node_fails_closed_without_touching_source(self) -> None:
        value = copy.deepcopy(self.manifest)
        value["safe_current_partition"]["ordered_node_rules"] = value[
            "safe_current_partition"]["ordered_node_rules"][:-1]
        _write_json(self.manifest_path, value)
        with self.assertRaisesRegex(RehearsalError, "unassigned"):
            self._run("unassigned")
        self._assert_source_unchanged()

    def test_spatial_safe_current_rule_is_refused(self) -> None:
        value = copy.deepcopy(self.manifest)
        value["safe_current_partition"]["ordered_node_rules"][0][
            "bounds"] = [[0, 0, 0], [1, 1, 1]]
        _write_json(self.manifest_path, value)
        with self.assertRaisesRegex(RehearsalError, "spatial/primitive"):
            self._run("spatial")
        self._assert_source_unchanged()


if __name__ == "__main__":
    unittest.main()
