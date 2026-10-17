import copy
import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'tools'))
from prepare_v2_heating_refit import project, revise

class HeatingRefitProjectionTests(unittest.TestCase):
    def setUp(self):
        self.plan = json.loads((ROOT/'art/data/orison_v2/heating_refit_authoring.json').read_text())
        self.layout = json.loads((ROOT/self.plan['source_layout']['path']).read_text())
        self.heat = json.loads((ROOT/'game/data/orison_v2/heating.json').read_text())
        added = {row['id'] for row in self.plan['projection']['append_installed_radiators']}
        self.heat['installed'] = [row for row in self.heat['installed'] if row['id'] not in added]

    def test_full_roster_without_changing_demand_or_threshold_authorities(self):
        before = copy.deepcopy((self.layout, self.heat))
        layout, heat = project(self.layout, self.heat, self.plan)
        self.assertEqual(before, (self.layout, self.heat))
        self.assertEqual(self.heat['network'], heat['network'])
        self.assertEqual(23, len(heat['installed']))
        self.assertEqual((layout, heat), project(layout, heat, self.plan))
        owned = set(self.plan['projection']['records'])
        for table, value in self.layout.items():
            if table not in owned: self.assertEqual(value, layout[table], table)
        for table in owned:
            after = {row['id']: row for row in layout[table]}
            for row in self.layout[table]:
                if row['id'] == 'HEAT_H-D_MAIN_CLEAR':
                    expected = copy.deepcopy(row); expected['bounds'][4] = after[row['id']]['bounds'][4]
                    self.assertEqual(expected, after[row['id']])
                else: self.assertEqual(row, after[row['id']], row['id'])
        self.assertEqual(self.heat['installed'], heat['installed'][:len(self.heat['installed'])])

    def test_refuses_foreign_identity_in_another_table(self):
        new_id = self.plan['projection']['records']['anchors'][0]['id']
        self.layout['doors'].append(dict(id=new_id))
        with self.assertRaisesRegex(ValueError, 'existing owner'): project(self.layout, self.heat, self.plan)

    def test_refuses_stale_original_thermal_demand(self):
        target = self.plan['projection']['append_installed_radiators'][0]['id']
        next(row for row in self.heat['network'] if row['id'] == target)['sections'] += 1
        with self.assertRaisesRegex(ValueError, 'original demand'): project(self.layout, self.heat, self.plan)

    def test_refuses_wall_cut_outside_actual_owner(self):
        self.plan['projection']['records']['wall_service_openings'][0]['bounds'][1] = -100
        with self.assertRaisesRegex(ValueError, 'Wall cut exceeds'): project(self.layout, self.heat, self.plan)

    def test_refuses_unbounded_main_extension(self):
        self.plan['projection']['replace_riser_openings'][0]['bounds'][4] = 100
        with self.assertRaisesRegex(ValueError, 'exceeds its shaft'): project(self.layout, self.heat, self.plan)

    def test_refuses_cross_table_projected_duplicate(self):
        self.plan['projection']['records']['anchors'][0]['id'] = self.plan['projection']['records']['riser_openings'][0]['id']
        with self.assertRaises(ValueError): project(self.layout, self.heat, self.plan)

    def test_refuses_missing_emitter_anchor(self):
        self.plan['projection']['records']['anchors'].pop()
        with self.assertRaisesRegex(ValueError, 'exactly one spatial anchor'): project(self.layout, self.heat, self.plan)

    def test_explicit_revision_preserves_unowned_records(self):
        installed, heat = project(self.layout, self.heat, self.plan)
        revised = copy.deepcopy(self.plan)
        port = revised['projection']['records']['wall_service_openings'][0]
        port['bounds'][1] += .001
        actual, actual_heat = revise(installed, heat, revised, self.plan)
        expected, expected_heat = project(self.layout, self.heat, revised)
        self.assertEqual((actual, actual_heat), (expected, expected_heat))

    def test_revision_rejects_modified_installed_owner(self):
        installed, heat = project(self.layout, self.heat, self.plan)
        identity = self.plan['projection']['records']['wall_service_openings'][0]['id']
        next(row for row in installed['wall_service_openings'] if row['id'] == identity)['bounds'][1] += .01
        with self.assertRaisesRegex(ValueError, 'Previous owned record changed'):
            revise(installed, heat, self.plan, self.plan)

    def test_revision_rejects_changed_pinned_authority(self):
        revised = copy.deepcopy(self.plan)
        revised['base_native']['sha256'] = '0'*64
        with self.assertRaisesRegex(ValueError, 'pinned authority'):
            revise(self.layout, self.heat, revised, self.plan)

if __name__ == '__main__': unittest.main()
