#!/usr/bin/env python3
"""Focused self-tests for tools/room_checkpoint_linter.py.

Runs against synthetic fixtures only; never touches production data.
Execute with:

    python tools/tests/test_room_checkpoint_linter.py
"""

from __future__ import annotations

import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

TOOLS_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS_DIR))

import room_checkpoint_linter as rl      # noqa: E402
import room_checkpoint_reconciler as rc  # noqa: E402

FIXTURES = Path(__file__).resolve().parent / "fixtures"
LAYOUT = FIXTURES / "mini_layout.json"
DRAFT = FIXTURES / "lint_drafts" / "ORISON_LINT_DRAFT_CHECKPOINT_TEST.md"
READY_DOC = FIXTURES / "lint_drafts" / "ORISON_LINT_READY_CHECKPOINT_TEST.md"
PROSE_DOC = FIXTURES / "lint_drafts" / "ORISON_LINT_PROSE_CHECKPOINT_TEST.md"
MALFORMED_DIR = FIXTURES / "checkpoints_malformed"
RUNTIME_SRC = FIXTURES / "runtime_src"


def build_ctx():
    return rl.build_context(LAYOUT, runtime_scan_root=RUNTIME_SRC)


class DraftLintTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.ctx = build_ctx()
        cls.doc = rl.lint_checkpoint(DRAFT, cls.ctx)
        cls.rows = {r["source"]["line"]: r for r in cls.doc["rows"]}

    def row_for(self, needle):
        return next(r for r in self.doc["rows"]
                    if needle in r["element_text"])

    def test_exact_id_row_is_ready(self):
        r = self.row_for("`a_counter` ")  # the KEEP row (line 9)
        r = self.rows[min(l for l, r in self.rows.items()
                          if r["verdict"] == "KEEP"
                          and r["element_text"].strip() == "`a_counter`")]
        self.assertEqual(r["status"], rl.READY)
        self.assertIn("READY", r["diagnostics"])
        self.assertEqual(r["tokens"][0]["diagnostics"], ["EXACT"])

    def test_single_prefix_match_named_but_not_assumed(self):
        r = self.row_for("`a_chair_9`")
        self.assertEqual(r["status"], rl.NEEDS_ATTENTION)
        t = r["tokens"][0]
        self.assertEqual(t["diagnostics"], ["PREFIX_ONLY"])
        self.assertIn("a_chair_90", t["suggestion"])
        self.assertIn("not assumed", t["suggestion"])

    def test_multiple_prefix_matches_all_listed(self):
        r = next(r for r in self.doc["rows"]
                 if r["element_text"].strip() == "`a_chair`")
        t = next(t for t in r["tokens"] if t["token"] == "a_chair")
        self.assertEqual(t["diagnostics"], ["PREFIX_ONLY"])
        self.assertIn("a_chair_45", t["suggestion"])
        self.assertIn("a_chair_90", t["suggestion"])

    def test_kind_mistaken_for_id(self):
        r = self.row_for("`chair`")
        t = next(t for t in r["tokens"] if t["token"] == "chair")
        self.assertEqual(t["diagnostics"], ["KIND_NOT_ID"])
        ids = {m["id"] for m in t["matches"]}
        self.assertEqual(ids, {"a_chair_45", "a_chair_90"})

    def test_runtime_source_match(self):
        r = self.row_for("`RuntimePropX`")
        t = r["tokens"][0]
        self.assertEqual(t["diagnostics"], ["RUNTIME_ONLY"])
        self.assertIn("game/scripts/fake_prop.gd",
                      t["matches"][0]["evidence"][0])
        self.assertEqual(r["status"], rl.NEEDS_ATTENTION)
        self.assertTrue(any("scope: runtime" in n for n in r["needs"]))

    def test_unknown_prose_row(self):
        r = self.row_for("mystery gadget")
        self.assertIn("UNKNOWN", r["diagnostics"])
        self.assertEqual(r["status"], rl.NEEDS_ATTENTION)

    def test_move_without_target_suggests_current_position_as_reference(self):
        r = self.row_for("`a_rug`")
        self.assertIn("MISSING_TARGET", r["diagnostics"])
        self.assertTrue(any("never the target" in n for n in r["notes"]))

    def test_repair_without_property_blocked(self):
        r = self.rows[min(l for l, r in self.rows.items()
                          if r["verdict"] == "REPAIR"
                          and "[visual]" not in r["element_text"])]
        self.assertIn("MISSING_TARGET", r["diagnostics"])
        self.assertEqual(r["status"], rl.NEEDS_ATTENTION)

    def test_repair_with_visual_tag_is_ready_manual(self):
        r = self.row_for("[visual]")
        self.assertEqual(r["status"], rl.READY)
        self.assertIn("MANUAL_TARGET", r["diagnostics"])

    def test_replace_missing_one_side_blocked(self):
        r = self.row_for("`old_x`")
        self.assertIn("MISSING_TARGET", r["diagnostics"])
        self.assertTrue(any("replacement" in n for n in r["needs"]))

    def test_replace_with_arrow_is_ready(self):
        r = self.row_for("`a_newbox`")
        self.assertEqual(r["status"], rl.READY)
        self.assertTrue(any("still present" in n for n in r["notes"]))

    def test_add_with_duplicate_proposed_id(self):
        r = self.row_for("`a_box2` (`chair`)")
        self.assertIn("CONFLICTING_TOKEN", r["diagnostics"])
        self.assertTrue(any("ALREADY exists" in n for n in r["needs"]))

    def test_add_with_fresh_id_and_kind_type_is_ready(self):
        r = self.row_for("`a_new_chair9`")
        self.assertEqual(r["status"], rl.READY)
        self.assertTrue(any("expected type" in n for n in r["notes"]))
        t = next(t for t in r["tokens"] if t["token"] == "a_new_chair9")
        self.assertIn("proposed new id", t["suggestion"])

    def test_architectural_prose_flagged_with_manual_guidance(self):
        r = self.row_for("walls, floor and ceiling")
        self.assertIn("ARCHITECTURAL", r["diagnostics"])
        self.assertEqual(r["status"], rl.NEEDS_ATTENTION)

    def test_explicit_manual_record_is_ready(self):
        r = self.row_for("[manual]")
        self.assertEqual(r["status"], rl.READY)
        self.assertIn("MANUAL_TARGET", r["diagnostics"])

    def test_keep_absent_of_never_existing_id_is_ready(self):
        r = self.row_for("`long_gone`")
        self.assertEqual(r["status"], rl.READY)
        self.assertIn("checkable as written", r["tokens"][0]["suggestion"])

    def test_prose_phrase_resolving_to_one_record_suggests_backtick(self):
        r = self.row_for("gizmometer device")
        f = next(f for f in r["prose"]["kind_findings"]
                 if f["kind"] == "gizmometer")
        self.assertEqual(f["diagnostic"], "EXACT")
        self.assertIn("`a_gizmo`", f["suggestion"])

    def test_prose_phrase_with_two_candidates_lists_both(self):
        r = self.row_for("seating chair")
        f = next(f for f in r["prose"]["kind_findings"]
                 if f["kind"] == "chair")
        self.assertEqual(f["diagnostic"], "AMBIGUOUS")
        self.assertIn("a_chair_45", f["suggestion"])
        self.assertIn("a_chair_90", f["suggestion"])


class DocumentLevelTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.ctx = build_ctx()

    def test_fully_ready_draft_exits_zero(self):
        docs = [rl.lint_checkpoint(READY_DOC, self.ctx)]
        self.assertEqual(docs[0]["summary"]["needs_attention"], 0)
        self.assertEqual(rl.exit_code_for(docs), 0)

    def test_draft_with_problems_exits_one(self):
        docs = [rl.lint_checkpoint(DRAFT, self.ctx)]
        self.assertEqual(rl.exit_code_for(docs), 1)

    def test_prose_only_checkpoint_flagged_with_inventory(self):
        doc = rl.lint_checkpoint(PROSE_DOC, self.ctx)
        self.assertIn("NO_VERDICT_TABLE", doc["document_diagnostics"])
        tokens = {t["token"]: t for t in doc["token_inventory"]}
        self.assertEqual(tokens["a_counter"]["diagnostics"], ["EXACT"])
        self.assertEqual(tokens["chair"]["diagnostics"], ["KIND_NOT_ID"])
        self.assertEqual(rl.exit_code_for([doc]), 1)

    def test_malformed_checkpoint_exits_four(self):
        docs = [rl.lint_checkpoint(p, self.ctx)
                for p in sorted(MALFORMED_DIR.glob("*.md"))]
        self.assertTrue(all(d["summary"]["malformed"] for d in docs))
        code = rl.exit_code_for(docs)
        self.assertIn(code, (4, 5))
        self.assertEqual(code & 4, 4)

    def test_manifest_file_lintable(self):
        doc = rl.lint_checkpoint(
            FIXTURES / "checkpoints_clean" / "future.decisions.json", self.ctx)
        move = next(r for r in doc["rows"] if r["verdict"] == "MOVE")
        self.assertEqual(move["status"], rl.READY)
        self.assertNotIn("MISSING_TARGET", move["diagnostics"])

    def test_works_outside_repository(self):
        # Graceful absence of git/repo metadata: lint a copy from a temp dir.
        with tempfile.TemporaryDirectory() as tmp:
            copy = Path(tmp) / DRAFT.name
            shutil.copy(DRAFT, copy)
            doc = rl.lint_checkpoint(copy, self.ctx)
            self.assertTrue(doc["rows"])
            self.assertTrue(doc["path"])


