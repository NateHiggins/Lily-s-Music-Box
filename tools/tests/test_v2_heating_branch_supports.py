import sys
import unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from build_v2_heating_branch_supports import build


class BranchSupportTests(unittest.TestCase):
    def fixture(self):
        layout={'spaces':[{'id':'ROOM','level':'F01','rect':[0,0,4,2]}],
                'risers':[{'id':'HEAT_STACK','rect':[5,5,6,6]}], 'slab_openings':[]}
        routes={'branches':[{'id':'PIPE','level':'F01','riser':'H-A',
                             'points_local_godot':[[.2,-.13,1],[3.8,-.07,1],[3.8,0,1]]}]}
        return layout,routes

    def test_hangers_follow_pitched_pipe_and_end_below_floor(self):
        layout,routes=self.fixture();result=build(layout,routes)
        self.assertFalse(result['unserved_straights'])
        self.assertGreater(len(result['supports']),1)
        for hanger in result['supports']:
            self.assertEqual(hanger['floor_owners'],['ROOM'])
            self.assertEqual(hanger['stem_top_y'],-.008)
            self.assertGreater(hanger['stem_top_y'],hanger['stem_bottom_y'])
            self.assertGreater(hanger['tangent'][1],0)

    def test_platform_is_an_explicit_floor_owner(self):
        layout,routes=self.fixture();layout['platforms']=layout.pop('spaces');layout['spaces']=[]
        self.assertTrue(build(layout,routes)['supports'])

    def test_opening_cannot_supply_a_hanger_bearing(self):
        layout,routes=self.fixture()
        layout['slab_openings']=[{'space':'ROOM','surface':'Floor','rect':[0,0,4,2]}]
        result=build(layout,routes)
        self.assertFalse(result['supports'])
        self.assertTrue(result['unserved_straights'])


if __name__=='__main__':unittest.main()
