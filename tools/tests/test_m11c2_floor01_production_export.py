#!/usr/bin/env python3
"""Objective/refusal tests for the committed production F01 cell export."""

from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path, PurePosixPath
import sys
import tempfile
import unittest


REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tools.m11c1_floor01_owner_first.owner_first_export import (  # noqa: E402
    CELL_IDS,
    CELL_SLUGS,
)
from tools.m11c2_floor01_production.export_floor01_cells import (  # noqa: E402
    ADAPTER_REL,
    ALIASES_NAME,
    ASSET_MANIFEST_NAME,
    ASSET_ROOT_REL,
    DEFAULT_MODE,
    GENERATOR_REL,
    LEGACY_MODE,
    LEGACY_MONOLITH,
    LINEAGE_NAME,
    LINEAGE_REL,
    OWNERSHIP_REL,
    PRODUCTION_EXPORTER_REL,
    PROTECTED_RELATIVE_PATHS,
    REGISTRY_REL,
    SCHEMA_ALIASES,
    SCHEMA_ASSETS,
    SCHEMA_LINEAGE,
    SCHEMA_REGISTRY,
    STATUS_PASS,
    ProductionExportError,
    _assert_exact_destinations,
    _allowed_asset_names,
    _production_resource,
    collect_protected_hashes,
    validate_registry,
)


def load_json(path: Path) -> dict:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise AssertionError(f"JSON root is not an object: {path}")
    return value


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


