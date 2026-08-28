#!/usr/bin/env python3
"""Focused self-tests for tools/audit_systemic_situation_authority.py.

Runs against a synthetic mini repository (copied to a temp dir per
mutating test).  Production files are never modified.  Execute with:

    python tools/tests/test_systemic_situation_authority.py
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
REPO_ROOT = TOOLS_DIR.parent
sys.path.insert(0, str(TOOLS_DIR))

import audit_systemic_situation_authority as audit  # noqa: E402

MINI_REPO = Path(__file__).resolve().parent / "fixtures" / \
    "situation_authority" / "mini_repo"
COORDINATOR = "game/scripts/campaign/story_coordinator_director.gd"


def run_main(*argv):
    out, err = io.StringIO(), io.StringIO()
    with redirect_stdout(out), redirect_stderr(err):
        code = audit.main(list(argv))
    return code, out.getvalue(), err.getvalue()


def run_findings(root, *extra):
    code, out, err = run_main("--root", str(root), "--json", *extra)
    payload = json.loads(out) if out.strip().startswith("{") else {}
    return code, payload.get("findings", []), payload


def of_class(findings, cls):
    return [f for f in findings if f["class"] == cls]


class TempRepo:
    def __enter__(self) -> Path:
        self._dir = tempfile.mkdtemp(prefix="situation_authority_")
        self.root = Path(self._dir) / "repo"
        shutil.copytree(MINI_REPO, self.root)
        return self.root

    def __exit__(self, *exc):
        shutil.rmtree(self._dir, ignore_errors=True)


def write_baseline(root: Path) -> Path:
    target = root / "tools/baseline.json"
    code, _out, err = run_main("--root", str(root), "--write-baseline",
                               str(target))
    assert code == 0, err
    return target


class DetectionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.code, cls.findings, cls.payload = run_findings(MINI_REPO)

    def test_coordinator_knowledge_write_flagged(self):
        hits = of_class(self.findings, "DIRECT_NPC_KNOWLEDGE_WRITE")
        self.assertEqual(len(hits), 1)
        self.assertEqual(hits[0]["scope"], "fabricate_knowledge")
        self.assertEqual(hits[0]["confidence"], "STRONG")
        self.assertEqual(hits[0]["disposition"], "DELEGATE_TO_OWNER")

    def test_npc_authority_own_perception_not_flagged(self):
        self.assertFalse([f for f in self.findings
                          if "neighbor_resident" in f["file"]])

    def test_timer_apply_flagged_scheduling_not(self):
        hits = of_class(self.findings, "TIMER_IMPERSONATES_ACTOR")
        scopes = {h["scope"] for h in hits}
        self.assertIn("timer_applies_consequence", scopes)
        self.assertNotIn("timer_schedules_only", scopes)

    def test_inventory_authority_vs_string_custody(self):
        hits = of_class(self.findings, "DUPLICATE_CUSTODY")
        self.assertEqual(len(hits), 1)
        self.assertEqual(hits[0]["scope"], "string_custody")
        self.assertNotIn("maintenance_inventory",
                         hits[0]["file"])

    def test_direct_mutation_vs_domain_api(self):
        hits = of_class(self.findings, "FOREIGN_PHYSICAL_MUTATION")
        scopes = {h["scope"] for h in hits}
        self.assertIn("foreign_mechanism_write", scopes)
        self.assertIn("foreign_job_write", scopes)
        self.assertNotIn("delegated_mechanism_call", scopes)

    def test_foreign_reality_data_names_owner(self):
        hits = [f for f in of_class(self.findings,
                                    "FOREIGN_PHYSICAL_MUTATION")
                if f["scope"] == "foreign_job_write"]
        self.assertIn("work_orders.gd", hits[0]["rightful_owner"])

    def test_unix_time_profiling_vs_durable(self):
        hits = of_class(self.findings, "HOST_CLOCK_MUTATES_WORLD")
        scopes = {h["scope"] for h in hits}
        self.assertIn("stamp_host_clock", scopes)
        self.assertNotIn("measure_perf", scopes)

    def test_objective_hud_vs_diegetic_paper(self):
        hits = of_class(self.findings, "OBJECTIVE_UI_LEAK")
        self.assertEqual(len(hits), 1)
        self.assertIn("goal_banner", hits[0]["file"])
        self.assertFalse([f for f in self.findings
                          if "steam_radiator_prop" in f["file"]])

    def test_single_path_compliance_vs_compensator(self):
        hits = of_class(self.findings, "COMPLIANCE_DEAD_END")
        files = {h["file"] for h in hits}
        self.assertTrue(any("permit_stage" in f for f in files))
        self.assertFalse(any("relief_stage" in f for f in files))
        self.assertEqual(hits[0]["confidence"], "HEURISTIC")

    def test_scene_local_autonomy_risk(self):
        hits = of_class(self.findings,
                        "AUTONOMY_DEPENDS_ON_PROXIMITY")
        self.assertTrue(any(h["scope"] == "_process" for h in hits))

    def test_internal_shortcut_vs_public_interaction(self):
        hits = of_class(self.findings, "TEST_AUTHORITY_SHORTCUT")
        self.assertEqual(len(hits), 1)
        self.assertIn("open_meddle_proof_test", hits[0]["file"])
        self.assertEqual(hits[0]["tier"], "test")
        self.assertFalse([f for f in self.findings
                          if "public_interaction_test" in f["file"]])

    def test_dynamic_unresolved(self):
        hits = of_class(self.findings, "DYNAMIC_UNRESOLVED")
        self.assertTrue(hits)
        self.assertEqual(hits[0]["confidence"], "UNKNOWN")

    def test_abstract_judgment(self):
        hits = of_class(self.findings, "ABSTRACT_JUDGMENT_FACT")
        self.assertEqual(len(hits), 1)
        self.assertIn("verdict_director", hits[0]["file"])
        self.assertEqual(hits[0]["disposition"], "FIX")

    def test_every_finding_is_fully_formed(self):
        for finding in self.findings:
            self.assertIn(finding["class"], audit.CLASSES)
            self.assertIn(finding["confidence"], audit.CONFIDENCES)
            self.assertIn(finding["disposition"], audit.DISPOSITIONS)
            for field in ("id", "file", "scope", "evidence", "writer",
                          "rightful_owner", "risk", "verify", "tier"):
                self.assertTrue(finding.get(field), field)

    def test_no_git_metadata_needed(self):
        self.assertFalse((MINI_REPO / ".git").exists())


class ModeTests(unittest.TestCase):
    def test_domain_filter(self):
        _c, findings, _p = run_findings(MINI_REPO, "--domain",
                                        "npc-knowledge")
        self.assertTrue(findings)
        self.assertTrue(all(f["domain"] == "npc-knowledge"
                            for f in findings))

    def test_production_only_excludes_tests(self):
        _c, findings, _p = run_findings(MINI_REPO, "--production-only")
        self.assertFalse([f for f in findings if f["tier"] == "test"])

    def test_deterministic_output(self):
        _c1, out1, _ = run_main("--root", str(MINI_REPO), "--json")
        _c2, out2, _ = run_main("--root", str(MINI_REPO), "--json")
        self.assertEqual(out1, out2)

    def test_compare_mode(self):
        with TempRepo() as root:
            report = root / "old_report.json"
            _c, out, _ = run_main("--root", str(root), "--json")
            report.write_text(out, encoding="utf-8")
            target = root / COORDINATOR
            target.write_text(
                target.read_text(encoding="utf-8") +
                '\n\nfunc extra() -> void:\n'
                '\tsituation.record_fact("npc_knowledge", '
                '{"porter": "arrived"})\n', encoding="utf-8")
            code, out2, _ = run_main("--root", str(root), "--json",
                                     "--compare", str(report))
            payload = json.loads(out2)
            self.assertEqual(len(payload["comparison"]["added"]), 1)
            self.assertEqual(payload["comparison"]["removed"], [])


class BaselineTests(unittest.TestCase):
    def test_clean_against_written_baseline(self):
        with TempRepo() as root:
            baseline = write_baseline(root)
            code, _out, _ = run_main("--root", str(root), "--baseline",
                                     str(baseline))
            self.assertEqual(code, 0)

    def test_line_movement_is_not_drift(self):
        with TempRepo() as root:
            baseline = write_baseline(root)
            target = root / COORDINATOR
            target.write_text("## moved\n## down\n\n" +
                              target.read_text(encoding="utf-8"),
                              encoding="utf-8")
            code, _out, _ = run_main("--root", str(root), "--baseline",
                                     str(baseline))
            self.assertEqual(code, 0)

    def test_new_actionable_fails(self):
        with TempRepo() as root:
            baseline = write_baseline(root)
            extra = root / "game/scripts/campaign/late_director.gd"
            extra.write_text(
                "extends Node\n\nfunc fabricate() -> void:\n"
                '\tsituation.record_fact("npc_knowledge", '
                '{"resident": "saw_it"})\n', encoding="utf-8")
            code, out, _ = run_main("--root", str(root), "--baseline",
                                    str(baseline))
            self.assertEqual(code, 1)
            self.assertIn("DIRECT_NPC_KNOWLEDGE_WRITE", out)

    def test_vanished_entry_is_cleanup(self):
        with TempRepo() as root:
            baseline = write_baseline(root)
            (root / "game/scripts/game/verdict_director.gd").write_text(
                "extends Node\n", encoding="utf-8")
            code, out, _ = run_main("--root", str(root), "--baseline",
                                    str(baseline))
            self.assertEqual(code, 0)
            self.assertIn("vanished baseline entries (cleanup): 1", out)

    def test_class_change_is_policy_violation(self):
        with TempRepo() as root:
            baseline = write_baseline(root)
            data = json.loads(baseline.read_text(encoding="utf-8"))
            for entry in data["entries"]:
                if entry["class"] == "DIRECT_NPC_KNOWLEDGE_WRITE":
                    entry["class"] = "DUPLICATE_CUSTODY"
            baseline.write_text(json.dumps(data), encoding="utf-8")
            code, out, _ = run_main("--root", str(root), "--baseline",
                                    str(baseline))
            self.assertEqual(code, 1)
            self.assertIn("policy violations", out)

    def test_confidence_increase_is_policy_violation(self):
        with TempRepo() as root:
            baseline = write_baseline(root)
            data = json.loads(baseline.read_text(encoding="utf-8"))
            for entry in data["entries"]:
                if entry["confidence"] == "STRONG":
                    entry["confidence"] = "HEURISTIC"
            baseline.write_text(json.dumps(data), encoding="utf-8")
            code, _out, _ = run_main("--root", str(root), "--baseline",
                                     str(baseline))
            self.assertEqual(code, 1)

    def test_test_tier_entry_cannot_baseline_production(self):
        with TempRepo() as root:
            baseline = write_baseline(root)
            data = json.loads(baseline.read_text(encoding="utf-8"))
            for entry in data["entries"]:
                if entry["tier"] == "production":
                    entry["tier"] = "test"
            baseline.write_text(json.dumps(data), encoding="utf-8")
            code, out, _ = run_main("--root", str(root), "--baseline",
                                    str(baseline))
            self.assertEqual(code, 1)
            self.assertIn("policy violations", out)

    def test_malformed_baseline(self):
        with TempRepo() as root:
            baseline = root / "tools/baseline.json"
            baseline.parent.mkdir(exist_ok=True)
            baseline.write_text("{ not json", encoding="utf-8")
            code, _out, err = run_main("--root", str(root),
                                       "--baseline", str(baseline))
            self.assertEqual(code, 5)  # malformed + actionable findings

    def test_malformed_baseline_without_actionable(self):
        with TempRepo() as root:
            for rel in (COORDINATOR,
                        "game/scripts/game/verdict_director.gd",
                        "game/scripts/ui/goal_banner.gd"):
                (root / rel).write_text("extends Node\n",
                                        encoding="utf-8")
            baseline = root / "tools/baseline.json"
            baseline.parent.mkdir(exist_ok=True)
            baseline.write_text("{ not json", encoding="utf-8")
            code, _out, err = run_main("--root", str(root),
                                       "--baseline", str(baseline))
            self.assertEqual(code, 4)

    def test_duplicate_baseline_entries(self):
        with TempRepo() as root:
            baseline = write_baseline(root)
            data = json.loads(baseline.read_text(encoding="utf-8"))
            data["entries"].append(dict(data["entries"][0]))
            baseline.write_text(json.dumps(data), encoding="utf-8")
            code, _out, err = run_main("--root", str(root),
                                       "--baseline", str(baseline))
            self.assertEqual(code, 5)
            self.assertIn("", err)

    def test_write_baseline_refuses_production_paths(self):
        with TempRepo() as root:
            for target in ("game/baseline.json", "art/baseline.json",
                           "design/baseline.json"):
                code, _out, err = run_main(
                    "--root", str(root), "--write-baseline",
                    str(root / target))
                self.assertEqual(code, 3, target)
                self.assertIn("refusing", err)
                self.assertFalse((root / target).exists())

    def test_usage_error(self):
        code, _out, _err = run_main("--root",
                                    str(MINI_REPO / "missing"))
        self.assertEqual(code, 3)

    def test_internal_failure_is_70(self):
        original = audit.run
        audit.run = lambda args: (_ for _ in ()).throw(
            RuntimeError("boom"))
        try:
            code, _out, err = run_main("--root", str(MINI_REPO))
        finally:
            audit.run = original
        self.assertEqual(code, 70)
        self.assertIn("INTERNAL", err)


class LiveRepoSmokeTests(unittest.TestCase):
    """Read-only: current main scans clean against the reviewed
    baseline, and the baseline itself is loadable and honest."""

    def test_live_clean_against_baseline(self):
        code, out, _ = run_main("--root", str(REPO_ROOT))
        self.assertEqual(code, 0, out)

    def test_live_baseline_shape(self):
        baseline = audit.load_baseline(
            REPO_ROOT / audit.DEFAULT_BASELINE)
        classes = {e["class"] for e in baseline["entries"]}
        self.assertIn("OBJECTIVE_UI_LEAK", classes)
        self.assertIn("HOST_CLOCK_MUTATES_WORLD", classes)
        tiers = {e["tier"] for e in baseline["entries"]}
        self.assertEqual(tiers, {"production", "test"})


if __name__ == "__main__":
    unittest.main(verbosity=2)
