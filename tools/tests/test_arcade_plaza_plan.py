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
        functions = [n for n in tree.body if isinstance(n, ast.FunctionDef)
                     and n.name in ('wall_openings', 'validate_plan')]
        namespace = {}
        exec(compile(ast.Module(body=functions, type_ignores=[]), str(SOURCE), 'exec'), namespace)
        cls.validate = staticmethod(namespace['validate_plan'])
        cls.openings = staticmethod(namespace['wall_openings'])
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

    def test_all_front_and_borrowed_optical_roles_have_real_openings(self):
        for shop in self.plan['shops']:
            front = self.openings(self.plan, shop)
            stock = self.openings(self.plan, shop, True)
            self.assertEqual([o['id'] for o in front], ['door','display','transom'])
            self.assertEqual([o['id'] for o in stock], ['door','borrowed'])
            self.assertEqual(front[0]['clear'][1]-front[0]['clear'][0], 2.0)
            self.assertEqual(stock[0]['clear'][1]-stock[0]['clear'][0], 1.0)
            self.assertTrue(all(o['glazed'] for o in front[1:]+stock[1:]))

    def test_original_eighty_mm_window_profile_conflicts_are_not_waived(self):
        self.rejected(lambda p:p.__setitem__('window_frame_m', .08))

    def test_original_news_door_position_cannot_fit_original_pane(self):
        self.rejected(lambda p:next(s for s in p['shops'] if s['id']=='shop_news_cigars')['entrance_center_m'].__setitem__(1,17.3))

    def test_transom_must_clear_new_door_header(self):
        self.rejected(lambda p:p.__setitem__('transom_clear_height_m',[2.35,2.75]))

    def test_missing_display_role_refuses(self):
        self.rejected(lambda p:p['shops'][0]['frontage'].__setitem__('display_source_ids',[]))

    def test_missing_borrowed_light_role_refuses(self):
        self.rejected(lambda p:p['shops'][0]['frontage'].__setitem__('borrowed_light_source_ids',[]))

    def test_borrowed_light_rebuild_preserves_original_clear_area(self):
        self.rejected(lambda p:p.__setitem__('borrowed_clear_height_m',[2.52,2.92]))


if __name__ == '__main__':
    unittest.main()
