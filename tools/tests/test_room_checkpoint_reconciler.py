#!/usr/bin/env python3
"""Focused self-tests for tools/room_checkpoint_reconciler.py.

Runs against synthetic fixtures only (mini layout + synthetic checkpoint
documents and manifests); never writes production data.  Execute with:

    python tools/tests/test_room_checkpoint_reconciler.py
"""

from __future__ import annotations

import copy
import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

TOOLS_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS_DIR))

import room_checkpoint_reconciler as rc  # noqa: E402
import room_layout_workbench as wb       # noqa: E402

FIXTURES = Path(__file__).resolve().parent / "fixtures"
LAYOUT = FIXTURES / "mini_layout.json"
CLEAN = FIXTURES / "checkpoints_clean"
CONTRADICTED = FIXTURES / "checkpoints_contradicted"
MALFORMED = FIXTURES / "checkpoints_malformed"

TABLES = {"ok": True, "note": "synthetic",
          "asm_foot": {"chair": (0.24, 0.25)},
          "fridge_foot": {False: (0.35, 0.31), True: (0.36, 0.34)},
          "stove_foot": (0.32, 0.30), "bath_sink_foot": (0.305, 0.28),
          "shower_foot": (0.36, 0.36), "boxfan_foot": (0.25, 0.25)}


def run_reconcile(checkpoints, layout=LAYOUT, **kwargs):
    kwargs.setdefault("tables", TABLES)
    kwargs.setdefault("use_git", False)
    kwargs.setdefault("runtime_scan_root", checkpoints)  # no runtime sources
    return rc.reconcile(layout, checkpoints, **kwargs)


def statuses(report):
    """(room, object, verdict) -> decision dict, over every parsed decision."""
    out = {}
    for room, rows in report["decisions_by_room"].items():
        for d in rows:
            out[(room, d["object"], d["verdict"])] = d
    return out


class CleanFixtureTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.report = run_reconcile(CLEAN)
        cls.by_key = statuses(cls.report)

    def d(self, room, obj, verdict):
        return self.by_key[(room, obj, verdict)]

    def test_exit_code_zero_without_contradictions(self):
        self.assertEqual(self.report["summary"]["CONTRADICTED"], 0)
        self.assertEqual(self.report["summary"]["MALFORMED"], 0)
        self.assertEqual(self.report["conflicts"], [])
        self.assertEqual(rc.exit_code_for(self.report), 0)

    def test_keep_satisfied_in_room(self):
        d = self.d("T1_A", "a_counter", "KEEP")
        self.assertEqual(d["status"], rc.SATISFIED)

    def test_range_expansion_produces_individual_decisions(self):
        self.assertEqual(self.d("T1_A", "a_box1", "KEEP")["status"],
                         rc.SATISFIED)
        self.assertEqual(self.d("T1_A", "a_box2", "KEEP")["status"],
                         rc.SATISFIED)

    def test_remove_satisfied_when_absent(self):
        self.assertEqual(self.d("T1_A", "a_ghost", "REMOVE")["status"],
                         rc.SATISFIED)

    def test_remove_of_assembly_kind_token_is_unverifiable(self):
        d = self.d("T1_A", "chair", "REMOVE")
        self.assertEqual(d["status"], rc.UNVERIFIABLE)
        self.assertIn("assembly/marker KIND", d["reason"])

    def test_glob_remove_satisfied(self):
        self.assertEqual(self.d("T1_A", "a_gone_*", "REMOVE")["status"],
                         rc.SATISFIED)

    def test_keep_absent_satisfied(self):
        self.assertEqual(self.d("T1_A", "a_ghost2", "KEEP ABSENT")["status"],
                         rc.SATISFIED)

    def test_prose_row_without_id_is_unverifiable_not_guessed(self):
        d = self.d("T1_A", None, "KEEP")
        self.assertEqual(d["status"], rc.UNVERIFIABLE)
        self.assertIn("no stable object id", d["reason"])

    def test_object_outside_every_room_is_unverifiable(self):
        d = self.d("T1_A", "x_stoop", "KEEP")
        self.assertEqual(d["status"], rc.UNVERIFIABLE)
        self.assertIn("outside every declared room rect", d["reason"])

    def test_move_without_target_is_unverifiable_not_a_guess(self):
        d = self.d("T1_A", "a_rug", "MOVE")
        md = d if not d.get("expected") else None
        # Two MOVE rows exist for a_rug (md + manifest); find the md one.
        rows = [x for x in self.report["decisions_by_room"]["T1_A"]
                if x["object"] == "a_rug" and x["verdict"] == "MOVE"]
        md_row = next(x for x in rows if not x["expected"])
        self.assertEqual(md_row["status"], rc.UNVERIFIABLE)
        self.assertIn("no checkable target", md_row["reason"])

    def test_move_with_target_within_tolerance_satisfied(self):
        rows = [x for x in self.report["decisions_by_room"]["T1_A"]
                if x["object"] == "a_rug" and x["verdict"] == "MOVE"]
        manifest_row = next(x for x in rows if x["expected"])
        self.assertEqual(manifest_row["status"], rc.SATISFIED)

    def test_repair_without_checkable_property_is_unverifiable(self):
        d = self.d("T1_A", "a_counter_clutter", "REPAIR")
        self.assertEqual(d["status"], rc.UNVERIFIABLE)

    def test_replace_half_complete_is_open_not_contradicted(self):
        d = self.d("T1_A", "old_thing", "REPLACE")
        self.assertEqual(d["status"], rc.OPEN)
        self.assertIn("half-complete", d["reason"])

    def test_replace_satisfied_via_manifest(self):
        d = self.d("T1_A", "a_ghost3", "REPLACE")
        self.assertEqual(d["status"], rc.SATISFIED)

    def test_add_open_when_absent_and_satisfied_when_present(self):
        self.assertEqual(self.d("T1_B", "b_new_lamp", "ADD")["status"],
                         rc.OPEN)
        self.assertEqual(self.d("T1_A", "a_box1", "ADD")["status"],
                         rc.SATISFIED)

    def test_runtime_scope_is_unverifiable(self):
        d = self.d("T1_A", "RuntimeThing", "KEEP")
        self.assertEqual(d["status"], rc.UNVERIFIABLE)
        self.assertIn("RuntimeThing", self.report["runtime_only_dependencies"])

    def test_unknown_room_is_flagged_not_fatal(self):
        d = self.d("T1_ZZZ", "a_box2", "KEEP")
        self.assertEqual(d["status"], rc.SATISFIED)
        self.assertTrue(any("not a declared layout room" in f
                            for f in d["flags"]))

    def test_duplicate_compatible_decisions_reported(self):
        dupes = {c["object"]: c["verdicts"] for c in self.report["duplicates"]}
        self.assertIn("a_rug", dupes)                  # MOVE twice
        # KEEP + ADD both assert presence: compatible duplicate, NOT conflict.
        self.assertEqual(dupes.get("a_box1"), ["ADD", "KEEP"])
        self.assertNotIn("a_box1",
                         {c["object"] for c in self.report["conflicts"]})

    def test_source_line_and_quote_preserved(self):
        d = self.d("T1_A", "a_ghost", "REMOVE")
        self.assertTrue(d["source"]["path"].endswith(
            "ORISON_T1_MAIN_CHECKPOINT_TEST.md"))
        self.assertGreater(d["source"]["line"], 0)
        self.assertIn("a_ghost", d["source"]["quote"])


class ContradictionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.report = run_reconcile(CONTRADICTED)
        cls.by_key = statuses(cls.report)

    def test_removed_object_reappearing_is_contradicted(self):
        d = self.by_key[("T1_A", "a_counter", "REMOVE")]
        self.assertEqual(d["status"], rc.CONTRADICTED)
        self.assertIn("still present", d["reason"])

    def test_kept_object_vanishing_is_contradicted(self):
        d = self.by_key[("T1_A", "vanished_thing", "KEEP")]
        self.assertEqual(d["status"], rc.CONTRADICTED)

    def test_room_ownership_drift_is_contradicted(self):
        d = self.by_key[("T1_B", "a_chair_90", "KEEP")]
        self.assertEqual(d["status"], rc.CONTRADICTED)
        self.assertIn("T1_A", d["reason"])

    def test_conflicting_rows_detected_and_neither_preferred(self):
        conflict = next(c for c in self.report["conflicts"]
                        if c["object"] == "a_counter")
        self.assertEqual(conflict["verdicts"], ["KEEP", "REMOVE"])
        self.assertEqual(len(conflict["sources"]), 2)

    def test_move_beyond_tolerance_contradicted(self):
        d = self.by_key[("T1_A", "a_rug", "MOVE")]
        self.assertEqual(d["status"], rc.CONTRADICTED)
        self.assertIn("tolerance", d["reason"])

    def test_replacement_with_both_objects_remaining_contradicted(self):
        d = self.by_key[("T1_A", "a_box1", "REPLACE")]
        self.assertEqual(d["status"], rc.CONTRADICTED)
        self.assertIn("both", d["reason"])

    def test_exit_code_one(self):
        self.assertEqual(rc.exit_code_for(self.report), 1)

    def test_actions_section_contains_only_open_and_contradicted(self):
        for a in self.report["next_reconstruction_actions"]:
            self.assertIn(a["status"], (rc.OPEN, rc.CONTRADICTED))
        self.assertTrue(self.report["next_reconstruction_actions"])


class MalformedTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.report = run_reconcile(MALFORMED)

    def test_malformed_rows_reported_with_line_numbers(self):
        problems = {m["problem"] for m in self.report["malformed_rows"]}
        self.assertTrue(any("unrecognized verdict" in p for p in problems))
        self.assertTrue(any("cells" in p for p in problems))
        for m in self.report["malformed_rows"]:
            self.assertGreater(m["line"], 0)
            self.assertTrue(m["quote"])

    def test_exit_code_four(self):
        self.assertEqual(rc.exit_code_for(self.report), 4)


class CombinedAndEmptyTests(unittest.TestCase):
    def test_contradicted_plus_malformed_is_exit_five(self):
        with tempfile.TemporaryDirectory() as tmp:
            both = Path(tmp) / "both"
            both.mkdir()
            for src in list(CONTRADICTED.iterdir()) + list(MALFORMED.iterdir()):
                shutil.copy(src, both / src.name)
            report = run_reconcile(both)
            self.assertEqual(rc.exit_code_for(report), 5)

    def test_no_checkpoint_documents_is_graceful_and_green(self):
        with tempfile.TemporaryDirectory() as tmp:
            report = run_reconcile(Path(tmp))
            self.assertEqual(report["summary"]["SATISFIED"], 0)
            self.assertEqual(report["documents"], [])
            self.assertEqual(rc.exit_code_for(report), 0)

    def test_non_checkpoint_markdown_is_ignored(self):
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / "notes.md").write_text(
                "| Room | Element | Verdict | Reason |\n|---|---|---|---|\n"
                "| A | `a_counter` | REMOVE | not a checkpoint doc |\n",
                encoding="utf-8")
            report = run_reconcile(Path(tmp))
            self.assertEqual(report["documents"], [])


class DuplicateIdTests(unittest.TestCase):
    def test_duplicated_layout_id_contradicts_keep(self):
        layout = json.loads(LAYOUT.read_text(encoding="utf-8"))
        layout["floors"][0]["furniture"].append(
            {"id": "a_counter", "rect": [5.0, 1.0, 5.5, 1.5], "h": 0.9,
             "z0": 0.0, "mat": "wood_dark"})
        index, rooms_by_id, kinds = rc.build_object_index(layout, TABLES)
        decision = {"source": {"path": "x", "line": 1, "quote": ""},
                    "room": "T1_A", "room_resolution": "explicit",
                    "verdict": "KEEP", "rationale": "", "element_text": "",
                    "replacement": None, "expected": {},
                    "object": "a_counter", "object_form": "literal"}
        rc.classify(decision, index, rooms_by_id, None, 0.05, 1.0, kinds)
        self.assertEqual(decision["status"], rc.CONTRADICTED)
        self.assertIn("duplicated", decision["reason"])


