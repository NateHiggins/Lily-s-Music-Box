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


class OwnedLampOutputTests(unittest.TestCase):
    def test_only_declared_lamp_result_field_is_owned(self):
        source = ("extends RefCounted\n"
                  "func write_output(result: Dictionary) -> void:\n"
                  "\tvar hot := 0.5\n\tresult.heat = hot\n")
        rel = "game/scripts/lamp/lamp_optical_state.gd"
        cases = [
            (rel, source, False),
            ("game/scripts/game/other_state.gd", source, True),
            (rel, source.replace("write_output", "mutate_world"), True),
            (rel, source.replace("result.heat", "radiator.heat"), True),
            (rel, source.replace("result: Dictionary", "result: Node"), True),
            (rel, source.replace("result.heat", "result.power"), True),
        ]
        for path, text, expected in cases:
            with self.subTest(path=path, source=text), TempRepo() as root:
                target = root / path
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text(text, encoding="utf-8")
                _, findings, _ = run_findings(root)
                actual = [f for f in findings if f["file"] == path
                          and f["class"] == "FOREIGN_PHYSICAL_MUTATION"]
                self.assertEqual(bool(actual), expected)


class ReconciledReviewTests(unittest.TestCase):
    def scan_source(self, source, rel="game/tests/player_reconstruction_test.gd", parents=None):
        with TempRepo() as root:
            for name, body in {rel: source, **(parents or {})}.items():
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(body, encoding="utf-8")
            _, findings, _ = run_findings(root)
            return [row for row in findings if row["file"] == rel]

    def test_declaration_is_not_a_timer_consequence_but_a_call_is(self):
        source = "extends Node\nfunc _complete_visit():\n    var elapsed := 1.0\n"
        self.assertFalse(of_class(self.scan_source(source), "TIMER_IMPERSONATES_ACTOR"))
        source += "    coordinator.complete_repair()\n"
        self.assertTrue(of_class(self.scan_source(source), "TIMER_IMPERSONATES_ACTOR"))

    def test_typed_adapter_lookup_is_read_only_but_unknown_resolve_is_not(self):
        source = ("extends Node\nvar world: OrisonV2RuntimeRoot\n"
                  "func _ready():\n    await get_tree().create_timer(.2).timeout\n"
                  "    var node = world.adapter.resolve(\"F01_LOBBY\")\n")
        for text, expected in [(source, False),
                (source.replace("OrisonV2RuntimeRoot", "Node"), True),
                (source.replace("world.adapter.resolve", "situation.resolve"), True),
                (source + "    situation.resolve(\"repair\")\n", True),
                (source.replace("func _ready():", "func _ready(world: Node):"), True)]:
            with self.subTest(source=text):
                rows = self.scan_source(text)
                self.assertEqual(bool(of_class(rows, "TIMER_IMPERSONATES_ACTOR")), expected)
                self.assertEqual(bool(of_class(rows, "TEST_AUTHORITY_SHORTCUT")), expected)

    def test_local_cast_is_scoped_and_does_not_credit_another_function(self):
        source = ("extends Node\nfunc _ready():\n"
                  "    var world := Runtime.instantiate() as OrisonV2RuntimeRoot\n"
                  "    await get_tree().create_timer(.2).timeout\n"
                  "    var node = world.adapter.resolve(\"F01_LOBBY\")\n"
                  "func unrelated(world: Node):\n"
                  "    await get_tree().create_timer(.2).timeout\n"
                  "    world.adapter.resolve(\"repair\")\n")
        rows = of_class(self.scan_source(source), "TIMER_IMPERSONATES_ACTOR")
        self.assertEqual([r["scope"] for r in rows], ["unrelated"])

    def test_receiver_type_must_be_code_not_a_comment_or_literal(self):
        declarations = [
            ('var world: OrisonV2RuntimeRoot = Runtime.new()', False),
            ('var world := Runtime.new() as OrisonV2RuntimeRoot', False),
            ('var world = Runtime.new() as OrisonV2RuntimeRoot', True),
            ('var world := foreign_owner # as OrisonV2RuntimeRoot', True),
            ('var world := foreign_owner # : OrisonV2RuntimeRoot', True),
            ('var world := "diagnostic as OrisonV2RuntimeRoot"', True),
        ]
        for declaration, expected in declarations:
            with self.subTest(declaration=declaration):
                source = ('extends Node\nfunc _ready():\n    ' + declaration + '\n'
                          '    await get_tree().create_timer(.2).timeout\n'
                          '    world.adapter.resolve("repair")\n')
                findings = self.scan_source(source)
                self.assertEqual(bool(of_class(findings, "TIMER_IMPERSONATES_ACTOR")), expected)
                self.assertEqual(bool(of_class(findings, "TEST_AUTHORITY_SHORTCUT")), expected)

    def test_only_reached_inherited_input_driver_counts(self):
        parent = ("extends Node\nvar world: OrisonV2RuntimeRoot\n"
                  "func _ready():\n    call_deferred(\"_run\")\n"
                  "func _run():\n    await _route()\n"
                  "func _route():\n    pass\n"
                  "func _use():\n    Input.action_press(\"interact\")\n"
                  "    Input.action_release(\"interact\")\n")
        child = ("extends \"res://tests/player_driver.gd\"\n"
                 "func _route():\n    situation.apply_condition()\n    await _use()\n")
        parents = {"game/tests/player_driver.gd": parent}
        for source, expected in [(child, False),
                (child.replace("    await _use()\n", ""), True),
                (child + "func _use():\n    pass\n", True)]:
            with self.subTest(source=source):
                self.assertEqual(bool(of_class(self.scan_source(source, parents=parents),
                    "TEST_AUTHORITY_SHORTCUT")), expected)

    def test_only_exact_artifact_timestamp_cannot_escape_to_world(self):
        source = ("extends Node\nfunc _ready():\n    var report := {\n"
                  "        \"generated_utc\": Time.get_datetime_string_from_system(true),\n"
                  "    }\n    file.store_string(JSON.stringify(report))\n")
        rel = "game/tests/interaction_inventory.gd"
        warehouse = source.replace("_ready", "_run").replace("report", "manifest").replace("generated_utc", "generated_at").replace("system(true)", "system(true, true)")
        warehouse += '    printerr("cannot write the manifest")\n'
        cases = [(rel, source, False),
                 ("game/tests/prop_warehouse_shot.gd", warehouse, False),
                 ("game/tests/prop_warehouse_shot.gd", warehouse + "    publish(manifest)\n", True),
                 ("game/scripts/game/calendar_export.gd", source, True),
                 (rel, source.replace("generated_utc", "issued_at"), True),
                 (rel, source + "    RealityState.data.report = report\n", True),
                 (rel, source + "    var alias = report\n    publish(alias)\n", True),
                 (rel, source + "    publish(report)\n", True),
                 (rel, source.replace("file.store_string(JSON.stringify(report))", "return report"), True)]
        for path, text, expected in cases:
            with self.subTest(path=path, source=text):
                self.assertEqual(bool(of_class(self.scan_source(text, path),
                    "HOST_CLOCK_MUTATES_WORLD")), expected)

    def test_inherited_input_requires_executable_calls_not_string_contents(self):
        parent = ('extends Node\n'
                  'func _ready():\n    call_deferred("_run")\n'
                  'func _run():\n    await _route()\n'
                  'func _route():\n    pass\n'
                  'func _use():\n    Input.action_press("interact")\n'
                  '    Input.action_release("interact")\n')
        child = ('extends "res://tests/player_driver.gd"\n'
                 'func _route():\n    situation.apply_condition()\n')
        cases = [
            ('    await _use()\n', False),
            ('    call_deferred("_use")\n', False),
            ("    call_deferred('_use')\n", False),
            ('    print("_use()")\n', True),
            ("    print('_use()')\n", True),
            ('    print("""diagnostic\n_use()\n""")\n', True),
            ("    print(\"call_deferred('_use')\")\n", True),
            ('    # _use()\n', True),
            ('    other.call_deferred("_use")\n', True),
            ('    call_deferred("_use" + suffix)\n', True),
        ]
        for suffix, expected in cases:
            with self.subTest(suffix=suffix):
                findings = self.scan_source(child + suffix,
                    parents={"game/tests/player_driver.gd": parent})
                self.assertEqual(bool(of_class(findings, "TEST_AUTHORITY_SHORTCUT")), expected)
        quoted_input = parent.replace(
            'Input.action_press("interact")', 'print(\"Input.action_press(\")').replace(
            'Input.action_release("interact")', 'print(\"Input.action_release(\")')
        findings = self.scan_source(child + '    await _use()\n',
            parents={"game/tests/player_driver.gd": quoted_input})
        self.assertTrue(of_class(findings, "TEST_AUTHORITY_SHORTCUT"))

    def test_inherited_method_headers_inside_multiline_literals_do_not_count(self):
        parent = ('extends Node\n'
                  'func _ready():\n    call_deferred("_run")\n'
                  'func _run():\n    await _route()\n'
                  'func _route():\n    pass\n'
                  'func _notes():\n    print("""example code\n'
                  'func _use():\n    Input.action_press("interact")\n'
                  '    Input.action_release("interact")\n""")\n'
                  'func _use():\n    pass\n')
        child = ('extends "res://tests/player_driver.gd"\n'
                 'func _route():\n    situation.apply_condition()\n    await _use()\n')
        findings = self.scan_source(child,
            parents={"game/tests/player_driver.gd": parent})
        self.assertTrue(of_class(findings, "TEST_AUTHORITY_SHORTCUT"))
        real_input = parent.replace('func _use():\n    pass\n',
            'func _use():\n    Input.action_press("interact")\n'
            '    Input.action_release("interact")\n')
        findings = self.scan_source(child,
            parents={"game/tests/player_driver.gd": real_input})
        self.assertFalse(of_class(findings, "TEST_AUTHORITY_SHORTCUT"))

    def test_unreached_top_level_declarations_do_not_supply_inherited_input(self):
        header = ('extends Node\nfunc _ready():\n    await _route()\n')
        child = ('extends "res://tests/player_driver.gd"\n'
                 'func _route():\n    situation.apply_condition()\n')
        tails = [
            ('class UnusedInput:\n    func _use():\n'
             '        Input.action_press("interact")\n'
             '        Input.action_release("interact")\n'),
            ('var unused = func():\n    Input.action_press("interact")\n'
             '    Input.action_release("interact")\n'),
        ]
        for tail in tails:
            with self.subTest(tail=tail):
                findings = self.scan_source(child,
                    parents={"game/tests/player_driver.gd": header + tail})
                self.assertTrue(of_class(findings, "TEST_AUTHORITY_SHORTCUT"))
        multiline = ('extends Node\nfunc _ready(\n    unused: Node = null\n) -> void:\n'
                     '    await _route()\n    Input.action_press("interact")\n'
                     '    Input.action_release("interact")\n')
        findings = self.scan_source(child,
            parents={"game/tests/player_driver.gd": multiline})
        self.assertFalse(of_class(findings, "TEST_AUTHORITY_SHORTCUT"))

    def test_printed_function_header_cannot_hide_artifact_extraction(self):
        source = ('extends Node\nfunc _ready():\n    var report := {\n'
                  '        "generated_utc": Time.get_datetime_string_from_system(true),\n'
                  '    }\n    file.store_string(JSON.stringify(report))\n'
                  '    print("""example code\nfunc unused():\n    pass\n""")\n')
        rel = "game/tests/interaction_inventory.gd"
        self.assertFalse(of_class(self.scan_source(source, rel), "HOST_CLOCK_MUTATES_WORLD"))
        source += '    var field = "generated_" + "utc"\n    publish(report[field])\n'
        self.assertTrue(of_class(self.scan_source(source, rel), "HOST_CLOCK_MUTATES_WORLD"))

    def test_artifact_field_reads_require_literal_non_clock_keys(self):
        source = ('extends Node\nfunc _ready():\n    var report := {\n'
                  '        "generated_utc": Time.get_datetime_string_from_system(true),\n'
                  '        "summary": {"count": 1},\n'
                  '    }\n    file.store_string(JSON.stringify(report))\n')
        cases = [
            ('    print(report.summary.count)\n', False),
            ('    print(report["summary"])\n', False),
            ("    print(report['summary'])\n", False),
            ('    print(report.get("summary", {}))\n', False),
            ('    publish(report.generated_utc)\n', True),
            ('    publish(report["generated_utc"])\n', True),
            ('    publish(report.get("generated_utc"))\n', True),
            ('    var field = "generated_" + "utc"\n    publish(report[field])\n', True),
            ('    var field = "generated_" + "utc"\n    publish(report.get(field))\n', True),
            ('    publish(report["generated_" + "utc"])\n', True),
            ('    publish(report.get("generated_" + "utc"))\n', True),
            ('    publish(report.values())\n', True),
            ('    file.store_string(JSON.stringify(report)); publish(report[field])\n', True),
        ]
        for suffix, expected in cases:
            with self.subTest(suffix=suffix):
                findings = self.scan_source(source + suffix,
                    "game/tests/interaction_inventory.gd")
                self.assertEqual(bool(of_class(findings, "HOST_CLOCK_MUTATES_WORLD")), expected)


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


