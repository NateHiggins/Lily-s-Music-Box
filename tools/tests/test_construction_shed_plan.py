"""Construction joinery must preserve source authorities and actual bearings."""
from pathlib import Path
import copy,json,sys,tempfile,unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from plan_v2_construction_shed import build,contact_patches,ROOT,RUNTIME

class ShedPlanTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.plan=build()
    def test_existing_collisions_and_lights_retained_exactly(self):
        source=json.loads((ROOT/RUNTIME).read_text())
        self.assertEqual(self.plan['retained_actors'],source['boxes'])
        self.assertEqual(self.plan['retained_lights'],source['lights'])
    def test_lapped_stock_has_remaining_contact_after_all_cuts(self):
        rows={p['id']:p for p in self.plan['parts']};count=0
        for joint in self.plan['joints']:
            if joint['kind']=='complementary_half_lap':negative,positive=rows[joint['beam']],rows[joint['post']]
            elif joint['kind']=='beam_cross_lap':negative,positive=rows[joint['lower']],rows[joint['upper']]
            else:continue
            args=(joint['plane_axis'],joint['plane_m'],joint['overlap'])
            patches=contact_patches(negative,positive,*args)
            # Crossing beams have small surviving shoulders beside the post
            # laps; the post joints retain at least 7000 mm2 of contact.
            minimum=.0003 if joint['kind']=='beam_cross_lap' else .006
            self.assertGreater(sum(area for area,_ in patches),minimum)
            displaced=copy.deepcopy(positive);displaced['center_m'][joint['plane_axis']]+=.01
            for cut in displaced['cuts']:
                for edge in ['low','high']:cut[edge][joint['plane_axis']]+=.01
            self.assertEqual(contact_patches(negative,displaced,*args),[])
            count+=1
        self.assertGreater(count,5)
    def test_unique_parts_and_positive_sized_stock(self):
        parts=self.plan['parts'];self.assertEqual(len(parts),len({p['id'] for p in parts}))
        for part in parts:
            if part['kind']=='box':self.assertGreater(min(part['size_m']),0)
            if part['kind']=='bolt':self.assertLess(*part['bearing_offsets_m'])
    def test_changed_source_stock_requires_a_new_recipe(self):
        from plan_v2_construction_shed import SOURCE
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary)
            for name in [SOURCE,RUNTIME]:
                document=json.loads((ROOT/name).read_text(encoding='utf8'))
                document['boxes'][0]['material']='brick'
                target=root/name;target.parent.mkdir(parents=True,exist_ok=True)
                target.write_text(json.dumps(document),encoding='utf8')
            with self.assertRaisesRegex(ValueError,'source stock requires a new native recipe'):build(root)

if __name__=='__main__':unittest.main()
