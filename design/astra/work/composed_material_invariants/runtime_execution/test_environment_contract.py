import unittest
from environment_contract import NORMAL, prepare_environment, actual_wrapper_environment


class EnvironmentControls(unittest.TestCase):
    def test_normal_inputs_reach_exact_actual_wrapper_child(self):
        child, receipt = prepare_environment({"PATH": "retained", "PERF_FAKE": "1", "SURFACE_BUDGET": "0", "DAYNIGHT_FORCE": "2"})
        actual = actual_wrapper_environment(child, "fresh/profile", "fresh/frames")
        self.assertEqual({key: actual[key] for key in NORMAL}, NORMAL)
        self.assertEqual(actual["PATH"], "retained")
        self.assertEqual(actual["APPDATA"], str(__import__("pathlib").Path("fresh/profile")))
        self.assertEqual(actual["CAMPAIGN_TIME_FREEZE"], "1")
        self.assertFalse(any(key in actual for key in ("PERF_FAKE", "SURFACE_BUDGET", "DAYNIGHT_FORCE")))

    def test_hostile_force_is_not_silently_cleared(self):
        inherited = {"ENCROACH_FORCE": "mina:0.8"}
        actual = actual_wrapper_environment(inherited, "profile", "frames")
        self.assertEqual(actual["ENCROACH_FORCE"], "mina:0.8")
        with self.assertRaisesRegex(ValueError, "refusing instead of clearing"):
            prepare_environment(inherited)
        self.assertEqual(inherited, {"ENCROACH_FORCE": "mina:0.8"})

    def test_disabled_debug_or_all_floor_controls_rejected(self):
        for key, value in (("ENCROACH", "0"), ("LIVING", "0"), ("LIVING_ALL", "1"),
                           ("ENCROACH_DEBUG_VIEW", "1"), ("ENCROACH_DEBUG", "1"), ("ENCROACH_FORCE", "mina:0.1")):
            with self.subTest(key=key):
                with self.assertRaises(ValueError):
                    prepare_environment({key: value})

    def test_unknown_control_is_not_ignored(self):
        with self.assertRaises(ValueError):
            prepare_environment({"ENCROACH_UNREVIEWED": "1"})

    def test_readonly_projection_leaves_inputs_unchanged(self):
        inherited = {"ENCROACH": "1", "ENCROACH_FORCE": "", "LIVING": "1"}
        before = inherited.copy()
        child, _ = prepare_environment(inherited)
        actual_wrapper_environment(child, "profile", "frames", scope="root_retirement")
        self.assertEqual(inherited, before)


if __name__ == "__main__":
    unittest.main()
