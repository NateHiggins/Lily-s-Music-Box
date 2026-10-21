import copy,json,sys,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools'))
from plan_v2_retained_grade import plan,covered,subtract

class RetainedGradePlan(unittest.TestCase):
    def setUp(self):
        self.layout=json.loads((ROOT/'game/data/orison_v2_blockout.json').read_text())
        self.previous=json.loads((ROOT/'art/data/orison_ground/retained_grade_source.json').read_text())
        self.span=next(r['bounds'] for r in self.previous['occupation_reservations'] if r['kind']=='retained_window_throat_reservation')[::3]
        self.native=dict(records=[],bindings={});self.survey=dict(failures=0,records=[])
    def build(self):return plan(self.layout,self.native,self.survey,self.previous,self.span)
    def box(self,bounds,aligned=True,kind='BoxShape3D'):
        return dict(owner='survey_test_box',shape_owner='CollisionShape3D',shape_type=kind,bounds=bounds,aligned=aligned,pose=dict(x_axis=[1,0,0],y_axis=[0,1,0],z_axis=[0,0,1]))
    def test_exact_union_coverage_and_positive_gap(self):
        b=[0,0,0,2,2,2];self.assertTrue(covered(b,[[0,0,0,1,2,2],[1,0,0,2,2,2]]))
        self.assertFalse(covered(b,[[0,0,0,1,2,2],[1.000001,0,0,2,2,2]]))
        pieces=subtract(b,[.5,.5,.5,1.5,1.5,1.5]);self.assertAlmostEqual(sum((r[3]-r[0])*(r[4]-r[1])*(r[5]-r[2]) for r in pieces),7)
    def test_current_occupied_air_proves_redundancy_even_for_rotated_box(self):
        room=next(r for r in self.layout['spaces'] if r['level']=='B1' and r['id']=='B1_LAUNDRY')
        a,b,c,d=room['rect'];x=(a+c)/2;z=(b+d)/2
        self.survey['records']=[self.box([x-.1,-2,z-.1,x+.1,-1,z+.1],False)]
        before=copy.deepcopy(self.survey);result,report=self.build()
        self.assertEqual(report['redundant_runtime_boxes'],['survey_test_box']);self.assertEqual(result['retained_solids'],[]);self.assertEqual(before,self.survey)
    def test_uncovered_aligned_box_keeps_its_exact_bounds(self):
        bounds=[1000,-1,1000,1001,-.5,1001];self.survey['records']=[self.box(bounds)]
        result,_=self.build();self.assertEqual(result['retained_solids'][0]['bounds'],bounds)
        self.assertEqual(result['retained_solids'][0]['kind'],'actual_axis_aligned_box')
    def test_uncovered_rotated_box_and_complex_aabb_are_refused(self):
        for aligned,kind,message in [(False,'BoxShape3D','Unaligned'),(True,'ConcavePolygonShape3D','Complex AABB')]:
            self.survey['records']=[self.box([1000,-1,1000,1001,-.5,1001],aligned,kind)]
            with self.subTest(kind=kind),self.assertRaisesRegex(ValueError,message):self.build()
    def test_failed_survey_and_invalid_native_source_refuse(self):
        self.survey['failures']=1
        with self.assertRaisesRegex(ValueError,'Failed'):self.build()
        self.survey['failures']=0;self.native['records']=[dict(bounds=[0,0,0,float('inf'),1,1])]
        with self.assertRaisesRegex(ValueError,'Invalid native'):self.build()
    def test_singular_claimed_basis_refuses(self):
        row=self.box([1000,-1,1000,1001,-.5,1001]);row['pose']['z_axis']=[1,0,0];self.survey['records']=[row]
        with self.assertRaisesRegex(ValueError,'Invalid claimed'):self.build()
    def test_all_current_shafts_get_explicit_construction_reservations(self):
        result,_=self.build();self.assertEqual({r['owner'] for r in result['occupation_reservations'] if r['kind']=='retained_service_or_shaft_reservation'},{r['id'] for r in self.layout['risers']})
    def test_invalid_reveal_is_not_silently_widened(self):
        self.span=[2,1]
        with self.assertRaisesRegex(ValueError,'Invalid reveal'):self.build()

if __name__=='__main__':unittest.main()