class HostCalendarTests(unittest.TestCase):
    CLOCK = "game/scripts/game/campaign_clock.gd"

    def _find(self, source, path=CLOCK):
        findings = []
        audit.scan_file(audit.FileContext(path, source), findings)
        return of_class(findings, "HOST_CLOCK_MUTATES_WORLD")

    def test_only_pure_local_minute_sampler_is_authorized(self):
        source = ('extends RefCounted\n'
                  'func _sample_local_minute_of_day() -> int:\n'
                  '\tvar t := Time.get_time_dict_from_system()\n'
                  '\treturn int(t.hour) * 60 + int(t.minute)\n')
        self.assertEqual(self._find(source), [])
        for field in ("year", "month", "day", "weekday"):
            with self.subTest(field=field):
                bad = source.replace('int(t.hour)', 'int(t.%s)' % field)
                hits = self._find(bad)
                self.assertEqual(len(hits), 1)
                self.assertEqual(hits[0]["disposition"], "FIX")

    def test_former_initializer_exemption_cannot_persist_calendar(self):
        for field in ("year", "month", "day", "weekday"):
            with self.subTest(field=field):
                source = ('extends RefCounted\n'
                          'func _initialize_epoch_from_host() -> void:\n'
                          '\tvar host := Time.get_date_dict_from_system()\n'
                          '\tvar copied := host.get("%s")\n'
                          '\t_state["start_%s"] = copied\n'
                          '\tRealityState.commit()\n' % (field, field))
                hits = self._find(source)
                self.assertEqual(len(hits), 1)
                self.assertEqual(hits[0]["disposition"], "FIX")
                foreign = self._find(source, "game/scripts/game/other_clock.gd")
                self.assertEqual(len(foreign), 1)
                self.assertEqual(foreign[0]["disposition"], "FIX")

    def test_repeated_or_durably_writing_sampler_is_not_exempt(self):
        for extra in ('\tvar again := Time.get_time_dict_from_system()\n',
                      '\tRealityState.data.clock = t\n'):
            source = ('func _sample_local_minute_of_day() -> int:\n'
                      '\tvar t := Time.get_time_dict_from_system()\n' + extra +
                      '\treturn t.hour * 60 + t.minute\n')
            self.assertTrue(self._find(source))

    def test_same_file_helper_cannot_hide_persisted_host_fields(self):
        source = ('func read_host():\n'
                  '\treturn Time.get_date_dict_from_system()\n'
                  'func copy_host():\n\treturn read_host()\n'
                  'func save_epoch():\n\tvar copied := copy_host()\n'
                  '\t_state.year = copied.year\n')
        hits = self._find(source, "game/scripts/game/other_clock.gd")
        self.assertEqual({hit["scope"] for hit in hits}, {"read_host", "save_epoch"})

    def test_logged_at_host_time_string_is_rejected_then_campaign_time_passes(self):
        source = ('func _voice(flat: Dictionary, n: int) -> String:\n'
                  '\tvar line := "Logged at %s"\n'
                  '\tif line.contains("%s"):\n'
                  '\t\tline = line % Time.get_time_string_from_system()\n'
                  '\treturn line\n')
        path = "game/scripts/reality/organism_incidents.gd"
        hits = self._find(source, path)
        self.assertEqual(len(hits), 1)
        self.assertEqual(hits[0]["disposition"], "FIX")
        self.assertEqual(hits[0]["scope"], "_voice")
        corrected = source.replace(
            '\t\tline = line % Time.get_time_string_from_system()',
            '\t\tvar minute := int(CampaignClock.new().minute_of_day())\n'
            '\t\tline = line % ("%02d:%02d" % [minute / 60, minute % 60])')
        self.assertEqual(self._find(corrected, path), [])

    def test_filename_helper_does_not_taint_its_storage_operation(self):
        source = ('func _new_photo_id() -> String:\n'
                  '\treturn Time.get_datetime_string_from_system()\n'
                  'func capture():\n\tvar path := _new_photo_id()\n'
                  '\timg.save_png(path)\n')
        self.assertEqual(self._find(source, "game/scripts/phoneos/phone_camera.gd"), [])
        bad = source.replace('\treturn Time.get_datetime_string_from_system()',
                             '\t_state.date = Time.get_datetime_string_from_system()\n\treturn "id"')
        self.assertTrue(self._find(bad, "game/scripts/phoneos/phone_camera.gd"))

    def test_calendar_conversion_and_filename_metadata_are_not_world_time(self):
        source = ('func convert() -> Dictionary:\n'
                  '\treturn Time.get_datetime_dict_from_unix_time(0)\n')
        self.assertEqual(self._find(source), [])
        source = ('static func _new_id() -> String:\n'
                  '\tvar t := Time.get_datetime_dict_from_system()\n'
                  '\treturn "%d-%d" % [t.year, t.month]\n')
        self.assertEqual(self._find(source, "game/scripts/songbook/songbook_store.gd"), [])
        persisted = ('static func save_version() -> void:\n'
                     '\tvar record := {"created": Time.get_datetime_string_from_system()}\n'
                     '\tFileAccess.open("user://take.json", FileAccess.WRITE).store_var(record)\n')
        self.assertEqual(len(self._find(persisted, "game/scripts/songbook/songbook_store.gd")), 1)

    def test_cli_host_calendar_red_then_authored_green(self):
        with TempRepo() as root:
            baseline = write_baseline(root)
            path = root / self.CLOCK
            path.write_text('func _initialize_epoch_from_host() -> void:\n'
                            '\tvar host := Time.get_date_dict_from_system()\n'
                            '\t_state.epoch_date = host\n', encoding="utf-8")
            argv = ("--root", str(root), "--baseline", str(baseline),
                    "--domain", "host-clock", "--json")
            code, out, _ = run_main(*argv)
            self.assertEqual(code, 1, out)
            path.write_text('func _sample_local_minute_of_day() -> int:\n'
                            '\tvar t := Time.get_time_dict_from_system()\n'
                            '\treturn t.hour * 60 + t.minute\n', encoding="utf-8")
            code, out, _ = run_main(*argv)
            self.assertEqual(code, 0, out)


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



