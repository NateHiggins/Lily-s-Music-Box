import copy,json,sys,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools'))
from build_v2_ground_probe_updates import build,OWNER

class GroundProbeUpdates(unittest.TestCase):
    def setUp(self):
        self.layout=json.loads((ROOT/'game/data/orison_v2_blockout.json').read_text())
        self.source=json.loads((ROOT/'game/tests/fixtures/orison_ground_source.json').read_text())
        self.survey=json.loads((ROOT/'art/data/orison_ground/discovery/runtime_survey.json').read_text())
    def test_exactly_three_source_owned_contacts_and_immutable_originals(self):
        before=copy.deepcopy(self.source);result=build(self.layout,self.source,self.survey)
        self.assertEqual(before,self.source);self.assertEqual(len(result['records']),3)
        for row in result['records']:
            self.assertEqual(row['point'],self.source['stations']['records'][row['record_index']]['points'][row['point_index']])
            self.assertEqual(row['collider'],OWNER)
    def test_cannot_replace_a_real_historical_owner(self):
        self.source['prior_records'][8]['samples'][0]['first_owner']='original_wall'
        with self.assertRaisesRegex(ValueError,'historical owner'):build(self.layout,self.source,self.survey)
    def test_changed_or_missing_actual_roof_refuses(self):
        for change in ['missing','unaligned','bounds']:
            survey=copy.deepcopy(self.survey);row=next(r for r in survey['records'] if r['owner']==OWNER)
            if change=='missing':survey['records'].remove(row)
            elif change=='unaligned':row['aligned']=False
            else:row['bounds'][4]=.03
            with self.subTest(change=change),self.assertRaises(ValueError):build(self.layout,self.source,survey)

if __name__=='__main__':unittest.main()
