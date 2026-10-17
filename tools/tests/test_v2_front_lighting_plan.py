"""Physical/program invariants for the uninstalled front-lighting batch."""
import copy
import json
import math
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from plan_v2_front_lighting import plan, wall_segments


class FrontLightingPlanTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.layout = json.loads((ROOT / 'game/data/orison_v2_blockout.json').read_text(encoding='utf-8'))
        cls.electrical = json.loads((ROOT / 'game/data/orison_v2/electrical_service.json').read_text(encoding='utf-8'))
        cls.plan = plan(cls.layout, cls.electrical)
        cls.levels = {s['id']: s['y'] for s in cls.layout['levels']}

    def test_pure_and_deterministic(self):
        before = copy.deepcopy(self.layout)
        self.assertEqual(plan(self.layout, self.electrical), self.plan)
        self.assertEqual(before, self.layout)
        self.assertEqual('NATIVE_CANDIDATE_NOT_INSTALLED', self.plan['status'])

    def test_complete_program_and_single_control(self):
        rooms = {s['id'] for s in self.layout['spaces'] if '_FRONT_' in s['id']}
        self.assertEqual(rooms, {s['room'] for s in self.plan['fixtures']})
        controls = [s['room'] for s in self.plan['switches']]
        self.assertEqual(rooms, set(controls))
        self.assertEqual(len(controls), len(set(controls)))
        identities = [s['id'] for s in self.plan['fixtures'] + self.plan['switches']]
        self.assertEqual(len(identities), len(set(identities)))

    def test_fixture_clearance_and_real_canopy_seats(self):
        spaces = {s['id']: s for s in self.layout['spaces']}
        for fixture in self.plan['fixtures']:
            x, _, z = fixture['position']
            x0, z0, x1, z1 = spaces[fixture['room']]['rect']
            self.assertGreaterEqual(min(x-x0, x1-x, z-z0, z1-z), .18, fixture['id'])
            self.assertAlmostEqual(fixture['ceiling_seat'][1], self.levels[fixture['level']] + 3)
            self.assertAlmostEqual(fixture['ceiling_seat'][1] - fixture['canopy_seat'][1], .08)

    def test_switches_have_actual_wall_bearings_outside_apertures(self):
        for switch in self.plan['switches']:
            x, y, z = switch['position']
            # Plate origin -> gasket (-8mm), surface box (40mm), then wall
            # face -> wall centre (70mm): 102mm back from the plate origin.
            back = [x + math.sin(switch['yaw']) * .102, y,
                    z + math.cos(switch['yaw']) * .102]
            matches = [w for w in wall_segments(self.layout, switch['level'])
                       if abs(back[w['axis']] - w['fixed']) < 1e-6
                       and w['low'] + .08 <= back[w['along']] <= w['high'] - .08]
            self.assertTrue(matches, switch['id'])
            for opening in self.layout['doors'] + self.layout['openings'] + self.layout['windows']:
                if opening['level'] != switch['level']:
                    continue
                axis = 0 if opening.get('axis', 'z' if abs(opening.get('yaw', 0)) > 1 else 'x') == 'z' else 2
                along = 2-axis
                center = [opening['center'][0], 0, opening['center'][1]]
                if abs(back[axis] - center[axis]) > .1:
                    continue
                if abs(back[along] - center[along]) < opening['width']/2 + .08:
                    bottom = opening.get('sill', 0)
                    self.assertFalse(bottom - .12 < y < bottom + opening['height'] + .12, switch['id'])

    def test_every_fixture_and_switch_reaches_existing_floor_junction(self):
        graph = {}
        for edge in self.plan['segments']:
            a, b = tuple(edge['a']), tuple(edge['b'])
            graph.setdefault(a, set()).add(b)
            graph.setdefault(b, set()).add(a)
        for level in ['F01', 'F02', 'F03', 'F04', 'F05', 'F06']:
            start = next(r for r in self.plan['routes'] if r['id'] == level + '_FRONT_FEED')['points'][0]
            reached, pending = set(), [tuple(start)]
            while pending:
                p = pending.pop()
                if p not in reached:
                    reached.add(p)
                    pending.extend(graph[p] - reached)
            for route in self.plan['routes']:
                if route['level'] == level:
                    self.assertIn(tuple(route['points'][-1]), reached, route['id'])
            self.assertTrue(all(abs(p[1] - self.levels[level]) < 3.01 for p in reached))

    def test_no_duplicate_overlapping_stock_or_unsplit_junctions(self):
        vertices = {tuple(p) for s in self.plan['segments'] for p in (s['a'], s['b'])}
        edges = set()
        for s in self.plan['segments']:
            a, b = s['a'], s['b']
            key = tuple(sorted((tuple(a), tuple(b))))
            self.assertNotIn(key, edges)
            edges.add(key)
            self.assertGreater(math.dist(a, b), .005)
            self.assertEqual(sum(abs(a[i]-b[i]) > 1e-6 for i in range(3)), 1)
            for p in vertices - {tuple(a), tuple(b)}:
                self.assertFalse(all(min(a[i], b[i])-1e-8 <= p[i] <= max(a[i], b[i])+1e-8 for i in range(3)), s)

    def test_ceiling_hangers_have_real_seats(self):
        for support in self.plan['supports']:
            segment = self.plan['segments'][support['segment']]
            self.assertEqual(support['seat'][1], self.levels[segment['level']] + 3)
            self.assertGreater(support['seat'][1], support['position'][1])
            self.assertEqual(support['seat'][::2], support['position'][::2])

    def test_switch_boxes_clear_panel_caps_and_picture_rails(self):
        for switch in self.plan['switches']:
            bottom=switch['position'][1]-switch['backbox_size'][1]/2
            top=switch['position'][1]+switch['backbox_size'][1]/2
            self.assertGreater(bottom,1.36+.02,switch['id'])
            self.assertLess(top,1.65-.021-.02,switch['id'])
            feed=next(r for r in self.plan['routes'] if r['id']==switch['room']+'_SWITCH_FEED')
            self.assertAlmostEqual(feed['points'][-1][1]-self.levels[switch['level']],switch['position'][1]+.08)

    def test_changed_room_program_or_ceiling_requires_review(self):
        for mutation in ('height', 'program'):
            layout = copy.deepcopy(self.layout)
            if mutation == 'height':
                layout['dimensions']['clear_height'] = 2.8
            else:
                layout['spaces'].pop(0)
            with self.assertRaises(ValueError):
                plan(layout, self.electrical)


if __name__ == '__main__':
    unittest.main()