class HostUnixTests(unittest.TestCase):
    _find = HostCalendarTests._find
    CLOCK = HostCalendarTests.CLOCK
    def test_unix_world_stamp_requires_fix_and_campaign_value_passes(self):
        for field in ("issued_at", "closed_at", "acquired_at", "consumed_at", "reported_at", "at"):
            source = ('func record():\n\tvar stamp := Time.get_unix_time_from_system()\n'
                      '\tvar facts := {"%s": stamp}\n\tRealityState.data.history = facts\n' % field)
            hits = self._find(source, "game/scripts/props/night_register_prop.gd")
            self.assertTrue(hits)
            self.assertTrue(all(hit["disposition"] == "FIX" for hit in hits))
            self.assertEqual(self._find(source.replace('Time.get_unix_time_from_system()',
                'CampaignClock.new().elapsed_minutes()'), "game/scripts/props/night_register_prop.gd"), [])

    def test_unix_named_helper_taint_reaches_renamed_consumer(self):
        source = ('func sample():\n\treturn Time.get_unix_time_from_system()\n'
                  'func pass_stamp():\n\treturn sample()\n'
                  'func remember():\n\t_state.at = pass_stamp()\n')
        hits = self._find(source, "game/scripts/game/other_clock.gd")
        self.assertEqual({hit["scope"] for hit in hits}, {"sample", "remember"})
        self.assertTrue(all(hit["disposition"] == "FIX" for hit in hits))

    def test_exact_seed_entropy_and_pure_ids_remain_allowed(self):
        source = ('func _new_dream_seed() -> String:\n'
                  '\tvar rng := RandomNumberGenerator.new()\n'
                  '\trng.seed = int(Time.get_unix_time_from_system() * 1000000.0)\n'
                  '\tvar high := int(rng.randi())\n\tvar low := int(rng.randi())\n'
                  '\tvar encoded := "%08x%08x" % [high, low]\n\treturn encoded\n')
        path = "game/scripts/game/reality_game_state.gd"
        self.assertEqual(self._find(source, path), [])
        self.assertTrue(self._find(source.replace('\treturn encoded',
            '\tRealityState.data.at = Time.get_unix_time_from_system()\n\treturn encoded'), path))
        self.assertTrue(self._find(source.replace('_new_dream_seed', 'other_entropy'), path))
        for path, helper in (("game/scripts/songbook/songbook_store.gd", "_new_id"),
                             ("game/scripts/phoneos/phone_camera.gd", "_new_photo_id")):
            source = ('func %s() -> String:\n\treturn str(Time.get_unix_time_from_system())\n'
                      'func capture():\n\tvar path := %s()\n\timg.save_png(path)\n') % (helper, helper)
            self.assertEqual(self._find(source, path), [])

    def test_documented_old_stamp_cannot_suppress_new_fix(self):
        source = 'func stamp():\n\tRealityState.data.at = Time.get_unix_time_from_system()\n'
        finding = self._find(source, "game/scripts/game/work_orders.gd")[0]
        entry = dict(finding, disposition="DOCUMENT")
        drift = audit.diff_baseline({"entries": [entry]}, [finding])
        self.assertEqual(len(drift["policy_violations"]), 1)


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
                        "game/scripts/ui/goal_banner.gd",
                        "game/scripts/game/maintenance_inventory.gd"):
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
