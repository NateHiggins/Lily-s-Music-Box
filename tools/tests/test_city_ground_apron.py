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

if __name__=='__main__':unittest.main()
