"""Keep the independent upper daylight fixture tied to its original authoring source."""
import ast
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = "design/astra/work/v2_upper_floors_01/build.py"
FIXTURE = "game/tests/data/v2_upper_daylight_contract.json"


class UpperDaylightContractTests(unittest.TestCase):
    def test_profiles_match_original_builder_literal(self):
        fixture = json.loads((ROOT / FIXTURE).read_text(encoding="utf-8"))
        self.assertEqual(fixture["schema_version"], 1)
        self.assertEqual(fixture["source_builder"], SOURCE)
        self.assertEqual(fixture["source_symbol"], "WINDOWS")
        tree = ast.parse((ROOT / SOURCE).read_text(encoding="utf-8"))
        declarations = [node for node in tree.body if isinstance(node, ast.Assign)
                        and any(isinstance(target, ast.Name) and target.id == "WINDOWS"
                                for target in node.targets)]
        self.assertEqual(len(declarations), 1)
        profiles = ast.literal_eval(declarations[0].value)
        expected = {letter: [{"room_suffix": room, "center": center, "axis": axis}
                             for room, center, axis in rows]
                    for letter, rows in profiles.items()}
        self.assertEqual(fixture["profiles"], expected)


if __name__ == "__main__":
    unittest.main()
