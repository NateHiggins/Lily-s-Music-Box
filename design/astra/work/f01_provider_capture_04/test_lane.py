import importlib.util
from pathlib import Path
import sys
import types
import unittest
sys.modules.setdefault("core", types.ModuleType("core"))
from capture_lane import classify_observations
previous = Path(__file__).resolve().parent.with_name("f01_provider_execution_07") / "test_lane.py"
spec = importlib.util.spec_from_file_location("earlier_lane_tests", previous)
prior = importlib.util.module_from_spec(spec)
sys.path.insert(0, str(previous.parent))
spec.loader.exec_module(prior)
prior.classify_observations = classify_observations
row = prior.row

class LaneTests(prior.LaneTests):
    def test_null_retirement_command_is_unknown(self):
        retired = [dict(r) for r in self.tree]
        retired[1]["CommandLine"] = None
        self.assertEqual(self.verdict(self.tree, retired), 0)
    def test_known_command_change_still_refused(self):
        altered = [dict(r) for r in self.tree]
        altered[1]["CommandLine"] = "different known command"
        self.assertEqual(self.verdict(self.tree, altered), 1)
    def test_foreign_blender_refused(self):
        self.assertEqual(self.verdict(self.tree + [row(50, 1, "blender.exe", 5)]), 1)

if __name__ == "__main__":
    unittest.main()
