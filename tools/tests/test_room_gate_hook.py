#!/usr/bin/env python3
"""Focused self-tests for tools/room_gate_hook.py.

Every scenario runs inside a temporary Git repository; the real repository,
its index and its hooks are never touched.  Execute with:

    python tools/tests/test_room_gate_hook.py
"""

from __future__ import annotations

import io
import json
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stdout, redirect_stderr
from pathlib import Path

TOOLS_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS_DIR))

import room_gate_hook as hook            # noqa: E402
import room_reconstruction_gate as gate  # noqa: E402

FIXTURES = Path(__file__).resolve().parent / "fixtures"
MINI = FIXTURES / "mini_layout.json"

LANDABLE_DOC = """# Landable fixture

Covers `T1_A`.

## Object and architecture verdicts

| Room | Element | Verdict | Reason |
|---|---|---|---|
| A | `a_counter` | KEEP | Exact id, satisfied. |
| A | `long_gone` | KEEP ABSENT | Absence checkable. |
"""

SYMBOLIC_DOC = LANDABLE_DOC + "\n## Validation\n\n- Generator: PASS.\n"

BLOCKED_DOC = """# Blocked fixture

Covers `T1_A`.

## Object and architecture verdicts

| Room | Element | Verdict | Reason |
|---|---|---|---|
| A | `vanished_thing` | KEEP | Never existed; contradicted. |
"""

MALFORMED_DOC = """# Malformed fixture

Covers `T1_A`.

## Object and architecture verdicts

| Room | Element | Verdict | Reason |
|---|---|---|---|
| A | `a_counter` | FROBNICATE | Not a verdict. |
"""

MANIFEST = json.dumps({
    "version": 1, "decisions": [
        {"room": "T1_A", "object": "a_rug", "verdict": "MOVE",
         "expected": {"room": "T1_A", "position": [2.15, 1.45],
                      "tolerance_m": 0.05},
         "rationale": "centre the rug"}]})


def git(root, *args):
    return subprocess.run(["git", "-C", str(root), *args],
                          capture_output=True, text=True, check=False)


def make_repo(tmp, docs=None, commit=True, with_layout=True):
    root = Path(tmp) / "gate hook repo"     # path with spaces, deliberately
    (root / "design").mkdir(parents=True)
    for name, text in (docs or {}).items():
        (root / "design" / name).write_text(text, encoding="utf-8")
    if with_layout:
        (root / "art" / "data").mkdir(parents=True)
        shutil.copy(MINI, root / "art" / "data" / "building_layout.json")
    for args in (("init", "-q"),
                 ("config", "user.email", "hook@test.local"),
                 ("config", "user.name", "Hook Test"),
                 ("config", "core.autocrlf", "false")):
        git(root, *args)
    if commit and (docs or with_layout):
        for name in (docs or {}):
            git(root, "add", f"design/{name}")
        if with_layout:
            git(root, "add", "art/data/building_layout.json")
        git(root, "commit", "-qm", "base")
    return root


def run_hook(root, *extra):
    out, err = io.StringIO(), io.StringIO()
    with redirect_stdout(out), redirect_stderr(err):
        code = hook.main(["--repository-root", str(root), "--no-color",
                          *extra])
    return code, out.getvalue(), err.getvalue()


def index_state(root):
    return git(root, "ls-files", "-s").stdout


