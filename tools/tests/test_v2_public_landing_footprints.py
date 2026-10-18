"""Retained landing unions preserve lift/stair voids and full capsule support."""
import copy
import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from derive_v2_public_landings import union,contains,capsule_supported,capsule_segment_supported,derive,body_radius


class LandingFootprints(unittest.TestCase):
    def test_overlap_is_not_double_counted(self):
        self.assertAlmostEqual(union([[0,0,2,2],[1,0,3,2]])[0],6)

    def test_internal_partition_is_not_an_obstruction(self):
        rects = [[0,0,1,2],[1,0,2,2]]
        self.assertTrue(capsule_supported(rects,[1,1],.8))

    def test_hole_and_concave_edge_cannot_support_a_capsule(self):
        ring = [[0,0,3,1],[0,2,3,3],[0,1,1,2],[2,1,3,2]]
        self.assertAlmostEqual(union(ring)[0],8)
        self.assertFalse(contains(ring,[1.5,1.5]))
        self.assertFalse(capsule_supported(ring,[.9,1.5],.24))
        self.assertTrue(capsule_supported(ring,[.5,1.5],.24))

    def test_safe_endpoints_do_not_prove_a_route_across_the_lift_void(self):
        ring = [[0,0,3,1],[0,2,3,3],[0,1,1,2],[2,1,3,2]]
        self.assertTrue(capsule_supported(ring,[.5,1.5],.24))
        self.assertTrue(capsule_supported(ring,[2.5,1.5],.24))
        self.assertFalse(capsule_segment_supported(ring,[.5,1.5],[2.5,1.5],.24))
        self.assertTrue(capsule_segment_supported(ring,[.5,.5],[2.5,.5],.24))
        self.assertFalse(capsule_segment_supported(ring,[.5,.9],[2.5,.9],.24))
        self.assertTrue(capsule_segment_supported([[0,0,1,2],[1,0,2,2]],[.5,1],[1.5,1],.24))

    def test_actual_support_census_preserves_missing_floor_and_void_diagnoses(self):
        layout = json.loads((ROOT/'game/data/orison_v2_blockout.json').read_text(encoding='utf-8'))
        original = copy.deepcopy(layout)
        radius=body_radius((ROOT/'game/scripts/player/player_controller.gd').read_text(encoding='utf-8'))
        self.assertEqual(radius,.33)
        result = derive(layout,radius)['landings']
        self.assertEqual(layout,original)
        self.assertEqual([r['union_area_m2'] for r in result],[33.815]+[38.32]*5)
        for r in result:
            self.assertFalse(contains(r['support_rects'],[0,-1.5]),r['level'])
        for r in result:
            self.assertEqual(r['legacy_unsupported_area_m2'],0)
            self.assertEqual(r['programme_space_id'],r['level']+'_LANDING')
        for r in [result[1],result[3]]:
            self.assertTrue(r['review_stance_supports_capsule'])
        self.assertIsNone(result[2]['review_stance'])
        for r in result:
            self.assertTrue(r['geometric_stance_candidates'])
            for candidate in r['geometric_stance_candidates']:
                p=candidate['position']
                self.assertTrue(capsule_supported(r['support_rects'],[p[0],p[2]],radius))
        self.assertEqual([r['legacy_space_id'] for r in [result[0],result[4],result[5]]],[None]*3)

    def test_old_review_envelopes_remain_a_measurable_negative_fixture(self):
        layout=json.loads((ROOT/'game/data/orison_v2_blockout.json').read_text(encoding='utf-8'))
        for space in layout['spaces']:
            if space['id'] not in ['F02_LANDING','F03_LANDING','F04_LANDING']:continue
            for field in ['floor_platforms','landing_core','programme_anchors']:space.pop(field,None)
            space['rect']=[-2.2,-3.35,1.45,.6]
        result=derive(layout,.33)['landings']
        self.assertEqual([r['legacy_unsupported_area_m2'] for r in result[1:4]],[6.125]*3)

    def test_invalid_or_foreign_floor_stock_is_rejected(self):
        for r in [[0,0,0,1],[0,0,float('nan'),1]]:
            with self.assertRaises(ValueError):union([r])
        layout = json.loads((ROOT/'game/data/orison_v2_blockout.json').read_text(encoding='utf-8'))
        next(r for r in layout['platforms'] if r['id']=='F02_PUBLIC_LANDING_S')['level']='F03'
        with self.assertRaises(ValueError):derive(layout,.33)

    def test_radius_comes_from_an_explicit_production_literal(self):
        self.assertEqual(body_radius('const BODY_RADIUS := 0.33\n'),.33)
        for text in ['','const BODY_RADIUS := 0','const BODY_RADIUS := other_setting']:
            with self.assertRaises(ValueError):body_radius(text)


if __name__=='__main__':
    unittest.main()
