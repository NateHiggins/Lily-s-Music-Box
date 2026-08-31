#!/usr/bin/env python3
"""Focused objective/refusal tests for disposable M11C1 owner-first export."""

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

from tools.rehearse_orison_floor01_partition import load_asset, validate_source
from tools.m11c1_floor01_owner_first.owner_first_export import (
    CELL_IDS,
    OwnerFirstError,
    _assert_disposable_output,
    _validate_expected_input_bindings,
    bind_candidate_triangle_slices,
    prove_equivalence,
    validate_catalog_rows,
    verify_transaction_artifact_closure,
)


def _align(buffer: bytearray) -> None:
    while len(buffer) % 4:
        buffer.append(0)


Point3 = tuple[float, float, float]
Triangle3 = tuple[Point3, Point3, Point3]


def _write_asset(
        root: Path, name: str,
        node_specs: list[tuple[str, list[Triangle3]]],
) -> Path:
    buffer = bytearray()
    views = []
    accessors = []
    meshes = []
    nodes = []

    def add_accessor(payload: bytes, component_type: int, count: int,
                     accessor_type: str, target: int,
                     minimum=None, maximum=None) -> int:
        _align(buffer)
        offset = len(buffer)
        buffer.extend(payload)
        view_index = len(views)
        views.append({
            "buffer": 0, "byteOffset": offset, "byteLength": len(payload),
            "target": target,
        })
        value = {
            "bufferView": view_index,
            "componentType": component_type,
            "count": count,
            "type": accessor_type,
        }
        if minimum is not None:
            value["min"] = minimum
        if maximum is not None:
            value["max"] = maximum
        accessors.append(value)
        return len(accessors) - 1

    for node_name, triangles in node_specs:
        positions = [point for triangle in triangles for point in triangle]
        normals = [(0.0, 0.0, 1.0)] * len(positions)
        uvs = [(0.0, 0.0), (1.0, 0.0), (0.0, 1.0)] * len(triangles)
        position_accessor = add_accessor(
            b"".join(struct.pack("<3f", *value) for value in positions),
            5126, len(positions), "VEC3", 34962,
            [min(value[axis] for value in positions) for axis in range(3)],
            [max(value[axis] for value in positions) for axis in range(3)],
        )
        normal_accessor = add_accessor(
            b"".join(struct.pack("<3f", *value) for value in normals),
            5126, len(normals), "VEC3", 34962,
        )
        uv_accessor = add_accessor(
            b"".join(struct.pack("<2f", *value) for value in uvs),
            5126, len(uvs), "VEC2", 34962,
        )
        index_accessor = add_accessor(
            b"".join(struct.pack("<H", index)
                     for index in range(len(positions))),
            5123, len(positions), "SCALAR", 34963,
        )
        mesh_index = len(meshes)
        meshes.append({
            "name": node_name,
            "primitives": [{
                "attributes": {
                    "POSITION": position_accessor,
                    "NORMAL": normal_accessor,
                    "TEXCOORD_0": uv_accessor,
                },
                "indices": index_accessor,
                "material": 0,
            }],
        })
        nodes.append({"name": node_name, "mesh": mesh_index})
    _align(buffer)
    document = {
        "asset": {"version": "2.0", "generator": "M11C1 synthetic"},
        "scene": 0,
        "scenes": [{"nodes": list(range(len(nodes)))}],
        "nodes": nodes,
        "meshes": meshes,
        "accessors": accessors,
        "bufferViews": views,
        "buffers": [{"uri": f"{name}.bin", "byteLength": len(buffer)}],
        "materials": [{
            "name": "M_mat",
            "pbrMetallicRoughness": {
                "baseColorFactor": [0.4, 0.5, 0.6, 1.0],
                "metallicFactor": 0.0,
                "roughnessFactor": 0.75,
            },
        }],
        "textures": [],
        "images": [],
        "samplers": [],
    }
    gltf = root / f"{name}.gltf"
    gltf.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    (root / f"{name}.bin").write_bytes(bytes(buffer))
    return gltf