class RuntimeEvidenceTests(unittest.TestCase):
    def test_gd_script_evidence_makes_absent_keep_unverifiable(self):
        with tempfile.TemporaryDirectory() as tmp:
            scripts = Path(tmp) / "game" / "scripts"
            scripts.mkdir(parents=True)
            (scripts / "fake_prop.gd").write_text(
                'var name := "GhostRuntimeProp"\n', encoding="utf-8")
            scan = rc.build_runtime_evidence_scanner(Path(tmp))
            layout = json.loads(LAYOUT.read_text(encoding="utf-8"))
            index, rooms_by_id, kinds = rc.build_object_index(layout, TABLES)
            decision = {"source": {"path": "x", "line": 1, "quote": ""},
                        "room": "T1_A", "room_resolution": "explicit",
                        "verdict": "KEEP", "rationale": "", "element_text": "",
                        "replacement": None, "expected": {},
                        "object": "GhostRuntimeProp", "object_form": "literal"}
            rc.classify(decision, index, rooms_by_id, scan, 0.05, 1.0, kinds)
            self.assertEqual(decision["status"], rc.UNVERIFIABLE)
            self.assertIn("runtime", decision["reason"].lower())

    def test_prefix_match_beats_contradiction_for_imprecise_ids(self):
        layout = json.loads(LAYOUT.read_text(encoding="utf-8"))
        index, rooms_by_id, kinds = rc.build_object_index(layout, TABLES)
        decision = {"source": {"path": "x", "line": 1, "quote": ""},
                    "room": "T1_A", "room_resolution": "explicit",
                    "verdict": "KEEP", "rationale": "", "element_text": "",
                    "replacement": None, "expected": {},
                    "object": "a_chair", "object_form": "literal"}
        rc.classify(decision, index, rooms_by_id, None, 0.05, 1.0, kinds)
        self.assertEqual(decision["status"], rc.UNVERIFIABLE)
        self.assertIn("imprecise id", decision["reason"])


class OutputAndOverwriteTests(unittest.TestCase):
    def test_deterministic_byte_identical_output(self):
        with tempfile.TemporaryDirectory() as tmp:
            d1, d2 = Path(tmp) / "one", Path(tmp) / "two"
            for out in (d1, d2):
                code = rc.main(["--layout", str(LAYOUT),
                                "--checkpoints", str(CLEAN),
                                "--output", str(out), "--no-git"])
                self.assertEqual(code, 0)
            for name in ("room_checkpoint_status.json",
                         "room_checkpoint_status.md"):
                self.assertEqual((d1 / name).read_bytes(),
                                 (d2 / name).read_bytes(), name)

    def test_refuses_overwrite_without_force(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp)
            code = rc.main(["--layout", str(LAYOUT), "--checkpoints",
                            str(CLEAN), "--output", str(out), "--no-git"])
            self.assertEqual(code, 0)
            stale = (out / "room_checkpoint_status.md").read_bytes()
            code = rc.main(["--layout", str(LAYOUT), "--checkpoints",
                            str(CONTRADICTED), "--output", str(out),
                            "--no-git"])
            self.assertEqual(code, 3)
            self.assertEqual((out / "room_checkpoint_status.md").read_bytes(),
                             stale)
            code = rc.main(["--layout", str(LAYOUT), "--checkpoints",
                            str(CONTRADICTED), "--output", str(out),
                            "--no-git", "--force"])
            self.assertEqual(code, 1)   # rewritten, contradictions found

    def test_internal_failure_returns_70(self):
        with tempfile.TemporaryDirectory() as tmp:
            bad_layout = Path(tmp) / "broken.json"
            bad_layout.write_text("{not json", encoding="utf-8")
            code = rc.main(["--layout", str(bad_layout), "--checkpoints",
                            str(CLEAN), "--output", str(Path(tmp) / "out"),
                            "--no-git"])
            self.assertEqual(code, 70)


if __name__ == "__main__":
    unittest.main(verbosity=2)
