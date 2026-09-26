"""Roof projection preserves lower-floor authority and both stair apertures."""
import copy
import importlib.util
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('roof_builder', ROOT / 'tools/build_v2_roof.py')
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


class RoofProjectionTest(unittest.TestCase):
    def setUp(self):
        self.layout = json.loads(builder.TARGET.read_text())
        self.source = json.loads(builder.SOURCE.read_text())

    def test_idempotent_and_preserves_unowned_records(self):
        before = copy.deepcopy(self.layout)
        before['anchors'].append({'id': 'OTHER_LANDED_WORK', 'value': [1, 2, 3]})
        result = builder.project(before, self.source)
        self.assertEqual(result, builder.project(result, self.source))
        owned = {table: {r['id'] for r in rows} for table, rows in self.source['records'].items()}
        owned.setdefault('stairs', set()).update(['PRIMARY_F06_ROOF', 'SERVICE_F06_ROOF'])
        for table, records in before.items():
            if not isinstance(records, list):
                self.assertEqual(result[table], records)
                continue
            for record in records:
                if record['id'] in owned.get(table, set()):
                    continue
                expected = copy.deepcopy(record)
                if record['id'] in ['F06_PUBLIC_CORE', 'F06_SERVICE_CORE']:
                    expected['no_ceiling'] = True
                self.assertEqual(next(r for r in result[table] if r['id'] == record['id']), expected)

    def test_deck_does_not_fill_bulkhead_stair_voids(self):
        result = builder.project(self.layout, self.source)
        rooms = [r for r in result['spaces'] if r['level'] == 'ROOF']
        for a in rooms:
            for b in rooms:
                if a['id'] == b['id']:
                    continue
                ra, rb = a['rect'], b['rect']
                area = max(0, min(ra[2], rb[2])-max(ra[0], rb[0])) * max(0, min(ra[3], rb[3])-max(ra[1], rb[1]))
                self.assertEqual(area, 0, (a['id'], b['id']))
        for core in ['PUBLIC', 'SERVICE']:
            self.assertTrue(next(r for r in rooms if r['id'] == f'ROOF_{core}_CORE')['no_floor'])
        for stair in result['stairs']:
            if stair['to'] == 'ROOF':
                self.assertAlmostEqual(stair['rise'] * stair['risers_per_flight'] * 2, 3.2)
        self.assertEqual(len([s for s in result['stairs'] if s['to'] == 'ROOF']), 2)


if __name__ == '__main__':
    unittest.main()
