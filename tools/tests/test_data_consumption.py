#!/usr/bin/env python3
from __future__ import annotations
import json
import sys
import tempfile
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS))
import audit_data_consumption as audit


class DataConsumptionTests(unittest.TestCase):
    def fixture(self):
        td = tempfile.TemporaryDirectory()
        root = Path(td.name)
        (root / "game/data").mkdir(parents=True)
        (root / "game/scripts/game").mkdir(parents=True)
        (root / "tools").mkdir()
        (root / "game/data/live.json").write_text(
            json.dumps({"used": 1, "dead": 2}), encoding="utf-8")
        (root / "game/data/orphan.json").write_text(
            json.dumps({"claim": "this file says it is read"}), encoding="utf-8")
        (root / "game/scripts/game/reader.gd").write_text(
            'const P="res://data/live.json"\nfunc f(d): return d.used\n', encoding="utf-8")
        (root / "game/scripts/game/reality_game_state.gd").write_text(
            '"dead_float": 0.0,\n', encoding="utf-8")
        (root / "tools/data_consumption_exceptions.json").write_text(
            '{"files":{},"fields":{}}', encoding="utf-8")
        return td, root

    def test_file_and_field_deadness_are_independent(self):
        td, root = self.fixture()
        try:
            rows = audit.scan(root, root / audit.DEFAULT_EXCEPTIONS)
            self.assertTrue(any(r["kind"] == "FILE_UNREAD" and "orphan" in r["file"] for r in rows))
            self.assertTrue(any(r["kind"] == "FIELD_UNREAD" and r.get("field") == "dead" for r in rows))
            self.assertFalse(any(r["kind"] == "FIELD_UNREAD" and r.get("field") == "used" for r in rows))
        finally:
            td.cleanup()

    def test_artifact_prose_does_not_assert_its_consumption(self):
        td, root = self.fixture()
        try:
            rows = audit.scan(root, root / audit.DEFAULT_EXCEPTIONS)
            self.assertTrue(any(r["kind"] == "FILE_UNREAD" and "orphan" in r["file"] for r in rows))
        finally:
            td.cleanup()

    def test_live_known_dead_schedule_fields(self):
        rows = audit.scan(TOOLS.parent, TOOLS.parent / audit.DEFAULT_EXCEPTIONS)
        dead = {(r.get("file"), str(r.get("field", "")).rsplit(".", 1)[-1])
                for r in rows if r["kind"] == "FIELD_UNREAD"}
        self.assertTrue(any(f == "outfit" for _p, f in dead))
        self.assertTrue(any(f == "with" for _p, f in dead))
        self.assertTrue(any(f == "route" for _p, f in dead))

    def test_live_progress_floats_are_monotonic_only(self):
        rows = audit.scan(TOOLS.parent, TOOLS.parent / audit.DEFAULT_EXCEPTIONS)
        fields = {r.get("field") for r in rows if r["kind"] == "DURABLE_NUMERIC_MONOTONIC_ONLY"}
        self.assertIn("building_stability", fields)
        self.assertIn("reality_coherence", fields)


if __name__ == "__main__":
    unittest.main(verbosity=2)