class CliTests(unittest.TestCase):
    def test_scaffold_deterministic_and_proposed_not_a_manifest(self):
        with tempfile.TemporaryDirectory() as tmp:
            d1, d2 = Path(tmp) / "one", Path(tmp) / "two"
            for out in (d1, d2):
                code = rl.main(["--checkpoint", str(DRAFT),
                                "--layout", str(LAYOUT),
                                "--scaffold-output", str(out)])
                self.assertEqual(code, 1)   # draft has unresolved rows
            stem = DRAFT.name[:-3]
            for name in (f"{stem}.lint.json", f"{stem}.lint.md",
                         f"{stem}.decisions.json.proposed"):
                self.assertEqual((d1 / name).read_bytes(),
                                 (d2 / name).read_bytes(), name)
            proposed = json.loads(
                (d1 / f"{stem}.decisions.json.proposed").read_text("utf-8"))
            self.assertIn("NOT an approved", proposed["PROPOSED"])
            # The reconciler must NOT discover the proposed file.
            _, manifests = rc.discover_checkpoints(d1)
            self.assertEqual(manifests, [])

    def test_scaffold_requires_marker_not_guess_for_ambiguous(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp)
            rl.main(["--checkpoint", str(DRAFT), "--layout", str(LAYOUT),
                     "--scaffold-output", str(out)])
            stem = DRAFT.name[:-3]
            proposed = json.loads(
                (out / f"{stem}.decisions.json.proposed").read_text("utf-8"))
            prefix_rows = [e for e in proposed["decisions"]
                           if "a_chair_45" in e.get("object_candidates", [])]
            self.assertTrue(prefix_rows)
            for e in prefix_rows:
                self.assertIsNone(e["object"])   # candidates never chosen

    def test_no_overwrite_then_force(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp)
            self.assertEqual(rl.main(["--checkpoint", str(READY_DOC),
                                      "--layout", str(LAYOUT),
                                      "--scaffold-output", str(out)]), 0)
            self.assertEqual(rl.main(["--checkpoint", str(READY_DOC),
                                      "--layout", str(LAYOUT),
                                      "--scaffold-output", str(out)]), 3)
            self.assertEqual(rl.main(["--checkpoint", str(READY_DOC),
                                      "--layout", str(LAYOUT),
                                      "--scaffold-output", str(out),
                                      "--force"]), 0)

    def test_missing_checkpoint_is_usage_error(self):
        self.assertEqual(rl.main(["--checkpoint", "does_not_exist.md",
                                  "--layout", str(LAYOUT)]), 2)

    def test_internal_failure_returns_70(self):
        with tempfile.TemporaryDirectory() as tmp:
            bad = Path(tmp) / "broken.json"
            bad.write_text("{not json", encoding="utf-8")
            self.assertEqual(rl.main(["--checkpoint", str(DRAFT),
                                      "--layout", str(bad)]), 70)


if __name__ == "__main__":
    unittest.main(verbosity=2)
