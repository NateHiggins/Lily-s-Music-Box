import copy,json,sys,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools'))
from plan_v2_flue_airway import plan,project


class FlueAirwayPlan(unittest.TestCase):
    def setUp(self):self.layout=json.loads((ROOT/'game/data/orison_v2_blockout.json').read_text(encoding='utf-8'))

    def test_vertical_airway_and_roof_aperture_share_exact_rect(self):
        p=plan(self.layout);b=p['riser_openings'][0]['bounds']
        self.assertEqual([b[0],b[2],b[3],b[5]],p['slab_openings'][0]['rect'])
        self.assertAlmostEqual(b[4],19.2);self.assertAlmostEqual(b[1],-3.1)

    def test_breeching_port_crosses_complete_wall_into_airway(self):
        p=plan(self.layout);air,port=[r['bounds'] for r in p['riser_openings']]
        self.assertEqual(port[0],15.05);self.assertGreater(port[3],air[0])
        self.assertLessEqual(port[2],2.15-.17);self.assertGreaterEqual(port[5],2.15+.17)

    def test_projection_preserves_every_unrelated_source_owner(self):
        before=copy.deepcopy(self.layout);proposal=plan(before);after=project(before,proposal)
        self.assertEqual(before,self.layout)
        for key in before:
            if key not in ['riser_openings','slab_openings']:self.assertEqual(after[key],before[key])
        self.assertEqual(project(after,proposal),after)

    def test_conflicting_opening_is_never_silently_overwritten(self):
        p=plan(self.layout);self.layout['riser_openings'].append(dict(p['riser_openings'][0],bounds=[0]*6))
        with self.assertRaisesRegex(ValueError,'review instead'):project(self.layout,p)

    def test_narrow_chimney_cannot_accept_current_breeching(self):
        shaft=next(r for r in self.layout['risers'] if r['id']=='B1_BOILER_FLUE');shaft['rect'][3]=2.2
        with self.assertRaisesRegex(ValueError,'cannot fit'):plan(self.layout)


if __name__=='__main__':unittest.main()
