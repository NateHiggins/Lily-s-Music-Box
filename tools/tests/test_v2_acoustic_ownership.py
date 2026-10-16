import sys
import unittest
import hashlib
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from audit_v2_acoustic_ownership import ownership, observation_errors, region_markers, fitted_layout


class AcousticOwnershipTests(unittest.TestCase):
    def setUp(self):
        self.anchor = {'id': 'A', 'level': 'F02', 'position': [2, .6, -4],
                       'kind': 'fixture', 'space': 'ROOM'}
        self.layout = {'levels': [{'id': 'F02', 'y': 3.2}], 'anchors': [self.anchor]}
        self.graph = {'nodes': [{'id': 'A', 'network': 'heating', 'pos': [9, 9, 9], 'connections': []}]}

    def test_level_relative_coordinates_and_blender_axis(self):
        observed = {'interior_frame': {'origin': [0, 0, -11.65], 'basis_columns': [[-1,0,0],[0,1,0],[0,0,-1]]}}
        row = ownership(self.layout, self.graph, observed)['nodes'][0]
        self.assertEqual(row['position_local_godot'], [2, 3.8000000000000003, -4])
        self.assertEqual(row['position_world_blender'], [-2, 7.65, 3.8000000000000003])

    def test_duplicate_owner_cannot_choose_first(self):
        self.layout['anchors'].append(dict(self.anchor))
        row = ownership(self.layout, self.graph)['nodes'][0]
        self.assertEqual(row['status'], 'AMBIGUOUS')
        self.assertNotIn('position_blender', row)

    def test_nearby_different_identity_is_not_a_match(self):
        self.anchor['id'] = 'B'
        row = ownership(self.layout, self.graph)['nodes'][0]
        self.assertEqual(row['status'], 'UNRESOLVED')

    def test_runtime_disagreement_is_not_silently_accepted(self):
        observed = {'interior_frame': {'origin': [0,0,0], 'basis_columns': [[1,0,0],[0,1,0],[0,0,1]]},
                    'nodes': [{'id': 'A', 'named_owners': [{'position_godot': [2, 8, -4]}]}]}
        row = ownership(self.layout, self.graph, observed)['nodes'][0]
        self.assertEqual(row['status'], 'SOURCE_RUNTIME_DISAGREEMENT')

    def test_missing_frame_does_not_compare_different_coordinate_systems(self):
        observed = {'nodes': [{'id': 'A', 'named_owners': [{'position_godot': [-2, 3.8, -7.65]}]}]}
        row = ownership(self.layout, self.graph, observed)['nodes'][0]
        self.assertNotIn('observed_position_delta_m', row)

    def test_broken_legacy_edge_remains_visible(self):
        self.graph['nodes'][0]['connections'] = ['MISSING']
        self.assertEqual(ownership(self.layout, self.graph)['legacy_missing_targets'], [['A', 'MISSING']])

    def test_terminal_offset_uses_support_rotation(self):
        self.layout['anchors'].append({'id': 'DESK', 'yaw': 1.5707963267948966})
        fit = {'id': 'A', 'support': 'DESK', 'offset': [.075, 0, 0]}
        row = ownership(self.layout, self.graph, terminal_fit=fit)['nodes'][0]
        self.assertAlmostEqual(row['fitted_position_local_godot'][2], -4.075)
        self.assertEqual(row['status'], 'EXPLICIT_FITTED_OWNER')

    def test_boiler_uses_level_not_inspection_height(self):
        self.anchor['id'] = self.graph['nodes'][0]['id'] = 'B1_BOILER_01'
        row = ownership(self.layout, self.graph, fitted_boiler=True)['nodes'][0]
        self.assertEqual(row['fitted_position_local_godot'][1], 3.2)

    def test_observation_provenance_refuses_stale_runtime_or_source(self):
        obs = {'observer_sha256': hashlib.sha256(b'script').hexdigest(),
               'legacy_graph_sha256': hashlib.sha256(b'graph').hexdigest(),
               'graph_restored_exactly': True, 'interior_frame': {'origin': [0,0,0]}}
        receipt = {'evidence_kind': 'suite_run', 'execution': {'completed': True, 'exit_code': 0, 'timed_out': False},
                   'source': {'runtime_inputs_sha256': 'current'}, 'log': {'script_error_count': 0}}
        self.assertEqual(observation_errors(obs, receipt, b'script', b'graph', 'current'), [])
        self.assertIn('observed production inputs are stale', observation_errors(obs, receipt, b'script', b'graph', 'new'))
        self.assertIn('observer source changed', observation_errors(obs, receipt, b'edited', b'graph', 'current'))

    def test_failed_observer_cannot_supply_positions(self):
        errors = observation_errors({}, {'execution': {'completed': False}}, b'', b'', 'current')
        self.assertIn('observer did not complete successfully', errors)
        self.assertIn('shared graph restoration was not confirmed', errors)

    def test_attachment_respects_support_frame_without_changing_source(self):
        self.anchor['id'] = 'DESK'
        self.anchor['yaw'] = 1.5707963267948966
        attached = [{'id': 'A', 'support': 'DESK', 'position': [1,.2,0], 'source': 'fixture.json'}]
        row = ownership(self.layout, self.graph, attachments=attached)['nodes'][0]
        self.assertEqual(row['status'], 'EXPLICIT_ATTACHMENT')
        self.assertAlmostEqual(row['position_local_godot'][2], -5)
        self.assertAlmostEqual(row['position_local_godot'][1], 4)
        self.assertEqual(len(self.layout['anchors']), 1)

    def test_missing_attachment_support_stays_unresolved(self):
        self.layout['anchors'] = []
        attached = [{'id': 'A', 'support': 'MISSING', 'position': [0,0,0], 'source': 'fixture.json'}]
        self.assertEqual(ownership(self.layout, self.graph, attachments=attached)['nodes'][0]['status'], 'UNRESOLVED')

    def test_regions_use_different_authored_datums_and_registered_owners(self):
        markers = [{'id': 'F01_DOOR_06', 'kind': 'door', 'pos': [1,10,2], 'w': 2, 'yaw_deg': 0},
                   {'id': 'P', 'kind': 'cage_bulb', 'zone': 'PASSAGE', 'pos': [4,12,5]},
                   {'id': 'B', 'kind': 'speaker', 'pos': [4,12,5]},
                   {'id': 'FOREIGN', 'kind': 'speaker', 'pos': [4,12,5]}]
        registry = {'cells': [{'id': 'CELL_SHOP_BAR', 'semantic_owners': ['B']}]}
        rows = region_markers({'floors': [{'id': 'F01', 'markers': markers}]}, registry, {'source_threshold_z': -10})
        self.assertEqual(rows['P'][0]['position_world_godot'], [2,3,-2])
        self.assertEqual(rows['B'][0]['position_world_godot'], [4,5,-2])
        self.assertNotIn('FOREIGN', rows)

    def test_facade_refuses_unaligned_seats(self):
        layout = {'anchors': [], 'levels': [{'id': 'B1', 'y': -3.2}, {'id': 'F01', 'y': 0}],
                  'doors': [{'id': 'F01_DOOR_06', 'width': 1, 'center': [0,-10]}],
                  'dimensions': {'outer_wall': .3, 'partition_wall': .2},
                  'spaces': [{'level': 'F02', 'rect': [-4,-10,-2,-8]},
                             {'level': 'F03', 'rect': [-4,-10,-3,-8]}]}
        retained = {'floors': [{'id': 'F01', 'markers': [{'id': 'F01_NEON_BLADE', 'pos': [1,2,3]}]}]}
        with self.assertRaisesRegex(ValueError, 'seats disagree'):
            fitted_layout(layout, retained, {'assemblies': [], 'floor_y': -3.2})

    def test_region_and_anchor_collision_is_ambiguous(self):
        row = ownership(self.layout, self.graph, regions={'A': [{'position_world_godot': [0,0,0]}]})['nodes'][0]
        self.assertEqual(row['status'], 'AMBIGUOUS')


if __name__ == '__main__':
    unittest.main()
