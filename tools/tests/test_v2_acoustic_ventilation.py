import copy
import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'tools'))
from build_v2_acoustic_ventilation import build


class VentilationGraphTests(unittest.TestCase):
    def setUp(self):
        read = lambda p: json.loads((ROOT/p).read_text())
        self.layout = read('game/data/orison_v2_blockout.json')
        self.vent = read('game/data/orison_v2/completion_interiors.json')['ventilation']
        self.old = read('game/data/acoustic_graph.json')
        self.frame = {'origin': [0,0,-11.65], 'basis_columns': [[-1,0,0],[0,1,0],[0,0,-1]]}

    def test_register_follows_installed_stack_not_legacy_unit_letter(self):
        result = build(self.layout,self.vent,self.old,self.frame)
        nodes = {n['id']:n for n in result['nodes']}
        self.assertEqual(nodes['F02_B_BATH_VENT_REGISTER']['connections'], ['F02_V_D_RISER'])
        self.assertEqual(nodes['F05_A_BATH_VENT_REGISTER']['connections'], ['F05_V_B_RISER'])
        self.assertEqual(nodes['F02_B_BATH_VENT_REGISTER']['riser'], 'V-D')
        self.assertEqual(nodes['F05_A_BATH_VENT_REGISTER']['riser'], 'V-B')
        for node in nodes.values():
            for neighbor in node['connections']:
                self.assertEqual(node['riser'], nodes[neighbor]['riser'])

    def test_no_phantom_duct_below_physical_extent(self):
        result = build(self.layout,self.vent,self.old,self.frame)
        self.assertEqual({n['id'] for n in result['retirements']}, {'F01_V_A_RISER','F01_V_C_RISER'})
        nodes = {n['id']:n for n in result['nodes']}
        for node in nodes.values():
            for other in node['connections']:
                self.assertIn(node['id'], nodes[other]['connections'])

    def test_preserves_acoustic_tuning_and_does_not_mutate_legacy(self):
        original = copy.deepcopy(self.old)
        result = build(self.layout,self.vent,self.old,self.frame)
        old = {n['id']:n for n in self.old['nodes']}
        for node in result['nodes']:
            for key in ('delay_ms','damping','frequency_band','infection_receptivity'):
                self.assertEqual(node[key],old[node['id']][key])
        self.assertEqual(self.old,original)

    def test_declared_routes_have_axis_aligned_physical_legs(self):
        result = build(self.layout,self.vent,self.old,self.frame)
        for route in result['routes']:
            for a,b in zip(route['points_local_godot'],route['points_local_godot'][1:]):
                self.assertLessEqual(sum(abs(x-y)>.00001 for x,y in zip(a,b)),1)

    def test_cross_network_edge_cannot_silently_disappear(self):
        node = next(n for n in self.old['nodes'] if n['network']=='ventilation')
        node['connections'].append('B1_BOILER_01')
        with self.assertRaisesRegex(ValueError,'Cross-network'):
            build(self.layout,self.vent,self.old,self.frame)


if __name__ == '__main__': unittest.main()
