import unittest
import prepare as p


class SourceControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.old = (p.REVISION / "originals" / p.REL).read_text(encoding="utf-8")
        cls.new = (p.REVISION / "proposed" / p.REL).read_text(encoding="utf-8")

    def test_baseline_exact_reviewed_bytes(self):
        self.assertEqual(p.sha((p.REVISION / "originals" / p.REL).read_bytes()), p.ORIGINAL_HASH)

    def test_only_method_changed(self):
        a, b = p.method_parts(self.old), p.method_parts(self.new)
        self.assertEqual(a[0], b[0])
        self.assertEqual(a[2].lstrip("\n"), b[2].lstrip("\n"))
        self.assertNotEqual(a[1], b[1])

    def test_adapter_has_no_method_change(self):
        self.assertEqual(p.adapted(self.new), self.new[len(p.CLASS):])

    def test_floor_owner_census_is_once_before_any_mesh(self):
        method = p.method_parts(self.new)[1]
        self.assertEqual(method.count("_prop_floor_owners()"), 1)
        self.assertLess(method.index("_prop_floor_owners()"), method.index(p.CENSUS))

    def test_known_metadata_checks_real_floor_before_retaining_row(self):
        method = p.method_parts(self.new)[1]
        known = method.split('if material.has_meta("encroachment_case"):', 1)[1].split("var aabb :=", 1)[0]
        self.assertIn("rows_by_case.has(owner_id) and _prop_matches_floor(mi,", known)
        self.assertIn("(units[owner_id] as Dictionary).floor_node, floor_owners)", known)
        self.assertLess(known.index("_prop_matches_floor"), known.index(".append("))

    def test_first_claim_floor_check_precedes_bounds_and_duplicate(self):
        method = p.method_parts(self.new)[1]
        claim = method.split(p.PRIORITY, 1)[1]
        self.assertIn("if not _prop_matches_floor(mi, unit.floor_node, floor_owners):", claim)
        self.assertLess(claim.index("_prop_matches_floor"), claim.index("var rect:"))
        self.assertLess(claim.index("_prop_matches_floor"), claim.index("material.duplicate()"))

    def test_floor_helpers_and_original_fixture_contract_unchanged(self):
        from pathlib import Path
        historical = Path(__file__).resolve().parent.with_name("ownership_7c54c_01")
        self.assertEqual(p.method_parts(self.old)[2], p.method_parts(self.new)[2])
        for relative in ("gate.py", "expected_check_contract.json",
                         "proposed/game/tests/encroachment_sweep_equivalence_test.gd",
                         "proposed/game/tests/EncroachmentSweepEquivalenceTest.tscn"):
            self.assertEqual((p.HERE / relative).read_bytes(), (historical / relative).read_bytes())

    def test_priority_control_only_changes_unclaimed_selection(self):
        broken = p.variant_source(self.new, "priority")
        a, b = p.method_parts(self.new), p.method_parts(broken)
        self.assertEqual(a[0], b[0])
        self.assertEqual(a[2], b[2])
        self.assertEqual(a[1].split(p.PRIORITY)[0], b[1].split("\t\tvar reversed_cases:")[0])
        self.assertIn('material.has_meta("encroachment_case")', b[1])
        self.assertIn("_living_candidate(mi, root)", b[1])

    def test_late_control_only_changes_census_lifetime(self):
        broken = p.variant_source(self.new, "drop_late")
        a, b = p.method_parts(self.new), p.method_parts(broken)
        self.assertEqual(a[0], b[0])
        self.assertEqual(a[2], b[2])
        self.assertEqual(a[1].split(p.CENSUS)[1], b[1].split('\tfor node in get_meta("equivalence_first_census"):\n')[1])

    def test_unknown_variant_rejected(self):
        with self.assertRaises(ValueError):
            p.variant_source(self.new, "unknown")

    def test_drift_rejected(self):
        with self.assertRaises(AssertionError):
            p.variant_source(self.new.replace(p.PRIORITY, "\t\tfor owner in units:\n"), "priority")
        with self.assertRaises(AssertionError):
            p.variant_source(self.new.replace(p.CENSUS, "\tfor node in []:\n"), "drop_late")


if __name__ == "__main__":
    unittest.main()
