from pathlib import Path
import json
import re
import unittest
import prepare


class FixtureRevisionControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.original = (prepare.HERE / "originals" / prepare.REL).read_text()
        cls.helper = (prepare.HERE / "material_helpers.gdfragment").read_text()
        cls.new = prepare.proposed(cls.original, cls.helper)

    def test_exact_original_hash(self):
        self.assertEqual(prepare.sha((prepare.HERE / "originals" / prepare.REL).read_bytes()), prepare.ORIGINAL_SHA)

    def test_all_original_assertion_calls_retained(self):
        old_calls = re.findall(r'_check\("[^"]+"', self.original)
        new_calls = re.findall(r'_check\("[^"]+"', self.new)
        for call in old_calls:
            self.assertEqual(new_calls.count(call), old_calls.count(call))

    def test_measured_transition_method_unchanged(self):
        def method(text):
            return text.split("func _transition(", 1)[1].split("\nfunc _check_zone(", 1)[0]
        self.assertEqual(method(self.original), method(self.new))

    def test_observations_after_measured_inner_cycle(self):
        self.assertIn('\t\t\tawait _transition(STATIONS[index], cycle, false)\n\t\t_observe_material_ownership', self.new)
        self.assertEqual(self.new.count('_observe_material_ownership("'), 3)

    def test_probe_restoration_is_synchronous_and_preserves_force_dictionary(self):
        body = self.helper.split("func _exercise_actual_material_refresh(", 1)[1].split("\n\nfunc _actual_material_state_snapshot(", 1)[0]
        self.assertNotIn("await ", body)
        self.assertIn("enc._forced = forced.duplicate(true)", body)
        self.assertIn("enc._forced = forced\n\tenc.refresh()", body)
        self.assertIn("before_state == after_state", body)

    def test_only_weak_references_cross_retirement(self):
        self.assertIn("material_case_refs[material_id] = weakref(material)", self.helper)
        self.assertIn('"draw": weakref(draw)', self.helper)
        self.assertIn("get_ref() != null", self.helper)

    def test_anchor_drift_rejected(self):
        with self.assertRaises(AssertionError):
            prepare.proposed(self.original.replace('\t_phase("after_retirement")\n', ""), self.helper)

    def test_unit_map_matches_independent_shipped_cases(self):
        case_data = json.loads((prepare.ROOT / "game/data/reality_cases.json").read_text())
        mapping = json.loads(self.helper.split("const MATERIAL_CASE_UNITS := ", 1)[1].split("\n}", 1)[0].replace(",\n", ",\n").rstrip().rstrip(",") + "\n}")
        self.assertEqual(mapping, {case: case_data[case]["unit"] for case in mapping})

    def test_precondition_refuses_before_mutation_and_values_stay_below_actual_threshold(self):
        body = self.helper.split("func _exercise_actual_material_refresh(", 1)[1].split("\n\nfunc _material_refresh_precondition(", 1)[0]
        refusal = body.split("if precondition.passed != true:", 1)[1].split("\n\tvar poisoned", 1)[0]
        self.assertIn('"mutated": false', refusal)
        self.assertNotIn("enc.refresh()", refusal)
        self.assertNotIn("enc._forced =", refusal)
        self.assertLess(body.index("if precondition.passed != true:"), body.index("enc._forced = forced.duplicate(true)"))
        values = json.loads(re.search(r"MATERIAL_PROBE_INTENSITIES := (\[[^\]]+\])", self.helper).group(1))
        owner = (prepare.HERE / "controls/build_marker_omission/originals/game/scripts/reality/apartment_encroachment.gd").read_text()
        threshold = float(re.search(r"BEACHHEAD_AT := ([0-9.]+)", owner).group(1))
        self.assertEqual(len(values), 6)
        self.assertTrue(all(0 <= value < threshold for value in values))
        self.assertIn("before_beachheads == during_beachheads", body)
        self.assertIn("before_beachheads == after_beachheads", body)


if __name__ == "__main__":
    unittest.main()