TRIANGLE_A = ((0.0, 0.0, 0.0), (1.0, 0.0, 0.0), (0.0, 1.0, 0.0))
TRIANGLE_B = ((2.0, 0.0, 0.0), (3.0, 0.0, 0.0), (2.0, 1.0, 0.0))


class PayloadEquivalenceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.protected_path = _write_asset(
            self.root, "protected", [("F01_shared", [TRIANGLE_A, TRIANGLE_B])])
        self.candidate_path = _write_asset(
            self.root, "candidate",
            [("Owned_A", [TRIANGLE_A]), ("Owned_B", [TRIANGLE_B])],
        )
        self.protected = load_asset(self.protected_path)
        self.candidate = load_asset(self.candidate_path)
        validate_source(self.protected)
        validate_source(self.candidate)
        self.validated = {
            "assignments": [
                {
                    "buffer_id": "BUFFER_A", "node_index": 0,
                    "cell": CELL_IDS[0],
                    "legacy_compatibility_identity": "F01_shared",
                },
                {
                    "buffer_id": "BUFFER_B", "node_index": 1,
                    "cell": CELL_IDS[1],
                    "legacy_compatibility_identity": "F01_shared",
                },
            ],
        }

    def tearDown(self):
        self.temp.cleanup()

    def test_decoded_vertex_triangle_material_and_alias_union_equivalence(self):
        receipt = prove_equivalence(
            self.protected, self.candidate, self.validated)
        self.assertEqual("PASS", receipt["status"])
        self.assertTrue(all(receipt["checks"].values()))
        alias = receipt["legacy_alias_equivalence"]
        self.assertEqual(1, alias["protected_legacy_identities"])
        self.assertEqual(1, alias["one_to_many_split_identities"])
        self.assertEqual(2, len(alias["rows"][0]["candidate_batches"]))

    def test_payload_change_is_refused_even_when_counts_and_bounds_can_match(self):
        changed = _write_asset(
            self.root, "changed",
            [("Owned_A", [TRIANGLE_A]),
             ("Owned_B", [((2.0, 0.0, 0.0), (3.0, 0.0, 0.0),
                           (2.0, 0.5, 0.0))])],
        )
        with self.assertRaisesRegex(OwnerFirstError, "not canonically equivalent"):
            prove_equivalence(
                self.protected, load_asset(changed), self.validated)

    def test_legacy_alias_spoof_is_refused(self):
        spoofed = copy.deepcopy(self.validated)
        spoofed["assignments"][1]["legacy_compatibility_identity"] = "F01_other"
        with self.assertRaisesRegex(OwnerFirstError, "alias vocabulary differs"):
            prove_equivalence(self.protected, self.candidate, spoofed)


class TriangleBindingTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.candidate = _write_asset(
            self.root, "candidate",
            [("Owned_A", [TRIANGLE_A, TRIANGLE_B])],
        )
        self.lineage_path = self.root / "generated_owner_lineage.json"
        self.lineage = {
            "buffers": [{
                "object_name": "Owned_A",
                "contributions": [
                    {"generated_range": {"triangles": {"start": 0, "count": 1}}},
                    {"generated_range": {"triangles": {"start": 1, "count": 1}}},
                ],
            }],
        }
        self.lineage_path.write_text(
            json.dumps(self.lineage, indent=2) + "\n", encoding="utf-8")

    def tearDown(self):
        self.temp.cleanup()

    def test_ranges_bind_to_distinct_decoded_post_export_slices(self):
        bound = bind_candidate_triangle_slices(
            self.candidate, self.lineage_path)
        hashes = [row["post_export_triangle_payload_sha256"]
                  for row in bound["buffers"][0]["contributions"]]
        self.assertEqual(2, len(set(hashes)))
        self.assertTrue(all(len(value) == 64 for value in hashes))

    def test_noncontiguous_triangle_range_is_refused(self):
        self.lineage["buffers"][0]["contributions"][1][
            "generated_range"]["triangles"]["start"] = 2
        self.lineage_path.write_text(
            json.dumps(self.lineage), encoding="utf-8")
        with self.assertRaisesRegex(OwnerFirstError, "invalid triangle range"):
            bind_candidate_triangle_slices(self.candidate, self.lineage_path)


