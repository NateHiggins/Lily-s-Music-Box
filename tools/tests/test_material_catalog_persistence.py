"""Regenerating layout must preserve every registered physical finish."""
import ast
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class MaterialCatalogPersistenceTest(unittest.TestCase):
    def test_registered_catalog_survives_regeneration(self):
        # Read the source assignment without executing gen_layout's world-data
        # writer. This exercises the actual catalogue that writer serializes.
        tree = ast.parse((ROOT / 'art/data/gen_layout.py').read_text(encoding='utf-8'))
        declarations = [node.value for node in tree.body if isinstance(node, ast.Assign)
                        and any(isinstance(target, ast.Name) and target.id == 'MATERIAL_CATALOG'
                                for target in node.targets)]
        self.assertEqual(len(declarations), 1)
        keys = [ast.literal_eval(key) for key in declarations[0].keys]
        self.assertEqual(len(keys), len(set(keys)), 'Duplicate finish silently shadows its earlier definition')
        generated = ast.literal_eval(declarations[0])
        registered = json.loads((ROOT / 'art/data/material_catalog.json').read_text(encoding='utf-8'))
        self.assertEqual(generated, registered,
                         'gen_layout would retire or alter registered finishes; update its source catalogue too')


if __name__ == '__main__':
    unittest.main()
