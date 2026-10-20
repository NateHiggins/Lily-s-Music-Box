import copy,json,sys,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools'))
from plan_v2_front_trim import plan,merge,validate_source

class FrontTrimTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.layout=json.loads((ROOT/'game/data/orison_v2_blockout.json').read_text())
        cls.snapshot=json.loads((ROOT/'art/data/orison_v2/front_trim_layout_source.json').read_text())
    def build(self,snapshot=None):return plan(self.layout,snapshot or self.snapshot,'asset','profile')
    def test_pure_deterministic_complete_owner_projection(self):
        before=copy.deepcopy(self.snapshot);result=self.build()
        self.assertEqual(before,self.snapshot);self.assertEqual(result,self.build())
        self.assertEqual(sum(r['variant']=='rail' for r in result['fittings']),0)
        self.assertEqual(sum(r['variant']=='cornice' for r in result['fittings']),22)
        anchors={r['id'] for r in self.layout['anchors']};ports={r['id'] for r in self.layout['wall_service_openings']}
        self.assertTrue(all(r['owner'] in anchors|ports for r in result['fittings']))
    def test_only_real_bounded_source_instances_are_cut(self):
        source={(r['room'],r['index']):r for r in self.snapshot['records']}
        for room in self.build()['rooms']:
            for cut in room['cuts']:
                self.assertEqual(cut['source'],source[(room['room'],cut['index'])]['source'])
                self.assertTrue(all(-.500001<=lo<hi<=.500001 for lo,hi in cut['intervals']))
                self.assertTrue(all(a[1]<b[0] for a,b in zip(cut['intervals'],cut['intervals'][1:])))
    def test_missing_or_duplicate_geometry_refuses_projection(self):
        for change in ['missing','duplicate','zero_basis','nonfinite']:
            sample=copy.deepcopy(self.snapshot)
            if change=='missing':sample['records']=[]
            elif change=='duplicate':sample['records'].append(copy.deepcopy(sample['records'][0]))
            elif change=='zero_basis':sample['records'][0]['basis'][0]=[0,0,0]
            else:sample['records'][0]['position'][0]=float('nan')
            with self.subTest(change=change),self.assertRaises(ValueError):self.build(sample)
    def test_stale_or_missing_source_binding_is_rejected(self):
        validate_source(ROOT,self.snapshot)
        for value in ['', '0'*64]:
            sample=copy.deepcopy(self.snapshot);sample['source_bindings_lf']['game/data/orison_v2_blockout.json']=value
            with self.assertRaises(ValueError):validate_source(ROOT,sample)
    def test_overlapping_splices_form_a_union_without_double_removal(self):
        self.assertEqual(merge([[-.2,.1],[.05,.3],[.4,.5]]),[[-.2,.3],[.4,.5]])
        with self.assertRaises(ValueError):merge([[.2,.1]])

if __name__=='__main__':unittest.main()
