"""Sampling limits prevent physical leather grain becoming oversized noise."""
from pathlib import Path
import sys
import unittest
import numpy as np
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'art/tools'))
from build_binding_stock import leather


class LeatherReliefTests(unittest.TestCase):
    def test_unresolved_valleys_are_roughness_debt_not_aliased_bumps(self):
        height, normal, metadata=leather(128,.16)
        np.testing.assert_array_equal(height,np.zeros((128,128)))
        np.testing.assert_array_equal(normal,np.broadcast_to([0.,0.,1.],normal.shape))
        self.assertFalse(metadata['bands'])
        self.assertEqual(metadata['unresolved_for_roughness'][0]['valley_width_m'],.00065)

    def test_resolved_grain_retains_micrometre_scale(self):
        height,normal,metadata=leather(1024,.16)
        self.assertGreater(height.std(),.000003)
        self.assertLess(height.std(),.000022)
        self.assertLess(height.max()-height.min(),.000023)
        self.assertGreater(metadata['maximum_slope'],.005)
        self.assertLess(metadata['maximum_slope'],.2)
        np.testing.assert_allclose(np.linalg.norm(normal,axis=-1),1.,atol=1e-12)
        self.assertFalse(metadata['unresolved_for_roughness'])

    def test_invalid_physical_scales_refuse(self):
        for size,tile in [(True,.32),(3,.32),(16,0),(16,float('nan'))]:
            with self.subTest(size=size,tile=tile),self.assertRaises(ValueError):
                leather(size,tile)


if __name__=='__main__': unittest.main()
