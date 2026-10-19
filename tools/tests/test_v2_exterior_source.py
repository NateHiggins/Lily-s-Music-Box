"""Candidate frame and source mutation checks; no proof admission."""
import copy
import json
import unittest
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from v2_exterior_source import ExteriorSource, apply, add, indexed, disc_inside, polygon

ROOT = Path(__file__).resolve().parents[2]


class ExteriorFrameTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = json.loads((ROOT/'game/data/orison_v2/exterior/regions.json').read_text())
        cls.modules = json.loads((ROOT/'game/data/orison_v2/exterior/public_region_programmes.json').read_text())
        cls.layout = json.loads((ROOT/'game/data/orison_v2_blockout.json').read_text())
        cls.connection = json.loads((ROOT/'game/data/orison_v2/world_connection.json').read_text())
        cls.street_frame = json.loads((ROOT/'game/data/orison_v2/exterior/street_frame.json').read_text())

    def assertVector(self, a, b):
        for x, y in zip(a, b): self.assertAlmostEqual(x, y, places=9)

    def test_all_retained_module_frames_are_conserved(self):
        model = ExteriorSource(self.source)
        for module in self.modules['modules']:
            basis, origin = model.transform(module['instance_id'])
            body = tuple(a-b for a, b in zip(origin, apply(basis, module['source_origin_m'])))
            expected = (0., 0., 0.) if module['owner_node']=='StreetBoundaries' else (0., 0., -self.street_frame['source_threshold_z'])
            with self.subTest(module=module['instance_id']): self.assertVector(body, expected)

    def test_all_route_nodes_resolve_finitely_without_mutating_source(self):
        before = copy.deepcopy(self.source); model = ExteriorSource(self.source); count = 0
        for route in self.source['routes']:
            for node in route['nodes']:
                self.assertEqual(len(model.placement(node['owner_instance_id'], node['placement_id'])), 3); count += 1
        self.assertEqual(self.source, before); self.assertGreaterEqual(count, 40)

    def test_real_building_threshold_maps_exactly_to_public_surface(self):
        model = ExteriorSource(self.source); basis, origin = model.interior_transform(self.layout, self.connection)
        door = indexed(self.layout['doors'])[self.connection['door_id']]
        level = indexed(self.layout['levels'])[door['level']]
        threshold = (door['center'][0], level['y'], door['center'][1])
        self.assertVector(add(origin, apply(basis, threshold)), model.surface(self.connection['instance_id'], self.connection['surface_id'])['point'])
        # The current outside arrival is also a genuine interior-source apron.
        point = model.placement('STREET_ORISON_01', 'orison_exit')
        inverse = tuple(sum(basis[j][i]*(point[i]-origin[i]) for i in range(3)) for j in range(3))
        apron = indexed(self.layout['spaces'])['F01_STREET_APRON']['rect']
        self.assertTrue(apron[0]+.33<inverse[0]<apron[2]-.33 and apron[1]+.33<inverse[2]<apron[3]-.33)

    def test_duplicate_id_and_missing_owner_refuse_derivation(self):
        for change in ['duplicate', 'missing']:
            source = copy.deepcopy(self.source)
            if change=='duplicate': source['instances'].append(copy.deepcopy(source['instances'][0]))
            else: source['instances'][1]['owner_instance_id']='NO_SUCH_OWNER'
            with self.subTest(change=change), self.assertRaises((ValueError, KeyError)): ExteriorSource(source)

    def test_cycles_zero_axes_and_nonfinite_values_refuse_derivation(self):
        for change in ['cycle', 'zero_axis', 'nonfinite', 'root_shift']:
            source = copy.deepcopy(self.source)
            root = source['frame']['canonical_root_instance_id']
            child = next(r for r in source['instances'] if r['owner_instance_id'])
            if change=='cycle': child['owner_instance_id']=child['id']
            elif change=='zero_axis':
                owner = indexed(source['instances'])[child['owner_instance_id']]
                surface = next(s for t in source['surface_templates'] if t['id']==owner['template_id'] for s in t['surfaces'] if s['id']==child['owner_surface_id'])
                surface['u_axis']=[0,0,0]
            elif change=='nonfinite': child['offset_uvn_m'][0]=float('nan')
            else: indexed(source['instances'])[root]['offset_uvn_m'][0]=.01
            with self.subTest(change=change), self.assertRaises((ValueError, KeyError)): ExteriorSource(source)

    def test_private_or_unrelated_building_connection_refuses_derivation(self):
        for change in ['outside', 'inside']:
            connection = copy.deepcopy(self.connection)
            connection[change+'_space_id']='F04_B_MAIN'
            with self.subTest(change=change), self.assertRaises(ValueError): ExteriorSource(self.source).interior_transform(self.layout, connection)

    def test_concave_construction_claim_cannot_use_bounding_rectangle(self):
        boundary=indexed(self.source['regions'])['REGION_CONSTRUCTION_SEAM']['boundary']
        self.assertTrue(disc_inside(boundary,(20.5,3),.33))
        self.assertTrue(disc_inside(boundary,(24,0),.33))
        self.assertFalse(disc_inside(boundary,(20,-1),.33))

    def test_capsule_cannot_clip_the_concave_corner_or_outer_wall(self):
        boundary=indexed(self.source['regions'])['REGION_CONSTRUCTION_SEAM']['boundary']
        self.assertFalse(disc_inside(boundary,(22.7,1.9),.33))
        self.assertTrue(disc_inside(boundary,(22.9,2.1),.33))
        self.assertFalse(disc_inside(boundary,(19.2,3),.33))
        self.assertEqual(disc_inside(boundary,(24,0),.33),disc_inside(list(reversed(boundary)),(24,0),.33))

    def test_malformed_and_crossed_boundary_refuse_claims(self):
        for boundary in [[], [[0,0],[4,3],[0,5],[5,0]], [[0,0],[0,0],[1,1]], [[False,0],[1,0],[0,1]], [[float('nan'),0],[1,0],[0,1]]]:
            with self.subTest(boundary=boundary), self.assertRaises(ValueError): polygon(boundary)

    def test_every_actual_authoritative_region_is_a_valid_simple_polygon(self):
        for region in self.source['regions']:self.assertEqual(len(polygon(region['boundary'])),len(region['boundary']))


if __name__=='__main__': unittest.main()