class RefusalBoundaryTests(unittest.TestCase):
    def test_transaction_refuses_unbound_json_receipt(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve()
            run_id = "M11C1-transaction-test"
            lineage = root / "candidate/generated_owner_lineage.json"
            lineage.parent.mkdir(parents=True)
            lineage.write_text("{}\n", encoding="utf-8")
            receipt = root / "receipts/bound.json"
            receipt.parent.mkdir(parents=True)
            receipt_value = {
                "schema": "orison.test.bound.v1",
                "status": "PASS",
                "run_id": run_id,
                "disposable_root": str(root),
            }
            receipt.write_text(
                json.dumps(receipt_value) + "\n", encoding="utf-8")
            digest = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
            transaction = {
                "run_id": run_id,
                "candidate": {
                    "generated_lineage_path": str(lineage),
                    "generated_lineage_sha256": digest(lineage),
                },
                "artifacts": {
                    "receipts/bound.json": {
                        "relative_path": "receipts/bound.json",
                        "sha256": digest(receipt),
                        "schema": receipt_value["schema"],
                        "status": "PASS",
                    },
                },
            }
            transaction_path = (
                root / "receipts/floor01_owner_first_transaction.json")
            verify_transaction_artifact_closure(
                root, transaction, transaction_path)
            (root / "receipts/unbound.json").write_text(
                json.dumps({"schema": "orison.test.stray.v1"}) + "\n",
                encoding="utf-8",
            )
            with self.assertRaisesRegex(OwnerFirstError, "unbound="):
                verify_transaction_artifact_closure(
                    root, transaction, transaction_path)

    def test_nested_adapter_binding_drift_is_refused(self):
        expected = {
            "generator": {"path": "generator.py", "sha256": "a" * 64},
            "adapter": {"path": "adapter.py", "sha256": "b" * 64},
        }
        inputs = {"generator": copy.deepcopy(expected["generator"])}
        producer = {"adapter": {"path": "adapter.py", "sha256": "c" * 64}}
        with self.assertRaisesRegex(OwnerFirstError, "adapter binding drifted"):
            _validate_expected_input_bindings(inputs, producer, expected)

    def test_catalog_unknown_owner_is_refused(self):
        row = {
            "source_id": "SOURCE_A",
            "source_locator": "floors[F01].furniture[0]",
            "collection": "furniture",
            "source_record_sha256": "a" * 64,
            "owner_cell": "CELL_SPATIAL_GUESS",
            "identity_origin": "AUTHORED_RECORD_ID",
            "authoring_context": "EXPLICIT_TEST_CONTEXT",
        }
        with self.assertRaisesRegex(OwnerFirstError, "undeclared owner_cell"):
            validate_catalog_rows({row["source_locator"]: row})

    def test_output_inside_protected_asset_directory_is_refused(self):
        protected = REPO_ROOT / "game/assets/building/floor_01.gltf"
        output = protected.parent / "m11c1_forbidden"
        with self.assertRaisesRegex(OwnerFirstError, "protected asset directory"):
            _assert_disposable_output(output, protected)

    def test_output_anywhere_inside_repo_is_refused(self):
        protected = REPO_ROOT / "game/assets/building/floor_01.gltf"
        output = REPO_ROOT / "tmp/m11c1_forbidden"
        with self.assertRaisesRegex(OwnerFirstError, "external disposable root"):
            _assert_disposable_output(output, protected)


if __name__ == "__main__":
    unittest.main()
