import copy,json,sys,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'art/blender/scripts'))
from city_closure_source import check_registered_layout, v2_layout, shell_projection, city_group
class ConsumedCitySourceTest(unittest.TestCase):
    def setUp(self):
        self.layout=json.loads((ROOT/'art/data/building_layout.json').read_text())
        self.proof=json.loads((ROOT/'art/blender/city_shells_consumed_layout.json').read_text())
        self.registration=json.loads((ROOT/'art/blender/city_shells_registration.json').read_text())
        self.plan=json.loads((ROOT/'art/data/city_elevations/source_plan.json').read_text())
    def test_current_and_editorial_copy_keep_registered_geometry(self):
        check_registered_layout(self.layout,self.proof,self.registration,self.plan)
        self.layout['editorial_note']='Changed story copy'
        check_registered_layout(self.layout,self.proof,self.registration,self.plan)
    def test_physical_dimensions_material_or_identity_cannot_reuse_library(self):
        for field in ['rect','h','mat','id']:
            layout=copy.deepcopy(self.layout)
            floor=next(row for row in layout['floors'] if row['id']=='F01')
            row=next(row for row in floor['furniture'] if row['id']==self.proof['records'][0]['id'])
            if field=='rect':row['rect'][0]+=.01
            elif field=='h':row['h']+=.01
            else:row[field]+='_changed'
            with self.subTest(field=field),self.assertRaises(AssertionError):check_registered_layout(layout,self.proof,self.registration,self.plan)
    def test_projection_cannot_attach_to_a_different_source_or_native(self):
        for field in ['layout_sha256','native_sha256']:
            proof=copy.deepcopy(self.proof);proof[field]='0'*64
            with self.subTest(field=field),self.assertRaises(AssertionError):check_registered_layout(self.layout,proof,self.registration,self.plan)
    def test_height_projection_preserves_other_buildings_and_roof_equipment_dimensions(self):
        before=copy.deepcopy(self.layout)
        result=v2_layout(self.layout,self.plan)
        self.assertEqual(self.layout,before)
        source={r['id']:r for r in next(f for f in before['floors'] if f['id']=='F01')['furniture']}
        rows=next(f for f in result['floors'] if f['id']=='F01')['furniture']
        projected={r['id'] for r in self.plan['buildings'] if 'vertical_profile' in r}
        changed=0;equipment=0
        for row in rows:
            old=source[row['id']]
            if city_group(row['id']) not in projected:
                self.assertEqual(old,row);continue
            changed+=old!=row
            if row.get('asm')=='pipe':
                equipment+=1
                self.assertEqual(row['r'],old['r'])
                for axis in range(3):
                    self.assertAlmostEqual(row['p1'][axis]-row['p0'][axis],old['p1'][axis]-old['p0'][axis])
            if 'rect' in row:self.assertEqual(row['rect'],old['rect'])
        self.assertGreater(changed,20);self.assertGreater(equipment,10)
    def test_bad_or_changed_height_program_cannot_reuse_native(self):
        for value in [float('nan'),0.,3.6]:
            plan=copy.deepcopy(self.plan)
            next(r for r in plan['buildings'] if r['id']=='site_far_n')['vertical_profile'][-1]=value
            with self.subTest(value=value),self.assertRaises(AssertionError):v2_layout(self.layout,plan)
        projected={'source_records':shell_projection(self.layout),'records':shell_projection(v2_layout(self.layout,self.plan)),
                   'layout_sha256':self.proof['layout_sha256'],'native_sha256':self.proof['native_sha256']}
        plan=copy.deepcopy(self.plan)
        next(r for r in plan['buildings'] if r['id']=='site_far_n')['vertical_profile'][-1]+=.1
        with self.assertRaises(AssertionError):check_registered_layout(self.layout,projected,self.registration,plan)
class ArticulatedElevationProbes(unittest.TestCase):
    @staticmethod
    def module():
        sys.path.insert(0,str(ROOT/'tools'))
        import city_elevation_probe_fixture
        return city_elevation_probe_fixture

    def test_frozen_native_targets_remain_reproducible_and_complete(self):
        m=self.module()
        self.assertEqual(json.loads(m.OUTPUT.read_text()),m.build())

    def test_articulated_plane_is_not_the_old_envelope_or_a_missing_face(self):
        m=self.module();np=m.np
        faces=np.array([[[-1,0,0],[1,0,0],[1,2,0]],[[-1,0,0],[1,2,0],[-1,2,0]]],dtype=float)
        normal=np.array([0,0,1]);seed=np.array([-.88,1,.2])
        target=m.target_at_height(faces,1.,seed,normal)
        self.assertEqual(float(target[2]),0.)
        self.assertAlmostEqual(m.first_hit(faces,target,normal),.04)
        self.assertAlmostEqual(m.first_hit(faces,target+normal*.01,normal),.05)
        with self.assertRaises(ValueError):m.target_at_height(faces,3.,seed,normal)
        with self.assertRaises(ValueError):m.target_at_height(faces[:,::-1],1.,seed,normal)

    def test_source_face_hidden_by_trim_is_not_admitted(self):
        m=self.module();np=m.np
        face=np.array([[[-1,0,0],[1,0,0],[1,2,0]],[[-1,0,0],[1,2,0],[-1,2,0]]],dtype=float)
        covered=np.concatenate([face,face+np.array([0,0,.02])])
        target=m.target_at_height(covered,1.,np.array([-.88,1,.2]),np.array([0,0,1]))
        self.assertAlmostEqual(float(target[2]),.02)
        with self.assertRaises(ValueError):
            m.target_at_height(covered,1.,np.array([-.88,1,.2]),np.array([0,0,1]),np.array([True,True,False,False]))

if __name__=='__main__':unittest.main()
