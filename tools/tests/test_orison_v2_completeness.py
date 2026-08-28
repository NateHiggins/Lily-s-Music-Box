#!/usr/bin/env python3
"""Focused self-tests for tools/audit_orison_v2_completeness.py.

Runs against synthetic fixtures (a mini repo copied to a temp dir per
mutating test) plus a small read-only live-repository smoke section.
Production files are never modified.  Execute with:

    python tools/tests/test_orison_v2_completeness.py
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

import audit_orison_v2_completeness as audit  # noqa: E402

MINI_REPO = Path(__file__).resolve().parent / "fixtures" / \
    "v2_completeness" / "mini_repo"


def run_main(*argv):
    out, err = io.StringIO(), io.StringIO()
    with redirect_stdout(out), redirect_stderr(err):
        code = audit.main(list(argv))
    return code, out.getvalue(), err.getvalue()


def run_payload(root, *extra):
    code, out, err = run_main("--root", str(root), "--json", *extra)
    payload = json.loads(out) if out.strip().startswith("{") else {}
    return code, payload, err


def req(payload, rid):
    hits = [r for r in payload["requirements"] if r["id"] == rid]
    return hits[0] if hits else None


class TempRepo:
    def __enter__(self) -> Path:
        self._dir = tempfile.mkdtemp(prefix="v2_completeness_")
        self.root = Path(self._dir) / "repo"
        shutil.copytree(MINI_REPO, self.root)
        return self.root

    def __exit__(self, *exc):
        shutil.rmtree(self._dir, ignore_errors=True)


def edit_v2(root: Path, mutate):
    path = root / "game/data/orison_v2_blockout.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    mutate(data)
    path.write_text(json.dumps(data), encoding="utf-8")


def make_slice_complete(root: Path) -> None:
    """Mutate the fixture so FIRST_SLICE_TECHNICAL has zero blockers
    while the whole building stays obviously incomplete."""
    def mutate(data):
        data["levels"].append({"id": "B1", "y": -3.2})
        data["levels"].append({"id": "F04", "y": 9.6})
        data["spaces"] += [
            {"id": "F04_B_ALCOVE", "level": "F04", "class": "private",
             "rect": [-10, 5, -5, 9], "purpose": "player sleeping "
             "context"},
            {"id": "B1_SERVICE_HALL", "level": "B1", "class": "service",
             "rect": [0, -3, 4, 0], "purpose": "staff and maintenance "
             "route"},
            {"id": "B1_BOILER", "level": "B1", "class": "service",
             "rect": [4, -3, 9, 2],
             "purpose": "heat production, boiler firing and gauge "
                        "maintenance"},
            {"id": "F02_B_MAIN", "level": "F02", "class": "private",
             "rect": [5, 0, 10, 5], "purpose": "Lena living and rest"},
        ]
        data["doors"] += [
            {"id": "B1_SERVICE_DOOR", "level": "B1", "center": [4, -1],
             "width": 0.91, "connects": ["B1_SERVICE_HALL", "B1_BOILER"]},
            {"id": "F02_B_DOOR", "level": "F02", "center": [5, 0.5],
             "width": 0.91, "connects": ["F02_WEST_HALL", "F02_B_MAIN"]},
        ]
        data["anchors"] += [
            {"id": "F01_WATCHMAN_DETECTOR", "level": "F01",
             "position": [-8.0, 1.1, -2.0], "kind": "interaction"},
            {"id": "F01_NIGHT_REGISTER", "level": "F01",
             "position": [-7.5, 1.1, -2.0], "kind": "interaction"},
            {"id": "F01_SIGNAL_REGISTER", "level": "F01",
             "position": [-7.0, 1.1, -2.0], "kind": "interaction"},
            {"id": "F01_TOUR_KEY_GUARD", "level": "F01",
             "position": [-6.5, 1.1, -2.0], "kind": "interaction"},
            {"id": "F02_B_RADIATOR_01", "level": "F02",
             "position": [9.5, 0.4, 4.0], "kind": "interaction"},
            {"id": "B1_BOILER_01", "level": "B1",
             "position": [6.0, 1.0, 0.0], "kind": "interaction"},
            {"id": "F04_B_BED", "level": "F04",
             "position": [-8.0, 0.55, 7.0], "kind": "semantic"},
            {"id": "F04_B_BEDSIDE_RETURN", "level": "F04",
             "position": [-7.0, 0.0, 7.0], "kind": "clearance"},
        ]
    edit_v2(root, mutate)
    (root / "design" /
     "ORISON_V2_MINI_M08E_CHECKPOINT_2026-08-28.md").write_text(
        "# Mini M08E checkpoint (synthetic fixture)\n\n"
        "Status: RUNTIME PROVEN (fixture).\n\n"
        "Composed and exercised `F01_WATCHMAN_DETECTOR`, "
        "`F01_NIGHT_REGISTER`, `F01_SIGNAL_REGISTER`, "
        "`F01_TOUR_KEY_GUARD`, `F02_B_MAIN`, `F02_B_DOOR`, "
        "`F02_B_RADIATOR_01`, `B1_SERVICE_HALL`, `B1_BOILER`, "
        "`B1_SERVICE_DOOR`, `B1_BOILER_01`, `F01_DOOR_06`, "
        "`F04_B_ALCOVE`, `F04_B_BED` and `F04_B_BEDSIDE_RETURN`.\n",
        encoding="utf-8")


def add_golden_acceptance(root: Path) -> None:
    (root / "design" /
     "ORISON_V2_MINI_GOLDEN_HUMAN_ACCEPTANCE_2026-08-28.json").write_text(
        json.dumps({
            "schema_version": 1,
            "receipt_type": "orison_v2_golden_shift_acceptance",
            "reviewed_commit": "fixture0",
            "verdict": "PASS",
            "scope": "Eleven golden-shift beats under explicit v2 "
                     "selection.",
            "authorization": {"m09": False, "production_cutover": False},
        }), encoding="utf-8")


class UntouchedFixtureTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.code, cls.payload, _ = run_payload(MINI_REPO)

    def test_untouched_building_is_blocked_not_clean(self):
        self.assertEqual(self.code, 2)
        self.assertTrue(
            self.payload["blockers_by_scope"]["PRODUCTION_CUTOVER"])

    def test_missing_apartment(self):
        record = req(self.payload, "unit.2B")
        self.assertEqual(record["status"], "ABSENT")
        self.assertIn("FIRST_SLICE_TECHNICAL", record["blocking_scopes"])
        self.assertIn("PRODUCTION_CUTOVER", record["blocking_scopes"])

    def test_missing_floor_blocks_dependents(self):
        record = req(self.payload, "floor.B1")
        self.assertEqual(record["status"], "ABSENT")
        boiler = req(self.payload, "b1.boiler_room")
        self.assertIn("floor B1 absent from v2", boiler["blocked_by"])

    def test_shell_only_room(self):
        record = req(self.payload, "circ.F02.public_landing")
        self.assertEqual(record["status"], "SHELL_ONLY")

    def test_room_without_entrance_drags_floor(self):
        record = req(self.payload, "floor.F01")
        self.assertEqual(record["status"], "SHELL_ONLY")
        self.assertIn("F01_DEAD_STORE", record["provenance"][0])

    def test_anchor_without_room(self):
        anchors = [a["anchor"] for a in self.payload["anchor_only"]]
        self.assertEqual(anchors, ["FLOATING_ANCHOR"])

    def test_unit_minimums_proven_via_purpose_not_id(self):
        for func in ("entry", "living", "cooking", "sanitary", "sleep",
                     "storage"):
            record = req(self.payload, f"unit.2A.{func}")
            self.assertIsNotNone(record, func)
            self.assertGreaterEqual(
                audit.RANK[record["status"]],
                audit.RANK["SPATIALLY_PROVEN"], func)

    def test_missing_service_connection(self):
        heat = req(self.payload, "service.heat_stack")
        self.assertEqual(heat["status"], "SHELL_ONLY")
        telephone = req(self.payload, "service.telephone_riser")
        self.assertEqual(telephone["status"], "ABSENT")

    def test_preserved_v1_fallback(self):
        record = req(self.payload, "save.bedside_return")
        self.assertEqual(record["status"], "ABSENT")
        self.assertTrue(record["temporary_v1_fallback"])
        self.assertIn("V1_RETIREMENT", record["blocking_scopes"])

    def test_runtime_only_identity(self):
        record = req(self.payload, "interaction.LobbyPorterBoard")
        self.assertEqual(record["status"], "RUNTIME_PROVEN")
        self.assertEqual(record["blocking_scopes"], [])

    def test_checkpointed_then_removed_room_is_stale(self):
        tokens = [s["token"]
                  for s in self.payload["stale_checkpoint_ids"]]
        self.assertIn("F02_GONE_ROOM", tokens)

    def test_human_accepted_but_runtime_incomplete(self):
        record = req(self.payload, "human.route_readability")
        self.assertEqual(record["status"], "HUMAN_ACCEPTED")
        self.assertEqual(self.code, 2)

    def test_screenshot_receipt_is_not_acceptance(self):
        record = req(self.payload, "human.whole_building_navigation")
        self.assertEqual(record["status"], "ABSENT")
        receipts = req(self.payload, "evidence.receipts")
        self.assertEqual(receipts["status"], "RUNTIME_PROVEN")

    def test_alias_handling(self):
        coverage = self.payload["v1_room_coverage"]
        self.assertIn({"v1": "F01_OFFICE", "v2": "F01_WATCH"},
                      coverage["aliased"])
        self.assertIn("F01_HALL", coverage["unrepresented"])

    def test_pseudo_room_exclusion(self):
        coverage = self.payload["v1_room_coverage"]
        self.assertIn("F01_NAVIGATION",
                      coverage["pseudo_rooms_excluded"])
        self.assertNotIn("F01_NAVIGATION", coverage["unrepresented"])

    def test_case_blocked_by_missing_unit(self):
        record = req(self.payload, "case.juno_feedback_tetris")
        self.assertIn("unit 2C absent from v2", record["blocked_by"])

    def test_queue_starts_with_m08e(self):
        queue = self.payload["queue"]
        self.assertEqual(queue[0]["id"], "M08E-f01-rituals-2b-b1")
        for item in queue:
            for field in ("scope", "prerequisite", "blocked_consumers",
                          "required_ids", "automated_proof",
                          "human_evidence", "files_change",
                          "files_forbidden", "exit"):
                self.assertIn(field, item)

    def test_queue_places_default_flip_after_full_building_proof(self):
        ids = [item["id"] for item in self.payload["queue"]]
        m09 = ids.index("M09-production-cutover-proposal")
        self.assertGreater(m09, ids.index(
            "M16-whole-building-performance-navigation"))
        self.assertGreater(m09, ids.index(
            "M15-whole-building-runtime-matrix"))
        self.assertGreater(m09, ids.index("M11-structural-floors"))
        self.assertGreater(m09, ids.index(
            "M12-apartments-by-case-dependency"))
        self.assertEqual(ids[-1], "M18-v1-retirement")

    def test_production_blockers_include_whole_building_gaps(self):
        production = set(
            self.payload["blockers_by_scope"]["PRODUCTION_CUTOVER"])
        first_slice = set(
            self.payload["blockers_by_scope"]["FIRST_SLICE_TECHNICAL"])
        self.assertTrue(first_slice <= production)
        for gap in ("floor.F05", "floor.F06", "floor.ROOF", "unit.2C",
                    "acoustic.v2_rederivation", "case.juno_feedback_"
                    "tetris", "service.electrical_riser"):
            self.assertIn(gap, production, gap)

    def test_fallbacks_block_retirement_superset(self):
        retirement = set(
            self.payload["blockers_by_scope"]["V1_RETIREMENT"])
        production = set(
            self.payload["blockers_by_scope"]["PRODUCTION_CUTOVER"])
        self.assertTrue(production <= retirement)
        self.assertIn("retirement.authorization", retirement)

    def test_no_percentage_anywhere(self):
        text = json.dumps(self.payload["summary"])
        self.assertNotIn("percent", text.lower())
        self.assertNotIn("%", text)

    def test_no_git_metadata_needed(self):
        self.assertFalse((MINI_REPO / ".git").exists())


class ScopeAndModeTests(unittest.TestCase):
    def test_clean_scope_unit_2a(self):
        code, payload, _ = run_payload(MINI_REPO, "--unit", "2A")
        self.assertEqual(code, 0, [r["id"]
                                   for r in payload["requirements"]
                                   if r["blocking_scopes"]])

    def test_incomplete_scope_unit_2c_blocks_production(self):
        # An absent non-first-slice case unit blocks production cutover,
        # so even a scoped query is BLOCKED, not merely incomplete.
        code, payload, _ = run_payload(MINI_REPO, "--unit", "2C")
        self.assertEqual(code, 2)
        record = req(payload, "unit.2C")
        self.assertIn("PRODUCTION_CUTOVER", record["blocking_scopes"])
        self.assertNotIn("FIRST_SLICE_TECHNICAL",
                         record["blocking_scopes"])

    def test_retirement_only_scope_is_incomplete_not_blocked(self):
        with TempRepo() as root:
            make_slice_complete(root)
            code, payload, _ = run_payload(root, "--space", "F04_B_BED")
            ids = {r["id"] for r in payload["requirements"]}
            self.assertEqual(ids, {"save.bedside_return"})
            self.assertEqual(code, 1)

    def test_floor_filter(self):
        code, payload, _ = run_payload(MINI_REPO, "--floor", "F01")
        floors = {r["scope"].get("floor") for r in payload["requirements"]
                  if r["scope"].get("floor")}
        self.assertEqual(floors, {"F01"})

    def test_blockers_only_means_production_cutover(self):
        code, payload, _ = run_payload(MINI_REPO, "--blockers-only")
        self.assertEqual(code, 2)
        self.assertTrue(payload["requirements"])
        self.assertEqual(payload["queried_scopes"],
                         ["PRODUCTION_CUTOVER"])
        self.assertTrue(all("PRODUCTION_CUTOVER" in r["blocking_scopes"]
                            for r in payload["requirements"]))
        # The alias must be WIDE: more than the ten first-slice blockers.
        self.assertGreater(len(payload["requirements"]), 20)

    def test_blockers_for_first_slice_is_narrow(self):
        code, payload, _ = run_payload(MINI_REPO, "--blockers-for",
                                       "first-slice")
        self.assertEqual(code, 2)
        ids = {r["id"] for r in payload["requirements"]}
        self.assertLessEqual(len(ids), 10)
        self.assertIn("unit.2B", ids)
        self.assertNotIn("floor.F05", ids)

    def test_complete_first_slice_is_not_production_ready(self):
        with TempRepo() as root:
            make_slice_complete(root)
            code, payload, _ = run_payload(root, "--blockers-for",
                                           "first-slice")
            self.assertEqual(code, 0, [r["id"]
                                       for r in payload["requirements"]])
            self.assertEqual(payload["banner"],
                             audit.FIRST_SLICE_BANNER)
            code2, payload2, _ = run_payload(root, "--blockers-for",
                                             "production-cutover")
            self.assertEqual(code2, 2)
            production = {r["id"] for r in payload2["requirements"]}
            for gap in ("floor.F05", "floor.F06", "floor.ROOF",
                        "unit.2C", "acoustic.v2_rederivation"):
                self.assertIn(gap, production, gap)
            code3, _, _ = run_payload(root)
            self.assertEqual(code3, 2)

    def test_first_slice_banner_in_text_mode(self):
        with TempRepo() as root:
            make_slice_complete(root)
            code, out, _ = run_main("--root", str(root),
                                    "--blockers-for", "first-slice")
            self.assertEqual(code, 0)
            self.assertIn(audit.FIRST_SLICE_BANNER, out)

    def test_golden_shift_can_pass_while_full_building_blocked(self):
        with TempRepo() as root:
            make_slice_complete(root)
            add_golden_acceptance(root)
            code, payload, _ = run_payload(root, "--blockers-for",
                                           "golden-shift")
            self.assertEqual(code, 0, [r["id"]
                                       for r in payload["requirements"]])
            code2, _, _ = run_payload(root, "--blockers-for",
                                      "full-building")
            self.assertEqual(code2, 2)
            code3, _, _ = run_payload(root)
            self.assertEqual(code3, 2)

    def test_whole_building_exit_zero_is_completion(self):
        # The unfiltered command is the operational definition of the
        # completed rebuild: it must stay nonzero while any scope up to
        # PRODUCTION_CUTOVER is blocked, even with the slice and golden
        # shift clean.
        with TempRepo() as root:
            make_slice_complete(root)
            add_golden_acceptance(root)
            code, payload, _ = run_payload(root)
            self.assertEqual(code, 2)
            self.assertTrue(
                payload["blockers_by_scope"]["PRODUCTION_CUTOVER"])

    def test_markdown_mode(self):
        code, out, _ = run_main("--root", str(MINI_REPO), "--markdown")
        self.assertEqual(code, 2)
        self.assertIn("# Orison v2 completeness ledger", out)
        self.assertIn("## Recommended queue", out)

    def test_deterministic_output(self):
        _, first, _ = run_main("--root", str(MINI_REPO), "--json")
        _, second, _ = run_main("--root", str(MINI_REPO), "--json")
        self.assertEqual(first, second)

    def test_missing_floor_variant(self):
        with TempRepo() as root:
            def drop_f02(data):
                data["levels"] = [lv for lv in data["levels"]
                                  if lv["id"] != "F02"]
                data["spaces"] = [s for s in data["spaces"]
                                  if s["level"] != "F02"]
            edit_v2(root, drop_f02)
            code, payload, _ = run_payload(root)
            self.assertEqual(req(payload, "floor.F02")["status"],
                             "ABSENT")
            circ = req(payload, "circ.F02.public_core")
            self.assertIn("floor F02 absent from v2", circ["blocked_by"])

    def test_unit_missing_kitchen_minimum(self):
        with TempRepo() as root:
            def drop_kitchen(data):
                data["spaces"] = [s for s in data["spaces"]
                                  if s["id"] != "F02_A_KITCHEN"]
            edit_v2(root, drop_kitchen)
            code, payload, _ = run_payload(root, "--unit", "2A")
            record = req(payload, "unit.2A.cooking")
            self.assertEqual(record["status"], "ABSENT")
            self.assertIn("FULL_BUILDING_STRUCTURAL",
                          record["blocking_scopes"])
            self.assertEqual(code, 2)

    def test_evidence_present_but_no_acceptance(self):
        with TempRepo() as root:
            (root / "design" /
             "ORISON_V2_MINI_HUMAN_ACCEPTANCE_2026-08-28.json").unlink()
            code, payload, _ = run_payload(root)
            self.assertEqual(req(payload, "human.route_readability")
                             ["status"], "ABSENT")
            self.assertEqual(req(payload, "evidence.receipts")["status"],
                             "RUNTIME_PROVEN")

    def test_changed_state_comparison(self):
        with TempRepo() as root:
            baseline = root / "baseline_v2.json"
            data = json.loads(
                (root / "game/data/orison_v2_blockout.json").read_text(
                    encoding="utf-8"))
            data["spaces"] = [s for s in data["spaces"]
                              if s["id"] != "F02_A_KITCHEN"]
            baseline.write_text(json.dumps(data), encoding="utf-8")
            code, payload, _ = run_payload(
                root, "--baseline", str(baseline))
            improved = [c["id"] for c in
                        payload["comparison"]["improved"]]
            self.assertIn("unit.2A.cooking", improved)
            self.assertEqual(payload["comparison"]["regressed"], [])


class OutputSafetyTests(unittest.TestCase):
    def test_refuses_game_art_design(self):
        with TempRepo() as root:
            for target in ("game/reports", "art/reports", "design"):
                code, _, err = run_main("--root", str(root), "--out",
                                        str(root / target))
                self.assertEqual(code, 3, target)
                self.assertIn("refusing", err)
                self.assertFalse(
                    (root / target /
                     "ORISON_V2_COMPLETENESS_LEDGER.json").exists())

    def test_safe_design_path_and_overwrite_refusal(self):
        with TempRepo() as root:
            safe = root / audit.SAFE_DESIGN_OUT
            code, _, _ = run_main("--root", str(root), "--out", str(safe))
            self.assertEqual(code, 2)  # writes reports; exit is audit state
            ledger = safe / "ORISON_V2_COMPLETENESS_LEDGER.json"
            self.assertTrue(ledger.is_file())
            before = ledger.read_bytes()
            code, _, err = run_main("--root", str(root), "--out",
                                    str(safe))
            self.assertEqual(code, 3)
            self.assertIn("refusing to overwrite", err)
            self.assertEqual(ledger.read_bytes(), before)
            code, _, _ = run_main("--root", str(root), "--out", str(safe),
                                  "--force")
            self.assertEqual(code, 2)

    def test_out_writes_json_and_markdown(self):
        with TempRepo() as root:
            out = root.parent / "reports"
            code, _, _ = run_main("--root", str(root), "--out", str(out))
            self.assertEqual(code, 2)
            self.assertTrue(
                (out / "ORISON_V2_COMPLETENESS_LEDGER.json").is_file())
            self.assertTrue(
                (out / "ORISON_V2_COMPLETENESS_LEDGER.md").is_file())
            leftovers = [p for p in out.iterdir()
                         if p.name.startswith(
                             "ORISON_V2_COMPLETENESS_LEDGER") and
                         p.suffix not in (".json", ".md")]
            self.assertEqual(leftovers, [])


class FailureModeTests(unittest.TestCase):
    def test_malformed_v2(self):
        with TempRepo() as root:
            (root / "game/data/orison_v2_blockout.json").write_text(
                "{ not json", encoding="utf-8")
            code, _, err = run_main("--root", str(root))
            self.assertEqual(code, 3)
            self.assertIn("malformed", err)

    def test_malformed_v2_shape(self):
        with TempRepo() as root:
            (root / "game/data/orison_v2_blockout.json").write_text(
                json.dumps({"schema_version": 1, "spaces": "nope"}),
                encoding="utf-8")
            code, _, err = run_main("--root", str(root))
            self.assertEqual(code, 3)

    def test_missing_root(self):
        code, _, err = run_main("--root", str(MINI_REPO / "nope"))
        self.assertEqual(code, 3)

    def test_bad_baseline(self):
        with TempRepo() as root:
            bogus = root / "bogus.json"
            bogus.write_text("{}", encoding="utf-8")
            code, _, err = run_main("--root", str(root), "--baseline",
                                    str(bogus))
            self.assertEqual(code, 3)
            self.assertIn("neither", err)

    def test_internal_failure_is_70(self):
        original = audit.run
        audit.run = lambda args: (_ for _ in ()).throw(
            RuntimeError("boom"))
        try:
            code, _, err = run_main("--root", str(MINI_REPO))
        finally:
            audit.run = original
        self.assertEqual(code, 70)
        self.assertIn("INTERNAL", err)


class LiveRepoSmokeTests(unittest.TestCase):
    """Read-only assertions against the real repository."""

    @classmethod
    def setUpClass(cls):
        cls.code, cls.payload, _ = run_payload(REPO_ROOT)

    M08D_TEN = {
        "ritual.F01_WATCHMAN_DETECTOR", "ritual.F01_NIGHT_REGISTER",
        "ritual.F01_SIGNAL_REGISTER", "ritual.F01_TOUR_KEY_GUARD",
        "floor.B1", "unit.2B", "b1.boiler_room",
        "contract.B1_BOILER_01", "contract.F02_B_RADIATOR_01",
        "job.lena_radiator_round_2b"}

    def test_live_first_slice_blockers_stay_within_m08d_ten(self):
        # M08E landed the spatial owners; anything still blocking the
        # first slice must come from the M08D-named set (runtime
        # composition pending), never from whole-building gaps.
        self.assertEqual(self.code, 2)
        first_slice = set(
            self.payload["blockers_by_scope"]["FIRST_SLICE_TECHNICAL"])
        self.assertTrue(first_slice <= self.M08D_TEN, first_slice)

    def test_live_mentions_of_missing_ids_never_prove_runtime(self):
        # M08C/M08D backtick the ritual/2B/B1 ids while stating they are
        # missing; after M08E built them spatially, they must not read
        # as RUNTIME_PROVEN until an M08F-class runtime checkpoint.
        for rid in ("ritual.F01_NIGHT_REGISTER",
                    "contract.B1_BOILER_01",
                    "contract.F02_B_RADIATOR_01"):
            record = req(self.payload, rid)
            self.assertIsNotNone(record, rid)
            self.assertNotEqual(record["status"], "RUNTIME_PROVEN", rid)

    def test_live_production_blockers_are_whole_building(self):
        production = set(
            self.payload["blockers_by_scope"]["PRODUCTION_CUTOVER"])
        first_slice = set(
            self.payload["blockers_by_scope"]["FIRST_SLICE_TECHNICAL"])
        self.assertTrue(first_slice <= production)
        self.assertGreater(len(production), 80)
        for gap in ("floor.F05", "floor.F06", "floor.ROOF", "unit.3B",
                    "acoustic.v2_rederivation",
                    "human.whole_building_navigation"):
            self.assertIn(gap, production, gap)

    def test_live_redundancy_fallback_blocks_only_retirement(self):
        record = req(self.payload, "save.bedside_return")
        self.assertEqual(record["blocking_scopes"], ["V1_RETIREMENT"])

    def test_live_first_slice_is_proven_not_complete(self):
        # Unit status is worst-of across its spaces: support halls not
        # individually named by a checkpoint keep 2A at PROGRAMMED even
        # though the census as a whole passed - deliberately honest.
        record = req(self.payload, "unit.2A")
        self.assertGreaterEqual(audit.RANK[record["status"]],
                                audit.RANK["PROGRAMMED"])
        floors = req(self.payload, "floor.F05")
        self.assertEqual(floors["status"], "ABSENT")

    def test_live_route_acceptance_is_scoped(self):
        record = req(self.payload, "human.route_readability")
        self.assertEqual(record["status"], "HUMAN_ACCEPTED")
        whole = req(self.payload, "human.whole_building_navigation")
        self.assertEqual(whole["status"], "ABSENT")

    def test_live_queue_order(self):
        ids = [item["id"] for item in self.payload["queue"]]
        self.assertEqual(ids[0], "M08E-f01-rituals-2b-b1")
        m09 = ids.index("M09-production-cutover-proposal")
        self.assertGreater(m09, ids.index("M11-structural-floors"))
        self.assertGreater(m09, ids.index(
            "M16-whole-building-performance-navigation"))
        self.assertEqual(ids[-1], "M18-v1-retirement")

    def test_live_v1_coverage_is_honest(self):
        coverage = self.payload["v1_room_coverage"]
        self.assertGreater(len(coverage["unrepresented"]), 90)
        self.assertIn("B1_BOILER", coverage["unrepresented"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