class TriggerTests(unittest.TestCase):
    def test_no_relevant_staged_files_skips_cleanly(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = make_repo(tmp, {"ORISON_T1_OK_CHECKPOINT_TEST.md":
                                   LANDABLE_DOC})
            code, out, _ = run_hook(root)
            self.assertEqual(code, 0)
            self.assertIn("skipped cleanly", out)

    def test_unrelated_staged_file_does_not_trigger(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = make_repo(tmp, {"ORISON_T1_OK_CHECKPOINT_TEST.md":
                                   LANDABLE_DOC})
            (root / "art" / "poster.txt").write_text("art", encoding="utf-8")
            git(root, "add", "art/poster.txt")
            code, out, _ = run_hook(root)
            self.assertEqual(code, 0)
            self.assertIn("skipped cleanly", out)

    def test_newly_added_staged_checkpoint_gates_strictly(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = make_repo(tmp, {})
            (root / "design" / "ORISON_T1_NEW_CHECKPOINT_TEST.md").write_text(
                LANDABLE_DOC, encoding="utf-8")
            git(root, "add", "design/ORISON_T1_NEW_CHECKPOINT_TEST.md")
            code, out, _ = run_hook(root)
            self.assertEqual(code, 0)
            self.assertIn("LANDABLE", out)
            self.assertIn("ORISON_T1_NEW_CHECKPOINT_TEST.md", out)

    def test_staged_manifest_triggers_and_pulls_sibling_checkpoint(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = make_repo(tmp, {"ORISON_T1_OK_CHECKPOINT_TEST.md":
                                   LANDABLE_DOC})
            man = root / "design" / "ORISON_T1_OK_CHECKPOINT_TEST.decisions.json"
            man.write_text(MANIFEST, encoding="utf-8")
            git(root, "add", "design/ORISON_T1_OK_CHECKPOINT_TEST.decisions.json")
            code, out, _ = run_hook(root)
            self.assertEqual(code, 0)
            self.assertIn(".decisions.json", out)
            self.assertIn("ORISON_T1_OK_CHECKPOINT_TEST.md", out)

    def test_staged_checkpoint_deletion_blocks_for_review(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = make_repo(tmp, {"ORISON_T1_OK_CHECKPOINT_TEST.md":
                                   LANDABLE_DOC})
            git(root, "rm", "-q", "design/ORISON_T1_OK_CHECKPOINT_TEST.md")
            code, out, _ = run_hook(root)
            self.assertEqual(code, 1)
            self.assertIn("DELETION", out)
            self.assertIn("deliberate review", out)

    def test_layout_only_change_runs_corpus_safety(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = make_repo(tmp, {"ORISON_T1_OK_CHECKPOINT_TEST.md":
                                   LANDABLE_DOC})
            layout = json.loads(MINI.read_text("utf-8"))
            layout["meta"]["name"] = "Edited Fixture House"
            (root / "art" / "data" / "building_layout.json").write_text(
                json.dumps(layout), encoding="utf-8")
            git(root, "add", "art/data/building_layout.json")
            code, out, _ = run_hook(root)
            self.assertEqual(code, 0)
            self.assertIn("whole-corpus safety gate", out)
            self.assertIn("not a strict checkpoint gate", out)

    def test_exact_selection_gates_only_staged_documents(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = make_repo(tmp, {
                "ORISON_T1_OK_CHECKPOINT_TEST.md": LANDABLE_DOC,
                "ORISON_T1_OTHER_CHECKPOINT_TEST.md": LANDABLE_DOC})
            (root / "design" / "ORISON_T1_THIRD_CHECKPOINT_TEST.md"
             ).write_text(SYMBOLIC_DOC, encoding="utf-8")
            git(root, "add", "design/ORISON_T1_THIRD_CHECKPOINT_TEST.md")
            code, out, _ = run_hook(root)
            self.assertEqual(code, 0)
            self.assertIn("ORISON_T1_THIRD_CHECKPOINT_TEST.md", out)
            self.assertNotIn("ORISON_T1_OTHER_CHECKPOINT_TEST.md", out)


class IndexTruthTests(unittest.TestCase):
    def test_staged_version_wins_over_working_tree(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = make_repo(tmp, {"ORISON_T1_OK_CHECKPOINT_TEST.md":
                                   LANDABLE_DOC})
            doc = root / "design" / "ORISON_T1_OK_CHECKPOINT_TEST.md"
            doc.write_text(BLOCKED_DOC, encoding="utf-8")
            git(root, "add", "design/ORISON_T1_OK_CHECKPOINT_TEST.md")
            doc.write_text(LANDABLE_DOC, encoding="utf-8")   # unstaged again
            code, out, _ = run_hook(root)
            self.assertEqual(code, 1)   # the STAGED (blocked) version gated
            self.assertIn("BLOCKED", out)

    def test_unstaged_checkpoint_edit_is_excluded(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = make_repo(tmp, {"ORISON_T1_OK_CHECKPOINT_TEST.md":
                                   LANDABLE_DOC})
            (root / "design" / "ORISON_T1_OK_CHECKPOINT_TEST.md").write_text(
                BLOCKED_DOC, encoding="utf-8")     # blocked, NOT staged
            layout = json.loads(MINI.read_text("utf-8"))
            layout["meta"]["name"] = "Edited"
            (root / "art" / "data" / "building_layout.json").write_text(
                json.dumps(layout), encoding="utf-8")
            git(root, "add", "art/data/building_layout.json")
            code, out, _ = run_hook(root)
            self.assertEqual(code, 0)   # index still holds the landable doc

    def test_index_and_worktree_unchanged(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = make_repo(tmp, {})
            (root / "design" / "ORISON_T1_NEW_CHECKPOINT_TEST.md").write_text(
                LANDABLE_DOC, encoding="utf-8")
            git(root, "add", "design/ORISON_T1_NEW_CHECKPOINT_TEST.md")
            before_index = index_state(root)
            before_status = git(root, "status", "--porcelain").stdout
            before_bytes = (root / "design" /
                            "ORISON_T1_NEW_CHECKPOINT_TEST.md").read_bytes()
            code, _, _ = run_hook(root)
            self.assertEqual(code, 0)
            self.assertEqual(index_state(root), before_index)
            self.assertEqual(git(root, "status", "--porcelain").stdout,
                             before_status)
            self.assertEqual((root / "design" /
                              "ORISON_T1_NEW_CHECKPOINT_TEST.md").read_bytes(),
                             before_bytes)

    def test_works_before_first_commit(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = make_repo(tmp, {}, commit=False)
            (root / "design" / "ORISON_T1_NEW_CHECKPOINT_TEST.md").write_text(
                LANDABLE_DOC, encoding="utf-8")
            git(root, "add", "design/ORISON_T1_NEW_CHECKPOINT_TEST.md",
                "art/data/building_layout.json")
            code, out, _ = run_hook(root)
            self.assertEqual(code, 0)
            self.assertIn("LANDABLE", out)


class PolicyTests(unittest.TestCase):
    def stage_doc(self, tmp, name, text):
        root = make_repo(tmp, {})
        (root / "design" / name).write_text(text, encoding="utf-8")
        git(root, "add", f"design/{name}")
        return root

    def test_exit_two_symbolic_is_allowed(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self.stage_doc(tmp, "ORISON_T1_S_CHECKPOINT_TEST.md",
                                  SYMBOLIC_DOC)
            code, out, _ = run_hook(root)
            self.assertEqual(code, 0)
            self.assertIn("LANDABLE_WITH_SYMBOLIC_EVIDENCE", out)
            self.assertIn("symbolic evidence debt", out)

    def test_blocked_checkpoint_exit_one(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self.stage_doc(tmp, "ORISON_T1_B_CHECKPOINT_TEST.md",
                                  BLOCKED_DOC)
            code, out, _ = run_hook(root)
            self.assertEqual(code, 1)
            self.assertIn("blockers", out)

    def test_malformed_checkpoint_exit_four(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self.stage_doc(tmp, "ORISON_T1_M_CHECKPOINT_TEST.md",
                                  MALFORMED_DOC)
            code, _, _ = run_hook(root)
            self.assertEqual(code, 4)

    def test_blocked_plus_malformed_exit_five(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = make_repo(tmp, {})
            for name, text in (("ORISON_T1_B_CHECKPOINT_TEST.md",
                                BLOCKED_DOC),
                               ("ORISON_T1_M_CHECKPOINT_TEST.md",
                                MALFORMED_DOC)):
                (root / "design" / name).write_text(text, encoding="utf-8")
                git(root, "add", f"design/{name}")
            code, _, _ = run_hook(root)
            self.assertEqual(code, 5)

    def test_advisory_mode_reports_but_exits_zero(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self.stage_doc(tmp, "ORISON_T1_B_CHECKPOINT_TEST.md",
                                  BLOCKED_DOC)
            code, out, _ = run_hook(root, "--advisory")
            self.assertEqual(code, 0)
            self.assertIn("ADVISORY", out)
            self.assertIn("BLOCKED", out)

    def test_untrustworthy_snapshot_blocks_internal(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = make_repo(tmp, {}, with_layout=False)
            (root / "design" / "ORISON_T1_X_CHECKPOINT_TEST.md").write_text(
                LANDABLE_DOC, encoding="utf-8")
            git(root, "add", "design/ORISON_T1_X_CHECKPOINT_TEST.md")
            code, _, err = run_hook(root)
            self.assertEqual(code, 70)
            self.assertIn("trustworthy", err)

    def test_outside_a_repository_is_a_config_error(self):
        with tempfile.TemporaryDirectory() as tmp:
            code, _, err = run_hook(Path(tmp))
            self.assertEqual(code, 3)
            self.assertIn("not a git repository", err)


class SafetyAndOutputTests(unittest.TestCase):
    def landable_repo(self, tmp):
        root = make_repo(tmp, {})
        (root / "design" / "ORISON_T1_NEW_CHECKPOINT_TEST.md").write_text(
            LANDABLE_DOC, encoding="utf-8")
        git(root, "add", "design/ORISON_T1_NEW_CHECKPOINT_TEST.md")
        return root

    def test_packet_preserved_in_keep_packet_dir(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self.landable_repo(tmp)
            packet = Path(tmp) / "packet out"
            code, out, _ = run_hook(root, "--keep-packet", str(packet))
            self.assertEqual(code, 0)
            self.assertTrue((packet /
                             "room_reconstruction_gate.json").exists())
            self.assertIn(str(packet), out)
            self.assertIn("were not modified", out)

    def test_snapshot_cleaned_by_default_and_kept_on_request(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self.landable_repo(tmp)
            code, out, err = run_hook(root)
            self.assertEqual(code, 0)
            m = re.search(r"exact Git index export \((.+?)\); gate ran", out)
            self.assertTrue(m, out)
            self.assertFalse(Path(m.group(1)).exists())
            code, out, err = run_hook(root, "--keep-snapshot")
            m = re.search(r"snapshot kept for diagnosis: (.+)", err)
            self.assertTrue(m, err)
            snap = Path(m.group(1).strip())
            self.assertTrue(snap.exists())
            hook.detach_links(snap)
            shutil.rmtree(snap, ignore_errors=True)

    def test_deterministic_concise_output(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self.landable_repo(tmp)
            packet = Path(tmp) / "pk"

            def normalized(text):
                text = text.replace(str(packet), "<PACKET>")
                return re.sub(r"exact Git index export \(.+?\);",
                              "exact Git index export (<SNAP>);", text)

            _, out1, _ = run_hook(root, "--keep-packet", str(packet))
            shutil.rmtree(packet)
            _, out2, _ = run_hook(root, "--keep-packet", str(packet))
            self.assertEqual(normalized(out1), normalized(out2))

    def test_snapshot_gate_uses_staged_tool_sources_when_present(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = make_repo(tmp, {})
            (root / "tools").mkdir()
            for tool in ("room_layout_workbench.py",
                         "room_checkpoint_reconciler.py",
                         "room_checkpoint_linter.py",
                         "room_evidence_verifier.py",
                         "room_reconstruction_progress.py",
                         "room_reconstruction_gate.py",
                         "audit_orison_rooms.py"):
                shutil.copy(TOOLS_DIR / tool, root / "tools" / tool)
                git(root, "add", f"tools/{tool}")
            git(root, "commit", "-qm", "tools")
            (root / "design" / "ORISON_T1_NEW_CHECKPOINT_TEST.md").write_text(
                LANDABLE_DOC, encoding="utf-8")
            git(root, "add", "design/ORISON_T1_NEW_CHECKPOINT_TEST.md")
            code, out, _ = run_hook(root)
            self.assertEqual(code, 0)
            self.assertIn("staged snapshot tools", out)

    def test_print_hook_installs_nothing(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self.landable_repo(tmp)
            code, out, _ = run_hook(root, "--print-hook")
            self.assertEqual(code, 0)
            self.assertIn("pre-commit", out)
            self.assertIn("room_gate_hook.py", out)
            hooks_dir = root / ".git" / "hooks"
            self.assertFalse((hooks_dir / "pre-commit").exists())


class GateSelectionTests(unittest.TestCase):
    def test_gate_accepts_repeatable_checkpoint(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "plain root"
            (root / "design").mkdir(parents=True)
            (root / "art" / "data").mkdir(parents=True)
            shutil.copy(MINI, root / "art" / "data" / "building_layout.json")
            for name in ("ORISON_T1_A_CHECKPOINT_TEST.md",
                         "ORISON_T1_B_CHECKPOINT_TEST.md"):
                (root / "design" / name).write_text(LANDABLE_DOC,
                                                    encoding="utf-8")
            out = Path(tmp) / "out"
            code = gate.main([
                "--repository-root", str(root),
                "--layout", str(root / "art/data/building_layout.json"),
                "--checkpoints", str(root / "design"),
                "--checkpoint",
                str(root / "design" / "ORISON_T1_A_CHECKPOINT_TEST.md"),
                "--checkpoint",
                str(root / "design" / "ORISON_T1_B_CHECKPOINT_TEST.md"),
                "--output", str(out), "--no-git"])
            self.assertEqual(code, 0)
            report = json.loads(
                (out / "room_reconstruction_gate.json").read_text("utf-8"))
            self.assertEqual(
                len(report["gate"]["selection"]["checkpoints"]), 2)
            self.assertTrue(report["gate"]["strict"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
