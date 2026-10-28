"""Independent area and reservation tests for the distant native grade."""
from pathlib import Path
import importlib.util,unittest

PATH=Path(__file__).resolve().parents[2]/'art/blender/scripts/city_ground_apron_geometry.py'
spec=importlib.util.spec_from_file_location('apron_geometry',PATH)
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)

class Apron(unittest.TestCase):
    def test_exact_ring_area_and_no_old_ground_overlap(self):
        rows=module.apron_boxes([-108,-4,-108,112,-.02,64],[-420,-420,420,420],.28)
        self.assertEqual(len(rows),4)
        area=0
        for row in rows:
            x,y,z,X,Y,Z=row['bounds'];area+=(X-x)*(Z-z)
            self.assertAlmostEqual(Y,-.02)
            self.assertAlmostEqual(Y-y,.28)
            self.assertTrue(X<=-108 or x>=112 or Z<=-108 or z>=64)
        self.assertAlmostEqual(area,840*840-220*172)
        for i,a in enumerate(rows):
            for b in rows[i+1:]:
                av,bv=a['bounds'],b['bounds']
                self.assertTrue(min(av[3],bv[3])<=max(av[0],bv[0]) or min(av[5],bv[5])<=max(av[2],bv[2]))

    def test_invalid_or_intersecting_envelopes_refused(self):
        for outer in [[-100,-420,420,420],[-420,-108,420,420],[-420,-420,112,420],[-420,-420,420,50]]:
            with self.assertRaises(AssertionError):module.apron_boxes([-108,-4,-108,112,-.02,64],outer,.28)
        for depth in [0,-.2,1,5]:
            with self.assertRaises(AssertionError):module.apron_boxes([-108,-4,-108,112,-.02,64],[-420,-420,420,420],depth)

    def test_relief_preserves_every_installed_building_and_retained_seam(self):
        import json
        root=PATH.parents[3]
        r=json.loads((root/'art/data/city_ground_apron/source_plan.json').read_text())['relief']
        buildings=json.loads((root/'art/data/city_horizon/source_plan.json').read_text())['buildings']
        for b in buildings:
            a,z,A,Z=b['rect']
            for x in [a,(a+A)/2,A]:
                for y in [z,(z+Z)/2,Z]:self.assertEqual(module.relief_height(x,y,-.02,r),-.02,b['id'])
        for x in [-108,0,112]:
            for z in [-108,0,64]:self.assertEqual(module.relief_height(x,z,-.02,r),-.02)
        self.assertAlmostEqual(module.relief_height(450,0,-.02,r),-8)
        self.assertAlmostEqual(module.relief_height(-400,0,-.02,r),-3.5)
        self.assertAlmostEqual(module.relief_height(0,-360,-.02,r),-8)
        self.assertEqual(r['street_asl_m']+r['water_scene_y_m'],0)

    def test_relief_and_clipped_water_are_closed_with_real_depth(self):
        import json,collections,numpy as np
        r=json.loads((PATH.parents[3]/'art/data/city_ground_apron/source_plan.json').read_text())['relief']
        for row in module.apron_boxes([-108,-4,-108,112,-.02,64],[-500,-500,500,500],.28):
            v,f,keys=module.relief_stock(row['bounds'],r)
            for points,faces in [(v,f),module.water_stock(v,f,r['water_scene_y_m'])]:
                if not points:continue
                edges=collections.Counter(tuple(sorted((a,b))) for face in faces for a,b in zip(face,face[1:]+face[:1]))
                self.assertTrue(all(n==2 for n in edges.values()),row['id'])
                volume=sum(np.dot(points[face[0]],np.cross(points[face[i]],points[face[i+1]]))/6 for face in faces for i in range(1,len(face)-1))
                self.assertGreater(volume,0,row['id'])
            self.assertEqual(len(keys),len(f))

if __name__=='__main__':unittest.main()
