#!/usr/bin/env python3
from __future__ import annotations
import json
import sys
import tempfile
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS))
import audit_data_consumption as audit


class DataConsumptionTests(unittest.TestCase):
    def test_installed_case_getter_records_potential_read_and_keeps_all_unproven_cases(self):
        td, root = self.fixture()
        self.addCleanup(td.cleanup)
        owner = "game/scripts/game/reality_case_manager.gd"
        director = "game/scripts/building/orison_v2_reality_director.gd"
        data = "game/data/reality_cases.json"
        for relative in ("game/project.godot", owner, director, data):
            path = root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes((TOOLS.parent / relative).read_bytes())
        cases = json.loads((root / data).read_text(encoding="utf-8"))
        first = next(iter(cases.values()))
        first["metadata"] = {"enabled": False}
        first["never_read_probe"] = 2
        (root / data).write_text(json.dumps(cases), encoding="utf-8")
        other = "game/data/other.json"
        (root / other).write_text(json.dumps(cases), encoding="utf-8")

        def unread():
            return {(row["file"], row["field"]): row
                    for row in audit.scan(root, root / audit.DEFAULT_EXCEPTIONS)
                    if row["kind"] == "FIELD_UNREAD"}

        fields = unread()
        n = sum("enabled" in case for case in cases.values())
        self.assertGreater(n, 0)
        self.assertEqual(fields[data, "enabled"]["occurrences"], n + 1)
        self.assertIn("potential read through JSON-backed getter RealityCases.definition",
                      fields[data, "enabled"]["detail"])
        self.assertEqual(fields[data, "never_read_probe"]["detail"], "zero production token readers")
        self.assertEqual(fields[other, "enabled"]["occurrences"], n + 1)
        self.assertEqual(fields[other, "enabled"]["detail"], "zero production token readers")
        # If enabled survives only in nested metadata, its same name does not earn the getter detail.
        for row in cases.values():
            row.pop("enabled", None)
        (root / data).write_text(json.dumps(cases), encoding="utf-8")
        self.assertEqual(unread()[data, "enabled"]["detail"], "zero production token readers")
        first["enabled"] = True
        (root / data).write_text(json.dumps(cases), encoding="utf-8")
        project = root / "game/project.godot"
        project.write_text(project.read_text().replace("RealityCases=", "UnrelatedCases="))
        self.assertEqual(unread()[data, "enabled"]["detail"], "zero production token readers")

    def test_getter_proof_requires_registered_loader_pure_return_and_matching_loop_key(self):
        td, root = self.fixture()
        self.addCleanup(td.cleanup)
        project = root / "game/project.godot"
        config = '[autoload]\nCases="*res://scripts/game/cases.gd"\n[display]\n'
        owner = ('extends Node\nconst DATA := "res://data/reality_cases.json"\n'
                 'var records: Dictionary = {}\nfunc _ready():\n'
                 '    records = JSON.parse_string(FileAccess.get_file_as_string(DATA))\n'
                 'func row(id: String) -> Dictionary:\n    return records.get(id, {})\n')
        consumer = ('extends Node\nfunc tick():\n    for id: String in Cases.records:\n'
                    '        if bool(Cases.row(id).get("enabled", false)):\n            pass\n')
        owner_path = root / "game/scripts/game/cases.gd"
        reader_path = root / "game/scripts/game/consumer.gd"

        def proof(project_text=config, loader=owner, reader=consumer):
            project.write_text(project_text, encoding="utf-8")
            return audit.autoload_getter_reads(root, {owner_path: loader, reader_path: reader})

        expected = {"reality_cases.json": {(None, "enabled"): {"Cases.row"}}}
        self.assertEqual(proof(), expected)
        for config_text in (config.replace("[autoload]", "[other]"),
                            config.replace("*res://", "res://"),
                            config.replace("cases.gd", "other.gd"),
                            config.replace("[display]", 'Cases="*res://scripts/game/other.gd"')):
            with self.subTest(config=config_text):
                self.assertEqual(proof(project_text=config_text), {})
        for loader in (owner.replace("FileAccess.get_file_as_string(DATA)", '"{}"'),
                       owner.replace("_ready()", "later()"),
                       owner.replace("= {}", '= {"x": {}}', 1),
                       owner.replace("return records.get(id, {})", 'return {"unrelated": true}'),
                       owner.replace("get(id, {})", 'get("somebody", {})'),
                       owner.replace("get(id, {})", 'get(id, default_record)'),
                       owner.replace("    return", "    if cached:\n        return cached\n    return"),
                       owner + "func reset():\n    self.records = {}\n",
                       owner + 'func reset():\n    records["x"] = {}\n'):
            with self.subTest(loader=loader):
                self.assertEqual(proof(loader=loader), {})
        for reader in (consumer.replace("Cases.row(id)", "Other.row(id)"),
                       consumer.replace("Cases.records", "Other.records"),
                       consumer.replace("Cases.row(id)", 'Cases.row("no_such_id")'),
                       consumer.replace("Cases.row(id)", "Cases.row(other_id)"),
                       consumer.replace("tick()", "tick(Cases)"),
                       consumer.replace("for id:", "var Cases = Other.new()\n    for id:"),
                       consumer.replace("        if", '        id = "absent"\n        if'),
                       consumer.replace("        if", "        pass\n    if"),
                       consumer.replace("        if", "        break\n        if"),
                       consumer.replace("        if", "        return\n        if"),
                       consumer.replace("        if", "        continue\n        if"),
                       consumer.replace('"enabled"', "field_name"),
                       consumer.replace("if bool(Cases.row(id).get(\"enabled\", false)):", "if true: # Cases.row(id).get('enabled')"),
                       consumer.replace('if bool(Cases.row(id).get("enabled", false)):', '''if "Cases.row(id).get('enabled')":'''),
                       consumer + "func replace_data():\n    Cases.records = fixture\n",
                       consumer + "func replace_data():\n    Cases.records[key] = fixture\n"):
            with self.subTest(reader=reader):
                self.assertEqual(proof(reader=reader), {})

        (root / "game/data/reality_cases.json").write_text(json.dumps({
            key: {"enabled": False} for key in ("named", "other")}), encoding="utf-8")
        owner_path.write_text(owner, encoding="utf-8")
        project.write_text(config, encoding="utf-8")
        # Conditional control flow never upgrades a possible read to all-entry evidence.
        for reader in (consumer,
                       consumer.replace("        if", '        if id != "named":\n            continue\n        if'),
                       consumer.replace("        if", '        if id == "named":\n            if').replace(
                           "            pass", "                pass"),
                       consumer.replace("        if", "        if hidden:\n            break\n        if"),
                       consumer.replace("        if", "        if hidden:\n            return\n        if")):
            with self.subTest(reader=reader):
                reader_path.write_text(reader, encoding="utf-8")
                result = next(row for row in audit.scan(root, root / audit.DEFAULT_EXCEPTIONS)
                              if row["file"] == "game/data/reality_cases.json" and row.get("field") == "enabled")
                self.assertEqual(result["occurrences"], 2)
                self.assertIn("potential read through JSON-backed getter Cases.row", result["detail"])

    def test_darts_instance_consumes_only_its_dealt_card_and_kind_blurb(self):
        td, root = self.fixture()
        self.addCleanup(td.cleanup)
        for relative in ("game/scripts/minigames/trivia_darts.gd", "game/scripts/ui/darts_panel.gd",
                         "game/data/trivia_darts.json"):
            path = root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes((TOOLS.parent / relative).read_bytes())
        deck_path = root / "game/data/trivia_darts.json"
        deck = json.loads(deck_path.read_text(encoding="utf-8"))
        deck["metadata"] = {"q": "unread sibling", "blurb": "unread sibling"}
        deck["deck"][0]["unread_probe"] = True
        deck_path.write_text(json.dumps(deck), encoding="utf-8")
        (root / "game/data/other.json").write_text(json.dumps(deck), encoding="utf-8")

        def findings():
            return {(r["file"], r["field"]): r["occurrences"]
                    for r in audit.scan(root, root / audit.DEFAULT_EXCEPTIONS)
                    if r["kind"] == "FIELD_UNREAD"}

        current = findings()
        file = "game/data/trivia_darts.json"
        self.assertEqual(current[file, "q"], 1)
        # The UI reads a blurb only for bonus-scoring kinds. A dynamic key
        # cannot vouch for the plain category, which awards zero bonus.
        self.assertEqual(current[file, "blurb"], len(deck["kinds"]) + 1)
        blurb = next(r for r in audit.scan(root, root / audit.DEFAULT_EXCEPTIONS)
                     if r["file"] == file and r.get("field") == "blurb")
        self.assertIn("dynamic dictionary key", blurb["detail"])
        self.assertEqual(current[file, "unread_probe"], 1)
        self.assertEqual(current["game/data/other.json", "q"], len(deck["deck"]) + 1)
        self.assertEqual(current["game/data/other.json", "blurb"], len(deck["kinds"]) + 1)

        panel = root / "game/scripts/ui/darts_panel.gd"
        panel.write_text(panel.read_text(encoding="utf-8").replace("var trivia := TriviaDarts.new()",
                                                                   "var trivia := OtherGame.new()"),
                         encoding="utf-8")
        disconnected = findings()
        self.assertEqual(disconnected[file, "q"], len(deck["deck"]) + 1)
        self.assertEqual(disconnected[file, "blurb"], len(deck["kinds"]) + 1)

    def test_instance_handoff_requires_unambiguous_file_member_and_receiver(self):
        owner = ('class_name Deck\nextends RefCounted\nconst DATA := "res://data/cards.json"\n'
                 'var records := []\nvar dealt := {}\nfunc load_data():\n'
                 '    var d = JSON.parse_string(FileAccess.get_file_as_string(DATA))\n'
                 '    records = d.get("cards", [])\nfunc select(i):\n    dealt = records[i]\n')
        panel = ('extends Control\nvar source := Deck.new()\nfunc open():\n'
                 '    source.load_data()\n    source.select(0)\nfunc show_card():\n'
                 '    label.text = source.dealt.get("copy", "")\n')

        def reads(loader, reader):
            return audit.constructed_member_reads({"loader.gd": loader, "reader.gd": reader})

        expected = ("cards", None, "copy")
        self.assertIn(expected, reads(owner, panel)["cards.json"])
        for loader, reader in (
            (owner.replace('FileAccess.get_file_as_string(DATA)', '"{}"'), panel),
            (owner.replace('load_data():', 'load_data(DATA := "res://data/other.json"):'), panel),
            (owner.replace('load_data():', 'load_data():\n    var DATA := "res://data/other.json"'), panel),
            (owner.replace('dealt = records[i]', 'dealt = other_records[i]'), panel),
            (owner + 'func replace():\n    dealt = fake()\n', panel),
            (owner, panel.replace('source.load_data()', 'other.load_data()')),
            (owner, panel.replace('show_card()', 'show_card(source)')),
            (owner, panel.replace('show_card()', 'show_card(\n    source: Dictionary\n)')),
            (owner, panel.replace('    label.text =', '    var cb := func(source):\n        label.text =')),
            (owner, panel.replace('    label.text', '    source = substitute\n    label.text')),
            (owner, panel.replace('    label.text', '    source.dealt = other_card\n    label.text')),
            (owner, panel.replace('Deck.new()', 'Other.new()')),
            (owner, panel.replace('    label.text = source.dealt.get("copy", "")',
                                  '    print(\'source.dealt.get("copy", "")\')')),
        ):
            with self.subTest(loader=loader, reader=reader):
                self.assertNotIn(expected, reads(loader, reader).get("cards.json", ()))
        self.assertNotIn(("cards", None, "get"), reads(owner, panel)["cards.json"])

    def test_literal_star_integer_and_dynamic_keys_do_not_credit_named_siblings(self):
        td, root = self.fixture()
        self.addCleanup(td.cleanup)
        data = root / "game/data/map.json"
        data.write_text('{"rows":{"*":{"leaf":1},"x":{"leaf":2},"y":{"leaf":3}}}', encoding="utf-8")
        game = root / "game/scripts/game"
        (game / "table.gd").write_text(
            'class_name Table\nvar rows := {}\nfunc _init():\n'
            '    var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/map.json"))\n'
            '    rows = d.get("rows", {})\n', encoding="utf-8")
        for key, expected, conditional in [('"*"', 2, False), ('"x"', 2, False),
                                            ('5', 3, False), ('kind', 3, True)]:
            with self.subTest(key=key):
                (game / "view.gd").write_text(
                    'var table := Table.new()\nfunc show_row(kind):\n'
                    f'    return table.rows.get({key}, {{}}).get("leaf")\n', encoding="utf-8")
                records = audit.scan(root, root / audit.DEFAULT_EXCEPTIONS)
                row = next(r for r in records if r["file"] == "game/data/map.json" and r.get("field") == "leaf")
                self.assertEqual(row["occurrences"], expected)
                self.assertEqual("dynamic dictionary key" in row["detail"], conditional)

    def entry_contract_fixture(self):
        td, root = self.fixture()
        for relative in audit.ENTRY_RECORD_CONSTANTS:
            target = root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text((TOOLS.parent / relative).read_text(encoding="utf-8"), encoding="utf-8")
        for filename in ["harukiya_entry.json", "harukiya_entry_retirement.json"]:
            path = root / "game/data/orison_v2" / filename
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(json.dumps({"source_records": [{"record_only_probe": 1}], "metadata": {"record_only_probe": 2}}), encoding="utf-8")
        return td, root

    def test_entry_record_credit_is_path_local_and_keeps_sibling(self):
        td, root = self.entry_contract_fixture()
        try:
            texts = {p: p.read_text(encoding="utf-8") for p in audit.production_sources(root)}
            self.assertEqual(len(audit.entry_whole_record_paths(root, texts)), 2)
            records = audit.scan(root, root / audit.DEFAULT_EXCEPTIONS)
            for filename in ["harukiya_entry.json", "harukiya_entry_retirement.json"]:
                match = [r for r in records if r["file"].endswith("/" + filename) and r.get("field") == "record_only_probe"]
                self.assertEqual(len(match), 1)
                self.assertEqual(match[0]["occurrences"], 1)  # Sibling not consumed.
        finally:
            td.cleanup()

    def test_entry_record_contract_rejects_changed_guard_reader_or_lineage(self):
        td, root = self.entry_contract_fixture()
        try:
            texts = {p: p.read_text(encoding="utf-8") for p in audit.production_sources(root)}
            cases = [
                ("game/scripts/building/harukiya_entry_retirement.gd", "rows.get(identity) != raw", "false"),
                ("game/scripts/building/harukiya_entry_retirement.gd", "rows.get(identity) != raw", "spec.source_records != data.source_records"),
                ("game/scripts/building/harukiya_entry_retirement.gd", "data.source_records != spec.get(\"source_records\", [])", "false"),
                ("game/scripts/building/harukiya_entry_retirement.gd", "FileAccess.get_file_as_string(DATA)", "FileAccess.get_file_as_string(ENTRY_DATA)"),
                ("game/scripts/building/orison_v2_bar_region.gd", "source_layout = layout", "source_layout = {}"),
                ("game/scripts/building/orison_v2_bar_region.gd", "Entry.mount_cell(geometry, source_layout)", "Entry.mount_cell(geometry, {})"),
                ("game/scripts/building/orison_v2_bar_region.gd", "res://data/building_layout.json", "res://data/unrelated.json"),
            ]
            for relative, old, new in cases:
                with self.subTest(relative=relative, old=old):
                    path = root / relative
                    self.assertIn(old, texts[path])
                    changed = dict(texts); changed[path] = texts[path].replace(old, new, 1)
                    self.assertEqual(audit.entry_whole_record_paths(root, changed), {})
            absent = dict(texts); del absent[root / "game/scripts/building/harukiya_entry_retirement.gd"]
            self.assertEqual(audit.entry_whole_record_paths(root, absent), {})
        finally:
            td.cleanup()

    def test_entry_identity_keys_do_not_hide_unknown_value_fields(self):
        cases = [
            ("orison_v2/harukiya_entry.json", {"materials": {"entry_new": {"unused_probe": 1}}}, "materials[].unused_probe"),
            ("orison_v2/harukiya_entry_retirement.json", {"stock_counts": {"stock_new": {"finish_new": {"unused_probe": 1}}}}, "stock_counts[][].unused_probe"),
            ("orison_v2/harukiya_entry_retirement.json", {"retirement": [{"owners": {"stock_new": {"unused_probe": 1}}}]}, "retirement[].owners[].unused_probe"),
        ]
        for filename, document, expected in cases:
            with self.subTest(filename=filename, expected=expected):
                fields = audit.data_json_fields(document, filename)
                self.assertIn(expected, fields)
                self.assertTrue(any("_new" in name for name in audit.data_json_fields(document, "unrelated.json")))

    def test_entry_identity_declaration_does_not_grant_file_or_field_reader(self):
        td, root = self.fixture()
        try:
            path = root / "game/data/orison_v2/harukiya_entry.json"
            path.parent.mkdir()
            path.write_text(json.dumps({"materials": {"entry_new": {"unused_probe": 1}}, "native_parts": [{"unused_part": 1}], "fixtures": [{"unused_fixture": 1}]}), encoding="utf-8")
            records = audit.scan(root, root / audit.DEFAULT_EXCEPTIONS)
            owned = [r for r in records if r["file"] == "game/data/orison_v2/harukiya_entry.json"]
            self.assertTrue(any(r["kind"] == "FILE_UNREAD" for r in owned))
            self.assertTrue({"unused_probe", "unused_part", "unused_fixture"}.issubset({r.get("field") for r in owned}))
            self.assertNotIn("entry_new", {r.get("field") for r in owned})
        finally:
            td.cleanup()

    def test_loop_performance_identity_maps_preserve_unread_phase_fields(self):
        document = {
            "profiles": {"some_resident": {"line": "Hello", "unused_profile": 1}},
            "anchors": {"some_visit": {"actors": {
                "some_resident": [{"until": 10, "unused_phase": 1}]
            }}}
        }
        fields = audit.data_json_fields(document, "temporal/performances.json")
        self.assertIn("profiles[].unused_profile", fields)
        self.assertIn("anchors[].actors[][].unused_phase", fields)
        self.assertFalse(any("some_resident" in key or "some_visit" in key for key in fields))
        other = audit.data_json_fields(document, "unrelated.json")
        self.assertIn("anchors.some_visit.actors.some_resident[].unused_phase", other)

    def test_readable_library_identity_maps_do_not_exempt_record_fields(self):
        for filename, document, expected in [
            ("material_catalog.json", {"arbitrary_title":{"roughness":0.5, "unread_probe":1}}, "[].unread_probe"),
            ("audio_cues.json", {"cues":{"arbitrary_title":{"stream_key":"x", "unread_probe":1}}}, "cues[].unread_probe"),
            ("orison_v2/book_spreads.json", {"spreads":{"arbitrary_title":{"left":{"body":"x", "unread_probe":1}}}}, "spreads[].left.unread_probe"),
            ("orison_v2/nook_readable_books.json", {"parts":{"arbitrary_title":{"collision":True,"unread_probe":1}}}, "parts[].unread_probe"),
            ("orison_v2/nook_readable_books.json", {"books":{"arbitrary_title":{"parts":[], "unread_probe":1}}}, "books[].unread_probe"),
            ("orison_v2/readable_library.json", {"books":{"arbitrary_title":{"parts":[], "unread_probe":1}}}, "books[].unread_probe"),
        ]:
            fields=audit.data_json_fields(document, filename)
            self.assertIn(expected, fields)
            self.assertFalse(any("arbitrary_title" in name for name in fields))
            # An unrelated file cannot borrow this schema's identity declaration.
            other=audit.data_json_fields(document, "unrelated.json")
            self.assertTrue(any("arbitrary_title" in name for name in other))

    def fixture(self):
        td = tempfile.TemporaryDirectory()
        root = Path(td.name)
        (root / "game/data").mkdir(parents=True)
        (root / "game/scripts/game").mkdir(parents=True)
        (root / "tools").mkdir()
        (root / "game/data/live.json").write_text(
            json.dumps({"used": 1, "dead": 2}), encoding="utf-8")
        (root / "game/data/orphan.json").write_text(
            json.dumps({"claim": "this file says it is read"}), encoding="utf-8")
        (root / "game/scripts/game/reader.gd").write_text(
            'const P="res://data/live.json"\nfunc f(d): return d.used\n', encoding="utf-8")
        (root / "game/scripts/game/reality_game_state.gd").write_text(
            'func _fresh_data() -> Dictionary:\n'
            '\treturn {\n\t\t"dead_float": 0.0,\n\t}\n', encoding="utf-8")
        (root / "tools/data_consumption_exceptions.json").write_text(
            '{"files":{},"fields":{}}', encoding="utf-8")
        return td, root

    def test_baseline_fails_only_on_new_findings_and_reports_resolved(self):
        td, root = self.fixture()
        try:
            import contextlib, io
            quiet = contextlib.redirect_stdout(io.StringIO())
            with quiet:
                self.assertEqual(audit.main(["--root", str(root), "--write-baseline"]), 0)
                self.assertEqual(audit.main(["--root", str(root), "--baseline"]), 0)
            # A new unread field is new debt: the baseline does not excuse it.
            (root / "game/data/live.json").write_text(
                json.dumps({"used": 1, "dead": 2, "fresh": 3}), encoding="utf-8")
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                self.assertEqual(audit.main(["--root", str(root), "--baseline", "--json"]), 1)
            report = json.loads(out.getvalue())["baseline"]
            self.assertEqual(report["new"], ["FIELD_UNREAD|game/data/live.json|fresh"])
            # Reading a known-dead field resolves it without failing the gate.
            (root / "game/scripts/game/reader.gd").write_text(
                'const P="res://data/live.json"\nfunc f(d): return d.used + d.dead + d.fresh\n',
                encoding="utf-8")
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                self.assertEqual(audit.main(["--root", str(root), "--baseline", "--json"]), 0)
            self.assertIn("FIELD_UNREAD|game/data/live.json|dead",
                          json.loads(out.getvalue())["baseline"]["resolved"])
        finally:
            td.cleanup()

    def test_malformed_baseline_is_a_usage_error(self):
        td, root = self.fixture()
        try:
            (root / "tools/data_consumption_baseline.json").write_text('{"records": []}', encoding="utf-8")
            import contextlib, io
            with contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(audit.main(["--root", str(root), "--baseline"]), 4)
        finally:
            td.cleanup()

    def test_file_and_field_deadness_are_independent(self):
        td, root = self.fixture()
        try:
            rows = audit.scan(root, root / audit.DEFAULT_EXCEPTIONS)
            self.assertTrue(any(r["kind"] == "FILE_UNREAD" and "orphan" in r["file"] for r in rows))
            self.assertTrue(any(r["kind"] == "FIELD_UNREAD" and r.get("field") == "dead" for r in rows))
            self.assertFalse(any(r["kind"] == "FIELD_UNREAD" and r.get("field") == "used" for r in rows))
        finally:
            td.cleanup()

    def test_artifact_prose_does_not_assert_its_consumption(self):
        td, root = self.fixture()
        try:
            rows = audit.scan(root, root / audit.DEFAULT_EXCEPTIONS)
            self.assertTrue(any(r["kind"] == "FILE_UNREAD" and "orphan" in r["file"] for r in rows))
        finally:
            td.cleanup()

    def test_live_known_dead_schedule_fields(self):
        rows = audit.scan(TOOLS.parent, TOOLS.parent / audit.DEFAULT_EXCEPTIONS)
        dead = {(r.get("file"), str(r.get("field", "")).rsplit(".", 1)[-1])
                for r in rows if r["kind"] == "FIELD_UNREAD"}
        self.assertTrue(any(f == "outfit" for _p, f in dead))
        self.assertTrue(any(f == "with" for _p, f in dead))
        self.assertTrue(any(f == "route" for _p, f in dead))

    def test_live_progress_floats_are_monotonic_only(self):
        rows = audit.scan(TOOLS.parent, TOOLS.parent / audit.DEFAULT_EXCEPTIONS)
        fields = {r.get("field") for r in rows if r["kind"] == "DURABLE_NUMERIC_MONOTONIC_ONLY"}
        self.assertIn("building_stability", fields)
        self.assertIn("reality_coherence", fields)

    def test_approved_nested_exterior_home_is_enumerated_and_can_go_green(self):
        td, root = self.fixture()
        try:
            exterior = root / "game/data/orison_v2/exterior"
            exterior.mkdir(parents=True)
            (exterior / "shops.json").write_text(
                json.dumps({"shops": [{"id": "SHOP_BODEGA", "tier": "S1"}]}),
                encoding="utf-8")
            (root / "game/scripts/game/exterior_reader.gd").write_text(
                'const P="res://data/orison_v2/exterior/shops.json"\n'
                'func f(row): return [row.shops, row.id, row.tier]\n',
                encoding="utf-8")
            rows = audit.scan(root, root / audit.DEFAULT_EXCEPTIONS)
            target = "game/data/orison_v2/exterior/shops.json"
            self.assertFalse(any(
                r["file"] == target and r["kind"] in {"FILE_UNREAD", "FIELD_UNREAD"}
                for r in rows))
        finally:
            td.cleanup()

    def test_floor01_registry_identity_maps_are_data_but_value_schema_is_audited(self):
        td, root = self.fixture()
        try:
            (root / "game/data/floor_01_cell_registry.json").write_text(
                json.dumps({
                    "schema": "orison.floor01.cell-registry.v1",
                    "semantic_owner_index": {
                        "F01_DOOR_06": "CELL_FACADE",
                    },
                    "compatibility_alias_index": {
                        "F01_ceiling_plaster": {
                            "cell_id": "CELL_INTERIOR",
                            "node_index": 0,
                            "mesh_index": 0,
                            "unread_schema_field": "must remain visible",
                        },
                    },
                }), encoding="utf-8")
            (root / "game/scripts/game/floor01_registry.gd").write_text(
                'const P="res://data/floor_01_cell_registry.json"\n'
                'func f(row): return [row.schema, row.semantic_owner_index, '
                'row.compatibility_alias_index, row.cell_id, row.node_index, '
                'row.mesh_index]\n', encoding="utf-8")
            rows = audit.scan(root, root / audit.DEFAULT_EXCEPTIONS)
            target = "game/data/floor_01_cell_registry.json"
            unread = {r.get("field") for r in rows
                      if r["file"] == target and r["kind"] == "FIELD_UNREAD"}
            self.assertNotIn("F01_DOOR_06", unread)
            self.assertNotIn("F01_ceiling_plaster", unread)
            self.assertIn("unread_schema_field", unread)
        finally:
            td.cleanup()

    def test_file_identity_maps_are_exact_and_keep_value_fields(self):
        # Schema-less production catalogs use variable record IDs. Only the
        # exact file/container pair changes classification; child fields do not.
        declarations = {
            "prop_catalog.json": {""},
            "reality_cases.json": {""},
            "reality_rules.json": {""},
            "music_catalog.json": {"tracks", "residents"},
            "resident_schedules.json": {"residents"},
            "maintenance_activities.json": {"activities"},
            "orison_v2/upper_floor_programs.json": {"doors"},
            "orison_v2/mina_routine.json": {"places"},
            "runtime_material_sets.json": {"materials"},
        }
        for filename, containers in declarations.items():
            for container in containers:
                with self.subTest(filename=filename, container=container):
                    record = {"AUTHORED_RECORD_ID": {"unread_value": 1}}
                    value = {container: record} if container else record
                    fields = audit.data_json_fields(value, filename)
                    self.assertFalse(any("AUTHORED_RECORD_ID" in key for key in fields))
                    self.assertTrue(any(key.endswith("unread_value") for key in fields))
                    # A same basename in another directory gets no declaration.
                    other = audit.data_json_fields(value, "unrelated/" + filename)
                    self.assertTrue(any("AUTHORED_RECORD_ID" in key for key in other))
                    # A caller without exact file identity also stays conservative.
                    self.assertEqual(other, audit.data_json_fields(value))

    def test_variable_door_id_is_not_a_field_but_unknown_value_stays_unread(self):
        td, root = self.fixture()
        try:
            path = root / "game/data/orison_v2/upper_floor_programs.json"
            path.parent.mkdir()
            path.write_text(json.dumps({
                "doors": {"F05_UNKNOWN_DOOR": {"unit": "5A", "unread_value": 1}},
            }), encoding="utf-8")
            (root / "game/scripts/game/doors.gd").write_text(
                'const P="res://data/orison_v2/upper_floor_programs.json"\n'
                'func f(source, identity): return source.doors[identity].unit\n',
                encoding="utf-8")
            rows = audit.scan(root, root / audit.DEFAULT_EXCEPTIONS)
            unread = {r.get("field") for r in rows
                      if r["file"] == "game/data/orison_v2/upper_floor_programs.json"
                      and r["kind"] == "FIELD_UNREAD"}
            self.assertNotIn("F05_UNKNOWN_DOOR", unread)
            self.assertIn("unread_value", unread)
        finally:
            td.cleanup()

    def test_identity_classification_does_not_credit_unrelated_field_readers(self):
        td, root = self.fixture()
        try:
            path = root / "game/data/music_catalog.json"
            path.write_text(json.dumps({
                "tracks": {"TRACK_ID": {"unread_value": 1}},
                "other": {"TRACK_ID": {"other_value": 2}},
            }), encoding="utf-8")
            reader = root / "game/scripts/game/catalog.gd"
            reader.write_text(
                'const P="res://data/music_catalog.json"\n'
                'func f(catalog, identity): return catalog.tracks[identity]\n',
                encoding="utf-8")
            (root / "game/scripts/game/unrelated.gd").write_text(
                'func f(other): return other.unread_value\n', encoding="utf-8")
            rows = audit.scan(root, root / audit.DEFAULT_EXCEPTIONS)
            unread = {r.get("field") for r in rows
                      if r["file"] == "game/data/music_catalog.json"
                      and r["kind"] == "FIELD_UNREAD"}
            self.assertIn("unread_value", unread)
            self.assertIn("TRACK_ID", unread)  # same key outside declared tracks
            self.assertIn("other_value", unread)
            reader.unlink()
            rows = audit.scan(root, root / audit.DEFAULT_EXCEPTIONS)
            self.assertTrue(any(r["file"] == "game/data/music_catalog.json"
                                and r["kind"] == "FILE_UNREAD" for r in rows))
        finally:
            td.cleanup()

    def inherited_fixture(self):
        td, root = self.fixture()
        (root / "game/data/live.json").write_text(json.dumps({
            "props": [{"surfaces": [{"normals": [1], "vertices": [2],
                                      "material": "paper"}]}],
        }), encoding="utf-8")
        (root / "game/scripts/game/reader.gd").write_text(
            'extends "res://scripts/game/mesh_base.gd"\n'
            'const DATA = "res://data/live.json"\n'
            'func mount():\n'
            '    var source = JSON.parse_string(FileAccess.get_file_as_string(DATA))\n'
            '    for record: Dictionary in source.props:\n'
            '        _surfaces(record.surfaces)\n', encoding="utf-8")
        (root / "game/scripts/game/mesh_base.gd").write_text(
            'func _surfaces(surfaces):\n'
            '    for surface: Dictionary in surfaces:\n'
            '        print(surface.normals, surface.get("vertices"))\n'
            '    var unrelated = {}\n'
            '    print(unrelated.material)\n', encoding="utf-8")
        return td, root

    def unread_live_fields(self, root):
        return {r.get("field") for r in audit.scan(root, root / audit.DEFAULT_EXCEPTIONS)
                if r["file"] == "game/data/live.json" and r["kind"] == "FIELD_UNREAD"}

    def test_inherited_helper_tracks_only_the_passed_parameter(self):
        td, root = self.inherited_fixture()
        try:
            unread = self.unread_live_fields(root)
            self.assertNotIn("normals", unread)
            self.assertNotIn("vertices", unread)
            self.assertIn("material", unread)  # another dictionary in the same base
        finally:
            td.cleanup()

    def test_inherited_helper_resolves_nearest_base_and_stops_cycles(self):
        td, root = self.inherited_fixture()
        try:
            base = root / "game/scripts/game/mesh_base.gd"
            grand = root / "game/scripts/game/mesh_grand.gd"
            grand.write_text(base.read_text(encoding="utf-8"), encoding="utf-8")
            base.write_text('extends "res://scripts/game/mesh_grand.gd"\n', encoding="utf-8")
            self.assertNotIn("normals", self.unread_live_fields(root))
            self.assertIn("material", self.unread_live_fields(root))
            base.write_text(base.read_text() + 'func _surfaces(surfaces):\n    pass\n', encoding="utf-8")
            self.assertIn("normals", self.unread_live_fields(root))
            base.write_text('extends "res://scripts/game/reader.gd"\n', encoding="utf-8")
            self.assertIn("normals", self.unread_live_fields(root))
        finally:
            td.cleanup()

    def test_inherited_nested_read_consumes_container_but_not_siblings(self):
        td, root = self.inherited_fixture()
        try:
            (root / "game/data/live.json").write_text(json.dumps({
                "props": [{"surfaces": [{"finish": {"roughness": .5, "unused": 1}},
                                         {"finish": {}}]}],
            }), encoding="utf-8")
            base = root / "game/scripts/game/mesh_base.gd"
            base.write_text('func _surfaces(surfaces):\n'
                            '    for surface in surfaces:\n'
                            '        print(surface.finish.roughness)\n', encoding="utf-8")
            unread = self.unread_live_fields(root)
            self.assertNotIn("finish", unread)
            self.assertNotIn("roughness", unread)
            self.assertIn("unused", unread)
            base.write_text('func _surfaces(surfaces):\n'
                            '    for surface in surfaces:\n'
                            '        print(surface.finish)\n', encoding="utf-8")
            self.assertIn("roughness", self.unread_live_fields(root))
        finally:
            td.cleanup()

    def test_inherited_helper_cannot_credit_another_file_or_changed_argument(self):
        td, root = self.inherited_fixture()
        try:
            caller = root / "game/scripts/game/reader.gd"
            original = caller.read_text(encoding="utf-8")
            for replacement in [
                '        _surfaces({})',
                '        print("_surfaces(record.surfaces)")',
                '        var record = {}\n        _surfaces(record.surfaces)',
                '        _surfaces(make_copy(record.surfaces))',
            ]:
                caller.write_text(original.replace('        _surfaces(record.surfaces)', replacement), encoding="utf-8")
                self.assertIn("normals", self.unread_live_fields(root))
            caller.write_text(original.replace('FileAccess.get_file_as_string(DATA)',
                'FileAccess.get_file_as_string("res://data/orphan.json")'), encoding="utf-8")
            self.assertIn("normals", self.unread_live_fields(root))
        finally:
            td.cleanup()

    def test_inherited_helper_override_and_rebinding_do_not_counterfeit_reads(self):
        td, root = self.inherited_fixture()
        try:
            caller = root / "game/scripts/game/reader.gd"
            original = caller.read_text(encoding="utf-8")
            caller.write_text(original + '\nfunc _surfaces(surfaces):\n    pass\n', encoding="utf-8")
            self.assertIn("normals", self.unread_live_fields(root))
            caller.write_text(original, encoding="utf-8")
            parent = root / "game/scripts/game/mesh_base.gd"
            original_parent = parent.read_text(encoding="utf-8")
            parent.write_text(original_parent.replace('    for surface: Dictionary in surfaces:',
                '    surfaces = []\n    for surface: Dictionary in surfaces:'), encoding="utf-8")
            self.assertIn("normals", self.unread_live_fields(root))
        finally:
            td.cleanup()

    def test_inherited_parameter_aliases_reject_member_and_conditional_lookalikes(self):
        td, root = self.inherited_fixture()
        try:
            parent = root / "game/scripts/game/mesh_base.gd"
            cases = [
                '    for surface in surfaces:\n        print(unrelated.surface.normals)\n',
                '    for surface in surfaces:\n        var shadow = surface if false else {}\n        print(shadow.normals)\n',
                '    for surface in surfaces:\n        pass\n    for surface in unrelated:\n        print(surface.normals)\n',
                '    for surface in self.surfaces:\n        print(surface.normals)\n',
            ]
            for body in cases:
                with self.subTest(body=body):
                    parent.write_text('func _surfaces(surfaces):\n' + body, encoding="utf-8")
                    self.assertIn("normals", self.unread_live_fields(root))
        finally:
            td.cleanup()

    def test_inherited_parse_uses_local_path_binding_without_constant_leakage(self):
        td, root = self.inherited_fixture()
        try:
            caller = root / "game/scripts/game/reader.gd"
            original = caller.read_text(encoding="utf-8")
            for shadow in ['var DATA = "res://data/orphan.json"', 'var DATA = unknown_path()']:
                caller.write_text(original.replace('func mount():\n', 'func mount():\n    ' + shadow + '\n'), encoding="utf-8")
                self.assertIn("normals", self.unread_live_fields(root))
            caller.write_text(original.replace('func mount():\n',
                'func earlier():\n    const DATA = "res://data/orphan.json"\n\nfunc mount():\n'), encoding="utf-8")
            self.assertNotIn("normals", self.unread_live_fields(root))
        finally:
            td.cleanup()

    def test_nested_durable_numbers_are_walked_and_scoped_to_their_owner(self):
        td, root = self.fixture()
        try:
            (root / "game/scripts/game/reality_game_state.gd").write_text(
                """func _fresh_data() -> Dictionary:
\treturn {
\t\t\"shop_buckets\": {
\t\t\t\"SHOP_BODEGA\": {
\t\t\t\t\"stock\": 8,
\t\t\t\t\"last_simulated_minute\": 0.0,
\t\t\t\t\"orphan_count\": 1,
\t\t\t\t\"write_only_count\": 0,
\t\t\t},
\t\t},
\t}
""", encoding="utf-8")
            (root / "game/scripts/game/shop_bucket.gd").write_text(
                """func advance(elapsed):
\tvar buckets = RealityState.data.shop_buckets
\tvar bucket = buckets[\"SHOP_BODEGA\"]
\tprint(bucket.get(\"stock\", 0))
\tbucket.last_simulated_minute = bucket.last_simulated_minute + elapsed
\tbucket.write_only_count = elapsed
""", encoding="utf-8")
            # The same token in a subsystem that never opens shop_buckets must
            # not counterfeit a reader for the durable owner.
            (root / "game/scripts/game/unrelated.gd").write_text(
                'func f(d): return d.get("orphan_count", 0)\n', encoding="utf-8")
            rows = audit.scan(root, root / audit.DEFAULT_EXCEPTIONS)
            unread = {r.get("field") for r in rows
                      if r["kind"] == "DURABLE_NUMERIC_UNREAD"}
            monotonic = {r.get("field") for r in rows
                         if r["kind"] == "DURABLE_NUMERIC_MONOTONIC_ONLY"}
            self.assertNotIn("shop_buckets.SHOP_BODEGA.stock", unread)
            self.assertIn("shop_buckets.SHOP_BODEGA.orphan_count", unread)
            self.assertIn("shop_buckets.SHOP_BODEGA.write_only_count", unread)
            self.assertIn(
                "shop_buckets.SHOP_BODEGA.last_simulated_minute", monotonic)
        finally:
            td.cleanup()

    def test_equality_is_a_reader_and_constant_owner_keys_resolve(self):
        td, root = self.fixture()
        try:
            (root / "game/scripts/game/reality_game_state.gd").write_text(
                """func _fresh_data() -> Dictionary:
\treturn {
\t\t\"shop_buckets\": {
\t\t\t\"SHOP_BODEGA\": {
\t\t\t\t\"stock\": 0,
\t\t\t},
\t\t},
\t}
""", encoding="utf-8")
            (root / "game/scripts/game/shop_bucket.gd").write_text(
                """const STATE_KEY = \"shop_buckets\"
func empty() -> bool:
\tvar buckets = RealityState.data.get(STATE_KEY, {})
\tvar bucket = buckets[\"SHOP_BODEGA\"]
\treturn bucket.stock == 0
""", encoding="utf-8")
            rows = audit.scan(root, root / audit.DEFAULT_EXCEPTIONS)
            self.assertFalse(any(
                r.get("field") == "shop_buckets.SHOP_BODEGA.stock"
                and r["kind"].startswith("DURABLE_NUMERIC") for r in rows))
        finally:
            td.cleanup()

    def test_compound_progress_is_monotonic_and_siblings_do_not_cross_clear(self):
        td, root = self.fixture()
        try:
            (root / "game/scripts/game/reality_game_state.gd").write_text(
                """func _fresh_data() -> Dictionary:
\treturn {
\t\t\"shop_buckets\": {
\t\t\t\"SHOP_BODEGA\": {\n\t\t\t\t\"stock\": 1,\n\t\t\t\t\"progress\": 0,\n\t\t\t},
\t\t\t\"SHOP_DELI\": {\n\t\t\t\t\"stock\": 1,\n\t\t\t},
\t\t},
\t}
""", encoding="utf-8")
            (root / "game/scripts/game/shop_bucket.gd").write_text(
                """func tick():
\tvar buckets = RealityState.data.shop_buckets
\tvar bodega = buckets[\"SHOP_BODEGA\"]
\tbodega.progress += 1
\tvar key = \"SHOP_DELI\"
\tvar deli = buckets[key]
\tprint(deli.stock)
\tvar unrelated = {}
\tprint(unrelated.stock)
\tprint(\"RealityState.data.shop_buckets.SHOP_BODEGA.stock\")
""", encoding="utf-8")
            rows = audit.scan(root, root / audit.DEFAULT_EXCEPTIONS)
            unread = {r.get("field") for r in rows
                      if r["kind"] == "DURABLE_NUMERIC_UNREAD"}
            monotonic = {r.get("field") for r in rows
                         if r["kind"] == "DURABLE_NUMERIC_MONOTONIC_ONLY"}
            self.assertIn("shop_buckets.SHOP_BODEGA.stock", unread)
            self.assertNotIn("shop_buckets.SHOP_DELI.stock", unread)
            self.assertIn("shop_buckets.SHOP_BODEGA.progress", monotonic)
        finally:
            td.cleanup()

    def test_array_schema_uses_wildcard_path_and_generic_reader(self):
        td, root = self.fixture()
        try:
            (root / "game/scripts/game/reality_game_state.gd").write_text(
                """func _fresh_data() -> Dictionary:
\treturn {
\t\t\"shops\": [
\t\t\t{
\t\t\t\t\"stock\": 8,
\t\t\t},
\t\t],
\t}
""", encoding="utf-8")
            (root / "game/scripts/game/shop_bucket.gd").write_text(
                """func total() -> int:
\tvar shops = RealityState.data.shops
\tvar result := 0
\tfor shop in shops:
\t\tresult += shop.stock
\treturn result
""", encoding="utf-8")
            numeric = audit.durable_numeric_defaults(
                (root / "game/scripts/game/reality_game_state.gd").read_text())
            self.assertIn(("shops", "*", "stock"), numeric)
            rows = audit.scan(root, root / audit.DEFAULT_EXCEPTIONS)
            self.assertFalse(any(
                r.get("field") == "shops.*.stock"
                and r["kind"].startswith("DURABLE_NUMERIC") for r in rows))
        finally:
            td.cleanup()

    def test_missing_durable_schema_fails_closed(self):
        with self.assertRaisesRegex(ValueError, "no _fresh_data"):
            audit.durable_numeric_defaults('"stock": 8\n')

    def test_numeric_forms_and_constants_remain_in_the_nested_schema(self):
        state = """const DEFAULT_STOCK := 1_000
func _fresh_data() -> Dictionary:
\treturn {
\t\t\"bucket\": {
\t\t\t\"positive\": +1,
\t\t\t\"fraction\": .5,
\t\t\t\"stock\": DEFAULT_STOCK,
\t\t},
\t}
"""
        numeric = audit.durable_numeric_defaults(state)
        self.assertEqual(
            {("bucket", "positive"), ("bucket", "fraction"),
             ("bucket", "stock")}, set(numeric))

    def test_inline_or_numeric_expression_schema_fails_closed(self):
        inline = """func _fresh_data() -> Dictionary:
\treturn {\n\t\t\"bucket\": {\"stock\": 8},\n\t}\n"""
        expression = """func _fresh_data() -> Dictionary:
\treturn {\n\t\t\"stock\": int(8),\n\t}\n"""
        with self.assertRaisesRegex(ValueError, "inline durable container"):
            audit.durable_numeric_defaults(inline)
        with self.assertRaisesRegex(ValueError, "unsupported numeric"):
            audit.durable_numeric_defaults(expression)

    def test_member_aliases_and_value_methods_remain_real_reads(self):
        td, root = self.fixture()
        try:
            (root / "game/scripts/game/reality_game_state.gd").write_text(
                """func _fresh_data() -> Dictionary:
\treturn {
\t\t\"shop_buckets\": {
\t\t\t\"SHOP_BODEGA\": {\n\t\t\t\t\"stock\": 8,\n\t\t\t},
\t\t},
\t}
""", encoding="utf-8")
            (root / "game/scripts/game/shop_bucket.gd").write_text(
                """var _bucket: Dictionary
func stock_text() -> String:
\treturn _bucket.stock.to_string() + \" units=remaining\"
func bind_state() -> void:
\t_bucket = RealityState.data.shop_buckets[\"SHOP_BODEGA\"]
func teardown() -> void:
\t_bucket = {}
""", encoding="utf-8")
            rows = audit.scan(root, root / audit.DEFAULT_EXCEPTIONS)
            self.assertFalse(any(
                r.get("field") == "shop_buckets.SHOP_BODEGA.stock"
                and r["kind"].startswith("DURABLE_NUMERIC") for r in rows))
        finally:
            td.cleanup()

    def test_constructor_argument_is_a_read_not_a_returned_member_alias(self):
        source = '''var _state: Dictionary
func bind_state():
    _state = RealityState.data.campaign_clock
func rebuild():
    var old = _state
    _state = _civil_record(date, int(old.start_minute_of_day))
func display():
    return _state.elapsed_minutes
'''
        events = audit.numeric_source_events(source)
        self.assertIn((("campaign_clock", "start_minute_of_day"), "read"), events)
        self.assertIn((("campaign_clock", "elapsed_minutes"), "read"), events)
        self.assertFalse(any(path[:2] == ("campaign_clock", "start_minute_of_day")
                             and len(path) > 2 for path, _kind in events))
        # A function result must not invent a reader of an unrelated child.
        result = audit.numeric_source_events('''func pretend():
    var product = make_value(RealityState.data.bucket.stock)
    print(product.unconsumed)
''')
        self.assertNotIn((("bucket", "stock", "unconsumed"), "read"), result)

    def test_a_state_chain_inside_prose_cannot_counterfeit_a_reader(self):
        td, root = self.fixture()
        try:
            (root / "game/scripts/game/reality_game_state.gd").write_text(
                """func _fresh_data() -> Dictionary:
\treturn {
\t\t\"shop_buckets\": {
\t\t\t\"SHOP_BODEGA\": {\n\t\t\t\t\"stock\": 8,\n\t\t\t},
\t\t},
\t}
""", encoding="utf-8")
            (root / "game/scripts/game/shop_bucket.gd").write_text(
                'func explain():\n'
                '\tprint("RealityState.data.shop_buckets.SHOP_BODEGA.stock")\n',
                encoding="utf-8")
            rows = audit.scan(root, root / audit.DEFAULT_EXCEPTIONS)
            self.assertTrue(any(
                r.get("field") == "shop_buckets.SHOP_BODEGA.stock"
                and r["kind"] == "DURABLE_NUMERIC_UNREAD" for r in rows))
        finally:
            td.cleanup()


if __name__ == "__main__":
    unittest.main(verbosity=2)
