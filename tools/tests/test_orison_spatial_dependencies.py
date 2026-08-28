#!/usr/bin/env python3
"""Focused self-tests for tools/audit_orison_spatial_dependencies.py.

Runs against synthetic fixtures (a mini repo copied to a temp dir per
mutating test) plus a small read-only production smoke section at the end.
Production sources are never modified.  Execute with:

    python tools/tests/test_orison_spatial_dependencies.py
"""

from __future__ import annotations

import io
import json
import shutil
import sys
import tempfile
import unittest
from contextlib import redirect_stdout, redirect_stderr
from pathlib import Path

TOOLS_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = TOOLS_DIR.parent
sys.path.insert(0, str(TOOLS_DIR))

import audit_orison_spatial_dependencies as audit  # noqa: E402

FIXTURES = Path(__file__).resolve().parent / "fixtures" / \
    "spatial_dependencies"
MINI_REPO = FIXTURES / "mini_repo"
MINI_LAYOUT = "art/data/building_layout.json"


def run_main(*argv):
    out, err = io.StringIO(), io.StringIO()
    with redirect_stdout(out), redirect_stderr(err):
        code = audit.main(list(argv))
    return code, out.getvalue(), err.getvalue()


def scan(root: Path):
    meta, records = audit.scan_repository(
        root, root / MINI_LAYOUT, include_tests=True, production_only=False)
    return meta, records


def rec(records, **want):
    hits = [r for r in records
            if all(r.get(k) == v for k, v in want.items())]
    return hits


class TempRepo:
    """Copy of the mini repo the test may freely mutate."""

    def __enter__(self) -> Path:
        self._dir = tempfile.mkdtemp(prefix="spatial_deps_")
        self.root = Path(self._dir) / "repo"
        shutil.copytree(MINI_REPO, self.root)
        return self.root

    def __exit__(self, *exc):
        shutil.rmtree(self._dir, ignore_errors=True)


def write_manifest(root: Path) -> Path:
    manifest = root / "manifest.json"
    code, _, err = run_main("--root", str(root), "--layout", MINI_LAYOUT,
                            "--manifest", str(manifest),
                            "--update-manifest")
    assert code == 0, err
    return manifest


class ScanTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.meta, cls.records = scan(MINI_REPO)

    def test_valid_room_id_lookup(self):
        hits = rec(self.records, kind="id_reference", token="F01_LOBBY",
                   file="game/scripts/building/mini_root.gd")
        self.assertEqual(len(hits), 1)
        record = hits[0]
        self.assertTrue(record["target_exists"])
        self.assertIn("ROOM_MEMBERSHIP", record["spatial"])
        self.assertIn("RUNTIME_LOOKUP", record["authority"])
        self.assertEqual(record["tier"], "production")

    def test_missing_room_id_is_candidate(self):
        hits = rec(self.records, kind="id_candidate",
                   token="F01_MISSING_ROOM")
        self.assertEqual(len(hits), 1)
        self.assertIs(hits[0]["target_exists"], False)
        self.assertIn("UNKNOWN_DYNAMIC", hits[0]["spatial"])
        self.assertEqual(hits[0]["disposition"], "UNRESOLVED")

    def test_runtime_created_identifier(self):
        hits = rec(self.records, kind="runtime_id",
                   token="F01_NIGHT_REGISTER")
        self.assertEqual(len(hits), 1)
        self.assertIn("GENERATED_IDENTITY", hits[0]["authority"])
        self.assertEqual(hits[0]["disposition"], "MUST_PRESERVE_ID")

    def test_save_field_anchor_id_via_known_contract(self):
        hits = rec(self.records, kind="id_reference",
                   token="1A_FRIDGE_FACE",
                   file="game/scripts/cases/mina_caption_manifestation.gd")
        self.assertEqual(len(hits), 1)
        self.assertIn("SAVE_CONTRACT", hits[0]["authority"])
        self.assertEqual(hits[0]["confidence"], "HIGH")

    def test_b2g_gameplay_coordinate(self):
        hits = rec(self.records, kind="plan_coordinate",
                   file="game/scripts/building/mini_root.gd")
        self.assertEqual(len(hits), 1)
        self.assertIn("RAW_PLAN_COORDINATE", hits[0]["spatial"])
        self.assertEqual(hits[0]["disposition"],
                         "REPLACE_WITH_NAMED_ANCHOR")

    def test_derived_b2g_counts_in_stats_only(self):
        self.assertGreaterEqual(self.meta["stats"]["b2g_derived"], 1)

    def test_direct_vector3_spawn(self):
        hits = rec(self.records, kind="vector3_coordinate",
                   file="game/scripts/building/mini_root.gd")
        self.assertEqual(len(hits), 1)
        self.assertTrue(hits[0]["gameplay_binding"])

    def test_harmless_local_offsets_stay_out(self):
        hits = [r for r in self.records
                if r["file"] == "game/scripts/props/local_prop.gd"]
        self.assertEqual(hits, [])
        self.assertGreaterEqual(self.meta["stats"]["vector3_stats_only"], 3)

    def test_fallback_offset_behind_anchor_stays_out(self):
        hits = rec(self.records, kind="vector3_coordinate",
                   file="game/scripts/cases/mina_caption_manifestation.gd")
        self.assertEqual(hits, [])

    def test_camera_test_only_coordinate(self):
        hits = rec(self.records, kind="plan_coordinate",
                   file="game/tests/camera_shot.gd")
        self.assertEqual(len(hits), 1)
        self.assertIn("CAMERA_STATION", hits[0]["spatial"])
        self.assertEqual(hits[0]["tier"], "test")
        self.assertEqual(hits[0]["disposition"], "UPDATE_TEST_FIXTURE")

    def test_dynamically_assembled_id(self):
        hits = rec(self.records, kind="id_candidate", token="F01_BAR_LT_")
        self.assertEqual(len(hits), 1)
        self.assertIn("UNKNOWN_DYNAMIC", hits[0]["spatial"])

    def test_asset_path_dependency(self):
        hits = rec(self.records, kind="asset_path",
                   token="res://assets/building/floor_01.gltf")
        self.assertEqual(len(hits), 1)
        self.assertIn("ASSET_PATH", hits[0]["spatial"])

    def test_node_path_lookup(self):
        hits = rec(self.records, kind="node_path",
                   token="F01/F01_LOBBY_CLOCK_01")
        self.assertEqual(len(hits), 1)
        self.assertIn("SCENE_NODE_PATH", hits[0]["authority"])

    def test_generated_name_template(self):
        hits = rec(self.records, kind="generated_name",
                   file="game/scripts/building/mini_root.gd")
        self.assertEqual(len(hits), 1)
        self.assertIn("GENERATED_IDENTITY", hits[0]["authority"])

    def test_layout_load(self):
        hits = rec(self.records, kind="layout_load",
                   file="game/scripts/building/mini_root.gd")
        self.assertEqual(len(hits), 1)
        self.assertEqual(hits[0]["disposition"], "REGENERATE_CONSUMER")

    def test_secondary_authority_reference_and_self_skip(self):
        hits = rec(self.records, kind="id_reference", token="MINI_HUB",
                   file="game/scripts/building/mini_root.gd")
        self.assertEqual(len(hits), 1)
        self.assertIn("SEMANTIC_ANCHOR", hits[0]["spatial"])
        self_refs = rec(self.records, token="MINI_HUB",
                        file="game/data/acoustic_graph.json")
        self.assertEqual(self_refs, [])
        room_fk = rec(self.records, kind="id_reference", token="F01_LOBBY",
                      file="game/data/acoustic_graph.json")
        self.assertEqual(len(room_fk), 1)
        self.assertIn("DATA_FOREIGN_KEY", room_fk[0]["authority"])

    def test_data_foreign_keys(self):
        unit = rec(self.records, kind="unit_reference", token="1A",
                   file="game/data/mini_data.json")
        self.assertEqual(len(unit), 1)
        self.assertIn("DATA_FOREIGN_KEY", unit[0]["authority"])
        stale = rec(self.records, kind="id_candidate",
                    token="F01_GHOST_ROOM")
        self.assertEqual(len(stale), 1)

    def test_debug_file_gains_debug_only(self):
        hits = [r for r in self.records
                if r["file"] == "game/scripts/ui/thing_debug.gd"]
        self.assertTrue(hits)
        for record in hits:
            self.assertIn("DEBUG_ONLY", record["authority"])

    def test_manual_contract_emitted_when_file_exists(self):
        hits = rec(self.records, kind="manual_contract",
                   token="organism_ledger_spatial_payload")
        self.assertEqual(len(hits), 1)
        self.assertIn("SAVE_CONTRACT", hits[0]["authority"])
        absent = rec(self.records, kind="manual_contract",
                     token="street_lane_scalars")
        self.assertEqual(absent, [])


