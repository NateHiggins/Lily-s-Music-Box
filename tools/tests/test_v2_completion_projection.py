"""New construction preserves other owners and keeps the lift well open."""
import copy
import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from build_v2_vertical_services import project
from build_v2_roof import project as roof_project


class CompletionProjectionTest(unittest.TestCase):
    def test_owners_preserve_each_others_projection_freshness(self):
        layout = json.loads((ROOT / 'game/data/orison_v2_blockout.json').read_text())
        roof = json.loads((ROOT / 'art/data/orison_v2/roof_source.json').read_text())
        services = json.loads((ROOT / 'art/data/orison_v2/vertical_services_source.json').read_text())
        homes = json.loads((ROOT / 'art/data/orison_v2/completion_interiors_source.json').read_text())
        candidate = project(project(roof_project(layout, roof), services), homes)
        self.assertEqual(candidate, roof_project(candidate, roof))
        self.assertEqual(candidate, project(candidate, services))
        self.assertEqual(candidate, project(candidate, homes))

    def test_projection_preserves_unowned_records(self):
        layout = json.loads((ROOT / 'game/data/orison_v2_blockout.json').read_text())
        for name in ['vertical_services', 'completion_interiors']:
            source = json.loads((ROOT / f'art/data/orison_v2/{name}_source.json').read_text())
            before = copy.deepcopy(layout)
            before['anchors'].append({'id': 'OTHER_OWNER', 'position': [123, 4, 5]})
            result = project(before, source)
            self.assertEqual(result, project(result, source))
            for table, additions in source['records'].items():
                owned = {r['id'] for r in additions}
                self.assertEqual(len(owned), len(additions))
                self.assertEqual([r for r in before[table] if r['id'] not in owned],
                                 [r for r in result[table] if r['id'] not in owned])

    def test_passenger_well_has_no_landing_slab(self):
        source = json.loads((ROOT / 'art/data/orison_v2/vertical_services_source.json').read_text())
        for platform in source['records']['platforms']:
            rect = platform['rect']
            overlap_x = max(0, min(rect[2], 1.2) - max(rect[0], -1.2))
            overlap_z = max(0, min(rect[3], -.3) - max(rect[1], -2.8))
            self.assertEqual(overlap_x * overlap_z, 0, platform['id'])

    def test_all_consumers_have_authored_anchors(self):
        source = json.loads((ROOT / 'art/data/orison_v2/completion_interiors_source.json').read_text())
        anchors = {r['id'] for r in source['records']['anchors']}
        consumers = source['consumers']
        for record in consumers['fittings'] + consumers['furniture'] + consumers['lighting']['fixtures'] + consumers['lighting']['switches']:
            self.assertIn(record['id'], anchors)
        doors = {r['id'] for r in source['records']['doors']}
        self.assertEqual(doors, {r['id'] for r in consumers['doors']})


if __name__ == '__main__':
    unittest.main()
