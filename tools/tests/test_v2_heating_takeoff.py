import copy
import json
import math
from pathlib import Path
import sys
import unittest

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from plan_v2_heating_takeoff import plan


class TakeoffTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.layout=json.loads((ROOT/'game/data/orison_v2_blockout.json').read_text())
        cls.routes=json.loads((ROOT/'art/blender/heating_distribution/heating_routes_exact.json').read_text())

    def test_real_source_socket_is_perpendicular_and_drains_to_supply(self):
        result=plan(self.layout,self.routes)
        u,v=result['main_axis_local_godot'],result['outlet_axis_local_godot']
        self.assertAlmostEqual(sum(x*y for x,y in zip(u,v)),0,places=10)
        self.assertGreater(result['floor_clearance_m'],.035)
        points=result['child']['points_local_godot']
        self.assertTrue(all(b[1]>a[1] for a,b in zip(points,points[1:])))
        self.assertEqual(points[-1][1],0)
        self.assertAlmostEqual(math.dist(result['join_local_godot'],points[0]),.06)
        socket=result['socket']
        self.assertGreater(socket['branch_outer_radius_m'],socket['receiving_radius_m']+.004)
        self.assertGreater(socket['flow_radius_m']+socket['main_flow_relief_m'],socket['flow_radius_m'])

    def test_parent_remains_continuous_through_the_fitting_gap(self):
        result=plan(self.layout,self.routes)
        parent=next(r for r in self.routes['branches'] if r['id']==result['parent_branch'])
        original=parent['points_local_godot']
        self.assertEqual(result['parent_before'][0],original[0])
        self.assertEqual(result['parent_after'][-1],original[-1])
        length=lambda p:sum(math.dist(a,b) for a,b in zip(p,p[1:]))
        self.assertAlmostEqual(length(original),length(result['parent_before'])+
                               length(result['parent_after'])+.09,places=10)
        self.assertEqual(result['child']['parent_branch'],parent['id'])

    def test_join_outside_retained_straight_is_rejected(self):
        with self.assertRaisesRegex(ValueError,'outside'):
            plan(self.layout,self.routes,join_x=-99)

    def test_reverse_pitch_is_rejected(self):
        routes=copy.deepcopy(self.routes)
        parent=next(r for r in routes['branches'] if r['id']=='F01_A_RADIATOR_01')
        parent['points_local_godot'][2][1]=parent['points_local_godot'][1][1]-.02
        with self.assertRaisesRegex(ValueError,'Condensate'):
            plan(self.layout,routes)

    def test_missing_lobby_floor_is_rejected(self):
        layout=copy.deepcopy(self.layout)
        layout['spaces']=[s for s in layout['spaces'] if s['id']!='F01_LOBBY']
        with self.assertRaisesRegex(ValueError,'floor envelope'):
            plan(layout,self.routes)

    def test_nonfinite_source_cannot_generate_a_candidate(self):
        routes=copy.deepcopy(self.routes)
        parent=next(r for r in routes['branches'] if r['id']=='F01_A_RADIATOR_01')
        parent['points_local_godot'][1][1]=float('nan')
        with self.assertRaisesRegex(ValueError,'Finite'):
            plan(self.layout,routes)

    def test_source_anchor_controls_the_floor_stub(self):
        layout=copy.deepcopy(self.layout)
        anchor=next(a for a in layout['anchors'] if a['id']=='F01_LOBBY_RADIATOR_01')
        anchor['position'][0]+=.1
        result=plan(layout,self.routes)
        self.assertAlmostEqual(result['child']['points_local_godot'][-1][0],anchor['position'][0])


if __name__=='__main__':unittest.main()