class DriftTests(unittest.TestCase):
    def test_clean_round_trip(self):
        with TempRepo() as root:
            manifest = write_manifest(root)
            code, out, _ = run_main("--root", str(root), "--layout",
                                    MINI_LAYOUT, "--manifest", str(manifest))
            self.assertEqual(code, 0, out)

    def test_new_unclassified_production_dependency_fails(self):
        with TempRepo() as root:
            manifest = write_manifest(root)
            extra = root / "game/scripts/building/new_pass.gd"
            extra.write_text('extends Node\n\nfunc _ready() -> void:\n'
                             '\ttoggle_room("F01_A_MAIN")\n',
                             encoding="utf-8")
            code, out, _ = run_main("--root", str(root), "--layout",
                                    MINI_LAYOUT, "--manifest", str(manifest))
            self.assertEqual(code, 1, out)
            self.assertIn("F01_A_MAIN", out)

    def test_new_raw_gameplay_coordinate_fails(self):
        with TempRepo() as root:
            manifest = write_manifest(root)
            extra = root / "game/scripts/game/new_spawn.gd"
            extra.parent.mkdir(parents=True, exist_ok=True)
            extra.write_text('extends Node\n\nfunc _ready() -> void:\n'
                             '\tplayer.global_position = '
                             'Vector3(4.0, 0.0, -7.0)\n', encoding="utf-8")
            code, out, _ = run_main("--root", str(root), "--layout",
                                    MINI_LAYOUT, "--manifest", str(manifest))
            self.assertEqual(code, 1, out)

    def test_removed_preserved_record_is_stale(self):
        with TempRepo() as root:
            manifest = write_manifest(root)
            src = root / "game/scripts/cases/mina_caption_manifestation.gd"
            src.write_text("extends Node\n", encoding="utf-8")
            code, out, _ = run_main("--root", str(root), "--layout",
                                    MINI_LAYOUT, "--manifest", str(manifest))
            self.assertEqual(code, 4, out)
            self.assertIn("stale preserved", out)

    def test_removed_incidental_record_is_cleanup_only(self):
        with TempRepo() as root:
            manifest = write_manifest(root)
            shot = root / "game/tests/camera_shot.gd"
            shot.write_text("extends Node3D\n", encoding="utf-8")
            code, out, _ = run_main("--root", str(root), "--layout",
                                    MINI_LAYOUT, "--manifest", str(manifest))
            self.assertEqual(code, 0, out)
            self.assertIn("cleanup opportunities: ", out)

    def test_vanished_target_fails(self):
        with TempRepo() as root:
            manifest = write_manifest(root)
            layout_path = root / MINI_LAYOUT
            layout = json.loads(layout_path.read_text(encoding="utf-8"))
            rooms = layout["floors"][0]["rooms"]
            layout["floors"][0]["rooms"] = [
                r for r in rooms if r["id"] != "F01_LOBBY"]
            layout_path.write_text(json.dumps(layout), encoding="utf-8")
            code, out, _ = run_main("--root", str(root), "--layout",
                                    MINI_LAYOUT, "--manifest", str(manifest))
            self.assertEqual(code, 1, out)
            self.assertNotIn("targets vanished (FAIL): 0", out)
            self.assertIn("targets vanished (FAIL):", out)

    def test_authority_class_change_fails(self):
        with TempRepo() as root:
            manifest = write_manifest(root)
            data = json.loads(manifest.read_text(encoding="utf-8"))
            for record in data["records"]:
                if record["token"] == "F01_LOBBY" and \
                        record["file"].endswith("mini_root.gd"):
                    record["authority"] = ["SAVE_CONTRACT"]
            manifest.write_text(json.dumps(data), encoding="utf-8")
            code, out, _ = run_main("--root", str(root), "--layout",
                                    MINI_LAYOUT, "--manifest", str(manifest))
            self.assertEqual(code, 1, out)

    def test_coordinate_contract_flip_fails(self):
        with TempRepo() as root:
            manifest = write_manifest(root)
            data = json.loads(manifest.read_text(encoding="utf-8"))
            for record in data["records"]:
                if record["kind"] == "vector3_coordinate" and \
                        record["file"].endswith("mini_root.gd"):
                    record["gameplay_binding"] = False
            manifest.write_text(json.dumps(data), encoding="utf-8")
            code, out, _ = run_main("--root", str(root), "--layout",
                                    MINI_LAYOUT, "--manifest", str(manifest))
            self.assertEqual(code, 1, out)

    def test_identifier_domain_change_fails(self):
        with TempRepo() as root:
            manifest = write_manifest(root)
            data = json.loads(manifest.read_text(encoding="utf-8"))
            for record in data["records"]:
                if record["token"] == "F01_LOBBY" and \
                        record["file"].endswith("mini_root.gd"):
                    record["resolved_target"] = "F02/marker"
            manifest.write_text(json.dumps(data), encoding="utf-8")
            code, out, _ = run_main("--root", str(root), "--layout",
                                    MINI_LAYOUT, "--manifest", str(manifest))
            self.assertEqual(code, 1, out)

    def test_manifest_refuses_production_paths(self):
        with TempRepo() as root:
            for target in ("game/data/evil.json", "art/data/evil.json",
                           "design/evil.json"):
                code, _, err = run_main(
                    "--root", str(root), "--layout", MINI_LAYOUT,
                    "--manifest", str(root / target), "--update-manifest")
                self.assertEqual(code, 3, err)
                self.assertIn("refusing to write manifest", err)
                self.assertFalse((root / target).exists())

    def test_line_number_movement_is_not_drift(self):
        with TempRepo() as root:
            manifest = write_manifest(root)
            src = root / "game/scripts/building/mini_root.gd"
            src.write_text("## moved\n## down\n\n" +
                           src.read_text(encoding="utf-8"),
                           encoding="utf-8")
            code, out, _ = run_main("--root", str(root), "--layout",
                                    MINI_LAYOUT, "--manifest", str(manifest))
            self.assertEqual(code, 0, out)

    def test_deterministic_output(self):
        with TempRepo() as root:
            m1 = root / "m1.json"
            m2 = root / "m2.json"
            for target in (m1, m2):
                code, _, err = run_main(
                    "--root", str(root), "--layout", MINI_LAYOUT,
                    "--manifest", str(target), "--update-manifest")
                self.assertEqual(code, 0, err)
            self.assertEqual(m1.read_text(encoding="utf-8"),
                             m2.read_text(encoding="utf-8"))

    def test_production_only_scope_filters_manifest(self):
        with TempRepo() as root:
            manifest = write_manifest(root)
            code, out, _ = run_main("--root", str(root), "--layout",
                                    MINI_LAYOUT, "--manifest", str(manifest),
                                    "--production-only")
            self.assertEqual(code, 0, out)

    def test_works_without_git_metadata(self):
        # TempRepo copies contain no .git directory; a full round trip
        # succeeding there is the contract (no Godot, no Git).
        with TempRepo() as root:
            self.assertFalse((root / ".git").exists())
            manifest = write_manifest(root)
            code, _, _ = run_main("--root", str(root), "--layout",
                                  MINI_LAYOUT, "--manifest", str(manifest))
            self.assertEqual(code, 0)


