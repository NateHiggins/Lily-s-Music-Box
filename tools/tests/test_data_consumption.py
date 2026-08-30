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