class ProductionFloor01ExportTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.asset_root = REPO_ROOT.joinpath(*ASSET_ROOT_REL.parts)
        cls.registry_path = REPO_ROOT.joinpath(*REGISTRY_REL.parts)
        cls.registry = load_json(cls.registry_path)
        cls.assets = load_json(cls.asset_root / ASSET_MANIFEST_NAME)
        cls.aliases = load_json(cls.asset_root / ALIASES_NAME)
        cls.lineage_path = REPO_ROOT.joinpath(*LINEAGE_REL.parts)
        cls.lineage = load_json(cls.lineage_path)

    def test_registry_schema_modes_and_all_fields_validate(self):
        self.assertEqual(self.registry["schema"], SCHEMA_REGISTRY)
        self.assertEqual(self.registry["status"], STATUS_PASS)
        self.assertEqual(self.registry["default_mode"], DEFAULT_MODE)
        self.assertEqual(
            self.registry["supported_session_modes"],
            [DEFAULT_MODE, LEGACY_MODE])
        self.assertEqual(self.registry["legacy_monolith_path"], LEGACY_MONOLITH)
        self.assertFalse(self.registry["simultaneous_monolith_and_cells_allowed"])
        self.assertFalse(self.registry["session_mode_is_save_authority"])
        validate_registry(self.registry)

    def test_exact_seventeen_production_assets_and_metadata(self):
        self.assertEqual(self.assets["schema"], SCHEMA_ASSETS)
        self.assertEqual(self.assets["status"], STATUS_PASS)
        self.assertTrue(self.assets["production_asset"])
        self.assertEqual(self.assets["cell_count"], 17)
        self.assertEqual(
            [row["id"] for row in self.assets["cells"]], list(CELL_IDS))
        for row in self.assets["cells"]:
            cell_id = row["id"]
            slug = CELL_SLUGS[cell_id]
            gltf_path = self.asset_root / f"{slug}.gltf"
            bin_path = self.asset_root / f"{slug}.bin"
            self.assertEqual(row["resource_path"], _production_resource(slug))
            self.assertEqual(sha256_file(gltf_path), row["gltf_sha256"])
            self.assertEqual(sha256_file(bin_path), row["bin_sha256"])
            self.assertEqual(gltf_path.stat().st_size, row["gltf_bytes"])
            self.assertEqual(bin_path.stat().st_size, row["bin_bytes"])
            document = load_json(gltf_path)
            extras = document["asset"]["extras"]
            self.assertNotIn("orison_m11c1_candidate", extras)
            self.assertNotIn("orison_m11c1_owner_first", extras)
            production = extras["orison_floor01_owner_first"]
            self.assertEqual(production["cell_id"], cell_id)
            self.assertTrue(production["production_asset"])
            self.assertTrue(production["owner_before_material"])
            self.assertFalse(production["spatial_inference_used"])
            self.assertEqual(extras["orison_bin_sha256"], row["bin_sha256"])
            self.assertEqual(document["buffers"], [{
                "byteLength": row["bin_bytes"], "uri": f"{slug}.bin"}])
            for image in document.get("images", []):
                if "uri" in image and not str(image["uri"]).startswith("data:"):
                    self.assertTrue(str(image["uri"]).startswith("../textures/"))
                    self.assertNotIn("shared_textures", str(image["uri"]))

    def test_existing_texture_library_is_hash_bound_without_duplication(self):
        rows = self.assets["texture_bindings"]
        self.assertEqual(self.assets["texture_binding_count"], 304)
        self.assertEqual(len(rows), 304)
        self.assertEqual(
            [row["resource_path"] for row in rows],
            sorted(row["resource_path"] for row in rows))
        self.assertFalse((self.asset_root / "shared_textures").exists())
        for row in rows:
            prefix = "res://"
            self.assertTrue(row["resource_path"].startswith(prefix))
            path = REPO_ROOT / "game" / row["resource_path"][len(prefix):]
            self.assertTrue(path.is_file())
            self.assertEqual(sha256_file(path), row["sha256"])
            self.assertEqual(path.stat().st_size, row["bytes"])

    def test_complete_lineage_and_alias_manifests(self):
        self.assertEqual(self.lineage["schema"], SCHEMA_LINEAGE)
        self.assertEqual(self.lineage["status"], STATUS_PASS)
        self.assertTrue(self.lineage["production_asset"])
        self.assertTrue(self.lineage["lineage_complete"])
        self.assertEqual(self.lineage["counts"]["source_records"], 5286)
        self.assertEqual(self.lineage["counts"]["generated_sources"], 3)
        self.assertEqual(self.lineage["counts"]["generated_contributions"], 9820)
        self.assertEqual(self.lineage["counts"]["output_primitives"], 609)
        self.assertEqual(self.lineage["counts"]["output_triangles"], 183726)
        self.assertEqual(self.lineage["unresolved_lineage_records"], [])
        self.assertEqual(self.aliases["schema"], SCHEMA_ALIASES)
        self.assertEqual(self.aliases["status"], STATUS_PASS)
        self.assertEqual(self.aliases["identity_count"], 531)
        self.assertEqual(self.aliases["split_identity_count"], 47)
        self.assertEqual(len(self.aliases["split_identities"]), 47)
        self.assertEqual(self.aliases["incompatible_aliases"], [])
        self.assertEqual(
            self.registry["compatibility_alias_index"],
            {alias: [{
                "cell_id": target["cell_id"],
                "node_index": target["node_index"],
                "mesh_index": target["mesh_index"],
            } for target in targets]
             for alias, targets in self.aliases["aliases"].items()})

    def test_manifest_hashes_and_protected_inputs_are_current(self):
        generated = self.assets["generated_manifests"]
        self.assertEqual(
            sha256_file(self.lineage_path),
            generated["lineage"]["sha256"])
        self.assertEqual(generated["lineage"]["path"], LINEAGE_REL.as_posix())
        self.assertEqual(LINEAGE_REL.name, LINEAGE_NAME)
        self.assertEqual(
            self.registry["lineage_manifest_path"], LINEAGE_REL.as_posix())
        self.assertFalse(
            (self.asset_root / LINEAGE_NAME).exists(),
            "the lineage sidecar must not also live in the Godot asset root")
        self.assertEqual(
            sha256_file(self.asset_root / ALIASES_NAME),
            generated["compatibility_aliases"]["sha256"])
        self.assertEqual(
            sha256_file(self.asset_root / ASSET_MANIFEST_NAME),
            self.registry["asset_manifest_sha256"])
        self.assertEqual(self.assets["protected_hashes"],
                         collect_protected_hashes(REPO_ROOT))
        self.assertEqual(
            set(self.assets["protected_hashes"]),
            {path.as_posix() for path in PROTECTED_RELATIVE_PATHS})

    def test_single_source_ownership_authority_is_reused(self):
        exporter = (REPO_ROOT /
                    "tools/m11c2_floor01_production/"
                    "export_floor01_cells.py").read_text(encoding="utf-8")
        self.assertEqual(
            OWNERSHIP_REL.as_posix(),
            "art/data/m11c1/floor01_source_ownership.json")
        self.assertIn("OWNERSHIP_REL", exporter)
        self.assertFalse(any(
            path.name.endswith("ownership.json")
            for path in (REPO_ROOT / "tools/m11c2_floor01_production").rglob("*")
            if path.is_file()))
        self.assertEqual(
            self.assets["authoritative_inputs"]["ownership"],
            sha256_file(REPO_ROOT.joinpath(*OWNERSHIP_REL.parts)))
        self.assertEqual(
            self.assets["authoritative_inputs"]["generator"],
            sha256_file(REPO_ROOT.joinpath(*GENERATOR_REL.parts)))
        self.assertEqual(
            self.assets["authoritative_inputs"]["generator_adapter"],
            sha256_file(REPO_ROOT.joinpath(*ADAPTER_REL.parts)))
        self.assertEqual(
            self.assets["authoritative_inputs"]["production_exporter"],
            sha256_file(REPO_ROOT.joinpath(*PRODUCTION_EXPORTER_REL.parts)))

    def test_unknown_cell_and_dependency_cycle_are_refused(self):
        unknown = copy.deepcopy(self.registry)
        unknown["cells"][0]["id"] = "CELL_UNKNOWN"
        with self.assertRaisesRegex(ProductionExportError, "duplicate/unknown"):
            validate_registry(unknown)
        cycle = copy.deepcopy(self.registry)
        cycle["cells"][0]["dependencies"] = [cycle["cells"][1]["id"]]
        cycle["cells"][1]["dependencies"] = [cycle["cells"][0]["id"]]
        with self.assertRaisesRegex(ProductionExportError, "dependency cycle"):
            validate_registry(cycle)

    def test_duplicate_semantic_and_incompatible_alias_are_refused(self):
        duplicate = copy.deepcopy(self.registry)
        identity = duplicate["cells"][0]["semantic_owners"][0]
        duplicate["cells"][1]["semantic_owners"].append(identity)
        with self.assertRaisesRegex(ProductionExportError,
                                    "duplicate/incompatible"):
            validate_registry(duplicate)
        incompatible = copy.deepcopy(self.registry)
        alias = next(iter(incompatible["compatibility_alias_index"]))
        incompatible["compatibility_alias_index"][alias].append(
            copy.deepcopy(incompatible["compatibility_alias_index"][alias][0]))
        with self.assertRaisesRegex(ProductionExportError, "incompatible"):
            validate_registry(incompatible)

    def test_simultaneous_monolith_and_cells_is_refused(self):
        value = copy.deepcopy(self.registry)
        value["simultaneous_monolith_and_cells_allowed"] = True
        with self.assertRaisesRegex(ProductionExportError, "header or mode"):
            validate_registry(value)

    def test_exact_destination_allowlist_refuses_unowned_file(self):
        artifacts = {
            ASSET_ROOT_REL / name: b"" for name in _allowed_asset_names()
        }
        artifacts[LINEAGE_REL] = b""
        artifacts[REGISTRY_REL] = b""
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            asset_root = root.joinpath(*ASSET_ROOT_REL.parts)
            asset_root.mkdir(parents=True)
            (asset_root / "unowned.json").write_text("{}\n", encoding="utf-8")
            with self.assertRaisesRegex(ProductionExportError, "unowned files"):
                _assert_exact_destinations(artifacts, root)

    def test_committed_asset_allowlist_is_exact(self):
        expected = _allowed_asset_names()
        actual = {
            path.name for path in self.asset_root.iterdir()
            if path.is_file() and path.suffix != ".import"
        }
        self.assertEqual(actual, expected)
        self.assertEqual(len(expected), 36)
        self.assertEqual(
            set(self.registry["semantic_owner_index"]),
            {row["identity"] for row in self.lineage["semantic_owners"]})


if __name__ == "__main__":
    unittest.main()
