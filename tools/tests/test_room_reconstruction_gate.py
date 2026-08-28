#!/usr/bin/env python3
"""Focused self-tests for tools/room_reconstruction_gate.py.

All fixtures are synthetic and live in temporary repository roots;
production data is never read or written (except one read-only git-ref test
against the real repository).  Execute with:

    python tools/tests/test_room_reconstruction_gate.py
"""

from __future__ import annotations

import json
import shutil
import struct
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

TOOLS_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS_DIR))

import room_reconstruction_gate as gate  # noqa: E402

FIXTURES = Path(__file__).resolve().parent / "fixtures"
MINI = FIXTURES / "mini_layout.json"
CONTRADICTED_DOC = (FIXTURES / "checkpoints_contradicted"
                    / "ORISON_T1_BAD_CHECKPOINT_TEST.md")
MALFORMED_DOC = (FIXTURES / "checkpoints_malformed"
                 / "ORISON_T1_UGLY_CHECKPOINT_TEST.md")

LANDABLE_DOC = """# Landable fixture

Covers `T1_A`.

## Object and architecture verdicts

| Room | Element | Verdict | Reason |
|---|---|---|---|
| A | `a_counter` | KEEP | Exact id, satisfied. |
| A | `a_box1..2` | KEEP | Full existing range. |
| A | `long_gone` | KEEP ABSENT | Absence checkable. |
| A | plaster patching [manual] | REPAIR | Declared visual work. |
"""

SYMBOLIC_EVIDENCE_SECTION = """
## Validation

- Generator: PASS.
"""

OPEN_DOC = """# Open fixture

Covers `T1_B`.

## Object and architecture verdicts

| Room | Element | Verdict | Reason |
|---|---|---|---|
| B | `b_new_lamp` (`chair`) | ADD | Not landed yet. |
"""

LINT_BLOCK_DOC = """# Lint blocker fixture

Covers `T1_A`.

## Object and architecture verdicts

| Room | Element | Verdict | Reason |
|---|---|---|---|
| A | `a_box2` (`chair`) | ADD | Proposed id already exists. |
"""


def png_bytes(width=1280, height=720):
    return (b"\x89PNG\r\n\x1a\n" + struct.pack(">I", 13) + b"IHDR"
            + struct.pack(">II", width, height) + b"\x08\x02\x00\x00\x00")


def make_root(tmp, docs, evidence=None):
    """Synthetic repository root: design/<docs>, mini layout, evidence."""
    root = Path(tmp)
    (root / "design").mkdir(parents=True, exist_ok=True)
    for name, text in docs.items():
        (root / "design" / name).write_text(text, encoding="utf-8")
    (root / "art" / "data").mkdir(parents=True, exist_ok=True)
    shutil.copy(MINI, root / "art" / "data" / "building_layout.json")
    for dirname, files in (evidence or {}).items():
        d = root / "art" / "renders" / dirname
        d.mkdir(parents=True, exist_ok=True)
        for fname, content in files.items():
            if isinstance(content, bytes):
                (d / fname).write_bytes(content)
            else:
                (d / fname).write_text(content, encoding="utf-8")
    return root


def run_gate(root, out, *extra):
    argv = ["--repository-root", str(root),
            "--layout", str(root / "art/data/building_layout.json"),
            "--output", str(out), "--no-git", *extra]
    return gate.main(argv)


def gate_json(out):
    return json.loads((Path(out) / "room_reconstruction_gate.json")
                      .read_text("utf-8"))


