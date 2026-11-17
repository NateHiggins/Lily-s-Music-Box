"""Exercise the actual Blender producer's pure floor/opening admission seam."""
import ast
import copy
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'art/blender/scripts/build_arcade_plaza.py'


class ArcadePlazaPlanTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        tree = ast.parse(SOURCE.read_text(encoding='utf-8'))
        function = next(n for n in tree.body if isinstance(n, ast.FunctionDef)
                        and n.name == 'validate_plan')
        namespace = {}
        exec(compile(ast.Module(body=[function], type_ignores=[]), str(SOURCE), 'exec'), namespace)
        cls.validate = staticmethod(namespace['validate_plan'])
        cls.plan = json.loads((ROOT / 'art/data/arcade_plaza/source_plan.json').read_text(encoding='utf-8'))
        cls.legacy = json.loads((ROOT / 'art/data/building_layout.json').read_text(encoding='utf-8'))

    def rejected(self, mutate):
        plan = copy.deepcopy(self.plan)
        mutate(plan)
        with self.assertRaises((AssertionError, ValueError, TypeError)):
            self.validate(plan, self.legacy)

    def diner(self, plan):
        return next(s for s in plan['shops'] if s['id'] == 'shop_luncheonette')

    def test_complete_expanded_floor(self):
        self.assertEqual(self.validate(self.plan, self.legacy)['shops'], 11)

    def test_missing_trade(self):
        self.rejected(lambda p: p['shops'].pop())

    def test_historical_area_cannot_be_relabelled(self):
        self.rejected(lambda p: p['shops'][0].__setitem__('old_total_floor_m2', 1))

    def test_lost_stock_space(self):
        def shrink(p):
            r = p['shops'][0]['stock_rect_m']
            r[2] = r[0] + .01
        self.rejected(shrink)

    def test_public_floor_gap(self):
        self.rejected(lambda p: p['public_floor_rects_m'][0].__setitem__(0, 9.66))

    def test_public_floor_overlap(self):
        self.rejected(lambda p: p['public_floor_rects_m'].append(p['public_floor_rects_m'][0][:]))

    def test_nonfinite_opening(self):
        self.rejected(lambda p: self.diner(p).__setitem__('stock_opening_center_m', [float('nan'), 27.29]))

    def test_opening_must_stay_on_partition(self):
        self.rejected(lambda p: self.diner(p).__setitem__('stock_opening_center_m', [22.75, 27.0]))

    def test_frame_must_fit_complete_opening(self):
        def beyond(p):
            row = self.diner(p)
            cut = row['partition_rect_m']
            row['stock_opening_center_m'] = [cut[0] + .01, (cut[1] + cut[3]) / 2]
        self.rejected(beyond)

    def test_boolean_is_not_a_coordinate(self):
        self.rejected(lambda p: self.diner(p).__setitem__('stock_opening_center_m', [True, 27.29]))

    def test_old_default_remains_available(self):
        plan = copy.deepcopy(self.plan)
        for row in plan['shops']:
            row.pop('stock_opening_center_m', None)
        self.assertEqual(self.validate(plan, self.legacy)['status'], 'PASS')


if __name__ == '__main__':
    unittest.main()
