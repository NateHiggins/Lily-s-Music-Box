#!/usr/bin/env python3
"""Run receipts: scene-to-test resolution, log summary, and staleness."""
from __future__ import annotations

import argparse
import json
import sys
import tempfile
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS))
import run_receipt as rr  # noqa: E402

NL = chr(10)


class ReceiptTests(unittest.TestCase):
    def setUp(self):
        self.td = tempfile.TemporaryDirectory()
        self.root = Path(self.td.name)
        (self.root / "game/tests").mkdir(parents=True)
        (self.root / "game/scripts").mkdir(parents=True)
        (self.root / "game/project.godot").write_text("config_version=5" + NL, encoding="utf-8")
        (self.root / "game/scripts/a.gd").write_text("extends Node" + NL, encoding="utf-8")
        (self.root / "game/tests/probe_test.gd").write_text("extends Node" + NL, encoding="utf-8")
        (self.root / "game/tests/Probe.tscn").write_text(NL.join([
            '[gd_scene load_steps=2 format=3]',
            '[ext_resource type="Script" path="res://tests/probe_test.gd" id="1_x"]',
            '[ext_resource type="Script" path="res://scripts/a.gd" id="2_y"]',
            '[node name="Probe" type="Node"]',
            'script = ExtResource("1_x")',
            '[node name="Child" type="Node" parent="."]',
            'script = ExtResource("2_y")', ""]), encoding="utf-8")
        self.log = self.root / "run.log"
        self.log.write_text(NL.join(["boot", "CHECK one: PASS", "PROBE TEST: PASS", ""]),
                            encoding="utf-8")
        Path(str(self.log) + ".stderr").write_text("", encoding="utf-8")

    def tearDown(self):
        self.td.cleanup()

    def args(self, **over):
        base = dict(log=str(self.log), scene="res://tests/Probe.tscn", runner="serial",
                    exit="0", elapsed="1.5", started="2026-09-18T00:00:00Z", timed_out=False,
                    project=str(self.root / "game"), windowed=False, shot_dir="", out=None)
        base.update(over)
        return argparse.Namespace(**base)

    def write(self, **over) -> Path:
        receipt = rr.build_receipt(self.args(**over))
        path = Path(str(self.log) + ".receipt.json")
        path.write_text(json.dumps(receipt), encoding="utf-8")
        return path

    def test_older_scene_syntax_still_names_its_test_script(self):
        """format=2/3 scenes write path before type, and may leave id unquoted."""
        (self.root / "game/tests/Legacy.tscn").write_text(NL.join([
            "[gd_scene load_steps=2 format=3]",
            '[ext_resource path="res://tests/probe_test.gd" type="Script" id="1"]',
            '[node name="Legacy" type="Node"]',
            'script = ExtResource("1")', ""]), encoding="utf-8")
        found = rr.scene_test_script(self.root / "game", "res://tests/Legacy.tscn")
        self.assertTrue(found.endswith("game/tests/probe_test.gd"))
        (self.root / "game/tests/Older.tscn").write_text(NL.join([
            "[gd_scene load_steps=2 format=2]",
            '[ext_resource path="res://tests/probe_test.gd" type="Script" id=1]',
            '[node name="Older" type="Node"]',
            "script = ExtResource( 1 )", ""]), encoding="utf-8")
        self.assertTrue(rr.scene_test_script(self.root / "game", "res://tests/Older.tscn")
                        .endswith("game/tests/probe_test.gd"))

    def test_root_script_not_child_script_is_the_test(self):
        found = rr.scene_test_script(self.root / "game", "res://tests/Probe.tscn")
        self.assertTrue(found.endswith("game/tests/probe_test.gd"))

    def test_receipt_shape_matches_the_ledger_blocks(self):
        receipt = rr.build_receipt(self.args())
        self.assertEqual(receipt["evidence_kind"], "suite_run")
        self.assertEqual(receipt["execution"]["exit_code"], 0)
        self.assertIs(receipt["execution"]["completed"], True)
        self.assertIs(receipt["execution"]["timed_out"], False)
        self.assertEqual(receipt["log"]["pass_count"], 2)
        self.assertRegex(receipt["source"]["runtime_inputs_sha256"], r"^[0-9a-f]{64}$")

    def test_fresh_receipt_binds(self):
        code, problems = rr.verify(self.write(), self.root)
        self.assertEqual((code, problems), (0, []))

    def test_changed_test_source_or_runtime_input_is_stale(self):
        path = self.write()
        (self.root / "game/scripts/a.gd").write_text("extends Node2D" + NL, encoding="utf-8")
        code, problems = rr.verify(path, self.root)
        self.assertEqual(code, 1)
        self.assertIn("runtime inputs changed since the run", problems)

    def test_rewritten_log_is_stale(self):
        path = self.write()
        self.log.write_text("PROBE TEST: PASS" + NL, encoding="utf-8")
        code, problems = rr.verify(path, self.root)
        self.assertIn("stdout log missing or rewritten since the run", problems)

    def test_timeout_is_never_completed(self):
        receipt = rr.build_receipt(self.args(exit="", timed_out=True))
        self.assertIs(receipt["execution"]["completed"], False)
        self.assertIsNone(receipt["execution"]["exit_code"])

    def test_stale_cache_signature_is_flagged(self):
        self.log.write_text("SCRIPT ERROR: Nonexistent function 'foo' in base 'Node'." + NL,
                            encoding="utf-8")
        summary = rr.summarise_log(self.log)
        self.assertTrue(summary["stale_cache_suspect"])
        code, problems = rr.verify(self.write(), self.root)
        self.assertTrue(any("stale-import-cache" in p for p in problems))

    def test_digest_ignores_non_runtime_files(self):
        before = rr.runtime_inputs_sha256(self.root)
        (self.root / "game/tests/notes.txt").write_text("x", encoding="utf-8")
        self.assertEqual(before, rr.runtime_inputs_sha256(self.root))


if __name__ == "__main__":
    unittest.main(verbosity=2)
