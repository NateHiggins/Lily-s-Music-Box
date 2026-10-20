import copy
import json
import sys
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from build_v2_acoustic_heating import projection,build,AUTHORED,BINDINGS


class HeatingAcoustics(unittest.TestCase):
    def setUp(self):
        read=lambda p:json.loads((ROOT/p).read_text(encoding='utf-8'))
        self.args=[read(BINDINGS[1]),read(BINDINGS[2]),read(BINDINGS[0]),*[read(p) for p in AUTHORED]]
        self.result=build(*self.args)
        self.nodes={n['id']:n for n in self.result['nodes']}

    def test_all_legacy_identities_and_tuning_survive(self):
        old=[n for n in self.args[2]['nodes'] if n['network']=='heating']
        self.assertEqual(len(old),26)
        for row in old:
            for key in ['delay_ms','damping','frequency_band','infection_receptivity']:
                self.assertEqual(self.nodes[row['id']][key],row[key])

    def test_emitters_are_parallel_leaves_instead_of_serial_transit(self):
        for radiator in self.args[1]['installed']:
            peers=[n for n in self.nodes[radiator['id']]['connections'] if n in self.nodes]
            self.assertEqual(len(peers),1)
            self.assertTrue(peers[0].startswith('V2_HEAT_TAP_'))
        self.assertEqual(len(self.nodes),53)
        self.assertEqual(len(self.result['routes']),52)

    def test_new_junctions_do_not_multiply_authored_loss_or_delay(self):
        for identity,row in self.nodes.items():
            if identity.startswith('V2_HEAT_'):
                self.assertEqual([row[k] for k in ['delay_ms','damping','infection_receptivity']],[0,0,0])

    def test_boiler_can_reach_every_heating_node_without_other_networks(self):
        visited=set();queue=['B1_BOILER_01']
        while queue:
            identity=queue.pop()
            if identity in visited:continue
            visited.add(identity)
            queue.extend(n for n in self.nodes[identity]['connections'] if n in self.nodes)
        self.assertEqual(visited,set(self.nodes))
        for route in self.result['routes']:
            self.assertIn(route['end'],self.nodes[route['start']]['connections'])
            self.assertIn(route['start'],self.nodes[route['end']]['connections'])

    def test_external_bridges_preserve_exact_authored_direction(self):
        old={n['id']:n for n in self.args[2]['nodes'] if n['network']=='heating'}
        expected={(n['id'],t) for n in old.values() for t in n['connections'] if t not in old}
        actual={(n['id'],t) for n in self.nodes.values() for t in n['connections'] if t not in self.nodes}
        self.assertEqual(actual,expected)

    def test_moved_supply_stub_requires_new_fabrication(self):
        self.args[3]['branches'][0]['points_local_godot'][-1][0]+=.02
        with self.assertRaisesRegex(ValueError,'actual radiator stub'):build(*self.args)

    def test_lobby_takeoff_cannot_float_off_parent_pipe(self):
        self.args[4]['join_local_godot'][2]+=.02
        with self.assertRaisesRegex(ValueError,'parent supply'):build(*self.args)

    def test_every_installed_emitter_requires_an_actual_native_route(self):
        self.args[5]['routes']['branches'].pop()
        with self.assertRaisesRegex(ValueError,'every installed radiator'):build(*self.args)

    def test_source_inputs_are_not_modified(self):
        before=copy.deepcopy(self.args);build(*self.args);self.assertEqual(before,self.args)

    def test_boiler_is_grounded_and_projection_is_reproducible(self):
        self.assertEqual(self.nodes['B1_BOILER_01']['pos'],[12.45,.5,-3.2])
        saved=json.loads((ROOT/'game/data/orison_v2/acoustic_heating.json').read_text(encoding='utf-8'))
        self.assertEqual(saved,projection())


if __name__=='__main__':unittest.main()
