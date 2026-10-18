"""A partial native review must never overwrite the installed object family."""
import ast
import copy
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

RECIPE = Path(__file__).resolve().parents[2] / "art/blender/scripts/build_domestic_objects.py"
source = RECIPE.read_text(encoding="utf-8")
start = source.index("assert len(plan['instances'])==248")
end = source.index("rows={record['id']", start)
guard = compile(ast.parse(source[start:end]), str(RECIPE), "exec")

class BoundedNativePreflightTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.plan = {"variants": [{"id": "cloth", "kind": "blanket"}, {"id": "case", "kind": "chargingcase"}],
                     "instances": [{"id": str(i), "variant": "cloth" if i % 2 else "case"} for i in range(248)]}

    def run_guard(self, output, kinds):
        plan = copy.deepcopy(self.plan)
        with patch.dict(os.environ, {"DOMESTIC_OBJECTS_REVIEW_KINDS": kinds}):
            exec(guard, {"ROOT": self.root, "OUT": output, "plan": plan, "os": os})
        return plan

    def test_normal_export_keeps_the_complete_source(self):
        self.assertEqual(self.run_guard(self.root, ""), self.plan)

    def test_review_keeps_every_copy_of_only_the_requested_kind(self):
        result = self.run_guard(self.root / "tmp" / "review", "blanket")
        self.assertEqual(result["variants"], [self.plan["variants"][0]])
        self.assertEqual(result["instances"], [r for r in self.plan["instances"] if r["variant"] == "cloth"])

    def test_review_cannot_write_the_installation_or_a_similarly_named_directory(self):
        for output in [self.root, self.root / "game", self.root / "tmp-suffix", self.root / "tmp" / ".." / "game"]:
            with self.subTest(output=output), self.assertRaises(AssertionError):
                self.run_guard(output, "blanket")

    def test_unknown_kind_is_refused(self):
        with self.assertRaises(AssertionError):
            self.run_guard(self.root / "tmp" / "review", "blanekt")

    def test_original_family_count_remains_a_source_guard(self):
        self.plan["instances"].pop()
        with self.assertRaises(AssertionError):
            self.run_guard(self.root, "")

if __name__ == "__main__":
    unittest.main()
