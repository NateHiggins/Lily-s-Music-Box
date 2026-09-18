#!/usr/bin/env python3
"""Design-doc evidence lint: header against name, and the id-like backticks."""
from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS))
import lint_design_doc as lint  # noqa: E402

NL = chr(10)


class LintTests(unittest.TestCase):
    def setUp(self):
        self.td = tempfile.TemporaryDirectory()
        self.root = Path(self.td.name)
        (self.root / "design").mkdir()

    def tearDown(self):
        self.td.cleanup()

    def doc(self, name, header=None, body="Body." + NL):
        text = "# Title" + NL + NL + (f"Evidence class: **{header}**" + NL + NL if header else "") + body
        path = self.root / "design" / name
        path.write_text(text, encoding="utf-8")
        return path

    def rules(self, path):
        return {(f["level"], f["rule"]) for f in lint.lint_file(path, self.root)}

    def test_inert_header_on_marker_name_is_an_error(self):
        path = self.doc("ORISON_V2_X_CHECKPOINT_2026-09-18.md", "INERT - PROMOTES NOTHING")
        self.assertIn(("ERROR", "header-contradicts-name"), self.rules(path))

    def test_evidence_header_on_unadmitted_name_is_an_error(self):
        path = self.doc("ORISON_V2_X_NOTES_2026-09-18.md", "TECHNICAL CHECKPOINT")
        self.assertIn(("ERROR", "header-contradicts-name"), self.rules(path))

    def test_report_only_header_is_inert_not_evidence(self):
        path = self.doc("ORISON_V2_X_REPORT_2026-09-18.md", "REPORT ONLY")
        self.assertFalse(any(level == "ERROR" for level, _ in self.rules(path)))

    def test_receipt_that_disclaims_production_is_still_evidence(self):
        self.assertEqual(lint.classify_header("DISPOSABLE REHEARSAL RECEIPT - NO PRODUCTION EVIDENCE"),
                         "EVIDENCE")

    def test_missing_header_warns_and_suggests_the_class_the_name_implies(self):
        findings = lint.lint_file(self.doc("ORISON_V2_X_GRAYBOX_CHECKPOINT_2026-09-18.md"), self.root)
        warn = [f for f in findings if f["rule"] == "no-header"]
        self.assertTrue(warn and "EVIDENCE" in warn[0]["message"])

    def test_unclassified_header_only_warns(self):
        path = self.doc("ORISON_V2_X_PREWRITE_BASELINE_2026-09-18.md", "TECHNICAL BASELINE")
        self.assertIn(("WARN", "unclassified-header"), self.rules(path))

    def test_inert_doc_backticking_ids_warns_but_filenames_do_not(self):
        path = self.doc("PROP_BRIEF.md", "INERT", "See `F01_DOOR_06` and `gen_layout.py`." + NL)
        findings = [f for f in lint.lint_file(path, self.root) if f["rule"] == "inert-backticks"]
        self.assertEqual(len(findings), 1)
        self.assertIn("F01_DOOR_06", findings[0]["message"])
        self.assertNotIn("gen_layout.py", findings[0]["message"])

    def test_non_ledger_family_is_never_admitted(self):
        admitted, marker = lint.admitted_by_name(Path("design/PROP_CHECKPOINT.md"), self.root)
        self.assertEqual((admitted, marker), (False, "CHECKPOINT"))

    def test_main_exit_codes(self):
        bad = self.doc("ORISON_V2_X_CHECKPOINT_2026-09-18.md", "INERT")
        good = self.doc("ORISON_V2_X_REPORT_2026-09-18.md", "INERT")
        import contextlib, io
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(lint.main(["--root", str(self.root), str(good)]), 0)
            self.assertEqual(lint.main(["--root", str(self.root), str(bad)]), 1)


if __name__ == "__main__":
    unittest.main(verbosity=2)
