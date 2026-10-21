import copy,json,sys,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools'))
from build_v2_acoustic_flue import build,projection
from apply_v2_c_stove_stack import splice
from plan_v2_c_stove_stack import plan,project

class PhysicalFlue(unittest.TestCase):
    def test_shipping_projection_matches_current_sources(self):
        self.assertEqual(json.loads((ROOT/'game/data/orison_v2/acoustic_flue.json').read_bytes()),projection(ROOT))
    def setUp(self):
        self.layout=json.loads((ROOT/'game/data/orison_v2_blockout.json').read_bytes());self.layout=project(self.layout,plan(self.layout))
        self.old=json.loads((ROOT/'game/data/acoustic_graph.json').read_bytes());self.data=build(self.layout,self.old,'a'*64)
    def test_all_thirteen_original_identities_and_tuning_survive(self):
        nodes={n['id']:n for n in self.data['nodes']};old=[r for r in self.old['nodes'] if r['network']=='flue'];self.assertEqual(len(old),13)
        for row in old:
            for key in ['delay_ms','damping','frequency_band','infection_receptivity']:self.assertEqual(nodes[row['id']][key],row[key])
    def test_new_junctions_are_only_passive_transmission(self):
        passive=[r for r in self.data['nodes'] if r['id'].startswith('V2_FLUE_')];self.assertEqual(len(passive),11)
        for row in passive:self.assertTrue(row['transit_only']);self.assertEqual([row[k] for k in ['delay_ms','damping','infection_receptivity']],[0,0,0])
    def test_reciprocal_tree_routes_have_no_unmodeled_diagonal(self):
        nodes={r['id']:r for r in self.data['nodes']};seen={'B1_FLUE_BASE'}
        for _ in nodes:
            seen|={n for identity in list(seen) for n in nodes[identity]['connections'] if n in nodes}
        self.assertEqual(seen,set(nodes));self.assertEqual(len(self.data['routes']),len(nodes)-1)
        for route in self.data['routes']:
            self.assertIn(route['end'],nodes[route['start']]['connections']);self.assertIn(route['start'],nodes[route['end']]['connections'])
            for a,b in zip(route['points_local_godot'],route['points_local_godot'][1:]):self.assertLessEqual(sum(abs(x-y)>1e-6 for x,y in zip(a,b)),1)
    def test_boiler_external_authority_is_preserved(self):
        self.assertEqual(self.data['external_bridges'],[{'start':'B1_FLUE_BASE','end':'B1_BOILER_01','owner':'BoilerFlue'}])
    def test_every_carrier_names_a_current_room_or_level(self):
        rooms={r['id'] for table in ['spaces','levels'] for r in self.layout[table]}
        self.assertTrue(all(r['room'] in rooms for r in self.data['nodes']))
        self.assertEqual(next(r for r in self.data['nodes'] if r['id']=='B1_FLUE_BASE')['room'],'B1_BOILER_ROOM')
    def test_five_actual_closures_use_their_room_side_origins(self):
        closures=[r for r in self.data['nodes'] if r['physical_role']=='thimble'];self.assertEqual(len(closures),5)
        for row in closures:self.assertAlmostEqual(row['pos'][0],6.945);self.assertAlmostEqual(row['pos'][1],-10.05);self.assertEqual(row['unit'],str(int(row['id'][1:3]))+'C')
        self.assertEqual(next(r for r in closures if r['unit']=='3C')['room'],'F03_C_RESTRICTED')
    def test_slab_route_does_not_cross_stairwell_void(self):
        for route in self.data['routes']:
            if route['kind']=='structural_slab':self.assertNotIn('ROOF_SERVICE_CORE/Floor',route['owners'])
    def test_missing_or_displaced_anchor_is_not_guessed(self):
        a=next(r for r in self.layout['anchors'] if r['id']=='F02_FLUE_BREAST');a['position'][0]+=.1
        with self.assertRaisesRegex(ValueError,'Missing installed'):build(self.layout,self.old,'a'*64)
    def test_text_splice_is_byte_idempotent_for_current_layout(self):
        text=(ROOT/'game/data/orison_v2_blockout.json').read_bytes().decode();self.assertEqual(splice(text,self.layout,self.layout),text)

if __name__=='__main__':unittest.main()
