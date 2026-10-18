"""Source contact, immutable programme and independent face-frame checks."""
import copy,json,sys,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools'))
from plan_v2_arcade_clock import build
class ClockPlanTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.layout=json.loads((ROOT/'art/data/building_layout.json').read_text(encoding='utf8'))
    def test_deterministic_plan_preserves_exact_five_source_boundaries(self):
        layout=copy.deepcopy(self.layout);before=copy.deepcopy(layout);a=build(layout)
        self.assertEqual(layout,before);self.assertEqual(a,build(layout));self.assertEqual(len(a['retire']),5)
        self.assertEqual({r['id'] for r in a['retire']},{'site_passage_crossing_clock_'+n for n in ['body','face_ns','face_ew','band_0','band_1']})
        self.assertEqual(len({p['id'] for p in a['parts']}),len(a['parts']))
        self.assertEqual(sum(p.get('pivot',False) for p in a['parts']),8)
    def test_changed_faces_caps_or_supports_are_refused(self):
        for identity,field in [('site_passage_crossing_clock_body','h'),('site_passage_crossing_clock_face_ns','h'),('site_passage_crossing_clock_band_1','h'),('site_crossing_clock_stem','r'),('site_crossing_clock_drop','axis')]:
            sample=copy.deepcopy(self.layout);row=next(r for f in sample['floors'] if f['id']=='F01' for r in f['furniture'] if r['id']==identity)
            if field=='axis':row['p0'][0]+=.01
            else:row[field]+=.01
            with self.subTest(identity=identity),self.assertRaises(ValueError):build(sample)
    def test_each_face_has_independent_outward_right_handed_frame(self):
        plan=build(self.layout)
        for face in plan['faces']:
            u,v,n=face['u'],face['v'],face['normal']
            cross=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
            self.assertEqual(cross,n);self.assertEqual(sum(x*x for x in u),1)
            pieces=[p for p in plan['parts'] if p.get('face')==face['id']]
            self.assertEqual(sum(p['kind']=='stroke' for p in pieces),60)
            glass=next(p for p in pieces if p['id'].endswith('_glass'));dial=next(p for p in pieces if p['id'].endswith('_dial'))
            for hand in [p for p in pieces if p['kind']=='hand']:
                self.assertGreater(hand['low'],dial['high']);self.assertLess(hand['high'],glass['low']);self.assertLess(hand['length'],dial['radius'])
            side=next(p for p in pieces if p['kind']=='square_ring');self.assertEqual(side['half_height'],.31)
    def test_every_finish_key_already_has_registered_custom_maps(self):
        catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
        for part in build(self.layout)['parts']:
            key=part['catalog_key'];self.assertIn(key,catalog);self.assertEqual(len(catalog[key]['files']),3)
            for name in catalog[key]['files']:self.assertTrue((ROOT/'game/assets/building/textures'/name).is_file())
if __name__=='__main__':unittest.main()
