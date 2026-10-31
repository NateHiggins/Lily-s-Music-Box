"""Continuous public paving and preserved openings in the eastern district."""
from pathlib import Path
import copy,importlib.util,json,unittest

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('city_street_geometry',ROOT/'art/blender/scripts/city_street_geometry.py')
geo=importlib.util.module_from_spec(spec);spec.loader.exec_module(geo)


class EasternStreet(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.plan=json.loads((ROOT/'art/data/city_streets/source_plan.json').read_text())
        cls.district=next(r for r in cls.plan['districts'] if r['id']=='Eastern')
        cls.threshold=json.loads((ROOT/'game/data/orison_v2/exterior/street_frame.json').read_text())['source_threshold_z']

    def make(self,segments,district=None):
        return geo.district_topology(district or self.district,segments,self.plan['curb_width_m'],self.plan['curb_cap_overhang_m'])

    def swept_rect(self,a,b):
        radius=.33
        lo=[min(a[i],b[i])-radius for i in range(2)];hi=[max(a[i],b[i])+radius for i in range(2)]
        return geo.rectangle([lo[0],-hi[1]-self.threshold,hi[0],-lo[1]-self.threshold])

    def test_near_and_lower_keep_four_full_width_footway_approaches(self):
        # Conservative standing-body width, including the corner-stoop bypass.
        # This is nominal source paving coverage, not loaded collision proof.
        legs=[((148.8,-8.7),(148.8,135.3)),((148.8,135.3),(115.5,135.3)),
              ((148.8,-8.7),(205.8,-8.7)),((205.8,-8.7),(205.8,-121.15))]
        for segments in [12,8]:
            result=self.make(segments)
            self.assertLess(result['maximum_curve_sagitta_m'],self.plan['lod_error_m'])
            for a,b in legs:
                missed=geo.cut(self.swept_rect(a,b),result['walk'])
                self.assertLess(sum(geo.area(p) for p in missed),1e-7,(segments,a,b))
        # A deliberately absent corridor must not pass the same coverage test.
        result=self.make(12)
        wrong=[p for p in result['walk'] if geo.bounds(p)[2]<147.0]
        missed=geo.cut(self.swept_rect(*legs[0]),wrong)
        self.assertGreater(sum(geo.area(p) for p in missed),1.0)

    def test_existing_main_road_connection_has_no_new_end_curb(self):
        connection=geo.rectangle([114.99,-19.422,115.01,-19.222])
        result=self.make(12)
        self.assertFalse(any(geo.intersection(connection,p) for p in result['curb_caps']))
        wrong=copy.deepcopy(self.district);wrong['open_edges']=[]
        self.assertTrue(any(geo.intersection(connection,p) for p in self.make(12,wrong)['curb_caps']))

    def test_preserved_steps_have_no_new_public_floor_overlay(self):
        for segments in [12,8]:
            result=self.make(segments)
            for protected in result['reserved']:
                for p in result['walk']:
                    overlap=geo.intersection(p,protected)
                    self.assertLess(geo.area(overlap) if overlap else 0.,1e-8)


if __name__=='__main__':unittest.main()
