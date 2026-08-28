#!/usr/bin/env python3
"""Focused self-tests for tools/audit_interaction_prompt_carriers.py.

Runs against synthetic fixtures only; production GDScript is never modified
and (except one read-only whole-tree smoke test) never read.  Execute with:

    python tools/tests/test_interaction_prompt_carriers.py
"""

from __future__ import annotations

import io
import json
import shutil
import sys
import tempfile
import unittest
from contextlib import redirect_stdout, redirect_stderr
from pathlib import Path

TOOLS_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS_DIR))

import audit_interaction_prompt_carriers as audit  # noqa: E402

FIXTURES = Path(__file__).resolve().parent / "fixtures" / "prompt_carriers"


def run_main(*argv):
    out, err = io.StringIO(), io.StringIO()
    with redirect_stdout(out), redirect_stderr(err):
        code = audit.main(list(argv))
    return code, out.getvalue(), err.getvalue()


def run_json(root, baseline, *extra):
    code, out, _ = run_main("--root", str(root), "--baseline", str(baseline),
                            "--json", *extra)
    return code, json.loads(out)


class ClassifyLiteralTests(unittest.TestCase):
    def cls(self, text):
        return audit.classify_literal(text)[0]

    def test_clean_semantic_prompts(self):
        self.assertEqual(self.cls("Open the wardrobe"), "CLEAN")
        self.assertEqual(self.cls("Enter the apartment"), "CLEAN")
        self.assertEqual(self.cls("Press the carriage lever"), "CLEAN")
        self.assertEqual(self.cls("Press a number."), "CLEAN")
        self.assertEqual(self.cls("Tap the barrel for leaks"), "CLEAN")
        self.assertEqual(self.cls("Shift the crate aside"), "CLEAN")
        self.assertEqual(self.cls("Escape through the window"), "CLEAN")

    def test_bracket_carriers(self):
        self.assertEqual(self.cls("[E]  Open"), "LEGACY_E")
        self.assertEqual(self.cls("[A]  Open"), "FORBIDDEN_CONTROLLER")
        self.assertEqual(self.cls("[TAP]  Ring"), "FORBIDDEN_TOUCH")
        self.assertEqual(self.cls("[SPACE] Jump"), "FORBIDDEN_KEYBOARD")
        self.assertEqual(self.cls("[F]  Salute"), "FORBIDDEN_KEYBOARD")
        self.assertEqual(self.cls("[RMB] Aim"), "FORBIDDEN_MOUSE")
        self.assertEqual(self.cls("[WHAT] Odd"), "FORBIDDEN_OTHER")

    def test_glyph_carrier(self):
        self.assertEqual(self.cls("Ⓐ Open the hatch"),
                         "FORBIDDEN_CONTROLLER")

    def test_instructional_key_names(self):
        self.assertEqual(self.cls("Press Escape to step away"),
                         "FORBIDDEN_KEYBOARD")
        self.assertEqual(self.cls("Hold E — winding…"),
                         "FORBIDDEN_KEYBOARD")
        self.assertEqual(self.cls("Press E"), "FORBIDDEN_KEYBOARD")
        self.assertEqual(self.cls("Press A to confirm"),
                         "FORBIDDEN_CONTROLLER")
        self.assertEqual(self.cls("hold Shift and pull"),
                         "FORBIDDEN_KEYBOARD")

    def test_mouse_and_pad_instructions(self):
        self.assertEqual(self.cls("Right-click the drawer"),
                         "FORBIDDEN_MOUSE")
        self.assertEqual(self.cls("left click to open"), "FORBIDDEN_MOUSE")
        self.assertEqual(self.cls("Use the left stick to steer"),
                         "FORBIDDEN_CONTROLLER")
        self.assertEqual(self.cls("double-tap to sprint"),
                         "FORBIDDEN_TOUCH")


class ScanTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.results = audit.scan_tree(FIXTURES)

    def by_file(self, name):
        return [f for f in self.results["findings"]
                if f["file"].endswith(name)]

    def test_clean_prop_produces_no_findings(self):
        self.assertEqual(self.by_file("clean_prop.gd"), [])

    def test_direct_carriers_detected_with_method_and_family(self):
        pad = self.by_file("forbidden_pad.gd")
        self.assertEqual(len(pad), 1)
        self.assertEqual(pad[0]["classification"], "FORBIDDEN_CONTROLLER")
        self.assertEqual(pad[0]["method"], "interact_prompt")
        touch = self.by_file("forbidden_touch.gd")
        self.assertEqual(touch[0]["classification"], "FORBIDDEN_TOUCH")
        self.assertEqual(touch[0]["family"], "control_prompt")

    def test_conditional_and_ternary_returns_covered(self):
        kb = self.by_file("keyboard_prop.gd")
        self.assertEqual(len(kb), 3)
        self.assertTrue(all(f["classification"] == "FORBIDDEN_KEYBOARD"
                            for f in kb))
        mouse = self.by_file("mouse_prop.gd")
        self.assertEqual(len(mouse), 2)

    def test_concatenated_carrier_detected(self):
        cat = self.by_file("concat_prop.gd")
        self.assertEqual(cat[0]["classification"], "FORBIDDEN_TOUCH")

    def test_constant_referenced_by_method_detected(self):
        const = self.by_file("const_prop.gd")
        self.assertTrue(any(f["via"].startswith("const HATCH_PROMPT")
                            for f in const))
        self.assertEqual(const[0]["classification"], "FORBIDDEN_CONTROLLER")

    def test_comment_only_carrier_is_separate_and_nonfailing(self):
        self.assertEqual(self.by_file("comment_prop.gd"), [])
        comments = [c for c in self.results["comments"]
                    if c["file"].endswith("comment_prop.gd")]
        self.assertEqual(len(comments), 1)
        self.assertEqual(comments[0]["classification"], "COMMENT_ONLY")

    def test_string_outside_prompt_method_not_a_finding(self):
        self.assertEqual(self.by_file("outside_prop.gd"), [])
        outside = [c for c in self.results["outside"]
                   if c["file"].endswith("outside_prop.gd")]
        self.assertEqual(outside[0]["classification"],
                         "NOT_A_PROMPT_RETURN")

    def test_unresolved_dynamic_prompt_marked_separately(self):
        dyn = [d for d in self.results["dynamics"]
               if d["file"].endswith("dynamic_prop.gd")]
        self.assertEqual(len(dyn), 1)
        self.assertEqual(dyn[0]["classification"], "AMBIGUOUS_DYNAMIC")

    def test_debug_only_implementation_reclassified(self):
        debug = [f for f in self.results["debug_findings"]
                 if f["file"] == "characters/npc_placeholder.gd"]
        self.assertEqual(len(debug), 1)
        self.assertEqual(debug[0]["classification"], "DEBUG_ONLY")
        self.assertNotIn("characters/npc_placeholder.gd",
                         {f["file"] for f in self.results["findings"]})

    def test_include_debug_promotes_debug_files(self):
        promoted = audit.scan_tree(FIXTURES, include_debug=True)
        self.assertIn("characters/npc_placeholder.gd",
                      {f["file"] for f in promoted["findings"]})


