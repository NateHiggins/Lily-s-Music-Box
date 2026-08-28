#!/usr/bin/env python3
"""Focused self-tests for tools/room_reconstruction_progress.py.

Synthetic fixtures only; production data is never read or written.
Execute with:

    python tools/tests/test_room_reconstruction_progress.py
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

import room_checkpoint_reconciler as rc      # noqa: E402
import room_reconstruction_progress as rp    # noqa: E402

FIXTURES = Path(__file__).resolve().parent / "fixtures"
MINI = FIXTURES / "mini_layout.json"
CLEAN = FIXTURES / "checkpoints_clean"
CONTRADICTED = FIXTURES / "checkpoints_contradicted"
MALFORMED = FIXTURES / "checkpoints_malformed"
PROSE_DOC = FIXTURES / "lint_drafts" / "ORISON_LINT_PROSE_CHECKPOINT_TEST.md"


def two_floor_layout(tmp):
    """The mini fixture plus an entirely untouched second floor T2."""
    layout = json.loads(MINI.read_text(encoding="utf-8"))
    layout["floors"].append({
        "id": "T2", "z": 3.2, "slabs": [], "walls": [],
        "rooms": [{"id": "T2_X", "rect": [0.0, 0.0, 3.0, 3.0],
                   "kind": "office"},
                  {"id": "T2_Y", "rect": [3.0, 0.0, 6.0, 3.0],
                   "kind": "storage"}],
        "markers": [], "furniture": [], "ceilings": [],
        "vent_registers": [], "sockets": [],
    })
    path = Path(tmp) / "two_floor_layout.json"
    path.write_text(json.dumps(layout), encoding="utf-8")
    return path


def run_report(layout_path, checkpoints, floor=None, room=None):
    sources = rp.gather(layout_path, checkpoints, use_git=False)
    sources["layout_path"] = layout_path
    return rp.build_report(sources, floor_filter=floor, room_filter=room)


def room_of(report, room_id):
    return next(r for r in report["rooms"] if r["room"] == room_id)


class CleanCorpusTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.mkdtemp()
        cls.layout = two_floor_layout(cls.tmp)
        cls.report = run_report(cls.layout, CLEAN)

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.tmp, ignore_errors=True)

    def test_untouched_floor_reported(self):
        self.assertIn("T2", self.report["building"]
                      ["floors_with_no_reconstruction_work"])
        t2x = room_of(self.report, "T2_X")
        self.assertEqual(t2x["coverage"], "none")
        self.assertIn("UNPROFILED", t2x["states"])
        self.assertEqual(t2x["headline"], "no profile, no checkpoint")

    def test_changed_room_count_is_authoritative(self):
        self.assertEqual(self.report["building"]["declared_rooms"], 6)

    def test_structured_green_room(self):
        a = room_of(self.report, "T1_A")
        self.assertIn("CHECKPOINT_STRUCTURED", a["states"])
        self.assertIn("DRIFT_GREEN", a["states"])
        self.assertNotIn("DRIFT_RED", a["states"])
        self.assertTrue(a["profiled"])   # fixture has a Room profiles section
        self.assertGreater(a["decisions"]["SATISFIED"], 0)

    def test_no_generic_complete_status_exists(self):
        for r in self.report["rooms"]:
            self.assertNotIn("COMPLETE", r["states"])
            for s in r["states"]:
                self.assertIn(s, rp.STATES)

    def test_manual_runtime_evidence_stays_visible_but_green(self):
        a = room_of(self.report, "T1_A")
        self.assertIn("MANUAL_EVIDENCE_REQUIRED", a["states"])
        self.assertIn("manual/runtime evidence remains", a["headline"])
        self.assertEqual(rp.exit_code_for(self.report), 0)

    def test_multi_room_checkpoint_covers_both_rooms(self):
        a, b = room_of(self.report, "T1_A"), room_of(self.report, "T1_B")
        shared = set(a["checkpoints"]) & set(b["checkpoints"])
        self.assertTrue(any(p.endswith("ORISON_T1_MAIN_CHECKPOINT_TEST.md")
                            for p in shared))

    def test_manifest_backed_coverage(self):
        a = room_of(self.report, "T1_A")
        self.assertEqual(a["coverage"], "manifest-backed")

    def test_unknown_room_reference_surfaced(self):
        self.assertIn("T1_ZZZ", self.report["building"]
                      ["room_ids_referenced_but_not_declared"])

    def test_compatible_duplicates_attributed(self):
        a = room_of(self.report, "T1_A")
        self.assertIn("a_rug", a["compatible_duplicates"])
        self.assertEqual(a["conflicts"], [])

    def test_workbench_packet_generatable(self):
        a = room_of(self.report, "T1_A")
        self.assertTrue(a["workbench"]["packet_generatable"])
        self.assertGreater(a["workbench"]["objects"], 0)

    def test_next_actions_ranked_and_explained(self):
        ranks = [a["rank"] for a in self.report["next_actions"]]
        self.assertEqual(ranks, sorted(ranks))
        for a in self.report["next_actions"]:
            self.assertTrue(a["ranking_source"].startswith(
                f"rank {a['rank']}:"))
        # T2 rooms are unprofiled on a later-sequence (unknown) floor.
        t2 = [a for a in self.report["next_actions"]
              if a["room"] in ("T2_X", "T2_Y")]
        self.assertTrue(all(a["action"] == "write a room profile"
                            for a in t2))


class CoverageKindTests(unittest.TestCase):
    def test_prose_only_checkpoint_coverage(self):
        with tempfile.TemporaryDirectory() as tmp:
            layout = two_floor_layout(tmp)
            docs = Path(tmp) / "docs"
            docs.mkdir()
            shutil.copy(PROSE_DOC, docs / PROSE_DOC.name)
            report = run_report(layout, docs)
            a = room_of(report, "T1_A")
            self.assertEqual(a["coverage"], "prose-only")
            self.assertIn("CHECKPOINT_PROSE_ONLY", a["states"])
            self.assertTrue(any(x["rank"] == 4
                                for x in report["next_actions"]))

    def test_profiled_but_uncheckpointed_room(self):
        with tempfile.TemporaryDirectory() as tmp:
            layout = two_floor_layout(tmp)
            docs = Path(tmp) / "docs"
            docs.mkdir()
            (docs / "T1_A_room_notes.md").write_text(
                "# Notes\n\n## Room profile\n\n`T1_A` is the test office.\n",
                encoding="utf-8")
            report = run_report(layout, docs)
            a = room_of(report, "T1_A")
            self.assertTrue(a["profiled"])
            self.assertEqual(a["coverage"], "none")
            self.assertIn(("T1_A", "create a checkpoint"),
                          [(x["room"], x["action"])
                           for x in report["next_actions"]
                           if x["rank"] == 6])

    def test_no_checkpoint_directory_is_graceful(self):
        with tempfile.TemporaryDirectory() as tmp:
            layout = two_floor_layout(tmp)
            report = run_report(layout, Path(tmp) / "missing_dir")
            self.assertEqual(report["building"]["rooms_checkpointed"], 0)
            self.assertEqual(rp.exit_code_for(report), 0)


class DriftAndExitTests(unittest.TestCase):
    def test_contradicted_checkpoint_is_red_and_exit_one(self):
        with tempfile.TemporaryDirectory() as tmp:
            layout = two_floor_layout(tmp)
            report = run_report(layout, CONTRADICTED)
            a = room_of(report, "T1_A")
            self.assertIn("DRIFT_RED", a["states"])
            self.assertIn("drift RED", a["headline"])
            self.assertEqual(rp.exit_code_for(report), 1)
            first = report["next_actions"][0]
            self.assertEqual(first["rank"], 1)
            self.assertEqual(first["action"], "resolve contradicted decisions")

    def test_malformed_checkpoint_exit_four_and_rank_two(self):
        with tempfile.TemporaryDirectory() as tmp:
            layout = two_floor_layout(tmp)
            report = run_report(layout, MALFORMED)
            self.assertEqual(rp.exit_code_for(report), 4)
            self.assertTrue(any(a["rank"] == 2
                                for a in report["next_actions"]))

    def test_combined_exit_five(self):
        with tempfile.TemporaryDirectory() as tmp:
            layout = two_floor_layout(tmp)
            both = Path(tmp) / "both"
            both.mkdir()
            for src in list(CONTRADICTED.iterdir()) + list(MALFORMED.iterdir()):
                shutil.copy(src, both / src.name)
            report = run_report(layout, both)
            self.assertEqual(rp.exit_code_for(report), 5)

    def test_runtime_manual_only_room_needs_evidence(self):
        with tempfile.TemporaryDirectory() as tmp:
            layout = two_floor_layout(tmp)
            docs = Path(tmp) / "docs"
            docs.mkdir()
            (docs / "runtime.decisions.json").write_text(json.dumps({
                "version": 1, "decisions": [
                    {"room": "T2_X", "object": "GhostProp", "verdict": "KEEP",
                     "scope": "runtime", "rationale": "runtime only"}]}),
                encoding="utf-8")
            report = run_report(layout, docs)
            x = room_of(report, "T2_X")
            self.assertIn("MANUAL_EVIDENCE_REQUIRED", x["states"])
            self.assertEqual(x["decisions"]["UNVERIFIABLE"], 1)
            self.assertTrue(any(
                a["action"] == "collect manual/runtime evidence"
                and a["room"] == "T2_X" for a in report["next_actions"]))
            self.assertEqual(rp.exit_code_for(report), 0)


class AbbreviatedRoomLabelTests(unittest.TestCase):
    def test_unit_plus_component_label_resolves(self):
        with tempfile.TemporaryDirectory() as tmp:
            layout_path = two_floor_layout(tmp)
            layout = json.loads(Path(layout_path).read_text("utf-8"))
            doc = Path(tmp) / "ORISON_T1_ABBREV_CHECKPOINT_TEST.md"
            doc.write_text(
                "# Abbrev\n\n| Room | Element | Verdict | Reason |\n"
                "|---|---|---|---|\n"
                "| 9Z living | `a_counter` | KEEP | abbreviated label |\n"
                "| Both flats | `a_rug` | KEEP | unresolvable label |\n",
                encoding="utf-8")
            rooms_by_id = {r["id"]: r for fl in layout["floors"]
                           for r in fl["rooms"]}
            decisions, malformed, _ = rc.parse_checkpoint_markdown(
                doc, rooms_by_id)
            by_obj = {d["object"]: d for d in decisions}
            self.assertEqual(by_obj["a_counter"]["room"], "T1_ENV")
            self.assertIsNone(by_obj["a_rug"]["room"])
            self.assertEqual(by_obj["a_rug"]["room_resolution"], "unresolved")


class CliTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.mkdtemp()
        cls.layout = two_floor_layout(cls.tmp)

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.tmp, ignore_errors=True)

    def cli(self, out, *extra):
        return rp.main(["--layout", str(self.layout),
                        "--checkpoints", str(CLEAN),
                        "--output", str(out), "--no-git", *extra])

    def test_deterministic_byte_identical_output(self):
        d1, d2 = Path(self.tmp) / "d1", Path(self.tmp) / "d2"
        self.assertEqual(self.cli(d1), 0)
        self.assertEqual(self.cli(d2), 0)
        for name in ("room_reconstruction_progress.json",
                     "room_reconstruction_progress.md"):
            self.assertEqual((d1 / name).read_bytes(),
                             (d2 / name).read_bytes(), name)

    def test_floor_and_room_filters(self):
        out = Path(self.tmp) / "flt"
        self.assertEqual(self.cli(out, "--floor", "T2"), 0)
        report = json.loads(
            (out / "room_reconstruction_progress.json").read_text("utf-8"))
        self.assertEqual({r["floor"] for r in report["rooms"]}, {"T2"})
        out2 = Path(self.tmp) / "room"
        self.assertEqual(self.cli(out2, "--room", "T1_B"), 0)
        report2 = json.loads(
            (out2 / "room_reconstruction_progress.json").read_text("utf-8"))
        self.assertEqual([r["room"] for r in report2["rooms"]], ["T1_B"])

    def test_json_only_and_markdown_only(self):
        out = Path(self.tmp) / "jo"
        self.assertEqual(self.cli(out, "--json-only"), 0)
        self.assertTrue((out / "room_reconstruction_progress.json").exists())
        self.assertFalse((out / "room_reconstruction_progress.md").exists())
        out2 = Path(self.tmp) / "mo"
        self.assertEqual(self.cli(out2, "--markdown-only"), 0)
        self.assertFalse((out2 / "room_reconstruction_progress.json").exists())
        self.assertTrue((out2 / "room_reconstruction_progress.md").exists())

    def test_no_overwrite_then_force(self):
        out = Path(self.tmp) / "ow"
        self.assertEqual(self.cli(out), 0)
        self.assertEqual(self.cli(out), 3)
        self.assertEqual(self.cli(out, "--force"), 0)

    def test_internal_failure_returns_70(self):
        bad = Path(self.tmp) / "broken.json"
        bad.write_text("{not json", encoding="utf-8")
        out = Path(self.tmp) / "fail"
        code = rp.main(["--layout", str(bad), "--checkpoints", str(CLEAN),
                        "--output", str(out), "--no-git"])
        self.assertEqual(code, 70)


if __name__ == "__main__":
    unittest.main(verbosity=2)
