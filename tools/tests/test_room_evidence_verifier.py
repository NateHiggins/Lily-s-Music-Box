#!/usr/bin/env python3
"""Focused self-tests for tools/room_evidence_verifier.py.

All artifacts are synthetic and constructed inside a temporary repository
root; production evidence is never read or written.  Execute with:

    python tools/tests/test_room_evidence_verifier.py
"""

from __future__ import annotations

import json
import shutil
import struct
import sys
import tempfile
import unittest
from pathlib import Path

TOOLS_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS_DIR))

import room_evidence_verifier as ev          # noqa: E402
import room_reconstruction_progress as rp    # noqa: E402

FIXTURES = Path(__file__).resolve().parent / "fixtures"
MINI = FIXTURES / "mini_layout.json"


def png_bytes(width=1280, height=720):
    return (b"\x89PNG\r\n\x1a\n" + struct.pack(">I", 13) + b"IHDR"
            + struct.pack(">II", width, height) + b"\x08\x02\x00\x00\x00")


def receipt(status="PASS", expected=2, actual=2, captures=("00.png", "01.png"),
            schema=1, **extra):
    data = {"schema_version": schema, "status": status, "tag": "T9-TEST",
            "expected_frames": expected, "actual_frames": actual,
            "elapsed_seconds": 33.0, "budget_seconds": 54.0,
            "captures": [{"file": f, "label": Path(f).stem,
                          "width": 1280, "height": 720,
                          "elapsed_seconds": 32.0, "provenance": "rendered"}
                         for f in captures]}
    data.update(extra)
    return json.dumps(data, indent=1)


CHECKPOINT_MD = """# T9 evidence fixture

Covers `T1_A` and `T1_B`.

## Validation and evidence

- `T9Shot`: PASS, two 1280x720 player-height frames with receipt under
  `art/renders/t9_run/`.
- `WalkTest` FAST: PASS.
- `LoneTest`: PASS, 5/5.
- Missing artifact: `art/renders/t9_run/gone_forever.png`.
- Shared basename: `dup.log`.
- Second run directory: `art/renders/t9_run2/`.
- Generator: PASS.
- Plain document: `art/renders/t9_run/notes.md`.
"""


def build_tree(tmp):
    """One synthetic repository root with a checkpoint and evidence tree."""
    root = Path(tmp)
    (root / "design").mkdir(parents=True)
    (root / "design" / "ORISON_T9_EVID_CHECKPOINT_TEST.md").write_text(
        CHECKPOINT_MD, encoding="utf-8")
    (root / "art" / "data").mkdir(parents=True)
    shutil.copy(MINI, root / "art" / "data" / "building_layout.json")
    run = root / "art" / "renders" / "t9_run"
    run.mkdir(parents=True)
    (run / "00.png").write_bytes(png_bytes())
    (run / "01.png").write_bytes(png_bytes())
    (run / "scene_capture_receipt.json").write_text(receipt(),
                                                   encoding="utf-8")
    (run / "walk_fast.log").write_text(
        "  [ok] step\nWALKTEST RESULT: PASS [FAST]\n", encoding="utf-8")
    (run / "dup.log").write_text("noise\n", encoding="utf-8")
    (run / "notes.md").write_text("notes\n", encoding="utf-8")
    run2 = root / "art" / "renders" / "t9_run2"
    run2.mkdir(parents=True)
    (run2 / "dup.log").write_text("noise\n", encoding="utf-8")
    return root


def run_report(root, **kwargs):
    kwargs.setdefault("use_git", False)
    return ev.build_report(root / "design", root, **kwargs)


def citation(report, predicate):
    for doc in report["checkpoints"]:
        for c in doc["citations"]:
            if predicate(c):
                return c
    raise AssertionError("citation not found")


class CitationResolutionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.mkdtemp()
        cls.root = build_tree(cls.tmp)
        cls.report = run_report(cls.root)

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.tmp, ignore_errors=True)

    def test_exact_existing_directory(self):
        c = citation(self.report, lambda c: c["cited"] ==
                     "art/renders/t9_run" and c["kind"] == "directory")
        self.assertEqual(c["status"], ev.VERIFIED_PRESENT)
        self.assertEqual(c["artifact"]["png_count"], 2)
        self.assertIn("scene_capture_receipt.json", c["artifact"]["receipts"])

    def test_missing_exact_path(self):
        c = citation(self.report, lambda c: c["cited"] ==
                     "art/renders/t9_run/gone_forever.png")
        self.assertEqual(c["status"], ev.MISSING)

    def test_ambiguous_basename(self):
        c = citation(self.report, lambda c: c["cited"] == "dup.log")
        self.assertEqual(c["status"], ev.AMBIGUOUS)
        self.assertTrue(any("several" in n for n in c["notes"]))

    def test_symbolic_shot_resolves_to_receipt_pass(self):
        c = citation(self.report, lambda c: c["cited"] == "T9Shot")
        self.assertEqual(c["status"], ev.RECORDED_PASS)
        self.assertTrue(c["resolved_path"].endswith(
            "scene_capture_receipt.json"))
        self.assertEqual(c["artifact"]["actual_frames"], 2)

    def test_symbolic_walktest_resolves_to_log(self):
        c = citation(self.report, lambda c: c["cited"] == "WalkTest")
        self.assertEqual(c["status"], ev.RECORDED_PASS)
        self.assertIn("WALKTEST RESULT: PASS",
                      c["artifact"]["decisive_line"])

    def test_symbolic_name_without_artifact_stays_symbolic(self):
        c = citation(self.report, lambda c: c["cited"] == "LoneTest")
        self.assertEqual(c["status"], ev.SYMBOLIC_ONLY)

    def test_assertion_without_citation_stays_symbolic(self):
        c = citation(self.report, lambda c: c["kind"] == "assertion")
        self.assertEqual(c["status"], ev.SYMBOLIC_ONLY)
        self.assertIn("Generator: PASS", c["quote"])

    def test_plain_document_is_present_only(self):
        c = citation(self.report, lambda c: c["cited"] ==
                     "art/renders/t9_run/notes.md")
        self.assertEqual(c["status"], ev.VERIFIED_PRESENT)

    def test_rooms_shared_across_citations(self):
        self.assertEqual(self.report["checkpoints"][0]["rooms"],
                         ["T1_A", "T1_B"])
        self.assertIn("T1_A", self.report["by_room"])
        self.assertIn("T1_B", self.report["by_room"])
        self.assertEqual(self.report["by_room"]["T1_A"],
                         self.report["by_room"]["T1_B"])

    def test_exit_code_one_due_to_missing(self):
        self.assertEqual(ev.exit_code_for(self.report), 1)