class ManifestFormatTests(unittest.TestCase):
    def test_malformed_manifest(self):
        code, _, err = run_main("--root", str(MINI_REPO), "--layout",
                                MINI_LAYOUT, "--manifest",
                                str(FIXTURES / "malformed_manifest.json"))
        self.assertEqual(code, 3)
        self.assertIn("malformed manifest", err)

    def test_non_json_manifest(self):
        code, _, err = run_main("--root", str(MINI_REPO), "--layout",
                                MINI_LAYOUT, "--manifest",
                                str(FIXTURES / "not_json_manifest.json"))
        self.assertEqual(code, 3)
        self.assertIn("malformed manifest", err)

    def test_duplicate_record(self):
        with TempRepo() as root:
            manifest = write_manifest(root)
            data = json.loads(manifest.read_text(encoding="utf-8"))
            data["records"].append(dict(data["records"][0]))
            manifest.write_text(json.dumps(data), encoding="utf-8")
            code, _, err = run_main("--root", str(root), "--layout",
                                    MINI_LAYOUT, "--manifest", str(manifest))
            self.assertEqual(code, 3)
            self.assertIn("duplicate manifest identity", err)

    def test_missing_manifest_is_usage_error(self):
        code, _, err = run_main("--root", str(MINI_REPO), "--layout",
                                MINI_LAYOUT, "--manifest",
                                str(FIXTURES / "does_not_exist.json"))
        self.assertEqual(code, 3)
        self.assertIn("missing", err)

    def test_json_output_parses(self):
        with TempRepo() as root:
            manifest = write_manifest(root)
            code, out, _ = run_main("--root", str(root), "--layout",
                                    MINI_LAYOUT, "--manifest",
                                    str(manifest), "--json")
            self.assertEqual(code, 0)
            payload = json.loads(out)
            self.assertEqual(payload["result"], "clean")