class LandabilityTests(unittest.TestCase):
    def test_fully_landable_checkpoint_exit_zero(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = make_root(tmp, {"ORISON_T1_OK_CHECKPOINT_TEST.md":
                                   LANDABLE_DOC})
            out = Path(tmp) / "out"
            code = run_gate(root, out, "--checkpoint",
                            str(root / "design" /
                                "ORISON_T1_OK_CHECKPOINT_TEST.md"))
            self.assertEqual(code, 0)
            report = gate_json(out)
            self.assertEqual(report["gate"]["result"], "LANDABLE")
            self.assertEqual(report["blockers"], [])
            # The [manual] REPAIR stays visible as manual/runtime debt.
            self.assertTrue(any(d["kind"] == "manual-runtime-decision"
                                for d in report["debt"]))

    def test_landable_with_symbolic_evidence_exit_two(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = make_root(tmp, {"ORISON_T1_SYM_CHECKPOINT_TEST.md":
                                   LANDABLE_DOC + SYMBOLIC_EVIDENCE_SECTION})
            out = Path(tmp) / "out"
            code = run_gate(root, out, "--checkpoint",
                            str(root / "design" /
                                "ORISON_T1_SYM_CHECKPOINT_TEST.md"))
            self.assertEqual(code, 2)
            report = gate_json(out)
            self.assertEqual(report["gate"]["result"],
                             "LANDABLE_WITH_SYMBOLIC_EVIDENCE")
            self.assertTrue(any(d["kind"] == "manual-assertion"
                                for d in report["debt"]))

    def test_pure_lint_blocker(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = make_root(tmp, {"ORISON_T1_LINT_CHECKPOINT_TEST.md":
                                   LINT_BLOCK_DOC})
            out = Path(tmp) / "out"
            code = run_gate(root, out, "--checkpoint",
                            str(root / "design" /
                                "ORISON_T1_LINT_CHECKPOINT_TEST.md"))
            self.assertEqual(code, 1)
            report = gate_json(out)
            self.assertEqual(report["gate"]["result"], "BLOCKED_LINT")
            self.assertTrue(all(b["category"] == "lint"
                                for b in report["blockers"]))

    def test_open_decision_blocks_strict_landing(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = make_root(tmp, {"ORISON_T1_OPEN_CHECKPOINT_TEST.md":
                                   OPEN_DOC})
            out = Path(tmp) / "out"
            code = run_gate(root, out, "--checkpoint",
                            str(root / "design" /
                                "ORISON_T1_OPEN_CHECKPOINT_TEST.md"))
            self.assertEqual(code, 1)
            report = gate_json(out)
            self.assertEqual(report["gate"]["result"], "BLOCKED_DRIFT")
            self.assertTrue(any("still open" in b["detail"]
                                for b in report["blockers"]))

    def test_contradiction_and_conflict_block(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = make_root(tmp, {CONTRADICTED_DOC.name:
                                   CONTRADICTED_DOC.read_text("utf-8")})
            out = Path(tmp) / "out"
            code = run_gate(root, out, "--checkpoint",
                            str(root / "design" / CONTRADICTED_DOC.name))
            self.assertEqual(code, 1)
            report = gate_json(out)
            self.assertEqual(report["gate"]["result"], "BLOCKED_DRIFT")
            details = " | ".join(b["detail"] for b in report["blockers"])
            self.assertIn("contradicted", details)
            self.assertIn("conflicting verdicts", details)

    def test_malformed_verdict_exit_four(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = make_root(tmp, {MALFORMED_DOC.name:
                                   MALFORMED_DOC.read_text("utf-8")})
            out = Path(tmp) / "out"
            code = run_gate(root, out, "--checkpoint",
                            str(root / "design" / MALFORMED_DOC.name))
            self.assertEqual(code, 4)
            self.assertEqual(gate_json(out)["gate"]["result"],
                             "BLOCKED_MALFORMED")

    def test_multiple_blockers_exit_five(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = make_root(tmp, {
                CONTRADICTED_DOC.name: CONTRADICTED_DOC.read_text("utf-8"),
                MALFORMED_DOC.name: MALFORMED_DOC.read_text("utf-8")})
            out = Path(tmp) / "out"
            code = run_gate(root, out, "--checkpoints",
                            str(root / "design"))
            self.assertEqual(code, 5)


class EvidenceGateTests(unittest.TestCase):
    def doc_with_evidence(self, evidence_lines):
        return LANDABLE_DOC + "\n## Validation\n\n" + evidence_lines + "\n"

    def run_doc(self, tmp, doc_text, evidence=None):
        root = make_root(tmp, {"ORISON_T1_EV_CHECKPOINT_TEST.md": doc_text},
                         evidence)
        out = Path(tmp) / "out"
        code = run_gate(root, out, "--checkpoint",
                        str(root / "design" /
                            "ORISON_T1_EV_CHECKPOINT_TEST.md"))
        return code, gate_json(out)

    def test_missing_artifact_blocks(self):
        with tempfile.TemporaryDirectory() as tmp:
            code, report = self.run_doc(
                tmp, self.doc_with_evidence(
                    "- Proof: `art/renders/nowhere/proof.png`."))
            self.assertEqual(code, 1)
            self.assertEqual(report["gate"]["result"], "BLOCKED_EVIDENCE")
            self.assertTrue(any("missing" in b["detail"]
                                for b in report["blockers"]))

    def test_recorded_failure_blocks(self):
        with tempfile.TemporaryDirectory() as tmp:
            code, report = self.run_doc(
                tmp, self.doc_with_evidence(
                    "- `WalkTest` FAST: FAIL.\n"
                    "- Evidence: `art/renders/t9/`."),
                evidence={"t9": {"walk_fast.log":
                                 "WALKTEST RESULT: FAIL [FAST]\n"}})
            self.assertEqual(code, 1)
            self.assertEqual(report["gate"]["result"], "BLOCKED_EVIDENCE")
            self.assertTrue(any("FAILURE" in b["detail"]
                                for b in report["blockers"]))

    def test_metadata_mismatch_blocks(self):
        with tempfile.TemporaryDirectory() as tmp:
            code, report = self.run_doc(
                tmp, self.doc_with_evidence(
                    "- `T9Shot`: PASS, three 1280x720 frames under "
                    "`art/renders/t9/`."),
                evidence={"t9": {
                    "00.png": png_bytes(), "01.png": png_bytes(),
                    "scene_capture_receipt.json": json.dumps({
                        "schema_version": 1, "status": "PASS",
                        "expected_frames": 2, "actual_frames": 2,
                        "captures": [
                            {"file": "00.png", "width": 1280, "height": 720},
                            {"file": "01.png", "width": 1280,
                             "height": 720}]})}})
            self.assertEqual(code, 1)
            self.assertEqual(report["gate"]["result"], "BLOCKED_EVIDENCE")
            self.assertTrue(any("mismatch" in b["category"] or
                                "claims 3" in b["detail"]
                                for b in report["blockers"]))

    def test_malformed_evidence_manifest_exit_four(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = make_root(tmp, {"ORISON_T1_OK_CHECKPOINT_TEST.md":
                                   LANDABLE_DOC})
            (root / "design" / "bad.evidence.json").write_text(json.dumps({
                "version": 1, "claims": [{"claim_id": "X"}]}),
                encoding="utf-8")
            out = Path(tmp) / "out"
            code = run_gate(root, out, "--checkpoints", str(root / "design"))
            self.assertEqual(code, 4)

    def test_verified_present_is_not_a_recorded_pass(self):
        with tempfile.TemporaryDirectory() as tmp:
            code, report = self.run_doc(
                tmp, self.doc_with_evidence(
                    "- Frames live under `art/renders/t9/`."),
                evidence={"t9": {"00.png": png_bytes()}})
            self.assertEqual(code, 0)   # present evidence, nothing symbolic
            counts = report["counts"]["evidence"]
            self.assertEqual(counts["VERIFIED_PRESENT"], 1)
            self.assertEqual(counts["RECORDED_PASS"], 0)


class PolicyModeTests(unittest.TestCase):
    def test_corpus_mode_reports_debt_without_blocking(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = make_root(tmp, {"ORISON_T1_OPEN_CHECKPOINT_TEST.md":
                                   OPEN_DOC})
            out = Path(tmp) / "out"
            code = run_gate(root, out, "--checkpoints",
                            str(root / "design"))
            self.assertEqual(code, 0)
            report = gate_json(out)
            self.assertEqual(report["gate"]["result"], "LANDABLE")
            self.assertFalse(report["gate"]["strict"])
            self.assertTrue(any(d["kind"] == "historical-open"
                                for d in report["debt"]))

    def test_strict_mode_blocks_the_same_document(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = make_root(tmp, {"ORISON_T1_OPEN_CHECKPOINT_TEST.md":
                                   OPEN_DOC})
            out = Path(tmp) / "out"
            code = run_gate(root, out, "--checkpoint",
                            str(root / "design" /
                                "ORISON_T1_OPEN_CHECKPOINT_TEST.md"))
            self.assertEqual(code, 1)


class ChangedSinceTests(unittest.TestCase):
    def git(self, root, *args):
        return subprocess.run(["git", "-C", str(root), *args],
                              capture_output=True, text=True, check=False)

    def make_repo(self, tmp):
        root = make_root(tmp, {"ORISON_T1_OLD_CHECKPOINT_TEST.md":
                               LANDABLE_DOC})
        for args in (("init", "-q"),
                     ("config", "user.email", "gate@test.local"),
                     ("config", "user.name", "Gate Test"),
                     ("add", "-A"), ("commit", "-qm", "base")):
            self.git(root, *args)
        sha = self.git(root, "rev-parse", "HEAD").stdout.strip()
        return root, sha

    def test_selects_only_changed_checkpoint_documents(self):
        with tempfile.TemporaryDirectory() as tmp:
            root, base = self.make_repo(tmp)
            (root / "design" / "ORISON_T1_NEW_CHECKPOINT_TEST.md").write_text(
                LANDABLE_DOC, encoding="utf-8")
            (root / "design" / "unrelated_notes.md").write_text(
                "not a checkpoint", encoding="utf-8")
            out = Path(tmp) / "out"
            code = gate.main(["--repository-root", str(root),
                              "--layout",
                              str(root / "art/data/building_layout.json"),
                              "--checkpoints", str(root / "design"),
                              "--changed-since", base,
                              "--output", str(out)])
            self.assertEqual(code, 0)
            report = gate_json(out)
            self.assertEqual(
                report["gate"]["selection"]["checkpoints"],
                ["design/ORISON_T1_NEW_CHECKPOINT_TEST.md"])
            self.assertTrue(report["gate"]["strict"])

    def test_deleted_checkpoint_is_a_review_condition(self):
        with tempfile.TemporaryDirectory() as tmp:
            root, base = self.make_repo(tmp)
            self.git(root, "rm", "-q",
                     "design/ORISON_T1_OLD_CHECKPOINT_TEST.md")
            out = Path(tmp) / "out"
            code = gate.main(["--repository-root", str(root),
                              "--layout",
                              str(root / "art/data/building_layout.json"),
                              "--checkpoints", str(root / "design"),
                              "--changed-since", base,
                              "--output", str(out)])
            self.assertEqual(code, 1)
            report = gate_json(out)
            self.assertEqual(report["gate"]["result"], "BLOCKED_REVIEW")
            self.assertEqual(report["deleted_checkpoints"],
                             ["design/ORISON_T1_OLD_CHECKPOINT_TEST.md"])

    def test_invalid_ref_and_no_git_are_usage_errors(self):
        with tempfile.TemporaryDirectory() as tmp:
            root, _ = self.make_repo(tmp)
            out = Path(tmp) / "out"
            code = gate.main(["--repository-root", str(root),
                              "--layout",
                              str(root / "art/data/building_layout.json"),
                              "--checkpoints", str(root / "design"),
                              "--changed-since", "no_such_ref",
                              "--output", str(out)])
            self.assertEqual(code, 3)
            self.assertFalse(out.exists() and any(out.iterdir()))
            code = gate.main(["--repository-root", str(root),
                              "--layout",
                              str(root / "art/data/building_layout.json"),
                              "--checkpoints", str(root / "design"),
                              "--changed-since", "HEAD", "--no-git",
                              "--output", str(out)])
            self.assertEqual(code, 3)


class SafetyAndCliTests(unittest.TestCase):
    def test_selection_must_be_explicit(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = make_root(tmp, {"ORISON_T1_OK_CHECKPOINT_TEST.md":
                                   LANDABLE_DOC})
            self.assertEqual(run_gate(root, Path(tmp) / "out"), 3)

    def test_component_internal_failure_publishes_blocked_internal(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = make_root(tmp, {"ORISON_T1_OK_CHECKPOINT_TEST.md":
                                   LANDABLE_DOC})
            out = Path(tmp) / "out"
            original = gate.RUNNERS["evidence"]
            gate.RUNNERS["evidence"] = lambda argv: (_ for _ in ()).throw(
                RuntimeError("synthetic evidence crash"))
            try:
                code = run_gate(root, out, "--checkpoint",
                                str(root / "design" /
                                    "ORISON_T1_OK_CHECKPOINT_TEST.md"))
            finally:
                gate.RUNNERS["evidence"] = original
            self.assertEqual(code, 70)
            report = gate_json(out)
            self.assertEqual(report["gate"]["result"], "BLOCKED_INTERNAL")
            self.assertIn("synthetic evidence crash",
                          report["components"]["evidence"]["error"])

    def test_missing_component_output_is_internal(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = make_root(tmp, {"ORISON_T1_OK_CHECKPOINT_TEST.md":
                                   LANDABLE_DOC})
            out = Path(tmp) / "out"
            original = gate.RUNNERS["reconciliation"]
            gate.RUNNERS["reconciliation"] = lambda argv: 0   # writes nothing
            try:
                code = run_gate(root, out, "--checkpoint",
                                str(root / "design" /
                                    "ORISON_T1_OK_CHECKPOINT_TEST.md"))
            finally:
                gate.RUNNERS["reconciliation"] = original
            self.assertEqual(code, 70)
            self.assertEqual(gate_json(out)["gate"]["result"],
                             "BLOCKED_INTERNAL")

    def test_no_overwrite_then_force(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = make_root(tmp, {"ORISON_T1_OK_CHECKPOINT_TEST.md":
                                   LANDABLE_DOC})
            out = Path(tmp) / "out"
            doc = str(root / "design" / "ORISON_T1_OK_CHECKPOINT_TEST.md")
            self.assertEqual(run_gate(root, out, "--checkpoint", doc), 0)
            stale = (out / "room_reconstruction_gate.json").read_bytes()
            self.assertEqual(run_gate(root, out, "--checkpoint", doc), 3)
            self.assertEqual(
                (out / "room_reconstruction_gate.json").read_bytes(), stale)
            self.assertEqual(run_gate(root, out, "--checkpoint", doc,
                                      "--force"), 0)

    def test_deterministic_byte_identical_output(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = make_root(tmp, {"ORISON_T1_OK_CHECKPOINT_TEST.md":
                                   LANDABLE_DOC})
            out = Path(tmp) / "out"
            doc = str(root / "design" / "ORISON_T1_OK_CHECKPOINT_TEST.md")
            argv = ["--checkpoint", doc, "--force"]
            self.assertEqual(run_gate(root, out, *argv), 0)
            first = {p.name: p.read_bytes()
                     for p in out.rglob("*") if p.is_file()}
            self.assertEqual(run_gate(root, out, *argv), 0)
            second = {p.name: p.read_bytes()
                      for p in out.rglob("*") if p.is_file()}
            self.assertEqual(first, second)

    def test_room_filter_scopes_progress_states(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = make_root(tmp, {"ORISON_T1_OK_CHECKPOINT_TEST.md":
                                   LANDABLE_DOC})
            out = Path(tmp) / "out"
            code = run_gate(root, out, "--checkpoint",
                            str(root / "design" /
                                "ORISON_T1_OK_CHECKPOINT_TEST.md"),
                            "--room", "T1_A")
            self.assertEqual(code, 0)
            report = gate_json(out)
            self.assertEqual(sorted(report["progress_states"]), ["T1_A"])

    def test_json_only_and_markdown_only(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = make_root(tmp, {"ORISON_T1_OK_CHECKPOINT_TEST.md":
                                   LANDABLE_DOC})
            doc = str(root / "design" / "ORISON_T1_OK_CHECKPOINT_TEST.md")
            out = Path(tmp) / "jo"
            run_gate(root, out, "--checkpoint", doc, "--json-only")
            self.assertTrue((out / "room_reconstruction_gate.json").exists())
            self.assertFalse((out / "room_reconstruction_gate.md").exists())
            out2 = Path(tmp) / "mo"
            run_gate(root, out2, "--checkpoint", doc, "--markdown-only")
            self.assertFalse((out2 / "room_reconstruction_gate.json").exists())
            self.assertTrue((out2 / "room_reconstruction_gate.md").exists())

    def test_components_preserved_in_packet(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = make_root(tmp, {"ORISON_T1_OK_CHECKPOINT_TEST.md":
                                   LANDABLE_DOC})
            out = Path(tmp) / "out"
            run_gate(root, out, "--checkpoint",
                     str(root / "design" / "ORISON_T1_OK_CHECKPOINT_TEST.md"))
            for sub, name in (("lint", None),
                              ("reconciliation", "room_checkpoint_status.json"),
                              ("evidence", "room_evidence_status.json"),
                              ("progress",
                               "room_reconstruction_progress.json")):
                d = out / "components" / sub
                self.assertTrue(d.is_dir(), sub)
                if name:
                    self.assertTrue((d / name).exists(), name)

    def test_ledger_never_emits_complete(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = make_root(tmp, {"ORISON_T1_OK_CHECKPOINT_TEST.md":
                                   LANDABLE_DOC})
            out = Path(tmp) / "out"
            run_gate(root, out, "--checkpoint",
                     str(root / "design" / "ORISON_T1_OK_CHECKPOINT_TEST.md"))
            report = gate_json(out)
            for states in report["progress_states"].values():
                for s in states:
                    self.assertNotIn("COMPLETE", s)


if __name__ == "__main__":
    unittest.main(verbosity=2)