class ArtifactVerdictTests(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def write(self, name, content, binary=False):
        path = self.tmp / name
        if binary:
            path.write_bytes(content)
        else:
            path.write_text(content, encoding="utf-8")
        return path

    def test_receipt_recording_pass(self):
        (self.tmp / "00.png").write_bytes(png_bytes())
        (self.tmp / "01.png").write_bytes(png_bytes())
        p = self.write("scene_capture_receipt.json", receipt())
        status, facts, mism = ev.verify_artifact(p, {})
        self.assertEqual(status, ev.RECORDED_PASS)
        self.assertEqual(facts["actual_frames"], 2)
        self.assertEqual(mism, [])

    def test_receipt_recording_failure(self):
        p = self.write("scene_capture_receipt.json",
                       receipt(status="FAIL", captures=()))
        status, facts, _ = ev.verify_artifact(p, {})
        self.assertEqual(status, ev.RECORDED_FAIL)

    def test_unknown_receipt_schema_not_reinterpreted(self):
        p = self.write("scene_capture_receipt.json", receipt(schema=2))
        status, facts, _ = ev.verify_artifact(p, {})
        self.assertEqual(status, ev.UNSUPPORTED)
        self.assertIn("not reinterpreted", facts["note"])

    def test_receipt_output_missing_is_mismatch(self):
        (self.tmp / "00.png").write_bytes(png_bytes())
        p = self.write("scene_capture_receipt.json", receipt())
        status, _, mism = ev.verify_artifact(p, {})
        self.assertEqual(status, ev.METADATA_MISMATCH)
        self.assertTrue(any("01.png" in m for m in mism))

    def test_frame_count_claim_mismatch(self):
        (self.tmp / "00.png").write_bytes(png_bytes())
        (self.tmp / "01.png").write_bytes(png_bytes())
        p = self.write("scene_capture_receipt.json", receipt())
        status, _, mism = ev.verify_artifact(p, {"claimed_count": 3})
        self.assertEqual(status, ev.METADATA_MISMATCH)
        self.assertTrue(any("claims 3" in m for m in mism))

    def test_resolution_claim_mismatch(self):
        (self.tmp / "00.png").write_bytes(png_bytes())
        (self.tmp / "01.png").write_bytes(png_bytes())
        p = self.write("scene_capture_receipt.json", receipt())
        status, _, mism = ev.verify_artifact(
            p, {"claimed_resolution": (1600, 900)})
        self.assertEqual(status, ev.METADATA_MISMATCH)

    def test_explicit_pass_and_fail_logs(self):
        p = self.write("walk_fast.log", "WALKTEST RESULT: PASS [FAST]\n")
        self.assertEqual(ev.verify_artifact(p, {})[0], ev.RECORDED_PASS)
        f = self.write("walk2_fast.log", "WALKTEST RESULT: FAIL [FAST]\n")
        self.assertEqual(ev.verify_artifact(f, {})[0], ev.RECORDED_FAIL)

    def test_unittest_log_formats(self):
        ok = self.write("workbench_tests.log", "ran stuff\nOK\n")
        self.assertEqual(ev.verify_artifact(ok, {})[0], ev.RECORDED_PASS)
        bad = self.write("other_tests.log", "ran stuff\nFAILED (errors=1)\n")
        self.assertEqual(ev.verify_artifact(bad, {})[0], ev.RECORDED_FAIL)

    def test_mixed_verdict_log_is_ambiguous(self):
        p = self.write("walk_fast.log",
                       "WALKTEST RESULT: FAIL [FAST]\n"
                       "WALKTEST RESULT: PASS [FAST]\n")
        status, facts, _ = ev.verify_artifact(p, {})
        self.assertEqual(status, ev.AMBIGUOUS)

    def test_log_without_verdict_is_present_not_pass(self):
        p = self.write("godot.log", "booting\nrendering\n")
        status, facts, _ = ev.verify_artifact(p, {})
        self.assertEqual(status, ev.VERIFIED_PRESENT)
        self.assertIn("not a pass", facts["note"])

    def test_shot_harness_log_count_mismatch(self):
        p = self.write("godot.log",
                       "[T9] RESULT: PASS captures=7 expected=8\n")
        status, facts, mism = ev.verify_artifact(p, {})
        self.assertEqual(status, ev.METADATA_MISMATCH)
        self.assertTrue(any("7/8" in m for m in mism))

    def test_png_dimensions_read(self):
        p = self.write("shot.png", png_bytes(640, 360), binary=True)
        status, facts, _ = ev.verify_artifact(p, {})
        self.assertEqual(status, ev.VERIFIED_PRESENT)
        self.assertEqual((facts["width"], facts["height"]), (640, 360))

    def test_unreadable_image(self):
        p = self.write("bad.png", b"not a png at all", binary=True)
        self.assertEqual(ev.verify_artifact(p, {})[0], ev.UNREADABLE)

    def test_metrics_pass_and_recorded_failures(self):
        (self.tmp / "a.png").write_bytes(png_bytes())
        good = self.write("shot_metrics.json", json.dumps({
            "schema_version": 1, "status": "PASS", "failures": [],
            "frames": [{"file": "a.png"}],
            "pairs": [{"name": "p", "min_rmse": 0.01}]}))
        status, facts, _ = ev.verify_artifact(good, {})
        self.assertEqual(status, ev.RECORDED_PASS)
        self.assertEqual(facts["thresholds_recorded_by_artifact"],
                         ["min_rmse"])
        bad = self.write("shot_metrics2.json", json.dumps({
            "schema_version": 1, "status": "FAIL",
            "failures": ["pair p below threshold"], "frames": []}))
        status2, _, _ = ev.verify_metrics(bad, {})
        self.assertEqual(status2, ev.RECORDED_FAIL)


class ManifestTests(unittest.TestCase):
    def test_manifest_claims_verified_and_malformed_detected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = build_tree(tmp)
            manifest = root / "design" / "t9.evidence.json"
            manifest.write_text(json.dumps({
                "version": 1, "claims": [
                    {"claim_id": "A", "rooms": ["T1_A"],
                     "artifact": "art/renders/t9_run/scene_capture_receipt.json",
                     "claimed_recorded_result": "PASS"},
                    {"claim_id": "B", "rooms": ["T1_A"],
                     "artifact": "art/renders/t9_run/missing.json"},
                    {"claim_id": "C", "rooms": ["T1_B"],
                     "manual_visual_proof_required": True,
                     "artifact": None},
                    {"claim_id": "D", "rooms": []},
                ]}), encoding="utf-8")
            report = run_report(root)
            claims = {c.get("claim_id"): c for d in report["checkpoints"]
                      for c in d["citations"] if c.get("claim_id")}
            self.assertEqual(claims["A"]["status"], ev.RECORDED_PASS)
            self.assertEqual(claims["B"]["status"], ev.MISSING)
            self.assertEqual(claims["C"]["status"], ev.SYMBOLIC_ONLY)
            self.assertEqual(claims["D"]["status"], ev.MALFORMED)
            self.assertEqual(ev.exit_code_for(report), 5)  # missing+malformed

    def test_commit_mismatch_with_real_git(self):
        # Use the real repository: a claimed commit of all zeros never
        # resolves, which must surface as METADATA_MISMATCH.
        with tempfile.TemporaryDirectory() as tmp:
            manifest = Path(tmp) / "x.evidence.json"
            manifest.write_text(json.dumps({
                "version": 1, "claims": [
                    {"claim_id": "Z",
                     "artifact": "tools/audit_orison_rooms.py",
                     "expected_commit": "0" * 40}]}), encoding="utf-8")
            results, malformed = ev.verify_manifest(manifest, ev.ROOT,
                                                    use_git=True)
            self.assertEqual(malformed, [])
            self.assertEqual(results[0]["status"], ev.METADATA_MISMATCH)
            self.assertTrue(any("does not resolve" in m
                                for m in results[0]["mismatches"]))


class CliAndIntegrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.mkdtemp()
        cls.root = build_tree(cls.tmp)

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.tmp, ignore_errors=True)

    def cli(self, out, *extra):
        return ev.main(["--checkpoints", str(self.root / "design"),
                        "--repository-root", str(self.root),
                        "--layout",
                        str(self.root / "art/data/building_layout.json"),
                        "--output", str(out), "--no-git", *extra])

    def test_deterministic_byte_identical_output(self):
        d1, d2 = Path(self.tmp) / "o1", Path(self.tmp) / "o2"
        self.assertEqual(self.cli(d1), 1)   # fixture has one MISSING
        self.assertEqual(self.cli(d2), 1)
        for name in ("room_evidence_status.json", "room_evidence_status.md"):
            self.assertEqual((d1 / name).read_bytes(),
                             (d2 / name).read_bytes(), name)

    def test_room_filter(self):
        out = Path(self.tmp) / "flt"
        self.assertEqual(self.cli(out, "--room", "T1_A"), 1)
        report = json.loads(
            (out / "room_evidence_status.json").read_text("utf-8"))
        self.assertEqual(len(report["checkpoints"]), 1)
        out2 = Path(self.tmp) / "flt2"
        self.assertEqual(self.cli(out2, "--room", "T2_NOPE"), 0)
        report2 = json.loads(
            (out2 / "room_evidence_status.json").read_text("utf-8"))
        self.assertEqual(report2["checkpoints"], [])

    def test_single_checkpoint_filter(self):
        out = Path(self.tmp) / "single"
        code = self.cli(out, "--checkpoint",
                        str(self.root / "design" /
                            "ORISON_T9_EVID_CHECKPOINT_TEST.md"))
        self.assertEqual(code, 1)

    def test_no_overwrite_then_force(self):
        out = Path(self.tmp) / "ow"
        self.assertEqual(self.cli(out), 1)
        self.assertEqual(self.cli(out), 3)
        self.assertEqual(self.cli(out, "--force"), 1)

    def test_scaffold_marked_unapproved(self):
        out = Path(self.tmp) / "scaf"
        self.assertEqual(self.cli(out, "--scaffold"), 1)
        proposed = json.loads(
            (out / "ORISON_T9_EVID_CHECKPOINT_TEST.evidence.json.proposed")
            .read_text("utf-8"))
        self.assertIn("NOT an approved", proposed["PROPOSED"])
        self.assertTrue(proposed["claims"])

    def test_ledger_integration_adds_evidence_states(self):
        out = Path(self.tmp) / "ev_for_ledger"
        self.cli(out)
        ledger_out = Path(self.tmp) / "ledger"
        code = rp.main(["--layout",
                        str(self.root / "art/data/building_layout.json"),
                        "--checkpoints", str(self.root / "design"),
                        "--output", str(ledger_out), "--no-git",
                        "--evidence-report",
                        str(out / "room_evidence_status.json")])
        self.assertEqual(code, 0)
        report = json.loads(
            (ledger_out / "room_reconstruction_progress.json")
            .read_text("utf-8"))
        room = next(r for r in report["rooms"] if r["room"] == "T1_A")
        self.assertIn("RECORDED_VALIDATION_PASS", room["states"])
        self.assertIn("EVIDENCE_MISSING", room["states"])
        self.assertIn("evidence", room)

    def test_ledger_unchanged_without_evidence_report(self):
        ledger_out = Path(self.tmp) / "ledger_plain"
        code = rp.main(["--layout",
                        str(self.root / "art/data/building_layout.json"),
                        "--checkpoints", str(self.root / "design"),
                        "--output", str(ledger_out), "--no-git"])
        self.assertEqual(code, 0)
        report = json.loads(
            (ledger_out / "room_reconstruction_progress.json")
            .read_text("utf-8"))
        for r in report["rooms"]:
            self.assertNotIn("evidence", r)
            for s in r["states"]:
                self.assertNotIn("EVIDENCE", s)

    def test_internal_failure_returns_70(self):
        out = Path(self.tmp) / "fail"
        code = ev.main(["--checkpoints", str(self.root / "design"),
                        "--repository-root", str(self.root),
                        "--checkpoint", str(self.root / "nope.md"),
                        "--output", str(out), "--no-git"])
        self.assertEqual(code, 70)


if __name__ == "__main__":
    unittest.main(verbosity=2)
