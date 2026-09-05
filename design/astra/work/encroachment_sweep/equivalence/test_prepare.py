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
