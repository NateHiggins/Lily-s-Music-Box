#!/usr/bin/env python3
"""Rulings registry: append-only ids, real sources, defined citations."""
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import check_rulings as cr  # noqa: E402


def ruling(rid, **kw):
    base = {"id": rid, "date": "2026-09-18", "authority": "owner", "summary": "s",
            "source": "design/SRC.md", "scope": ["x"], "supersedes": []}
    base.update(kw)
    return base


class RulingsTests(unittest.TestCase):
    def setUp(self):
        self.td = tempfile.TemporaryDirectory()
        self.root = Path(self.td.name)
        (self.root / "design").mkdir()
        (self.root / "design/SRC.md").write_text("source", encoding="utf-8")
        subprocess.run(["git", "init", "-q", str(self.root)], check=True)

    def tearDown(self):
        self.td.cleanup()

    def write(self, rulings, cite=None):
        (self.root / cr.REGISTRY).write_text(json.dumps({"schema": cr.SCHEMA, "rulings": rulings}),
                                             encoding="utf-8")
        if cite:
            (self.root / "design/NOTE.md").write_text(cite, encoding="utf-8")
            subprocess.run(["git", "-C", str(self.root), "add", "design/NOTE.md"], check=True)
        return cr.check(self.root)

    def test_valid_registry(self):
        self.assertEqual(self.write([ruling("RUL-001"), ruling("RUL-002", supersedes=["RUL-001"])])
                         ["errors"], [])

    def test_duplicate_and_out_of_order_ids(self):
        errors = self.write([ruling("RUL-002"), ruling("RUL-001"), ruling("RUL-001")])["errors"]
        self.assertTrue(any("duplicate" in e for e in errors))
        self.assertTrue(any("ascending" in e for e in errors))

    def test_superseding_a_later_or_unknown_ruling(self):
        errors = self.write([ruling("RUL-001", supersedes=["RUL-002"]), ruling("RUL-002"),
                             ruling("RUL-003", supersedes=["RUL-009"])])["errors"]
        self.assertTrue(any("not earlier" in e for e in errors))
        self.assertTrue(any("unknown RUL-009" in e for e in errors))

    def test_missing_source_file_is_an_error(self):
        errors = self.write([ruling("RUL-001", source="design/GONE.md")])["errors"]
        self.assertTrue(any("does not exist" in e for e in errors))

    def test_undefined_citation_is_an_error_and_superseded_citation_warns(self):
        result = self.write([ruling("RUL-001"), ruling("RUL-002", supersedes=["RUL-001"])],
                            cite="See RUL-001 and RUL-007.")
        self.assertTrue(any("RUL-007" in e for e in result["errors"]))
        self.assertTrue(any("superseded by RUL-002" in w for w in result["warnings"]))

    def test_bad_authority_and_date(self):
        errors = self.write([ruling("RUL-001", authority="boss", date="18/09/2026")])["errors"]
        self.assertTrue(any("authority" in e for e in errors))
        self.assertTrue(any("date" in e for e in errors))


if __name__ == "__main__":
    unittest.main(verbosity=2)
