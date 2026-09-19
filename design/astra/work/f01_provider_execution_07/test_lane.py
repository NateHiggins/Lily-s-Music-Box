import sys
import types
import unittest
sys.modules.setdefault("core", types.ModuleType("core"))
from lane import classify_observations

def row(pid, parent, name, born, command="test"):
    return {"ProcessId": pid, "ParentProcessId": parent, "Name": name,
            "CreatedUtc": "2026-09-06T00:00:%02d.0000000Z" % born, "CommandLine": command}

class LaneTests(unittest.TestCase):
    def setUp(self):
        self.tree = [row(10, 1, "pwsh.exe", 1), row(11, 10, "Godot_v4.7.1-stable_win64_console.exe", 2),
                     row(12, 11, "Godot_v4.7.1-stable_win64.exe", 3)]
    def verdict(self, *samples):
        return classify_observations([{"processes": sample} for sample in samples], 10)["contract_exit"]
    def test_owned_engine(self):
        self.assertEqual(self.verdict(self.tree), 0)
    def test_unrelated_pid_reuse(self):
        self.assertEqual(self.verdict(self.tree + [row(20, 1, "pwsh.exe", 4)],
                                     self.tree + [row(20, 2, "pwsh.exe", 8, "another")]), 0)
    def test_foreign_engine(self):
        self.assertEqual(self.verdict(self.tree + [row(30, 1, "Godot.exe", 5)]), 1)
    def test_same_lifetime_conflict(self):
        changed = [dict(r) for r in self.tree]
        changed[-1]["ParentProcessId"] = 1
        self.assertEqual(self.verdict(self.tree, changed), 1)
    def test_later_parent_reuse_does_not_steal_child(self):
        self.assertEqual(self.verdict(self.tree, [row(11, 1, "pwsh.exe", 8)]), 0)
    def test_new_engine_under_reused_parent_is_foreign(self):
        self.assertEqual(self.verdict(self.tree, [row(11, 1, "pwsh.exe", 8), row(30, 11, "Godot.exe", 9)]), 1)
    def test_missing_lifetime_refused(self):
        broken = [dict(r) for r in self.tree]
        broken[0].pop("CreatedUtc")
        self.assertEqual(self.verdict(broken), 1)

if __name__ == "__main__":
    unittest.main()
