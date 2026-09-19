#!/usr/bin/env python3
from __future__ import annotations

import copy
import json
import sys
import tempfile
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS))
import build_v2_authoring_projection as projection


class V2AuthoringProjectionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.root = TOOLS.parent
        cls.sources = {name: json.loads((cls.root / projection.source_path(name)).read_text(encoding="utf-8"))
                       for name in projection.PROJECTIONS}
        cls.generated = projection.outputs(cls.root)

    def test_checked_in_runtime_and_proofs_are_current(self):
        self.assertEqual([], projection.stale_outputs(self.root, self.generated))

    def test_every_original_value_survives_in_runtime_or_authoring_metadata(self):
        # Reconstruct every original record, including large vertex/normal arrays,
        # to ensure this split cannot silently drop geometry or owner information.
        for name, source in self.sources.items():
            with self.subTest(name=name):
                runtime, metadata = projection.project(name, source)
                rebuilt = copy.deepcopy(runtime)
                collection, identity_key, fields = projection.PROJECTIONS[name]
                if collection is None:
                    rebuilt.update(metadata)
                else:
                    for row in rebuilt[collection]:
                        self.assertTrue(all(field not in row for field in fields))
                        row.update(metadata.get(row[identity_key], {}))
                self.assertEqual(source, rebuilt)

    def test_proof_identities_match_the_runtime_rosters(self):
        proof = json.loads(self.generated[projection.PROOF_PATH])
        for name in ["domestic_radios", "household_accessories"]:
            collection, identity_key, _ = projection.PROJECTIONS[name]
            rows = json.loads(self.generated[projection.runtime_path(name)])[collection]
            self.assertEqual({row[identity_key] for row in rows}, set(proof[collection]))
        for row in self.sources["domestic_furniture"]["furniture"]:
            if row["kind"] == "cupboard":
                self.assertEqual("upper_cabinet", proof["furniture"][row["id"]]["source_component"]["component"])

    def test_changed_runtime_owner_and_missing_proof_are_rejected_as_stale(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            name = projection.runtime_path("domestic_radios")
            path = root / name
            path.parent.mkdir(parents=True)
            runtime = json.loads(self.generated[name])
            runtime["receivers"][0]["support"] = "WRONG_OWNER"
            path.write_text(projection.render(runtime), encoding="utf-8")
            expected = {name: self.generated[name], projection.PROOF_PATH: self.generated[projection.PROOF_PATH]}
            self.assertEqual(set(expected), set(projection.stale_outputs(root, expected)))

    def test_authoring_proof_mutation_changes_proof_without_changing_runtime(self):
        original = self.sources["domestic_radios"]
        changed = copy.deepcopy(original)
        changed["receivers"][0]["bounds"][1][1] += 0.5
        old_runtime, old_proof = projection.project("domestic_radios", original)
        new_runtime, new_proof = projection.project("domestic_radios", changed)
        self.assertEqual(old_runtime, new_runtime)
        self.assertNotEqual(old_proof, new_proof)
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            path = root / projection.PROOF_PATH
            path.parent.mkdir(parents=True)
            path.write_text(projection.render(old_proof), encoding="utf-8")
            self.assertEqual([projection.PROOF_PATH], projection.stale_outputs(
                root, {projection.PROOF_PATH: projection.render(new_proof)}))

    def test_source_geometry_and_owner_changes_reach_runtime(self):
        original = self.sources["domestic_radios"]
        changed = copy.deepcopy(original)
        changed["receivers"][0]["position"][0] += 0.1
        changed["receivers"][0]["support"] = "NEW_AUTHORED_OWNER"
        runtime, _ = projection.project("domestic_radios", changed)
        self.assertEqual(changed["receivers"][0]["position"], runtime["receivers"][0]["position"])
        self.assertEqual("NEW_AUTHORED_OWNER", runtime["receivers"][0]["support"])
        self.assertNotEqual(projection.project("domestic_radios", original)[0], runtime)

    def test_projection_is_scoped_to_the_named_record_fields(self):
        source = {"schema_version": 1, "receivers": [{"id": "A", "bounds": [[0], [1]],
                  "mechanism": {"bounds": [99], "intent": "runtime meaning"}}],
                  "other": {"bounds": [17]}}
        runtime, proof = projection.project("domestic_radios", source)
        self.assertEqual({"bounds": [99], "intent": "runtime meaning"}, runtime["receivers"][0]["mechanism"])
        self.assertEqual(source["other"], runtime["other"])
        self.assertEqual({"A": {"bounds": [[0], [1]]}}, proof)

    def test_missing_duplicate_or_nonstring_identity_cannot_overwrite_metadata(self):
        for identity in [None, "", 1, "DUPLICATE"]:
            rows = [{"id": "DUPLICATE", "bounds": [0]}, {"id": identity, "bounds": [1]}]
            with self.subTest(identity=identity), self.assertRaises(ValueError):
                projection.project("domestic_radios", {"schema_version": 1, "receivers": rows})
        for source in [{}, {"schema_version": True, "receivers": []}, {"schema_version": 1, "receivers": []}]:
            with self.assertRaises(ValueError):
                projection.project("domestic_radios", source)


if __name__ == "__main__":
    unittest.main()
