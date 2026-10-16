import sys
import unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from check_v2_heating_envelopes import floor_clearance, cylinder_separation
from heating_pipe_fittings import floor_boundary


class HeatingEnvelopeTests(unittest.TestCase):
    def test_coaxial_finite_cylinders_have_flat_end_gap(self):
        self.assertAlmostEqual(cylinder_separation([0,0,0],[1,0,0],.2,
                                                  [1.01,0,0],[2,0,0],.2),.01)

    def test_parallel_cylinders_keep_radial_clearance(self):
        self.assertAlmostEqual(cylinder_separation([0,0,0],[1,0,0],.2,
                                                  [0,.5,0],[1,.5,0],.2),.1)

    def test_crossed_cylinders_cannot_be_certified_clear(self):
        self.assertLess(cylinder_separation([-1,0,0],[1,0,0],.1,
                                            [0,-1,0],[0,1,0],.1),0)

    def test_subdivision_merges_without_closing_a_real_gap(self):
        _, edges = floor_boundary([[i,0,i+1,1] for i in range(100)],[])
        self.assertEqual(len(edges),4)
        _, edges = floor_boundary([[0,0,1,1],[2,0,3,1]],[])
        self.assertEqual(len(edges),8)
        self.assertEqual(floor_clearance([[.5,.5],[2.5,.5]],
                                        [[0,0,1,1],[2,0,3,1]],[]),0)

    def test_shared_rect_edge_is_not_a_floor_boundary(self):
        self.assertAlmostEqual(floor_clearance([[.5,.5],[1.5,.5]],
                               [[0,0,1,1],[1,0,2,1]],[]),.5)

    def test_narrow_opening_cannot_fall_between_samples(self):
        self.assertAlmostEqual(floor_clearance([[.2,.5],[1.8,.5]],
                               [[0,0,2,1]],[[.991,.4,.999,.6]]),0)

    def test_diagonal_corner_clearance_uses_full_segment(self):
        self.assertAlmostEqual(floor_clearance([[.5,1],[1,.5]],
                               [[0,0,2,2]],[[1,1,1.5,1.5]]),2**.5/4)

    def test_route_outside_union_is_rejected(self):
        self.assertEqual(floor_clearance([[-1,.5],[.5,.5]],[[0,0,1,1]],[]),0)


if __name__=='__main__': unittest.main()
