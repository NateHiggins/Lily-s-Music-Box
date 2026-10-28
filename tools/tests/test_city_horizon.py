"""Reject open/overlapping source stock and windows behind real party walls."""
from pathlib import Path
import importlib.util,collections,json,unittest
import numpy as np
root=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('horizon',root/'art/blender/scripts/city_horizon_geometry.py')
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)

class Horizon(unittest.TestCase):
    def test_reveal_is_closed_oriented_and_has_the_exact_void_volume(self):
        v,f=module.reveal_cell(0,0,3,3,1,.6,2,2.4,.18)
        edges=collections.Counter(tuple(sorted((a,b))) for face in f for a,b in zip(face,face[1:]+face[:1]))
        self.assertTrue(edges and all(n==2 for n in edges.values()))
        volume=0
        for face in f:
            for i in range(1,len(face)-1):
                a,b,c=[np.array(v[j]) for j in [face[0],face[i],face[i+1]]]
                volume+=np.dot(a,np.cross(b,c))/6
        self.assertAlmostEqual(volume,(9-1.8)*.18)

    def test_party_wall_overlap_uses_the_full_segment_and_actual_roof_height(self):
        other=[dict(rect=[0,0,10,10],height_m=25)]
        self.assertTrue(module.party_wall_overlap((5,-2),(5,12),3,other))
        self.assertFalse(module.party_wall_overlap((-1,-2),(-1,12),3,other))
        self.assertFalse(module.party_wall_overlap((5,-2),(5,-.01),3,other))
        self.assertFalse(module.party_wall_overlap((5,-2),(5,12),26,other))
        with self.assertRaises(AssertionError):module.party_wall_overlap((1,1),(2,2),3,other)

    def test_retained_ground_overlap_and_duplicate_ids_fail_closed(self):
        plan=dict(schema='orison.city-horizon.v1',frame='ORISON_V2_BUILDING_FRAME',buildings=[dict(id='one',rect=[150,0,170,50],height_m=25)])
        self.assertTrue(module.validate_plan(plan,[-108,-4,-108,112,-.02,64]))
        plan['buildings'].append(dict(plan['buildings'][0]))
        with self.assertRaises(AssertionError):module.validate_plan(plan,[-108,-4,-108,112,-.02,64])
        plan['buildings'].pop()
        plan['buildings'][0]['rect']=[100,0,120,50]
        with self.assertRaises(AssertionError):module.validate_plan(plan,[-108,-4,-108,112,-.02,64])

    def test_individual_study_stock_is_closed_and_oriented_including_concave_court(self):
        plan=json.loads((root/'art/data/city_horizon/source_plan.json').read_text())
        studies=[r for r in plan['buildings'] if 'architecture' in r]
        self.assertGreaterEqual(len(studies),3)
        for row in studies:
            outline=module.building_outline(row)
            for v,f in [module.extrusion(outline,0,.18),module.cornice_ring(outline,.32,0,.2)]:
                edges=collections.Counter(tuple(sorted((a,b))) for face in f for a,b in zip(face,face[1:]+face[:1]))
                self.assertTrue(all(n==2 for n in edges.values()),row['id'])
                volume=sum(np.dot(v[face[0]],np.cross(v[face[i]],v[face[i+1]]))/6 for face in f for i in range(1,len(face)-1))
                self.assertGreater(volume,0,row['id'])
            floors=module.floor_intervals(row)
            self.assertAlmostEqual(floors[-1][1],row['height_m'])
            self.assertEqual(len(outline),len(row['architecture']['side_bays']))
        # Reversed and malformed source must fail before a native export.
        bad=dict(studies[0]);bad['architecture']=dict(bad['architecture'],floor_heights_m=[1,2])
        with self.assertRaises(AssertionError):module.floor_intervals(bad)
        bad['architecture']=dict(studies[0]['architecture'],outline_m=[[x,-y] for x,y in reversed(module.building_outline(studies[0]))])
        with self.assertRaises(AssertionError):module.building_outline(bad)

if __name__=='__main__':unittest.main()
