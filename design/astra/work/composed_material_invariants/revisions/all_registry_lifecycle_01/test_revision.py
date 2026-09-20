from pathlib import Path
import hashlib
import json
import re
import unittest

HERE = Path(__file__).resolve().parent
REL = Path("game/tests/vulkan_composed_root_test.gd")


class StrongerObserverSourceControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.old = (HERE / "originals" / REL).read_text()
        cls.new = (HERE / "proposed" / REL).read_text()
        cls.body = (HERE / "refresh.gdfragment").read_text()

    def test_exact_parent_and_only_observer_region_changes(self):
        receipt = json.loads((HERE / "preparation.json").read_text())
        self.assertEqual(hashlib.sha256((HERE / "originals" / REL).read_bytes()).hexdigest(), receipt["parent_fixture_sha256"])
        self.assertEqual(hashlib.sha256((HERE / "proposed" / REL).read_bytes()).hexdigest(), receipt["fixture_sha256"])
        start, stop = "func _exercise_actual_material_refresh(", "func _material_refresh_precondition("
        self.assertEqual(self.old.split(start, 1)[0], self.new.split(start, 1)[0])
        self.assertEqual(self.old.split(stop, 1)[1], self.new.split(stop, 1)[1])
        self.assertEqual(self.new[self.new.index(start):self.new.index(stop)].rstrip(), self.body.rstrip())

    def test_all_original_assertions_and_timers_retained(self):
        self.assertEqual([line for line in self.old.splitlines() if "_check(" in line],
                         [line for line in self.new.splitlines() if "_check(" in line])
        old_method = self.old.split("func _transition(", 1)[1].split("\nfunc _check_zone(", 1)[0]
        new_method = self.new.split("func _transition(", 1)[1].split("\nfunc _check_zone(", 1)[0]
        self.assertEqual(old_method, new_method)

    def test_comparisons_do_not_short_circuit_on_prior_aggregate_failure(self):
        self.assertNotRegex(self.body, r"okay\s*=\s*okay\s+and")
        self.assertEqual(self.body.count("var identity_matches: bool ="), 2)
        self.assertEqual(self.body.count("var state_matches: bool ="), 2)
        self.assertEqual(self.body.count('"identity_matches": identity_matches'), 2)
        self.assertEqual(self.body.count('"state_matches": state_matches'), 2)
        self.assertIn('"case_comparisons_evaluated": rows_evaluated * 2', self.body)

    def test_all_registry_targets_captured_before_push_and_restored_before_refresh(self):
        capture = self.body.index("var registry_targets := {}")
        snapshot = self.body.index("var registry_before := _material_lifecycle_target_snapshot")
        push = self.body.index("enc._push_living_lifecycle(")
        restore = self.body.index("var restore_targets: Dictionary = poisoned.duplicate()")
        refresh = self.body.index("enc.refresh()", restore)
        after = self.body.index("var registry_after := _material_lifecycle_target_snapshot")
        self.assertTrue(capture < snapshot < push < restore < refresh < after)
        self.assertIn('for registered in enc.storey_materials.get(floor_id, []):', self.body[capture:snapshot])
        self.assertIn('if poisoned.has(material_id): original_value = poisoned[material_id].value', self.body[capture:snapshot])
        self.assertIn('if not restore_targets.has(material_id): restore_targets[material_id] = registry_targets[material_id]', self.body[restore:refresh])
        self.assertIn('item.material.set_shader_parameter("living_lifecycle_stage", item.value)', self.body[restore:refresh])
        self.assertIn("registry_before == registry_after", self.body)

    def test_refusal_and_cleanup_remain_synchronous_without_returned_resources(self):
        self.assertNotIn("await ", self.body)
        refusal = self.body.split("if precondition.passed != true:", 1)[1].split("\n\tvar poisoned", 1)[0]
        self.assertNotIn("enc.refresh()", refusal)
        self.assertNotIn("enc._forced =", refusal)
        self.assertIn('"mutated": false', refusal)
        final_return = self.body.split('return {"passed": okay', 1)[1].split("\n\nfunc ", 1)[0]
        self.assertNotIn('"material":', final_return)
        self.assertNotIn('"registry_targets":', final_return)
        serializer = self.body.split("func _material_lifecycle_target_snapshot", 1)[1]
        self.assertNotIn('"material":', serializer)


if __name__ == "__main__":
    unittest.main()
