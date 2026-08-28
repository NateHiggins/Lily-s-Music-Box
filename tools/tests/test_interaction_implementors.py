#!/usr/bin/env python3
"""Focused self-tests for tools/audit_interaction_implementors.py.

Synthetic fixtures plus read-only production smoke checks.  Execute with:

    python tools/tests/test_interaction_implementors.py
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
sys.path.insert(0, str(TOOLS_DIR))

import audit_interaction_implementors as audit  # noqa: E402

FIXTURES = Path(__file__).resolve().parent / "fixtures" / "implementor_census"


def run_main(*argv):
    out, err = io.StringIO(), io.StringIO()
    with redirect_stdout(out), redirect_stderr(err):
        code = audit.main(list(argv))
    return code, out.getvalue(), err.getvalue()


def run_json(root, manifest, *extra):
    code, out, _ = run_main("--root", str(root), "--manifest", str(manifest),
                            "--json", *extra)
    return code, json.loads(out)


def fixture_copy(tmp):
    root = Path(tmp) / "root"
    shutil.copytree(FIXTURES, root)
    return root


def fresh_manifest(root, tmp):
    manifest = Path(tmp) / "manifest.json"
    code, _, _ = run_main("--root", str(root), "--manifest", str(manifest),
                          "--update-manifest")
    return manifest


class DiscoveryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.implementors = {(i["file"], i["family"]): i
                            for i in audit.discover(FIXTURES)}

    def imp(self, file, family="interact_prompt"):
        return self.implementors[(file, family)]

    def test_whole_object_same_file(self):
        i = self.imp("props/whole_object.gd")
        self.assertEqual(i["protocol"], "whole-object")
        self.assertEqual(i["action_status"], "ACTION_RESOLVED_SAME_FILE")
        self.assertEqual(i["action_owner"], "same node")

    def test_named_control_same_file(self):
        i = self.imp("props/named_control.gd", "control_prompt")
        self.assertEqual(i["protocol"], "named-control")
        self.assertEqual(i["action_method"], "interact_control")

    def test_adapter_pattern_detected(self):
        i = self.imp("props/prop_control_area.gd")
        self.assertEqual(i["role"], "adapter")
        self.assertEqual(i["action_status"], "ACTION_RESOLVED_ADAPTER")
        self.assertEqual(i["action_owner"], "adapter target")

    def test_inherited_via_class_name(self):
        i = self.imp("props/child_class.gd")
        self.assertEqual(i["action_status"], "ACTION_RESOLVED_INHERITED")
        self.assertEqual(i["action_source"], "props/base_thing.gd")

    def test_inherited_via_script_path(self):
        i = self.imp("props/child_path.gd")
        self.assertEqual(i["action_status"], "ACTION_RESOLVED_INHERITED")
        self.assertEqual(i["action_source"], "props/base_path.gd")

    def test_composed_interact_area(self):
        i = self.imp("building/composed_area.gd")
        self.assertEqual(i["protocol"], "composed/interact-area")
        self.assertEqual(i["action_status"], "ACTION_RESOLVED_COMPOSED")
        self.assertEqual(i["action_method"], "interact_area")

    def test_parent_delegation_detected(self):
        i = self.imp("props/parent_delegate.gd")
        self.assertEqual(i["action_owner"], "parent/delegate")
        self.assertEqual(i["action_status"], "ACTION_RESOLVED_SAME_FILE")

    def test_unresolved_dynamic_delegation(self):
        i = self.imp("props/dynamic_delegate.gd")
        self.assertEqual(i["action_status"], "ACTION_UNRESOLVED")
        self.assertEqual(i["action_owner"], "unresolved")

    def test_debug_role_from_known_path(self):
        i = self.imp("characters/npc_placeholder.gd")
        self.assertEqual(i["role"], "debug-only")


class DriftTests(unittest.TestCase):
    def test_generated_manifest_agrees_with_source(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = fixture_copy(tmp)
            manifest = fresh_manifest(root, tmp)
            code, report = run_json(root, manifest)
            self.assertEqual(code, 0)
            self.assertTrue(report["summary"]["totals_agree"])
            self.assertEqual(report["summary"]["unclassified"], 0)

    def test_new_unclassified_implementor_fails(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = fixture_copy(tmp)
            manifest = fresh_manifest(root, tmp)
            (root / "props" / "newcomer.gd").write_text(
                "extends Node\n\n\nfunc interact_prompt() -> String:\n"
                "\treturn \"Poke it\"\n\n\nfunc interact(_p) -> void:\n"
                "\tpass\n", encoding="utf-8")
            code, report = run_json(root, manifest)
            self.assertEqual(code, 1)
            self.assertEqual(report["unclassified"],
                             [["props/newcomer.gd", "interact_prompt"]])

    def test_removed_implementor_is_stale_not_silent(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = fixture_copy(tmp)
            manifest = fresh_manifest(root, tmp)
            (root / "props" / "whole_object.gd").unlink()
            code, report = run_json(root, manifest)
            self.assertEqual(code, 1)
            self.assertIn(["props/whole_object.gd", "interact_prompt"],
                          report["stale"])

    def test_changed_prompt_family_reported(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = fixture_copy(tmp)
            manifest = fresh_manifest(root, tmp)
            (root / "props" / "whole_object.gd").write_text(
                "extends Node\n\n\nfunc control_prompt(c) -> String:\n"
                "\treturn \"Work it\"\n\n\n"
                "func interact_control(c, p) -> void:\n\tpass\n",
                encoding="utf-8")
            code, report = run_json(root, manifest)
            self.assertEqual(code, 1)
            self.assertIn("props/whole_object.gd", report["family_flips"])

    def test_file_move_causes_explicit_drift(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = fixture_copy(tmp)
            manifest = fresh_manifest(root, tmp)
            (root / "props" / "whole_object.gd").rename(
                root / "props" / "renamed_object.gd")
            code, report = run_json(root, manifest)
            self.assertEqual(code, 1)
            self.assertIn(["props/whole_object.gd", "interact_prompt"],
                          report["stale"])
            self.assertIn(["props/renamed_object.gd", "interact_prompt"],
                          report["unclassified"])

    def test_line_number_changes_cause_no_drift(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = fixture_copy(tmp)
            manifest = fresh_manifest(root, tmp)
            target = root / "props" / "whole_object.gd"
            target.write_text("## moved down\n## by comments\n\n"
                              + target.read_text(encoding="utf-8"),
                              encoding="utf-8")
            code, _ = run_json(root, manifest)
            self.assertEqual(code, 0)

    def test_production_to_debug_reclassification_fails(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = fixture_copy(tmp)
            manifest = fresh_manifest(root, tmp)
            data = json.loads(manifest.read_text("utf-8"))
            for e in data["entries"]:
                if e["file"] == "props/whole_object.gd":
                    e["role"] = "debug-only"
            manifest.write_text(json.dumps(data), encoding="utf-8")
            code, report = run_json(root, manifest)
            self.assertEqual(code, 1)
            self.assertTrue(any(c["file"] == "props/whole_object.gd"
                                for c in report["changed"]))

    def test_adapter_losing_target_fails(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = fixture_copy(tmp)
            manifest = fresh_manifest(root, tmp)
            (root / "props" / "prop_control_area.gd").write_text(
                "extends Area3D\n\n\nfunc interact_prompt() -> String:\n"
                "\treturn \"\"\n\n\nfunc interact(_p) -> void:\n\tpass\n",
                encoding="utf-8")
            code, report = run_json(root, manifest)
            self.assertEqual(code, 1)
            self.assertTrue(any("adapter lost" in f["problem"]
                                for f in report["required_failures"]))

    def test_named_control_without_action_fails(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = fixture_copy(tmp)
            manifest = fresh_manifest(root, tmp)
            (root / "props" / "named_control.gd").write_text(
                "extends Node\n\n\nfunc control_prompt(c) -> String:\n"
                "\treturn \"Work it\"\n", encoding="utf-8")
            code, report = run_json(root, manifest)
            self.assertEqual(code, 1)
            self.assertTrue(any("named-control" in f["problem"]
                                for f in report["required_failures"]))

    def test_resolved_inheritance_disappearing_fails(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = fixture_copy(tmp)
            manifest = fresh_manifest(root, tmp)
            (root / "props" / "base_thing.gd").write_text(
                "class_name FixtureBaseThing\nextends Node\n",
                encoding="utf-8")
            code, report = run_json(root, manifest)
            self.assertEqual(code, 1)
            self.assertTrue(any(f["file"] == "props/child_class.gd"
                                for f in report["required_failures"]))

    def test_tolerated_unresolved_stays_green_when_declared(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = fixture_copy(tmp)
            manifest = fresh_manifest(root, tmp)
            data = json.loads(manifest.read_text("utf-8"))
            entry = next(e for e in data["entries"]
                         if e["file"] == "props/dynamic_delegate.gd")
            self.assertEqual(entry["action_owner"], "unresolved")
            code, _ = run_json(root, manifest)
            self.assertEqual(code, 0)


class ManifestValidationTests(unittest.TestCase):
    def test_duplicate_manifest_record_is_malformed(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = fixture_copy(tmp)
            manifest = fresh_manifest(root, tmp)
            data = json.loads(manifest.read_text("utf-8"))
            data["entries"].append(dict(data["entries"][0]))
            manifest.write_text(json.dumps(data), encoding="utf-8")
            code, report = run_json(root, manifest)
            self.assertEqual(code & 4, 4)
            self.assertTrue(any("duplicate" in p
                                for p in report["manifest_problems"]))

    def test_invalid_role_value_is_malformed(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = fixture_copy(tmp)
            manifest = fresh_manifest(root, tmp)
            data = json.loads(manifest.read_text("utf-8"))
            data["entries"][0]["role"] = "mystery"
            manifest.write_text(json.dumps(data), encoding="utf-8")
            code, report = run_json(root, manifest)
            self.assertEqual(code & 4, 4)

    def test_unreadable_manifest_is_usage_error(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = fixture_copy(tmp)
            manifest = Path(tmp) / "broken.json"
            manifest.write_text("{not json", encoding="utf-8")
            code, _, err = run_main("--root", str(root), "--manifest",
                                    str(manifest))
            self.assertEqual(code, 3)

    def test_missing_manifest_is_usage_error(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = fixture_copy(tmp)
            code, _, err = run_main("--root", str(root), "--manifest",
                                    str(Path(tmp) / "nope.json"))
            self.assertEqual(code, 3)
            self.assertIn("--update-manifest", err)


class CliTests(unittest.TestCase):
    def test_deterministic_json_output(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = fixture_copy(tmp)
            manifest = fresh_manifest(root, tmp)
            _, out1 = run_json(root, manifest, "--verbose")
            _, out2 = run_json(root, manifest, "--verbose")
            self.assertEqual(out1, out2)

    def test_operates_without_godot_or_git_metadata(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = fixture_copy(tmp)          # bare tree, no .git anywhere
            manifest = fresh_manifest(root, tmp)
            code, report = run_json(root, manifest)
            self.assertEqual(code, 0)
            # 11 fixture files, of which 9 define a prompt (two are bases).
            self.assertEqual(report["summary"]["discovered"], 9)

    def test_missing_root_is_usage_error(self):
        code, _, _ = run_main("--root", "no/such/dir")
        self.assertEqual(code, 3)


class ProductionSmokeTests(unittest.TestCase):
    """Read-only checks against the real tree and checked-in manifest."""

    @classmethod
    def setUpClass(cls):
        cls.code, cls.report = run_json(audit.DEFAULT_ROOT,
                                        audit.DEFAULT_MANIFEST, "--verbose")

    def test_production_census_agrees_with_manifest(self):
        self.assertEqual(self.code, 0)
        summary = self.report["summary"]
        self.assertEqual(summary["discovered"], 85)
        self.assertEqual(summary["by_family"],
                         {"control_prompt": 18, "interact_prompt": 67})
        self.assertEqual(summary["by_role"],
                         {"adapter": 1, "debug-only": 2, "production": 82})

    def test_projector_inheritance_resolution_pinned(self):
        imp = next(i for i in self.report["implementors"]
                   if i["file"] == "props/projector_prop.gd")
        self.assertEqual(imp["action_status"], "ACTION_RESOLVED_INHERITED")
        self.assertEqual(imp["action_source"], "props/tv_prop.gd")

    def test_wayfinding_composition_resolution_pinned(self):
        imp = next(i for i in self.report["implementors"]
                   if i["file"] == "building/wayfinding_signage_pass.gd")
        self.assertEqual(imp["action_status"], "ACTION_RESOLVED_COMPOSED")
        self.assertEqual(imp["protocol"], "composed/interact-area")

    def test_no_unresolved_required_relationships_in_production(self):
        self.assertEqual(
            self.report["summary"]["required_relationship_failures"], 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