class BaselineTests(unittest.TestCase):
    def make_root(self, tmp, files):
        root = Path(tmp) / "root"
        (root / "props").mkdir(parents=True)
        for name in files:
            shutil.copy(FIXTURES / "props" / name, root / "props" / name)
        return root

    def test_legacy_without_baseline_fails_then_baseline_covers(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self.make_root(tmp, ["legacy_prop.gd"])
            baseline = Path(tmp) / "baseline.json"
            code, report = run_json(root, baseline)
            self.assertEqual(code, 1)
            self.assertEqual(report["summary"]["legacy_uncovered"], 1)
            code, _, _ = run_main("--root", str(root), "--baseline",
                                  str(baseline), "--update-baseline")
            code, report = run_json(root, baseline)
            self.assertEqual(code, 0)
            self.assertEqual(report["summary"]["legacy_covered"], 1)

    def test_new_legacy_occurrence_fails(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self.make_root(tmp, ["legacy_prop.gd"])
            baseline = Path(tmp) / "baseline.json"
            run_main("--root", str(root), "--baseline", str(baseline),
                     "--update-baseline")
            extra = root / "props" / "new_legacy.gd"
            extra.write_text(
                "extends Node\n\n\nfunc interact_prompt() -> String:\n"
                "\treturn \"[E]  Brand new legacy\"\n", encoding="utf-8")
            code, report = run_json(root, baseline)
            self.assertEqual(code, 1)
            self.assertEqual(report["summary"]["legacy_uncovered"], 1)

    def test_removed_legacy_is_cleanup_opportunity_not_failure(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self.make_root(tmp, ["legacy_prop.gd"])
            baseline = Path(tmp) / "baseline.json"
            run_main("--root", str(root), "--baseline", str(baseline),
                     "--update-baseline")
            (root / "props" / "legacy_prop.gd").write_text(
                "extends Node\n\n\nfunc interact_prompt() -> String:\n"
                "\treturn \"Open the coal chute\"\n", encoding="utf-8")
            code, report = run_json(root, baseline)
            self.assertEqual(code, 0)
            self.assertEqual(
                report["summary"]["baseline_cleanup_opportunities"], 1)

    def test_stale_baseline_entry_fails_distinctly(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self.make_root(tmp, ["legacy_prop.gd"])
            baseline = Path(tmp) / "baseline.json"
            run_main("--root", str(root), "--baseline", str(baseline),
                     "--update-baseline")
            (root / "props" / "legacy_prop.gd").unlink()
            code, report = run_json(root, baseline)
            self.assertEqual(code, 4)
            self.assertEqual(report["summary"]["baseline_stale"], 1)

    def test_baseline_never_covers_forbidden_carriers(self):
        with tempfile.TemporaryDirectory() as tmp:
            baseline = Path(tmp) / "baseline.json"
            baseline.write_text(json.dumps({"version": 1, "entries": [
                {"file": "props/forbidden_pad.gd",
                 "method": "interact_prompt", "token": "[A]",
                 "literal": "[A]  Open the hatch",
                 "justification": "nope"}]}), encoding="utf-8")
            root = self.make_root(tmp, ["forbidden_pad.gd"])
            code, _, err = run_main("--root", str(root), "--baseline",
                                    str(baseline))
            self.assertEqual(code, 3)
            self.assertIn("never suppresses", err)

    def test_malformed_baseline_is_a_usage_error(self):
        with tempfile.TemporaryDirectory() as tmp:
            baseline = Path(tmp) / "baseline.json"
            baseline.write_text("{not json", encoding="utf-8")
            root = self.make_root(tmp, ["clean_prop.gd"])
            code, _, err = run_main("--root", str(root), "--baseline",
                                    str(baseline))
            self.assertEqual(code, 3)

    def test_combined_forbidden_plus_stale_exit_five(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self.make_root(tmp, ["legacy_prop.gd"])
            baseline = Path(tmp) / "baseline.json"
            run_main("--root", str(root), "--baseline", str(baseline),
                     "--update-baseline")
            (root / "props" / "legacy_prop.gd").unlink()
            shutil.copy(FIXTURES / "props" / "forbidden_pad.gd",
                        root / "props" / "forbidden_pad.gd")
            code, report = run_json(root, baseline)
            self.assertEqual(code, 5)


class CliTests(unittest.TestCase):
    def test_deterministic_json_output(self):
        with tempfile.TemporaryDirectory() as tmp:
            baseline = Path(tmp) / "b.json"
            _, out1 = run_json(FIXTURES, baseline)
            _, out2 = run_json(FIXTURES, baseline)
            self.assertEqual(out1, out2)

    def test_fixture_tree_exit_and_counts(self):
        with tempfile.TemporaryDirectory() as tmp:
            code, report = run_json(FIXTURES, Path(tmp) / "b.json")
            self.assertEqual(code, 1)
            summary = report["summary"]
            self.assertEqual(summary["forbidden"], 10)
            self.assertEqual(summary["legacy_uncovered"], 1)
            self.assertEqual(summary["ambiguous_dynamic"], 1)
            self.assertEqual(summary["comment_only"], 1)
            self.assertEqual(summary["debug_only"], 1)

    def test_missing_root_is_usage_error(self):
        code, _, err = run_main("--root", "no/such/dir")
        self.assertEqual(code, 3)

    def test_operates_without_godot_or_git_metadata(self):
        # Fixtures live outside any .git checkout when copied to temp.
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "bare"
            shutil.copytree(FIXTURES, root)
            code, report = run_json(root, Path(tmp) / "b.json")
            self.assertEqual(code, 1)
            self.assertGreater(report["summary"]["prompt_methods"], 0)


class ProductionSmokeTests(unittest.TestCase):
    """Read-only checks against the real tree with the checked-in baseline."""

    def test_production_counts_match_interaction_contract(self):
        code, report = run_json(audit.DEFAULT_ROOT, audit.DEFAULT_BASELINE)
        summary = report["summary"]
        # 66 interact_prompt + 18 control_prompt definers (contract SSC.1).
        self.assertEqual(summary["prompt_methods"], 84)
        self.assertEqual(summary["legacy_uncovered"], 0)
        self.assertEqual(summary["baseline_stale"], 0)

    def test_known_production_violation_is_reported_not_suppressed(self):
        code, report = run_json(audit.DEFAULT_ROOT, audit.DEFAULT_BASELINE)
        files = {f["file"] for f in report["forbidden"]}
        self.assertIn("props/clock_prop.gd", files)
        self.assertEqual(code, 1)


if __name__ == "__main__":
    unittest.main(verbosity=2)
