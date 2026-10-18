"""Source-bound construction checks before any expensive world capture."""
import copy, json, sys, unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from plan_v2_arcade_lantern import build


class LanternTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source=json.loads((ROOT/'art/data/building_layout.json').read_text())

    def test_top_light_has_four_clear_well_paths_but_original_slabs_do_not(self):
        result=build(self.source)
        for x in [13.4,14.6]:
            for z in [51.,52.2]:
                def crosses(row):return row['low'][0]<x<row['high'][0] and row['low'][2]<z<row['high'][2]
                self.assertFalse(any(crosses(r) for r in result['parts']))
                self.assertTrue(all(crosses(r) for r in result['retire']))

    def test_clock_endpoint_connects_to_tie_and_source_geometry_is_untouched(self):
        original=copy.deepcopy(self.source);result=build(self.source)
        self.assertEqual(original,self.source)
        parts={r['id']:r for r in result['parts']}
        collar,tie=parts['clock_hanger_collar'],parts['clock_cross_tie']
        self.assertEqual(collar['low'][1],result['hanger_bearing'][1])
        self.assertEqual(collar['high'][1],tie['low'][1])
        self.assertEqual([r['id'] for r in result['retire']],['site_passage_lantern_cap_'+str(i) for i in range(3)])
        self.assertEqual(result,build(self.source))

    def test_changed_tiers_light_and_hanger_refuse_stale_fitting(self):
        for identity,field,value in [('site_passage_lantern_cap_1','z0',14.),
                                      ('site_passage_lantern_cap_light','z0',11.7),
                                      ('site_crossing_clock_stem','r',.1)]:
            source=copy.deepcopy(self.source)
            row=next(r for f in source['floors'] if f['id']=='F01' for r in f['furniture'] if r['id']==identity)
            row[field]=value
            with self.subTest(identity=identity),self.assertRaises(ValueError):build(source)


if __name__=='__main__':unittest.main()