class ProductionSmokeTests(unittest.TestCase):
    """Read-only assertions against the live repository and the checked-in
    manifest: a handful of known load-bearing contracts, not total counts.
    """

    @classmethod
    def setUpClass(cls):
        manifest_path = REPO_ROOT / audit.DEFAULT_MANIFEST
        cls.manifest = json.loads(
            manifest_path.read_text(encoding="utf-8"))
        cls.records = cls.manifest["records"]

    def _one(self, **want):
        hits = rec(self.records, **want)
        self.assertEqual(
            len(hits), 1,
            f"expected exactly one record for {want}, got {len(hits)}")
        return hits[0]

    def test_safe_return_anchor_contract(self):
        record = self._one(kind="runtime_id", token="F04_B_BED",
                           file="game/scripts/campaign/core_loop_director.gd")
        self.assertIn("SAVE_CONTRACT", record["authority"])
        self.assertEqual(record["disposition"], "MUST_PRESERVE_ID")

    def test_waking_residue_socket_contract(self):
        record = self._one(
            kind="id_reference", token="2A_FRIDGE_FACE",
            file="game/scripts/cases/mina_caption_manifestation.gd")
        self.assertIn("SAVE_CONTRACT", record["authority"])

    def test_floor_asset_path_contract(self):
        record = self._one(
            kind="asset_path", token="res://assets/building/floor_01.gltf",
            file="game/scripts/building/building_root.gd")
        self.assertEqual(record["disposition"], "PRESERVE_OR_ALIAS")

    def test_organism_ledger_manual_contract(self):
        record = self._one(kind="manual_contract",
                           token="organism_ledger_spatial_payload")
        self.assertIn("SAVE_CONTRACT", record["authority"])

    def test_arrival_spawn_named_anchor_candidate(self):
        record = self._one(
            kind="vector3_coordinate",
            file="game/scripts/game/first_shift_director.gd",
            token="<module>")
        self.assertEqual(record["disposition"],
                         "REPLACE_WITH_NAMED_ANCHOR")
        self.assertEqual(record["confidence"], "HIGH")

    def test_building_root_selector_paths(self):
        for token in ("res://scenes/building/orison_root.tscn",
                      "res://scenes/building/orison_v2_runtime.tscn"):
            record = self._one(
                kind="asset_path", token=token,
                file="game/scripts/building/building_root_selector.gd")
            self.assertEqual(record["disposition"], "PRESERVE_OR_ALIAS")
            self.assertEqual(record["confidence"], "HIGH")

    def test_v2_parity_anchor_contract(self):
        adapter = "game/scripts/building/orison_v2_anchor_adapter.gd"
        for token in ("F04_B_BEDSIDE_RETURN", "F02_A_MAIN_VANTRY_POINT",
                      "F01_DOOR_06", "LobbyPorterBoard"):
            hits = rec(self.records, file=adapter, token=token)
            self.assertEqual(len(hits), 1, token)
            self.assertEqual(hits[0]["disposition"], "MUST_PRESERVE_ID")
            self.assertTrue(hits[0]["target_exists"], token)

    def test_v1_anonymous_bed_fallback_not_migrated(self):
        for file in ("game/scripts/building/orison_v2_anchor_adapter.gd",
                     "game/scripts/campaign/core_loop_director.gd"):
            record = self._one(kind="id_reference", token="bed", file=file)
            self.assertEqual(record["disposition"], "PRESERVE_OR_ALIAS")
            self.assertIn("V1-ONLY", record["rationale"])

    def test_v2_blockout_is_an_authority_not_noise(self):
        blockout = [r for r in self.records
                    if r["file"] == "game/data/orison_v2_blockout.json"]
        tokens = {r["token"] for r in blockout}
        # Parity ids surface; v2-only vocabulary (envelopes, capsule
        # stations) stays out of the inventory.
        self.assertIn("F01_DOOR_06", tokens)
        self.assertIn("F02_A_MAIN_VANTRY_POINT", tokens)
        self.assertNotIn("F01_PRIMARY_ROUTE_ENVELOPE", tokens)
        self.assertNotIn("F04_CAPSULE_BEDSIDE_RETURN", tokens)

    def test_live_check_is_clean(self):
        code, out, _ = run_main("--root", str(REPO_ROOT))
        self.assertEqual(code, 0, out)


if __name__ == "__main__":
    unittest.main(verbosity=2)
